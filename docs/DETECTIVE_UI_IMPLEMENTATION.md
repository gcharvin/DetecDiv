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

Viewer construction suppresses lazy axes-toolbar creation until the docking host is running. Image/Data toolbars then initialize explicitly through `ImageAxes`; an invalid interaction container can trigger one reconstruction of an empty axes before pixels/data are bound. Side-by-side panels use the same helper; Pipeline graphs never instantiate a toolbar just to hide it. A startup scope defers menu polling across concurrent viewer construction and workspace discovery. Failed construction disposes the partial instance without saving its layout; existing viewers/data remain intact. See `imageAxesTest` and `startupTest` for focused regressions.

Inter-widget status/change/progress/graph/ROI/advanced-editor links use `detecdivui.Callback` descriptors (owner, public method, fixed arguments). Dispatch resolves the method by name, while retaining function-handle compatibility and ignoring notifications to deleted owners. This avoids keeping anonymous Viewer constructor source locations in child widgets. `viewer.rebindCallbacks()` repairs these links in an already-open viewer without reloading project data; navigation also upgrades an older anonymous status link before calling Pipeline. It does not promise arbitrary hot replacement of native controls/layouts: recreate the viewer after structural UI changes. `detecdivui.callbackTest()` exercises the native ROI-outline click with an injected failing legacy status link.

File > Open Classifier... uses classiLoad and registers classifiers in Projects. File / Pipeline > Open Pipeline... and Pipeline's Open action use pipelineLoad and register templates in Pipeline's always-visible Open/Recent tree. Single-clicking a recent entry opens it; clicking an open entry displays its retained draft in the graph below. Copy Pipeline Path is in the tree context menu. Recent hides already-open paths without removing them from the MRU store. These independent objects remain open across Refresh Workspace. Classifier reloads replace their browser snapshot; reopening an already-open pipeline path preserves its live handle and session draft. Neither action publishes variables into the base workspace or creates a project. The classifier editor/training workflow remains a separate integration.

File > Recent Projects reuses the classic `prefdir/recentProjects.mat` / `RecentProjects` string-array format. Up to ten successful explicit project opens/saves are retained, deduplicated case-insensitively, with MAT/JSON references to the same project grouped together. History loading only reads preferences; it neither checks referenced drives nor opens projects/images. Unavailable paths remain listed until the user clears history. A recent project already open is focused without reloading its unsaved data. A failed open leaves the current image/project intact. Clear Recent Projects also clears the shared classic history; it does not close or delete projects. Use `'RecentProjectsFile',''` for an in-memory isolated history, or an explicit temporary file in tests.

Pipeline recent history reuses `prefdir/recentPipelines.mat` / `RecentPipelines`, merging pipeline2's existing `DetecDiv/pipeline2RecentPipelines` preference only for the default store. Explicit Open/reuse/Save records successful entries, with lexical path deduplication and a ten-entry MRU limit. Startup reads saved references without probing their files/drives or automatically opening them. A failed open keeps the active pipeline/draft and the missing recent entry. The Pipelines tree context menu clears history without closing templates. Use `'RecentPipelinesFile',''` or an explicit temporary MAT file to isolate history; these stores do not access the shared legacy preference. Selecting a pipeline leaves the current project/FOV and its run scope unchanged.

- File, Edit, View, Navigate and Help menus, with standard open/close/copy accelerators.
- One Projects tree containing Project → FOV → ROI nodes. Multiple projects remain open; selecting a node updates the central image. Opening the same handle, stable project ID or project path focuses the existing project.
- Browser rebuilding briefly detaches the tree from its layout, populates its hierarchy without a live native peer, then reattaches the same control and expands project/collection roots. Incremental construction of large live trees failed inside R2026a's graphics property setter; changing metadata or constructor alone did not reliably fix it. Navigation records stay in MATLAB-side `UserData`. `detecdivui.treeTest()` checks visible workspace import, live rebuilding and selection with 641 ROIs. Failed launch-time discovery closes its partially opened viewer.
- Launching without arguments discovers live `shallow`, `classi`, `process` and `pipeline` variables in the base workspace, including object arrays and aliases. Projects contains the Project/FOV/ROI hierarchy and typed Classifiers/Processors collections. Pipeline handles populate the separate Pipeline widget's Open tree; they are not Projects tree entries. View > Refresh Workspace (or `viewer.refreshWorkspace()`) imports new objects without removing manually opened projects/templates. Deleted handles are skipped. Discovery does not load files, save data, publish variables or recursively scan cells/structs. Explicit project arguments keep their existing behavior; `DiscoverWorkspace` can override discovery for scripted launches.
- A bottom Project details panel follows the active project, including when a FOV/ROI is selected. It shows the name, selectable project folder path (`fullfile(io.path, io.file)`) with Copy, and the project's cached run list/status instead of object counters. Selecting a run displays its saved configuration in Pipeline; startup/project switching does not automatically select one. Refresh explicitly discovers additional run records. Classifier/processor selections retain their relevant object metadata. Unknown paths disable Copy; opening this panel needs no filesystem/network scan or image load. Clicking a project keeps that node selected while retaining its current image context.
- Per-project FOV/ROI, frame and named-channel state. Closing a project restores another open project; closing the last project clears the viewport.
- Breadcrumb and parent-FOV navigation synchronized with tree and ROI-outline selection.
- Launch, Open Project, workspace refresh, project-root selection and project closure update metadata without probing raw paths or loading ROI H5 stores. Select a FOV/ROI or click Load Image to request pixels. View > Reload Image also explicitly requests/retries the current image. Display controls cannot trigger reads while the view is pending.
- On a requested raw read, Session checks only the referenced source folder/file before using `fov.readImage`. Missing sources expose Relink Raw Data... in the image toolbar; File > Relink Raw Data... remains available for a project with FOVs. The action uses the existing root picker and `detecdiv_paths_relink_project` in its default mode, invalidates display pixels and retries a previously requested missing raw image after successful relinking. A metadata-only view stays unloaded. Relinking changes paths in memory and registers the chosen root through the existing helpers; it does not save the project.
- Named logical channels, including non-contiguous RGB subchannels. Missing or incompatible channel metadata falls back to individual image planes.
- A Layers table with independent visibility, an active layer, Solo, source-unit min/max contrast and a range slider, Auto, color and opacity. Label layers use score's renderer and stable ID colors or a selected RGB color.
- Reference ROI outlines that can be hidden; no temporal geometry is inferred.
- Frame number, slider and previous/next actions. Zoom survives temporal navigation of the same view.
- Independent Projects, Image, Display, Pipeline, Objects and Data widgets, with native detachment/redocking and View menu commands. Document X hides its retained controls and drafts; View restores it, including floating placement. Application/project closure keeps explicit unsaved-edit protection. Layout migration preserves older arrangements and initializes newly added documents hidden.
- Pipeline has a compact Open/Recent tree at the top, a graph below, then two equal New Run/Settings buttons and status. Template selection activates its retained draft; selecting a project run in Projects displays its frozen graph, with run ID · pipeline name in the header. Use Pipeline is available from that header's context menu and the Run Settings > Runs footer. The main widget has no duplicate template dropdown or nested Pipeline/Runs/Pipelines tabs. The dialog retains its internal configuration picker and Run/Steps/Checks/Runs tools. New Run/common settings open this shared dialog; Advanced uses `pipeline2` with the same run identity and configuration. Execution/remote monitoring and the richer editor remain transitional bridges. See `DETECTIVE_UI_PIPELINE.md`.
- Pipeline distinguishes Parameter Bindings, Run Parameters and staged Static Parameters. Bindings show direction/resource, exact symbolic value and Pipeline/This Run scope; dashed graph links expose shared-contract resource references alongside declared execution edges without resolving or rewriting them. Typed static controls support the native scalar/choice/matrix subset, Apply/Cancel and stale-dialog guards. Specialized concrete-resource inventory selectors, classifier/artifact linkage and complex editors remain in Advanced/pipeline2.
- Objects has a compact family/layer browser and current-frame label/track/parent/state table, with Contours/Tracks as contextual assistant tabs inside its independent document. Selecting a family enables multicolor image selection/editing while Display retains its active channel and settings. Same-provider families retain separate IDs, exact uint64 tracks and one shared annotation draft/history/save controller. See `DETECTIVE_UI_OBJECTS.md`.
- Data reuses Score's dataseries plotting below Image, with variable/group selection and synchronized frame markers/navigation. View > Arrange Analysis Workspace exposes Display/Objects alongside the shared image and its lower data plot. Compact Display keeps a 100-pixel Layers area; the `Hist.` button controls its detailed plot, with explicit choices retained for the session.
- Edit > Define ROIs... and the image/Projects context menus open the contextual assistant on the main raw image. Its tab is absent at launch; Done removes it and drawing handles while retaining the draft. Manual/Pattern/Grid definitions use existing backends; pipeline ROI commands reuse this assistant instead of opening Workflow. Save Project writes lightweight JSON metadata without extracting/saving ROI pixels. See `DETECTIVE_UI_ROIS.md`.
- Image browsing reuses Score's Left/Right Arrow and configurable ten-frame jump keys (L/M by default), with focus isolation, clamped frame bounds and float/redock support. Navigate shows the keys; Help > Keyboard Shortcuts... lists available actions. Annotation/painting keys remain reserved for their respective editors. See `DETECTIVE_UI_SHORTCUTS.md`.
- Edit > Edit Contours... opens a contextual indexed-mask assistant on Image: selection, polygon/freehand, boundary editing, brush/eraser, fill/delete, undo/redo and Score keyboard preferences. Drafts are isolated from canonical ROI pixels/model/data until Save Masks, retained across navigation, and guarded on normal closure. Persistence reuses ROI and Score helpers; partial-file failures remain dirty/retryable. See `DETECTIVE_UI_CONTOURS.md`.
- Edit > Edit Tracks... opens the provider/family inspector and linking assistant. Scoped reassignment/new tracks, whole-track swaps/deletion and parent selection reuse the same cellModel operations as Score. Parent/continuity picks can cross frames while retaining their source context. Contours/Tracks share selection, bounded model/pixel history, explicit persistence and close protection; model-only edits preserve the image H5. See `DETECTIVE_UI_TRACKS.md`.
- Run parameters with simple supported types can be edited in Pipeline without changing its template. Drafts are separate per project/template and pass through the existing run context to validation and the advanced editor. Details opens the run review (Summary, Steps, Issues) in the settings dialog, loaded only on request through `pipelineRunReview`.
- Concise English labels, native MATLAB tooltips and a bottom status bar. There is no permanent explanatory or onboarding text.
- Copy Image uses MATLAB `copygraphics` on the displayed axes. The automated smoke test does not overwrite the user's clipboard.

On demand, the session uses existing `fov.readImage` and `roi.load('Data',false)`. ROI loading can load a whole extraction and update in-memory display metadata. A missing recorded raw source is reported before invoking the legacy reader's automatic root search. Direct path checks and successful image reads remain synchronous after an explicit image request; an unavailable network filesystem can therefore still delay that requested read. Startup does no image I/O. Browsing does not save, extract or process scientific data. Closing a project only removes its UI reference.

## Limits

The current interface is an exploration prototype. Managed Annotation/Review, full classifier/processor management, complete native pipeline editor/execution parity, guided segmentation, cross-session display presets and lazy reconstruction of non-extracted ROIs remain incomplete. Native binding/static editing covers the documented subset; specialized selectors still use the established advanced editor. A three-plane logical channel is displayed as RGB; other multi-plane groups are exposed individually. Outlines use the same reference rectangles as workflow; mobile trajectories are not reconstructed.

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
detecdivui.pipelineBindingsTest();
detecdivui.pipelineBindingUITest();
detecdivui.staticParameterDialogTest();
detecdivui.objectsTest();
detecdivui.analysisLayoutTest();
% Optional visible export for visual inspection:
detecdivui.smokeTest(fullfile(tempdir, 'detective-ui-desktop.png'));
```

The smoke test creates temporary TIFFs and in-memory ROIs. It exercises pixels, logical/RGB channels, image/contrast limits, outlines, timeline, failed-read recovery, menu callbacks, tree selection, multiple projects, duplicate opening, closing active/inactive/last projects and empty projects. It does not yet validate real acquisitions or extracted H5 data. The optional PNG export briefly shows the window.

Validated on 4 November 2026 with MATLAB R2026a: smoke test passed, Code Analyzer clean for the entry point and package, and the exported desktop window inspected visually with two projects open.

The 6 November tranche passed native binding/static, Objects/Data, Contours/Tracks, close/docking and live-display checks, plus a combined workspace visual check. Startup fault recovery and multi-viewer cleanup also passed after native teardown was guarded against other hosts' menu polling. Code Analyzer was clean. These exercise synthetic local fixtures and existing helpers; they do not establish complete Score/pipeline2 parity, real inference performance or every optional external dependency.

## Docking and layout preferences

See `DETECTIVE_UI_DOCKING.md` for the internal API boundary, classic menu adapter, JSON layout contract and test scope. Preferences default to `fullfile(prefdir, 'DetecDiv', 'ui-layout-r2026a.json')`. Use `'LayoutFile', '', 'AutoSaveLayout', false` to isolate a temporary session.

`viewer.Figure` refers to the Image widget figure. Use `viewer.widgetFigure('Projects')` and `viewer.widgetFigure('Display')` for the other native component trees. `viewer.Host` exposes explicit docking and layout methods.

## Next implementation tranche

### Classifier workspace (9 November 2026)

Classifier is an independent native dockable document, exposed by File > Open
Classifier and View > Classifier. Projects contains projects/FOVs/ROIs and
processors; classifiers are discovered in the separate widget. A compact selector
chooses the open classifier. Its dataset table lists ROI index, ID, editable
Training/Test/Validation membership, inclusive frame bounds, annotation status
and reviewed coverage. Selecting a classifier opens its first ROI;
selecting a ROI uses the central image tabs and shared Display/Objects/Data.
Discovery only reads metadata and reports unchecked annotation status explicitly;
opening/selecting a classifier, selecting a ROI or pressing Refresh checks its
annotations through annotationManager, with scoped progress. Inclusive bounds
use trainingBounds.resolve/setRoi/parse and honor global Auto bounds. Set edits
use classi.setRoiSet to synchronize legacy trainingset and dataset.split while
preserving other ROIs' validation membership. Invalid edits restore canonical
values; edits from a stale classifier/ROI binding cannot affect the new context.
A transient Session projection adapts the legacy
image controllers to a classifier's flat ROI collection. It is never listed or
saved as a project, and cannot be used for project pipeline execution, relinking,
or FOV ROI construction. No classifier becomes a child of a project.

The widget shows package, category, inference/training functions, output type,
description, classes and separate training/inference static-parameter and binding
views. Review is the default; Edit enables dataset/configuration/annotation
changes. Package-described typed controls and compatible resource dropdowns
stage changes until Apply; Save reuses classiSave. Ground truth can be opened
or initialized through annotationManager without overwriting existing assets.
Specialized bindings and operations retain the existing Advanced editor.
See [DETECTIVE_UI_CLASSIFIER.md](DETECTIVE_UI_CLASSIFIER.md). Native parameter Apply/Save
is blocked while that editor is open. Refresh reconciles ROI membership after
legacy dataset changes. Closing the document hides controls and retains context.
Existing layout files gain the optional Classifier widget without a reset.

ClassifierGUI migration inventory, based on
`structure/GUI/classifier/private/classifierGUI_runtime_code.m`:

| Existing area | Integrated here | Remaining migration |
| --- | --- | --- |
| Classifier properties / package configuration | Metadata and typed common properties | Package/type changes, model-specific output/postprocessing selectors |
| Training parameters and bindings | Separate static/binding views, typed controls, resource catalog, common/advanced settings | Specialized package input editors and structured values |
| Dataset preparation | ROI table, canonical handles and synchronized split editing | Import/removal, remapping, formatting and missing-ROI checks |
| Annotation and frame bounds | Review/Edit, status/coverage, persistent bounds, shared image/Objects editing, blank/source-based annotationManager GT initialization | Batch/partial-GT repair, validation/approval and model-assisted prediction |
| Training and validation | Advanced compatibility entry | Existing training/validation pipelines, target selection, logs and curves |
| Runtime export | Advanced compatibility entry | Package-specific checksum/release validation and export UI |

Do not invoke training or formatting automatically while browsing. Preserve
the existing package contracts and annotationManager rather than reproducing
those rules in widget callbacks. `classifierWidgetTest`, `fileToolsTest`, and
`workspaceTest` cover the new browser boundary and source identity.

The complete Score review and staged migration dependencies are in [DETECTIVE_UI_SCORE_PARITY.md](DETECTIVE_UI_SCORE_PARITY.md), backed by a reproducible source inventory. Objects, Contours and Tracks now share scientific drafts/save/undo independently of Display. The dockable read-only Data browser and Tracks lineage dialog reuse Score's plotting and tree renderers; see [DETECTIVE_UI_DATA.md](DETECTIVE_UI_DATA.md) and [DETECTIVE_UI_TRACKS.md](DETECTIVE_UI_TRACKS.md).

The intent bridge now provides metadata-only resource inspection, five curated intent profiles, added/reused/input states in the Pipeline graph, independent effective-configuration forks and run-linked proposal provenance. Use Edit > Plan Workflow... or Pipeline > Plan...; see [DETECTIVE_UI_INTENT_WORKFLOWS.md](DETECTIVE_UI_INTENT_WORKFLOWS.md). The next bridge tranche is common method configuration/binding and validation, then task-triggered execution and full semantic history. Automatic launch is not implemented by this first planner. Missing model artifacts and unverified results must remain explicit prerequisites.

Movie/sequence export, managed Annotation/Review and Data editing remain on the parity roadmap. Export must freeze the visible layer and draft settings and report progress without changing the interactive canvas.

Validate the layered display and main-image ROI assistant on real data, then connect classifier management and selection before guided segmentation. Projects keeps the project/FOV/ROI hierarchy, the Processors collection and project context/run list. Classifier owns its independent library, ROI dataset and common parameters. Pipeline owns its top open/recent tree, compact graph, shared settings dialog and bridged `pipeline2` editor. `recentPipelinesTest` checks the compatible history store; `pipelineLibraryTest` checks single-click opening, draft reuse and missing-entry behavior; `projectRunsTest` checks project-owned run selection and frozen graph reuse. See `DETECTIVE_UI_PIPELINE.md` and `DETECTIVE_UI_DISPLAY.md`. Follow `DETECTIVE_UI_GUIDELINES.md`: conventional desktop menus, English, DetecDiv terminology, a multi-project tree and contextual help through tooltips/status rather than permanent explanatory paragraphs.

Uncommitted fixes in the initial DetecDiv checkout have not been imported into this worktree; compare them before adapting affected loading/display code.
