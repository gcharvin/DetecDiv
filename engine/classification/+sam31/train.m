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
    classif.trainingParam = sam31.utils.normalizeTrainingParam(classif.trainingParam);
end

runSam31Train(classif, ctx);
out.status = "OK";
end

function runSam31Train(classif, ctx)
tp = classif.trainingParam;
internal = sam31.utils.internalDefaults();
base = classif.path;
workDir = fullfile(base, 'sam31_train');
if ~exist(workDir, 'dir'), mkdir(workDir); end

repoRoot = char(string(runtimeParam(tp, internal, 'repoRoot')));
sam3Repo = char(string(runtimeParam(tp, internal, 'sam3Repo')));
artifactsRoot = char(string(runtimeParam(tp, internal, 'artifactsRoot')));
if isempty(artifactsRoot)
    artifactsRoot = fullfile(base, 'sam31_artifacts');
end
trainingFolderName = char(string(runtimeParam(tp, internal, 'trainingFolderName')));
ctcSubfolder = char(string(runtimeParam(tp, internal, 'ctcSubfolder')));
if isempty(strtrim(ctcSubfolder)) || strcmp(strtrim(ctcSubfolder), '.')
    datasetRoot = fullfile(base, trainingFolderName);
else
    datasetRoot = fullfile(base, trainingFolderName, ctcSubfolder);
end
if ~hasSam31DirectSplits(datasetRoot) && ~hasCtcSplits(datasetRoot)
    legacyDatasetRoot = fullfile(base, trainingFolderName, 'moma');
    if hasSam31DirectSplits(legacyDatasetRoot) || hasCtcSplits(legacyDatasetRoot)
        warning('sam31:LegacyCTCExport', ...
            'Using legacy SAM31 CTC export layout: %s. Re-run sam31.format to use %s.', ...
            legacyDatasetRoot, datasetRoot);
        datasetRoot = legacyDatasetRoot;
    else
        error('sam31:MissingTrainingExport', ...
            'SAM31 dataset not found under %s. Expected direct JSON/framebank or train/CTC or val/CTC. Run sam31.format first.', ...
            datasetRoot);
    end
end

cfg = struct();
cfg.repo_root = strrep(repoRoot, '\', '/');
cfg.sam3_repo = strrep(sam3Repo, '\', '/');
cfg.artifacts_root = strrep(artifactsRoot, '\', '/');
cfg.dataset_root = strrep(datasetRoot, '\', '/');
cfg.resolution = double(str2double(string(sam31.utils.paramValue(tp, 'resolution', 280))));
cfg.num_gpus = double(runtimeParam(tp, internal, 'numGpus'));
cfg.prepare_before_train = logical(runtimeParam(tp, internal, 'prepareBeforeTrain'));
cfg.prepare_only = logical(runtimeParam(tp, internal, 'prepareOnly'));
cfg.dry_run = logical(runtimeParam(tp, internal, 'dryRun'));
cfg.modules = trainModuleList(sam31.utils.paramValue(tp, 'trainModules', 'instance + video memory'));
cfg.splits = splitWords(runtimeParam(tp, internal, 'splits'));
cfg.image_dataset_name = char(string(runtimeParam(tp, internal, 'imageDatasetName')));
cfg.video_dataset_name = char(string(runtimeParam(tp, internal, 'videoDatasetName')));
cfg.tracklet_dataset_name = char(string(runtimeParam(tp, internal, 'trackletDatasetName')));
cfg.epochs = double(tp.epochs);
cfg.save_freq = double(tp.saveFreq);
cfg.clip_length = double(tp.clipLength);
cfg.clip_stride = double(tp.clipStride);
cfg.max_tracks_per_clip = double(tp.maxTracksPerClip);
cfg.min_visible_frames = double(tp.minVisibleFrames);
cfg.stage_stride_max = double(runtimeParam(tp, internal, 'stageStrideMax'));
cfg.max_tracks_per_datapoint = double(runtimeParam(tp, internal, 'maxTracksPerDatapoint'));
cfg.run_policy = pipelineRunPolicy(ctx);
cfg.run_id = pipelineRunField(ctx, 'runId', '');
cfg.run_path = pipelineRunField(ctx, 'runPath', pipelineRunField(ctx, 'path', ''));

configPath = fullfile(workDir, 'train_sam31_config.json');
writeJson(configPath, cfg);

scriptPath = fullfile(fileparts(mfilename('fullpath')), 'py', 'train_sam31.py');
sam31.utils.runPythonScript(scriptPath, configPath, tp, workDir);
end

function parts = splitWords(value)
if iscell(value)
    parts = value(end);
else
    txt = strtrim(char(string(value)));
    parts = regexp(txt, '\s+', 'split');
end
parts = parts(~cellfun(@isempty, parts));
end

function modules = trainModuleList(value)
txt = lower(strtrim(char(string(value))));
txt = strrep(txt, '_', ' ');
txt = strrep(txt, '-', ' ');
txt = regexprep(txt, '\s+', ' ');
if strcmp(txt, 'all')
    modules = {'all'};
elseif contains(txt, 'semantic')
    modules = {'semantic'};
elseif contains(txt, 'instance') && (contains(txt, 'video') || contains(txt, 'memory'))
    modules = {'instance', 'video-memory'};
elseif contains(txt, 'video') || contains(txt, 'memory')
    modules = {'video-memory'};
elseif contains(txt, 'instance')
    modules = {'instance'};
else
    modules = splitWords(value);
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

function tf = hasCtcSplits(root)
tf = exist(fullfile(root, 'train', 'CTC'), 'dir') == 7 || ...
    exist(fullfile(root, 'val', 'CTC'), 'dir') == 7;
end

function tf = hasSam31DirectSplits(root)
tf = exist(fullfile(root, 'train', '_annotations.coco.json'), 'file') == 2 || ...
    exist(fullfile(root, 'val', '_annotations.coco.json'), 'file') == 2;
end

function policy = pipelineRunPolicy(ctx)
policy = 'resume';
try
    if isstruct(ctx) && isfield(ctx, 'run') && isstruct(ctx.run)
        if isfield(ctx.run, 'runPolicy') && ~isempty(ctx.run.runPolicy)
            policy = char(string(ctx.run.runPolicy));
        elseif isfield(ctx.run, 'resume') && ~logical(ctx.run.resume)
            policy = 'restart';
        elseif isfield(ctx.run, 'control') && isstruct(ctx.run.control) ...
                && isfield(ctx.run.control, 'resume_policy') && ~isempty(ctx.run.control.resume_policy)
            policy = char(string(ctx.run.control.resume_policy));
        end
    end
    if strcmpi(policy, 'resume') && isstruct(ctx) && isfield(ctx, 'pipeline') && isstruct(ctx.pipeline)
        if isfield(ctx.pipeline, 'runPolicy') && ~isempty(ctx.pipeline.runPolicy)
            policy = char(string(ctx.pipeline.runPolicy));
        elseif isfield(ctx.pipeline, 'resume') && ~logical(ctx.pipeline.resume)
            policy = 'restart';
        elseif isfield(ctx.pipeline, 'control') && isstruct(ctx.pipeline.control) ...
                && isfield(ctx.pipeline.control, 'resume_policy') && ~isempty(ctx.pipeline.control.resume_policy)
            policy = char(string(ctx.pipeline.control.resume_policy));
        end
    end
    if strcmpi(policy, 'resume') && isstruct(ctx) && isfield(ctx, 'params') && isstruct(ctx.params)
        if isfield(ctx.params, 'runPolicy') && ~isempty(ctx.params.runPolicy)
            policy = char(string(ctx.params.runPolicy));
        elseif isfield(ctx.params, 'resumePolicy') && ~isempty(ctx.params.resumePolicy)
            policy = char(string(ctx.params.resumePolicy));
        elseif isfield(ctx.params, 'resume') && ~logical(ctx.params.resume)
            policy = 'restart';
        end
    end
catch
    policy = 'resume';
end
policy = strtrim(char(string(policy)));
if any(strcmpi(policy, {'restart','fresh','replace','reset'}))
    policy = 'restart';
else
    policy = 'resume';
end
end

function value = pipelineRunField(ctx, name, defaultValue)
value = defaultValue;
try
    if isstruct(ctx) && isfield(ctx, 'run') && isstruct(ctx.run) && isfield(ctx.run, name) && ~isempty(ctx.run.(name))
        value = char(string(ctx.run.(name)));
    elseif isstruct(ctx) && isfield(ctx, name) && ~isempty(ctx.(name))
        value = char(string(ctx.(name)));
    end
catch
    value = defaultValue;
end
end
