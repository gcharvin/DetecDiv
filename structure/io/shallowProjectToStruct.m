function project = shallowProjectToStruct(shallowObj)
%SHALLOWPROJECTTOSTRUCT Build a lightweight JSON-safe project manifest.
%   The manifest is a reconstruction description, not a MATLAB object dump.

if nargin < 1 || isempty(shallowObj) || ~isa(shallowObj, 'shallow')
    error('shallowProjectToStruct:InvalidProject', 'A shallow project object is required.');
end

[projectPath, projectFile] = shallowObj.getPath();
projectPath = char(string(projectPath));
projectFile = char(string(projectFile));

project = struct();
project.schemaVersion = 2;
project.projectId = localEnsureProjectId(shallowObj);
project.projectName = projectFile;
project.tag = localText(localGetProp(shallowObj, 'tag', ''));
project.createdAt = '';
project.updatedAt = localNowText();
project.detecdivVersion = '';
project.paths = struct( ...
    'projectRoot', projectPath, ...
    'projectDir', fullfile(projectPath, projectFile), ...
    'legacyMat', fullfile(projectPath, [projectFile '.mat']));
project.rawSources = localCollectRawSources(shallowObj);
project.fovs = localFovsToStruct(shallowObj, project.paths.projectDir);
project.pipelines = localPipelineRefs(shallowObj, project.paths.projectDir);
project.pipelineRuns = localPipelineRunRefs(shallowObj, project.paths.projectDir);
project.classifiers = localChildRefs(fullfile(project.paths.projectDir, 'classification'), project.paths.projectDir, 'classification');
project.processors = localChildRefs(fullfile(project.paths.projectDir, 'processor'), project.paths.projectDir, 'processor');
project.runProfiles = localSanitizeValue(localGetProp(shallowObj, 'runProfiles', struct()));
project.compat = struct( ...
    'legacyClass', 'shallow', ...
    'legacyMatVariable', 'shallowObj', ...
    'notes', 'Lightweight manifest; heavy ROI/classifier/processor/run data live in external files.');
end

function id = localEnsureProjectId(shallowObj)
id = '';
try
    if isprop(shallowObj, 'projectId')
        id = char(string(shallowObj.projectId));
    end
catch
    id = '';
end
if isempty(strtrim(id))
    id = char(java.util.UUID.randomUUID);
    try
        shallowObj.projectId = id;
    catch
    end
end
end

function out = localFovsToStruct(shallowObj, projectDir)
out = repmat(localEmptyFov(), 0, 1);
try
    fovs = shallowObj.fov;
catch
    return;
end

for i = 1:numel(fovs)
    f = fovs(i);
    entry = localEmptyFov();
    entry.index = i;
    entry.id = localText(localGetProp(f, 'id', ''));
    entry.number = localSanitizeValue(localGetProp(f, 'number', i));
    entry.tag = localText(localGetProp(f, 'tag', ''));
    entry.comments = localText(localGetProp(f, 'comments', ''));
    entry.srcpath = localSanitizeValue(localGetProp(f, 'srcpath', {}));
    entry.channel = localSanitizeValue(localGetProp(f, 'channel', {}));
    entry.frames = localSanitizeValue(localGetProp(f, 'frames', []));
    entry.interval = localSanitizeValue(localGetProp(f, 'interval', []));
    entry.binning = localSanitizeValue(localGetProp(f, 'binning', []));
    entry.orientation = localSanitizeValue(localGetProp(f, 'orientation', 0));
    entry.crop = localSanitizeValue(localGetProp(f, 'crop', []));
    entry.pattern = localSanitizeValue(localCompactPossiblyLarge(localGetProp(f, 'pattern', []), 10000));
    entry.drift = localSanitizeValue(localGetProp(f, 'drift', []));
    entry.display = localSanitizeValue(localGetProp(f, 'display', struct()));
    entry.raw = localFovRawStruct(f);
    entry.rois = localRoisToStruct(localGetProp(f, 'roi', roi.empty), projectDir);
    out(end + 1) = entry; %#ok<AGROW>
end
end

function entry = localEmptyFov()
entry = struct( ...
    'index', [], ...
    'id', '', ...
    'number', [], ...
    'tag', '', ...
    'comments', '', ...
    'srcpath', {{}}, ...
    'channel', {{}}, ...
    'frames', [], ...
    'interval', [], ...
    'binning', [], ...
    'orientation', [], ...
    'crop', [], ...
    'pattern', [], ...
    'drift', [], ...
    'display', struct(), ...
    'raw', struct(), ...
    'rois', repmat(localEmptyRoi(), 0, 1));
end

function raw = localFovRawStruct(f)
raw = struct();
names = {'isMultiTiff','tiffSource','pageMap','isStackSeries','stackPageMap', ...
    'isNDTiff','ndtiffPath','ndtiffPosition','ndtiffChannels','ndtiffZ', ...
    'isOMEZarr','omeZarrPath','omeZarrSeries','omeZarrArrayPath', ...
    'omeZarrShape','omeZarrChunkShape','omeZarrDtype','omeZarrDimensionNames', ...
    'omeZarrChannelIndices','omeZarrZIndices'};
for i = 1:numel(names)
    raw.(names{i}) = localSanitizeValue(localGetProp(f, names{i}, []));
end

% Full srclist can dominate project size. Persist a compact summary only.
srclist = localGetProp(f, 'srclist', {});
raw.srclistSummary = localSrclistSummary(srclist);
end

function summary = localSrclistSummary(srclist)
summary = struct('channelCount', 0, 'frameCounts', [], 'firstNames', {{}}, 'lastNames', {{}});
if ~iscell(srclist)
    return;
end
summary.channelCount = numel(srclist);
summary.frameCounts = zeros(1, numel(srclist));
summary.firstNames = cell(1, numel(srclist));
summary.lastNames = cell(1, numel(srclist));
for ch = 1:numel(srclist)
    items = srclist{ch};
    try
        summary.frameCounts(ch) = numel(items);
        if ~isempty(items) && isstruct(items) && isfield(items, 'name')
            summary.firstNames{ch} = char(string(items(1).name));
            summary.lastNames{ch} = char(string(items(end).name));
        else
            summary.firstNames{ch} = '';
            summary.lastNames{ch} = '';
        end
    catch
        summary.frameCounts(ch) = 0;
        summary.firstNames{ch} = '';
        summary.lastNames{ch} = '';
    end
end
end

function out = localRoisToStruct(rois, projectDir)
out = repmat(localEmptyRoi(), 0, 1);
for i = 1:numel(rois)
    r = rois(i);
    if isempty(localGetProp(r, 'id', '')) && isempty(localGetProp(r, 'value', []))
        continue;
    end
    entry = localEmptyRoi();
    entry.index = i;
    entry.id = localText(localGetProp(r, 'id', ''));
    entry.value = localSanitizeValue(localGetProp(r, 'value', []));
    entry.path = localRelPath(localText(localGetProp(r, 'path', '')), projectDir);
    entry.channelid = localSanitizeValue(localGetProp(r, 'channelid', []));
    entry.display = localSanitizeValue(localGetProp(r, 'display', struct()));
    entry.extraction = localSanitizeValue(localGetProp(r, 'extraction', struct()));
    entry.files = localRoiFiles(r, projectDir);
    out(end + 1) = entry; %#ok<AGROW>
end
end

function entry = localEmptyRoi()
entry = struct( ...
    'index', [], ...
    'id', '', ...
    'value', [], ...
    'path', '', ...
    'channelid', [], ...
    'display', struct(), ...
    'extraction', struct(), ...
    'files', struct('imageH5', '', 'dataMat', ''));
end

function files = localRoiFiles(r, projectDir)
files = struct('imageH5', '', 'dataMat', '');
roiPath = localText(localGetProp(r, 'path', ''));
roiId = localText(localGetProp(r, 'id', ''));
if isempty(roiPath) || isempty(roiId)
    return;
end
files.imageH5 = localRelPath(fullfile(roiPath, ['im_' roiId '.h5']), projectDir);
files.dataMat = localRelPath(fullfile(roiPath, ['data_' roiId '.mat']), projectDir);
end

function refs = localPipelineRefs(shallowObj, projectDir)
refs = struct('kind', {}, 'id', {}, 'path', {});
try
    rp = shallowObj.runProfiles;
    if isstruct(rp) && isfield(rp, 'pipeline') && isstruct(rp.pipeline)
        names = {'defaultTemplatePath', 'defaultTemplateId'};
        ref = struct('kind', 'defaultTemplate', 'id', '', 'path', '');
        if isfield(rp.pipeline, names{2})
            ref.id = localText(rp.pipeline.(names{2}));
        end
        if isfield(rp.pipeline, names{1})
            ref.path = localRelPath(localText(rp.pipeline.(names{1})), projectDir);
        end
        if ~isempty(ref.id) || ~isempty(ref.path)
            refs(end + 1) = ref;
        end
    end
catch
end
end

function refs = localPipelineRunRefs(shallowObj, projectDir)
refs = struct('runId', {}, 'path', {}, 'status', {}, 'pipelineId', {}, 'updatedAt', {});
try
    if ~isfield(shallowObj.processing, 'pipelineRun')
        return;
    end
    runs = shallowObj.processing.pipelineRun;
catch
    return;
end
for i = 1:numel(runs)
    runObj = runs(i);
    ref = struct('runId', '', 'path', '', 'status', '', 'pipelineId', '', 'updatedAt', '');
    ref.runId = localText(localGetProp(runObj, 'runId', ''));
    ref.path = localRelPath(localText(localGetProp(runObj, 'path', '')), projectDir);
    ref.status = localText(localGetProp(runObj, 'status', ''));
    ref.pipelineId = localText(localGetProp(runObj, 'pipelineId', ''));
    ref.updatedAt = localText(localGetProp(runObj, 'updatedAt', ''));
    if ~isempty(ref.runId) || ~isempty(ref.path)
        refs(end + 1) = ref; %#ok<AGROW>
    end
end
end

function refs = localChildRefs(rootDir, projectDir, kind)
refs = struct('kind', {}, 'id', {}, 'path', {});
if ~isfolder(rootDir)
    return;
end
d = dir(rootDir);
d = d([d.isdir]);
d = d(~ismember({d.name}, {'.', '..'}));
for i = 1:numel(d)
    refs(end + 1) = struct( ... %#ok<AGROW>
        'kind', kind, ...
        'id', d(i).name, ...
        'path', localRelPath(fullfile(d(i).folder, d(i).name), projectDir));
end
end

function sources = localCollectRawSources(shallowObj)
sources = struct('fovIndex', {}, 'channelIndex', {}, 'kind', {}, 'path', {}, 'exists', {});
try
    fovs = shallowObj.fov;
catch
    return;
end
for i = 1:numel(fovs)
    f = fovs(i);
    sources = localAppendPathSources(sources, i, 'srcpath', localGetProp(f, 'srcpath', {}));
    sources = localAppendPathSources(sources, i, 'tiffSource', localGetProp(f, 'tiffSource', {}));
    sources = localAppendPathSources(sources, i, 'ndtiffPath', {localGetProp(f, 'ndtiffPath', '')});
    sources = localAppendPathSources(sources, i, 'omeZarrPath', {localGetProp(f, 'omeZarrPath', '')});
end
end

function sources = localAppendPathSources(sources, fovIndex, kind, paths)
if ischar(paths) || isstring(paths)
    paths = {char(string(paths))};
end
if ~iscell(paths)
    return;
end
for ch = 1:numel(paths)
    p = localText(paths{ch});
    if isempty(p)
        continue;
    end
    sources(end + 1) = struct( ... %#ok<AGROW>
        'fovIndex', fovIndex, ...
        'channelIndex', ch, ...
        'kind', kind, ...
        'path', p, ...
        'exists', isfolder(p) || isfile(p));
end
end

function value = localGetProp(obj, name, defaultValue)
value = defaultValue;
try
    if isstruct(obj) && isfield(obj, name)
        value = obj.(name);
    elseif isobject(obj) && isprop(obj, name)
        value = obj.(name);
    end
catch
    value = defaultValue;
end
end

function value = localSanitizeValue(value)
if isempty(value)
    return;
end
if isstring(value)
    value = cellstr(value);
    if numel(value) == 1
        value = value{1};
    end
elseif ischar(value) || isnumeric(value) || islogical(value)
    return;
elseif iscell(value)
    for i = 1:numel(value)
        value{i} = localSanitizeValue(value{i});
    end
elseif isstruct(value)
    fields = fieldnames(value);
    for i = 1:numel(value)
        for j = 1:numel(fields)
            value(i).(fields{j}) = localSanitizeValue(value(i).(fields{j}));
        end
    end
elseif isa(value, 'datetime')
    value = char(value);
elseif istable(value)
    value = struct('tableSummary', sprintf('%d row(s), %d variable(s)', height(value), width(value)));
elseif isobject(value)
    value = struct('class', class(value), 'omitted', true);
else
    try
        value = char(string(value));
    catch
        value = [];
    end
end
end

function value = localCompactPossiblyLarge(value, maxElements)
if isnumeric(value) || islogical(value)
    if numel(value) > maxElements
        value = struct('class', class(value), 'size', size(value), 'omitted', true);
    end
end
end

function text = localText(value)
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
    text = '';
end
end

function rel = localRelPath(pathText, baseDir)
rel = localText(pathText);
if isempty(rel) || isempty(baseDir)
    return;
end
try
    absPath = char(java.io.File(rel).getCanonicalPath());
    absBase = char(java.io.File(baseDir).getCanonicalPath());
    if startsWith(lower(absPath), lower(absBase))
        relCandidate = extractAfter(absPath, strlength(absBase));
        relCandidate = regexprep(char(relCandidate), '^[\\/]+', '');
        if ~isempty(relCandidate)
            rel = relCandidate;
        end
    end
catch
end
end

function txt = localNowText()
try
    txt = char(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ss'));
catch
    txt = datestr(now, 30);
end
end
