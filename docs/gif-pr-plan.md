# Animation submission plan

The complete implementation is preserved on `animated-gif-support`. Submission branches start from upstream and include the tests, workflow documentation, and schema changes for the feature they introduce.

## First PR: complete GIF workflow

`codex/gif-workflow` combines the former foundation, frame-editing, and timing/export PRs. It is based on upstream `365b574` (Compositor 1.5.3), with the foundation checkpoint preserved on `codex/gif-foundation`. The first submission supports import → edit → save/reopen → animated GIF export as one usable feature.

Its scope includes immutable sources, per-layer centered timelines, elapsed-time playback and preview speed, frame pixel edits and masks, duplication/deletion/reordering, Command-click and Command-drag selection with edge scrolling, batch mask/deletion commands, mask copying, onion skin, saved frame delays, combined playback, and animated GIF export with encoded preview. Geometry changes, 16-bit/HDR still coexistence, validation, cancellation, existing history/edit targeting, and source/thumbnail/raster budgets are included. Enabled masks apply consistently to editor, still, and GIF output.

The branch carries the later regression fixes relevant to this scope, including centered short-strip reordering, decode observation, elapsed-time previews, frame-edit isolation, and enabled-mask exports. New files remain in the original Document, IO, Rendering, UI, and test directories. It adds no codec dependency, release setting changes, or screenshot-scheme changes.

Gradual effects, saved effect history/interpolation captures, APNG animation, and animated WebP are excluded. They remain intact on the complete feature branch. Review commits can separate related implementation work without requiring incomplete product states to merge separately.

## Project format decision

The complete first submission writes version 28 and reads upstream versions 1–14 plus local foundation versions 27–28. Version 27 was used by the earlier review build; it supports the source, captured frame, geometry, masks, and edited pixels. Version 28 adds optional stable frame order/deletions and saved timing together. Missing values use source order, no deletions, and imported delays. New saves require 28 so the earlier foundation reader cannot silently discard these edits.

The private fork already used versions 12–26, overlapping upstream versions 12–14. Versions 15–26 and GIF metadata under versions 1–14 remain rejected. Keep private-fork packages unchanged and use the complete fork to read them. The first public PR introduces one complete GIF schema; no intermediate PR schemas need to merge.

The proposed number is subject to maintainer review. Coordinate any renumbering across the writer, accepted versions, validation gates, fixtures, and both format guides. Later PRs adding saved fields allocate new versions in merge order. Upstream's 16-bit/HDR/smoothing gates remain 12/13/14.

## Remaining PRs

| PR | Scope after the complete GIF workflow |
| --- | --- |
| 2 | Gradual opacity, rotation, position, mask movement, dissolve/morph, editable effect history, preview, and capture memory accounting |
| 3 | APNG import/export through the shared frame workflow |
| 4 | Animated WebP import/export, codec dependency, and third-party notices |

Each merge state must build and pass its relevant suites. Do not discard later regression fixes when reconstructing a submission.

## Verification

The final app build passes. The complete unit run exercised 788 tests: 786 passed. All GIF workflow, timing, export, compatibility, history, precision, and geometry tests passed. The two existing window-position failures (`ColorPickerTests.pickerReopensWhereItWasLastLeft` and `FloatingPanelTests.dockedPlacementLeavesTheSavedFilterPosition`) match the failures reproduced in untouched upstream during the foundation review. The external-file notification suite passed in the final full run and in a separate six-test recheck. The full run is therefore not reported as completely green.

Live verification used an isolated app and a disposable four-frame GIF. Import showed the centered strip and compact controls; duplication produced a fifth frame; Command-click kept the displayed frame while adding selection; a pixel inversion affected only the copy; mask disabling updated the tooltip and state; a 450 ms frame delay committed through the shared editor. Saving wrote version 28 with stable order, edited pixels, mask enabled state, and timing. Reopening restored the selected copy and disabled mask with playback paused. Playback disabled editing and temporarily hid onion skin. Export As produced a five-frame GIF; independent ImageIO decoding confirmed 320 × 240 dimensions, delays `[0.3, 0.3, 0.45, 0.3, 0.3]`, Once looping, and inverted pixels on the copied frame.

A new onion-skin regression reproduced linked-mask displacement during a pending layer transform; resolving mask placement before applying the draft transform fixed it. Both linked and unlinked cases pass in the final run.

The automated native selection/reorder suites cover centered and scrolling strips, drag hit-testing, edge scrolling, release/cancellation, and stable identities. Physical three-finger dragging remains a manual hardware check. The combined review build is left open separately from the user's original app and foundation review build.

Markdown fences, local links/anchors, scheme XML, and Git whitespace checks pass. Local builds use optimized Debug settings, ad hoc signing, and a command-line hardened-runtime override; repository build/signing settings and dependencies remain unchanged. No PR has been published by this preparation.
