# Correct a binary fission in Score

Open a classifier ROI through classifierGUI's **Annotate selected ROI** button.
Select the editable GT annotation channel, rather than the input segmentation
or the frozen tracking prediction. GT channels conventionally start with `gt_`;
Draft/Reviewed/Ready describes their validation state independently of naming.

1. Display the parent's last frame before division and double-click it.
2. Right-click its selection box and choose **Lineage: correct binary fission
   (parent -> 2 daughters)...**.
3. Score advances exactly one frame. Click the first daughter, then the second.
   The yellow instruction banner identifies the parent and the expected frame.
4. Score allocates two unused TrackIDs, propagates them along the selected
   existing track segments and creates both parent links together. The parent
   terminates on the previous frame. Later descendant links follow the relevant
   reassigned segment. Pixel contours and per-frame object IDs are unchanged.

Escape or right-click cancels an unfinished selection without changing the
model. Selecting one daughter twice does not commit. If the ROI, channel or
model changes during selection, restart the command. Two distinct tracked
daughter objects must already exist on the next frame; correct a merged or
missing segmentation first. The action requires a family explicitly configured
for binary fission; budding keeps its existing interaction.

**Lineage: undo last fission correction** restores the previous cell model.
It is available until another model edit occurs. Saving alone does not disable
undo. Undo remains a local in-memory action; save again to persist it.

Use **File > Save selected roi** to save the corrected masks/model. In a
managed annotation session the event is an explicit edit, while the other
automatically reassigned frames remain unreviewed for tracking. Review those
frames, then use **Validate GT**. Neither correcting nor validating a fission
starts training. Renaming an annotation channel also does not establish human
ground truth: AI preannotations remain Draft until reviewed.
