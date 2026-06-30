function report = backfillBudPairing(classifOrPath, varargin)
% sam31.backfillBudPairing  Populate cell_information lineageSources after inference.
%
% This is a lightweight post-processing pass: it reads existing SAM31 result
% channels from ROI H5 files, calls sam31.applyBudPairing, and optionally saves
% only the ROI data_*.mat files. It does not rerun SAM31 inference.

p = inputParser;
p.addParameter('OutputName', '', @(x) ischar(x) || isstring(x));
p.addParameter('RoiIds', {}, @(x) iscell(x) || isstring(x) || ischar(x));
p.addParameter('Save', false, @(x) islogical(x) || isnumeric(x));
p.addParameter('Params', struct(), @(x) isempty(x) || isstruct(x));
p.parse(varargin{:});

[classif, classifierPath] = localClassifierFromInput(classifOrPath);
outputName = char(string(p.Results.OutputName));
if isempty(outputName)
    outputName = localClassifStrid(classif, localFolderName(classifierPath));
end

roiIds = localNormalizeRoiIds(p.Results.RoiIds);
if isempty(roiIds)
    roiIds = localDiscoverRoiIds(classifierPath);
end

doSave = logical(p.Results.Save);
params = p.Results.Params;
if ~isfield(params, 'inferBudPairing')
    params.inferBudPairing = true;
end
classif.runProfiles.classify.params = params;

rows = repmat(struct('roiId', '', 'changed', false, 'reason', '', ...
    'sourceKey', '', 'channelName', '', 'nEvents', 0, 'saved', false, ...
    'error', ''), 0, 1);

for i = 1:numel(roiIds)
    roiId = roiIds{i};
    row = rowsTemplate(roiId);
    try
        r = roi;
        r.id = roiId;
        r.path = classifierPath;
        localLoadRoiForPairing(r, classif, outputName);

        rep = sam31.applyBudPairing(r, classif, 'OutputName', outputName);
        row.changed = logical(rep.changed);
        row.reason = char(string(rep.reason));
        row.sourceKey = char(string(rep.sourceKey));
        row.channelName = char(string(rep.channelName));
        row.nEvents = double(rep.nEvents);

        if doSave && row.changed
            r.save('data', false);
            row.saved = true;
        end
    catch ME
        row.reason = 'error';
        row.error = ME.message;
    end
    rows(end+1) = row; %#ok<AGROW>
end

report = struct();
report.classifierPath = classifierPath;
report.outputName = outputName;
report.save = doSave;
report.rows = rows;
report.nRois = numel(rows);
report.nChanged = nnz([rows.changed]);
report.nSaved = nnz([rows.saved]);
report.nErrors = nnz(~cellfun(@isempty, {rows.error}));
end

function localLoadRoiForPairing(r, classif, outputName)
if localLoadRoiFromSam31Workdir(r, classif, outputName)
    return;
end

className = 'cell';
try
    if ~isempty(classif.classes)
        className = char(string(classif.classes{1}));
    end
catch
end

candidates = {['results_' outputName '_' className], ...
    ['results_' outputName '_cell'], ...
    ['results_' localClassifStrid(classif, outputName) '_' className], ...
    ['results_' localClassifStrid(classif, outputName) '_cell']};
candidates = unique(candidates, 'stable');

lastError = [];
for i = 1:numel(candidates)
    try
        r.load('Channel', candidates{i}, 'Silent');
        return;
    catch ME
        lastError = ME;
    end
end

try
    r.load('Silent');
catch ME
    if ~isempty(lastError)
        error('sam31:BackfillLoadFailed', ...
            'Could not load SAM31 result channel for ROI %s. Last channel error: %s. Full load error: %s', ...
            char(string(r.id)), lastError.message, ME.message);
    end
    rethrow(ME);
end
end

function ok = localLoadRoiFromSam31Workdir(r, classif, outputName)
ok = false;
try
    resultsPath = fullfile(char(string(classif.path)), 'work', 'sam31', char(string(r.id)), 'results.mat');
    if exist(resultsPath, 'file') ~= 2
        return;
    end
    r.load('data');
    S = load(resultsPath, 'masks_all', 'frames_list');
    if ~isfield(S, 'masks_all') || isempty(S.masks_all)
        return;
    end
    masks = uint16(S.masks_all);
    if ndims(masks) == 3
        masks = reshape(masks, size(masks,1), size(masks,2), 1, size(masks,3));
    end

    channelName = ['results_' char(string(outputName)) '_cell'];
    r.image = masks;
    r.channelid = 1;
    r.display.channel = {channelName};
    r.display.indexed = 1;
    r.display.intensity = [0 0 0];
    r.display.rgb = [1 1 1];
    r.display.selectedchannel = 1;
    r.display.frame = 1;
    ok = true;
catch
    ok = false;
end
end

function row = rowsTemplate(roiId)
row = struct('roiId', char(string(roiId)), 'changed', false, 'reason', '', ...
    'sourceKey', '', 'channelName', '', 'nEvents', 0, 'saved', false, ...
    'error', '');
end

function [classif, classifierPath] = localClassifierFromInput(inputValue)
if isa(inputValue, 'classi')
    classif = inputValue;
    classifierPath = char(string(classif.path));
    return;
end

classifierPath = char(string(inputValue));
classif = classi;
classif.path = classifierPath;
classif.classifierPkg = 'sam31';
classif.classifyFun = 'sam31.classify';
classif.classes = {'cell'};

metaPath = fullfile(classifierPath, 'classi_meta.json');
if exist(metaPath, 'file') == 2
    try
        meta = jsondecode(fileread(metaPath));
        if isfield(meta, 'strid'), classif.strid = char(string(meta.strid)); end
        if isfield(meta, 'classifierPkg'), classif.classifierPkg = char(string(meta.classifierPkg)); end
        if isfield(meta, 'classes') && ~isempty(meta.classes)
            classif.classes = cellstr(string(meta.classes));
        end
    catch
    end
end
if isempty(classif.strid)
    classif.strid = localFolderName(classifierPath);
end
end

function ids = localDiscoverRoiIds(classifierPath)
files = dir(fullfile(classifierPath, 'im_*.h5'));
ids = cell(1, numel(files));
for i = 1:numel(files)
    name = files(i).name;
    ids{i} = regexprep(name, '^im_', '');
    ids{i} = regexprep(ids{i}, '\.h5$', '');
end
ids = sort(ids);
end

function ids = localNormalizeRoiIds(raw)
if isempty(raw)
    ids = {};
elseif ischar(raw) || (isstring(raw) && isscalar(raw))
    ids = {char(string(raw))};
elseif isstring(raw)
    ids = cellstr(raw);
else
    ids = raw;
end
ids = cellfun(@(x) char(string(x)), ids(:).', 'UniformOutput', false);
end

function name = localFolderName(pathValue)
[~, name] = fileparts(char(string(pathValue)));
if isempty(name)
    name = 'sam31';
end
end

function strid = localClassifStrid(classif, fallback)
strid = fallback;
try
    if isprop(classif, 'strid') && ~isempty(classif.strid)
        strid = char(string(classif.strid));
    end
catch
end
end
