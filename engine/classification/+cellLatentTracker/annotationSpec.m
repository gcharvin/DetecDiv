function spec = annotationSpec(classif)
%CELLLATENTTRACKER.ANNOTATIONSPEC Stable-track ID annotation contract.
spec = annotationManager.newSpec(classif);
p = cellLatentTracker.executionSpec(classif);
prediction = outputChannelName(char(string(p.defaults.outputName)));
gtName = configuredGroundTruth(classif);
component = annotationManager.newComponent( ...
    'id','tracklets', 'kind','tracked_instances', 'storage','channel', ...
    'coverageUnit','frame', 'editor','tracking', 'bootstrap','copy_channel', ...
    'classes',{'tracklet'}, ...
    'groundTruth',annotationManager.newAsset('channel',gtName, ...
        'quality','gt','producer','human_review', ...
        'semantic','stable_tracks'), ...
    'prediction',annotationManager.newAsset('channel',prediction, ...
        'channelCandidates',{prediction}, ...
        'quality','pred','producer','cellLatentTracker', ...
        'semantic','stable_tracks'));
spec.displayName = 'Latent stable-ID tracking';
spec.components = component;
spec.defaultEditor = 'tracking';
end

function name = configuredGroundTruth(classif)
name = '';
try
    tp = classif.trainingParam;
    if isstruct(tp) && isfield(tp,'groundTruthChannelName')
        name = textValue(tp.groundTruthChannelName);
    end
catch
end
if isempty(name) || any(strcmpi(name,{'<auto>','<unconfigured>','N/A'}))
    name = cellLatentTracker.annotationChannelName(classif);
end
end

function value = textValue(value)
while iscell(value)
    if isempty(value), value=''; return; end
    value=value{end};
end
value=strtrim(char(string(value)));
end

function name = outputChannelName(name)
if ~startsWith(name,'results_','IgnoreCase',true)
    name = ['results_' name];
end
end
