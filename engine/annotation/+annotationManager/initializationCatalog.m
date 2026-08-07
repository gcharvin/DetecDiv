function catalog = initializationCatalog(roiObj, spec)
%ANNOTATIONMANAGER.INITIALIZATIONCATALOG Discover safe GT starting points.

channels = annotationManager.availableChannels(roiObj);
families = emptyFamilies();
groundTruthFamilies = groundTruthFamilyNames(spec);
groundTruthChannels = groundTruthChannelNames(spec);
model = cellModel.create(char(string(roiObj.id)));
try
    [model, ~] = roiObj.loadCellModel('MigrateLegacy', true);
    model = cellModel.normalize(model, char(string(roiObj.id)));
catch
end

for i = 1:numel(model.families.family_id)
    familyId = model.families.family_id(i);
    instanceRows = model.instances.family_id == familyId;
    relationRows = model.relations.family_id == familyId;
    trackIds = unique(model.instances.track_id(instanceRows));
    trackIds = trackIds(trackIds > 0);
    frames = unique(model.instances.frame(instanceRows));
    frames = frames(frames > 0);
    provider = char(string(model.families.mask_provider{i}));
    providerExists = any(strcmpi(channels, provider));
    providerIndexed = isIndexedChannel(roiObj, provider);
    usable = providerExists && ~isSyntheticDisplayChannel(provider) && ...
        (providerIndexed || isLikelyMaskName(provider)) && ...
        ~any(strcmpi(groundTruthFamilies, char(string(model.families.name{i}))));
    item = struct( ...
        'name', char(string(model.families.name{i})), ...
        'familyId', double(familyId), ...
        'maskProvider', provider, ...
        'providerExists', providerExists, ...
        'providerIndexed', providerIndexed, ...
        'usable', usable, ...
        'instanceCount', nnz(instanceRows), ...
        'trackCount', numel(trackIds), ...
        'frameCount', numel(frames), ...
        'relationCount', nnz(relationRows), ...
        'label', '');
    item.label = familyLabel(item);
    families(end+1,1) = item; %#ok<AGROW>
end

predictionFamily = predictionFamilyName(spec);
prediction = struct('available', false, 'family', predictionFamily, ...
    'maskProvider', '', 'instanceCount', 0, 'trackCount', 0, ...
    'frameCount', 0, 'relationCount', 0, 'label', '');
if ~isempty(predictionFamily)
    idx = find(strcmpi({families.name}, predictionFamily), 1, 'first');
    if ~isempty(idx)
        source = families(idx);
        prediction.available = source.usable;
        prediction.family = source.name;
        prediction.maskProvider = source.maskProvider;
        prediction.instanceCount = source.instanceCount;
        prediction.trackCount = source.trackCount;
        prediction.frameCount = source.frameCount;
        prediction.relationCount = source.relationCount;
        prediction.label = source.label;
    end
else
    try
        summary = annotationManager.inspect(roiObj, spec);
        required = [summary.components.required];
        if isempty(required), required = true(1, numel(summary.components)); end
        prediction.available = ~isempty(summary.components) && ...
            all([summary.components(required).predictionExists]);
        prediction.label = 'Classifier prediction';
    catch
    end
end

maskChannels = maskChannelNames(roiObj, channels, families, groundTruthChannels);
catalog = struct( ...
    'roiId', char(string(roiObj.id)), ...
    'channels', {channels}, ...
    'maskChannels', {maskChannels}, ...
    'families', families, ...
    'prediction', prediction, ...
    'supports', struct('mask', supportsMaskInitialization(spec), ...
        'family', any(strcmp({spec.components.storage}, 'cell_model_family'))), ...
    'recommended', blankRecipe());
catalog.recommended = recommendedRecipe(catalog, spec);
end

function tf = supportsMaskInitialization(spec)
tf = false;
for i = 1:numel(spec.components)
    component = spec.components(i);
    if strcmp(char(string(component.storage)), 'channel') && ...
            any(strcmp(char(string(component.kind)), ...
            {'tracked_instances','instances','semantic_mask','instance_mask','mask'}))
        tf = true;
        return;
    end
end
end

function families = emptyFamilies()
families = repmat(struct('name', '', 'familyId', 0, 'maskProvider', '', ...
    'providerExists', false, 'providerIndexed', false, 'usable', false, ...
    'instanceCount', 0, 'trackCount', 0, ...
    'frameCount', 0, 'relationCount', 0, 'label', ''), 0, 1);
end

function text = familyLabel(item)
provider = item.maskProvider;
if isempty(provider), provider = '<missing mask provider>'; end
text = sprintf('%s - %d tracks, %d parent links - mask: %s', ...
    item.name, item.trackCount, item.relationCount, provider);
if ~item.providerExists
    text = [text ' (mask unavailable)'];
end
end

function name = predictionFamilyName(spec)
name = '';
for i = 1:numel(spec.components)
    component = spec.components(i);
    if strcmp(char(string(component.storage)), 'cell_model_family')
        try, name = char(string(component.prediction.family)); catch, end
        if ~isempty(name), return; end
    end
end
end

function names = groundTruthFamilyNames(spec)
names = {};
for i = 1:numel(spec.components)
    component = spec.components(i);
    if ~strcmp(char(string(component.storage)), 'cell_model_family'), continue; end
    try, name = char(string(component.groundTruth.family)); catch, name = ''; end
    if ~isempty(name), names{end+1} = name; end %#ok<AGROW>
end
names = unique(names, 'stable');
end

function recipe = recommendedRecipe(catalog, spec)
recipe = blankRecipe();
if catalog.prediction.available
    recipe.mode = 'prediction';
    recipe.family = catalog.prediction.family;
    recipe.channel = catalog.prediction.maskProvider;
    recipe.copyParentage = true;
    return;
end

valid = find([catalog.families.usable]);
if ~isempty(valid)
    scores = [catalog.families(valid).trackCount] .* 100000 + ...
        [catalog.families(valid).relationCount];
    [~, best] = max(scores);
    source = catalog.families(valid(best));
    recipe.mode = 'family';
    recipe.family = source.name;
    recipe.channel = source.maskProvider;
    recipe.copyParentage = source.relationCount > 0;
    return;
end

channel = resolvedMaskPrediction(spec);
if ~isempty(channel) && any(strcmpi(catalog.maskChannels, channel))
    recipe.mode = 'mask';
    recipe.channel = channel;
    return;
end

likely = find(contains(lower(string(catalog.maskChannels)), ...
    ["mask","cell","seg","track","result"]), 1, 'first');
if ~isempty(likely) && ~isempty(catalog.maskChannels)
    recipe.mode = 'mask';
    recipe.channel = catalog.maskChannels{likely};
end
end

function names = maskChannelNames(roiObj, channels, families, excluded)
names = {};
for i = 1:numel(channels)
    name = channels{i};
    if ~any(strcmpi(excluded, name)) && ~isSyntheticDisplayChannel(name) && ...
            (isIndexedChannel(roiObj, name) || isLikelyMaskName(name))
        names{end+1} = name; %#ok<AGROW>
    end
end
for i = 1:numel(families)
    if families(i).usable && ~any(strcmpi(names, families(i).maskProvider))
        names{end+1} = families(i).maskProvider; %#ok<AGROW>
    end
end
names = unique(names, 'stable');
end

function names = groundTruthChannelNames(spec)
names = {};
for i = 1:numel(spec.components)
    component = spec.components(i);
    if ~strcmp(char(string(component.storage)), 'channel'), continue; end
    try, name = char(string(component.groundTruth.channel)); catch, name = ''; end
    if ~isempty(name), names{end+1} = name; end %#ok<AGROW>
end
names = unique(names, 'stable');
end

function tf = isIndexedChannel(roiObj, name)
tf = false;
try
    channels = cellstr(string(roiObj.display.channel));
    idx = find(strcmpi(channels, char(string(name))), 1, 'first');
    indexed = logical(roiObj.display.indexed);
    if ~isempty(idx) && idx <= numel(indexed), tf = indexed(idx); end
catch
end
end

function tf = isLikelyMaskName(name)
value = lower(string(name));
tf = contains(value, "mask") || contains(value, "seg") || ...
    contains(value, "track") || startsWith(value, "results_") || ...
    endsWith(value, "_cell");
end

function tf = isSyntheticDisplayChannel(name)
value = regexprep(lower(char(string(name))), '[^a-z0-9]', '');
tf = strcmp(value, 'combinedchannel');
end

function channel = resolvedMaskPrediction(spec)
channel = '';
for i = 1:numel(spec.components)
    component = spec.components(i);
    if strcmp(char(string(component.storage)), 'channel')
        try, channel = char(string(component.prediction.channel)); catch, end
        if ~isempty(channel), return; end
    end
end
end

function recipe = blankRecipe()
recipe = struct('mode', 'blank', 'family', '', 'channel', '', ...
    'copyParentage', false);
end
