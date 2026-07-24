# DetecDiv `cellLatentModel` classifier

Builtin classifier adapter for the independent `cell_latent_model` repository.

## Inputs and output

- required: one indexed-mask channel with stable track IDs;
- optional: one raw nuclear GFP channel;
- output: a new canonical `cellModel` lineage family referencing the tracked
  mask provider;
- image output: none. The classifier never copies or rewrites source channels.

The packaged Python checkpoint is used when no classifier training has been
performed. A trained classifier stores its checkpoint beneath
`<classifier>/models/<modelName>/ensemble.pt`.

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
