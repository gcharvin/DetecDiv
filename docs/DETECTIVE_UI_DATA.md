# Data widget

Open **View > Data**, select a ROI and choose **Load Data**. The document appears below Image in the default workspace; custom layouts are preserved. Data can float, dock, hide and restore like the other documents. Older layout files gain a hidden Data document without losing their arrangement.

The selectors expose dataseries, variables and saved Score plot groups. Rendering reuses `score_displayDataPanel` and `score_extractYData`, including numeric curves, categories, strings, vector cells and saved Plot/Image group styles. Source colors, line widths and bounds are read from the dataseries. The colormap is restricted to the existing `lines` map. Frames/Minutes and the acquisition interval affect this view only.

Dataseries are cloned for read-only inspection. Existing cached data takes precedence; when no populated series is cached, Load Data reads the data MAT into a scratch ROI. It does not populate or overwrite the project's live data cache, read raw images, or save scientific data. Opening the viewer or selecting another ROI never loads series automatically. Selection changes clear the previous curves and snapshot.

For temporal series with exactly as many rows as the loaded ROI image has frames, clicking a curve navigates Image. Image navigation updates the time marker without redrawing curves or resetting zoom. Generation/other series and mismatched row counts do not control the timeline. Stale callbacks and drawing gestures cannot move another ROI's frame.

`detecdivui.dataTest()` exercises typed Score plots, snapshot isolation, disk reads, single-row tables, both navigation directions, ROI/project changes, old layout migration, floating/redocking and saved layouts. Real-acquisition performance remains to be checked. Data editing, group/style editing, event offsets/windows, export and managed annotation datasets remain separate migration work.
