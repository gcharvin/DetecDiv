function out = format(classif,rois,ctx)
%CELLLATENTMODEL.FORMAT Build a versioned multimodal relation dataset.
if nargin < 2, rois = []; end
if nargin < 3 || isempty(ctx), ctx = struct(); end
cellLatentModel.ensureClassMetadata(classif);
out = cellLatentModel.utils.outInitSafe('cellLatentModel.format');
tp = cellLatentModel.preflightFormat(classif,rois,ctx);
architecture = textChoice(tp.architectureVersion,'detecdiv_composite_v1');
if strcmp(architecture,'detecdiv_composite_v1') && logical(tp.trainMotherNull)
    % The existing composite backend couples tracking to the physical-time
    % parent/NULL head.  The legacy relation ensemble remains available
    % through lineage_only_v1.
    tp.trainingObjective = 'continuous_lineage';
end
classif.trainingParam = tp;
out.refs.trainingScope = classifierBinding.trainingScopeSpec(classif);
[trainRois,valRois] = resolveSplits( ...
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
    out = formatComposite(classif,trainRois,valRois,root,ctx,tp,out);
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
out.refs.trainRois = trainRois;
out.refs.validationRois = valRois;
out.status = "OK";
end

function out = formatComposite(classif,trainRois,valRois,root,ctx,tp,out)
components = struct();
metrics = struct();
artifacts = struct();
allTrainingRois = [trainRois valRois];
if logical(tp.trainTrackingActions)
    trackerParams = cellLatentModel.trackerTrainingParams(tp);
    proxy = trackerProxy(classif,trackerParams);
    trackerCtx = ctx;
    trackerCtx.params = trackerParams;
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
    lineage = cellLatentModel.formatDataset( ...
        classif,trainRois,valRois,root,ctx,tp);
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
compositeManifest = fullfile(root,'composite_dataset_manifest.json');
payload = struct( ...
    'schema_version',1, ...
    'format','detecdiv_cell_latent_composite_dataset_v1', ...
    'created_at',char(datetime('now','Format', ...
        'yyyy-MM-dd''T''HH:mm:ssXXX')), ...
    'architecture','detecdiv_composite_v1', ...
    'classifier_id',char(string(classif.strid)), ...
    'split',struct('train',trainRois,'validation',valRois, ...
        'test',testRois(classif)), ...
    'components',components, ...
    'label_contract',struct( ...
        'instance_input',textValue(tp.instanceChannelName), ...
        'tracking_identity_gt',textValue(tp.trackChannelName), ...
        'tracking_identity_source','cellModel.instances.track_id', ...
        'lineage_gt_family',textValue(tp.groundTruthFamily), ...
        'unlinked_appearance','NULL'), ...
    'state_update_mode',stateMode);
writeJson(compositeManifest,payload);
pointer = fullfile(root,'latest_cell_latent_composite_dataset.json');
writeJson(pointer,struct('schema_version',1, ...
    'manifest',normalizedPath(compositeManifest), ...
    'manifest_sha256',fileSha256(compositeManifest), ...
    'created_at',payload.created_at));
artifacts.compositeManifest = compositeManifest;
artifacts.pointer = pointer;
out.artifacts = artifacts;
out.metrics = metrics;
out.refs.trainRois = trainRois;
out.refs.validationRois = valRois;
out.refs.trainingScope = classifierBinding.trainingScopeSpec(classif);
out.status = "OK";
end

function row = componentRecord(component,manifest,status,trainRois,valRois)
row = struct('component',component,'scope','trainable','status',status, ...
    'manifest',normalizedPath(manifest), ...
    'manifest_sha256',fileSha256(manifest), ...
    'train_rois',trainRois,'validation_rois',valRois);
end

function proxy = trackerProxy(classif,tp)
proxy = struct('path',classif.path,'strid',classif.strid, ...
    'roi',classif.roi,'dataset',classif.dataset, ...
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

function value = ternary(condition,yes,no)
if condition,value=yes;else,value=no;end
end

function writeJson(filename,value)
folder=fileparts(filename);if ~isempty(folder)&&exist(folder,'dir')~=7,mkdir(folder);end
fid=fopen(filename,'w');if fid<0,error('cellLatentModel:ConfigWriteFailed','Cannot write %s.',filename);end
cleanup=onCleanup(@()fclose(fid));fwrite(fid,jsonencode(value,'PrettyPrint',true),'char'); %#ok<NASGU>
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

function [trainRois,valRois] = resolveSplits(classif,requested,fraction)
n = numel(classif.roi);
trainRois = normalizeIndices(requested,n);
if isempty(trainRois)
    try trainRois = normalizeIndices(classif.dataset.split.train,n); catch, end
end
if isempty(trainRois)
    try trainRois = normalizeIndices(classif.trainingset,n); catch, end
end
valRois = [];
testRois = [];
try
    valRois = normalizeIndices(classif.dataset.split.val,n);
    testRois = normalizeIndices(classif.dataset.split.test,n);
catch
end
trainRois = setdiff(trainRois,testRois,'stable');
valRois = setdiff(valRois,testRois,'stable');
trainRois = setdiff(trainRois,valRois,'stable');
if isempty(valRois) && numel(trainRois) > 1 && fraction > 0
    count = max(1,min(numel(trainRois)-1, ...
        round(numel(trainRois)*fraction)));
    valRois = trainRois(end-count+1:end);
    trainRois = trainRois(1:end-count);
end
end

function out = normalizeIndices(value,n)
if isempty(value), out = []; return; end
out = unique(round(double(value(:)')),'stable');
out = out(isfinite(out) & out >= 1 & out <= n);
end
