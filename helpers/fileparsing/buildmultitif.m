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

foldername = filelist(1).folder;

% --- Ensure struct schema has required fields (prevent dissimilar-struct assignment) ---
output.pos = local_ensureMultitiffFields(output.pos);

% --- Initialize positions with filenames (one file = one position) ---
for i = 1:numel(filelist)
    if i ~= 1
        output.pos(i) = output.pos(1); %#ok<AGROW>
    end
    output.pos(i).name = filelist(i).name;
end

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
    output.pos = output.pos(ix);
else
    sortedres = 1:numel(output.pos);
end

output.comments = [output.comments num2str(numel(output.pos)) ' positions were identifed' char(10)];

% --- loop over positions (each = one multi-page TIFF) ---
for i = 1:numel(output.pos)

    info = ['Processing position: ' num2str(i) '/' num2str(numel(output.pos))];
    disp(info);
    if ~isempty(progress)
        progress.Message = info;
        progress.Value = min(1, 0.67 + 0.33*(i-1)/max(1,numel(output.pos)));
    end

    tiffPath = fullfile(foldername, output.pos(i).name);

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

    % --- parse nch / nframes from metadata ---
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

    % --- fill output.pos(i) (no dissimilar struct) ---
    output.pos(i).channels = nch;
    output.pos(i).frames   = nframes;

    output.pos(i).isMultiTiff = true;

    output.pos(i).tiffSource = cell(1, nch);
    output.pos(i).pageMap    = cell(1, nch);
    output.pos(i).filelist   = cell(1, nch);
    output.pos(i).pathlist   = cell(1, nch);

    entries = repmat(struct('name', output.pos(i).name, 'folder', foldername), 1, nframes);

    for c = 1:nch
        output.pos(i).tiffSource{c} = tiffPath;
        output.pos(i).pathlist{c}   = foldername;
        output.pos(i).filelist{c}   = entries;

        pm = (c:nch:nPages);
        if numel(pm) < nframes
            pm = ((0:nframes-1) * nch + c);
        end
        output.pos(i).pageMap{c} = pm(1:nframes);
    end

    output.pos(i).unfilteredpathlist = output.pos(i).pathlist;
    output.pos(i).unfilteredfilelist = output.pos(i).filelist;

    output.pos(i).binning  = ones(1, nch);
    output.pos(i).interval = interval;

    % Standardize name to posN (as before)
    output.pos(i).name = ['pos' num2str(sortedres(i))];
    output.pos(i).channelfilter = {''};
    output.pos(i).stackfilter   = {''};

    output.pos(i).channelname = cell(1, nch);
    for c = 1:nch
        output.pos(i).channelname{c} = ['ch' num2str(c)];
    end
end

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
