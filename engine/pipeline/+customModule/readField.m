function value = readField(value, reference)
% Resolve a declared dotted field reference, without eval.
parts = strsplit(char(reference), '.');
for i = 1:numel(parts)
    if ~isstruct(value) || ~isscalar(value) || ~isfield(value, parts{i})
        error('customModule:MissingArgument', 'Missing field reference: %s.', char(reference));
    end
    value = value.(parts{i});
end
end
