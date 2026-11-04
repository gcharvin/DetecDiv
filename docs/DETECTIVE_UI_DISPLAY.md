# Display layers and contrast

## Interaction

- The Layers table toggles channel visibility. Selecting a row or choosing an Active layer changes which settings are edited; it does not silently change other layers' visibility.
- Solo shows only the active layer.
- Intensity and RGB layers have source-unit minimum/maximum fields, a contrast range slider and an Auto button. Auto uses finite min/max from the current frame and keeps those limits while browsing time.
- Color accepts an RGB triplet or an existing score colormap name. RGB layers retain their three subchannels. Label layers accept `Labels` for score's ID palette or an RGB triplet for a single overlay color.
- Opacity controls intensity weight or mask alpha. Label zero is transparent and label one remains a valid object.
- Label layers are recognized from ROI display metadata; a scalar layer's type can also be selected explicitly. Integer-valued intensity channels are not guessed to be segmentation masks.
- View > Reload Image invalidates the current-frame display cache. It does not overwrite unsaved in-memory ROI edits by forcing a disk reload.

All controls remain inside the dockable Display widget. Help is in native tooltips; no explanatory paragraphs are added to the interface.

## State and cache

`detecdivui.LayerModel` is independent of the widget layout. Each open project has its own model, with separate display settings per FOV/ROI view. Visibility, layer type, color, opacity and contrast survive navigation within that session. They are not written to project files, ROI metadata or H5 stores, and are not yet persisted across application restarts. Workspace geometry remains separately persisted by DockingHost.

Only the current view/frame's requested image planes are cached, lazily by channel. Frame/context changes or Reload Image invalidate those pixels while retaining contrast settings. Editing color or contrast does not reread unchanged source frames from disk. Hidden layers can still be read when selected for adjustment.

## Reused rendering

The adapter uses `score_makeComposite`, `score_collectDisplayOptions`, `score_channelColorSpec`, `score_applyChannelColorSpec`, `score_colormapFromName` and `score_trackColor` without changing their implementation. Source-unit contrast normalization reuses `workflowui.stretchToUnit` before providing a temporary 16-bit display plane to score. Label IDs bypass intensity normalization and retain their full source precision.

A temporary ROI is used only as a renderer input. It is never saved and does not modify the source ROI. Intensity layers combine additively using score's `imlincomb` convention; label overlays are alpha-composited above them. A single untinted scalar layer uses native axes with the original pixels and selected contrast limits; a single unadjusted RGB layer preserves its original pixels. Mixed/colorized views produce an 8-bit RGB display image, while quantitative source values remain unchanged.

Semantic coloring by lineage, censoring, cell state and tracking provider, mask editing, layer reordering, histogram panels and saved display presets remain later integrations. The initial labels view uses frame-local IDs and the existing stable score palette.

## Tests

```matlab
detecdivui.layerTest();
detecdivui.displayTest();
detecdivui.smokeTest();
detecdivui.dockingTest();
```

Tests cover known rendered pixels, additive weights, mask alpha/background, label IDs beyond uint16, fractional/negative physical intensities, per-view contrast, current-frame cache invalidation, source immutability, real widget callbacks and docking. The display test accepts an optional PNG path for visual inspection.

## Next widgets: classifiers and pipelines

Before introducing Segment Cells, implement model discovery and selection. The proposed browser structure uses typed top-level collections for Projects, Classifiers and Processors in the same browser widget, with icons and contextual actions. A Classifier remains an independent `@classi` object, not a second kind of `@shallow` project. Project-associated classifiers are links to those objects. The collection can become a separate widget if later usability testing supports that choice. Do not add empty placeholder collections before their backing registry is connected.

Workspace discovery now provides read-only Classifiers, Processors and Pipelines collections for live base-workspace objects, including metadata and variable names. Compatible-model selection for execution, file-based discovery, project links and editing actions remain to implement.

Pipeline requires its own dockable widget for steps, effective parameters, validation, progress and runs. Guided actions should select compatible classifiers and configure the same inspectable `@pipeline` template / `pipelineRun` execution, with advanced details available on demand. Pipeline templates remain independent of projects. Add future widgets with a layout migration/default strategy that preserves existing user arrangements.

These are design requirements for the next tranche; classifier management and the Pipeline widget are not implemented by the Display changes.
