function component = newComponent(varargin)
%ANNOTATIONMANAGER.NEWCOMPONENT Create one annotation primitive contract.

component = struct( ...
    'id', '', ...
    'kind', '', ...
    'storage', '', ...
    'required', true, ...
    'coverageUnit', 'frame', ...
    'editor', '', ...
    'bootstrap', 'none', ...
    'classes', {{}}, ...
    'groundTruth', annotationManager.newAsset(), ...
    'prediction', annotationManager.newAsset());

if mod(numel(varargin), 2) ~= 0
    error('annotationManager:InvalidComponentArguments', ...
        'Component overrides must be name/value pairs.');
end
for i = 1:2:numel(varargin)
    key = char(string(varargin{i}));
    if ~isfield(component, key)
        error('annotationManager:UnknownComponentField', ...
            'Unknown annotation component field "%s".', key);
    end
    value = varargin{i+1};
    if strcmp(key, 'classes')
        if ischar(value) || isstring(value)
            value = cellstr(string(value));
        elseif isempty(value)
            value = {};
        end
    elseif any(strcmp(key, {'groundTruth','prediction'}))
        value = normalizeAsset(value);
    elseif isstring(value) && isscalar(value)
        value = char(value);
    end
    component.(key) = value;
end
end

function asset = normalizeAsset(value)
asset = annotationManager.newAsset();
if isempty(value)
    return;
end
if ~isstruct(value)
    error('annotationManager:InvalidAsset', ...
        'groundTruth and prediction bindings must be structs.');
end
names = fieldnames(asset);
for i = 1:numel(names)
    if isfield(value, names{i})
        asset.(names{i}) = value.(names{i});
    end
end
end
