# DetecDiv UI guidelines

Reference: discussion with Gilles, 4 November 2026, and `DETECTIVE_UI_ROADMAP.md`.
The requirements below supersede the earlier French labels, renamed data concepts and permanently visible guidance text.

## Required desktop conventions

- **English UI.** Menus, labels, tooltips, status messages and app-generated errors use English. Preserve user-provided project, FOV, ROI and channel names verbatim.
- **Conventional menu bar.** Use File, Edit, View, Navigate and Help. Commands must invoke available actions; do not add placeholder commands suggesting unsupported capabilities.
- **DetecDiv vocabulary.** Use Project, FOV, ROI, Classifier, Processor and Pipeline. Do not replace FOV and ROI with a new naming scheme.
- **One project tree.** Show the actual Project → FOV → ROI hierarchy, with multiple open projects in the same tree. Project navigation and task-oriented tools complement one another.
- **Image first.** Keep the central viewport dominant. The Projects and Display panels can be hidden through View.
- **Real docking.** Projects, Image, Display, Pipeline, Objects and Data are independent native docking documents. Each can float, redock or change position without reconstructing its contents. Native document Close hides it; View reopens the same controls and retains scientific drafts. Application/project close retains its explicit unsaved-edit handling. Save and restore the workspace layout across launches, and preserve older saved arrangements when adding documents.
- **No explanatory paragraphs in the layout.** Remove onboarding text, next-step essays, disclaimers and decorative workflow slogans. Use concise control labels and MATLAB tooltips. Keep the bottom status bar for the current view or an actionable error. Hover-driven status help can be added if it works reliably with native components; standard tooltips are the initial implementation.

## Interaction rules

1. Selecting a FOV or ROI updates the same viewport and synchronizes the tree and breadcrumb. Clicking an ROI outline selects that ROI in the tree.
2. Opening a project adds it to the workspace. Focusing an already open project does not create another copy. Closing removes it from this window without saving or deleting scientific data.
3. Keep each project's current FOV/ROI, frame and named channel while browsing other projects. Preserve zoom within temporal navigation of one view; fitting the image is an explicit command.
4. Empty legacy placeholders are hidden, while object indices remain unchanged. Display user names alongside FOV/ROI indices.
5. Show reference ROI geometry as reference geometry. Do not infer tracking or drift correction. Clear old pixels after a failed read.
6. Contextual tools expose useful defaults first, with detailed parameters and the pipeline available on demand. Guiding an action must not require a permanent tutorial beside the image.
7. Treatment commands must make selection, output naming and replacement behavior clear. Scientific logic stays in backend modules; pipelines retain provenance.
8. Native tooltips and enabled/disabled commands communicate availability. The colour of a contour is not the only selection cue; the project tree also identifies the active ROI.
9. Every integration from Score, DetecDiv, Workflow or Pipeline must review progress UI and caller/destination ownership. Long operations show a scoped widget/footer indicator before blocking; reuse real backend callbacks and preserve cancellation where supported. Use indeterminate progress without a measurable fraction. Hidden-widget work falls back to a visible owner. See `DETECTIVE_UI_PROGRESS.md` and regenerate the audit when adding a handoff.
10. Keep Pipeline's operational view compact: an always-visible Open/Recent tree above one graph, then New Run/Settings and status. Single-clicking a template opens or activates its retained draft. Avoid redundant template dropdowns and nested navigation tabs. New Run/common settings belong in a dialog; the current Advanced bridge reuses pipeline2 with the same configuration and run identity. The future larger dockable editor must preserve pipeline2's features and share the same draft rather than create a parallel settings store.
11. Define ROIs on the main Image viewport, through an assistant opened explicitly by Define ROIs... or a pipeline step. Do not show a permanent ROIs tab at launch. Done dismisses the assistant without discarding pending geometry; inactive tools must release image gestures/handles. Keep it usable independently of pipelines; no Workflow image window in the new viewer path. Distinguish preview, project ROI creation and definition transfer to a run. Reuse engine packages, and keep pixel extraction explicit.
12. Use Score as the reference for Display functionality: rich channel rows, direct color selection, levels/weights and histograms. Keep scientific pixels unchanged and share rendering/statistics helpers. Rich web controls must stay inside the existing dockable document, work offline and reject stale context events.
13. Preserve Score functionality against the capability IDs in `DETECTIVE_UI_SCORE_PARITY.md`. Keep raw-FOV ROI geometry, ROI mask editing, quantitative dataseries variables and classifier training datasets distinct. Scientific editors require explicit dirty/save and reversible-action handling; metadata-only Save Project must never be presented as saving mask/data/model edits.
14. Annotations and Data have independent workspace areas alongside Display. Annotations follows the selected mask layer and provides Masks/Tracks tools on the shared Image viewport. Keep mask labels and track identities distinct; expose one editable tracking result per layer. Legacy shared providers require explicit separation into dedicated layers before editing. Use the same drafts/history/save for project and classifier ROIs, respecting classifier Review/Edit and GT contracts. See `DETECTIVE_UI_ANNOTATIONS.md`.

15. Centralize Hub connection/identity in a shared session controller and independent Hub widget. Reuse existing settings/auth/dialog/broker helpers; Pipeline, Export and project clients consume this session and retain only their job-specific settings. No duplicate credentials forms, blocking startup checks or job cancellation merely from hiding/disconnecting the connection UI. See `DETECTIVE_UI_HUB.md`.
16. Preserve Score keyboard conventions and shared preferences. Bare browsing keys act on the focused Image canvas, including floating documents, without intercepting typing or native/widget navigation. Editing tools own their context-specific bindings. Show active navigation keys in Navigate and list available shortcuts in Help; keep an inventory of annotation bindings for their corresponding widgets. See `DETECTIVE_UI_SHORTCUTS.md`.
17. Keep contour edits separate from extraction ROI geometry. Display layer selection sets the Annotations target; open Masks on request for an indexed ROI mask. Shared tracking results require dedicated layers before editing. Stage changes, provide bounded undo/redo and explicit Save Annotations, and retain drafts across navigation/Done or document hiding. Reuse Score's provider/model helpers and ROI writers. Resolve dirty drafts before application/project closure, preserve recovery on forced deletion, and expose incomplete multi-file saves without marking them clean. See `DETECTIVE_UI_CONTOURS.md`.
18. Tracks is another contextual assistant under Objects, sharing Image, Contours' selection, provider draft, history and close/save controller. Keep family ID, physical provider, frame-local mask label, object identity, track ID and parentage distinct; two families can share a provider without sharing their track identities. Use Score/cellModel operations and canonical event frames; pin the child/source context while picking across frames. Make reassignment scope visible, keep swap/deletion whole-track scope explicit, and prevent independent provider drafts from overwriting the ROI's shared model. See `DETECTIVE_UI_TRACKS.md` and `DETECTIVE_UI_OBJECTS.md`.
19. Pipeline templates belong to Pipeline; run history belongs to its project. Keep Projects to Project/FOV/ROI navigation, the existing Processors collection, and a bottom project context panel with name, path/Copy and runs rather than object counters. Selecting a run shows its frozen graph in Pipeline; selecting a template shows its editable draft. Keep these identities explicit. Open/recent template browsing and path inspection/Copy remain in Pipeline. Single-clicking a recent entry loads it, while retaining unavailable references without startup source probes. Neither template selection nor run inspection executes processing or changes project/FOV selection.

20. Classifier distinguishes Review/Edit, training/inference, and static parameters/resource bindings. Browsing never creates GT or launches a model. Package contracts own choices and derived GT targets; expose common controls first and preserve specialized editors in Advanced. Initialize missing GT through annotationManager with overwrite disabled; keep existing GT, draft/undo/save semantics and readiness lifecycle. See `DETECTIVE_UI_CLASSIFIER.md`.

21. Keep one visible docking tab level for Display, Annotations and Pipeline. Display and the Annotations browser occupy their document bodies directly. On-demand ROI/Masks/Tracks assistants replace that body and offer an explicit return action, preserving drafts and controller state. Do not add a duplicate Display/Annotations tab strip beneath the document header.

## Initial menu structure

| Menu | Available commands |
| --- | --- |
| File | Open Project..., Recent Projects, Open Classifier..., Recent Classifiers, Save Project, Save Annotations, Export Movie..., New Pipeline..., Open Pipeline..., Save Pipeline, Close Project, Relink Raw Data..., Exit |
| Edit | Copy Image, Display Presets (Copy/Paste/Save/Load), Define ROIs..., Edit Masks..., Edit Tracks... |
| Pipeline | New Pipeline..., Open Pipeline..., Edit Pipeline..., Project Runs, Refresh Project Runs |
| View | Projects, Image, Display, Pipeline, Annotations, Data, Arrange Analysis Workspace, ROI Outlines, Fit Image, Reload Image, Refresh Workspace, Expand/Collapse Projects, Docking, Save/Restore/Reset Layout |
| Navigate | Parent FOV, Previous Frame, Next Frame, Back 10 Frames, Forward 10 Frames |
| Help | Keyboard Shortcuts..., About DetecDiv |

Open Project uses Ctrl+O, Close Project uses Ctrl+W, and Copy Image uses Ctrl+C. Save/edit/analysis commands will be added with their actual implementations.

Opening the workspace/project is metadata-only. Image I/O follows FOV/ROI selection or Load Image / Reload Image. A missing raw source offers Relink Raw Data... through the existing path tools; do not start a root search as a side effect of opening the application. No automatic analysis or pixel preload is scheduled after startup.

## Intent-driven workflow integration

Integrate business capabilities through **intent → state-aware pipeline proposal → execution**, as specified in `DETECTIVE_UI_INTENT_WORKFLOWS.md`. Segment Cells is an example, not a dedicated priority. The pipeline is a visible evolving plan that can be constructed or amended through user choices; it is more than a hidden implementation detail. The compact graph and advanced editor expose that same configuration.

Reuse compatible existing resources, ask only unresolved scientific questions, and show downstream impact before changing results. Creating a run is automatic when a task launches. Plan edits do not execute processing; keep historical execution configurations frozen while recording status changes and compatible resume attempts. View operations and scientific draft edits retain their own appropriate controllers.

Project import, drag-and-drop, ROI construction and analysis actions share this mechanism. Keep guidance contextual and maintain a semantic action history linked to existing run events/reports. Metadata discovery must not load models, activate Python or search raw roots.

## Remaining design decisions

- Classifier owns the classifier library, ROI dataset and configuration. Keep classifiers out of Projects. Processors remain a typed collection in Projects. Pipeline templates remain in Pipeline; project run browsing belongs in the context panel below the Projects tree.
- Extend the implemented layers/contrast controls to semantic mask rendering and scientific editing tools.
- Decide when single-click selection should be distinguished from double-click opening for grouped actions.
- Stabilize keyboard navigation, minimum window size and multi-monitor layout migration.
- Keep the docking shell code-owned; use the established App Designer / code-sync workflow for widget contents where useful.

## Validation

Verify navigation, pixels, tree selection, menu callbacks, project isolation and image limits in MATLAB. Inspect an exported window. Validate on a representative real acquisition before changing the default DetecDiv entry point.

The R2026a-specific integration and layout contract are described in `DETECTIVE_UI_DOCKING.md`. Classic menus are provided by an app-local menu adapter above AppContainer; the image, tree and display controls remain native MATLAB components.

## Display and analysis widgets

Display exposes a visibility table, an active layer, Solo, source-unit contrast, Auto, color, opacity and label rendering. Settings are local to each project's FOV/ROI view during the session. Selecting a layer edits its settings without changing visibility implicitly. See `DETECTIVE_UI_DISPLAY.md` for reuse of score and the validation scope.

Annotations can stay visible beside Display. Its region list follows the active mask layer; Masks and Tracks replace the document body as contextual tools. Shared mask providers remain read-only until explicit separation; each editable result then owns its layer. Missing optional tracking metadata does not invalidate Image. See `DETECTIVE_UI_ANNOTATIONS.md`.

Workspace discovery supplies the independent Classifier widget and the Processors collection in Projects. Live pipeline handles populate Pipeline's top Open/Recent tree; a single click displays the retained draft in the graph below. Project runs are listed with their status in the bottom Projects context panel and recall frozen graphs in Pipeline. New Run/Settings sit below the graph and use the shared settings dialog; advanced bindings and execution still reuse pipeline2 with the same run identity/configuration while the larger native editor is migrated. ROI definition uses the independent ROIs assistant on the main image. Connect guided actions to the same inspectable templates/runs, including compatible-model selection. See `DETECTIVE_UI_PIPELINE.md` and `DETECTIVE_UI_ROIS.md`.

Movie export is an on-demand Display assistant with isolated preview/output, explicit scope, real progress/cancellation and a frozen copy of layer/draft settings. Keep FPS separate from acquisition time, and keep full options in a typed dialog. See `DETECTIVE_UI_MOVIES.md`.
