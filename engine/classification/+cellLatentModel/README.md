# DetecDiv `cellLatentModel` classifier

Builtin classifier adapter for the independent `cell_latent_model` repository.

## Inputs and output

- required: one indexed-mask channel with stable track IDs;
- legacy optional input: one raw GFP channel;
- temporal optional inputs: explicitly typed nucleus and bud-neck channels;
- continuous optional inputs: explicitly typed brightfield, nucleus, and
  bud-neck channels; generic GFP is rejected;
- output: a new canonical `cellModel` lineage family referencing the tracked
  mask provider;
- continuous state output: a versioned JSON sidecar keyed by
  `(family_id, track_id, frame)` and referenced by `cellModel.provenance`;
- image output: none. The classifier never copies or rewrites source channels.

The default tracking-load guard routes events with more than seven new track
IDs in the birth frame to review before relation confidence is considered.
This threshold is visible and auditable as `maxNewTracksPerFrame`.

Ranked multimodal relation scores are passed to the shared
`cell_lineage_linker` global temporal decoder before lineage persistence.
Tracking-error/high-load events are excluded from the decoder state. Changed
local predictions require review by default; the two biological windows and
beam size are explicit static execution parameters.

The packaged Python checkpoint is used when no classifier training has been
performed. A trained classifier stores its checkpoint beneath
`<classifier>/models/<modelName>/ensemble.pt`.

`continuous_cell_state` requires a trusted trained checkpoint and an explicit
physical `frameIntervalMinutes`. Schema 2/3 checkpoints predict lineage;
schema 6/7 checkpoints additionally expose biological-state probabilities.
The checkpoint owns the candidate count, contour-distance radius, and temporal
sample grid; legacy linker and frame-count biology defaults are not forwarded
to this backend.

Python executable and repository paths are discovered internally. They are
not static parameters and do not appear in pipeline JSON.

## Pipeline2 inference

The classifier uses DetecDiv's ordinary classifier and Pipeline2 contracts.
Runtime bindings independently select:

- the tracked-label mask provider (`trackChannelName`);
- optional brightfield (`brightfieldChannelName`);
- optional nuclear/HTB2-like fluorescence (`nucleusChannelName`);
- optional bud-neck/MYO1-like fluorescence (`budneckChannelName`).

Missing optional modalities are represented explicitly and never guessed from
a generic GFP channel. `inputFamily` can select lineage metadata associated
with the mask provider. The output is both a compatible lineage `dataSeries`
and a canonical `cellModel` object family; both reference the original mask
channel instead of creating another mask stack.

Trackastra, SAM31, and CellposeSAM are upstream providers, not hidden
dependencies of this classifier. A Pipeline2 graph may chain any segmentation
and tracking nodes that produce an indexed mask with stable track IDs. A
segmentation-only channel whose labels change every frame must first be tracked.
DetecDiv's shared Python bootstrap manages the common PyTorch,
CellposeSAM/Cellpose, and Trackastra environment. The latent classifier itself
resolves the independent sibling `cell_latent_model` and
`cell_lineage_linker` source distributions (or their installed packages);
SAM31 is required only when a SAM31 node is present upstream and is managed by
that node's own runtime adapter.

Model checkpoints and adaptive-marker checkpoints are classifier artifacts,
not static pipeline parameters or repository paths. Pipeline JSON therefore
stays portable.

## ClassifierGUI lifecycle

- `format`: imported training/validation ROIs, reviewed lineage family,
  tracked masks, physical frame interval, and typed optional modalities are
  exported to a versioned dataset;
- `train`: `relation_ensemble` retains the historical linker training;
  `continuous_lineage` trains the physical-time parent-or-NULL lineage head;
- `validate`: independent imported ROIs are reformatted and scored with the
  objective that trained the checkpoint;
- `classify`: an audit JSON and canonical lineage family are saved.

For `continuous_lineage`, `frameIntervalMinutes` is mandatory because the
temporal windows are expressed in physical time. If it is absent,
classifierGUI asks for it before formatting and stores the entered value in
the classifier training parameters. Programmatic formatting fails during a
read-only preflight, before an existing `trainingdataset` is replaced.

The continuous DetecDiv objective currently trains the lineage head only. It
does not manufacture cycle/death/budding state targets from lineage labels;
those heads remain separately trainable when audited biological-state GT is
available. Consequently, a newly trained schema 2/3 checkpoint does not
materialize untrained state labels on DetecDiv objects.

Project47 remains weak supervision and is rejected from the continuous
training and validation splits by both its declared domain and its source ROI
path, so it cannot fit, select, or calibrate a checkpoint. It remains usable
for inference and a held-out audit/test split.

At least two training-side ROIs are required for ROI-level train/validation.
Automatic-link calibration additionally requires two actual training ROIs;
with only one, the trained checkpoint remains usable but routes every event
to review.
