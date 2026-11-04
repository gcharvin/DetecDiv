# ROIs on the main image

Open View > ROIs, or right-click the image and choose ROI Tools.... The assistant appears in the right-hand Display document's ROIs tab. It remains usable with no pipeline selected. It shares the Image viewport, frame/channel selection and raw-source relinking tools; it never opens a second raw-data viewer.

## Drawing and generation

- Manual: draw/move/resize rectangles on the raw FOV, or edit their coordinates. Existing project outlines remain reference geometry. Drawing gestures suppress their ROI-opening callbacks. Clear Draft removes pending shapes only.
- Pattern: draw a reference patch on the main image. The definition contains the original pixel patch and source FOV/frame/channel metadata. Crop defines the current FOV's inclusion region. Preview runs roiPattern in test mode against a metadata copy and overlays its detections on Image; project ROIs/crop remain unchanged.
- Grid: choose the existing full-frame/grid parameters or draw explicit rectangles. Preview and generation use roiGrid, with no new grid algorithm in the widget.
- Tracked: configure the existing tracked-mask source/parameters. Drawing is disabled because tracked geometry comes from that backend. Standalone generation forces extract=false; pipeline definitions retain their explicit extraction setting.

Manual/Grid previews use scratch FOV objects and the existing package processors; no project ROIs are created by preview. Create ROIs appends through the existing package backend on the selected project FOV. Existing ROI images, IDs and results are preserved; standalone creation does not extract pixels into H5. Save Project (Ctrl+S) explicitly persists lightweight JSON inventory/ROI geometry through shallowSave(...,'shallowObj'), without saving/clearing ROI image caches. Extraction remains a separate pipeline operation.

Opening the assistant is metadata-only. Drawing/preview requests the raw image on demand; absent sources use the existing Relink Raw Data... action. ROI geometry is drawn in raw FOV coordinates, even when the user entered the assistant from a cropped ROI view. The FOV target is shown at the top. Pending shapes/settings are remembered per project/FOV during the session and released when the project closes.

## Pipeline reuse

Run Settings > Steps > Define ROIs and viewer-launched pipeline2 ROI-edit commands open this same assistant. Its action becomes Use in Run and its mode is fixed by the selected step. Accepting updates the working definition, without creating project ROIs or extracting data. Changing project/pipeline invalidates an old definition callback instead of applying it to another target. FOV-specific manual records and pattern patch provenance are retained.

The new viewer path no longer calls Workflow/Workflow2 to define ROIs. Those applications remain in the repository for legacy callers. Raw-data parsing, extraction, segmentation and tracking algorithms are not rewritten in the assistant; canonical shallow/fov/roi objects and engine packages remain authoritative. Full first-time project/raw-import UI and richer tracked/mask editing remain separate integration work.

## Verification

```matlab
detecdivui.separationTest();
```

The native test draws actual MATLAB rectangle objects, appends through roiManual, verifies old pixels/geometry and absence of H5 extraction, saves/reloads the project inventory, transfers definitions via pipeline2, checks the same run ID/configuration, and previews a captured pattern/crop without changing project ROIs. Source TIFF pixels are checked directly. Preview overlays are not persisted as scientific results.

The GUI paths still require validation on representative real acquisitions. The test does not execute a classifier, launch a Hub job or validate tracked-mask generation on a real dataset.
