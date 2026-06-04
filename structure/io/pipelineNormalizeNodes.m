function nodes = pipelineNormalizeNodes(nodes, mode)
% pipelineNormalizeNodes  Canonicalize pipeline nodes before save/run/validation.
%
% The persisted template should keep user intent (id/type/pkg/func/gui/params/
% layout/etc.), not derived contract state. Contracts, inputs and outputs are
% recalculated from node params so stale saved contracts cannot override
% dynamic module IO.

if nargin < 2 || isempty(mode)
    mode = 'runtime';
end

if isempty(nodes)
    return;
end

derivedFields = {'contract','inputs','outputs'};
for i = 1:numel(derivedFields)
    if isfield(nodes, derivedFields{i})
        nodes = rmfield(nodes, derivedFields{i});
    end
end
if ~isfield(nodes, 'params')
    [nodes.params] = deal(struct());
end
if ~isfield(nodes, 'pkg')
    [nodes.pkg] = deal('');
end
if ~isfield(nodes, 'func')
    [nodes.func] = deal('');
end

for i = 1:numel(nodes)
    nodes(i) = normalizeOneNode(nodes(i), mode);
end

if strcmpi(char(string(mode)), 'withDerived')
    for i = 1:numel(nodes)
        nodes(i).contract = pipelineNodeContract(nodes(i));
        [nodes(i).inputs, nodes(i).outputs] = pipelineContractPortNames(nodes(i).contract);
    end
end
end

function node = normalizeOneNode(node, mode)
if ~isfield(node, 'params') || ~isstruct(node.params)
    node.params = struct();
end
if ~isfield(node, 'pkg') || isempty(node.pkg)
    node.pkg = '';
end
if ~isfield(node, 'func') || isempty(node.func)
    node.func = defaultFunctionForNode(node);
end

end

function fun = defaultFunctionForNode(node)
fun = '';
nodeType = lower(char(string(getFieldLocal(node, 'type', ''))));
pkg = char(string(getFieldLocal(node, 'pkg', '')));
switch nodeType
    case 'dataloader'
        fun = 'dataLoader.process';
    case {'roipattern','roiidentify'}
        fun = 'roiPattern.process';
    case 'roimanual'
        fun = 'roiManual.process';
    case 'roigrid'
        fun = 'roiGrid.process';
    case 'roitracked'
        fun = 'roiTracked.process';
    case 'roiextract'
        fun = 'roiExtract.process';
    case 'processor'
        if ~isempty(pkg)
            fun = [pkg '.process'];
        end
    case 'classifier'
        if ~isempty(pkg)
            fun = [pkg '.classify'];
        end
end
end

function v = getFieldLocal(s, name, defaultValue)
v = defaultValue;
if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
    v = s.(name);
end
end
