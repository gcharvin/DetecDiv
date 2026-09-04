function tests = testClassifierPredictForAnnotation
%TESTCLASSIFIERPREDICTFORANNOTATION Direct PRED-to-Draft workflow tests.
tests = functiontests(localfunctions);
end

function setupOnce(~)
repoRoot = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(genpath(repoRoot));
end

function setup(~)
clearAnnotationPredictionProbe();
end

function teardown(~)
clearAnnotationPredictionProbe();
end

function testPlanPrefersCellposePredictionAndRejectsGtInput(testCase)
[c, r] = fixture(testCase);
beforeSplit = c.dataset.split;
markIndexed(r, 'Channel1_z2');

plan = classifierPredictForAnnotation(c, 1, 'PlanOnly', true);

verifyTrue(testCase, plan.available, strjoin(plan.issues, ' '));
verifyTrue(testCase, plan.canRun);
verifyFalse(testCase, plan.usesGroundTruth);
verifyEqual(testCase, plan.items.inputs.instanceChannelName, ...
    'results_cellposeSAM_cell');
verifyEqual(testCase, ...
    plan.items.inputs.resolution.instanceChannelName.strategy, ...
    'preferred_cellposesam_prediction');
verifyFalse(testCase, any(strcmpi( ...
    plan.items.inputs.resolution.instanceChannelName.candidates, ...
    'Channel1_z2')), ...
    'An indexed raw acquisition channel must not become a mask candidate.');
verifyFalse(testCase, plan.items.inputs.usesGroundTruth);
verifyTrue(testCase, any(strcmp( ...
    plan.items.inputs.forbiddenGroundTruthChannels, ...
    'gt_latent_model_1_stable_tracks')));
verifyFalse(testCase, any(strcmp( ...
    plan.items.inputs.requiredChannels, ...
    'gt_latent_model_1_stable_tracks')));
verifyEqual(testCase, plan.items.inputs.brightfieldChannelName, ...
    'Channel1_z2');
verifyEqual(testCase, c.dataset.split, beforeSplit, ...
    'Planning must not repurpose the train/test split.');
verifyEqual(testCase, plan.status, 'planned');
verifyEmpty(testCase, plan.runDir);
end

function testPredictionCanInitializeDraftWithoutSplitOrGtInference(testCase)
[c, r] = fixture(testCase);
beforeSplit = c.dataset.split;
payloads = {};

report = classifierPredictForAnnotation(c, 1, ...
    'InitializeGT', true, 'Save', false, ...
    'Executor', @fakeCellLatentExecutor, ...
    'ProgressCallback', @recordProgress);

verifyEqual(testCase, report.status, 'ok');
verifyNotEmpty(testCase, report.runId);
verifyEqual(testCase, report.items.status, 'draft_initialized');
verifyEqual(testCase, report.items.recipe.mode, 'prediction');
verifyEqual(testCase, report.items.predictionFamily, ...
    'pred_latent_model_1_lineage');
verifyEqual(testCase, report.items.predictionChannel, ...
    'results_pred_latent_model_1_tracks');
verifyEqual(testCase, report.items.provenance.quality, 'pred');
verifyFalse(testCase, report.items.provenance.inputs.usesGroundTruth);
verifyEqual(testCase, ...
    report.items.initializationReport.entry.source_run_id, report.runId);
verifyEqual(testCase, ...
    report.items.initializationReport.entry.status, 'draft');
verifyEqual(testCase, c.dataset.split, beforeSplit);
verifyNotEmpty(testCase, r.findChannelID('gt_latent_model_1_stable_tracks'));
verifyGreaterThan(testCase, numel(payloads), 0);
verifyEqual(testCase, r.cellModel.provenance.last_prediction_run_id, ...
    report.runId);
verifyFalse(testCase, ...
    r.cellModel.provenance.last_prediction_uses_ground_truth);
manifestPath = fullfile(report.runDir, 'prediction_for_annotation.json');
verifyTrue(testCase, isfile(manifestPath));
manifest = jsondecode(fileread(manifestPath));
verifyEqual(testCase, manifest.runId, report.runId);
verifyFalse(testCase, logical(manifest.usesGroundTruth));
verifyEqual(testCase, manifest.model.classifierId, c.strid);
verifyEqual(testCase, manifest.items.inputs.instanceChannelName, ...
    'results_cellposeSAM_cell');
verifyFalse(testCase, logical( ...
    manifest.items.provenance.inputs.usesGroundTruth));

    function recordProgress(payload)
        payloads{end+1} = payload; %#ok<AGROW>
    end
end

function testDirectExecutionWrapsOneRoiMultiChannelArgument(testCase)
[c, ~] = predictionClassiProbeFixture(testCase);

report = classifierPredictForAnnotation(c, 1, 'Save', false);

verifyEqual(testCase, report.status, 'ok');
captured = getappdata(0, 'DetecDivAnnotationPredictionProbe');
verifyTrue(testCase, iscell(captured.channelArgument));
verifyEqual(testCase, numel(captured.channelArgument), 1, ...
    'The outer cell must describe the single ROI.');
verifyTrue(testCase, iscell(captured.channelArgument{1}));
verifyEqual(testCase, captured.channelArgument{1}, ...
    {'results_cellposeSAM_cell', 'Channel1_z2'}, ...
    'The inner cell must preserve every input required by that ROI.');
verifyTrue(testCase, captured.strictRequiredChannels, ...
    'Only this audited annotation path opts into strict required inputs.');
end

function testAmbiguousMasksRequireExplicitOverride(testCase)
[c, r] = fixture(testCase);
r.removeChannel('results_cellposeSAM_cell');
mask = uint16(zeros(4,4,1,3));
mask(1:2,1:2,1,:) = 1;
r.addChannel(mask, 'results_segmenter_a_cell', [1 1 1], [0 0 0]);
r.addChannel(mask, 'results_segmenter_b_cell', [1 1 1], [0 0 0]);

plan = classifierPredictForAnnotation(c, 1, 'PlanOnly', true);
verifyFalse(testCase, plan.available);
verifyTrue(testCase, ...
    plan.items.inputs.resolution.instanceChannelName.ambiguous);
verifyEmpty(testCase, plan.items.inputs.instanceChannelName);

override = struct('instanceChannelName', 'results_segmenter_b_cell');
resolved = classifierPredictForAnnotation(c, 1, 'PlanOnly', true, ...
    'InputOverrides', override);
verifyTrue(testCase, resolved.available, strjoin(resolved.issues, ' '));
verifyEqual(testCase, resolved.items.inputs.instanceChannelName, ...
    'results_segmenter_b_cell');
verifyEqual(testCase, ...
    resolved.items.inputs.resolution.instanceChannelName.strategy, 'user_override');
end

function testPlanRejectsMissingActiveCheckpoint(testCase)
[c, ~] = fixture(testCase);
delete(c.executionParam.compositeManifestPath);

plan = classifierPredictForAnnotation(c, 1, 'PlanOnly', true);

verifyFalse(testCase, plan.available);
verifyFalse(testCase, plan.model.available);
verifyTrue(testCase, any(contains(string(plan.model.issues), ...
    'composite manifest', 'IgnoreCase', true)));
verifyTrue(testCase, any(contains(string(plan.issues), ...
    'composite manifest', 'IgnoreCase', true)));
end

function testPostTrainingSnapshotOverridesLegacyMatWithoutPlanMutation(testCase)
[c, r] = fixture(testCase);
c.executionParam = struct( ...
    'backend', 'legacy', ...
    'modelSource', 'builtin', ...
    'trackChannelName', 'gt_latent_model_1_stable_tracks', ...
    'outputTrackChannelName', 'legacy_tracks', ...
    'outputFamilyName', 'legacy_lineage');
legacyExecution = c.executionParam;
channelCount = size(r.image, 3);

payload = struct( ...
    'schemaVersion', 1, ...
    'classifierId', c.strid, ...
    'classifierPackage', 'cellLatentModel', ...
    'executionDefaults', struct( ...
        'backend', 'causal_composite', ...
        'modelSource', 'trained', ...
        'modelPath', 'lineage.pt', ...
        'compositeManifestPath', 'composite_manifest.json', ...
        'trackingCheckpointDir', 'tracking', ...
        'instanceChannelName', 'gt_latent_model_1_stable_tracks', ...
        'brightfieldChannelName', 'Channel1_z2', ...
        'frameIntervalMinutes', 5, ...
        'stateUpdateMode', 'none'));
snapshot = fullfile(c.path, 'training_execution_defaults.json');
fid = fopen(snapshot, 'w');
verifyGreaterThan(testCase, fid, 0);
closeFile = onCleanup(@()fclose(fid));
fwrite(fid, jsonencode(payload), 'char');
clear closeFile;

plan = classifierPredictForAnnotation(c, 1, 'PlanOnly', true);

verifyTrue(testCase, plan.available, strjoin(plan.issues, ' '));
verifyEqual(testCase, plan.model.backend, 'causal_composite');
verifyEqual(testCase, plan.model.modelSource, 'trained');
verifyEqual(testCase, plan.model.compositeManifestPath, ...
    fullfile(c.path, 'composite_manifest.json'));
verifyEqual(testCase, plan.model.modelPath, fullfile(c.path, 'lineage.pt'));
verifyEqual(testCase, plan.model.trackingCheckpointDir, ...
    fullfile(c.path, 'tracking'));
verifyEqual(testCase, plan.items.params.outputTrackChannelName, ...
    'pred_latent_model_1_tracks');
verifyEqual(testCase, plan.items.params.outputFamilyName, ...
    'pred_latent_model_1_lineage');
verifyEqual(testCase, plan.items.inputs.instanceChannelName, ...
    'results_cellposeSAM_cell');
verifyEqual(testCase, c.executionParam, legacyExecution, ...
    'PlanOnly must not rewrite the loaded classifier snapshot.');
verifyEqual(testCase, size(r.image, 3), channelCount, ...
    'PlanOnly must not materialize a PRED channel.');

spec = annotationManager.specForClassifier(c);
verifyEqual(testCase, predictionFamily(spec), ...
    plan.items.params.outputFamilyName);

report = classifierPredictForAnnotation(c, 1, ...
    'Save', false, 'Executor', @fakeCellLatentExecutor);
verifyEqual(testCase, report.items.predictionFamily, ...
    plan.items.params.outputFamilyName);
verifyEqual(testCase, report.items.predictionChannel, ...
    'results_pred_latent_model_1_tracks');
verifyEqual(testCase, c.executionParam, legacyExecution, ...
    'Direct prediction must not persist active-model defaults on the handle.');
end

function testPriorPredictedTracksAreNeverReusedAsLocalInstances(testCase)
[c, r] = fixture(testCase);
r.removeChannel('results_cellposeSAM_cell');
mask = uint16(zeros(4,4,1,3));
mask(1:2,1:2,1,:) = 1;
r.addChannel(mask, 'results_pred_latent_model_tracks', ...
    [1 1 1], [0 0 0]);

plan = classifierPredictForAnnotation(c, 1, 'PlanOnly', true);

verifyFalse(testCase, plan.available);
verifyFalse(testCase, any(strcmp( ...
    plan.items.inputs.resolution.instanceChannelName.candidates, ...
    'results_pred_latent_model_tracks')));
verifyEmpty(testCase, plan.items.inputs.instanceChannelName);
verifyFalse(testCase, plan.items.requiresPreparation);
verifyFalse(testCase, plan.items.canPrepare);
verifyFalse(testCase, plan.canRun);
end

function testTracksFromAnotherModuleCanSeedLatentInference(testCase)
[c, r] = fixture(testCase);
r.removeChannel('results_cellposeSAM_cell');
markIndexed(r, 'Channel1_z2');
r.addChannel(uint16(ones(4,4,1,3)), 'CombinedChannel', ...
    [1 1 1], [1 1 1]);
r.addChannel(uint16(ones(4,4,1,3)), 'GFP_marker', ...
    [1 1 1], [1 1 1]);
r.addChannel(uint16(ones(4,4,1,3)), 'ch1', [1 1 1], [1 1 1]);
r.addChannel(uint16(ones(4,4,1,3)), 'DIC', [1 1 1], [1 1 1]);
r.addChannel(uint16(ones(4,4,1,3)), ...
    'pred_cellposesam_probability', [1 1 1], [1 1 1]);
r.addChannel(uint16(ones(4,4,1,3)), ...
    'results_tracking_score', [1 1 1], [1 1 1]);
markIndexed(r, 'CombinedChannel');
markIndexed(r, 'GFP_marker');
markIndexed(r, 'ch1');
markIndexed(r, 'DIC');
markIndexed(r, 'pred_cellposesam_probability');
markIndexed(r, 'results_tracking_score');
tracks = uint16(zeros(4,4,1,3));
tracks(1:2,1:2,1,:) = 7;
r.addChannel(tracks, 'results_trackastra_tracks', ...
    [1 1 1], [0 0 0]);

plan = classifierPredictForAnnotation(c, 1, 'PlanOnly', true);

verifyTrue(testCase, plan.available, strjoin(plan.issues, ' '));
verifyTrue(testCase, plan.canRun);
verifyEqual(testCase, plan.items.inputs.instanceChannelName, ...
    'results_trackastra_tracks');
verifyEqual(testCase, ...
    plan.items.inputs.resolution.instanceChannelName.strategy, ...
    'single_compatible_prediction');
verifyFalse(testCase, plan.items.inputs.usesGroundTruth);
verifyFalse(testCase, any(ismember( ...
    plan.items.inputs.resolution.instanceChannelName.candidates, ...
    {'Channel1_z2','CombinedChannel','GFP_marker','ch1','DIC', ...
    'pred_cellposesam_probability','results_tracking_score'})), ...
    strjoin(plan.items.inputs.resolution.instanceChannelName.candidates, ', '));
end

function testIndexedRawChannelOverrideIsRejected(testCase)
[c, r] = fixture(testCase);
r.removeChannel('results_cellposeSAM_cell');
markIndexed(r, 'Channel1_z2');

plan = classifierPredictForAnnotation(c, 1, 'PlanOnly', true, ...
    'InputOverrides', struct('instanceChannelName', 'Channel1_z2'));

verifyFalse(testCase, plan.available);
verifyFalse(testCase, plan.canRun);
verifyEmpty(testCase, plan.items.inputs.instanceChannelName);
verifyEqual(testCase, ...
    plan.items.inputs.resolution.instanceChannelName.strategy, ...
    'unsafe_override_rejected');
verifyFalse(testCase, any(strcmpi( ...
    plan.items.inputs.resolution.instanceChannelName.candidates, ...
    'Channel1_z2')));
verifyTrue(testCase, any(contains(string(plan.issues), ...
    'override is not a safe existing mask/track', 'IgnoreCase', true)));
end

function testConfiguredObservationCannotAlsoBecomeInstanceMask(testCase)
[c, r] = fixture(testCase);
r.removeChannel('results_cellposeSAM_cell');
signal = uint16(ones(4,4,1,3));
r.addChannel(signal, 'results_nucleus_mask', [1 1 1], [1 1 1]);
markIndexed(r, 'results_nucleus_mask');
c.executionParam.nucleusChannelName = 'results_nucleus_mask';

plan = classifierPredictForAnnotation(c, 1, 'PlanOnly', true);

verifyFalse(testCase, plan.canRun);
verifyEmpty(testCase, plan.items.inputs.instanceChannelName);
verifyEqual(testCase, plan.items.inputs.nucleusChannelName, ...
    'results_nucleus_mask');
verifyFalse(testCase, any(strcmpi( ...
    plan.items.inputs.resolution.instanceChannelName.candidates, ...
    'results_nucleus_mask')));
end

function testHumanGtFamilyMetadataForbidsProviderAndOverride(testCase)
[c, r] = fixture(testCase);
r.removeChannel('results_cellposeSAM_cell');
mask = uint16(zeros(4,4,1,3));
mask(1:2,1:2,1,:) = 1;
r.addChannel(mask, 'results_external_review_cell', ...
    [1 1 1], [0 0 0]);
r.addChannel(mask, 'results_safe_segmenter_cell', ...
    [1 1 1], [0 0 0]);

model = cellModel.create(r.id);
model.families.family_id = uint32(1);
model.families.name = {'External reviewed identities'};
model.families.mask_provider = {'results_external_review_cell'};
model.families.lineage_source = {'classifier'};
model.families.color_rgb = uint8([1 2 3]);
% Extra metadata is intentionally supported by normalize so newer catalog
% schemas can declare quality without weakening older readers.
model.families.quality = {'human_gt'};
r.cellModel = model;
r.cellModelInfo = struct('loaded', true, ...
    'filename', cellModel.pathForROI(r), 'datenum', NaN);

plan = classifierPredictForAnnotation(c, 1, 'PlanOnly', true);

verifyTrue(testCase, plan.available, strjoin(plan.issues, ' '));
verifyEqual(testCase, plan.items.inputs.instanceChannelName, ...
    'results_safe_segmenter_cell');
verifyTrue(testCase, any(strcmp( ...
    plan.items.inputs.forbiddenGroundTruthChannels, ...
    'results_external_review_cell')));
verifyFalse(testCase, plan.usesGroundTruth);
verifyFalse(testCase, plan.items.inputs.usesGroundTruth);
verifyError(testCase, @() classifierPredictForAnnotation(c, 1, ...
    'PlanOnly', true, 'InputOverrides', struct( ...
    'instanceChannelName', 'results_external_review_cell')), ...
    'classifierPredictForAnnotation:GroundTruthInputRejected');
end

function testAnnotationInferenceUsesOnePinnedActiveSnapshot(testCase)
[c, ~] = fixture(testCase);
initialModel = c.executionParam.modelPath;
initialManifest = c.executionParam.compositeManifestPath;
captured = struct();

classifierPredictForAnnotation(c, 1, 'Save', false, ...
    'Executor', @executorChangingSnapshot);

verifyEqual(testCase, captured.modelPath, initialModel);
verifyEqual(testCase, captured.compositeManifestPath, initialManifest);
verifyTrue(testCase, captured.pinEnabled);
verifyFalse(testCase, captured.usesGroundTruth);

% Outside the explicit annotation context, ordinary execution sees the new
% classifier-owned deployment snapshot and still ignores runtime artifact
% redirection.
normal = cellLatentModel.resolveInferenceParam(c, struct( ...
    'params', struct('modelPath', initialModel)));
verifyEqual(testCase, normal.modelPath, captured.alternateModel);

    function executorChangingSnapshot(classif, roiObj, item, ctx, opts)
        alternateModel = fullfile(classif.path, 'alternate_lineage.pt');
        alternateManifest = fullfile(classif.path, 'alternate_manifest.json');
        alternateTracking = fullfile(classif.path, 'alternate_tracking');
        mkdir(alternateTracking);
        touch(alternateModel);
        touch(alternateManifest);
        touch(fullfile(alternateTracking, 'manifest.json'));
        payload = struct('schemaVersion', 1, ...
            'classifierId', classif.strid, ...
            'classifierPackage', 'cellLatentModel', ...
            'executionDefaults', struct( ...
            'backend', 'causal_composite', ...
            'modelSource', 'trained', ...
            'modelPath', alternateModel, ...
            'compositeManifestPath', alternateManifest, ...
            'trackingCheckpointDir', alternateTracking, ...
            'stateUpdateMode', 'none'));
        snapshotFile = fullfile(classif.path, ...
            'training_execution_defaults.json');
        fid = fopen(snapshotFile, 'w');
        assert(fid >= 0);
        cleanup = onCleanup(@() fclose(fid));
        fwrite(fid, jsonencode(payload), 'char');
        clear cleanup;

        resolved = cellLatentModel.resolveInferenceParam(classif, ctx);
        captured = struct( ...
            'modelPath', resolved.modelPath, ...
            'compositeManifestPath', resolved.compositeManifestPath, ...
            'alternateModel', alternateModel, ...
            'pinEnabled', logical( ...
                ctx.annotationPrediction.usePinnedActiveModel), ...
            'usesGroundTruth', logical( ...
                ctx.annotationPrediction.usesGroundTruth));
        fakeCellLatentExecutor(classif, roiObj, item, ctx, opts);
    end
end

function testCellposeSAMPlanUsesActiveModelThenDefaultFallback(testCase)
[c, ~, modelFile] = cellposeFixture(testCase);

plan = classifierPredictForAnnotation(c, 1, 'PlanOnly', true);

verifyTrue(testCase, plan.available, strjoin(plan.issues, ' '));
verifyTrue(testCase, plan.canRun);
verifyFalse(testCase, plan.usesGroundTruth);
verifyEqual(testCase, plan.model.package, 'cellposesam');
verifyEqual(testCase, plan.model.modelSource, 'trained');
verifyEqual(testCase, plan.model.modelPath, modelFile);
verifyEqual(testCase, plan.items.inputs.inputChannelName, 'Channel0');
verifyEqual(testCase, plan.items.inputs.requiredChannels, {'Channel0'});
verifyEqual(testCase, plan.items.params.outputName, 'pred_cellposesam');

delete(modelFile);
fallback = classifierPredictForAnnotation(c, 1, 'PlanOnly', true);
verifyTrue(testCase, fallback.available, strjoin(fallback.issues, ' '));
verifyEqual(testCase, fallback.model.modelSource, 'builtin');
verifyEmpty(testCase, fallback.model.modelPath);
verifyTrue(testCase, contains(lower(fallback.model.modelLabel), 'default'));
end

function testCellposeSAMPredictionInitializesSeparateDraftGt(testCase)
[c, r] = cellposeFixture(testCase);

report = classifierPredictForAnnotation(c, 1, ...
    'InitializeGT', true, 'Save', false, ...
    'Executor', @fakeCellposeExecutor);

verifyEqual(testCase, report.status, 'ok');
verifyEqual(testCase, report.items.status, 'draft_initialized');
verifyEqual(testCase, report.items.recipe.mode, 'prediction');
verifyEqual(testCase, report.items.predictionChannel, '');
pred = r.findChannelID('results_pred_cellposesam_cell');
spec = annotationManager.specForClassifier(c);
gtName = spec.components(1).groundTruth.channel;
gt = r.findChannelID(gtName);
verifyNotEmpty(testCase, pred);
verifyNotEmpty(testCase, gt);
verifyEqual(testCase, r.image(:,:,gt,:), r.image(:,:,pred,:));
verifyEqual(testCase, ...
    report.items.initializationReport.entry.source_run_id, report.runId);
verifyEqual(testCase, ...
    report.items.initializationReport.entry.status, 'draft');
verifyEmpty(testCase, r.cellModel.families.family_id, ...
    'CellposeSAM annotation inference must not create object families.');
verifyEmpty(testCase, r.cellModel.instances.object_id, ...
    'CellposeSAM annotation inference must not create cell instances.');
verifyEmpty(testCase, r.cellModel.relations.relation_id, ...
    'CellposeSAM annotation inference must not create lineage relations.');
end

function [c, r] = fixture(testCase)
root = tempname;
mkdir(root);
addTeardown(testCase, @() removeFolder(root));
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
    'nucleusChannelName', '', ...
    'budneckChannelName', '', ...
    'frameIntervalMinutes', 5, ...
    'outputTrackChannelName', 'pred_latent_model_tracks', ...
    'outputFamilyName', 'pred_latent_lineage_mother_null', ...
    'modelSource', 'trained', ...
    'modelPath', modelFile, ...
    'compositeManifestPath', manifestFile, ...
    'trackingCheckpointDir', trackingDir, ...
    'stateUpdateMode', 'none');
c.trainingParam = struct( ...
    'architectureVersion', 'detecdiv_composite_v1', ...
    'trainTrackingActions', true, ...
    'trainMotherNull', true, ...
    'instanceChannelName', 'gt_latent_model_1_stable_tracks', ...
    'trackChannelName', 'gt_latent_model_1_stable_tracks', ...
    'groundTruthFamily', '<auto>', ...
    'brightfieldChannelName', 'Channel1_z2');
c.channelName = {'gt_latent_model_1_stable_tracks','Channel1_z2'};
c.dataset.split = struct('train', 1, 'val', [], 'test', 1);

r = roi('Pos0_1_50', [1 1 4 4]);
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
instances = uint16(zeros(4,4,1,3));
instances(1:2,1:2,1,:) = 1;
r.addChannel(instances, 'results_cellposeSAM_cell', [1 1 1], [0 0 0]);
r.addChannel(zeros(size(instances), 'uint16'), ...
    'gt_latent_model_1_stable_tracks', [1 1 1], [0 0 0]);
c.roi = r;
end

function [c, r, modelFile] = cellposeFixture(testCase)
root = tempname;
mkdir(root);
addTeardown(testCase, @() removeFolder(root));
c = classi(root, 'cellpose', 4);
c.classifierPkg = 'cellposesam';
c.classifyFun = 'cellposesam.classify';
c.trainingFun = 'cellposesam.train';
c.category = {'Pixel'};
c.classes = {'cell'};
c.channelName = 'Channel0';
c.outputType = 'segmentation';
c.executionParam = struct('outputName', 'pred_cellposesam');

modelDir = fullfile(c.path, 'models');
mkdir(modelDir);
modelFile = fullfile(modelDir, c.strid);
touch(modelFile);

r = roi('Pos0_1_1', [1 1 4 4]);
r.path = c.path;
r.image = uint16(reshape(1:48, 4,4,1,3));
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
end

function fakeCellposeExecutor(~, roiObj, item, ~, ~)
sourceIndex = roiObj.findChannelID(item.inputs.inputChannelName);
source = roiObj.image(:,:,sourceIndex,:);
mask = uint16(source > median(source(:)));
name = ['results_' char(string(item.params.outputName)) '_cell'];
existing = roiObj.findChannelID(name);
if isempty(existing)
    roiObj.addChannel(mask, name, [1 1 1], [0 0 0]);
else
    roiObj.image(:,:,existing,:) = mask;
end
end

function [c, r] = predictionClassiProbeFixture(testCase)
root = tempname;
mkdir(root);
addTeardown(testCase, @() removeFolder(root));
c = annotationPredictionClassiProbe(root, 'latent_model', 1);
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
    'nucleusChannelName', '', ...
    'budneckChannelName', '', ...
    'frameIntervalMinutes', 5, ...
    'outputTrackChannelName', 'pred_latent_model_tracks', ...
    'outputFamilyName', 'pred_latent_lineage_mother_null', ...
    'modelSource', 'trained', ...
    'modelPath', modelFile, ...
    'compositeManifestPath', manifestFile, ...
    'trackingCheckpointDir', trackingDir, ...
    'stateUpdateMode', 'none');
c.trainingParam = struct( ...
    'architectureVersion', 'detecdiv_composite_v1', ...
    'trainTrackingActions', true, ...
    'trainMotherNull', true, ...
    'instanceChannelName', 'gt_latent_model_1_stable_tracks', ...
    'trackChannelName', 'gt_latent_model_1_stable_tracks', ...
    'groundTruthFamily', '<auto>', ...
    'brightfieldChannelName', 'Channel1_z2');
c.channelName = {'gt_latent_model_1_stable_tracks','Channel1_z2'};
c.dataset.split = struct('train', 1, 'val', [], 'test', 1);

r = roi('Pos0_1_50', [1 1 4 4]);
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
instances = uint16(zeros(4,4,1,3));
instances(1:2,1:2,1,:) = 1;
r.addChannel(instances, 'results_cellposeSAM_cell', ...
    [1 1 1], [0 0 0]);
r.addChannel(zeros(size(instances), 'uint16'), ...
    'gt_latent_model_1_stable_tracks', [1 1 1], [0 0 0]);
c.roi = r;
end

function fakeCellLatentExecutor(~, roiObj, item, ~, ~)
sourceIndex = roiObj.findChannelID(item.inputs.instanceChannelName);
stack = uint16(roiObj.image(:,:,sourceIndex,:));
predictionChannel = char(string(item.params.outputTrackChannelName));
if ~startsWith(predictionChannel, 'results_', 'IgnoreCase', true)
    predictionChannel = ['results_' predictionChannel];
end
existing = roiObj.findChannelID(predictionChannel);
if isempty(existing)
    roiObj.addChannel(stack, predictionChannel, [1 1 1], [0 0 0]);
else
    roiObj.image(:,:,existing,:) = stack;
end
model = cellModel.create(roiObj.id);
[model, ~, ~] = cellModel.applyLineageResult(model, ...
    squeeze(stack), predictionChannel, '', ...
    char(string(item.params.outputFamilyName)), struct('edges', struct([])), ...
    true, 'pred:cellLatentModel');
roiObj.cellModel = model;
roiObj.saveCellModel(model);
end

function touch(path)
fid = fopen(path, 'w');
assert(fid >= 0, 'Could not create test artifact %s.', path);
fclose(fid);
end

function markIndexed(roiObj, channelName)
index = find(strcmpi(cellstr(string(roiObj.display.channel)), ...
    channelName), 1);
assert(~isempty(index), 'Missing test channel %s.', channelName);
flags = logical(roiObj.display.indexed);
if numel(flags) < numel(roiObj.display.channel)
    flags(end+1:numel(roiObj.display.channel)) = false;
end
flags(index) = true;
roiObj.display.indexed = flags;
end

function value = predictionFamily(spec)
value = '';
for i = 1:numel(spec.components)
    try
        candidate = char(string(spec.components(i).prediction.family));
    catch
        candidate = '';
    end
    if ~isempty(candidate), value = candidate; return; end
end
end

function removeFolder(folder)
if isfolder(folder), rmdir(folder, 's'); end
end

function clearAnnotationPredictionProbe()
if isappdata(0, 'DetecDivAnnotationPredictionProbe')
    rmappdata(0, 'DetecDivAnnotationPredictionProbe');
end
end
