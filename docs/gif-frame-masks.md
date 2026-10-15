# GIF frame masks

A frame mask hides or reveals parts of one GIF frame. It stays with that frame when frames are reordered, and combines with any shared layer mask. Painting white reveals pixels; painting black hides them.

## Create and edit a mask

1. Select the GIF layer and click its frame thumbnail.
2. Optionally make a lasso or marquee selection around the area to keep.
3. Click the timeline's mask button. A selection becomes the visible area of the new mask; without a selection, the mask reveals the whole frame.
4. While the header says **Editing mask**, paint or fill the mask. The selected frame stays visible throughout a brush stroke. Click the mask button again to edit the frame's pixels.

The eye button enables or disables the current frame's mask in the canvas and exports. Right-click a thumbnail to enable, disable, or delete that frame's mask. Disabled masks remain attached and editable but do not affect the export preview or saved file.

Turn on [onion skin preview](gif-onion-skin.md) to compare the current mask with the previous or next frame's appearance. The ghost is a canvas reference; painting still changes the selected frame's mask.

## Work with several frames

1. Click a frame, then Command-click other thumbnails to add them to the selection. Command-click again to remove one. To select many frames, hold Command and drag across thumbnails with the left mouse button or macOS three-finger dragging. Every thumbnail crossed is added; crossing it again keeps it selected. Hold near either strip edge to scroll and select newly revealed frames. Release the mouse button or Command to stop. Selected frames have blue borders, and the header shows the selected count. Playback pauses; the displayed frame stays on the canvas while multiple frames are selected.
2. Optionally make a lasso or marquee selection around the area to keep.
3. Click the timeline's mask button, or right-click a selected thumbnail and choose **Add Masks**.

Every selected frame without a mask receives one. Existing masks, including disabled masks, stay intact. The same canvas selection is mapped through the layer's shared placement and rotation; without a canvas selection, new masks reveal the whole frame. The selection is consumed only after the complete batch succeeds. Creating masks is one **Add Frame Masks** undo step, and later painting changes only the displayed frame's mask. The total mask memory budget is checked before applying the batch.

Right-click a selected thumbnail and choose **Delete Masks** to remove attached masks from the selected frames, including disabled masks. Frames without masks are skipped. This is one **Delete Frame Masks** undo step; frame pixels, delays, the shared layer mask, and the canvas selection stay intact. If the displayed frame’s mask was the paint target and is deleted, editing returns to frame pixels.

The selected group has a separate right-click menu. **Add Masks** appears when some selected frames lack masks, and **Delete Masks** when some have masks. **Delete N Frames** always appears and is grayed out when all frames are selected or frame editing is unavailable. Individual mask visibility, copy and duplication commands remain in the single-frame menu.

Choose **Delete N Frames** to remove the selected frames in one undo step. At least one frame must remain. Surviving frames retain their pixels, masks, delays, and effects. If the displayed frame is deleted, the next surviving frame is displayed, or the last survivor if there is no following frame.

Command-drag adds to the current selection without changing the displayed frame. Only the existing selection borders and count appear; there is no selection rectangle or pointer trail. Dragging without Command retains frame reordering and empty-space scrolling.

A plain click returns to one selected frame and displays it. If Command-click leaves only one selected frame, that frame is displayed. Right-clicking an unselected thumbnail operates on that frame alone. Starting playback, switching layers, or hiding the timeline clears the batch selection. Selection is temporary; the masks and deletions are saved with the project.

## Copy a mask to other frames

1. Right-click the thumbnail whose mask you want to copy and choose **Copy Mask to Frames…**. Playback pauses. The source can differ from the frame currently displayed on the canvas.
2. Check the destination thumbnails, or use **Select All**. **Clear** unchecks them. The source frame is excluded.
3. Review the replacement count. Existing destination masks will be replaced in full.
4. Click **Copy to N Frames**. **Cancel**, Escape, or clicking outside the picker closes it without copying.

Choosing destinations does not navigate the canvas or change the layer or pixel selection. Copying preserves the source mask's pixels, enabled state, placement, and linking. Copying a disabled mask produces disabled masks.

Each destination owns its mask: editing, disabling, or deleting one later does not change the others. The batch is one **Copy Frame Mask** undo step. It leaves frame pixels, delays, and the shared layer mask unchanged. If the displayed frame is a destination, its canvas result updates immediately.

Copies use the same mask shape on every destination. They do not track a moving subject or interpolate between masks. Copying respects the existing mask memory budget; a rejected batch does not partially replace masks.

Frame masks and their enabled states are saved in `.comp` projects. Enabled copies appear during editor playback and in Export As previews and saved [GIF output](gif-export.md). Disabled copies stay out of both the canvas composition and exported output.
