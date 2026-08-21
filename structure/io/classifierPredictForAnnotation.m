function report = classifierPredictForAnnotation(classif, roiIndices, varargin)
%CLASSIFIERPREDICTFORANNOTATION Predict ROI content and optionally seed GT.
%
% This service is deliberately independent from Pipeline2 and from the
% classifier train/validation/test split.  It runs the classifier attached
% to CLASSIF on the explicitly requested ROI indices, discovers the
% resulting PRED assets through the annotation contract, and can clone them
% into editable Draft GT in the same operation.
%
%   plan = classifierPredictForAnnotation(classif, indices, ...
%       'PlanOnly', true)
%   run = classifierPredictForAnnotation(classif, indices, ...
%       'InitializeGT', true, 'OverwriteGT', false)
%
% Options
%   PlanOnly         Resolve model and typed inputs without writing data.
%   InitializeGT     Clone each successful prediction into editable GT.
%   OverwriteGT      Permit replacement of existing Draft/Ready GT.
%   Save             Persist prediction/GT outputs (default true).
%   InputOverrides   Scalar struct, or one struct per ROI, using selector
%                    names such as instanceChannelName.
%   Progress         uiprogressdlg-compatible handle passed to classifyData.
%   ProgressCallback Callback accepting a detecdiv.progress.v1 payload.
%   Ctx              Additional classifier execution context.
%   RunId            Optional logical run identifier.  The physical run
%                    folder remains managed by classi.runStart.
%   Executor         Test/integration injection. The default invokes
%                    classi.classifyData directly.
% The cellLatentModel planner never selects a GT channel as an inference
% input.  It also never runs a segmenter: an eligible non-GT instance-mask
% channel must already exist on every selected ROI.  Segmentation remains
% an explicit, separate pipeline/classifier operation.


opts = parseOptions(varargin{:});
validateClassifier(classif);
indices = normalizeIndices(roiIndices, numel(classif.roi));
if isempty(indices)
    error('classifierPredictForAnnotation:NoRoi', ...
        'Select at least one valid classifier ROI index.');
end

package = classifierPackage(classif);
if ~strcmpi(package, 'cellLatentModel')
    error('classifierPredictForAnnotation:UnsupportedClassifier', ...
        ['Direct prediction-assisted GT initialization is currently ' ...
         'implemented for cellLatentModel classifiers, not "%s".'], package);
end

spec = annotationManager.specForClassifier(classif);
[baseParams, model] = effectiveParameters(classif, package);
items = repmat(emptyItem(), numel(indices), 1);
issues = strings(0,1);
for i = 1:numel(indices)
    override = overrideForItem(opts.InputOverrides, i, numel(indices));
    items(i) = planItem(classif, indices(i), spec, baseParams, override);
    if ~items(i).canRun
        issues = [issues; "ROI " + string(items(i).roiId) + ": " + ...
            string(items(i).issues(:))]; %#ok<AGROW>
    end
end

requestedRunId = cleanRunId(opts.RunId, classif);
reportAvailable = model.available && all([items.available]);
reportCanRun = model.available && all([items.canRun]);
requiresPreparation = false;
reportCanPrepare = false;
usesGroundTruth = false;
for i = 1:numel(items)
    try
        usesGroundTruth = usesGroundTruth || ...
            logical(items(i).inputs.usesGroundTruth);
    catch
    end
end
if usesGroundTruth
    reportAvailable = false;
    reportCanRun = false;
    reportCanPrepare = false;
    issues = ["Ground-truth input use was detected and blocked."; issues];
end
if ~model.available
    issues = [string(model.issues(:)); issues];
end
report = struct( ...
    'schemaVersion', 1, ...
    'operation', 'predict_for_annotation', ...
    'planOnly', logical(opts.PlanOnly), ...
    'available', reportAvailable, ...
    'canRun', reportCanRun, ...
    'canPrepare', reportCanPrepare, ...
    'requiresPreparation', requiresPreparation, ...
    'usesGroundTruth', usesGroundTruth, ...
    'classifierId', char(string(classif.strid)), ...
    'roiIndices', indices, ...
    'requestedRunId', requestedRunId, ...
    'runId', '', ...
    'runDir', '', ...
    'model', model, ...
    'issues', {cellstr(issues)}, ...
    'items', {items}, ...
    'startedAt', '', ...
    'finishedAt', '', ...
    'status', 'planned');

if opts.PlanOnly
    return;
end
if ~report.canRun
    error('classifierPredictForAnnotation:InputsNotReady', ...
        'Prediction inputs are not ready:%s%s', newline, ...
        strjoin(report.issues, newline));
end
try
    if isstruct(classif.run) && isfield(classif.run, 'active') && ...
            logical(classif.run.active)
        error('classifierPredictForAnnotation:ClassifierBusy', ...
            ['The classifier already owns an active run. Finish or cancel ' ...
             'that run before starting annotation prediction.']);
    end
catch ME
    if strcmp(ME.identifier, 'classifierPredictForAnnotation:ClassifierBusy')
        rethrow(ME);
    end
end

runState = struct();
runStarted = false;
report.startedAt = timestamp();
try
    runState = classif.runStart('classifierPredictForAnnotation', ...
        struct('roiIndices', indices, 'runId', requestedRunId, ...
        'usesGroundTruth', false), 'Tag', 'annotation_prediction');
    runStarted = true;
    report.runDir = char(string(runState.runDirAbs));
    report.runId = runLeaf(runState, requestedRunId);
    emitProgress(opts, 0, 'Preparing prediction-assisted annotation', 0, numel(items));

    % Phase 1: run the active latent model for every selected ROI.  All
    % predictions must succeed before any editable GT is created.
    for i = 1:numel(items)
        item = report.items(i);
        ctx = executionContext(opts, item, report, i, numel(items));
        emitProgress(opts, 0.85 * (i-1)/numel(items), ...
            sprintf('Predicting ROI %d/%d', i, numel(items)), i-1, numel(items));
        item.status = 'predicting';
        report.items(i) = item;
        try
            executeOne(classif, classif.roi(item.roiIndex), item, ctx, opts);
        catch ME
            item.status = 'prediction_failed';
            report.items(i) = item;
            rethrow(ME);
        end

        % Reload discovery from the persisted PRED family.  This is the
        % authoritative boundary between inference and editable GT.
        session = annotationManager.createSession(classif, item.roiIndex);
        catalog = session.initializationCatalog();
        [recipe, prediction] = predictionRecipe(catalog);
        item.catalog = catalog;
        item.recipe = recipe;
        item.predictionFamily = prediction.family;
        item.predictionChannel = prediction.maskProvider;
        item.provenance = struct( ...
            'quality', 'pred', ...
            'producer', package, ...
            'runId', report.runId, ...
            'model', model, ...
            'inputs', item.inputs);
        stampPredictionProvenance(classif.roi(item.roiIndex), report, item, opts.Save);
        item.status = 'predicted';
        report.items(i) = item;
    end

    % Phase 2: only after every latent inference succeeded do
    % we cross the PRED -> editable Draft GT boundary.
    if opts.InitializeGT
        snapshots = captureGtStates(classif, report.items);
        trainingParamBefore = classif.trainingParam;
        try
            % Stage every clone in memory first.  A clone/provider failure
            % on any ROI therefore cannot leave GT on earlier ROIs.
            for i = 1:numel(items)
                item = report.items(i);
                session = annotationManager.createSession(classif, item.roiIndex);
                item.initializationReport = session.initialize(item.recipe, ...
                    'Overwrite', opts.OverwriteGT, 'Save', false, ...
                    'SourceRunId', report.runId);
                item.status = 'draft_initialized';
                report.items(i) = item;
            end
            if opts.Save
                persistStagedGt(classif, report.items);
            end
        catch ME
            restoreGtStates(classif, snapshots, trainingParamBefore);
            rethrow(ME);
        end
    end

    report.finishedAt = timestamp();
    report.status = 'ok';
    report.available = true;
    report.canRun = true;
    try, classif.runJson('prediction_for_annotation.json', serializableReport(report)); catch, end
    emitProgress(opts, 1, 'Prediction-assisted annotation ready', numel(items), numel(items));
catch ME
    report.finishedAt = timestamp();
    report.status = 'failed';
    try
        if runStarted
            classif.runMsg('Prediction-assisted annotation failed: %s', ME.message);
            classif.runJson('prediction_for_annotation_failed.json', ...
                serializableReport(report));
        end
    catch
    end
    if runStarted, try, classif.runStop(); catch, end, end
    rethrow(ME);
end
if runStarted, classif.runStop(); end
end

function opts = parseOptions(varargin)
p = inputParser;
p.FunctionName = 'classifierPredictForAnnotation';
p.addParameter('PlanOnly', false, @(x)islogical(x) && isscalar(x));
p.addParameter('InitializeGT', false, @(x)islogical(x) && isscalar(x));
p.addParameter('OverwriteGT', false, @(x)islogical(x) && isscalar(x));
p.addParameter('Save', true, @(x)islogical(x) && isscalar(x));
p.addParameter('InputOverrides', struct(), @isstruct);
p.addParameter('Progress', [], @(x)true);
p.addParameter('ProgressCallback', [], @(x)isempty(x) || isa(x,'function_handle'));
p.addParameter('Ctx', struct(), @(x)isstruct(x) && isscalar(x));
p.addParameter('RunId', '', @(x)ischar(x) || (isstring(x) && isscalar(x)));
p.addParameter('Executor', [], @(x)isempty(x) || isa(x,'function_handle'));
p.parse(varargin{:});
opts = p.Results;
end

function validateClassifier(classif)
if isempty(classif) || ~isa(classif, 'classi')
    error('classifierPredictForAnnotation:InvalidClassifier', ...
        'Expected a classi object.');
end
if isempty(classif.roi) || ...
        (isscalar(classif.roi) && isempty(classif.roi(1).id))
    error('classifierPredictForAnnotation:NoRoi', ...
        'The classifier has no attached ROI.');
end
end

function indices = normalizeIndices(value, count)
if islogical(value), value = find(value(:).'); end
if ischar(value) || isstring(value)
    text = strtrim(char(string(value)));
    if strcmpi(text, 'all'), value = 1:count;
    else, value = str2num(text); %#ok<ST2NM>
    end
end
if isempty(value) || ~isnumeric(value), indices = []; return; end
value = round(double(value(:).'));
indices = unique(value(isfinite(value) & value >= 1 & value <= count), 'stable');
end

function package = classifierPackage(classif)
package = '';
try, package = strtrim(char(string(classif.classifierPkg))); catch, end
if ~isempty(package), return; end
try
    fun = char(string(classif.classifyFun));
    dot = strfind(fun, '.');
    if ~isempty(dot), package = fun(1:dot(1)-1); end
catch
end
end

function [params, model] = effectiveParameters(classif, package)
execution = feval([package '.executionSpec'], classif);
params = execution.defaults;
try
    if isstruct(classif.executionParam)
        params = overlay(params, classif.executionParam);
    end
catch
end
params = classifierApplyTrainingExecutionDefaults( ...
    params, classif, execution, 'annotation');
status = artifactStatus(params, classif);
% Pin canonical absolute artifact paths now.  Every ROI in this operation
% receives this same resolved deployment view; no execution callback needs
% to consult the mutable on-disk snapshot again.
artifactKeys = fieldnames(status);
for i = 1:numel(artifactKeys)
    key = artifactKeys{i};
    if isfield(params, key) && ~isempty(status.(key).path)
        params.(key) = status.(key).path;
    end
end
[available, issues] = modelAvailability(params, status);
model = struct( ...
    'classifierId', char(string(classif.strid)), ...
    'package', package, ...
    'classifyFun', char(string(classif.classifyFun)), ...
    'backend', textField(params, 'backend'), ...
    'modelSource', textField(params, 'modelSource'), ...
    'modelPath', status.modelPath.path, ...
    'compositeManifestPath', status.compositeManifestPath.path, ...
    'trackingCheckpointDir', status.trackingCheckpointDir.path, ...
    'stateUpdateMode', textField(params, 'stateUpdateMode'), ...
    'stateRuntimeConfigPath', status.stateRuntimeConfigPath.path, ...
    'resolvedAt', timestamp(), ...
    'artifactStatus', status, ...
    'available', available, ...
    'issues', {issues});
end

function [available, issues] = modelAvailability(params, status)
issues = {};
backend = lower(textField(params, 'backend'));
modelSource = lower(textField(params, 'modelSource'));
switch backend
    case 'causal_composite'
        issues = requireArtifact(issues, status, 'compositeManifestPath', ...
            'The active composite manifest is missing.');
        issues = requireArtifact(issues, status, 'trackingCheckpointDir', ...
            'The active EDGE/APPEAR/END checkpoint is missing.');
        issues = requireArtifact(issues, status, 'modelPath', ...
            'The active mother/NULL checkpoint is missing.');
        if strcmpi(textField(params, 'stateUpdateMode'), 'promoted_frozen_bf')
            issues = requireArtifact(issues, status, 'stateRuntimeConfigPath', ...
                'The active biological-state runtime is missing.');
        end
    case 'continuous_cell_state'
        issues = requireArtifact(issues, status, 'modelPath', ...
            'The active continuous cell-state checkpoint is missing.');
    case 'legacy'
        if strcmp(modelSource, 'trained')
            issues = requireArtifact(issues, status, 'modelPath', ...
                'The active trained lineage checkpoint is missing.');
        end
end
available = isempty(issues);
end

function issues = requireArtifact(issues, status, key, message)
entry = status.(key);
if isempty(entry.path) || ~entry.exists
    issues{end+1} = message; %#ok<AGROW>
end
end

function status = artifactStatus(params, classif)
status = struct();
for name = {'modelPath','compositeManifestPath','trackingCheckpointDir', ...
        'stateRuntimeConfigPath'}
    key = name{1};
    value = textField(params, key);
    value = resolveRelative(value, classif.path);
    exists = isempty(value) || isfile(value) || isfolder(value);
    if strcmp(key, 'trackingCheckpointDir') && ~isempty(value)
        exists = isfile(fullfile(value, 'manifest.json'));
    end
    status.(key) = struct('path', value, 'exists', logical(exists));
end
end

function item = planItem(classif, index, spec, baseParams, override)
roiObj = classif.roi(index);
channels = annotationManager.availableChannels(roiObj);
forbidden = globalGroundTruthChannels(roiObj, spec, channels);
rejectGroundTruthOverrides(override, forbidden);
params = baseParams;
ownOutputTrackNames = nonempty({textField(baseParams, ...
    'outputTrackChannelName')});
try
    ownOutputTrackNames = [ownOutputTrackNames nonempty({ ...
        textField(classif.executionParam, 'outputTrackChannelName')})]; %#ok<AGROW>
catch
end
try
    ownOutputTrackNames = [ownOutputTrackNames nonempty({ ...
        textField(classif.trainingParam, 'outputTrackChannelName')})]; %#ok<AGROW>
catch
end
ownOutputTrackNames = unique(ownOutputTrackNames, 'stable');
observationChannelNames = nonempty({ ...
    selectorOverride(override, 'brightfieldChannelName'), ...
    selectorOverride(override, 'gfpChannelName'), ...
    selectorOverride(override, 'nucleusChannelName'), ...
    selectorOverride(override, 'budneckChannelName'), ...
    configuredSelector(classif, baseParams, 'brightfieldChannelName'), ...
    configuredSelector(classif, baseParams, 'gfpChannelName'), ...
    configuredSelector(classif, baseParams, 'nucleusChannelName'), ...
    configuredSelector(classif, baseParams, 'budneckChannelName')});
observationChannelNames = observationChannelNames( ...
    ~cellfun(@isNone, observationChannelNames));
[instance, instanceResolution] = resolveInstanceChannel( ...
    roiObj, channels, forbidden, selectorOverride(override, 'instanceChannelName'), ...
    configuredSelector(classif, baseParams, 'instanceChannelName'), ...
    ownOutputTrackNames, observationChannelNames);
[brightfield, bfResolution] = resolveObservationChannel( ...
    channels, forbidden, instance, selectorOverride(override, 'brightfieldChannelName'), ...
    configuredSelector(classif, baseParams, 'brightfieldChannelName'), ...
    {'channel1_z2','brightfield','bright','phase','bf'});
[nucleus, nucleusResolution] = resolveObservationChannel( ...
    channels, forbidden, instance, selectorOverride(override, 'nucleusChannelName'), ...
    configuredSelector(classif, baseParams, 'nucleusChannelName'), ...
    {'nucleus','nuclear','htb','dapi'});
[budneck, budneckResolution] = resolveObservationChannel( ...
    channels, forbidden, instance, selectorOverride(override, 'budneckChannelName'), ...
    configuredSelector(classif, baseParams, 'budneckChannelName'), ...
    {'budneck','bud_neck','myo'});

directInstanceAvailable = ~isempty(instance) && ~instanceResolution.ambiguous;
instanceResolution.required = true;
bfResolution.required = strcmpi(textField(params, 'stateUpdateMode'), ...
    'promoted_frozen_bf');
nucleusResolution.required = false;
budneckResolution.required = false;

params.instanceChannelName = instance;
params.brightfieldChannelName = brightfield;
params.nucleusChannelName = nucleus;
params.budneckChannelName = budneck;
params.gfpChannelName = '';
required = unique(nonempty({instance, brightfield, nucleus, budneck}), 'stable');
usesGroundTruth = anyGroundTruthResource(required, forbidden);
resolution = struct('instanceChannelName', instanceResolution, ...
    'brightfieldChannelName', bfResolution, ...
    'nucleusChannelName', nucleusResolution, ...
    'budneckChannelName', budneckResolution);
inputs = struct( ...
    'instanceChannelName', instance, ...
    'brightfieldChannelName', brightfield, ...
    'nucleusChannelName', nucleus, ...
    'budneckChannelName', budneck, ...
    'requiredChannels', {required}, ...
    'forbiddenGroundTruthChannels', {forbidden}, ...
    'usesGroundTruth', usesGroundTruth, ...
    'resolution', resolution);

issues = strings(0,1);
if usesGroundTruth
    issues(end+1) = "A resolved inference input is a ground-truth resource."; %#ok<AGROW>
end
if strcmp(instanceResolution.strategy, 'unsafe_override_rejected')
    issues(end+1) = ...
        "The requested instance-channel override is not a safe existing mask/track resource."; %#ok<AGROW>
end
if isempty(instance)
    missingMaskMessage = sprintf('%s%s%s', ...
        'No existing non-GT frame-local instance-mask channel is available. ', ...
        'Run CellposeSAM (or another segmentation/tracking classifier) separately ', ...
        'on this ROI, click Refresh status, then reopen Initialize GT.');
    issues(end+1,1) = string(missingMaskMessage); %#ok<AGROW>
elseif any(strcmpi(forbidden, instance))
    issues(end+1) = "The resolved instance input is a GT channel."; %#ok<AGROW>
end
if instanceResolution.ambiguous
    issues(end+1) = "Several equally ranked instance-mask inputs are available."; %#ok<AGROW>
end
if strcmpi(textField(params, 'stateUpdateMode'), 'promoted_frozen_bf') && ...
        isempty(brightfield)
    issues(end+1) = "The active promoted BF state component requires a brightfield input."; %#ok<AGROW>
end
ctx = struct('params', params, 'io', struct('requiredChannels', {required}));
try
    cellLatentModel.normalizeParam(params, ctx, classif);
catch ME
    issues(end+1) = string(ME.message); %#ok<AGROW>
end

item = emptyItem();
item.roiIndex = index;
item.roiId = char(string(roiObj.id));
item.available = directInstanceAvailable && isempty(issues);
item.canPrepare = false;
item.canRun = item.available;
item.requiresPreparation = false;
item.issues = cellstr(unique(issues, 'stable'));
item.inputs = inputs;
item.params = params;
item.status = 'planned';
end

function [selected, resolution] = resolveInstanceChannel(roiObj, channels, forbidden, override, configured, outputTrackNames, observationChannelNames)
candidates = maskCandidates(roiObj, channels, forbidden, ...
    outputTrackNames, observationChannelNames);
selected = '';
strategy = '';
ambiguous = false;
if ~isempty(override)
    selected = availableName(candidates, override);
    if isempty(selected) && ~isempty(availableName(channels, override))
        strategy = 'unsafe_override_rejected';
    else
        strategy = 'user_override';
    end
elseif ~isempty(availableName(candidates, 'results_cellposeSAM_cell'))
    selected = availableName(candidates, 'results_cellposeSAM_cell');
    strategy = 'preferred_cellposesam_prediction';
elseif ~isempty(configured) && ~any(strcmpi(forbidden, configured)) && ...
        ~isempty(availableName(candidates, configured))
    selected = availableName(candidates, configured);
    strategy = 'configured_non_gt';
elseif numel(candidates) == 1
    selected = candidates{1};
    strategy = 'single_compatible_prediction';
elseif numel(candidates) > 1
    scores = cellfun(@maskScore, candidates);
    best = find(scores == max(scores));
    if numel(best) == 1
        selected = candidates{best};
        strategy = 'ranked_prediction';
    else
        ambiguous = true;
        strategy = 'ambiguous';
    end
end
if ~isempty(selected) && any(strcmpi(forbidden, selected))
    selected = '';
    strategy = 'gt_rejected';
end
resolution = resolutionRecord(selected, strategy, candidates, ambiguous);
end

function candidates = maskCandidates(roiObj, channels, forbidden, ...
        outputTrackNames, observationChannelNames)
candidates = {};
outputNames = nonempty(outputTrackNames);
physicalNames = cellfun(@physicalTrackName, outputNames, ...
    'UniformOutput', false);
outputNames = unique([outputNames physicalNames], 'stable');
indexed = false(size(channels));
try
    displayChannels = cellstr(string(roiObj.display.channel));
    flags = logical(roiObj.display.indexed);
    for i = 1:numel(channels)
        hit = find(strcmpi(displayChannels, channels{i}), 1);
        if ~isempty(hit) && hit <= numel(flags), indexed(i) = flags(hit); end
    end
catch
end
for i = 1:numel(channels)
    name = channels{i};
    lowerName = lower(name);
    evidentRaw = isEvidentRawImageChannel(name);
    continuousPrediction = isContinuousPredictionChannel(name);
    likely = ~evidentRaw && ~continuousPrediction && (indexed(i) || ...
        startsWith(lowerName, 'results_') || ...
        contains(lowerName, 'cellpose') || contains(lowerName, 'mask') || ...
        contains(lowerName, 'segment'));
    % Only the current latent model's own track output is unsafe here: it
    % would feed a previous latent prediction back into the same model.
    % Tracks/masks produced by another explicit upstream module (for
    % example Trackastra) are legitimate existing inputs.
    ownLatentPrediction = any(strcmpi(outputNames, name));
    if likely && ~any(strcmpi(forbidden, name)) && ...
            ~any(strcmpi(observationChannelNames, name)) && ...
            ~ownLatentPrediction && ...
            ~startsWith(lowerName, 'gt_') && ...
            maskChannelHasContentWhenLoaded(roiObj, name)
        candidates{end+1} = name; %#ok<AGROW>
    end
end
candidates = unique(candidates, 'stable');
end

function tf = isEvidentRawImageChannel(name)
% An indexed display flag can be stale or user-controlled.  Never let it
% promote channels whose names clearly describe raw microscopy images.
token = regexprep(lower(strtrim(char(string(name)))), '[^a-z0-9]+', '_');
token = regexprep(token, '^_+|_+$', '');

% Explicit mask/track producer names remain eligible even if they also
% contain a biological marker token (for example results_nucleus_mask).
explicitMaskOrTrack = startsWith(token, 'results_') && ...
    any(contains(token, {'cellpose','trackastra','segment','mask', ...
    'instance','track'}));
if explicitMaskOrTrack
    tf = false;
    return;
end

if ~isempty(regexp(token, '^(channel|ch|c)\d+(_z\d+)?$', 'once')) || ...
        any(strcmp(token, {'combinedchannel','combined_channel', ...
        'brightfield','bright_field','bf','phase','phase_contrast', ...
        'phasecontrast','gfp','rfp','cfp','yfp','marker','dic','tl', ...
        'transmitted_light','transmittedlight','raw'}))
    tf = true;
    return;
end

parts = regexp(token, '_', 'split');
rawTokens = {'brightfield','bf','phase','gfp','rfp','cfp','yfp', ...
    'marker','fluorescence','myo1','htb2','dapi','dic','tl','raw'};
tf = any(ismember(parts, rawTokens));
end

function tf = isContinuousPredictionChannel(name)
% Probability/confidence/flow maps are continuous evidence, never integer
% instance identities, even when their display happens to be indexed.
token = regexprep(lower(strtrim(char(string(name)))), '[^a-z0-9]+', '_');
parts = regexp(regexprep(token, '^_+|_+$', ''), '_', 'split');
continuousTokens = {'probability','prob','score','confidence', ...
    'logit','logits','flow','distance','heatmap'};
tf = any(ismember(parts, continuousTokens));
end

function name = physicalTrackName(name)
name = strtrim(char(string(name)));
if isempty(name), return; end
if ~startsWith(name, 'results_', 'IgnoreCase', true)
    name = ['results_' name];
end
end

function score = maskScore(name)
value = lower(char(string(name)));
score = 0;
if startsWith(value, 'results_'), score = score + 20; end
if contains(value, 'cellposesam'), score = score + 20; end
if contains(value, 'cellpose'), score = score + 10; end
if contains(value, 'cell'), score = score + 2; end
end

function [selected, resolution] = resolveObservationChannel(channels, forbidden, instance, override, configured, patterns)
selected = '';
strategy = 'not_used';
candidates = {};
ambiguous = false;
if ~isempty(override) && ~isNone(override)
    selected = availableName(channels, override);
    strategy = 'user_override';
elseif isNone(override)
    strategy = 'user_disabled';
elseif ~isempty(configured) && ~any(strcmpi(forbidden, configured)) && ...
        ~strcmpi(configured, instance) && ~isempty(availableName(channels, configured))
    selected = availableName(channels, configured);
    strategy = 'configured';
else
    for i = 1:numel(channels)
        name = channels{i};
        if any(strcmpi(forbidden, name)) || strcmpi(instance, name), continue; end
        token = lower(regexprep(name, '[^a-z0-9]+', '_'));
        if any(cellfun(@(x)contains(token, lower(x)), patterns))
            candidates{end+1} = name; %#ok<AGROW>
        end
    end
    candidates = unique(candidates, 'stable');
    if numel(candidates) == 1
        selected = candidates{1};
        strategy = 'single_typed_candidate';
    elseif numel(candidates) > 1
        exact = find(strcmpi(candidates, patterns{1}));
        if numel(exact) == 1
            selected = candidates{exact};
            strategy = 'preferred_typed_candidate';
        else
            ambiguous = true;
            strategy = 'ambiguous_optional';
        end
    end
end
if ~isempty(selected) && (any(strcmpi(forbidden, selected)) || strcmpi(instance, selected))
    selected = '';
    strategy = 'unsafe_rejected';
end
resolution = resolutionRecord(selected, strategy, candidates, ambiguous);
end

function record = resolutionRecord(selected, strategy, candidates, ambiguous)
record = struct('selected', selected, 'strategy', strategy, ...
    'candidates', {candidates}, 'ambiguous', logical(ambiguous), ...
    'required', false);
end

function value = configuredSelector(classif, params, key)
value = textField(params, key);
try
    tp = classif.trainingParam;
    if isempty(value) && isstruct(tp) && isfield(tp, key)
        value = selectedText(tp.(key));
    end
catch
end
end

function value = selectorOverride(overrides, key)
value = '';
if isstruct(overrides) && isscalar(overrides) && isfield(overrides, key)
    value = selectedText(overrides.(key));
end
end

function override = overrideForItem(overrides, index, count)
if isempty(overrides), override = struct(); return; end
if isscalar(overrides), override = overrides; return; end
if numel(overrides) ~= count
    error('classifierPredictForAnnotation:InvalidInputOverrides', ...
        'InputOverrides must be scalar or contain one struct per selected ROI.');
end
override = overrides(index);
end

function names = groundTruthChannels(spec)
names = {};
try
    for i = 1:numel(spec.components)
        asset = spec.components(i).groundTruth;
        if isstruct(asset) && isfield(asset, 'channel') && ~isempty(asset.channel)
            names{end+1} = char(string(asset.channel)); %#ok<AGROW>
        end
        if isstruct(asset) && isfield(asset, 'maskProvider') && ...
                ~isempty(asset.maskProvider)
            names{end+1} = char(string(asset.maskProvider)); %#ok<AGROW>
        end
    end
catch
end
names = unique(nonempty(names), 'stable');
end

function names = globalGroundTruthChannels(roiObj, spec, channels)
% Include GT owned by every classifier/family on this ROI, not only the
% annotation contract of the classifier currently being executed.
names = [groundTruthChannels(spec), recognizableGroundTruthChannels(channels)];
gtFamilies = groundTruthFamilies(spec);
model = struct();
try
    [model, ~] = roiObj.loadCellModel('MigrateLegacy', true);
    model = cellModel.normalize(model, char(string(roiObj.id)));
catch
end
if isstruct(model) && isfield(model, 'families') && isstruct(model.families)
    families = model.families;
    count = familyCount(families);
    for i = 1:count
        familyName = familyText(families, 'name', i);
        provider = familyText(families, 'mask_provider', i);
        quality = familyText(families, 'quality', i);
        lineageSource = familyText(families, 'lineage_source', i);
        source = familyText(families, 'source', i);
        if any(strcmpi(gtFamilies, familyName)) || ...
                isGroundTruthName(familyName) || ...
                isGroundTruthQuality(quality) || ...
                isGroundTruthSource(lineageSource) || ...
                isGroundTruthSource(source)
            names = [names nonempty({provider})]; %#ok<AGROW>
        end
    end
end

% Future catalog versions may expose quality/source explicitly even when
% the cell-model schema does not.  Audit those fields defensively so a
% reviewed family can never become an inference candidate after a schema
% upgrade.
try
    catalog = annotationManager.initializationCatalog(roiObj, spec);
    for i = 1:numel(catalog.families)
        family = catalog.families(i);
        if catalogEntryIsGroundTruth(family, gtFamilies)
            names = [names nonempty({textField(family, 'maskProvider')})]; %#ok<AGROW>
        end
    end
catch
end
names = unique(nonempty(names), 'stable');
end

function names = groundTruthFamilies(spec)
names = {};
try
    for i = 1:numel(spec.components)
        asset = spec.components(i).groundTruth;
        if isstruct(asset) && isfield(asset, 'family') && ~isempty(asset.family)
            names{end+1} = char(string(asset.family)); %#ok<AGROW>
        end
    end
catch
end
names = unique(nonempty(names), 'stable');
end

function rejectGroundTruthOverrides(overrides, forbidden)
if ~isstruct(overrides) || ~isscalar(overrides), return; end
keys = {'instanceChannelName','brightfieldChannelName', ...
    'nucleusChannelName','budneckChannelName','gfpChannelName', ...
    'trackChannelName'};
for i = 1:numel(keys)
    key = keys{i};
    if ~isfield(overrides, key), continue; end
    value = selectedText(overrides.(key));
    if isempty(value) || isNone(value), continue; end
    if isGroundTruthName(value) || any(strcmpi(forbidden, value))
        error('classifierPredictForAnnotation:GroundTruthInputRejected', ...
            ['Input override "%s=%s" refers to a ground-truth resource. ' ...
             'Prediction-assisted annotation accepts PRED/raw inputs only.'], ...
            key, value);
    end
end
end

function tf = anyGroundTruthResource(values, forbidden)
tf = false;
values = nonempty(values);
for i = 1:numel(values)
    if isGroundTruthName(values{i}) || any(strcmpi(forbidden, values{i}))
        tf = true;
        return;
    end
end
end

function tf = catalogEntryIsGroundTruth(entry, gtFamilies)
tf = any(strcmpi(gtFamilies, textField(entry, 'name'))) || ...
    isGroundTruthName(textField(entry, 'name')) || ...
    isGroundTruthQuality(textField(entry, 'quality')) || ...
    isGroundTruthSource(textField(entry, 'lineageSource')) || ...
    isGroundTruthSource(textField(entry, 'lineage_source')) || ...
    isGroundTruthSource(textField(entry, 'source'));
end

function count = familyCount(families)
count = 0;
for key = {'family_id','name','mask_provider','lineage_source','quality','source'}
    try, count = max(count, numel(families.(key{1}))); catch, end
end
end

function value = familyText(families, key, index)
value = '';
try
    raw = families.(key);
    if iscell(raw), raw = raw{index}; else, raw = raw(index); end
    value = strtrim(char(string(raw)));
catch
end
end

function tf = isGroundTruthQuality(value)
token = normalizedToken(value);
tf = any(strcmp(token, {'gt','human_gt','reviewed_gt', ...
    'ground_truth','human_ground_truth','reviewed_ground_truth'}));
end

function tf = isGroundTruthSource(value)
token = normalizedToken(value);
tf = isGroundTruthQuality(token) || startsWith(token, 'ground_truth') || ...
    startsWith(token, 'human_review') || startsWith(token, 'reviewed_gt') || ...
    contains(token, '_ground_truth');
end

function tf = isGroundTruthName(value)
token = normalizedToken(value);
tf = startsWith(token, 'gt_') || endsWith(token, '_gt') || ...
    startsWith(token, 'ground_truth_') || ...
    contains(token, '_ground_truth_') || ...
    contains(token, '_human_gt') || contains(token, '_reviewed_gt');
end

function token = normalizedToken(value)
token = lower(regexprep(strtrim(char(string(value))), '[^a-z0-9]+', '_'));
token = regexprep(token, '^_+|_+$', '');
end

function names = recognizableGroundTruthChannels(channels)
names = {};
for i = 1:numel(channels)
    name = char(string(channels{i}));
    token = lower(regexprep(name, '[^a-z0-9]+', '_'));
    if startsWith(token, 'gt_') || endsWith(token, '_gt') || ...
            contains(token, '_ground_truth_') || ...
            startsWith(token, 'ground_truth_')
        names{end+1} = name; %#ok<AGROW>
    end
end
end

function tf = maskChannelHasContentWhenLoaded(roiObj, name)
tf = true;
try
    if isempty(roiObj.image), return; end
    index = roiObj.findChannelID(name);
    if isempty(index), tf = false; return; end
    stack = roiObj.image(:,:,index,:);
    tf = any(isfinite(double(stack(:))) & double(stack(:)) ~= 0);
catch
    tf = false;
end
end

function executeOne(classif, roiObj, item, ctx, opts)
if ~isempty(opts.Executor)
    feval(opts.Executor, classif, roiObj, item, ctx, opts);
    return;
end
% classifyData accepts a cell array per ROI.  Wrap this ROI's multi-channel
% list in an outer cell so it is not mistaken for several one-channel ROIs.
args = {'Frames', -1, 'Channel', {item.inputs.requiredChannels}, ...
    'OutputName', char(string(classif.strid)), 'Ctx', ctx};
if ~isempty(opts.Progress), args = [args {'Progress', opts.Progress}]; end
classif.classifyData(roiObj, args{:});
end

function stampPredictionProvenance(roiObj, report, item, saveOutput)
try
    model = [];
    try, model = roiObj.cellModel; catch, end
    if isempty(model)
        [model, ~] = roiObj.loadCellModel('MigrateLegacy', true);
    end
    model = cellModel.normalize(model, char(string(roiObj.id)));
    model.provenance.last_prediction_run_id = report.runId;
    model.provenance.last_prediction_classifier_id = report.classifierId;
    model.provenance.last_prediction_uses_ground_truth = false;
    model.provenance.last_prediction_instance_channel = ...
        item.inputs.instanceChannelName;
    model.provenance.last_prediction_model_manifest = ...
        report.model.compositeManifestPath;
    roiObj.cellModel = model;
    if saveOutput
        roiObj.saveCellModel(model);
    end
catch ME
    error('classifierPredictForAnnotation:ProvenanceWriteFailed', ...
        'Could not attach prediction run provenance to ROI "%s": %s', ...
        char(string(roiObj.id)), ME.message);
end
end

function ctx = executionContext(opts, item, report, itemIndex, total)
ctx = opts.Ctx;
ctx.params = item.params;
if ~isfield(ctx, 'io') || ~isstruct(ctx.io), ctx.io = struct(); end
ctx.io.requiredChannels = item.inputs.requiredChannels;
ctx.io.strictRequiredChannels = true;
ctx.io.saveMode = ternary(opts.Save, 'immediate', 'defer');
if ~isfield(ctx, 'store') || ~isstruct(ctx.store), ctx.store = struct(); end
if ~isempty(report.runDir), ctx.store.workDir = report.runDir; end
activeModelSnapshot = struct( ...
    'schemaVersion', 1, ...
    'intent', 'predict_for_annotation', ...
    'classifierId', report.classifierId, ...
    'package', report.model.package, ...
    'resolvedAt', report.model.resolvedAt, ...
    'backend', report.model.backend, ...
    'modelSource', report.model.modelSource, ...
    'artifactStatus', report.model.artifactStatus, ...
    'usesGroundTruth', false, ...
    'parameters', item.params);
ctx.annotationPrediction = struct('runId', report.runId, ...
    'usesGroundTruth', false, 'roiIndex', item.roiIndex, ...
    'usePinnedActiveModel', true, ...
    'activeModelSnapshot', activeModelSnapshot);
ctx.progressCallback = opts.ProgressCallback;
if ~isfield(ctx, 'progress') || ~isstruct(ctx.progress), ctx.progress = struct(); end
ctx.progress.currentNodeId = char(string(report.classifierId));
ctx.progress.currentNodeIndex = 1;
ctx.progress.totalNodes = 1;
ctx.progress.localBase = (itemIndex-1) / total;
ctx.progress.localSpan = 1 / total;
ctx.progress.emitConsoleProtocol = ~isempty(opts.ProgressCallback);
end

function snapshots = captureGtStates(classif, items)
template = struct('roiIndex', 0, 'image', [], 'data', [], ...
    'cellModel', [], 'display', [], 'channelid', []);
snapshots = repmat(template, numel(items), 1);
for i = 1:numel(items)
    roiObj = classif.roi(items(i).roiIndex);
    snapshots(i).roiIndex = items(i).roiIndex;
    try, snapshots(i).image = roiObj.image; catch, end
    try, snapshots(i).data = roiObj.data; catch, end
    try, snapshots(i).cellModel = roiObj.cellModel; catch, end
    try, snapshots(i).display = roiObj.display; catch, end
    try, snapshots(i).channelid = roiObj.channelid; catch, end
end
end

function restoreGtStates(classif, snapshots, trainingParam)
for i = 1:numel(snapshots)
    roiObj = classif.roi(snapshots(i).roiIndex);
    try, roiObj.image = snapshots(i).image; catch, end
    try, roiObj.data = snapshots(i).data; catch, end
    try, roiObj.cellModel = snapshots(i).cellModel; catch, end
    try, roiObj.display = snapshots(i).display; catch, end
    try, roiObj.channelid = snapshots(i).channelid; catch, end
end
try, classif.trainingParam = trainingParam; catch, end
end

function persistStagedGt(classif, items)
for i = 1:numel(items)
    roiObj = classif.roi(items(i).roiIndex);
    result = items(i).initializationReport;
    channels = {};
    try, channels = unique(result.channelsSaved, 'stable'); catch, end
    if ~isempty(channels), roiObj.save(channels, false); end
    if isfield(result, 'modelChanged') && logical(result.modelChanged)
        roiObj.saveCellModel(roiObj.cellModel);
    end
    % The annotation manifest is data-backed even when the copied
    % components themselves are channel/family-backed.
    roiObj.save('data', false);
end
end

function [recipe, prediction] = predictionRecipe(catalog)
prediction = catalog.prediction;
if ~prediction.available
    error('classifierPredictForAnnotation:PredictionMissing', ...
        ['The classifier completed, but its PRED family "%s" or mask ' ...
         'provider is unavailable.'], prediction.family);
end
recipe = struct('mode', 'prediction', ...
    'family', prediction.family, ...
    'channel', prediction.maskProvider, ...
    'copyParentage', true);
end

function emitProgress(opts, value, message, current, total)
ctx = opts.Ctx;
ctx.progressCallback = opts.ProgressCallback;
if ~isfield(ctx, 'progress') || ~isstruct(ctx.progress), ctx.progress = struct(); end
ctx.progress.emitConsoleProtocol = ~isempty(opts.ProgressCallback);
if exist('detecdiv_progress', 'file') == 2
    detecdiv_progress(ctx, value, message, 'Scope', 'roi', ...
        'Current', current, 'Total', total);
end
try
    if ~isempty(opts.Progress) && isvalid(opts.Progress)
        opts.Progress.Indeterminate = 'off';
        opts.Progress.Value = max(0, min(1, value));
        opts.Progress.Message = message;
        drawnow limitrate;
    end
catch
end
end

function id = cleanRunId(value, classif)
id = strtrim(char(string(value)));
if isempty(id)
    id = sprintf('annotation_prediction_%s_%s', ...
        regexprep(char(string(classif.strid)), '[^A-Za-z0-9_-]', '_'), ...
        char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS')));
end
end

function id = runLeaf(runState, fallback)
id = fallback;
try
    [~, leaf] = fileparts(char(string(runState.runDirAbs)));
    if ~isempty(leaf), id = leaf; end
catch
end
end

function item = emptyItem()
item = struct('roiIndex', 0, 'roiId', '', 'available', false, ...
    'canRun', false, 'canPrepare', false, 'requiresPreparation', false, ...
    'issues', {{}}, 'inputs', struct(), 'params', struct(), ...
    'predictionFamily', '', 'predictionChannel', '', ...
    'recipe', struct(), 'catalog', struct(), 'provenance', struct(), ...
    'initializationReport', struct(), 'status', '');
end

function result = serializableReport(report)
result = report;
% Catalogs and initialization reports can contain implementation-specific
% values.  The concise manifest keeps only reproducibility-critical fields.
for i = 1:numel(result.items)
    result.items(i).catalog = struct();
    result.items(i).initializationReport = struct();
    result.items(i).params = struct();
end
end

function result = overlay(result, source)
if ~isstruct(source), return; end
keys = fieldnames(source);
for i = 1:numel(keys), result.(keys{i}) = source.(keys{i}); end
end

function value = textField(source, key)
value = '';
try
    if isstruct(source) && isfield(source, key)
        value = selectedText(source.(key));
    end
catch
end
end

function value = selectedText(value)
while iscell(value)
    if isempty(value), value = ''; return; end
    value = value{end};
end
value = strtrim(char(string(value)));
end

function value = availableName(names, requested)
value = '';
if isempty(requested), return; end
idx = find(strcmpi(names, char(string(requested))), 1);
if ~isempty(idx), value = names{idx}; end
end

function values = nonempty(values)
values = cellstr(string(values));
values = values(strlength(strtrim(string(values))) > 0);
end

function tf = isNone(value)
tf = any(strcmpi(strtrim(char(string(value))), ...
    {'<none>','none','off','disabled'}));
end

function path = resolveRelative(path, root)
if isempty(path) || isfile(path) || isfolder(path), return; end
candidate = fullfile(root, path);
if isfile(candidate) || isfolder(candidate), path = candidate; end
end

function value = ternary(condition, a, b)
if condition, value = a; else, value = b; end
end

function value = timestamp()
value = char(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ss.SSSXXX'));
end
