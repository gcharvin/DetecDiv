function listout = listAvailableChannels(source, varargin)
% listAvailableChannels  Return available logical image channels cheaply.
%
% Backward compatible:
%   listAvailableChannels()
%
% Optional:
%   listAvailableChannels(shallowObj)
%   listAvailableChannels(roiObj)
%   listAvailableChannels(classiObj)
%   listAvailableChannels(...,'MaxRoiPerFov',1,'UseH5Fallback',true)
%
% The function intentionally avoids roi.load() and h5read(). When ROI display
% metadata is missing, it reads only HDF5 structure/attributes (h5info,
% h5readatt), which is enough to populate processor dropdowns.

optionNames = {'maxroiperfov','maxstandaloneroi','useh5fallback', ...
    'includeclassifiers','allowworkspacescan'};

if nargin < 1
    source = [];
elseif ischar(source) || isstring(source)
    firstArg = lower(char(source));
    if any(strcmp(firstArg, optionNames))
        varargin = [{source} varargin];
        source = [];
    end
end

opts.MaxRoiPerFov = 1;
opts.MaxStandaloneRoi = 10;
opts.UseH5Fallback = true;
opts.IncludeClassifiers = true;
opts.AllowWorkspaceScan = isempty(source);

i = 1;
while i <= numel(varargin)
    if ~(ischar(varargin{i}) || isstring(varargin{i}))
        i = i + 1;
        continue;
    end
    key = lower(char(varargin{i}));
    switch key
        case 'maxroiperfov'
            opts.MaxRoiPerFov = varargin{i+1};
            i = i + 2;
        case 'maxstandaloneroi'
            opts.MaxStandaloneRoi = varargin{i+1};
            i = i + 2;
        case 'useh5fallback'
            opts.UseH5Fallback = logical(varargin{i+1});
            i = i + 2;
        case 'includeclassifiers'
            opts.IncludeClassifiers = logical(varargin{i+1});
            i = i + 2;
        case 'allowworkspacescan'
            opts.AllowWorkspaceScan = logical(varargin{i+1});
            i = i + 2;
        otherwise
            i = i + 1;
    end
end

list = {};

if isa(source, 'shallow')
    list = collectFromProject(source, list, opts);
elseif isa(source, 'fov')
    list = collectFromFov(source, list, opts);
elseif isa(source, 'roi')
    list = collectFromRois(source, list, opts.MaxStandaloneRoi, opts);
elseif isa(source, 'classi')
    list = collectFromRois(source.roi, list, opts.MaxStandaloneRoi, opts);
elseif isstruct(source)
    list = collectFromStruct(source, list, opts);
end

if opts.AllowWorkspaceScan
    listproj = gatherVariablesFromWorkspace;

    for p = 1:numel(listproj.Project)
        proj = evalin('base', listproj.Project{p});
        list = collectFromProject(proj, list, opts);
    end

    if opts.IncludeClassifiers
        for c = 1:numel(listproj.Classifier)
            classifiers = evalin('base', listproj.Classifier{c});
            if isa(classifiers, 'classi')
                list = collectFromRois(classifiers.roi, list, opts.MaxStandaloneRoi, opts);
            end
        end
    end
end

listout = cleanChannelList(list);
if isempty(listout)
    listout = {'Channel1'};
end
end

function list = collectFromProject(proj, list, opts)
if ~isa(proj, 'shallow')
    return;
end

if isprop(proj, 'fov')
    for f = 1:numel(proj.fov)
        list = collectFromFov(proj.fov(f), list, opts);
    end
end

if opts.IncludeClassifiers && isprop(proj, 'processing') && ...
        isstruct(proj.processing) && isfield(proj.processing, 'classification')
    for c = 1:numel(proj.processing.classification)
        list = collectFromRois(proj.processing.classification(c).roi, list, opts.MaxStandaloneRoi, opts);
    end
end
end

function list = collectFromFov(fovObj, list, opts)
if ~isa(fovObj, 'fov')
    return;
end

if isprop(fovObj, 'channel') && ~isempty(fovObj.channel)
    list = appendChannels(list, fovObj.channel);
end

if isprop(fovObj, 'roi') && ~isempty(fovObj.roi)
    list = collectFromRois(fovObj.roi, list, opts.MaxRoiPerFov, opts);
end
end

function list = collectFromRois(roiobj, list, maxRoi, opts)
if isempty(roiobj) || ~isa(roiobj, 'roi')
    return;
end

n = min(numel(roiobj), max(0, maxRoi));
for r = 1:n
    names = getRoiDisplayChannels(roiobj(r));
    if ~hasUsableChannelNames(names) && opts.UseH5Fallback
        names = getRoiH5Channels(roiobj(r));
    end
    list = appendChannels(list, names);
end
end

function list = collectFromStruct(source, list, opts)
if isfield(source, 'shallow') && isa(source.shallow, 'shallow')
    list = collectFromProject(source.shallow, list, opts);
elseif isfield(source, 'shallowObj') && isa(source.shallowObj, 'shallow')
    list = collectFromProject(source.shallowObj, list, opts);
elseif isfield(source, 'roiList') && isa(source.roiList, 'roi')
    list = collectFromRois(source.roiList, list, opts.MaxStandaloneRoi, opts);
elseif isfield(source, 'channels')
    list = appendChannels(list, source.channels);
end
end

function names = getRoiDisplayChannels(r)
names = {};
try
    if isprop(r, 'display') && isstruct(r.display) && isfield(r.display, 'channel')
        names = r.display.channel;
    end
catch
    names = {};
end
end

function names = getRoiH5Channels(r)
names = {};

try
    [h5File, exists] = r.getH5Filename();
catch
    try
        h5File = fullfile(r.path, ['im_' r.id '.h5']);
        exists = isfile(h5File);
    catch
        exists = false;
    end
end

if ~exists
    return;
end

try
    info = h5info(h5File, '/');
catch
    return;
end

idxMin = nan(1, numel(info.Datasets));
tmpNames = cell(1, numel(info.Datasets));

for d = 1:numel(info.Datasets)
    dsPath = ['/' info.Datasets(d).Name];
    try
        tmpNames{d} = char(string(h5readatt(h5File, dsPath, 'channel_name')));
    catch
        tmpNames{d} = info.Datasets(d).Name;
    end

    try
        ci = double(h5readatt(h5File, dsPath, 'channel_indices'));
        idxMin(d) = min(ci(:));
    catch
        idxMin(d) = d;
    end
end

[~, ord] = sort(idxMin, 'ascend');
names = tmpNames(ord);
end

function list = appendChannels(list, names)
if isempty(names)
    return;
end

if ischar(names) || isstring(names)
    names = cellstr(string(names));
elseif ~iscell(names)
    return;
end

names = cellfun(@(x) char(string(x)), names(:).', 'UniformOutput', false);
list = [list names]; %#ok<AGROW>
end

function tf = hasUsableChannelNames(names)
tf = false;
if isempty(names)
    return;
end

if ischar(names) || isstring(names)
    names = cellstr(string(names));
elseif ~iscell(names)
    return;
end

for i = 1:numel(names)
    name = strtrim(char(string(names{i})));
    if isempty(name) || strcmp(name, ' ')
        continue;
    end
    tf = true;
    return;
end
end

function listout = cleanChannelList(list)
listout = {};
if isempty(list)
    return;
end

list = cellfun(@(x) char(string(x)), list(:).', 'UniformOutput', false);
list = list(~cellfun(@isempty, list));
list = unique(list, 'stable');

cc = 1;
for i = 1:numel(list)
    name = strtrim(list{i});
    if isempty(name) || strcmp(name, ' ')
        continue;
    end
    listout{cc} = name; %#ok<AGROW>
    cc = cc + 1;
end
end
