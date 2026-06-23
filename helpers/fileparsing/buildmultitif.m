function output = buildmultitif(filelist, outputin, progress)
% buildmultitif
% Build list of positions from multi-page TIFF files and parse channels/frames.
%
% Supports metadata in:
% - ImageJ (ImageDescription: "channels=..", "frames=..")
% - OME-XML (ImageDescription contains SizeC/SizeT)
% - tifffile.py JSON (ImageDescription: {"shape":[T,C,Y,X]} or variants)
%
% Output format:
% - output.pos(i).channels  = #channels
% - output.pos(i).frames    = #frames (timepoints)
% - output.pos(i).isMultiTiff = true
% - output.pos(i).tiffSource{c} = full path of source tiff
% - output.pos(i).pageMap{c}(t) = page index within tiff for channel c, frame t
% - output.pos(i).filelist{c}(t) = virtual struct array for compatibility

output = outputin;

% --- filter files ---
filelist = filelist([filelist.isdir] == 0);
filelist = filelist(contains({filelist.name},{'.tif','.tiff'},'IgnoreCase',true)); % only tiffs here

if isempty(filelist)
    output.comments = [output.comments 'No TIFF files found for multi-TIFF parsing.' char(10)];
    return;
end

% --- Ensure struct schema has required fields (prevent dissimilar-struct assignment) ---
output.pos = local_ensureMultitiffFields(output.pos);

% --- detect trailing numeric suffix for sorting positions ---
res = nan(1,numel(filelist));
okSuffix = true;
for i = 1:numel(filelist)
    [~, fle] = fileparts(filelist(i).name);
    tok = regexp(fle, '(\d+)(\.ome)?$', 'tokens', 'once'); % supports "...123" or "...123.ome"
    if isempty(tok)
        okSuffix = false;
        break;
    end
    res(i) = str2double(tok{1});
end

if okSuffix && all(isfinite(res))
    [sortedres, ix] = sort(res);
    filelist = filelist(ix);
else
    sortedres = 1:numel(filelist);
end

templatePos = output.pos(1);
outPos = templatePos;
outCount = 0;

% --- loop over files; a single OME-TIFF may contain several XY positions ---
for i = 1:numel(filelist)

    info = ['Processing multi-TIFF file: ' num2str(i) '/' num2str(numel(filelist))];
    disp(info);
    if ~isempty(progress)
        progress.Message = info;
        progress.Value = min(1, 0.67 + 0.33*(i-1)/max(1,numel(filelist)));
    end
    detecdiv_check_cancel(progress, info);

    foldername = filelist(i).folder;
    fileName = filelist(i).name;
    tiffPath = fullfile(foldername, fileName);

    % Read tiff directory
    im = imfinfo(tiffPath);
    nPages = numel(im);

    % --- extract metadata string (may be empty except on first page) ---
    desc = '';
    if isfield(im,'ImageDescription')
        % your dataset: only page 1 has the JSON -> checking page 1 is enough,
        % but we scan a few pages anyway for robustness
        for ii = 1:min(nPages, 10)
            if ~isempty(im(ii).ImageDescription)
                desc = im(ii).ImageDescription;
                break;
            end
        end
    end

    % --- pymmcore-gui OME-TIFF repair path ---
    % Some pymmcore-gui/acquisition outputs write every IFD as TheT with
    % SizeC=1/SizeZ=1 even when the physical acquisition was T-P-C-Z.  In
    % that case, rebuild virtual DetecDiv channels from per-plane position,
    % exposure, and Z coordinates, and let readImage use the resulting pageMap.
    omePositions = local_buildOmePlanePositions(desc, nPages, fileName, foldername, tiffPath, templatePos);
    if ~isempty(omePositions)
        for p = 1:numel(omePositions)
            outCount = outCount + 1;
            if outCount == 1
                outPos = omePositions(p);
            else
                outPos(outCount) = omePositions(p); %#ok<AGROW>
            end
            outPos(outCount).name = sprintf('pos%d', sortedres(i));
            if numel(omePositions) > 1
                outPos(outCount).name = sprintf('%s_p%d', outPos(outCount).name, p);
            end
        end
        continue;
    end

    % --- standard multi-TIFF path: parse nch / nframes from metadata ---
    [nch, nframes] = local_parseChannelsFrames(desc, nPages);

    % Final safety
    if isempty(nch) || ~isfinite(nch) || nch < 1
        nch = 1;
    end
    nch = max(1, round(nch));

    if isempty(nframes) || ~isfinite(nframes) || nframes < 1
        nframes = floor(nPages / nch);
    else
        nframes = floor(nframes);
    end

    % Interval placeholder (per-channel relative frequency)
    interval = ones(1, nch);

    channelNames = cell(1, nch);
    for c = 1:nch
        channelNames{c} = ['ch' num2str(c)];
    end
    pageMap = cell(1, nch);
    for c = 1:nch
        pm = (c:nch:nPages);
        if numel(pm) < nframes
            pm = ((0:nframes-1) * nch + c);
        end
        pageMap{c} = pm(1:nframes);
    end

    outCount = outCount + 1;
    pos = local_makeMultitiffPosition(templatePos, fileName, foldername, tiffPath, ...
        nch, nframes, pageMap, channelNames, interval, desc);
    pos.name = ['pos' num2str(sortedres(i))];
    if outCount == 1
        outPos = pos;
    else
        outPos(outCount) = pos; %#ok<AGROW>
    end
end

if outCount == 0
    output.pos = templatePos;
else
    output.pos = outPos;
end

output.comments = [output.comments num2str(numel(output.pos)) ' positions were identifed' char(10)];

end

% -------------------------------------------------------------------------
function pos = local_ensureMultitiffFields(pos)
% Ensure all required fields exist so assignments don't create dissimilar structs.

% if pos is empty, create a minimal template
if isempty(pos)
    pos = struct();
end

required = {
    'isMultiTiff', false
    'tiffSource',  {}
    'pageMap',     {}
};

for k = 1:size(required,1)
    fn = required{k,1};
    dv = required{k,2};
    if ~isfield(pos, fn)
        [pos.(fn)] = deal(dv); %#ok<AGROW>
    end
end

% Also ensure these exist (they already exist in your pipeline usually)
if ~isfield(pos,'filelist'),           [pos.filelist] = deal({}); end
if ~isfield(pos,'pathlist'),           [pos.pathlist] = deal({}); end
if ~isfield(pos,'unfilteredfilelist'), [pos.unfilteredfilelist] = deal({}); end
if ~isfield(pos,'unfilteredpathlist'), [pos.unfilteredpathlist] = deal({}); end
if ~isfield(pos,'channelname'),        [pos.channelname] = deal({}); end
if ~isfield(pos,'channels'),           [pos.channels] = deal([]); end
if ~isfield(pos,'frames'),             [pos.frames] = deal([]); end
if ~isfield(pos,'binning'),            [pos.binning] = deal([]); end
if ~isfield(pos,'interval'),           [pos.interval] = deal([]); end
if ~isfield(pos,'channelfilter'),      [pos.channelfilter] = deal({''}); end
if ~isfield(pos,'stackfilter'),        [pos.stackfilter] = deal({''}); end
if ~isfield(pos,'name'),               [pos.name] = deal(''); end
if ~isfield(pos,'metadataText'),       [pos.metadataText] = deal(''); end

end

% -------------------------------------------------------------------------
function pos = local_makeMultitiffPosition(templatePos, fileName, foldername, tiffPath, ...
    nch, nframes, pageMap, channelNames, interval, metadataText)
% Fill one DetecDiv position backed by a multi-page TIFF and a page map.

pos = templatePos;
pos.channels = nch;
pos.frames   = nframes;
pos.isMultiTiff = true;

pos.tiffSource = cell(1, nch);
pos.pageMap    = cell(1, nch);
pos.filelist   = cell(1, nch);
pos.pathlist   = cell(1, nch);

entries = repmat(struct('name', fileName, 'folder', foldername), 1, nframes);

for c = 1:nch
    pos.tiffSource{c} = tiffPath;
    pos.pathlist{c}   = foldername;
    pos.filelist{c}   = entries;
    pos.pageMap{c}    = pageMap{c};
end

pos.unfilteredpathlist = pos.pathlist;
pos.unfilteredfilelist = pos.filelist;
pos.binning = ones(1, nch);
pos.interval = interval;
pos.channelfilter = {''};
pos.stackfilter = {''};
pos.positionfilter2 = {};
pos.channelfilter2 = {};
pos.stackfilter2 = {};
pos.channelname = channelNames;
pos.metadataText = metadataText;
end

% -------------------------------------------------------------------------
function positions = local_buildOmePlanePositions(desc, nPages, fileName, foldername, tiffPath, templatePos)
% Reconstruct pymmcore-gui OME-TIFF acquisition order as T-P-C-Z.
%
% The current DetecDiv FOV model has frame x channel addressing but no
% separate Z axis. We therefore expose each physical channel/Z plane as one
% DetecDiv channel, matching the NDTiff importer convention.

positions = [];
if isempty(desc) || ~contains(desc, '<OME', 'IgnoreCase', true)
    return;
end

planes = regexp(desc, '<Plane[^>]*>', 'match');
if isempty(planes) || numel(planes) ~= nPages
    return;
end

[sizeC, sizeT, sizeZ] = local_parseOmeSizes(desc);
if ~(sizeC <= 1 && sizeZ <= 1 && sizeT == nPages)
    return;
end

plane = repmat(struct('page',0,'x',NaN,'y',NaN,'z',NaN,'exp',NaN), 1, nPages);
for i = 1:nPages
    attr = planes{i};
    plane(i).page = i;
    plane(i).x = local_attrDouble(attr, 'PositionX');
    plane(i).y = local_attrDouble(attr, 'PositionY');
    plane(i).z = local_attrDouble(attr, 'PositionZ');
    plane(i).exp = local_attrDouble(attr, 'ExposureTime');
end

if all(isnan([plane.z])) && all(isnan([plane.exp])) && all(isnan([plane.x]))
    return;
end

posIds = local_groupRows([[plane.x]' [plane.y]'], 0.5);
if isempty(posIds)
    posIds = ones(nPages, 1);
end

posVals = unique(posIds(:))';
posStructs = repmat(templatePos, 1, numel(posVals));
madeAny = false;

for pi = 1:numel(posVals)
    pageIdx = find(posIds(:)' == posVals(pi));
    if isempty(pageIdx)
        continue;
    end

    pageIdx = sort(pageIdx(:)');
    breaks = [0 find(diff(pageIdx) > 1) numel(pageIdx)];
    runs = {};
    for r = 1:numel(breaks)-1
        runPages = pageIdx((breaks(r)+1):breaks(r+1));
        if ~isempty(runPages)
            runs{end+1} = runPages; %#ok<AGROW>
        end
    end
    if isempty(runs)
        continue;
    end

    nch = min(cellfun(@numel, runs));
    nframes = numel(runs);
    if nch < 1 || nframes < 1
        continue;
    end

    pageMap = cell(1, nch);
    for c = 1:nch
        pageMap{c} = zeros(1, nframes);
        for t = 1:nframes
            pageMap{c}(t) = runs{t}(c);
        end
    end

    channelNames = local_namesForOmeRun(plane, runs{1}(1:nch));
    posStructs(pi) = local_makeMultitiffPosition(templatePos, fileName, foldername, tiffPath, ...
        nch, nframes, pageMap, channelNames, ones(1, nch), desc);
    madeAny = true;
end

if madeAny
    positions = posStructs;
end
end

% -------------------------------------------------------------------------
function channelNames = local_namesForOmeRun(plane, pages)
channelNames = cell(1, numel(pages));
expVals = [plane(pages).exp]';
if all(isnan(expVals))
    chanIds = ones(numel(pages), 1);
else
    chanIds = local_groupRows(expVals, 1e-9);
end

seenPerChannel = zeros(1, max(chanIds));
for i = 1:numel(pages)
    c = chanIds(i);
    seenPerChannel(c) = seenPerChannel(c) + 1;
    expVal = plane(pages(i)).exp;
    if isnan(expVal)
        cName = sprintf('ch%d', c);
    else
        cName = sprintf('ch%d_exp%s', c, local_compactNumber(expVal));
    end
    channelNames{i} = sprintf('%s_z%d', cName, seenPerChannel(c));
end
end

% -------------------------------------------------------------------------
function [sizeC, sizeT, sizeZ] = local_parseOmeSizes(desc)
sizeC = NaN;
sizeT = NaN;
sizeZ = NaN;
t = regexp(desc,'SizeC\s*=\s*["''](\d+)["'']','tokens','once','ignorecase');
if ~isempty(t), sizeC = str2double(t{1}); end
t = regexp(desc,'SizeT\s*=\s*["''](\d+)["'']','tokens','once','ignorecase');
if ~isempty(t), sizeT = str2double(t{1}); end
t = regexp(desc,'SizeZ\s*=\s*["''](\d+)["'']','tokens','once','ignorecase');
if ~isempty(t), sizeZ = str2double(t{1}); end
end

% -------------------------------------------------------------------------
function v = local_attrDouble(attr, name)
v = NaN;
tok = regexp(attr, [name '\s*=\s*["'']([^"'']*)["'']'], 'tokens', 'once', 'ignorecase');
if ~isempty(tok)
    v = str2double(tok{1});
end
end

% -------------------------------------------------------------------------
function ids = local_groupRows(vals, tol)
if isempty(vals)
    ids = [];
    return;
end

if isvector(vals)
    vals = vals(:);
end

n = size(vals, 1);
ids = zeros(n, 1);
groups = {};
ng = 0;
for i = 1:n
    row = vals(i, :);
    assigned = false;
    for g = 1:ng
        ref = groups{g};
        same = (isnan(row) & isnan(ref)) | abs(row - ref) <= tol;
        if all(same)
            ids(i) = g;
            assigned = true;
            break;
        end
    end
    if ~assigned
        ng = ng + 1;
        groups{ng} = row; %#ok<AGROW>
        ids(i) = ng;
    end
end
end

% -------------------------------------------------------------------------
function s = local_compactNumber(v)
if isnan(v)
    s = 'nan';
    return;
end
s = regexprep(sprintf('%.6g', v), '[^0-9A-Za-z]+', 'p');
end

% -------------------------------------------------------------------------
function [nch, nframes] = local_parseChannelsFrames(desc, nPages)
% Returns nch, nframes (may be empty) from ImageDescription string.

nch = [];
nframes = [];

if isempty(desc)
    return;
end

s = desc;
sTrim = strtrim(s);

% 1) tifffile.py JSON: {"shape":[T,C,Y,X]} or {"shape": [61, 2, ...]}
if ~isempty(sTrim) && sTrim(1) == '{'
    try
        md = jsondecode(sTrim);
        if isstruct(md) && isfield(md,'shape') && ~isempty(md.shape)
            sh = double(md.shape(:))';
            if numel(sh) >= 2
                nframes = sh(1);
                nch     = sh(2);
                return;
            end
        end
    catch
        % ignore JSON errors
    end
end

% 2) ImageJ style: channels=, frames=
if contains(s,'imagej','IgnoreCase',true)
    t = regexp(s,'channels\s*=\s*(\d+)','tokens','once','ignorecase');
    if ~isempty(t), nch = str2double(t{1}); end
    t = regexp(s,'frames\s*=\s*(\d+)','tokens','once','ignorecase');
    if ~isempty(t), nframes = str2double(t{1}); end
    return;
end

% 3) OME-XML: SizeC / SizeT
t = regexp(s,'SizeC\s*=\s*["''](\d+)["'']','tokens','once','ignorecase');
if ~isempty(t), nch = str2double(t{1}); end

t = regexp(s,'SizeT\s*=\s*["''](\d+)["'']','tokens','once','ignorecase');
if ~isempty(t), nframes = str2double(t{1}); end

% 4) If only nch known, infer frames from pages
if ~isempty(nch) && (isempty(nframes) || ~isfinite(nframes) || nframes < 1)
    nframes = nPages / nch;
end

end
