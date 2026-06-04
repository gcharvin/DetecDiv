# Pipeline Run Preview

Status: deferred / nice-to-have.

This note records a possible future feature for the pipeline GUI layer. The feature is useful for readability, demonstrations, and user confidence, but it is not required for the core pipeline runtime.

## Idea

Once a pipeline is built and a concrete `pipelineRun` is configured, the GUI could expose a `Preview` or `Visual sketch` action that generates a compact graphical readout of what the run would do.

The preview should be tied to a run, not only to the pipeline template, because useful visual examples require concrete project data:

- selected FOVs
- selected frames
- channels
- ROI examples
- output names
- runtime-level overrides

The goal is to let a user understand the pipeline quickly without inspecting every node parameter.

## Expected content

The preview should show only representative outputs, not everything produced by the pipeline.

Possible panels:

- data loading: sample raw images for selected channels
- ROI identification: image overlay with representative ROI boxes or centers
- ROI extraction: montage of a few extracted ROI crops
- channel combination: before/after or composite image example
- classifier: representative mask, probability map, or label overlay
- processor: characteristic data series plot for a selected output
- exporter: concise list of files or tables that would be produced

Each module must define what is meaningful to display. The default should be conservative and small.

## Relationship with smoke tests

This feature could reuse a smoke-test execution mode, but it should remain conceptually separate:

- validation checks whether the pipeline is coherent
- smoke tests check whether a minimal run can execute
- preview generates a human-readable visual summary

A preview may run on a tiny subset of data, for example one FOV, a few frames, and a few ROIs. It must not silently perform a full expensive run.

## Execution granularity

The preview and smoke-test design must respect the natural execution granularity of the pipeline.

ROI-by-ROI execution is only a good default after ROI extraction has produced ROI-local image stores. From that point onward, most classifiers and processors can operate on independent ROI `.h5` files, so sampling one or a few ROIs is meaningful and cheap.

Before ROI extraction, execution should generally stay batched at the FOV/frame/channel level. Data loading, ROI identification, and ROI extraction are usually more efficient when they process a position and its frames together, because this minimizes repeated disk I/O and avoids reopening the same raw data for each candidate ROI.

For smoke tests this implies:

- pre-extraction smoke tests should use a small batch, for example one FOV and a short frame range
- ROI identification should still operate on the batch needed by the method, then report a limited number of representative ROIs
- ROI extraction should extract a small selected subset if supported, but should avoid per-ROI raw-data reload loops
- post-extraction classifier and processor smoke tests may run ROI-by-ROI on one or a few extracted ROIs

The preview runner should therefore treat ROI extraction as the boundary between batch-oriented raw-data work and ROI-oriented downstream work.

## Proposed backend contract

The GUI should not implement the business logic. It should call a backend helper such as:

```matlab
artifact = pipelineRunPreview(runObj, "UseCache", true);
```

or:

```matlab
[fig, report] = pipelineRunPreviewGenerate(pipe, runObj, opts);
```

Individual modules may optionally expose a preview hook:

```matlab
panel = package.preview(ctx, node, opts);
```

The hook would return a small structured panel description or draw into a provided layout/axes. Modules without a preview hook can fall back to a generic text panel based on their node type, inputs, outputs, and selected params.

## Caching

Generated previews should be stored as run artifacts so they do not need to be regenerated every time the GUI is opened.

Suggested location:

```text
<run.path>/artifacts/pipeline_run_preview/
```

Suggested files:

- `preview.png`
- `preview.fig`
- `manifest.json`

The manifest should include enough information to invalidate the cache when the run meaning changes:

- pipeline template id/path/version when available
- node ids and relevant node params
- selected FOVs/ROIs/frames/channels
- output names
- preview code version

If the manifest hash still matches, the GUI can open the stored preview directly.

## Implementation notes

The first implementation should be minimal:

- add the backend artifact/cache helper
- support `dataLoader`, ROI identification, ROI extraction, channel combination, and data series plots
- expose one button in the run-oriented GUI
- keep all preview generation optional and non-blocking

Classifier previews and Python-backed previews should come later, after the core module contracts are stable, because they can be expensive and runtime-dependent.

## Priority

This is decorative and explanatory rather than core infrastructure. It has product value, especially for teaching and auditing pipelines, but it should not delay pipeline execution, validation, run configuration, or backend contract stabilization.
