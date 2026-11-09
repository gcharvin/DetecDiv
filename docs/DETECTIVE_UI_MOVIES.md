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
- Video profiles are restricted to installed color-capable VideoWriter profiles;
  PDF Sequence uses Score's frame-in-columns export layout. Extensions match the
  actual profile. Playback FPS and acquisition minutes/frame are separate.
- Timestamp, start-at-zero and annotation-draft inclusion are explicit. Export
  does not save, approve, discard or modify the source annotations.

Options opens a typed dialog for title/ROI titles, crop `[x y width height]`
(integer pixel counts), image scale, quarter-turn rotation, vertical/horizontal
flip, mosaic rows/columns (0 = auto), font size and native color pickers. It also
provides data legend, data window/size ratio, data colormap and an editable event
table using Score's event representation. Cancel leaves settings unchanged.

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
Raw files are read during rendering, not duplicated into another raw volume.

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

Export writes a temporary file beside the destination and publishes it only
after successful completion. An existing destination requires explicit
replacement. Failure/cancellation closes the writer and deletes the temporary
output, preserving an existing file. Cancel is cooperative at render/frame
boundaries; MATLAB reads and PDF printing finish their current native call.
Closing the app during export requests cancellation before allowing closure.

Progress reports actual completed video frames (or rendered sequence cells),
with a visible footer owner that follows Display/Image as widgets are hidden
or covered. Open File and Folder act on the last successful output.

This integration is local. Score's Hub export helper remains available in the
legacy application; serializing viewer-specific Display/draft snapshots for
Hub submission is pending and is not offered as a misleading widget option.
Intensity scale-bar toggles not yet present in Display are also not invented
as independent export defaults.

## Verification

`detecdivui.movieExportTest()` checks actual AVI decoding/frame count/FPS, PDF,
Display/draft pixel and contour parity, independent snapshots, transforms,
isolated preview, flat pages and source/draft preservation.
`detecdivui.movieRecipeTest()` checks separated channels, mosaics with data/events,
raw frame reads and cancellation after a written frame without replacing an
existing destination. Score's movie/sequence comparison tests cover the shared
renderer, layout and full-canvas capture path.
