function out = classify(roiobj, classif, ctx)
% cellposesam.classify  Package entry point for CellposeSAM inference.

if nargin < 3 || isempty(ctx)
    ctx = struct();
end

out = cellposesam.utils.outInitSafe('cellposesam.classify');

frames = [];
channels = [];
gpu = true;
outputName = '';
cancelPath = '';

if isfield(ctx,'sel') && isstruct(ctx.sel)
    if isfield(ctx.sel,'frames'),   frames   = ctx.sel.frames;   end
    if isfield(ctx.sel,'channels'), channels = ctx.sel.channels; end
end
if isfield(ctx,'exec') && isstruct(ctx.exec)
    if isfield(ctx.exec,'gpu'), gpu = ctx.exec.gpu; end
end
if isfield(ctx,'names') && isstruct(ctx.names)
    if isfield(ctx.names,'outputName'), outputName = ctx.names.outputName; end
end
if isfield(ctx,'cancel') && isstruct(ctx.cancel)
    if isfield(ctx.cancel,'tokenFile') && ~isempty(ctx.cancel.tokenFile)
        cancelPath = char(string(ctx.cancel.tokenFile));
    end
end

[data, image] = classifyCellposeInternal(roiobj, classif, frames, channels, gpu, outputName, cancelPath, ctx);

out.data = data;
out.image = image;
out.patch = [];
out.status = "OK";
end

function [data, image] = classifyCellposeInternal(roiobj, classif, frames, channel, gpu, outputName, cancelPath, ctx)
% Segmentation avec CellposeSAM sans tracking (optionnel : tracking basique hongrois)

if nargin < 6
    outputName = '';
end
if nargin < 7
    cancelPath = '';
end
if nargin < 8 || isempty(ctx)
    ctx = struct();
end
try
    disp('[DEBUG] cellposesam.classify: version=2026-02-06T13:10');
catch
end

if isempty(outputName)
    try
        outputName = classif.strid;
    catch
        outputName = '';
    end
end
outputName = char(string(outputName));
classNames = resolveClassNamesLocal(classif, ctx);
if isempty(classNames)
    classNames = {'cell'};
end
try
    if isobject(classif) && isprop(classif, 'classes')
        classif.classes = classNames;
    elseif isstruct(classif)
        classif.classes = classNames;
    end
catch
end

doTracking = true;

if isempty(frames)
    frames = 1:size(roiobj.image, 4);
end
try
    if isempty(roiobj.id)
        roiIdStr = '(id empty)';
    else
        roiIdStr = num2str(roiobj.id);
    end
catch
    roiIdStr = '(id unavailable)';
end
try
    disp(['[DEBUG] cellposesam.classify: ROI ' roiIdStr ' frames=' mat2str(frames)]);
catch
end

image = roiobj.image;
data  = roiobj.data;
if isempty(data)
    roiobj.load('data');
    data = roiobj.data;
end

pix = roiobj.findChannelID(channel);
if iscell(pix)
    pix = cell2mat(pix);
end

% --- Type de sortie demandee (robuste struct/class) ---
outputType = 'segmentation';
if isobject(classif) && isprop(classif, 'outputType') && ~isempty(classif.outputType)
    outputType = classif.outputType;
elseif isstruct(classif) && isfield(classif, 'outputType') && ~isempty(classif.outputType)
    outputType = classif.outputType;
end
if isfield(ctx, 'params') && isstruct(ctx.params)
    if isfield(ctx.params, 'outputType') && ~isempty(ctx.params.outputType)
        outputType = ctx.params.outputType;
    elseif isfield(ctx.params, 'outputMode') && ~isempty(ctx.params.outputMode)
        outputType = ctx.params.outputMode;
    end
end
outputType = lower(strrep(strrep(strtrim(char(string(outputType))), 'probability', 'proba'), ' ', '_'));

if ~any(strcmpi(outputType, {'proba','segmentation','both','postprocessing'}))
    warning('cellposesam.classify: outputType="%s" inconnu -> fallback segmentation', outputType);
    outputType = 'segmentation';
end
wantSegmentation = any(strcmpi(outputType, {'segmentation','both','postprocessing'}));
wantProbability = any(strcmpi(outputType, {'proba','both'}));

% --- Channels results (instance mask) ---
pixresults = [];
for i = 1:numel(classNames)
    chName = ['results_' outputName '_' classNames{i}];
    pixresultstmp = findChannelID(roiobj, chName);
    if isempty(pixresultstmp)
        matrix = uint16(zeros(size(image,1), size(image,2), 1, size(image,4)));
        rgb = [1 1 1];
        intensity = [0 0 0]; % indexed mask
        roiobj.addChannel(matrix, chName, rgb, intensity);
        pixresultstmp = findChannelID(roiobj, chName);
    end
    pixresults = [pixresults pixresultstmp]; %#ok<AGROW>
end
if isempty(pixresults)
    error('cellposesam.classify: impossible de determiner/ajouter un channel results_* pour %s', safeClassifierIdLocal(classif));
end
pixresults = pixresults(1);

% refresh local image after channel creation
image = roiobj.image;

% Try to auto-select the results channel for display
try
    if isprop(roiobj, 'channelid') && ~isempty(roiobj.channelid)
        logIdx = roiobj.channelid(pixresults);
        localConfigureIndexedAnnotationDisplay(roiobj, logIdx);
    end
catch
end

% Preparation des images pour CellposeSAM
if isempty(pix)
    error('cellposesam.classify: input channel not found.');
end

gfp = uint8(zeros(size(image, 1), size(image, 2), numel(pix), numel(frames)));
for i = 1:numel(frames)
    tmp = image(:, :, pix, frames(i));
    gfp(:, :, :, i) = uint8(255 * mat2gray(tmp));
end
try
    disp(['[DEBUG] cellposesam.classify: gfp size=' mat2str(size(gfp)) ' frames_len=' num2str(numel(frames))]);
    if ~isempty(frames)
        disp(['[DEBUG] cellposesam.classify: frames min=' num2str(min(frames)) ' max=' num2str(max(frames))]);
    end
catch
end

tmp_mat_path = fullfile(classif.path, 'tmp.mat');
save(tmp_mat_path, 'gfp', 'frames');
try
    infoTmp = dir(tmp_mat_path);
    if ~isempty(infoTmp)
        disp(['[DEBUG] cellposesam.classify: tmp.mat bytes=' num2str(infoTmp.bytes) ' date=' infoTmp.date]);
    end
catch
end

% Parameters. Pipeline static params override the linked classifier defaults.
diameter = getCellposeParamLocal(ctx, classif, 'diameter', NaN);
flow_threshold = getCellposeParamLocal(ctx, classif, 'flow_threshold', 0.4);
min_size = getCellposeParamLocal(ctx, classif, 'min_size', 10);
cellprob_threshold = getCellposeParamLocal(ctx, classif, 'cell_prob_threshold', 0);

% Model selection
model_dir          = fullfile(classif.path, 'models');
model_path_to_use  = 'sam';
if exist(model_dir, 'dir')
    candidate1 = fullfile(model_dir, classif.strid);
    candidate2 = [candidate1 '.pth'];
    if exist(candidate1, 'file')
        model_path_to_use = candidate1;
    elseif exist(candidate2, 'file')
        model_path_to_use = candidate2;
    end
end

if strcmp(model_path_to_use, 'sam')
    disp('[INFO] Aucun modele local trouve, utilisation du modele CellposeSAM par defaut.');
else
    disp(['[INFO] Modele local trouve et utilise : ' model_path_to_use]);
end

% Output mode
if wantProbability
    mode_str = 'proba';
else
    mode_str = 'segmentation';
end

scriptPath = fullfile(fileparts(mfilename('fullpath')), 'py', 'classify_cellposesam.py');
if exist(scriptPath, 'file') ~= 2
    error('CellposeSAM python script not found: %s', scriptPath);
end
runnerPath = fullfile(fileparts(mfilename('fullpath')), 'py', 'cellposesam_runner.py');

cfg = struct();
cfg.tmp_mat_path = strrep(tmp_mat_path, '\\', '/');
cfg.classif_path = strrep(classif.path, '\\', '/');
cfg.model_path   = strrep(model_path_to_use, '\\', '/');
cfg.gpu          = logical(gpu);
cfg.diameter     = diameter;
cfg.flow_threshold = flow_threshold;
cfg.cell_prob_threshold = cellprob_threshold;
cfg.min_size     = round(min_size);
cfg.mode         = mode_str;
cfg.cancel_path  = char(string(cancelPath));
cfg.log_path     = strrep(fullfile(classif.path, 'runner_live.log'), '\\', '/');

configPath = fullfile(classif.path, 'classify_cellposesam_config.json');
fid = fopen(configPath, 'w');
if fid == -1
    error('Unable to create Python config: %s', configPath);
end
fwrite(fid, jsonencode(cfg), 'char');
fclose(fid);

setenv('CPSAM_CONFIG', configPath);
disp(['[INFO] CellposeSAM classify script: ' scriptPath]);
disp(['[INFO] CellposeSAM config: ' configPath]);
if ~isempty(cancelPath) && exist(cancelPath, 'file') == 2
    error('runPipeline:Cancelled', 'Pipeline run cancelled by user before CellposeSAM execution.');
end
try
    disp(['[DEBUG] cellposesam.classify: cfg.tmp_mat_path=' cfg.tmp_mat_path]);
    disp(['[DEBUG] cellposesam.classify: cfg.classif_path=' cfg.classif_path]);
    disp(['[DEBUG] cellposesam.classify: cfg.model_path=' cfg.model_path]);
    infoCfg = dir(configPath);
    if ~isempty(infoCfg)
        disp(['[DEBUG] cellposesam.classify: config bytes=' num2str(infoCfg.bytes) ' date=' infoCfg.date]);
    end
catch
end

% test the existence of python environment
selectArgs = buildPythonSelectionArgsLocal(ctx, classif);
test = select_and_load_conda_env(selectArgs{:}); %#ok<NASGU>
cellposesam.utils.ensurePythonDeps(classif);

% Run the Python routine either in the current pyenv session, so the Python
% module can keep its model cache alive across ROI calls, or as the legacy
% external process when requested/fallback is needed.
pe = pyenv;
pythonExe = char(pe.Executable);
stdoutPath = fullfile(classif.path, 'runner_stdout.txt');
stderrPath = fullfile(classif.path, 'runner_stderr.txt');
liveLogPath = fullfile(classif.path, 'runner_live.log');
runnerMode = resolveCellposeRunnerModeLocal(ctx);
runnerFallback = resolveCellposeRunnerFallbackLocal(ctx, runnerMode);
disp(['[DEBUG] cellposesam: runner mode=' runnerMode]);
tRun = tic;
runCellposeRunnerSelected(runnerMode, runnerFallback, pythonExe, runnerPath, configPath, classif.path, cancelPath, stdoutPath, stderrPath, liveLogPath);
runSec = toc(tRun);
disp(['[DEBUG] cellposesam.classify: runner time=' num2str(runSec, '%.3f') 's']);

% If results.mat missing, force reload + retry once
resultsPath = fullfile(classif.path, 'results.mat');
try
    disp(['[DEBUG] cellposesam.classify: results.mat exists after runner? ' num2str(exist(resultsPath,'file'))]);
catch
end
if exist(resultsPath, 'file') ~= 2
    disp('[WARN] cellposesam.classify: results.mat missing after runner; retrying once...');
    try
        tRun = tic;
        runCellposeRunnerSelected(runnerMode, runnerFallback, pythonExe, runnerPath, configPath, classif.path, cancelPath, stdoutPath, stderrPath, liveLogPath);
        runSec = toc(tRun);
        disp(['[DEBUG] cellposesam.classify: retry runner time=' num2str(runSec, '%.3f') 's']);
    catch ME
        error('cellposesam_runner retry failed: %s', ME.message);
    end
end
try
    infoRes = dir(fullfile(classif.path, 'results.mat'));
    if ~isempty(infoRes)
        disp(['[DEBUG] cellposesam.classify: results.mat bytes=' num2str(infoRes.bytes) ' date=' infoRes.date]);
    end
catch
end
if exist(fullfile(classif.path, 'results.mat'), 'file') ~= 2
    try
        stampPath = fullfile(classif.path, 'runner_stamp.txt');
        if exist(stampPath, 'file') == 2
            disp('[DEBUG] cellposesam.classify: runner_stamp.txt exists');
            disp(fileread(stampPath));
        else
            disp('[DEBUG] cellposesam.classify: runner_stamp.txt missing');
        end
        d = dir(fullfile(classif.path, '*results*'));
        if ~isempty(d)
            disp('[DEBUG] cellposesam.classify: files matching *results* in classif.path:');
            for k = 1:numel(d)
                disp(['  ' d(k).name]);
            end
        end
    catch
    end
end

% Read results
res = load(fullfile(classif.path, 'results.mat'));
frames_list = res.frames_list;
try
    disp(['[DEBUG] cellposesam.classify: results loaded frames=' num2str(numel(frames_list))]);
catch
end

if ~isfield(res, 'masks_all')
    error('cellposesam.classify: no masks_all found in results.mat.');
end

tmpout = res.masks_all;
try
    disp(['[DEBUG] cellposesam.classify: masks_all size=' mat2str(size(tmpout))]);
catch
end

% Normalize IDs per frame
for f = 1:size(tmpout, 4)
    labels = unique(tmpout(:,:,1,f));
    labels(labels == 0) = [];
    new_frame = zeros(size(tmpout(:,:,1,f)), 'uint16');
    for k = 1:numel(labels)
        new_frame(tmpout(:,:,1,f) == labels(k)) = uint16(k);
    end
    tmpout(:,:,1,f) = new_frame;
end

if doTracking
    tmpout = trackMasksHungarian(tmpout);
end

if wantSegmentation
    image(:,:,pixresults, frames_list) = tmpout;
    localConfigureIndexedAnnotationDisplay(roiobj, roiobj.channelid(pixresults));
    disp('Masques CellposeSAM integres dans image.');
end

if wantProbability
    if ~isfield(res, 'cellprob_all')
        error('cellposesam.classify: outputType=%s mais results.mat ne contient pas cellprob_all.', outputType);
    end

    chNameProba = [outputName '_cellprob'];
    if isfield(ctx, 'params') && isstruct(ctx.params) && isfield(ctx.params, 'probabilityOutputName') && ~isempty(ctx.params.probabilityOutputName)
        chNameProba = char(string(ctx.params.probabilityOutputName));
    end
    pixproba = findChannelID(roiobj, chNameProba);
    if isempty(pixproba)
        matrix = zeros(size(image,1), size(image,2), 1, size(image,4), 'like', image);
        roiobj.addChannel(matrix, chNameProba, [1 1 1], [0 0 65535]);
        image = roiobj.image;
        pixproba = findChannelID(roiobj, chNameProba);
        if isempty(pixproba)
            error('cellposesam.classify: impossible de creer le channel proba "%s".', chNameProba);
        end
    end

    tmpproba = res.cellprob_all;

    lo = -5; hi = 5;
    tmpproba_clipped = min(max(tmpproba, lo), hi);

    if isinteger(image)
        proba_scaled = mat2gray(tmpproba_clipped, [lo hi]);
        proba_scaled = uint16(65535 * proba_scaled);
        image(:,:,pixproba, frames_list) = proba_scaled;
    else
        image(:,:,pixproba, frames_list) = tmpproba_clipped;
    end

    disp('? Carte de probabilite CellposeSAM integree (channel *_cellprob).');
end
end

function value = getCellposeParamLocal(ctx, classif, name, defaultValue)
value = defaultValue;
try
    if isobject(classif) && isprop(classif, 'trainingParam') && isstruct(classif.trainingParam) && ...
            isfield(classif.trainingParam, name) && ~isempty(classif.trainingParam.(name))
        value = classif.trainingParam.(name);
    elseif isstruct(classif) && isfield(classif, 'trainingParam') && isstruct(classif.trainingParam) && ...
            isfield(classif.trainingParam, name) && ~isempty(classif.trainingParam.(name))
        value = classif.trainingParam.(name);
    end
catch
    value = defaultValue;
end
try
    if isfield(ctx, 'params') && isstruct(ctx.params) && isfield(ctx.params, name) && ~isempty(ctx.params.(name))
        value = ctx.params.(name);
    end
catch
end
end

function args = buildPythonSelectionArgsLocal(ctx, classif)
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
                args = [args, {'envName', char(string(pyCfg.envName))}]; %#ok<AGROW>
            end
        catch
        end
        try
            if isfield(pyCfg,'envPath') && ~isempty(pyCfg.envPath)
                args = [args, {'envPath', char(string(pyCfg.envPath))}]; %#ok<AGROW>
            end
        catch
        end
    otherwise
        args = {'mode','default'};
end
end

function localConfigureIndexedAnnotationDisplay(roiobj, logIdx)
if ~isprop(roiobj, 'display') || ~isstruct(roiobj.display)
    return;
end

nLog = max(double(logIdx), numel(roiobj.display.channel));

if ~isfield(roiobj.display,'selectedchannel') || isempty(roiobj.display.selectedchannel)
    roiobj.display.selectedchannel = zeros(1, nLog);
elseif numel(roiobj.display.selectedchannel) < nLog
    roiobj.display.selectedchannel(end+1:nLog) = 0;
end

if ~isfield(roiobj.display,'indexed') || isempty(roiobj.display.indexed)
    roiobj.display.indexed = zeros(1, nLog);
elseif numel(roiobj.display.indexed) < nLog
    roiobj.display.indexed(end+1:nLog) = 0;
end

if ~isfield(roiobj.display,'alpha') || isempty(roiobj.display.alpha)
    roiobj.display.alpha = ones(1, nLog);
elseif numel(roiobj.display.alpha) < nLog
    roiobj.display.alpha(end+1:nLog) = 1;
end

if ~isfield(roiobj.display,'contour') || isempty(roiobj.display.contour)
    roiobj.display.contour = zeros(1, nLog);
elseif numel(roiobj.display.contour) < nLog
    roiobj.display.contour(end+1:nLog) = 0;
end

if ~isfield(roiobj.display,'width') || isempty(roiobj.display.width)
    roiobj.display.width = ones(1, nLog);
elseif numel(roiobj.display.width) < nLog
    roiobj.display.width(end+1:nLog) = 1;
end

if ~isfield(roiobj.display,'intensity') || isempty(roiobj.display.intensity)
    roiobj.display.intensity = ones(nLog, 3);
elseif size(roiobj.display.intensity,1) < nLog
    roiobj.display.intensity(end+1:nLog,:) = 1;
end

if ~isfield(roiobj.display,'rgb') || isempty(roiobj.display.rgb)
    roiobj.display.rgb = ones(nLog, 3);
elseif size(roiobj.display.rgb,1) < nLog
    roiobj.display.rgb(end+1:nLog,:) = 1;
end

roiobj.display.selectedchannel(logIdx) = 1;
roiobj.display.indexed(logIdx) = 1;
roiobj.display.contour(logIdx) = 1;
roiobj.display.intensity(logIdx,:) = [0 0 0];
roiobj.display.rgb(logIdx,:) = [1 1 1];

if roiobj.display.alpha(logIdx) <= 0 || roiobj.display.alpha(logIdx) > 0.5
    roiobj.display.alpha(logIdx) = 0.35;
end
if roiobj.display.width(logIdx) <= 0
    roiobj.display.width(logIdx) = 1.5;
end
end

function mode = resolveCellposeRunnerModeLocal(ctx)
mode = 'external';
explicitMode = false;
try
    if isstruct(ctx) && isfield(ctx,'exec') && isstruct(ctx.exec) && ...
            isfield(ctx.exec,'python') && isstruct(ctx.exec.python)
        pyCfg = ctx.exec.python;
        if isfield(pyCfg,'cellposesamRunner') && ~isempty(pyCfg.cellposesamRunner)
            mode = lower(strtrim(char(string(pyCfg.cellposesamRunner))));
            explicitMode = true;
        elseif isfield(pyCfg,'modelCache') && ~isempty(pyCfg.modelCache)
            cacheMode = lower(strtrim(char(string(pyCfg.modelCache))));
            if any(strcmp(cacheMode, {'session','persistent','pyenv'}))
                mode = 'session';
            end
        end
    end
    if ~explicitMode && isstruct(ctx) && isfield(ctx,'pipeline') && isstruct(ctx.pipeline)
        mode = 'session';
    end
catch
    mode = 'external';
end
if any(strcmp(mode, {'inprocess','in_process','pyenv','persistent'}))
    mode = 'session';
elseif any(strcmp(mode, {'session_strict','strict_session'}))
    mode = 'session';
elseif ~strcmp(mode, 'session')
    mode = 'external';
end
end

function fallback = resolveCellposeRunnerFallbackLocal(ctx, runnerMode)
fallback = strcmpi(runnerMode, 'session');
try
    if ~(isstruct(ctx) && isfield(ctx,'exec') && isstruct(ctx.exec) && ...
            isfield(ctx.exec,'python') && isstruct(ctx.exec.python))
        return;
    end
    pyCfg = ctx.exec.python;
    if isfield(pyCfg,'cellposesamRunner') && ~isempty(pyCfg.cellposesamRunner)
        rawMode = lower(strtrim(char(string(pyCfg.cellposesamRunner))));
        if any(strcmp(rawMode, {'session_strict','strict_session'}))
            fallback = false;
            return;
        end
    end
    if isfield(pyCfg,'cellposesamFallbackExternal') && ~isempty(pyCfg.cellposesamFallbackExternal)
        fallback = parseLogicalScalarLocal(pyCfg.cellposesamFallbackExternal, fallback);
    elseif isfield(pyCfg,'fallbackExternal') && ~isempty(pyCfg.fallbackExternal)
        fallback = parseLogicalScalarLocal(pyCfg.fallbackExternal, fallback);
    end
catch
    fallback = strcmpi(runnerMode, 'session');
end
end

function value = parseLogicalScalarLocal(rawValue, defaultValue)
value = defaultValue;
try
    if islogical(rawValue) || isnumeric(rawValue)
        value = logical(rawValue(1));
        return;
    end
    text = lower(strtrim(char(string(rawValue))));
    if any(strcmp(text, {'true','1','yes','y','on'}))
        value = true;
    elseif any(strcmp(text, {'false','0','no','n','off'}))
        value = false;
    end
catch
    value = defaultValue;
end
end

function runCellposeRunnerSelected(mode, fallbackExternal, pythonExe, runnerPath, configPath, classifPath, cancelPath, stdoutPath, stderrPath, liveLogPath)
if strcmpi(mode, 'session')
    try
        runCellposeRunnerInProcess(runnerPath, configPath, cancelPath);
    catch ME
        if strcmp(ME.identifier, 'runPipeline:Cancelled') || ~fallbackExternal
            rethrow(ME);
        end
        disp(['[WARN] cellposesam: session runner failed, falling back to external process: ' ME.message]);
        runCellposeRunnerProcess(pythonExe, runnerPath, configPath, classifPath, cancelPath, stdoutPath, stderrPath, liveLogPath);
    end
else
    runCellposeRunnerProcess(pythonExe, runnerPath, configPath, classifPath, cancelPath, stdoutPath, stderrPath, liveLogPath);
end
end

function runCellposeRunnerInProcess(runnerPath, configPath, cancelPath)
persistent runnerMod runnerPathCached
if ~isempty(cancelPath) && exist(cancelPath, 'file') == 2
    error('runPipeline:Cancelled', 'Pipeline run cancelled by user before CellposeSAM execution.');
end
try
    runnerDir = fileparts(runnerPath);
    if isempty(runnerMod) || isempty(runnerPathCached) || ~strcmp(runnerPathCached, runnerPath)
        py.importlib.import_module('sys');
        py.sys.path().insert(int32(0), runnerDir);
        runnerMod = py.importlib.import_module('cellposesam_runner');
        runnerPathCached = runnerPath;
    end
    runnerMod.run(configPath);
catch ME
    if ~isempty(cancelPath) && exist(cancelPath, 'file') == 2
        error('runPipeline:Cancelled', 'Pipeline run cancelled by user during CellposeSAM execution.');
    end
    rethrow(ME);
end
end

function runCellposeRunnerProcess(pythonExe, runnerPath, configPath, classifPath, cancelPath, stdoutPath, stderrPath, liveLogPath)
if exist(stdoutPath, 'file') == 2
    delete(stdoutPath);
end
if exist(stderrPath, 'file') == 2
    delete(stderrPath);
end
if exist(liveLogPath, 'file') == 2
    delete(liveLogPath);
end

[exitCode, runnerOut] = runCellposeRunnerBackground(pythonExe, runnerPath, configPath, classifPath, cancelPath, stdoutPath, stderrPath, liveLogPath);

runnerErr = '';

if exitCode ~= 0
    if ~isempty(cancelPath) && exist(cancelPath, 'file') == 2
        error('runPipeline:Cancelled', 'Pipeline run cancelled by user during CellposeSAM execution.');
    end
    try
        errPath = fullfile(classifPath, 'runner_error.txt');
        if exist(errPath, 'file') == 2
            extra = fileread(errPath);
            if ~isempty(strtrim(extra))
                runnerErr = strtrim(string(runnerErr) + newline + extra);
            end
        end
    catch
    end
    try
        if strlength(strtrim(string(runnerErr))) == 0 && exist(stderrPath, 'file') == 2
            extra = fileread(stderrPath);
            if ~isempty(strtrim(extra))
                runnerErr = strtrim(string(runnerErr) + newline + extra);
            end
        end
    catch
    end
    try
        if strlength(strtrim(string(runnerErr))) == 0 && ~isempty(strtrim(runnerOut))
            runnerErr = strtrim(runnerOut);
        end
    catch
    end
    if strlength(strtrim(string(runnerErr))) == 0
        runnerErr = sprintf('Python runner exited with code %d.', exitCode);
    end
    error('cellposesam_runner failed: %s', char(string(runnerErr)));
end
end

function [exitCode, runnerOut] = runCellposeRunnerBackground(pythonExe, runnerPath, configPath, classifPath, cancelPath, stdoutPath, stderrPath, liveLogPath)
statusPath = fullfile(classifPath, 'runner_status.txt');
if exist(statusPath, 'file') == 2
    delete(statusPath);
end
if exist(stdoutPath, 'file') == 2
    delete(stdoutPath);
end
if exist(stderrPath, 'file') == 2
    delete(stderrPath);
end
if exist(liveLogPath, 'file') == 2
    delete(liveLogPath);
end

if ~isempty(cancelPath) && exist(cancelPath, 'file') == 2
    error('runPipeline:Cancelled', 'Pipeline run cancelled by user before CellposeSAM execution.');
end

if ispc
    cmd = sprintf('"%s" -u "%s" "%s" > "%s" 2> "%s"', ...
        pythonExe, runnerPath, configPath, stdoutPath, stderrPath);
else
    cmd = sprintf('"%s" -u "%s" "%s" > "%s" 2> "%s"', ...
        pythonExe, runnerPath, configPath, stdoutPath, stderrPath);
end
[exitCode, runnerOut] = system(cmd);

try
    fid = fopen(statusPath, 'w');
    if fid ~= -1
        fprintf(fid, '%d', exitCode);
        fclose(fid);
    end
catch
end

localFlushRunnerLog(liveLogPath, 0);
end

function out = localShellQuote(value)
text = char(string(value));
if ispc
    out = ['"' strrep(text, '"', '\"') '"'];
else
    out = ['''' strrep(text, '''', '''"''"''') ''''];
end
end

function out = localCmdQuote(value)
text = char(string(value));
out = ['"' strrep(text, '"', '""') '"'];
end

function out = localPowerShellQuote(value)
text = char(string(value));
out = ['''' strrep(text, '''', '''''') ''''];
end

function pid = localReadPid(pidPath)
pid = '';
try
    if exist(pidPath, 'file') == 2
        pid = strtrim(fileread(pidPath));
    end
catch
    pid = '';
end
end

function code = localReadExitCode(statusPath)
code = 1;
try
    if exist(statusPath, 'file') == 2
        txt = strtrim(fileread(statusPath));
        val = str2double(txt);
        if ~isnan(val)
            code = val;
        end
    end
catch
    code = 1;
end
end

function tf = localProcessExists(pid)
tf = false;
try
    if isempty(pid)
        return;
    end
    if ispc
        [status, ~] = system(sprintf('powershell.exe -NoProfile -Command "if (Get-Process -Id %s -ErrorAction SilentlyContinue) { exit 0 } else { exit 1 }"', pid));
    else
        [status, ~] = system(sprintf('kill -0 %s 2>/dev/null', pid));
    end
    tf = status == 0;
catch
    tf = false;
end
end

function localKillProcess(pid)
try
    if isempty(pid)
        return;
    end
    if ispc
        system(sprintf('powershell.exe -NoProfile -Command "Stop-Process -Id %s -Force -ErrorAction SilentlyContinue"', pid));
    else
        system(sprintf('kill %s 2>/dev/null', pid));
        pause(1);
        [status, ~] = system(sprintf('kill -0 %s 2>/dev/null', pid));
        if status == 0
            system(sprintf('kill -9 %s 2>/dev/null', pid));
        end
    end
catch
end
end

function localFlushRunnerLog(logPath, alreadyPrintedBytes)
try
    if exist(logPath, 'file') ~= 2
        return;
    end
    txt = fileread(logPath);
    n = numel(txt);
    startIdx = max(1, alreadyPrintedBytes + 1);
    if n >= startIdx
        delta = txt(startIdx:n);
        if ~isempty(delta)
            fprintf('%s', delta);
        end
    end
catch
end
end

function n = localFileBytes(p)
n = 0;
try
    info = dir(p);
    if ~isempty(info)
        n = info.bytes;
    end
catch
end
end

function names = resolveClassNamesLocal(classif, ctx)
names = {};
raw = {};
try
    if isobject(classif) && isprop(classif, 'classes') && ~isempty(classif.classes)
        raw = classif.classes;
    elseif isstruct(classif) && isfield(classif, 'classes') && ~isempty(classif.classes)
        raw = classif.classes;
    end
catch
    raw = {};
end
if isempty(raw) && isfield(ctx, 'params') && isstruct(ctx.params)
    keys = {'classes','classNames','className','labels'};
    for k = 1:numel(keys)
        key = keys{k};
        if isfield(ctx.params, key) && ~isempty(ctx.params.(key))
            raw = ctx.params.(key);
            break;
        end
    end
end

if isstring(raw)
    raw = cellstr(raw);
elseif ischar(raw)
    raw = {raw};
elseif ~iscell(raw)
    raw = {};
end

for i = 1:numel(raw)
    try
        value = strtrim(char(string(raw{i})));
        if ~isempty(value)
            names{end+1} = value; %#ok<AGROW>
        end
    catch
    end
end
names = unique(names, 'stable');
end

function id = safeClassifierIdLocal(classif)
id = '';
try
    if isobject(classif) && isprop(classif, 'strid') && ~isempty(classif.strid)
        id = char(string(classif.strid));
    elseif isstruct(classif) && isfield(classif, 'strid') && ~isempty(classif.strid)
        id = char(string(classif.strid));
    end
catch
    id = '';
end
if isempty(id)
    id = '<classifier>';
end
end

function tracked_masks = trackMasksHungarian(masks4D)
% Hongrois + distance gating ; next_id strictement monotone

[H, W, ~, num_frames] = size(masks4D);
tracked_masks = masks4D;

ids_f1 = unique(masks4D(:,:,1,1)); ids_f1(ids_f1==0) = [];
if isempty(ids_f1)
    next_id = uint16(1);
else
    next_id = uint16(max(ids_f1) + 1);
end

for t = 1:(num_frames-1)
    mask_t  = tracked_masks(:,:,1,t);
    mask_t1 = masks4D(:,:,1,t+1);

    labels_t  = unique(mask_t);  labels_t(labels_t==0) = [];
    labels_t1 = unique(mask_t1); labels_t1(labels_t1==0) = [];

    if isempty(labels_t) || isempty(labels_t1)
        tracked_masks(:,:,1,t+1) = mask_t1;
        continue;
    end

    areas_t  = arrayfun(@(id) sum(mask_t(:)  == id), labels_t);
    areas_t1 = arrayfun(@(id) sum(mask_t1(:) == id), labels_t1);

    cent_t  = zeros(numel(labels_t),  2);
    cent_t1 = zeros(numel(labels_t1), 2);
    for iL = 1:numel(labels_t)
        [yy, xx] = find(mask_t == labels_t(iL));
        cent_t(iL,:) = [mean(xx), mean(yy)];
    end
    for jL = 1:numel(labels_t1)
        [yy, xx] = find(mask_t1 == labels_t1(jL));
        cent_t1(jL,:) = [mean(xx), mean(yy)];
    end

    diam_t  = sqrt(4*areas_t  / pi);
    diam_t1 = sqrt(4*areas_t1 / pi);
    med_diam = median([diam_t(:); diam_t1(:)]);
    if isempty(med_diam) || ~isfinite(med_diam) || med_diam==0
        med_diam = min(H,W)/20;
    end
    gate_factor = 3.0;
    dmax = gate_factor * med_diam;

    D = zeros(numel(labels_t), numel(labels_t1));
    for iL = 1:numel(labels_t)
        dx = cent_t1(:,1) - cent_t(iL,1);
        dy = cent_t1(:,2) - cent_t(iL,2);
        D(iL,:) = sqrt(dx.^2 + dy.^2);
    end

    big = 1e6;
    costMat = big * ones(numel(labels_t), numel(labels_t1));
    for iL = 1:numel(labels_t)
        bin_i = (mask_t == labels_t(iL));
        Ai = areas_t(iL);
        for jL = 1:numel(labels_t1)
            if D(iL,jL) > dmax
                continue;
            end
            bin_j = (mask_t1 == labels_t1(jL));
            inter = sum(bin_i(:) & bin_j(:));
            uni   = sum(bin_i(:) | bin_j(:));
            iou = (uni==0) * 0 + (uni>0) * (inter/uni);

            mean_size_pair = (Ai + areas_t1(jL)) / 2;
            size_diff = abs(Ai - areas_t1(jL)) / max(1, mean_size_pair);

            dist_term = 0.2 * (D(iL,jL) / dmax);

            costMat(iL,jL) = (1 - iou) + 0.5*size_diff + dist_term;
        end
    end

    maxAcceptableCost = 1.6;
    [assignments, ~, unassigned_t1] = matchpairs(costMat, maxAcceptableCost);

    mask_new_t1 = zeros(size(mask_t1), 'uint16');

    for a = 1:size(assignments,1)
        id_t  = labels_t(assignments(a,1));
        id_t1 = labels_t1(assignments(a,2));
        mask_new_t1(mask_t1 == id_t1) = id_t;
    end

    for j = unassigned_t1'
        id_t1 = labels_t1(j);
        mask_new_t1(mask_t1 == id_t1) = next_id;
        next_id = next_id + 1;
    end

    tracked_masks(:,:,1,t+1) = mask_new_t1;
end
end
