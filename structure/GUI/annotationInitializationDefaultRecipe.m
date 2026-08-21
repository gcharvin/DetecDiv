function [recipe, available] = annotationInitializationDefaultRecipe(catalog, activeModel)
%ANNOTATIONINITIALIZATIONDEFAULTRECIPE Pick a source-backed GT recipe only.

if nargin < 2, activeModel = struct(); end
[~, ids] = annotationInitializationModes(catalog, activeModel);
recipe = struct('mode', '', 'family', '', 'channel', '', ...
    'copyParentage', false);
available = ~isempty(ids);
if ~available, return; end

try
    candidate = catalog.defaultRecipe;
    if isstruct(candidate) && isfield(candidate, 'mode')
        candidate = normalizeRecipe(candidate);
    end
    if isstruct(candidate) && sourceRecipeIsUsable(candidate, catalog, ...
            activeModel, ids)
        recipe = canonicalizeRecipe(candidate, catalog);
        return;
    end
catch
end

recipe.mode = ids{1};
switch recipe.mode
    case 'prediction'
        recipe.family = char(string(catalog.prediction.family));
        recipe.channel = char(string(catalog.prediction.maskProvider));
        recipe.copyParentage = true;
    case 'run_prediction'
        recipe.copyParentage = true;
    case 'family'
        families = catalog.families([catalog.families.usable]);
        recipe.family = families(1).name;
        recipe.channel = families(1).maskProvider;
        recipe.copyParentage = families(1).relationCount > 0;
    case 'mask'
        recipe.channel = catalog.maskChannels{1};
end
end

function tf = sourceRecipeIsUsable(recipe, catalog, activeModel, ids)
tf = any(strcmp(ids, recipe.mode));
if ~tf, return; end
switch recipe.mode
    case 'prediction'
        tf = logical(catalog.prediction.available);
    case 'run_prediction'
        tf = false;
        try
            tf = logical(activeModel.available) && ...
                logical(activeModel.canRunOnExistingInputs);
        catch
        end
    case 'family'
        tf = any(strcmpi({catalog.families.name}, recipe.family) & ...
            [catalog.families.usable]);
    case 'mask'
        tf = any(strcmpi(catalog.maskChannels, recipe.channel));
    otherwise
        tf = false;
end
end

function recipe = canonicalizeRecipe(recipe, catalog)
switch recipe.mode
    case 'prediction'
        recipe.family = char(string(catalog.prediction.family));
        recipe.channel = char(string(catalog.prediction.maskProvider));
        recipe.copyParentage = true;
    case 'family'
        index = find(strcmpi({catalog.families.name}, recipe.family), 1, 'first');
        recipe.family = catalog.families(index).name;
        recipe.channel = catalog.families(index).maskProvider;
    case 'mask'
        index = find(strcmpi(catalog.maskChannels, recipe.channel), 1, 'first');
        recipe.channel = catalog.maskChannels{index};
        recipe.copyParentage = false;
end
end

function recipe = normalizeRecipe(value)
recipe = struct('mode', '', 'family', '', 'channel', '', ...
    'copyParentage', false);
fields = fieldnames(recipe);
for i = 1:numel(fields)
    if isfield(value, fields{i}), recipe.(fields{i}) = value.(fields{i}); end
end
recipe.mode = char(string(recipe.mode));
recipe.family = char(string(recipe.family));
recipe.channel = char(string(recipe.channel));
recipe.copyParentage = logical(recipe.copyParentage);
end
