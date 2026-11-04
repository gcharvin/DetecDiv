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
- Steps shows template order, type and enabled state. Selecting a step displays effective parameters with readable labels and package help, reusing `classifierBinding.parameterSpecFromDefaults` and `pipelineParamScope`. Large arrays and objects are summarized instead of dumped into cells.
- Select a run-scoped parameter to edit a finite scalar number, boolean, text or legacy choice payload in the widget. Apply changes the run draft; Reset restores the template value. `run *` identifies an override. Template/design parameters, arrays and structured values remain available through Editor. The shared contract determines scope, including fixed design settings such as grid count or pattern threshold.
- Current FOV, Current ROI and Whole project define the validation target from the active project/browser selection. A missing FOV/ROI produces an actionable check error instead of silently checking the entire project. Checks without a project remain available for templates that do not need one. These checks cover all frames, not just the frame displayed in Image.
- Validate calls `validatePipeline`; Dry Run calls `runPipelineDry` with GUI completion disabled. Checks displays backend errors/warnings and the status bar reports the outcome. Changing target/template invalidates the previous report.
- Runs uses the template's existing `findDependentRuns` method to list the active project's linked `pipelineRun` objects and statuses. Selecting a run shows its in-memory metadata. Review calls `pipelineRunReview` on demand and displays Summary, Steps and Issues inside Pipeline, including the backend's latest-attempt semantics. Reviews are cached until Refresh or a context change. No review file is written. More opens the existing `pipelineRunInspector` for full reports, events, parameters and execution scope. Review may query the Hub if the existing backend needs it; there is no startup scan or automatic polling.
- Editor opens the existing `pipeline2` frontend with the selected template, project and available FOV/ROI scope. Run overrides are passed as an unsaved `pipelineRun` seed; the existing editor creates a distinct run ID. Its ordinary resume/skip defaults are restored through its own callback, so editing a parameter does not implicitly recommend replacing outputs. Graph construction, complex parameter editing, classifier bindings, execution policies, local/Hub submission, monitoring and cancellation remain in that established frontend. No processing is launched by merely opening it. The existing project workspace alias is reused; an unbound project is published under a free name so unrelated variables are preserved. After saving edits there, use Open to reload the saved JSON; Refresh only rereads live handles.

There are no placeholder Run/Stop buttons in this first widget. Bringing run configuration and monitoring into the main window remains the next integration; this widget does not create a second execution engine or reinterpret execution policies.

## Data boundaries

Templates remain independent of `shallow`. A `pipelineRun` belongs to execution history, and is never substituted for its template. Browsing and checking do not create runs, save projects or alter H5 data. The UI passes a value snapshot to checking because the shared binding resolver can update handle templates. Backend module validation hooks retain their existing behavior.

`RunDraft` keeps overrides per live project/template in this viewer session, using exact node IDs and `pipelineApplyRunNodeParams` for effective values. Switching projects preserves their independent settings. Closing a project drops its drafts; loading a replacement template drops drafts tied to the previous object. Template Save writes only the template. Drafts are not saved across viewer restarts. In-place changes that remove a parameter, change its scope/type or alter choice options invalidate the affected override; validation then requires a fresh review. Parameter editing checks basic types/ranges; module-specific validation still belongs to the shared backend.

No engine, module, Python runtime or worker deployment is changed here. File writes occur only through explicit Save and existing advanced-editor actions.

## Validation

```matlab
detecdivui.pipelineTest();
detecdivui.runDraftTest();
detecdivui.pipelineSettingsTest();
detecdivui.pipelineSettingsTest('',true); % Native settings handoff to the existing editor.
detecdivui.pipelineTest('',true); % Also verify the existing advanced-editor handoff.
detecdivui.dockingTest();
detecdivui.workspaceTest();
detecdivui.smokeTest();
```

The pipeline test checks real controls, relative custom-module code resolution, no function execution during checks, template/pixel immutability, target selection, JSON save/load, project-linked run history, preserved control handles after docking, floating-layout restore and migration from a three-widget v1 layout. Advanced-editor execution is reused, not revalidated against a real acquisition by these UI tests.
