# Pipeline: compact control, shared run settings

The dockable widget is a compact control surface. New Run and Settings open one modeless Run Settings dialog; Advanced opens the existing pipeline2 frontend. These are views of the current configuration, not independent parameter copies.

## Compact widget

- Select an independent pipeline template from the workspace/browser, or File > Open Pipeline....
- New Run starts a fresh draft and opens Run Settings. Settings reopens the current configuration.
- The run selector switches between Draft and project-linked runs. The main graph shows the selected template/draft or the run's saved pipelineSpec snapshot, with statuses from the shared review helper.
- Click a block for its settings/details. Step inclusion checkboxes live in the settings dialog, not the compact graph.
- The status line follows the selected live pipelineRun handle. A lightweight timer reads in-memory status/message only; it does not read images, scan folders or poll the Hub at startup. Refresh reads the selected run review through pipelineRunReview; Details opens Summary/Steps/Issues and the existing inspector.
- Image remains central. Pipeline and Display retain native docking and existing saved layouts.

## Run Settings

The Run page has aligned labels/fields for run ID, source, FOV/ROI/frames, resume/restart, output policy, device, execution target and description. Fields use the same RunSetup controls and RunDraft as checking, saving and Advanced. Done hides the dialog and keeps the session draft. There is no second Apply/Cancel parameter store.

Steps contains graph/list, effective parameters and Validate/Dry Run. Basic finite scalar numbers, booleans, text and choices remain editable according to pipelineParamScope. Arrays, structured bindings and template design editing are available in Advanced. Imported advanced run overrides retain their exact node IDs and values, including complex values; backend validation remains authoritative. Basic edits/reset retain their original type checks.

Define ROIs on an ROI definition step opens the ROIs assistant on the main image. It edits a working template definition; Use in Run does not generate/extract project data. The original workspace template remains unchanged until an explicit template Save. Refresh Workspace does not replace the active working definition with an older alias pointing at the same template folder.

## Shared Advanced configuration

Planned connection centralization is specified in [DETECTIVE_UI_HUB.md](DETECTIVE_UI_HUB.md). The current advanced bridge still uses pipeline2's Hub controls. Its future viewer path must consume the independent shared Hub session and keep run-specific execution settings; no separate connection form per execution widget.

Advanced uses pipeline2 with EditExistingRun and a viewer bridge. Opening it preserves the current run ID, progress policy, output policy, selection and overrides. An automatic ID is chosen without creating a run folder. A saved run is passed as its canonical project-linked handle, preserving execution/history identity.

The bridge exports metadata/parameters only, without buildRunContext's image/ROI inventory scans. Closing Advanced through its window close action, or Viewer > Apply Settings and Return, applies its current settings to the viewer. Opening common settings/checking/saving also imports an idle open editor before continuing. Graph/design changes become a working template copy; template JSON is written only by explicit Save. Hub/control/runtime settings not exposed in the common form remain in the draft context.

If an advanced run is active, its window keeps its own run monitor/cancel controls. Changing context detaches its viewer bridge without stopping the job. The compact UI refuses to reopen/overwrite an active run as a second editable execution; choose New Run or use its existing advanced window. Closing the viewer disposes idle child windows and the follow timer, while an active advanced monitor remains independent.

Viewer-launched ROI editor commands route to the same main-image assistant. Pattern library selection remains available; editing a library draft routes to the main assistant. Standalone/legacy pipeline2 retains its previous Workflow behaviour for compatibility. The viewer bridge does not add another execution engine or submit a job by opening a settings window.

## Persistence and boundaries

Save Run reuses pipelineRunNew/pipelineRunSave and saves the lightweight project inventory so reopening its JSON restores the run reference. This metadata save does not write or clear ROI pixels. A new saved configuration has status new, exact selectedNodes/overrides and a pipelineSpec snapshot; live project/FOV/ROI handles and pixels are excluded. Saving the same unexecuted run updates that run instead of duplicating it. Runs with execution history require New Run or Advanced's established resume/edit flow. Existing folders/IDs are protected when creating another run.

Template Save remains separate from run Save. Drafts/settings are retained per project/template for the viewer session; closing a project forgets them. Runtime templates remain independent of shallow and pipelineRun remains project-linked history. No engine, model runtime or worker changes are included here.

## Scripted use and checks

```matlab
viewer.Pipeline.addTemplate(pipeObj);
viewer.Pipeline.newRun();
viewer.Pipeline.openSettings('Steps');
viewer.openROITool();

detecdivui.separationTest();
detecdivui.runDraftTest();
detecdivui.pipelineSettingsTest('',true);
detecdivui.newRunTest('',true);
detecdivui.progressTest();
detecdivui.dockingTest();
```

Tests cover native controls/shapes, Advanced round-trip with the same run ID, definition transfer from Advanced to the main image, run identity, untouched source pixels/template, metadata-only project saving, status following and pattern preview isolation. They use temporary TIFF/JSON data; no real inference or Hub job is launched. See DETECTIVE_UI_ROIS.md and DETECTIVE_UI_PROGRESS.md.
