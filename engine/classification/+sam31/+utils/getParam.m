function v = getParam(params, names, defaultValue)
% sam31.utils.getParam
% Case-insensitive param fetch from a struct.

v = defaultValue;
if ~isstruct(params)
    return;
end
if ischar(names) || isstring(names)
    names = cellstr(names);
end
f = fieldnames(params);
for i = 1:numel(names)
    hit = find(strcmpi(f, names{i}), 1, 'first');
    if ~isempty(hit)
        v = params.(f{hit});
        return;
    end
end
end
