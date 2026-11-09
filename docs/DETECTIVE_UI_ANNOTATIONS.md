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
