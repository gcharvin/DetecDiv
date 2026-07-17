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
tp = sam31.utils.defaultExecutionParam();
tp = inheritClassifierExecutionDefaults(tp, classif);
if isfield(ctx,'params') && isstruct(ctx.params)
    tp = sam31.utils.applyParamOverrides(tp, ctx.params);
end
internal = sam31.utils.internalDefaults();
modes = normalizeInferenceModes(tp);

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

if ~modes.instanceSegmentation
    fprintf('[SAM31 classify] inference stages: instance=off tracking=off bud_pairing=off -> no output requested\n');
    return;
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
    beforeC = size(roiobj.image, 3);
    roiobj.addChannel(matrix, chName, [1 1 1], [0 0 0]);
    pixresults = findChannelID(roiobj, chName);
    if isempty(pixresults)
        pixresults = recoverJustAddedResultChannel(roiobj, chName, beforeC);
    end
    image = roiobj.image;
end
if isempty(pixresults)
    error('sam31:OutputChannelCreateFailed', ...
        'Unable to create output channel %s. %s', chName, sam31ChannelDiagnostic(roiobj));
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
cfg.backend = char(string(runtimeParam(tp, internal, 'backend')));
cfg.python_executable = char(string(runtimeParam(tp, internal, 'pythonExecutable')));
cfg.smoke_only = logical(runtimeParam(tp, internal, 'smokeOnly'));
cfg.image_size = sam31ScalarNumber(sam31.utils.paramValue(tp, 'resolution', 280), 280, 'resolution', true, 1);
cfg.max_num_objects = sam31ScalarNumber(tp.maxNumObjects, 40, 'maxNumObjects', true, 1);
cfg.chunk_size = sam31ScalarNumber(runtimeParam(tp, internal, 'chunkSize'), 0, 'chunkSize', true, 0);
cfg.chunk_overlap = sam31ScalarNumber(runtimeParam(tp, internal, 'chunkOverlap'), 0, 'chunkOverlap', true, 0);
cfg.prompt = char(string(runtimeParam(tp, internal, 'prompt')));
cfg.prompt_mode = char(string(runtimeParam(tp, internal, 'promptMode')));
cfg.min_score = sam31ScalarNumber(runtimeParam(tp, internal, 'minScore'), 0, 'minScore', false, 0);
cfg.infer_instance_segmentation = logical(modes.instanceSegmentation);
cfg.infer_cell_tracking = logical(modes.cellTracking);
cfg.video_score_threshold = sam31ScalarNumber(tp.videoScoreThreshold, 0.40, 'videoScoreThreshold', false, 0);
cfg.video_new_det_threshold = sam31ScalarNumber(tp.videoNewDetThreshold, 0.40, 'videoNewDetThreshold', false, 0);
cfg.video_det_nms_threshold = sam31ScalarNumber(tp.videoDetNmsThreshold, 0.10, 'videoDetNmsThreshold', false, 0);
cfg.video_assoc_iou_threshold = sam31ScalarNumber(tp.videoAssocIouThreshold, 0.50, 'videoAssocIouThreshold', false, 0);
cfg.hotstart_unmatch_thresh = sam31ScalarNumber(tp.hotstartUnmatchThreshold, 3, 'hotstartUnmatchThreshold', true, 1);
cfg.cancel_path = cancelTokenFileFromCtx(ctx);
cfg.runner_mode = runnerModeFromCtx(ctx);

fprintf('[SAM31 classify] effective params: backend=%s image_size=%g max_num_objects=%g score=%.3g new_det=%.3g det_nms=%.3g assoc_iou=%.3g unmatched_grace=%g runner=%s stages=[instance=%d tracking=%d bud_pairing=%d]\n', ...
    cfg.backend, ...
    cfg.image_size, cfg.max_num_objects, cfg.video_score_threshold, ...
    cfg.video_new_det_threshold, cfg.video_det_nms_threshold, ...
    cfg.video_assoc_iou_threshold, cfg.hotstart_unmatch_thresh, cfg.runner_mode, ...
    logical(modes.instanceSegmentation), logical(modes.cellTracking), logical(modes.budPairing));

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

if modes.budPairing
    roiobj.image = image;
    roiobj.data = data;
    pairingReport = sam31.applyBudPairing(roiobj, classif, ...
        'OutputName', outputName, ...
        'Ctx', ctx);
    data = roiobj.data;
    if isfield(pairingReport, 'reason')
        fprintf('[SAM31 classify] bud pairing: %s (%d events, source=%s)\n', ...
            char(string(pairingReport.reason)), ...
            localReportNumber(pairingReport, 'nEvents'), ...
            char(string(localReportString(pairingReport, 'sourceKey'))));
    end
end
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

function modes = normalizeInferenceModes(tp)
modes = struct();
modes.instanceSegmentation = paramBoolLocal(getParamOrDefault(tp, 'inferInstanceSegmentation', true), true);
modes.cellTracking = paramBoolLocal(getParamOrDefault(tp, 'inferCellTracking', true), true);
modes.budPairing = paramBoolLocal(getParamOrDefault(tp, 'inferBudPairing', true), true);

if modes.budPairing && ~modes.cellTracking
    warning('sam31:InferenceModeDependency', ...
        'Bud pairing requires cell tracking; enabling cell tracking.');
    modes.cellTracking = true;
end
if modes.cellTracking && ~modes.instanceSegmentation
    warning('sam31:InferenceModeDependency', ...
        'Cell tracking requires instance segmentation; enabling instance segmentation.');
    modes.instanceSegmentation = true;
end
if ~modes.instanceSegmentation
    modes.cellTracking = false;
    modes.budPairing = false;
end
end

function value = getParamOrDefault(s, name, defaultValue)
value = defaultValue;
try
    if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
        value = sam31.utils.paramValue(s, name, defaultValue);
    end
catch
    value = defaultValue;
end
end

function tf = paramBoolLocal(value, defaultValue)
tf = defaultValue;
try
    if islogical(value)
        tf = logical(value(1));
    elseif isnumeric(value)
        tf = value(1) ~= 0;
    elseif ischar(value) || (isstring(value) && isscalar(value))
        txt = lower(strtrim(char(string(value))));
        if any(strcmp(txt, {'1','true','yes','on','oui'}))
            tf = true;
        elseif any(strcmp(txt, {'0','false','no','off','non'}))
            tf = false;
        end
    elseif iscell(value) && ~isempty(value)
        tf = paramBoolLocal(value{end}, defaultValue);
    end
catch
    tf = defaultValue;
end
end

function value = localReportNumber(report, name)
value = 0;
try
    if isstruct(report) && isfield(report, name) && ~isempty(report.(name))
        value = double(report.(name));
    end
catch
    value = 0;
end
end

function value = localReportString(report, name)
value = '';
try
    if isstruct(report) && isfield(report, name) && ~isempty(report.(name))
        value = char(string(report.(name)));
    end
catch
    value = '';
end
end

function s = safePathPart(value)
s = char(string(value));
s = regexprep(s, '[^\w.-]+', '_');
if isempty(s)
    s = 'roi';
end
end

function pixresults = recoverJustAddedResultChannel(roiobj, chName, beforeC)
pixresults = [];
try
    afterC = size(roiobj.image, 3);
    if afterC <= beforeC
        return;
    end
    pixresults = (beforeC + 1):afterC;
    pix = pixresults(1);
    logicalId = [];
    if isprop(roiobj, 'channelid') && numel(roiobj.channelid) >= pix
        logicalId = roiobj.channelid(pix);
    end
    if isempty(logicalId) || ~isfinite(double(logicalId)) || double(logicalId) < 1
        logicalId = numel(localChannelNames(roiobj)) + 1;
        if ~isprop(roiobj, 'channelid') || isempty(roiobj.channelid)
            roiobj.channelid = zeros(1, afterC);
        elseif numel(roiobj.channelid) < afterC
            roiobj.channelid(end+1:afterC) = 0;
        end
        roiobj.channelid(pixresults) = logicalId;
    end
    forceResultChannelDisplay(roiobj, chName, logicalId);
    pixresults = roiobj.findChannelID(chName, 'exact');
    if isempty(pixresults)
        pixresults = (beforeC + 1):afterC;
    end
catch
    pixresults = [];
end
end

function forceResultChannelDisplay(roiobj, chName, logicalId)
try
    logicalId = double(logicalId);
    if isempty(roiobj.display) || ~isstruct(roiobj.display)
        roiobj.display = struct();
    end
    if ~isfield(roiobj.display, 'channel') || isempty(roiobj.display.channel)
        roiobj.display.channel = {};
    elseif ischar(roiobj.display.channel) || isstring(roiobj.display.channel)
        roiobj.display.channel = cellstr(roiobj.display.channel);
    end
    if numel(roiobj.display.channel) < logicalId
        roiobj.display.channel(end+1:logicalId) = {''};
    end
    roiobj.display.channel{logicalId} = chName;
    roiobj.display = ensureDisplayVectorField(roiobj.display, 'indexed', logicalId, 0);
    roiobj.display = ensureDisplayVectorField(roiobj.display, 'alpha', logicalId, 1);
    roiobj.display = ensureDisplayVectorField(roiobj.display, 'contour', logicalId, 0);
    roiobj.display = ensureDisplayVectorField(roiobj.display, 'width', logicalId, 0);
    roiobj.display = ensureDisplayVectorField(roiobj.display, 'selectedchannel', logicalId, 1);
    roiobj.display = ensureDisplayRowsField(roiobj.display, 'rgb', logicalId, [1 1 1]);
    roiobj.display = ensureDisplayRowsField(roiobj.display, 'intensity', logicalId, [1 1 1]);
    roiobj.display.indexed(logicalId) = 1;
    roiobj.display.alpha(logicalId) = 0.35;
    roiobj.display.contour(logicalId) = 1;
    roiobj.display.width(logicalId) = 1.5;
    roiobj.display.selectedchannel(logicalId) = 1;
    roiobj.display.rgb(logicalId, :) = [1 1 1];
    roiobj.display.intensity(logicalId, :) = [0 0 0];
catch
end
end

function display = ensureDisplayVectorField(display, fieldName, idx, defaultValue)
if ~isfield(display, fieldName) || isempty(display.(fieldName))
    display.(fieldName) = zeros(1, 0);
end
value = display.(fieldName);
value = value(:).';
if numel(value) < idx
    value(end+1:idx) = defaultValue;
end
display.(fieldName) = value;
end

function display = ensureDisplayRowsField(display, fieldName, idx, defaultRow)
if ~isfield(display, fieldName) || isempty(display.(fieldName))
    value = zeros(0, numel(defaultRow));
else
    value = double(display.(fieldName));
end
if isvector(value) && numel(value) == numel(defaultRow)
    value = reshape(value, 1, []);
end
if size(value, 2) ~= numel(defaultRow)
    value = reshape(value, [], numel(defaultRow));
end
if size(value, 1) < idx
    value(end+1:idx, :) = repmat(defaultRow, idx - size(value, 1), 1);
end
display.(fieldName) = value;
end

function txt = sam31ChannelDiagnostic(roiobj)
try
    names = localChannelNames(roiobj);
    if isempty(names)
        namesTxt = '<none>';
    else
        namesTxt = strjoin(names, ', ');
    end
    channelIdTxt = '<empty>';
    if isprop(roiobj, 'channelid') && ~isempty(roiobj.channelid)
        channelIdTxt = strtrim(sprintf(' %g', double(roiobj.channelid(:).')));
    end
    sz = size(roiobj.image);
    while numel(sz) < 4
        sz(end+1) = 1; %#ok<AGROW>
    end
    txt = sprintf('ROI=%s image=[%s] channels={%s} channelid=[%s]', ...
        safeRoiId(roiobj), strtrim(sprintf(' %d', sz)), namesTxt, channelIdTxt);
catch ME
    txt = ['Diagnostic failed: ' ME.message];
end
end

function names = localChannelNames(roiobj)
names = {};
try
    if isprop(roiobj, 'display') && isstruct(roiobj.display) && ...
            isfield(roiobj.display, 'channel') && ~isempty(roiobj.display.channel)
        names = cellstr(string(roiobj.display.channel));
    end
catch
    names = {};
end
end

function s = safeRoiId(roiobj)
s = 'roi';
try
    if isprop(roiobj, 'id') && ~isempty(roiobj.id)
        s = char(string(roiobj.id));
    elseif isprop(roiobj, 'strid') && ~isempty(roiobj.strid)
        s = char(string(roiobj.strid));
    end
catch
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

function value = sam31ScalarNumber(raw, defaultValue, name, makeInteger, minValue)
if nargin < 4 || isempty(makeInteger)
    makeInteger = false;
end
if nargin < 5 || isempty(minValue)
    minValue = -Inf;
end

value = defaultValue;
try
    if iscell(raw) && ~isempty(raw)
        raw = raw{end};
    end
    if ischar(raw) || (isstring(raw) && isscalar(raw))
        txt = strtrim(char(string(raw)));
        parsed = str2double(txt);
        if isnan(parsed) && contains(txt, ',') && ~contains(txt, '.')
            parsed = str2double(strrep(txt, ',', '.'));
        end
        raw = parsed;
    end
    candidate = double(raw);
    candidate = candidate(isfinite(candidate));
    if isempty(candidate)
        candidate = double(defaultValue);
    elseif ~isscalar(candidate)
        warning('sam31:VectorScalarParam', ...
            'SAM31 parameter %s must be scalar; using first value %.6g from [%s].', ...
            char(string(name)), candidate(1), strtrim(sprintf(' %.6g', candidate)));
        candidate = candidate(1);
    end
    value = candidate;
catch
    value = double(defaultValue);
end

if makeInteger
    value = round(value);
end
if ~isfinite(value) || value < minValue
    error('sam31:InvalidScalarParam', ...
        'SAM31 parameter %s must be a finite scalar >= %.6g.', ...
        char(string(name)), double(minValue));
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

function tp = inheritClassifierExecutionDefaults(tp, classif)
try
    if isprop(classif, 'trainingParam') && isstruct(classif.trainingParam) && ...
            isfield(classif.trainingParam, 'resolution') && ~isempty(classif.trainingParam.resolution)
        tp.resolution = classif.trainingParam.resolution;
    end
catch
end
try
    if isprop(classif, 'executionParam') && isstruct(classif.executionParam)
        tp = sam31.utils.applyParamOverrides(tp, classif.executionParam);
    end
catch
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
