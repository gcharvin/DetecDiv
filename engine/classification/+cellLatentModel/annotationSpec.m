function spec = annotationSpec(classif)
%CELLLATENTMODEL.ANNOTATIONSPEC Editable mask + lineage GT bundle.

spec = annotationManager.newSpec(classif);
execution = cellLatentModel.executionSpec(classif);
params = execution.defaults;
% Annotation must discover the family produced by the active trained
% bundle, not a possibly older executionParam stored in the MAT snapshot.
% This is read-only: the classifier handle is never rewritten here.
params = classifierApplyTrainingExecutionDefaults( ...
    params, classif, execution, 'annotation');

predictionFamily = char(string(params.outputFamilyName));
gtFamily = trainingText(classif, 'groundTruthFamily', '');
if isempty(gtFamily) || strcmpi(gtFamily, '<auto>')
    gtFamily = [spec.classifierId ' reviewed GT'];
end
gtMask = cellLatentModel.annotationChannelName(classif);

trackChannel = char(string(params.trackChannelName));
predictionTrackChannel = char(string(params.outputTrackChannelName));
candidates = textList(predictionTrackChannel);
candidates = [candidates textList(trackChannel)]; %#ok<AGROW>
candidates = [candidates classifierChannels(classif)]; %#ok<AGROW>
candidates = unique(candidates(~cellfun(@isempty, candidates)), 'stable');
candidates = excludeAnnotationInputs(candidates, classif, gtMask);
if isempty(candidates), primaryChannel = ''; else, primaryChannel = candidates{1}; end

maskComponent = annotationManager.newComponent( ...
    'id', 'tracked_mask', ...
    'kind', 'tracked_instances', ...
    'storage', 'channel', ...
    'coverageUnit', 'frame', ...
    'editor', 'tracking', ...
    'bootstrap', 'copy_channel', ...
    'classes', {'cell'}, ...
    'groundTruth', annotationManager.newAsset('channel', gtMask, ...
        'quality','gt','producer','human_review','semantic','stable_tracks'), ...
    'prediction', annotationManager.newAsset( ...
        'channel', primaryChannel, 'channelCandidates', candidates, ...
        'family', predictionFamily, 'quality','pred', ...
        'producer','cellLatentModel','semantic','stable_tracks'));

trackingComponent = annotationManager.newComponent( ...
    'id', 'tracking', ...
    'kind', 'tracking', ...
    'storage', 'cell_model_family', ...
    'coverageUnit', 'frame', ...
    'editor', 'tracking', ...
    'bootstrap', 'clone_family', ...
    'groundTruth', annotationManager.newAsset( ...
        'family', gtFamily, 'maskProvider', gtMask, ...
        'quality','gt','producer','human_review', ...
        'semantic','mother_null_lineage'), ...
    'prediction', annotationManager.newAsset('family', predictionFamily, ...
        'quality','pred','producer','cellLatentModel', ...
        'semantic','mother_null_lineage'));

parentageComponent = annotationManager.newComponent( ...
    'id', 'parentage', ...
    'kind', 'lineage', ...
    'storage', 'cell_model_family', ...
    'coverageUnit', 'roi', ...
    'editor', 'lineage', ...
    'bootstrap', 'none', ...
    'groundTruth', trackingComponent.groundTruth, ...
    'prediction', trackingComponent.prediction);

spec.displayName = 'Latent cell lineage';
spec.components = [maskComponent; trackingComponent; parentageComponent];
spec.defaultEditor = 'lineage';
end

function value = trainingText(classif, fieldName, fallback)
value = fallback;
try
    tp = classif.trainingParam;
    if isstruct(tp) && isfield(tp, fieldName) && ~isempty(tp.(fieldName))
        value = char(string(tp.(fieldName)));
    end
catch
end
end

function values = classifierChannels(classif)
values = {};
try
    raw = classif.channelName;
    if ischar(raw) || isstring(raw)
        values = cellstr(string(raw));
    elseif iscell(raw)
        values = cellfun(@(x) char(string(x)), raw, 'UniformOutput', false);
    end
    values = reshape(values, 1, []);
catch
end
end

function values = excludeAnnotationInputs(values, classif, gtMask)
% A GT mask and typed image observations are never prediction overlays.
% classifier.channelName may contain both masks and raw images, so using it
% unfiltered can make brightfield appear as an editable annotation channel.
excluded = textList(gtMask);
observationFields = {'brightfieldChannelName','gfpChannelName', ...
    'nucleusChannelName','budneckChannelName'};
containers = {'executionParam','trainingParam'};
for i = 1:numel(containers)
    try
        param = classif.(containers{i});
    catch
        param = [];
    end
    if ~isstruct(param), continue; end
    for j = 1:numel(observationFields)
        field = observationFields{j};
        if isfield(param, field)
            excluded = [excluded textList(param.(field))]; %#ok<AGROW>
        end
    end
end
excluded = excluded(~cellfun(@isempty, excluded));
if isempty(excluded), return; end
drop = ismember(lower(string(values)), lower(string(excluded)));
values = values(~drop);
end

function values = textList(value)
if isempty(value)
    values = {};
elseif ischar(value) || isstring(value)
    values = cellstr(string(value));
elseif iscell(value)
    values = cellfun(@(x) char(string(x)), value, 'UniformOutput', false);
else
    values = {};
end
values = reshape(values, 1, []);
end
