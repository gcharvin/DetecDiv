# Pipeline Batch Builder

Status: architecture note / proposed direction.

This note describes how DetecDiv should support batch execution of the same
pipeline over several independent projects or datasets, while reusing the
current project catalog, `pipeline2`, `pipelineRun`, and Hub execution model.

## 1. Problem

The current pipeline tooling is primarily centered on one concrete run:

- choose or build one pipeline template
- configure runtime parameters for one dataset or one project
- execute a `pipelineRun`
- produce one updated project and/or output files

This works well for interactive tuning and single-project execution. It is less
ergonomic when a user wants to apply the same pipeline to many independent
datasets or projects, where each item should produce its own project, run
folder, logs, artifacts, and status.

The target workflow is:

1. Select projects or datasets from a catalog.
2. Send the selection to a batch builder.
3. Choose a pipeline template.
4. Configure one prototype item using the existing `pipeline2` interface.
5. Propagate the runtime configuration to the rest of the selection.
6. Validate that every non-prototype item is compatible.
7. Submit the batch either locally or to DetecDiv Hub.
8. Monitor progress, logs, errors, and outputs from one batch-oriented UI.

The design goal is to add orchestration, not duplicate pipeline runtime logic.

## 2. Core principle

There should still be only one semantic definition of a pipeline run.

- `pipeline` remains the reusable template.
- `pipelineRun` remains the single-project execution instance.
- `runPipeline.m` remains the execution path for one configured run.
- The batch layer creates and supervises several pipeline runs.

The batch builder must not reimplement classifiers, processors, ROI extraction,
dataloading, or node execution. It should build run requests and delegate.

## 3. Proposed high-level flow

```text
Project / dataset catalog
        |
        | Send to batch
        v
Batch Builder UI
        |
        | choose pipeline
        | configure prototype through pipeline2
        v
Batch spec / batch run
        |
        | validate all items
        v
Local runner OR Hub runner
        |
        v
Batch monitor
```

## 4. Responsibilities

### Catalog

The existing project catalog is the natural selection surface.

It should provide:

- selectable local projects from the SQLite index
- selectable Hub projects when connected to the Hub
- eventually selectable raw datasets once a dataset catalog exists
- stable references for the selected entries
- a `Send to batch` action

The catalog should not become a pipeline configuration tool. Its responsibility
ends at producing a list of project or dataset references.

### Batch Builder

The batch builder is a dedicated UI and backend layer.

It should:

- receive selected project and dataset references
- let the user choose a pipeline template
- choose one prototype item
- open `pipeline2` in prototype/modal configuration mode
- receive a structured runtime configuration from `pipeline2`
- build one batch specification
- validate all items against the pipeline and runtime configuration
- allow item-level overrides when needed
- submit the batch locally or to the Hub
- open the batch monitor

It should not contain business logic for image processing or ROI detection.

### Pipeline2

`pipeline2` remains the detailed interactive pipeline/run configuration UI.

For batch usage, it should expose a prototype configuration mode:

```matlab
runtimeConfig = pipeline2ConfigurePrototype(pipelineTemplate, prototypeRef, options);
```

or an equivalent modal app contract:

```matlab
app = pipeline2(pipelineTemplate, prototypeCtx, ...
    "Mode", "prototype", ...
    "Modal", true);
runtimeConfig = app.RuntimeConfig;
```

The important contract is not the exact function name. The important contract is
that `pipeline2` returns a structured runtime configuration that can be reused
without scraping UI state.

### Local runner

The local runner should execute the batch item by item on the current machine.
For each item, it should build a normal `pipelineRun` context and call the
standard runtime.

Recommended entry point:

```matlab
report = runPipelineBatch(batchSpec, options);
```

Internally, this should call helpers similar to:

```matlab
ctx = buildPipelineBatchItemCtx(batchSpec, itemIndex);
itemReport = runPipeline(batchSpec.pipelineTemplate, ctx, runOptions);
```

### Hub runner

The Hub runner should submit the same batch semantics to DetecDiv Hub.

Recommended entry point:

```matlab
submission = submitPipelineBatchToHub(batchSpec, options);
```

The Hub should queue and execute individual pipeline run jobs, but keep their
relationship to the parent batch. The Hub should not reinterpret pipeline
business logic.

### Batch monitor

The monitor is a UI for progress and diagnostics.

It should support both local and Hub-backed batches through a common status
contract:

- item status
- current node
- progress summary
- last message
- error summary
- run id
- output project reference
- run log path or Hub log URI
- actions such as resume failed, cancel selected, open project, open log

The monitor can use a timer-based refresh model, as `pipeline2` already does for
run progress.

## 5. Batch concepts

### Batch spec

The batch specification is the portable declaration of what should be run.

Suggested logical shape:

```matlab
batchSpec.id
batchSpec.name
batchSpec.createdAt
batchSpec.createdBy

batchSpec.pipelineRef
batchSpec.pipelineTemplate
batchSpec.prototypeItemId
batchSpec.prototypeRuntimeConfig

batchSpec.items
batchSpec.execution
batchSpec.validation
```

For Hub or saved batch usage, this must be serializable. Avoid MATLAB handles in
the saved form. Use stable references, paths, IDs, and JSON-compatible structs.

### Batch item

Each item represents one target run.

Suggested shape:

```matlab
item.id
item.kind              % project | dataset
item.projectRef
item.datasetRef
item.displayName
item.localPathHint
item.hubProjectId
item.outputPolicy
item.outputProjectRef
item.runtimeOverrides
item.validation
item.status
```

An item may reference:

- an existing local project
- an existing Hub project
- a raw dataset that will create a project during the pipeline

The initial implementation can support project references first and add raw
dataset references later.

### Runtime configuration

The prototype runtime configuration is the reusable configuration produced by
`pipeline2`.

Suggested shape:

```matlab
runtimeConfig.selectedNodes
runtimeConfig.nodeParams
runtimeConfig.executionPolicies
runtimeConfig.selection
runtimeConfig.io
runtimeConfig.names
runtimeConfig.exec
runtimeConfig.validationState
```

Important fields:

- selected pipeline nodes
- node-level parameter overrides
- FOV/frame/channel/ROI selection semantics
- output names
- existing data policy
- resume/restart policy
- Python and GPU policy
- GUI/interactive policy

Server and batch execution should default to:

```matlab
runtimeConfig.exec.allowGUI = false;
runtimeConfig.exec.interactive = false;
```

The prototype item may have interactive tuning enabled, but the submitted batch
items should be non-interactive unless explicitly run locally in a user-approved
debug mode.

## 6. Relationship to existing project catalog

The current local SQLite project catalog can be used immediately as the first
selection source.

Existing catalog responsibilities:

- index DetecDiv projects
- detect missing raw paths
- expose project metadata
- list pipeline run summaries
- bridge local and Hub project views

Batch additions should be thin:

- add a selected-row action: `Send to batch`
- convert selected rows to `projectRef` values
- launch the Batch Builder with those refs

Example project reference:

```matlab
projectRef.kind = "local_project";
projectRef.projectMatPath = "D:/Projects/Exp001/Exp001.mat";
projectRef.catalogId = "optional-local-catalog-row-id";
projectRef.hubProjectId = "";
projectRef.displayName = "Exp001";
```

For Hub-backed projects:

```matlab
projectRef.kind = "hub_project";
projectRef.hubProjectId = "uuid";
projectRef.localPathHint = "";
projectRef.displayName = "Exp001";
```

The catalog should not decide pipeline compatibility. It only provides refs and
metadata hints. Compatibility belongs to batch validation.

## 7. Future dataset catalog

A dataset catalog can be added later for raw data that is not yet a DetecDiv
project.

Suggested dataset reference:

```matlab
datasetRef.id
datasetRef.kind              % local_dataset | hub_dataset
datasetRef.rootPath
datasetRef.loaderType
datasetRef.loaderParams
datasetRef.metadata
datasetRef.defaultProjectPath
datasetRef.tags
```

Dataset entries are useful when the first pipeline nodes create a `shallow`
project from raw data. They should remain separate from projects because a raw
dataset may not yet have a project, and several project variants may eventually
come from the same raw dataset.

The initial Batch Builder should allow the data model to represent datasets,
even if the first implementation only supports existing projects.

## 8. Prototype configuration workflow

The recommended UX is prototype-driven:

1. The user selects several projects or datasets in the catalog.
2. The user clicks `Send to batch`.
3. The Batch Builder opens with the selected items.
4. The user chooses a pipeline from a known list or adds a pipeline JSON/template.
5. The user chooses one prototype item.
6. The Batch Builder opens `pipeline2` in modal prototype mode.
7. The user tunes parameters using the normal `pipeline2` interface.
8. `pipeline2` returns `runtimeConfig`.
9. The Batch Builder applies that runtime config to every item.
10. The Batch Builder validates each item.
11. The user fixes blocking issues or adds item overrides.
12. The user submits locally or to the Hub.

This preserves `pipeline2` as the place where detailed runtime tuning happens.
The Batch Builder only manages scale-out.

## 9. Validation

Validation must happen after prototype configuration and before submission.

### Validation levels

Batch validation should include at least three levels.

#### Pipeline-level validation

Checks independent of the selected data:

- pipeline template loads
- node IDs are valid
- selected nodes are coherent
- required node params are present
- required modules are available
- output names are valid
- execution policies are valid

#### Item-level data compatibility

Checks for each project or dataset:

- project or dataset can be resolved
- raw paths are available or relinkable
- expected channels are present
- expected FOV/frame selections are valid
- required ROIs exist or can be generated by selected nodes
- output project path is writable
- required metadata are present

#### Runtime target compatibility

Checks specific to local or Hub execution:

- Python backend availability
- GPU policy compatibility
- classifier/model artifact availability
- path mapping availability
- Hub project permissions
- Hub execution target availability
- local worker write permissions

### Validation report

The validation report should be table-friendly and machine-readable:

```matlab
report.batchStatus
report.pipelineStatus
report.items(i).status          % ok | warning | error
report.items(i).blockingErrors
report.items(i).warnings
report.items(i).suggestedActions
```

The UI should show:

```text
Item | Type | Status | Warnings | Errors | Output | Action
```

Warnings can allow submission. Blocking errors should prevent submission for
the affected items unless the user explicitly excludes them.

## 10. Item overrides

The prototype runtime config should be the default for all items, but some
fields must be overrideable per item.

Typical overrides:

- output project path
- FOV selection
- frame range
- channel mapping
- raw path relink mapping
- crop/inclusion region
- ROI pattern source mapping
- execution policy for a rerun

Overrides should be sparse. The effective runtime config for one item is:

```matlab
effectiveRuntimeConfig = mergeRuntimeConfig( ...
    batchSpec.prototypeRuntimeConfig, ...
    batchSpec.items(i).runtimeOverrides);
```

The merge rules should be explicit. Avoid silent partial overrides of nested
structures unless the helper documents and validates the behavior.

## 11. Local execution model

For local execution, the batch runner should iterate over items and create a
normal `pipelineRun` for each one.

Suggested behavior:

- assign a parent batch id
- assign one run id per item
- create item-specific run folders
- write item-level `run.json`
- write a parent `batch.json`
- keep item logs separate
- update a machine-readable status file after each meaningful state change

Suggested local artifact layout:

```text
<batch_root>/
  batch.json
  status.json
  items/
    <item_id>/
      request.json
      run.json
      log.txt
      artifacts/
```

For project-backed runs, the run artifacts may also be copied or referenced from
the project pipeline run folder. The batch root should keep enough information
to monitor and resume the batch.

## 12. Hub execution model

For Hub execution, the client should submit a batch request. The Hub should
create one parent batch record and one child pipeline run job per item.

The submitted payload should preserve the same semantics as local execution:

```json
{
  "job_kind": "pipeline_batch",
  "batch": {
    "id": "optional-client-id",
    "name": "Batch name",
    "pipeline_ref": {},
    "prototype_runtime_config": {},
    "items": [],
    "execution": {
      "target": "hub",
      "execution_target_id": "uuid"
    }
  }
}
```

Each child job should be equivalent to the single-run payload described in
`doc/pipeline_run_contract.md`.

The Hub is responsible for:

- queueing child jobs
- assigning workers
- storing status
- exposing logs and artifacts
- supporting cancellation and retry
- enforcing permissions

DetecDiv remains responsible for actually executing pipeline logic on a worker.

## 13. Monitoring

The monitor should be backend-agnostic.

For local batches, it can read local status files or in-memory state.

For Hub batches, it should poll Hub APIs.

Common item status fields:

```matlab
status.items(i).itemId
status.items(i).displayName
status.items(i).state          % pending | queued | running | done | failed | canceled
status.items(i).currentNode
status.items(i).progress
status.items(i).lastMessage
status.items(i).startedAt
status.items(i).finishedAt
status.items(i).runId
status.items(i).projectRef
status.items(i).logRef
status.items(i).artifactRefs
```

Useful UI actions:

- refresh
- open project
- open run details
- open log
- retry failed
- resume selected
- cancel selected
- export batch report

The monitor should not require all jobs to finish before showing useful state.

## 14. Suggested MATLAB entry points

Initial backend functions:

```matlab
batchSpec = pipelineBatchNew(selectedRefs, options);
batchSpec = pipelineBatchSetPipeline(batchSpec, pipelineRef);
batchSpec = pipelineBatchSetPrototypeRuntime(batchSpec, runtimeConfig);
report = validatePipelineBatch(batchSpec, options);
report = runPipelineBatch(batchSpec, options);
submission = submitPipelineBatchToHub(batchSpec, options);
status = getPipelineBatchStatus(batchRef, options);
```

Context builder:

```matlab
ctx = buildPipelineBatchItemCtx(batchSpec, itemIndex, options);
```

Runtime config helpers:

```matlab
runtimeConfig = pipeline2ConfigurePrototype(pipelineTemplate, prototypeRef, options);
effectiveConfig = mergePipelineRuntimeConfig(runtimeConfig, itemOverrides);
```

The exact names can change, but the boundaries should remain stable.

## 15. UI surfaces

### Catalog browser

Add:

- multi-select project rows
- `Send to batch`
- optional filters for compatible project health

### Batch Builder UI

Core panels:

- selected items table
- pipeline selector
- prototype item selector
- runtime configuration summary
- validation table
- execution target selector: local or Hub
- submit button

Important actions:

- add/remove items
- choose pipeline
- configure prototype
- validate all
- edit item override
- submit local
- submit Hub

### Pipeline2

Add or expose:

- prototype mode
- modal return contract
- structured `runtimeConfig`
- no direct submission in prototype mode unless explicitly requested

### Batch Monitor UI

Core panels:

- batch summary
- item status table
- log/details pane
- action buttons

Refresh:

- timer-based polling
- manual refresh
- backend-specific status provider

## 16. Serialization and portability

Batch specs should be serializable to JSON-compatible data.

Avoid storing:

- live `shallow` handles
- live app handles
- function handles
- absolute-only references when a catalog or Hub id exists

Prefer storing:

- project ids
- dataset ids
- pipeline ids or pipeline bundle refs
- local path hints
- path mapping keys
- runtime params as structs
- explicit execution target

Local absolute paths are acceptable as hints for local execution, but portable
batch specs should be able to resolve through catalog or Hub references.

## 17. Relationship to raw-path relinking

Raw-path relinking remains a helper concern, not a dataloader UI concern.

Batch validation can detect missing raw paths and offer relink actions, but the
actual mapping should go through existing helpers such as:

- `detecdiv_paths_relink_project.m`
- `detecdiv_paths_ensure_fov_ready.m`
- Hub path mapping helpers

This keeps path resolution consistent with the rest of DetecDiv.

## 18. Relationship to project outputs

Each item should have explicit output policy.

Common modes:

- update existing project
- create a new derived project
- create a project if the item is a raw dataset
- write only external artifacts

The default should be conservative:

- existing projects are not destructively overwritten without an explicit policy
- new batch-created projects get deterministic names or user-confirmed paths
- each item writes its own run metadata

## 19. Minimal implementation plan

### Phase 1: local project batch MVP

Goal: batch run existing local projects using one pipeline and one prototype
runtime config.

Implement:

- catalog `Send to batch` for local project refs
- `pipelineBatchNew`
- `pipeline2` prototype runtime export, or a temporary equivalent if the app
  already has most of the state
- `validatePipelineBatch`
- `runPipelineBatch`
- simple Batch Builder UI
- simple timer-based local monitor

Do not implement raw dataset catalog yet.

### Phase 2: Hub submission

Goal: submit the same batch to Hub execution targets.

Implement:

- batch request serialization
- Hub submit helper
- Hub batch/job status polling
- monitor support for Hub status
- permission and execution-target validation

### Phase 3: item overrides and resume

Goal: make the batch useful for imperfect real datasets.

Implement:

- item override editor
- sparse runtime override merge
- resume failed
- retry selected
- skip/exclude selected items
- richer validation diagnostics

### Phase 4: dataset catalog support

Goal: support raw datasets that do not yet have DetecDiv projects.

Implement:

- dataset refs
- dataset scanner/indexer
- loader compatibility validation
- output project creation policy
- dataset-to-project provenance in run metadata

## 20. Non-goals

The batch builder should not:

- create a second pipeline architecture
- replace `pipeline2`
- make pipelines physical children of `shallow`
- put dataset catalog logic into `shallow`
- implement processing logic inside UI callbacks
- hide per-item validation failures
- submit server jobs that require GUI interaction

## 21. Open design questions

Questions to settle before implementation:

- What is the stable field schema for `runtimeConfig` returned by `pipeline2`?
- Should local batch artifacts live under each project, under a global batch
  folder, or both?
- How should a prototype ROI pattern be mapped to non-prototype datasets?
- Which runtime fields are allowed to vary per item?
- Should Hub batch jobs be first-class records or a parent job with child jobs?
- How should cancellation propagate to currently running MATLAB workers?
- How much of the local SQLite catalog schema should be shared with Hub project
  refs?

## 22. Recommended first concrete step

The first useful implementation step is not the full UI. It is the data contract:

1. Define `batchSpec`, `batchItem`, and `runtimeConfig` structs.
2. Add a local `runPipelineBatch.m` that loops over project refs.
3. Add a minimal validation report.
4. Add a temporary script or command-line entry point to test the contract.
5. Then connect the catalog `Send to batch` action and Batch Builder UI.

This keeps the feature aligned with the existing DetecDiv architecture and
limits the amount of new code required.
