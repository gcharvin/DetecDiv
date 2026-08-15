function params = classifierApplyPipelineInputBindings( ...
        params, classiObj, contract, intent, explicitChannels)
%classifierApplyPipelineInputBindings Restore classifier channel bindings.
%
% Pipeline2 contracts declare the effective channel selector keys.  This
% helper restores those selectors from classifier-scoped state for both
% training and validation runs.  Named selectors remain authoritative;
% positional classifier channels only fill required contract inputs, so an
% optional biological role is never inferred from an unrelated channel.

if nargin < 1 || isempty(params) || ~isstruct(params)
    params = struct();
end
if nargin < 3 || isempty(contract) || ~isstruct(contract)
    contract = struct();
end
if nargin < 4 || isempty(intent)
    intent = 'validate';
end
if nargin < 5
    explicitChannels = [];
end

selectorKeys = contractSelectorKeys(contract);
if isempty(selectorKeys)
    selectorKeys = {'channels','channel'};
end

trainingParam = classifierStructProperty(classiObj, 'trainingParam');
executionParam = classifierStructProperty(classiObj, 'executionParam');
intent = strtrim(char(string(intent)));

% Execution parameters provide the inference baseline. Some legacy packages
% do not merge them in executionSpec, so apply them here as well.
params = overlayNonemptySelectors(params, executionParam, selectorKeys);
if strcmpi(intent, 'train')
    % Training selectors describe how the reviewed dataset was formatted.
    % Their presence is authoritative, including an intentionally empty
    % optional selector which must clear an inference default.
    params = overlayPresentSelectors(params, trainingParam, selectorKeys);
else
    % A newly materialized validation run follows the channels used to build
    % the trained dataset.  Users can still override these node values in
    % Pipeline2 after creation.
    params = overlayNonemptySelectors(params, trainingParam, selectorKeys);
end

storedChannels = classifierInputChannels(classiObj);
if (~isfield(params, 'channels') || isEmptySelection(params.channels)) && ...
        ~isempty(storedChannels)
    params.channels = storedChannels;
end

requiredKeys = requiredChannelSelectorKeys(contract, selectorKeys);
explicitList = channelList(explicitChannels);
if ~isempty(explicitList)
    params.channels = explicitChannels;
    params = assignRequiredChannels(params, requiredKeys, explicitList, true);
else
    params = assignRequiredChannels(params, requiredKeys, storedChannels, false);
end
end

function params = overlayNonemptySelectors(params, source, keys)
for i = 1:numel(keys)
    key = keys{i};
    if isfield(source, key)
        value = selectedValue(source.(key));
        if ~isEmptySelection(value)
            params.(key) = value;
        end
    end
end
end

function params = overlayPresentSelectors(params, source, keys)
for i = 1:numel(keys)
    key = keys{i};
    if isfield(source, key)
        params.(key) = selectedValue(source.(key));
    end
end
end

function params = assignRequiredChannels(params, keys, channels, overwrite)
if isempty(keys) || isempty(channels)
    return;
end
channels = channelList(channels);
slot = 1;
for i = 1:numel(keys)
    key = keys{i};
    if strcmp(key, 'channels')
        if overwrite || ~isfield(params, key) || isEmptySelection(params.(key))
            params.(key) = channels;
        end
        continue;
    end
    if slot > numel(channels)
        break;
    end
    if overwrite || ~isfield(params, key) || isEmptySelection(params.(key))
        params.(key) = channels{slot};
    end
    slot = slot + 1;
end
end

function keys = contractSelectorKeys(contract)
keys = {};
try
    keys = cellstr(string(contract.binding.selectorKeys));
catch
end
keys = keys(~cellfun(@isempty, keys));
keys = unique(keys, 'stable');
end

function keys = requiredChannelSelectorKeys(contract, selectorKeys)
keys = {};
try
    resources = contract.resources.in;
catch
    resources = struct([]);
end
for i = 1:numel(resources)
    try
        if ~strcmpi(char(string(resources(i).type)), 'channel') || ...
                ~logical(resources(i).required)
            continue;
        end
        key = char(string(resources(i).param));
        if isempty(key) && isfield(resources, 'nameParam')
            key = char(string(resources(i).nameParam));
        end
        if ~isempty(key) && any(strcmp(selectorKeys, key))
            keys{end+1} = key; %#ok<AGROW>
        end
    catch
    end
end
keys = unique(keys, 'stable');
end

function source = classifierStructProperty(classiObj, name)
source = struct();
try
    if isobject(classiObj) && isprop(classiObj, name)
        candidate = classiObj.(name);
    elseif isstruct(classiObj) && isfield(classiObj, name)
        candidate = classiObj.(name);
    else
        candidate = [];
    end
    if isstruct(candidate)
        source = candidate;
    end
catch
end
end

function channels = classifierInputChannels(classiObj)
channels = {};
try
    if isobject(classiObj) && ismethod(classiObj, 'getInputChannels')
        channels = channelList(classiObj.getInputChannels());
    elseif isstruct(classiObj) && isfield(classiObj, 'dataset') && ...
            isstruct(classiObj.dataset) && isfield(classiObj.dataset, 'channels')
        channels = channelList(classiObj.dataset.channels);
    end
catch
end
if isempty(channels)
    try
        channels = channelList(classiObj.channelName);
    catch
    end
end
try
    secondary = channelList(classiObj.channelName2);
    channels = unique([channels secondary], 'stable');
catch
end
end

function values = channelList(raw)
values = {};
if isempty(raw)
    return;
end
if ischar(raw) || (isstring(raw) && isscalar(raw))
    text = char(string(raw));
    parts = regexp(text, '\s*,\s*', 'split');
    values = parts(~cellfun(@isempty, parts));
elseif isstring(raw)
    values = cellstr(raw(:).');
elseif iscell(raw)
    for i = 1:numel(raw)
        values = [values channelList(raw{i})]; %#ok<AGROW>
    end
end
values = values(~cellfun(@(x)isempty(strtrim(x)), values));
values = unique(values, 'stable');
end

function value = selectedValue(value)
while iscell(value)
    if isempty(value)
        value = '';
        return;
    end
    value = value{end};
end
if isstring(value) && isscalar(value)
    value = char(value);
end
end

function tf = isEmptySelection(value)
tf = isempty(value);
if ischar(value) || (isstring(value) && isscalar(value))
    tf = strlength(strtrim(string(value))) == 0;
end
end
