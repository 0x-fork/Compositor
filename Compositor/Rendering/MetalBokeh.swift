import CoreGraphics
import CoreImage
import Metal

/// Bokeh's lens blur on the GPU: every pixel gathers the light around it within the aperture's shape — round, a
/// hexagon of blades, an anamorphic oval, or a cat's eye clipped toward the frame's edges — more of it at the rim when
/// Ring asks. It works in half floats, so lights brighter than white keep their brightness through the blur. A big
/// blur runs on a smaller copy, which it hides, so its cost stays the same however wide the discs. It runs inside the
/// Core Image graph (`BokehKernel`), so nothing is read back to the CPU on the way.
nonisolated final class MetalBokeh: @unchecked Sendable {
    static let shared: MetalBokeh? = try? MetalBokeh()
    /// The widest disc radius gathered at full size, in pixels.
    static let largestRadius: CGFloat = 20
    let pipeline: MTLComputePipelineState

    struct Parameters {
        var radius: Float
        var shape: UInt32
        var ring: Float
        /// The whole blurred region, in the smaller copy's coordinates (y up): its middle is the frame's, for Cat's Eye.
        var regionOrigin: SIMD2<Float> = .zero
        var regionSize: SIMD2<Float> = SIMD2(1, 1)
        /// Where the output's and input's texels sit in those coordinates; their rows run top-down.
        var outputTop: SIMD2<Float> = .zero
        var inputTop: SIMD2<Float> = .zero
    }

    private init() throws {
        guard let device = MTLCreateSystemDefaultDevice(),
              let function = try device.makeLibrary(source: Self.source, options: nil).makeFunction(name: "bokeh")
        else { throw ExportError.render }
        pipeline = try device.makeComputePipelineState(function: function)
    }

    /// `image` blurred into discs of `radius` pixels within `extent`, the result covering `extent`.
    func blur(_ image: CIImage, extent: CGRect, radius: CGFloat, shape: BokehShape, ring: Double) throws -> CIImage {
        let shrink = min(1, Self.largestRadius / max(radius, 0.5))
        let small = radius * shrink
        // Room for the discs reaching in from past the edge, which carries its edge pixels on.
        let margin = (small * 1.7).rounded(.up) + 2
        let region = CGRect(x: extent.minX * shrink, y: extent.minY * shrink, width: extent.width * shrink, height: extent.height * shrink)
            .insetBy(dx: -margin, dy: -margin).integral
        let source = image.clampedToExtent().transformed(by: CGAffineTransform(scaleX: shrink, y: shrink))
        var parameters = Parameters(radius: Float(small), shape: shape.index, ring: Float(ring))
        parameters.regionOrigin = SIMD2(Float(region.minX), Float(region.minY))
        parameters.regionSize = SIMD2(Float(region.width), Float(region.height))
        let reach = (small * 1.62).rounded(.up) + 2
        let blurred = try BokehKernel.apply(withExtent: region, inputs: [source], arguments: [
            "parameters": withUnsafeBytes(of: parameters) { Data($0) }, "reach": reach])
        return blurred.transformed(by: CGAffineTransform(scaleX: 1 / shrink, y: 1 / shrink)).cropped(to: extent)
    }

    // Compiled at launch by the system's Metal compiler, as the brush's is.
    private static let source = """
#include <metal_stdlib>
using namespace metal;

struct Parameters {
    float radius;
    uint shape;     // 0 round, 1 hexagon, 2 oval, 3 cat's eye
    float ring;
    float2 regionOrigin;
    float2 regionSize;
    float2 outputTop;
    float2 inputTop;
};

// How far `o` (in disc radii) is toward the aperture's edge, 1 on it.
float aperture(float2 o, uint shape, float2 outward) {
    if (shape == 1) {
        float2 q = abs(o);
        return max(q.x * 0.866025 + q.y * 0.5, q.y) / 0.866025 * 0.93;
    }
    if (shape == 2) return length(o * float2(1.0, 0.62));
    if (shape == 3) {
        // The disc clipped by a second one shifted toward the frame's middle, more so farther out.
        return max(length(o), length(o + outward * 1.25));
    }
    return length(o);
}

kernel void bokeh(texture2d<float, access::sample> image [[texture(0)]],
                  texture2d<float, access::write> result [[texture(1)]],
                  constant Parameters &p [[buffer(0)]],
                  uint2 pixel [[thread_position_in_grid]]) {
    if (pixel.x >= result.get_width() || pixel.y >= result.get_height()) return;
    constexpr sampler linear(coord::pixel, address::clamp_to_edge, filter::linear);
    // This pixel's center measured from the region's top-left corner, rows down, as one texture over all of it has it.
    float2 regionTop = float2(p.regionOrigin.x, p.regionOrigin.y + p.regionSize.y);
    float2 here = float2(p.outputTop.x - regionTop.x, regionTop.y - p.outputTop.y) + float2(pixel) + 0.5;
    float2 fromMiddle = (here - p.regionSize * 0.5) / (max(p.regionSize.x, p.regionSize.y) * 0.5);
    // The same place in the input's texels.
    float2 at = float2(p.outputTop.x - p.inputTop.x, p.inputTop.y - p.outputTop.y) + float2(pixel) + 0.5;
    float2 outward = fromMiddle * min(1.0, length(fromMiddle));
    float radius = max(p.radius, 0.5);
    int reachX = int(ceil(radius)), reachY = int(ceil(radius * (p.shape == 2 ? 1.62 : 1.0)));
    float soft = 1.0 / radius;
    float4 sum = 0;
    float total = 0;
    for (int dy = -reachY; dy <= reachY; dy++) {
        for (int dx = -reachX; dx <= reachX; dx++) {
            float2 o = float2(dx, dy) / radius;
            float d = aperture(o, p.shape, outward);
            float inside = 1.0 - smoothstep(1.0 - soft, 1.0, d);
            if (inside <= 0.0) continue;
            // A lens that draws its discs with a bright rim, as many fast ones do.
            float weight = inside * (1.0 + p.ring * 2.5 * smoothstep(0.6, 0.97, d));
            sum += image.sample(linear, at + float2(dx, dy)) * weight;
            total += weight;
        }
    }
    result.write(sum / max(total, 1e-5), pixel);
}
"""
}

/// Runs `MetalBokeh` inside a Core Image graph, as `DispersionKernel` runs RGB Split's.
final class BokehKernel: CIImageProcessorKernel {
    override class var outputFormat: CIFormat { .RGBAh }
    override class func formatForInput(at input: Int32) -> CIFormat { .RGBAh }

    override class func roi(forInput input: Int32, arguments: [String: Any]?, outputRect: CGRect) -> CGRect {
        let reach = arguments?["reach"] as? CGFloat ?? 0
        return outputRect.insetBy(dx: -reach, dy: -reach)
    }

    override class func process(with inputs: [CIImageProcessorInput]?, arguments: [String: Any]?,
                                output: CIImageProcessorOutput) throws {
        guard let input = inputs?.first, let source = input.metalTexture, let destination = output.metalTexture,
              let command = output.metalCommandBuffer, let gpu = MetalBokeh.shared,
              let data = arguments?["parameters"] as? Data, data.count >= MemoryLayout<MetalBokeh.Parameters>.size,
              let encoder = command.makeComputeCommandEncoder() else { throw ExportError.render }
        var parameters = data.withUnsafeBytes { $0.loadUnaligned(as: MetalBokeh.Parameters.self) }
        // Core Image hands over textures with their first row at the top of their region.
        parameters.outputTop = SIMD2(Float(output.region.minX), Float(output.region.maxY))
        parameters.inputTop = SIMD2(Float(input.region.minX), Float(input.region.maxY))
        encoder.setComputePipelineState(gpu.pipeline)
        encoder.setTexture(source, index: 0)
        encoder.setTexture(destination, index: 1)
        encoder.setBytes(&parameters, length: MemoryLayout<MetalBokeh.Parameters>.stride, index: 0)
        encoder.dispatchThreads(MTLSize(width: destination.width, height: destination.height, depth: 1),
                                threadsPerThreadgroup: MTLSize(width: 16, height: 16, depth: 1))
        encoder.endEncoding()
    }
}
