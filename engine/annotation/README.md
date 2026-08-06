# DetecDiv annotation backend

This package is the non-graphical bridge between `classifierGUI` and Score.
It deliberately keeps existing ROI storage conventions:

- raster GT stays in the classifier's canonical ROI channel;
- temporal labels stay in `labels_training` / `id_training`;
- tracked objects and lineage stay in `objects_<roi>.h5`;
- lifecycle metadata is a small `detecdiv_annotation_manifest` dataseries in
  `data_<roi>.mat`, not another visible image channel.

The visible lifecycle is `missing -> draft -> approved`. Prediction is an
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
session.markChanged('Frames', frame);        % after an edit
session.markReviewed('Frames', frame);       % reviewed without changing pixels
report = session.validate();
[entry, report] = session.approve();
```

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
   `Annotation status`, `Coverage`, and `Validation`.
   Populate them from `classiObj.annotationSummary()` (or directly from
   `annotationManager.summarizeClassifier(classiObj)`). Display status as
   `Missing`, `Draft`, or `Approved`; coverage as `reviewed/total`; and the
   validation result as `Valid`, `Invalid`, or `Not run`.
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
   summary for every selected training ROI. If any ROI is not `Approved`, show
   a confirmation dialog listing the affected ROIs. The default action must be
   cancel; do not silently promote drafts or silently exclude them.
5. Rename the legacy output field labelled **Annotated ROIs with validation
   data** to **Approved annotation ROIs**, and compute it from the lifecycle
   status instead of inferring annotation state from the presence of old
   validation data.

#### Create controls

Place these controls immediately below `UITableData`, next to the existing
annotation button:

1. `GenerateDraftButton`, text **Generate draft from prediction**. Its callback
   creates a session for every selected ROI and calls `bootstrap()`. Enable it
   only when at least one selected ROI is `Missing` and its required prediction
   components are available.
2. `StartBlankGTButton`, text **Start blank GT**. Its callback calls
   `session.startBlank()`. Ask for confirmation before replacing an existing
   draft or approved GT; no confirmation is needed for a `Missing` ROI.
3. `RefreshAnnotationStatusButton`, text **Refresh status**. Its callback calls
   `refreshAnnotationTable` without reloading images.
4. `AnnotationFilterDropDown`, label **Show**, with values `All`, `Missing`,
   `Draft`, and `Approved`. Filtering changes only the visible rows and must
   preserve the underlying ROI indices.

Suggested callbacks are deliberately thin:

```matlab
function GenerateDraftButtonPushed(app, event)
    indices = app.selectedRoiIndices();
    for k = indices
        app.Data.classiObj.annotationSession(k).bootstrap();
    end
    app.refreshAnnotationTable();
end

function StartBlankGTButtonPushed(app, event)
    indices = app.selectedRoiIndices();
    for k = indices
        app.Data.classiObj.annotationSession(k).startBlank();
    end
    app.refreshAnnotationTable();
end
```

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
2. `AnnotationStatusLabel`: `Missing`, `Draft`, or `Approved`.
3. `AnnotationCoverageLabel`: for example `Reviewed: 415 / 762 frames`.
4. `CreateFromPredictionButton`, text **Create GT from prediction**. Call
   `AnnotationSession.bootstrap()`, reload the ROI data, then apply the returned
   display preset.
5. `StartBlankGTButton`, text **Start blank GT**. Call
   `AnnotationSession.startBlank()` after confirmation when GT already exists.
6. `MarkFrameReviewedButton`, text **Mark frame reviewed**. Call
   `markReviewed('Frames', currentFrame)` without changing image pixels.
7. `PreviousIncompleteButton` and `NextIncompleteButton`, text **Previous
   incomplete** and **Next incomplete**. Navigate through frames not covered by
   every required component.
8. `ValidateAnnotationButton`, text **Validate**. Call `validate()` and show the
   returned errors/warnings in a dialog or status area.
9. `ApproveAnnotationButton`, text **Approve GT**. Enable it only for a valid
   draft. Call `approve()`, refresh the status label, and keep the ROI open.
10. `ShowPredictionCheckBox`, text **Show prediction overlay**. It toggles only
    the read-only prediction overlays from `context.displayPreset`; it must
    never select a prediction channel for painting.

Button state rules:

| Status | Create from prediction | Start blank | Mark reviewed | Validate | Approve |
| --- | --- | --- | --- | --- | --- |
| Missing | enabled if prediction is available | enabled | disabled | disabled | disabled |
| Draft | disabled | confirmation required | enabled | enabled | enabled only if valid |
| Approved | disabled | confirmation required | enabled after reopening as draft | enabled | disabled |

#### Modify existing Score callbacks

1. After every real edit, call the session. For a painted mask:

   ```matlab
   app.AnnotationSession.markChanged( ...
       'Components', {componentId}, 'Frames', app.CurrentFrame);
   app.refreshAnnotationSessionUI();
   ```

   Add this call after the existing pixel write/save logic, not on mouse hover
   or display-only changes.
2. In CNN/LSTM keyboard class assignment, call the same method for the frame
   label component. A frame is therefore changed and reviewed in one action.
3. In object-state, track, mother-bud, or lineage editing callbacks, pass the
   appropriate object/lineage component ID and affected frames to
   `markChanged`.
4. When navigating to another ROI, select the matching session ROI (or attach a
   new session created by `classifierGUI`) before refreshing the display.
   Normal frame navigation does not modify annotation status.
5. Keep the existing ROI save action. Session methods save lifecycle metadata;
   the current raster/dataseries/object save paths remain responsible for GT
   content.
6. If an approved ROI is edited, `markChanged` makes it a draft again. Refresh
   `AnnotationStatusLabel` immediately so the user sees that re-approval is
   required.

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
   metadata. Only the editable GT content and manifest determine approval.

### 3. Manual acceptance sequence after editing the `.mlapp` files

1. Open a classifier containing a completely blank ROI and refresh the table:
   status must be `Missing`.
2. Select it and click **Generate draft from prediction**: canonical GT storage
   is created and status becomes `Draft`.
3. Click **Annotate selected ROI**: Score opens in managed mode, selects the GT
   mask/family automatically, and optionally shows prediction read-only.
4. Paint one mask frame or assign one keyboard class: coverage and status update
   without changing channels used only for prediction.
5. Mark an unchanged empty frame reviewed: coverage increases even though no
   foreground pixels were added.
6. Validate, resolve reported errors, then click **Approve GT**: both Score and
   `classifierGUI` show `Approved` after refresh.
7. Edit the approved ROI once: status returns to `Draft` and training formatting
   warns until it is approved again.
8. Repeat once for a frame-label classifier and once for an object/lineage
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
