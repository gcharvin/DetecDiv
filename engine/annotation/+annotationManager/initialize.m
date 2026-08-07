function report = initialize(classif, roiObj, spec, recipe, varargin)
%ANNOTATIONMANAGER.INITIALIZE Create GT from prediction, existing assets or blank.

p = inputParser;
p.addParameter('Overwrite', false, @(x) islogical(x) && isscalar(x));
p.addParameter('Save', true, @(x) islogical(x) && isscalar(x));
p.addParameter('SourceRunId', '', @(x) ischar(x) || isstring(x));
p.parse(varargin{:});

catalog = annotationManager.initializationCatalog(roiObj, spec);
recipe = normalizeRecipe(recipe);
switch recipe.mode
    case 'prediction'
        if ~catalog.prediction.available
            error('annotationManager:MissingPredictionFamily', ...
                'The classifier prediction family "%s" is unavailable or has no mask provider.', ...
                catalog.prediction.family);
        end
        recipe.family = catalog.prediction.family;
        recipe.channel = catalog.prediction.maskProvider;
        configured = spec;
        if ~isempty(recipe.family)
            configured = configureFamilySource(spec, recipe.family, recipe.channel);
            sourceId = sourceDescription(recipe, catalog.prediction.trackCount, ...
                catalog.prediction.relationCount);
        else
            sourceId = 'classifier prediction';
        end
        report = annotationManager.bootstrap(classif, roiObj, configured, ...
            'Overwrite', p.Results.Overwrite, 'Save', p.Results.Save, ...
            'SourceRunId', p.Results.SourceRunId, ...
            'CopyRelations', recipe.copyParentage, ...
            'SourceType', 'prediction', 'SourceId', sourceId);

    case 'family'
        family = findFamily(catalog, recipe.family);
        if isempty(family) || ~family.usable
            error('annotationManager:MissingInitializationFamily', ...
                'Object family "%s" is unavailable or has no readable mask provider.', ...
                recipe.family);
        end
        recipe.family = family.name;
        recipe.channel = family.maskProvider;
        configured = configureFamilySource(spec, recipe.family, recipe.channel);
        sourceId = sourceDescription(recipe, family.trackCount, family.relationCount);
        report = annotationManager.bootstrap(classif, roiObj, configured, ...
            'Overwrite', p.Results.Overwrite, 'Save', p.Results.Save, ...
            'SourceRunId', p.Results.SourceRunId, ...
            'CopyRelations', recipe.copyParentage, ...
            'SourceType', 'existing_family', 'SourceId', sourceId);

    case 'mask'
        channel = resolveAvailableChannel(catalog.channels, recipe.channel);
        if isempty(channel)
            error('annotationManager:MissingInitializationMask', ...
                'Segmentation channel "%s" is unavailable.', recipe.channel);
        end
        recipe.channel = channel;
        report = initializeFromMask(classif, roiObj, spec, recipe, p.Results);

    case 'blank'
        report = annotationManager.startBlank(classif, roiObj, spec, ...
            'Overwrite', p.Results.Overwrite, 'Save', p.Results.Save);

    otherwise
        error('annotationManager:UnknownInitializationMode', ...
            'Unknown GT initialization mode "%s".', recipe.mode);
end

report.recipe = recipe;
rememberRecipe(classif, recipe);
end

function report = initializeFromMask(classif, roiObj, spec, recipe, options)
maskIndex = findMaskComponent(spec);
if isempty(maskIndex)
    error('annotationManager:UnsupportedMaskInitialization', ...
        'This classifier has no channel-backed segmentation GT component.');
end

% Materialize every GT component as blank first, but keep the operation
% unsaved until the requested source mask has been copied successfully.
blankReport = annotationManager.startBlank(classif, roiObj, spec, ...
    'Overwrite', options.Overwrite, 'Save', false);
configured = spec;
for i = 1:numel(configured.components)
    configured.components(i).bootstrap = 'none';
end
configured.components(maskIndex).bootstrap = 'copy_channel';
configured.components(maskIndex).prediction = annotationManager.newAsset( ...
    'channel', recipe.channel, 'channelCandidates', {recipe.channel});
sourceId = sourceDescription(recipe, 0, 0);
copyReport = annotationManager.bootstrap(classif, roiObj, configured, ...
    'Overwrite', true, 'Save', false, ...
    'SourceRunId', options.SourceRunId, ...
    'SourceType', 'existing_mask', 'SourceId', sourceId);

if options.Save
    channels = unique([blankReport.channelsSaved copyReport.channelsSaved], 'stable');
    if ~isempty(channels), roiObj.save(channels, false); end
    if blankReport.modelChanged, roiObj.saveCellModel(roiObj.cellModel); end
    copyReport.entry = annotationManager.setEntry( ...
        roiObj, spec, copyReport.entry, 'Save', true);
end
report = copyReport;
report.modelChanged = blankReport.modelChanged;
end

function configured = configureFamilySource(spec, family, channel)
configured = spec;
hasFamilyComponent = false;
for i = 1:numel(configured.components)
    component = configured.components(i);
    storage = char(string(component.storage));
    if strcmp(storage, 'channel') && isMaskKind(component.kind)
        configured.components(i).prediction = annotationManager.newAsset( ...
            'channel', channel, 'channelCandidates', {channel}, ...
            'family', family);
    elseif strcmp(storage, 'cell_model_family')
        configured.components(i).prediction.family = family;
        hasFamilyComponent = true;
    end
end
if ~hasFamilyComponent
    error('annotationManager:UnsupportedFamilyInitialization', ...
        'This classifier has no object-family GT component.');
end
end

function tf = isMaskKind(kind)
tf = any(strcmp(char(string(kind)), ...
    {'tracked_instances','instances','semantic_mask','instance_mask','mask'}));
end

function index = findMaskComponent(spec)
index = [];
for i = 1:numel(spec.components)
    if strcmp(char(string(spec.components(i).storage)), 'channel') && ...
            isMaskKind(spec.components(i).kind)
        index = i;
        return;
    end
end
end

function family = findFamily(catalog, name)
family = [];
idx = find(strcmpi({catalog.families.name}, char(string(name))), 1, 'first');
if ~isempty(idx), family = catalog.families(idx); end
end

function channel = resolveAvailableChannel(channels, requested)
channel = '';
idx = find(strcmpi(channels, char(string(requested))), 1, 'first');
if ~isempty(idx), channel = channels{idx}; end
end

function recipe = normalizeRecipe(value)
template = struct('mode', 'blank', 'family', '', 'channel', '', ...
    'copyParentage', false);
if nargin < 1 || isempty(value), value = template; end
recipe = template;
fields = fieldnames(template);
for i = 1:numel(fields)
    if isstruct(value) && isfield(value, fields{i})
        recipe.(fields{i}) = value.(fields{i});
    end
end
recipe.mode = lower(char(string(recipe.mode)));
recipe.family = char(string(recipe.family));
recipe.channel = char(string(recipe.channel));
recipe.copyParentage = logical(recipe.copyParentage);
end

function text = sourceDescription(recipe, trackCount, relationCount)
switch recipe.mode
    case {'prediction','family'}
        if recipe.copyParentage
            parentage = sprintf('%d links', relationCount);
        else
            parentage = 'blank parentage';
        end
        text = sprintf('mask: %s | tracks: %s (%d) | %s', ...
            recipe.channel, recipe.family, trackCount, parentage);
    case 'mask'
        text = sprintf('mask: %s | tracks: blank | parentage: blank', ...
            recipe.channel);
    otherwise
        text = 'blank GT';
end
end

function rememberRecipe(classif, recipe)
try
    if isempty(classif) || ~isprop(classif, 'trainingParam') || ...
            ~isstruct(classif.trainingParam)
        return;
    end
    classif.trainingParam.annotationInitialization = recipe;
catch
end
end
