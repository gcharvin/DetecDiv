function spec = annotationSpec(classif)
%CELLLATENTMODEL.ANNOTATIONSPEC Editable mask + lineage GT bundle.

spec = annotationManager.newSpec(classif);
execution = cellLatentModel.executionSpec(classif);
params = execution.defaults;

predictionFamily = char(string(params.outputFamilyName));
gtFamily = trainingText(classif, 'groundTruthFamily', '');
if isempty(gtFamily) || strcmpi(gtFamily, '<auto>')
    gtFamily = [spec.classifierId ' reviewed GT'];
end
gtMask = [spec.classifierId '_cell'];

trackChannel = char(string(params.trackChannelName));
candidates = textList(trackChannel);
candidates = [candidates classifierChannels(classif)]; %#ok<AGROW>
candidates = unique(candidates(~cellfun(@isempty, candidates)), 'stable');
if isempty(candidates), primaryChannel = ''; else, primaryChannel = candidates{1}; end

maskComponent = annotationManager.newComponent( ...
    'id', 'tracked_mask', ...
    'kind', 'tracked_instances', ...
    'storage', 'channel', ...
    'coverageUnit', 'frame', ...
    'editor', 'tracking', ...
    'bootstrap', 'copy_channel', ...
    'classes', {'cell'}, ...
    'groundTruth', annotationManager.newAsset('channel', gtMask), ...
    'prediction', annotationManager.newAsset( ...
        'channel', primaryChannel, 'channelCandidates', candidates, ...
        'family', predictionFamily));

familyComponent = annotationManager.newComponent( ...
    'id', 'lineage', ...
    'kind', 'lineage', ...
    'storage', 'cell_model_family', ...
    'coverageUnit', 'roi', ...
    'editor', 'lineage', ...
    'bootstrap', 'clone_family', ...
    'groundTruth', annotationManager.newAsset( ...
        'family', gtFamily, 'maskProvider', gtMask), ...
    'prediction', annotationManager.newAsset('family', predictionFamily));

spec.displayName = 'Latent cell lineage';
spec.components = [maskComponent; familyComponent];
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
catch
end
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
end
