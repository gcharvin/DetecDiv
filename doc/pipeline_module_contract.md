# Pipeline module contract

This note defines the baseline contract for new DetecDiv pipeline modules. It
applies to dataloading, ROI identification, ROI extraction, processors,
classifiers, exporters, and Python-backed modules.

## Execution interface

Modules should be callable without GUI from a pipeline context `ctx`.

Required conventions:

- Accept `ctx` as the execution context.
- Read node parameters from `ctx.params`.
- Read selection from `ctx.sel` (`fovs`, `rois`, `frames`, `channels`).
- Read run policy from `ctx.run` and `ctx.executionPolicy`.
- Read I/O policy from `ctx.io`.
- Write logical outputs under explicit names, usually `ctx.names.outputName`.
- Return the updated `ctx`.

GUI completion is allowed only when `ctx.allowGUI` or `ctx.interactive` is true.
Backend modules must remain callable headlessly.

## Output families

Modules should declare and document which output families they consume and
produce:

- `images`
- `roiList`
- `channels`
- `masks`
- `dataSeries`
- `tables`
- `files`
- `artifacts`

Output names must be explicit for processors and classifiers. Avoid hidden
default names that make reruns ambiguous.

## Existing output policy

Modules must honor the effective existing-output policy when possible:

- `replace`: recompute and replace the named output.
- `skip`: leave existing output untouched and mark the node skipped.
- `append`: create a distinct/versioned output.
- `error`: fail if the output already exists.
- `upsert`: update existing output when compatible, otherwise create it.

If a module cannot safely support a policy, it should fail early with a clear
message rather than silently doing something else.

## Cancellation

Modules must check cooperative cancellation at safe points.

Cancellation source:

- `ctx.cancel.tokenFile`

Recommended check points:

- before expensive I/O
- before model loading
- between FOVs
- between ROI batches
- between frame batches
- before committing output files

Cancellation should raise:

```matlab
error('runPipeline:Cancelled', 'Pipeline run cancelled by user.');
```

External Python or process-backed modules should pass the cancel token path to
the external code when possible.

## Progress and run events

The runner writes a structured event ledger:

```text
run_events.jsonl
```

Each line is a JSON object. New modules should use `pipelineRunEvent(ctx, ...)`
for meaningful progress that should appear in local and Hub monitoring.

Recommended event types:

- `node_progress`
- `batch_start`
- `batch_done`
- `model_loading`
- `model_loaded`
- `model_reused`
- `output_written`
- `warning`

Recommended fields:

- `NodeId`
- `NodeType`
- `Phase`
- `Message`
- `FovIndex`
- `RoiIndex`
- `FrameStart`
- `FrameEnd`
- `BatchIndex`
- `BatchTotal`
- `OutputName`
- `OutputPath`
- `DurationSec`

Use structured fields instead of only formatted text. Keep `Message` short.

## Debug and verbose output

Console output is allowed, but it must not be the only source of run state.

Rules:

- Use concise `disp` / `fprintf` messages for human debugging.
- Put durable run state in `pipelineRunEvent`.
- Do not print large arrays, full parameter structs, raw JSON, or long Python
  traces unless debug mode is enabled.
- Use `ctx.run.verbose`, `ctx.run.debug`, or module-local params to control
  noisy output.
- Warnings should include enough context: node id, output name, FOV/ROI/frame
  when relevant.

## Resume and checkpoints

Modules should make resume decisions from both:

- the existing project/output state
- the run ledger/progress state when available

Long modules should checkpoint at the smallest safe committed unit, usually:

- FOV for raw loading and ROI identification
- FOV/ROI batch for ROI extraction
- ROI or ROI batch for classifiers/processors
- table/file artifact for exporters

Checkpoint data should be cheap to read and robust to cancelled runs. Avoid
marking work complete before outputs are committed.

## Python-backed modules

Python-backed modules should:

- use the active MATLAB `pyenv` when practical;
- avoid regenerating ad hoc scripts per ROI;
- cache loaded models in a persistent Python module/session when possible;
- pass `ctx.cancel.tokenFile` to Python;
- write Python logs into the run or classifier work directory;
- emit `model_loading`, `model_loaded`, and `model_reused` events from MATLAB
  when possible.

Fallback to an external process is acceptable when the session mode fails or is
explicitly requested.

## Review artifacts

A completed run should be reviewable from:

- `run.json`
- `run_params.json`
- `run_summary.txt`
- `run_log.txt`
- `run_events.jsonl`
- stdout/stderr or module-specific logs when available
- module artifacts such as smoke reports, preview figures, tables, masks, and
  exported files

Modules should register output paths in `ctx.outputs`, `ctx.artifacts`, or the
run report when they produce standalone files.
