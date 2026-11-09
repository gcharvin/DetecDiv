> Superseded user vocabulary and shared-provider editing policy: see
> [Annotations](DETECTIVE_UI_ANNOTATIONS.md). The document key and class name
> `Objects` below remain for compatibility; visible UI uses Annotations.

# Objects in the shared workspace

Objects is an independent dockable document beside Display and Pipeline. Display owns the active layer, channel visibility, contrast and histogram controls. Objects follows that layer and hosts the Contours/Tracks assistants. The image remains the shared viewport.

## Browser and selection

- There is no independent family chooser. Selecting a layer in Display determines the mask provider and associated object family. A compact read-only label identifies the family. An intensity layer with no associated family clears the objects table and disables image editing, without discarding pending edits. Unregistered indexed layers are identified as `(labels)`; browsing them does not create a cellular model or assign track identities.
- The lower table follows the current frame and lists mask label, track ID, parent and state. Track/parent values retain their exact `uint64` identities, including IDs above the floating-point exact-integer limit.
- The family readout uses one 22-pixel line. The selected object row uses a blue, bold highlight; Image retains the selected-mask outline as a separate cue. These styles are local selection state, not saved family colors.
- A valid label layer enables object selection/editing when the Objects browser is visible, retaining Display visibility and color choices. Selecting an object locates it on the image; opening Tracks retains the exact family and selected instance. When multiple registered families share a physical provider, editing is blocked. Separate Layers... creates independent providers while preserving result identities. No family chooser is imposed in the browser.
- Contours, Tracks and Lineage open the existing tools. Brush/polygon tools and linking controls remain contextual assistants rather than another display-mode configuration tree.

Returning from Tracks to the browser resumes selection for its current valid family/object. A hidden document cannot resume editing from a delayed table event; reopening Objects remains explicit. Display adapts independently when stacked above it, retaining a minimum Layers area and exposing the detailed histogram through `Hist.`. See `DETECTIVE_UI_DISPLAY.md`.

## Data and edit ownership

Opening projects remains metadata-only. The Objects widget can inspect already-cached family metadata; loading ROI pixels or the object sidecar follows explicit opening/loading or family selection. No legacy migration runs automatically. Model read failures remain in the Objects status line and cannot clear the main image.

Objects does not own another editing model. It consumes the same `MaskDraft` objects used by Contours and Tracks, reuses Score's mask-provider/model helpers and delegates operations to the existing mask and cell-model functions. Undo, Redo and Save Edits operate on that shared draft. Browsing and changing display defaults do not save pixels, object files, ROI display metadata or project JSON. Hiding Objects releases image editing callbacks while preserving pending edits and normal close/save protection.

Current-frame refreshes reuse cached metadata and the active provider draft. Changing Display to another label provider attaches its shared draft on demand when Objects is visible. Hidden Objects never enables image editing from a layer change. Queued object selections are rejected after ROI/frame/layer context changes.

## Validation

`detecdivui.objectsTest()` exercises same-provider family distinctions, exact track IDs, multicolor/edit defaults, selected objects, shared mask history, explicit save/reload, frame updates, stale selections, ROI isolation and independent Objects/Display docking. The existing `contourTest` and `tracksTest` follow the assistants into Objects; `contoursTest` continues to cover Display's vector rendering controls.
