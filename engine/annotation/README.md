# DetecDiv annotation backend

This package is the non-graphical bridge between `classifierGUI` and Score.
It deliberately keeps existing ROI storage conventions:

- raster GT stays in the classifier's canonical ROI channel;
- temporal labels stay in `labels_training` / `id_training`;
- tracked objects and lineage stay in `objects_<roi>.h5`;
- lifecycle metadata is a small `detecdiv_annotation_manifest` dataseries in
  `data_<roi>.mat`, not another visible image channel.

The visible lifecycle is `missing -> draft/invalid -> ready`. Prediction is an
input asset, not a GT status. Review coverage is explicit, so an annotated
empty frame is distinguishable from a frame that was never reviewed.

## GUI entry points

Create a session from the selected classifier ROI:

```matlab
session = annotationManager.createSession(classiObj, roiIndex);
context = session.uiContext();
```

`classifierGUI` can populate its ROI table without opening Score:

```matlab
rows = annotationManager.summarizeClassifier(classiObj);
```

Score should retain the `session` handle and call:

```matlab
session.bootstrap();                         % prediction -> editable draft
session.startBlank();                        % empty editable draft
session.markChanged('Frames', frame);        % edited frame -> draft + reviewed
session.markReviewed('Frames', frame);       % reviewed without changing pixels
quickReport = session.quickValidate(...
    'Components', {'tracking'}, 'Frames', frame);
report = session.validate();
[entry, report] = session.approve();
```

Validation is stored per ROI and per GT revision in the annotation manifest.
Opening another ROI therefore does not clear a previous `Valid` or `Invalid`
result. Any GT edit, review-state change, reinitialization, or training-bound
change resets that ROI to `Not run`; validation of the new revision must then
be run again.

`context.editor` selects the initial Score tool palette. During the UI
transition, `context.legacyScoreOption` maps back to the existing
`dataAnnotation` and `pixelAnnotation` modes.

`context.displayPreset` provides the GT channels, read-only prediction
channels, object families, mask providers and initial display/color mode.
Score should apply this preset instead of asking the annotator to configure
Semantic/Edit and Color-by manually.

## App Designer migration checklist

The backend is ready to be connected to the two existing applications. Do not
create a third annotation GUI. `classifierGUI.mlapp` remains the ROI/training
orchestrator; it does not edit pixels or labels itself. Score remains the only
editor. The instructions below use stable component names so that the `.mlapp`
callbacks can be wired without introducing classifier-specific UI branches.

### 1. `classifierGUI.mlapp`: ROI status and editor launcher

Work in the existing **Set training and validation set (ROIs)** tab.

App Designer must open the isolated layout source with
`classifier_gui_layout("edit")`; never open the runtime
`structure/GUI/classifierGUI.mlapp` directly. After saving and closing the
designer, use `classifier_gui_layout("apply")`. The apply step preserves the
code-rich reference, validates every callback, and rebuilds the runtime app.

#### Keep unchanged

Keep the following controls and their existing selection/import behavior:

- `UITableData`;
- `ImportROIsButton`;
- `SelectallButton` and `DeselectallButton`;
- `removeselectedROIButton`;
- the existing format/training buttons.

#### Modify existing controls

1. Append these read-only columns to `UITableData`:
   `Annotation status` and `Coverage`.
   Populate them from `classiObj.annotationSummary()` (or directly from
   `annotationManager.summarizeClassifier(classiObj)`). Display status as
   `Missing`, `Draft`, `Invalid`, or `Ready`, and coverage as
   `reviewed/total`. Validation and finalization are one user action; their
   separate persisted fields are internal audit metadata only.
2. Keep `AnnotateselectedROIButton`, but change its callback. Remove the direct
   call to `classiObj.userTraining('Roi', sel)` as the primary path. Create an
   annotation session for the selected row and open Score with that session:

   ```matlab
   session = app.Data.classiObj.annotationSession(sel);
   app.openAnnotationScore(session); % small private helper in classifierGUI
   ```

   During the transition, `openAnnotationScore` may use
   `session.uiContext().legacyScoreOption` to call the old Score constructor.
   Once Score accepts sessions, it must call `scoreApp.setAnnotationSession(session)`.
3. Modify the callback that refreshes/imports/removes ROIs so it calls a new
   private `refreshAnnotationTable` helper after the current operation.
4. Modify the format-training-set callback. Before formatting, obtain the
   summary for every selected training ROI. If any ROI is not `Ready`, show
   a confirmation dialog listing the affected ROIs. The default action must be
   cancel; do not silently validate drafts or silently exclude them.
   Do not ask for a transient frame expression during formatting. Formatting
   always consumes the persistent `Frame bounds` shown in the ROI table.
5. Rename the legacy output field labelled **Annotated ROIs with validation
   data** to **Ready annotation ROIs**, and compute it from the lifecycle
   status instead of inferring annotation state from the presence of old
   validation data.

#### Create controls

Place these controls immediately below `UITableData`, next to the existing
annotation button:

1. `GenerateDraftButton`, text **Initialize GT...**. Its callback opens the
   shared initialization dialog once, then applies the selected recipe to every
   selected ROI with `session.initialize(recipe)`. If no compatible PRED source
   exists, it stops before opening the recipe dialog and explains that
   CellposeSAM must be run separately followed by **Refresh**.
2. Keep `StartBlankGTButton` as an internal compatibility component, but hide
   it. Blank initialization is not offered by **Initialize GT...**.
3. `RefreshAnnotationStatusButton`, text **Refresh status**. Its callback calls
   `refreshAnnotationTable` without reloading images.
4. `AnnotationFilterDropDown`, label **Show**, with values `All`, `Missing`,
   `Draft`, `Invalid`, and `Ready`. Filtering changes only the visible rows and must
   preserve the underlying ROI indices.
5. Reuse `SetboundsselectionrulesButton` as **Set training frames...**. Its
   single dialog applies `all`, one shared inclusive range, or per-ROI editing
   to all training ROIs, selected table rows, or every imported ROI. The table
   remains the source of truth and defaults to `all`.

The initialization dialog offers only coherent starting points:

- **Copy existing PRED objects as Draft GT** copies every prediction component
  already materialized by the classifier.
- **Apply active latent model to existing masks/tracks** is available only for
  a trained `cellLatentModel` when every selected ROI already contains a
  compatible PRED mask or tracked-object provider. It predicts only the
  explicitly selected ROI, independently of Pipeline2 and the classifier
  train/test split, then copies the immutable refined PRED result into editable
  Draft GT. The preview names the active artifact and effective inputs and
  states explicitly that inference consumes no GT and launches no segmentation.
  Input mapping is requested only when existing non-GT inputs are ambiguous.
  If no compatible mask/provider exists, the action is not offered: the UI
  tells the user to run CellposeSAM separately, click **Refresh**, and reopen
  **Initialize GT...**.
- **Copy existing tracked objects as Draft GT** selects one object family. Its `mask_provider`
  supplies segmentation, its instances supply tracks, and its relations may be
  copied or deliberately replaced by blank parentage.
- **Copy existing segmentation mask as Draft GT** copies one channel and creates
  empty tracking and parentage GT around it.
Never expose independent mask and object-family selectors in the simple path:
selecting an object family must lock segmentation to its own `mask_provider`.
The dialog preview shows mask name, family name, track count, and parent-link
count before any write. Replacing draft or ready GT changes the action text
to **Replace GT** and displays a destructive-action warning. Recomputing an
existing PRED result or replacing GT requires a separate confirmation.

#### Remove or retire

1. Do not delete `userTraining`; keep it as a compatibility wrapper while old
   scripts still call it. Stop calling it directly from
   `AnnotateselectedROIButtonPushed` once the session path works.
2. Remove the old logic that treats a channel whose name matches the classifier
   as automatically validated GT. The canonical channel name still identifies
   GT storage, but its lifecycle comes exclusively from the annotation
   manifest.
3. Remove the old **Annotated ROIs with validation data** wording/counting, as
   described above. It duplicates the new status and gives the wrong answer for
   reviewed empty frames.

### 2. `score.mlapp`: managed annotation mode

Keep all ordinary Score functionality. Add a managed annotation mode that is
active only while an `annotationManager.Session` is attached. In ordinary Score
mode, the existing display and annotation controls continue to work as today.

#### Add non-visual properties and methods

1. Add a private/public-set property:

   ```matlab
   AnnotationSession = []
   ```

2. Add `setAnnotationSession(app, session)`. It stores the handle, calls
   `session.uiContext()`, selects the ROI, applies `context.displayPreset`, and
   refreshes the controls listed below.
3. Add private helpers `refreshAnnotationSessionUI`,
   `applyAnnotationDisplayPreset`, and `notifyAnnotationChanged(componentId,
   frames)`.
4. Extend the constructor or existing `addROI` options with an optional
   `AnnotationSession`. Keep `dataAnnotation` and `pixelAnnotation` accepted as
   compatibility options; they are no longer the source of truth.

#### Create the session header controls

At the top of the existing `AnnotationsTab`, above `AnnotationPanel`, create
`AnnotationSessionPanel` with title **Ground-truth annotation**. Add:

1. `AnnotationTargetLabel`: classifier, ROI, and target component currently
   being edited.
2. `AnnotationStatusLabel`: `Missing`, `Draft`, `Invalid`, or `Ready`.
3. `AnnotationCoverageLabel`: show one counter per required component, for
   example `Segmentation: 241/762`, `Tracking: 241/762`, and
   `Parentage: 0/1`. Do not merge these into one opaque percentage.
4. `CreateFromPredictionButton`, text **Initialize GT...**. The internal name is
   retained for App Designer compatibility. Open `annotationInitializationDialog`,
   either call `AnnotationSession.initialize(recipe)` for an existing source or
   `classifierPredictForAnnotation(..., 'InitializeGT', true)` for the active
   model, reload the ROI data, and apply the returned display preset.
5. Keep `StartBlankGTButton` hidden as a compatibility component. Blank GT is a
   choice in the shared initialization dialog rather than a separate action.
6. `MarkFrameReviewedButton`, text **Mark frame reviewed**. Call
   `markReviewed('Frames', currentFrame)` without changing image pixels.
7. `MarkThroughCurrentButton`, text **Review 1 -> current...**. After
   confirmation, mark every required frame-level component reviewed from frame
   1 through the current frame. As soon as every frame inside the ROI training
   bounds is covered, the session also completes required ROI-level units such
   as parentage; validation still checks their actual content.
8. `ReviewWhileNavigatingCheckBox`, text **Review while navigating**. When
   enabled, leaving a frame with keyboard or incomplete-frame navigation marks
   all required frame-level components reviewed. It is off by default.
9. `PreviousIncompleteButton` and `NextIncompleteButton`, text **Previous
   incomplete** and **Next incomplete**. Navigate through frames not covered by
   every required frame-level component.
10. `ValidateAnnotationButton`, text **Validate GT**. Call `validate()` and show
    every returned issue in one selectable table. Navigable rows expose their
    frame and related track; stale parentage links can be repaired individually
    or as one batch without reopening validation after every issue. A successful
    validation immediately marks that GT revision `Ready` and records its hash.
11. Keep `ApproveAnnotationButton` hidden only for compatibility with older
    layouts and scripts. No separate approval action is exposed.
12. `ShowPredictionCheckBox`, text **Show prediction overlay**. It toggles only
    the read-only prediction overlays from `context.displayPreset`; it must
    never select a prediction channel for painting.

Button state rules:

| Status | Initialize GT | Mark reviewed | Validate |
| --- | --- | --- | --- |
| Missing | enabled | disabled | disabled |
| Draft | enabled; replacement warning | enabled | enabled |
| Invalid | enabled; replacement warning | enabled | enabled |
| Ready | enabled; replacement warning | enabled | enabled |

After initialization, append the persisted provenance to the session display,
for example `mask: results_cellposeSAM_cell | tracks: Imported tracking (17) |
14 links`. Prediction assets remain untouched; all edits target the cloned GT
channel and family.

#### Modify existing Score callbacks

1. After every real edit, call the session. For a painted mask:

   ```matlab
   app.AnnotationSession.markChanged( ...
       'Components', {componentId}, 'Frames', app.CurrentFrame);
   app.refreshAnnotationSessionUI();
   ```

   Add this call after the existing pixel write/save logic, not on mouse hover
   or display-only changes. Frame-level edited units become reviewed
   automatically and receive a lightweight, non-modal validation. An edited
   ROI-level unit (notably parentage) is first made incomplete. If all required
   frame-level units inside the training bounds are already reviewed, the
   session completes that ROI-level review again automatically; content errors
   are still reported by full validation.
2. In CNN/LSTM keyboard class assignment, call the same method for the frame
   label component. A frame is therefore changed and reviewed in one action.
3. In object-state, track, mother-bud, or lineage editing callbacks, pass the
   appropriate object/lineage component ID and affected frames to
   `markChanged`.
4. When navigating to another ROI, select the matching session ROI (or attach a
   new session created by `classifierGUI`) before refreshing the display.
   Normal frame navigation does not modify annotation status unless **Review
   while navigating** is enabled.
5. Keep the existing ROI save action. Session methods save lifecycle metadata;
   the current raster/dataseries/object save paths remain responsible for GT
   content.
6. If a ready ROI is edited, `markChanged` makes it a draft again. Refresh
   `AnnotationStatusLabel` immediately so the user sees that validation is
   required again.

#### Constrain existing controls only in managed mode

Do not physically delete these controls because they are useful in ordinary
Score sessions. When `AnnotationSession` is non-empty:

1. `NormalButton`, `MulticolorButton`, `SemanticButton`, `EditButton`, and
   `DisplayCriterionDropDown`: apply the classifier display preset and disable
   them, or move them into a collapsed **Advanced display** section. This
   prevents a semantic GT from unexpectedly appearing multicolored by track.
2. `NewAnnotationButton`, `DeleteAnnnotationButton`, `NewclassButton`, and
   `DeleteclassButton`: hide or disable them. The classifier annotation spec
   defines the target schema; users must not create an unrelated annotation
   channel while editing managed GT.
3. `ObjectFamilyDropDown`, `MaskProviderDropDown`, and `LineageSourceDropDown`:
   select the values from `context.displayPreset` and disable them. Predictions
   may be displayed, but the GT family/channel remains the only edit target.
4. The lineage display radio buttons remain available because they affect
   visualization only.

#### Remove or retire

1. Remove no top-level Score tab and no general-purpose display component.
2. Retire callback branches that decide the annotation workflow solely from
   `dataAnnotation` versus `pixelAnnotation`. Use `context.editor` and the
   component specs; keep the two legacy option names only at the constructor
   boundary.
3. Never copy prediction colors, track IDs, or object overlays into lifecycle
   metadata. Only the editable GT content and manifest determine readiness.

### 3. Manual acceptance sequence after editing the `.mlapp` files

1. Open a classifier containing a completely blank ROI and refresh the table:
   status must be `Missing`.
2. Select it and click **Generate draft from prediction**: canonical GT storage
   is created and status becomes `Draft`.
3. Click **Annotate selected ROI**: Score opens in managed mode, selects the GT
   mask/family automatically, and optionally shows prediction read-only.
4. Paint one mask frame or assign one keyboard class: the corresponding
   frame-level coverage and check status update without changing prediction-only
   channels.
5. Enable **Review while navigating**, inspect two unchanged frames, and leave
   each one: segmentation/tracking coverage increases once per frame.
6. Use **Review 1 -> current...** after jumping to the final bounded frame:
   frame-level counters advance and parentage becomes `1/1` automatically once
   the complete bounded interval is covered.
7. Mark an unchanged empty frame reviewed: coverage increases even though no
   foreground pixels were added.
8. Validate and resolve reported errors: both Score and `classifierGUI` show
   `Ready` immediately after a successful validation.
9. Edit the ready ROI once: status returns to `Draft` and training formatting
   warns until it is validated again.
10. Repeat once for a frame-label classifier and once for an object/lineage
   classifier to verify that the same UI drives their different GT components.

## Classifier contract

A standardized classifier may expose `<package>.annotationSpec(classif)`.
The spec composes a few storage primitives instead of defining classifier
specific UI code. Classifiers without this hook use a category-based legacy
fallback and continue to work.

Current explicit adapters cover:

- `cnn_lstm`: per-frame class labels;
- `deeplab_pixel_classification`: semantic masks;
- `cellposesam`: instance masks;
- `trackastra`: stable tracked-instance masks;
- `sam31`: stable tracked-instance masks;
- `budMotherLinker`: tracked mask plus cloned mother-bud family;
- `cellLatentModel`: tracked mask plus cloned lineage family.
