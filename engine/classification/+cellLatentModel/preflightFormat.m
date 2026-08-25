function [tp, approvals] = preflightFormat(classif, rois, ctx)
%CELLLATENTMODEL.PREFLIGHTFORMAT Validate formatting configuration early.
% This function must remain read-only: classi.formatDataForTraining calls it
% before replacing an existing formatted dataset.

if nargin < 2, rois = []; end
if nargin < 3 || isempty(ctx), ctx = struct(); end
legacyArchitecture = true;
try
    legacyArchitecture = ~isfield(classif.trainingParam, ...
        'architectureVersion');
catch
end
tp = cellLatentModel.utils.defaultTrainingParam();
if ~isempty(classif) && isprop(classif, 'trainingParam') && ...
        isstruct(classif.trainingParam)
    tp = cellLatentModel.utils.applyOverrides(tp, classif.trainingParam);
end
if isfield(ctx, 'params') && isstruct(ctx.params)
    tp = cellLatentModel.utils.applyOverrides(tp, ctx.params);
end

architecture = configuredChoice(tp.architectureVersion, ...
    'detecdiv_composite_v1');
objective = configuredChoice(tp.trainingObjective, 'continuous_lineage');
if strcmp(architecture,'detecdiv_composite_v1') && logical(tp.trainMotherNull)
    objective = 'continuous_lineage';
end
if strcmp(architecture,'detecdiv_composite_v1') && ...
        logical(tp.trainTrackingActions)
    tp.instanceChannelName = ...
        cellLatentModel.utils.resolveFrameLocalInstanceChannel( ...
        classif,tp.instanceChannelName,tp.trackChannelName,ctx);
end
if strcmp(architecture,'detecdiv_composite_v1') && ...
        legacyArchitecture && strcmpi(strtrim(char(string(tp.modelName))), ...
            'cell_latent_relation_v001')
    tp.modelName = 'model_cell_latent_composite_v001';
end
assertNewModelTarget(classif, tp.modelName);
if ~any(strcmp(objective, {'relation_ensemble','continuous_lineage'}))
    error('cellLatentModel:InvalidTrainingObjective', ...
        ['trainingObjective must be relation_ensemble or ' ...
         'continuous_lineage.']);
end
if strcmp(objective, 'continuous_lineage') && ...
        ~isPositiveScalar(tp.frameIntervalMinutes)
    error('cellLatentModel:MissingFrameInterval', ...
        ['Continuous-lineage formatting requires the physical acquisition ' ...
         'interval. Set training parameter "frameIntervalMinutes" to the ' ...
         'strictly positive number of minutes between two consecutive ' ...
         'frames, then format the training set again.']);
end

roiIndices = formattingRois(classif, rois);
approvals = cellLatentModel.assertGroundTruthReady(classif, roiIndices);
validateChannels(classif, roiIndices, tp, objective, architecture);
assertCurrentAnnotationContract(classif, roiIndices);
end

function assertCurrentAnnotationContract(classif, roiIndices)
% Re-run the current validator even for approvals created by older code.
% Warnings (including centroid motion) remain advisory and never enter the
% blocking problem list.
spec = annotationManager.specForClassifier(classif);
problems = strings(0,1);
for i = 1:numel(roiIndices)
    roiIndex = roiIndices(i);
    roiObj = classif.roi(roiIndex);
    bounds = trainingBounds.resolve(classif, roiIndex);
    reviewFrames = [];
    if ~isempty(bounds), reviewFrames = bounds(1):bounds(2); end
    [~, managed] = annotationManager.entryForSpec(roiObj, spec);
    report = annotationManager.validate(roiObj, spec, ...
        'RequireReviewed', managed, 'ReviewFrames', reviewFrames);
    if report.valid, continue; end
    problems(end+1,1) = sprintf('ROI %s: %s', ... %#ok<AGROW>
        char(string(roiObj.id)), strjoin(cellstr(report.errors), ' '));
end
if ~isempty(problems)
    error('cellLatentModel:GroundTruthValidationFailed', ...
        ['Selected formatting ROIs fail the current GT validation ' ...
         'contract:' newline '%s' newline ...
         'Open each ROI, inspect the reported errors, and run Validate GT.'], ...
        strjoin(problems, newline));
end
end

function assertNewModelTarget(classif, rawModelName)
% Formatting is the first publication step for an immutable model version.
% Refuse a stale/default name immediately instead of producing a dataset
% that train.m can only reject later after expensive formatting.
modelName = regexprep(char(string(rawModelName)), ...
    '[^A-Za-z0-9_.-]', '_');
if isempty(modelName), modelName = 'cell_latent_relation_v001'; end
classifierPath = '';
try classifierPath = char(string(classif.path)); catch, end
if isempty(classifierPath), return; end
target = fullfile(classifierPath, 'models', modelName);
if ~isfolder(target), return; end
error('cellLatentModel:ImmutableModelExists', ...
    ['Model version "%s" already exists and is immutable. Choose a new ' ...
     'Target model version (for example the next vNNN) before formatting. ' ...
     'Existing model and datasets were not modified.'], modelName);
end

function indices = formattingRois(classif, requested)
n = numel(classif.roi);
indices = normalizeIndices(requested, n);
validation = [];
test = [];
try
    split = classif.dataset.split;
    if isempty(indices), indices = normalizeIndices(split.train, n); end
    validation = normalizeIndices(split.val, n);
    test = normalizeIndices(split.test, n);
catch
end
if isempty(indices)
    try indices = normalizeIndices(classif.trainingset, n); catch, end
end
indices = unique([indices validation], 'stable');
indices = setdiff(indices, test, 'stable');
end

function validateChannels(classif, roiIndices, tp, objective, architecture)
trackName = strtrim(char(string(tp.trackChannelName)));
requirements = {};
if strcmp(architecture,'detecdiv_composite_v1') && ...
        logical(tp.trainTrackingActions)
    instanceName = strtrim(char(string(tp.instanceChannelName)));
    if isempty(instanceName)
        error('cellLatentModel:MissingInstanceChannel', ...
            ['Composite tracking training requires [INPUT] frame-local ' ...
             'instance masks.']);
    end
    requirements(end+1,:) = {'frame-local instances', instanceName}; %#ok<AGROW>
end
if ~isempty(trackName), requirements(end+1,:) = {'tracked masks', trackName}; end %#ok<AGROW>
if strcmp(objective, 'relation_ensemble')
    gfpName = strtrim(char(string(tp.gfpChannelName)));
    if ~isempty(gfpName), requirements(end+1,:) = {'GFP', gfpName}; end %#ok<AGROW>
else
    fields = {'brightfieldChannelName','nucleusChannelName','budneckChannelName'};
    labels = {'brightfield','nucleus marker','bud-neck marker'};
    for i = 1:numel(fields)
        name = strtrim(char(string(tp.(fields{i}))));
        if ~isempty(name), requirements(end+1,:) = {labels{i}, name}; end %#ok<AGROW>
    end
end
if isempty(requirements), return; end

problems = strings(0,1);
for i = 1:numel(roiIndices)
    roiObj = classif.roi(roiIndices(i));
    missing = strings(0,1);
    for j = 1:size(requirements,1)
        if ~hasChannel(roiObj, requirements{j,2})
            missing(end+1) = sprintf('%s "%s"', ...
                requirements{j,1}, requirements{j,2}); %#ok<AGROW>
        end
    end
    if ~isempty(missing)
        problems(end+1) = sprintf('ROI %s: missing %s', ...
            char(string(roiObj.id)), strjoin(missing, ', ')); %#ok<AGROW>
    end
end
if ~isempty(problems)
    error('cellLatentModel:TrainingInputsNotReady', ...
        ['Selected formatting ROIs do not contain every configured input:' ...
         newline '%s' newline ...
         'Unselect these ROIs or initialize and validate their GT first.'], ...
        strjoin(problems, newline));
end
end

function tf = hasChannel(roiObj, name)
tf = false;
try
    tf = ~isempty(roiObj.findChannelID(name, 'exact'));
catch
    try
        tf = any(strcmp(string(roiObj.display.channel), string(name)));
    catch
    end
end
end

function values = normalizeIndices(raw, n)
if isempty(raw), values = []; return; end
values = unique(round(double(raw(:).')), 'stable');
values = values(isfinite(values) & values >= 1 & values <= n);
end

function value = configuredChoice(raw, fallback)
while iscell(raw)
    if isempty(raw), raw = fallback; else, raw = raw{end}; end
end
value = lower(strtrim(char(string(raw))));
if isempty(value), value = fallback; end
end

function tf = isPositiveScalar(value)
tf = isnumeric(value) && isscalar(value) && isfinite(value) && value > 0;
end
