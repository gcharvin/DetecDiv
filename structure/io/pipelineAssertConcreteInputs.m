function pipelineAssertConcreteInputs(node)
% Never let a module treat an unresolved pipeline reference as a disk name.
contract = pipelineNodeContract(node);
if ~isfield(contract, 'resources') || ~isfield(contract.resources, 'in')
    return;
end
inputs = contract.resources.in;
for i = 1:numel(inputs)
    key = char(string(inputs(i).param));
    if ~isfield(node.params, key), continue; end
    values = string(node.params.(key));
    if any(startsWith(strtrim(values(:)), '@resource:'))
        error('runPipeline:UnresolvedResource', ...
            'Node %s input %s still contains an unresolved resource reference: %s.', ...
            char(string(node.id)), key, strjoin(values(:), ', '));
    end
end
end
