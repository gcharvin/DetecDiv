# DetecDiv UI — MATLAB prototype

## Launch

Use a MATLAB session dedicated to this worktree:

```matlab
cd('C:\Users\Gilles\Documents\MATLAB\Detective-UI');
detecdiv_setup_path(pwd, 'DetecDivRoot', pwd);
viewer = detecdiv_ui();
% Existing projects can also be supplied:
viewer = detecdiv_ui(projectA);
viewer.addProject(projectB);
% Or open multiple projects at launch:
viewer = detecdiv_ui({projectA, projectB});
```

`DetecDivRoot` must explicitly select this worktree: the path helper can otherwise choose the sibling DetecDiv checkout. The regular `detecdiv` entry point and existing MLAPPs are unchanged. The prototype layout is code-owned until interactions are validated, then will follow the App Designer / code-sync workflow.

## Current interface

- File, Edit, View, Navigate and Help menus, with standard open/close/copy accelerators.
- One Projects tree containing Project → FOV → ROI nodes. Multiple projects remain open; selecting a node updates the central image. Opening the same handle, stable project ID or project path focuses the existing project.
- Per-project FOV/ROI, frame and named-channel state. Closing a project restores another open project; closing the last project clears the viewport.
- Breadcrumb and parent-FOV navigation synchronized with tree and ROI-outline selection.
- Named logical channels, including non-contiguous RGB subchannels. Missing or incompatible channel metadata falls back to individual image planes.
- Reference ROI outlines that can be hidden; no temporal geometry is inferred.
- Frame number, slider and previous/next actions. Zoom survives temporal navigation of the same view.
- Collapsible Projects and Display panels, concise English labels, native MATLAB tooltips and a bottom status bar. There is no permanent explanatory or onboarding text.
- Copy Image uses MATLAB `copygraphics` on the displayed axes. The automated smoke test does not overwrite the user's clipboard.

The session uses existing `fov.readImage` and `roi.load('Data',false)`. ROI loading can load a whole extraction and update in-memory display metadata; the legacy raw reader can repair paths in memory. Browsing does not save, extract or process scientific data. Closing a project only removes its UI reference.

## Limits

The current interface is an exploration prototype. Scientific editing, classifier/processor/pipeline management, guided segmentation, compositing multiple channels, persisted contrast, caches and lazy reconstruction of non-extracted ROIs remain to be integrated. A three-plane logical channel is displayed as RGB; other multi-plane groups are exposed individually. Outlines use the same reference rectangles as workflow; mobile trajectories are not reconstructed.

Reading is synchronous. Monochrome contrast uses finite pixel min/max without changing pixel values. Project switching restores frame and channel but does not preserve an independent zoom for every FOV/ROI. Data is synthetic in the automated validation; real acquisitions and performance still need validation.

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
% Optional visible export for visual inspection:
detecdivui.smokeTest(fullfile(tempdir, 'detective-ui-desktop.png'));
```

The smoke test creates temporary TIFFs and in-memory ROIs. It exercises pixels, logical/RGB channels, image/contrast limits, outlines, timeline, failed-read recovery, menu callbacks, tree selection, multiple projects, duplicate opening, closing active/inactive/last projects and empty projects. It does not yet validate real acquisitions or extracted H5 data. The optional PNG export briefly shows the window.

Validated on 4 November 2026 with MATLAB R2026a: smoke test passed, Code Analyzer clean for the entry point and package, and the exported desktop window inspected visually with two projects open.

## Next implementation tranche

Validate browsing on real data, then integrate guided segmentation and its inspectable pipeline. Follow `DETECTIVE_UI_GUIDELINES.md`: conventional desktop menus, English, DetecDiv terminology, a multi-project tree and contextual help through tooltips/status rather than permanent explanatory paragraphs.

Uncommitted fixes in the initial DetecDiv checkout have not been imported into this worktree; compare them before adapting affected loading/display code.
