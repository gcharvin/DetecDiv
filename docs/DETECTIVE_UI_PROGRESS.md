# Progress UI and frontend handoffs

## Policy

Long frontend operations show progress before the first blocking read, save or computation. In the dockable UI, use the initiating widget's footer; use the Image footer when that widget is hidden or Pipeline/Display is behind another tab, or another visible footer if Image is hidden. Floating widgets retain the same progress component. The idle footer returns when the operation finishes, returns early or fails. Messages are transient, concise and in English.

Use a backend's real progress callback when available. Without a measurable fraction, use an indeterminate indicator. Do not estimate elapsed-time percentages or add a cancellation button to a synchronous operation that cannot honour it. Existing pipeline/ROI-extraction cancellation contracts remain unchanged.

`detecdivui.Progress.begin` returns an `onCleanup` scope. Keep it alive for the operation. Nested scopes restore their parent's message and fraction; one widget finishing does not dismiss another widget's indicator. The HTML footer animates independently of MATLAB timers. It does not make the underlying I/O asynchronous. All-hidden layouts cannot display a footer until a document is shown.

```matlab
activity = obj.Progress.begin('Loading pipeline...'); %#ok<NASGU>
% Real work follows. update(message, fraction) is optional.
```

Progress objects, GUI handles and scopes are never added to persisted run contexts. Backend algorithms and execution policies remain shared.

## Dockable UI coverage

| Operation | Initial owner | Progress source |
| --- | --- | --- |
| Open/add/close project, build project tree | Projects | Indeterminate; `shallowLoad` metadata callback on file load |
| Discover/import workspace objects | Projects | Actual project count, then nested project operations |
| Relink raw paths | Projects | Indeterminate around the existing relink helper |
| Read raw pixels or ROI H5, render visible layers | Image | Indeterminate around existing readers and score rendering |
| Adjust display/Auto, copy image | Display / Image | Indeterminate; cached source data is preserved |
| Open/refresh/save pipeline | Pipeline | Indeterminate around existing helpers and graph refresh |
| Validate/dry run, save run, read run review | Pipeline | Indeterminate around shared backend calls |
| Movie/PDF/PNG/TIFF snapshot, preview and export | Export Movie (Display), falling back to Image/visible footer | Source loading indeterminate; real video-frame/sequence-cell fractions; cooperative Cancel, writer/temp cleanup |
| Frozen export snapshot and Hub submission | Export Movie / visible footer | Selected frame count during snapshot; standard Score Hub submit; widget-owned status polling/cancel, no startup request |
| Open advanced editor or run inspector | Pipeline | Caller covers construction; destination owns its subsequent operations |
| Save/restore/reset layout | Image | Scoped host activity callback |

The window is started before importing constructor-supplied projects, so the progress footer can be painted during metadata import. Startup still does not preload pixels or search raw-data roots.

## Legacy audit

`progressAudit` reads MATLAB sources under structure/engine/helpers and the embedded code of runtime MLAPP files, without extracting over sources. `DETECTIVE_UI_PROGRESS_INVENTORY.csv` records file, code line, enclosing function, constructor/handoff API, owner and a cleanup hint. Source variants and embedded code are intentionally listed separately: inventory rows are **not** distinct windows. Hints are conservative static checks, not proof that every branch has executed. Tests/layout sources are excluded; historical runtime app copies remain identifiable by filename.

The five principal runtime apps contain 61 progress-dialog constructors:

| Runtime | Dialog sites | Lifecycle review |
| --- | ---: | --- |
| detecdiv.mlapp | 27 | Local dialogs scoped; ROI-tree and workspace-refresh dialogs retain their asynchronous owners; run dialog is returned to its owner |
| pipeline2.mlapp | 14 | Local dialogs scoped; shared/nested `RuntimeProgressDialog` retains existing ownership |
| workflow.mlapp | 7 | Save/detection/generation/extraction/read scopes; first uncached channel now paints progress before reading, including a single channel |
| workflow2.mlapp | 7 | Existing pre-read indicator retained; local scopes cover failure/early exit |
| score/score.mlapp | 6 | Metrics, prediction initialization, findings, GT validation, ROI save and movie export scopes |

49 additional `onCleanup` guards protect local dialogs that previously relied on manual closes or a later cleanup registration. `detecdiv_close_progress` is idempotent after an explicit close or parent deletion. Existing owners are not replaced globally, and unrelated running windows are never closed. The following were deliberately preserved: `startRoiTreeBuild`/stop callbacks, workspace-refresh cleanup, `createPipelineRunProgressDialog`/active-run control, and nested `openRuntimeProgress`/outer cleanup. Job-monitor and cancel callbacks retain their existing lifetime and semantics.

Frontend handoffs inventoried include DetecDiv to Score/classifiers/pipeline2, Pipeline to ROI workflow/editors, and widget to pipeline2/run inspector. Destinations keep their own progress for subsequent work. The compact viewer currently renders through score helpers rather than launching Score; classifier selection there does not yet launch an editor.

Callback changes were packed back into detecdiv/pipeline2/workflow/workflow2 using `sync_mlapp_code`, and Score using `sync_score_layout`. The runtime code is verified against each authoritative source. No processing engine, model runtime, worker or execution-policy change is included.

## Verification and maintenance

The ROIs assistant scopes drawing preparation, preview and creation in its visible footer, falling back to the main image when hidden. Scratch previews call existing ROI packages without mutating source ROI collections. Run Settings and the advanced-editor handoff share the Pipeline progress owner; applying advanced settings is scoped before disposing the child window. The compact run-follow timer reads in-memory status only: explicit Refresh uses the existing review helper, and remote job monitoring remains in pipeline2. Metadata-only Save Project and Save Run also expose scoped progress. Custom layer-row and histogram edits enter the same scoped Display progress owner as native color/contrast controls; image reads and histogram cache construction remain inside the main render scope.

```matlab
detecdivui.progressTest();
detecdivui.progressLegacyTest(fullfile(pwd,'docs','DETECTIVE_UI_PROGRESS_INVENTORY.csv'));
detecdivui.pipelineSettingsTest('',true);
detecdivui.newRunTest('',true);
```

The native progress test covers nested and independent owners, hidden-widget fallback, error unwinding, early scope removal, real project-load metadata callbacks, failed file opens, manual dialog close and deleted parents. Viewer smoke/display/workspace/pipeline/lazy-image regressions cover the connected controls. Optional PNG capture checks footer layout at the default compact width. Runtime/source equality and scoped ownership of synchronous dialog sites are checked statically for all five principal apps; representative advanced-editor construction is exercised natively. Score's ROI-save menu callback was also exercised on a temporary H5 store, and its existing GT-progress regression passed. Real acquisition processing, remote submission and every scientific error/cancel branch are not executed by these UI tests.

For each future port from Score, DetecDiv, Workflow or Pipeline: review the source operation and its callers, retain backend progress/cancel callbacks, choose a visible owner before blocking, scope cleanup, and add the handoff to this inventory. Do not silently drop existing progress while moving a function into a widget.

Movie export reuses Score's layout/render/capture/writer on an isolated canvas. The contextual assistant moves its active progress scope to a visible footer when its document is hidden/covered. Cancellation is checked before composition and between video frames; PDF printing itself is synchronous. See `DETECTIVE_UI_MOVIES.md` and the movie export/recipe tests.
