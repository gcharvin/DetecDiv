function output = buildstkseries(filelist, outputin, progress)
% buildstkseries  Parse one-stack-file-per-timepoint acquisitions.
%
% Example:
%   pn1_1_DIC_s1_t1.stk
%   pn1_1_DIC_s1_t2.stk
%
% The current FOV model exposes frame x channel planes, not a separate Z
% axis. For STK time series, each physical Z slice is therefore exposed as a
% DetecDiv virtual channel and each STK file is one timepoint.

output = outputin;

filelist = filelist([filelist.isdir] == 0);
if isempty(filelist)
    output.comments = [output.comments 'No STK files found.' char(10)];
    return;
end

[~, ~, exts] = cellfun(@fileparts, {filelist.name}, 'UniformOutput', false);
filelist = filelist(strcmpi(exts, '.stk'));
if isempty(filelist)
    output.comments = [output.comments 'No STK files found.' char(10)];
    return;
end

output.pos = localEnsureStackFields(output.pos);
templatePos = output.pos(1);

prefixes = cell(1, numel(filelist));
times = nan(1, numel(filelist));
for i = 1:numel(filelist)
    [~, stem, ~] = fileparts(filelist(i).name);
    tok = regexp(stem, '^(?<prefix>.+)_t(?<time>\d+)$', 'names', 'once');
    if isempty(tok)
        prefixes{i} = stem;
        times(i) = i;
    else
        prefixes{i} = tok.prefix;
        times(i) = str2double(tok.time);
    end
end

uniquePrefixes = unique(prefixes, 'stable');
outPos = templatePos;
outCount = 0;

for p = 1:numel(uniquePrefixes)
    currentPrefix = uniquePrefixes{p};
    idx = find(strcmp(prefixes, currentPrefix));
    [~, order] = sort(times(idx));
    idx = idx(order);
    files = filelist(idx);
    sortedTimes = times(idx);

    info = ['Processing STK series: ' num2str(p) '/' num2str(numel(uniquePrefixes))];
    disp(info);
    if ~isempty(progress)
        progress.Message = info;
        progress.Value = min(1, 0.67 + 0.33*(p-1)/max(1,numel(uniquePrefixes)));
    end
    detecdiv_check_cancel(progress, info);

    firstPath = fullfile(files(1).folder, files(1).name);
    try
        imInfo = imfinfo(firstPath);
    catch ME
        warning('buildstkseries:imfinfoFailed', ...
            'Could not inspect STK file "%s": %s', firstPath, ME.message);
        continue;
    end

    nZ = localDetectPlaneCount(imInfo, firstPath);
    nFrames = numel(files);
    channelBase = localChannelBaseFromPrefix(currentPrefix);

    pos = templatePos;
    pos.name = currentPrefix;
    pos.channels = nZ;
    pos.frames = repmat(nFrames, 1, nZ);
    pos.isStackSeries = true;
    pos.stackPageMap = cell(1, nZ);
    pos.filelist = cell(1, nZ);
    pos.pathlist = cell(1, nZ);
    pos.unfilteredfilelist = cell(1, nZ);
    pos.unfilteredpathlist = cell(1, nZ);
    pos.channelname = cell(1, nZ);
    pos.binning = ones(1, nZ);
    pos.interval = ones(1, nZ);
    pos.positionfilter2 = {};
    pos.channelfilter2 = {};
    pos.stackfilter2 = {'stk_pages'};
    pos.metadataText = localMetadataText(currentPrefix, firstPath, sortedTimes, nZ);

    for z = 1:nZ
        entries = files;
        pos.filelist{z} = entries;
        pos.unfilteredfilelist{z} = entries;
        pos.pathlist{z} = files(1).folder;
        pos.unfilteredpathlist{z} = files(1).folder;
        pos.stackPageMap{z} = repmat(z, 1, nFrames);
        pos.channelname{z} = sprintf('%s_Z%03d', channelBase, z);
    end

    outCount = outCount + 1;
    if outCount == 1
        outPos = pos;
    else
        outPos(outCount) = pos; %#ok<AGROW>
    end
end

function nZ = localDetectPlaneCount(imInfo, firstPath)
nZ = max(1, numel(imInfo));
if nZ > 1 || isempty(imInfo)
    return;
end

try
    desc = imInfo(1).ImageDescription;
    exposureCount = numel(strfind(desc, 'Exposure:'));
catch
    exposureCount = 0;
end

try
    bytesPerPixel = max(1, double(imInfo(1).BitDepth) / 8);
    bytesPerPlane = double(imInfo(1).Width) * double(imInfo(1).Height) * bytesPerPixel;
    d = dir(firstPath);
    if ~isempty(d) && bytesPerPlane > 0
        contiguousCount = floor((double(d.bytes) - 8) / bytesPerPlane);
    else
        contiguousCount = 0;
    end
catch
    contiguousCount = 0;
end

candidates = [exposureCount contiguousCount];
candidates = candidates(isfinite(candidates) & candidates > 1);
if ~isempty(candidates)
    nZ = round(max(candidates));
end
end

if outCount == 0
    output.pos = templatePos;
else
    output.pos = outPos;
end

output.comments = [output.comments num2str(numel(output.pos)) ' STK series position(s) were identified' char(10)];
end

function pos = localEnsureStackFields(pos)
if isempty(pos)
    pos = struct();
end

required = {
    'isStackSeries', false
    'stackPageMap',  {}
    'metadataText',  ''
};

for k = 1:size(required, 1)
    fn = required{k, 1};
    dv = required{k, 2};
    if ~isfield(pos, fn)
        [pos.(fn)] = deal(dv); %#ok<AGROW>
    end
end

if ~isfield(pos,'filelist'),           [pos.filelist] = deal({}); end
if ~isfield(pos,'pathlist'),           [pos.pathlist] = deal({}); end
if ~isfield(pos,'unfilteredfilelist'), [pos.unfilteredfilelist] = deal({}); end
if ~isfield(pos,'unfilteredpathlist'), [pos.unfilteredpathlist] = deal({}); end
if ~isfield(pos,'channelname'),        [pos.channelname] = deal({}); end
if ~isfield(pos,'channels'),           [pos.channels] = deal([]); end
if ~isfield(pos,'frames'),             [pos.frames] = deal([]); end
if ~isfield(pos,'binning'),            [pos.binning] = deal([]); end
if ~isfield(pos,'interval'),           [pos.interval] = deal([]); end
if ~isfield(pos,'name'),               [pos.name] = deal(''); end
end

function channelBase = localChannelBaseFromPrefix(prefix)
channelBase = 'Stack';
tok = regexp(prefix, '_(?<channel>[^_]+)_s\d+$', 'names', 'once');
if ~isempty(tok) && ~isempty(tok.channel)
    channelBase = tok.channel;
    return;
end
parts = regexp(prefix, '_', 'split');
if numel(parts) >= 2
    channelBase = parts{end-1};
elseif ~isempty(prefix)
    channelBase = prefix;
end
channelBase = regexprep(channelBase, '[^\w]', '_');
end

function txt = localMetadataText(prefix, firstPath, sortedTimes, nZ)
if isempty(sortedTimes) || any(~isfinite(sortedTimes))
    timeText = '';
else
    timeText = mat2str(sortedTimes(:)');
end
txt = sprintf(['STK stack time series\n' ...
    'Series: %s\n' ...
    'First file: %s\n' ...
    'Frames/files: %d\n' ...
    'Z planes exposed as channels: %d\n' ...
    'Time indices: %s\n'], ...
    prefix, firstPath, numel(sortedTimes), nZ, timeText);
end
