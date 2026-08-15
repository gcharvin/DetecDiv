function params = classifierApplyTrainingInputBindings(params, trainingParam, inputKeys)
%classifierApplyTrainingInputBindings  Import authoritative training inputs.
%
% Classifier execution defaults describe inference.  A classifier-scoped
% training run must instead use the channel roles saved in trainingParam,
% because those are the roles used to format the reviewed training dataset.

if nargin < 1 || isempty(params) || ~isstruct(params)
    params = struct();
end
if nargin < 2 || isempty(trainingParam) || ~isstruct(trainingParam)
    return;
end
if nargin < 3 || isempty(inputKeys)
    return;
end

inputKeys = cellstr(string(inputKeys));
for i = 1:numel(inputKeys)
    key = char(string(inputKeys{i}));
    if isempty(key) || ~isfield(trainingParam, key)
        continue;
    end
    params.(key) = selectedTrainingValue(trainingParam.(key));
end
end

function value = selectedTrainingValue(value)
% Choice parameters use {choice1,...,selectedChoice}; channel selectors are
% normally text, but accepting the same representation keeps this helper
% compatible with legacy classifier metadata.
while iscell(value)
    if isempty(value)
        value = '';
        return;
    end
    value = value{end};
end
if isstring(value) && isscalar(value)
    value = char(value);
end
end
