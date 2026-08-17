# Latent stable-ID tracker

`cellLatentTracker` is the DetecDiv owner of the latent tracking-action head.
It learns and infers three mutually competing actions between adjacent frames:

- `EDGE`: continue an existing trajectory;
- `APPEAR`: start a new trajectory (for example a newly visible bud);
- `END`: terminate the old trajectory.

New GT channels use `gt_<classifier>_stable_tracks`; new inference channels use
`results_pred_<classifier>_tracks`. Existing channels such as
`latent_model_1_cell` remain supported and are displayed as `[GT]` rather than
being renamed in place.

The model receives frame-local instance masks, optional brightfield, and—only
during formatting—reviewed stable-ID GT. The GT channel supplies each object's
spatial mask and frame-local `mask_label`; persistent identity is read from the
matching reviewed family in `cellModel.instances.track_id`. Raw mask labels are
never treated as stable IDs because DetecDiv may reuse one after an ID switch.
Candidate predecessors are selected geometrically before GT identities are
consulted. A corrected ID break such as ROI 49 / former ID 13 consequently
produces an `END` target on the large old object and an `APPEAR` target on the
smaller new bud. Area, perimeter, radius, shape, position, and optional
brightfield descriptors are available to the head, so a large area regression
can be learned without a hard-coded penalty.

## Component boundary

This classifier trains only `EDGE/APPEAR/END`. It never launches or fine-tunes:

- CellposeSAM/SAM segmentation;
- Trackastra;
- the `cellLatentModel` mother-versus-NULL lineage linker.

Those are independent pipeline nodes. A complete inference pipeline is:

`CellposeSAM -> cellLatentTracker -> cellLatentModel`

Trackastra is an alternative stable-ID provider:

`CellposeSAM -> Trackastra -> cellLatentModel`

Training several components is a pipeline-level workflow: format/train each
selected node in dependency order. A classifier never reaches upstream and
silently trains another classifier.

## Data split and artifacts

When classifierGUI has no explicit validation selector, the formatter holds out
the configured ROI fraction (default 20%, at least one whole ROI). Test ROIs are
never used. Formatted datasets are immutable timestamped directories. Model
folders are immutable `modelName` versions; training refuses to overwrite an
existing non-empty version.

`promoted_cross_domain` copies the frozen promoted tracking weights and feature
normalization as the exact epoch-zero state. Fine-tuning writes a new
checkpoint. If no epoch satisfies the ROI-validation guard, deployment rolls
back to that initialization and records the decision in
`training_report.json`.
