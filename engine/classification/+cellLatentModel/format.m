function out = format(classif,rois,ctx)
%CELLLATENTMODEL.FORMAT Build a versioned multimodal relation dataset.
if nargin < 2, rois = []; end
if nargin < 3 || isempty(ctx), ctx = struct(); end
cellLatentModel.ensureClassMetadata(classif);
out = cellLatentModel.utils.outInitSafe('cellLatentModel.format');
[tp,approvalRecords] = cellLatentModel.preflightFormat(classif,rois,ctx);
architecture = textChoice(tp.architectureVersion,'detecdiv_composite_v1');
if strcmp(architecture,'detecdiv_composite_v1') && logical(tp.trainMotherNull)
    % The existing composite backend couples tracking to the physical-time
    % parent/NULL head.  The legacy relation ensemble remains available
    % through lineage_only_v1.
    tp.trainingObjective = 'continuous_lineage';
end
classif.trainingParam = tp;
out.refs.trainingScope = classifierBinding.trainingScopeSpec(classif);
[trainRois,valRois,~,splitAudit] = cellLatentModel.resolveRoiSplits( ...
    classif,rois,tp.validationFraction);
if isempty(trainRois)
    error('cellLatentModel:NoTrainingROIs', ...
        'Select at least one training ROI in classifierGUI.');
end
if isempty(valRois)
    error('cellLatentModel:NoValidationROIs', ...
        ['At least two imported ROIs are required: one for training and ' ...
         'one for ROI-level validation.']);
end
root = fullfile(classif.path,'trainingdataset');
if strcmp(architecture,'detecdiv_composite_v1')
    out = formatComposite(classif,trainRois,valRois,root,ctx,tp,out, ...
        approvalRecords,splitAudit);
    return;
end
result = cellLatentModel.formatDataset( ...
    classif,trainRois,valRois,root,ctx,tp);
out.artifacts.dataset = result.datasetDir;
out.artifacts.manifest = result.manifestFile;
out.artifacts.config = result.configFile;
out.artifacts.stdout = result.stdoutFile;
if isfield(result.manifest,'rows')
    out.metrics.rows = double(result.manifest.rows);
elseif isfield(result.manifest,'counts') && ...
        isfield(result.manifest.counts,'observations')
    out.metrics.rows = double(result.manifest.counts.observations);
end
if isfield(result.manifest,'events')
    out.metrics.events = double(result.manifest.events);
elseif isfield(result.manifest,'counts') && ...
        isfield(result.manifest.counts,'events')
    out.metrics.events = double(result.manifest.counts.events);
end
out.metrics.split = splitAudit.counts;
out.metrics.validationRoiFraction = ...
    splitAudit.actual_validation_roi_fraction;
out.refs.trainRois = trainRois;
out.refs.validationRois = valRois;
out.refs.splitAudit = splitAudit;
out.status = "OK";
end

function out = formatComposite(classif,trainRois,valRois,root,ctx,tp,out, ...
        approvalRecords,splitAudit)
runId = compositeRunId(tp);
compositeDir = fullfile(root,'c',compositePathId(tp));
compositeManifest = fullfile(compositeDir,'manifest.json');
pointer = fullfile(root,'latest_cell_latent_composite_dataset.json');
supersedes = previousPublishedVersion(pointer);
if isfolder(compositeDir)
    error('cellLatentModel:ImmutableDatasetExists', ...
        ['Composite dataset run "%s" already exists. Dataset versions ' ...
         'are immutable; start a new formatting run.'],runId);
end
mkdir(compositeDir);
try
components = struct();
metrics = struct();
metrics.split = splitAudit.counts;
metrics.validationRoiFraction = ...
    splitAudit.actual_validation_roi_fraction;
artifacts = struct();
allTrainingRois = [trainRois valRois];
if logical(tp.trainTrackingActions)
    trackerParams = cellLatentModel.trackerTrainingParams(tp);
    proxy = trackerProxy(classif,trackerParams,compositeDir, ...
        trainRois,valRois);
    trackerCtx = ctx;
    trackerCtx.params = trackerParams;
    trackerCtx.datasetDir = fullfile(compositeDir,'td');
    trackerCtx.runDir = fullfile(compositeDir,'tr');
    trackerCtx.pointerFile = fullfile(compositeDir,'tracking.json');
    tracker = cellLatentTracker.format( ...
        proxy,allTrainingRois,trackerCtx);
    components.tracking = componentRecord( ...
        'EDGE_APPEAR_END',tracker.artifacts.manifest, ...
        'trained',tracker.refs.trainRois,tracker.refs.validationRois);
    metrics.tracking = tracker.metrics;
    metrics.outputCount = tracker.metrics.outputCount;
    metrics.outputUnit = tracker.metrics.outputUnit;
    artifacts.trackingDataset = tracker.artifacts.dataset;
    artifacts.trackingManifest = tracker.artifacts.manifest;
    artifacts.trackingStdout = tracker.artifacts.stdout;
end
if logical(tp.trainMotherNull)
    lineageCtx = ctx;
    % The parent composite directory already provides the immutable version
    % identity. Keep the component token short to stay below MAX_PATH on
    % Windows classifier roots.
    lineageCtx.formatRunId = 'd';
    lineage = cellLatentModel.formatDataset( ...
        classif,trainRois,valRois,fullfile(compositeDir,'l'), ...
        lineageCtx,tp);
    components.lineage = componentRecord( ...
        'mother_NULL',lineage.manifestFile,'trained',trainRois,valRois);
    if isfield(lineage.manifest,'counts')
        metrics.lineage = lineage.manifest.counts;
        if ~isfield(metrics,'outputCount') && ...
                isfield(lineage.manifest.counts,'observations')
            metrics.rows = double(lineage.manifest.counts.observations);
        end
    else
        metrics.lineage = struct();
    end
    artifacts.lineageDataset = lineage.datasetDir;
    artifacts.lineageManifest = lineage.manifestFile;
    artifacts.lineageStdout = lineage.stdoutFile;
end
if isempty(fieldnames(components))
    error('cellLatentModel:NoTrainableComponent', ...
        'Select tracking and/or mother-NULL training before formatting.');
end
stateMode = textChoice(tp.stateUpdateMode,'promoted_frozen_bf');
components.biological_state = struct( ...
    'component','biological_state', ...
    'scope',stateMode, ...
    'status',ternary(strcmp(stateMode,'promoted_frozen_bf'), ...
        'frozen_promoted','disabled'), ...
    'manifest','','manifest_sha256','', ...
    'train_rois',[],'validation_rois',[]);
payload = struct( ...
    'schema_version',1, ...
    'format','detecdiv_cell_latent_composite_dataset_v1', ...
    'run_id',runId, ...
    'model_name',safeName(tp.modelName), ...
    'created_at',cellLatentModel.utils.utcIso8601(), ...
    'architecture','detecdiv_composite_v1', ...
    'classifier_id',char(string(classif.strid)), ...
    'supersedes',supersedes, ...
    'split',struct('train',trainRois,'validation',valRois, ...
        'test',testRois(classif)), ...
    'split_roi_ids',struct( ...
        'train',{roiIds(classif,trainRois)}, ...
        'validation',{roiIds(classif,valRois)}, ...
        'test',{roiIds(classif,testRois(classif))}), ...
    'split_contract',splitAudit, ...
    'annotation_approvals',approvalRecords, ...
    'components',components, ...
    'label_contract',struct( ...
        'instance_input',textValue(tp.instanceChannelName), ...
        'tracking_identity_gt',textValue(tp.trackChannelName), ...
        'tracking_identity_source','cellModel.instances.track_id', ...
        'lineage_gt_family',textValue(tp.groundTruthFamily), ...
        'unlinked_appearance','NULL'), ...
    'state_update_mode',stateMode);
writeJsonAtomic(compositeManifest,payload);
pointerPayload=struct('schema_version',1, ...
    'run_id',runId, ...
    'model_name',safeName(tp.modelName), ...
    'manifest',normalizedPath(compositeManifest), ...
    'manifest_sha256',fileSha256(compositeManifest), ...
    'created_at',payload.created_at, ...
    'legacy_pointer_policy', ...
        'marked compatibility aliases; this composite pointer is authoritative');
legacyPointers=publishCompositePointers( ...
    root,pointer,pointerPayload,components,payload.created_at);
artifacts.compositeManifest = compositeManifest;
artifacts.pointer = pointer;
artifacts.legacyPointers = legacyPointers;
artifacts.datasetRoot = compositeDir;
out.artifacts = artifacts;
out.metrics = metrics;
out.refs.trainRois = trainRois;
out.refs.validationRois = valRois;
out.refs.splitAudit = splitAudit;
out.refs.trainingScope = classifierBinding.trainingScopeSpec(classif);
out.status = "OK";
catch ME
    % A component failure never publishes the composite pointer. Remove
    % only this fresh run; completed prior versions remain immutable.
    if ~pointerTargets(pointer,compositeManifest)
        removeFolder(compositeDir);
    end
    rethrow(ME);
end
end

function row = componentRecord(component,manifest,status,trainRois,valRois)
row = struct('component',component,'scope','trainable','status',status, ...
    'manifest',normalizedPath(manifest), ...
    'manifest_sha256',fileSha256(manifest), ...
    'train_rois',trainRois,'validation_rois',valRois);
end

function proxy = trackerProxy(classif,tp,componentRoot,trainRois,valRois)
dataset = classif.dataset;
dataset.split.train = trainRois;
dataset.split.val = valRois;
proxy = struct('path',componentRoot,'strid',classif.strid, ...
    'roi',classif.roi,'dataset',dataset, ...
    'trainingset',classif.trainingset,'bounds',classif.bounds, ...
    'classifierPkg','cellLatentTracker', ...
    'trainingFun','cellLatentTracker.train', ...
    'classifyFun','cellLatentTracker.classify', ...
    'trainingParam',tp,'executionParam',struct());
end

function values = testRois(classif)
values = [];
try values = double(classif.dataset.split.test(:)'); catch, end
end

function values = roiIds(classif,indices)
indices=double(indices(:).');
values=cell(1,numel(indices));
for i=1:numel(indices)
    values{i}=char(string(classif.roi(indices(i)).id));
end
end

function value = ternary(condition,yes,no)
if condition,value=yes;else,value=no;end
end

function writeJson(filename,value)
folder=fileparts(filename);if ~isempty(folder)&&exist(folder,'dir')~=7,mkdir(folder);end
fid=fopen(filename,'w');if fid<0,error('cellLatentModel:ConfigWriteFailed','Cannot write %s.',filename);end
cleanup=onCleanup(@()fclose(fid));
encoded=jsonencode(value,'PrettyPrint',true);
written=fwrite(fid,encoded,'char');
if written~=numel(encoded)
    error('cellLatentModel:ConfigWriteFailed', ...
        'Incomplete JSON write for %s (%d/%d characters).', ...
        filename,written,numel(encoded));
end
end

function writeJsonAtomic(filename,value)
tmp=[filename '.tmp_' char(java.util.UUID.randomUUID)];
tmpCleanup=onCleanup(@()deleteIfPresent(tmp));
writeJson(tmp,value);
[ok,message]=movefile(tmp,filename,'f');
if ~ok
    error('cellLatentModel:PointerPublishFailed', ...
        'Cannot publish dataset pointer %s: %s',filename,message);
end
clear tmpCleanup;
end

function aliases=publishCompositePointers( ...
        root,authoritativeFile,authoritativePayload,components,createdAt)
% Keep old component-specific readers functional without letting their
% pointers masquerade as independent, authoritative formatting runs. Each
% alias is replaced atomically and names the composite pointer that owns it;
% the authoritative pointer is published last.
aliases=struct();
files={};
payloads={};
if isfield(components,'tracking')
    file=fullfile(root,'latest_latent_tracking_dataset.json');
    files{end+1}=file; %#ok<AGROW>
    payloads{end+1}=componentAliasPayload('tracking', ...
        components.tracking,authoritativeFile, ...
        authoritativePayload.manifest,createdAt); %#ok<AGROW>
    aliases.tracking=normalizedPath(file);
end
if isfield(components,'lineage')
    file=fullfile(root,'latest_cell_latent_continuous_dataset.json');
    files{end+1}=file; %#ok<AGROW>
    payloads{end+1}=componentAliasPayload('lineage', ...
        components.lineage,authoritativeFile, ...
        authoritativePayload.manifest,createdAt); %#ok<AGROW>
    aliases.lineage=normalizedPath(file);
end
authoritativePayload.compatibility_aliases=aliases;
prior=cell(size(files));
existed=false(size(files));
for index=1:numel(files)
    existed(index)=isfile(files{index});
    if existed(index),prior{index}=fileread(files{index});end
end
try
    for index=1:numel(files)
        writeJsonAtomic(files{index},payloads{index});
    end
    writeJsonAtomic(authoritativeFile,authoritativePayload);
catch ME
    % Application-level transaction: if the authoritative pointer was not
    % published, restore every legacy alias to its exact prior contents.
    for index=1:numel(files)
        if existed(index)
            try writeTextAtomic(files{index},prior{index});catch,end
        elseif isfile(files{index})
            try delete(files{index});catch,end
        end
    end
    rethrow(ME);
end
end

function payload=componentAliasPayload(component,record, ...
        authoritativeFile,authoritativeManifest,createdAt)
payload=struct( ...
    'schema_version',1, ...
    'format','detecdiv_composite_component_pointer_alias_v1', ...
    'status','compatibility_alias', ...
    'component',component, ...
    'manifest',record.manifest, ...
    'manifest_sha256',record.manifest_sha256, ...
    'authoritative_pointer',normalizedPath(authoritativeFile), ...
    'authoritative_manifest',normalizedPath(authoritativeManifest), ...
    'created_at',createdAt);
end

function writeTextAtomic(filename,value)
tmp=[filename '.tmp_' char(java.util.UUID.randomUUID)];
tmpCleanup=onCleanup(@()deleteIfPresent(tmp));
fid=fopen(tmp,'w');
if fid<0
    error('cellLatentModel:PointerPublishFailed', ...
        'Cannot create temporary pointer %s.',tmp);
end
closeFile=onCleanup(@()fclose(fid));
fwrite(fid,value,'char');
clear closeFile;
[ok,message]=movefile(tmp,filename,'f');
if ~ok
    error('cellLatentModel:PointerPublishFailed', ...
        'Cannot restore dataset pointer %s: %s',filename,message);
end
clear tmpCleanup;
end

function deleteIfPresent(filename)
if isfile(filename),try delete(filename);catch,end,end
end

function removeFolder(folder)
if isfolder(folder),try rmdir(folder,'s');catch,end,end
end

function tf=pointerTargets(pointerFile,manifestFile)
tf=false;
if ~isfile(pointerFile)||~isfile(manifestFile),return;end
try
    record=jsondecode(fileread(pointerFile));
    tf=strcmpi(normalizedPath(record.manifest), ...
        normalizedPath(manifestFile));
catch
end
end

function record=previousPublishedVersion(pointerFile)
record=struct('manifest','','manifest_sha256','');
if ~isfile(pointerFile),return;end
try
    prior=jsondecode(fileread(pointerFile));
    priorManifest=char(string(prior.manifest));
    if ~isfile(priorManifest),return;end
    record.manifest=normalizedPath(priorManifest);
    record.manifest_sha256=fileSha256(priorManifest);
catch
end
end

function value = fileSha256(filename)
fid=fopen(filename,'r');
if fid<0,error('cellLatentModel:ManifestReadFailed','Cannot read %s.',filename);end
cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
bytes=fread(fid,Inf,'*uint8');
digest=java.security.MessageDigest.getInstance('SHA-256');
hash=typecast(digest.digest(bytes),'uint8');
value=lower(reshape(dec2hex(hash,2).',1,[]));
end

function value = normalizedPath(value)
value=strrep(char(string(value)),'\','/');
end

function value = textValue(value)
while iscell(value),if isempty(value),value='';return;else,value=value{end};end,end
value=strtrim(char(string(value)));
end

function value = textChoice(value,fallback)
value=textValue(value);value=lower(strrep(strrep(value,'-','_'),' ','_'));
if isempty(value),value=fallback;end
end

function value = safeName(value)
value=regexprep(textValue(value),'[^A-Za-z0-9_.-]','_');
if isempty(value),value='cell_latent_model';end
end

function value = compositeRunId(tp)
stamp=char(datetime('now','Format','yyyyMMdd''T''HHmmssSSS'));
uuid=regexprep(char(java.util.UUID.randomUUID),'-','');
value=sprintf('%s_%s_%s',safeName(tp.modelName),stamp,uuid(1:8));
end

function value = compositePathId(tp)
model=safeName(tp.modelName);
version=regexp(model,'v\d+$','match','once');
if isempty(version),version=model(1:min(20,numel(model)));end
stamp=char(datetime('now','Format','yyyyMMdd''T''HHmmss'));
uuid=regexprep(char(java.util.UUID.randomUUID),'-','');
value=sprintf('%s_%s_%s',version,stamp,uuid(1:8));
end
