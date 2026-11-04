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

Inter-widget status/change/progress/graph/ROI/advanced-editor links use `detecdivui.Callback` descriptors (owner, public method, fixed arguments). Dispatch resolves the method by name, while retaining function-handle compatibility and ignoring notifications to deleted owners. This avoids keeping anonymous Viewer constructor source locations in child widgets. `viewer.rebindCallbacks()` repairs these links in an already-open viewer without reloading project data; navigation also upgrades an older anonymous status link before calling Pipeline. It does not promise arbitrary hot replacement of native controls/layouts: recreate the viewer after structural UI changes. `detecdivui.callbackTest()` exercises the native ROI-outline click with an injected failing legacy status link.

File > Open Classifier... uses classiLoad; File > Open Pipeline... and Pipeline's Open action use pipelineLoad. File-loaded tools appear in the typed Projects browser collections and remain open across Refresh Workspace. Explicitly reloading the same tool replaces its browser entry with the new snapshot. These actions do not publish variables into the base workspace or create a project. The classifier editor/training workflow remains a separate integration.

File > Recent Projects reuses the classic `prefdir/recentProjects.mat` / `RecentProjects` string-array format. Up to ten successful explicit project opens/saves are retained, deduplicated case-insensitively, with MAT/JSON references to the same project grouped together. History loading only reads preferences; it neither checks referenced drives nor opens projects/images. Unavailable paths remain listed until the user clears history. A recent project already open is focused without reloading its unsaved data. A failed open leaves the current image/project intact. Clear Recent Projects also clears the shared classic history; it does not close or delete projects. Use `'RecentProjectsFile',''` for an in-memory isolated history, or an explicit temporary file in tests.

- File, Edit, View, Navigate and Help menus, with standard open/close/copy accelerators.
- One Projects tree containing Project → FOV → ROI nodes. Multiple projects remain open; selecting a node updates the central image. Opening the same handle, stable project ID or project path focuses the existing project.
- Browser rebuilding briefly detaches the tree from its layout, populates its hierarchy without a live native peer, then reattaches the same control and expands project/collection roots. Incremental construction of large live trees failed inside R2026a's graphics property setter; changing metadata or constructor alone did not reliably fix it. Navigation records stay in MATLAB-side `UserData`. `detecdivui.treeTest()` checks visible workspace import, live rebuilding and selection with 641 ROIs. Failed launch-time discovery closes its partially opened viewer.
- Launching without arguments discovers live `shallow`, `classi`, `process` and `pipeline` variables in the base workspace, including object arrays and aliases. Independent tools have typed Classifiers, Processors and Pipelines collections with metadata inspection; their editing/execution widgets remain future work. View > Refresh Workspace (or `viewer.refreshWorkspace()`) imports new objects without removing manually opened projects. Deleted handles are skipped. Discovery does not load files, save data, publish variables or recursively scan cells/structs. Explicit project arguments keep their existing behavior; `DiscoverWorkspace` can override discovery for scripted launches.
- A bottom Project details panel follows the active project, including when a FOV/ROI is selected. It shows the name, selectable project folder path (`fullfile(io.path, io.file)`) with Copy, FOV/ROI counts, associated classifiers/processors, pipeline runs and the cached default pipeline when available. Unknown paths disable Copy; no filesystem/network scan or image load is needed. Clicking a project keeps that node selected while retaining its current image context.
- Per-project FOV/ROI, frame and named-channel state. Closing a project restores another open project; closing the last project clears the viewport.
- Breadcrumb and parent-FOV navigation synchronized with tree and ROI-outline selection.
- Launch, Open Project, workspace refresh, project-root selection and project closure update metadata without probing raw paths or loading ROI H5 stores. Select a FOV/ROI or click Load Image to request pixels. View > Reload Image also explicitly requests/retries the current image. Display controls cannot trigger reads while the view is pending.
- On a requested raw read, Session checks only the referenced source folder/file before using `fov.readImage`. Missing sources expose Relink Raw Data... in the image toolbar; File > Relink Raw Data... remains available for a project with FOVs. The action uses the existing root picker and `detecdiv_paths_relink_project` in its default mode, invalidates display pixels and retries a previously requested missing raw image after successful relinking. A metadata-only view stays unloaded. Relinking changes paths in memory and registers the chosen root through the existing helpers; it does not save the project.
- Named logical channels, including non-contiguous RGB subchannels. Missing or incompatible channel metadata falls back to individual image planes.
- A Layers table with independent visibility, an active layer, Solo, source-unit min/max contrast and a range slider, Auto, color and opacity. Label layers use score's renderer and stable ID colors or a selected RGB color.
- Reference ROI outlines that can be hidden; no temporal geometry is inferred.
- Frame number, slider and previous/next actions. Zoom survives temporal navigation of the same view.
- Independent Projects, Image, Display and Pipeline widgets, with native detachment/redocking and View menu docking commands. Widget visibility and layout can be saved and restored across launches. Older three-widget layouts keep their geometry and initially hide Pipeline.
- Pipeline keeps a compact graph, run selector and live in-memory status. New Run/common settings open a separate dialog; Advanced uses `pipeline2` with the same run identity and configuration. Execution/remote monitoring remain in that editor. See `DETECTIVE_UI_PIPELINE.md`.
- Edit > Define ROIs... and the image/Projects context menus open the contextual assistant on the main raw image. Its tab is absent at launch; Done removes it and drawing handles while retaining the draft. Manual/Pattern/Grid definitions use existing backends; pipeline ROI commands reuse this assistant instead of opening Workflow. Save Project writes lightweight JSON metadata without extracting/saving ROI pixels. See `DETECTIVE_UI_ROIS.md`.
- Image browsing reuses Score's Left/Right Arrow and configurable ten-frame jump keys (L/M by default), with focus isolation, clamped frame bounds and float/redock support. Navigate shows the keys; Help > Keyboard Shortcuts... lists available actions. Annotation/painting keys remain reserved for their respective editors. See `DETECTIVE_UI_SHORTCUTS.md`.
- Edit > Edit Contours... opens a contextual indexed-mask assistant on Image: selection, polygon/freehand, boundary editing, brush/eraser, fill/delete, undo/redo and Score keyboard preferences. Drafts are isolated from canonical ROI pixels/model/data until Save Masks, retained across navigation, and guarded on normal closure. Persistence reuses ROI and Score helpers; partial-file failures remain dirty/retryable. See `DETECTIVE_UI_CONTOURS.md`.
- Edit > Edit Tracks... opens the provider/family inspector and linking assistant. Scoped reassignment/new tracks, whole-track swaps/deletion and parent selection reuse the same cellModel operations as Score. Parent/continuity picks can cross frames while retaining their source context. Contours/Tracks share selection, bounded model/pixel history, explicit persistence and close protection; model-only edits preserve the image H5. See `DETECTIVE_UI_TRACKS.md`.
- Run parameters with simple supported types can be edited in Pipeline without changing its template. Drafts are separate per project/template and pass through the existing run context to validation and the advanced editor. Runs also has an embedded review (Summary, Steps, Issues), loaded only on request through `pipelineRunReview`.
- Concise English labels, native MATLAB tooltips and a bottom status bar. There is no permanent explanatory or onboarding text.
- Copy Image uses MATLAB `copygraphics` on the displayed axes. The automated smoke test does not overwrite the user's clipboard.

On demand, the session uses existing `fov.readImage` and `roi.load('Data',false)`. ROI loading can load a whole extraction and update in-memory display metadata. A missing recorded raw source is reported before invoking the legacy reader's automatic root search. Direct path checks and successful image reads remain synchronous after an explicit image request; an unavailable network filesystem can therefore still delay that requested read. Startup does no image I/O. Browsing does not save, extract or process scientific data. Closing a project only removes its UI reference.

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
detecdivui.lazyImageTest();
% Optional visible export for visual inspection:
detecdivui.smokeTest(fullfile(tempdir, 'detective-ui-desktop.png'));
```

The smoke test creates temporary TIFFs and in-memory ROIs. It exercises pixels, logical/RGB channels, image/contrast limits, outlines, timeline, failed-read recovery, menu callbacks, tree selection, multiple projects, duplicate opening, closing active/inactive/last projects and empty projects. It does not yet validate real acquisitions or extracted H5 data. The optional PNG export briefly shows the window.

Validated on 4 November 2026 with MATLAB R2026a: smoke test passed, Code Analyzer clean for the entry point and package, and the exported desktop window inspected visually with two projects open.

## Docking and layout preferences

See `DETECTIVE_UI_DOCKING.md` for the internal API boundary, classic menu adapter, JSON layout contract and test scope. Preferences default to `fullfile(prefdir, 'DetecDiv', 'ui-layout-r2026a.json')`. Use `'LayoutFile', '', 'AutoSaveLayout', false` to isolate a temporary session.

`viewer.Figure` refers to the Image widget figure. Use `viewer.widgetFigure('Projects')` and `viewer.widgetFigure('Display')` for the other native component trees. `viewer.Host` exposes explicit docking and layout methods.

## Next implementation tranche

The complete Score review and staged migration dependencies are in [DETECTIVE_UI_SCORE_PARITY.md](DETECTIVE_UI_SCORE_PARITY.md), backed by a reproducible source inventory. Contours and Tracks now share scientific drafts/save/undo. The dockable read-only Data browser and Tracks lineage dialog reuse Score's plotting and tree renderers; see [DETECTIVE_UI_DATA.md](DETECTIVE_UI_DATA.md) and [DETECTIVE_UI_TRACKS.md](DETECTIVE_UI_TRACKS.md). Next, add an isolated current-ROI movie/sequence export dialog, then managed Annotation/Review and Data editing. Export must freeze the visible layer and draft settings and report progress without changing the interactive canvas.

Validate the layered display and main-image ROI assistant on real data, then connect classifier management and selection before guided segmentation. The browser contains typed Classifiers/Processors/Pipelines collections alongside Projects. Pipeline uses its compact graph, shared settings dialog and bridged `pipeline2` editor. See `DETECTIVE_UI_PIPELINE.md` and `DETECTIVE_UI_DISPLAY.md`. Follow `DETECTIVE_UI_GUIDELINES.md`: conventional desktop menus, English, DetecDiv terminology, a multi-project tree and contextual help through tooltips/status rather than permanent explanatory paragraphs.

Uncommitted fixes in the initial DetecDiv checkout have not been imported into this worktree; compare them before adapting affected loading/display code.
