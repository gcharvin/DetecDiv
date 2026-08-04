function preset = displayPreset(roiObj, spec)
%ANNOTATIONMANAGER.DISPLAYPRESET Describe Score defaults for the annotation target.

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
    'objectFamilies', {unique(families, 'stable')}, ...
    'maskProviders', {unique(maskProviders, 'stable')}, ...
    'channelMode', mode, ...
    'colorBy', colorBy, ...
    'predictionReadOnly', true);
end
