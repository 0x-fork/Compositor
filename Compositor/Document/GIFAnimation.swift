import Foundation
import CoreGraphics

/// Encoded frames and small previews are immutable and shared by layers, history and background saves.
nonisolated final class GIFSource: @unchecked Sendable {
    static let byteLimit = 512 * 1024 * 1024
    static let totalByteLimit = DocumentLimits.documentPixelBudget * 4
    static let totalThumbnailPixelBudget = GIFTimelineLimits.thumbnailPixelBudget

    let data: Data
    let frames: [GIFTimelineFrame]
    let width: Int
    let height: Int

    init(data: Data, frames: [GIFTimelineFrame], width: Int, height: Int) {
        self.data = data
        self.frames = frames
        self.width = width
        self.height = height
    }

    var thumbnailPixels: Int { frames.reduce(0) { $0 + $1.thumbnail.width * $1.thumbnail.height } }
}

/// Image Size's rasterization, applied lazily to every frame, including rotation and uneven scaling.
nonisolated struct GIFFrameGeometry: Equatable, Codable, Sendable {
    let width: Int
    let height: Int
    let a: Double
    let b: Double
    let c: Double
    let d: Double
    let tx: Double
    let ty: Double
    var sampling: LayerSampling = .high

    init(width: Int, height: Int, unitTransform: CGAffineTransform, sampling: LayerSampling = .high) {
        self.width = width
        self.height = height
        a = unitTransform.a; b = unitTransform.b; c = unitTransform.c; d = unitTransform.d
        tx = unitTransform.tx; ty = unitTransform.ty
        self.sampling = sampling
    }

    private enum CodingKeys: String, CodingKey { case width, height, a, b, c, d, tx, ty, sampling }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        width = try values.decode(Int.self, forKey: .width)
        height = try values.decode(Int.self, forKey: .height)
        a = try values.decode(Double.self, forKey: .a); b = try values.decode(Double.self, forKey: .b)
        c = try values.decode(Double.self, forKey: .c); d = try values.decode(Double.self, forKey: .d)
        tx = try values.decode(Double.self, forKey: .tx); ty = try values.decode(Double.self, forKey: .ty)
        sampling = try values.decodeIfPresent(LayerSampling.self, forKey: .sampling) ?? .high
    }

    var unitTransform: CGAffineTransform { CGAffineTransform(a: a, b: b, c: c, d: d, tx: tx, ty: ty) }
    var isValid: Bool {
        (1...DocumentLimits.maxSide).contains(width) && (1...DocumentLimits.maxSide).contains(height)
            && width * height <= DocumentLimits.maxSurfacePixels
            && [a, b, c, d, tx, ty].allSatisfy { $0.isFinite && abs($0) <= 1_000_000 }
            && abs(a * d - b * c) > 1e-15
    }
}

nonisolated struct GIFAnimation: Equatable, Sendable {
    let source: GIFSource
    /// The frame restored on opening. Navigation and playback stay in the editor's runtime state.
    var selectedFrameIndex = 0
    var geometry: GIFFrameGeometry? = nil
    /// Only edited frames retain full-size pixels; unedited frames still decode from the immutable source.
    var framePixels: [Int: ImportedImage] = [:]

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.source === rhs.source && lhs.selectedFrameIndex == rhs.selectedFrameIndex && lhs.geometry == rhs.geometry
            && lhs.framePixels.count == rhs.framePixels.count
            && lhs.framePixels.allSatisfy { rhs.framePixels[$0.key]?.image === $0.value.image }
    }

    func resizing(from old: LayerTransform, to new: LayerTransform, scaleX: CGFloat, scaleY: CGFloat) -> GIFAnimation {
        let map = (geometry?.unitTransform ?? .identity)
            .concatenating(old.unitToDocument)
            .concatenating(CGAffineTransform(scaleX: scaleX, y: scaleY))
            .concatenating(new.unitToDocument.inverted())
        var resized = self
        resized.geometry = GIFFrameGeometry(width: Int(new.size.width), height: Int(new.size.height),
                                           unitTransform: map, sampling: new.sampling)
        return resized
    }
}
