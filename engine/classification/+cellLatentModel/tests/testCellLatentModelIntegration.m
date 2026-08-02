function tests = testCellLatentModelIntegration
%TESTCELLLATENTMODELINTEGRATION Exercise Python inference and training.
tests = functiontests(localfunctions);
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
verifyEmpty(testCase,dataout);
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
    model.families.lineage_source{familyIndex},'cellLatentModel');
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

verifyEmpty(testCase,dataout);
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
    model.families.lineage_source{familyIndex},'cellLatentModel');
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
verifyFalse(testCase,isfield(param,'packagePath'));
verifyFalse(testCase,isfield(param,'modelPackage'));
end

function testNormalizeDropsObsoleteRuntimePaths(testCase)
param = cellLatentModel.utils.defaultExecutionParam();
param.trackChannelName = 'results_trackastra';
param.pythonExecutable = 'forbidden-python';
param.repositoryRoot = 'forbidden-repository';
param.packagePath = 'forbidden-package';
param.modelPackage = 'forbidden-model-package';
param.cellLatentRepository = 'forbidden-latent-repository';

resolved = cellLatentModel.normalizeParam(param);

obsolete = {'pythonExecutable','repositoryRoot','packagePath', ...
    'modelPackage','cellLatentRepository'};
verifyFalse(testCase,any(isfield(resolved,obsolete)));
end

function testTemporalExecutionSpecDeclaresTypedRoles(testCase)
spec = cellLatentModel.executionSpec();

verifyEqual(testCase,spec.inputKeys, ...
    {'trackChannelName','gfpChannelName', ...
     'brightfieldChannelName','nucleusChannelName','budneckChannelName'});
verifyEqual(testCase,spec.choices.backend, ...
    {'legacy','temporal_lineage','continuous_cell_state'});
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
privatePathKeys = {'pythonExecutable','repositoryRoot','packagePath', ...
    'modelPackage','cellLatentRepository'};
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
classifier.trainingParam.trackChannelName = 'results_trackastra';
classifier.trainingParam.gfpChannelName = 'ch2-GFP';
classifier.trainingParam.groundTruthFamily = 'Reviewed lineage';
classifier.trainingParam.epochs = 2;
classifier.trainingParam.seedCount = 1;
classifier.trainingParam.device = 'cpu';

formatted = cellLatentModel.format(classifier,1,struct());
verifyEqual(testCase,formatted.status,"OK");
verifyTrue(testCase,isfile(formatted.artifacts.manifest));
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

function removeFolder(folder)
if isfolder(folder)
    try rmdir(folder,'s'); catch, end
end
end
