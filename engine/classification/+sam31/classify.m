function out = classify(roiobj, classif, ctx)
% sam31.classify  SAM3.1 instance tracking inference for one ROI.

if nargin < 3 || isempty(ctx)
    ctx = struct();
end
out = sam31.utils.outInitSafe('sam31.classify');

frames = [];
channels = [];
outputName = '';
if isfield(ctx,'sel') && isstruct(ctx.sel)
    if isfield(ctx.sel,'frames'), frames = ctx.sel.frames; end
    if isfield(ctx.sel,'channels'), channels = ctx.sel.channels; end
end
if isfield(ctx,'names') && isstruct(ctx.names) && isfield(ctx.names,'outputName')
    outputName = ctx.names.outputName;
end

detecdiv_check_cancel(ctx, 'sam31 classify start');
[data, image] = classifySam31Internal(roiobj, classif, frames, channels, outputName, ctx);
out.data = data;
out.image = image;
out.patch = [];
out.status = "OK";
end

function [data, image] = classifySam31Internal(roiobj, classif, frames, channel, outputName, ctx)
if isempty(classif.trainingParam)
    classif.trainingParam = sam31.utils.defaultTrainingParam();
end
sam31.ensureClassMetadata(classif);
if isfield(ctx,'params') && isstruct(ctx.params)
    classif.trainingParam = sam31.utils.applyParamOverrides(classif.trainingParam, ctx.params);
    classif.trainingParam = sam31.utils.normalizeTrainingParam(classif.trainingParam);
end
tp = classif.trainingParam;
internal = sam31.utils.internalDefaults();

if isempty(frames)
    frames = 1:size(roiobj.image, 4);
end
if isempty(channel)
    try
        channel = classif.channelName;
    catch
        channel = [];
    end
end
if isempty(outputName)
    outputName = char(string(runtimeParam(tp, internal, 'outputName')));
    if isempty(outputName)
        try
            outputName = classif.strid;
        catch
            outputName = 'sam31';
        end
    end
end
outputName = char(string(outputName));

image = roiobj.image;
data = roiobj.data;
if isempty(data)
    roiobj.load('data');
    data = roiobj.data;
end

pix = roiobj.findChannelID(channel);
if iscell(pix), pix = cell2mat(pix); end
if isempty(pix)
    error('sam31:InputChannelNotFound', 'SAM31 input channel not found.');
end
pix = pix(1);

classNames = {'cell'};
try
    if ~isempty(classif.classes)
        classNames = classif.classes;
    end
catch
end
chName = ['results_' outputName '_' classNames{1}];
pixresults = findChannelID(roiobj, chName);
if isempty(pixresults)
    matrix = uint16(zeros(size(image,1), size(image,2), 1, size(image,4)));
    roiobj.addChannel(matrix, chName, [1 1 1], [0 0 0]);
    pixresults = findChannelID(roiobj, chName);
    image = roiobj.image;
end
if isempty(pixresults)
    error('sam31:OutputChannelCreateFailed', 'Unable to create output channel %s', chName);
end
pixresults = pixresults(1);

workDir = resolveWorkDir(ctx, classif, roiobj);
raw = roiobj.image(:, :, pix, frames);
inputMatPath = fullfile(workDir, 'sam31_input.mat');
save(inputMatPath, 'raw', 'frames', '-v7');

cfg = struct();
cfg.input_mat_path = strrep(inputMatPath, '\', '/');
cfg.output_dir = strrep(workDir, '\', '/');
cfg.repo_root = strrep(char(string(runtimeParam(tp, internal, 'repoRoot'))), '\', '/');
cfg.sam3_repo = strrep(char(string(runtimeParam(tp, internal, 'sam3Repo'))), '\', '/');
cfg.detector_checkpoint_path = strrep(char(string(tp.detectorCheckpointPath)), '\', '/');
cfg.tracker_checkpoint_path = strrep(char(string(tp.trackerCheckpointPath)), '\', '/');
cfg.smoke_only = logical(runtimeParam(tp, internal, 'smokeOnly'));
cfg.image_size = double(str2double(string(sam31.utils.paramValue(tp, 'resolution', 280))));
cfg.max_num_objects = double(tp.maxNumObjects);
cfg.chunk_size = double(runtimeParam(tp, internal, 'chunkSize'));
cfg.chunk_overlap = double(runtimeParam(tp, internal, 'chunkOverlap'));
cfg.prompt = char(string(runtimeParam(tp, internal, 'prompt')));
cfg.prompt_mode = char(string(runtimeParam(tp, internal, 'promptMode')));
cfg.min_score = double(runtimeParam(tp, internal, 'minScore'));
cfg.video_score_threshold = double(tp.videoScoreThreshold);
cfg.video_new_det_threshold = double(tp.videoNewDetThreshold);
cfg.video_det_nms_threshold = double(tp.videoDetNmsThreshold);
cfg.video_assoc_iou_threshold = double(tp.videoAssocIouThreshold);
cfg.cancel_path = cancelTokenFileFromCtx(ctx);
cfg.runner_mode = runnerModeFromCtx(ctx);

configPath = fullfile(workDir, 'classify_sam31_config.json');
writeJson(configPath, cfg);

scriptPath = fullfile(fileparts(mfilename('fullpath')), 'py', 'classify_sam31.py');
detecdiv_check_cancel(ctx, 'sam31 classify before Python');
sam31.utils.runPythonScript(scriptPath, configPath, tp, workDir);
detecdiv_check_cancel(ctx, 'sam31 classify after Python');

resultsPath = fullfile(workDir, 'results.mat');
if exist(resultsPath, 'file') ~= 2
    error('sam31:MissingResults', 'SAM31 runner did not write %s', resultsPath);
end
res = load(resultsPath);
if ~isfield(res, 'masks_all')
    error('sam31:MissingMasks', 'SAM31 results.mat has no masks_all variable.');
end
tmpout = uint16(res.masks_all);
if ndims(tmpout) == 3
    tmpout = reshape(tmpout, size(tmpout,1), size(tmpout,2), 1, size(tmpout,3));
end
frames_list = frames;
if isfield(res, 'frames_list')
    frames_list = double(res.frames_list(:))';
end
image(:,:,pixresults,frames_list) = squeeze(tmpout(:,:,1,:));
end

function workDir = resolveWorkDir(ctx, classif, roiobj)
baseDir = '';
try
    if isfield(ctx,'workDir') && ~isempty(ctx.workDir)
        baseDir = char(string(ctx.workDir));
    end
catch
end
if isempty(baseDir)
    try
        baseDir = fullfile(classif.path, 'work', 'sam31');
    catch
        baseDir = fullfile(tempdir, 'detecdiv_sam31');
    end
end
roiId = 'roi';
try
    roiId = char(string(roiobj.id));
catch
end
workDir = fullfile(baseDir, safePathPart(roiId));
if ~exist(workDir, 'dir')
    mkdir(workDir);
end
end

function s = safePathPart(value)
s = char(string(value));
s = regexprep(s, '[^\w.-]+', '_');
if isempty(s)
    s = 'roi';
end
end

function writeJson(path, cfg)
fid = fopen(path, 'w');
if fid == -1
    error('sam31:ConfigWriteFailed', 'Unable to write %s', path);
end
cleanup = onCleanup(@() fclose(fid));
fwrite(fid, jsonencode(cfg), 'char');
end

function value = runtimeParam(tp, internal, name)
value = [];
if isstruct(internal) && isfield(internal, name)
    value = internal.(name);
end
if isstruct(tp) && isfield(tp, name) && ~isempty(tp.(name))
    value = sam31.utils.paramValue(tp, name, value);
end
end

function mode = runnerModeFromCtx(ctx)
mode = 'session';
try
    if ~(isstruct(ctx) && isfield(ctx,'exec') && isstruct(ctx.exec) && ...
            isfield(ctx.exec,'python') && isstruct(ctx.exec.python))
        return;
    end
    pyCfg = ctx.exec.python;
    if isfield(pyCfg,'sam31Runner') && ~isempty(pyCfg.sam31Runner)
        mode = char(string(pyCfg.sam31Runner));
    elseif isfield(pyCfg,'modelCache') && ~isempty(pyCfg.modelCache)
        cacheMode = lower(strtrim(char(string(pyCfg.modelCache))));
        if any(strcmp(cacheMode, {'session','persistent','pyenv'}))
            mode = 'session';
        elseif any(strcmp(cacheMode, {'none','off','external'}))
            mode = 'external';
        end
    end
catch
    mode = 'session';
end
end

function tokenFile = cancelTokenFileFromCtx(ctx)
tokenFile = '';
try
    if isstruct(ctx) && isfield(ctx, 'cancel') && isstruct(ctx.cancel) ...
            && isfield(ctx.cancel, 'tokenFile') && ~isempty(ctx.cancel.tokenFile)
        tokenFile = char(string(ctx.cancel.tokenFile));
    end
catch
    tokenFile = '';
end
end
