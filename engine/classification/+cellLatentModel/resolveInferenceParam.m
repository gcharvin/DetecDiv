function p = resolveInferenceParam(classif, ctx)
%CELLLATENTMODEL.RESOLVEINFERENCEPARAM Resolve one immutable inference view.
%
% Normal pipeline calls load the classifier-owned active-model snapshot and
% continue to reject artifact paths supplied through ctx.params.  The
% prediction-assisted annotation service is the sole exception: it resolves
% the active snapshot once before starting its multi-ROI run and places that
% complete, per-ROI parameter view in
% ctx.annotationPrediction.activeModelSnapshot.  In that explicit context
% this function consumes the pinned view directly and never re-reads the
% on-disk snapshot between ROIs.

if nargin < 2 || isempty(ctx), ctx = struct(); end
defaults = cellLatentModel.utils.defaultExecutionParam();

[pinned, requested] = pinnedAnnotationSnapshot(ctx);
if requested
    validatePinnedAnnotationSnapshot(pinned, classif);
    p = cellLatentModel.utils.applyOverrides(defaults, pinned.parameters);
    return;
end

p = defaults;
try
    p = cellLatentModel.utils.applyOverrides(p, classif.executionParam);
catch
end
execution = cellLatentModel.executionSpec(classif);
p = classifierApplyTrainingExecutionDefaults( ...
    p, classif, execution, 'active_model');
if isfield(ctx, 'params') && isstruct(ctx.params)
    runtime = ctx.params;
    % Artifact identity belongs to the classifier deployment snapshot.  A
    % normal pipeline runtime may select channels and static controls, but
    % it cannot redirect a trained model to arbitrary files.
    protected = {'modelPath','modelSource','compositeManifestPath', ...
        'trackingCheckpointDir','stateRuntimeConfigPath', ...
        'adaptiveMarkerModelPath','adaptiveMarkerModelSource', ...
        'modelUpdatePolicy','modelReleaseChannelPath', ...
        'resolvedModelReleaseId','resolvedModelReleaseManifestPath'};
    protected = protected(isfield(runtime, protected));
    if ~isempty(protected), runtime = rmfield(runtime, protected); end
    p = cellLatentModel.utils.applyOverrides(p, runtime);
end
end

function [snapshot, requested] = pinnedAnnotationSnapshot(ctx)
snapshot = struct();
requested = false;
if ~isstruct(ctx) || ~isfield(ctx, 'annotationPrediction') || ...
        ~isstruct(ctx.annotationPrediction)
    return;
end
annotation = ctx.annotationPrediction;
if ~isfield(annotation, 'usePinnedActiveModel') || ...
        ~logicalScalar(annotation.usePinnedActiveModel, false)
    return;
end
requested = true;
if isfield(annotation, 'activeModelSnapshot') && ...
        isstruct(annotation.activeModelSnapshot) && ...
        isscalar(annotation.activeModelSnapshot)
    snapshot = annotation.activeModelSnapshot;
end
end

function validatePinnedAnnotationSnapshot(snapshot, classif)
identifier = 'cellLatentModel:InvalidPinnedAnnotationSnapshot';
if ~isstruct(snapshot) || ~isscalar(snapshot) || ...
        ~isfield(snapshot, 'schemaVersion') || ...
        double(snapshot.schemaVersion) ~= 1 || ...
        ~strcmpi(textField(snapshot, 'intent'), 'predict_for_annotation') || ...
        ~isfield(snapshot, 'parameters') || ...
        ~isstruct(snapshot.parameters) || ~isscalar(snapshot.parameters)
    error(identifier, ...
        'The annotation active-model snapshot is missing or malformed.');
end

classifierId = '';
try, classifierId = char(string(classif.strid)); catch, end
if isempty(classifierId) || ...
        ~strcmp(textField(snapshot, 'classifierId'), classifierId)
    error(identifier, ...
        'The pinned annotation snapshot belongs to a different classifier.');
end
package = '';
try, package = char(string(classif.classifierPkg)); catch, end
if isempty(package)
    try
        fun = char(string(classif.classifyFun));
        dot = strfind(fun, '.');
        if ~isempty(dot), package = fun(1:dot(1)-1); end
    catch
    end
end
if ~strcmpi(textField(snapshot, 'package'), package) || ...
        ~strcmpi(package, 'cellLatentModel')
    error(identifier, ...
        'The pinned annotation snapshot has an invalid classifier package.');
end
if ~isfield(snapshot, 'usesGroundTruth') || ...
        logicalScalar(snapshot.usesGroundTruth, true)
    error(identifier, ...
        'A pinned annotation snapshot must explicitly declare GT-free inference.');
end

params = snapshot.parameters;
if isfield(snapshot, 'backend') && ...
        ~strcmpi(textField(snapshot, 'backend'), textField(params, 'backend'))
    error(identifier, ...
        'The pinned backend does not match its parameter payload.');
end
if isfield(snapshot, 'modelSource') && ...
        ~strcmpi(textField(snapshot, 'modelSource'), textField(params, 'modelSource'))
    error(identifier, ...
        'The pinned model source does not match its parameter payload.');
end
verifyPinnedArtifacts(snapshot, params, identifier);
end

function verifyPinnedArtifacts(snapshot, params, identifier)
if ~isfield(snapshot, 'artifactStatus') || ...
        ~isstruct(snapshot.artifactStatus)
    return;
end
keys = {'modelPath','compositeManifestPath','trackingCheckpointDir', ...
    'stateRuntimeConfigPath'};
for i = 1:numel(keys)
    key = keys{i};
    if ~isfield(snapshot.artifactStatus, key), continue; end
    entry = snapshot.artifactStatus.(key);
    expected = '';
    if isstruct(entry), expected = textField(entry, 'path'); end
    actual = textField(params, key);
    if ~isempty(expected) && ~samePath(expected, actual)
        error(identifier, ...
            'Pinned artifact "%s" does not match its audited path.', key);
    end
end
end

function tf = samePath(a, b)
a = strrep(strtrim(char(string(a))), '/', filesep);
b = strrep(strtrim(char(string(b))), '/', filesep);
if ispc
    tf = strcmpi(a, b);
else
    tf = strcmp(a, b);
end
end

function value = textField(source, key)
value = '';
try
    if isstruct(source) && isfield(source, key)
        raw = source.(key);
        while iscell(raw)
            if isempty(raw), return; end
            raw = raw{end};
        end
        value = strtrim(char(string(raw)));
    end
catch
    value = '';
end
end

function value = logicalScalar(raw, fallback)
value = logical(fallback);
try
    if islogical(raw) || isnumeric(raw)
        value = logical(raw(1));
    else
        value = any(strcmpi(strtrim(char(string(raw))), ...
            {'1','true','yes','on'}));
    end
catch
    value = logical(fallback);
end
end
