# Builtin bud/mother linker

`budMotherLinker` is a native DetecDiv processor. It is discovered from the
`engine/processor/+budMotherLinker` package and is not a plugin.

The processor consumes any indexed channel whose labels are stable track IDs.
It runs the frozen HGB ranker on the 16 published LYN-trace descriptors and
keeps explicit abstentions when the rank margin or tracking-load guard fails.
GFP is not used at inference.

## Cell-model output

The canonical output is a dedicated family in `objects_<roi-id>.h5`:

- the output family shares the selected mask provider;
- instances refer to `(family_id, frame, mask_label)` without copying pixels;
- existing cell-state IDs are copied from the input family when available;
- accepted parent links are written to `relations` with their HGB confidence;
- the source tracking family and its genealogy are not overwritten.

All events, including review/abstention events, ranked candidates, margins,
reason codes, descriptor values, runtime parameters and model hashes are kept
in a versioned JSON audit artifact next to the ROI. The sidecar provenance
points to the most recent artifact.

The frozen model and LYN source are runtime artifacts rather than plugins.
Paths can be supplied explicitly or through:

- `DETECDIV_BUD_MOTHER_MODEL`
- `DETECDIV_LYN_TRACE_REPO`
- `DETECDIV_LYN_TRACE_CHECKPOINT`
- `DETECDIV_PYTHON`

With `auto`, the current project47 v002 package and the local LYN checkout are
also discovered from sibling repositories when present.
