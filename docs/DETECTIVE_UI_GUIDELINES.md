# DetecDiv UI guidelines

Reference: discussion with Gilles, 4 November 2026, and `DETECTIVE_UI_ROADMAP.md`.
The requirements below supersede the earlier French labels, renamed data concepts and permanently visible guidance text.

## Required desktop conventions

- **English UI.** Menus, labels, tooltips, status messages and app-generated errors use English. Preserve user-provided project, FOV, ROI and channel names verbatim.
- **Conventional menu bar.** Use File, Edit, View, Navigate and Help. Commands must invoke available actions; do not add placeholder commands suggesting unsupported capabilities.
- **DetecDiv vocabulary.** Use Project, FOV, ROI, Classifier, Processor and Pipeline. Do not replace FOV and ROI with a new naming scheme.
- **One project tree.** Show the actual Project → FOV → ROI hierarchy, with multiple open projects in the same tree. Project navigation and task-oriented tools complement one another.
- **Image first.** Keep the central viewport dominant. The Projects and Display panels can be hidden through View.
- **Real docking.** Projects, Image and Display are independent native docking documents. Each can float, redock or change position without reconstructing its contents. Save and restore the workspace layout across launches.
- **No explanatory paragraphs in the layout.** Remove onboarding text, next-step essays, disclaimers and decorative workflow slogans. Use concise control labels and MATLAB tooltips. Keep the bottom status bar for the current view or an actionable error. Hover-driven status help can be added if it works reliably with native components; standard tooltips are the initial implementation.

## Interaction rules

1. Selecting a FOV or ROI updates the same viewport and synchronizes the tree and breadcrumb. Clicking an ROI outline selects that ROI in the tree.
2. Opening a project adds it to the workspace. Focusing an already open project does not create another copy. Closing removes it from this window without saving or deleting scientific data.
3. Keep each project's current FOV/ROI, frame and named channel while browsing other projects. Preserve zoom within temporal navigation of one view; fitting the image is an explicit command.
4. Empty legacy placeholders are hidden, while object indices remain unchanged. Display user names alongside FOV/ROI indices.
5. Show reference ROI geometry as reference geometry. Do not infer tracking or drift correction. Clear old pixels after a failed read.
6. Contextual tools expose useful defaults first, with detailed parameters and the pipeline available on demand. Guiding an action must not require a permanent tutorial beside the image.
7. Treatment commands must make selection, output naming and replacement behavior clear. Scientific logic stays in backend modules; pipelines retain provenance.
8. Native tooltips and enabled/disabled commands communicate availability. The colour of a contour is not the only selection cue; the project tree also identifies the active ROI.

## Initial menu structure

| Menu | Available commands |
| --- | --- |
| File | Open Project..., Close Project, Exit |
| Edit | Copy Image |
| View | Projects, Image, Display, ROI Outlines, Fit Image, Expand/Collapse Projects, Docking, Save/Restore/Reset Layout |
| Navigate | Parent FOV, Previous Frame, Next Frame |
| Help | About DetecDiv |

Open Project uses Ctrl+O, Close Project uses Ctrl+W, and Copy Image uses Ctrl+C. Save/edit/analysis commands will be added with their actual implementations.

## Remaining design decisions

- Extend the tree to Classifiers, Processors, Pipelines and Runs when the corresponding integrations are implemented.
- Extend the implemented layers/contrast controls to semantic mask rendering and scientific editing tools.
- Decide when single-click selection should be distinguished from double-click opening for grouped actions.
- Stabilize keyboard navigation, minimum window size and multi-monitor layout migration.
- Keep the docking shell code-owned; use the established App Designer / code-sync workflow for widget contents where useful.

## Validation

Verify navigation, pixels, tree selection, menu callbacks, project isolation and image limits in MATLAB. Inspect an exported window. Validate on a representative real acquisition before changing the default DetecDiv entry point.

The R2026a-specific integration and layout contract are described in `DETECTIVE_UI_DOCKING.md`. Classic menus are provided by an app-local menu adapter above AppContainer; the image, tree and display controls remain native MATLAB components.

## Display and upcoming analysis widgets

Display exposes a visibility table, an active layer, Solo, source-unit contrast, Auto, color, opacity and label rendering. Settings are local to each project's FOV/ROI view during the session. Selecting a layer edits its settings without changing visibility implicitly. See `DETECTIVE_UI_DISPLAY.md` for reuse of score and the validation scope.

Before Segment Cells, add actual classifier management as a typed browser collection alongside Projects (not a new project data type). Pipeline is a separate dockable widget, synchronized with guided analysis actions. These collections/widgets remain planned until their data and execution adapters are connected.
