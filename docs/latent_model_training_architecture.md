# Latent-model training architecture

The word “latent model” previously covered several independent components.
DetecDiv now exposes the actual ownership boundary in classifierGUI and in the
pipeline contract.

Resource names and GUI badges follow the companion
[`data_and_model_naming.md`](data_and_model_naming.md) convention: `gt` is
reviewed ground truth, `pred` is model inference, and `input` is consumed data.

| Classifier node | Input | Output | What `Train` changes |
|---|---|---|---|
| `cellposesam` | microscopy image | frame-local instances | segmentation weights only |
| `trackastra` | image + frame-local instances | stable track IDs | Trackastra weights only |
| `cellLatentTracker` | frame-local instances + optional brightfield | stable track IDs | latent `EDGE/APPEAR/END` head only |
| `cellLatentModel` | raw image(s) + frame-local instances | stable IDs + mother/NULL lineage + optional state | selected EDGE/APPEAR/END and mother/NULL heads; state student explicitly frozen or disabled |
| `budMotherLinker` | reviewed stable IDs + mother/bud GT | mother/bud lineage | geometric boosted-tree linker only |
| `cnn` | microscopy images + reviewed image/sequence classes | class-score dataseries | CNN image classifier only |
| `cnn_lstm` | microscopy sequences + reviewed frame/sequence classes | temporal class-score dataseries | selected CNN and/or LSTM stages only |
| `deeplab_pixel_classification` | microscopy images + reviewed semantic masks | semantic masks/probabilities | DeepLab v3+ network only |
| `sam31` | microscopy movies + reviewed tracked instances | instance/tracking masks | selected semantic, instance, and/or video-memory heads only |

The stable-ID providers `trackastra` and the composite latent tracker are
alternatives. The composite tracker does not consume Trackastra IDs during
formatting or inference.

## Composite and modular workflows

`cellLatentModel` is the single user-facing composite for latent tracking,
mother/NULL lineage, and state update. It resolves one ROI split and produces
one bundle manifest, but does not pretend that the backend is a monolithic
network: the manifest names every trained or frozen checkpoint.

Segmentation remains an explicit pipeline dependency. To retrain CellposeSAM
or Trackastra too, configure those nodes in the pipeline and train them in
dependency order. This preserves replaceable pipeline boundaries instead of
hiding upstream model training inside the latent classifier.

Inference follows the same graph:

```text
image -> CellposeSAM -> frame-local instances
                         |-> cellLatentModel composite
                               |-> stable IDs
                               |-> mother/NULL lineage
                               `-> optional causal state
```

Using Trackastra plus a lineage-only classifier remains a modular alternative.
`cellLatentTracker` is a backward-compatible adapter to the same
EDGE/APPEAR/END backend; it is no longer necessary to create a second
classifier merely to train tracking for the ordinary latent-model workflow.

The same ownership contract applies to every trainable classifier package,
not only to latent-lineage packages. CNN/LSTM stage switches and the SAM3.1
`trainModules` preset are interpreted dynamically: classifierGUI lists the
sub-modules that will change and those that remain frozen for the current
parameter values.

## Current cavity-budding experiment

For the reviewed five-ROI series, select four ROIs for training and one ROI for
testing in classifierGUI. Because classifierGUI has no validation selector, the
formatter holds out one of the four selected training ROIs. The effective split
is therefore three fitting ROIs, one ROI-disjoint validation ROI, and one
untouched test ROI. The tracker target is the corrected stable-ID mask. A newly
appearing bud must receive a new GT ID; this creates an `END` action for the
previous bud track and an `APPEAR` action for the new bud. No additional hard
area penalty is required for the first experiment: the action head already
receives log-area and relative-area features. The validation report must show
whether that supervision is sufficient before a solver penalty is considered.

The existing `latent_model_1` data use these bindings:

- frame-local instances (input): `results_cellposeSAM_cell`;
- stable-ID tracking GT (target): `latent_model_1_cell`;
- optional brightfield feature: `Channel1_z2`.

The input and GT bindings may use the same reviewed mask geometry: pixel labels
are consumed only as frame-local object support, while stable GT identity is
reconstructed from `cellModel.instances.track_id`. Inference reads only the
configured instance input and never reads the GT identity or reviewed family.

Composite test evaluation is end-to-end and reports IDF1, continuation recall,
predicted-ID reuse switches, event recovery, and mother/NULL accuracy. The
lineage-only compatibility mode still reports conditional lineage metrics on
fixed tracks and must not be confused with composite performance.
