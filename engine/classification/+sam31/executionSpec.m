function spec = executionSpec(classif)
% sam31.executionSpec  Execution-time parameter contract.

if nargin < 1
    classif = [];
end

tp = sam31.utils.defaultTrainingParam();
spec = struct();
spec.category = 'Pixel';
spec.defaultClasses = {'cell'};
spec.segmentationKind = 'instance_tracking';
spec.instanceSegmentation = true;
spec.summary = 'SAM3.1 instance segmentation and video tracking bridge.';
spec.staticKeys = {'resolution','detectorCheckpointPath','trackerCheckpointPath', ...
    'maxNumObjects','videoScoreThreshold','videoNewDetThreshold', ...
    'videoDetNmsThreshold','videoAssocIouThreshold'};
spec.outputKeys = {};
spec.defaultImportKeys = spec.staticKeys;

spec.defaults = struct( ...
    'resolution', tp.resolution, ...
    'detectorCheckpointPath', tp.detectorCheckpointPath, ...
    'trackerCheckpointPath', tp.trackerCheckpointPath, ...
    'maxNumObjects', tp.maxNumObjects, ...
    'videoScoreThreshold', tp.videoScoreThreshold, ...
    'videoNewDetThreshold', tp.videoNewDetThreshold, ...
    'videoDetNmsThreshold', tp.videoDetNmsThreshold, ...
    'videoAssocIouThreshold', tp.videoAssocIouThreshold);

spec.labels = struct( ...
    'resolution', 'Resolution', ...
    'detectorCheckpointPath', 'Detector checkpoint', ...
    'trackerCheckpointPath', 'Tracker checkpoint', ...
    'maxNumObjects', 'Object slots', ...
    'videoScoreThreshold', 'Detection score', ...
    'videoNewDetThreshold', 'New-object score', ...
    'videoDetNmsThreshold', 'Detection NMS', ...
    'videoAssocIouThreshold', 'Association IoU');

spec.tips = struct();
spec.choices = struct();
spec.choices.resolution = {'280','1008'};

spec.defaults = mergeDefaultsFromClassi(spec.defaults, classif);
end

function defaults = mergeDefaultsFromClassi(defaults, classif)
if isempty(classif)
    return;
end
sources = {};
try
    if isobject(classif) && isprop(classif, 'trainingParam') && isstruct(classif.trainingParam)
        sources{end+1} = classif.trainingParam;
    elseif isstruct(classif) && isfield(classif, 'trainingParam') && isstruct(classif.trainingParam)
        sources{end+1} = classif.trainingParam;
    end
catch
end
try
    if isobject(classif) && isprop(classif, 'executionParam') && isstruct(classif.executionParam)
        sources{end+1} = classif.executionParam;
    elseif isstruct(classif) && isfield(classif, 'executionParam') && isstruct(classif.executionParam)
        sources{end+1} = classif.executionParam;
    end
catch
end
keys = fieldnames(defaults);
for s = 1:numel(sources)
    src = sources{s};
    for i = 1:numel(keys)
        key = keys{i};
        if isfield(src, key) && ~isempty(src.(key))
            defaults.(key) = src.(key);
        end
    end
end
end
