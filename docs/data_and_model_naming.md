# DetecDiv data, model, and provenance naming

Names expose three independent facts: data quality, producing module, and
biological semantic. New artifacts use lowercase machine-safe names. Existing
legacy names remain valid and are shown with an explicit quality badge in the
GUI; they are never renamed automatically.

## Quality tokens

| Token | Meaning | May be used as a training target? |
|---|---|---|
| `input` | Acquired image or upstream model output consumed as a feature | No, unless separately declared as reviewed GT |
| `gt` | Human-reviewed ground truth | Yes |
| `pred` | Direct inference/prediction from a named model | No |
| `derived` | Deterministic post-processing or measurement | No |
| `model` | Trained parameter/checkpoint artifact | Not data |
| `dataset` | Formatted training/validation collection | Contains separately declared `input` and `gt` assets |

The GUI displays the badges as `[INPUT]`, `[GT]`, and `[PRED]`. Python and
MATLAB manifests retain the lower-case tokens.

## Canonical form

```text
<quality>_<producer>_<semantic>[_<domain>][_vNNN]
```

Examples for newly created resources:

| Resource | Canonical name |
|---|---|
| CellposeSAM instance prediction | `results_pred_cellposesam_cell` |
| Trackastra stable-track prediction | `results_pred_trackastra_tracks` |
| Latent stable-track prediction | `results_pred_latent_tracker_tracks` |
| Latent mother/NULL family | `pred_latent_lineage_mother_null` |
| Reviewed tracking GT | `gt_<classifier>_stable_tracks` |
| Latent tracker checkpoint | `model_latent_tracker_<domain>_vNNN` |
| CNN image-class prediction | `pred_cnn_image_class` |
| CNN/LSTM temporal prediction | `pred_cnn_lstm_frame_class` |
| DeepLab semantic-mask prediction | `results_pred_deeplab_semantic_mask` |
| SAM3.1 tracked-instance prediction | `results_pred_sam31_tracks_cell` |

`results_` remains the DetecDiv physical-channel namespace; `pred_` states the
scientific quality of its contents. A prediction copied into the annotation
editor remains `pred` until a user reviews and validates it as a distinct `gt`
asset.

## Training ownership

Every package exposes a machine-readable `trainingScopeSpec` with:

- the exact sub-components whose weights change;
- neighbouring components that remain frozen;
- the data unit and split policy;
- the quality and semantic of every training binding;
- the canonical prediction output.

classifierGUI renders this contract beside the parameter table and prefixes
the training-data bindings with `[INPUT]` or `[GT]`. The monitor also emits
`[TRAIN SCOPE]`, `[TRAIN DATA]`, `[TRAIN OUTPUT]`, and `[TRAIN SPLIT]` lines
before fitting starts.

Training multiple modules is pipeline orchestration. Each node formats its own
dataset and writes its own checkpoint; no classifier silently fine-tunes an
upstream or downstream node.

This contract is mandatory for every package exposing `+package/train.m`.
Legacy output names remain valid and are identified as `[PRED]` by metadata;
new pipeline defaults use the canonical `pred_<producer>_<semantic>` form.
