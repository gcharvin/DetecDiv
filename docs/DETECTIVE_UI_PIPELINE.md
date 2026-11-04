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
- Steps shows template order, type and enabled state. Selecting a step displays its stored parameters and their template/run scope via `pipelineParamScope`. Large arrays and objects are summarized instead of dumped into cells. This first parameter inspector is read-only.
- Current FOV, Current ROI and Whole project define the validation target from the active project/browser selection. A missing FOV/ROI produces an actionable check error instead of silently checking the entire project. Checks without a project remain available for templates that do not need one. These checks cover all frames, not just the frame displayed in Image.
- Validate calls `validatePipeline`; Dry Run calls `runPipelineDry` with GUI completion disabled. Checks displays backend errors/warnings and the status bar reports the outcome. Changing target/template invalidates the previous report.
- Runs uses the template's existing `findDependentRuns` method to list the active project's linked `pipelineRun` objects and statuses. Inspect opens the existing `pipelineRunInspector` for reports, events, parameters and execution scope. Refresh rereads the live objects, without a disk scan.
- Editor opens the existing `pipeline2` frontend with the selected template, project and available FOV/ROI scope. Graph construction, parameter editing, classifier bindings, run policies, local/Hub submission, monitoring and cancellation stay with that established frontend for this tranche. No processing is launched by merely opening it. After saving edits there, use Open to reload the saved JSON into this widget; Refresh only rereads live handles.

There are no placeholder Run/Stop buttons in this first widget. Bringing run configuration and monitoring into the main window remains the next integration; this widget does not create a second execution engine or reinterpret execution policies.

## Data boundaries

Templates remain independent of `shallow`. A `pipelineRun` belongs to execution history, and is never substituted for its template. Browsing and checking do not create runs, save projects or alter H5 data. The UI passes a value snapshot to checking because the shared binding resolver can update handle templates. Backend module validation hooks retain their existing behavior.

No engine, module, Python runtime or worker deployment is changed here. File writes occur only through explicit Save and existing advanced-editor actions.

## Validation

```matlab
detecdivui.pipelineTest();
detecdivui.pipelineTest('',true); % Also verify the existing advanced-editor handoff.
detecdivui.dockingTest();
detecdivui.workspaceTest();
detecdivui.smokeTest();
```

The pipeline test checks real controls, relative custom-module code resolution, no function execution during checks, template/pixel immutability, target selection, JSON save/load, project-linked run history, preserved control handles after docking, floating-layout restore and migration from a three-widget v1 layout. Advanced-editor execution is reused, not revalidated against a real acquisition by these UI tests.
