# Bud/mother lineage classifier

`budMotherLinker` is a builtin DetecDiv classifier discovered from
`engine/classification/+budMotherLinker`. It consumes indexed masks whose
labels are stable track IDs and writes mother-bud relations into a dedicated
cell-model family. It is not a plugin. The MATLAB package is the DetecDiv
adapter for the independent Python package/repository `cell_lineage_linker`.

The package implements the complete `classifierGUI` lifecycle:

1. `format` reads the classifier's imported ROIs, their tracked-mask channel
   and reviewed cell-model lineage. Existing review-tool exports can instead
   be supplied as `groundTruthSource` (`.sqlite` or
   `accepted_lineage.csv`). It exports each tracked-label stack to the
   external package, which generates candidate links and LYN-16 descriptors.
   Train/validation/test splits are made by ROI, never by candidate row.
2. `train` calls `python -m cell_lineage_linker train-hgb` in DetecDiv's
   managed Python environment. The external package fits the exact
   scikit-learn `HistGradientBoostingClassifier`, while DetecDiv retains the
   classifier artifact, metrics, and calibrated automatic-link margin.
3. `validate` evaluates top-1 accuracy, automatic-link precision and coverage
   on independent test ROIs by calling the external model scorer. The ordinary
   classifier validation pipeline runs `classify` and writes a separate
   predicted lineage family for visual audit.
4. ROI import remains generic: `@classi/addROI` copies the tracked masks and
   the canonical `cell_information`/cell-model lineage metadata. No synthetic
   pixel annotation channel is required.

The 16 descriptors reproduce the geometric feature family used by LYN-trace.
Their canonical implementation now belongs to `cell_lineage_linker`.
LYN-trace remains a scientific reference, not a runtime dependency.

Inference also calls the shared global temporal decoder after local HGB
ranking. The visible parameters control the mother refractory window,
new-daughter maturation window, beam size, and review policy. A global
reassignment is routed to review by default rather than silently persisted.

## Models

`cell_lineage_linker` ships a frozen Project47 HGB model for immediate inference.
Training from `classifierGUI` creates an exact sklearn HGB model under the
classifier's `models/` directory and switches that classifier instance to the
trained artifact. Training and inference both execute in the external Python
package. Model and Python paths are deliberately excluded from static pipeline
parameters; the Python runtime and editable/deployed package are infrastructure.

The historical native MATLAB tree evaluator and descriptor class are retained
temporarily for numerical-parity tests and saved-pipeline migration. They are
not the production inference path.

## Integration test

`tests/testBudMotherLinkerExternalIntegration.m` creates a disposable tracked
ROI and exercises the complete boundary: managed Python runtime, external
inference, JSON audit import, lineage-family creation, and canonical
`cellModel` HDF5 round trip. It never modifies a user project.

## Audit and cell-model output

Accepted links are written to `objects_<roi-id>.h5` in an output family that
shares the selected mask provider without copying pixels. Existing latent
state IDs are preserved when an input family can be resolved. Every event,
including abstentions, ranked candidates, descriptors, margins, reason codes
and model provenance, is also written to a JSON audit artifact. The artifact
also records the local parent, global parent, rejected candidates and temporal
constraint responsible for every conflict.

`process.m` is retained only as a compatibility entry point for pipelines
saved before the module became a classifier.
