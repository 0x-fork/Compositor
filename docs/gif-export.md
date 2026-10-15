# Exporting GIFs

Choose **File › Export As…**, then **GIF**.

To preview the composition while editing, click the text button immediately beside Play to switch from the layer’s name to **All**, then press Play. The editor also holds shorter GIFs on their final frames through the longest duration. Editor speed affects only the preview; export has its own Speed control and GIF timing quantization.

1. Choose the **Timeline** to animate. **All** is selected by default and animates every visible GIF layer together. Each starts at its first frame; the export lasts as long as the longest timeline, and shorter GIFs hold their last frame. Choose an individual timeline to animate only that GIF. Hidden layers and layers inside hidden folders are excluded. With no visible GIF timeline, export writes a single-frame GIF of the canvas.
2. Set the output **Size**. Width and height keep the canvas's proportions. This scales the export without changing the project.
3. **All** uses each GIF’s saved timeline delays. To change those delays, use the editor’s timeline controls before opening Export As. For an individual timeline, choose **Frame delay** to use individual timing, or **Same for all** to enter one delay in milliseconds. **Edit…** lets you change individual frame delays for that export; **Reset All** restores the imported values. The frame-delay editor opens as a popover; **Done** or dismissing it finishes pending values.
4. Adjust **Speed** from 0.25× to 4×. The center is 1.0×; click the multiplier to reset it. The **Frames** row shows the resulting loop duration.
5. Choose **Forever** or **Once** for looping. Forever is the default. The animation starts with the timeline's first frame, including after reordering.
6. Leave **Keep transparent areas** on, or turn it off and choose a **Background** color.
7. Check the animated preview, then click **Export…** and save the `.gif` file. The preview shows the encoded colors, transparency, and timing; its green button pauses and resumes playback. Fit and zoom work as with other export formats.

Individual timeline playback and the encoded GIF preview use an elapsed-time clock. Decoding a frame does not add another delay to every subsequent frame. If decoding falls behind, the preview skips expired display intervals to catch up; Once ends on the final frame. Pause/resume starts with the displayed frame's full delay. Saved delays and encoded output frames retain their existing values.

## What the file contains

With **All**, the visible GIF layers share an elapsed-time clock while keeping their own frame order and saved delays. An output frame is rendered when any participating GIF changes frames. Each layer uses the pixels and attached frame mask belonging to its frame at that time, together with its shared layer mask, placement, effects, and clipping. Shorter GIFs stay visible on their final frame until the longest timeline ends. **Forever** repeats this complete composition from the beginning; **Once** plays it once.

Export As applies only enabled layer and frame masks, matching the canvas and the separate Export PNG and Export JPEG commands. Disable a mask with its eye button or Enable/Disable Mask command to leave it out of the preview and saved file without deleting it. Export leaves mask pixels, enabled state, placement, linking, frame selection, and undo history unchanged. The same mask policy applies to still formats chosen in Export As.

Choosing an individual timeline retains the same full-canvas composition but advances only that GIF. Other GIF layers remain on the frames displayed when Export As opened.

Duplicated frames, deleted frames, and reordered frames follow the current timeline. At the default export settings, each surviving frame keeps its saved timeline delay, so duplication lengthens the loop and deletion shortens it.

## Delay and speed

Compositor reads each frame's delay from the original GIF metadata, preferring the unclamped delay when available. Missing or zero delays use 100 ms; imported delays shorter than 20 ms use 20 ms. The **Delay** row shows the original delay or range, and **Edit…** lists each frame's original delay beside its editable value. A duplicated frame can have its own export delay, independently of its original.

In **All**, Speed applies to every participating timeline. The longest duration is calculated from the saved delays after speed adjustment and GIF timing quantization. No source repeats within the export; a shorter timeline holds its last frame. Individual export delay overrides are available only when choosing one timeline.

**Frame delay** preserves different pauses unless you edit them. Export starts with the chosen timeline’s saved delay mode and values. **Same for all** uses one entered delay for every frame. **Speed** divides these values by the multiplier: an 80 ms delay becomes 40 ms at 2×, or 160 ms at 0.5×. Speed applies to either delay mode. Switching modes retains individual overrides; changing the chosen timeline starts with that timeline's saved settings.

For a newly imported GIF, Same for all starts with the most common original frame delay. If multiple delays tie for most common, it uses the average across every frame. This suggested value is retained with the layer; switching modes or editing the timeline does not recalculate it, and a value you enter is preserved.

Delay fields confirm typed values on Return or when you leave the field. Empty, nonnumeric, nonfinite, and out-of-range input restores the previous delay without a warning. The same behavior applies in the timeline controls and shared frame-delay editor; **Done** confirms any unfinished fields.

GIF stores delays in hundredths of a second. In **All**, overlapping frame starts can create gaps shorter than 20 ms. Those nearby changes are combined into output frames with delays of at least 20 ms without extending the longest timeline’s duration. A change may appear up to 10 ms earlier or later, and the dialog indicates the minimum delay. Final frames are retained. Long holds are split when necessary to stay within GIF’s maximum frame delay.

Export rounds adjusted delays to the nearest 10 ms and uses a 20 ms minimum, matching imported playback. The dialog indicates when speed reaches that minimum. Delays must be 20–655,350 ms before scaling; adjusted delays above 655,350 ms produce an error and disable export. Timing controls are disabled for a single-frame GIF.

Changes made in Export As affect this export and its preview. Timeline delay edits are saved with the GIF layer, while export overrides are temporary. They do not change the original GIF, the timeline's source delays, or saved project data. The editor timeline's speed slider remains a separate preview setting.

Export captures the document when the dialog opens and does not change frame selection, pixels, masks, or undo history. It works after reopening a `.comp` project even when the original imported GIF is unavailable. PNG, JPEG, and PDF continue to export the displayed canvas as one still image.

## GIF limits

GIF uses at most 256 palette colors per frame. Color reduction is handled by Apple's ImageIO encoder; palette size and dithering controls are not exposed in this version. GIF supports fully transparent or opaque pixels. With transparency enabled, coverage below 50% becomes transparent; the remaining pixels become opaque with their original color. Soft mask edges and translucent shadows can therefore look harder than on the canvas. Turn transparency off to blend those areas onto the chosen background color.

Export supports at most 4,096 frames, the ordinary 30,000-pixel side limit, 200 megapixels summed across all output frames, and 512 MiB of encoded data. The total pixel limit bounds the sequence retained by the encoder. Reduce output size or remove frames when an animation exceeds it. The dialog shows encoding progress and allows cancellation. Saving uses the existing coordinated, atomic export writer.

## Implementation

`GIFExportTiming` validates, scales, and quantizes the chosen delays, using stable frame identities for individual overrides. `GIFExportSchedule` merges the participating timelines’ frame starts on an integer 10 ms clock, ends at the longest timeline, and bounds output frame count before rendering. `GIFExporter` decodes each changed layer frame lazily, reuses unchanged frames, substitutes their pixels and frame identities into an immutable render snapshot, and uses `ImageExporter` for the existing canvas composition and resizing. The encoded preview uses the output delays. New `.comp` saves use version 28 for the complete GIF workflow; export overrides add no saved fields.

ImageIO writes each frame with its own palette and a full canvas, including transparent frames. Disabling its global palette optimization avoids invalid empty delta rectangles on very small canvases. Export tests cover transparent moving frames and empty frames to prevent trails or invalid output. Timing and loop metadata use Apple's [GIF image properties](https://developer.apple.com/documentation/imageio/gif-image-properties).
