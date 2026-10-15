# Animation submission plan

The complete implementation is preserved on `animated-gif-support`. Submission branches start from upstream and carry only the features they introduce. Each branch includes its own tests, workflow documentation, and schema changes.

## First PR: editable GIF layer foundation

`codex/gif-foundation` is based on upstream `365b574` (Compositor 1.5.3). It contains GIF import, per-layer timelines, elapsed-time preview playback, immutable sources, displayed-frame pixel editing, frame masks, save/reopen, geometry changes, validation, and history/source budgets. Basic pixel and mask support belongs here because existing tools must keep edits through frame changes and reopening. Layer selection, edit targeting, history transactions, and the ordinary still-image workflow retain their existing APIs.

The extraction starts from the first six animation commits (`f3b6a42` through `11bba58`) and incorporates the relevant tested fixes from the integration branch. Upstream's current precision, Camera Raw, shape, and canvas behavior are retained. The private fork's WebP dependency, animation export controls, advanced frame operations, gradual effects, and incidental screenshot-scheme edits are excluded.

## Project format decision

The proposed first submission writes version 27 and reads upstream versions 1–14 plus 27. The private fork already used versions 12–26, overlapping upstream versions 12–14. Reusing those numbers for a partial implementation could silently lose saved animation fields. This foundation rejects versions 15–26 and rejects `gif` metadata in versions 1–14. It does not rename or migrate private-fork packages; the complete fork remains their reader.

Version 27 introduces the source filename, selected frame, optional geometry, optional frame masks, and optional edited frame pixels together. Missing arrays default to empty, mask enabled/link flags default to true, and missing geometry means the source canvas. Original upstream 16-bit, HDR, and smoothing gates stay at versions 12, 13, and 14. Tests cover mixed documents, upstream input versions, missing optional animation fields, and rejection without replacing an existing package.

The version is provisional for review. If upstream requests another number before merge, update the writer, accepted versions, GIF gates, fixtures, and both format guides together. Later PRs that add saved fields must allocate new versions in merge order. Never renumber a user's manifest by hand.

## Remaining PRs

| PR | Scope after the foundation |
| --- | --- |
| 2 | Frame duplication/deletion/reordering, batch selection and masks, mask copying, and onion skin |
| 3 | Saved frame-delay editing, animated GIF export, encoded preview, and combined timeline playback/export |
| 4 | Gradual opacity, rotation, position, mask movement, dissolve/morph, editable effect history, and capture memory accounting |
| 5 | APNG import/export through the shared frame workflow |
| 6 | WebP import/export, codec dependency, and third-party notices |

Each proposed merge state must build independently and pass its relevant suites. Full unit results should identify the known upstream color-picker positioning failure separately. Do not discard a feature's later regression fixes while reconstructing its earlier commits.

## Verification of the first submission

The independent branch builds successfully. Its focused run passed 65 tests in six suites. The final complete run exercised 695 tests in 93 suites: 693 passed; `ColorPickerTests.pickerReopensWhereItWasLastLeft` and `FloatingPanelTests.dockedPlacementLeavesTheSavedFilterPosition` failed on window-position assertions. Both failures reproduce on the untouched upstream `f4b7009` checkout, whose panel implementation and tests match current upstream. No GIF, format compatibility, precision, geometry, history, or frame-editing tests failed. A separate frame-editing run also covered Gaussian Blur and native-resolution Camera Raw on the selected frame.

Live verification used an isolated app instance and a disposable GIF. The short timeline stayed centered, playback disabled mask actions, pausing and manual navigation restored them, and the eye tooltip described canvas/export visibility. Saving wrote format 27 with the selected frame and disabled frame mask; reopening restored both with playback paused and image pixels selected. The test instance closed without changing the user's open document.

Markdown fences, local links and anchors, scheme XML, and Git whitespace checks passed. Local tests used optimized Debug builds, ad hoc signing, and a command-line hardened-runtime override; repository build and signing settings are unchanged. The first PR has no package dependency or screenshot-scheme changes.
