# Dockable MATLAB workspace

## Scope

`detecdiv_ui` hosts Projects, Image, Display, Pipeline, Objects and Data in a native MATLAB docking container. Widget contents reuse the existing project browser, image reader, display controls, pipeline APIs and session controller. Scientific processing and storage formats are unchanged.

The undocumented integration is confined to `detecdivui.DockingHost`. This first implementation explicitly targets **Windows MATLAB R2026a**. A different MATLAB release raises an actionable error instead of silently launching an unsupported shell.

## Use

```matlab
cd('C:\Users\Gilles\Documents\MATLAB\Detective-UI');
detecdiv_setup_path(pwd, 'DetecDivRoot', pwd);
viewer = detecdiv_ui();
```

- File, Edit, View, Navigate and Help remain at the top of the workspace.
- Each widget has a native document tab and docking controls. View > Docking provides explicit Dock/Undock commands and Dock All.
- Native tab/floating-window Close hides the widget and preserves its figure, controls and scientific drafts. View reopens it. Closing the main window still uses the existing scientific dirty/save checks before releasing the application.
- View > Projects / Image / Display / Pipeline / Objects / Data shows or hides a widget.
- First opening Annotations (including View or checking a mask layer) splits its own panel below Display/Pipeline, so Display and Annotations remain visible together. Checking a mask keeps focus in Display. First opening Data splits Image into an upper image and lower dataseries view. These local splits retain other tiles and custom column widths. Previously floating or arranged inspectors keep their placement.
- Older saved layouts that stacked Annotations with Display are migrated once to this separate lower panel. New layout records carry `annotationsLayoutVersion=2`; later custom docking/tab choices are preserved.
- A hidden docked widget returns to its previous placement if the remaining layout has not been rearranged, including after saving and restoring that hidden state. Explicit rearrangements made while it was hidden take priority.
- View > Save Layout stores the current workspace. Restore Layout reloads it; Reset Layout restores the initial three-column arrangement.
- The current layout is also saved when the workspace closes normally, and loaded at the next launch.

`detecdivui.layerAnnotationsTest()` checks actual layer checkbox events, active
mask/track synchronization, concurrent Display/Annotations, retained Display
focus, legacy shared-tab migration and later custom placement. The broader
`detecdivui.analysisLayoutTest()` covers floating, closing/reopening and saved
inspector geometry.

The default file is `fullfile(prefdir, 'DetecDiv', 'ui-layout-r2026a.json')`. Layout preferences do not contain microscopy pixels or automatically reopen project data.

```matlab
viewer = detecdiv_ui(project, 'LayoutFile', fullfile(tempdir, 'my-layout.json'));
viewer.Host.setDocked('Display', false);
viewer.Host.saveLayout();
% For isolated sessions or automated tests:
viewer = detecdiv_ui(project, 'LayoutFile', '', 'AutoSaveLayout', false);
```

## Internal boundary

| Responsibility | Implementation |
| --- | --- |
| Native host | `matlab.ui.container.internal.AppContainer` |
| Figure factory | `matlab.ui.internal.FigureDocumentGroup` |
| Widget document | `matlab.ui.internal.FigureDocument` |
| Classic menu model | `detecdivui.MenuCommand` |
| Classic menu presentation | `desktopMenu.js`, installed only in this app's CEF window |
| Scientific navigation and display | Existing `Viewer` / `Session` and legacy readers |

`FigureDocumentGroup` is required: a generic `DocumentGroup` does not install the factory needed to render native figure contents. All widgets are figure documents so that their existing handles and callbacks survive detachment; there is no replacement tree or copied image widget on undocking. Native documents are closable, with a `CanCloseFcn` that vetoes destruction and schedules hiding on the next event turn. The host owns and cancels those one-shot timers. Floating documents are parked in the main host before hiding to preserve their native peer; the saved floating intent/bounds are restored when reopened. An approved whole-app close bypasses that per-widget hide veto; MATLAB installation files are unchanged.

AppContainer does not expose the same top-level `uimenu` interface as a standalone `uifigure`. A small menu adapter provides the conventional menu bar above its workspace. It uses semantic menu roles, keyboard navigation and the same MATLAB command callbacks. A local timer drains only allowlisted menu command IDs from this window; it is stopped on close. CEF access is serialized to avoid reentrant screenshot/menu requests. No MATLAB installation files are modified.

The shell itself is code-owned. App Designer can still be used for widget contents once their layout is stable; it does not own the native docking layout.

## Startup and axes lifecycle

Startup axes are created with `Toolbar=[]`; reading the lazy toolbar getter before the native host is ready is avoided. Once AppContainer is running and pending graphics updates have settled, image and Data axes receive an explicit default toolbar. Additional side-by-side image panels use the same initialization helper. Pipeline graphs stay toolbar-free and noninteractive except for their own callbacks.

R2026a's native axes toolbar listener can receive a deleted interaction container. `ImageAxes.initialize` detects invalid native interaction state and permits one reconstruction of the still-empty axes, retaining its parent, metadata and grid placement. Unexpected errors are reported; repeated native failure is bounded and cleaned up. Plotted axes are never replaced by this helper, so existing image/data contents cannot be discarded as a repair action. Zoom, pan and restore-view remain native controls. No MATLAB installation files are patched.

A reference-counted guard defers menu polling in other live DetecDiv hosts during construction/discovery and native teardown. It releases on success or failure. Constructor cleanup covers failures before Host.start as well as toolbar initialization: only the partial new viewer is disposed, its menu/preview/follow timers are released, and its layout is not auto-saved over existing preferences. Existing viewers and project data remain owned by their original instances. An open viewer is a supported relaunch scenario, not proof of the cause of every axes error. The startup regression reports success only after its multi-viewer cleanup completes; native teardown uses the same guard to prevent CEF menu reentry.

## Persistence contract

The JSON envelope is `detecdiv.ui.layout.v1`, with the MATLAB release, native layout snapshot, main window bounds and each widget's docked/visible state and floating-window bounds. Stable widget tags are `projects`, `image`, `display`, `pipeline`, `objects` and `data` in the `workspace` figure document group. Fresh layouts place Pipeline beside Display as tabs in the right column; Objects and Data start hidden. Older v1 records gain any missing Pipeline, Objects or Data document hidden/docked, retaining their geometry. Optional `placed` flags prevent inspectors from being rearranged again, and `hiddenLayouts` retains reversible Close placement across launches. View can show new widgets without resetting the workspace.

Saving waits for asynchronous layout changes to settle and writes to a temporary file before replacing the preference file. Restoring applies widget states before the native layout, so invisible or floating widgets are not reinserted into the wrong docked grid. Layout files from another release or malformed files fall back to the default layout. A rejected file is preserved; automatic saving is suppressed until an explicit successful save or restore.

## Verification

```matlab
detecdivui.dockingTest();
detecdivui.smokeTest();
detecdivui.imageAxesTest();
detecdivui.startupTest();
detecdivui.analysisLayoutTest();
```

The docking integration test checks actual visible native floating windows, menu-to-MATLAB dispatch, detachment and redocking of all four widgets, retained tree/control/image handles, non-default column widths, floating bounds, hidden widgets, normal-close auto-save, fresh-instance restoration, corrupt preference recovery and timer cleanup. The navigation test separately checks multi-project browsing, TIFF pixels, RGB grouping, time navigation and read-error recovery. `pipelineTest` additionally verifies migration from three-widget layouts.

The startup regressions added on 5 November 2026 reproduce the native listener's deleted-handle failure with an isolated race fixture, verify recovery of actual empty UIAxes and exercise their real zoom/pan callbacks. A temporary Viewer copy injects faults without adding production hooks: recovery, bounded repeated failure, pre-host construction failure, unchanged old-viewer pixels/zoom, released timers/windows/guard and unchanged saved-layout bytes are checked. Deliberately deleting a native container during creation can emit MATLAB Reparent-listener warnings in these negative tests; no MATLAB installation files or global graphics defaults are changed.

`analysisLayoutTest` adds native document close/reopen, Data below Image and simultaneous Display/Objects checks. It verifies custom widths and unrelated tiles, actual `Showing` state of all three inspectors, floating close without deletion, hidden placement persistence, old five-document records and approved whole-app closure. These host-only cases passed on 6 November 2026 in Windows MATLAB R2026a, with clean Code Analyzer output. Layout changes discard stale pixel caches while retaining valid per-tile `showingChildId` values; opening Data therefore keeps Display selected in its own tab group. Saved docked bounds are applied after reparenting, preventing negative default dimensions from reaching a still-floating viewport. Floating bounds are restored again after final focus because CEF can publish defaults late. Full Objects/Data scientific integration is verified separately.

An optional PNG path to either test captures the main workspace for visual inspection. Real acquisition testing, multi-monitor layout migration and other MATLAB releases remain outside this validation scope.

Validated on 4 November 2026 under Windows MATLAB R2026a: `dockingTest` and `smokeTest` passed without warnings, Code Analyzer was clean, and the exported workspace was inspected. Gilles subsequently confirmed successful interactive use of the shell. The agent's separate mouse-drag check was interrupted with Escape and is not counted as a completed drag-and-drop test.
