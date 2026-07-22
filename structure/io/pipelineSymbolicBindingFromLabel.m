function value = pipelineSymbolicBindingFromLabel(label)
% pipelineSymbolicBindingFromLabel  Convert a displayed resource label to its binding.
%
% The declared resource role is authoritative. Physical channel suffixes
% such as "_cell" are intentionally not used to infer lineage semantics.

label = strtrim(char(string(label)));
value = label;
if ~(startsWith(label, '<') && endsWith(label, '>'))
    return;
end

inner = strtrim(label(2:end-1));
tokens = regexp(inner, '^(.+?)\s+output\s+from\s+([^/\s]+)(?:\s*/\s*.*)?$', 'tokens', 'once');
if isempty(tokens)
    value = ['@' inner];
    return;
end

role = regexprep(strtrim(tokens{1}), '\s+', '_');
sourceNode = strtrim(tokens{2});
concrete = '';
concreteTokens = regexp(inner, '^.+?\s+output\s+from\s+[^/]+/\s*(.+)$', 'tokens', 'once');
if ~isempty(concreteTokens)
    concrete = strtrim(concreteTokens{1});
end
variableSuffix = '';
if contains(concrete, '/')
    parts = regexp(concrete, '\s*/\s*', 'split');
    if numel(parts) >= 2
        variableSuffix = strtrim(strjoin(parts(2:end), ' / '));
    end
end

if any(strcmp(role, {'lineage_cell','lineage_cell_mask','lineage_mask','lineage_mother_mask'}))
    role = 'lineage_mother';
elseif any(strcmp(role, {'lineage_conf','lineage_confidence','lineage_bud_mask'}))
    role = 'lineage_bud';
end

value = ['@resource:' role ':' sourceNode];
if ~isempty(variableSuffix)
    value = [value ' / ' variableSuffix];
end
end
