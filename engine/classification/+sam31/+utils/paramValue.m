function v = paramValue(params, name, defaultValue)
% sam31.utils.paramValue  Read a scalar value from visible or internal params.

if nargin < 3
    defaultValue = [];
end
v = defaultValue;
if isempty(params) || ~isstruct(params) || ~isfield(params, name) || isempty(params.(name))
    return;
end
v = params.(name);
if iscell(v) && ~isempty(v)
    v = v{end};
end
end
