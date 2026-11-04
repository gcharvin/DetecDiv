# Score → unified viewer: functional review and migration plan

Review date: 4 November 2026. Source baseline: `10121cc9629ec1267e550e0934b577d0d5e8d9e9`.
This is an audit of the implementation, not a claim that every legacy path has been exercised or migrated.

## Scope and evidence

Reviewed the authoritative [Score runtime source](../structure/GUI/score/private/score_runtime_code.m), its component/callback registrations, all top-level Score helper entry points, object-editing adapters, the dataseries model and existing regression sources. Runtime/source identity, including packed `score.mlapp`, was verified during this audit with `detecdivui.progressLegacyTest`; this check does not execute each scientific callback.

[The source inventory](DETECTIVE_UI_SCORE_SOURCE_INVENTORY.csv) contains 207 function declarations (including nested functions), 184 typed component declarations, 14 direct/dynamic callback assignment sites, 91 top-level helper files and 12 test files. These are source records, not distinct user features. Static named `createCallbackFcn` bindings are attached to their function records; dynamic Movie control loops and context-menu construction require the manual mapping below. The source SHA256 is recorded in the inventory. Regenerate it from the worktree with:

```powershell
.\tools\audit-score-ui.ps1
```

Status below describes the new viewer: **Partial** means only the stated subset is present; **Pending** means the Score capability has not been migrated. An existing backend/helper is not sufficient evidence of new-UI support.

## Functional parity map

### Navigation, display and measurements

| ID | User capability in Score | Existing implementation to reuse | Viewer status | Destination / migration constraint |
| --- | --- | --- | --- | --- |
| S01 | Browse/add/close ROI collections; selected ROI and channel presets | `addROI`, `displayROIs`, `handleROITableEdit`, `CloseselectedROIMenuSelected` | Partial: multi-project/FOV/ROI tree | Projects; retain standalone/classifier-owned ROI entry points without making a classifier a project |
| S02 | Frames, shortcuts, pan, zoom, reset | `ImageFigureKeyPress`, `ScoreAppUIFigureKeyPress`, frame/pan/zoom callbacks | Partial: time navigation, zoom, Fit | Image; shortcuts must respect text-input focus and the active drawing tool |
| S03 | Visible channels, colors/colormaps, weight, overlay | `displayROIChannels`, `handleChannelTableEdit`, `score_applyChannelColorSpec`, `score_makeComposite` | Partial: rich layer rows, picker, weight, composite | Display; separate display changes from source pixel edits |
| S04 | Levels, scale flags and logarithmic image mapping | `displayChannelFeatures`, `LowHighDisplaySliderValueChanging`, `score_makeComposite` | Partial: source-unit levels and Auto min/max; no full Scale/Log image controls | Display; histogram log axes do not mean logarithmic image mapping |
| S05 | Histogram, medians, current-channel values | `score_updateHistogram`, shared `score_histogramData` | Implemented subset: active/visible histograms, source-pixel levels and statistics | Display; preserve physical-value transforms when completing parity |
| S06 | Encoded/physical signal values and units; channel scale bars | `score_channelValueTransform`, `score_decodeChannelValues`, `score_encodeChannelValues`, `score_channelDisplayUnit`, `score_drawChannelScaleBar` | Pending beyond source-pixel contrast | Display; keep encoded storage and physical UI values distinct |
| S07 | Separate channel panels versus composite, annotation comparison layouts | `score_computePanels`, `score_updateLayout`, `score_renderAnnotationComparison`, `score_annotationRows` | Partial: composite/separate intensity panels, shared masks, linked time/pan/zoom and active source selection; annotation comparison layouts pending | Image layout options; one active scientific edit target even in comparisons |
| S08 | Mask fill/contours, width, transparency, background class | `UIAnnotationTableSelectionChanged`, mask/color/transparency callbacks, `score_makeComposite`, `score_displayVectorGraphics` | Partial: palette/single color, fill alpha, transparent label zero, Fill/Contours/combined modes and width; background-class convention controls pending | Display selected-mask controls; contour settings are not the reference FOV ROI rectangles |
| S09 | Color by track, frame instance, family, new bud or cell state; Normal/Multicolor/Semantic/Edit | `score_getObjectDisplayConfig`, `score_getObjectOverlay`, `score_setObjectDisplayConfig`, `score_refreshObjectDisplayUI` | Pending | Objects contextual widget + Display; preserve family/provider-specific configuration |
| S10 | Choose object family, mask provider and lineage source | `score_resolveMaskProvider`, `score_resolveCellModelFamily`, `score_resolveLineageDisplayConfig`, `score_updateCellModelMaskProvider` | Pending | Objects; disable unavailable providers, never guess from channel order |
| S11 | Bud-pairing/genealogy overlays and link colors | `score_lineageDisplayOptions`, `score_configureLineageDisplay`, `score_updateCellInformationLineage`, `score_storeCellModelColors` | Pending | Objects + Display; viewing relationships must not change them |
| S12 | Line intensity profile | `createIntensityLine`, `score_updateIntensityProfile` | Pending | Measurements assistant on Image; profile plot in the same workspace |
| S13 | Ellipse/shape intensity profile and channel fluorescence over time | `createEllipse`, `score_updateEllipticalProfile`, `quantifyChannelFluo` | Pending | Measurements; preview geometry distinct from a generated mask and processing result |
| S14 | Compute object metrics from the selected geometry/channel | `quantifyChannelFluo`, `getProcessorByName`, existing metrics processor | Pending | Measurement action launches the existing processor/pipeline; explicit output names and target |

### Quantitative data and dataset management

| ID | User capability in Score | Existing implementation to reuse | Viewer status | Destination / migration constraint |
| --- | --- | --- | --- | --- |
| S15 | Browse ROI dataseries, visibility, type/group and columns | `displayData`, `displaySubData`, `UIDataTable*`, `UISubDataTable*`, `@dataseries` | Pending | Data widget; metadata list before loading values; do not open a second image viewer |
| S16 | Plot numeric, categorical, string and numeric/vector cell variables | `score_extractYData`, `score_displayDataPanel`, `@dataseries/plot` | Pending | Dockable Data plots, normally below Image; preserve categories and vector expansion |
| S17 | Plot/image groups, curve colors/widths, bounds and data colormap | `UIGroupTableCellEdit`, `UISubDataTableCellEdit`, `score_displayDataPanel`, `plotProperties`, `groupProperties` | Pending | Data settings on demand, with a compact main variable selector |
| S18 | Synchronized time marker, units, offset, event markers and track window | `score_displayDataPanel`, `score_drawMovieEventLines`, `score_normalizeMovieEvents`, `score_updateSelectedSignalFields` | Pending | Shared Image/Data frame selection; validate generation/non-temporal series separately |
| S19 | Create a dataseries, add numeric/categorical columns and plot groups; delete a dataseries | `NewdataseriesButtonPushed`, `NewdatasetButtonPushed`, `NewdatagroupButtonPushed`, `DeleteselecteddataseriesMenuSelected`, `dataseries.addData` | Pending | Data dialogues/context menu; transactional data edits and explicit Save ROI data |
| S20 | Assign a quantitative/categorical value or training class at the current frame / sequence window | `AssignvalueEditFieldValueChanged`, `ClassDropDownValueChanged`, `assignSelectedTrainingClass`, `trainingClassFrames` | Pending | Data or Annotation according to target; classifier ownership and frame scope must be explicit |
| S21 | Add lineage-derived data sources to series display | `addLineageSourceRowsToSubDataTable`, `syncLineageSourcesFromSubDataTable`, `score_extractYData` | Pending | Data; derived source rows are not independent stored measurements |

### Drawing, masks, tracks and linking

| ID | User capability in Score | Existing implementation to reuse | Viewer status | Destination / migration constraint |
| --- | --- | --- | --- | --- |
| S22 | Create/delete annotation channels and classes | `NewAnnotationButtonPushed`, `DeleteAnnnotationButtonPushed`, `NewclassButtonPushed`, `DeleteclassButtonPushed` | Pending | Annotation settings; deletion has a scientific-data scope, not a visibility toggle |
| S23 | Select an object, inspect mask label / object / track / cell state | `score_paintOverlay`, `score_updateSelectedObjectFields`, `score_updateSelectedCellState`, `score_resolveSelectedTrackForFrame` | Pending | Objects widget and main-image selection; instance ID and track ID remain distinct |
| S24 | Brush painting/erasing; shape/size; paint selected track | `score_paintOverlay`, `openBrushSizeDialog`, `score_prepareSelectedTrackPaint`, `score_applySelectedTrackPaint`, `score_restoreMaskInteraction` | Pending | Annotation assistant on Image; FOV ROI rectangles already implemented are a different operation |
| S25 | Renumber mask IDs on current frame / from frame / all appearances | `score_paintOverlay` context-menu renumber handlers, `cellModel.relabelFrame` and related adapters | Pending | Advanced object actions; preserve instance-to-track/model synchronization and scope |
| S26 | Split an object using watershed; delete current/all-frame object | `score_splitMaskObject`, `score_deleteSelectedObject`, `cellModel` backend | Pending | Objects actions; preview/scope, dirty state and undo before mutation |
| S27 | Assign/start/reassign/swap track IDs with temporal scope | `score_assignSelectedTrack`, `score_swapSelectedTrackIds`, `cellModel.reassignTrack`, `cellModel.swapTrackIds` | Pending | Objects assistant; preserve reports and invalidate only affected model/render caches |
| S28 | Set/remove parent, guided binary fission, undo last fission correction | `score_setSelectedParentTrack`, `score_fissionCorrection`, `cellModel.setParentTrack` | Pending | Linking tool on Image; enforce temporal convention and family/provider context |
| S29 | Repair ID continuity via IoU; propagate a track with SAM31 and edit propagation settings | Context actions in `score_paintOverlay`, existing `cellModel`/`sam31` modules | Pending | Objects → Advanced actions; backend dependencies, model/environment and progress remain explicit |
| S30 | Track censoring, censor suggestions and repairs | `score_editSelectedTrackCensoring`, `CensorSelectedTrackButtonPushed`, `acceptAnnotationCensorSuggestion`, `repairAnnotationFindings` | Pending | Objects + Review; distinguish data repair from visual hiding |
| S31 | Lineage tree, navigation to track start and focus on a tree object | `score_lineageTreeDialog`, `score_lineageTreeLayout`, `showLineageTree`, `focusLineageTreeTrack` | Pending | Dockable Lineage view or existing dialog initially; synchronize Image selection |

### Managed annotation and training data

| ID | User capability in Score | Existing implementation to reuse | Viewer status | Destination / migration constraint |
| --- | --- | --- | --- | --- |
| S32 | Classifier-bound annotation sessions, target/source and coverage | `setAnnotationSession`, `selectClassifierTrainingData`, `@classi/annotationSession`, `annotationManager.Session` | Pending | Annotation widget, linked to independent Classifiers collection |
| S33 | Blank ground truth or initialize GT from a prediction; compare predictions/GT | `StartBlankGTButtonPushed`, `CreateFromPredictionButtonPushed`, `annotationManager.startBlank`, `annotationManager.initialize`, `score_updateAnnotationComparison` | Pending | Annotation setup dialog + main-image comparison; never overwrite a prediction implicitly |
| S34 | Review/unreview frame, review through current, review while navigating, next incomplete | Review callbacks, `reviewFrameBeforeNavigation`, `annotationManager.markReviewed/markUnreviewed` | Pending | Compact Review controls; preserve frame/component coverage rather than one global checkbox |
| S35 | Validate, inspect findings, navigate/repair findings and approve | `ValidateAnnotationButtonPushed`, `annotationValidationDialog`, `annotationManager.validate/approve`, findings callbacks | Pending | Review dialog; editing must invalidate previous validation/approval according to the existing backend |
| S36 | Training-frame bounds and class keyboard shortcuts, including sequence/window annotation | `setupTrainingBoundsMenu`, `updateTrainingFrameBounds`, `assignSelectedTrainingClass`, existing sequence-window tests | Pending | Annotation context; shortcut meaning follows session type and edit focus |
| S37 | Specialized latent-signal/object sessions and cavity trajectory inspection | `score_latentSignalContext`, `score_configureLatentSignalControls`, `score_setSelectedSignalGroundTruth`, `score_cavityTrajectoryDialog` | Pending | Context-specific Annotation/Data tools; preserve current runtime/model contracts |

### Export, presets and persistence

| ID | User capability in Score | Existing implementation to reuse | Viewer status | Destination / migration constraint |
| --- | --- | --- | --- | --- |
| S38 | Export a movie or a multi-frame PDF sequence | `setMovieMosaicArguments`, `score_collectDisplayOptions`, `score_createDisplayHandles`, `score_renderFinalFrame`, `score_exportSequence`, `score_captureMovieFrame` | Pending | File → Export… dialog with compact presets and optional advanced settings |
| S39 | Single/all loaded ROI export, mosaic rows/columns, channel separation/overlay, frames, crop/flip/rotate/size | Movie controls, `score_updateLayout`, `score_layoutMovie`, `score_layoutExport` | Pending | Export dialog; freeze explicit ROI/frame/channel selection before rendering |
| S40 | Movie speed versus acquisition interval, timestamps, titles, fonts/background, event text/lines, scale bars, data plots/tracking window | `score_gatherArguments`, `score_drawMovieEventText/Lines`, `score_drawChannelScaleBar`, `score_displayDataPanel` | Pending | Export uses the same display snapshot; acquisition time and output FPS are separate quantities |
| S41 | Local/Hub movie export, output path/profile, open generated file/folder | `submitScoreMovieToHub`, existing `hubClient` submission path, `localWriteMovie`, `ShowmovieandfolderButtonPushed` | Pending | Export monitor; retain submission identity and progress, do not silently route a local job remotely |
| S42 | Copy/paste presets between ROIs; save/load display presets | `copyVisibleROIPreset`, `score_copyROIChannelPreset`, dataseries preset methods, `Copy/Paste/Save/Loadpresets*` | Partial: per-view settings in memory only | Display preset actions; map by names, keep display-only changes distinct from data writes |
| S43 | Save selected ROI, cached cell model, modified ROI set; unsaved-change prompt | `SaveselectedroiMenuSelected`, `saveModifiedRois`, `notifyAnnotationChanged`, `ScoreAppUIFigureCloseRequest`, `roi.save`, `roi.saveCellModel` | Pending for scientific edits; Save Project is metadata-only | Explicit Save ROI / Save ROI data, dirty indication and close/switch policy before any scientific editor |
| S44 | Refresh ROI data after pipeline completion while preserving visible channel/data settings | `onPipelineRunCompleted`, `refreshROIDataFromDisk`, `refreshROIIntensityChannelsFromDisk`, preset collect/apply methods | Pending | Session/execution bridge; do not reload over unsaved work or force raw-path search |

## Important distinctions and verified static findings

1. **Dataset vocabulary:** `roi.data(k)` is a `dataseries` with a table; Score's New dataset button adds a variable/column to that table. It is not the same operation as selecting a classifier's training/annotation ROI set. The UI should keep a Data browser (`dataseries → variables → plot groups`) and classifier-bound Annotation sessions distinct while preserving DetecDiv vocabulary.
2. **ROI versus mask drawing:** the existing ROIs assistant defines extraction regions on a raw FOV. Score painting changes object labels inside a selected ROI/mask provider. They must use different tool modes, cursors, scopes and persistence commands on the same Image viewport.
3. **Linking has several meanings:** frame instance → stable track, track → parent, bud pairing and visualization of genealogy. A generic Link button without an explicit relation and temporal scope would lose semantics.
4. **Named helpers are not necessarily backend APIs:** many `score_*` functions take `app`, use classic-figure callbacks, access tables, or call `score_display`. Reuse their underlying `cellModel`, `annotationManager`, `sam31` and processing packages through small session/action adapters. Do not fabricate a second full Score app object to satisfy all callbacks inside the new viewer.
5. **Save Project is insufficient for editing:** it writes lightweight project JSON. Scientific edits can require ROI H5 channels, data MAT, a cached cell model and annotation manifests/review state. A unified dirty/save controller must account for each store, propagate failures, and leave unsaved data recoverable. Do not promise atomicity across these stores without implementing it.
6. **Undo is not general in legacy Score:** `score_fissionCorrection` has a specific guarded undo record. This does not establish undo support for every brush/delete/relabel/data action. Design per-action reversible changes before enabling destructive editors; bound undo memory explicitly.
7. **Declared menus are not all operational:** New dataseries/New dataset/Duplicate dataset menu callbacks have empty bodies. The first two corresponding buttons contain implementation; Duplicate dataset is not demonstrated by that menu. Compute metrics in object has a menu declaration but no registered callback in the reviewed source; the ellipse context action reaches `quantifyChannelFluo` through another route. Several older empty callback variants are superseded by registered numbered variants. Do not count the obsolete variants as missing functional navigation.
8. **An export callback needs correction when ported:** `MovieoutputtypeDropDownValueChanged` uses `selectedROI.path` without defining `selectedROI` locally, and assigns the two-output `fileparts` results as `[fle,pth]` then builds a path as if they were name/folder. The file picker advertises MAT whereas current movie rendering uses VideoWriter profiles and sequence output is PDF. Normalize the effective output contract rather than copying these controls verbatim. These are static findings, not an executed failure report.
9. **Exports need an isolated render canvas:** Score already separates its export figure from interactive refresh. Preserve this so queued image updates cannot clear a running export. Existing bulk renderers consume ROI image stacks; on-demand raw access and large exports need a bounded frame-loading adapter, not an unverified promise of fully lazy export.
10. **Data plotting needs a small safe adapter:** `score_displayDataPanel` still resolves `dataColormap` through an `eval` expression. Restrict the migrated setting to validated supported maps. Preserve categorical labels, vector expansion, group bounds and time alignment; do not reduce every dataseries to one numeric vector.

## Widget responsibilities

New dockable widgets are explicitly part of the migration when a task needs its own workspace area. Their boundaries follow user tasks and simultaneous viewing needs, not the old Score tabs or the internal class hierarchy.

| Surface | Responsibility | Placement and lifetime |
| --- | --- | --- |
| Projects (existing) | Project/FOV/ROI browsing and links to classifiers/processors/pipelines | Left; remains the shared navigation source |
| Image (existing) | Single image viewport, temporal navigation, selection and all drawing gestures | Central; no separate image window for each tool |
| Display (existing) | Layers, color/contrast/histograms, fill/contour appearance, scale bars | Right; changing appearance does not enable scientific editing |
| Define ROIs assistant (on-demand tab) | Define extraction geometry on raw FOVs | Opened explicitly from Edit, image/Projects context menus or Pipeline; Done dismisses it and retains the draft; independent of mask editing |
| Objects (new) | Selected object/track, family/provider, read-only lineage context; later track/link/split/delete actions | Right; may stay open alongside Display or Data; explicit edit scope for scientific actions |
| Data (new) | Dataseries/variable browser, plot groups and plots synchronized to Image | Normally below Image; compact selector with detailed settings on demand; one initial dockable document with an internal split rather than mandatory separate browser/plot windows |
| Annotation (new) | Brush/mask settings, classifier-bound session, GT/prediction source, review/validation actions | Right; drawing uses Image; advanced initialization/validation findings open dialogues |
| Lineage (optional new) | Tree and track navigation when simultaneous image/tree inspection is useful | Bottom or floating; existing tree dialog can serve as the first integration before adding a dedicated document |
| Measurements assistant | Line/ellipse geometry and profile controls | Contextual tool; plot in Data or an assistant panel. Create a separate document only if simultaneous inspection requires it |
| Pipeline (existing) | Compact graph, run selection and status | Dockable; common settings dialog and pipeline2 Advanced keep the same configuration |
| Hub (new) | Shared connection, identity and server status, independent of job submission | Dockable; common session controller reused by Pipeline/Export/project clients. See [DETECTIVE_UI_HUB.md](DETECTIVE_UI_HUB.md) |
| Export dialog | Movie/sequence scope, output options, preview and launch | Open through File; isolated rendering canvas. Do not permanently occupy workspace space with a full export form |

Objects, Data and Annotation are planned widgets, not implemented controls or empty placeholders. Add each when its first usable backend integration is available. Lineage and Measurements can become independent widgets when the actual interaction benefits from it; an assistant or dialog is sufficient initially.

Hub is another planned independent widget. Authentication/connection belongs to a common process session backed by existing Hub helpers and broker; each execution tool retains its own job settings. Opening Pipeline must not be required to connect to Hub, and future widgets must not recreate separate connection forms.

All widgets share the viewer session's project, ROI, frame, channel/provider/family and selected instance/track. They do not own competing copies of the current scientific selection. Data → Image and Lineage → Image navigation must use explicit shared selection events and avoid feedback loops. Tool-local preferences can persist per context; pending scientific edits remain under the common dirty/save controller. A hidden widget must not continue intercepting image gestures.

Expose available widgets through View; create them on demand, allow native docking/floating, and remember their layout. Default layouts keep Image dominant and avoid opening every widget at startup. Adding document IDs requires a backward-compatible layout migration: preserve the geometry/visibility of existing documents and initialize new ones hidden or on explicit opening. No empty sidebar sections, automatic pixel loads or duplicate scientific containers are needed just to advertise future widgets.

## Proposed implementation sequence

| Stage | Deliverable | Acceptance condition |
| --- | --- | --- |
| 1 | Complete read-only Display/Objects controls: contours, fill, widths, units, provider/family selection and semantic/lineage rendering | Same source pixels and object identities as Score; correct mask/family/provider targeting; no scientific mutations; wide/floating and compact layouts checked |
| 2 | Data browser + dockable plots synchronized to Image | Numeric/categorical/vector data, groups, actual time units, bounds and current-frame markers match Score; changing ROI/project clears stale selections; values load on demand |
| 3 | Export dialog, starting with current ROI, then multiple ROIs/data panels and Hub | Export image matches a frozen display snapshot; FPS/frame range/profile/path correct; isolated canvas; failures/cancellation clean up; preview does not modify the interactive view |
| 4 | Scientific edit/save controller and bounded undo infrastructure | Dirty state covers pixels/data/model/review; Save ROI differs from Save Project; failure/close/switch behavior tested; no silent overwrite on pipeline refresh |
| 5 | Object selection, brush/erase, split/delete, track IDs and linking | Reuse backend actions; explicit frame/from-frame/all scope; mask↔model consistency; gestures/shortcuts cannot fire on an inactive edit target; reversible edits verified |
| 6 | Full Annotation/Review workflow and Data editing | Correct classifier/session ownership, prediction→GT provenance, sequence bounds, review invalidation, findings/approval and persisted manifests; no regression in existing Score workflows |

Stages 1–3 provide useful capabilities without enabling scientific edits. Stage 4 is a dependency of stages 5–6, not a later polish item. Basic movie export can begin before complex Data plots, but full export parity depends on stage 2. Keep the current legacy Score entry points available while each capability is migrated and checked.

## Cross-cutting contracts for every port

- UI remains English, image-centered, dockable, and uses conventional menus. A compact contextual widget opens detailed settings only on demand; no permanently visible tutorial text.
- Pin each action to project, ROI, frame range, channel/provider, family and selected object/track. Reject stale callbacks after navigation or pipeline refresh.
- Display preferences, pending edits and execution configuration have separate lifetimes. Persisted run configuration stays compatible with the existing Pipeline bridge.
- Register/unregister image gestures in one interaction controller; navigation, ROI rectangles, mask painting, object selection and measurement lines must not overwrite each other's callbacks.
- Keep preview/display caches separate from scientific data. Reuse provenance and invalidation reports from backend actions.
- Review existing progress/cancel behavior and nested window ownership before porting. Hidden tools route progress to a visible owner. Display cache operations are scoped; batch work uses real progress where available.
- Do not introduce a new project/dataset schema or change ROI raw/H5 storage as a side effect of the UI migration. Raw-data virtualization remains a separate compatibility study.

## Verification baseline and limits

Existing Score regression sources cover mask editing, annotation sessions/comparison, sequence windows, latent-signal annotation, lineage navigation/tree/comparison, fission correction, cell-model cache and binary-fission overlays. Their presence is recorded, not a claim that all pass on the new viewer. Existing viewer tests cover its implemented navigation, display/histograms, docking, lazy image loading, Pipeline/ROI assistant and progress ownership.

Each stage needs targeted integration checks against these sources, plus a representative real acquisition. This audit does not launch inference, write scientific data, generate a movie or submit a Hub job. It also does not claim exhaustive coverage of dynamically reached external tools. The inventory and feature IDs make omissions reviewable rather than silently dropping advanced capabilities.
