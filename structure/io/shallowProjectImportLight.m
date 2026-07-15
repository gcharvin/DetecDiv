function [shallowObj, msg] = shallowProjectImportLight(jsonPath, varargin)
%SHALLOWPROJECTIMPORTLIGHT Reconstruct a shallow object from a v2 JSON manifest.

projectDirOverride = '';
if ~isempty(varargin)
    ip = inputParser;
    ip.addParameter('ProjectDir', '', @(x)ischar(x) || isstring(x));
    ip.parse(varargin{:});
    projectDirOverride = char(string(ip.Results.ProjectDir));
end

jsonPath = char(string(jsonPath));
if ~isfile(jsonPath)
    shallowObj = [];
    msg = ['Fichier introuvable : ' jsonPath];
    disp(msg);
    return;
end

project = jsondecode(fileread(jsonPath));
if ~isfield(project, 'schemaVersion') || double(project.schemaVersion) < 2
    error('shallowProjectImportLight:UnsupportedSchema', ...
        'Unsupported or missing project schemaVersion in %s.', jsonPath);
end

[jsonFolder, jsonName] = fileparts(jsonPath);
projectName = localFieldText(project, 'projectName', jsonName);

if isempty(projectDirOverride)
    effectivePath = [jsonFolder filesep];
    effectiveFile = projectName;
else
    [effectivePath0, effectiveFile] = fileparts(projectDirOverride);
    effectivePath = [effectivePath0 filesep];
end

shallowObj = shallow();
shallowObj.setPath(effectivePath, effectiveFile);
if isprop(shallowObj, 'projectId')
    shallowObj.projectId = localFieldText(project, 'projectId', '');
end
if isfield(project, 'tag')
    shallowObj.tag = localFieldText(project, 'tag', shallowObj.tag);
end
if isfield(project, 'runProfiles') && isstruct(project.runProfiles)
    shallowObj.runProfiles = project.runProfiles;
end

projectDir = fullfile(effectivePath, effectiveFile);
if isfield(project, 'paths') && isstruct(project.paths) && isfield(project.paths, 'projectDir')
    projectDir = localResolveProjectPath(localFieldText(project.paths, 'projectDir', projectDir), jsonFolder);
end

shallowObj.fov = localBuildFovs(project, shallowObj, projectDir);
shallowObj.processing = struct('roi', [], 'classification', [], ...
    'processor', process.empty, 'pipelineRun', pipelineRun.empty);

try
    shallowObj.processing.classification = localLoadClassifiers(project, projectDir);
catch ME
    warning('shallowProjectImportLight:ClassifierLoadFailed', '%s', ME.message);
    shallowObj.processing.classification = classi.empty;
end

try
    shallowObj.processing.processor = localLoadProcessors(project, projectDir);
catch ME
    warning('shallowProjectImportLight:ProcessorLoadFailed', '%s', ME.message);
    shallowObj.processing.processor = process.empty;
end

try
    shallowObj.processing.pipelineRun = localLoadPipelineRuns(project, projectDir);
catch ME
    warning('shallowProjectImportLight:PipelineRunLoadFailed', '%s', ME.message);
    shallowObj.processing.pipelineRun = pipelineRun.empty;
end

msg = ['Successfully loaded lightweight shallow project ' jsonPath '!'];
disp(msg);
end

function fovs = localBuildFovs(project, shallowObj, projectDir)
fovs = fov.empty;
if ~isfield(project, 'fovs') || isempty(project.fovs)
    return;
end

items = project.fovs;
for i = 1:numel(items)
    item = items(i);
    f = fov();
    f.parent = shallowObj;
    f.id = localFieldText(item, 'id', '');
    f.number = localFieldValue(item, 'number', i);
    f.tag = localFieldText(item, 'tag', f.tag);
    f.comments = localFieldText(item, 'comments', '');
    f.srcpath = localRowCell(localCellValue(localFieldValue(item, 'srcpath', {''})));
    f.channel = localRowCell(localCellValue(localFieldValue(item, 'channel', {})));
    f.frames = localRowValue(localFieldValue(item, 'frames', []));
    f.interval = localRowValue(localFieldValue(item, 'interval', []));
    f.binning = localRowValue(localFieldValue(item, 'binning', []));
    f.orientation = localFieldValue(item, 'orientation', 0);
    f.crop = localMatrixValue(localFieldValue(item, 'crop', []));
    f.pattern = localMatrixValue(localFieldValue(item, 'pattern', []));
    f.drift = localMatrixValue(localFieldValue(item, 'drift', []));
    if isfield(item, 'display') && isstruct(item.display)
        f.display = item.display;
    end
    if isfield(item, 'raw') && isstruct(item.raw)
        f = localApplyRawFields(f, item.raw, projectDir);
    end
    f = localEnsureFovSourceLists(f);
    f.roi = localBuildRois(item, f, projectDir);
    fovs(end + 1) = f; %#ok<AGROW>
end
end

function f = localEnsureFovSourceLists(f)
usesVirtualSource = (isprop(f, 'isMultiTiff') && f.isMultiTiff) || ...
    (isprop(f, 'isNDTiff') && f.isNDTiff) || ...
    (isprop(f, 'isOMEZarr') && f.isOMEZarr) || ...
    (isprop(f, 'isStackSeries') && f.isStackSeries);
if usesVirtualSource || ~iscell(f.srcpath) || isempty(f.srcpath)
    return;
end
for ch = 1:numel(f.srcpath)
    if ch <= numel(f.srclist) && ~isempty(f.srclist{ch})
        continue;
    end
    folder = char(string(f.srcpath{ch}));
    if ~isfolder(folder)
        continue;
    end
    files = localListImageFiles(folder);
    if isempty(files)
        continue;
    end
    f.srclist{ch} = files;
    if numel(f.frames) < ch || isempty(f.frames(ch)) || f.frames(ch) <= 0
        if isempty(f.frames)
            f.frames = zeros(1, numel(f.srcpath));
        elseif numel(f.frames) < ch
            f.frames(end+1:ch) = 0;
        end
        f.frames(ch) = numel(files);
    end
end
end

function files = localListImageFiles(folder)
patterns = {'*.tif','*.tiff','*.jpg','*.jpeg','*.png'};
files = struct('name', {}, 'folder', {}, 'date', {}, 'bytes', {}, 'isdir', {}, 'datenum', {});
for i = 1:numel(patterns)
    files = [files; dir(fullfile(folder, patterns{i}))]; %#ok<AGROW>
end
if isempty(files)
    return;
end
names = {files.name};
keep = ~startsWith(names, '._') & ~strcmp(names, '.DS_Store');
files = files(keep);
if isempty(files)
    return;
end
[~, idx] = sort(lower({files.name}));
files = files(idx);
end

function f = localApplyRawFields(f, raw, projectDir)
names = {'isMultiTiff','tiffSource','pageMap','isStackSeries','stackPageMap', ...
    'isNDTiff','ndtiffPath','ndtiffPosition','ndtiffChannels','ndtiffZ', ...
    'isOMEZarr','omeZarrPath','omeZarrSeries','omeZarrArrayPath', ...
    'omeZarrShape','omeZarrChunkShape','omeZarrDtype','omeZarrDimensionNames', ...
    'omeZarrChannelIndices','omeZarrZIndices'};
for i = 1:numel(names)
    name = names{i};
    if ~isprop(f, name) || ~isfield(raw, name)
        continue;
    end
    value = raw.(name);
    if any(strcmp(name, {'tiffSource','ndtiffPath','omeZarrPath'}))
        value = localResolvePathValue(value, projectDir);
    end
    try
        f.(name) = value;
    catch
    end
end
end

function rois = localBuildRois(fovItem, fovObj, projectDir)
rois = roi.empty;
if ~isfield(fovItem, 'rois') || isempty(fovItem.rois)
    return;
end

items = fovItem.rois;
for i = 1:numel(items)
    item = items(i);
    r = roi(localFieldText(item, 'id', ''), localFieldValue(item, 'value', []));
    r.parent = fovObj;
    r.path = localResolveProjectPath(localFieldText(item, 'path', ''), projectDir);
    r.value = localRowValue(r.value);
    r.channelid = localRowValue(localFieldValue(item, 'channelid', r.channelid));
    if isfield(item, 'display') && isstruct(item.display)
        r.display = item.display;
    end
    if isfield(item, 'extraction') && isstruct(item.extraction)
        r.extraction = item.extraction;
    end
    r.image = [];
    r.data = dataseries.empty;
    rois(end + 1) = r; %#ok<AGROW>
end
end

function list = localLoadClassifiers(project, projectDir)
list = classi.empty;
if ~isfield(project, 'classifiers')
    return;
end
refs = project.classifiers;
for i = 1:numel(refs)
    p = localResolveProjectPath(localFieldText(refs(i), 'path', ''), projectDir);
    id = localFieldText(refs(i), 'id', '');
    matPath = fullfile(p, [id '_classification.mat']);
    if isfile(matPath)
        [obj, ~] = classiLoad(matPath);
        if isa(obj, 'classi')
            list(end + 1) = obj; %#ok<AGROW>
        end
    end
end
end

function list = localLoadProcessors(project, projectDir)
list = process.empty;
if ~isfield(project, 'processors')
    return;
end
refs = project.processors;
for i = 1:numel(refs)
    p = localResolveProjectPath(localFieldText(refs(i), 'path', ''), projectDir);
    id = localFieldText(refs(i), 'id', '');
    matPath = fullfile(p, [id '_processor.mat']);
    if isfile(matPath)
        [obj, ~] = processLoad(matPath);
        if isa(obj, 'process')
            list(end + 1) = obj; %#ok<AGROW>
        end
    end
end
end

function list = localLoadPipelineRuns(project, projectDir)
list = pipelineRun.empty;
if ~isfield(project, 'pipelineRuns')
    return;
end
refs = project.pipelineRuns;
for i = 1:numel(refs)
    p = localResolveProjectPath(localFieldText(refs(i), 'path', ''), projectDir);
    if isfile(p)
        p = fileparts(p);
    end
    if isfolder(p)
        [obj, msg] = pipelineRunLoad(p);
        if isempty(obj)
            warning('shallowProjectImportLight:PipelineRunSkipped', '%s', msg);
        elseif isa(obj, 'pipelineRun')
            list(end + 1) = obj; %#ok<AGROW>
        end
    end
end
end

function value = localFieldValue(S, name, defaultValue)
if isstruct(S) && isfield(S, name)
    value = S.(name);
else
    value = defaultValue;
end
end

function text = localFieldText(S, name, defaultValue)
value = localFieldValue(S, name, defaultValue);
if isempty(value)
    text = '';
    return;
end
try
    if iscell(value)
        value = value{1};
    end
    text = char(string(value));
catch
    text = char(string(defaultValue));
end
end

function value = localCellValue(value)
if isempty(value)
    value = {};
elseif iscell(value)
    return;
elseif ischar(value) || isstring(value)
    value = cellstr(string(value));
end
end

function value = localRowCell(value)
if iscell(value)
    value = reshape(value, 1, []);
end
end

function value = localRowValue(value)
if isnumeric(value) || islogical(value)
    value = reshape(value, 1, []);
elseif isstring(value)
    value = reshape(value, 1, []);
elseif iscell(value)
    value = reshape(value, 1, []);
end
end

function value = localMatrixValue(value)
if isnumeric(value) || islogical(value)
    if isempty(value)
        return;
    end
    if isvector(value)
        value = reshape(value, 1, []);
    end
elseif iscell(value)
    value = reshape(value, 1, []);
end
end

function value = localResolvePathValue(value, baseDir)
if iscell(value)
    for i = 1:numel(value)
        value{i} = localResolveProjectPath(value{i}, baseDir);
    end
elseif ischar(value) || isstring(value)
    value = localResolveProjectPath(value, baseDir);
end
end

function pathOut = localResolveProjectPath(pathText, baseDir)
pathOut = char(string(pathText));
if isempty(pathOut)
    return;
end
if isfolder(pathOut) || isfile(pathOut) || localIsAbsolute(pathOut)
    return;
end
pathOut = fullfile(baseDir, pathOut);
end

function tf = localIsAbsolute(pathText)
pathText = char(string(pathText));
tf = ~isempty(regexp(pathText, '^[A-Za-z]:[\\/]', 'once')) || startsWith(pathText, '/') || startsWith(pathText, '\\');
end
