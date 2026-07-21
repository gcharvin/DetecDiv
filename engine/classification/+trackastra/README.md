# DetecDiv Trackastra module

This package exposes Trackastra as a DetecDiv classifier because it supports
the full `format -> train -> classify` lifecycle. Scientifically it is a
linker/tracker: it never replaces the upstream instance segmentation.

Inference bindings:

- `imageChannelName`: raw/intensity ROI channel;
- `instanceChannelName`: indexed instance masks, typically produced by CellposeSAM;
- `outputName`: indexed `results_<outputName>` channel containing stable tracklet IDs.

Custom model folders and checkpoints belong to the `classi` artifact. A
pipeline selects them only by using **Link classifier**; their paths are not
stored as static node parameters. Without a linked classifier, inference uses
the selected pretrained model (by default `general_2d`).

Training requires an indexed ground-truth channel whose IDs are already stable
through time. `trackastra.format` exports selected classifier ROIs to Cell
Tracking Challenge (CTC) layout. The upstream Trackastra training source is
cached at the pinned version under the classifier folder when training first
runs; it is not maintained as a second DetecDiv repository.

Formatting and training are separate operations. `trackastra.train` never
reloads ROI images or regenerates the CTC export; it validates and consumes the
existing `trainingdataset/trackastra_dataset_manifest.json`. Missing, malformed,
or CTC-incompatible exports fail early with an instruction to run
`trackastra.format` first.

The classifier input list is an inference binding: first the raw/intensity
channel, then the frame-local instance-mask channel. For training export,
`imageChannelName` defaults to that first selected input, while
`groundTruthChannelName` defaults to the editable `<classifier id>_tracklet`
annotation channel. The inference instance mask is not tracking ground truth
unless its object IDs have explicitly been made stable through time.

CTC parent-child edges require the parent tracklet to end before the child
starts. DetecDiv budding lineages commonly keep the mother tracklet alive after
bud emergence. The exporter preserves those mother and bud tracks but writes
the overlapping parent edge as `0`, records the omitted edge in the manifest,
and emits a warning. Consequently, the initial exporter trains temporal
tracklet association but does not train persistent-mother/bud lineage pairing.

Python resolution prefers an explicit `pythonExecutable`, then a pipeline
runtime executable, then MATLAB `pyenv`. If none contains Trackastra, the
local `detecdiv_python` Conda environment is discovered without storing its
machine-specific path in the pipeline JSON.
