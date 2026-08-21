function tests = testClassifierPredictionMaskPreparation
%TESTCLASSIFIERPREDICTIONMASKPREPARATION Existing-mask-only seed workflow.
tests = functiontests(localfunctions);
end

function setupOnce(~)
repoRoot = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(genpath(repoRoot));
end

function testMissingMaskPlanIsBlockedWithoutWriting(testCase)
[c, r] = fixture(testCase);
splitBefore = c.dataset.split;
gtBefore = channelStack(r, 'gt_latent_model_1_stable_tracks');
channelCount = size(r.image, 3);

plan = classifierPredictForAnnotation(c, 1, 'PlanOnly', true);

verifyFalse(testCase, plan.available);
verifyFalse(testCase, plan.canRun);
verifyFalse(testCase, plan.canPrepare);
verifyFalse(testCase, plan.requiresPreparation);
verifyFalse(testCase, plan.items.canRun);
verifyFalse(testCase, plan.items.canPrepare);
verifyFalse(testCase, plan.items.requiresPreparation);
verifyEmpty(testCase, plan.items.inputs.instanceChannelName);
verifyTrue(testCase, any(contains(string(plan.issues), ...
    'Run CellposeSAM', 'IgnoreCase', true)));
verifyTrue(testCase, any(contains(string(plan.issues), ...
    'click Refresh status', 'IgnoreCase', true)));
verifyEqual(testCase, c.dataset.split, splitBefore);
verifyEqual(testCase, size(r.image, 3), channelCount);
verifyEqual(testCase, channelStack(r, ...
    'gt_latent_model_1_stable_tracks'), gtBefore);
end

function testMissingMaskCannotInvokeLatentOrCreateGt(testCase)
[c, r] = fixture(testCase);
called = false;
gtBefore = channelStack(r, 'gt_latent_model_1_stable_tracks');

verifyError(testCase, @()classifierPredictForAnnotation(c, 1, ...
    'InitializeGT', true, 'Save', false, 'Executor', @executor), ...
    'classifierPredictForAnnotation:InputsNotReady');

verifyFalse(testCase, called);
verifyEqual(testCase, channelStack(r, ...
    'gt_latent_model_1_stable_tracks'), gtBefore);

    function executor(varargin) %#ok<INUSD>
        called = true;
    end
end

function testBlankMaskStubIsNotAccepted(testCase)
[c, r] = fixture(testCase);
r.addChannel(uint16(zeros(4,4,1,3)), 'results_cellposeSAM_cell', ...
    [1 1 1], [0 0 0]);

plan = classifierPredictForAnnotation(c, 1, 'PlanOnly', true);

verifyFalse(testCase, plan.available);
verifyFalse(testCase, plan.canRun);
verifyEmpty(testCase, plan.items.inputs.instanceChannelName);
verifyTrue(testCase, any(contains(string(plan.issues), ...
    'Run CellposeSAM', 'IgnoreCase', true)));
end

function testExternalProducerRecipeIsNeverDiscoveredOrExecuted(testCase)
[c, r] = fixture(testCase);
experimentRoot = tempname;
mkdir(fullfile(experimentRoot, 'classifier', 'latent_model_1'));
addTeardown(testCase, @()removeFolder(experimentRoot));
c.path = [fullfile(experimentRoot, 'classifier', 'latent_model_1') filesep];

producerPath = fullfile(experimentRoot, 'producer', 'cellpose_4');
mkdir(fullfile(producerPath, 'models'));
touch(fullfile(producerPath, 'models', 'cellpose_4'));
moduleFolder = fullfile(experimentRoot, 'pipeline', 'p1', 'modules', ...
    'classifier_cellposesam_1');
mkdir(moduleFolder);
payload = struct('pkg', 'cellposesam', 'params', struct( ...
    'outputName', 'cellposeSAM', 'modulePath', producerPath, ...
    'moduleId', 'cellpose_4', 'channels', 'Channel1_z2'));
writeJson(fullfile(moduleFolder, 'module.json'), payload);
producerBefore = treeSignature(producerPath);

plan = classifierPredictForAnnotation(c, 1, 'PlanOnly', true);

verifyFalse(testCase, plan.canRun);
verifyFalse(testCase, plan.canPrepare);
verifyFalse(testCase, isfield(plan.items, 'preparation'));
verifyEqual(testCase, treeSignature(producerPath), producerBefore);
verifyEmpty(testCase, r.findChannelID('results_cellposeSAM_cell'));
source = fileread(which('classifierPredictForAnnotation'));
verifyFalse(testCase, contains(source, 'resolveCellposePreparation'));
verifyFalse(testCase, contains(source, 'InstanceMaskExecutor'));
verifyFalse(testCase, contains(source, 'PrepareMissingInstanceMasks'));
end

function testGroundTruthLookingObservationIsNeverUsed(testCase)
[c, r] = fixture(testCase);
r.removeChannel('Channel1_z2');
r.addChannel(uint16(ones(4,4,1,3)), 'gt_other_brightfield', ...
    [1 1 1], [1 1 1]);

plan = classifierPredictForAnnotation(c, 1, 'PlanOnly', true);

verifyFalse(testCase, plan.canRun);
verifyEmpty(testCase, plan.items.inputs.brightfieldChannelName);
verifyFalse(testCase, any(strcmpi( ...
    plan.items.inputs.requiredChannels, 'gt_other_brightfield')));
verifyTrue(testCase, any(strcmpi( ...
    plan.items.inputs.forbiddenGroundTruthChannels, ...
    'gt_other_brightfield')));
end

function [c, r] = fixture(testCase)
root = tempname;
mkdir(root);
addTeardown(testCase, @()removeFolder(root));
c = classi(root, 'latent_model', 1);
c.classifierPkg = 'cellLatentModel';
c.classifyFun = 'cellLatentModel.classify';
c.category = {'Tracking'};
c.classes = {'latent lineage link'};

modelFile = fullfile(c.path, 'lineage.pt');
manifestFile = fullfile(c.path, 'composite_manifest.json');
trackingDir = fullfile(c.path, 'tracking');
mkdir(trackingDir);
touch(modelFile);
touch(manifestFile);
touch(fullfile(trackingDir, 'manifest.json'));
c.executionParam = struct( ...
    'backend', 'causal_composite', ...
    'instanceChannelName', 'gt_latent_model_1_stable_tracks', ...
    'brightfieldChannelName', 'Channel1_z2', ...
    'nucleusChannelName', '', 'budneckChannelName', '', ...
    'frameIntervalMinutes', 5, ...
    'outputTrackChannelName', 'pred_latent_model_tracks', ...
    'outputFamilyName', 'pred_latent_lineage_mother_null', ...
    'modelSource', 'trained', 'modelPath', modelFile, ...
    'compositeManifestPath', manifestFile, ...
    'trackingCheckpointDir', trackingDir, 'stateUpdateMode', 'none');
c.trainingParam = struct('instanceChannelName', ...
    'gt_latent_model_1_stable_tracks', 'trackChannelName', ...
    'gt_latent_model_1_stable_tracks', 'brightfieldChannelName', ...
    'Channel1_z2');
c.channelName = {'gt_latent_model_1_stable_tracks','Channel1_z2'};
c.dataset.split = struct('train', 1, 'val', [], 'test', 1);

r = roi('Pos0_1_51', [1 1 4 4]);
r.path = c.path;
r.image = uint16(ones(4,4,1,3));
r.channelid = 1;
r.display.channel = {'Channel1_z2'};
r.display.intensity = [1 1 1];
r.display.rgb = [1 1 1];
r.display.selectedchannel = true;
r.display.indexed = false;
r.display.alpha = 1;
r.display.contour = false;
r.display.width = 1;
r.addChannel(uint16(zeros(4,4,1,3)), ...
    'gt_latent_model_1_stable_tracks', [1 1 1], [0 0 0]);
c.roi = r;
end

function stack = channelStack(roiObj, name)
index = roiObj.findChannelID(name);
if isempty(index), stack = []; return; end
stack = uint16(roiObj.image(:,:,index,:));
end

function touch(path)
fid = fopen(path, 'w');
assert(fid >= 0, 'Could not create test artifact %s.', path);
fclose(fid);
end

function writeJson(path, payload)
fid = fopen(path, 'w');
assert(fid >= 0, 'Could not create test JSON %s.', path);
cleanup = onCleanup(@()fclose(fid));
fwrite(fid, jsonencode(payload), 'char');
clear cleanup;
end

function signature = treeSignature(root)
files = dir(fullfile(root, '**', '*'));
files = files(~[files.isdir]);
signature = strings(numel(files), 1);
for i = 1:numel(files)
    signature(i) = string(fullfile(files(i).folder, files(i).name)) + ...
        "|" + string(files(i).bytes) + "|" + string(files(i).datenum);
end
signature = sort(signature);
end

function removeFolder(folder)
if isfolder(folder), rmdir(folder, 's'); end
end
