# DetecDiv UI — MATLAB prototype

## Launch

Use a MATLAB session dedicated to this worktree:

```matlab
cd('C:\Users\Gilles\Documents\MATLAB\Detective-UI');
detecdiv_setup_path(pwd, 'DetecDivRoot', pwd);
viewer = detecdiv_ui();
% Imports existing shallow/classi/process/pipeline handles from the base workspace.
% Use detecdiv_ui([]) to start empty, or View > Refresh Workspace to rescan.
% Existing projects can also be supplied:
viewer = detecdiv_ui(projectA);
viewer.addProject(projectB);
% Or open multiple projects at launch:
viewer = detecdiv_ui({projectA, projectB});
```

`DetecDivRoot` must explicitly select this worktree: the path helper can otherwise choose the sibling DetecDiv checkout. The regular `detecdiv` entry point and existing MLAPPs are unchanged. The main docking shell is code-owned; widget content can later follow the App Designer / code-sync workflow. This docking host currently requires Windows MATLAB R2026a.

## Current interface

- File, Edit, View, Navigate and Help menus, with standard open/close/copy accelerators.
- One Projects tree containing Project → FOV → ROI nodes. Multiple projects remain open; selecting a node updates the central image. Opening the same handle, stable project ID or project path focuses the existing project.
- Browser rebuilding briefly detaches the tree from its layout, populates its hierarchy without a live native peer, then reattaches the same control and expands project/collection roots. Incremental construction of large live trees failed inside R2026a's graphics property setter; changing metadata or constructor alone did not reliably fix it. Navigation records stay in MATLAB-side `UserData`. `detecdivui.treeTest()` checks visible workspace import, live rebuilding and selection with 641 ROIs. Failed launch-time discovery closes its partially opened viewer.
- Launching without arguments discovers live `shallow`, `classi`, `process` and `pipeline` variables in the base workspace, including object arrays and aliases. Independent tools have typed Classifiers, Processors and Pipelines collections with metadata inspection; their editing/execution widgets remain future work. View > Refresh Workspace (or `viewer.refreshWorkspace()`) imports new objects without removing manually opened projects. Deleted handles are skipped. Discovery does not load files, save data, publish variables or recursively scan cells/structs. Explicit project arguments keep their existing behavior; `DiscoverWorkspace` can override discovery for scripted launches.
- A bottom Project details panel follows the active project, including when a FOV/ROI is selected. It shows the name, selectable project folder path (`fullfile(io.path, io.file)`) with Copy, FOV/ROI counts, associated classifiers/processors, pipeline runs and the cached default pipeline when available. Unknown paths disable Copy; no filesystem/network scan or image load is needed. Clicking a project keeps that node selected while retaining its current image context.
- Per-project FOV/ROI, frame and named-channel state. Closing a project restores another open project; closing the last project clears the viewport.
- Breadcrumb and parent-FOV navigation synchronized with tree and ROI-outline selection.
- Named logical channels, including non-contiguous RGB subchannels. Missing or incompatible channel metadata falls back to individual image planes.
- A Layers table with independent visibility, an active layer, Solo, source-unit min/max contrast and a range slider, Auto, color and opacity. Label layers use score's renderer and stable ID colors or a selected RGB color.
- Reference ROI outlines that can be hidden; no temporal geometry is inferred.
- Frame number, slider and previous/next actions. Zoom survives temporal navigation of the same view.
- Independent Projects, Image, Display and Pipeline widgets, with native detachment/redocking and View menu docking commands. Widget visibility and layout can be saved and restored across launches. Older three-widget layouts keep their geometry and initially hide Pipeline.
- Pipeline selects workspace or JSON templates, inspects steps/parameter scope, validates and dry-runs the current FOV/ROI or whole project, lists associated project runs and opens their inspector. Advanced editing/execution reuse `pipeline2`; the main widget does not yet launch/monitor runs inline. See `DETECTIVE_UI_PIPELINE.md`.
- Concise English labels, native MATLAB tooltips and a bottom status bar. There is no permanent explanatory or onboarding text.
- Copy Image uses MATLAB `copygraphics` on the displayed axes. The automated smoke test does not overwrite the user's clipboard.

The session uses existing `fov.readImage` and `roi.load('Data',false)`. ROI loading can load a whole extraction and update in-memory display metadata; the legacy raw reader can repair paths in memory. Browsing does not save, extract or process scientific data. Closing a project only removes its UI reference.

## Limits

The current interface is an exploration prototype. Scientific editing, full classifier/processor management, inline pipeline editing/execution, guided segmentation, cross-session display presets and lazy reconstruction of non-extracted ROIs remain to be integrated. A three-plane logical channel is displayed as RGB; other multi-plane groups are exposed individually. Outlines use the same reference rectangles as workflow; mobile trajectories are not reconstructed.

Reading is synchronous, with a bounded current-frame cache for requested channels. Contrast defaults to finite pixel min/max and stays fixed while navigating until changed or reset with Auto. Display settings are separate for each project's FOV/ROI during the session, without changing source pixels or metadata. Project switching restores frame and channel but does not preserve an independent zoom for every FOV/ROI. Data is synthetic in automated validation; real acquisitions and performance still need validation.

## Initial reuse inventory

| Intent | Existing source | Adaptation needed |
| --- | --- | --- |
| Open Project | `structure/io/shallowLoad.m` | Progress and Hub access context |
| Browse raw images | `structure/classes/@fov/readImage.m` | Block reading, cache, time/channel mapping |
| View extracted ROIs | `structure/classes/@roi/load.m` | Selective reads and channel loading |
| Define ROIs | `+roiManual`, `+roiPattern`, `+roiGrid`, `+roiTracked` | Contextual parameters and preview |
| Preview geometry/drift | `structure/GUI/workflow_extracted.m` | Identify active runtime source, isolate transforms |
| Display layers/results | `structure/GUI/score/score_display.m` and render helpers | Remove dependencies on score components |
| Edit masks/tracks | `score_setEditMode`, `score_splitMaskObject`, `score_swapSelectedTrackIds` | Selection, preconditions, save and undo |
| Annotate/review | `score/private/score_runtime_code.m`, annotation tests | Separate actions/state from UI |
| View lineages/signals | score helpers and `@dataseries` | Synchronize session selection and time |
| Reproducible analysis | `runPipeline.m`, `@pipeline`, `pipelineRun` | An inspectable pipeline behind each guided action |
| Frontend synchronization | `detecdiv_event.m`, `detecdiv_frontend_plugins.m` | Lifecycle and event contracts |
| App Designer layout | Existing `*_gui_layout` / `sync_*_layout` helpers | Preserve separate layout and code sources |

This inventory identifies reuse candidates, not completed integrations.

## Validation

```matlab
detecdivui.smokeTest();
detecdivui.dockingTest();
detecdivui.layerTest();
detecdivui.displayTest();
% Optional visible export for visual inspection:
detecdivui.smokeTest(fullfile(tempdir, 'detective-ui-desktop.png'));
```

The smoke test creates temporary TIFFs and in-memory ROIs. It exercises pixels, logical/RGB channels, image/contrast limits, outlines, timeline, failed-read recovery, menu callbacks, tree selection, multiple projects, duplicate opening, closing active/inactive/last projects and empty projects. It does not yet validate real acquisitions or extracted H5 data. The optional PNG export briefly shows the window.

Validated on 4 November 2026 with MATLAB R2026a: smoke test passed, Code Analyzer clean for the entry point and package, and the exported desktop window inspected visually with two projects open.

## Docking and layout preferences

See `DETECTIVE_UI_DOCKING.md` for the internal API boundary, classic menu adapter, JSON layout contract and test scope. Preferences default to `fullfile(prefdir, 'DetecDiv', 'ui-layout-r2026a.json')`. Use `'LayoutFile', '', 'AutoSaveLayout', false` to isolate a temporary session.

`viewer.Figure` refers to the Image widget figure. Use `viewer.widgetFigure('Projects')` and `viewer.widgetFigure('Display')` for the other native component trees. `viewer.Host` exposes explicit docking and layout methods.

## Next implementation tranche

Validate the layered display on real data, then connect classifier management and selection before guided segmentation. The proposed browser contains typed Projects/Classifiers/Processors collections; Pipeline needs its own dockable widget. See `DETECTIVE_UI_DISPLAY.md`. Follow `DETECTIVE_UI_GUIDELINES.md`: conventional desktop menus, English, DetecDiv terminology, a multi-project tree and contextual help through tooltips/status rather than permanent explanatory paragraphs.

Uncommitted fixes in the initial DetecDiv checkout have not been imported into this worktree; compare them before adapting affected loading/display code.
