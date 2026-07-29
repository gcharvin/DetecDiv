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

`continuous_cell_state` requires a trusted trained schema-6/7 checkpoint and
an explicit physical `frameIntervalMinutes`. Its checkpoint owns the candidate
count, contour-distance radius, and temporal sample grid; legacy linker and
frame-count biology defaults are not forwarded to this backend.

Python executable and repository paths are discovered internally. They are
not static parameters and do not appear in pipeline JSON.

## ClassifierGUI lifecycle

- `format`: imported training/validation ROIs, reviewed lineage family,
  tracked masks, and optional GFP are exported to a versioned dataset;
- `train`: a PyTorch relation ensemble and OOF automatic-link calibration are
  created by the external repository;
- `validate`: independent imported ROIs are formatted and scored;
- `classify`: an audit JSON and canonical lineage family are saved.

At least two training-side ROIs are required for ROI-level train/validation.
Automatic-link calibration additionally requires two actual training ROIs;
with only one, the trained checkpoint remains usable but routes every event
to review.
