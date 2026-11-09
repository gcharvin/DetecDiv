# Display layers and contrast

## Interaction

- Layers uses a custom local HTML/JavaScript table embedded through uihtml, rather than uitable or Swing. Each row shows visibility, a color picker, type, display levels and weight. The selected row exposes numeric Low/High/Weight editors. Selection changes settings without silently changing visibility. Names are inserted as text, and asynchronously received edits are scoped to the current table revision.
- Solo shows only the active layer.
- Overlay channels follows Score's display convention: checked combines visible intensity/RGB layers; unchecked displays one horizontal panel per visible intensity/RGB channel, with the same visible masks/contours on every panel. Masks do not get extra panels. Mask-only selection uses one black base tile; no visible layers produces a black tile. A logical RGB channel remains one tile even when its stored planes are non-contiguous.
- Separate panels share time, pan and zoom. Clicking an image selects its channel and active drawing/copy target without changing visibility or rebuilding the images during a pan gesture. Per-channel contrast/color stays unchanged when switching modes. As in Score's non-overlay renderer, intensity weights apply only to the combined view; their controls are disabled in separate mode, while mask fill opacity still applies. Copy Image copies the active panel.
- Intensity and RGB layers have source-unit minimum/maximum fields, a contrast range slider and an Auto button. Auto uses finite min/max from the current frame and keeps those limits while browsing time.
- The frame slider and contrast range slider update the image during dragging through ValueChangingFcn, using event.Value rather than the previous committed slider value. A viewer-local single-shot timer coalesces intermediate positions (60 ms delay); release cancels any pending preview and applies the exact final value. Pending previews are scoped to their project/FOV/ROI/model, and contrast previews additionally require the same frame/selected layer. They are discarded on navigation or close. The image, current-frame histogram, data marker and annotation overlays follow the preview frame. Native slider values are not reassigned while their thumb is being dragged.
- Color can be chosen from the row's picker or the native MATLAB uicolorpicker below the histogram. The editable dropdown offers common RGB/Score colormap choices and accepts the full Score color specification. RGB layers retain their three subchannels and disable tinting. Label layers accept `Labels` for score's ID palette or an RGB triplet for a single overlay color. A multicolor swatch denotes an ID palette or named colormap, not a fixed RGB color.
- Opacity controls intensity weight or mask alpha. Label zero is transparent and label one remains a valid object.
- Label layers expose Fill, Contours and Fill + Contours plus a positive contour width in points. Existing ROI contour/width metadata initializes the session setting. Fill alpha keeps the current layer opacity; contour edges follow Score's opaque vector-edge convention. The setting stays local to the current project/FOV/ROI/layer and does not write metadata or change mask IDs. Hidden layers have no contours, and contours do not capture mouse gestures.
- Label layers are recognized from ROI display metadata; a scalar layer's type can also be selected explicitly. Integer-valued intensity channels are not guessed to be segmentation masks.
- View > Reload Image invalidates the current-frame display cache. It does not overwrite unsaved in-memory ROI edits by forcing a disk reload.
- Histogram shows the active intensity layer, its median and finite pixel count. Visible overlays other visible intensity/RGB histograms. Label IDs are excluded from intensity statistics. Auto X follows Score (log for strictly positive ranges, linear otherwise); explicit Linear X/Log X and Log Y are available. Nonpositive ranges fall back to linear X. Drag the two level markers, or use their arrow keys, to adjust the same source-unit contrast as the numeric editors/slider. Histogram axis scaling does not change pixel mapping.
- Histogram marker drags preview contrast before release, retaining the captured SVG marker across display refreshes. Updates are throttled and acknowledged so only the latest unsent position is kept. Release commits the exact limits; pointer cancellation restores the limits from the start of the gesture. Project/FOV/ROI/frame/layer context changes invalidate that gesture and reject its delayed updates, even when ordinary histogram revisions changed during its own preview.
- The `Hist.` state button in the Layers header shows or hides the detailed histogram plot for intensity/RGB layers. Short Display panels, including Display stacked above Objects, default to a compact layout: the Layers table keeps a 100-pixel area and the histogram plot starts hidden when the content height is below 650 pixels. Taller panels show the plot by default. An explicit `Hist.` choice overrides these resize defaults for the current viewer session. The remaining controls stay in the scrollable panel; contrast fields, source levels and image mapping do not depend on the plot being visible.

All controls remain inside the dockable Display widget. Help is in native tooltips; no explanatory paragraphs are added to the interface.

Objects is an independent document and can remain visible below or beside Display. Its compact family browser and contextual Contours/Tracks tabs use the shared Image viewport, while Display keeps channel, level and histogram controls. Selecting a family enables multicolor object selection/editing without changing Display's active channel. See `DETECTIVE_UI_OBJECTS.md`.

Overlay/separate presentation is a viewer-session setting retained while navigating projects/FOVs/ROIs, with Overlay as the initial default. Image panels are inside the existing Image docking document, not additional floating image windows. Raw ROI pattern capture uses the active visible panel's original channel/frame pixels. Rendering failures and metadata-only navigation clear all old panels. A future export adapter must carry this presentation flag into Score's existing overlay option.

## State and cache

`detecdivui.LayerModel` is independent of the widget layout. Each open project has its own model, with separate display settings per FOV/ROI view. Visibility, layer type, color, opacity and contrast survive navigation within that session. They are not written to project files, ROI metadata or H5 stores, and are not yet persisted across application restarts. Workspace geometry remains separately persisted by DockingHost.

Only the current view/frame's requested image planes and histogram statistics are cached, lazily by channel. Frame/context changes or Reload Image invalidate both while retaining contrast settings. Editing color or contrast does not reread unchanged source frames or recount histograms. Hidden layers can still be read when selected for adjustment. Histogram overlays use requested visible planes, not a scan of every project channel.

## Reused rendering

The adapter uses `score_makeComposite`, `score_collectDisplayOptions`, `score_channelColorSpec`, `score_applyChannelColorSpec`, `score_colormapFromName` and `score_trackColor` without changing their implementation. Source-unit contrast normalization reuses `workflowui.stretchToUnit` before providing a temporary 16-bit display plane to score. Label IDs bypass intensity normalization and retain their full source precision. Optional contours use score_makeComposite's vector output and score_displayVectorGraphics; vector fill is zero because fill is already raster-composited once. No separate mask-boundary algorithm is introduced.

A temporary ROI is used only as a renderer input. It is never saved and does not modify the source ROI. Intensity layers combine additively using score's `imlincomb` convention; label overlays are alpha-composited above them. A single untinted scalar layer uses native axes with the original pixels and selected contrast limits; a single unadjusted RGB layer preserves its original pixels. Mixed/colorized views produce an 8-bit RGB display image, while quantitative source values remain unchanged.

Histogram statistics are factored into score_histogramData, also called by legacy score_updateHistogram: finite values, a target of 200 bin edges, positive logarithmic bins, linear bins for zero/signed values, median and RGB luminance. Flat ranges are expanded and repeated/rounded edges normalized to keep counts valid for constant or near-constant planes. Display consumes source pixel units; legacy Score retains its existing physical-value decoding before calling the shared helper. No project image/metadata is modified by the helper.

Semantic coloring by lineage, censoring, cell state and tracking provider, layer reordering and saved display presets remain later Display integrations. Mask and track editing live in the independent Objects document with shared annotation drafts; selecting a family defaults to multicolor label rendering. This palette uses frame-local mask IDs and the existing stable Score colors; it does not introduce a new biological identity or semantic color contract. Swing components cannot be embedded in this web FigureDocument/uifigure host; the custom web boundary stays local, with no network/CDN or third-party table library.

## Tests

The central Image workspace keeps one tab per visited project/FOV/ROI context.
FOV tabs use `Image: FOV <name>` and cropped views use `ROI <number>`;
the tooltip includes the project and full hierarchy. Selecting an existing ROI
reactivates its tab. Frame, active channel, overlay mode and zoom are retained
per tab, while the existing LayerModel retains contrast/color/layer settings.
Display, Objects, Data and Pipeline follow the selected context. The canvas stays
in its original native figure to preserve axes interactions and drawing tools.
Each image tab has a close button; closing removes its UI reference. Scientific data
and annotation drafts remain owned by the existing controllers. Closing a project
removes its image tabs. Tabs are session-local and do not reopen raw files on startup.

```matlab
detecdivui.layerTest();
detecdivui.imageTabsTest();
detecdivui.displayTest();
detecdivui.contoursTest();
detecdivui.separateChannelsTest();
detecdivui.displayWebTest();
detecdivui.liveDisplayTest();
detecdivui.scoreHistogramTest();
detecdivui.smokeTest();
detecdivui.dockingTest();
```

Tests cover known rendered pixels, additive weights, mask alpha/background, label IDs beyond uint16, fractional/negative physical intensities, per-view contrast, current-frame cache invalidation, source immutability, native picker callbacks, signed/constant/RGB/nonfinite histograms and stale events. displayWebTest drives actual embedded DOM click/change/keyboard events through uihtml to MATLAB and checks redocking; it pauses the test session's menu polling timer while issuing direct CEF commands. scoreHistogramTest checks legacy Score curves/counts/level markers against the shared helper. Display tests accept an optional PNG path for visual inspection. The OS color chooser still needs hands-on verification in an unlocked desktop session; the native MATLAB picker remains available alongside the row picker.

liveDisplayTest checks frame/contrast changes before release, latest-value coalescing, exact release values, retained histogram pointer gestures, pointer cancellation, stale-context rejection, unchanged source pixels/metadata and preview-timer cleanup. Its synthetic pointer test stubs native pointer capture only; desktop drag verification checks the native capture path separately.

## Next widgets: classifiers and pipelines

Classifiers now have an independent Classifier widget with an open-model selector, a ROI dataset table and common parameter editing. The table exposes dataset membership, persistent frame bounds and annotation status/coverage. A classifier remains a canonical `@classi` object. Its flat ROI collection uses a transient image-session adapter; this is never listed or saved as a project. Compatible-model selection for guided actions remains a separate integration.

Workspace discovery supplies Classifier independently from Projects. File > Open Classifier loads into that widget and shows its ROI in the central image workspace. Projects retains projects/FOVs/ROIs and independent processors. Pipelines are owned by the separate Pipeline widget: its compact Open/Recent tree stays above the graph, with single-click opening/activation and local path inspection/Copy. Project runs appear in Projects' bottom context panel and recall their saved graph in Pipeline. See the ClassifierGUI migration inventory in DETECTIVE_UI_IMPLEMENTATION.md.

Pipeline is implemented as a separate dockable widget with its own library, graph and project Runs, a settings dialog and a bridged pipeline2 editor; see DETECTIVE_UI_PIPELINE.md. Recent pipeline references are read without source probes or automatic opening; opening/reusing a template does not change the current project/run scope. The larger native editor remains a migration target. Guided segmentation/model selection remains future integration work. Pipeline templates remain independent of projects. Add future widgets with a layout migration/default strategy that preserves existing user arrangements.
