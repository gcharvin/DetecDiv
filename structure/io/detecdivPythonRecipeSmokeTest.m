function detecdivPythonRecipeSmokeTest()
% detecdivPythonRecipeSmokeTest  Keep canonical imports/install specs aligned.

recipe = detecdiv_python_recipe();
assert(any(strcmp(recipe.requiredImports, 'sklearn')), ...
    'The canonical runtime must verify the sklearn import.');
assert(isfield(recipe.packages, 'scikitLearn') && ...
    strcmp(recipe.packages.scikitLearn, 'scikit-learn'), ...
    'The sklearn import must map to the scikit-learn pip distribution.');

assertInstallSpecs(recipe.installSpecs.windows, ...
    recipe.packages.cellposeWindows, recipe);
assertInstallSpecs(recipe.installSpecs.wsl, ...
    recipe.packages.cellposeWsl, recipe);

fprintf('DetecDiv Python recipe smoke test passed.\n');
end

function assertInstallSpecs(specs, cellposeSpec, recipe)
assert(iscell(specs), 'Canonical pip installation specs must be a cell array.');
required = { ...
    recipe.packages.zarr, cellposeSpec, recipe.packages.trackastra, ...
    recipe.packages.scikitLearn};
for i = 1:numel(required)
    assert(any(strcmp(specs, required{i})), ...
        'Canonical pip installation is missing "%s".', required{i});
end
end
