function spec = trainingSpec(classif)
%CLASSIFIERBINDING.TRAININGSPEC Return normalized typed training bindings.
%
% Package classifiers opt in by exposing +pkg/trainingSpec.m.  The returned
% resource records deliberately follow the same vocabulary as pipeline
% resources (type, role, param, required), so frontends can render them
% without classifier-specific UI code.

spec = repmat(classifierBinding.newBinding(), 0, 1);
pkg = classifierPackage(classif);
if isempty(pkg)
    return;
end

fun = [pkg '.trainingSpec'];
if isempty(which(fun))
    return;
end

try
    raw = feval(fun, classif);
catch ME
    warning('classifierBinding:TrainingSpec', ...
        'Could not read %s: %s', fun, ME.message);
    return;
end
if isempty(raw) || ~isstruct(raw)
    return;
end

spec = repmat(classifierBinding.newBinding(), numel(raw), 1);
for i = 1:numel(raw)
    fields = fieldnames(spec(i));
    for j = 1:numel(fields)
        name = fields{j};
        if isfield(raw, name) && ~isempty(raw(i).(name))
            spec(i).(name) = raw(i).(name);
        end
    end
    spec(i).param = char(string(spec(i).param));
    spec(i).type = char(string(spec(i).type));
    spec(i).role = char(string(spec(i).role));
    spec(i).label = char(string(spec(i).label));
    spec(i).tip = char(string(spec(i).tip));
    spec(i).group = char(string(spec(i).group));
    spec(i).storage = char(string(spec(i).storage));
    spec(i).cardinality = char(string(spec(i).cardinality));
    spec(i).componentId = char(string(spec(i).componentId));
    spec(i).legacyFallback = char(string(spec(i).legacyFallback));
    spec(i).autoValue = char(string(spec(i).autoValue));
    spec(i).quality = lower(char(string(spec(i).quality)));
    spec(i).semantic = char(string(spec(i).semantic));
    spec(i).required = logical(spec(i).required);
    spec(i).allowAuto = logical(spec(i).allowAuto);
    spec(i).allowNone = logical(spec(i).allowNone);
    spec(i).editable = logical(spec(i).editable);
    if ~any(strcmp(spec(i).quality,{'input','gt','pred','derived'}))
        error('classifierBinding:InvalidTrainingQuality', ...
            '%s declares unsupported quality "%s" for %s.', ...
            fun,spec(i).quality,spec(i).param);
    end
end
spec = spec(~cellfun(@isempty, {spec.param}));
end

function pkg = classifierPackage(classif)
pkg = '';
try
    pkg = char(string(classif.classifierPkg));
catch
end
if ~isempty(strtrim(pkg))
    pkg = strtrim(pkg);
    return;
end
for property = {'trainingFun','classifyFun'}
    try
        value = char(string(classif.(property{1})));
        dot = strfind(value, '.');
        if ~isempty(dot)
            pkg = value(1:dot(1)-1);
            return;
        end
    catch
    end
end
end
