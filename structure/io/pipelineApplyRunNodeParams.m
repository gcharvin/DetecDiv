function nodes = pipelineApplyRunNodeParams(nodes, nodeParams)
%PIPELINEAPPLYRUNNODEPARAMS Apply the user's per-run choices to a node copy.
% A concrete run binding (or an explicit empty value) overrides a template
% symbol. Generic source placeholders must not erase concrete template inputs.
if isempty(nodes) || isempty(nodeParams)
    return;
end
for i = 1:numel(nodes)
    nodeId = char(string(nodes(i).id));
    patch = findPatch(nodeParams, nodeId);
    if isempty(patch) || ~isstruct(patch)
        continue;
    end
    if isfield(patch, 'params') && isstruct(patch.params)
        patch = patch.params;
    else
        reserved = intersect(fieldnames(patch), {'id','nodeId'});
        patch = rmfield(patch, reserved);
    end
    if ~isfield(nodes(i), 'params') || ~isstruct(nodes(i).params)
        nodes(i).params = struct();
    end
    names = fieldnames(patch);
    for j = 1:numel(names)
        key = names{j};
        base = '';
        if isfield(nodes(i).params, key)
            base = scalarText(nodes(i).params.(key));
        end
        value = scalarText(patch.(key));
        genericSource = any(strcmp(value, {'@source','@all_channels'})) || ...
            startsWith(value, '@resource:source:');
        if genericSource && ~isempty(base) && ~startsWith(base, '@')
            continue;
        end
        nodes(i).params.(key) = patch.(key);
    end
end
end

function patch = findPatch(nodeParams, nodeId)
patch = [];
if iscell(nodeParams)
    for i = 1:numel(nodeParams)
        patch = findPatch(nodeParams{i}, nodeId);
        if ~isempty(patch), return; end
    end
elseif isstruct(nodeParams)
    for i = 1:numel(nodeParams)
        item = nodeParams(i);
        if (isfield(item, 'id') && strcmp(char(string(item.id)), nodeId)) || ...
                (isfield(item, 'nodeId') && strcmp(char(string(item.nodeId)), nodeId))
            patch = item;
            return;
        end
    end
    if isscalar(nodeParams)
        key = matlab.lang.makeValidName(nodeId);
        if isfield(nodeParams, key)
            patch = nodeParams.(key);
        elseif isfield(nodeParams, nodeId)
            patch = nodeParams.(nodeId);
        end
    end
end
end

function text = scalarText(value)
text = '';
if iscell(value)
    if numel(value) ~= 1, return; end
    value = value{1};
end
if ischar(value) || (isstring(value) && isscalar(value))
    text = strtrim(char(value));
end
end
