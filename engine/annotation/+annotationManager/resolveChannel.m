function [channelName, exists] = resolveChannel(roiObj, asset)
%ANNOTATIONMANAGER.RESOLVECHANNEL Resolve the first existing channel candidate.

channelName = '';
exists = false;
candidates = normalizeCandidates(asset);
available = annotationManager.availableChannels(roiObj);

familyName = '';
if isstruct(asset) && isfield(asset, 'family')
    familyName = char(string(asset.family));
end
if ~isempty(familyName)
    try
        [familyExists, ~, provider] = ...
            cellModel.findStoredFamily(roiObj, familyName);
        if familyExists
            providerIdx = find(strcmpi(available, provider), 1, 'first');
            if ~isempty(providerIdx)
                channelName = available{providerIdx};
                exists = true;
                return;
            end
        end
    catch
    end
end

% Explicit candidates remain a compatibility fallback when no stored
% object family can authoritatively identify its mask provider.  In
% particular, classifier input channels may be raw intensity images and
% must not override the provider carried by an existing tracked family.
for i = 1:numel(candidates)
    idx = find(strcmpi(available, candidates{i}), 1, 'first');
    if ~isempty(idx)
        channelName = available{idx};
        exists = true;
        return;
    end
end
end

function values = normalizeCandidates(asset)
values = {};
if ~isstruct(asset), return; end
if isfield(asset, 'channel') && ~isempty(asset.channel)
    values{end+1} = char(string(asset.channel)); %#ok<AGROW>
end
if isfield(asset, 'channelCandidates') && ~isempty(asset.channelCandidates)
    raw = asset.channelCandidates;
    while iscell(raw) && numel(raw) == 1 && iscell(raw{1})
        raw = raw{1};
    end
    if ischar(raw) || isstring(raw), raw = cellstr(string(raw)); end
    if iscell(raw)
        for i = 1:numel(raw)
            if ~isempty(raw{i})
                values{end+1} = char(string(raw{i})); %#ok<AGROW>
            end
        end
    end
end
values = unique(values, 'stable');
end
