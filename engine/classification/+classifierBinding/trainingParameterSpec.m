function [spec,policy] = trainingParameterSpec(classif)
%CLASSIFIERBINDING.TRAININGPARAMETERSPEC Package-owned display metadata.
% Scientific/business logic stays in the classifier package. classifierGUI
% consumes only labels, help text, grouping, and optional choice labels.
spec = struct('param',{},'label',{},'group',{},'tip',{},'choiceLabels',{});
policy = struct('showUnspecified',true);
if nargin < 1 || isempty(classif), return; end
pkg = '';
try pkg = strtrim(char(string(classif.classifierPkg))); catch, end
if isempty(pkg), return; end
fun = [pkg '.trainingParameterSpec'];
if isempty(which(fun)), return; end
try
    if nargout(fun) == 2
        [raw,rawPolicy] = feval(fun,classif);
        if isstruct(rawPolicy) && isscalar(rawPolicy) && ...
                isfield(rawPolicy,'showUnspecified')
            policy.showUnspecified = logical(rawPolicy.showUnspecified);
        end
    else
        raw = feval(fun,classif);
    end
catch ME
    warning('classifierBinding:TrainingParameterSpec', ...
        'Could not read %s: %s',fun,ME.message);
    return;
end
if isempty(raw), return; end
required = {'param','label','group','tip'};
if ~isstruct(raw) || ~all(isfield(raw,required))
    warning('classifierBinding:InvalidTrainingParameterSpec', ...
        '%s must return a struct array with %s.',fun,strjoin(required,', '));
    return;
end
for i = 1:numel(raw)
    item = struct();
    item.param = strtrim(char(string(raw(i).param)));
    item.label = strtrim(char(string(raw(i).label)));
    item.group = strtrim(char(string(raw(i).group)));
    item.tip = strtrim(char(string(raw(i).tip)));
    item.choiceLabels = {};
    if isfield(raw,'choiceLabels') && ~isempty(raw(i).choiceLabels)
        item.choiceLabels = cellstr(string(raw(i).choiceLabels));
    end
    if isempty(item.param), continue; end
    spec(end+1) = item; %#ok<AGROW>
end
if numel(unique({spec.param})) ~= numel(spec)
    error('classifierBinding:DuplicateTrainingParameterSpec', ...
        '%s returned duplicate parameter metadata.',fun);
end
end
