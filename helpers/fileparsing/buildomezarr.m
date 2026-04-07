function output = buildomezarr(omezarrDirs, outputin, progress)
% buildomezarr
% Build DetecDiv positions from local OME-Zarr v0.5 / Zarr v3 datasets.
%
% Current support targets pymmcore-gui OME-Zarr stores with series folders
% at the root (e.g. 0, 1) and arrays shaped T-C-Y-X. The parser reads only
% JSON metadata; image chunks are read lazily by @fov/readImage.

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
    if ~isfolder(zarrPath) || exist(fullfile(zarrPath, 'zarr.json'), 'file') ~= 2
        continue;
    end

    info = ['Processing OME-Zarr dataset: ' zarrPath];
    disp(info);
    if ~isempty(progress)
        progress.Message = info;
        progress.Value = min(1, 0.33 + 0.33*(d-1)/max(1,numel(omezarrDirs)));
    end

    rootJson = localReadJson(fullfile(zarrPath, 'zarr.json'));
    seriesNames = localGetSeriesNames(rootJson, zarrPath);
    [~, zarrName] = fileparts(zarrPath);

    for s = 1:numel(seriesNames)
        seriesName = char(seriesNames{s});
        seriesPath = fullfile(zarrPath, seriesName);
        seriesJsonPath = fullfile(seriesPath, 'zarr.json');
        if exist(seriesJsonPath, 'file') ~= 2
            continue;
        end

        seriesJson = localReadJson(seriesJsonPath);
        arrayPath = localGetFirstArrayPath(seriesJson, seriesPath);
        arrayJsonPath = fullfile(seriesPath, arrayPath, 'zarr.json');
        if exist(arrayJsonPath, 'file') ~= 2
            continue;
        end

        arrayJson = localReadJson(arrayJsonPath);
        shape = double(arrayJson.shape(:))';
        chunks = double(arrayJson.chunk_grid.configuration.chunk_shape(:))';
        dimNames = localGetDimNames(arrayJson);
        tDim = localFindDim(dimNames, 't', 1);
        cDim = localFindDim(dimNames, 'c', 2);

        if numel(shape) < 4 || isempty(tDim) || isempty(cDim)
            warning('Unsupported OME-Zarr array dimensions in %s', arrayJsonPath);
            continue;
        end

        nFrames = shape(tDim);
        nCh = shape(cDim);
        channelNames = localGetChannelNames(seriesJson, nCh);
        entries = repmat(struct('name', sprintf('omezarr_%s_%s', seriesName, arrayPath), 'folder', zarrPath), 1, nFrames);

        cc = cc + 1;
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
        pos.omeZarrDtype = char(string(arrayJson.data_type));
        pos.omeZarrDimensionNames = dimNames;
        pos.omeZarrChannelIndices = 0:(nCh-1);
        pos.metadataText = fileread(seriesJsonPath);

        if cc == 1
            outPos = pos;
        else
            outPos(cc) = pos; %#ok<AGROW>
        end
    end
end

if cc > 0
    output.pos = outPos;
else
    output.pos = templatePos;
end

output.comments = [output.comments num2str(cc) ' OME-Zarr position(s) detected' char(10)];
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
        [pos.(fn)] = deal(dv); %#ok<AGROW>
    end
end
end

function S = localReadJson(pathStr)
S = jsondecode(fileread(pathStr));
end

function names = localGetSeriesNames(rootJson, zarrPath)
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

function arrayPath = localGetFirstArrayPath(seriesJson, seriesPath)
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

function dimNames = localGetDimNames(arrayJson)
dimNames = {};
if isfield(arrayJson, 'dimension_names') && ~isempty(arrayJson.dimension_names)
    dimNames = cellstr(string(arrayJson.dimension_names));
end
end

function idx = localFindDim(dimNames, name, fallback)
idx = find(strcmpi(dimNames, name), 1, 'first');
if isempty(idx) && nargin >= 3
    idx = fallback;
end
end

function names = localGetChannelNames(seriesJson, nCh)
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
