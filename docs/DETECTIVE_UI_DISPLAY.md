# Display layers and contrast

## Interaction

- Layers uses a custom local HTML/JavaScript table embedded through uihtml, rather than uitable or Swing. Each row shows visibility, a color picker, type, display levels and weight. The selected row exposes numeric Low/High/Weight editors. Selection changes settings without silently changing visibility. Names are inserted as text, and asynchronously received edits are scoped to the current table revision.
- Solo shows only the active layer.
- Intensity and RGB layers have source-unit minimum/maximum fields, a contrast range slider and an Auto button. Auto uses finite min/max from the current frame and keeps those limits while browsing time.
- Color can be chosen from the row's picker or the native MATLAB uicolorpicker below the histogram. The editable dropdown offers common RGB/Score colormap choices and accepts the full Score color specification. RGB layers retain their three subchannels and disable tinting. Label layers accept `Labels` for score's ID palette or an RGB triplet for a single overlay color. A multicolor swatch denotes an ID palette or named colormap, not a fixed RGB color.
- Opacity controls intensity weight or mask alpha. Label zero is transparent and label one remains a valid object.
- Label layers expose Fill, Contours and Fill + Contours plus a positive contour width in points. Existing ROI contour/width metadata initializes the session setting. Fill alpha keeps the current layer opacity; contour edges follow Score's opaque vector-edge convention. The setting stays local to the current project/FOV/ROI/layer and does not write metadata or change mask IDs. Hidden layers have no contours, and contours do not capture mouse gestures.
- Label layers are recognized from ROI display metadata; a scalar layer's type can also be selected explicitly. Integer-valued intensity channels are not guessed to be segmentation masks.
- View > Reload Image invalidates the current-frame display cache. It does not overwrite unsaved in-memory ROI edits by forcing a disk reload.
- Histogram shows the active intensity layer, its median and finite pixel count. Visible overlays other visible intensity/RGB histograms. Label IDs are excluded from intensity statistics. Auto X follows Score (log for strictly positive ranges, linear otherwise); explicit Linear X/Log X and Log Y are available. Nonpositive ranges fall back to linear X. Drag the two level markers, or use their arrow keys, to adjust the same source-unit contrast as the numeric editors/slider. Histogram axis scaling does not change pixel mapping.

All controls remain inside the dockable Display widget. Help is in native tooltips; no explanatory paragraphs are added to the interface.

## State and cache

`detecdivui.LayerModel` is independent of the widget layout. Each open project has its own model, with separate display settings per FOV/ROI view. Visibility, layer type, color, opacity and contrast survive navigation within that session. They are not written to project files, ROI metadata or H5 stores, and are not yet persisted across application restarts. Workspace geometry remains separately persisted by DockingHost.

Only the current view/frame's requested image planes and histogram statistics are cached, lazily by channel. Frame/context changes or Reload Image invalidate both while retaining contrast settings. Editing color or contrast does not reread unchanged source frames or recount histograms. Hidden layers can still be read when selected for adjustment. Histogram overlays use requested visible planes, not a scan of every project channel.

## Reused rendering

The adapter uses `score_makeComposite`, `score_collectDisplayOptions`, `score_channelColorSpec`, `score_applyChannelColorSpec`, `score_colormapFromName` and `score_trackColor` without changing their implementation. Source-unit contrast normalization reuses `workflowui.stretchToUnit` before providing a temporary 16-bit display plane to score. Label IDs bypass intensity normalization and retain their full source precision. Optional contours use score_makeComposite's vector output and score_displayVectorGraphics; vector fill is zero because fill is already raster-composited once. No separate mask-boundary algorithm is introduced.

A temporary ROI is used only as a renderer input. It is never saved and does not modify the source ROI. Intensity layers combine additively using score's `imlincomb` convention; label overlays are alpha-composited above them. A single untinted scalar layer uses native axes with the original pixels and selected contrast limits; a single unadjusted RGB layer preserves its original pixels. Mixed/colorized views produce an 8-bit RGB display image, while quantitative source values remain unchanged.

Histogram statistics are factored into score_histogramData, also called by legacy score_updateHistogram: finite values, 200 bin edges, positive logarithmic bins, linear bins for zero/signed values, median and RGB luminance. Display consumes source pixel units; legacy Score retains its existing physical-value decoding before calling the shared helper. No project image/metadata is modified by the helper.

Semantic coloring by lineage, censoring, cell state and tracking provider, mask editing, layer reordering and saved display presets remain later integrations. The labels view uses frame-local IDs and the existing stable score palette. Swing components cannot be embedded in this web FigureDocument/uifigure host; the custom web boundary stays local, with no network/CDN or third-party table library.

## Tests

```matlab
detecdivui.layerTest();
detecdivui.displayTest();
detecdivui.contoursTest();
detecdivui.displayWebTest();
detecdivui.scoreHistogramTest();
detecdivui.smokeTest();
detecdivui.dockingTest();
```

Tests cover known rendered pixels, additive weights, mask alpha/background, label IDs beyond uint16, fractional/negative physical intensities, per-view contrast, current-frame cache invalidation, source immutability, native picker callbacks, signed/constant/RGB/nonfinite histograms and stale events. displayWebTest drives actual embedded DOM click/change/keyboard events through uihtml to MATLAB and checks redocking; it pauses the test session's menu polling timer while issuing direct CEF commands. scoreHistogramTest checks legacy Score curves/counts/level markers against the shared helper. Display tests accept an optional PNG path for visual inspection. The OS color chooser still needs hands-on verification in an unlocked desktop session; the native MATLAB picker remains available alongside the row picker.

## Next widgets: classifiers and pipelines

Before introducing Segment Cells, implement model discovery and selection. The proposed browser structure uses typed top-level collections for Projects, Classifiers and Processors in the same browser widget, with icons and contextual actions. A Classifier remains an independent `@classi` object, not a second kind of `@shallow` project. Project-associated classifiers are links to those objects. The collection can become a separate widget if later usability testing supports that choice. Do not add empty placeholder collections before their backing registry is connected.

Workspace discovery now provides read-only Classifiers, Processors and Pipelines collections for live base-workspace objects, including metadata and variable names. Compatible-model selection for execution, file-based discovery, project links and editing actions remain to implement.

Pipeline is implemented as a separate dockable widget, settings dialog and bridged pipeline2 editor; see DETECTIVE_UI_PIPELINE.md. Guided segmentation/model selection remains future integration work. Pipeline templates remain independent of projects. Add future widgets with a layout migration/default strategy that preserves existing user arrangements.
