# Pipeline: compact control, shared run settings

The dockable widget is a compact control surface. New Run and Settings open one modeless Run Settings dialog; Advanced opens the existing pipeline2 frontend. These are views of the current configuration, not independent parameter copies.

The accepted target is a compact control surface plus a larger dockable editor in the same workspace, progressively replacing the pipeline2 frontend without reducing its features. The current Designer/Advanced windows remain compatibility bridges. The capability matrix, reusable entry points, remaining gaps and cutover gates are in [DETECTIVE_UI_PIPELINE_PARITY.md](DETECTIVE_UI_PIPELINE_PARITY.md); no complete replacement editor is claimed here.

## Compact widget

- A compact Open/Recent tree stays at the top of Pipeline. Click an open template to display its retained draft below; click a recent entry to open it and add it to Open. File / Pipeline > Open Pipeline... remains available. Workspace discovery contributes live pipeline handles to Open. Pipeline definitions stay independent of the Projects browser.
- The main widget has one graph below the tree, without a template dropdown or nested Pipeline/Runs/Pipelines tabs. New Run and Settings sit below the graph. Module labels use the available card width, shortening only when necessary to fit.
- Project-linked runs belong in the bottom context panel of Projects, alongside the project name and copyable path. The run list replaces the former count table and follows the selected project/FOV/ROI. Select a run there to display its frozen graph and run identity in Pipeline, even without an open template. Startup and project switching do not automatically select a saved run. Selecting an open/recent template returns to its editable Draft without changing the project or historical runs.
- Use Pipeline is available from the saved-run graph header's context menu and the Run Settings > Runs footer; the main graph footer keeps only New Run and Settings. Use Pipeline creates an independent, pathless editable copy of the selected run's saved pipeline, baking in its effective parameter overrides and preserving its selected steps/settings. Historical runs and their worker/template paths are preserved. Those historical paths are provenance, never automatic save destinations. A run without a snapshot remains inspectable; its source template must be opened explicitly.
- New Run starts a fresh draft and opens Run Settings. Settings reopens the current configuration.
- The graph header shows the template name for Draft, or run ID · pipeline name for a saved run's pipelineSpec snapshot. Saved-run statuses come from the shared review helper; selecting a run does not silently turn it into an editable template.
- Click a block for its settings/details. Step inclusion checkboxes live in the settings dialog, not the compact graph.
- Graph arrows use actual source/target IDs and ports. Solid links show declared execution flow; dashed links show symbolic resource bindings from the shared module contracts and stored binding values, including references that are not duplicated in the declared execution edges. Adjacent downstream modules connect from bottom to top; skip links, branches, backward links and self-loops use separate side routes. Overlapping vertical spans never share a side trunk. Clicking a link highlights its route/endpoints and shows the exact source-port → target-port in the status bar. Missing or ambiguous module references are reported rather than connected to a guessed module. Derived binding links remain view metadata: drawing never changes stored nodes/edges, resolves runtime values or invents a sequential chain.
- The status line follows the selected live pipelineRun handle. A lightweight timer reads in-memory status/message only; it does not read images, scan folders or poll the Hub at startup. Explicit Refresh / Pipeline > Refresh Project Runs discovers run.json files one level below the project's pipeline folder through pipelineRunLoad, without replacing already loaded canonical handles or saving the project. It then reviews the selected run through pipelineRunReview. Details opens Summary/Steps/Issues and the existing inspector.
- Image remains central. Pipeline and Display retain native docking and existing saved layouts.

Recreate the viewer after this structural layout change. Named callback rebinding preserves supported live links, but does not promise arbitrary hot replacement of native controls or layouts. The earlier empty-tab recovery remains a compatibility concern for already-created tabbed widgets, rather than a reason to keep nested tabs in the new interface.

## Open and recent pipelines

The Open/Recent tree is always visible above the graph. Single-clicking an entry activates its existing handle/draft or loads the recent file. Copy Pipeline Path is available from the tree context menu. Recent hides paths already listed under Open while preserving the persisted MRU history. Reopening an already-open path reuses its current handle and session draft rather than reloading over unsaved settings. The pipeline definition remains independent of the project: selecting it does not change the current project/FOV or the project's run history.

Recent history reuses `prefdir/recentPipelines.mat` with the classic `RecentPipelines` string-array variable and merges pipeline2's existing `DetecDiv/pipeline2RecentPipelines` preference for the default store. Successful explicit opening, reuse or saving updates the MRU list; Clear Recent Pipelines in the tree context menu clears history without closing open templates. At startup the list is metadata only: no recent pipeline is automatically opened, and referenced files/drives are not probed. A failed explicit open keeps the active pipeline/draft and retains its unavailable history entry.

Use `detecdiv_ui(...,'RecentPipelinesFile','')` for isolated in-memory history, or supply a temporary MAT path for persistence tests. These injected stores do not read or write the shared legacy preference. The larger Designer/Advanced windows remain transitional pipeline2 bridges; moving the library does not claim a full native editor replacement.

## Independent pipeline design and Process menu

File / Pipeline > New Pipeline and Pipeline > Edit Pipeline open pipeline2 as a project-independent Pipeline Designer. It uses the same module catalogue, graph editor and serialization helpers. Its viewer bridge disables run creation/execution, does not publish or overwrite base-workspace variables, and returns an edited template copy without applying runtime output policies to template parameters. Source handles remain unchanged; Save Pipeline explicitly chooses a location for a new definition. A definition remains editable with no project open.

Process exposes Define ROIs, Segment Cells, Track Cells, Measure Signals, Analyze Cavity Trajectory and Plan Workflow. The scientific intents open the shared planner with that goal already selected. They inspect project state and show proposed additions/reuse in Pipeline; they do not imply that processing has started. Define ROIs opens the existing contextual assistant on the main image.

## Run Settings

The dialog retains its internal Run, Steps, Checks and Runs tools and configuration picker; only the main widget's nested navigation tabs are removed. The Run page has aligned labels/fields for run ID, source, FOV/ROI/frames, resume/restart, output policy, device, execution target and description. Fields use the same RunSetup controls and RunDraft as checking, saving and Advanced. Done hides the dialog and keeps the session draft. Module static edits have their own staged Apply/Cancel dialog, rather than another run configuration store.

Steps contains graph/list, Parameter Bindings, Run Parameters, Static Parameters and Validate/Dry Run. Edit Module and Change Type act on the selected step, opening Pipeline Designer directly on its module tab; Change Type uses pipeline2's existing module catalogue and replacement/defaults logic. The same actions are available by right-clicking a module in the compact, settings or saved-run graph. A historical run is forked before definition editing. Module replacement preserves its ID and declared graph links/ports; contract validation reports links that need reconnecting rather than inferring a different graph from block positions.

Parameter kind and value scope are separate concepts. Static parameters configure a module; bindings name the resources it consumes or produces. A binding can belong to the Pipeline definition or, where `pipelineParamScope` allows it, be overridden for This Run. The native bindings table shows Input/Output, resource, exact stored value and scope; a run override is marked `This Run *`. Apply updates the selected scope, while Reset removes that run override. Applying a Pipeline value creates a protected working definition and removes the superseded override for that parameter, preserving unrelated settings and overrides.

Bindings keep symbolic values such as `@resource:segmentation:segment_cells`, `@load.channels` and dataseries-variable suffixes intact. Compatible module-output choices come from `pipelineNodeContract` metadata; displayed labels are converted through the existing `pipelineSymbolicBindingFromLabel` helper. Browsing/editing does not resolve them to execution-time channel names or load source images/models. `pipelinePhysicalResourceOutputName` supplies the shared physical-name convention for choice labels; it does not replace the stored symbolic reference. Full classifier/artifact linkage, lazy concrete channel/dataseries inventory discovery, component selection and complex binding editors remain in Advanced/pipeline2.

Static Parameters opens `StaticParameterDialog` for contract-declared module settings. Booleans, finite numbers, text and legacy choice cells receive native typed controls; existing numeric matrices use an editable table, and empty numeric arrays accept numeric JSON without evaluating MATLAB expressions. Structured values and integers outside exact editable-double precision remain unchanged and readonly, with Edit Module available for the richer editor. Opening, changing controls or cancelling does not change the source pipeline. Apply validates types, then transfers only changed static keys into the working definition. The reply checks the original project, pipeline handle, definition revision and node signature; a stale dialog stays open with an actionable status instead of editing a different definition. Saving JSON remains explicit.

Other basic run parameters remain editable in Run Parameters according to `pipelineParamScope`. Returning from the designer retains the draft's run settings and unrelated overrides; replacement clears the old module's overrides, and explicitly edited template values supersede their old overrides. Viewer > Discard Changes and Return abandons designer edits. Apply Settings and Return, or closing the designer, applies the working definition; writing JSON still requires an explicit Save. Imported advanced run overrides retain their exact node IDs and values, including complex values; backend validation remains authoritative. Basic edits/reset retain their original type checks.

Define ROIs on an ROI definition step opens the ROIs assistant on the main image. It edits a working template definition; Use in Run does not generate/extract project data. The original workspace template remains unchanged until an explicit template Save. Refresh Workspace does not replace the active working definition with an older alias pointing at the same template folder.

## Shared Advanced configuration

Planned connection centralization is specified in [DETECTIVE_UI_HUB.md](DETECTIVE_UI_HUB.md). The current advanced bridge still uses pipeline2's Hub controls. Its future viewer path must consume the independent shared Hub session and keep run-specific execution settings; no separate connection form per execution widget.

Advanced uses pipeline2 with EditExistingRun and a viewer bridge. Opening it preserves the current run ID, progress policy, output policy, selection and overrides. An automatic ID is chosen without creating a run folder. A saved run is passed as its canonical project-linked handle, preserving execution/history identity.

The bridge exports metadata/parameters only, without buildRunContext's image/ROI inventory scans. Closing Advanced through its window close action, or Viewer > Apply Settings and Return, applies its current settings to the viewer. Opening common settings/checking/saving also imports an idle open editor before continuing. Graph/design changes become a working template copy; template JSON is written only by explicit Save. Hub/control/runtime settings not exposed in the common form remain in the draft context.

If an advanced run is active, its window keeps its own run monitor/cancel controls. Changing context detaches its viewer bridge without stopping the job. The compact UI refuses to reopen/overwrite an active run as a second editable execution; choose New Run or use its existing advanced window. Closing the viewer disposes idle child windows and the follow timer, while an active advanced monitor remains independent.

Viewer-launched ROI editor commands route to the same main-image assistant. Pattern library selection remains available; editing a library draft routes to the main assistant. Standalone/legacy pipeline2 retains its previous Workflow behaviour for compatibility. The viewer bridge does not add another execution engine or submit a job by opening a settings window.

This route now includes the definition-only Designer: its image tools use the current viewer project as an explicit preview association without binding that project to the independent pipeline definition. The main breadcrumb and ROI target show the pipeline/module being edited. Effective module/run FOV selections are resolved before opening the tool, including named project FOVs. The editor remains available while Image is used, and a missing FOV/source never hides it or silently substitutes an unrelated raw acquisition. Parsing a new raw acquisition directly into this temporary image context remains a migration gap; the legacy parser is still available through standalone pipeline2.

ROI replies check the editor lifetime, template/run identity, module contents, effective runtime parameters/selections and target project/FOV. Closing/changing the owner or navigating to another FOV invalidates the old reply; navigation dismisses the bound tool rather than turning its Apply button into a standalone Create operation. Accepted run-scoped ROI parameters update the existing override records as well as the working definition, so old frame/channel/FOV overrides cannot shadow the accepted edit. Draft geometry is retained separately for each owner/module request and separately from standalone drawing.

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
detecdivui.projectRunsTest();
detecdivui.pipelineGraphTest();
detecdivui.moduleEditingTest();
detecdivui.pipelineImageContextTest();
detecdivui.pipelineTabTest();
detecdivui.recentPipelinesTest();
detecdivui.pipelineLibraryTest();
detecdivui.pipelineBindingsTest();
detecdivui.staticParameterDialogTest();
detecdivui.pipelineBindingUITest();
detecdivui.progressTest();
detecdivui.dockingTest();
```

Tests cover native controls/shapes, Advanced round-trip with the same run ID, definition transfer from Advanced to the main image, run identity, untouched source pixels/template, metadata-only project saving, status following and pattern preview isolation. They use temporary TIFF/JSON data; no real inference or Hub job is launched. See DETECTIVE_UI_ROIS.md and DETECTIVE_UI_PROGRESS.md.

pipelineGraphTest additionally checks actual line/arrow endpoints against the source and target block boundaries, shuffled edge storage, overlapping branches, backward/self/parallel links, resource-link styles, port inspection, stale clicks, missing references and container resizing without a redraw. The renderer preserves stored node order and links; layout and highlighted routes are view state only.

The binding/static regression entry points check the distinction between kind and scope, exact symbolic references and ports, derived links without topology mutation, typed staged values and their original classes, Apply/Cancel, protected source definitions and stale-dialog rejection. They cover the native subset described above, not complete pipeline2 binding/editor parity.
