# Keyboard shortcuts

## Image browsing

The viewer reuses `detecdiv_prefs_get_shortcuts`, the preference reader called by Score at startup. Left/Right Arrow move one frame; L/M always move back/forward ten frames. The pair stored in `roi_view_frames_jump_size` remains available as additional bindings. Navigation clamps at the first/last frame and uses the existing viewer frame/render path, retaining contrast, selected channels and zoom. The Navigate menu shows the preference keys and exposes the same actions. Help > Keyboard Shortcuts... lists the available shortcuts without adding permanent help text to the workspace.

The numeric keypad selects a third of the full image in each dimension:

| Left | Centre | Right |
| --- | --- | --- |
| 7: top-left | 8: top | 9: top-right |
| 4: left | 5: centre | 6: right |
| 1: bottom-left | 2: bottom | 3: bottom-right |

Each selection is relative to the full image, not a recursive zoom. **0** fits
the complete image. The number row is accepted too. Physical keypad keys work
with Num Lock off without intercepting the separate Home/End/arrow keys. Zoom
works for still images as well as sequences, and uses pixel-edge limits.

The Image timeline includes **Zoom**, **Pan** and **Reset**. Zoom enables a
dragged rectangle and pointer-centred wheel zoom; Pan enables drag.
Click the active mode again to return to selection. All channel panels share
limits, and each Image tab keeps
its own viewport across frame changes and tab switches. Reset changes the
viewport without rereading pixels. Export's visible-area option uses that same
viewport. View > Zoom Image / Pan Image / Fit Image expose the same actions.

Manual navigation temporarily takes precedence over mask painting and track
picking without changing drafts. Selecting a painting tool or opening an editor
returns to editing. ROI drawing suspends navigation until the gesture ends.

Bare keys apply while the main Image canvas, its figure container or its ordinary buttons have focus, including its separate channel panels and floating Image document. MATLAB commonly focuses the figure container after an image click or redraw. Toggling Overlay channels or using the previous/next frame buttons explicitly focuses the Image figure through the keyboard bridge: selecting the docking document alone leaves native control focus unchanged. Subsequent arrows browse frames, including during that asynchronous focus handoff. They do not intercept typing, numeric edits, sliders, tree/table navigation, histogram level markers, toolbar navigation, menus, modified keys or another viewer. The ROI definition assistant suspends frame shortcuts but retains zoom keys while idle; drawing gestures suspend all image shortcuts. Its timeline remains available. Source ROI metadata and pixels remain unchanged.

`imageKeyboard.html` is a zero-height component in the Image document. It forwards only recognized image-navigation/editor keys through the existing uihtml event mechanism. Its listener is restricted to the hosting FigureDocument (including its floating-window background when it is the only figure), removed on unload, and rebound when its owning document changes. This small browser boundary relies on the same Windows R2026a docking implementation as DockingHost. Context identifiers reject keys queued for a different project/FOV/ROI. No global OS keyboard hook is installed.

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
| `helpers/changeframe.m`, legacy ROI view | 1–9 / 0 | Zoom to image thirds / reset view | Available on Image, with linked channel panels and physical keypad support |
| Same legacy helper; paint/classifier context, group 4 | K | Fill painted contours | Available in Contours for the selected label; not a global key |
| Same legacy helper; group 5 | Down/G, Up/H | Decrease/increase paint overlay opacity | Available in Contours for its selected provider; not a global intensity adjustment |
| Same legacy helper; sequence/class context | Bounds/class keys | Edit classification/training | Reuse annotation contracts when the corresponding widget exists |
| `helpers/draw.m`, legacy class menu | Ctrl + class key | Activate a training class menu entry | Keep local to the future annotation/paint tool |
| `annotationValidationDialog` | C / K / R | Accept censor / keep usable / refresh | Keep scoped to validation dialog |
| `score_paintOverlay`, relabel dialog | Enter / Escape | Apply / cancel relabel | Keep scoped to relabel dialog |
| Preferences group 1 | J / K | Correction key preference | Declared in preferences; no active use in the audited Score main handler or legacy `changeframe` handler |

Inventory sources: `structure/GUI/score/private/score_runtime_code.m` (`ScoreAppUIFigureKeyPress`, `assignSelectedTrainingClass`, `ImageFigureKeyPress`), `helpers/changeframe.m`, `helpers/draw.m`, `helpers/detecdiv_prefs_get_shortcuts.m`, `structure/GUI/score/annotationValidationDialog.m`, and `structure/GUI/score/score_paintOverlay.m`. Commented-out legacy bindings are not advertised as active shortcuts. Context-specific annotation actions must be connected to their existing business helpers when those tools are integrated; unavailable actions are not exposed in the current shortcut dialog.

## Verification

`detecdivui.keyboardTest()` sends CEF keydown events through the Image document, including consecutive keys dispatched to the browser's actual focused element and native frame-button clicks with button focus. It checks frame and ten-frame jumps, clamping, repeated events, input/modifier isolation, pixels, timeline, retained channel layouts/mask fill/contours, zoom, float/redock, active preference labels, help-window reuse/cleanup and unchanged source data. Desktop verification also uses native Windows key input after clicking the frame buttons; synthetic CEF key events alone do not establish physical-key behavior.

The test additionally covers all nine keypad positions with Num Lock off and
the Zoom/Pan/Reset buttons. `detecdivui.imageNavigationTest()` covers a single
frame, exported viewport and source preservation. These automated tests check
mode wiring; physical mouse gestures require an unlocked desktop.

Validation on 2026-11-09: navigation, keyboard and contour tests passed; Code
Analyzer reported no issues in the changed components. After unlocking the
desktop, physical rectangle zoom, pan at fixed scale, wheel zoom in Zoom mode,
and keypad 1/0 were verified against actual axes limits. Callback-driven
suppression of built-in gestures required explicit MATLAB `zoom(ax,'on')` /
`pan(ax,'on')` modes, in addition to interaction objects. A second physical test
verified linked channel panels, L/M (1 → 11 → 1), Reset, and further rectangle
zoom after a frame redraw. Native modes are suspended around callback/axes
reconstruction and restored afterwards, avoiding WebAxesModeWarnings.
The older `tracksTest` fails at line 62
when driving the now-hidden provider selector. This also reproduces with the
unchanged Viewer/MaskWidget/TracksWidget from `de02be11`, so the test needs a
separate update to the current Display-owned provider workflow.

With Contours active, Ctrl+Z/Ctrl+Y undo/redo the mask draft, and Escape cancels a pending stroke/returns to Select. Its Delete/fill/opacity bindings share the existing Score preferences. Frame navigation remains active outside drawing gestures. See `DETECTIVE_UI_CONTOURS.md` and `detecdivui.contourTest()` for editor scope and persistence.

Tracks uses the same navigation and shared annotation Undo/Redo. Escape cancels a pending parent/continuity pick; Delete retains the current-frame contour meaning. Whole-track deletion is an explicitly labeled button, not the Delete key. Inputs retain text editing, including exact decimal uint64 IDs. See `DETECTIVE_UI_TRACKS.md` and `detecdivui.tracksTest()`.
