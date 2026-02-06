function out = classify(roiobj, classif, ctx)
% cellposesam.classify  Package entry point for CellposeSAM inference.

if nargin < 3 || isempty(ctx)
    ctx = struct();
end

out = cellposesam.utils.outInitSafe('cellposesam.classify');
persistent runnerMod runnerPathCached

frames = [];
channels = [];
gpu = 0;
outputName = '';

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

[data, image] = classifyCellposeInternal(roiobj, classif, frames, channels, gpu, outputName);

out.data = data;
out.image = image;
out.patch = [];
out.status = "OK";
end

function [data, image] = classifyCellposeInternal(roiobj, classif, frames, channel, gpu, outputName)
% Segmentation avec CellposeSAM sans tracking (optionnel : tracking basique hongrois)
persistent runnerNS runnerPathCached

if nargin < 6
    outputName = '';
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

if ~any(strcmpi(outputType, {'proba','segmentation','postprocessing'}))
    warning('cellposesam.classify: outputType="%s" inconnu -> fallback segmentation', outputType);
    outputType = 'segmentation';
end

% --- Channels results (instance mask) ---
pixresults = [];
for i = 1:numel(classif.classes)
    chName = ['results_' outputName '_' classif.classes{i}];
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
    error('cellposesam.classify: impossible de determiner/ajouter un channel results_* pour %s', classif.strid);
end
pixresults = pixresults(1);

% refresh local image after channel creation
image = roiobj.image;

% Try to auto-select the results channel for display
try
    if isfield(roiobj, 'channelid') && ~isempty(roiobj.channelid)
        logIdx = roiobj.channelid(pixresults);
        if isfield(roiobj, 'display') && isstruct(roiobj.display)
            if ~isfield(roiobj.display,'selectedchannel') || isempty(roiobj.display.selectedchannel)
                roiobj.display.selectedchannel = zeros(1, numel(roiobj.display.channel));
            end
            roiobj.display.selectedchannel(:) = 0;
            if numel(roiobj.display.selectedchannel) < logIdx
                roiobj.display.selectedchannel(logIdx) = 1;
            else
                roiobj.display.selectedchannel(logIdx) = 1;
            end
            if isfield(roiobj.display,'indexed') && numel(roiobj.display.indexed) >= logIdx
                roiobj.display.indexed(logIdx) = 1;
            end
        end
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

% Parameters
if isfield(classif.trainingParam, 'diameter')
    diameter = classif.trainingParam.diameter;
else
    diameter = NaN;
end

if isfield(classif.trainingParam, 'flow_threshold')
    flow_threshold = classif.trainingParam.flow_threshold;
else
    flow_threshold = 0.4;
end

if isfield(classif.trainingParam, 'min_size') && ~isempty(classif.trainingParam.min_size)
    min_size = classif.trainingParam.min_size;
else
    min_size = 10;
end
if isfield(classif.trainingParam, 'cell_prob_threshold') && ~isempty(classif.trainingParam.cell_prob_threshold)
    cellprob_threshold = classif.trainingParam.cell_prob_threshold;
else
    cellprob_threshold = 0;
end

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
if strcmpi(outputType, 'proba')
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
test = select_and_load_conda_env('classif', classif); %#ok<NASGU>
cellposesam.utils.ensurePythonDeps(classif);

% run python routine (prefer persistent module)
didRun = false;
try
    pyPath = fileparts(runnerPath);
    if count(py.sys.path, pyPath) == 0
        insert(py.sys.path, int32(0), pyPath);
    end
    % Load runner into a persistent namespace (avoids module cache issues)
    if isempty(runnerNS) || isempty(runnerPathCached) || ~strcmp(runnerPathCached, runnerPath)
        try
            runnerSrc = fileread(runnerPath);
        catch ME
            error('cellposesam_runner load failed (read): %s', ME.message);
        end
        runnerNS = py.dict();
        try
            py.exec(runnerSrc, runnerNS, runnerNS);
        catch ME
            error('cellposesam_runner load failed (exec): %s', ME.message);
        end
        runnerPathCached = runnerPath;
    end
    try
        disp('[DEBUG] cellposesam.classify: runner namespace loaded');
    catch
    end
    resultsPath = fullfile(classif.path, 'results.mat');
    disp('[DEBUG] cellposesam: using persistent python runner');
    tRun = tic;
    try
        try
            runFunc = runnerNS{'run'};
        catch
            error('cellposesam_runner namespace missing run()');
        end
        pyOut = runFunc(py.str(configPath));
    catch ME
        try
            errPath = fullfile(classif.path, 'runner_error.txt');
            if exist(errPath, 'file') == 2
                disp('[DEBUG] cellposesam.classify: runner_error.txt contents:');
                disp(fileread(errPath));
            else
                disp('[DEBUG] cellposesam.classify: runner_error.txt missing');
            end
        catch
        end
        error('cellposesam_runner run() failed: %s', ME.message);
    end
    runSec = toc(tRun);
    disp(['[DEBUG] cellposesam.classify: runner time=' num2str(runSec, '%.3f') 's']);
    try
        disp(['[DEBUG] cellposesam.classify: runner pyOut class=' class(pyOut)]);
        try
            if strcmp(class(pyOut),'py.dict')
                keys = pyOut.keys();
                disp(['[DEBUG] cellposesam.classify: runner keys=' char(py.str(keys))]);
            end
        catch
        end
        framesLen = double(pyOut{'frames_len'});
        fmin = double(pyOut{'frames_min'});
        fmax = double(pyOut{'frames_max'});
        gfpShape = char(py.repr(pyOut{'gfp_shape'}));
        resPath = char(pyOut{'results_path'});
        resBytes = double(pyOut{'results_bytes'});
        disp(['[DEBUG] cellposesam.classify: runner frames_len=' num2str(framesLen) ...
            ' frames_min=' num2str(fmin) ' frames_max=' num2str(fmax) ...
            ' gfp_shape=' gfpShape]);
        disp(['[DEBUG] cellposesam.classify: runner results_path=' resPath ' bytes=' num2str(resBytes)]);
    catch
        disp('[DEBUG] cellposesam.classify: runner output unreadable');
        try
            keys = py.list(pyOut.keys());
            disp(['[DEBUG] cellposesam.classify: runner keys=' char(py.str(keys))]);
        catch
        end
    end
    didRun = true;
catch ME
    try
        errPath = fullfile(classif.path, 'runner_error.txt');
        if exist(errPath, 'file') == 2
            disp('[DEBUG] cellposesam.classify: runner_error.txt contents:');
            disp(fileread(errPath));
        end
    catch
    end
    error('cellposesam_runner failed (fallback disabled): %s', ME.message);
end
% If results.mat missing, force reload + retry once
resultsPath = fullfile(classif.path, 'results.mat');
try
    disp(['[DEBUG] cellposesam.classify: results.mat exists after runner? ' num2str(exist(resultsPath,'file'))]);
catch
end
if exist(resultsPath, 'file') ~= 2
    disp('[WARN] cellposesam.classify: results.mat missing after runner; reloading module and retrying once...');
    try
        runnerSrc = fileread(runnerPath);
        runnerNS = py.dict();
        py.exec(runnerSrc, runnerNS, runnerNS);
        runFunc = runnerNS{'run'};
        tRun = tic;
        pyOut = runFunc(py.str(configPath));
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

image(:,:,pixresults, frames_list) = tmpout;
disp('Masques CellposeSAM integres dans image.');

if strcmpi(outputType, 'proba')
    if ~isfield(res, 'cellprob_all')
        error('cellposesam.classify: outputType=proba mais results.mat ne contient pas cellprob_all.');
    end

    chNameProba = [outputName '_cellprob'];
    pixproba = findChannelID(roiobj, chNameProba);
    if isempty(pixproba)
        error('cellposesam.classify: channel proba "%s" attendu (cree en ROIpreprocessing).', chNameProba);
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
