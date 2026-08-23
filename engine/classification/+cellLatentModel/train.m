function out = train(classif,ctx)
%CELLLATENTMODEL.TRAIN Train and package a PyTorch relation ensemble.
if nargin < 2 || isempty(ctx), ctx = struct(); end
if (ischar(ctx) || isstring(ctx)) && ...
        strcmpi(strtrim(char(string(ctx))),'init')
    ctx = struct('mode','init');
end
cellLatentModel.ensureClassMetadata(classif);
out = cellLatentModel.utils.outInitSafe('cellLatentModel.train');
tp = cellLatentModel.utils.defaultTrainingParam();
if isstruct(classif.trainingParam)
    tp = cellLatentModel.utils.applyOverrides(tp,classif.trainingParam);
end
classif.trainingParam = tp;
architecture = trainingChoice(tp.architectureVersion, ...
    'detecdiv_composite_v1');
if strcmp(architecture,'detecdiv_composite_v1')
    tp.instanceChannelName = ...
        cellLatentModel.utils.resolveFrameLocalInstanceChannel( ...
        classif,tp.instanceChannelName,tp.trackChannelName,ctx);
    classif.trainingParam=tp;
end
objective = trainingChoice(tp.trainingObjective,'relation_ensemble');
if strcmp(architecture,'detecdiv_composite_v1') && logical(tp.trainMotherNull)
    objective = 'continuous_lineage';
end
if isempty(classif.executionParam)
    classif.executionParam = ...
        cellLatentModel.utils.defaultExecutionParam();
end
if isfield(ctx,'mode') && strcmpi(char(string(ctx.mode)),'init')
    out.refs.trainingParam = classif.trainingParam;
    out.refs.executionParam = classif.executionParam;
    return;
end
componentCall=false;try componentCall=logical(ctx.componentCall);catch,end
if strcmp(architecture,'detecdiv_composite_v1') && ~componentCall
    out = trainComposite(classif,ctx,tp,out);
    return;
end
if ~componentCall
    cellLatentModel.assertGroundTruthReady( ...
        classif,formattedTrainingRois(classif));
end
out.refs.trainingScope = classifierBinding.logTrainingScope(classif);
if exist('detecdiv_progress','file') == 2
    detecdiv_progress(ctx,0,'Checking formatted latent training dataset...', ...
        'Scope','training');
end
[datasetDir,manifestFile] = resolveFormattedDataset( ...
    classif,objective,ctx);
if ~isfile(manifestFile) || ...
        (strcmp(objective,'relation_ensemble') && ...
         ~isfile(fullfile(datasetDir,'relations.npz')))
    error('cellLatentModel:MissingFormattedDataset', ...
        'Format the imported ROI training set before training.');
end
modelName = safeName(tp.modelName);
modelDir = '';
try modelDir = char(string(ctx.componentOutputDir)); catch, end
if isempty(modelDir),modelDir = fullfile(classif.path,'models',modelName);end
if exist(modelDir,'dir') ~= 7, mkdir(modelDir); end
configFile = fullfile(modelDir,'training_config.json');
stdoutFile = fullfile(modelDir,'training_stdout.txt');
if strcmp(objective,'continuous_lineage')
    modalities = continuousModalities(jsondecode(fileread(manifestFile)));
    cfg = struct( ...
        'schema_version',1, ...
        'dataset_manifest',normalizedPath(manifestFile), ...
        'output_dir',normalizedPath(modelDir), ...
        'variant',trainingChoice(tp.continuousVariant,'all_observed'), ...
        'latency_minutes',nonnegativeScalar( ...
            tp.decisionLatencyMinutes,'decisionLatencyMinutes'), ...
        'training',struct( ...
            'epochs',positiveInteger(tp.epochs,'epochs'), ...
            'learning_rate',positiveScalar( ...
                tp.learningRate,'learningRate'), ...
            'weight_decay',nonnegativeScalar( ...
                tp.weightDecay,'weightDecay'), ...
            'early_stopping_patience',positiveInteger( ...
                tp.motherNullEarlyStoppingPatience, ...
                'motherNullEarlyStoppingPatience'), ...
            'early_stopping_min_delta',nonnegativeScalar( ...
                tp.motherNullEarlyStoppingMinDelta, ...
                'motherNullEarlyStoppingMinDelta'), ...
            'state_dim',positiveInteger( ...
                tp.continuousStateDim,'continuousStateDim'), ...
            'block_embedding_dim',positiveInteger( ...
                tp.continuousBlockEmbeddingDim, ...
                'continuousBlockEmbeddingDim'), ...
            'attention_dim',positiveInteger( ...
                tp.continuousAttentionDim,'continuousAttentionDim'), ...
            'max_event_history_tokens',positiveInteger( ...
                tp.maxEventHistoryTokens,'maxEventHistoryTokens'), ...
            'time_scale_minutes',positiveScalar( ...
                tp.timeScaleMinutes,'timeScaleMinutes'), ...
            'seed',0, ...
            'device',char(string(tp.device)), ...
            'causal_feedback',logical(tp.continuousCausalFeedback)));
    command = 'train-detecdiv-continuous';
    checkpointName = 'continuous_cell_state.pt';
else
    manifest = jsondecode(fileread(manifestFile));
    modalities = availableModalities(manifest);
    cfg = struct( ...
        'schema_version',1, ...
        'dataset',normalizedPath(datasetDir), ...
        'output',normalizedPath(modelDir), ...
        'modalities',{modalities}, ...
        'target_precision',double(tp.targetAutoPrecision), ...
        'training',struct( ...
            'latent_dim',positiveInteger(tp.latentDim,'latentDim'), ...
            'hidden_dim',positiveInteger(tp.hiddenDim,'hiddenDim'), ...
            'dropout',boundedScalar(tp.dropout,0,1,'dropout'), ...
            'epochs',positiveInteger(tp.epochs,'epochs'), ...
            'learning_rate',positiveScalar(tp.learningRate,'learningRate'), ...
            'weight_decay',nonnegativeScalar(tp.weightDecay,'weightDecay'), ...
            'seeds',0:(positiveInteger(tp.seedCount,'seedCount')-1), ...
            'device',char(string(tp.device))));
    command = 'train-from-config';
    checkpointName = 'ensemble.pt';
end
writeJson(configFile,cfg);
detecdiv_check_cancel(ctx,'cellLatentModel before training');
if exist('detecdiv_progress','file') == 2
    detecdiv_progress(ctx,0.01,'Starting latent-model optimization...', ...
        'Scope','training');
end
runtime = cellLatentModel.utils.runPythonModule( ...
    command,configFile,ctx,stdoutFile);
detecdiv_check_cancel(ctx,'cellLatentModel after training');
if exist('detecdiv_progress','file') == 2
    detecdiv_progress(ctx,0.97,'Verifying trained checkpoint...', ...
        'Scope','training');
end
checkpoint = fullfile(modelDir,checkpointName);
reportFile = fullfile(modelDir,'training_report.json');
if ~isfile(checkpoint) || ~isfile(reportFile)
    error('cellLatentModel:TrainingIncomplete', ...
        'Training produced no deployable checkpoint/report.');
end
report = jsondecode(fileread(reportFile));
classif.executionParam = cellLatentModel.utils.applyOverrides( ...
    cellLatentModel.utils.defaultExecutionParam(),classif.executionParam);
classif.executionParam.modelSource = 'trained';
classif.executionParam.modelPath = ...
    classifierRelativePath(classif,checkpoint);
classif.executionParam.trackChannelName = ...
    char(string(tp.trackChannelName));
classif.executionParam.device = char(string(tp.device));
if strcmp(objective,'continuous_lineage')
    classif.executionParam.backend = 'continuous_cell_state';
    classif.executionParam.gfpChannelName = '';
    classif.executionParam.brightfieldChannelName = ...
        char(string(tp.brightfieldChannelName));
    classif.executionParam.nucleusChannelName = ...
        char(string(tp.nucleusChannelName));
    classif.executionParam.budneckChannelName = ...
        char(string(tp.budneckChannelName));
    classif.executionParam.frameIntervalMinutes = ...
        positiveScalar(tp.frameIntervalMinutes,'frameIntervalMinutes');
    classif.executionParam.causalSolverFeedback = ...
        logical(tp.continuousCausalFeedback);
    % This objective trains the lineage head only. A biological checkpoint
    % can later be linked without falsely materializing untrained states.
    classif.executionParam.materializeCellStates = false;
    classif.executionParam.primaryStateAxis = 'none';
else
    classif.executionParam.backend = 'legacy';
    classif.executionParam.gfpChannelName = ...
        char(string(tp.gfpChannelName));
end
embedded=false;try embedded=logical(ctx.embedded);catch,end
if ~embedded
    try classifierPersistTrainingResult(classif); catch ME
        warning('cellLatentModel:ClassifierSaveFailed', ...
            'Checkpoint trained, but classifier metadata was not saved: %s', ...
            ME.message);
    end
end
if exist('detecdiv_progress','file') == 2
    detecdiv_progress(ctx,1,'Latent-model training complete.', ...
        'Scope','training','Status','completed');
end

out.artifacts.dataset = datasetDir;
out.artifacts.model = checkpoint;
out.artifacts.report = reportFile;
out.artifacts.config = configFile;
out.artifacts.stdout = stdoutFile;
if strcmp(objective,'continuous_lineage')
    out.metrics = report.validation;
else
    out.metrics = report.metrics;
end
out.refs.modalities = modalities;
out.refs.executionParam = classif.executionParam;
out.refs.runtime = runtime;
out.status = "OK";
end

function out = trainComposite(classif,ctx,tp,out)
out.refs.trainingScope=classifierBinding.logTrainingScope(classif);
pointerFile=fullfile(classif.path,'trainingdataset', ...
    'latest_cell_latent_composite_dataset.json');
if ~isfile(pointerFile)
    error('cellLatentModel:MissingCompositeDataset', ...
        'Format the composite latent training set before training.');
end
pointer=jsondecode(fileread(pointerFile));
datasetManifest=char(string(pointer.manifest));
if ~isfile(datasetManifest)
    error('cellLatentModel:MissingCompositeDataset', ...
        'The composite dataset manifest no longer exists: %s',datasetManifest);
end
verifyManifestHash(pointer,datasetManifest, ...
    'cellLatentModel:CompositeDatasetChanged');
datasetRecord=jsondecode(fileread(datasetManifest));
datasetRois=[];
datasetRoiIds={};
try
    datasetRois=unique([double(datasetRecord.split.train(:).') ...
        double(datasetRecord.split.validation(:).')],'stable');
catch
end
expectedApprovals=struct([]);
try
    if isstruct(datasetRecord.annotation_approvals)
        expectedApprovals=datasetRecord.annotation_approvals;
    end
catch
end
try
    datasetRoiIds=[textCell(datasetRecord.split_roi_ids.train) ...
        textCell(datasetRecord.split_roi_ids.validation)];
catch
end
if isempty(datasetRoiIds) && ~isempty(expectedApprovals)
    try datasetRoiIds=cellstr(string({expectedApprovals.roi_id}));catch,end
end
if ~isempty(datasetRoiIds)
    % Manifest indices are historical positions. Once stable IDs exist,
    % never inspect whatever ROI happens to occupy those positions now.
    datasetRois=[];
end
cellLatentModel.assertGroundTruthReady(classif,datasetRois, ...
    'ExpectedApprovals',expectedApprovals, ...
    'ExpectedRoiIds',datasetRoiIds);
bundleName=safeName(tp.modelName);
bundleDir=fullfile(classif.path,'models',bundleName);
if isfolder(bundleDir)||isfile(bundleDir)
    error('cellLatentModel:ImmutableModelExists', ...
        ['Composite model version "%s" already exists and will not be ' ...
         'overwritten. Choose a new vNNN modelName.'],bundleName);
end
stagingDir=[bundleDir '.partial_' char(java.util.UUID.randomUUID)];
mkdir(stagingDir);
stageCleanup=onCleanup(@()removeFolder(stagingDir));
originalTraining=classif.trainingParam;
originalExecution=classif.executionParam;
rollbackState=containers.Map({'armed'},{true});
restore=onCleanup(@()restoreClassifierIfArmed( ...
    classif,originalTraining,originalExecution,rollbackState));
components=struct(); artifacts=struct(); metrics=struct();
componentCount=double(logical(tp.trainTrackingActions))+ ...
    double(logical(tp.trainMotherNull));
componentIndex=0;

if logical(tp.trainTrackingActions)
    componentIndex=componentIndex+1;
    trackerParams=cellLatentModel.trackerTrainingParams(tp);
    trackerParams.modelName=[bundleName '_tracking'];
    proxy=struct('path',classif.path,'strid',classif.strid, ...
        'roi',classif.roi,'dataset',classif.dataset, ...
        'trainingset',classif.trainingset,'bounds',classif.bounds, ...
        'classifierPkg','cellLatentTracker', ...
        'trainingFun','cellLatentTracker.train', ...
        'classifyFun','cellLatentTracker.classify', ...
        'trainingParam',trackerParams, ...
        'executionParam',cellLatentTracker.utils.defaultExecutionParam());
    trackerCtx=ctx;
    trackerCtx.trainingParam=trackerParams;
    trackerCtx.datasetManifest=componentManifest( ...
        datasetRecord,'tracking');
    trackerCtx.outputDir=fullfile(stagingDir,'tracking');
    trackerCtx.runDir=fullfile(stagingDir,'runs','tracking');
    trackerCtx.embedded=true;
    trackerCtx.progress=componentProgress( ...
        ctx,(componentIndex-1)*0.9/componentCount,0.9/componentCount);
    tracking=cellLatentTracker.train(proxy,trackerCtx);
    components.tracking=trainedComponent( ...
        'EDGE_APPEAR_END',tracking.artifacts.checkpoint, ...
        tracking.artifacts.report,tracking.refs.promotion);
    artifacts.trackingCheckpoint=tracking.artifacts.checkpoint;
    artifacts.trackingReport=tracking.artifacts.report;
    metrics.tracking=tracking.metrics;
end

if logical(tp.trainMotherNull)
    componentIndex=componentIndex+1;
    lineageTp=tp;
    lineageTp.architectureVersion='lineage_only_v1';
    lineageTp.trainingObjective='continuous_lineage';
    lineageTp.trainTrackingActions=false;
    classif.trainingParam=lineageTp;
    lineageCtx=ctx;
    lineageCtx.componentCall=true;
    lineageCtx.datasetManifest=componentManifest( ...
        datasetRecord,'lineage');
    lineageCtx.embedded=true;
    lineageCtx.componentOutputDir=fullfile(stagingDir,'lineage');
    lineageCtx.progress=componentProgress( ...
        ctx,(componentIndex-1)*0.9/componentCount,0.9/componentCount);
    lineage=cellLatentModel.train(classif,lineageCtx);
    components.lineage=trainedComponent( ...
        'mother_NULL',lineage.artifacts.model, ...
        lineage.artifacts.report,lineageSelection( ...
        lineage.artifacts.report));
    artifacts.lineageCheckpoint=lineage.artifacts.model;
    artifacts.lineageReport=lineage.artifacts.report;
    metrics.lineage=lineage.metrics;
end

stateMode=trainingChoice(tp.stateUpdateMode,'promoted_frozen_bf');
stateRuntime='';
if strcmp(stateMode,'promoted_frozen_bf')
    runtime=cellLatentModel.utils.resolvePythonRuntime(ctx);
    candidate=fullfile(runtime.repositoryRoot,'artifacts', ...
        'cell_latent_scene_runtime_v001','runtime_config.json');
    if ~isfile(candidate)
        error('cellLatentModel:MissingPromotedStateRuntime', ...
            ['The promoted biological-state scene runtime is unavailable: ' ...
             '%s'],candidate);
    end
    stateRuntime=candidate;
end
components.biological_state=frozenStateComponent(stateMode,stateRuntime);
bundleManifest=fullfile(bundleDir,'manifest.json');
[ok,message]=movefile(stagingDir,bundleDir);
if ~ok
    error('cellLatentModel:BundleFinalizeFailed', ...
        'Cannot finalize composite model bundle: %s',message);
end
clear stageCleanup;
bundleCleanup=onCleanup(@()removeUnpublishedBundle( ...
    bundleDir,bundleManifest)); %#ok<NASGU>
[textRelocation]=cellLatentModel.utils.relocateTextArtifacts( ...
    bundleDir,stagingDir,bundleDir);
[components,componentRelocation]=cellLatentModel.utils.relocatePathTree( ...
    components,stagingDir,bundleDir);
[artifacts,artifactRelocation]=cellLatentModel.utils.relocatePathTree( ...
    artifacts,stagingDir,bundleDir);
components=refreshComponentHashes(components);
[~,postRelocationCheck]=cellLatentModel.utils.relocatePathTree( ...
    struct('components',components,'artifacts',artifacts), ...
    stagingDir,bundleDir);
relocationAudit=struct( ...
    'schema_version',1, ...
    'target_root',normalizedPath(bundleDir), ...
    'checked_value_count',componentRelocation.checked_value_count+ ...
        artifactRelocation.checked_value_count, ...
    'checked_text_file_count',textRelocation.checked_file_count, ...
    'rewritten_text_file_count',textRelocation.rewritten_file_count, ...
    'relocated_path_count',componentRelocation.relocated_path_count+ ...
        artifactRelocation.relocated_path_count+ ...
        textRelocation.relocated_path_count, ...
    'expected_minimum_relocated_paths',4*componentCount, ...
    'source_paths_remaining',postRelocationCheck.relocated_path_count+ ...
        textRelocation.source_paths_remaining, ...
    'verified_no_transient_paths', ...
        postRelocationCheck.relocated_path_count==0&& ...
        textRelocation.verified_no_transient_paths);
if relocationAudit.relocated_path_count < ...
        relocationAudit.expected_minimum_relocated_paths
    error('cellLatentModel:BundlePathRelocationIncomplete', ...
        ['Composite bundle finalization rewrote only %d path(s), while ' ...
         'at least %d component/artifact path(s) were expected.'], ...
        relocationAudit.relocated_path_count, ...
        relocationAudit.expected_minimum_relocated_paths);
end

if ~relocationAudit.verified_no_transient_paths
    error('cellLatentModel:BundlePathRelocationFailed', ...
        ['Composite bundle finalization left %d path(s) pointing to its ' ...
         'transient staging directory.'], ...
        relocationAudit.source_paths_remaining);
end
snapshotRuntime=cellLatentModel.utils.resolvePythonRuntime(ctx);
codeSnapshot=cellLatentModel.utils.snapshotTrainingCode( ...
    bundleDir,snapshotRuntime);
classif.trainingParam=tp;
scope=classifierBinding.trainingScopeSpec(classif);
supersedes=previousCompositeModel(classif,bundleManifest);
payload=struct( ...
    'schema_version',1, ...
    'format','detecdiv_cell_latent_composite_model_v1', ...
    'created_at',cellLatentModel.utils.utcIso8601(), ...
    'architecture','detecdiv_composite_v1', ...
    'classifier_id',char(string(classif.strid)), ...
    'supersedes',supersedes, ...
    'dataset_manifest',normalizedPath(datasetManifest), ...
    'dataset_manifest_sha256',fileSha256(datasetManifest), ...
    'components',components, ...
    'model_selection',componentSelections(components), ...
    'code_snapshot',codeSnapshot, ...
    'packaging',struct('path_relocation',relocationAudit), ...
    'training_scope',scope, ...
    'inference_order',{{'tracking','mother_NULL','biological_state'}}, ...
    'targets_consumed_at_inference',false);
writeJsonAtomic(bundleManifest,payload);

p=cellLatentModel.utils.defaultExecutionParam();
p.backend='causal_composite';
p.instanceChannelName=cellLatentModel.utils.resolveFrameLocalInstanceChannel( ...
    classif,tp.instanceChannelName,tp.trackChannelName,ctx);
if isempty(p.instanceChannelName)
    error('cellLatentModel:MissingInstanceChannel', ...
        ['Composite inference needs a frame-local segmentation input. ' ...
         'Reviewed GT identities cannot be persisted as that input.']);
end
p.brightfieldChannelName=textValue(tp.brightfieldChannelName);
p.nucleusChannelName=textValue(tp.nucleusChannelName);
p.budneckChannelName=textValue(tp.budneckChannelName);
p.frameIntervalMinutes=double(tp.frameIntervalMinutes);
p.causalSolverFeedback=logical(tp.continuousCausalFeedback);
p.outputTrackChannelName=['pred_' safeName(classif.strid) '_tracks'];
p.outputFamilyName=['pred_' safeName(classif.strid) '_lineage'];
p.compositeManifestPath=classifierRelativePath(classif,bundleManifest);
p.stateUpdateMode=stateMode;
p.stateRuntimeConfigPath=classifierRelativePath(classif,stateRuntime);
p.trackingTopK=double(tp.trackingTopK);
p.materializeCellStates=strcmp(stateMode,'promoted_frozen_bf');
if p.materializeCellStates
    p.primaryStateAxis='budding';
else
    p.primaryStateAxis='none';
end
p.device=textValue(tp.device);
if isfield(artifacts,'trackingCheckpoint')
    p.trackingCheckpointDir=classifierRelativePath( ...
        classif,artifacts.trackingCheckpoint);
end
if isfield(artifacts,'lineageCheckpoint')
    p.modelSource='trained';
    p.modelPath=classifierRelativePath(classif,artifacts.lineageCheckpoint);
end
classif.trainingParam=tp;
classif.executionParam=p;
cellLatentModel.ensureClassMetadata(classif);
classifierPersistTrainingResult(classif);
% Keep the pre-training parameters armed as a rollback until both the
% authoritative classifier MAT and its execution-defaults sidecar have
% been persisted successfully.  Clearing this guard earlier left a failed
% training call pointing at the unpublished model in memory.
rollbackState('armed')=false;
clear restore;
if exist('detecdiv_progress','file')==2
    detecdiv_progress(ctx,1,'Composite latent-model bundle complete.', ...
        'Scope','training','Status','completed');
end
out.status="OK";
out.artifacts=artifacts;
out.artifacts.bundle=bundleDir;
out.artifacts.manifest=bundleManifest;
out.artifacts.dataset=datasetManifest;
out.metrics=metrics;
out.refs.trainingScope=scope;
out.refs.executionParam=p;
end

function row=trainedComponent(name,checkpoint,report,selection)
row=struct('component',name,'status','trained', ...
    'checkpoint',normalizedPath(checkpoint), ...
    'checkpoint_sha256',artifactSha256(checkpoint), ...
    'report',normalizedPath(report), ...
    'report_sha256',fileSha256(report), ...
    'selection',selection);
end

function selection=lineageSelection(reportFile)
% Propagate the deployable lineage checkpoint decision into the composite
% manifest.  The component report remains the detailed source of truth,
% while this compact record makes the selected epoch/policy discoverable
% without opening a nested artifact.
selection=struct('selected_epoch',[],'best_validation_nll',[], ...
    'selection_policy',struct(),'stopped_early',false, ...
    'stop_epoch',[],'stop_reason','', ...
    'calibration',struct(),'validation',struct());
try
    report=jsondecode(fileread(reportFile));
    training=report.training;
    if isfield(training,'best_epoch')
        selection.selected_epoch=double(training.best_epoch);
    end
    if isfield(training,'best_validation_nll')
        selection.best_validation_nll=double( ...
            training.best_validation_nll);
    end
    if isfield(training,'selection_policy')
        selection.selection_policy=training.selection_policy;
    end
    if isfield(training,'stopped_early')
        selection.stopped_early=logical(training.stopped_early);
    end
    if isfield(training,'stop_epoch')
        selection.stop_epoch=double(training.stop_epoch);
    end
    if isfield(training,'stop_reason')
        rawReason=training.stop_reason;
        if ischar(rawReason)
            selection.stop_reason=strtrim(rawReason);
        elseif isstring(rawReason)&&isscalar(rawReason)&&~ismissing(rawReason)
            selection.stop_reason=strtrim(char(rawReason));
        end
    end
    if isfield(report,'calibration')
        selection.calibration=report.calibration;
    end
    if isfield(report,'validation')
        selection.validation=report.validation;
    end
catch ME
    error('cellLatentModel:InvalidLineageTrainingReport', ...
        'Cannot propagate lineage checkpoint selection from %s: %s', ...
        reportFile,ME.message);
end
end

function selections=componentSelections(components)
selections=struct();
names=fieldnames(components);
for index=1:numel(names)
    record=components.(names{index});
    if isfield(record,'selection')
        selections.(names{index})=record.selection;
    end
end
end

function components=refreshComponentHashes(components)
names=fieldnames(components);
for index=1:numel(names)
    name=names{index};
    record=components.(name);
    if isfield(record,'checkpoint')&&~isempty(record.checkpoint)
        record.checkpoint_sha256=artifactSha256(record.checkpoint);
    end
    if isfield(record,'report')&&~isempty(record.report)&& ...
            isfile(record.report)
        record.report_sha256=fileSha256(record.report);
    end
    components.(name)=record;
end
end

function row=frozenStateComponent(mode,runtimeConfig)
row=struct('component','biological_state','status','disabled', ...
    'source',mode,'runtime_config','','runtime_config_sha256','');
if strcmp(mode,'promoted_frozen_bf')
    row.status='frozen_promoted';
    row.runtime_config=normalizedPath(runtimeConfig);
    if ~isempty(runtimeConfig)&&isfile(runtimeConfig)
        row.runtime_config_sha256=fileSha256(runtimeConfig);
    end
end
end

function value=artifactSha256(path)
if isfolder(path)
    manifest=fullfile(path,'manifest.json');
    if isfile(manifest),value=fileSha256(manifest);else,value='';end
elseif isfile(path)
    value=fileSha256(path);
else
    value='';
end
end

function restoreClassifier(classif,tp,execution)
try classif.trainingParam=tp;catch,end
try classif.executionParam=execution;catch,end
end

function restoreClassifierIfArmed(classif,tp,execution,state)
armed=true;
try armed=logical(state('armed'));catch,end
if armed,restoreClassifier(classif,tp,execution);end
end

function values=formattedTrainingRois(classif)
% Prefer the ROI identities frozen by the formatter over a later GUI split.
values=[];
configFile=fullfile(classif.path,'trainingdataset','format_config.json');
try
    objective=trainingChoice(classif.trainingParam.trainingObjective, ...
        'relation_ensemble');
    pointerFile=fullfile(classif.path,'trainingdataset', ...
        formattedPointerName(objective));
    if isfile(pointerFile)
        pointer=jsondecode(fileread(pointerFile));
        if isfield(pointer,'config') && isfile(char(string(pointer.config)))
            configFile=char(string(pointer.config));
        end
    end
catch
end
if isfile(configFile)
    try
        config=jsondecode(fileread(configFile));
        ids=string({config.rois.roi_id});
        currentIds=string(arrayfun(@(x)char(string(x.id)),classif.roi, ...
            'UniformOutput',false));
        for i=1:numel(ids)
            match=find(currentIds==ids(i),1,'first');
            if ~isempty(match),values(end+1)=match;end %#ok<AGROW>
        end
        values=unique(values,'stable');
    catch
        values=[];
    end
end
if ~isempty(values),return;end
try
    values=unique([double(classif.dataset.split.train(:).') ...
        double(classif.dataset.split.val(:).')],'stable');
    values=setdiff(values,double(classif.dataset.split.test(:).'),'stable');
catch
    try values=double(classif.trainingset(:).');catch,values=[];end
end
values=values(isfinite(values)&values>=1&values<=numel(classif.roi));
end

function [datasetDir,manifestFile]=resolveFormattedDataset( ...
        classif,objective,ctx)
manifestFile='';
try manifestFile=textValue(ctx.datasetManifest);catch,end
if isempty(manifestFile)
    pointerFile=fullfile(classif.path,'trainingdataset', ...
        formattedPointerName(objective));
    if isfile(pointerFile)
        pointer=jsondecode(fileread(pointerFile));
        manifestFile=textValue(pointer.manifest);
        if ~isfile(manifestFile)
            error('cellLatentModel:MissingFormattedDataset', ...
                'The formatted dataset manifest no longer exists: %s', ...
                manifestFile);
        end
        verifyManifestHash(pointer,manifestFile, ...
            'cellLatentModel:FormattedDatasetChanged');
    end
end
if isempty(manifestFile)
    % Read-only compatibility for datasets created before run-scoped
    % formatting was introduced.
    if strcmp(objective,'continuous_lineage')
        datasetDir=fullfile(classif.path,'trainingdataset', ...
            'continuous_dataset');
    else
        datasetDir=fullfile(classif.path,'trainingdataset', ...
            'relation_dataset');
    end
    manifestFile=fullfile(datasetDir,'manifest.json');
else
    datasetDir=fileparts(manifestFile);
end
end

function name=formattedPointerName(objective)
if strcmp(objective,'continuous_lineage')
    name='latest_cell_latent_continuous_dataset.json';
else
    name='latest_cell_latent_relation_dataset.json';
end
end

function manifestFile=componentManifest(datasetRecord,name)
if ~isfield(datasetRecord,'components') || ...
        ~isfield(datasetRecord.components,name)
    error('cellLatentModel:MissingCompositeComponent', ...
        'The composite dataset has no %s component.',name);
end
record=datasetRecord.components.(name);
manifestFile=textValue(record.manifest);
if isempty(manifestFile)||~isfile(manifestFile)
    error('cellLatentModel:MissingCompositeComponent', ...
        'The composite %s manifest no longer exists: %s', ...
        name,manifestFile);
end
verifyManifestHash(record,manifestFile, ...
    'cellLatentModel:CompositeComponentChanged');
end

function verifyManifestHash(record,manifestFile,errorId)
expected='';
try expected=lower(textValue(record.manifest_sha256));catch,end
if isempty(expected),return;end
actual=fileSha256(manifestFile);
if ~strcmpi(actual,expected)
    error(errorId, ...
        ['Immutable formatted dataset manifest changed after publication: ' ...
         '%s'],manifestFile);
end
end

function values=textCell(raw)
if isempty(raw)
    values={};
elseif ischar(raw)||isstring(raw)
    values=cellstr(string(raw));
elseif iscell(raw)
    values=cellfun(@(x)char(string(x)),raw(:).', ...
        'UniformOutput',false);
else
    values={};
end
values=values(~cellfun(@isempty,values));
end

function modalities = continuousModalities(manifest)
modalities = {'geometry'};
try
    sequences = manifest.sequences;
    names = {};
    for i = 1:numel(sequences)
        names = [names cellstr(string(sequences(i).observation_blocks))']; %#ok<AGROW>
    end
    names = unique(names,'stable');
    if any(strcmp(names,'brightfield_summary'))
        modalities{end+1} = 'brightfield';
    end
    if any(strcmp(names,'nucleus_summary'))
        modalities{end+1} = 'nucleus';
    end
    if any(strcmp(names,'budneck_summary'))
        modalities{end+1} = 'budneck';
    end
catch
end
end

function modalities = availableModalities(manifest)
modalities = {'geometry'};
blocks = manifest.feature_blocks;
for i = 1:numel(blocks)
    name = char(string(blocks(i).name));
    count = double(blocks(i).available_rows);
    if count <= 0, continue; end
    if strcmp(name,'gfp_axis'), modalities{end+1} = 'gfp_axis'; end %#ok<AGROW>
    if strcmp(name,'gfp_brightness')
        modalities{end+1} = 'gfp_brightness'; %#ok<AGROW>
    end
end
end

function value = positiveScalar(raw,name)
value = double(raw);
if ~isscalar(value) || ~isfinite(value) || value <= 0
    error('cellLatentModel:InvalidTrainingParameter', ...
        '%s must be positive.',name);
end
end
function value = positiveInteger(raw,name)
value = round(positiveScalar(raw,name));
end
function value = nonnegativeScalar(raw,name)
value = double(raw);
if ~isscalar(value) || ~isfinite(value) || value < 0
    error('cellLatentModel:InvalidTrainingParameter', ...
        '%s must be non-negative.',name);
end
end
function value = boundedScalar(raw,low,high,name)
value = double(raw);
if ~isscalar(value) || ~isfinite(value) || value < low || value >= high
    error('cellLatentModel:InvalidTrainingParameter', ...
        '%s must be in [%g,%g).',name,low,high);
end
end
function value = safeName(raw)
value = regexprep(char(string(raw)),'[^A-Za-z0-9_.-]','_');
if isempty(value), value = 'cell_latent_relation_v001'; end
end
function value = trainingChoice(raw,fallback)
while iscell(raw)
    if isempty(raw), raw = fallback; else, raw = raw{end}; end
end
value = lower(strtrim(char(string(raw))));
if isempty(value), value = fallback; end
end
function writeJson(filename,value)
fid = fopen(filename,'w');
if fid < 0, error('cellLatentModel:ConfigWriteFailed','Cannot write %s.',filename); end
cleanup = onCleanup(@() fclose(fid));
encoded=jsonencode(value,'PrettyPrint',true);
written=fwrite(fid,encoded,'char');
if written~=numel(encoded)
    error('cellLatentModel:ConfigWriteFailed', ...
        'Incomplete JSON write for %s (%d/%d characters).', ...
        filename,written,numel(encoded));
end
end
function writeJsonAtomic(filename,value)
temporary=[filename '.tmp_' char(java.util.UUID.randomUUID)];
cleanup=onCleanup(@()deleteIfPresent(temporary));
writeJson(temporary,value);
[ok,message]=movefile(temporary,filename,'f');
if ~ok
    error('cellLatentModel:ManifestPublishFailed', ...
        'Cannot publish model manifest %s: %s',filename,message);
end
clear cleanup;
end
function deleteIfPresent(filename)
if isfile(filename),try delete(filename);catch,end,end
end
function value = normalizedPath(value)
value = strrep(char(string(value)),'\','/');
end
function value = classifierRelativePath(classif,value)
value=char(string(value));
try
    root=normalizedPath(classif.path);
    root=regexprep(root,'/+$','');
    candidate=normalizedPath(value);
    windowsRoot=~isempty(regexp(root,'^[A-Za-z]:/','once'))|| ...
        startsWith(root,'//');
    if windowsRoot
        sameRoot=strcmpi(candidate,root);
        belowRoot=startsWith(candidate,[root '/'],'IgnoreCase',true);
    else
        sameRoot=strcmp(candidate,root);
        belowRoot=startsWith(candidate,[root '/']);
    end
    if sameRoot
        value='';
    elseif belowRoot
        value=candidate(numel(root)+2:end);
    end
catch
end
end

function record=previousCompositeModel(classif,currentManifest)
record=struct('manifest','','manifest_sha256','');
candidate='';
try candidate=textValue(classif.executionParam.compositeManifestPath);catch,end
if isempty(candidate),return;end
if ~isfile(candidate)
    candidate=fullfile(char(string(classif.path)),candidate);
end
if ~isfile(candidate)||strcmpi(normalizedPath(candidate), ...
        normalizedPath(currentManifest))
    return;
end
record.manifest=normalizedPath(candidate);
record.manifest_sha256=fileSha256(candidate);
end
function value = textValue(value)
while iscell(value)
    if isempty(value),value='';return;else,value=value{end};end
end
value=strtrim(char(string(value)));
end
function value = fileSha256(filename)
filename=char(string(filename));
if isempty(filename)||~isfile(filename),value='';return;end
fid=fopen(filename,'r');if fid<0,value='';return;end
cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
bytes=fread(fid,Inf,'*uint8');
digest=java.security.MessageDigest.getInstance('SHA-256');
hash=typecast(digest.digest(bytes),'uint8');
value=lower(reshape(dec2hex(hash,2).',1,[]));
end

function removeFolder(folder)
folder=char(string(folder));
if isempty(folder)||~isfolder(folder),return;end
try rmdir(folder,'s');catch,end
end

function removeUnpublishedBundle(bundleDir,manifestFile)
if isfile(manifestFile),return;end
removeFolder(bundleDir);
end

function progress=componentProgress(ctx,localBase,localSpan)
progress=struct();
try if isstruct(ctx.progress),progress=ctx.progress;end;catch,end
parentBase=0;parentSpan=1;
if isfield(progress,'localBase'),parentBase=double(progress.localBase);end
if isfield(progress,'localSpan'),parentSpan=double(progress.localSpan);end
progress.localBase=parentBase+parentSpan*double(localBase);
progress.localSpan=parentSpan*double(localSpan);
end
