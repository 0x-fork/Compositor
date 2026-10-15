import CoreGraphics

extension EditorSession {
    /// A tool's input is the raw selected frame, without either of its masks baked in.
    func pixelEditingLayer(for layer: ImageLayer) -> ImageLayer {
        guard layer.gifAnimation != nil else { return layer }
        var editing = layer
        editing.asset = displayedAsset(for: layer)
        editing.gifAnimation = currentGIFAnimation(for: layer)
        return editing
    }

    func pixelEditTargetMatches(_ current: ImageLayer, original: ImageLayer) -> Bool {
        current.transform == original.transform && displayedAsset(for: current)?.image === original.asset?.image
            && (original.gifAnimation == nil || (current.gifAnimation?.source === original.gifAnimation?.source
                && selectedGIFFrameIndex(for: current.id) == original.gifAnimation?.selectedFrameIndex))
    }

    func pixelEditTransformMatches(_ current: ImageLayer, original: ImageLayer) -> Bool {
        pixelEditTransformMatches(current, transform: original.transform)
    }

    func pixelEditTransformMatches(_ current: ImageLayer, transform: LayerTransform) -> Bool {
        current.transform == transform
    }

    /// GIF frames share one logical rectangle. Cropped or grown tool results are placed back on that grid.
    func layerByEditingPixels(_ layer: ImageLayer, asset: ImportedImage, transform: LayerTransform,
                              mask: LayerMask?) throws -> ImageLayer {
        guard var animation = layer.gifAnimation, let index = selectedGIFFrameIndex(for: layer.id) else {
            return ImageLayer(id: layer.id, asset: asset, name: layer.name, isVisible: layer.isVisible,
                transform: transform, parentID: layer.parentID, isGroup: false, opacity: layer.opacity,
                blendMode: layer.blendMode, mask: mask, maskSourceID: layer.maskSourceID, effects: layer.effects)
        }
        let width = animation.geometry?.width ?? animation.source.width
        let height = animation.geometry?.height ?? animation.source.height
        let used = (document?.layers ?? []).reduce(0) { total, candidate in
            total + (candidate.asset.map { $0.image.width * $0.image.height } ?? 0)
                + (candidate.gifAnimation?.framePixels.filter { candidate.id != layer.id || $0.key != index }
                    .values.reduce(0) { $0 + $1.image.width * $1.image.height } ?? 0)
        }
        guard width * height <= DocumentLimits.documentPixelBudget - used else { throw ProjectError.tooLarge }
        let pixels: ImportedImage
        if transform == layer.transform, asset.image.width == width, asset.image.height == height {
            // GIF frame overrides use the animation's 8-bit grid even when pasted from a deep still layer.
            pixels = asset.deep == nil ? asset : ImportedImage(image: asset.image, thumbnail: asset.thumbnail,
                                                              name: asset.name, raster: asset.raster)
        } else {
            let context = try BrushRaster.context(width: width, height: height, mask: false)
            let map = transform.unitToDocument.concatenating(layer.transform.unitToDocument.inverted())
                .concatenating(CGAffineTransform(scaleX: CGFloat(width), y: CGFloat(height)))
            context.concatenate(map)
            BrushRaster.draw(asset.image, in: CGRect(x: 0, y: 0, width: 1, height: 1), mask: false, context: context)
            guard let image = context.makeImage() else { throw ExportError.render }
            pixels = ImportedImage(image: image, thumbnail: try PixelAdjust.thumbnail(of: image), name: layer.name)
        }
        animation.framePixels[index] = pixels
        var edited = layer
        edited.gifAnimation = animation
        return edited
    }
}
