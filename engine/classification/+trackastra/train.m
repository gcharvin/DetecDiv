function out = train(classif, ctx)
% trackastra.train  Export classifier ROIs and launch upstream training.

if nargin < 2 || isempty(ctx), ctx = struct(); end
if (ischar(ctx) || (isstring(ctx) && isscalar(ctx))) && strcmpi(strtrim(char(string(ctx))),'init')
    ctx = struct('mode','init');
end
out = trackastra.utils.outInitSafe('trackastra.train');
if isempty(classif.trainingParam)
    classif.trainingParam = trackastra.utils.defaultTrainingParam();
end
if isempty(classif.executionParam)
    classif.executionParam = trackastra.utils.defaultExecutionParam();
end
if isfield(ctx,'params') && isstruct(ctx.params)
    classif.trainingParam = trackastra.utils.applyParamOverrides(classif.trainingParam, ctx.params);
end
trackastra.ensureClassMetadata(classif);
if isfield(ctx,'mode') && strcmpi(char(string(ctx.mode)),'init')
    out.refs.trainingParam = classif.trainingParam;
    out.refs.executionParam = classif.executionParam;
    out.status = "OK";
    return;
end

detecdiv_check_cancel(ctx, 'trackastra train start');
explicitPython = '';
try
    if isprop(classif,'executionParam') && isstruct(classif.executionParam) && ...
            isfield(classif.executionParam,'pythonExecutable')
        explicitPython = classif.executionParam.pythonExecutable;
    end
catch
end
pythonExe = trackastra.utils.resolvePythonExecutable(explicitPython, ctx);
ensureTrainingDependencies(pythonExe);
sourceRoot = resolveTrainingSource(classif, pythonExe);
trainScript = fullfile(sourceRoot, 'scripts', 'train.py');
if exist(trainScript,'file') ~= 2
    error('trackastra:MissingUpstreamTrainScript', ...
        'Pinned Trackastra source has no scripts/train.py: %s', sourceRoot);
end

rois = [];
try, rois = classif.dataset.split.train; catch, end
if isempty(rois), rois = classif.trainingset; end
formatOut = trackastra.format(classif, rois, ctx);
trainSeq = formatOut.artifacts.trainSequences;
valSeq = formatOut.artifacts.validationSequences;
if isempty(trainSeq) || isempty(valSeq)
    error('trackastra:IncompleteDataset', 'Trackastra training requires train and validation sequences.');
end

tp = classif.trainingParam;
modelName = safeName(getField(tp,'modelName','trackastra_detecdiv'));
modelsRoot = fullfile(classif.path, 'models');
if exist(modelsRoot,'dir') ~= 7, mkdir(modelsRoot); end
configPath = fullfile(classif.path, 'trackastra_train_config.yaml');
cfg = struct();
cfg.input_train = slashList(trainSeq);
cfg.input_val = slashList(valSeq);
cfg.detection_folders = {'TRA'};
cfg.outdir = slashPath(modelsRoot);
cfg.name = modelName;
cfg.timestamp = false;
cfg.device = choice(getField(tp,'device','cuda'), {'cuda','cpu'}, 'cuda');
cfg.ndim = 2;
cfg.epochs = positiveInteger(getField(tp,'epochs',100),100,'epochs');
cfg.warmup_epochs = nonnegativeInteger(getField(tp,'warmupEpochs',10),10,'warmupEpochs');
cfg.window = positiveInteger(getField(tp,'window',6),6,'window');
cfg.batch_size = positiveInteger(getField(tp,'batchSize',8),8,'batchSize');
cfg.crop_size = numericVector(getField(tp,'cropSize',[256 256]),[256 256],'cropSize');
cfg.max_tokens = positiveInteger(getField(tp,'maxTokens',2048),2048,'maxTokens');
cfg.train_samples = positiveInteger(getField(tp,'trainSamples',50000),50000,'trainSamples');
cfg.lr = positiveScalar(getField(tp,'learningRate',1e-4),1e-4,'learningRate');
cfg.num_workers = nonnegativeInteger(getField(tp,'numWorkers',0),0,'numWorkers');
cfg.augment = nonnegativeInteger(getField(tp,'augment',3),3,'augment');
cfg.features = choice(getField(tp,'features','wrfeat'), ...
    {'none','regionprops','regionprops2','patch','patch_regionprops','wrfeat'}, 'wrfeat');
cfg.distributed = logicalScalar(getField(tp,'distributed',false),false);
cfg.logger = choice(getField(tp,'logger','tensorboard'), {'tensorboard','wandb','none'}, 'tensorboard');
cfg.resume = logicalScalar(getField(tp,'resume',true),true);
cfg.example_images = false;
cfg.tracking_frequency = -1;
initialModel = scalarText(getField(tp,'initialModelPath',''));
if ~isempty(initialModel), cfg.model = slashPath(initialModel); end
writeJson(configPath, cfg);

fprintf('[Trackastra train] source=%s\n', sourceRoot);
fprintf('[Trackastra train] dataset=%s train=%d val=%d model=%s\n', ...
    formatOut.artifacts.datasetRoot, numel(trainSeq), numel(valSeq), modelName);
cmd = sprintf('"%s" "%s" --config "%s"', pythonExe, trainScript, configPath);
[status,msg] = system(cmd,'-echo');
if status ~= 0
    error('trackastra:TrainingFailed','Trackastra training failed (%d):\n%s',status,msg);
end
detecdiv_check_cancel(ctx, 'trackastra train after Python');

modelFolder = fullfile(modelsRoot, modelName);
classif.executionParam.modelSource = 'custom';
classif.executionParam.customModelPath = fullfile('models',modelName);
out.status = "OK";
out.artifacts.datasetRoot = formatOut.artifacts.datasetRoot;
out.artifacts.config = configPath;
out.artifacts.modelFolder = modelFolder;
out.artifacts.upstreamSource = sourceRoot;
out.refs.executionParam = struct('modelSource','custom', ...
    'customModelPath',fullfile('models',modelName));
end

function sourceRoot = resolveTrainingSource(classif, pythonExe)
tp = classif.trainingParam;
sourceRoot = scalarText(getField(tp,'trackastraSourceRoot',''));
if ~isempty(sourceRoot)
    if exist(fullfile(sourceRoot,'scripts','train.py'),'file') ~= 2
        error('trackastra:BadSourceRoot','trackastraSourceRoot has no scripts/train.py: %s',sourceRoot);
    end
    return;
end
version = scalarText(getField(tp,'trackastraVersion','0.5.3'));
vendorRoot = fullfile(classif.path,'vendor');
sourceRoot = fullfile(vendorRoot,['trackastra-' version]);
if exist(fullfile(sourceRoot,'scripts','train.py'),'file') == 2, return; end
if exist(vendorRoot,'dir') ~= 7, mkdir(vendorRoot); end
fprintf('[Trackastra train] caching pinned upstream source %s under %s\n',version,vendorRoot);
cmd = sprintf('"%s" -m pip download --disable-pip-version-check --no-deps --no-binary=:all: --dest "%s" "trackastra==%s"', ...
    pythonExe, vendorRoot, version);
[status,msg] = system(cmd,'-echo');
if status ~= 0
    error('trackastra:SourceDownloadFailed','Unable to download Trackastra source (%d):\n%s',status,msg);
end
archive = dir(fullfile(vendorRoot,['trackastra-' version '.tar.gz']));
if isempty(archive)
    error('trackastra:SourceArchiveMissing','Downloaded Trackastra source archive was not found.');
end
untar(fullfile(archive(1).folder,archive(1).name),vendorRoot);
if exist(fullfile(sourceRoot,'scripts','train.py'),'file') ~= 2
    error('trackastra:SourceExtractionFailed','Unable to extract Trackastra source to %s.',sourceRoot);
end
end

function ensureTrainingDependencies(pythonExe)
code = ['import importlib.util as u,sys;' ...
    'mods=[''trackastra'',''lightning'',''wandb'',''tensorboard'',''configargparse'',''kornia'',''git''];' ...
    'missing=[m for m in mods if u.find_spec(m) is None];' ...
    'print('',''.join(missing));sys.exit(1 if missing else 0)'];
cmd = sprintf('"%s" -c "%s"',pythonExe,code);
[status,msg] = system(cmd);
if status ~= 0
    error('trackastra:TrainingDependenciesMissing', ...
        ['Trackastra training dependencies are missing: %s\n' ...
         'Install them into the active DetecDiv environment with:\n' ...
         '  python -m pip install "trackastra[train]==0.5.3"'], strtrim(msg));
end
end

function out = slashList(values)
out = cellfun(@slashPath,values,'UniformOutput',false);
end
function out = slashPath(value), out=strrep(char(string(value)),'\','/'); end
function value=getField(s,name,fallback),value=fallback;if isstruct(s)&&isfield(s,name)&&~isempty(s.(name)),value=s.(name);end,end
function txt=scalarText(value),while iscell(value),value=value(~cellfun(@isempty,value));if isempty(value),txt='';return;end,value=value{end};end,txt=strtrim(char(string(value)));end
function out=choice(value,allowed,fallback),out=lower(strtrim(scalarText(value)));if ~any(strcmp(out,allowed)),out=fallback;end,end
function out=safeName(value),out=regexprep(scalarText(value),'[^A-Za-z0-9_.-]','_');if isempty(out),out='trackastra_detecdiv';end,end
function value=positiveScalar(raw,fallback,name),value=double(raw);if isempty(value),value=fallback;end,if ~isscalar(value)||~isfinite(value)||value<=0,error('trackastra:InvalidTrainingParameter','%s must be positive.',name);end,end
function value=positiveInteger(raw,fallback,name),value=round(positiveScalar(raw,fallback,name));end
function value=nonnegativeInteger(raw,fallback,name),value=double(raw);if isempty(value),value=fallback;end,if ~isscalar(value)||~isfinite(value)||value<0,error('trackastra:InvalidTrainingParameter','%s must be non-negative.',name);end,value=round(value);end
function value=numericVector(raw,fallback,name),value=double(raw(:)');if isempty(value),value=fallback;end,if any(~isfinite(value))||any(value<=0),error('trackastra:InvalidTrainingParameter','%s must contain positive values.',name);end,value=round(value);end
function value=logicalScalar(raw,fallback),if isempty(raw),value=fallback;elseif ischar(raw)||isstring(raw),value=any(strcmpi(strtrim(char(string(raw))),{'true','yes','on','1'}));else,value=logical(raw(1));end,end
function writeJson(pathValue,value),fid=fopen(pathValue,'w');if fid<0,error('trackastra:TrainingConfigWriteFailed','Unable to write %s.',pathValue);end,cleaner=onCleanup(@()fclose(fid));fwrite(fid,jsonencode(value,'PrettyPrint',true),'char');end %#ok<NASGU>
