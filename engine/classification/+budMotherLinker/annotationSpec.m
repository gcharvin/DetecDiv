function spec = annotationSpec(classif)
%BUDMOTHERLINKER.ANNOTATIONSPEC Editable tracked mask + lineage bundle.

spec = annotationManager.newSpec(classif);
execution = budMotherLinker.executionSpec(classif);
params = execution.defaults;
predictionFamily = char(string(params.outputFamilyName));
gtFamily = trainingText(classif, 'groundTruthFamily', '');
if isempty(gtFamily) || strcmpi(gtFamily, '<auto>')
    gtFamily = [spec.classifierId ' reviewed GT'];
end
gtMask = budMotherLinker.annotationChannelName(classif);

trackChannel = char(string(params.trackChannelName));
candidates = textList(trackChannel);
candidates = [candidates classifierChannels(classif)]; %#ok<AGROW>
candidates = unique(candidates(~cellfun(@isempty, candidates)), 'stable');
if isempty(candidates), primaryChannel = ''; else, primaryChannel = candidates{1}; end

maskComponent = annotationManager.newComponent( ...
    'id', 'tracked_mask', 'kind', 'tracked_instances', ...
    'storage', 'channel', 'coverageUnit', 'frame', ...
    'editor', 'tracking', 'bootstrap', 'copy_channel', ...
    'classes', {'cell'}, ...
    'groundTruth', annotationManager.newAsset('channel', gtMask, ...
        'quality','gt','producer','human_review','semantic','stable_tracks'), ...
    'prediction', annotationManager.newAsset( ...
        'channel', primaryChannel, 'channelCandidates', candidates, ...
        'family', predictionFamily, 'quality','pred', ...
        'producer','budMotherLinker','semantic','stable_tracks'));

trackingComponent = annotationManager.newComponent( ...
    'id', 'tracking', 'kind', 'tracking', ...
    'storage', 'cell_model_family', 'coverageUnit', 'frame', ...
    'editor', 'tracking', 'bootstrap', 'clone_family', ...
    'groundTruth', annotationManager.newAsset( ...
        'family', gtFamily, 'maskProvider', gtMask, ...
        'quality','gt','producer','human_review', ...
        'semantic','mother_bud_lineage'), ...
    'prediction', annotationManager.newAsset('family', predictionFamily, ...
        'quality','pred','producer','budMotherLinker', ...
        'semantic','mother_bud_lineage'));

parentageComponent = annotationManager.newComponent( ...
    'id', 'parentage', 'kind', 'lineage', ...
    'storage', 'cell_model_family', 'coverageUnit', 'roi', ...
    'editor', 'lineage', 'bootstrap', 'none', ...
    'groundTruth', trackingComponent.groundTruth, ...
    'prediction', trackingComponent.prediction);

spec.displayName = 'Mother-bud lineage';
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
