# DetecDiv Project Brief

## 1. Project Structure

DetecDiv is a MATLAB codebase centered on microscopy time-lapse analysis, with a legacy object hierarchy kept for backward compatibility and a newer pipeline-oriented orchestration layer being introduced.

### Core project/data classes
- `@shallow`: top-level project object. A `shallow` project stores metadata, paths, FOVs, processing history, and pipeline run references.
- `@fov`: field of view / position object. A FOV points to raw data sources and stores ROI collections and FOV-specific settings such as crop/exclusion regions.
- `@roi`: region of interest object. Historically one ROI often represented one trap or one single-cell crop. A ROI stores extracted image data (`.h5`), display metadata, results, and quantitative `dataseries`.
- `@dataseries`: quantitative outputs associated with an ROI, such as fluorescence metrics, division timing, lineage-derived values, classifier outputs, etc.

Legacy hierarchical storage remains the reference data model:
- `shallowObj.fov(i)`
- `shallowObj.fov(i).roi(j)`
- `shallowObj.fov(i).roi(j).data(k)`

### Processing/model classes
- `@process`: image/data processing object. A processor can transform images, create derived images, or create quantitative data series.
- `@classi`: classifier object. Used for segmentation, probability maps, sequence classification, etc.
- `@pipeline`: pipeline template object. This is now the main pipeline definition class and is independent from `@shallow`.
- `pipelineRun`: execution instance linking a pipeline template to a concrete dataset / project / ROI target.

### GUI/front-end classes
- `detecdiv.mlapp`: main application shell. Displays projects, pipelines, independent objects, and high-level entry points.
- `workflow.mlapp`: dedicated frontend for data loading, FOV display, ROI identification, and ROI extraction. It operates on a project (`@shallow`) and updates the associated default pipeline modules.
- `score.mlapp`: heavy ROI-centric visualization and annotation GUI. Useful for ROI review, channels, dataseries, annotations, and opening extracted ROIs.

### Engine packages
The backend is being standardized into packages under `engine/`, notably:
- `engine/dataloading`: dataloader, ROI identification, ROI extraction modules
- `engine/classification`: classifier packages
- `engine/processor`: processor packages

ROI identification modes currently standardized as package modules:
- `+roiManual`
- `+roiPattern`
- `+roiGrid`
- `+roiTracked`

## 2. Scientific / Data Processing Goals

The software is designed for microscopy experiments with repeated cellular structures, often traps or cell-containing ROIs, acquired over time and across channels.

Typical user workflow:
1. Create or open a project (`@shallow`).
2. Link raw image data and parse positions / frames / channels.
3. Define ROIs, either manually or automatically.
4. Extract ROI image hypervolumes into ROI-local `.h5` files.
5. Run classifiers or processors on extracted ROI data.
6. Quantify fluorescence and lineage-related metrics.
7. Export results to Excel or other tabular formats.

Typical biological tasks:
- detect repeated trap-like ROIs from a reference pattern
- segment cells within ROIs
- classify cell states or division events
- infer division timing using CNN/LSTM tools
- quantify fluorescence per cell / per generation
- compute lineage and generation metrics
- export aggregate measurements for downstream analysis

## 3. Current Refactor Projects

### A. Streamlined pipeline architecture
The main ongoing refactor is to move from a collection of loosely connected GUIs and command-line functions toward a reproducible, validated, sequential pipeline system.

Current design principles:
- a `pipeline` is an independent template object, not a physical child of `@shallow`
- a `pipelineRun` is the execution instance that links a template to concrete data
- pipeline nodes declare required params, required inputs, and provided outputs
- pipeline execution should support validation, dry-run, logging, rerun, and partial resume
- pipeline definitions are saved as JSON and should become portable across machines

Current module families inside a pipeline:
- dataloader
- ROI identification
- ROI extraction
- processors
- classifiers
- exporters (still less formalized)

The execution entry point is [`runPipeline.m`](C:\Users\charvin\Documents\MATLAB\DetecDiv\structure\io\runPipeline.m), which already carries several of these ideas:
- context normalization (`ctx`)
- dry-run support
- node validation
- execution policies (`resume`, `restart`, `replace`, `append`, `skip`, etc.)
- processor/classifier node execution wrappers
- run reporting and summary

### B. Frontend / backend decoupling
A second major goal is to separate GUI logic from business logic.

Desired rule:
- engine packages do the actual work
- GUIs only edit parameters, preview data, launch execution, and display results

Consequences:
- backend modules must be callable without GUI
- GUIs should not contain domain logic that cannot be reused in pipeline runs
- package contracts must be explicit enough for automatic validation and chaining

`workflow.mlapp` is the main experimental frontend in this decoupling effort. It currently centralizes:
- dataloader parameter review
- FOV display and raw image browsing
- ROI mode selection and parameter editing
- ROI generation preview and execution
- ROI extraction execution

The user preference is to keep App Designer for layout, but preserve code synchronization. For this, local sync helpers were introduced:
- `sync_mlapp_code.m`
- `sync_workflow_layout.m`
- `classifier_gui_layout.m` / `sync_classifier_layout.m`
- `score_gui_layout.m` / `sync_score_layout.m`

## 4. Business Logic Principles for Processing Functions

### Unified contract for processing/classification steps
Historically, many routines had signatures such as:
- `computeX(param, roiobj, frames)`
- `classifySomething(roiobj, classif, classifier, varargin)`

The refactor direction is to standardize processing around an execution context `ctx`, so each module can be chained in a pipeline without ad hoc glue code.

Target ideas:
- normalize what each node consumes and produces
- avoid repeated open/save cycles between steps
- keep naming of outputs explicit (`outputName`, channel names, dataseries names)
- support logging, checks, and reruns from a common runner

### ROI pattern detection
Pattern-based ROI detection is a core business function. The local backend currently lives in [`identifyROIsLocal.m`](C:\Users\charvin\Documents\MATLAB\DetecDiv\engine\dataloading\+roiPattern\private\identifyROIsLocal.m).

Important rules that emerged during refactor:
- the canonical pattern should be stored as an image patch plus metadata (source FOV / frame / channel), not only as absolute rectangle coordinates
- `crop` is FOV-specific and acts as an inclusion region for accepted detections
- test mode and generation mode must be distinguished clearly in the frontend

### Processors
Processors are not secondary to classifiers. They are central business functions and may:
- transform images into new image channels
- derive dataseries from raw or segmented data
- compute lineage information
- compute fluorescence metrics
- aggregate and export measurements

Examples mentioned repeatedly in design discussions:
- `computeLineage.m`
- `computeMetrics.m`
- channel combination or image preprocessing processors

### CNN/LSTM classifiers
CNN/LSTM modules are used to infer events such as cell division timing from ROI image sequences.

Design implications:
- they should behave as pipeline nodes, not as standalone UI-only tools
- outputs should be written under explicit names in ROI data/results
- training/inference artifacts should become traceable in the pipeline layer

### Python-backed tools, including CellposeSAM
Some classifiers/segmenters outsource work to Python. `cellposeSAM` is the main example discussed.

Current and target principles:
- Python environment is typically prepared externally with `pyenv`
- the pipeline should use the active `pyenv`, log it, and validate required packages
- Python-backed tools should eventually be stabilized as persistent modules rather than regenerated scripts per call
- model loading should happen once per persistent Python session where possible
- temporary files, logs, manifests, and outputs should live in run-scoped work directories rather than polluting classifier folders

This is important for:
- `cellposeSAM`
- future SAM / YOLO / tracking tools
- any external deep-learning backend

## 5. Practical Rules for Future Threads

When continuing work on DetecDiv, assume the following unless explicitly changed:
- `@shallow` remains the canonical project/data container.
- `@pipeline` is the single pipeline template class.
- `pipelineRun` is the execution instance linking pipeline templates to real data.
- Pipeline modules should be backend packages with explicit contracts.
- Frontends should configure and visualize, not implement business logic.
- Legacy hierarchy is preserved for data compatibility, even if orchestration is moving to pipelines.
- Raw-data relinking is a dedicated helper concern, not a dataloader GUI concern.
- ROI extraction writes `.h5` ROI image stores.
- The codebase mixes legacy code and refactored package code; prefer extending the standardized packages when possible.

## 6. Near-Term Priorities

The active priorities at the end of this thread are:
1. Keep stabilizing `workflow.mlapp` as frontend for dataloader / ROI ID / ROI extraction.
2. Continue making ROI modules self-contained package backends.
3. Keep improving `runPipeline.m` and the `ctx`-based execution model.
4. Preserve clear separation between project data (`@shallow`, `@fov`, `@roi`) and execution templates (`@pipeline`) / runs (`pipelineRun`).
5. Delay heavy Python runtime optimization until the pipeline contracts are fully stabilized.

## 7. Working Rules For Future Agents

### Do
- Read the data model first: `@shallow`, `@fov`, `@roi`, `@dataseries`.
- Treat `@pipeline` as the template and `pipelineRun` as the execution instance.
- Prefer extending package backends in `engine/` over adding new business logic inside GUIs.
- Keep frontend work in `detecdiv.mlapp`, `workflow.mlapp`, or `score.mlapp` focused on parameter editing, preview, and launch.
- When touching ROI identification, preserve the distinction between:
  - manual ROIs
  - pattern ROIs
  - grid ROIs
  - tracked/mobile ROIs
- Preserve legacy compatibility unless the user explicitly approves a breaking migration.
- Log or expose enough runtime information to debug Python-backed tools and pipeline runs.
- Assume ROI extracted image data lives in `.h5`, not `.mat`.

### Don't
- Do not make pipelines physical children of `@shallow` again.
- Do not move business logic from package backends into App Designer callbacks.
- Do not assume raw-path relinking belongs to the dataloader UI. It is a separate helper concern.
- Do not treat processors as secondary objects; they are first-class pipeline modules.
- Do not hardcode absolute paths for portable pipeline definitions.
- Do not regenerate ad hoc Python scripts per inference step unless no stable module path exists yet.
- Do not assume a ROI always corresponds to a single biological cell. The codebase is evolving toward richer cell-level representations.

## 8. Key Files To Read First

When starting a new DetecDiv thread, these files give the shortest path to the current architecture.

### Project / orchestration
- [`structure/io/runPipeline.m`](C:\Users\charvin\Documents\MATLAB\DetecDiv\structure\io\runPipeline.m): current pipeline execution entry point.
- `pipelineNew.m`, `pipelineLoad.m`, `pipelineSave.m`: pipeline lifecycle helpers.
- `structure/classes/@pipeline/`: pipeline template class implementation.
- `structure/classes/@shallow/`: project class and project-level persistence.

### Frontends
- `structure/GUI/detecdiv.mlapp`: main shell and object tree.
- `structure/GUI/workflow.mlapp`: current dataloader / FOV / ROI / extraction frontend.
- `structure/GUI/score/score.mlapp`: ROI-centric review and annotation frontend.

### ROI backend modules
- `engine/dataloading/+roiManual/`
- `engine/dataloading/+roiPattern/`
- `engine/dataloading/+roiGrid/`
- `engine/dataloading/+roiTracked/`
- [`engine/dataloading/+roiPattern/private/identifyROIsLocal.m`](C:\Users\charvin\Documents\MATLAB\DetecDiv\engine\dataloading\+roiPattern\private\identifyROIsLocal.m): current local pattern-detection backend.

### Path / relink helpers
- `helpers/detecdiv_paths_relink_project.m`
- `helpers/detecdiv_paths_ensure_fov_ready.m`

### App Designer synchronization
- `sync_mlapp_code.m`
- `sync_workflow_layout.m`
- `classifier_gui_layout.m` / `sync_classifier_layout.m`
- `score_gui_layout.m` / `sync_score_layout.m`

## 9. Minimal Pipeline Context Schema

The refactor is converging on a context-driven execution model. The exact schema may still evolve, but future work should stay compatible with the current direction.

### `ctx` core fields
- `ctx.shallow` / `ctx.shallowObj`: project handle.
- `ctx.fovList`: active FOV list.
- `ctx.roiList`: active ROI list.
- `ctx.channels`: channel names or selected channel set.
- `ctx.masks`: mask/result channel references when present.
- `ctx.dataSeries`: currently available quantitative outputs.
- `ctx.params`: node-local parameters.

### `ctx` execution fields
- `ctx.runId`: unique invocation identifier.
- `ctx.run`: run-level config, selection, resume policy, node overrides.
- `ctx.io`: overwrite / append / skip / cache behavior.
- `ctx.store`: transient or persisted execution store metadata.
- `ctx.names.outputName`: explicit output naming for processors/classifiers.
- `ctx.pipeline`: current node id and node type during execution.
- `ctx.executionPolicy`: normalized node execution policy.

### `ctx` optional frontend/runtime fields
- `ctx.allowGUI` / `ctx.interactive`: whether a node may open a GUI to complete missing params.
- `ctx.exec.python`: Python runtime metadata when Python-backed tools are involved.

### Output conventions
Future nodes should aim to expose outputs in a standardized way, even if legacy code still writes directly inside ROI/project objects.

Preferred logical output families:
- `images`
- `roiList`
- `channels`
- `masks`
- `dataSeries`
- `tables`
- `files`
- `artifacts`

### Execution rules
- Validation must happen before execution when possible.
- Dry-run should remain available and should not mutate project data.
- Output naming must remain explicit for processors and classifiers.
- Existing data policy must be controllable (`replace`, `append`, `skip`, `error`, `upsert`).
- GUI completion of missing params is acceptable, but backend execution must remain callable without GUI.
