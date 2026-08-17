function out = train(classif, ctx)
% trackastra.train  Train from an existing Trackastra CTC export.

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
classif.trainingParam = applyExplicitTrainingOverrides(classif.trainingParam, ctx);
trackastra.ensureClassMetadata(classif);
if isfield(ctx,'mode') && strcmpi(char(string(ctx.mode)),'init')
    out.refs.trainingParam = classif.trainingParam;
    out.refs.executionParam = classif.executionParam;
    out.status = "OK";
    return;
end
out.refs.trainingScope = classifierBinding.logTrainingScope(classif);

detecdiv_check_cancel(ctx, 'trackastra train start');
dataset = loadFormattedDataset(classif);
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

trainSeq = dataset.trainSequences;
valSeq = dataset.validationSequences;

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
    dataset.datasetRoot, numel(trainSeq), numel(valSeq), modelName);
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
out.artifacts.datasetRoot = dataset.datasetRoot;
out.artifacts.manifest = dataset.manifest;
out.artifacts.config = configPath;
out.artifacts.modelFolder = modelFolder;
out.artifacts.upstreamSource = sourceRoot;
out.refs.executionParam = struct('modelSource','custom', ...
    'customModelPath',fullfile('models',modelName));
end

function tp = applyExplicitTrainingOverrides(tp, ctx)
% Inference node parameters live at ctx.params and deliberately do not
% override training parameters. Training overrides must be namespaced.
patch = [];
if isstruct(ctx) && isfield(ctx,'trainingParam') && isstruct(ctx.trainingParam)
    patch = ctx.trainingParam;
elseif isstruct(ctx) && isfield(ctx,'params') && isstruct(ctx.params) && ...
        isfield(ctx.params,'trainingParam') && isstruct(ctx.params.trainingParam)
    patch = ctx.params.trainingParam;
end
if ~isempty(patch)
    tp = trackastra.utils.applyParamOverrides(tp, patch);
end
end

function dataset = loadFormattedDataset(classif)
tp = classif.trainingParam;
folderName = scalarText(getField(tp,'foldername','trainingdataset'));
if isempty(folderName), folderName = 'trainingdataset'; end
datasetRoot = fullfile(classif.path, folderName);
manifest = fullfile(datasetRoot, 'trackastra_dataset_manifest.json');
if exist(manifest,'file') ~= 2
    error('trackastra:MissingTrainingExport', ...
        ['Trackastra CTC dataset manifest was not found: %s\n' ...
         'Run trackastra.format (Format training set) before training.'], manifest);
end
try
    payload = jsondecode(fileread(manifest));
catch ME
    error('trackastra:InvalidTrainingManifest', ...
        'Unable to read Trackastra CTC manifest %s: %s. Run trackastra.format again.', ...
        manifest, ME.message);
end
if ~isstruct(payload) || ~isfield(payload,'format') || ...
        ~strcmp(char(string(payload.format)), 'ctc_trackastra_v1') || ...
        ~isfield(payload,'sequences') || isempty(payload.sequences)
    error('trackastra:InvalidTrainingManifest', ...
        'Invalid Trackastra CTC manifest: %s. Run trackastra.format again.', manifest);
end

trainSeq = {};
valSeq = {};
rows = payload.sequences;
for i = 1:numel(rows)
    if ~isfield(rows(i),'split') || ~isfield(rows(i),'sequence')
        error('trackastra:InvalidTrainingManifest', ...
            'Manifest sequence %d has no split/sequence fields. Run trackastra.format again.', i);
    end
    splitName = lower(strtrim(char(string(rows(i).split))));
    seqName = char(string(rows(i).sequence));
    seqDir = fullfile(datasetRoot, splitName, seqName);
    validateCtcSequence(seqDir);
    switch splitName
        case 'train'
            trainSeq{end+1} = seqDir; %#ok<AGROW>
        case {'val','validation'}
            valSeq{end+1} = seqDir; %#ok<AGROW>
    end
end
if isempty(trainSeq) || isempty(valSeq)
    error('trackastra:IncompleteDataset', ...
        ['Trackastra training requires at least one formatted train sequence and one ' ...
         'formatted validation sequence. Run trackastra.format again.']);
end
dataset = struct('datasetRoot',datasetRoot,'manifest',manifest, ...
    'trainSequences',{trainSeq},'validationSequences',{valSeq});
end

function validateCtcSequence(seqDir)
if exist(seqDir,'dir') ~= 7
    invalidExport('Image sequence folder is missing: %s', seqDir);
end
[splitRoot, seqName] = fileparts(seqDir);
traDir = fullfile(splitRoot, [seqName '_GT'], 'TRA');
trackPath = fullfile(traDir, 'man_track.txt');
rawFiles = dir(fullfile(seqDir, 't*.tif'));
maskFiles = dir(fullfile(traDir, 'man_track*.tif'));
if isempty(rawFiles)
    invalidExport('No tNNN.tif image was found in %s', seqDir);
end
if isempty(maskFiles)
    invalidExport('No man_trackNNN.tif mask was found in %s', traDir);
end
if numel(rawFiles) ~= numel(maskFiles)
    invalidExport('Image/mask frame counts differ for %s (%d images, %d masks)', ...
        seqName, numel(rawFiles), numel(maskFiles));
end
if exist(trackPath,'file') ~= 2
    invalidExport('CTC track table is missing: %s', trackPath);
end
try
    tracks = readmatrix(trackPath, 'FileType', 'text');
catch ME
    invalidExport('Unable to read %s: %s', trackPath, ME.message);
end
if isempty(tracks) || size(tracks,2) < 4 || any(~isfinite(tracks(:,1:4)),'all')
    invalidExport('CTC track table is empty or malformed: %s', trackPath);
end
tracks = double(tracks(:,1:4));
ids = tracks(:,1);
if any(ids < 1) || numel(unique(ids)) ~= numel(ids) || ...
        any(tracks(:,2) < 0) || any(tracks(:,3) < tracks(:,2))
    invalidExport('CTC track IDs or frame intervals are invalid: %s', trackPath);
end
for i = 1:size(tracks,1)
    parent = tracks(i,4);
    if parent == 0, continue; end
    parentIndex = find(ids == parent, 1);
    if isempty(parentIndex)
        invalidExport('Track %u references missing parent %u in %s', ids(i), parent, trackPath);
    end
    if tracks(parentIndex,3) >= tracks(i,2)
        invalidExport(['Track %u starts at t=%u while parent %u ends at t=%u in %s. ' ...
            'This export predates the budding-lineage CTC fix'], ...
            ids(i), tracks(i,2), parent, tracks(parentIndex,3), trackPath);
    end
end
end

function invalidExport(message, varargin)
detail = sprintf(message, varargin{:});
error('trackastra:InvalidFormattedDataset', ...
    '%s. Run trackastra.format (Format training set) again before training.', detail);
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
