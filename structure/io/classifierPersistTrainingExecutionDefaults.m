function file = classifierPersistTrainingExecutionDefaults(classiObj)
%classifierPersistTrainingExecutionDefaults Save post-training runtime state.

file = '';
if isempty(classiObj)
    return;
end
pathValue = '';
try
    pathValue = char(string(classiObj.path));
catch
end
if isempty(pathValue) || exist(pathValue, 'dir') ~= 7
    return;
end

spec = resolveExecutionSpec(classiObj);
defaults = classifierTrainingExecutionDefaults(classiObj, spec, false);
executionParam = struct();
try
    if isstruct(classiObj.executionParam)
        executionParam = classiObj.executionParam;
    end
catch
end
executionParam = retainDeployableKeys(executionParam, spec);
defaults = overlayStruct(defaults, executionParam);
defaults = normalizePackageDefaults(classiObj, defaults);
if isempty(fieldnames(defaults))
    return;
end

payload = struct();
payload.schemaVersion = 1;
payload.createdAt = char(datetime('now', 'TimeZone', 'UTC', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss.SSSXXX'));
try
    payload.classifierId = char(string(classiObj.strid));
catch
    payload.classifierId = '';
end
try
    payload.classifierPackage = classifierPackage(classiObj);
catch
    payload.classifierPackage = '';
end
payload.executionDefaults = defaults;

file = fullfile(pathValue, 'training_execution_defaults.json');
temporary = [tempname(pathValue) '.json'];
cleanup = onCleanup(@()deleteIfPresent(temporary));
fid = fopen(temporary, 'w');
if fid < 0
    error('classifierPersistTrainingExecutionDefaults:OpenFailed', ...
        'Could not create %s.', temporary);
end
closeFile = onCleanup(@()fclose(fid));
fwrite(fid, jsonencode(payload, 'PrettyPrint', true), 'char');
clear closeFile;
[ok, message] = movefile(temporary, file, 'f');
if ~ok
    error('classifierPersistTrainingExecutionDefaults:MoveFailed', ...
        'Could not publish %s: %s', file, message);
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
end
end

function pkg = classifierPackage(classiObj)
pkg = '';
try
    pkg = char(string(classiObj.classifierPkg));
catch
end
if ~isempty(pkg)
    return;
end
try
    fun = char(string(classiObj.trainingFun));
    dot = strfind(fun, '.');
    if ~isempty(dot), pkg = fun(1:dot(1)-1); end
catch
end
end

function out = retainDeployableKeys(out, spec)
if isempty(fieldnames(out)) || ~isstruct(spec)
    return;
end
declared = {};
% The snapshot is the authoritative deployable model description.  Keep
% canonical PRED output identities alongside its backend, inputs and
% artifacts so annotation discovery cannot fall back to stale legacy names
% from the in-memory classifier object.
fields = {'staticKeys','inputKeys','artifactKeys','outputKeys'};
for i = 1:numel(fields)
    if isfield(spec, fields{i})
        declared = [declared cellstr(string(spec.(fields{i})))]; %#ok<AGROW>
    end
end
if isempty(declared)
    return;
end
declared = unique(declared, 'stable');
excluded = {};
fields = {'environmentKeys'};
for i = 1:numel(fields)
    if isfield(spec, fields{i})
        excluded = [excluded cellstr(string(spec.(fields{i})))]; %#ok<AGROW>
    end
end
declared = setdiff(declared, unique(excluded, 'stable'), 'stable');
keep = intersect(fieldnames(out), declared, 'stable');
drop = setdiff(fieldnames(out), keep, 'stable');
if ~isempty(drop)
    out = rmfield(out, drop);
end
end

function out = overlayStruct(out, source)
keys = fieldnames(source);
for i = 1:numel(keys)
    out.(keys{i}) = source.(keys{i});
end
end

function deleteIfPresent(file)
if exist(file, 'file') == 2
    delete(file);
end
end

function defaults = normalizePackageDefaults(classiObj,defaults)
pkg=classifierPackage(classiObj);
if isempty(pkg),return;end
hook=[pkg '.normalizeTrainingExecutionDefaults'];
try
    if ~isempty(which(hook))
        defaults=feval(hook,classiObj,defaults);
    end
catch ME
    warning('classifierPersistTrainingExecutionDefaults:PackageNormalizationFailed', ...
        'Could not normalize %s execution defaults: %s',pkg,ME.message);
end
end
