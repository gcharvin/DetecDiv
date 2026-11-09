# Classifier workspace

The dockable Classifier widget owns classifier selection, the ROI dataset,
parameter configuration and annotation entry points. It shares the central
image tabs and Display/Objects/Data with projects without making classifiers
children of projects.

## Review and Edit

Each newly selected classifier starts in **Review**. Images, frame navigation,
Display controls, object inspection and object highlighting remain available.
Dataset splits, frame bounds, classifier configuration and annotation edits
require **Edit**. The image breadcrumb also reports the mode. Review does not
create ground truth or an annotation session as a side effect of browsing.

Returning to Review resolves pending scientific drafts through the existing
Save/Discard/Cancel flow. Save remains explicit; hiding a widget does not discard
its state. Annotation mutation and save callbacks also check the source ROI's
classifier, including delayed callbacks. Project annotation behavior is retained.

Advanced opens the existing Classifier GUI. Native dataset/parameter mutation is
blocked while that editor is alive, and changing mode requires closing it. Its
own save/close behavior is retained.

## Parameter configuration

The selector separates **Properties**, **Training Parameters**, **Training
Bindings**, **Inference Parameters** and **Inference Bindings**.

- Static settings come from stored values and package contracts. Bindings are
  excluded from the static editor. Inference configuration uses `executionParam`;
  training uses `trainingParam`.
- Bindings use `classifierBinding.trainingSpec`, `pipelineNodeContract`,
  `classifierBinding.catalog/choices/value/applyValue`. Dropdowns display typed
  compatible ROI resources and coverage. Configured symbolic references retain
  their exact value; browsing does not resolve them into execution parameters.
- Canonical image inputs continue to use `channelName`/`dataset.channels` where
  declared by the package. Annotation-derived GT bindings are read-only;
  specialized `packageInputs` remain in Advanced. Missing configured resources
  remain visible with the existing catalog diagnostics.
- Boolean, numeric, text, enumerated and numeric-array values have matching
  controls. Package labels, choice labels and tips are retained. Automatic numeric
  defaults can be restored with `auto`. A common view is shown first; Advanced
  reveals additional settings. Structured settings stay read-only and retain
  their existing specialized editor.
- Apply stages only changed values in the classifier; Cancel writes nothing.
  Apply rejects a changed classifier/configuration. Save persists through
  `classiSave`. No formatting, training, inference or model initialization occurs
  from parameter browsing. Runtime/environment keys declared by inference
  contracts are excluded from this generic editor.

## Ground truth

Select a ROI, switch to Edit and choose **Initialize GT...**:

- Existing GT is opened, never cleared or copied over.
- Missing GT offers **Blank GT** or **From Existing...**. The latter uses the
  shared source-selection dialog; no model is implicitly executed.
- Creation delegates to `classi.annotationSession`, `annotationManager.startBlank`
  or `annotationManager.initialize`, with overwrite disabled and the canonical
  H5/model/manifest writers. It creates **Draft**, not Ready/approved annotations.
- The authoritative GT layer is selected in Display, and compatible contour
  tools open on the central image. Subsequent editing retains the shared
  draft/undo/save behavior. Classifier binding changes require Save Classifier.
- Incomplete existing multi-component GT is preserved and directed to Advanced
  for repair. Native initialization currently handles one selected ROI. Batch
  initialization, model-assisted prediction, validation/approval and specialized
  dataseries annotation remain migration work.

## Verification

MATLAB R2026a tests use temporary classifiers/ROI H5 files:

```matlab
detecdivui.classifierWidgetTest();
detecdivui.classifierParameterContractTest();
detecdivui.classifierEditingTest();
detecdivui.objectsTest();
```

The contract test checks ten classifier packages, static/binding separation,
environment exclusion, symbolic-reference preservation and sentinel translation.
The editing test checks typed controls, staging/stale rejection, training versus
inference storage, Review protection, actual blank-GT persistence, draft
resolution and preservation of existing GT. Optional `classifierEditingTest`
PNG output captures the native parameter dialog for visual inspection. These
tests do not execute training or inference or establish full Classifier GUI parity.
