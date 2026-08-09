function result = propagateTrackCorrection(roiobj, opts)
% sam31.propagateTrackCorrection  Propagate one edited object from a seed mask.

if nargin < 2 || ~isstruct(opts)
    opts = struct();
end
opts = normalizeOptions(roiobj, opts);

seedMask = roiobj.image(:,:,opts.annotationPix,opts.startFrame) == opts.label;
if ~any(seedMask(:))
    error('sam31:CorrectionSeedMissing', ...
        'Selected label %d is not present on frame %d.', opts.label, opts.startFrame);
end

nf = size(roiobj.image,4);
lastFrame = min(nf, opts.startFrame + opts.maxFrames);
frames = opts.startFrame:lastFrame;
if numel(frames) < 2
    error('sam31:CorrectionNoFutureFrames', 'No following frames are available.');
end

raw = roiobj.image(:,:,opts.inputPix,frames);
[providerPix, providerName, providerInfo] = sam31.resolveCorrectionProvider(roiobj, opts);
workDir = resolveCorrectionWorkDir(roiobj, opts);
if ~exist(workDir, 'dir')
    mkdir(workDir);
end
inputMatPath = fullfile(workDir, 'sam31_track_correction_input.mat');
seedMaskPath = fullfile(workDir, 'sam31_track_correction_seed.mat');
providerMatPath = '';
save(inputMatPath, 'raw', 'frames', '-v7');
save(seedMaskPath, 'seedMask', '-v7');
if ~isempty(providerPix)
    providerLabels = roiobj.image(:,:,providerPix,frames);
    providerMatPath = fullfile(workDir, 'sam31_track_correction_provider.mat');
    save(providerMatPath, 'providerLabels', '-v7');
end

internal = sam31.utils.internalDefaults();
[detectorCheckpointPath, trackerCheckpointPath, checkpointInfo] = ...
    resolveCorrectionCheckpoints(opts);
tp = sam31.utils.defaultExecutionParam();
tp = mergeStruct(tp, opts);
tp.backend = char(string(opts.backend));
tp.resolution = char(string(opts.resolution));
tp.maxNumObjects = opts.maxNumObjects;
tp.minScore = opts.minScore;
tp.videoScoreThreshold = opts.videoScoreThreshold;
tp.videoNewDetThreshold = opts.videoNewDetThreshold;
tp.videoDetNmsThreshold = opts.videoDetNmsThreshold;
tp.videoAssocIouThreshold = opts.videoAssocIouThreshold;
tp.hotstartUnmatchThreshold = opts.hotstartUnmatchThreshold;
tp.sam31Runner = opts.runnerMode;

cfg = struct();
cfg.task = 'track_correction';
cfg.input_mat_path = slashPath(inputMatPath);
cfg.seed_mask_mat_path = slashPath(seedMaskPath);
cfg.candidate_provider_mat_path = slashPath(providerMatPath);
cfg.candidate_provider_name = providerName;
cfg.output_dir = slashPath(workDir);
cfg.repo_root = slashPath(char(string(getField(opts, 'repoRoot', internal.repoRoot))));
cfg.sam3_repo = slashPath(char(string(getField(opts, 'sam3Repo', internal.sam3Repo))));
cfg.detector_checkpoint_path = slashPath(detectorCheckpointPath);
cfg.tracker_checkpoint_path = slashPath(trackerCheckpointPath);
cfg.backend = char(string(opts.backend));
cfg.python_executable = char(string(getField(opts, 'pythonExecutable', '')));
cfg.image_size = opts.resolution;
cfg.max_num_objects = opts.maxNumObjects;
cfg.min_score = opts.minScore;
cfg.video_score_threshold = opts.videoScoreThreshold;
cfg.video_new_det_threshold = opts.videoNewDetThreshold;
cfg.video_det_nms_threshold = opts.videoDetNmsThreshold;
cfg.video_assoc_iou_threshold = opts.videoAssocIouThreshold;
cfg.hotstart_unmatch_thresh = opts.hotstartUnmatchThreshold;
cfg.runner_mode = opts.runnerMode;
cfg.prompt_obj_id = 0;
cfg.prompt_margin = 4;
cfg.prompt = char(string(opts.prompt));
cfg.correction_strategy = 'text_provider_mask_prompt';
cfg.fallback_text_track = true;
cfg.fallback_provider_track = true;
cfg.fallback_box_prompt = true;
cfg.fallback_mask_prompt = true;
cfg.fallback_min_seed_iou = opts.textMinSeedIou;
cfg.provider_min_seed_iou = opts.providerMinSeedIou;
cfg.provider_min_iou = opts.providerMinIou;
cfg.provider_min_dilated_iou = opts.providerMinDilatedIou;
cfg.provider_dilation_radius = opts.providerDilationRadius;
cfg.provider_max_centroid_distance = opts.providerMaxCentroidDistance;
cfg.provider_max_gap = opts.providerMaxGap;
modelRoot = char(string(getField(opts, 'modelRoot', '')));
if isempty(modelRoot)
    cfg.checkpoint_search_roots = {};
else
    cfg.checkpoint_search_roots = {slashPath(modelRoot)};
end

configPath = fullfile(workDir, 'sam31_track_correction_config.json');
writeJsonLocal(configPath, cfg);

scriptPath = fullfile(fileparts(mfilename('fullpath')), 'py', 'classify_sam31.py');
sam31.utils.runPythonScript(scriptPath, configPath, tp, workDir);

outPath = fullfile(workDir, 'track_correction.mat');
if exist(outPath, 'file') ~= 2
    error('sam31:CorrectionMissingResults', 'SAM31 correction did not write %s', outPath);
end
res = load(outPath);
if ~isfield(res, 'candidate_masks')
    error('sam31:CorrectionMissingMasks', 'SAM31 correction result has no candidate_masks variable.');
end

result = struct();
result.candidateMasks = logical(res.candidate_masks);
result.frames = frames;
if isfield(res, 'frames_list')
    result.frames = double(res.frames_list(:)');
end
result.workDir = workDir;
result.providerPix = providerPix;
result.providerName = providerName;
result.providerResolution = providerInfo;
result.checkpoints = checkpointInfo;
result.method = '';
if isfield(res, 'strategy_method')
    result.method = char(string(res.strategy_method));
end
statsPath = fullfile(workDir, 'track_correction_stats.json');
result.stats = struct();
if exist(statsPath, 'file') == 2
    try
        result.stats = jsondecode(fileread(statsPath));
    catch
    end
end
end

function opts = normalizeOptions(roiobj, opts)
defaults = struct( ...
    'label', NaN, ...
    'annotationPix', [], ...
    'inputPix', [], ...
    'startFrame', 1, ...
    'maxFrames', 20, ...
    'backend', 'wsl', ...
    'resolution', 280, ...
    'maxNumObjects', 120, ...
    'minScore', 0, ...
    'videoScoreThreshold', 0.40, ...
    'videoNewDetThreshold', 0.40, ...
    'videoDetNmsThreshold', 0.10, ...
    'videoAssocIouThreshold', 0.50, ...
    'hotstartUnmatchThreshold', 3, ...
    'runnerMode', 'external', ...
    'prompt', 'cell', ...
    'candidateProviderPix', [], ...
    'candidateProviderName', '', ...
    'modelRoot', '', ...
    'cacheCheckpoints', true, ...
    'checkpointCacheDir', defaultCheckpointCacheDir(), ...
    'textMinSeedIou', 0.02, ...
    'providerMinSeedIou', 0.02, ...
    'providerMinIou', 0.01, ...
    'providerMinDilatedIou', 0.05, ...
    'providerDilationRadius', 3, ...
    'providerMaxCentroidDistance', 0, ...
    'providerMaxGap', 2);
opts = mergeStruct(defaults, opts);

opts.label = round(double(opts.label));
opts.annotationPix = round(double(opts.annotationPix));
opts.inputPix = round(double(opts.inputPix));
opts.startFrame = round(double(opts.startFrame));
opts.maxFrames = round(double(opts.maxFrames));
opts.resolution = round(double(opts.resolution));
opts.maxNumObjects = round(double(opts.maxNumObjects));
opts.minScore = double(opts.minScore);
opts.videoScoreThreshold = double(opts.videoScoreThreshold);
opts.videoNewDetThreshold = double(opts.videoNewDetThreshold);
opts.videoDetNmsThreshold = double(opts.videoDetNmsThreshold);
opts.videoAssocIouThreshold = double(opts.videoAssocIouThreshold);
opts.hotstartUnmatchThreshold = round(double(opts.hotstartUnmatchThreshold));
opts.runnerMode = lower(strtrim(char(string(opts.runnerMode))));
opts.prompt = strtrim(char(string(opts.prompt)));
opts.candidateProviderName = strtrim(char(string(opts.candidateProviderName)));
opts.modelRoot = strtrim(char(string(opts.modelRoot)));
opts.checkpointCacheDir = strtrim(char(string(opts.checkpointCacheDir)));
opts.cacheCheckpoints = logical(opts.cacheCheckpoints);
opts.textMinSeedIou = double(opts.textMinSeedIou);
opts.providerMinSeedIou = double(opts.providerMinSeedIou);
opts.providerMinIou = double(opts.providerMinIou);
opts.providerMinDilatedIou = double(opts.providerMinDilatedIou);
opts.providerDilationRadius = round(double(opts.providerDilationRadius));
opts.providerMaxCentroidDistance = double(opts.providerMaxCentroidDistance);
opts.providerMaxGap = round(double(opts.providerMaxGap));

if ~isfinite(opts.label) || opts.label < 1
    error('sam31:CorrectionBadLabel', 'A positive label is required.');
end
if isempty(opts.annotationPix) || ~isfinite(opts.annotationPix) || opts.annotationPix < 1
    error('sam31:CorrectionBadAnnotationChannel', 'A valid annotation channel is required.');
end
if isempty(opts.inputPix) || ~isfinite(opts.inputPix) || opts.inputPix < 1
    opts.inputPix = firstNonAnnotationChannel(roiobj, opts.annotationPix);
end
if isempty(opts.inputPix)
    error('sam31:CorrectionBadInputChannel', 'Unable to find a raw input channel for SAM31.');
end
if opts.startFrame < 1 || opts.startFrame > size(roiobj.image,4)
    error('sam31:CorrectionBadFrame', 'Start frame is outside the ROI.');
end
if opts.maxFrames < 1
    error('sam31:CorrectionBadFrameCount', 'maxFrames must be positive.');
end
if opts.resolution < 1
    error('sam31:CorrectionBadResolution', 'resolution must be positive.');
end
if opts.maxNumObjects < 1
    error('sam31:CorrectionBadMaxObjects', 'maxNumObjects must be positive.');
end
if ~isfinite(opts.hotstartUnmatchThreshold) || opts.hotstartUnmatchThreshold < 1
    error('sam31:CorrectionBadUnmatchThreshold', ...
        'hotstartUnmatchThreshold must be a positive integer.');
end
opts.backend = lower(strtrim(char(string(opts.backend))));
if any(strcmp(opts.backend, {'linux','wsl'}))
    opts.backend = 'wsl';
else
    opts.backend = 'local';
end
if ~any(strcmp(opts.runnerMode, {'external','session'}))
    opts.runnerMode = 'external';
end
if isempty(opts.prompt), opts.prompt = 'cell'; end
if opts.providerDilationRadius < 0 || opts.providerMaxCentroidDistance < 0 || opts.providerMaxGap < 0
    error('sam31:CorrectionBadProviderOptions', ...
        'Provider dilation, centroid distance and maximum gap must be non-negative.');
end
end

function [detectorPath, trackerPath, info] = resolveCorrectionCheckpoints(opts)
detectorPath = char(string(getField(opts, 'detectorCheckpointPath', '')));
trackerPath = char(string(getField(opts, 'trackerCheckpointPath', '')));
modelRoot = char(string(getField(opts, 'modelRoot', '')));

if isempty(detectorPath) && ~isempty(modelRoot)
    detectorPath = findModelCheckpoint(modelRoot, opts.resolution, 'detector');
end
if isempty(trackerPath) && ~isempty(modelRoot)
    trackerPath = findModelCheckpoint(modelRoot, opts.resolution, 'tracker');
end

info = struct('modelRoot', modelRoot, 'cacheDir', opts.checkpointCacheDir, ...
    'detectorSource', detectorPath, 'trackerSource', trackerPath, ...
    'detectorPath', detectorPath, 'trackerPath', trackerPath, 'cached', false);
if ~opts.cacheCheckpoints || ~ispc
    return;
end

[detectorPath, detectorCached] = cacheCheckpointIfNeeded( ...
    detectorPath, 'detector', opts.resolution, opts.checkpointCacheDir);
[trackerPath, trackerCached] = cacheCheckpointIfNeeded( ...
    trackerPath, 'tracker', opts.resolution, opts.checkpointCacheDir);
info.detectorPath = detectorPath;
info.trackerPath = trackerPath;
info.cached = detectorCached || trackerCached;
end

function pathValue = findModelCheckpoint(modelRoot, resolution, kind)
pathValue = '';
artifacts = fullfile(modelRoot, 'sam31_artifacts');
if exist(artifacts, 'dir') ~= 7
    return;
end
switch kind
    case 'detector'
        exactPattern = sprintf('moma_sam31_image_instance*_%d', resolution);
        fallbackPattern = 'moma_sam31_image_instance*';
    case 'tracker'
        exactPattern = sprintf('moma_sam31_tracklet*_%d', resolution);
        fallbackPattern = 'moma_sam31_tracklet*';
    otherwise
        error('sam31:CorrectionBadCheckpointKind', 'Unknown checkpoint kind: %s', kind);
end
listing = dir(fullfile(artifacts, exactPattern, 'checkpoints', 'checkpoint.pt'));
if isempty(listing)
    listing = dir(fullfile(artifacts, fallbackPattern, 'checkpoints', 'checkpoint.pt'));
end
if isempty(listing)
    return;
end
[~, newest] = max([listing.datenum]);
pathValue = fullfile(listing(newest).folder, listing(newest).name);
end

function [pathValue, cached] = cacheCheckpointIfNeeded(sourcePath, kind, resolution, cacheDir)
pathValue = sourcePath;
cached = false;
if isempty(sourcePath) || exist(sourcePath, 'file') ~= 2 || ...
        isempty(cacheDir) || ~isSlowCheckpointPath(sourcePath)
    return;
end
if exist(cacheDir, 'dir') ~= 7
    mkdir(cacheDir);
end
sourceInfo = dir(sourcePath);
targetName = sprintf('sam31_%s_%d_%d.pt', kind, resolution, sourceInfo.bytes);
targetPath = fullfile(cacheDir, targetName);
targetInfo = dir(targetPath);
if ~isempty(targetInfo) && targetInfo.bytes == sourceInfo.bytes
    pathValue = targetPath;
    cached = true;
    return;
end

partialPath = [targetPath '.partial'];
if exist(partialPath, 'file') == 2
    delete(partialPath);
end
fprintf('[SAM31] Caching %s checkpoint locally (%0.2f GB): %s\n', ...
    kind, double(sourceInfo.bytes) / 1024^3, targetPath);
[ok, message] = copyfile(sourcePath, partialPath, 'f');
if ~ok
    error('sam31:CorrectionCheckpointCacheFailed', ...
        'Unable to cache %s checkpoint: %s', kind, message);
end
partialInfo = dir(partialPath);
if isempty(partialInfo) || partialInfo.bytes ~= sourceInfo.bytes
    error('sam31:CorrectionCheckpointCacheIncomplete', ...
        'Cached %s checkpoint is incomplete (%s).', kind, partialPath);
end
[ok, message] = movefile(partialPath, targetPath, 'f');
if ~ok
    error('sam31:CorrectionCheckpointCacheFailed', ...
        'Unable to finalize cached %s checkpoint: %s', kind, message);
end
pathValue = targetPath;
cached = true;
end

function tf = isSlowCheckpointPath(pathValue)
pathValue = char(string(pathValue));
tf = startsWith(pathValue, '\\') || startsWith(pathValue, '//');
if numel(pathValue) >= 2 && pathValue(2) == ':'
    tf = tf || ~strcmpi(pathValue(1), 'C');
end
end

function pathValue = defaultCheckpointCacheDir()
base = getenv('LOCALAPPDATA');
if isempty(base)
    base = tempdir;
end
pathValue = fullfile(base, 'DetecDiv', 'sam31_checkpoint_cache');
end

function pix = firstNonAnnotationChannel(roiobj, annotationPix)
pix = [];
try
    candidates = setdiff(1:size(roiobj.image,3), annotationPix, 'stable');
    if ~isempty(candidates)
        pix = candidates(1);
    end
catch
end
end

function workDir = resolveCorrectionWorkDir(roiobj, opts)
baseDir = '';
try
    if isfield(opts, 'workDir') && ~isempty(opts.workDir)
        baseDir = char(string(opts.workDir));
    end
catch
end
if isempty(baseDir)
    try
        if isfield(opts, 'classif') && isa(opts.classif, 'classi') && ~isempty(opts.classif.path)
            baseDir = fullfile(opts.classif.path, 'work', 'sam31');
        end
    catch
    end
end
if isempty(baseDir)
    try
        if isa(roiobj.parent, 'classi') && ~isempty(roiobj.parent.path)
            baseDir = fullfile(roiobj.parent.path, 'work', 'sam31');
        end
    catch
    end
end
if isempty(baseDir)
    baseDir = fullfile(tempdir, 'detecdiv_sam31_interactive');
end
roiId = 'roi';
try
    roiId = char(string(roiobj.id));
catch
end
workDir = fullfile(baseDir, safePathPartLocal(roiId));
end

function s = safePathPartLocal(value)
s = regexprep(char(string(value)), '[^A-Za-z0-9._-]+', '_');
if isempty(s)
    s = 'roi';
end
end

function out = mergeStruct(out, in)
if ~isstruct(in)
    return;
end
fields = fieldnames(in);
for i = 1:numel(fields)
    out.(fields{i}) = in.(fields{i});
end
end

function value = getField(s, name, defaultValue)
value = defaultValue;
try
    if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
        value = s.(name);
    end
catch
end
end

function out = slashPath(pathValue)
out = strrep(char(string(pathValue)), '\', '/');
end

function writeJsonLocal(pathValue, data)
txt = jsonencode(data);
txt = regexprep(txt, ',"', sprintf(',\n"'));
fid = fopen(pathValue, 'w');
if fid == -1
    error('sam31:CorrectionConfigWriteFailed', 'Unable to write %s', pathValue);
end
cleanup = onCleanup(@() fclose(fid));
fwrite(fid, txt, 'char');
end
