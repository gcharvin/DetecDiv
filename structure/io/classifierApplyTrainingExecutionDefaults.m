function params = classifierApplyTrainingExecutionDefaults( ...
        params, classiObj, spec, intent)
%classifierApplyTrainingExecutionDefaults Apply training-compatible runtime defaults.

if nargin < 1 || isempty(params) || ~isstruct(params)
    params = struct();
end
if nargin < 4 || ~strcmpi(char(string(intent)), 'validate')
    return;
end
defaults = classifierTrainingExecutionDefaults(classiObj, spec);
if isempty(defaults) || ~isstruct(defaults) || ~isstruct(spec) || ...
        ~isfield(spec, 'staticKeys')
    return;
end
keys = intersect(cellstr(string(spec.staticKeys)), ...
    fieldnames(defaults), 'stable');
for i = 1:numel(keys)
    params.(keys{i}) = defaults.(keys{i});
end
end
