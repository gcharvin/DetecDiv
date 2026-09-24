function [shallowObj, msg] = shallowProjectImportLight(jsonPath, varargin)
%SHALLOWPROJECTIMPORTLIGHT Reconstruct a shallow object from a v2/v3 JSON manifest.

projectDirOverride = '';
progressCallback = [];
if ~isempty(varargin)
    ip = inputParser;
    ip.addParameter('ProjectDir', '', @(x)ischar(x) || isstring(x));
    ip.addParameter('ProgressCallback', [], @(x)isempty(x) || isa(x, 'function_handle'));
    ip.parse(varargin{:});
    projectDirOverride = char(string(ip.Results.ProjectDir));
    progressCallback = ip.Results.ProgressCallback;
end

jsonPath = char(string(jsonPath));
if ~isfile(jsonPath)
    shallowObj = [];
    msg = ['Fichier introuvable : ' jsonPath];
    disp(msg);
    return;
end

localReportProgress(progressCallback, 0.01, 'Reading project JSON manifest...', 'json');
project = jsondecode(fileread(jsonPath));
localReportProgress(progressCallback, 0.04, 'Project JSON loaded; resolving project metadata...', 'metadata');
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
if isempty(projectDirOverride) && ~isfolder(projectDir) && ...
        isfield(project, 'paths') && isstruct(project.paths) && ...
        isfield(project.paths, 'projectDir')
    % The manifest location is authoritative for portable relative paths.
    % Fall back to its historical absolute projectDir only when the sibling
    % project folder is genuinely absent and the stored location exists.
    storedProjectDir = localResolveProjectPath( ...
        localFieldText(project.paths, 'projectDir', ''), jsonFolder);
    if isfolder(storedProjectDir)
        projectDir = storedProjectDir;
    end
end

if isfield(project, 'runProfilesPath') && ~isempty(project.runProfilesPath)
    localReportProgress(progressCallback, 0.05, 'Loading project run profiles...', 'metadata');
    profilePath = localResolveProjectPath(project.runProfilesPath, projectDir);
    if ~isfile(profilePath)
        error('shallowProjectImportLight:MissingMetadata', ...
            'Project run profiles file is missing: %s', profilePath);
    end
    shallowObj.runProfiles = jsondecode(fileread(profilePath));
    localReportProgress(progressCallback, 0.07, 'Run profiles loaded.', 'metadata');
end

fovItems = localResolveFovItems(project, projectDir, progressCallback, 0.08, 0.18);
localReportProgress(progressCallback, 0.18, 'Reconstructing FOV and ROI objects...', 'reconstruction');
shallowObj.fov = localBuildFovs(fovItems, shallowObj, projectDir, progressCallback, 0.18, 0.68);
shallowObj.processing = struct('roi', [], 'classification', [], ...
    'processor', process.empty, 'pipelineRun', pipelineRun.empty);

localReportProgress(progressCallback, 0.69, 'Loading classifier objects...', 'classifiers');
try
    shallowObj.processing.classification = localLoadClassifiers(project, projectDir);
catch ME
    warning('shallowProjectImportLight:ClassifierLoadFailed', '%s', ME.message);
    shallowObj.processing.classification = classi.empty;
end

localReportProgress(progressCallback, 0.77, 'Loading processor objects...', 'processors');
try
    shallowObj.processing.processor = localLoadProcessors(project, projectDir);
catch ME
    warning('shallowProjectImportLight:ProcessorLoadFailed', '%s', ME.message);
    shallowObj.processing.processor = process.empty;
end

localReportProgress(progressCallback, 0.85, 'Loading pipeline run records...', 'pipelineRuns');
try
    shallowObj.processing.pipelineRun = localLoadPipelineRuns(project, projectDir);
catch ME
    warning('shallowProjectImportLight:PipelineRunLoadFailed', '%s', ME.message);
    shallowObj.processing.pipelineRun = pipelineRun.empty;
end

localReportProgress(progressCallback, 0.92, 'Finalizing project reconstruction...', 'finalizing');
msg = ['Successfully loaded lightweight shallow project ' jsonPath '!'];
disp(msg);
localReportProgress(progressCallback, 0.93, 'Project data reconstructed.', 'complete');
end

function items = localResolveFovItems(project, projectDir, progressCallback, progressStart, progressEnd)
items = [];
if ~isfield(project, 'fovs') || isempty(project.fovs)
    localReportProgress(progressCallback, progressEnd, 'No FOV metadata to load.', 'fovMetadata');
    return;
end
items = project.fovs;
if ~isfield(items, 'metadataPath')
    localReportProgress(progressCallback, progressEnd, 'FOV metadata is embedded in the project JSON.', 'fovMetadata');
    return; % Legacy v2 manifests contain full FOV metadata inline.
end
details = cell(numel(items), 1);
for i = 1:numel(items)
    fovId = localFieldText(items(i), 'id', '');
    localReportProgress(progressCallback, progressStart + (progressEnd - progressStart) * (i - 1) / numel(items), ...
        sprintf('Loading FOV metadata %d/%d: %s', i, numel(items), fovId), 'fovMetadata');
    detailPath = localResolveProjectPath(items(i).metadataPath, projectDir);
    if ~isfile(detailPath)
        error('shallowProjectImportLight:MissingMetadata', ...
            'FOV metadata file is missing: %s', detailPath);
    end
    details{i} = jsondecode(fileread(detailPath));
    localReportProgress(progressCallback, progressStart + (progressEnd - progressStart) * i / numel(items), ...
        sprintf('Loaded FOV metadata %d/%d: %s', i, numel(items), fovId), 'fovMetadata');
end
items = vertcat(details{:});
end

function fovs = localBuildFovs(items, shallowObj, projectDir, progressCallback, progressStart, progressEnd)
fovs = fov.empty;
if isempty(items)
    localReportProgress(progressCallback, progressEnd, 'No FOVs to reconstruct.', 'reconstruction');
    return;
end
for i = 1:numel(items)
    item = items(i);
    fovId = localFieldText(item, 'id', '');
    fovStart = progressStart + (progressEnd - progressStart) * (i - 1) / numel(items);
    fovEnd = progressStart + (progressEnd - progressStart) * i / numel(items);
    localReportProgress(progressCallback, fovStart, ...
        sprintf('Reconstructing FOV %d/%d: %s', i, numel(items), fovId), 'reconstruction');
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
    roiStart = fovStart + 0.25 * (fovEnd - fovStart);
    localReportProgress(progressCallback, roiStart, ...
        sprintf('Reconstructing ROI objects for FOV %d/%d: %s', i, numel(items), fovId), 'rois');
    f.roi = localBuildRois(item, f, projectDir, progressCallback, roiStart, fovEnd, i, numel(items), fovId);
    fovs(end + 1) = f; %#ok<AGROW>
    localReportProgress(progressCallback, fovEnd, ...
        sprintf('Reconstructed FOV %d/%d: %s (%d ROI)', i, numel(items), fovId, numel(f.roi)), 'reconstruction');
end
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

function rois = localBuildRois(fovItem, fovObj, projectDir, progressCallback, progressStart, progressEnd, fovIndex, fovCount, fovId)
rois = roi.empty;
if ~isfield(fovItem, 'rois') || isempty(fovItem.rois)
    localReportProgress(progressCallback, progressEnd, ...
        sprintf('FOV %d/%d: no ROIs to reconstruct.', fovIndex, fovCount), 'rois');
    return;
end

items = fovItem.rois;
for i = 1:numel(items)
    item = items(i);
    localReportProgress(progressCallback, progressStart + (progressEnd - progressStart) * (i - 1) / numel(items), ...
        sprintf('Reconstructing FOV %d/%d (%s), ROI %d/%d', fovIndex, fovCount, fovId, i, numel(items)), 'rois');
    r = roi(localFieldText(item, 'id', ''), localFieldValue(item, 'value', []));
    r.parent = fovObj;
    r.path = localResolveRoiPath(localFieldText(item, 'path', ''), projectDir, fovObj.id);
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
    localReportProgress(progressCallback, progressStart + (progressEnd - progressStart) * i / numel(items), ...
        sprintf('Reconstructed FOV %d/%d (%s), ROI %d/%d', fovIndex, fovCount, fovId, i, numel(items)), 'rois');
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
% Relative paths in manifests may have been written on Windows. On Linux,
% backslashes are ordinary filename characters, so normalize both forms
% before joining them to the project directory.
if ~localIsAbsolute(pathOut)
    pathOut = strrep(pathOut, '\', filesep);
    pathOut = strrep(pathOut, '/', filesep);
end
if isfolder(pathOut) || isfile(pathOut) || localIsAbsolute(pathOut)
    return;
end
pathOut = fullfile(baseDir, pathOut);
end

function pathOut = localResolveRoiPath(pathText, projectDir, fovId)
% Resolve normal relative ROI paths and repair manifests produced by the
% historical Windows setPath bug (data\...\Project\FOV).
pathText = char(string(pathText));
fovId = char(string(fovId));
pathOut = localResolveProjectPath(pathText, projectDir);
if isempty(pathText) || isempty(projectDir) || isempty(fovId)
    return;
end

[~, projectName] = fileparts(regexprep(char(string(projectDir)), '[\\/]+$', ''));
parts = regexp(regexprep(pathText, '^[A-Za-z]:', ''), '[\\/]+', 'split');
parts = parts(~cellfun('isempty', parts));
projectIdx = find(strcmpi(parts, projectName), 1, 'last');
if ~isempty(projectIdx) && projectIdx < numel(parts)
    suffix = parts(projectIdx+1:end);
    if strcmpi(suffix{1}, fovId)
        pathOut = fullfile(projectDir, suffix{:});
        return;
    end
end

% ROI storage generated by the standard extractor is one directory per
% FOV.  Prefer that deterministic location when an old relative value is
% broken and the expected folder exists.
expected = fullfile(projectDir, fovId);
if ~localIsAbsolute(pathText) && ~isfolder(pathOut) && isfolder(expected)
    pathOut = expected;
end
end

function tf = localIsAbsolute(pathText)
pathText = char(string(pathText));
tf = ~isempty(regexp(pathText, '^[A-Za-z]:[\\/]', 'once')) || startsWith(pathText, '/') || startsWith(pathText, '\\');
end

function localReportProgress(progressCallback, fraction, message, stage)
if isempty(progressCallback)
    return;
end
payload = struct( ...
    'fraction', min(1, max(0, double(fraction))), ...
    'message', char(string(message)), ...
    'stage', char(string(stage)));
progressCallback(payload);
end
