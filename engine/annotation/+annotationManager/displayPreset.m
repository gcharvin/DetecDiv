function preset = displayPreset(roiObj, spec, classifier)
%ANNOTATIONMANAGER.DISPLAYPRESET Describe Score defaults for the annotation target.

if nargin < 3
    classifier = [];
end

gtChannels = {};
predictionChannels = {};
families = {};
maskProviders = {};
for i = 1:numel(spec.components)
    component = spec.components(i);
    if strcmp(component.storage, 'channel')
        gt = char(string(component.groundTruth.channel));
        if ~isempty(gt), gtChannels{end+1} = gt; end %#ok<AGROW>
        [pred, exists] = annotationManager.resolveChannel(roiObj, component.prediction);
        if exists, predictionChannels{end+1} = pred; end %#ok<AGROW>
    elseif strcmp(component.storage, 'cell_model_family')
        family = char(string(component.groundTruth.family));
        provider = char(string(component.groundTruth.maskProvider));
        if ~isempty(family), families{end+1} = family; end %#ok<AGROW>
        if ~isempty(provider), maskProviders{end+1} = provider; end %#ok<AGROW>
    end
end

mode = 'Normal';
colorBy = 'Family';
if any(strcmp({spec.components.kind}, 'semantic_mask'))
    mode = 'Semantic';
elseif any(ismember({spec.components.kind}, ...
        {'instance_mask','tracked_instances','lineage'}))
    mode = 'Edit';
    colorBy = 'Track';
end
preset = struct( ...
    'editableChannels', {unique(gtChannels, 'stable')}, ...
    'predictionChannels', {unique(predictionChannels, 'stable')}, ...
    'backgroundChannels', {configuredBackgroundChannels( ...
        roiObj, classifier)}, ...
    'objectFamilies', {unique(families, 'stable')}, ...
    'maskProviders', {unique(maskProviders, 'stable')}, ...
    'channelMode', mode, ...
    'colorBy', colorBy, ...
    'predictionReadOnly', true);
end

function names = configuredBackgroundChannels(roiObj, classifier)
% Prefer the image observation bound to this classifier over a cached
% composite.  availableChannels also sees HDF5-only channels, which is
% important when Score currently holds a deliberately partial ROI cache.
names = {};
if isempty(classifier)
    return;
end

candidates = {};
% The runtime binding is authoritative when it is present; trainingParam
% remains the fallback for older classifier snapshots.
containers = {'executionParam','trainingParam'};
for i = 1:numel(containers)
    try
        param = classifier.(containers{i});
    catch
        param = [];
    end
    if ~isstruct(param) || ~isfield(param, 'brightfieldChannelName')
        continue;
    end
    value = strtrim(char(string(param.brightfieldChannelName)));
    if ~isempty(value) && ~any(strcmpi(value, {'<none>','<auto>'}))
        candidates{end+1} = value; %#ok<AGROW>
    end
end

available = annotationManager.availableChannels(roiObj);
for i = 1:numel(candidates)
    idx = find(strcmpi(available, candidates{i}), 1, 'first');
    if isempty(idx) || any(strcmpi(names, available{idx}))
        continue;
    end
    names{end+1} = available{idx}; %#ok<AGROW>
end
end
