# Bud/mother lineage classifier

`budMotherLinker` is a builtin DetecDiv classifier discovered from
`engine/classification/+budMotherLinker`. It consumes indexed masks whose
labels are stable track IDs and writes mother-bud relations into a dedicated
cell-model family. It is not a plugin and inference has no Python dependency.

The package implements the complete `classifierGUI` lifecycle:

1. `format` reads the classifier's imported ROIs, their tracked-mask channel
   and reviewed cell-model lineage. Existing review-tool exports can instead
   be supplied as `groundTruthSource` (`.sqlite` or
   `accepted_lineage.csv`). Candidate links are exported to a versioned
   16-feature dataset. Train/validation/test splits are made by ROI, never by
   candidate row.
2. `train` uses DetecDiv's managed Python environment to fit the exact
   scikit-learn `HistGradientBoostingClassifier` ranker used in the original
   Project47 experiments. It exports the scaler and all trees to a `.mat`
   artifact, evaluates event-level top-1 accuracy, and calibrates an
   automatic-link margin on the validation ROIs.
3. `validate` evaluates top-1 accuracy, automatic-link precision and coverage
   on independent test ROIs. The ordinary classifier validation pipeline runs
   `classify` and writes a separate predicted lineage family for visual audit.
4. ROI import remains generic: `@classi/addROI` copies the tracked masks and
   the canonical `cell_information`/cell-model lineage metadata. No synthetic
   pixel annotation channel is required.

The 16 descriptors reproduce the geometric feature family used by LYN-trace.
LYN-trace is a scientific reference, not a runtime dependency.

## Models

The package ships a frozen Project47 HGB model for immediate inference.
Training from `classifierGUI` creates an exact sklearn HGB model under the
classifier's `models/` directory and switches that classifier instance to the
trained artifact. Python is used only during training: production inference
evaluates the exported trees natively in MATLAB. Model and Python paths are
deliberately excluded from static pipeline parameters.

## Audit and cell-model output

Accepted links are written to `objects_<roi-id>.h5` in an output family that
shares the selected mask provider without copying pixels. Existing latent
state IDs are preserved when an input family can be resolved. Every event,
including abstentions, ranked candidates, descriptors, margins, reason codes
and model provenance, is also written to a JSON audit artifact.

`process.m` is retained only as a compatibility entry point for pipelines
saved before the module became a classifier.
