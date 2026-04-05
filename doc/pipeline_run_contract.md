# Pipeline Run Contract

This document defines the shared contract for pipeline-run creation, submission, execution, and synchronization across:

- `DetecDiv`
- `detecdiv-catalog`
- `detecdiv-hub`

It is intentionally product-level and repo-agnostic. Each repo should implement its own surface, but all three must honor the same run semantics.

## 1. Roles of the three repos

### `DetecDiv`
- Owns the pipeline runtime.
- Owns `pipeline`, `pipelineRun`, `ctx`, validation, export bundles, and MATLAB/Python execution.
- Must expose a stable non-interactive batch entrypoint for running a pipeline job.

### `detecdiv-catalog`
- Desktop client for browsing and opening projects.
- Must support two modes:
  - pure local mode
  - hub-connected mode
- Must not reimplement runtime logic.
- May launch runs locally or submit them to the hub using the same run-request payload.

### `detecdiv-hub`
- Control plane for projects, pipelines, execution targets, jobs, logs, and artifacts.
- Owns the queue, scheduling, and server-side execution orchestration.
- Must not duplicate DetecDiv business logic.

## 2. Core principle

There must be only one semantic definition of a pipeline run.

The payload stored in the hub for a `pipeline_run` job should map directly to the same concepts already used by `pipelineRun.ctx.run` in DetecDiv:

- selected nodes
- node overrides
- run policy
- data reuse policy
- cache policy
- Python runtime policy
- GPU policy
- execution target

The hub should persist and transport this payload, not reinterpret pipeline logic.

## 3. Pipeline identity

Two complementary pipeline references are supported.

### Registry pipeline
Use when the hub knows a pipeline as a managed object.

- `pipeline_id`
- optional `pipeline_version`
- optional `pipeline_key`

### Portable bundle
Use when execution must be reproducible and self-sufficient.

- `pipeline_bundle_uri`
- or `pipeline_json_path`
- optional `export_manifest_uri`

The long-term preferred server execution mode is the portable bundle, because it avoids fragile local references.

## 4. Project identity

Projects must be resolved by durable storage identity, not by display name.

Canonical fields:

- `project_id` in the hub
- preferred project `.mat` location resolved from project locations
- optional local path hint for client mode

Project names are labels only. They must not be used as synchronization keys.

## 5. Shared run-request payload

The following JSON shape is the reference payload for a pipeline run request.

```json
{
  "job_kind": "pipeline_run",
  "project_ref": {
    "project_id": "uuid-or-null",
    "project_mat_path": "optional-direct-local-path"
  },
  "pipeline_ref": {
    "pipeline_id": "uuid-or-null",
    "pipeline_key": "optional-key",
    "pipeline_bundle_uri": "optional-bundle-path-or-uri",
    "pipeline_json_path": "optional-direct-json-path",
    "export_manifest_uri": "optional-manifest-path"
  },
  "run_request": {
    "run_id": "optional-run-id",
    "description": "",
    "selected_nodes": ["node_1", "node_2"],
    "node_params": [
      {
        "id": "node_2",
        "params": {
          "frames": "1:10",
          "channel": "ch2"
        }
      }
    ],
    "run_policy": "resume",
    "existing_data_policy": "replace",
    "roi_cache_policy": "auto",
    "selection": {
      "fovs": [],
      "frames": [],
      "channels": []
    },
    "gpu": {
      "mode": "module_default"
    },
    "python": {
      "mode": "default",
      "env_name": "detecdiv_python"
    }
  },
  "execution": {
    "requested_mode": "auto",
    "execution_target_id": "uuid-or-null",
    "allow_gui": false,
    "interactive": false
  }
}
```

## 6. Mapping to DetecDiv runtime

The hub payload should map almost directly to DetecDiv runtime state.

### Hub -> `pipelineRun.ctx`

- `run_request.selected_nodes` -> `ctx.run.selectedNodes`
- `run_request.node_params` -> `ctx.run.nodeParams`
- `run_request.run_policy` -> `ctx.run.runPolicy`
- `run_request.existing_data_policy` -> `ctx.io.existingData`
- `run_request.roi_cache_policy` -> `ctx.io.roiCache`
- `run_request.python` -> `ctx.exec.python`
- `run_request.gpu` -> `ctx.exec.gpu`

### Execution constraints

Server and batch execution must always run with:

- `allow_gui = false`
- `interactive = false`

If required parameters are missing, the run must fail with a machine-readable validation error, not open a GUI.

## 7. DetecDiv batch entrypoint

DetecDiv must expose one stable entrypoint for worker execution.

Recommended MATLAB entrypoint:

- `detecdiv_run_pipeline_job(job_json_path)`

Equivalent programmatic form:

- `detecdiv_run_pipeline_job_struct(jobStruct)`

Responsibilities:

- resolve project
- resolve pipeline source or bundle
- materialize a `pipelineRun`-compatible context
- execute through the standard runtime
- save `run.json`
- return a machine-readable summary

Expected result JSON:

```json
{
  "status": "done",
  "run_id": "pipeline_gui_run_1",
  "project_mat_path": "C:/.../project.mat",
  "pipeline_json_path": "C:/.../pipeline.json",
  "run_json_path": "C:/.../run.json",
  "artifacts": [
    {
      "kind": "run_json",
      "path": "C:/.../run.json"
    }
  ],
  "summary": {
    "node_count": 6,
    "selected_node_count": 2,
    "status_by_node": {}
  }
}
```

## 8. Hub job model

The existing generic `jobs` table can host pipeline runs, but the semantics must be formalized.

Required conventions:

- `params_json.job_kind = "pipeline_run"`
- `project_id` references the target project
- `pipeline_id` references the registry pipeline when applicable
- `execution_target_id` references the chosen target

Recommended additions in `params_json`:

- `project_ref`
- `pipeline_ref`
- `run_request`
- `execution`

Recommended future API specialization:

- `POST /pipeline-runs`
- `GET /pipeline-runs`
- `GET /pipeline-runs/{job_id}`
- `POST /pipeline-runs/{job_id}/cancel`

These can still persist into the generic `jobs` table internally.

## 9. Execution targets

Execution targets must become first-class operational objects.

Each target should declare at least:

- `target_kind`
  - `local`
  - `server_cpu`
  - `server_gpu`
- `supports_matlab`
- `supports_python`
- `supports_gpu`
- `status`
- worker hostname or routing metadata

Catalog and web UI should let the user choose:

- `Run locally`
- `Submit to hub`
- when using hub, optionally choose a specific target or let the hub auto-select

## 10. Local mode versus hub mode

### Local mode
Used mainly in `detecdiv-catalog`.

- loads the project locally
- launches the same run builder semantics
- executes directly through DetecDiv
- no hub dependency required

### Hub mode

- builds the same run-request payload
- submits it to the hub
- the hub stores the job and dispatches it through a worker

The run builder logic must remain semantically identical in both modes.

## 11. UI implications

### Catalog UI

Catalog should expose:

- project listing and filtering
- pipeline selection
- run definition
- local execution or hub submission

The same project browser may stay dual-mode, but run creation should rely on one shared payload model.

### Hub web UI

The missing server-side surface is mainly:

- choose a project
- choose a pipeline or bundle
- define selected nodes and overrides
- define Python/GPU policy
- choose execution target
- submit and monitor the run

This is the main missing product surface today.

## 12. Artifacts and synchronization

A completed run should publish enough information back to the hub for monitoring and reopening.

Minimum artifacts:

- `run.json`
- stdout/stderr log or consolidated log
- optional exported reports
- optional bundle of run outputs

The hub should store artifact metadata and URIs. It does not need to parse all run internals.

After a local or remote run, the owning client may refresh the project from disk. The synchronization key is the resolved project path, never the display name.

## 13. Recommended implementation order

### Phase 1
- Define this shared contract.
- Add a stable DetecDiv batch entrypoint.
- Add explicit `pipeline_run` job semantics in the hub worker.

### Phase 2
- Add server execution target routes and UI.
- Add a basic web run builder in the hub.
- Add catalog actions:
  - `Run locally`
  - `Submit to hub`

### Phase 3
- Prefer portable pipeline bundles for hub execution.
- Add cancellation, richer logs, and resumable monitoring.

## 14. Non-goals

- The hub must not implement pipeline business logic itself.
- The catalog must not fork its own independent job model.
- Project display names must not be treated as durable identifiers.
- Batch/server execution must not rely on interactive GUI completion.

## 15. Immediate next step

The next concrete implementation artifact should be:

- a DetecDiv wrapper that accepts the shared run-request payload
- plus a hub worker execution wrapper that calls it for `job_kind = pipeline_run`

That is the smallest step that unlocks both:

- local/client reuse of the same run model
- true server-side pipeline execution from the web UI
