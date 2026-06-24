function spec = executionSpec(classif)
% sam31.executionSpec  Execution-time parameter contract.

if nargin < 1
    classif = [];
end

tp = sam31.utils.defaultExecutionParam();
spec = struct();
spec.category = 'Pixel';
spec.defaultClasses = {'cell'};
spec.segmentationKind = 'instance_tracking';
spec.instanceSegmentation = true;
spec.summary = 'SAM3.1 instance segmentation and video tracking bridge.';
spec.staticKeys = {'resolution','maxNumObjects','videoScoreThreshold', ...
    'videoNewDetThreshold','videoAssocIouThreshold','sam31Runner'};
spec.outputKeys = {};
spec.defaultImportKeys = spec.staticKeys;

spec.defaults = struct( ...
    'resolution', {tp.resolution}, ...
    'maxNumObjects', tp.maxNumObjects, ...
    'videoScoreThreshold', tp.videoScoreThreshold, ...
    'videoNewDetThreshold', tp.videoNewDetThreshold, ...
    'videoAssocIouThreshold', tp.videoAssocIouThreshold, ...
    'sam31Runner', {tp.sam31Runner});

spec.labels = struct( ...
    'resolution', 'Resolution', ...
    'maxNumObjects', 'Object slots', ...
    'videoScoreThreshold', 'Detection score', ...
    'videoNewDetThreshold', 'New-object score', ...
    'videoAssocIouThreshold', 'Association IoU', ...
    'sam31Runner', 'Runner');

spec.tips = struct( ...
    'resolution', 'Working resolution used by SAM3.1. 280 is the yeast-friendly mode; 1008 is heavier.', ...
    'maxNumObjects', 'Maximum number of object slots tracked at the same time during inference. Raise this if tracks disappear when many cells are present.', ...
    'videoScoreThreshold', 'Detection score threshold for per-frame detections.', ...
    'videoNewDetThreshold', 'Threshold for accepting new detections during video propagation.', ...
    'videoAssocIouThreshold', 'IoU threshold used to associate objects across frames.', ...
    'sam31Runner', 'session keeps the SAM31 predictor loaded across ROIs; external starts a fresh Python process per ROI.');
spec.choices = struct();
spec.choices.resolution = {'280','1008'};
spec.choices.sam31Runner = {'session','external'};

spec.defaults = mergeDefaultsFromClassi(spec.defaults, classif);
end

function defaults = mergeDefaultsFromClassi(defaults, classif)
if isempty(classif)
    return;
end
sources = {};
try
    if isobject(classif) && isprop(classif, 'trainingParam') && isstruct(classif.trainingParam)
        sources{end+1} = struct('resolution', classif.trainingParam.resolution);
    elseif isstruct(classif) && isfield(classif, 'trainingParam') && isstruct(classif.trainingParam)
        sources{end+1} = struct('resolution', classif.trainingParam.resolution);
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
