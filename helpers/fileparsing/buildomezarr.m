function output = buildomezarr(omezarrDirs, outputin, progress)
% buildomezarr
% Build DetecDiv positions from local OME-Zarr datasets.
%
% Supports the pymmcore-gui layouts seen so far:
%   - OME-Zarr v0.5 / Zarr v3 with root zarr.json and series groups.
%   - OME-Zarr v0.4 / Zarr v2 with .zattrs/.zarray arrays at Pos*.
%
% The parser reads only JSON metadata; image chunks are read lazily by
% @fov/readImage.

output = outputin;

if ischar(omezarrDirs) || isstring(omezarrDirs)
    omezarrDirs = {char(string(omezarrDirs))};
end

if isempty(omezarrDirs)
    output.comments = [output.comments 'No OME-Zarr dataset found.' char(10)];
    return;
end

output.pos = localEnsureFields(output.pos);
templatePos = output.pos(1);

outPos = templatePos;
cc = 0;

for d = 1:numel(omezarrDirs)
    zarrPath = char(string(omezarrDirs{d}));
    if ~isfolder(zarrPath)
        continue;
    end

    info = ['Processing OME-Zarr dataset: ' zarrPath];
    disp(info);
    if ~isempty(progress)
        progress.Message = info;
        progress.Value = min(1, 0.33 + 0.33*(d-1)/max(1,numel(omezarrDirs)));
    end

    if exist(fullfile(zarrPath, 'zarr.json'), 'file') == 2
        [outPos, cc] = localBuildZarrV3(zarrPath, templatePos, outPos, cc);
    elseif exist(fullfile(zarrPath, '.zattrs'), 'file') == 2 && ...
            exist(fullfile(zarrPath, '.zgroup'), 'file') == 2
        [outPos, cc] = localBuildZarrV2(zarrPath, templatePos, outPos, cc);
    end
end

if cc > 0
    output.pos = outPos;
else
    output.pos = templatePos;
end

output.comments = [output.comments num2str(cc) ' OME-Zarr position(s) detected' char(10)];
end

function [outPos, cc] = localBuildZarrV3(zarrPath, templatePos, outPos, cc)
rootJson = localReadJson(fullfile(zarrPath, 'zarr.json'));
seriesNames = localGetV3SeriesNames(rootJson, zarrPath);
[~, zarrName] = fileparts(zarrPath);

for s = 1:numel(seriesNames)
    seriesName = char(seriesNames{s});
    seriesPath = fullfile(zarrPath, seriesName);
    seriesJsonPath = fullfile(seriesPath, 'zarr.json');
    if exist(seriesJsonPath, 'file') ~= 2
        continue;
    end

    seriesJson = localReadJson(seriesJsonPath);
    arrayPath = localGetV3FirstArrayPath(seriesJson, seriesPath);
    arrayJsonPath = fullfile(seriesPath, arrayPath, 'zarr.json');
    if exist(arrayJsonPath, 'file') ~= 2
        continue;
    end

    arrayJson = localReadJson(arrayJsonPath);
    shape = double(arrayJson.shape(:))';
    chunks = double(arrayJson.chunk_grid.configuration.chunk_shape(:))';
    dimNames = localGetV3DimNames(arrayJson);
    tDim = localFindDim(dimNames, 't', 1);
    cDim = localFindDim(dimNames, 'c', 2);

    if numel(shape) < 4 || isempty(tDim) || isempty(cDim)
        warning('Unsupported OME-Zarr array dimensions in %s', arrayJsonPath);
        continue;
    end

    nFrames = shape(tDim);
    nCh = shape(cDim);
    channelNames = localGetV3ChannelNames(seriesJson, nCh);
    channelIndices = 0:(nCh-1);
    zIndices = zeros(1, nCh);

    cc = cc + 1;
    pos = localMakePos(templatePos, zarrPath, zarrName, seriesName, arrayPath, ...
        shape, chunks, char(string(arrayJson.data_type)), dimNames, channelNames, ...
        channelIndices, zIndices, nFrames, fileread(seriesJsonPath));

    if cc == 1
        outPos = pos;
    else
        outPos(cc) = pos;
    end
end
end

function [outPos, cc] = localBuildZarrV2(zarrPath, templatePos, outPos, cc)
rootAttrsPath = fullfile(zarrPath, '.zattrs');
rootAttrs = localReadJson(rootAttrsPath);
seriesNames = localGetV2SeriesNames(rootAttrs, zarrPath);
[~, zarrName] = fileparts(zarrPath);

for s = 1:numel(seriesNames)
    seriesName = char(seriesNames{s});
    arrayPath = '';
    arrayDir = fullfile(zarrPath, seriesName);
    arrayJsonPath = fullfile(arrayDir, '.zarray');
    arrayAttrsPath = fullfile(arrayDir, '.zattrs');
    if exist(arrayJsonPath, 'file') ~= 2
        continue;
    end

    arrayJson = localReadJson(arrayJsonPath);
    if exist(arrayAttrsPath, 'file') == 2
        arrayAttrs = localReadJson(arrayAttrsPath);
    else
        arrayAttrs = struct();
    end

    shape = double(arrayJson.shape(:))';
    chunks = double(arrayJson.chunks(:))';
    dimNames = localGetV2DimNames(arrayAttrs, rootAttrs);
    if isempty(dimNames)
        dimNames = {'t','c','z','y','x'};
    end

    tDim = localFindDim(dimNames, 't', 1);
    cDim = localFindDim(dimNames, 'c', 2);
    zDim = localFindDim(dimNames, 'z', 3);
    if isempty(tDim) || isempty(cDim) || numel(shape) < max([tDim cDim])
        warning('Unsupported OME-Zarr v2 array dimensions in %s', arrayJsonPath);
        continue;
    end

    nFrames = shape(tDim);
    nC = shape(cDim);
    if isempty(zDim) || zDim > numel(shape)
        nZ = 1;
    else
        nZ = shape(zDim);
    end

    [channelIndices, zIndices, channelNames] = localGetV2ChannelZMap(arrayAttrs, nC, nZ);
    metadataText = sprintf('OME-Zarr v2 array: %s\nshape: %s\nchunks: %s', ...
        seriesName, mat2str(shape), mat2str(chunks));

    cc = cc + 1;
    pos = localMakePos(templatePos, zarrPath, zarrName, seriesName, arrayPath, ...
        shape, chunks, char(string(arrayJson.dtype)), dimNames, channelNames, ...
        channelIndices, zIndices, nFrames, metadataText);

    if cc == 1
        outPos = pos;
    else
        outPos(cc) = pos;
    end
end
end

function pos = localMakePos(templatePos, zarrPath, zarrName, seriesName, arrayPath, ...
    shape, chunks, dtype, dimNames, channelNames, channelIndices, zIndices, nFrames, metadataText)

nCh = numel(channelNames);
entries = repmat(struct('name', sprintf('omezarr_%s_%s', seriesName, arrayPath), 'folder', zarrPath), 1, nFrames);

pos = templatePos;
pos.name = sprintf('%s_%s', zarrName, seriesName);
pos.channels = nCh;
pos.frames = repmat(nFrames, 1, nCh);
pos.filelist = cell(1, nCh);
pos.pathlist = repmat({zarrPath}, 1, nCh);
for c = 1:nCh
    pos.filelist{c} = entries;
end
pos.unfilteredpathlist = pos.pathlist;
pos.unfilteredfilelist = pos.filelist;
pos.binning = ones(1, nCh);
pos.interval = ones(1, nCh);
pos.channelname = channelNames;
pos.channelfilter = {''};
pos.stackfilter = {''};
pos.positionfilter2 = {};
pos.channelfilter2 = {};
pos.stackfilter2 = {};

pos.isOMEZarr = true;
pos.omeZarrPath = zarrPath;
pos.omeZarrSeries = seriesName;
pos.omeZarrArrayPath = arrayPath;
pos.omeZarrShape = shape;
pos.omeZarrChunkShape = chunks;
pos.omeZarrDtype = dtype;
pos.omeZarrDimensionNames = dimNames;
pos.omeZarrChannelIndices = channelIndices;
pos.omeZarrZIndices = zIndices;
pos.metadataText = metadataText;
end

function pos = localEnsureFields(pos)
if isempty(pos)
    pos = struct();
end
fields = {
    'isOMEZarr', false
    'omeZarrPath', ''
    'omeZarrSeries', ''
    'omeZarrArrayPath', '0'
    'omeZarrShape', []
    'omeZarrChunkShape', []
    'omeZarrDtype', ''
    'omeZarrDimensionNames', {}
    'omeZarrChannelIndices', []
    'omeZarrZIndices', []
    'metadataText', ''
    'filelist', {}
    'pathlist', {}
    'unfilteredfilelist', {}
    'unfilteredpathlist', {}
    'channelname', {}
    'channels', []
    'frames', []
    'binning', []
    'interval', []
    'channelfilter', {''}
    'stackfilter', {''}
    'positionfilter2', {}
    'channelfilter2', {}
    'stackfilter2', {}
    'name', ''
};
for i = 1:size(fields,1)
    fn = fields{i,1};
    dv = fields{i,2};
    if ~isfield(pos, fn)
        [pos.(fn)] = deal(dv);
    end
end
end

function S = localReadJson(pathStr)
S = jsondecode(fileread(pathStr));
end

function names = localGetV3SeriesNames(rootJson, zarrPath)
names = {};
try
    if isfield(rootJson, 'attributes') && isfield(rootJson.attributes, 'ome') && ...
            isfield(rootJson.attributes.ome, 'series') && ~isempty(rootJson.attributes.ome.series)
        names = cellstr(string(rootJson.attributes.ome.series));
    end
catch
    names = {};
end
if isempty(names)
    dd = dir(zarrPath);
    dd = dd([dd.isdir]);
    dd = dd(~ismember({dd.name}, {'.','..','OME'}));
    for i = 1:numel(dd)
        if exist(fullfile(dd(i).folder, dd(i).name, 'zarr.json'), 'file') == 2
            names{end+1} = dd(i).name; %#ok<AGROW>
        end
    end
end
end

function names = localGetV2SeriesNames(rootAttrs, zarrPath)
names = {};
try
    ms = rootAttrs.multiscales;
    for i = 1:numel(ms)
        ds = ms(i).datasets;
        if isstruct(ds) && isfield(ds, 'path') && ~isempty(ds(1).path)
            names{end+1} = char(string(ds(1).path)); %#ok<AGROW>
        elseif isfield(ms(i), 'name') && ~isempty(ms(i).name)
            names{end+1} = char(string(ms(i).name)); %#ok<AGROW>
        end
    end
catch
    names = {};
end
if isempty(names)
    dd = dir(zarrPath);
    dd = dd([dd.isdir]);
    dd = dd(~ismember({dd.name}, {'.','..'}));
    for i = 1:numel(dd)
        if exist(fullfile(dd(i).folder, dd(i).name, '.zarray'), 'file') == 2
            names{end+1} = dd(i).name; %#ok<AGROW>
        end
    end
end
names = unique(names, 'stable');
end

function arrayPath = localGetV3FirstArrayPath(seriesJson, seriesPath)
arrayPath = '0';
try
    ms = seriesJson.attributes.ome.multiscales;
    if isstruct(ms)
        ds = ms(1).datasets;
        if isstruct(ds) && isfield(ds, 'path') && ~isempty(ds(1).path)
            arrayPath = char(string(ds(1).path));
        end
    end
catch
end
if exist(fullfile(seriesPath, arrayPath, 'zarr.json'), 'file') ~= 2
    dd = dir(seriesPath);
    dd = dd([dd.isdir]);
    dd = dd(~ismember({dd.name}, {'.','..'}));
    for i = 1:numel(dd)
        if exist(fullfile(dd(i).folder, dd(i).name, 'zarr.json'), 'file') == 2
            arrayPath = dd(i).name;
            return;
        end
    end
end
end

function dimNames = localGetV3DimNames(arrayJson)
dimNames = {};
if isfield(arrayJson, 'dimension_names') && ~isempty(arrayJson.dimension_names)
    dimNames = cellstr(string(arrayJson.dimension_names));
end
end

function dimNames = localGetV2DimNames(arrayAttrs, rootAttrs)
dimNames = localGetJsonField(arrayAttrs, '_ARRAY_DIMENSIONS', {});
if isempty(dimNames)
    try
        axes = rootAttrs.multiscales(1).axes;
        dimNames = cell(1, numel(axes));
        for i = 1:numel(axes)
            dimNames{i} = char(string(axes(i).name));
        end
    catch
        dimNames = {};
    end
end
if ~isempty(dimNames)
    dimNames = cellstr(string(dimNames));
end
end

function idx = localFindDim(dimNames, name, fallback)
idx = find(strcmpi(dimNames, name), 1, 'first');
if isempty(idx) && nargin >= 3
    idx = fallback;
end
end

function names = localGetV3ChannelNames(seriesJson, nCh)
names = {};
try
    ch = seriesJson.attributes.ome.omero.channels;
    for i = 1:min(numel(ch), nCh)
        names{i} = char(string(ch(i).label)); %#ok<AGROW>
    end
catch
    names = {};
end
if numel(names) ~= nCh
    names = arrayfun(@(i)sprintf('ch%d', i), 1:nCh, 'UniformOutput', false);
end
end

function [channelIndices, zIndices, names] = localGetV2ChannelZMap(arrayAttrs, nC, nZ)
pairs = [];
baseNames = arrayfun(@(i)sprintf('ch%d', i), 1:nC, 'UniformOutput', false);

try
    seq = localGetJsonField(arrayAttrs, 'useq_MDASequence', struct());
    if isstruct(seq) && isfield(seq, 'channels')
        for i = 1:min(numel(seq.channels), nC)
            if isfield(seq.channels(i), 'config') && ~isempty(seq.channels(i).config)
                baseNames{i} = char(strtrim(string(seq.channels(i).config)));
            end
        end
    end
catch
end

try
    fm = arrayAttrs.frame_meta;
    for i = 1:numel(fm)
        idx = fm(i).mda_event.index;
        c = double(idx.c);
        z = 0;
        if isfield(idx, 'z')
            z = double(idx.z);
        end
        if c >= 0 && c < nC && z >= 0 && z < nZ
            pairs(end+1,:) = [c z]; %#ok<AGROW>
        end
        try
            cfg = strtrim(char(string(fm(i).mda_event.channel.config)));
            if ~isempty(cfg) && c >= 0 && c < nC
                baseNames{c+1} = cfg;
            end
        catch
        end
    end
catch
end

if isempty(pairs)
    [cc, zz] = ndgrid(0:(nC-1), 0:(nZ-1));
    pairs = [cc(:) zz(:)];
else
    pairs = unique(pairs, 'rows', 'stable');
end

channelIndices = pairs(:,1)';
zIndices = pairs(:,2)';
names = cell(1, size(pairs,1));
appendZ = nZ > 1;
for i = 1:size(pairs,1)
    base = baseNames{pairs(i,1)+1};
    if appendZ
        names{i} = sprintf('%s_z%d', base, pairs(i,2)+1);
    else
        names{i} = base;
    end
end
end

function val = localGetJsonField(S, rawName, defaultVal)
val = defaultVal;
if ~isstruct(S)
    return;
end
candidates = {rawName, matlab.lang.makeValidName(rawName), ['x' rawName]};
fn = fieldnames(S);
for i = 1:numel(candidates)
    hit = strcmp(fn, candidates{i});
    if any(hit)
        val = S.(fn{find(hit, 1, 'first')});
        return;
    end
end
end
