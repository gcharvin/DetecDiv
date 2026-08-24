function out = train(classif,ctx)
%CELLLATENTTRACKER.TRAIN Fit only latent EDGE/APPEAR/END actions.
if nargin < 2 || isempty(ctx), ctx = struct(); end
if (ischar(ctx)||isstring(ctx)) && strcmpi(strtrim(char(string(ctx))),'init')
    ctx=struct('mode','init');
end
out=cellLatentModel.utils.outInitSafe('cellLatentTracker.train');
cellLatentTracker.ensureClassMetadata(classif);
tp=cellLatentTracker.utils.defaultTrainingParam();
if isstruct(classif.trainingParam)
    tp=cellLatentModel.utils.applyOverrides(tp,classif.trainingParam);
end
if isfield(ctx,'trainingParam')&&isstruct(ctx.trainingParam)
    tp=cellLatentModel.utils.applyOverrides(tp,ctx.trainingParam);
end
classif.trainingParam=tp;
if isempty(classif.executionParam)
    classif.executionParam=cellLatentTracker.utils.defaultExecutionParam();
end
if isfield(ctx,'mode')&&strcmpi(char(string(ctx.mode)),'init')
    out.refs.trainingParam=tp; out.refs.executionParam=classif.executionParam;
    out.status="OK"; return;
end
out.refs.trainingScope=classifierBinding.logTrainingScope(classif);
pointerFile=fullfile(classif.path,'trainingdataset', ...
    'latest_latent_tracking_dataset.json');
manifestFile='';
try manifestFile=textValue(ctx.datasetManifest);catch,end
if isempty(manifestFile)
    if ~isfile(pointerFile)
        error('cellLatentTracker:MissingFormattedDataset', ...
            'Format the latent-tracker ROI set before training.');
    end
    pointer=jsondecode(fileread(pointerFile));
    manifestFile=char(string(pointer.manifest));
    verifyManifestHash(pointer,manifestFile);
end
if ~isfile(manifestFile)
    error('cellLatentTracker:MissingFormattedDataset', ...
        'The formatted tracking manifest no longer exists: %s',manifestFile);
end
modelName=safeName(tp.modelName);
modelDir='';
try modelDir=textValue(ctx.outputDir);catch,end
if isempty(modelDir),modelDir=fullfile(classif.path,'models',modelName);end
if isfolder(modelDir)&&~isempty(dir(fullfile(modelDir,'*')))
    error('cellLatentTracker:ImmutableModelExists', ...
        ['Model version "%s" already exists and will not be overwritten. ' ...
         'Choose a new vNNN modelName.'],modelName);
end
runDir='';
try runDir=textValue(ctx.runDir);catch,end
if isempty(runDir),runDir=fullfile(classif.path,'trainingruns',modelName);end
if exist(runDir,'dir')~=7, mkdir(runDir); end
configFile=fullfile(runDir,'training_config.json');
stdoutFile=fullfile(runDir,'training_stdout.txt');
initialSource=choice(tp.initialModelSource, ...
    {'promoted_cross_domain','checkpoint','random'},'promoted_cross_domain');
cfg=struct('schema_version',1, ...
    'dataset_manifest',normalizedPath(manifestFile), ...
    'output_dir',normalizedPath(modelDir), ...
    'initial_model_source',initialSource, ...
    'initial_checkpoint',normalizedPath(textValue(tp.initialCheckpoint)), ...
    'training',struct( ...
        'epochs',positiveInteger(tp.epochs,'epochs'), ...
        'learning_rate',positiveScalar(tp.learningRate,'learningRate'), ...
        'weight_decay',nonnegative(tp.weightDecay,'weightDecay'), ...
        'hidden_dim',positiveInteger(tp.hiddenDim,'hiddenDim'), ...
        'dropout',bounded(tp.dropout,0,1,'dropout'), ...
        'association_loss_weight',nonnegative( ...
            tp.associationLossWeight,'associationLossWeight'), ...
        'appearance_loss_weight',nonnegative( ...
            tp.appearanceLossWeight,'appearanceLossWeight'), ...
        'end_loss_weight',nonnegative(tp.endLossWeight,'endLossWeight'), ...
        'successor_loss_weight',nonnegative( ...
            tp.successorLossWeight,'successorLossWeight'), ...
        'gradient_clip_norm',5, 'promotion_tolerance',0.002, ...
        'seed',23, 'device',choice(tp.device, ...
            {'automatic','auto','cuda','cpu'},'automatic')));
writeJson(configFile,cfg);
detecdiv_check_cancel(ctx,'cellLatentTracker before training');
runtime=cellLatentModel.utils.runPythonModule( ...
    'train-detecdiv-tracking',configFile,ctx,stdoutFile);
detecdiv_check_cancel(ctx,'cellLatentTracker after training');
checkpointDir=fullfile(modelDir,'checkpoint');
reportFile=fullfile(modelDir,'training_report.json');
if ~isfile(fullfile(checkpointDir,'manifest.json'))||~isfile(reportFile)
    error('cellLatentTracker:TrainingIncomplete', ...
        'Training produced no deployable checkpoint/report.');
end
report=jsondecode(fileread(reportFile));
p=cellLatentTracker.utils.defaultExecutionParam();
p=cellLatentModel.utils.applyOverrides(p,classif.executionParam);
p.imageChannelName=textValue(tp.brightfieldChannelName);
p.instanceChannelName=textValue(tp.instanceChannelName);
p.outputName=['pred_' safeName(classif.strid) '_tracks'];
p.checkpointDir=classifierRelativePath(classif,checkpointDir);
p.topK=positiveInteger(tp.topK,'topK');
p.frameIntervalMinutes=positiveScalar( ...
    tp.frameIntervalMinutes,'frameIntervalMinutes');
p.device=choice(tp.device,{'automatic','auto','cuda','cpu'},'automatic');
classif.executionParam=p;
embedded=false;try embedded=logical(ctx.embedded);catch,end
if ~embedded
    try classiSave(classif); catch ME
        warning('cellLatentTracker:ClassifierSaveFailed', ...
            'Checkpoint trained, but classifier metadata was not saved: %s',ME.message);
    end
end
out.status="OK";
out.artifacts.dataset=manifestFile;
out.artifacts.model=modelDir;
out.artifacts.checkpoint=checkpointDir;
out.artifacts.report=reportFile;
out.artifacts.config=configFile;
out.artifacts.stdout=stdoutFile;
out.metrics=report.validation;
out.refs.trainingScope=report.scope;
out.refs.promotion=report.promotion;
out.refs.executionParam=p;
out.refs.runtime=runtime;
if isfield(report.promotion,'promoted')&&~logical(report.promotion.promoted)
    out.warnings{end+1}=[ ...
        'No fine-tuning epoch passed the validation guard; the deployable ' ...
        'checkpoint was rolled back to its initialization.'];
end
end

function writeJson(filename,value),fid=fopen(filename,'w');if fid<0,error('cellLatentTracker:ConfigWriteFailed','Cannot write %s.',filename);end,cleanup=onCleanup(@()fclose(fid));fwrite(fid,jsonencode(value,'PrettyPrint',true),'char');end %#ok<NASGU>
function value=normalizedPath(value),value=strrep(char(string(value)),'\','/');end
function value=textValue(value),while iscell(value),if isempty(value),value='';return;else,value=value{end};end,end,value=strtrim(char(string(value)));end
function value=choice(value,allowed,fallback),value=lower(strrep(textValue(value),' ','_'));if ~any(strcmp(value,allowed)),value=fallback;end,end
function value=safeName(value),value=regexprep(textValue(value),'[^A-Za-z0-9_.-]','_');if isempty(value),value='latent_tracker_v001';end,end
function verifyManifestHash(record,filename)
expected='';try expected=lower(textValue(record.manifest_sha256));catch,end
if isempty(expected),return;end
if ~isfile(filename)
    error('cellLatentTracker:MissingFormattedDataset', ...
        'The formatted tracking manifest no longer exists: %s',filename);
end
actual=fileSha256(filename);
if ~strcmpi(actual,expected)
    error('cellLatentTracker:FormattedDatasetChanged', ...
        ['Immutable formatted tracking manifest changed after publication: ' ...
         '%s'],filename);
end
end
function value=fileSha256(filename)
fid=fopen(filename,'r');
if fid<0,error('cellLatentTracker:ManifestReadFailed', ...
        'Cannot read %s.',filename);end
cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
bytes=fread(fid,Inf,'*uint8');
digest=java.security.MessageDigest.getInstance('SHA-256');
hash=typecast(digest.digest(bytes),'uint8');
value=lower(reshape(dec2hex(hash,2).',1,[]));
end
function value=classifierRelativePath(classif,value),value=textValue(value);try root=char(string(classif.path));if startsWith(lower(value),lower(root)),value=value(numel(root)+1:end);value=regexprep(value,'^[\\/]+','');end,catch,end,end
function value=positiveScalar(raw,name),value=double(raw);if ~isscalar(value)||~isfinite(value)||value<=0,error('cellLatentTracker:InvalidParameter','%s must be positive.',name);end,end
function value=positiveInteger(raw,name),value=round(positiveScalar(raw,name));end
function value=nonnegative(raw,name),value=double(raw);if ~isscalar(value)||~isfinite(value)||value<0,error('cellLatentTracker:InvalidParameter','%s must be non-negative.',name);end,end
function value=bounded(raw,low,high,name),value=double(raw);if ~isscalar(value)||~isfinite(value)||value<low||value>=high,error('cellLatentTracker:InvalidParameter','%s must lie in [%g,%g).',name,low,high);end,end
