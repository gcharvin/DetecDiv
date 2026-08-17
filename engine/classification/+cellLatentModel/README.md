# Composite latent cell model

`cellLatentModel` is the user-facing composite adapter to the existing
`cell_latent_model` backend. It is one classifier and one immutable model
bundle, while preserving the backend's explicit checkpoint composition.

## Composite contract

Inference runs in this order:

```text
[INPUT] raw image(s) + frame-local instance masks
    -> [PRED] EDGE / APPEAR / END stable tracking
    -> [PRED] mother / NULL lineage
    -> [PRED] causal biological state (optional frozen BF student)
```

No GT channel or reviewed family is read at inference. The stable tracks
produced by the first component are the tracks consumed by the lineage and
state components.

Training exposes the actual ownership switches:

- `trainTrackingActions`: fit the existing EDGE/APPEAR/END head;
- `trainMotherNull`: fit the existing physical-time mother/NULL head;
- `stateUpdateMode`: use the hash-locked BF/geometry state student or disable
  state updates. It is not retrained without audited state GT;
- CellposeSAM and Trackastra are not silently retrained. They remain explicit
  upstream pipeline alternatives.

One ROI split is resolved before formatting and recorded in the composite
dataset manifest. One bundle manifest records the tracking checkpoint, lineage
checkpoint, frozen state runtime, hashes, and training scope. A failed training
run remains in a disposable `.partial_*` staging directory and never replaces
a completed version.

## GT and input identity

`instanceChannelName` is mask geometry before tracking. Its integer values are
frame-local and are never interpreted as persistent identity.

`trackChannelName` is the reviewed GT mask provider. Persistent GT identity is
read from `cellModel.instances.track_id`, not from the pixel value. Therefore
the same reviewed mask channel may supply both frame-local geometry and GT
spatial support without leaking stable IDs into the tracker. An ID change in
the reviewed cell model creates an END target followed by an APPEAR target.

The first frame of a track and any later appearance without a reviewed mother
relation are NULL events. They are not inferred from a reused mask label.

## Outputs and evaluation

The composite classifier materializes two named prediction resources:

- `results_<outputTrackChannelName>`: stable predicted track IDs;
- `<outputFamilyName>`: predicted mother/NULL lineage family referencing that
  predicted track channel.

Optional state probabilities are saved in a versioned JSON sidecar and
confident states can be projected onto canonical cell objects.

Composite validation is end-to-end. It runs the tracker and lineage on the
test ROI, then reports detection coverage, IDF1, continuation recall,
fragmentation, predicted-ID reuse switches, event recovery, mother/NULL
accuracy, linked accuracy, and NULL accuracy. This avoids the misleading
oracle-tracks validation used by the lineage-only compatibility mode.

## Pipeline compatibility

The composite classifier remains an ordinary DetecDiv classifier node. A
pipeline can provide masks from CellposeSAM or another mask producer.
Alternatively, the specialized `cellLatentTracker` and lineage-only backends
remain supported for old saved classifiers and experiments that intentionally
train components separately.

Python and repository locations are runtime environment details. Classifier
artifacts are referenced by the classifier-owned bundle and are not copied into
pipeline static parameters.
