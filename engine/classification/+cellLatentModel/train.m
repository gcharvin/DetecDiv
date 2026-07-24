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
if isempty(classif.executionParam)
    classif.executionParam = ...
        cellLatentModel.utils.defaultExecutionParam();
end
if isfield(ctx,'mode') && strcmpi(char(string(ctx.mode)),'init')
    out.refs.trainingParam = classif.trainingParam;
    out.refs.executionParam = classif.executionParam;
    return;
end
datasetDir = fullfile(classif.path,'trainingdataset','relation_dataset');
manifestFile = fullfile(datasetDir,'manifest.json');
if ~isfile(manifestFile) || ...
        ~isfile(fullfile(datasetDir,'relations.npz'))
    error('cellLatentModel:MissingFormattedDataset', ...
        'Format the imported ROI training set before training.');
end
manifest = jsondecode(fileread(manifestFile));
modalities = availableModalities(manifest);
modelName = safeName(tp.modelName);
modelDir = fullfile(classif.path,'models',modelName);
if exist(modelDir,'dir') ~= 7, mkdir(modelDir); end
configFile = fullfile(modelDir,'training_config.json');
stdoutFile = fullfile(modelDir,'training_stdout.txt');
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
writeJson(configFile,cfg);
detecdiv_check_cancel(ctx,'cellLatentModel before training');
runtime = cellLatentModel.utils.runPythonModule( ...
    'train-from-config',configFile,ctx,stdoutFile);
detecdiv_check_cancel(ctx,'cellLatentModel after training');
checkpoint = fullfile(modelDir,'ensemble.pt');
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
    fullfile('models',modelName,'ensemble.pt');
classif.executionParam.trackChannelName = ...
    char(string(tp.trackChannelName));
classif.executionParam.gfpChannelName = ...
    char(string(tp.gfpChannelName));
try classiSave(classif); catch ME
    warning('cellLatentModel:ClassifierSaveFailed', ...
        'Checkpoint trained, but classifier metadata was not saved: %s', ...
        ME.message);
end
out.artifacts.dataset = datasetDir;
out.artifacts.model = checkpoint;
out.artifacts.report = reportFile;
out.artifacts.config = configFile;
out.artifacts.stdout = stdoutFile;
out.metrics = report.metrics;
out.refs.modalities = modalities;
out.refs.executionParam = classif.executionParam;
out.refs.runtime = runtime;
out.status = "OK";
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
function writeJson(filename,value)
fid = fopen(filename,'w');
if fid < 0, error('cellLatentModel:ConfigWriteFailed','Cannot write %s.',filename); end
cleanup = onCleanup(@() fclose(fid));
fwrite(fid,jsonencode(value,'PrettyPrint',true),'char');
end
function value = normalizedPath(value)
value = strrep(char(string(value)),'\','/');
end
