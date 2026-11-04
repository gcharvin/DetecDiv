# Contour editing on Image

## Entry points and scope

Select an extracted ROI with a loaded indexed annotation mask, then choose Edit > Edit Contours... or the Image context menu. The on-demand Contours tab appears in Display. It is independent of Pipeline and different from Define ROIs, which edits extraction rectangles on raw FOVs. Done removes the tab, selection outline and image callbacks while retaining its drafts. Display/Contours tab switching suspends and restores the editing tool. Project/FOV/ROI navigation retains drafts by canonical ROI handle and resolved mask provider. Closing a project releases its records after resolving unsaved changes.

The provider selector lists indexed mask layers, including the legacy zero-intensity convention. `score_resolveMaskProvider` resolves the authoritative channel/family; it never assumes a mask from its channel order. RGB/multi-plane and intensity channels are rejected. Cached temporal windows with a nonzero `write_abs_start` require loading the complete sequence. The Label field is a mask label, not a track ID.

## Tools

- Select: click an object in the main image; its label and boundary are highlighted.
- Polygon/Freehand + Draw: draw in source-pixel coordinates, double-click to complete, Escape to cancel. New ID uses the next global label across the provider's frames. Drawing can also extend an explicitly selected label.
- Edit: adjust the selected connected object's outer boundary, then double-click to apply. Existing holes are retained. Disconnected objects require Brush rather than silently dropping components.
- Brush/Eraser: drag and release to commit one undoable stroke. A path preview follows the pointer. Radius is in source pixels; Shift temporarily erases. With no selected label, starting on an object reuses its label; background painting allocates a new ID.
- Fill Holes and Delete operate on the selected label on the current frame only. Overwrite other labels defaults off. Erasing intentionally clears pixels under the brush.
- Undo/Redo retain at most 20 frame transactions, with a 64 MiB history target (one unusually large transaction is retained). A successful save clears history; it does not offer an apparent undo of already persisted disk data.

Score and the assistant share the pure `score_editMaskPlane` disk-brush primitive. Score's paint overlay calls it directly; it retains its existing selection, track synchronization, rendering and persistence callbacks. Other operations use MATLAB ROI geometry, `createMask`, `bwboundaries` and `imfill`. No alternative segmentation or tracking implementation is introduced.

The assistant temporarily owns mouse callbacks and suspends image pan/zoom interactions. It restores their previous values on dismissal, and reattaches to newly created image axes after display-layout changes. Drawing uses the shared gesture guard. The mask selection is drawn on the active image panel; label overlays remain shared in separate-channel mode.

## Keyboard

While the Image canvas is focused and Contours is active:

| Key | Action |
| --- | --- |
| Left/Right Arrow; Score's L/M pair by default | Navigate one/ten frames |
| Delete | Delete selected label on the current frame |
| K by default | Fill selected label holes; shares Score's paint-fill preference |
| G/H by default; Down/Up Arrow | Decrease/increase selected mask opacity; shares Score's opacity preferences |
| Ctrl+Z / Ctrl+Y | Undo / redo mask edit |
| Escape | Cancel pending stroke and return to Select; native geometry tools handle Escape during drawing |
| Shift + brush drag | Erase |

Keys do not intercept text/number edits, tables, sliders, menus or other widgets. Help > Keyboard Shortcuts... includes the editor bindings once the assistant has been opened. Ctrl+S remains Save Project and does not save masks. Use Save Masks for scientific mask edits.

## Drafts and persistence

`detecdivui.MaskDraft` holds an isolated channel volume and bounded frame history. Canonical ROI images, data and cell model remain unchanged during editing. LayerModel reads staged label planes through an optional callback; only edited indexed providers are replaced, never raw intensity pixels. The assistant marks its target with `*`, and Image status shows Unsaved masks even after Done.

The widget Save Masks saves its current provider. File > Save Masks saves all pending providers/ROIs, stopping on an error. Before saving, each draft checks the original in-memory provider pixels, channel mapping, cached model, and H5/MAT/objects file timestamps/sizes. Conflicting external changes are rejected rather than overwritten. Successful saves of another provider on the same ROI rebase that ROI's remaining drafts onto the updated model/files without replacing their pixels.

Save builds a scratch ROI and independent dataseries handles, applies the staged pixels, then calls `score_syncCellModelFrames(...,'Save',false)` and the existing `roi.save({provider},false)` / `roi.saveCellModel` writers. The save path preserves raw channels and other frame contents. Approval/validation is conservatively invalidated for existing annotation bundles on that ROI; review marks for edited frames are cleared, using `annotationManager.resetValidationState` and `writeManifest`. Classifier-specific review invalidation can become more selective with the future Annotation session widget.

The existing writers provide per-file staging; this is not a multi-file atomic transaction. A later MAT/model failure can follow an H5 write. Such a failure keeps the full draft dirty and the canonical in-memory ROI unchanged, retains the actual error, and permits Retry after fixing the storage problem. Discard is blocked after an incomplete save until a successful retry. Retrying reconciles every model frame. A draft is marked clean only after all writers succeed.

Normal application/project closure offers an asynchronous modal Save / Discard / Cancel dialog. The native window's CanClose callback first vetoes closing; only a successful save/discard continues the exact requested action. Old dialog callbacks carry a generation token so they cannot discard the next ROI's draft. The dialog has its own scoped save progress and retains write errors for retry. Programmatic `delete(viewer)` cannot be vetoed by a MATLAB handle destructor, so remaining drafts are written as recovery MAT files under `fullfile(prefdir,'DetecDivUI','mask-recovery')`, with a warning containing the path. They contain the source ROI/provider identity, baseline, staged masks and incomplete-save flag. To restore a compatible recovery into the current provider:

```matlab
saved = load(recoveryFile,'draft');
draft = viewer.Masks.current();
draft.restore(saved.draft);
viewer.contourChanged();
```

Restore rejects another ROI/path/provider or conflicting current pixels. Recovery files are not scientific exports or automatically applied to project data. Preserve them until the restored draft is saved and verified.

## Validation and remaining work

`detecdivui.maskDraftTest()` checks exact Score brush coverage at edges, source isolation, fill/delete/undo/redo, H5 round-trip, model track preservation, annotation invalidation, an actual MAT file-lock failure after H5 writing, successful retry, external-edit conflicts, recovery restore and consecutive provider saves. `detecdivui.contourTest()` exercises the native assistant, selection outline, a native polygon/createMask, real CEF key events, opacity/frame navigation, Done callback restoration, retained drafts, floating/redocking Display, explicit H5 saving, native X-close cancellation, save-and-close-project continuation and discard-and-close-app continuation. A screenshot is optional via its path argument.

Interactive freehand/vertex gestures still need testing on representative acquisitions. Current scope does not include new mask-channel creation, painting a selected track identity across frames, watershed splits, relabel/track swaps, lineage linking, SAM propagation, or classifier-managed Annotation/Review sessions. Those remain separate integrations from the Score parity roadmap.
