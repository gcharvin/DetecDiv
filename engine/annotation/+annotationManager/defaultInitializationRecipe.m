function recipe = defaultInitializationRecipe(classif, catalog)
%ANNOTATIONMANAGER.DEFAULTINITIALIZATIONRECIPE Resolve saved or recommended UI choice.

recipe = catalog.recommended;
saved = struct();
try
    if isstruct(classif.trainingParam) && ...
            isfield(classif.trainingParam, 'annotationInitialization')
        saved = classif.trainingParam.annotationInitialization;
    end
catch
end
if ~isstruct(saved) || ~isfield(saved, 'mode'), return; end

candidate = normalizeRecipe(saved);
switch candidate.mode
    case 'prediction'
        valid = catalog.prediction.available;
        if valid
            candidate.family = catalog.prediction.family;
            candidate.channel = catalog.prediction.maskProvider;
        end
    case 'family'
        idx = find(strcmpi({catalog.families.name}, candidate.family), 1, 'first');
        valid = ~isempty(idx) && catalog.families(idx).usable;
        if valid, candidate.channel = catalog.families(idx).maskProvider; end
    case 'mask'
        valid = any(strcmpi(catalog.maskChannels, candidate.channel));
    otherwise
        valid = strcmp(candidate.mode, 'blank');
end
if valid, recipe = candidate; end
end

function recipe = normalizeRecipe(value)
recipe = struct('mode', 'blank', 'family', '', 'channel', '', ...
    'copyParentage', false);
fields = fieldnames(recipe);
for i = 1:numel(fields)
    name = fields{i};
    if isfield(value, name), recipe.(name) = value.(name); end
end
recipe.mode = lower(char(string(recipe.mode)));
recipe.family = char(string(recipe.family));
recipe.channel = char(string(recipe.channel));
recipe.copyParentage = logical(recipe.copyParentage);
end
