# Pipeline module contract

This note defines the baseline contract for new DetecDiv pipeline modules. It
applies to dataloading, ROI identification, ROI extraction, processors,
classifiers, exporters, and Python-backed modules.

## Semantic contract API

CellposeSAM, CellLatentModel and HOCT own their semantic contract in their
adapter packages. The entrypoint has one common signature:

```matlab
contract = package.moduleContract(params);
```

`params` is the effective node parameter struct; omitting it is equivalent to
passing `struct()`. The result is a scalar struct with
`format = 'detecdiv.module_contract.v1'`. This function only describes the
configuration. It must not initialize a Python environment, resolve or load
model artifacts, inspect or modify ROI data, change the MATLAB path, or execute
processing. It may reuse its own pure `executionSpec` metadata.

`executionSpec` retains ownership of parameter keys, defaults, choices, labels
and editor metadata. `moduleContract(params)` declares the effective semantic
ports, resources, requirements, capabilities, selectors and bindings. Existing
classifier execution signatures are unchanged.

The returned struct patches the generic classifier contract:

| Field | Composition rule |
| --- | --- |
| `in`, `out` | Complete port arrays replace the generic arrays |
| `resources.in`, `resources.out` | Complete resource arrays replace the generic arrays |
| `selectors`, `parameters`, `requirements`, `capabilities`, `binding` | Optional scalar sections recursively overlay inherited fields |
| Explicit empty scalar-section field | Clears the inherited value |
| Omitted scalar-section field | Inherits the generic value |
| `summary` | Package-owned descriptive text |
| `format` | Validated API marker, removed from the normalized pipeline contract |
| `semantics` | Optional additive, informational metadata |

A port has `name`, `type`, `required` and `source`. A resource has `type`,
`role`, `symbol`, `param`, `port`, `nameParam`, `required` and `transfer`.
These shapes retain the existing pipeline vocabulary. Packages return complete
arrays for the ports/resources they declare rather than relying on merging
individual generic elements.

The package's `module.json` must set
`compatibility.pipelineContract` to `detecdiv.module_contract.v1` and
`entrypoints.contract` to its package-owned function, for example
`cellLatentModel.moduleContract`. Static descriptor capabilities describe the
available module modes; this function describes the selected mode.

`pipelineNodeContract` uses the descriptor beside the resolved execution
function. The declared contract must resolve in that same package directory,
so an adapter loaded from an older release cannot accidentally use another
checkout's metadata. Releases without the new declaration retain the existing
historical fallback. A broken declaration fails explicitly instead of silently
using a fallback contract.

For known modules, the effective selected parameters remain authoritative:
saved pipeline contract metadata is recalculated rather than merged over the
package's current declaration. Existing pipeline `pkg`, `func`, parameters and
classifier references remain readable. CellLatentModel retains the historical
`legacy` contract when no backend is specified.

The pilot modules add `semantics.inputIdentity` and
`semantics.outputIdentity` to distinguish frame-local instances from stable
track identities where applicable. This metadata is informational: it does not
reinterpret an existing mask channel or change connection validation or
execution. Runner behavior, GUI menus and scientific inference are unchanged
by this API migration.

See [`MODULE_CATALOG.md`](../docs/MODULE_CATALOG.md) for discovery and audit.

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
- `run_review.txt`
- `run_log.txt`
- `run_events.jsonl`
- stdout/stderr or module-specific logs when available
- module artifacts such as smoke reports, preview figures, tables, masks, and
  exported files

Modules should register output paths in `ctx.outputs`, `ctx.artifacts`, or the
run report when they produce standalone files.

`run_review.txt` is generated from `run_events.jsonl` and the saved run object.
It is meant for quick post-run triage: timeline, node statuses, failures or
cancellations, and relevant artifacts. A module that only prints to the console
will not appear clearly in this review.
