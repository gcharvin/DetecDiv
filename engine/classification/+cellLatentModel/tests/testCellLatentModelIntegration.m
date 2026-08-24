function tests = testCellLatentModelIntegration
%TESTCELLLATENTMODELINTEGRATION Exercise Python inference and training.
tests = functiontests(localfunctions);
end

function testPackagingTimestampIsStrictUtcIso8601(testCase)
value=cellLatentModel.utils.utcIso8601();
verifyNotEmpty(testCase,regexp(value, ...
    '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}(Z|\+00:00)$', ...
    'once'));
verifyFalse(testCase,contains(value,'***'));
end

function testBuiltinInferencePersistsMultimodalLineage(testCase)
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() removeFolder(folder));
roiobj = syntheticROI(folder,'latent_inference',0);
param = cellLatentModel.utils.defaultExecutionParam();
param.trackChannelName = 'results_trackastra';
param.gfpChannelName = 'ch2-GFP';
param.outputFamilyName = 'Latent integration';
param.device = 'cpu';
param.maxParentContourDistance = 25;
ctx = struct('store',struct('workDir',fullfile(folder,'runtime')));
[resolved,dataout,imageout] = cellLatentModel.core(param,roiobj,ctx);
verifyClass(testCase,dataout,'dataseries');
verifyTrue(testCase,any(strcmp({dataout.groupid},'cell_information')));
verifyEmpty(testCase,imageout);
verifyEqual(testCase,resolved.runtime.package,'cell_latent_model');
verifyEqual(testCase,resolved.runtime.backend,'legacy');
verifyTrue(testCase,resolved.runtime.gfp_used);
verifyTrue(testCase,isfile(resolved.auditFile));
audit = jsondecode(fileread(resolved.auditFile));
verifyEqual(testCase,audit.tool,'cell_latent_model');
verifyGreaterThanOrEqual(testCase,double(audit.summary.events),1);
[model,report] = roiobj.loadCellModel('Force',true);
verifyTrue(testCase,report.validation.ok);
[familyIndex,~] = cellModel.familyIndex(model,param.outputFamilyName);
verifyNotEmpty(testCase,familyIndex);
verifyEqual(testCase, ...
    model.families.mask_provider{familyIndex},'results_trackastra');
verifyEqual(testCase, ...
    model.families.lineage_source{familyIndex},'pred:cellLatentModel');
ds = dataout(find(strcmp({dataout.groupid},'cell_information'),1));
sourceKey = matlab.lang.makeValidName(param.outputFamilyName);
verifyTrue(testCase,isfield(ds.userData.lineageSources,sourceKey));
verifyEqual(testCase,ds.userData.activeLineageSource,sourceKey);
end

function testTemporalBuiltinV002PersistsObjectsOnly(testCase)
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() removeFolder(folder));
roiobj = syntheticROI(folder,'temporal_inference',0);
param = cellLatentModel.utils.defaultExecutionParam();
param.backend = 'temporal_lineage';
param.temporalVariant = 'all_observed';
param.trackChannelName = 'results_trackastra';
param.nucleusChannelName = 'ch2-GFP';
param.budneckChannelName = '';
param.frameIntervalMinutes = 3;
param.outputFamilyName = 'Temporal v002 integration';
param.device = 'cpu';
ctx = struct('store',struct('workDir',fullfile(folder,'runtime')));

[resolved,dataout,imageout] = cellLatentModel.core(param,roiobj,ctx);

verifyClass(testCase,dataout,'dataseries');
verifyTrue(testCase,any(strcmp({dataout.groupid},'cell_information')));
verifyEmpty(testCase,imageout);
verifyEqual(testCase,resolved.runtime.backend,'temporal_lineage');
verifyTrue(testCase,resolved.runtime.nucleus_used);
verifyFalse(testCase,resolved.runtime.budneck_used);
verifyTrue(testCase,isfile(resolved.cellModelFile));
audit = jsondecode(fileread(resolved.auditFile));
verifyEqual(testCase,audit.backend,'temporal_lineage');
verifyEqual(testCase,audit.package.package_id, ...
    'temporal_lineage_multidomain_v002');
verifyEqual(testCase,audit.package.variant,'all_observed');
verifyEqual(testCase,double(audit.frame_interval_minutes),3);
verifyTrue(testCase,audit.marker_inputs.nucleus);
verifyFalse(testCase,audit.marker_inputs.budneck);

[model,report] = roiobj.loadCellModel('Force',true);
verifyTrue(testCase,report.validation.ok);
[familyIndex,~] = cellModel.familyIndex(model,param.outputFamilyName);
verifyNotEmpty(testCase,familyIndex);
verifyEqual(testCase, ...
    model.families.mask_provider{familyIndex},'results_trackastra');
verifyEqual(testCase, ...
    model.families.lineage_source{familyIndex},'pred:cellLatentModel');
end

function testJsonDecodedHeterogeneousEdgesMaterializeRelations(testCase)
model = cellModel.create('heterogeneous_json');
tracks = zeros(4,4,3,'uint32');
tracks(1:2,1:2,:) = 1;
tracks(3:4,3:4,2:3) = 2;
payload = ['{"edges":[' ...
    '{"status":"linked","pred_parent_id":1,"child_track_id":2,' ...
    '"bud_appearance_frame":2,"top_score":0.95},' ...
    '{"status":"review","child_track_id":3,' ...
    '"bud_appearance_frame":3,"reason":"low_margin"}]}'];
result = jsondecode(payload);
verifyClass(testCase,result.edges,'cell');

[model,familyId,report] = cellModel.applyLineageResult( ...
    model,tracks,'results_trackastra','<auto>', ...
    'Decoded lineage',result,true,'cellLatentModel');

verifyEqual(testCase,report.linked_relations,1);
verifyEqual(testCase,sum(model.relations.family_id == familyId),1);
verifyEqual(testCase,model.relations.parent_track_id,uint64(1));
verifyEqual(testCase,model.relations.child_track_id,uint64(2));
end

function testTemporalChannelRolesAreExplicit(testCase)
param = cellLatentModel.utils.defaultExecutionParam();
param.backend = 'temporal_lineage';
param.channels = {'results_trackastra','ch2-GFP'};
param.trackChannelName = '';
param.gfpChannelName = 'ch2-GFP';

resolved = cellLatentModel.normalizeParam(param);

verifyEqual(testCase,resolved.trackChannelName,'results_trackastra');
verifyEmpty(testCase,resolved.gfpChannelName);
verifyEmpty(testCase,resolved.nucleusChannelName);
verifyEmpty(testCase,resolved.budneckChannelName);
end

function testTemporalChannelRoleConflictsAreRejected(testCase)
param = cellLatentModel.utils.defaultExecutionParam();
param.backend = 'temporal_lineage';
param.trackChannelName = 'results_trackastra';
param.nucleusChannelName = 'ch2-GFP';
param.budneckChannelName = 'ch2-GFP';

verifyError(testCase,@() cellLatentModel.normalizeParam(param), ...
    'cellLatentModel:ConflictingChannelRoles');
end

function testAllObservedPermitsExplicitMissingMarkers(testCase)
param = cellLatentModel.utils.defaultExecutionParam();
param.backend = 'temporal_lineage';
param.temporalVariant = 'all_observed';
param.trackChannelName = 'results_trackastra';
param.nucleusChannelName = '';
param.budneckChannelName = '';

resolved = cellLatentModel.normalizeParam(param);

verifyEqual(testCase,resolved.temporalVariant,'all_observed');
verifyEmpty(testCase,resolved.nucleusChannelName);
verifyEmpty(testCase,resolved.budneckChannelName);
end

function testContinuousRequiresExplicitFrameInterval(testCase)
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() removeFolder(folder));
checkpoint = fullfile(folder,'continuous.pt');
touchFile(checkpoint);
param = continuousParam(checkpoint);
param.frameIntervalMinutes = [];

verifyError(testCase,@() cellLatentModel.normalizeParam(param), ...
    'cellLatentModel:MissingFrameInterval');
end

function testContinuousRequiresTrainedCheckpoint(testCase)
param = cellLatentModel.utils.defaultExecutionParam();
param.backend = 'continuous_cell_state';
param.trackChannelName = 'results_trackastra';
param.frameIntervalMinutes = 3;

verifyError(testCase,@() cellLatentModel.normalizeParam(param), ...
    'cellLatentModel:ContinuousRequiresTrainedModel');
end

function testContinuousRolesAreExplicitAndExclusive(testCase)
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() removeFolder(folder));
checkpoint = fullfile(folder,'continuous.pt');
touchFile(checkpoint);
param = continuousParam(checkpoint);
param.brightfieldChannelName = 'ch1-PH';
param.nucleusChannelName = 'ch2-nucleus';
param.budneckChannelName = 'ch3-budneck';

resolved = cellLatentModel.normalizeParam(param);

verifyEqual(testCase,resolved.backend,'continuous_cell_state');
verifyEqual(testCase,resolved.modelSource,'trained');
verifyEqual(testCase,resolved.frameIntervalMinutes,3);
verifyEmpty(testCase,resolved.gfpChannelName);
param.nucleusChannelName = param.brightfieldChannelName;
verifyError(testCase,@() cellLatentModel.normalizeParam(param), ...
    'cellLatentModel:ConflictingChannelRoles');
end

function testAdaptiveMarkerArtifactIsClassifierOwned(testCase)
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() removeFolder(folder));
checkpoint = fullfile(folder,'continuous.pt');
markerCheckpoint = fullfile(folder,'adaptive_marker.pt');
touchFile(checkpoint);
touchFile(markerCheckpoint);
param = continuousParam(checkpoint);
param.causalSolverFeedback = false;
param.adaptiveMarkerModelSource = 'trained';
param.adaptiveMarkerModelPath = markerCheckpoint;

resolved = cellLatentModel.normalizeParam(param);
spec = cellLatentModel.executionSpec();

verifyEqual(testCase,resolved.adaptiveMarkerModelSource,'trained');
verifyEqual(testCase,resolved.adaptiveMarkerModelPath,markerCheckpoint);
verifyTrue(testCase,ismember('adaptiveMarkerModelPath',spec.artifactKeys));
verifyFalse(testCase,ismember('adaptiveMarkerModelPath',spec.staticKeys));
end

function testAdaptiveMarkerRejectsUnsupportedSolverCombination(testCase)
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() removeFolder(folder));
checkpoint = fullfile(folder,'continuous.pt');
markerCheckpoint = fullfile(folder,'adaptive_marker.pt');
touchFile(checkpoint);
touchFile(markerCheckpoint);
param = continuousParam(checkpoint);
param.adaptiveMarkerModelSource = 'trained';
param.adaptiveMarkerModelPath = markerCheckpoint;

verifyError(testCase,@() cellLatentModel.normalizeParam(param), ...
    'cellLatentModel:AdaptiveMarkerSolverConflict');
end

function testContinuousBiologicalStateSidecar(testCase)
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() removeFolder(folder));
roiobj = roi('continuous_state',[1 1 10 10]);
roiobj.path = folder;
records = repmat(struct( ...
    'track_id',0,'label_id',0,'frame',0,'time_minutes',0, ...
    'bud_onset_hazard',0,'division_hazard',0, ...
    'active_bud_probability',0),2,1);
records(1).track_id = 1;
records(1).label_id = 1;
records(1).frame = 1;
records(2).track_id = 2;
records(2).label_id = 2;
records(2).frame = 3;
records(2).time_minutes = 6;
result = struct( ...
    'created_at','2026-07-27T12:00:00+02:00', ...
    'frame_interval_minutes',3, ...
    'checkpoint',struct('sha256','abc','model_class', ...
        'ContinuousBiologicalStateFeedbackModel'), ...
    'biological_state',struct( ...
        'enabled',true, ...
        'state_names',{{'bud_onset_hazard','division_hazard'}}, ...
        'records',records));

report = cellLatentModel.persistBiologicalState( ...
    roiobj,uint32(4),'Continuous state','results_trackastra', ...
    result,fullfile(folder,'audit.json'));

verifyTrue(testCase,isfile(report.filename));
verifyEqual(testCase,report.records,2);
saved = jsondecode(fileread(report.filename));
verifyEqual(testCase,saved.format,'detecdiv_continuous_cell_state');
verifyEqual(testCase,double(saved.schema_version),1);
verifyEqual(testCase,double(saved.family_id),4);
verifyEqual(testCase,double([saved.records.track_id]),[1 2]);
verifyEqual(testCase,double([saved.records.frame]),[1 3]);
end

function testContinuousStatesAreMaterializedOnCellObjects(testCase)
model = cellModel.create('state_materialization');
tracks = zeros(5,5,3,'uint32');
tracks(2:3,2:3,1:3) = 1;
lineageResult = struct('edges',struct([]));
[model,familyId] = cellModel.applyLineageResult( ...
    model,tracks,'results_trackastra','<auto>', ...
    'Latent cells',lineageResult,true,'cellLatentModel');
records = repmat(struct('track_id',1,'frame',1, ...
    'active_bud_probability',0),3,1);
records(1).active_bud_probability = 0.1;
records(2).frame = 2;
records(2).active_bud_probability = 0.5;
records(3).frame = 3;
records(3).active_bud_probability = 0.9;
result = struct('biological_state',struct('records',records));
param = cellLatentModel.utils.defaultExecutionParam();

[model,report] = cellLatentModel.applyBiologicalState( ...
    model,familyId,result,param);

rows = model.instances.family_id == familyId;
verifyEqual(testCase,cellstr(string(model.states.name)), ...
    {'budding: inactive';'budding: active'});
verifyEqual(testCase,double(model.instances.state_id(rows))',[1 0 2]);
verifyEqual(testCase,report.inactive,1);
verifyEqual(testCase,report.uncertain,1);
verifyEqual(testCase,report.active,1);
verifyTrue(testCase,cellModel.validate(model).ok);
end

function testStateThresholdsAreValidated(testCase)
param = cellLatentModel.utils.defaultExecutionParam();
param.trackChannelName = 'results_trackastra';
param.stateNegativeThreshold = 0.8;
param.statePositiveThreshold = 0.2;

verifyError(testCase,@() cellLatentModel.normalizeParam(param), ...
    'cellLatentModel:InvalidStateThresholds');
end

function testDefaultExecutionRemainsPathFreeLegacy(testCase)
param = cellLatentModel.utils.defaultExecutionParam();

verifyEqual(testCase,param.backend,'legacy');
verifyEmpty(testCase,param.frameIntervalMinutes);
verifyFalse(testCase,isfield(param,'pythonExecutable'));
verifyFalse(testCase,isfield(param,'repositoryRoot'));
verifyFalse(testCase,isfield(param,'lineageRepositoryRoot'));
verifyFalse(testCase,isfield(param,'packagePath'));
verifyFalse(testCase,isfield(param,'modelPackage'));
end

function testNormalizeDropsObsoleteRuntimePaths(testCase)
param = cellLatentModel.utils.defaultExecutionParam();
param.trackChannelName = 'results_trackastra';
param.pythonExecutable = 'forbidden-python';
param.repositoryRoot = 'forbidden-repository';
param.lineageRepositoryRoot = 'forbidden-lineage-repository';
param.packagePath = 'forbidden-package';
param.modelPackage = 'forbidden-model-package';
param.cellLatentRepository = 'forbidden-latent-repository';

resolved = cellLatentModel.normalizeParam(param);

obsolete = {'pythonExecutable','repositoryRoot','lineageRepositoryRoot', ...
    'packagePath','modelPackage','cellLatentRepository'};
verifyFalse(testCase,any(isfield(resolved,obsolete)));
end

function testTemporalExecutionSpecDeclaresTypedRoles(testCase)
spec = cellLatentModel.executionSpec();

verifyEqual(testCase,spec.inputKeys, ...
    {'instanceChannelName','trackChannelName','gfpChannelName', ...
     'brightfieldChannelName','nucleusChannelName','budneckChannelName'});
verifyEqual(testCase,spec.choices.backend, ...
    {'causal_composite','legacy','temporal_lineage','continuous_cell_state'});
verifyEqual(testCase,spec.choices.temporalVariant, ...
    {'temporal_geometry','all_observed'});
verifyTrue(testCase,contains(lower(spec.labels.nucleusChannelName), ...
    'division/nucleus fluorescence'));
verifyTrue(testCase,contains(lower(spec.labels.budneckChannelName), ...
    'bud-neck fluorescence'));
verifyTrue(testCase,contains(lower(spec.tips.gfpChannelName), ...
    'never assigned'));
verifyTrue(testCase,contains(lower(spec.tips.brightfieldChannelName), ...
    'continuous_cell_state'));
verifyTrue(testCase,contains(lower(spec.tips.temporalVariant), ...
    'temporal history'));
allPipelineKeys = [spec.staticKeys spec.defaultImportKeys];
privatePathKeys = {'pythonExecutable','repositoryRoot', ...
    'lineageRepositoryRoot','packagePath','modelPackage', ...
    'cellLatentRepository'};
verifyFalse(testCase,any(ismember(privatePathKeys,allPipelineKeys)));
verifyTrue(testCase,all(ismember(privatePathKeys,spec.environmentKeys)));
end

function param = continuousParam(checkpoint)
param = cellLatentModel.utils.defaultExecutionParam();
param.backend = 'continuous_cell_state';
param.trackChannelName = 'results_trackastra';
param.frameIntervalMinutes = 3;
param.modelSource = 'trained';
param.modelPath = checkpoint;
end

function touchFile(filename)
fid = fopen(filename,'w');
if fid < 0, error('testCellLatentModel:TouchFailed','Cannot create fixture.'); end
cleanup = onCleanup(@() fclose(fid));
fwrite(fid,uint8([1 2 3]),'uint8');
end

function testClassifierLifecycleFormatsTrainsAndValidates(testCase)
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() removeFolder(folder));
classifier = classi(folder,'latent_lifecycle',1);
roi1 = syntheticROI(fullfile(folder,'roi1'),'latent_train',0);
roi2 = syntheticROI(fullfile(folder,'roi2'),'latent_validation',1);
writeReviewedLineage(roi1);
writeReviewedLineage(roi2);
classifier.roi = [roi1 roi2];
classifier.channelName = {'results_trackastra','ch2-GFP'};
classifier.dataset.split.train = 1;
classifier.dataset.split.val = 2;
classifier.dataset.split.test = [];
cellLatentModel.setparam(classifier);
classifier.trainingParam.architectureVersion = 'lineage_only_v1';
classifier.trainingParam.trainingObjective = 'relation_ensemble';
classifier.trainingParam.trackChannelName = 'results_trackastra';
classifier.trainingParam.gfpChannelName = 'ch2-GFP';
classifier.trainingParam.groundTruthFamily = 'Reviewed lineage';
classifier.trainingParam.epochs = 2;
classifier.trainingParam.seedCount = 1;
classifier.trainingParam.device = 'cpu';

formatted = cellLatentModel.format(classifier,1,struct());
verifyEqual(testCase,formatted.status,"OK");
verifyTrue(testCase,isfile(formatted.artifacts.manifest));
firstManifest = formatted.artifacts.manifest;
datasetRoot = fullfile(classifier.path,'trainingdataset');
pointerFile = fullfile(datasetRoot, ...
    'latest_cell_latent_relation_dataset.json');
verifyTrue(testCase,isfile(pointerFile));
pointerBeforeFailure = fileread(pointerFile);
badTp = classifier.trainingParam;
badTp.trackChannelName = 'missing_tracking_channel';
verifyError(testCase,@() cellLatentModel.formatDataset( ...
    classifier,1,2,datasetRoot, ...
    struct('formatRunId','intentional_failure'),badTp), ...
    'cellLatentModel:TrainingChannelNotFound');
verifyEqual(testCase,fileread(pointerFile),pointerBeforeFailure, ...
    'A failed run must not replace the last completed dataset pointer.');
verifyFalse(testCase,isfolder(fullfile(datasetRoot,'format_runs', ...
    'intentional_failure')));
% Exercise the same public path used by classifierGUI.  Versioned package
% formatters must not inherit the legacy wrapper's destructive reset.
formatted = classifier.formatDataForTraining('Frames',[],'Rois',1);
verifyNotEqual(testCase,formatted.artifacts.manifest,firstManifest);
verifyTrue(testCase,isfile(firstManifest), ...
    'Reformatting must preserve the earlier immutable dataset version.');
trained = cellLatentModel.train(classifier,struct());
verifyEqual(testCase,trained.status,"OK");
verifyTrue(testCase,isfile(trained.artifacts.model));
verifyEqual(testCase,classifier.executionParam.modelSource,'trained');
validated = cellLatentModel.validate(classifier,2,struct());
verifyEqual(testCase,validated.status,"OK");
verifyGreaterThanOrEqual(testCase, ...
    double(validated.metrics.labeled_events),1);
verifyTrue(testCase,isfinite(double(validated.metrics.top1)));
end

function testCompositeLifecycleTrainsTracksThenLineage(testCase)
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() removeFolder(folder)); %#ok<NASGU>
classifier = classi(folder,'composite_lifecycle',1);
roi1 = syntheticROI(fullfile(folder,'roi1'),'composite_train',0);
roi2 = syntheticROI(fullfile(folder,'roi2'),'composite_validation',1);
addFrameLocalInstances(roi1);
addFrameLocalInstances(roi2);
writeReviewedLineage(roi1);
writeReviewedLineage(roi2);
classifier.roi = [roi1 roi2];
classifier.channelName = {'results_cellposeSAM_cell','ch2-GFP'};
classifier.dataset.split.train = 1;
classifier.dataset.split.val = 2;
classifier.dataset.split.test = [];
cellLatentModel.setparam(classifier);
tp = classifier.trainingParam;
tp.architectureVersion = 'detecdiv_composite_v1';
tp.trainTrackingActions = true;
tp.trainMotherNull = true;
tp.stateUpdateMode = 'none';
tp.instanceChannelName = 'results_cellposeSAM_cell';
tp.trackChannelName = 'results_trackastra';
tp.groundTruthFamily = 'Reviewed lineage';
tp.frameIntervalMinutes = 3;
tp.trainingDomain = 'synthetic_reviewed';
tp.continuousVariant = 'geometry';
tp.continuousStateDim = 8;
tp.continuousBlockEmbeddingDim = 4;
tp.continuousAttentionDim = 8;
tp.maxEventHistoryTokens = 2;
tp.trackingInitialModelSource = 'random';
tp.trackingEpochs = 1;
tp.epochs = 1;
tp.device = 'cpu';
tp.modelName = 'composite_smoke_v001';
classifier.trainingParam = tp;

formatted = cellLatentModel.format(classifier,1,struct());
verifyEqual(testCase,formatted.status,"OK");
verifyGreaterThan(testCase,double(formatted.metrics.outputCount),0);
verifyEqual(testCase,formatted.metrics.outputUnit,'ROI frames');
verifyTrue(testCase,isfile(formatted.artifacts.compositeManifest));
verifyTrue(testCase,contains(normalizeTestPath( ...
    formatted.artifacts.compositeManifest),'/trainingdataset/c/'));
dataset = jsondecode(fileread(formatted.artifacts.compositeManifest));
verifyTrue(testCase,isfield(dataset.components,'tracking'));
verifyTrue(testCase,isfield(dataset.components,'lineage'));
verifyEqual(testCase,double(dataset.split.train),1);
verifyEqual(testCase,double(dataset.split.validation),2);
verifyEqual(testCase,double(dataset.components.tracking.train_rois),1);
verifyEqual(testCase,double(dataset.components.tracking.validation_rois),2);
verifyEqual(testCase,double(dataset.components.lineage.train_rois),1);
verifyEqual(testCase,double(dataset.components.lineage.validation_rois),2);
pointer = jsondecode(fileread(formatted.artifacts.pointer));
verifyEqual(testCase,normalizeTestPath(pointer.manifest), ...
    normalizeTestPath(formatted.artifacts.compositeManifest));
verifyFalse(testCase,contains(pointer.created_at,'***'));
verifyNotEmpty(testCase,regexp(pointer.created_at, ...
    '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}(Z|\+00:00)$', ...
    'once'));
verifyEqual(testCase,pointer.legacy_pointer_policy, ...
    'marked compatibility aliases; this composite pointer is authoritative');
datasetRoot=fullfile(classifier.path,'trainingdataset');
trackingAlias=jsondecode(fileread(fullfile(datasetRoot, ...
    'latest_latent_tracking_dataset.json')));
lineageAlias=jsondecode(fileread(fullfile(datasetRoot, ...
    'latest_cell_latent_continuous_dataset.json')));
verifyEqual(testCase,trackingAlias.status,'compatibility_alias');
verifyEqual(testCase,lineageAlias.status,'compatibility_alias');
verifyEqual(testCase,normalizeTestPath(trackingAlias.manifest), ...
    normalizeTestPath(dataset.components.tracking.manifest));
verifyEqual(testCase,normalizeTestPath(lineageAlias.manifest), ...
    normalizeTestPath(dataset.components.lineage.manifest));
verifyEqual(testCase,normalizeTestPath( ...
    trackingAlias.authoritative_pointer), ...
    normalizeTestPath(formatted.artifacts.pointer));
verifyEqual(testCase,normalizeTestPath(dataset.components.tracking.manifest), ...
    normalizeTestPath(formatted.artifacts.trackingManifest));
verifyEqual(testCase,normalizeTestPath(dataset.components.lineage.manifest), ...
    normalizeTestPath(formatted.artifacts.lineageManifest));
trackingDataset = jsondecode(fileread(formatted.artifacts.trackingManifest));
lineageDataset = jsondecode(fileread(formatted.artifacts.lineageManifest));
verifyTrue(testCase,isfield(trackingDataset,'materialized_sources'));
verifyTrue(testCase,isfield(lineageDataset,'materialized_sources'));
verifyEqual(testCase,numel(trackingDataset.materialized_sources),2);
verifyEqual(testCase,numel(lineageDataset.materialized_sources),2);
for source = [trackingDataset.materialized_sources(:); ...
        lineageDataset.materialized_sources(:)].'
    verifyTrue(testCase,isfile(source.path));
    verifyNotEmpty(testCase,source.sha256);
    verifyGreaterThan(testCase,double(source.bytes),0);
end
verifyFalse(testCase,contains(lower(normalizeTestPath( ...
    jsonencode(trackingDataset))),'/staging/'));
verifyFalse(testCase,contains(lower(normalizeTestPath( ...
    jsonencode(lineageDataset))),'/staging/'));

trained = cellLatentModel.train(classifier,struct());
verifyEqual(testCase,trained.status,"OK");
verifyTrue(testCase,isfile(trained.artifacts.manifest));
verifyEqual(testCase,classifier.executionParam.backend,'causal_composite');
verifyTrue(testCase,isfolder(fullfile( ...
    classifier.path,classifier.executionParam.trackingCheckpointDir)));
verifyTrue(testCase,isfile(fullfile( ...
    classifier.path,classifier.executionParam.modelPath)));
modelManifest = jsondecode(fileread(trained.artifacts.manifest));
verifyFalse(testCase,contains(modelManifest.created_at,'***'));
verifyTrue(testCase,isfield(modelManifest,'model_selection'));
verifyTrue(testCase,isfield(modelManifest.model_selection,'lineage'));
verifyTrue(testCase,isfield( ...
    modelManifest.components.lineage.selection,'selected_epoch'));
verifyTrue(testCase,isfield( ...
    modelManifest.components.lineage.selection,'selection_policy'));
verifyEqual(testCase, ...
    modelManifest.model_selection.lineage.selected_epoch, ...
    modelManifest.components.lineage.selection.selected_epoch);
verifyFalse(testCase,contains(lower(jsonencode(modelManifest)), ...
    '.partial_'));
modelJsonFiles = dir(fullfile(fileparts(trained.artifacts.manifest), ...
    '**','*.json'));
for file = modelJsonFiles(:).'
    contents = fileread(fullfile(file.folder,file.name));
    verifyFalse(testCase,contains(lower(contents),'.partial_'), ...
        sprintf('Transient path survived in %s.',file.name));
end

classified = cellLatentModel.classify(roi2,classifier,struct( ...
    'store',struct('workDir',fullfile(folder,'runtime'))));
verifyEqual(testCase,classified.status,"OK");
verifyTrue(testCase,isfield(classified.refs,'outputTrackChannelName'));
verifyFalse(testCase,isempty(roi2.findChannelID( ...
    classified.refs.outputTrackChannelName,'exact')));
audit = jsondecode(fileread(classified.artifacts.audit));
verifyEqual(testCase,audit.backend,'causal_composite');
verifyFalse(testCase,audit.composite.targets_consumed_at_inference);
validated = cellLatentModel.validate(classifier,2,struct( ...
    'store',struct('workDir',fullfile(folder,'validation_runtime'))));
verifyEqual(testCase,validated.status,"OK");
verifyTrue(testCase,isfield(validated.metrics,'tracking'));
verifyTrue(testCase,isfield(validated.metrics,'lineage'));
verifyGreaterThanOrEqual(testCase,validated.metrics.tracking.idf1,0);
verifyTrue(testCase,isfile(validated.artifacts.validation));
end

function testAutomaticValidationHoldoutExcludesGuiTestRois(testCase)
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() removeFolder(folder)); %#ok<NASGU>
classifier = classi(folder,'latent_automatic_validation',1);
rois = [ ...
    syntheticROI(fullfile(folder,'roi1'),'automatic_train_1',0), ...
    syntheticROI(fullfile(folder,'roi2'),'automatic_train_2',1), ...
    syntheticROI(fullfile(folder,'roi3'),'automatic_train_3',2), ...
    syntheticROI(fullfile(folder,'roi4'),'automatic_validation',3), ...
    syntheticROI(fullfile(folder,'roi5'),'gui_test_unannotated',4)];
for i = 1:4
    writeReviewedLineage(rois(i));
end
classifier.roi = rois;
classifier.channelName = {'results_trackastra','ch2-GFP'};
classifier.dataset.split.train = 1:4;
classifier.dataset.split.val = [];
classifier.dataset.split.test = 5;
cellLatentModel.setparam(classifier);
classifier.trainingParam.architectureVersion = 'lineage_only_v1';
classifier.trainingParam.trainingObjective = 'relation_ensemble';
classifier.trainingParam.trackChannelName = 'results_trackastra';
classifier.trainingParam.gfpChannelName = 'ch2-GFP';
classifier.trainingParam.groundTruthFamily = 'Reviewed lineage';
classifier.trainingParam.validationFraction = 0.2;

[expectedTrain,expectedValidation] = cellLatentModel.resolveRoiSplits( ...
    classifier,1:4,classifier.trainingParam.validationFraction);
formatted = cellLatentModel.format(classifier,1:4,struct());

verifyEqual(testCase,double(formatted.refs.trainRois),expectedTrain);
verifyEqual(testCase,double(formatted.refs.validationRois), ...
    expectedValidation);
verifyEqual(testCase,formatted.refs.splitAudit.mode,'automatic');
verifyEqual(testCase,formatted.refs.splitAudit.algorithm, ...
    'sha256_ranked_stable_roi_identity_v1');
config = jsondecode(fileread(formatted.artifacts.config));
splits = string({config.rois.split});
verifyEqual(testCase,find(splits == "train"),1:numel(expectedTrain));
verifyEqual(testCase,find(splits == "validation"), ...
    numel(expectedTrain)+(1:numel(expectedValidation)));
verifyEqual(testCase,string({config.rois.roi_id}),string({ ...
    classifier.roi([expectedTrain expectedValidation]).id}));
verifyFalse(testCase,any(strcmp({config.rois.roi_id},'gui_test_unannotated')));
end

function testTrackingFormatterRefusesImmutableTargetCollision(testCase)
folder=tempname;
mkdir(folder);
cleanup=onCleanup(@()removeFolder(folder)); %#ok<NASGU>
classifier=classi(folder,'tracking_collision',1);
classifier.roi=[ ...
    syntheticROI(fullfile(folder,'roi1'),'collision_train',0), ...
    syntheticROI(fullfile(folder,'roi2'),'collision_validation',1)];
classifier.dataset.split.train=1;
classifier.dataset.split.val=2;
classifier.dataset.split.test=[];
cellLatentTracker.setparam(classifier);
classifier.trainingParam.instanceChannelName='results_cellposeSAM_cell';
classifier.trainingParam.groundTruthChannelName='reviewed_tracks';
datasetDir=fullfile(folder,'immutable_dataset');
mkdir(datasetDir);
sentinel=fullfile(datasetDir,'completed.marker');
touchFile(sentinel);
ctx=struct('datasetDir',datasetDir, ...
    'runDir',fullfile(folder,'new_run'));

verifyError(testCase,@()cellLatentTracker.format(classifier,1,ctx), ...
    'cellLatentTracker:ImmutableDatasetExists');
verifyTrue(testCase,isfile(sentinel));
verifyFalse(testCase,isfolder(ctx.runDir));
end

function testDirectTrackingTrainingRejectsChangedPublishedManifest(testCase)
folder=tempname;
mkdir(folder);
classifier=classi(folder,'tracking_manifest_hash_gate',1);
mkdir(fullfile(classifier.path,'trainingdataset'));
cleanup=onCleanup(@()removeFolder(folder)); %#ok<NASGU>
cellLatentTracker.setparam(classifier);
manifestFile=fullfile(classifier.path,'trainingdataset','manifest.json');
writeJsonFixture(manifestFile,struct('schema_version',1, ...
    'format','detecdiv_latent_tracking_collection_v1', ...
    'sequences',struct([])));
pointerFile=fullfile(classifier.path,'trainingdataset', ...
    'latest_latent_tracking_dataset.json');
writeJsonFixture(pointerFile,struct('schema_version',1, ...
    'manifest',normalizeTestPath(manifestFile), ...
    'manifest_sha256',repmat('0',1,64)));

verifyError(testCase,@()cellLatentTracker.train(classifier,struct()), ...
    'cellLatentTracker:FormattedDatasetChanged');
end

function testLineageFormatterExportsStableTrackIdsAndPreservesSources(testCase)
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() removeFolder(folder)); %#ok<NASGU>
classifier = classi(folder,'stable_lineage_export',1);
roi1 = syntheticROI(fullfile(folder,'roi1'),'stable_train',0);
roi2 = syntheticROI(fullfile(folder,'roi2'),'stable_validation',1);
writeStableReviewedLineage(roi1);
writeStableReviewedLineage(roi2);
classifier.roi = [roi1 roi2];
classifier.dataset.split.train = 1;
classifier.dataset.split.val = 2;
classifier.dataset.split.test = [];
cellLatentModel.setparam(classifier);
tp = classifier.trainingParam;
tp.architectureVersion = 'lineage_only_v1';
tp.trainingObjective = 'continuous_lineage';
tp.trackChannelName = 'results_trackastra';
tp.groundTruthFamily = 'Reviewed lineage';
tp.frameIntervalMinutes = 3;
tp.trainingDomain = 'synthetic_stable_identity';

imageFile = roi1.getH5Filename();
modelFile = cellModel.pathForROI(roi1);
sourceHashes = {fixtureFileSha256(imageFile),fixtureFileSha256(modelFile)};
datasetRoot = fullfile(folder,'formatted');
runContext = struct('formatRunId','stable_identity_v001');
formatted = cellLatentModel.formatDataset( ...
    classifier,1,2,datasetRoot,runContext,tp);

config = jsondecode(fileread(formatted.configFile));
trainSpec = config.rois(strcmp(string({config.rois.split}),'train'));
verifyEqual(testCase,trainSpec.tracks_representation, ...
    'cell_model_track_id');
verifyEqual(testCase,trainSpec.tracks_mask_provider, ...
    'results_trackastra');
materialized = h5read(trainSpec.input_path,trainSpec.tracks_dataset);
verifyEqual(testCase,unique(materialized(:,:,3)), ...
    uint32([0;40;41;50]));
verifyEqual(testCase,unique(materialized(:,:,7)), ...
    uint32([0;40;42;50]));
verifyFalse(testCase,any(ismember(unique(materialized(:)),uint32(1:3))), ...
    'Frame-local labels must never be exported as persistent track IDs.');
relations = trainSpec.ground_truth_relations;
verifyEqual(testCase,sort(double([relations.child_track_id])),[41 42]);
verifyEqual(testCase,double([relations.parent_track_id]),[40 40]);
verifyGreaterThan(testCase,min(double([relations.child_track_id])),3, ...
    'Relation endpoints must remain stable IDs, not local mask labels.');
verifyEqual(testCase,fixtureFileSha256(imageFile),sourceHashes{1});
verifyEqual(testCase,fixtureFileSha256(modelFile),sourceHashes{2});

publishedHash = fixtureFileSha256(formatted.manifestFile);
verifyError(testCase,@() cellLatentModel.formatDataset( ...
    classifier,1,2,datasetRoot,runContext,tp), ...
    'cellLatentModel:ImmutableDatasetExists');
verifyEqual(testCase,fixtureFileSha256(formatted.manifestFile),publishedHash, ...
    'A completed versioned dataset must remain immutable.');
end

function testLineageFormatterRejectsRelationOutsideStableGt(testCase)
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() removeFolder(folder)); %#ok<NASGU>
classifier = classi(folder,'invalid_stable_lineage',1);
roi1 = syntheticROI(fullfile(folder,'roi1'),'invalid_train',0);
roi2 = syntheticROI(fullfile(folder,'roi2'),'valid_validation',1);
writeStableReviewedLineage(roi1);
writeStableReviewedLineage(roi2);
[model,~] = roi1.loadCellModel('Force',true);
model.relations.child_track_id(2) = uint64(999);
roi1.saveCellModel(model,'KeepBackup',false);
classifier.roi = [roi1 roi2];
cellLatentModel.setparam(classifier);
tp = classifier.trainingParam;
tp.trainingObjective = 'continuous_lineage';
tp.trackChannelName = 'results_trackastra';
tp.groundTruthFamily = 'Reviewed lineage';
tp.frameIntervalMinutes = 3;
modelFile = cellModel.pathForROI(roi1);
sourceHash = fixtureFileSha256(modelFile);
datasetRoot = fullfile(folder,'formatted');

verifyError(testCase,@() cellLatentModel.formatDataset( ...
    classifier,1,2,datasetRoot,struct('formatRunId','invalid_v001'),tp), ...
    'cellLatentModel:InvalidGroundTruthRelations');
verifyEqual(testCase,fixtureFileSha256(modelFile),sourceHash);
verifyFalse(testCase,isfolder(fullfile( ...
    datasetRoot,'format_runs','invalid_v001')));
end

function testLineageFormatterUsesTolerantTemporalRelationContract(testCase)
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() removeFolder(folder)); %#ok<NASGU>
classifier = classi(folder,'temporal_relation_contract',1);
roi1 = syntheticROI(fullfile(folder,'roi1'),'birth_plus_one_train',0);
roi2 = syntheticROI(fullfile(folder,'roi2'),'birth_plus_one_validation',1);
writeStableReviewedLineage(roi1);
writeStableReviewedLineage(roi2);
for roiobj = [roi1 roi2]
    [model,~] = roiobj.loadCellModel('Force',true);
    model.relations.event_frame = model.relations.event_frame + uint32(1);
    roiobj.saveCellModel(model,'KeepBackup',false);
end
classifier.roi = [roi1 roi2];
cellLatentModel.setparam(classifier);
tp = classifier.trainingParam;
tp.trainingObjective = 'continuous_lineage';
tp.trackChannelName = 'results_trackastra';
tp.groundTruthFamily = 'Reviewed lineage';
tp.frameIntervalMinutes = 3;

formatted = cellLatentModel.formatDataset( ...
    classifier,1,2,fullfile(folder,'birth_plus_one'), ...
    struct('formatRunId','birth_plus_one_v001'),tp);
verifyTrue(testCase,isfile(formatted.manifestFile), ...
    'A relation recorded at child birth+1 must remain format-compatible.');

[model,~] = roi1.loadCellModel('Force',true);
model.relations.event_frame(1) = uint32(9);
roi1.saveCellModel(model,'KeepBackup',false);
verifyError(testCase,@() cellLatentModel.formatDataset( ...
    classifier,1,2,fullfile(folder,'impossible_relation'), ...
    struct('formatRunId','impossible_v001'),tp), ...
    'cellLatentModel:InvalidGroundTruthRelations');
end

function testFormattingAppliesPerRoiTrainingBounds(testCase)
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() removeFolder(folder)); %#ok<NASGU>
classifier = classi(folder,'latent_bounds',1);
roi1 = syntheticROI(fullfile(folder,'roi1'),'bounded_train',0);
roi2 = syntheticROI(fullfile(folder,'roi2'),'unbounded_validation',1);
writeReviewedLineage(roi1);
writeReviewedLineage(roi2);
classifier.roi = [roi1 roi2];
classifier.channelName = {'results_trackastra','ch2-GFP'};
classifier.dataset.split.train = 1;
classifier.dataset.split.val = 2;
classifier.dataset.split.test = [];
cellLatentModel.setparam(classifier);
classifier.trainingParam.architectureVersion = 'lineage_only_v1';
classifier.trainingParam.trainingObjective = 'relation_ensemble';
classifier.trainingParam.trackChannelName = 'results_trackastra';
classifier.trainingParam.gfpChannelName = 'ch2-GFP';
classifier.trainingParam.groundTruthFamily = 'Reviewed lineage';
trainingBounds.setRoi(classifier,1,'2:6','FrameCount',12);

formatted = cellLatentModel.format(classifier,1,struct());
config = jsondecode(fileread(formatted.artifacts.config));
trainSpec = config.rois(strcmp(string({config.rois.split}),'train'));
validationSpec = config.rois(strcmp(string({config.rois.split}),'validation'));
verifyEqual(testCase,double(trainSpec.source_frames(:).'),2:6);
verifyEqual(testCase,double(validationSpec.source_frames(:).'),1:12);
verifyEqual(testCase,double(trainSpec.ground_truth_relations.event_frame),2, ...
    'The original event at frame 3 must be remapped into the sliced stack.');
end

function testMissingContinuousIntervalPreservesFormattedDataset(testCase)
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() removeFolder(folder)); %#ok<NASGU>
classifier = classi(folder, 'continuous_preflight', 1);
roi1 = syntheticROI(fullfile(folder, 'roi1'), 'preflight_train', 0);
roi2 = syntheticROI(fullfile(folder, 'roi2'), 'preflight_validation', 1);
classifier.roi = [roi1 roi2];
classifier.dataset.split.train = 1;
classifier.dataset.split.val = 2;
classifier.dataset.split.test = [];
cellLatentModel.setparam(classifier);
classifier.trainingParam.trainingObjective = 'continuous_lineage';
classifier.trainingParam.frameIntervalMinutes = [];

datasetDir = fullfile(classifier.path, 'trainingdataset');
mkdir(datasetDir);
sentinel = fullfile(datasetDir, 'previous_dataset.marker');
touchFile(sentinel);

verifyError(testCase, @() classifier.formatDataForTraining( ...
    'Rois', 1, 'Frames', []), 'cellLatentModel:MissingFrameInterval');
verifyTrue(testCase, isfile(sentinel), ...
    'A failed preflight must not delete the previously formatted dataset.');
end

function testMissingGtChannelPreservesFormattedDataset(testCase)
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() removeFolder(folder)); %#ok<NASGU>
classifier = classi(folder, 'missing_gt_preflight', 1);
roi1 = syntheticROI(fullfile(folder, 'roi1'), 'ready_roi', 0);
roi2 = syntheticROI(fullfile(folder, 'roi2'), 'missing_gt_roi', 1);
classifier.roi = [roi1 roi2];
classifier.dataset.split.train = [1 2];
classifier.dataset.split.val = [];
classifier.dataset.split.test = [];
cellLatentModel.setparam(classifier);
classifier.trainingParam.architectureVersion = 'lineage_only_v1';
classifier.trainingParam.trainingObjective = 'relation_ensemble';
classifier.trainingParam.trackChannelName = 'latent_model_1_cell';

datasetDir = fullfile(classifier.path, 'trainingdataset');
mkdir(datasetDir);
sentinel = fullfile(datasetDir, 'previous_dataset.marker');
touchFile(sentinel);

verifyError(testCase, @() classifier.formatDataForTraining( ...
    'Rois', [1 2], 'Frames', []), ...
    'cellLatentModel:TrainingInputsNotReady');
verifyTrue(testCase, isfile(sentinel), ...
    'Missing ROI inputs must be detected before replacing the dataset.');
end

function testFormattingRejectsAnExistingImmutableModelVersion(testCase)
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() removeFolder(folder)); %#ok<NASGU>
classifier = classi(folder, 'immutable_format_target', 1);
cellLatentModel.setparam(classifier);
classifier.trainingParam.architectureVersion = 'lineage_only_v1';
classifier.trainingParam.trainingObjective = 'relation_ensemble';
classifier.trainingParam.modelName = 'model_cell_latent_composite_v004';
target = fullfile(classifier.path, 'models', ...
    classifier.trainingParam.modelName);
mkdir(target);
sentinel = fullfile(target, 'immutable.marker');
touchFile(sentinel);

verifyError(testCase, @() cellLatentModel.preflightFormat( ...
    classifier, [], struct()), 'cellLatentModel:ImmutableModelExists');
verifyTrue(testCase, isfile(sentinel), ...
    'Preflight must not modify an existing model bundle.');
end

function testManagedStaleApprovalBlocksFormattingBeforeDatasetReset(testCase)
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() removeFolder(folder)); %#ok<NASGU>
classifier = classi(folder, 'managed_stale_preflight', 1);
roi1 = syntheticROI(fullfile(folder, 'roi1'), 'managed_train', 0);
roi2 = syntheticROI(fullfile(folder, 'roi2'), 'managed_validation', 1);
writeReviewedLineage(roi1);
writeReviewedLineage(roi2);
classifier.roi = [roi1 roi2];
classifier.dataset.split.train = 1;
classifier.dataset.split.val = 2;
classifier.dataset.split.test = [];
cellLatentModel.setparam(classifier);
classifier.trainingParam.architectureVersion = 'lineage_only_v1';
classifier.trainingParam.trainingObjective = 'relation_ensemble';
classifier.trainingParam.trackChannelName = 'results_trackastra';
classifier.trainingParam.gfpChannelName = 'ch2-GFP';
classifier.trainingParam.groundTruthFamily = 'Reviewed lineage';
approveManagedGroundTruth(testCase, classifier, 1);
approveManagedGroundTruth(testCase, classifier, 2);

datasetDir = fullfile(classifier.path, 'trainingdataset');
mkdir(datasetDir);
sentinel = fullfile(datasetDir, 'previous_dataset.marker');
touchFile(sentinel);
trackIndex = roi1.findChannelID('results_trackastra', 'exact');
roi1.image(1,1,trackIndex,1) = roi1.image(1,1,trackIndex,1) + 7;
roi1.save({'results_trackastra'}, false);

verifyError(testCase, @() classifier.formatDataForTraining( ...
    'Rois', 1, 'Frames', []), ...
    'cellLatentModel:GroundTruthNotReady');
verifyTrue(testCase, isfile(sentinel), ...
    'A stale approval must be rejected before replacing formatted data.');
end

function testCompositeTrainingRejectsDifferentApprovalThanFormatted(testCase)
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() removeFolder(folder)); %#ok<NASGU>
classifier = classi(folder, 'formatted_approval_gate', 1);
roi1 = syntheticROI(fullfile(folder, 'roi1'), 'snapshot_train', 0);
roi2 = syntheticROI(fullfile(folder, 'roi2'), 'snapshot_validation', 1);
writeReviewedLineage(roi1);
writeReviewedLineage(roi2);
addFrameLocalInstances(roi1);
addFrameLocalInstances(roi2);
classifier.roi = [roi1 roi2];
classifier.dataset.split.train = 1;
classifier.dataset.split.val = 2;
classifier.dataset.split.test = [];
cellLatentModel.setparam(classifier);
classifier.trainingParam.architectureVersion = 'detecdiv_composite_v1';
classifier.trainingParam.instanceChannelName = 'results_cellposeSAM_cell';
classifier.trainingParam.trackChannelName = 'results_trackastra';
classifier.trainingParam.groundTruthFamily = 'Reviewed lineage';
classifier.trainingParam.modelName = 'approval_gate_v001';
approveManagedGroundTruth(testCase, classifier, 1);
approveManagedGroundTruth(testCase, classifier, 2);
approvals = cellLatentModel.assertGroundTruthReady(classifier, [1 2]);
approvals(1).approved_hash = repmat('0', 1, 64);

datasetRoot = fullfile(classifier.path, 'trainingdataset');
mkdir(datasetRoot);
manifestFile = fullfile(datasetRoot, 'composite_dataset_manifest.json');
writeJsonFixture(manifestFile, struct( ...
    'schema_version', 1, ...
    'split', struct('train', 1, 'validation', 2, 'test', []), ...
    'split_roi_ids', struct('train', {{'snapshot_train'}}, ...
        'validation', {{'snapshot_validation'}}, 'test', {{}}), ...
    'annotation_approvals', approvals));
pointerFile = fullfile(datasetRoot, ...
    'latest_cell_latent_composite_dataset.json');
writeJsonFixture(pointerFile, struct('schema_version', 1, ...
    'manifest', manifestFile));

verifyError(testCase, @() cellLatentModel.train(classifier, struct()), ...
    'cellLatentModel:GroundTruthNotReady');
verifyFalse(testCase, isfolder(fullfile( ...
    classifier.path, 'models', 'approval_gate_v001')), ...
    'Training must stop before creating a model bundle.');
end

function testApprovalSnapshotTracksBoundsAndStableRoiIds(testCase)
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() removeFolder(folder)); %#ok<NASGU>
classifier = classi(folder, 'approval_identity_gate', 1);
roi1 = syntheticROI(fullfile(folder, 'roi1'), 'identity_train', 0);
roi2 = syntheticROI(fullfile(folder, 'roi2'), 'identity_validation', 1);
writeReviewedLineage(roi1);
writeReviewedLineage(roi2);
classifier.roi = [roi1 roi2];
classifier.dataset.split.train = 1;
classifier.dataset.split.val = 2;
classifier.dataset.split.test = [];
cellLatentModel.setparam(classifier);
classifier.trainingParam.architectureVersion = 'detecdiv_composite_v1';
classifier.trainingParam.trackChannelName = 'results_trackastra';
classifier.trainingParam.groundTruthFamily = 'Reviewed lineage';
approveManagedGroundTruth(testCase, classifier, 1);
approveManagedGroundTruth(testCase, classifier, 2);
snapshot = cellLatentModel.assertGroundTruthReady(classifier, [1 2]);
verifyEqual(testCase, snapshot(1).frame_bounds, [1 12]);

trainingBounds.setRoi(classifier, 1, '2:6', 'FrameCount', 12);
verifyError(testCase, @() cellLatentModel.assertGroundTruthReady( ...
    classifier, [], 'ExpectedApprovals', snapshot, ...
    'ExpectedRoiIds', {snapshot.roi_id}), ...
    'cellLatentModel:GroundTruthNotReady');

trainingBounds.clearRoi(classifier, 1);
classifier.roi = [roi2 roi1];
current = cellLatentModel.assertGroundTruthReady(classifier, [], ...
    'ExpectedApprovals', snapshot, ...
    'ExpectedRoiIds', {snapshot.roi_id});
verifyEqual(testCase, string({current.roi_id}), ...
    string({snapshot.roi_id}), ...
    'Approval matching must follow stable ROI IDs after a table reorder.');
verifyEqual(testCase, string({current.approved_hash}), ...
    string({snapshot.approved_hash}));
end

function testContinuousClassifierLifecycleUsesTypedMarkers(testCase)
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() removeFolder(folder));
classifier = classi(folder,'continuous_lifecycle',1);
roi1 = syntheticROI(fullfile(folder,'roi1'),'continuous_train',0);
roi2 = syntheticROI(fullfile(folder,'roi2'),'continuous_validation',1);
writeReviewedLineage(roi1);
writeReviewedLineage(roi2);
classifier.roi = [roi1 roi2];
classifier.channelName = {'results_trackastra','ch2-GFP'};
classifier.dataset.split.train = 1;
classifier.dataset.split.val = 2;
classifier.dataset.split.test = [];
cellLatentModel.setparam(classifier);
classifier.trainingParam.architectureVersion = 'lineage_only_v1';
classifier.trainingParam.trainingObjective = 'continuous_lineage';
classifier.trainingParam.trackChannelName = 'results_trackastra';
classifier.trainingParam.nucleusChannelName = 'ch2-GFP';
classifier.trainingParam.groundTruthFamily = 'Reviewed lineage';
classifier.trainingParam.frameIntervalMinutes = 3;
classifier.trainingParam.trainingDomain = 'synthetic_reviewed';
classifier.trainingParam.continuousVariant = 'all_observed';
classifier.trainingParam.decisionLatencyMinutes = 6;
classifier.trainingParam.temporalWindowMinutes = 12;
classifier.trainingParam.temporalSampleStepMinutes = 3;
classifier.trainingParam.continuousStateDim = 8;
classifier.trainingParam.continuousBlockEmbeddingDim = 4;
classifier.trainingParam.continuousAttentionDim = 8;
classifier.trainingParam.maxEventHistoryTokens = 2;
classifier.trainingParam.epochs = 1;
classifier.trainingParam.device = 'cpu';
classifier.trainingParam.modelName = 'continuous_smoke';

formatted = cellLatentModel.format(classifier,1,struct());
verifyEqual(testCase,formatted.status,"OK");
verifyTrue(testCase,isfile(formatted.artifacts.manifest));
manifest = jsondecode(fileread(formatted.artifacts.manifest));
verifyEqual(testCase,manifest.format, ...
    'continuous_cell_observation_collection_v1');
trainingCtx = struct('progress',struct( ...
    'emitConsoleProtocol',true,'localBase',0,'localSpan',1));
trainingConsole = evalc( ...
    'trained = cellLatentModel.train(classifier,trainingCtx);');
verifyEqual(testCase,trained.status,"OK");
verifyTrue(testCase,isfile(trained.artifacts.model));
trainingConfig = jsondecode(fileread(trained.artifacts.config));
verifyEqual(testCase,double( ...
    trainingConfig.training.early_stopping_patience),30);
verifyEqual(testCase,double( ...
    trainingConfig.training.early_stopping_min_delta),0.0001, ...
    'AbsTol',eps);
trainingReport = jsondecode(fileread(trained.artifacts.report));
verifyTrue(testCase,logical( ...
    trainingReport.training.selection_policy.epoch_zero_eligible));
verifyTrue(testCase,logical( ...
    trainingReport.training.selection_policy.restore_best_checkpoint));
verifyGreaterThanOrEqual(testCase,double( ...
    trainingReport.training.best_epoch),0);
verifyTrue(testCase,contains(trainingConsole,'[training] Epoch 1/1:'), ...
    'Python epoch output must be relayed through the MATLAB worker console.');
verifyTrue(testCase,contains(trainingConsole,'@@DETECDIV_PROGRESS@@') && ...
    contains(trainingConsole,'Epoch 1/1:'), ...
    'Python progress must be mapped back into the DetecDiv monitor protocol.');
verifyTrue(testCase,contains(fileread(trained.artifacts.stdout), ...
    '[training] Epoch 1/1:'), ...
    'The live subprocess stream must also be persisted to training stdout.');
verifyEqual(testCase,classifier.executionParam.backend, ...
    'continuous_cell_state');
verifyEqual(testCase,classifier.executionParam.nucleusChannelName, ...
    'ch2-GFP');
verifyFalse(testCase,classifier.executionParam.materializeCellStates);
validated = cellLatentModel.validate(classifier,2,struct());
verifyEqual(testCase,validated.status,"OK");
verifyEqual(testCase,double(validated.metrics.events),3);
verifyEqual(testCase,double(validated.metrics.parent_events),1);
verifyEqual(testCase,double(validated.metrics.null_events),2);
end

function roiobj = syntheticROI(folder,id,offset)
if ~isfolder(folder), mkdir(folder); end
height = 80;
width = 80;
frames = 12;
[xx,yy] = meshgrid(1:width,1:height);
tracks = zeros(height,width,frames,'uint16');
gfp = zeros(height,width,frames,'single');
for frame = 1:frames
    plane = zeros(height,width,'uint16');
    plane(((xx-(32+offset))/10).^2 + ((yy-40)/13).^2 <= 1) = 1;
    plane(((xx-58)/9).^2 + ((yy-40)/12).^2 <= 1) = 2;
    if frame >= 3
        radius = min(8,4+floor((frame-1)/2));
        plane(((xx-(43+offset))/radius).^2 + ...
            ((yy-35)/(radius+1)).^2 <= 1) = 3;
    end
    tracks(:,:,frame) = plane;
    signal = single(0.05*ones(height,width));
    signal((xx-(32+offset)).^2 + (yy-40).^2 <= 16) = ...
        single(1 + 0.05*frame);
    gfp(:,:,frame) = signal;
end
roiobj = roi(id,[1 1 width height]);
roiobj.path = folder;
roiobj.image = zeros(height,width,2,frames,'single');
roiobj.image(:,:,1,:) = single(tracks);
roiobj.image(:,:,2,:) = gfp;
roiobj.channelid = [1 2];
displayState = roiobj.display;
displayState.channel = {'results_trackastra','ch2-GFP'};
displayState.indexed = [true false];
displayState.rgb = [1 1 1; 1 1 1];
roiobj.display = displayState;
end

function writeReviewedLineage(roiobj)
if isempty(roiobj.image),roiobj.load;end
tracks = uint32(squeeze(roiobj.image(:,:,1,:)));
model = cellModel.create(roiobj.id);
result = struct('edges',struct( ...
    'status','linked', ...
    'pred_parent_id',1, ...
    'child_track_id',3, ...
    'bud_appearance_frame',3, ...
    'top_score',1));
[model,~,~] = cellModel.applyLineageResult( ...
    model,tracks,'results_trackastra','<auto>', ...
    'Reviewed lineage',result,true,'manual_review');
roiobj.saveCellModel(model);
end

function writeStableReviewedLineage(roiobj)
tracks = uint32(squeeze(roiobj.image(:,:,1,:)));
roiobj.save([],false);
model = cellModel.create(roiobj.id);
familyId = uint32(7);
model.families.family_id = familyId;
model.families.name = {'Reviewed lineage'};
model.families.mask_provider = {'results_trackastra'};
model.families.lineage_source = {'ground_truth'};
model.families.color_rgb = uint8([99 214 255]);
nextObject = uint64(1);
for frame = 1:size(tracks,3)
    labels = unique(tracks(:,:,frame));
    labels(labels == 0) = [];
    for label = double(labels(:).')
        row = numel(model.instances.object_id) + 1;
        model.instances.object_id(row,1) = nextObject;
        nextObject = nextObject + 1;
        model.instances.family_id(row,1) = familyId;
        model.instances.frame(row,1) = uint32(frame);
        model.instances.mask_label(row,1) = uint32(label);
        if label == 1
            stableTrack = 40;
        elseif label == 2
            stableTrack = 50;
        elseif frame <= 6
            stableTrack = 41;
        else
            stableTrack = 42;
        end
        model.instances.track_id(row,1) = uint64(stableTrack);
        model.instances.state_id(row,1) = uint16(0);
    end
end
model.relations.relation_id = uint64([1;2]);
model.relations.family_id = repmat(familyId,2,1);
model.relations.parent_track_id = uint64([40;40]);
model.relations.child_track_id = uint64([41;42]);
model.relations.event_frame = uint32([3;7]);
model.relations.type_id = uint8([1;1]);
model.relations.confidence = single([1;1]);
roiobj.saveCellModel(model,'KeepBackup',false);
end

function addFrameLocalInstances(roiobj)
instances=uint16(roiobj.image(:,:,1,:));
roiobj.addChannel(instances,'results_cellposeSAM_cell', ...
    [1 1 1],[0 0 0]);
index=roiobj.findChannelID('results_cellposeSAM_cell','exact');
roiobj.display.indexed(index)=true;
roiobj.save([],false);
end

function approveManagedGroundTruth(testCase, classifier, roiIndex)
roiobj = classifier.roi(roiIndex);
spec = annotationManager.specForClassifier(classifier);
annotationManager.markReviewed(roiobj, spec, 'Save', false);
report = annotationManager.validate(roiobj, spec, ...
    'RequireReviewed', true);
verifyTrue(testCase, report.valid, strjoin(cellstr(report.errors), ' '));
entry = annotationManager.recordValidation(roiobj, spec, report, ...
    'Save', false);
verifyEqual(testCase, entry.status, 'approved');
verifyNotEmpty(testCase, entry.approved_hash);
end

function writeJsonFixture(filename, value)
fid = fopen(filename, 'w');
if fid < 0
    error('testCellLatentModel:WriteJsonFailed', ...
        'Cannot create fixture %s.', filename);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fwrite(fid, jsonencode(value, 'PrettyPrint', true), 'char');
end

function value = normalizeTestPath(value)
value = strrep(char(string(value)),'\','/');
end

function value = fixtureFileSha256(filename)
fid = fopen(filename,'r');
if fid < 0
    error('testCellLatentModel:HashReadFailed', ...
        'Cannot read fixture %s.',filename);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
bytes = fread(fid,Inf,'*uint8');
digest = java.security.MessageDigest.getInstance('SHA-256');
hash = typecast(digest.digest(bytes),'uint8');
value = lower(reshape(dec2hex(hash,2).',1,[]));
end

function removeFolder(folder)
if isfolder(folder)
    try rmdir(folder,'s'); catch, end
end
end
