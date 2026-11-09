# Sparse fluorescence acquisition

`interpolateSparseAcquisition=true` (default) interpolates fluorescence metrics
linearly between measured frames, before computing channel ratios. It never
changes extracted images, masks or measured values, and does not extrapolate.
Unacquired frames without two neighbouring measurements remain NaN. Empty masks
remain empty; interpolation cannot cross the disappearance of a mask label.
Labels are joined by their numeric ID, not their position inside a table cell.
Instance IDs must therefore represent the same object over the interval (use a
tracked/lineage mask when quantifying individual objects).

For pymmcore-plus OME-Zarr v3, cadence comes from the series metadata's
`pymmcore_plus.summary_metadata.mda_sequence.channels[].acquire_every`, matched
through the FOV's source channel index and acquisition name. The first acquired
frame is 1. The FOV is resolved from the ROI parent or the pipeline context.
The acquired time grid is not compressed via `fov.interval`.

For other formats or standalone ROIs, set `channelN_acquisitionPeriod` explicitly
(global frame count, e.g. 3) and optionally `channelN_firstAcquisitionFrame`
(one-based, default 1). Period 0 reads metadata; period 1 means every frame.
Without cadence metadata or an explicit period, measurements remain unchanged:
zero cell fluorescence is not evidence of a missing acquisition.

Only entirely zero-filled planes on the declared unacquired frames are replaced.
A genuine zero on an acquired frame and unexpected nonzero acquisitions are
preserved. All fluorescence reducers, including composite mask measurements,
use the same interpolation policy. Ratios are then recomputed from the component
signals, rather than interpolating ratios. Geometry statistics stay frame-local.

Partial frame requests use measured neighbours from the loaded image stack and
return only the requested rows in their original order. Callers must load the
relevant acquired frames. `userData.acquisition_sampling` records cadence, source
and zero-filled unacquired frame candidates; `source_frames` keeps absolute IDs.

Existing saved metrics are not changed by installing the code. Recompute
`computeMetrics` and downstream aggregations such as `computeRLS` to update them.
Extraction, segmentation and lineage need not be repeated.
