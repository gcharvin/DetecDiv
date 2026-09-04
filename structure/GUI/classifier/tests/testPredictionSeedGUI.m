function tests = testPredictionSeedGUI
%TESTPREDICTIONSEEDGUI Test the active-model GT initialization UI contract.
tests = functiontests(localfunctions);
end

function setupOnce(~)
repoRoot = fileparts(fileparts(fileparts(fileparts(fileparts( ...
    mfilename('fullpath'))))));
addpath(repoRoot);
detecdiv_setup_path;
end

function testTrainedLatentClassifierExposesActiveModel(testCase)
folder = freshFolder(testCase);
c = classi(folder, 'latent_seed', 1);
c.classifierPkg = 'cellLatentModel';
modelFolder = fullfile(c.path, 'models', 'model_v002');
mkdir(modelFolder);
manifest = fullfile(modelFolder, 'composite_manifest.json');
writeText(manifest, '{}');
c.executionParam = struct('modelSource', 'trained', ...
    'compositeManifestPath', fullfile('models', 'model_v002', ...
        'composite_manifest.json'), ...
    'instanceChannelName', 'results_cellposeSAM_cell', ...
    'brightfieldChannelName', 'Channel1_z2');

info = annotationActiveModelInfo(c, 6);
verifyTrue(testCase, info.available);
verifyFalse(testCase, info.usesGroundTruth);
verifyEqual(testCase, info.roiIndices, 6);
verifyEqual(testCase, info.modelReference, manifest);
verifyTrue(testCase, any(contains(string(info.inputs), ...
    'results_cellposeSAM_cell')));
verifyTrue(testCase, any(contains(string(info.inputs), 'Channel1_z2')));
end

function testPostTrainingSnapshotOverridesStaleExecutionParam(testCase)
folder = freshFolder(testCase);
c = classi(folder, 'latent_seed_snapshot', 1);
c.classifierPkg = 'cellLatentModel';
c.executionParam = struct('modelSource', 'builtin', 'backend', 'legacy');
modelFolder = fullfile(c.path, 'models', 'model_cell_latent_composite_v004');
mkdir(modelFolder);
manifest = fullfile(modelFolder, 'manifest.json');
writeText(manifest, '{}');
payload = struct( ...
    'schemaVersion', 1, ...
    'classifierId', char(string(c.strid)), ...
    'classifierPackage', 'cellLatentModel', ...
    'executionDefaults', struct( ...
        'modelSource', 'trained', ...
        'backend', 'causal_composite', ...
        'compositeManifestPath', fullfile('models', ...
            'model_cell_latent_composite_v004', 'manifest.json'), ...
        'instanceChannelName', 'results_cellposeSAM_cell', ...
        'brightfieldChannelName', 'Channel1_z2'));
writeText(fullfile(c.path, 'training_execution_defaults.json'), ...
    jsonencode(payload, 'PrettyPrint', true));

info = annotationActiveModelInfo(c, 4);
verifyTrue(testCase, info.available);
verifyEqual(testCase, info.modelReference, manifest);
verifyEqual(testCase, info.modelLabel, 'composite manifest');
verifyTrue(testCase, any(contains(string(info.inputs), ...
    'results_cellposeSAM_cell')));
verifyTrue(testCase, any(contains(string(info.inputs), 'Channel1_z2')));
end

function testCellposeSAMExposesDirectSegmentationChoice(testCase)
folder = freshFolder(testCase);
c = classi(folder, 'cellpose_seed', 1);
c.classifierPkg = 'cellposesam';
c.classifyFun = 'cellposesam.classify';
c.category = {'Pixel'};
c.classes = {'cell'};
c.channelName = 'Channel0';
modelFolder = fullfile(c.path, 'models');
mkdir(modelFolder);
modelFile = fullfile(modelFolder, c.strid);
writeText(modelFile, 'fixture');
r = roi('Pos0_1_1', [1 1 4 4]);
r.path = c.path;
r.image = uint16(ones(4,4,1,2));
r.channelid = 1;
r.display.channel = {'Channel0'};
r.display.intensity = [1 1 1];
r.display.rgb = [1 1 1];
r.display.selectedchannel = true;
r.display.indexed = false;
r.display.alpha = 1;
r.display.contour = false;
r.display.width = 1;
c.roi = r;

plan = classifierPredictForAnnotation(c, 1, 'PlanOnly', true);
info = annotationActiveModelInfo(c, 1, plan);
[labels, ids] = annotationInitializationModes(minimalCatalog(false), info);

verifyTrue(testCase, info.available);
verifyTrue(testCase, info.canRunOnExistingInputs);
verifyEqual(testCase, info.modelReference, modelFile);
verifyTrue(testCase, any(strcmp(ids, 'run_prediction')));
verifyTrue(testCase, any(contains(string(labels), ...
    'Run active CellposeSAM model')));

delete(modelFile);
fallbackPlan = classifierPredictForAnnotation(c, 1, 'PlanOnly', true);
fallbackInfo = annotationActiveModelInfo(c, 1, fallbackPlan);
[fallbackLabels, fallbackIds] = annotationInitializationModes( ...
    minimalCatalog(false), fallbackInfo);
verifyTrue(testCase, any(strcmp(fallbackIds, 'run_prediction')));
verifyTrue(testCase, any(contains(string(fallbackLabels), ...
    'Run default CellposeSAM model')));
end

function testExistingAndFreshPredictionChoicesRemainSeparate(testCase)
catalog = minimalCatalog(true);
active = struct('available', true, 'canRunOnExistingInputs', true, ...
    'releaseId', 'latent-v54-parent-ensemble-v002');
[labels, ids] = annotationInitializationModes(catalog, active);
verifyTrue(testCase, any(strcmp(ids, 'prediction')));
verifyTrue(testCase, any(strcmp(ids, 'run_prediction')));
verifyTrue(testCase, any(contains(string(labels), 'Copy existing PRED')));
verifyTrue(testCase, any(contains(string(labels), ...
    'latent-v54-parent-ensemble-v002')));
end

function testRunChoiceAppearsWithoutExistingPrediction(testCase)
catalog = minimalCatalog(false);
[~, ids] = annotationInitializationModes(catalog, struct( ...
    'available', true, 'canRunOnExistingInputs', true));
verifyFalse(testCase, any(strcmp(ids, 'prediction')));
verifyTrue(testCase, any(strcmp(ids, 'run_prediction')));
[~, ids] = annotationInitializationModes(catalog, struct('available', false));
verifyFalse(testCase, any(strcmp(ids, 'run_prediction')));
end

function testRunChoiceHiddenWithoutCompatiblePredMask(testCase)
catalog = minimalCatalog(false);
active = struct('available', true, 'canRunOnExistingInputs', false, ...
    'inputsResolved', false);
[labels, ids] = annotationInitializationModes(catalog, active);
verifyFalse(testCase, any(strcmp(ids, 'run_prediction')));
verifyEmpty(testCase, labels);
verifyEmpty(testCase, ids);
[recipe, available] = annotationInitializationDefaultRecipe(catalog, active);
verifyFalse(testCase, available);
verifyEmpty(testCase, recipe.mode);

root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
dialogSource = fileread(fullfile(root, 'annotationInitializationDialog.m'));
verifyTrue(testCase, contains(dialogSource, ...
    'Run CellposeSAM separately, click'));
verifyTrue(testCase, contains(dialogSource, ...
    'CellposeSAM is never launched'));
end

function testPlanKeepsModelRunnableButRequestsOnlyAmbiguousInput(testCase)
folder = freshFolder(testCase);
checkpoint = fullfile(folder, 'model.pt');
writeText(checkpoint, 'fixture');
c = classi(folder, 'latent_seed_plan', 1);
c.classifierPkg = 'cellLatentModel';
c.executionParam = struct('modelSource', 'trained', ...
    'modelPath', checkpoint);

resolution = struct( ...
    'instanceChannelName', resolutionRow('', ...
        {'results_cellposeSAM_cell','other_mask'}, true), ...
    'brightfieldChannelName', resolutionRow('Channel1_z2', ...
        {'Channel1_z2'}, false));
inputs = struct('resolution', resolution, 'usesGroundTruth', false);
item = struct('roiIndex', 7, 'roiId', 'Pos0_1_51', 'inputs', inputs);
plan = struct('available', false, ...
    'issues', {{'Instance-mask input is ambiguous.'}}, ...
    'model', struct('modelSource', 'trained', 'available', true, ...
        'modelPath', checkpoint), 'items', item);

info = annotationActiveModelInfo(c, 7, plan);
verifyTrue(testCase, info.available, ...
    'A resolvable input ambiguity must not hide the active-model action.');
verifyFalse(testCase, info.inputsResolved);
verifyTrue(testCase, info.inputMappingRequired);
verifyTrue(testCase, info.canRunOnExistingInputs);
verifyFalse(testCase, info.usesGroundTruth);
requests = annotationInputMappingRequests(plan);
verifyNumElements(testCase, requests, 1);
verifyEqual(testCase, requests.selector, 'instanceChannelName');
verifyEqual(testCase, requests.candidates, ...
    {'results_cellposeSAM_cell','other_mask'});
end

function testUnrelatedInputMappingDoesNotExposeLatentWithoutMask(testCase)
folder = freshFolder(testCase);
checkpoint = fullfile(folder, 'model.pt');
writeText(checkpoint, 'fixture');
c = classi(folder, 'latent_seed_missing_mask', 1);
c.classifierPkg = 'cellLatentModel';
c.executionParam = struct('modelSource', 'trained', 'modelPath', checkpoint);

resolution = struct( ...
    'instanceChannelName', resolutionRow('', {}, false), ...
    'brightfieldChannelName', resolutionRow('', ...
        {'Channel1_z2','Channel2_z2'}, true));
inputs = struct('resolution', resolution, 'usesGroundTruth', false);
item = struct('roiIndex', 7, 'roiId', 'Pos0_1_51', 'inputs', inputs);
plan = struct('available', false, 'canRun', false, ...
    'issues', {{'Instance-mask input is missing.'}}, ...
    'model', struct('modelSource', 'trained', 'available', true, ...
        'modelPath', checkpoint), 'items', item);

info = annotationActiveModelInfo(c, 7, plan);
verifyTrue(testCase, info.available);
verifyTrue(testCase, info.inputMappingRequired, ...
    'The unrelated brightfield ambiguity remains user-configurable.');
verifyFalse(testCase, info.hasExistingMaskInputs);
verifyFalse(testCase, info.canRunOnExistingInputs);
[~, ids] = annotationInitializationModes(minimalCatalog(false), info);
verifyFalse(testCase, any(strcmp(ids, 'run_prediction')));
end

function testMultiRoiCatalogKeepsOnlySourcesSharedByEveryRoi(testCase)
first = sourceCatalog(true, true, true);
second = sourceCatalog(false, false, false);
common = annotationCommonInitializationCatalog({first, second});
[labels, ids] = annotationInitializationModes(common, struct('available', false));
verifyEmpty(testCase, labels);
verifyEmpty(testCase, ids);
[recipe, available] = annotationInitializationDefaultRecipe(common, struct());
verifyFalse(testCase, available);
verifyEmpty(testCase, recipe.mode);
end

function testSavedBlankRecipeCannotBypassSourceOnlyContract(testCase)
catalog = sourceCatalog(false, false, true);
catalog.defaultRecipe = struct('mode', 'blank', 'family', '', ...
    'channel', '', 'copyParentage', false);
[recipe, available] = annotationInitializationDefaultRecipe(catalog, struct());
verifyTrue(testCase, available);
verifyEqual(testCase, recipe.mode, 'mask');
verifyEqual(testCase, recipe.channel, 'results_cellposeSAM_cell');
end

function testRuntimeCallbacksUsePackageAwarePredictionInitialization(testCase)
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
classifierSource = fileread(fullfile(root, 'classifier', 'private', ...
    'classifierGUI_runtime_code.m'));
scoreSource = fileread(fullfile(root, 'score', 'private', ...
    'score_runtime_code.m'));
for source = {classifierSource, scoreSource}
    verifyTrue(testCase, contains(source{1}, ...
        'classifierPredictForAnnotation'));
    verifyTrue(testCase, contains(source{1}, '''PlanOnly'', true'));
    verifyTrue(testCase, contains(source{1}, '''InitializeGT'', true'));
    verifyTrue(testCase, contains(source{1}, '''OverwriteGT'', overwrite'));
    verifyTrue(testCase, contains(source{1}, '''ActiveModel'', activeModel'));
    verifyTrue(testCase, contains(source{1}, ...
        'annotationPredictionUiText'));
    verifyTrue(testCase, contains(source{1}, ...
        'annotationInitializationDefaultRecipe'));
    verifyTrue(testCase, contains(source{1}, ...
        'annotationInitializationUnavailableMessage'));
    verifyFalse(testCase, contains(source{1}, ...
        'recipe = catalog.defaultRecipe'));
    verifyFalse(testCase, contains(source{1}, ...
        '''PrepareMissingInstanceMasks'', true'));
    verifyFalse(testCase, contains(source{1}, '''CellposeSAMParams'''));
end
verifyTrue(testCase, contains(classifierSource, ...
    'annotationCommonInitializationCatalog'));
modeSource = fileread(fullfile(root, 'annotationInitializationModes.m'));
verifyFalse(testCase, contains(modeSource, '''Blank GT'''));
resolverSource = fileread(fullfile(root, ...
    'annotationResolvePredictionInputs.m'));
verifyFalse(testCase, contains(resolverSource, ...
    'annotationCellposeSAMPreparationDialog('));
verifyTrue(testCase, contains(resolverSource, ...
    'Run CellposeSAM from Initialize GT'));
uiTextSource = fileread(fullfile(root, 'annotationPredictionUiText.m'));
verifyTrue(testCase, contains(uiTextSource, ...
    'Segmenting selected ROI image(s) with CellposeSAM'));
verifyTrue(testCase, contains(uiTextSource, ...
    'Applying latent model to existing masks/tracks'));
end

function testPackedAppsExcludeImplicitCellposePreparation(testCase)
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
paths = {fullfile(root, 'classifierGUI.mlapp'), ...
    fullfile(root, 'score', 'score.mlapp')};
legacy = {'PrepareMissingInstanceMasks', 'CellposeSAMParams', ...
    'CellposeSAM masks generated', 'annotationCellposeSAMPreparationDialog'};
for i = 1:numel(paths)
    unpacked = freshFolder(testCase);
    unzip(paths{i}, unpacked);
    documentPath = fullfile(unpacked, 'matlab', 'document.xml');
    verifyTrue(testCase, isfile(documentPath), ...
        sprintf('Missing document.xml in %s.', paths{i}));
    source = fileread(documentPath);
    for j = 1:numel(legacy)
        verifyFalse(testCase, contains(source, legacy{j}), ...
            sprintf('%s still contains legacy token %s.', paths{i}, legacy{j}));
    end
    verifyTrue(testCase, contains(source, ...
        'annotationPredictionUiText'));
    verifyTrue(testCase, contains(source, ...
        'annotationInitializationDefaultRecipe'));
    verifyTrue(testCase, contains(source, ...
        'annotationInitializationUnavailableMessage'));
    verifyFalse(testCase, contains(source, ...
        'recipe = catalog.defaultRecipe'));
end
end

function catalog = minimalCatalog(hasPrediction)
families = repmat(struct('usable', false), 0, 1);
catalog = struct( ...
    'prediction', struct('available', logical(hasPrediction)), ...
    'families', families, 'maskChannels', {{}}, ...
    'supports', struct('family', false, 'mask', false));
end

function catalog = sourceCatalog(hasPrediction, hasFamily, hasMask)
family = repmat(struct('name', '', 'maskProvider', '', 'usable', false, ...
    'relationCount', 0), 0, 1);
if hasFamily
    family = struct('name', 'latent_pred', ...
        'maskProvider', 'results_cellposeSAM_cell', 'usable', true, ...
        'relationCount', 2);
end
channels = {};
if hasMask, channels = {'results_cellposeSAM_cell'}; end
catalog = struct( ...
    'prediction', struct('available', logical(hasPrediction), ...
        'family', 'latent_pred', ...
        'maskProvider', 'results_cellposeSAM_cell'), ...
    'families', family, 'maskChannels', {channels}, ...
    'supports', struct('family', true, 'mask', true), ...
    'defaultRecipe', struct('mode', 'blank', 'family', '', ...
        'channel', '', 'copyParentage', false));
end

function value = resolutionRow(selected, candidates, ambiguous)
value = struct('selected', selected, 'strategy', 'fixture', ...
    'candidates', {candidates}, 'ambiguous', logical(ambiguous));
end

function folder = freshFolder(testCase)
folder = tempname;
mkdir(folder);
testCase.addTeardown(@() removeFolder(folder));
end

function writeText(path, value)
fid = fopen(path, 'w');
assert(fid >= 0, 'Could not create test fixture.');
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fwrite(fid, value, 'char');
end

function removeFolder(folder)
if isfolder(folder), rmdir(folder, 's'); end
end
