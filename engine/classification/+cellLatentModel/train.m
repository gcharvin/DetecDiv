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
objective = trainingChoice(tp.trainingObjective,'relation_ensemble');
if isempty(classif.executionParam)
    classif.executionParam = ...
        cellLatentModel.utils.defaultExecutionParam();
end
if isfield(ctx,'mode') && strcmpi(char(string(ctx.mode)),'init')
    out.refs.trainingParam = classif.trainingParam;
    out.refs.executionParam = classif.executionParam;
    return;
end
if exist('detecdiv_progress','file') == 2
    detecdiv_progress(ctx,0,'Checking formatted latent training dataset...', ...
        'Scope','training');
end
if strcmp(objective,'continuous_lineage')
    datasetDir = fullfile(classif.path,'trainingdataset', ...
        'continuous_dataset');
else
    datasetDir = fullfile(classif.path,'trainingdataset','relation_dataset');
end
manifestFile = fullfile(datasetDir,'manifest.json');
if ~isfile(manifestFile) || ...
        (strcmp(objective,'relation_ensemble') && ...
         ~isfile(fullfile(datasetDir,'relations.npz')))
    error('cellLatentModel:MissingFormattedDataset', ...
        'Format the imported ROI training set before training.');
end
modelName = safeName(tp.modelName);
modelDir = fullfile(classif.path,'models',modelName);
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
    fullfile('models',modelName,checkpointName);
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
try classiSave(classif); catch ME
    warning('cellLatentModel:ClassifierSaveFailed', ...
        'Checkpoint trained, but classifier metadata was not saved: %s', ...
        ME.message);
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
fwrite(fid,jsonencode(value,'PrettyPrint',true),'char');
end
function value = normalizedPath(value)
value = strrep(char(string(value)),'\','/');
end
