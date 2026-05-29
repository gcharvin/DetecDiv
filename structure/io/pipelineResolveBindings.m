function [pipeOut, report] = pipelineResolveBindings(pipeIn, ctx, opts)
% pipelineResolveBindings  Apply auto-resolvable symbolic/runtime bindings.
%
% This helper is intentionally small: validation remains in validatePipeline.
% Here we only materialize bindings that the solver has already classified as
% auto_resolvable. Ambiguous bindings remain untouched and are reported for UI.

if nargin < 2 || isempty(ctx)
    ctx = struct();
end
if nargin < 3 || isempty(opts)
    opts = struct();
end

pipeOut = pipelineToStructLocal(pipeIn);
[~, validation] = validatePipeline(pipeOut, ctx, opts);
report = struct( ...
    'validation', validation, ...
    'applied', appliedRecordDef(), ...
    'warnings', {{}});

if ~isfield(validation, 'binding') || ~isstruct(validation.binding) || ...
        ~isfield(validation.binding, 'nodes') || ~isstruct(validation.binding.nodes)
    return;
end

if ~isfield(pipeOut, 'nodes') || isempty(pipeOut.nodes)
    return;
end

keys = fieldnames(validation.binding.nodes);
for i = 1:numel(keys)
    br = validation.binding.nodes.(keys{i});
    nodeId = char(string(getFieldLocal(br, 'nodeId', '')));
    idx = findNodeIndexLocal(pipeOut.nodes, nodeId);
    if isempty(idx)
        continue;
    end
    if ~isfield(pipeOut.nodes(idx), 'params') || ~isstruct(pipeOut.nodes(idx).params)
        pipeOut.nodes(idx).params = struct();
    end
    vIdx = findNodeIndexLocal(validation.nodes, nodeId);
    if ~isempty(vIdx) && isfield(validation.nodes(vIdx), 'contract')
        pipeOut.nodes(idx).contract = validation.nodes(vIdx).contract;
    end

    [pipeOut.nodes(idx), appliedResource] = applyAutoResourceBindingsLocal(pipeOut.nodes(idx), br);
    report.applied = appendAppliedLocal(report.applied, appliedResource);

    [pipeOut.nodes(idx), appliedLegacy] = applyAutoChannelBindingLocal(pipeOut.nodes(idx), br);
    report.applied = appendAppliedLocal(report.applied, appliedLegacy);
end

if isa(pipeIn, 'pipeline')
    try
        tmp = pipeIn;
        tmp.nodes = pipeOut.nodes;
        tmp.edges = pipeOut.edges;
        if isfield(pipeOut, 'branches')
            tmp.branches = pipeOut.branches;
        end
        pipeOut = tmp;
    catch
    end
end
end

function [node, applied] = applyAutoResourceBindingsLocal(node, br)
applied = appliedRecordDef();
if ~isfield(br, 'resources') || ~isstruct(br.resources) || ...
        ~isfield(br.resources, 'inputs') || isempty(br.resources.inputs)
    return;
end

inputs = br.resources.inputs;
for i = 1:numel(inputs)
    item = inputs(i);
    if ~strcmp(char(string(getFieldLocal(item, 'status', ''))), 'auto_resolvable')
        continue;
    end
    param = char(string(getFieldLocal(item, 'param', '')));
    if isempty(param) || (isfield(node.params, param) && ~isempty(node.params.(param)))
        continue;
    end
    choice = getFieldLocal(item, 'autoChoice', struct([]));
    value = resourceConcreteNameLocal(choice);
    if isempty(value)
        continue;
    end
    node.params.(param) = value;
    applied(end+1) = appliedRecordLocal(node, param, value, 'resource', item); %#ok<AGROW>
end
end

function [node, applied] = applyAutoChannelBindingLocal(node, br)
applied = appliedRecordDef();
if ~strcmp(char(string(getFieldLocal(br, 'status', ''))), 'auto_resolvable')
    return;
end
autoChoice = getFieldLocal(br, 'autoChoice', {});
if isempty(autoChoice)
    return;
end
contract = getFieldLocal(node, 'contract', struct());
binding = getFieldLocal(contract, 'binding', struct());
selectorKeys = getFieldLocal(binding, 'selectorKeys', {});
if isempty(selectorKeys)
    return;
end
selectorKeys = cellstr(string(selectorKeys(:)));
param = selectorKeys{1};
if isfield(node.params, param) && ~isempty(node.params.(param))
    return;
end
value = autoChoice;
if iscell(value) && numel(value) == 1
    value = value{1};
end
node.params.(param) = value;
applied = appliedRecordLocal(node, param, value, 'channel', br);
end

function rec = appliedRecordLocal(node, param, value, kind, source)
rec = struct( ...
    'nodeId', char(string(getFieldLocal(node, 'id', ''))), ...
    'param', char(string(param)), ...
    'value', valueToCharLocal(value), ...
    'kind', char(string(kind)), ...
    'source', source);
end

function rec = appliedRecordDef()
rec = struct('nodeId',{},'param',{},'value',{},'kind',{},'source',{});
end

function out = appendAppliedLocal(out, extra)
if isempty(extra)
    return;
end
if isempty(out)
    out = extra;
else
    out = [out extra]; %#ok<AGROW>
end
end

function value = resourceConcreteNameLocal(choice)
value = '';
if isempty(choice) || ~isstruct(choice)
    return;
end
if isfield(choice, 'concreteName') && ~isempty(choice(1).concreteName)
    value = char(string(choice(1).concreteName));
elseif isfield(choice, 'symbol') && ~isempty(choice(1).symbol)
    value = char(string(choice(1).symbol));
end
end

function idx = findNodeIndexLocal(nodes, nodeId)
idx = [];
if isempty(nodes) || isempty(nodeId)
    return;
end
for i = 1:numel(nodes)
    if isfield(nodes(i), 'id') && strcmp(char(string(nodes(i).id)), nodeId)
        idx = i;
        return;
    end
end
end

function pipe = pipelineToStructLocal(pipeIn)
if isa(pipeIn, 'pipeline')
    pipe = struct();
    pipe.nodes = pipeIn.nodes;
    pipe.edges = pipeIn.edges;
    pipe.branches = pipeIn.branches;
else
    pipe = pipeIn;
end
if ~isfield(pipe, 'edges')
    pipe.edges = struct([]);
end
if ~isfield(pipe, 'branches')
    pipe.branches = struct([]);
end
end

function txt = valueToCharLocal(v)
if isempty(v)
    txt = '';
elseif ischar(v)
    txt = v;
elseif iscell(v)
    txt = strjoin(cellstr(string(v(:))), ', ');
else
    txt = char(string(v));
end
end

function v = getFieldLocal(s, name, defaultValue)
if nargin < 3
    defaultValue = [];
end
v = defaultValue;
if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
    v = s.(name);
end
end
