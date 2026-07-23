function out = applyOverrides(out, patch)
%BUDMOTHERLINKER.UTILS.APPLYOVERRIDES Shallow override of known fields.
if ~isstruct(patch), return; end
names = fieldnames(patch);
for i = 1:numel(names)
    if isfield(out, names{i}) && ~isempty(patch.(names{i}))
        out.(names{i}) = patch.(names{i});
    end
end
end
