function loaded = score_loadChannelsForDisplay(roiObj, channels)
% Load only the logical channels needed by score display/rendering.

loaded = false;

if isempty(roiObj) || ~ismethod(roiObj, 'load')
    return;
end

names = localNormalizeChannelNames(roiObj, channels);
if isempty(names)
    return;
end

missing = names;
if ~isempty(roiObj.image)
    missing = {};
    for ii = 1:numel(names)
        pix = localFindChannelID(roiObj, names{ii});
        if isempty(pix) || any(pix > size(roiObj.image, 3))
            missing{end+1} = names{ii}; %#ok<AGROW>
        end
    end
end

if isempty(missing)
    return;
end

try
    roiObj.load('Channel', missing, 'Data', false, 'Silent');
catch
    roiObj.load('Channel', missing);
end
loaded = true;
end

function pix = localFindChannelID(roiObj, name)
try
    pix = roiObj.findChannelID(name, 'exact');
catch
    try
        pix = roiObj.findChannelID(name);
    catch
        pix = [];
    end
end
end

function names = localNormalizeChannelNames(roiObj, channels)
names = {};

if nargin < 2 || isempty(channels)
    if isprop(roiObj, 'display') && isstruct(roiObj.display) && ...
            isfield(roiObj.display, 'channel') && isfield(roiObj.display, 'selectedchannel')
        nCh = numel(roiObj.display.channel);
        sel = logical(roiObj.display.selectedchannel(:)');
        sel = sel(1:min(numel(sel), nCh));
        if numel(sel) < nCh
            sel(end+1:nCh) = false;
        end
        names = roiObj.display.channel(sel);
    end
elseif iscell(channels)
    names = channels;
elseif isstring(channels) || ischar(channels)
    names = cellstr(string(channels));
elseif isnumeric(channels) && isprop(roiObj, 'display') && isstruct(roiObj.display) && ...
        isfield(roiObj.display, 'channel')
    idx = channels(:)';
    idx = idx(idx >= 1 & idx <= numel(roiObj.display.channel));
    names = roiObj.display.channel(idx);
end

names = cellfun(@(s) char(string(s)), names(:)', 'UniformOutput', false);
names = names(~cellfun(@isempty, names));
end
