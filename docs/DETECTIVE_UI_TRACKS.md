# Tracks and linking on Image

## Context and selection

Select an extracted ROI with a loaded indexed mask, then use Edit > Edit Tracks..., the Image context menu or Objects > Tracks.... Tracks is an on-demand assistant tab inside the independent Objects document; the browser is that document's first tab. Display remains available alongside it for channel, contrast and histogram adjustments, while Image remains the shared viewport. Done removes Tracks' overlays and mouse callbacks while retaining annotation drafts. Objects can float/redock with the assistant open; native document Close hides it and View > Objects reopens the retained document. Provider/family changes and leaving the ROI cancel an armed link pick.

Choose the physical mask provider and its object family, or enter Tracks from the already-selected Objects browser row. The browser's default shows masks in multicolor with image selection/editing enabled; entering Tracks retains the exact family and selected instance. Two families using one physical provider remain separate selections. Click an object in Image to inspect its frame-local mask label, track ID, parent, canonical event frame and first/last appearance. These are distinct identities: track reassignment never renumbers mask pixels. Track IDs are parsed as exact uint64 decimal strings, without an intermediate double. Read-only inspector fields allow selecting/copying their values and expose the complete value in tooltips.

Objects, Contours and Tracks share the current selection and the same ROI/provider draft. Family IDs, physical mask-provider names, mask labels and track IDs retain their own meanings; changing the display channel does not replace that edit target. Tracks follows a selected biological track across frames even if its mask label changes. A track absent on the current frame cannot be reassigned through a guessed contour; select an object actually present on that frame. Hiding Objects releases editing callbacks without saving or discarding its draft. Application/project closure keeps the shared Save/Discard/Cancel protection.

## Identity editing and linking

| Action | Scope and existing implementation |
| --- | --- |
| Assign | Target ID, with This frame / From this frame / Whole track (`frame` / `to-last` / `all`); `cellModel.reassignTrack` |
| New Track | First unused positive ID from `cellModel.nextTrackId`, then the selected reassignment scope |
| Pick | Select the source object, arm Pick, navigate if needed, then click an object in the destination track; uses scoped reassignment for continuity |
| Swap IDs (all) | Exchange both complete track identities, including parent/child references and censoring, through `cellModel.swapTrackIds`; the reassignment scope selector does not limit this action |
| Set Parent | Apply Target as the selected child's parent, using `cellModel.setParentTrack` |
| Pick Parent | Select the child, arm Pick Parent, optionally change frames, then click the parent |
| Remove Parent | Remove that child's parent relation through the same backend |
| Delete Track (all frames) | `cellModel.removeTrack` removes the entire track and its relationships/censoring; reported mask labels are erased with `score_editMaskPlane`; Undo restores model and pixels together |

These are the same model operations used by `score_assignSelectedTrack`, `score_swapSelectedTrackIds`, `score_setSelectedParentTrack` and Score's whole-track deletion. Their GUI wrappers can write immediately or assume Score controls, so the new assistant calls their existing backends inside the shared transaction rather than instantiating Score or imitating its app fields.

An armed pick stores the source ROI, provider, family, frame, mask label, track and temporal scope. Picking a destination never replaces that source selection. Before applying, it checks that the original instance still belongs to the same track. Escape cancels; editing scope/target or changing ROI/provider/family cancels the pending pick. Destination conflicts are errors, not implicit overwrite/detachment of another object.

Parentage uses Score's temporal convention, not the frame where a parent happened to be clicked: the stored event is the child's first appearance. Budding requires the parent on that birth frame; binary fission requires the parent to end immediately beforehand. Family/provider resolution and schema checks remain in the existing `cellModel`/Score helpers. This editor does not automatically approve annotations or replace the full managed Annotation/Review validator.

## Image and keyboard

Track IDs and selected-object boundaries are drawn on the active Image panel. Parent links use `cellModelLineageSegments`, the same helper as Score's lineage overlays. It handles historical endpoints, mask-label reuse, and the current sister link in binary fission. Link colors/width come from `score_getObjectDisplayConfig`. The renderer uses the draft model/masks without changing canonical ROI display metadata or model files.

Frame arrows and Score's configured ten-frame keys remain available. Ctrl+Z/Ctrl+Y traverse the shared annotation history. Escape cancels picking. Delete keeps Score's current-frame contour meaning; it does not invoke whole-track deletion. Text inputs, numeric fields, sliders, tables and other widgets keep their own keys. Help > Keyboard Shortcuts... refreshes its list and includes Tracks after it is opened.

## Legacy input

When the selected provider has no cellular model, Import Legacy explicitly calls `cellModel.fromLegacy` for that provider. Existing stable mask IDs become track IDs and compatible legacy cell-information references are reused. Missing data MAT content is loaded into the scratch ROI, not over the live ROI. Import is undoable and remains in memory until Save Edits; opening the assistant never migrates data automatically. If a model exists without a family for this provider, select a registered provider or prepare the family with the existing model tools rather than silently replacing the model.

## Shared transactions and persistence

The existing `MaskDraft` now stages both mask planes and a working cellular model. Contours and Tracks use one chronological undo/redo stack per canonical ROI/provider, with the same 20-command / 64 MiB target. Undoing a track deletion restores its mask frames, identities, parent links and censoring as one operation. Mask edits are reconciled through `score_syncCellModelFrames` for every family referencing that physical provider, on a scratch ROI.

Save Edits commits the selected provider's combined mask/track draft. File > Save Masks retains its existing role of saving all pending annotation drafts, including associated model edits. Pure identity/parentage edits leave the image H5 untouched when it already exists. Only the model and changed annotation lifecycle data need writing; a placeholder-only dataseries is not treated as a failed MAT save. A missing image H5 is materialized explicitly for the selected provider when saving an import.

Persistence reuses `roi.save`, `roi.saveCellModel` and the annotation lifecycle helpers. Model edits conservatively clear review marks across the ROI's frames; edited bundles remain draft/unapproved. In-memory source pixels/model/data remain unchanged until all required writes succeed. File/model/cache conflicts and partial multi-file failures retain a dirty, retryable draft, as in Contours. Normal close offers the same asynchronous Save / Discard / Cancel continuation. Forced-delete recovery now includes baseline/working models as well as mask data; older mask-only recoveries remain readable. See `DETECTIVE_UI_CONTOURS.md` for storage/retry/recovery details.

An ROI has one shared model file even when it has several mask providers. The UI requires saving/discarding another provider's pending edits before making model changes, and blocks editing another provider while a model draft is pending. This avoids independent whole-model snapshots overwriting each other. When a provider save rebases a clean model draft, obsolete whole-model undo/redo snapshots are cleared; otherwise a later redo could erase the committed provider's changes. It does not attempt automatic merging of independently edited models. Source changes from other applications are still rejected at save.

## Validation

- `detecdivui.trackDraftTest()` checks scoped continuity assignment and atomic conflict rejection, whole-track swapping, parent removal/undo, exact large uint64 IDs, model-only save/H5 invariance, complete track deletion/undo, combined mask/model chronology, explicit legacy import/recovery, family-specific edits, synchronization of two families on one mask provider, and binary-fission event/segment conventions.
- `detecdivui.tracksTest()` exercises the actual assistant, parent/continuity picks across frames, native genealogy/selection overlays, CEF undo keys, identity scope, ROI isolation, Contours handoff/shared history, cross-provider edit guards, exact-ID inspector fields, Done, native float/redock, explicit model persistence and asynchronous close cancellation/discard. Pass a PNG path to capture the workspace.
- `detecdivui.editorCloseTest()` verifies a clean native X-close with Tracks or Contours active, without destructor warnings or leaked menu timers. Cleanup restores callbacks/interactions only while the image figure still exists; native application shutdown can destroy figures first.
- `detecdivui.objectsTest()` covers browser-to-Tracks handoff for two families sharing one mask provider, exact IDs above the floating-point exact-integer limit, current-frame tables, shared mask undo/save, provider isolation and Objects floating/redocking while Display remains available.

Interactive picking still needs validation on representative real acquisitions. Guided two-child fission correction, track propagation with SAM/IoU, censoring controls, cell-state editing and mask-ID relabeling remain separate Score integrations.

## Lineage tree

**Lineage...** opens the existing `score_lineageTreeDialog` renderer on the current provider/family's draft model. Its Refresh command rebuilds from that same draft, preserving the tree's lane and vertical view. It does not save or reload over edits. Clicking a track selects its exact uint64 identity in Tracks and navigates Image to its first frame through the shared viewer selection.

Each viewer owns its own tree figure, independently of legacy Score. Leaving Tracks, changing ROI/provider/family, or closing the viewer closes its associated tree. Callback tokens reject queued clicks from previous trees; drawing gestures block timeline changes. The tree helper's default singleton tag, labels and double-valued callback remain compatible with Score. The new viewer explicitly requests a scoped figure tag and uint64 callbacks.

The native Tracks test also checks tree/image navigation, draft/source isolation, coexistence with the legacy Score tree, explicit refresh, exact IDs above 2^53, stale callbacks and contextual cleanup. The existing five Score lineage-tree unit tests remain part of validation.
