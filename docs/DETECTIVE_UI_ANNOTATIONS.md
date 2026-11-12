# Annotations: masks and tracks

The dockable **Annotations** widget replaces the visible **Objects** name.
**Masks** are indexed image layers; **Tracks** hold identities across frames
and their parent/child links. A mask value is a label, not a track identity.
Object families remain an internal compatibility concept in the cell model.

## Selection and tools

Select the mask layer in Display. Annotations follows that selection and lists
the current frame's regions, exact track IDs, parents and states. There is no
second layer or family selector in Masks/Tracks. The same contextual tools work
on project ROIs and classifier ROIs. Masks supports painting, erasing, drawing
and contour editing; Tracks supports explicit assignment, linking and lineage.
They share one provider draft, Undo/Redo, Discard and Save Edits.

Click a visible mask in Image to select its Display layer and highlight the
frame-local label. Where masks overlap, the uppermost visible layer wins.

Turn **Paint** on in Annotations to edit the selected layer. Turning it off
returns to mask selection and keeps unsaved edits available for **Save Edits**.
Painting shows the contextual toolbar above the image. Brush is the
initial tool. Click a mask to pick its frame-local label, or drag to paint
with the disk brush. Starting on empty pixels creates a new label for instance
masks. A stroke previews the affected pixels and creates one
undo entry on release. Shift or Ctrl held at the start of a stroke erases.
Use **[ / ]** to resize the brush and **K** (the default Score shortcut) to
fill holes in the selected mask. A solid amber outline identifies **Mask N**
on its selected frame. Double-click an assigned mask to select **Track N**
with a dashed cyan outline that follows its identity across frames.

Parentage is part of the ordinary Image rendering, including read-only review,
with or without Annotations/Tracks open. **Parent links** toggles it for the
selected mask layer, independently per FOV/ROI view. It defaults to on when a
unique tracking result provides relations. The tooltip reports the relation
count and first event frame; before that event the status identifies its frame.
Existing parents are not inferred from spatial proximity or reused pixel labels.
The Score `cellModelLineageSegments` helper determines current/historical
endpoints and binary-fission sister links. Shared legacy providers do not borrow
an arbitrary family's parentage; separate the results to inspect them individually.
Visible mask layers carry their own links in overlay and separate-channel views.
Hidden masks do not retain links, and an unrelated selected mask never inherits
another provider's relationships. Line/contour display, presets and export share
the same per-layer setting. Undo/Redo redraws the pending model without saving.

Classifier Review is read-only. In Edit, the declared GT layers are editable;
prediction layers remain read-only in that classifier context. Semantic GT uses
a class palette from its package contract, including Unlabeled (0). It does not
offer track operations. Instance masks retain numeric labels and track tools.
Newly painted regions start with an unassigned track ID, even if another frame
uses the same pixel label. Existing same-frame identities are preserved.

## One editable tracking result per mask layer

**New Tracks...** on a project ROI copies the selected masks to a new, uniquely
named layer and creates a manual tracking result with all identities unassigned.
It does not infer trajectories from pixel labels.

Legacy files with several tracking families on the same mask layer stay
readable. Editing is blocked until **Separate Layers...** is applied. The dialog
lists the result, original mask and destination layer before writing anything.
One result keeps the original layer; every other result receives an exact mask
copy and its own provider. Family, object, track, state and relationship IDs
are unchanged, including uint64 identities above 2^53. In classifier context,
the declared GT family retains its original provider to preserve its contract.

Cancel and browsing do not mutate data. Create Layers saves the new H5 datasets,
ROI display metadata and model sidecar through existing ROI methods. The source
ROI in memory updates only after all writes succeed. Incomplete saves stay open
for Retry; normal app/project close is blocked. Forced deletion writes a recovery
MAT file under `prefdir/DetecDivUI/annotation-layer-recovery`, containing the
planned mask copies and model rather than another raw image volume. Recovery
files are diagnostic/manual recovery artifacts, not an automatic restore flow.

This is an explicit viewer editing policy, not a global model-schema migration.
Existing classifiers and historical runs retain their numerical behavior and
provider mappings until the user applies separation to a concrete ROI. Future
backend outputs that intentionally share masks remain compatible and are
presented as shared/read-only until separated in this editor.

## Compatibility and validation

Legacy class names, callback tags and the docking key `objects` are retained so
saved layouts and callers continue to work; the visible title/menu is
Annotations. `Host.widgetFigure('Annotations')` and `openAnnotations()` expose
the new terminology.

Tests: `annotationLayersTest` covers planning, exact mask/identity preservation,
H5 reload, partial-save retry and unassigned IDs; `objectsTest` covers explicit
shared-layer separation and shared editing; `annotationsTest` covers semantic
GT, classifier access and the common editor. Existing mask/track draft tests
continue to exercise the reused editing and persistence functions.

`lineageDisplayTest` covers first-event timing, historical endpoints under label
reuse, provider/ROI isolation, native toggles, read-only display, shared draft
parent edits and undo, separate panels, presets and immutable movie snapshots.
Snapshots retain the resolved segments for each exported frame, including
historical endpoints outside the requested frame range, without adding raw
history or whole cellular-model trees to the worker bundle.
