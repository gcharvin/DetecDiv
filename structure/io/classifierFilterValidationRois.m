function [compatibleIdx, missingIdx, channels] = ...
        classifierFilterValidationRois(roiList, candidateIdx, node)
%classifierFilterValidationRois Keep validation ROIs with configured inputs.
%
% Classifier-scoped validation can contain raw, unannotated ROIs alongside
% the held-out ground-truth subset.  A one-node validation pipeline cannot
% synthesize missing segmentation/tracking inputs, so select only ROIs that
% already store every configured channel input declared by the node contract.

compatibleIdx = [];
missingIdx = [];
channels = configuredInputChannels(node);
if isempty(candidateIdx)
    return;
end
candidateIdx = unique(round(double(candidateIdx(:)')), 'stable');
candidateIdx = candidateIdx(isfinite(candidateIdx) & ...
    candidateIdx >= 1 & candidateIdx <= numel(roiList));
if isempty(channels)
    compatibleIdx = candidateIdx;
    return;
end

for i = 1:numel(candidateIdx)
    idx = candidateIdx(i);
    if roiHasChannels(roiList(idx), channels)
        compatibleIdx(end+1) = idx; %#ok<AGROW>
    else
        missingIdx(end+1) = idx; %#ok<AGROW>
    end
end
end

function channels = configuredInputChannels(node)
channels = {};
params = struct();
if isfield(node, 'params') && isstruct(node.params)
    params = node.params;
end
try
    contract = pipelineNodeContract(node);
    inputs = contract.resources.in;
catch
    inputs = struct([]);
end
for i = 1:numel(inputs)
    try
        if ~strcmpi(char(string(inputs(i).type)), 'channel')
            continue;
        end
        key = char(string(inputs(i).param));
        if isempty(key) && isfield(inputs, 'nameParam')
            key = char(string(inputs(i).nameParam));
        end
        if ~isempty(key) && isfield(params, key)
            channels = [channels channelList(params.(key))]; %#ok<AGROW>
        end
    catch
    end
end
if isempty(channels)
    for key = {'channels','channel','channelName'}
        if isfield(params, key{1})
            channels = channelList(params.(key{1}));
            if ~isempty(channels), break; end
        end
    end
end
skip = strcmpi(string(channels), 'all') | ...
    strcmpi(string(channels), 'auto') | ...
    startsWith(string(channels), '<') | ...
    startsWith(string(channels), '@');
channels = unique(channels(~skip), 'stable');
end

function tf = roiHasChannels(roiObj, channels)
missing = channels;
try
    names = cellstr(string(roiObj.display.channel(:)'));
    missing = channels(~ismember(lower(string(channels)), ...
        lower(string(names))));
catch
end
if isempty(missing)
    tf = true;
    return;
end
diskChannels = storedHdf5Channels(roiObj);
if ~isempty(diskChannels)
    missing = missing(~ismember(lower(string(missing)), ...
        lower(string(diskChannels))));
end
tf = isempty(missing);
end

function channels = storedHdf5Channels(roiObj)
channels = {};
try
    file = fullfile(char(string(roiObj.path)), ...
        ['im_' char(string(roiObj.id)) '.h5']);
    if exist(file, 'file') ~= 2
        return;
    end
    info = h5info(file);
    for i = 1:numel(info.Datasets)
        dataset = info.Datasets(i);
        channels{end+1} = char(string(dataset.Name)); %#ok<AGROW>
        attributes = string({dataset.Attributes.Name});
        hit = find(strcmpi(attributes, 'channel_name'), 1);
        if ~isempty(hit)
            logicalName = strtrim(char(string( ...
                dataset.Attributes(hit).Value)));
            if ~isempty(logicalName)
                channels{end+1} = logicalName; %#ok<AGROW>
            end
        end
    end
    channels = unique(channels, 'stable');
catch
    channels = {};
end
end

function values = channelList(raw)
values = {};
if isempty(raw)
    return;
end
if ischar(raw) || (isstring(raw) && isscalar(raw))
    text = strtrim(char(string(raw)));
    if ~isempty(text), values = {text}; end
elseif isstring(raw)
    values = cellstr(raw(:)');
elseif iscell(raw)
    for i = 1:numel(raw)
        values = [values channelList(raw{i})]; %#ok<AGROW>
    end
end
values = values(~cellfun(@isempty, values));
end
