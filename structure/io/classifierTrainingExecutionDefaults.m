function defaults = classifierTrainingExecutionDefaults(classiObj, spec, varargin)
%classifierTrainingExecutionDefaults Runtime defaults produced by training.
%
% A successful classifier training may change the deployable backend,
% artifact and compatible inference settings.  Those values are stored in a
% dedicated snapshot which cannot be overwritten by a stale classifier GUI.
% Package hooks provide migration defaults for trainings completed before
% the snapshot protocol existed.

readSnapshot = true;
if nargin >= 3 && ~isempty(varargin{1})
    readSnapshot = logical(varargin{1});
end
if nargin < 2 || isempty(spec) || ~isstruct(spec)
    spec = resolveExecutionSpec(classiObj);
end

defaults = genericCompatibleDefaults(classiObj, spec);
pkg = classifierPackage(classiObj);
if ~isempty(pkg)
    hook = [pkg '.trainingExecutionDefaults'];
    try
        if ~isempty(which(hook))
            defaults = overlayStruct(defaults, feval(hook, classiObj));
        end
    catch ME
        warning('classifierTrainingExecutionDefaults:PackageHookFailed', ...
            'Could not derive %s training execution defaults: %s', ...
            pkg, ME.message);
    end
end

if readSnapshot
    defaults = overlayStruct(defaults, readSnapshotDefaults(classiObj, pkg));
end
end

function defaults = genericCompatibleDefaults(classiObj, spec)
defaults = struct();
trainingParam = structProperty(classiObj, 'trainingParam');
if isempty(fieldnames(trainingParam)) || ~isstruct(spec)
    return;
end
keys = {};
if isfield(spec, 'staticKeys')
    keys = cellstr(string(spec.staticKeys));
end
for i = 1:numel(keys)
    key = keys{i};
    if isfield(trainingParam, key)
        defaults.(key) = selectedValue(trainingParam.(key));
    end
end
end

function defaults = readSnapshotDefaults(classiObj, pkg)
defaults = struct();
pathValue = classifierPath(classiObj);
if isempty(pathValue)
    return;
end
file = fullfile(pathValue, 'training_execution_defaults.json');
if exist(file, 'file') ~= 2
    return;
end
try
    payload = jsondecode(fileread(file));
    if isfield(payload, 'classifierPackage') && ~isempty(pkg) && ...
            ~strcmpi(char(string(payload.classifierPackage)), pkg)
        return;
    end
    if isfield(payload, 'classifierId')
        id = classifierId(classiObj);
        if ~isempty(id) && ~strcmp(char(string(payload.classifierId)), id)
            return;
        end
    end
    if isfield(payload, 'executionDefaults') && ...
            isstruct(payload.executionDefaults)
        defaults = payload.executionDefaults;
    end
catch ME
    warning('classifierTrainingExecutionDefaults:SnapshotReadFailed', ...
        'Could not read training execution snapshot %s: %s', file, ME.message);
end
end

function spec = resolveExecutionSpec(classiObj)
spec = struct();
pkg = classifierPackage(classiObj);
if isempty(pkg)
    return;
end
try
    spec = feval([pkg '.executionSpec'], classiObj);
catch
    try
        spec = feval([pkg '.executionSpec']);
    catch
        spec = struct();
    end
end
end

function value = selectedValue(value)
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

function out = overlayStruct(out, source)
if ~isstruct(source) || isempty(source)
    return;
end
keys = fieldnames(source);
for i = 1:numel(keys)
    out.(keys{i}) = source.(keys{i});
end
end

function value = structProperty(obj, name)
value = struct();
try
    candidate = obj.(name);
    if isstruct(candidate)
        value = candidate;
    end
catch
end
end

function value = classifierPath(obj)
value = '';
try
    value = char(string(obj.path));
catch
end
end

function value = classifierId(obj)
value = '';
try
    value = char(string(obj.strid));
catch
end
end

function pkg = classifierPackage(obj)
pkg = '';
try
    pkg = char(string(obj.classifierPkg));
catch
end
if ~isempty(pkg)
    return;
end
try
    fun = char(string(obj.trainingFun));
    dot = strfind(fun, '.');
    if ~isempty(dot), pkg = fun(1:dot(1)-1); end
catch
end
end
