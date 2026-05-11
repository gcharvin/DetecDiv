function scope = pipelineParamScope(node, paramName)
% pipelineParamScope  Classify a parameter as template or run scoped.

scope = 'template';
if nargin < 1 || ~isstruct(node)
    return;
end
if nargin < 2
    paramName = '';
end

paramName = lower(strtrim(char(string(paramName))));
if isempty(paramName)
    return;
end

contract = struct();
try
    contract = pipelineNodeContract(node);
catch
end

% First honor the explicit parameter contract when present.
if isstruct(contract) && isfield(contract, 'parameters') && isstruct(contract.parameters)
    if ismember(paramName, normalizeNameList(getFieldLocal(contract.parameters, 'fixed', {}))) || ...
            ismember(paramName, normalizeNameList(getFieldLocal(contract.parameters, 'design', {}))) || ...
            ismember(paramName, normalizeNameList(getFieldLocal(contract.parameters, 'template', {})))
        scope = 'template';
        return;
    end
    if ismember(paramName, normalizeNameList(getFieldLocal(contract.parameters, 'run', {}))) || ...
            ismember(paramName, normalizeNameList(getFieldLocal(contract.parameters, 'data', {})))
        scope = 'run';
        return;
    end
end

% Backward-compatible heuristic fallback.
nodeType = lower(char(string(getFieldLocal(node, 'type', ''))));
switch nodeType
    case 'dataloader'
        if any(strcmp(paramName, {'path','positionfilter','channelfilter','stackfilter','label'}))
            scope = 'run';
        end
    case {'roipattern','roiidentify','roimanual','roigrid','roiextract','roitracked'}
        if any(strcmp(paramName, {'fovindex','roiindex','frames','channels','extractframes','extractchannels','threshold','referenceframe','channel','channelindex','pattern','patternrect','patternimage','patternlist','activepatternindex','fallbackfullframe','keepexisting','gridcount','mode','margin','extract','correctdrift','driftchannel','driftmethod','driftrefmode','driftsubpixel','driftmaxshift','scale','cropdrift','extend','forcechannelnames'}))
            scope = 'run';
        end
    case {'processor','classifier'}
        if any(strcmp(paramName, {'frames','channels','channel','outputname','out_dataseries_name','roilist'}))
            scope = 'run';
        end
end
end

function list = normalizeNameList(v)
list = {};
if isempty(v)
    return;
end
if ischar(v) || isstring(v)
    list = cellstr(string(v(:)));
    list = lower(strtrim(list));
    list = list(~cellfun(@isempty, list));
    return;
end
if iscell(v)
    tmp = cell(size(v));
    for i = 1:numel(v)
        if isempty(v{i})
            tmp{i} = '';
        else
            tmp{i} = lower(strtrim(char(string(v{i}))));
        end
    end
    list = tmp(~cellfun(@isempty, tmp));
end
end

function v = getFieldLocal(s, name, defaultValue)
if nargin < 3
    defaultValue = [];
end
v = defaultValue;
if isstruct(s) && isfield(s, name)
    v = s.(name);
end
end
