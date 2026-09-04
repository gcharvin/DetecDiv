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

### Frozen external benchmark handoff

`cellLatentModel.exportBenchmarkSnapshot` is the read-only bridge from an
authoritative DetecDiv classifier to external evaluation code. It publishes a
new immutable `experiments/<name>_vNNN` directory below the backed-up
`cell_latent_model` data root. The handoff has two physically separate
contracts:

- `inputs/inputs_manifest.json` references only brightfield/raw pixels and
  instance masks relabeled independently in every frame;
- `targets/targets_manifest.json` references reviewed stable IDs, observed
  birth/END labels, mother/NULL relations, relation namespaces, and DetecDiv
  approval hashes.

External inference may open only the inputs manifest. Targets are opened by a
separate scorer after prediction. Unlike the in-process formatter described
above, this boundary rejects use of the reviewed GT mask provider as its input
mask channel, because an external frozen benchmark must also exclude reviewed
spatial corrections. The top manifest records both manifest hashes, source ROI
hashes, exact whole-ROI split, label quality, and the DetecDiv Git commit. A
stale unsaved classifier, invalid parentage, ambiguous frame range, existing
version, or source change aborts publication without calling `classiSave`.

## Pipeline compatibility

The composite classifier remains an ordinary DetecDiv classifier node. A
pipeline can provide masks from CellposeSAM or another mask producer.
Alternatively, the specialized `cellLatentTracker` and lineage-only backends
remain supported for old saved classifiers and experiments that intentionally
train components separately.

Python and repository locations are runtime environment details. Classifier
artifacts are referenced by the classifier-owned bundle and are not copied into
pipeline static parameters.

## Custom fluorescence heads

`cellLatentModel.signal` defines optional user-owned fluorescence heads inside
the latent-model package while keeping their training independent from the
promoted tracker and mother/NULL linker. A head may use one or more arbitrary
raw channels, temporal context, and one of three target contracts:

- classification with a user-provided class list or class count;
- scalar regression with an optional accepted value range;
- multiclass subcellular semantic segmentation.

```matlab
def = cellLatentModel.signal.definition( ...
    'TF localization', 'classification', ...
    'Channels', 'GFP', 'Family', 'latent cells', 'Classes', 3);
uiContract = cellLatentModel.signal.annotationSpec(def);
cellLatentModel.signal.createGroundTruth(roiObj, def);
cellLatentModel.signal.setGroundTruth(roiObj, def, ...
    'ObjectIds', objectIds, 'Values', labels);
report = cellLatentModel.signal.validateGroundTruth(roiObj, def);
```

Classification and regression GT are long tables keyed by immutable
`ObjectId`, with frame, track, and mask references retained for audit.
Segmentation GT is a semantic channel plus an explicit reviewed-frame table,
so an empty reviewed frame is distinguishable from an unannotated frame. The
UI-neutral annotation specification exposes palette, numeric, or paint-editor
controls to Score or another annotation client.

Every definition freezes tracking and parentage during independent head
training and declares that the custom head cannot change parentage. A future
promoted composite may consume such evidence only through a new calibrated,
versioned training contract. Pixel-level processors can obtain aligned raw
sequences through `cellMetrics.readRaw`, including a mother-bud-pair scope.
