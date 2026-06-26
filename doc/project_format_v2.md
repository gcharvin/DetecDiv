# DetecDiv project format v2

## Motivation

The legacy DetecDiv project file is a MATLAB `.mat` file containing a serialized
`shallow` object. This remains convenient for backward compatibility, but it is
too heavy as the long-term project source of truth.

In practice, the project file often contains or references far more runtime
state than is needed to reopen a project:

- expanded file lists such as `fov.srclist`
- parsed raw-data metadata that can be rebuilt
- ROI image/data caches
- display caches and UI state
- full processor, classifier, and pipeline-run objects
- history and transient execution metadata

This makes project saves slow, produces large files, and can trigger expensive
operations when GUIs inspect the project. A recent example was `pipeline2`
walking all FOV `srclist` entries just to infer a display raw path.

The v2 goal is to store a small, explicit project manifest and keep heavy data in
the existing external stores:

- raw acquisition folders remain the source of truth for raw images
- ROI image/data stores remain ROI-local `.h5` / legacy data files
- pipeline templates remain JSON
- pipeline runs remain run-folder `run.json` artifacts
- classifiers and processors remain independent saved objects or plugin/module
  references

## Design Principle

The project file should be a reconstruction manifest, not a MATLAB object dump.

`@shallow`, `@fov`, `@roi`, and `@dataseries` remain the in-memory and legacy
compatibility model. The v2 project manifest should contain only enough
information to reconstruct a valid `shallow` object and relink the external
artifacts.

## Proposed Files

Preferred layout:

```text
ProjectRoot/
  MyProject.json
  MyProject/
    project_state.h5          optional, only if needed later
    pipeline/
      pipeline_name_1/
        run.json
    roi folders / h5 stores
    classification/
    processor/
```

`MyProject.json` should be the source of truth for project metadata.

`project_state.h5` is optional. It should not become a replacement object dump.
Use it only for structured arrays that are genuinely too large or awkward for
JSON, and only when those arrays are not already stored in raw data, ROI `.h5`,
or run artifacts.

## Minimal JSON Schema

Draft top-level structure:

```json
{
  "schemaVersion": 2,
  "projectId": "uuid",
  "projectName": "x2026_04_27",
  "createdAt": "2026-06-26T00:00:00Z",
  "updatedAt": "2026-06-26T00:00:00Z",
  "detecdivVersion": "",
  "paths": {
    "projectRoot": ".",
    "projectDir": "x2026_04_27",
    "legacyMat": "x2026_04_27.mat"
  },
  "rawSources": [],
  "fovs": [],
  "pipelines": [],
  "pipelineRuns": [],
  "classifiers": [],
  "processors": [],
  "runProfiles": {},
  "compat": {}
}
```

### FOV entries

Each FOV entry should describe acquisition identity and user annotations, not
expanded file caches.

Keep:

- `id`, `number`, `tag`, `comments`
- `channel`, `frames`, `interval`, `binning`, `orientation`
- `srcpath` as relinkable source references
- format-specific source metadata:
  - `tiffSource`, `pageMap` summary or compact path reference
  - `ndtiffPath`, `ndtiffPosition`, `ndtiffChannels`, `ndtiffZ`
  - `omeZarrPath`, `omeZarrSeries`, `omeZarrArrayPath`, shape/chunk/dtype
- `crop`, `pattern`, `drift`
- lightweight ROI list

Avoid:

- full `srclist` when it can be reconstructed from raw source metadata
- preview images
- parsed vendor metadata blobs
- parent handles

### ROI entries

Keep:

- `id`
- `value` / bounding box
- path relative to the project directory
- extraction status, timestamp, and run id
- channel/display metadata needed to reopen the ROI viewer
- optional references to ROI-local files

Avoid:

- `image`
- loaded `dataseries`
- large `results`, `train`, `proc`, `classes`
- repeated save history

ROI quantitative outputs should live in ROI-local data stores. If some outputs
still use legacy `.mat` files, v2 should reference them explicitly and not embed
them in the project manifest.

### Pipeline and run entries

Keep only references:

- default pipeline template path or id
- list of known pipeline template refs
- list of run refs: `runId`, relative `run.json`, status summary, timestamps

Do not embed full `pipelineRun` objects in the project manifest. `run.json` is
the source of truth for run state.

## Compatibility Strategy

Phase 1: exporter only.

- Add `shallowProjectExportLight(shallowObj, jsonPath)`.
- Keep `shallowLoad` and `shallowSave` unchanged.
- Export JSON next to existing `.mat`.
- Compare file size and reopen coverage on real projects.

Initial implementation note:

- `shallowSave(shallowObj)` writes `MyProject.json` by default.
- `shallowSave(shallowObj, 'shallowObj')` also writes `MyProject.json`, preserving
  old project-only save call sites while avoiding a heavy `.mat` rewrite.
- `shallowSave(shallowObj, 'json')` writes only `MyProject.json`.
- `shallowSave(shallowObj, 'mat')` or `shallowSave(shallowObj, 'legacy')` writes
  the old `.mat`.
- `shallowSave(shallowObj, 'both')` writes `MyProject.json` and then the legacy
  `.mat`.
- `shallowLoad('MyProject.json')` loads the lightweight manifest.
- `shallowLoad('MyProject.mat')` prefers `MyProject.json` when it exists next to
  the `.mat`, then falls back to the legacy `.mat`.

Phase 2: importer.

- Add `shallowProjectImportLight(jsonPath)`.
- Reconstruct a `shallow` object in memory.
- Rebuild `parsedData` from project/FOV/raw references when possible.
- Load classifiers, processors, and pipeline runs from external refs.

Phase 3: loader integration.

- Extend `shallowLoad` to accept `.json`.
- Keep `.mat` support indefinitely for old projects.
- Prefer JSON when both `.json` and `.mat` exist and JSON is newer or explicitly
  selected.

Phase 4: save integration.

- Add `shallowSaveLight` or a `Format` option to `shallowSave`.
- During transition, optionally write both:
  - `MyProject.json` as the v2 source of truth
  - `MyProject.mat` as a compatibility snapshot

## Save Policy

The format migration should be paired with a stricter save policy. The current
log pattern shows redundant saves:

```text
Pipeline saved: .../pipeline.json
Pipeline run saved: .../run.json
Pipeline run saved: .../run.json
Pipeline run saved: .../run.json
Pipeline run saved: .../run.json
...
Pipeline run saved: .../run.json
Saving shallow project ... x2026_04_27.mat
```

This should be treated as a separate but related problem. A lighter project file
helps, but repeated writes still add latency and risk.

### Project save

Saving the project when launching a run should not be the default unless the run
actually mutates project-level state.

Project save is justified when:

- FOVs are added, removed, or relinked
- ROIs are created, deleted, moved, or extraction status is updated
- default pipeline reference changes
- run reference list is attached to the project
- Hub/project identity metadata changes
- user edits project-level annotations or settings

Project save is not necessary merely because:

- a run starts
- a run status changes
- a processor writes ROI-local outputs
- `run.json` changes
- a pipeline template was saved elsewhere

Preferred policy:

- mark the project dirty when project-level state changes
- save the project once at the end of the user action
- for pipeline execution, do not save the project at launch unless attaching a
  new run ref or changing project metadata
- after execution, save the project only if project-level state changed
- ROI-local outputs should be flushed through ROI save paths, not by rewriting
  the project manifest

### Pipeline template save

`pipeline.json` should be saved when the template changes, not every time a run
starts. A run should store the template path/id and a resolved execution spec or
snapshot if needed for reproducibility.

### Pipeline run save

`run.json` is the source of truth for execution state, but saves should be
coalesced.

Useful save points:

- after run creation
- after final execution spec is resolved
- on major status transition: `created`, `running`, `completed`, `failed`,
  `cancelled`
- after node completion, if resume/recovery depends on it
- at final summary

Avoid:

- saving several times in a row with identical content
- saving once per small in-memory field mutation
- saving both before and after a no-op status update

Implementation idea:

- introduce a `pipelineRunDirty` flag or content hash
- make `pipelineRunSave` skip writes if serialized JSON is unchanged
- add a `SavePolicy` option: `immediate`, `coalesced`, `finalOnly`
- for local interactive runs, use `coalesced`
- for long server runs, save after node/ROI checkpoints only when resume state
  changed

### ROI output save

The runner already supports deferred processor output:

```text
[processData] Defer save requested; processor output kept in ROI memory.
[runPipeline] Final ROI save: data for ROI ...
```

This is the right direction. For ROI-major execution, processors/classifiers
should write or flush ROI outputs once per ROI or at defined checkpoints, not
force a project save.

## Migration Tasks

1. Document current persisted fields for `shallow`, `fov`, `roi`, and
   `dataseries`.
2. Implement `shallowProjectToStruct(shallowObj)` producing a JSON-safe struct.
3. Implement `shallowProjectExportLight`.
4. Export a few real projects and compare:
   - legacy `.mat` size
   - JSON size
   - load time
   - catalog index time
5. Implement `shallowProjectImportLight`.
6. Add a round-trip validation script:
   - FOV count
   - ROI count
   - channels
   - frame counts
   - crops/pattern refs
   - raw source refs
   - pipeline refs
   - run refs
7. Add save coalescing for `pipelineRunSave`.
8. Audit run launch code to remove unnecessary project saves.
9. Extend catalog indexing to read `project.json` directly without loading a
   full `shallow` object.

## Open Decisions

- Should v2 JSON fully replace `.mat`, or should `.mat` remain an optional
  compatibility snapshot for a long transition?
- Should ROI-local quantitative outputs be standardized to `.h5`, or should
  legacy ROI `.mat` data files remain supported indefinitely?
- How much display state belongs in the project manifest versus ROI-local state?
- Should `srclist` ever be persisted, or always rebuilt lazily?
- Should a pipeline run attach itself to the project at creation, or should the
  project discover runs by scanning `project/pipeline/*/run.json`?

## Recommendation

Start with a non-invasive exporter and measurement pass. Do not change
`shallowLoad` first.

The first implementation should prove that a real project can be represented by
a small JSON manifest while preserving enough information to reopen the project,
show FOV/ROI lists, relink raw data, and discover pipelines/runs. Once that is
validated, integrate JSON loading and then tighten save timing.
