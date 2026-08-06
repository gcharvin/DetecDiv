function value = value(classif, binding)
%CLASSIFIERBINDING.VALUE Read a binding through its declared storage.

value = [];
storage = lower(strtrim(char(string(binding.storage))));
switch storage
    case 'trainingparam'
        try
            tp = classif.trainingParam;
            if isstruct(tp) && isfield(tp, binding.param)
                value = normalizeLegacyCell(tp.(binding.param));
            end
        catch
        end
        if isEmptyValue(value) && strcmpi(binding.legacyFallback, 'classifierInputChannels')
            value = classifierInputChannels(classif);
            if strcmpi(binding.cardinality, 'one') && iscell(value) && ~isempty(value)
                value = value{1};
            end
        end

    case 'classifierinputchannels'
        value = classifierInputChannels(classif);
        if strcmpi(binding.cardinality, 'one') && iscell(value) && ~isempty(value)
            value = value{1};
        end

    case 'annotation'
        value = annotationGroundTruthValue(classif, binding.componentId);
end
end

function values = classifierInputChannels(classif)
values = {};
try
    values = classif.getInputChannels();
catch
    try
        if isstruct(classif.dataset) && isfield(classif.dataset, 'channels') && ...
                ~isempty(classif.dataset.channels)
            values = classif.dataset.channels;
        else
            values = classif.channelName;
        end
    catch
        try, values = classif.channelName; catch, end
    end
end
values = textList(values);
if ~isempty(values), return; end

% Pre-channelName classifiers stored only numeric channel indices. Resolve
% them against the first usable imported ROI without changing the object.
indices = [];
try, indices = round(double(classif.channel(:).')); catch, end
indices = indices(isfinite(indices) & indices >= 1);
if isempty(indices), return; end
try
    rois = classif.roi;
    for i = 1:numel(rois)
        names = cellstr(string(rois(i).display.channel(:).'));
        valid = indices(indices <= numel(names));
        if ~isempty(valid)
            values = names(valid);
            return;
        end
    end
catch
end
end

function value = annotationGroundTruthValue(classif, componentId)
value = '';
try
    spec = annotationManager.specForClassifier(classif);
    components = spec.components;
    if isempty(components), return; end
    idx = 1;
    if ~isempty(componentId)
        match = find(strcmp({components.id}, componentId), 1);
        if ~isempty(match), idx = match; end
    end
    asset = components(idx).groundTruth;
    if isfield(asset, 'channel') && ~isempty(asset.channel)
        value = char(string(asset.channel));
    elseif isfield(asset, 'family') && ~isempty(asset.family)
        value = char(string(asset.family));
    elseif isfield(asset, 'groupId') && ~isempty(asset.groupId)
        value = char(string(asset.groupId));
        if isfield(asset, 'valueField') && ~isempty(asset.valueField)
            value = [value ' / ' char(string(asset.valueField))];
        end
    end
catch
end
end

function value = normalizeLegacyCell(value)
while iscell(value) && numel(value) == 1 && iscell(value{1})
    value = value{1};
end
end

function tf = isEmptyValue(value)
tf = isempty(value);
if ischar(value) || (isstring(value) && isscalar(value))
    tf = strlength(strtrim(string(value))) == 0;
end
end

function values = textList(raw)
if isempty(raw)
    values = {};
elseif ischar(raw)
    values = {raw};
elseif isstring(raw)
    values = cellstr(raw(:).');
elseif iscell(raw)
    values = {};
    for i = 1:numel(raw)
        nested = textList(raw{i});
        values = [values nested]; %#ok<AGROW>
    end
else
    values = {};
end
values = values(~cellfun(@(x)isempty(strtrim(x)), values));
values = unique(values, 'stable');
end
