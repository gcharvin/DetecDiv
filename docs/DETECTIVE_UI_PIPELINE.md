# Pipeline widget

## Use

Open **View > Pipeline**, select an independent `pipeline` from the workspace, or use **File > Open Pipeline...** / **Open...** to load its JSON. Selecting a template in the Projects browser also focuses the widget. For scripted use:

```matlab
viewer.Pipeline.addTemplate(pipeObj);
viewer.Pipeline.openTemplate(fullfile(templateFolder,'pipeline.json'));
viewer.Host.focusWidget('Pipeline');
```

The image remains central. In a fresh layout, Pipeline and Display share tabs on the right; both remain independently dockable. Existing three-widget layouts retain their arrangement and initially hide Pipeline. Show it through View, position it and save the layout.

## Controls

- The selector keeps multiple independent templates. Open uses `pipelineLoad`; Save uses `pipelineSave`. Loading the same folder updates its entry instead of duplicating it.
- Steps defaults to a compact vertical graph with coloured blocks and the template's real dependency arrows. The graph scrolls without shrinking long pipelines into unreadable thumbnails. Click a block to inspect its parameters; use its checkbox to include/exclude it from this run. Disabled template nodes remain excluded. List retains the tabular view. Steps shows template order, type and run selection. Selecting a step displays effective parameters with readable labels and package help, reusing `classifierBinding.parameterSpecFromDefaults` and `pipelineParamScope`. Large arrays and objects are summarized instead of dumped into cells.
- Select a run-scoped parameter to edit a finite scalar number, boolean, text or legacy choice payload in the widget. Apply changes the run draft; Reset restores the template value. `run *` identifies an override. Template/design parameters, arrays and structured values remain available through Editor. The shared contract determines scope, including fixed design settings such as grid count or pattern threshold.
- Current FOV, Current ROI and Whole project define the validation target from the active project/browser selection. A missing FOV/ROI produces an actionable check error instead of silently checking the entire project. Checks without a project remain available for templates that do not need one. These checks use the run frame selection (all by default), independently of the frame displayed in Image.
- Validate calls `validatePipeline`; Dry Run calls `runPipelineDry` with GUI completion disabled. Checks displays backend errors/warnings and the status bar reports the outcome. Changing target/template invalidates the previous report.
- Runs uses the template's existing `findDependentRuns` method to list the active project's linked `pipelineRun` objects and statuses. Selecting a run shows its in-memory metadata. Review calls `pipelineRunReview` on demand and displays Summary, Steps and Issues inside Pipeline, including the backend's latest-attempt semantics. Reviews are cached until Refresh or a context change. No review file is written. More opens the existing `pipelineRunInspector` for full reports, events, parameters and execution scope. Review may query the Hub if the existing backend needs it; there is no startup scan or automatic polling.
- Editor opens the existing `pipeline2` frontend with the selected template, project and available FOV/ROI scope. Run overrides are passed as an unsaved `pipelineRun` seed; the existing editor creates a distinct run ID. Run progress/output choices are restored through its own callbacks, with resume/skip as defaults. A free explicit run ID is preserved; an already saved ID uses the editor's suggested new ID. Graph construction, complex parameter editing, classifier bindings, execution policies, local/Hub submission, monitoring and cancellation remain in that established frontend. No processing is launched by merely opening it. The existing project workspace alias is reused; an unbound project is published under a free name so unrelated variables are preserved. After saving edits there, use Open to reload the saved JSON; Refresh only rereads live handles.

New Run starts a fresh session draft, resets overrides and opens Run. Its scrollable form contains Run ID (automatic if empty), input mode/raw folder, FOV/ROI/frame selections, resume/restart, existing-output policy, device, execution target and description. Source selection is metadata-only. Numeric selectors accept comma lists and ranges; project FOV/ROI IDs resolve exactly, without evaluating MATLAB expressions. ROI IDs across multiple FOVs require consistent ROI indexing; use numeric indices or one FOV otherwise. Raw selections use numeric source indices. Invalid selections block checks/saving instead of falling back to all data.

Save Run calls pipelineRunNew and pipelineRunSave to create a new project-linked run.json with status new, selectedNodes, overrides and a pipelineSpec snapshot. It requires an existing project folder and refuses existing run IDs/folders. The saved snapshot excludes live project/FOV/ROI handles and pixels. No project images are loaded and no processing is launched. Existing project loading discovers these run folders. Changes after saving are a draft for a different run ID; New Run starts over.

Runs > Steps also offers Graph/List. The graph uses the run snapshot, not a subsequently edited template, and annotates nodes from pipelineRunReview. Legacy runs without a snapshot show event nodes without inventing dependency edges. Editor remains the execution entry point for local/WSL/Hub runs, detailed bindings, Hub configuration and cancellation; no placeholder Run/Stop command or second execution engine is added. Explicit run policies and output choices survive the handoff.

## Data boundaries

Templates remain independent of `shallow`. A `pipelineRun` belongs to execution history, and is never substituted for its template. Browsing and checking do not create runs, save projects or alter H5 data. The UI passes a value snapshot to checking because the shared binding resolver can update handle templates. Backend module validation hooks retain their existing behavior.

`RunDraft` keeps overrides per live project/template in this viewer session, using exact node IDs and `pipelineApplyRunNodeParams` for effective values. Switching projects preserves their independent settings. Closing a project drops its drafts; loading a replacement template drops drafts tied to the previous object. Template Save writes only the template. Drafts are not saved across viewer restarts. In-place changes that remove a parameter, change its scope/type or alter choice options invalidate the affected override; validation then requires a fresh review. Parameter editing checks basic types/ranges; module-specific validation still belongs to the shared backend.

No engine, module, Python runtime or worker deployment is changed here. File writes occur only through explicit template Save, Save Run and existing advanced-editor actions.

## Validation

```matlab
detecdivui.pipelineTest();
detecdivui.runDraftTest();
detecdivui.newRunTest();
detecdivui.newRunTest('',true); % Also verify explicit run settings in the advanced editor.
detecdivui.pipelineSettingsTest();
detecdivui.pipelineSettingsTest('',true); % Native settings handoff to the existing editor.
detecdivui.pipelineTest('',true); % Also verify the existing advanced-editor handoff.
detecdivui.dockingTest();
detecdivui.workspaceTest();
detecdivui.smokeTest();
```

The pipeline test checks real controls, relative custom-module code resolution, no function execution during checks, template/pixel immutability, target selection, JSON save/load, project-linked run history, preserved control handles after docking, floating-layout restore and migration from a three-widget v1 layout. Advanced-editor execution is reused, not revalidated against a real acquisition by these UI tests.
