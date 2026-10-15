# GIF onion skin preview

Onion skin shows the previous or next frame as a translucent ghost over the frame you are editing. It helps compare movement or align a frame mask with a neighboring frame.

## Controls

1. Select a GIF layer and pause playback.
2. Click the stacked-layers icon beside the mask eye icon to turn onion skin on. It highlights while enabled; delay controls follow it, and playback speed sits at the right edge of the header.
3. Click the adjacent arrow to open **Onion Skin** settings. Choose **Previous frame** (the default) or **Next frame** from **Preview**. Drag **Opacity** to adjust the ghost from 5% to 100%; it starts at 25%.
4. Select a frame thumbnail. Its neighbor in the chosen direction supplies the ghost. Previous has no ghost at the first frame, and Next has no ghost at the last frame. The preview does not wrap around the loop.
5. Click the icon again to turn the preview off.

The controls are disabled during playback and for a single-frame GIF. Playback temporarily hides the ghost; pausing restores it if onion skin is still enabled. Only the selected GIF shows a ghost. The setting follows the editor session across layer selection and resets when a project is opened.

Opacity uses the same standard continuous slider as layer opacity, allowing fine adjustments without snapping to 5% steps and retaining the system's translucent knob effect.

## Editing and rendering

The ghost follows the timeline's current order, including duplicated, deleted, and reordered frames. It includes that frame's edited pixels and enabled frame mask, together with the GIF's shared mask, layer effects, transform, and opacity. Layers above the GIF cover the ghost. For a GIF in a clipping stack, the ghost appears above that stack and uses the existing clipping source's coverage. Folder masks also apply.

The ghost draws over the current frame so it is visible even with an opaque GIF background. Editing continues to target the current frame or its mask. The ghost is a canvas preview, without a layer row or selection target. Viewing a mask alone hides it.

Onion skin changes do not modify pixels, selections, undo history, or saved project data. Still-image export, animated GIF export, merged pixels, and color sampling use the document's actual appearance. Full-size source pixels are decoded asynchronously for just one neighboring frame; an obsolete decode cannot replace the preview after switching layers, frames, or direction. Effects use a separate preview cache.

Colored tints, multiple neighboring frames, and loop wrapping remain future additions.
