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
- `sam31.classify`: run SAM3.1 full-model inference on one ROI.
- `sam31.executionSpec`: expose inference parameters to pipeline nodes.

## Important Parameters

- `repoRoot`: path to `SAM31_zero_shot_ctc_benchmark`.
- `sam3Repo`: path to the official SAM3.1 checkout, usually `<repoRoot>/artifacts/sam3_official`.
- `backend`: `wsl` or `local`.
- `pythonExecutable`: Python executable for the selected backend.
- `trainingFolderName`: source dataset folder under the classifier path, default `trainingdataset`.
- `ctcSubfolder`: optional CTC subfolder below `trainingFolderName`; empty by default so SAM31 reads `trainingdataset/<split>/CTC` directly.
- `resolution`: propagated to SAM3.1 training and inference.
- `trainModules`: e.g. `instance video-memory`.
- `detectorCheckpointPath`: instance detector checkpoint for inference.
- `trackerCheckpointPath`: video memory/tracker checkpoint for inference.
- `maxNumObjects`, `videoScoreThreshold`, `videoNewDetThreshold`, `videoDetNmsThreshold`, `videoAssocIouThreshold`: full-model inference controls.

## Data Contract

The preferred training export keeps formatted raw images in one HDF5 framebank and stores instance masks as COCO RLE in JSON.
Video JSON records keep object IDs across frames through `track_id` and preserve parentage through `parent_id` / `parent_track_id`.
This is the bridge to future mother-bud assignment work: SAM3.1 handles segmentation/tracking, while parentage can be trained later from the same lineage metadata.
