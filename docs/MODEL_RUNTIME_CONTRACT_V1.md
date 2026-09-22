# Latent-model layout and runtime contract (v1)

This contract freezes the *roles* and allowed contents of the existing
`cell_latent_model` data root. It does not move or rename any legacy folder,
classifier object, ROI, dataset, experiment, or release. The three historical
training-domain classifier objects remain authoritative source objects at
their current paths; `classifierGUI` may export a runtime copy, never replace
or clean those sources.

## Fixed top-level roles

| Existing root | Sole purpose | Runtime export rule |
| --- | --- | --- |
| `classifier/<classifier-id>/` | Mutable DetecDiv classifier sources and their training-time state | Never copy the whole directory. Export only a reduced classifier snapshot and files named by a validated runtime package. |
| `detecdiv_projects/<project-id>/` | Project-owned annotations / GT and review state | Never copy into an inference runtime. |
| `datasets/<dataset-id>/` | Curated training/validation/test datasets | Never copy into an inference runtime. |
| `experiments/<experiment-id>/` | Mutable or historical training/evaluation work | Never copy a directory. A promoted runtime may explicitly name an individual checkpoint file here. |
| `models/<model-id>/` | Reusable model artifacts, not a place for ad-hoc runs | Copy only individually declared runtime files. |
| `runtime_code/<snapshot-id>/` | Immutable executable source snapshots | Copy exactly the checksum-listed runtime files. Never copy a repository or its working tree. |
| `releases/<release-id>/` | Immutable promoted release manifests | Do not edit a release after promotion. `releases/detecdiv_stable.json` is the sole mutable channel pointer. |
| `runtime_bundles/<classifier-id>/<release-id>/` | Exported, inference-only package | Created only by `cellLatentModel.exportRuntime`; immutable after creation. |

Existing auxiliary roots (for example `annotations`, `audits`, `cache`,
`inference`, `pipeline`, `reviews`, or `runs`) keep their legacy meaning and
must not be repurposed. New top-level folders or new ad-hoc version naming
schemes require an update to this contract first. Do not migrate existing
content as part of a runtime export.

## Runtime package declaration

A promoted `release.json` may contain a `runtimePackage` object matching
`docs/schemas/cell-latent-runtime-package-v1.schema.json`. It is an explicit
allowlist: each source file, bundle-relative target path, byte size, SHA-256,
and any JSON path rewrite/removal is declared. Directory globs, recursive
copy rules, and implicit “copy the classifier folder” rules are forbidden.
Artifact targets must be under `releases/<release-id>/artifacts/`; every
manifest path rewrite names a JSON Pointer and another allowlisted target.
An absolute provenance/training path is omitted with an explicit JSON Pointer
removal, never by broad search-and-replace.

The exporter checks the existing release checksums first, then checks every
allowlisted source file and target path. It rejects image/ROI/training-data
extensions, unsafe paths, undeclared artifacts, missing files, duplicate
targets, and unhandled references. Only after preflight succeeds does it
write to a fresh staging directory and atomically publish the immutable
bundle. The bundle contains a reduced `*_classification.mat` snapshot with
ROIs, training selection, dataset splits, and training profiles removed.

The runtime bundle has one classifier module at
`classifier/<classifier-id>/`, one stable pointer at
`releases/detecdiv_stable.json`, and one immutable release folder at
`releases/<release-id>/`. Each `artifactTargets` value and each copied
runtime file must live under
`releases/<release-id>/artifacts/`; the exported release points to that
folder using paths relative to its own directory. Paths inside those
manifests are bundle-relative. No training ROI, source project, full
experiment, or mutable development repository is included.

## Legacy sources and multi-domain training

Training-domain classifier objects remain separate because they are
independent historical annotation/training sources. Their identity is
recorded by stable classifier ID and domain role in the source catalog; their
folder names are not inferred from screenshots or from directory scans.
The v1 catalog schema freezes the three historical IDs shown in the review:
`latent_model_1_indep` (`latent_independent`),
`latent_project47_gt_1_indep` (`project47_gt`), and
`moma01_44_managed_gt_1_indep` (`moma01_managed_gt`). Their exact legacy
module paths must be confirmed and recorded relative to the data root; the
contract deliberately does not guess them.
Combining, moving, or renaming those objects is a separate migration and is
not part of export.

`legacy` means “preserve and reference the current source layout”; it does
not mean a second untracked folder tree. New agents must first consult this
contract and the source catalog, and must not invent a new hierarchy or copy
training data to make an inference job run.

## Required workflow

1. Train/review in the existing source classifier and project folders.
2. Promote an immutable release through the existing stable-release flow.
3. Ensure the release has a complete `runtimePackage` declaration. If it
   does not, export preflight must stop and report the missing declaration;
   it must not guess dependencies.
4. Use the `Export runtime...` button in `classifierGUI` to create a runtime bundle.
5. Link pipeline nodes to the exported classifier module, not to a training
   source object. Use the same promoted code/release identity for annotation
initialization where that runtime profile is supported.

No exporter may change the stable pointer, source classifier, release, or
source catalog. Publishing a release or changing the catalog is a separate,
explicit action.
