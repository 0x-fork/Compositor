# GIF workflow

This branch implements a complete GIF workflow: import, preview, edit, save/reopen, and animated export. A GIF remains one image layer with immutable encoded source bytes and small frame thumbnails. Gradual changes and additional animation formats are separate features in the [submission plan](gif-pr-plan.md).

## Import and playback

Import a `.gif` with the existing image picker or drop workflow. Selecting its layer shows a horizontal frame strip below the canvas. Short strips stay centered. Click a thumbnail to display that frame. Drag empty space, scroll the trackpad, or drag the bottom scrollbar to reach hidden frames. A single-frame GIF uses the same layer workflow with playback disabled.

The green Play button loops through the layer's saved delays. Missing or zero source delays default to 100 ms, and positive delays below 20 ms use the 20 ms minimum. Playback follows elapsed time; slow decoding may skip expired display intervals without changing stored delays. Pausing and resuming gives the displayed frame its full hold. Source loop metadata stays embedded; the editor previews continuously.

Click the layer name beside Play to switch between that timeline and **All**. All starts visible GIF layers together, runs through the longest timeline, and holds shorter timelines on their final frame. Switching layers or hiding the timeline stops playback. The speed slider runs from 0.25× to 4×, with 1× at the center. These preview settings do not change the saved project or export timing.

## Frame editing and timing

The displayed frame supplies pixels to ordinary painting, selections, filters, and color commands. Editing pauses playback and retains an immutable replacement for that frame. Other frames keep their original pixels. Frames share one logical raster rectangle: operations that grow or trim pixels are mapped back onto that grid. Layer placement, opacity, effects, clipping, and the shared layer mask apply across the animation. Frame navigation changes the preview without adding undo entries; edits use existing undo/redo transactions.

Right-click a thumbnail to duplicate or delete a frame. Drag a thumbnail to reorder it; its pixels, masks, and delays follow its stable identity. At least one frame must remain. Command-click toggles selection; hold Command and drag across thumbnails to add every frame crossed, with automatic scrolling at the edges. No selection rectangle or pointer trail is drawn. The displayed frame stays on the canvas while several frames are selected. A plain click returns to one displayed frame. Right-click a selected frame for batch mask or deletion commands.

Choose **Frame delay** and **Edit…** to set individual delays, or **Same for all** for a uniform delay. Typed values confirm on Return or when leaving the field; invalid values restore the previous delay. Closing the frame-delay popover confirms its pending values as one undoable edit. Delays are saved with the layer; preview speed is separate. A newly imported GIF suggests its most common delay for uniform mode, or its mean when frequencies tie. See [timing and export](gif-export.md).

The timeline mask button adds a frame mask from the canvas selection, or a white mask if no selection exists. Clicking it again switches between frame pixels and that frame's mask. The eye enables or disables the mask in both the canvas and exports. Enabled frame and shared masks multiply independently; disabled masks remain attached and editable. A frame without a mask returns painting to pixels when navigating from another frame's mask. The context menu also copies a mask to chosen frames; batches preserve existing masks when adding new ones. See [frame masks](gif-frame-masks.md).

[Onion skin](gif-onion-skin.md) shows the previous or next frame as a translucent canvas reference while paused. It follows the current order, edited pixels, enabled masks, and shared layer appearance. It does not change pixels, edit targeting, export, or saved data.

GIF pixels and frame masks stay 8-bit. High-precision still layers retain upstream's 16-bit/HDR workflow in the same document. Layer depth conversion is unavailable on animation layers.

## Export

Choose **File › Export As… › GIF** to export the animation. **All** animates visible timelines together; choosing one advances only that timeline while other layers keep their captured frames. Set output size, export speed, looping, and transparency, then inspect the encoded preview before saving. Individual timelines also offer temporary delay overrides. Export does not change document pixels, masks, timing, frame selection, or history.

GIF stores up to 256 colors per frame and uses 10 ms timing ticks with a 20 ms minimum. It supports fully transparent or opaque pixels; soft coverage uses a 50% threshold. Turn transparency off to composite soft edges onto a chosen background. Animated export is limited to 4,096 frames, 200 megapixels across all output frames, and 512 MiB of encoded data. See [GIF export](gif-export.md) for combined timeline timing and limits.

PNG/JPEG and other still exports render the displayed frame. Every export applies only enabled masks, matching the canvas.

## Saving and limits

Saving a `.comp` embeds the original GIF, selected raw-frame PNG, edited frame PNGs, frame masks, frame order/deletions, and saved delays. Playback reopens paused and undo history starts empty, even after the imported file is deleted or the package is moved. Crop and Canvas Size keep animation sources; Image Size resamples every frame and mask, including rotated and nonuniformly scaled layers.

Each GIF is limited to 4,096 frames and 512 MiB of encoded source. All animation layers share about 16 megapixels of thumbnails and a source-byte allowance of four times `DocumentLimits.documentPixelBudget`. Admission counts each layer, including duplicates, to match save/reopen budgets. Source images meet the ordinary side and surface limits. Selected-frame images and edited pixels count toward the document raster budget; frame masks share the mask budget. Undo accounting includes retained sources, thumbnails, and edited assets with identity deduplication. Full-size frames decode on demand.

New saves use provisional format 28. Upstream versions 1–14 and local foundation version 27 remain readable. The earlier private fork's animation formats are rejected, as described in [format compatibility](project-format.md#submission-format-compatibility). Keep their original packages and use the complete fork for those projects.

## Code organization

`Compositor/Document/` owns animation state, frame operations, timing, selected-frame tool input, history integration, and playback scheduling. `Compositor/IO/` owns decoding, import admission, project validation/storage, resizing, export scheduling, and GIF encoding. `Compositor/UI/` contains compact timeline controls, shared delay editors, export UI, and native selection/reorder bridges. `Compositor/Rendering/` adds onion skin to the existing canvas paths. Feature suites under `CompositorTests/` use the same importer and exporter as the app.
