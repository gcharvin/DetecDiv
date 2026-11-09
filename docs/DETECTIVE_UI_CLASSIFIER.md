# Classifier workspace

The dockable Classifier widget owns classifier selection, the ROI dataset,
parameter configuration and annotation entry points. It shares the central
image tabs and Display/Objects/Data with projects without making classifiers
children of projects.

File > **Open Classifier...** loads a classifier. **Recent Classifiers** reuses
the classic `prefdir/recentClassifiers.mat` / `RecentClassifiers` history, keeping
the ten most recent successful explicit opens/saves. Startup reads only saved
references; it does not inspect their drives or open their classifiers/ROI data.
Unavailable sources remain listed. Clear Recent Classifiers clears history,
without closing classifiers or deleting files.

A recent entry focuses its existing live classifier, preserving unsaved settings
and the active ROI/frame. If explicit Open loaded multiple snapshots of one file,
the current snapshot is preferred. An unavailable entry that is not open reports
the loader failure without changing the active classifier or history. Discovery
and in-memory registration do not add history. `RecentClassifiersFile` accepts a
temporary MAT path or `''` for an isolated in-memory history.

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
  initialization, model-assisted prediction and specialized
  dataseries annotation remain migration work.

## Review and readiness

**Review GT...** opens a separate non-modal assistant for the selected classifier
ROI. It lists GT components, their coverage unit, reviewed coverage and asset
availability. It remains pinned to that ROI; **Open ROI** returns to its central
image tab. It does not open Score or create GT while inspecting a missing asset.

- **Mark Reviewed** and **Clear Reviewed** use the shared annotation session.
  Scope is explicit: current frame, through the current frame, training frame
  bounds, or required ROI-level components. Only applicable scopes are offered;
  frames outside training bounds are not authorized implicitly.
- **Next Unreviewed** navigates required frame-level coverage inside the training
  bounds, wrapping to the first incomplete frame. Navigation and the cached
  frame indicator do not write GT or run a findings audit.
- **Validate GT** calls `annotationManager.Session.validate`, including the
  existing persistence/hash checks and package coverage policy. Success sets
  **Ready** through the existing validation record. Reviewing alone leaves
  **Draft**. Invalid GT stays unavailable for training. Cellpose's nonempty
  reviewed subsets remain supported; untouched frames are not interpreted as
  negative training examples.
- **Findings...** reuses Score's persistent findings dialog. Go to selected keeps
  it open, opens the correct central ROI/frame and selects the implicated family,
  mask label and exact track identity when present. Inspecting findings is
  read-only and is available in Review. The dialog owns only its own window;
  another viewer's findings are not closed. Automatic link/censor repair is not
  exposed by this adapter; those optional buttons require actual callbacks.
- Dirty masks/tracks are resolved before review-state writes or validation.
  Resolution follows canonical ROI handles, including a ROI shared with a project,
  rather than assuming the draft was created under the transient classifier
  session. Delayed actions recheck the classifier, source ROI, mode, annotation
  identity and training bounds.
- Metadata commits rebase clean annotation editors before further drawing. A
  subsequent mask save invalidates readiness/affected review coverage through the
  existing draft writer and refreshes the classifier row and review assistant.
- Dataset frame-bound edits use `Session.setFrameBounds` so an old validation
  cannot authorize a newly changed interval. Dirty edits are resolved first;
  the classifier still requires Save to persist its dataset bounds.

Successful validation does not reopen findings merely because advisory warnings
remain. Finding collection is explicit or refreshed on demand after a saved
change; moving the timeline never performs a full audit. Training/formatting,
validation against a test dataset and runtime export remain in Advanced.

## Verification

MATLAB R2026a tests use temporary classifiers/ROI H5 files:

```matlab
detecdivui.classifierWidgetTest();
detecdivui.recentClassifiersTest();
detecdivui.classifierParameterContractTest();
detecdivui.classifierEditingTest();
detecdivui.classifierReviewTest();
detecdivui.objectsTest();
```

The contract test checks ten classifier packages, static/binding separation,
environment exclusion, symbolic-reference preservation and sentinel translation.
The editing test checks typed controls, staging/stale rejection, training versus
inference storage, Review protection, actual blank-GT persistence, draft
resolution and preservation of existing GT. Optional `classifierEditingTest`
PNG output captures the native parameter dialog for visual inspection. These
tests do not execute training or inference or establish full Classifier GUI parity.

`classifierReviewTest` exercises persisted review coverage, bound-scoped review,
partial Ready, invalid validation, metadata-to-mask save continuity, changing
bounds after validation, canonical-source draft resolution, stale continuation
rejection and findings navigation/highlighting with track IDs above `flintmax`.
The shared `testAnnotationValidationDialog` tests preserve Score's persistent
navigation and censor callbacks. An optional PNG argument captures the review
assistant.
