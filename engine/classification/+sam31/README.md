# DetecDiv SAM3.1 Bridge

This package is intentionally a thin DetecDiv adapter.

The generic SAM3.1 repository remains independent from DetecDiv:

- DetecDiv exports annotations as SAM31-ready JSON plus a HDF5 framebank. The legacy CTC `SEG`, `TRA`, and `man_track.txt` export can still be enabled as a compatibility/debug artifact with the internal `writeLegacyCtc` flag.
- The SAM31 benchmark repository can train directly from the JSON/framebank export, or fall back to converting CTC folders when only CTC is available.
- Training and evaluation are launched through the generic `scripts/sam31_moma.py` CLI.
- Inference from DetecDiv writes one ROI movie to a temporary `.mat`, calls a separate Python runner, then imports `results.mat` masks back into a DetecDiv result channel.

## MATLAB Entry Points

- `sam31.setparam`: initialize training/inference parameters.
- `sam31.format`: export DetecDiv annotations to `classif.path/trainingdataset/<split>/_annotations.*.json` plus `<classifier>_sam31_framebank.h5`; legacy CTC writing is disabled by default.
- `sam31.train`: call the generic SAM31 CLI to prepare datasets and train selected modules.
- `sam31.classify`: run SAM3.1 inference on one ROI, with independent switches for instance segmentation, cell tracking, and bud-mother pairing.
- `sam31.applyBudPairing`: infer bud-mother links from SAM31 tracked labels and store them in `cell_information.userData.lineageSources`.
- `sam31.executionSpec`: expose inference parameters to pipeline nodes.

## Important Parameters

- `repoRoot`: path to the independent `SAM31_yeast` Python distribution.
- `sam3Repo`: path to the official SAM3.1 checkout, usually `<repoRoot>/artifacts/sam3_official`.
- `backend`: `wsl` or `local`.
- `pythonExecutable`: Python executable for the selected backend.
- `trainingFolderName`: source dataset folder under the classifier path, default `trainingdataset`.
- `ctcSubfolder`: optional CTC subfolder below `trainingFolderName`; empty by default so SAM31 reads `trainingdataset/<split>/CTC` directly.
- `resolution`: propagated to SAM3.1 training and inference.
- `trainModules`: e.g. `instance video-memory`.
- `detectorCheckpointPath`: instance detector checkpoint for inference.
- `trackerCheckpointPath`: video memory/tracker checkpoint for inference.
- `maxNumObjects`, `chunkSize`, `chunkOverlap`, `videoScoreThreshold`, `videoNewDetThreshold`, `videoDetNmsThreshold`, `videoAssocIouThreshold`: full-model inference controls. `chunkSize`/`chunkOverlap` split long movies into temporal chunks to reduce VRAM pressure on dense fields of view.
- `inferInstanceSegmentation`: run the instance segmentation stage and write/update the result label channel.
- `inferCellTracking`: keep object IDs coherent over time. This requires `inferInstanceSegmentation=true`; when disabled, output labels are frame-local instance masks.
- `inferBudPairing`: after inference, write inferred bud-mother links; enabled by default.
- `budPairingSourceKey`: optional source key under `cell_information.userData.lineageSources`; empty uses the output name.

## Model And Artifact Ownership

`SAM31_yeast` is the code distribution. DetecDiv classifier instances own the
mutable training data, generated configs, outputs, and fine-tuned checkpoints.
By default, `sam31.train` sends the generic Python CLI:

```text
--artifacts-root <classif.path>/sam31_artifacts
```

Therefore, new detector/tracker checkpoints produced by a DetecDiv training run
stay inside the SAM31 classifier folder. Standalone Python runs are different:
the caller chooses their model/output location with `--artifacts-root`; if it is
not provided, the generic SAM31 CLI writes to `<repoRoot>/artifacts`.

## Data Contract

The preferred training export keeps formatted raw images in one HDF5 framebank and stores instance masks as COCO RLE in JSON.
Video JSON records keep object IDs across frames through `track_id` and preserve parentage through `parent_id` / `parent_track_id`.
SAM31 inference writes inferred parentage into the same `cell_information`
dataseries used by manual annotations, but keeps each label-channel reference in
a separate source:

```text
cell_information.userData.lineageSources.<sourceKey>.motherOf
cell_information.userData.lineageSources.<sourceKey>.channelName
cell_information.userData.activeLineageSource
```

The legacy `userData.motherOf` map remains as a compatibility alias for older
score code and manual GT workflows. It is updated only when empty; replacement
of existing outputs is handled by the surrounding pipeline/run output policy.

Inference dependencies are enforced at runtime:

```text
bud pairing -> cell tracking -> instance segmentation
```

For example, enabling `inferBudPairing` automatically enables `inferCellTracking`
and `inferInstanceSegmentation`. Disabling `inferCellTracking` while keeping
`inferInstanceSegmentation` enabled produces instance labels without temporal ID
continuity.
