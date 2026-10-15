# Writing Compositor projects (for AI agents and scripts)

A Compositor project (`.comp`) is a folder of PNG layer images plus a `manifest.json`. Anything that can write files can build or edit one, and Compositor updates the open canvas as the files change. No plugin or API is involved.

## Try it

1. Open a project in Compositor 1.3 or later (save a new canvas somewhere, e.g. `~/Desktop/demo.comp`), and keep it open.
2. Ask an AI agent that can edit files on your Mac (Claude Code, Codex and the like):

   > Read docs/writing-comp-files.md in github.com/robbietilton/Compositor, then design a moody night scene in ~/Desktop/demo.comp. Work in steps, one or two layers at a time.

3. Watch the canvas. Each time the agent writes the project, Compositor reloads it, usually within half a second.

What you get are ordinary layers: select them, change their opacity or blend mode, paint on their masks, save.

## The package

```
Example.comp/
├── manifest.json
└── images/
    ├── 6F1D3C2A-0B7E-4E8A-9C4D-2A1B3C4D5E6F.png        a layer's pixels
    └── 6F1D3C2A-0B7E-4E8A-9C4D-2A1B3C4D5E6F.mask.png   its mask (optional)
```

A minimal manifest with one full-canvas image layer:

```json
{
  "format": "com.compositor.project",
  "version": 11,
  "colorSpace": "sRGB",
  "documentID": "0C5E7A91-3B2D-4F6A-8E1C-9D0B7A6F5E4D",
  "width": 1920,
  "height": 1080,
  "resolution": 72,
  "activeLayerID": "6F1D3C2A-0B7E-4E8A-9C4D-2A1B3C4D5E6F",
  "layers": [
    {
      "id": "6F1D3C2A-0B7E-4E8A-9C4D-2A1B3C4D5E6F",
      "name": "Background",
      "imageFile": "6F1D3C2A-0B7E-4E8A-9C4D-2A1B3C4D5E6F.png",
      "isVisible": true,
      "isGroup": false,
      "opacity": 1,
      "blendMode": "Normal",
      "transform": {
        "origin": [0, 0],
        "size": [1920, 1080],
        "rotation": 0,
        "flipX": false,
        "flipY": false,
        "sampling": "High quality"
      }
    }
  ]
}
```

- `layers` runs **bottom to top**: the last layer draws on top.
- Keep `documentID` as it is when editing an existing project.
- `transform` places the layer in document pixels: `origin` is its top-left corner, `size` its width and height, `rotation` is in degrees, clockwise. The image is stretched to `size`, so a layer can be smaller than the canvas (a cut-out placed with `origin`) or scaled.
- `sampling` is `"High quality"`, `"Smooth"` or `"Nearest"`.
- `opacity` runs from 0 to 1.

## Rules that matter

Break one of these and Compositor refuses the whole file **without any message**: the open canvas just stays as it was. If nothing updates, check these first.

- **Image files are named after their layer.** A layer with `"id": "6F1D…"` must use `"imageFile": "6F1D….png"`, and a mask `"maskFile": "6F1D….mask.png"`, with the ID in uppercase as written in the manifest. One ID per layer, unique in the project.
- **Images are 8-bit PNGs** in `images/`. Layer images are RGBA; masks are 8-bit grayscale (white shows the layer, black hides it).
- **Blend modes are spelled exactly** as Compositor names them: `Normal`, `Darken`, `Multiply`, `Color Burn`, `Linear Burn`, `Lighten`, `Screen`, `Color Dodge`, `Linear Dodge (Add)`, `Overlay`, `Soft Light`, `Hard Light`, `Vivid Light`, `Linear Light`, `Pin Light`, `Hard Mix`, `Difference`, `Exclusion`, `Subtract`, `Divide`, `Hue`, `Saturation`, `Color`, `Luminosity`.
- **Every layer the manifest names has its image in place**, and the manifest is valid JSON.

## Writing safely while the project is open

Compositor reads the project as soon as it changes, so never leave it half written:

1. Write any new or changed PNGs into `images/` first.
2. Then write the manifest to a temporary file inside the package (for example `.manifest.json.tmp`) and rename it over `manifest.json`. A rename is atomic: Compositor sees either the old manifest or the new one, never part of one.

To change an existing layer, keep its `id` and overwrite its PNG, then rewrite the manifest. The layer updates in place, in the same spot in the stack.

Remove images you no longer reference once the manifest no longer lists them.

A project Compositor saved also has a `QuickLook` folder (`Preview.jpg`), which Finder shows as its Space-bar preview. When you change a project, delete that folder, so Finder doesn't preview an out-of-date picture; Compositor writes it again the next time it saves.

## What the open app does

- It reloads about a third of a second after writes stop. Several writes in quick succession arrive as one update, so pause briefly between steps if a viewer should see each one.
- A reload keeps the zoom, scroll and selection, but clears undo, as reopening a file does.
- If the person has unsaved changes of their own, Compositor asks them to revert to your version or keep theirs, and never replaces their work silently.
- A write that fails to load is ignored until the next change, so a mistake you then fix will still show up.
- Changes are noticed from the manifest's contents and from each image's name and size, not from when files were written. Rewriting a PNG with different pixels changes its size in practice. If you replace an image with one of exactly the same byte size, also make a change to the manifest, such as renaming the layer; writing identical manifest bytes back isn't enough.

## Masks

Add a mask to any layer with `"maskFile": "<id>.mask.png"` and `"maskEnabled": true`. The mask covers the layer's own pixels, so it has the same pixel size as the layer's image. Soft grays give soft edges.

## Adjustment layers

An adjustment layer has an `adjustment` object and no `imageFile`, and it affects everything below it. Every kind carries identity `levels` and `curves` blocks, plus its own settings. A warming Curves layer:

```json
{
  "id": "A1B2C3D4-E5F6-4A7B-8C9D-0E1F2A3B4C5D",
  "name": "Warm Grade",
  "isVisible": true,
  "isGroup": false,
  "opacity": 1,
  "blendMode": "Normal",
  "transform": { "origin": [0, 0], "size": [1920, 1080], "rotation": 0, "flipX": false, "flipY": false, "sampling": "High quality" },
  "adjustment": {
    "kind": "Curves",
    "hue": 0, "saturation": 0, "lightness": 0, "colorize": false,
    "levels": { "channel": "RGB", "ranges": [
      { "black": 0, "gamma": 1, "white": 255, "outputBlack": 0, "outputWhite": 255 },
      { "black": 0, "gamma": 1, "white": 255, "outputBlack": 0, "outputWhite": 255 },
      { "black": 0, "gamma": 1, "white": 255, "outputBlack": 0, "outputWhite": 255 },
      { "black": 0, "gamma": 1, "white": 255, "outputBlack": 0, "outputWhite": 255 } ] },
    "curves": { "channel": "RGB", "channels": [
      [ { "x": 0, "y": 0 }, { "x": 255, "y": 255 } ],
      [ { "x": 0, "y": 0 }, { "x": 120, "y": 147 }, { "x": 255, "y": 255 } ],
      [ { "x": 0, "y": 0 }, { "x": 100, "y": 114 }, { "x": 255, "y": 255 } ],
      [ { "x": 0, "y": 0 }, { "x": 115, "y": 97 }, { "x": 255, "y": 238 } ] ] }
  }
}
```

- `ranges` and `channels` run RGB, then red, green, blue. Curve points run from x 0 to x 255, in increasing x.
- `kind` is one of `Hue/Saturation`, `Levels`, `Curves`, `Exposure`, `Gradient Map`, `Grain`, `Invert`, `Black & White`, `Color Balance`, `Gaussian Blur`, `Motion Blur`, `Add Noise`.
- For Hue/Saturation, set `hue`, `saturation` and `lightness` on the adjustment itself. Color Balance takes a `colorBalanceSettings` object (`shadowCyanRed`, `shadowMagentaGreen`, `shadowYellowBlue`, and the same for `mid` and `highlight`, each −100 to 100, plus `preserveLuminosity`).
- For the other kinds, the easiest way to get the exact shape is to add one in Compositor, save, and copy it from that project's manifest.

## More

- Folders, text layers, layer effects and everything else the format holds: [project-format.md](project-format.md).
- Limits: canvases up to 30,000 pixels on a side; layers and masks count toward a memory budget that scales with the Mac.


## GIF layers

Use version 28 for new projects containing GIF timelines, edited pixels, frame order, and saved delays. Upstream versions 1–14 remain readable for still projects and cannot contain `gif` metadata. Older app builds reject version 28.

Keep the usual `imageFile` entry and add a `gif` object to that image layer:

```json
"imageFile": "6F1D3C2A-0B7E-4E8A-9C4D-2A1B3C4D5E6F.png",
"gif": {
  "sourceFile": "6F1D3C2A-0B7E-4E8A-9C4D-2A1B3C4D5E6F.gif",
  "selectedFrameIndex": 0,
  "frameMasks": [
    {
      "index": 0,
      "maskFile": "6F1D3C2A-0B7E-4E8A-9C4D-2A1B3C4D5E6F.frame-0.mask.png",
      "isEnabled": true
    }
  ]
}
```

Copy the complete original GIF into `images/<id>.gif`, and write the selected frame as `images/<id>.png`. The PNG must contain that frame's unmasked pixels and have the same dimensions as the GIF's composed frames. Frame indices start at zero. Every index must identify a surviving editable frame; list each mask index only once. Groups, adjustment layers, editable text, and editable shapes cannot also be GIF layers.

Each frame mask uses an 8-bit grayscale PNG named exactly `<id>.frame-<index>.mask.png`. White reveals, black hides, and gray gives partial coverage. Omit a frame from `frameMasks` when it has no mask; omitting the entire array means no frame masks. `isEnabled` and `isLinked` default to true. Optional `placement` uses the same transform format as a shared layer mask. Keep `maskFile` on the layer for its shared mask; never bake either mask into the selected-frame PNG or merge the masks together.

When editing an existing GIF layer, preserve any `geometry` object. Image Size uses it to apply a saved rasterization to every frame; the selected PNG then has its `width` and `height`. Refer to [project-format.md](project-format.md#gif-layers-version-28) for the affine coordinates and validation rules. No thumbnail files are needed: the app rebuilds them from the embedded GIF or edited frame PNGs and starts playback paused.

For edited frame pixels, add an optional `framePixels` array inside `gif`, for example `[{ "index": 1, "imageFile": "<id>.frame-1.png" }]`. Save each edited full-size raw frame as that canonical PNG filename, with transparency and without masks baked in. Its dimensions must match the GIF's composed frame grid or saved `geometry`. List each index only once and only if it identifies a surviving editable frame. Omitted indices use the original source pixels; omitting `framePixels` means no pixel edits. Also update the selected-frame `<id>.png` to reflect its edited pixels. Edited PNGs and the selected-frame PNG share the document image-pixel budget. See [project-format.md](project-format.md#edited-gif-frame-pixels-version-28).

Save all referenced assets before replacing the manifest, as for still layers. GIFs are limited to 4,096 frames and 512 MiB each, with combined source-byte and thumbnail budgets. Frame masks share the document's mask-pixel budget. A source file missing from the package, a malformed GIF, or an invalid frame index prevents the whole project from loading.


Use `deletedFrameIndices`, `frameOrder`, and `timing` to preserve frame management and saved delays. Keep stable identities when moving frames; inserted identities refer to their original `sourceIndex`. Masks, pixel overrides, delay overrides, and `selectedFrameIndex` refer to those stable identities, not positions in the strip. Remove records belonging to deleted frames. Leave at least one frame, include every undeleted original identity in an explicit order, and preserve all existing timing values. See [frame order and timing](project-format.md#frame-order-and-timing-version-28) for a four-source-frame example, defaults, identity ranges, and validation.

New saves use provisional format 28; upstream projects from versions 1–14 and local foundation version 27 remain readable. Version 27 cannot contain frame order, deletions, or timing overrides. Private animation-fork versions 15–26 and GIF metadata stored under versions 1–14 are rejected. Do not change an old fork manifest’s version to make it load. See [format compatibility](project-format.md#submission-format-compatibility).
