function tests = testClassifierBinding
%TESTCLASSIFIERBINDING Typed training-resource catalog tests.
tests = functiontests(localfunctions);
end

function setupOnce(~)
repoRoot = fileparts(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))));
addpath(genpath(repoRoot));
end

function testCellLatentDeclaresTypedTrainingResources(testCase)
c = struct('classifierPkg', 'cellLatentModel');
spec = classifierBinding.trainingSpec(c);
verifyEqual(testCase, {spec.param}, { ...
    'instanceChannelName','trackChannelName','groundTruthFamily', ...
    'brightfieldChannelName', ...
    'gfpChannelName','nucleusChannelName','budneckChannelName'});
verifyEqual(testCase, spec(1).role, 'mask_roi_image');
verifyTrue(testCase, spec(1).required);
verifyEqual(testCase, spec(2).role, 'mask_roi_image');
verifyEqual(testCase, spec(3).type, 'cellModelFamily');
end

function testEveryClassifierPackageDeclaresTrainingBindings(testCase)
classificationRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
folders = dir(fullfile(classificationRoot, '+*'));
folders = folders(arrayfun(@(d) ...
    isfile(fullfile(d.folder, d.name, 'train.m')) && ...
    isfile(fullfile(d.folder, d.name, 'classify.m')), folders));
packages = erase({folders.name}, '+');
verifyNotEmpty(testCase, packages);
for i = 1:numel(packages)
    spec = classifierBinding.trainingSpec(struct('classifierPkg', packages{i}));
    verifyNotEmpty(testCase, spec, sprintf('%s has no training bindings.', packages{i}));
    verifyTrue(testCase, all(~cellfun(@isempty,{spec.group})));
    verifyTrue(testCase, all(~cellfun(@isempty, {spec.param})));
    defaults = feval([packages{i} '.utils.defaultTrainingParam']);
    persisted = spec(strcmpi({spec.storage}, 'trainingParam'));
    if ~isempty(persisted)
        verifyTrue(testCase, all(isfield(defaults, {persisted.param})), ...
            sprintf('%s declares a missing trainingParam binding.', packages{i}));
    end
end
end

function testLegacyInputStorageRoundTrip(testCase)
folder = tempname;
mkdir(folder);
addTeardown(testCase, @()removeFolder(folder));

c = classi(folder, 'legacy_inputs', 1);
c.classifierPkg = 'cnn_lstm';
c.trainingParam = cnn_lstm.utils.defaultTrainingParam();
c.channelName = {'old_raw'};
c.dataset.channels = {'old_raw'};

spec = classifierBinding.trainingSpec(c);
input = spec(strcmp({spec.param}, 'inputChannelNames'));
verifyEqual(testCase, classifierBinding.value(c, input), {'old_raw'});

classifierBinding.applyValue(c, input, {'brightfield','nucleus'});
verifyEqual(testCase, c.channelName, {'brightfield','nucleus'});
verifyEqual(testCase, c.dataset.channels, {'brightfield','nucleus'});
verifyEqual(testCase, c.getInputChannels(), {'brightfield','nucleus'});
end

function testNumericLegacyChannelsAreMigrated(testCase)
folder = tempname;
mkdir(folder);
addTeardown(testCase, @()removeFolder(folder));

c = classi(folder, 'numeric_legacy', 1);
c.classifierPkg = 'cellposesam';
c.trainingParam = cellposesam.utils.defaultTrainingParam();
r = roiWithRaw(folder, 'R1');
r.display.channel = {'brightfield','mask'};
r.display.indexed = [false true];
c.roi = r;
c.channel = 2;
c.channelName = {};
c.dataset.channels = {};

report = classifierBinding.normalizeClassifier(c);
verifyTrue(testCase, report.migratedChannels);
verifyEqual(testCase, c.channelName, {'mask'});
verifyEqual(testCase, c.dataset.channels, {'mask'});
end

function testNestedLegacyEnumsAreFlattened(testCase)
folder = tempname;
mkdir(folder);
addTeardown(testCase, @()removeFolder(folder));

c = classi(folder, 'nested_enum', 1);
c.classifierPkg = 'cellLatentModel';
c.trainingParam = struct( ...
    'trainingObjective', {{{'relation_ensemble','continuous_lineage', ...
        'continuous_lineage'}}}, ...
    'tip', {{}});
report = classifierBinding.normalizeClassifier(c);
verifyEqual(testCase, c.trainingParam.trainingObjective, ...
    {'relation_ensemble','continuous_lineage','continuous_lineage'});
verifyTrue(testCase, any(strcmp(report.flattenedParameters, 'trainingObjective')));
end

function testLegacyClassifierReceivesNewScopeControlsWithoutReset(testCase)
folder = tempname;
mkdir(folder);
addTeardown(testCase, @()removeFolder(folder));

c = classi(folder, 'legacy_scope', 1);
c.classifierPkg = 'cellLatentModel';
c.trainingParam = struct( ...
    'frameIntervalMinutes',7, ...
    'trainingObjective',{{'relation_ensemble','continuous_lineage', ...
        'relation_ensemble'}}, ...
    'tip',{{'Saved interval','Saved objective'}});

report = classifierBinding.normalizeClassifier(c);
keys = fieldnames(c.trainingParam);
verifyEqual(testCase,keys{1},'architectureVersion');
verifyEqual(testCase,keys{2},'trainTrackingActions');
verifyEqual(testCase,keys{3},'trainMotherNull');
verifyEqual(testCase,keys{4},'stateUpdateMode');
verifyEqual(testCase,c.trainingParam.frameIntervalMinutes,7);
verifyEqual(testCase,c.trainingParam.trainingObjective, ...
    {'relation_ensemble','continuous_lineage','relation_ensemble'});
verifyTrue(testCase,all(ismember( ...
    {'architectureVersion','trainTrackingActions','trainMotherNull', ...
     'stateUpdateMode'},report.addedParameters)));
end

function testCompositeMigrationSeparatesRuntimeMasksFromReviewedGt(testCase)
folder=tempname;
mkdir(folder);
addTeardown(testCase,@()removeFolder(folder));
c=classi(folder,'legacy_composite_binding',1,'InitTraining',false);
c.classifierPkg='cellLatentModel';
c.trainingParam=cellLatentModel.utils.defaultTrainingParam();
c.trainingParam.architectureVersion='detecdiv_composite_v1';
c.trainingParam.trackChannelName='latent_model_1_cell';
c.trainingParam.instanceChannelName='latent_model_1_cell';
c.executionParam=cellLatentModel.utils.defaultExecutionParam();
c.executionParam.backend='causal_composite';
c.executionParam.instanceChannelName='latent_model_1_cell';
r=roiWithRaw(folder,'R1');
mask=zeros(4,4,1,3,'uint16');
mask(2:3,2:3,1,:)=1;
r.addChannel(mask,'results_cellposeSAM_cell',[1 1 1],[0 0 0]);
r.display.indexed(r.findChannelID('results_cellposeSAM_cell','exact'))=true;
r.addChannel(mask,'latent_model_1_cell',[1 1 1],[0 0 0]);
r.display.indexed(r.findChannelID('latent_model_1_cell','exact'))=true;
c.roi=r;

report=classifierBinding.normalizeClassifier(c);

verifyTrue(testCase,report.packageMigration.changed);
verifyEqual(testCase,c.trainingParam.instanceChannelName, ...
    'results_cellposeSAM_cell');
verifyEqual(testCase,c.trainingParam.trackChannelName, ...
    'latent_model_1_cell');
verifyEqual(testCase,c.executionParam.instanceChannelName, ...
    'results_cellposeSAM_cell');
verifyEqual(testCase,c.executionParam.trackChannelName,'');
end

function testCompositeMigrationNeverFallsBackToGt(testCase)
folder=tempname;
mkdir(folder);
addTeardown(testCase,@()removeFolder(folder));
c=classi(folder,'gt_only_composite',1,'InitTraining',false);
c.classifierPkg='cellLatentModel';
c.trainingParam=cellLatentModel.utils.defaultTrainingParam();
c.trainingParam.architectureVersion='detecdiv_composite_v1';
c.trainingParam.trackChannelName='latent_model_1_cell';
c.trainingParam.instanceChannelName='latent_model_1_cell';
c.executionParam=struct('backend','causal_composite', ...
    'instanceChannelName','latent_model_1_cell', ...
    'trackChannelName','latent_model_1_cell');
r=roiWithRaw(folder,'R1');
mask=zeros(4,4,1,3,'uint16');
r.addChannel(mask,'latent_model_1_cell',[1 1 1],[0 0 0]);
r.display.indexed(r.findChannelID('latent_model_1_cell','exact'))=true;
c.roi=r;

classifierBinding.normalizeClassifier(c);

verifyEmpty(testCase,c.trainingParam.instanceChannelName);
verifyEmpty(testCase,c.executionParam.instanceChannelName);
verifyEqual(testCase,c.trainingParam.trackChannelName, ...
    'latent_model_1_cell');
verifyEmpty(testCase,c.executionParam.trackChannelName);
end

function testManagedAnnotationBindingIsReadOnly(testCase)
folder = tempname;
mkdir(folder);
addTeardown(testCase, @()removeFolder(folder));

c = classi(folder, 'cpsam_gt', 1);
c.classifierPkg = 'cellposesam';
c.category = {'Pixel'};
c.classes = {'cell'};
c.trainingParam = cellposesam.utils.defaultTrainingParam();
spec = classifierBinding.trainingSpec(c);
gt = spec(strcmp({spec.param}, 'groundTruthChannelName'));
verifyFalse(testCase, gt.editable);
verifyEqual(testCase, classifierBinding.value(c, gt), ...
    ['gt_' c.strid '_instances']);
verifyError(testCase, @()classifierBinding.applyValue(c, gt, 'other'), ...
    'classifierBinding:ReadOnlyBinding');
end

function testLegacyGtChannelNameIsNeverRenamed(testCase)
folder = tempname;
mkdir(folder);
addTeardown(testCase, @()removeFolder(folder));
c = classi(folder, 'legacy_gt', 1);
c.classifierPkg = 'cellposesam';
c.category = {'Pixel'};
c.classes = {'cell'};
c.trainingParam = cellposesam.utils.defaultTrainingParam();
r = roiWithRaw(folder, 'R1');
legacy = [c.strid '_cell'];
r.addChannel(zeros(4,4,1,3,'uint16'),legacy,[1 1 1],[0 0 0]);
c.roi = r;
verifyEqual(testCase,cellposesam.annotationChannelName(c),legacy);
end

function testExplicitTrainingScopeAndQualityContract(testCase)
packages = {'cellposesam','trackastra','cellLatentTracker', ...
    'cellLatentModel','budMotherLinker','cnn','cnn_lstm', ...
    'deeplab_pixel_classification','sam31'};
for i=1:numel(packages)
    c=struct('classifierPkg',packages{i});
    scope=classifierBinding.trainingScopeSpec(c);
    verifyEqual(testCase,scope.module,packages{i});
    verifyNotEmpty(testCase,scope.trainedComponents);
    verifyNotEmpty(testCase,scope.frozenComponents);
    verifyEqual(testCase,scope.outputQuality,'pred');
    verifyTrue(testCase,startsWith(scope.canonicalOutput,'results_pred_')|| ...
        startsWith(scope.canonicalOutput,'pred_'));
    bindings=classifierBinding.trainingSpec(c);
    verifyTrue(testCase,all(ismember({bindings.quality}, ...
        {'input','gt','pred','derived'})));
    verifyTrue(testCase,any(strcmp({bindings.quality},'gt')));
    [parameterLabels,displayPolicy]= ...
        classifierBinding.trainingParameterSpec(c);
    verifyNotEmpty(testCase,parameterLabels, ...
        sprintf('%s must explain its training parameters.',packages{i}));
    if strcmp(packages{i},'cellLatentModel')
        verifyFalse(testCase,displayPolicy.showUnspecified);
    else
        verifyTrue(testCase,displayPolicy.showUnspecified);
    end
end
end

function testEveryTrainablePackageDeclaresProvenanceContract(testCase)
classificationRoot=fileparts(fileparts(fileparts(mfilename('fullpath'))));
folders=dir(fullfile(classificationRoot,'+*'));
folders=folders(arrayfun(@(d) ...
    isfile(fullfile(d.folder,d.name,'train.m'))&& ...
    isfile(fullfile(d.folder,d.name,'classify.m')),folders));
packages=erase({folders.name},'+');
verifyNotEmpty(testCase,packages);
for i=1:numel(packages)
    pkg=packages{i};
    verifyNotEmpty(testCase,which([pkg '.train']));
    verifyNotEmpty(testCase,which([pkg '.trainingScopeSpec']));
    verifyNotEmpty(testCase,which([pkg '.trainingParameterSpec']));
    verifyNotEmpty(testCase,which([pkg '.executionSpec']));
    execution=feval([pkg '.executionSpec']);
    verifyTrue(testCase,isfield(execution,'outputProvenance'), ...
        sprintf('%s must declare output provenance.',pkg));
    verifyEqual(testCase,execution.outputProvenance.quality,'pred');
    verifyEqual(testCase,execution.outputProvenance.producer,pkg);
end
end

function testNewPredictionDefaultsCarryProducerAndQuality(testCase)
spec=cellposesam.executionSpec();
verifyEqual(testCase,spec.defaults.outputName,'pred_cellposesam');
verifyEqual(testCase,spec.outputProvenance.quality,'pred');
trackastraParam=trackastra.utils.defaultExecutionParam();
latentTrackerParam=cellLatentTracker.utils.defaultExecutionParam();
latentLineageParam=cellLatentModel.utils.defaultExecutionParam();
verifyEqual(testCase,trackastraParam.outputName,'pred_trackastra_tracks');
verifyEqual(testCase,latentTrackerParam.outputName, ...
    'pred_latent_tracker_tracks');
verifyEqual(testCase,latentLineageParam.outputFamilyName, ...
    'pred_latent_lineage_mother_null');
cnnSpec=cnn.executionSpec();
cnnLstmSpec=cnn_lstm.executionSpec();
deeplabSpec=deeplab_pixel_classification.executionSpec();
samSpec=sam31.executionSpec();
verifyEqual(testCase,cnnSpec.defaults.outputName,'pred_cnn_image_class');
verifyEqual(testCase,cnnLstmSpec.defaults.outputName, ...
    'pred_cnn_lstm_frame_class');
verifyEqual(testCase,deeplabSpec.defaults.outputName, ...
    'pred_deeplab_semantic_mask');
verifyEqual(testCase,samSpec.defaults.outputName,'pred_sam31_tracks');
end

function testLegacyClassifierIdsRemainPredictionOutputs(testCase)
packages={'cnn','cnn_lstm','deeplab_pixel_classification','sam31'};
for i=1:numel(packages)
    c=struct('strid',['legacy_' packages{i}], ...
        'classifierPkg',packages{i},'executionParam',struct(), ...
        'trainingParam',struct(),'runProfiles',struct(), ...
        'defaultExecutionParam',struct(),'outputType','');
    execution=feval([packages{i} '.executionSpec'],c);
    verifyEqual(testCase,execution.defaults.outputName,c.strid);
end
end

function testNewSamAndDeepLabGtNamesExposeQuality(testCase)
sam=struct('strid','sam_demo','classifierPkg','sam31', ...
    'trainingParam',struct(),'roi',[]);
deep=struct('strid','deep_demo', ...
    'classifierPkg','deeplab_pixel_classification', ...
    'trainingParam',struct(),'roi',[]);
verifyEqual(testCase,sam31.annotationChannelName(sam), ...
    'gt_sam_demo_stable_tracks');
verifyEqual(testCase,deeplab_pixel_classification.annotationChannelName(deep), ...
    'gt_deep_demo_semantic_mask');
end

function testCatalogReportsRoiCoverageAndSemanticChoices(testCase)
folder = tempname;
mkdir(folder);
addTeardown(testCase, @()removeFolder(folder));

c = classi(folder, 'binding_demo', 1);
c.classifierPkg = 'cellLatentModel';
c.trainingParam = cellLatentModel.utils.defaultTrainingParam();

r1 = roiWithRaw(folder, 'R1');
mask = zeros(4, 4, 1, 3, 'uint16');
mask(2:3, 2:3, 1, :) = 1;
r1.addChannel(mask, 'reviewed_mask', [1 1 1], [0 0 0]);
maskIdx = r1.findChannelID('reviewed_mask', 'exact');
r1.display.indexed(maskIdx) = true;

model = cellModel.create(r1.id);
[model, ~, ~] = cellModel.applyLineageResult(model, ...
    squeeze(mask), 'reviewed_mask', '', 'Reviewed lineage', ...
    struct('edges', struct([])), true, 'ground_truth');
r1.saveCellModel(model);

r2 = roiWithRaw(folder, 'R2');
c.roi = [r1 r2];

catalog = classifierBinding.catalog(c);
verifyEqual(testCase, catalog.roiCount, 2);

spec = classifierBinding.trainingSpec(c);
maskChoices = classifierBinding.choices(spec(1), catalog, '');
verifyTrue(testCase, any(strcmp(maskChoices.values, 'reviewed_mask')));
label = maskChoices.labels{strcmp(maskChoices.values, 'reviewed_mask')};
verifyTrue(testCase, contains(label, '1/2 ROI'));
verifyFalse(testCase, any(strcmp(maskChoices.values, 'raw')));

familyChoices = classifierBinding.choices(spec(3), catalog, '<auto>');
verifyTrue(testCase, any(strcmp(familyChoices.values, 'Reviewed lineage')));
label = familyChoices.labels{strcmp(familyChoices.values, 'Reviewed lineage')};
verifyTrue(testCase, contains(label, '1/2 ROI'));

imageChoices = classifierBinding.choices(spec(4), catalog, '');
verifyTrue(testCase, any(strcmp(imageChoices.values, 'raw')));
verifyFalse(testCase, any(strcmp(imageChoices.values, 'reviewed_mask')));
end

function r = roiWithRaw(folder, id)
r = roi(id, [1 1 4 4]);
r.path = folder;
r.image = uint16(ones(4, 4, 1, 3));
r.channelid = 1;
r.display.channel = {'raw'};
r.display.intensity = [1 1 1];
r.display.rgb = [1 1 1];
r.display.selectedchannel = true;
r.display.indexed = false;
r.display.alpha = 1;
r.display.contour = false;
r.display.width = 1;
end

function removeFolder(folder)
if isfolder(folder), rmdir(folder, 's'); end
end
