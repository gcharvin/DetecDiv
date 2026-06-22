# DetecDiv SAM3.1 Bridge

This package is intentionally a thin DetecDiv adapter.

The generic SAM3.1 repository remains independent from DetecDiv:

- DetecDiv exports annotations directly as the SAM31 CTC source layout with `SEG`, `TRA`, and `man_track.txt`.
- The SAM31 benchmark repository converts those CTC folders to its own image/video/tracklet datasets.
- Training and evaluation are launched through the generic `scripts/sam31_moma.py` CLI.
- Inference from DetecDiv writes one ROI movie to a temporary `.mat`, calls a separate Python runner, then imports `results.mat` masks back into a DetecDiv result channel.

## MATLAB Entry Points

- `sam31.setparam`: initialize training/inference parameters.
- `sam31.format`: export DetecDiv annotations to `classif.path/trainingdataset/train/CTC` and `classif.path/trainingdataset/val/CTC`.
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

The training export keeps object IDs across frames in `TRA` masks and preserves parentage in `man_track.txt`.
The SAM31 benchmark preparation scripts consume the CTC root directly, so no intermediate `moma` folder is created for SAM31 classifiers.
This is the bridge to future mother-bud assignment work: SAM3.1 handles segmentation/tracking, while parentage can be trained later from the same CTC lineage metadata.
