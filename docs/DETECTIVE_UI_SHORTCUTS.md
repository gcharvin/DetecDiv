# Keyboard shortcuts

## Image browsing

The viewer reuses `detecdiv_prefs_get_shortcuts`, the preference reader called by Score at startup. Left/Right Arrow move one frame; the pair stored in `roi_view_frames_jump_size` moves ten frames (L/M by default). Navigation clamps at the first/last frame and uses the existing viewer frame/render path, retaining contrast, selected channels and zoom. The Navigate menu shows the active keys and exposes the same actions. Help > Keyboard Shortcuts... lists the available shortcuts without adding permanent help text to the workspace.

Bare keys apply while the main Image canvas has focus, including its separate channel panels and floating Image document. They do not intercept typing, numeric edits, sliders, tree/table navigation, histogram level markers, menus, modified keys or another viewer. The ROI definition assistant and drawing gestures suspend browsing shortcuts; its timeline remains available. Source ROI metadata and pixels remain unchanged.

`imageKeyboard.html` is a zero-height component in the Image document. It forwards only recognized image-canvas keys through the existing uihtml event mechanism. Its listener is restricted to the hosting FigureDocument, removed on unload, and rebound when its owning document changes. This small browser boundary relies on the same Windows R2026a docking implementation as DockingHost. Context identifiers reject keys queued for a different project/FOV/ROI. No global OS keyboard hook is installed.

## Score inventory and migration

| Current source/context | Keys (defaults) | Meaning | New viewer |
| --- | --- | --- | --- |
| `ScoreAppUIFigureKeyPress`, also forwarded by `ImageFigureKeyPress` | Left/Right Arrow | Previous/next frame | Available on Image |
| Same callback; preferences group 3 | L / M | Back/forward ten frames | Available; shares Score preferences |
| Same callback; managed annotation session, group 2 | W / X | Set training sequence start/end | Reserve for annotation/dataset widget |
| Same callback; class keys | A Z E R T Y U I | Assign selected training class | Reserve for annotation/dataset widget |
| Same callback | Shift + class key | Outside a sequence window, extend assignment from current frame to the end; within a window, keep window scope | Reserve for annotation/dataset widget |
| Same callback | Delete | Delete selected annotation contour/object | Available in Contours for the selected label/current frame; never deletes a project/ROI |
| Same callback | Escape | Cancel active fission correction | Reserve for the fission editor |
| `helpers/changeframe.m`, legacy ROI view | 1–9 / 0 | Zoom to image thirds / reset view | Legacy helper behavior; not a current Score main-window binding |
| Same legacy helper; paint/classifier context, group 4 | K | Fill painted contours | Available in Contours for the selected label; not a global key |
| Same legacy helper; group 5 | Down/G, Up/H | Decrease/increase paint overlay opacity | Available in Contours for its selected provider; not a global intensity adjustment |
| Same legacy helper; sequence/class context | Bounds/class keys | Edit classification/training | Reuse annotation contracts when the corresponding widget exists |
| `helpers/draw.m`, legacy class menu | Ctrl + class key | Activate a training class menu entry | Keep local to the future annotation/paint tool |
| `annotationValidationDialog` | C / K / R | Accept censor / keep usable / refresh | Keep scoped to validation dialog |
| `score_paintOverlay`, relabel dialog | Enter / Escape | Apply / cancel relabel | Keep scoped to relabel dialog |
| Preferences group 1 | J / K | Correction key preference | Declared in preferences; no active use in the audited Score main handler or legacy `changeframe` handler |

Inventory sources: `structure/GUI/score/private/score_runtime_code.m` (`ScoreAppUIFigureKeyPress`, `assignSelectedTrainingClass`, `ImageFigureKeyPress`), `helpers/changeframe.m`, `helpers/draw.m`, `helpers/detecdiv_prefs_get_shortcuts.m`, `structure/GUI/score/annotationValidationDialog.m`, and `structure/GUI/score/score_paintOverlay.m`. Commented-out legacy bindings are not advertised as active shortcuts. Context-specific annotation actions must be connected to their existing business helpers when those tools are integrated; unavailable actions are not exposed in the current shortcut dialog.

## Verification

`detecdivui.keyboardTest()` sends actual CEF keydown events through the Image document. It checks frame and ten-frame jumps, clamping, repeated events, input/modifier isolation, pixels, timeline, zoom, float/redock, active preference labels, help-window reuse/cleanup and unchanged source data.

With Contours active, Ctrl+Z/Ctrl+Y undo/redo the mask draft, and Escape cancels a pending stroke/returns to Select. Its Delete/fill/opacity bindings share the existing Score preferences. Frame navigation remains active outside drawing gestures. See `DETECTIVE_UI_CONTOURS.md` and `detecdivui.contourTest()` for editor scope and persistence.

Tracks uses the same navigation and shared annotation Undo/Redo. Escape cancels a pending parent/continuity pick; Delete retains the current-frame contour meaning. Whole-track deletion is an explicitly labeled button, not the Delete key. Inputs retain text editing, including exact decimal uint64 IDs. See `DETECTIVE_UI_TRACKS.md` and `detecdivui.tracksTest()`.
