function [paramout,dataout,imageout] = core(param,roiobj,ctx,classif)
%CELLLATENTMODEL.CORE Infer relations and update the canonical cell model.
if nargin < 3, ctx = struct(); end
if nargin < 4, classif = []; end
paramout = cellLatentModel.normalizeParam(param,ctx,classif);
if isempty(roiobj.image), roiobj.load; end
trackChannelName = paramout.trackChannelName;
trackingRefs = struct();
compositeImage = [];
if strcmp(paramout.backend,'causal_composite')
    trackerParam = cellLatentTracker.utils.defaultExecutionParam();
    trackerParam.instanceChannelName = paramout.instanceChannelName;
    trackerParam.imageChannelName = paramout.brightfieldChannelName;
    trackerParam.checkpointDir = paramout.trackingCheckpointDir;
    trackerParam.topK = paramout.trackingTopK;
    trackerParam.frameIntervalMinutes = paramout.frameIntervalMinutes;
    trackerParam.device = paramout.device;
    trackerParam.solverTimeLimitSeconds = ...
        paramout.trackingSolverTimeLimitSeconds;
    trackerCtx = fullRoiContext(ctx);
    [tracks,frames,trackingRefs] = cellLatentTracker.inferStack( ...
        roiobj,classif,trackerParam,trackerCtx);
    if ~isequal(frames,1:size(roiobj.image,4))
        error('cellLatentModel:CompositeRequiresFullROI', ...
            'Composite tracking must run on the complete ROI time interval.');
    end
    trackChannelName = physicalTrackChannel( ...
        paramout.outputTrackChannelName);
    [compositeImage,trackChannelName] = ...
        cellLatentModel.utils.materializeTracks( ...
        roiobj,tracks,trackChannelName,frames);
    paramout.trackChannelName = trackChannelName;
else
    [tracks,~] = channelStack(roiobj,trackChannelName,true);
end
observations = struct( ...
    'gfp',[],'brightfield',[],'nucleus',[],'budneck',[]);
switch paramout.backend
    case 'legacy'
        if ~isempty(paramout.gfpChannelName)
            [observations.gfp,~] = channelStack( ...
                roiobj,paramout.gfpChannelName,false);
        end
    case 'temporal_lineage'
        if ~isempty(paramout.nucleusChannelName)
            [observations.nucleus,~] = channelStack( ...
                roiobj,paramout.nucleusChannelName,false);
        end
        if ~isempty(paramout.budneckChannelName)
            [observations.budneck,~] = channelStack( ...
                roiobj,paramout.budneckChannelName,false);
        end
    case {'continuous_cell_state','causal_composite'}
        if ~isempty(paramout.brightfieldChannelName)
            [observations.brightfield,~] = channelStack( ...
                roiobj,paramout.brightfieldChannelName,false);
        end
        if ~isempty(paramout.nucleusChannelName)
            [observations.nucleus,~] = channelStack( ...
                roiobj,paramout.nucleusChannelName,false);
        end
        if ~isempty(paramout.budneckChannelName)
            [observations.budneck,~] = channelStack( ...
                roiobj,paramout.budneckChannelName,false);
        end
end
auditFile = resolveAuditFile(roiobj,paramout.outputFamilyName,ctx);
if ~isfolder(fileparts(auditFile)), mkdir(fileparts(auditFile)); end
if exist('detecdiv_progress','file') == 2
    detecdiv_progress(ctx,0,'Running multimodal lineage inference...', ...
        'Scope','event','Indeterminate',true);
end
if strcmp(paramout.backend,'causal_composite')
    lineageParam = paramout;
    if ~isempty(paramout.sceneParentRuntimeManifestPath)
        lineageParam.backend = 'scene_parent_v54';
    else
        lineageParam.backend = 'continuous_cell_state';
    end
    lineageParam.trackChannelName = trackChannelName;
    lineageParam.modelSource = 'trained';
    lineageParam.materializeCellStates = false;
    lineageParam.primaryStateAxis = 'none';
    result = cellLatentModel.infer( ...
        tracks,observations,lineageParam,char(string(roiobj.id)),ctx);
    stateRefs = struct();
    if strcmp(paramout.stateUpdateMode,'promoted_frozen_bf')
        [result.biological_state,stateRefs] = ...
            cellLatentModel.inferFrozenBiologicalState( ...
                tracks,observations,paramout, ...
                char(string(roiobj.id)),ctx);
    end
    result.backend = 'causal_composite';
    result.composite = struct( ...
        'manifest',paramout.compositeManifestPath, ...
        'tracking',trackingRefs, ...
        'biological_state',stateRefs, ...
        'targets_consumed_at_inference',false);
else
    result = cellLatentModel.infer( ...
        tracks,observations,paramout,char(string(roiobj.id)),ctx);
end
writeJsonAtomic(auditFile,result);
[model,loadReport] = roiobj.loadCellModel('MigrateLegacy',true);
[model,familyId,applyReport] = cellModel.applyLineageResult( ...
    model,tracks,trackChannelName,paramout.inputFamily, ...
    paramout.outputFamilyName,result,paramout.overwriteOutputFamily, ...
    'pred:cellLatentModel');
stateReport = struct('filename',"",'records',0,'schema_version',0);
materializationReport = struct('enabled',false,'axis','none');
if any(strcmp(paramout.backend, ...
        {'continuous_cell_state','causal_composite'})) && ...
        (~strcmp(paramout.backend,'causal_composite') || ...
         ~strcmp(paramout.stateUpdateMode,'none')) && ...
        isfield(result,'biological_state') && ...
        isstruct(result.biological_state) && ...
        isfield(result.biological_state,'records')
    stateReport = cellLatentModel.persistBiologicalState( ...
        roiobj,familyId,paramout.outputFamilyName, ...
        trackChannelName,result,auditFile);
    model.provenance.last_biological_state_artifact = ...
        char(stateReport.filename);
    model.provenance.last_biological_state_family_id = double(familyId);
    model.provenance.last_biological_state_schema_version = ...
        double(stateReport.schema_version);
    [model,materializationReport] = ...
        cellLatentModel.applyBiologicalState( ...
            model,familyId,result,paramout);
    model.provenance.last_primary_state_axis = ...
        char(materializationReport.axis);
end
model.provenance.last_classifier = 'pred:cellLatentModel';
model.provenance.last_audit_artifact = auditFile;
model.provenance.last_processor_version = '0.1.0';
saveReport = roiobj.saveCellModel(model);
legacyReport = cellLatentModel.publishLegacyLineage( ...
    roiobj,model,familyId,paramout.outputFamilyName, ...
    trackChannelName,auditFile);
if exist('detecdiv_progress','file') == 2
    detecdiv_progress(ctx,1,'Latent lineage saved.', ...
        'Scope','integration');
end
paramout.outputFamilyId = double(familyId);
paramout.auditFile = auditFile;
paramout.cellModelFile = char(saveReport.filename);
paramout.biologicalStateFile = char(stateReport.filename);
paramout.artifacts = {auditFile,char(saveReport.filename)};
if strlength(stateReport.filename) > 0
    paramout.artifacts{end+1} = char(stateReport.filename);
end
paramout.summary = result.summary;
% Keep the structured backend result available to callers such as the
% end-to-end validator.  The regular audit remains the persisted record.
paramout.prediction = result;
paramout.runtime = struct( ...
    'backend',paramout.backend, ...
    'package','cell_latent_model', ...
    'model_source',paramout.modelSource, ...
    'model',paramout.modelPath, ...
    'variant',paramout.temporalVariant, ...
    'gfp_used',~isempty(observations.gfp), ...
    'brightfield_used',~isempty(observations.brightfield), ...
    'nucleus_used',~isempty(observations.nucleus), ...
    'budneck_used',~isempty(observations.budneck));
paramout.runtime.model_update_policy=paramout.modelUpdatePolicy;
paramout.runtime.model_release_id=paramout.resolvedModelReleaseId;
paramout.runtime.model_release_manifest= ...
    paramout.resolvedModelReleaseManifestPath;
if strcmp(paramout.backend,'causal_composite')
    paramout.runtime.composite_manifest = paramout.compositeManifestPath;
    paramout.runtime.tracking = trackingRefs;
    paramout.runtime.state_update_mode = paramout.stateUpdateMode;
end
paramout.cellModelReport = struct( ...
    'load',loadReport,'apply',applyReport,'state',stateReport, ...
    'materialization',materializationReport, ...
    'legacy',legacyReport,'save',saveReport);
paramout.saveChannels = {};
dataout = roiobj.data;
imageout = compositeImage;
if paramout.debug
    [linked,review] = summaryCounts(result.summary);
    fprintf(['[cellLatentModel] %d linked, %d review; family %u; ' ...
        'backend=%s; GFP=%d; BF=%d; nucleus=%d; budneck=%d.\n'], ...
        linked,review,familyId,paramout.backend,~isempty(observations.gfp), ...
        ~isempty(observations.brightfield), ...
        ~isempty(observations.nucleus),~isempty(observations.budneck));
end
end

function [linked,review] = summaryCounts(summary)
linked = 0;
review = 0;
if isfield(summary,'linked')
    linked = double(summary.linked);
elseif isfield(summary,'predicted_parent')
    linked = double(summary.predicted_parent);
end
if isfield(summary,'review')
    review = double(summary.review);
elseif isfield(summary,'events')
    review = max(0,double(summary.events)-linked);
end
end

function [stack,pix] = channelStack(roiobj,name,isLabels)
try pix = roiobj.findChannelID(name,'exact');
catch, pix = roiobj.findChannelID(name);
end
if isempty(pix)
    try
        roiobj.load('Channel',name,'Data',false,'Silent');
        pix = roiobj.findChannelID(name,'exact');
    catch
    end
end
if isempty(pix)
    error('cellLatentModel:ChannelNotFound', ...
        'Channel "%s" was not found.',name);
end
pix = pix(1);
stack = squeeze(roiobj.image(:,:,pix,:));
if ismatrix(stack)
    stack = reshape(stack,size(stack,1),size(stack,2),1);
end
if isLabels
    values = double(stack(:));
    if any(~isfinite(values)) || any(values < 0) || ...
            any(mod(values,1) ~= 0)
        error('cellLatentModel:InvalidLabels', ...
            'Tracked masks must be finite non-negative integers.');
    end
    stack = uint32(stack);
else
    stack = single(stack);
end
end

function filename = resolveAuditFile(roiobj,outputFamily,ctx)
root = '';
try
    if isfield(ctx,'store') && isfield(ctx.store,'workDir')
        root = char(string(ctx.store.workDir));
    end
catch
end
if isempty(root)
    sidecar = cellModel.pathForROI(roiobj);
    root = fullfile(fileparts(sidecar),'artifacts','cellLatentModel');
end
stamp = char(datetime('now','Format','yyyyMMdd''T''HHmmssSSS'));
safeFamily = regexprep(outputFamily,'[^A-Za-z0-9_-]+','_');
safeRoi = regexprep(char(string(roiobj.id)),'[^A-Za-z0-9_-]+','_');
filename = fullfile(root,sprintf('cell_latent_%s_%s_%s.json', ...
    safeRoi,safeFamily,stamp));
end

function writeJsonAtomic(filename,value)
temporary = [filename '.tmp'];
fid = fopen(temporary,'w');
if fid < 0
    error('cellLatentModel:AuditWriteFailed', ...
        'Cannot create %s.',temporary);
end

cleanup = onCleanup(@() fclose(fid));
fwrite(fid,jsonencode(value,'PrettyPrint',true),'char');
clear cleanup;
[ok,message] = movefile(temporary,filename,'f');
if ~ok
    error('cellLatentModel:AuditWriteFailed', ...
        'Cannot finalize %s: %s',filename,message);
end
end

function ctx = fullRoiContext(ctx)
if nargin<1||isempty(ctx)||~isstruct(ctx),ctx=struct();end
if ~isfield(ctx,'sel')||~isstruct(ctx.sel),ctx.sel=struct();end
ctx.sel.frames=-1;
end

function name = physicalTrackChannel(name)
name=strtrim(char(string(name)));
if isempty(name),name='pred_latent_model_tracks';end
if ~startsWith(name,'results_','IgnoreCase',true)
    name=['results_' name];
end
end
