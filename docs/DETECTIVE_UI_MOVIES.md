# Contextual movie export

Open **File > Export Movie...** or the Image context menu. The assistant
replaces Display's body, with a **← Display** return action and no additional
tab strip. It is created on demand, not during startup.

## Selection and common controls

- Current Image exports the active FOV or ROI tab, including classifier ROIs.
- Open ROI Tabs exports the currently open ROI images as a mosaic.
- Current FOV ROIs exports the active FOV's ROI collection (the classifier
  dataset when a classifier is active). Reading those ROIs is explicit work.
- Frames accepts `all`, inclusive ranges such as `1:100` or `1:2:100`, or an
  increasing list. No MATLAB expressions are evaluated. Differing sequence
  lengths require an explicit common range; `all` never silently truncates.
- Video profiles are restricted to installed color-capable VideoWriter profiles.
  PDF Sequence uses Score's frame-in-columns export layout. PNG Sequence and
  TIFF Sequence write one lossless rendered frame per file in a new directory,
  named `frame_000001.png` / `.tif` using absolute source frame numbers. They
  retain the same mosaic, data panels, contours and timestamps as the movie.
  Extensions match the actual profile. Playback FPS and acquisition minutes/frame
  are separate; FPS applies only to video.
- Timestamp, start-at-zero and annotation-draft inclusion are explicit. Export
  does not save, approve, discard or modify the source annotations.

Options opens a typed dialog for title/ROI titles, crop `[x y width height]`
(integer pixel counts), image scale, quarter-turn rotation, vertical/horizontal
flip, mosaic rows/columns (0 = auto), font size and native color pickers. It also
provides data legend, data window/size ratio, data colormap and an editable event
table using Score's event representation. Cancel leaves settings unchanged.
By default, the visible image area after pan/zoom is used. Disable **Use visible
image area** for the complete image. An explicit crop takes priority over the
viewport. Export size is a deliberate pixel scale, independent of widget size.

Include Data selection uses the temporal variable/group selected in the Data
widget. Data must have one row per image frame; mosaic sources must contain
the same selected dataset/variables. Display and Data export choices remain
independent. Saved plot settings are copied and normalized on scratch objects.

## Display snapshot and reuse

`MovieExportJob` freezes each source's navigation, named layers, visibility,
source-unit levels, colors/colormaps, weights and contour styles. Overlay and
separate-channel modes use the same `LayerModel.compose/separate` methods as
the viewer. Mask overlays remain shared across separated intensity panels.
Open ROI tabs retain their own cached Display state. Incompatible channel panel
layouts require separate exports, rather than silently relabeling panels.

ROI pixels and optional dirty masks are copied on write into isolated ROI
proxies. The raw-FOV adapter snapshots metadata and reads requested frames on
demand with the existing reader; it does not search for missing raw roots.
Relink through the existing viewer tools before retrying. ROI export currently
uses loaded/full ROI sequences; it does not claim lazy H5 streaming. Nonzero
cached temporal-window offsets are rejected to protect absolute frame numbers.
Local raw files are read during rendering. Hub submission instead freezes the
requested planes/frames into the explicit export snapshot described below.

Score still owns export geometry, vector contour rendering, event text/lines,
data panels/markers, timeline windows, timestamps, movie capture and PDF output.
An optional `compositeProvider` supplies already composed frozen viewer frames
to `score_makeComposite`; ordinary Score callers retain their existing path.
No App Designer app is instantiated and no scientific processing algorithm is
reimplemented in the widget.

The canvas is separate from the viewer and invisible during writing. Preview
shows its first-frame mosaic in an independent window. Score's explicit axis
parenting avoids global-current-axis dependencies; capture pins the raster DPI
to its paper geometry so Windows display scaling cannot change frame sizes.
Score's existing minimum image/text sizes still apply to export layouts.

## Output, progress and cancellation

Export writes a temporary file or sequence directory beside the destination and publishes it only
after successful completion. An existing destination requires explicit
replacement. Failure/cancellation closes the writer and deletes the temporary
output, preserving an existing file. Cancel is cooperative at render/frame
boundaries; MATLAB reads and PDF printing finish their current native call.
Closing the app during export requests cancellation before allowing closure.
Image-sequence destinations must be new: existing folders are never merged,
recursively replaced or removed, even when file replacement is enabled.

Progress reports actual completed video frames (or rendered sequence cells),
with a visible footer owner that follows Display/Image as widgets are hidden
or covered. Open File and Folder act on the last successful output.

## Shared Hub connection and frozen worker recipe

**Hub > Connection…** uses the existing central connection dialog and settings.
Opening the viewer does not make a network request. Choose **DetecDiv Hub**
in Export Movie to select an available MATLAB target and Submit. The widget
reuses Score's `detecdiv_movie_export_submit`, standard project/classifier run
history, path mappings, target selection, locks and cancellation. Authentication
is read from the central settings, never copied into the export snapshot.

Before submission, `MovieExportSnapshot` writes a data-only MAT recipe and
compressed H5 files under a dedicated `.detecdiv_export_<uuid>` directory beside
the requested output. Only requested frames and visible/active layer planes are
stored, with optional draft masks and selected data curves. This is an explicit
export snapshot, not a change to scientific ROI storage; no classifier/model
folder or runtime bundle is copied. Large selections therefore require local
preparation time and shared disk space. Progress and Cancel cover preparation.
The snapshot is retained with the run for reproducibility.

Both snapshot and output paths must map to shared Hub storage. The worker uses
its own host mappings, verifies SHA256 for the recipe and every pixel file, and
reconstructs `LayerModel` without rereading mutable project pixels or raw paths.
The submitted run pins the client's full Git commit. Exporter code must be
committed, published and available to the worker's isolated code checkout.
Uncommitted render changes are rejected before submission. Captured font names
and DPI are reused. Source signatures, canvas dimensions and video profile are
checked rather than silently applying worker defaults or choosing another codec.
A differing renderer/layout/profile fails with diagnostics. Font rasterization
can still vary across operating systems; decoded raster equality has been
verified for local worker replay, not across live compute hosts. Lossy video codecs still have
their usual compression; PNG/TIFF preserve the captured raster losslessly.

The widget follows its submitted job with the existing Hub status endpoint and
can request cancellation. Closing the widget stops its monitor, not the remote
job. Open File/Folder becomes available when the completed artifact is visible
through the client mapping. Expired sessions require **Hub > Connection…**.
No worker service restart or change of the global default release is performed
by the viewer. Intensity scale-bar toggles not yet present in Display are not
invented as independent export defaults.

## Verification

`detecdivui.movieExportTest()` checks actual AVI decoding/frame count/FPS, PDF,
Display/draft pixel and contour parity, independent snapshots, transforms,
isolated preview, flat pages and source/draft preservation.
`detecdivui.movieRecipeTest()` checks separated channels, mosaics with data/events,
raw frame reads and cancellation after a written frame without replacing an
existing destination. Score's movie/sequence comparison tests cover the shared
renderer, layout and full-canvas capture path.

`detecdivui.movieSnapshotTest()` compares local and worker-adapter PNG pixels,
checks the real Score submission helper/local pipeline runner, frame-bounded H5,
viewport, TIFF output, checksum tampering and renderer/canvas mismatch rejection.
`detecdivui.movieHubTest()` checks centralized authentication, zero startup
requests, MATLAB target filtering and the real submission helper's path/code
pinning through an isolated transport stub. It never changes user credentials.
This transport test does not establish a live Hub execution result.
