function out = train(classif, ctx)
% cellposesam.train  Package entry point for CellposeSAM training.
%
% ctx.mode:
%   - 'init'  -> initialize training parameters
%   - 'train' -> run training

if nargin < 2 || isempty(ctx)
    ctx = struct();
end

out = cellposesam.utils.outInitSafe('cellposesam.train');

mode = "train";
if isfield(ctx,'mode') && ~isempty(ctx.mode)
    mode = string(ctx.mode);
end

if strcmpi(mode,"init") || strcmpi(mode,"setparam") || strcmpi(mode,"param")
    classif.trainingParam = cellposesam.utils.defaultTrainingParam();
    classif.classifierPkg = 'cellposesam';
    classif.trainingFun = 'cellposesam.train';
    classif.classifyFun = 'cellposesam.classify';
    classif.category = {'Pixel'};
    out.refs.trainingParam = classif.trainingParam;
    out.status = "OK";
    return;
end

if isempty(classif.trainingParam)
    classif.trainingParam = cellposesam.utils.defaultTrainingParam();
end
classif.classifierPkg = 'cellposesam';
classif.trainingFun = 'cellposesam.train';
classif.classifyFun = 'cellposesam.classify';
classif.category = {'Pixel'};

% Optional overrides from ctx.params
if isfield(ctx,'params') && isstruct(ctx.params) && ~isempty(ctx.params)
    classif.trainingParam = cellposesam.utils.applyParamOverrides(classif.trainingParam, ctx.params);
end

runCellposeTrain(classif, ctx);

out.status = "OK";
end

function runCellposeTrain(classif, ctx)
% Train a Cellpose/CellposeSAM model from a HDF5 framebank.

if nargin < 2 || isempty(ctx)
    ctx = struct();
end

trainingParam = classif.trainingParam;
if isempty(trainingParam)
    disp('Training parameters not set. Launch with cellposesam.train(..., mode=init) first.');
    return;
end

if ~isfield(trainingParam, 'verbose'),        trainingParam.verbose = true; end
if ~isfield(trainingParam, 'use_pretrained'), trainingParam.use_pretrained = true; end
if ~isfield(trainingParam, 'n_epochs'),       trainingParam.n_epochs = 5; end
if ~isfield(trainingParam, 'learning_rate'),  trainingParam.learning_rate = 1e-4; end
if ~isfield(trainingParam, 'weight_decay'),   trainingParam.weight_decay = 1e-5; end
if ~isfield(trainingParam, 'batch_size'),     trainingParam.batch_size = 1; end
if ~isfield(trainingParam, 'MaxTrainImages'), trainingParam.MaxTrainImages = 50; end
if ~isfield(trainingParam, 'Seed'),           trainingParam.Seed = 12345; end
if ~isfield(trainingParam, 'NegDownsampleTrainRatio'), trainingParam.NegDownsampleTrainRatio = 0; end
if ~isfield(trainingParam, 'CPSAM_ValFraction'), trainingParam.CPSAM_ValFraction = 0.2; end

% -------------------------------------------------------------------------
% Locate framebank (robust with *_framebank_XXX.h5)
% -------------------------------------------------------------------------
base = classif.path;
pattern = sprintf('%s_framebank*.h5', classif.strid);
d = dir(fullfile(base, pattern));

if isempty(d)
    error('Framebank HDF5 not found in %s with pattern %s. Run format first.', base, pattern);
end

[~, idxSort] = sort([d.datenum], 'descend');
d = d(idxSort);

framebank_path = '';
for k = 1:numel(d)
    cand = fullfile(base, d(k).name);
    try
        h5info(cand);
        framebank_path = cand;
        fprintf('[INFO] Using framebank file: %s (modified: %s)\n', framebank_path, d(k).date);
        break;
    catch ME
        warning('[WARN] HDF5 file %s seems corrupted/unreadable (%s), skipping...', cand, ME.message);
    end
end

if isempty(framebank_path)
    error('No usable HDF5 framebank found in %s for pattern %s (all candidates unreadable).', base, pattern);
end

% -------------------------------------------------------------------------
% External Python script + config
% -------------------------------------------------------------------------
scriptPath = fullfile(fileparts(mfilename('fullpath')), 'py', 'train_cellposesam.py');
if exist(scriptPath, 'file') ~= 2
    error('CellposeSAM python script not found: %s', scriptPath);
end

cfg = struct();
cfg.framebank_path = strrep(framebank_path, '\\', '/');
cfg.save_path      = strrep(classif.path, '\\', '/');
cfg.model_name     = classif.strid;
cfg.seed           = trainingParam.Seed;
cfg.use_pretrained = logical(trainingParam.use_pretrained);
cfg.verbose        = logical(trainingParam.verbose);
cfg.weight_decay   = trainingParam.weight_decay;
cfg.learning_rate  = trainingParam.learning_rate;
cfg.n_epochs       = trainingParam.n_epochs;
cfg.batch_size     = trainingParam.batch_size;

cfg.min_train_masks = 0;
if isfield(trainingParam, 'min_train_masks') && ~isempty(trainingParam.min_train_masks)
    cfg.min_train_masks = max(0, round(double(trainingParam.min_train_masks)));
end

configPath = fullfile(classif.path, 'train_cellposesam_config.json');
statusPath = fullfile(classif.path, 'train_cellposesam_status.json');
if exist(statusPath, 'file') == 2
    delete(statusPath);
end
cfg.status_path = strrep(statusPath, '\\', '/');
fid = fopen(configPath, 'w');
if fid == -1
    error('Unable to create Python config: %s', configPath);
end
fwrite(fid, jsonencode(cfg), 'char');
fclose(fid);

setenv('CPSAM_CONFIG', configPath);
disp(['[INFO] CellposeSAM train script: ' scriptPath]);
disp(['[INFO] CellposeSAM config: ' configPath]);

% -------------------------------------------------------------------------
% Python environment & execution
% -------------------------------------------------------------------------
try
    selectArgs = buildPythonSelectionArgsLocal(ctx);
    test = select_and_load_conda_env(selectArgs{:}); %#ok<NASGU>
catch ME
    msg = ME.message;
    if contains(msg, 'CondaToSNonInteractiveError') || contains(msg, 'Terms of Service')
        msg = [msg newline newline ...
            'Anaconda requires Terms of Service acceptance before DetecDiv can create the default env.' newline ...
            'Run the three "conda tos accept" commands shown above, then relaunch training.'];
    end
    error('cellposesam:PythonBootstrapFailed', ...
        'select_and_load_conda_env failed before training could start:%s%s', newline, msg);
end
cellposesam.utils.ensurePythonDeps(classif);

python_env = pyenv();
if strcmp(python_env.Status, 'NotLoaded')
    error('Python environment not loaded. Activate an environment before running this script.');
else
    disp(['[INFO] Active Python env: ' python_env.Executable]);
end

function args = buildPythonSelectionArgsLocal(ctx)
args = {'mode','default'};

pyCfg = struct();
try
    if isfield(ctx,'exec') && isstruct(ctx.exec) && isfield(ctx.exec,'python') && isstruct(ctx.exec.python)
        pyCfg = ctx.exec.python;
    end
catch
    pyCfg = struct();
end

if isempty(fieldnames(pyCfg))
    return;
end

mode = 'default';
try
    if isfield(pyCfg,'mode') && ~isempty(pyCfg.mode)
        mode = lower(strtrim(char(string(pyCfg.mode))));
    end
catch
    mode = 'default';
end

switch mode
    case 'custom'
        args = {'mode','custom'};
        try
            if isfield(pyCfg,'envName') && ~isempty(pyCfg.envName)
                args = [args, {'envName', char(string(pyCfg.envName))}];
            end
        catch
        end
        try
            if isfield(pyCfg,'envPath') && ~isempty(pyCfg.envPath)
                args = [args, {'envPath', char(string(pyCfg.envPath))}];
            end
        catch
        end
    otherwise
        args = {'mode','default'};
end
end

try
    runPythonTrainingWithCudaRecovery(scriptPath, selectArgs, classif, statusPath);
    disp('[OK] CellposeSAM training finished successfully.');
catch ME
    disp('[ERROR] during Python script execution.');
    disp(ME.message);
    rethrow(ME);
end
end

function runPythonTrainingWithCudaRecovery(scriptPath, selectArgs, classif, statusPath)
% Retry once after stale MATLAB/Python CUDA contexts have been released.
for attempt = 1:2
    try
        pyrunfile(scriptPath);
        return;
    catch ME
        if isPythonTerminatedAfterCompletedTraining(ME, statusPath)
            disp('[WARN] MATLAB Python host terminated after CellposeSAM saved the trained model.');
            disp('[WARN] Training is considered complete; the Python host will be restarted on the next Python call.');
            releaseMatlabGpuState();
            try
                terminate(pyenv);
            catch
            end
            return;
        end
        if attempt == 1 && isRecoverableCudaPyenvFailure(ME)
            disp('[WARN] CUDA memory failure detected during CellposeSAM training.');
            disp('[WARN] Releasing MATLAB GPU state and restarting MATLAB Python host, then retrying once...');
            releaseMatlabGpuState();
            restartPythonHost(selectArgs, classif);
            continue;
        end
        rethrow(ME);
    end
end
end

function tf = isPythonTerminatedAfterCompletedTraining(ME, statusPath)
msg = lower(string(ME.message));
id = lower(string(ME.identifier));
tf = contains(id, "pythonterminated") || contains(msg, "python process terminated unexpectedly");
if tf
    tf = trainingStatusShowsSuccess(statusPath);
end
end

function tf = trainingStatusShowsSuccess(statusPath)
tf = false;
if isempty(statusPath) || exist(statusPath, 'file') ~= 2
    return;
end

try
    status = jsondecode(fileread(statusPath));
catch
    return;
end

if ~isfield(status, 'status') || ~strcmpi(char(string(status.status)), 'OK')
    return;
end

paths = {};
if isfield(status, 'model_path') && ~isempty(status.model_path)
    paths{end+1} = char(string(status.model_path));
end
if isfield(status, 'best_model_path') && ~isempty(status.best_model_path)
    paths{end+1} = char(string(status.best_model_path));
end

for iPath = 1:numel(paths)
    if exist(paths{iPath}, 'file') == 2
        tf = true;
        return;
    end
end
end

function tf = isRecoverableCudaPyenvFailure(ME)
msg = lower(string(ME.message));
tf = contains(msg, "out of memory") || ...
     contains(msg, "persistent matlab/python cuda context") || ...
     contains(msg, "free gpu memory before relaunching training") || ...
     contains(msg, "cuda runtime test failed");
end

function releaseMatlabGpuState()
try
    g = gpuDevice();
    reset(g);
    disp('[INFO] MATLAB GPU device reset completed.');
catch ME
    fprintf('[WARN] MATLAB GPU reset failed or unavailable: %s\n', ME.message);
end
end

function restartPythonHost(selectArgs, classif)
try
    terminate(pyenv);
    disp('[INFO] MATLAB Python host terminated.');
catch ME
    fprintf('[WARN] terminate(pyenv) failed or was unnecessary: %s\n', ME.message);
end

try
    pause(1);
catch
end

try
    test = select_and_load_conda_env(selectArgs{:}); %#ok<NASGU>
catch ME
    error('cellposesam:PythonBootstrapFailedAfterCudaRecovery', ...
        'Unable to reload Python after CUDA recovery:%s%s', newline, ME.message);
end

cellposesam.utils.ensurePythonDeps(classif);
python_env = pyenv();
if strcmp(python_env.Status, 'NotLoaded')
    error('cellposesam:PythonNotLoadedAfterCudaRecovery', ...
        'Python environment was not loaded after CUDA recovery.');
end
disp(['[INFO] Active Python env after recovery: ' python_env.Executable]);
end
