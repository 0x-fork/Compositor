# GIF workflow

This branch implements the first animation foundation: one GIF remains one image layer, with immutable encoded source bytes and small frame thumbnails. Later features are listed in the [submission plan](gif-pr-plan.md).

## Import and playback

Import a `.gif` with the existing image picker or drop workflow. Selecting its layer shows a centered horizontal strip below the canvas. Click a thumbnail to display that frame. Drag empty space, scroll the trackpad, or drag the bottom scrollbar to reach hidden frames. A single-frame GIF uses the same layer workflow with playback disabled.

The green Play button loops through source frame delays. Missing or zero delays default to 100 ms, and positive delays below 20 ms use the 20 ms minimum. Playback follows elapsed time; slow decoding may skip expired display intervals without changing stored delays. Pausing and resuming gives the displayed frame its full hold. Switching layers or hiding the timeline stops playback and restores the other layer's captured frame when selected again. Source loop metadata stays embedded; the editor previews continuously.

## Editing scope

The displayed frame supplies pixels to ordinary painting, selections, filters, and color commands. Editing pauses playback and retains an immutable replacement for that frame. Other frames keep their original pixels. Frames share one logical raster rectangle: operations that grow or trim pixels are mapped back onto that grid. Layer placement, opacity, effects, clipping, and the shared layer mask apply across the animation. Frame navigation changes the preview without adding undo entries; pixel and mask edits use existing undo/redo transactions.

The timeline mask button adds a frame mask from the canvas selection, or a white mask if no selection exists. Clicking it again switches between frame pixels and that frame's mask. The eye enables or disables the frame mask in both the canvas and exports. Enabled frame and shared masks multiply independently; disabled masks remain attached and editable. A frame without a mask returns painting to pixels when navigating from another frame's mask.

GIF pixels and frame masks stay 8-bit. High-precision still layers retain upstream's 16-bit/HDR workflow in the same document. Layer depth conversion is unavailable on animation layers. Still PNG/JPEG exports use the displayed frame and enabled masks. Animated export is planned separately.

## Saving and limits

Saving a `.comp` embeds the original GIF, the selected raw-frame PNG, edited frame PNGs, and frame masks. Playback reopens paused and undo history starts empty, even after the imported file is deleted or the package is moved. Crop and Canvas Size keep animation sources; Image Size resamples every frame and mask, including rotated and nonuniformly scaled layers.

Each GIF is limited to 4,096 frames and 512 MiB of encoded source. All animation layers share about 16 megapixels of thumbnails and a source-byte allowance of four times `DocumentLimits.documentPixelBudget`. Admission counts each layer, including duplicates, to match save/reopen budgets. Source images meet the ordinary side and surface limits. Selected-frame images and edited pixels count toward the document raster budget; frame masks share the mask budget. Undo accounting includes retained sources, thumbnails, and edited assets with identity deduplication. Full-size frames decode on demand.

New saves use provisional format 27. Upstream versions 1–14 remain readable. The earlier private fork's animation formats are intentionally rejected by this partial foundation, as described in [format compatibility](project-format.md#submission-format-compatibility). Keep their original packages and use the complete fork for those projects.

## Code organization

`Compositor/Document/` owns animation state, selected-frame tool input, history integration, and the playback scheduler. `Compositor/IO/` owns immutable-byte decoding, import admission, project validation, storage, and resizing. `Compositor/UI/` contains the timeline and its native scroll bridge. `Compositor/Rendering/` uses the displayed frame without replacing the editor's existing composition paths. Feature suites under `CompositorTests/` cover these behaviors through the same importer used by the app.
