import CoreGraphics
import Metal

/// RGB Split's dispersion on the GPU: each pixel gathers the image from many places along the split, each tinted by
/// its place in the spectrum (blue at one end, green in the middle, red at the other), so edges fan out into a
/// continuous rainbow as light through a prism does, rather than three offset copies. Blur smears each of those along
/// the same line, into streaks. Linear splits along one direction everywhere; Radial splits outwards from a center,
/// more the farther from it, leaving the center sharp.
nonisolated final class MetalDispersion: @unchecked Sendable {
    static let shared: MetalDispersion? = try? MetalDispersion()
    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let pipeline: MTLComputePipelineState

    struct Parameters {
        /// In the image's pixels, rows top-down.
        var center: SIMD2<Float>
        /// Linear's direction, a unit vector, rows top-down.
        var direction: SIMD2<Float>
        /// How far the spectrum spreads and the streaks run, in pixels: everywhere for Linear, at `reach` from the
        /// center for Radial (in proportion to the distance from it).
        var distance: Float
        var blur: Float
        var reach: Float
        var radial: UInt32
        /// The image's sides at the canvas's edge, which carry its edge pixels on rather than going clear:
        /// 1 left, 2 right, 4 top, 8 bottom.
        var sides: UInt32
        /// Samples across the spectrum, and along each streak.
        var spectral: UInt32
        var smear: UInt32
    }

    private init() throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue(),
              let function = try device.makeLibrary(source: Self.source, options: nil).makeFunction(name: "disperse")
        else { throw ExportError.render }
        self.device = device
        self.queue = queue
        pipeline = try device.makeComputePipelineState(function: function)
    }

    /// Disperses `pixels` (8-bit premultiplied RGBA, rows top-down) in place.
    func run(_ pixels: CGContext, _ parameters: Parameters) throws {
        guard let data = pixels.data else { throw ExportError.render }
        let width = pixels.width, height = pixels.height
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.storageMode = .shared
        guard let source = device.makeTexture(descriptor: descriptor), let destination = device.makeTexture(descriptor: descriptor),
              let command = queue.makeCommandBuffer(), let encoder = command.makeComputeCommandEncoder()
        else { throw ExportError.render }
        let region = MTLRegionMake2D(0, 0, width, height)
        source.replace(region: region, mipmapLevel: 0, withBytes: data, bytesPerRow: pixels.bytesPerRow)
        var parameters = parameters
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(source, index: 0)
        encoder.setTexture(destination, index: 1)
        encoder.setBytes(&parameters, length: MemoryLayout<Parameters>.stride, index: 0)
        encoder.dispatchThreads(MTLSize(width: width, height: height, depth: 1),
                                threadsPerThreadgroup: MTLSize(width: 16, height: 16, depth: 1))
        encoder.endEncoding()
        command.commit()
        command.waitUntilCompleted()
        guard command.status == .completed else { throw command.error ?? ExportError.render }
        destination.getBytes(data, bytesPerRow: pixels.bytesPerRow, from: region, mipmapLevel: 0)
    }

    // Compiled at launch by the system's Metal compiler, as the brush's is.
    private static let source = """
#include <metal_stdlib>
using namespace metal;

struct Parameters {
    float2 center;
    float2 direction;
    float distance;
    float blur;
    float reach;
    uint radial;
    uint sides;
    uint spectral;
    uint smear;
};

// The image at `q` (pixels), clear past a side that isn't the canvas's edge, its edge carried on past one that is.
float4 tap(texture2d<float, access::sample> image, float2 q, float2 size, uint sides) {
    constexpr sampler edges(coord::normalized, address::clamp_to_edge, filter::linear);
    if ((q.x < 0 && !(sides & 1)) || (q.x > size.x && !(sides & 2)) || (q.y < 0 && !(sides & 4)) || (q.y > size.y && !(sides & 8))) {
        return float4(0);
    }
    return image.sample(edges, q / size);
}

kernel void disperse(texture2d<float, access::sample> image [[texture(0)]],
                     texture2d<float, access::write> result [[texture(1)]],
                     constant Parameters &p [[buffer(0)]],
                     uint2 pixel [[thread_position_in_grid]]) {
    float2 size = float2(image.get_width(), image.get_height());
    if (pixel.x >= image.get_width() || pixel.y >= image.get_height()) return;
    float2 at = float2(pixel) + 0.5;
    float2 axis = p.radial ? (at - p.center) / max(p.reach, 1.0) : p.direction;
    float2 spread = axis * p.distance, streak = axis * p.blur;
    uint n = max(p.spectral, 1u), m = max(p.smear, 1u);
    // Each pixel's samples sit a little apart from its neighbors', so where they're spread wide a hard edge fans into a
    // smooth spectrum with a fine grain, rather than a row of separate copies.
    float jitter = fract(sin(dot(float2(pixel), float2(12.9898, 78.233))) * 43758.5453);
    float3 color = 0, alpha = 0, total = 0;
    for (uint i = 0; i < n; i++) {
        // −1 is the blue end, 0 green, 1 red: red lands ahead along the split, blue behind.
        float t = n == 1 ? 0.0 : (float(i) + jitter) / float(n) * 2.0 - 1.0;
        float3 weight = float3(smoothstep(-0.3, 1.0, t), 1.0 - smoothstep(0.0, 1.0, abs(t)) + 0.05, smoothstep(-0.3, 1.0, -t));
        for (uint j = 0; j < m; j++) {
            // Each streak trails back along the split, so the image smears out in its direction.
            float u = m == 1 ? 0.0 : (float(j) + jitter) / float(m);
            float4 c = tap(image, at - spread * t - streak * u, size, p.sides);
            color += weight * c.rgb;
            alpha += weight * c.a;
            total += weight;
        }
    }
    color /= total;
    alpha /= total;
    // As opaque as the most opaque channel, so each color stays within the alpha it's stored multiplied by.
    float a = max(alpha.r, max(alpha.g, alpha.b));
    result.write(float4(min(color, float3(a)), a), pixel);
}
"""
}
