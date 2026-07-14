function displayValidationRuns(classif, selectedRois)
% displayValidationRuns  Browse SAM31 validation runs and checkpoints.

if nargin < 2
    selectedRois = [];
end

if isempty(classif) || ~isprop(classif, 'path') || isempty(classif.path)
    error('sam31:ValidationBrowserNoClassifier', 'SAM31 validation browser requires a saved classifier path.');
end

state = refreshState(classif, selectedRois);
fig = uifigure('Name', sprintf('SAM31 validation runs - %s', safeClassifierName(classif)), ...
    'Position', [120 120 1120 680]);
grid = uigridlayout(fig, [5 1]);
grid.RowHeight = {28, '1x', 28, 180, 42};
grid.ColumnWidth = {'1x'};

header = uilabel(grid, 'Text', headerText(classif, state), 'FontWeight', 'bold');
header.Layout.Row = 1;

runTable = uitable(grid);
runTable.Layout.Row = 2;
runTable.ColumnName = {'Run', 'Status', 'Created', 'Updated', 'Resolution', 'Frames', 'ROIs', 'Duration', 'Path'};
runTable.ColumnWidth = {240, 80, 145, 145, 80, 100, 60, 90, 320};
runTable.Multiselect = 'on';

ckptLabel = uilabel(grid, 'Text', 'Checkpoints', 'FontWeight', 'bold');
ckptLabel.Layout.Row = 3;

ckptTable = uitable(grid);
ckptTable.Layout.Row = 4;
ckptTable.ColumnName = {'Active', 'Resolution', 'Modified', 'Size MB', 'Path'};
ckptTable.ColumnWidth = {70, 90, 145, 80, 650};
ckptTable.Multiselect = 'off';

buttons = uigridlayout(grid, [1 7]);
buttons.Layout.Row = 5;
buttons.ColumnWidth = {110, 110, 130, 150, 170, 130, '1x'};
uibutton(buttons, 'Text', 'Refresh', 'ButtonPushedFcn', @(~, ~) refreshTables());
uibutton(buttons, 'Text', 'Open run', 'ButtonPushedFcn', @(~, ~) openSelectedRun());
uibutton(buttons, 'Text', 'Compare runs', 'ButtonPushedFcn', @(~, ~) compareSelectedRuns());
uibutton(buttons, 'Text', 'Open checkpoint', 'ButtonPushedFcn', @(~, ~) openSelectedCheckpoint());
uibutton(buttons, 'Text', 'Use checkpoint', 'ButtonPushedFcn', @(~, ~) useSelectedCheckpoint());
uibutton(buttons, 'Text', 'Open classifier', 'ButtonPushedFcn', @(~, ~) openPath(classif.path));
uilabel(buttons, 'Text', 'Validation results are listed from pipeline_runs/validate_*; checkpoints are discovered from sam31_artifacts.');

refreshTables();

    function refreshTables()
        state = refreshState(classif, selectedRois);
        runTable.Data = runsToCell(state.runs);
        ckptTable.Data = checkpointsToCell(state.checkpoints);
        header.Text = headerText(classif, state);
    end

    function openSelectedRun()
        idx = selectedRows(runTable);
        if isempty(idx)
            uialert(fig, 'Select one validation run first.', 'SAM31 validation runs', 'Icon', 'warning');
            return;
        end
        openPath(state.runs(idx(1)).path);
    end

    function compareSelectedRuns()
        idx = selectedRows(runTable);
        if numel(idx) ~= 2
            uialert(fig, 'Select exactly two validation runs to compare.', 'SAM31 validation runs', 'Icon', 'warning');
            return;
        end
        showRunComparison(state.runs(idx(1)), state.runs(idx(2)));
    end

    function openSelectedCheckpoint()
        idx = selectedRows(ckptTable);
        if isempty(idx)
            uialert(fig, 'Select one checkpoint first.', 'SAM31 checkpoints', 'Icon', 'warning');
            return;
        end
        openPath(fileparts(state.checkpoints(idx(1)).path));
    end

    function useSelectedCheckpoint()
        idx = selectedRows(ckptTable);
        if isempty(idx)
            uialert(fig, 'Select one checkpoint first.', 'SAM31 checkpoints', 'Icon', 'warning');
            return;
        end
        ckpt = state.checkpoints(idx(1));
        if isempty(classif.executionParam) || ~isstruct(classif.executionParam)
            classif.executionParam = sam31.utils.defaultExecutionParam();
        end
        classif.executionParam.detectorCheckpointPath = ckpt.path;
        classif.executionParam.activeCheckpointPath = ckpt.path;
        classif.executionParam.activeCheckpointSetAt = char(datetime('now'));
        try
            classif.executionParam.resolution = char(string(ckpt.resolution));
        catch
        end
        refreshTables();
        uialert(fig, sprintf(['Active SAM31 detector checkpoint set for this classifier session:\n%s\n\n' ...
            'Use "Save classifier" to persist this choice.'], ckpt.path), ...
            'SAM31 checkpoints', 'Icon', 'success');
    end

    function showRunComparison(a, b)
        lines = compareRunsText(a, b);
        cfig = uifigure('Name', 'SAM31 run comparison', 'Position', [180 180 780 520]);
        cg = uigridlayout(cfig, [2 1]);
        cg.RowHeight = {'1x', 36};
        txt = uitextarea(cg, 'Value', lines, 'Editable', 'off');
        txt.FontName = 'Consolas';
        uibutton(cg, 'Text', 'Close', 'ButtonPushedFcn', @(~, ~) delete(cfig));
    end
end

function state = refreshState(classif, selectedRois)
state = struct();
state.runs = collectValidationRuns(classif, selectedRois);
state.checkpoints = collectCheckpoints(classif);
end

function runs = collectValidationRuns(classif, selectedRois)
runs = emptyRunStruct();
roots = {};
roots{end+1} = fullfile(classif.path, 'pipeline_runs');
roots{end+1} = fullfile(classif.path, 'validation_runs');
roots{end+1} = fullfile(classif.path, 'runs');

for r = 1:numel(roots)
    root = roots{r};
    if exist(root, 'dir') ~= 7
        continue;
    end
    dirs = [dir(fullfile(root, 'validate*')); dir(fullfile(root, 'validation*'))];
    dirs = dirs([dirs.isdir]);
    for i = 1:numel(dirs)
        runPath = fullfile(dirs(i).folder, dirs(i).name);
        item = inspectRun(runPath, dirs(i), selectedRois);
        if isempty(runs)
            runs = item;
        else
            runs(end+1) = item; %#ok<AGROW>
        end
    end
end

if ~isempty(runs)
    [~, order] = sort([runs.modifiedDatenum], 'descend');
    runs = runs(order);
end
end

function item = inspectRun(runPath, dirEntry, selectedRois)
item = defaultRunStruct();
item.id = dirEntry.name;
item.path = runPath;
item.status = '';
item.created = '';
item.updated = char(string(dirEntry.date));
item.modifiedDatenum = dirEntry.datenum;
item.resolution = '';
item.frames = '';
item.rois = '';
item.duration = '';
item.summary = '';
item.paramsPath = '';
item.runJsonPath = '';

paramsPath = fullfile(runPath, 'run_params.json');
runJsonPath = fullfile(runPath, 'run.json');
summaryPath = fullfile(runPath, 'run_summary.txt');
if exist(paramsPath, 'file') == 2
    item.paramsPath = paramsPath;
    item = mergeRunJson(item, paramsPath);
end
if exist(runJsonPath, 'file') == 2
    item.runJsonPath = runJsonPath;
    item = mergeRunJson(item, runJsonPath);
end
if exist(summaryPath, 'file') == 2
    item.summary = readText(summaryPath);
    item = mergeRunSummary(item, item.summary);
end
if isempty(item.rois) && ~isempty(selectedRois)
    item.rois = num2str(numel(selectedRois));
end
if isempty(item.status)
    item.status = 'unknown';
end
end

function item = mergeRunJson(item, jsonPath)
txt = readText(jsonPath);
if isempty(txt)
    return;
end
try
    s = jsondecode(txt);
catch
    s = struct();
end
item.status = firstNonEmpty(item.status, fieldText(s, {'status'}));
item.created = firstNonEmpty(item.created, fieldText(s, {'createdAt'}));
item.updated = firstNonEmpty(item.updated, fieldText(s, {'updatedAt'}));
item.resolution = firstNonEmpty(item.resolution, regexpValue(txt, '"resolution"\s*:\s*"?([^",}\s]+)"?'));
item.frames = firstNonEmpty(item.frames, framesText(s));
item.rois = firstNonEmpty(item.rois, roiText(s));
item.duration = firstNonEmpty(item.duration, regexpValue(txt, '"duration"\s*:\s*([0-9.]+)'));
end

function item = mergeRunSummary(item, txt)
item.status = firstNonEmpty(item.status, regexpValue(txt, 'Status:\s*([^\r\n]+)'));
item.created = firstNonEmpty(item.created, regexpValue(txt, 'Created:\s*([^\r\n]+)'));
item.updated = firstNonEmpty(item.updated, regexpValue(txt, 'Updated:\s*([^\r\n]+)'));
dur = regexpValue(txt, 'duration=([0-9.]+s)');
item.duration = firstNonEmpty(item.duration, dur);
roi = regexpValue(txt, 'roi=([0-9]+->[0-9]+)');
item.rois = firstNonEmpty(item.rois, roi);
end

function checkpoints = collectCheckpoints(classif)
checkpoints = emptyCheckpointStruct();
root = fullfile(classif.path, 'sam31_artifacts');
if exist(root, 'dir') ~= 7
    return;
end
files = dir(fullfile(root, '**', 'checkpoint*.pt'));
explicitPath = '';
try
    explicitPath = char(string(classif.executionParam.detectorCheckpointPath));
catch
end
for i = 1:numel(files)
    p = fullfile(files(i).folder, files(i).name);
    item = defaultCheckpointStruct();
    item.path = p;
    item.active = false;
    item.activeLabel = '';
    item.resolution = inferResolutionFromPath(p);
    item.modified = char(string(files(i).date));
    item.modifiedDatenum = files(i).datenum;
    item.sizeMb = files(i).bytes / 1024 / 1024;
    if isempty(checkpoints)
        checkpoints = item;
    else
        checkpoints(end+1) = item; %#ok<AGROW>
    end
end
if ~isempty(checkpoints)
    [~, order] = sort([checkpoints.modifiedDatenum], 'descend');
    checkpoints = checkpoints(order);
    if ~isempty(explicitPath)
        for i = 1:numel(checkpoints)
            if samePath(checkpoints(i).path, explicitPath)
                checkpoints(i).active = true;
                checkpoints(i).activeLabel = 'explicit';
                break;
            end
        end
    else
        activePath = autoDetectorCheckpointPath(classif, checkpoints);
        for i = 1:numel(checkpoints)
            if samePath(checkpoints(i).path, activePath)
                checkpoints(i).active = true;
                checkpoints(i).activeLabel = 'auto';
                break;
            end
        end
    end
end
end

function data = runsToCell(runs)
data = cell(numel(runs), 9);
for i = 1:numel(runs)
    data{i, 1} = runs(i).id;
    data{i, 2} = runs(i).status;
    data{i, 3} = runs(i).created;
    data{i, 4} = runs(i).updated;
    data{i, 5} = runs(i).resolution;
    data{i, 6} = runs(i).frames;
    data{i, 7} = runs(i).rois;
    data{i, 8} = runs(i).duration;
    data{i, 9} = runs(i).path;
end
end

function data = checkpointsToCell(checkpoints)
data = cell(numel(checkpoints), 5);
for i = 1:numel(checkpoints)
    if checkpoints(i).active
        data{i, 1} = checkpoints(i).activeLabel;
    else
        data{i, 1} = '';
    end
    data{i, 2} = checkpoints(i).resolution;
    data{i, 3} = checkpoints(i).modified;
    data{i, 4} = sprintf('%.1f', checkpoints(i).sizeMb);
    data{i, 5} = checkpoints(i).path;
end
end

function lines = compareRunsText(a, b)
lines = {
    sprintf('Run A: %s', a.id)
    sprintf('Run B: %s', b.id)
    ''
    sprintf('%-14s | %-30s | %-30s', 'Field', 'A', 'B')
    repmat('-', 1, 82)
    compareLine('Status', a.status, b.status)
    compareLine('Created', a.created, b.created)
    compareLine('Updated', a.updated, b.updated)
    compareLine('Resolution', a.resolution, b.resolution)
    compareLine('Frames', a.frames, b.frames)
    compareLine('ROIs', a.rois, b.rois)
    compareLine('Duration', a.duration, b.duration)
    ''
    'Run folders:'
    ['A: ' a.path]
    ['B: ' b.path]
    ''
    'Note: per-run masks/previews will appear here once validation archives results per run.'
    };
end

function line = compareLine(name, a, b)
line = sprintf('%-14s | %-30s | %-30s', name, truncateText(a, 30), truncateText(b, 30));
end

function idx = selectedRows(tbl)
idx = [];
try
    sel = tbl.Selection;
    if isempty(sel)
        return;
    end
    idx = unique(sel(:, 1));
    idx = idx(:)';
catch
    idx = [];
end
end

function openPath(pathStr)
if isempty(pathStr)
    return;
end
try
    if ispc
        winopen(pathStr);
    elseif ismac
        system(sprintf('open %s', shellQuote(pathStr)));
    else
        system(sprintf('xdg-open %s', shellQuote(pathStr)));
    end
catch ME
    warning('sam31:OpenPathFailed', 'Could not open %s: %s', pathStr, ME.message);
end
end

function txt = headerText(classif, state)
[active, mode] = activeDetectorCheckpointText(classif, state);
if isempty(active)
    active = '(none found)';
end
txt = sprintf('Classifier: %s     Active detector checkpoint (%s): %s', safeClassifierName(classif), mode, active);
end

function [active, mode] = activeDetectorCheckpointText(classif, state)
active = '';
mode = 'explicit';
try
    active = char(string(classif.executionParam.detectorCheckpointPath));
catch
end
if isempty(active)
    mode = 'auto';
    try
        active = autoDetectorCheckpointPath(classif, state.checkpoints);
    catch
        active = '';
    end
end
end

function pathStr = autoDetectorCheckpointPath(classif, checkpoints)
pathStr = '';
if isempty(checkpoints)
    return;
end
resolution = activeResolutionText(classif);
if ~isempty(resolution)
    idx = find(strcmp(string({checkpoints.resolution}), string(resolution)), 1, 'first');
    if ~isempty(idx)
        pathStr = checkpoints(idx).path;
        return;
    end
end
pathStr = checkpoints(1).path;
end

function resolution = activeResolutionText(classif)
resolution = '';
try
    if isprop(classif, 'executionParam') && isstruct(classif.executionParam) && ...
            isfield(classif.executionParam, 'resolution') && ~isempty(classif.executionParam.resolution)
        resolution = char(string(classif.executionParam.resolution));
        return;
    end
catch
end
try
    if isprop(classif, 'trainingParam') && isstruct(classif.trainingParam) && ...
            isfield(classif.trainingParam, 'resolution') && ~isempty(classif.trainingParam.resolution)
        resolution = char(string(classif.trainingParam.resolution));
    end
catch
end
end

function name = safeClassifierName(classif)
name = 'sam31';
try
    if ~isempty(classif.strid)
        name = char(string(classif.strid));
    end
catch
end
end

function value = framesText(s)
value = '';
try
    if isfield(s, 'sel') && isstruct(s.sel) && isfield(s.sel, 'frames') && ~isempty(s.sel.frames)
        value = vectorSummary(s.sel.frames);
    elseif isfield(s, 'run') && isstruct(s.run) && isfield(s.run, 'frames') && ~isempty(s.run.frames)
        value = vectorSummary(s.run.frames);
    end
catch
    value = '';
end
end

function value = roiText(s)
value = '';
try
    if isfield(s, 'run') && isstruct(s.run) && isfield(s.run, 'rois') && ~isempty(s.run.rois)
        value = char(string(s.run.rois));
    elseif isfield(s, 'sel') && isstruct(s.sel) && isfield(s.sel, 'rois') && ~isempty(s.sel.rois)
        value = vectorSummary(s.sel.rois);
    end
catch
    value = '';
end
end

function txt = vectorSummary(v)
v = v(:)';
if isempty(v)
    txt = '';
elseif numel(v) <= 8
    txt = strjoin(cellstr(string(v)), ',');
else
    txt = sprintf('%g-%g (%d)', v(1), v(end), numel(v));
end
end

function value = fieldText(s, names)
value = '';
try
    cur = s;
    for i = 1:numel(names)
        if isstruct(cur) && isfield(cur, names{i})
            cur = cur.(names{i});
        else
            return;
        end
    end
    if ~isempty(cur)
        value = char(string(cur));
    end
catch
    value = '';
end
end

function value = regexpValue(txt, pattern)
value = '';
try
    m = regexp(txt, pattern, 'tokens', 'once');
    if ~isempty(m)
        value = strtrim(m{1});
    end
catch
    value = '';
end
end

function value = firstNonEmpty(a, b)
if ~isempty(a)
    value = a;
else
    value = b;
end
end

function txt = readText(pathStr)
txt = '';
try
    if exist(pathStr, 'file') == 2
        txt = fileread(pathStr);
    end
catch
    txt = '';
end
end

function resolution = inferResolutionFromPath(pathStr)
resolution = '';
parts = regexp(pathStr, '[\\/]', 'split');
for i = numel(parts):-1:1
    tok = regexp(parts{i}, '(^|_)(\d{2,4})($|_)', 'tokens', 'once');
    if ~isempty(tok)
        resolution = tok{2};
        return;
    end
end
end

function tf = samePath(a, b)
if isempty(a) || isempty(b)
    tf = false;
    return;
end
a = char(string(a));
b = char(string(b));
if ispc
    tf = strcmpi(strrep(a, '/', '\'), strrep(b, '/', '\'));
else
    tf = strcmp(a, b);
end
end

function s = emptyRunStruct()
s = struct('id', {}, 'path', {}, 'status', {}, 'created', {}, 'updated', {}, ...
    'modifiedDatenum', {}, 'resolution', {}, 'frames', {}, 'rois', {}, ...
    'duration', {}, 'summary', {}, 'paramsPath', {}, 'runJsonPath', {});
end

function s = defaultRunStruct()
s = struct('id', '', 'path', '', 'status', '', 'created', '', 'updated', '', ...
    'modifiedDatenum', 0, 'resolution', '', 'frames', '', 'rois', '', ...
    'duration', '', 'summary', '', 'paramsPath', '', 'runJsonPath', '');
end

function s = emptyCheckpointStruct()
s = struct('active', {}, 'resolution', {}, 'modified', {}, 'modifiedDatenum', {}, ...
    'sizeMb', {}, 'path', {}, 'activeLabel', {});
end

function s = defaultCheckpointStruct()
s = struct('active', false, 'resolution', '', 'modified', '', 'modifiedDatenum', 0, ...
    'sizeMb', 0, 'path', '', 'activeLabel', '');
end

function out = truncateText(in, n)
out = char(string(in));
if numel(out) > n
    out = [out(1:max(1, n-3)) '...'];
end
end

function q = shellQuote(s)
q = ['''' strrep(char(string(s)), '''', '''"''"''') ''''];
end
