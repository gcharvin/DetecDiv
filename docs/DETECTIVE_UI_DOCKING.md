# Dockable MATLAB workspace

## Scope

`detecdiv_ui` hosts Projects, Image and Display in a native MATLAB docking container. Widget contents reuse the existing project browser, image reader, display controls and session controller. Scientific processing and storage formats are unchanged.

The undocumented integration is confined to `detecdivui.DockingHost`. This first implementation explicitly targets **Windows MATLAB R2026a**. A different MATLAB release raises an actionable error instead of silently launching an unsupported shell.

## Use

```matlab
cd('C:\Users\Gilles\Documents\MATLAB\Detective-UI');
detecdiv_setup_path(pwd, 'DetecDivRoot', pwd);
viewer = detecdiv_ui();
```

- File, Edit, View, Navigate and Help remain at the top of the workspace.
- Each widget has a native document tab and docking controls. View > Docking provides explicit Dock/Undock commands and Dock All.
- View > Projects / Image / Display shows or hides a widget.
- View > Save Layout stores the current workspace. Restore Layout reloads it; Reset Layout restores the initial three-column arrangement.
- The current layout is also saved when the workspace closes normally, and loaded at the next launch.

The default file is `fullfile(prefdir, 'DetecDiv', 'ui-layout-r2026a.json')`. Layout preferences do not contain microscopy pixels or automatically reopen project data.

```matlab
viewer = detecdiv_ui(project, 'LayoutFile', fullfile(tempdir, 'my-layout.json'));
viewer.Host.setDocked('Display', false);
viewer.Host.saveLayout();
% For isolated sessions or automated tests:
viewer = detecdiv_ui(project, 'LayoutFile', '', 'AutoSaveLayout', false);
```

## Internal boundary

| Responsibility | Implementation |
| --- | --- |
| Native host | `matlab.ui.container.internal.AppContainer` |
| Figure factory | `matlab.ui.internal.FigureDocumentGroup` |
| Widget document | `matlab.ui.internal.FigureDocument` |
| Classic menu model | `detecdivui.MenuCommand` |
| Classic menu presentation | `desktopMenu.js`, installed only in this app's CEF window |
| Scientific navigation and display | Existing `Viewer` / `Session` and legacy readers |

`FigureDocumentGroup` is required: a generic `DocumentGroup` does not install the factory needed to render native figure contents. All three widgets are figure documents so that their existing handles and callbacks survive detachment; there is no replacement tree or copied image widget on undocking.

AppContainer does not expose the same top-level `uimenu` interface as a standalone `uifigure`. A small menu adapter provides the conventional menu bar above its workspace. It uses semantic menu roles, keyboard navigation and the same MATLAB command callbacks. A local timer drains only allowlisted menu command IDs from this window; it is stopped on close. CEF access is serialized to avoid reentrant screenshot/menu requests. No MATLAB installation files are modified.

The shell itself is code-owned. App Designer can still be used for widget contents once their layout is stable; it does not own the native docking layout.

## Persistence contract

The JSON envelope is `detecdiv.ui.layout.v1`, with the MATLAB release, native layout snapshot, main window bounds and each widget's docked/visible state and floating-window bounds. Stable widget tags are `projects`, `image` and `display` in the `workspace` figure document group.

Saving waits for asynchronous layout changes to settle and writes to a temporary file before replacing the preference file. Restoring applies widget states before the native layout, so invisible or floating widgets are not reinserted into the wrong docked grid. Layout files from another release or malformed files fall back to the default layout. A rejected file is preserved; automatic saving is suppressed until an explicit successful save or restore.

## Verification

```matlab
detecdivui.dockingTest();
detecdivui.smokeTest();
```

The docking integration test checks actual visible native floating windows, menu-to-MATLAB dispatch, detachment and redocking of all three widgets, retained tree/control/image handles, non-default column widths, floating bounds, hidden widgets, normal-close auto-save, fresh-instance restoration, corrupt preference recovery and timer cleanup. The navigation test separately checks multi-project browsing, TIFF pixels, RGB grouping, time navigation and read-error recovery.

An optional PNG path to either test captures the main workspace for visual inspection. Real acquisition testing, multi-monitor layout migration and other MATLAB releases remain outside this validation scope.

Validated on 4 November 2026 under Windows MATLAB R2026a: `dockingTest` and `smokeTest` passed without warnings, Code Analyzer was clean, and the exported workspace was inspected. Gilles subsequently confirmed successful interactive use of the shell. The agent's separate mouse-drag check was interrupted with Escape and is not counted as a completed drag-and-drop test.
