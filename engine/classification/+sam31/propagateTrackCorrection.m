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
workDir = resolveCorrectionWorkDir(roiobj, opts);
if ~exist(workDir, 'dir')
    mkdir(workDir);
end
inputMatPath = fullfile(workDir, 'sam31_track_correction_input.mat');
seedMaskPath = fullfile(workDir, 'sam31_track_correction_seed.mat');
save(inputMatPath, 'raw', 'frames', '-v7');
save(seedMaskPath, 'seedMask', '-v7');

internal = sam31.utils.internalDefaults();
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
tp.sam31Runner = 'external';

cfg = struct();
cfg.task = 'track_correction';
cfg.input_mat_path = slashPath(inputMatPath);
cfg.seed_mask_mat_path = slashPath(seedMaskPath);
cfg.output_dir = slashPath(workDir);
cfg.repo_root = slashPath(char(string(getField(opts, 'repoRoot', internal.repoRoot))));
cfg.sam3_repo = slashPath(char(string(getField(opts, 'sam3Repo', internal.sam3Repo))));
cfg.detector_checkpoint_path = slashPath(char(string(getField(opts, 'detectorCheckpointPath', ''))));
cfg.tracker_checkpoint_path = slashPath(char(string(getField(opts, 'trackerCheckpointPath', ''))));
cfg.backend = char(string(opts.backend));
cfg.python_executable = char(string(getField(opts, 'pythonExecutable', '')));
cfg.image_size = opts.resolution;
cfg.max_num_objects = opts.maxNumObjects;
cfg.min_score = opts.minScore;
cfg.video_score_threshold = opts.videoScoreThreshold;
cfg.video_new_det_threshold = opts.videoNewDetThreshold;
cfg.video_det_nms_threshold = opts.videoDetNmsThreshold;
cfg.video_assoc_iou_threshold = opts.videoAssocIouThreshold;
cfg.runner_mode = 'external';
cfg.prompt_obj_id = 0;
cfg.prompt_margin = 4;

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
end

function opts = normalizeOptions(roiobj, opts)
defaults = struct( ...
    'label', NaN, ...
    'annotationPix', [], ...
    'inputPix', [], ...
    'startFrame', 1, ...
    'maxFrames', 20, ...
    'backend', 'wsl', ...
    'resolution', 560, ...
    'maxNumObjects', 120, ...
    'minScore', 0, ...
    'videoScoreThreshold', 0.40, ...
    'videoNewDetThreshold', 0.40, ...
    'videoDetNmsThreshold', 0.10, ...
    'videoAssocIouThreshold', 0.50);
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
opts.backend = lower(strtrim(char(string(opts.backend))));
if any(strcmp(opts.backend, {'linux','wsl'}))
    opts.backend = 'wsl';
else
    opts.backend = 'local';
end
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
