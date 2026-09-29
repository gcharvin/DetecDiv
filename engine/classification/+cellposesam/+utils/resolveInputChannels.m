function [pix, missingNames] = resolveInputChannels(roiObj, names)
%RESOLVEINPUTCHANNELS Resolve canonical ROI channel names and display aliases.

if ischar(names)
    names = cellstr(names);
elseif isstring(names)
    names = cellstr(names(:));
elseif ~iscell(names)
    names = {char(string(names))};
end

pix = [];
missingNames = {};
if isempty(names)
    missingNames = {'(no input channel configured)'};
    return;
end

for iName = 1:numel(names)
    name = char(string(names{iName}));
    idx = roiObj.findChannelID(name);
    if isempty(idx)
        idx = findDisplayAlias(roiObj, name);
    end
    if isempty(idx)
        missingNames{end+1} = name; %#ok<AGROW>
    else
        pix = [pix, idx(:).']; %#ok<AGROW>
    end
end
pix = unique(pix, 'stable');
end

function pix = findDisplayAlias(roiObj, alias)
pix = [];
if ~isstruct(roiObj.display) || ...
        ~isfield(roiObj.display, 'channelAlias') || ...
        isempty(roiObj.display.channelAlias) || isempty(roiObj.channelid)
    return;
end

aliases = cellstr(string(roiObj.display.channelAlias(:)));
logicalChannels = find(strcmpi(aliases, alias));
if isempty(logicalChannels), return; end
pix = find(ismember(roiObj.channelid, logicalChannels));
end
