# ROIs on the main image

Choose Edit > Define ROIs..., or right-click the image or Projects tree and choose Define ROIs.... These actions require a selected FOV and remain usable with no pipeline selected. The contextual Define ROIs assistant replaces the Display document contents on demand. Its ← Display button restores the layer controls and removes drawing/preview overlays while retaining the pending draft. There is no second visible tab strip inside Display. Opening an extracted ROI or leaving the FOV context dismisses the assistant. It shares the Image viewport, frame/channel selection and raw-source relinking tools; it never opens a second raw-data viewer.

## Drawing and generation

- Manual: draw/move/resize rectangles on the raw FOV, or edit their coordinates. Existing project outlines remain reference geometry. Drawing gestures suppress their ROI-opening callbacks. Clear Draft removes pending shapes only.
- Pattern: draw a reference patch on the main image. The definition contains the original pixel patch and source FOV/frame/channel metadata. Crop defines the current FOV's inclusion region. Preview runs roiPattern in test mode against a metadata copy and overlays its detections on Image; project ROIs/crop remain unchanged.
- Grid: choose the existing full-frame/grid parameters or draw explicit rectangles. Preview and generation use roiGrid, with no new grid algorithm in the widget.
- Tracked: configure the existing tracked-mask source/parameters. Drawing is disabled because tracked geometry comes from that backend. Standalone generation forces extract=false; pipeline definitions retain their explicit extraction setting.

Manual/Grid previews use scratch FOV objects and the existing package processors; no project ROIs are created by preview. Create ROIs appends through the existing package backend on the selected project FOV. Existing ROI images, IDs and results are preserved; standalone creation does not extract pixels into H5. Save Project (Ctrl+S) explicitly persists lightweight JSON inventory/ROI geometry through shallowSave(...,'shallowObj'), without saving/clearing ROI image caches. Extraction remains a separate pipeline operation.

The assistant is created lazily on explicit opening; its hidden page and draft remain in memory after returning to Display. Navigation/rendering and project closure do not require it to exist; deleted tool instances are rebuilt on their next explicit opening. Opening the assistant is metadata-only. Drawing/preview requests the raw image on demand; absent sources use the existing Relink Raw Data... action. ROI geometry is drawn in raw FOV coordinates, even when the user entered the assistant from a cropped ROI view. The FOV target is shown at the top. Pending shapes/settings are remembered per project/FOV during the session and released when the project closes. Closing the viewer also deletes the assistant controls.

## Pipeline reuse

Run Settings > Steps > Define ROIs and viewer-launched pipeline2 ROI-edit commands open this same assistant. Its action becomes Use in Run and its mode is fixed by the selected step. Closing and reopening the same step resumes its unsubmitted draft. Accepting updates the working definition, without creating project ROIs or extracting data. Changing project/pipeline invalidates an old definition callback instead of applying it to another target. FOV-specific manual records and pattern patch provenance are retained.

The definition-only Pipeline Designer uses the same route, with Use in Pipeline. The independent definition remains unbound to a project: the viewer project/FOV supplies image context for this edit only. Pipeline/module identity appears in the image breadcrumb and the assistant target. Explicit module FOVs and effective run selections take precedence over an unrelated visible FOV; opening the tool does not search raw paths or load pixels. Drawing/preview still loads the requested raw FOV on demand. Missing context leaves the editor available and reports the selection required in the viewer status.

Replies are checked against the live owner, pipeline/run/module/effective parameter signature and target project/FOV. Switching FOV dismisses a bound assistant rather than silently converting it into standalone creation. Closing its editor or changing the module/run selections rejects a stale reply. Pending module drafts are stored by owner/request identity and FOV, separately from the standalone draft; switching between two ROI steps on the same image preserves each pending geometry.

Successful Use in Run/Pipeline dismisses the image assistant and leaves the editor available. Reopening the module creates a request from the accepted definition; the old request cannot overwrite it. Returning to Display suspends an unsubmitted draft without applying it.

Inclusion-crop persistence is not yet fully isolated: bound Use in Run currently applies a changed crop to the project FOV, as required by the existing pattern backend. A separate explicit project-edit or supported run-local crop contract is required before claiming complete draft isolation. See [the pipeline parity matrix](DETECTIVE_UI_PIPELINE_PARITY.md), P23. Preview itself still uses a scratch FOV.

Viewer-owned ROI requests are intercepted before Workflow/Workflow2, in both definition and runtime editing. Those applications remain in the repository for legacy callers. Raw-data parsing, extraction, segmentation and tracking algorithms are not rewritten in the assistant; canonical shallow/fov/roi objects and engine packages remain authoritative. Full first-time project/raw-import UI and richer tracked/mask editing remain separate integration work. A raw-input run cannot borrow an unrelated open project's images; its acquisition must first be available in Projects until the legacy parser has been integrated into a temporary main-image context.

## Verification

```matlab
detecdivui.separationTest();
detecdivui.pipelineImageContextTest();
```

The native test draws actual MATLAB rectangle objects, appends through roiManual, verifies old pixels/geometry and absence of H5 extraction, saves/reloads the project inventory, transfers definitions via pipeline2, checks the same run ID/configuration, and previews a captured pattern/crop without changing project ROIs. Source TIFF pixels are checked directly. Preview overlays are not persisted as scientific results.

The GUI paths still require validation on representative real acquisitions. The test does not execute a classifier, launch a Hub job or validate tracked-mask generation on a real dataset.
