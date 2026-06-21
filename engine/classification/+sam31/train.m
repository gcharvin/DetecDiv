function out = train(classif, ctx)
% sam31.train  Package entry point for SAM3.1 training.

if nargin < 2 || isempty(ctx)
    ctx = struct();
end
out = sam31.utils.outInitSafe('sam31.train');

mode = "train";
if isfield(ctx,'mode') && ~isempty(ctx.mode)
    mode = string(ctx.mode);
end

if strcmpi(mode,"init") || strcmpi(mode,"setparam") || strcmpi(mode,"param")
    classif.trainingParam = sam31.utils.defaultTrainingParam();
    sam31.ensureClassMetadata(classif);
    out.refs.trainingParam = classif.trainingParam;
    out.status = "OK";
    return;
end

if isempty(classif.trainingParam)
    classif.trainingParam = sam31.utils.defaultTrainingParam();
end
sam31.ensureClassMetadata(classif);
if isfield(ctx,'params') && isstruct(ctx.params)
    classif.trainingParam = sam31.utils.applyParamOverrides(classif.trainingParam, ctx.params);
end

runSam31Train(classif);
out.status = "OK";
end

function runSam31Train(classif)
tp = classif.trainingParam;
base = classif.path;
workDir = fullfile(base, 'sam31_train');
if ~exist(workDir, 'dir'), mkdir(workDir); end

repoRoot = char(string(tp.repoRoot));
sam3Repo = char(string(tp.sam3Repo));
artifactsRoot = char(string(tp.artifactsRoot));
if isempty(artifactsRoot)
    artifactsRoot = fullfile(base, 'sam31_artifacts');
end
datasetRoot = fullfile(base, 'trainingdataset', 'moma');
if exist(datasetRoot, 'dir') ~= 7
    error('sam31:MissingCTCExport', 'CTC dataset not found: %s. Run sam31.format first.', datasetRoot);
end

cfg = struct();
cfg.repo_root = strrep(repoRoot, '\', '/');
cfg.sam3_repo = strrep(sam3Repo, '\', '/');
cfg.artifacts_root = strrep(artifactsRoot, '\', '/');
cfg.dataset_root = strrep(datasetRoot, '\', '/');
cfg.python = char(string(tp.pythonExecutable));
cfg.resolution = double(tp.resolution);
cfg.num_gpus = double(tp.numGpus);
cfg.prepare_before_train = logical(tp.prepareBeforeTrain);
cfg.modules = splitWords(tp.trainModules);
cfg.splits = splitWords(tp.splits);
cfg.image_dataset_name = char(string(tp.imageDatasetName));
cfg.video_dataset_name = char(string(tp.videoDatasetName));
cfg.tracklet_dataset_name = char(string(tp.trackletDatasetName));
cfg.epochs = double(tp.epochs);
cfg.save_freq = double(tp.saveFreq);
cfg.clip_length = double(tp.clipLength);
cfg.clip_stride = double(tp.clipStride);
cfg.max_tracks_per_clip = double(tp.maxTracksPerClip);
cfg.min_visible_frames = double(tp.minVisibleFrames);
cfg.stage_stride_max = double(tp.stageStrideMax);
cfg.max_tracks_per_datapoint = double(tp.maxTracksPerDatapoint);

configPath = fullfile(workDir, 'train_sam31_config.json');
writeJson(configPath, cfg);

scriptPath = fullfile(fileparts(mfilename('fullpath')), 'py', 'train_sam31.py');
sam31.utils.runPythonScript(scriptPath, configPath, tp, workDir);
end

function parts = splitWords(value)
if iscell(value)
    parts = value;
else
    txt = strtrim(char(string(value)));
    parts = regexp(txt, '\s+', 'split');
end
parts = parts(~cellfun(@isempty, parts));
end

function writeJson(path, cfg)
fid = fopen(path, 'w');
if fid == -1
    error('sam31:ConfigWriteFailed', 'Unable to write %s', path);
end
cleanup = onCleanup(@() fclose(fid));
fwrite(fid, jsonencode(cfg), 'char');
end
