function p = internalDefaults()
% sam31.utils.internalDefaults
% Non-GUI defaults for SAM3.1 plumbing.

repoRoot = firstPathFromEnvOrCandidates('SAM31_REPO_ROOT', { ...
    fullfile(getenv('USERPROFILE'), 'Documents', 'MATLAB', 'SAM31_zero_shot_ctc_benchmark'), ...
    fullfile(getenv('USERPROFILE'), 'Documents', 'MATLAB', 'SAM31_yeast'), ...
    '/home/charvin-admin/repos/SAM31_zero_shot_ctc_benchmark', ...
    '/mnt/c/Users/Gilles/Documents/MATLAB/SAM31_yeast', ...
    '/data/Gilles/SAM31_zero_shot_ctc_benchmark'});

sam3Repo = firstPathFromEnvOrCandidates('SAM31_OFFICIAL_REPO', { ...
    fullfile(repoRoot, 'artifacts', 'sam3_official')});

p = struct();
p.backend = getenvOrDefault('SAM31_BACKEND', 'local');
p.pythonExecutable = getenvOrDefault('SAM31_PYTHON_EXE', '');
p.repoRoot = repoRoot;
p.sam3Repo = sam3Repo;
p.artifactsRoot = getenvOrDefault('SAM31_ARTIFACTS_ROOT', '');
p.trainingFolderName = 'trainingdataset';
p.ctcSubfolder = '';
p.writeLegacyCtc = false;
p.numGpus = 1;
p.prepareBeforeTrain = true;
p.prepareOnly = false;
p.dryRun = false;
p.splits = 'train val';
p.imageDatasetName = 'moma_sam31_image_coco';
p.videoDatasetName = 'moma_sam31_video';
p.trackletDatasetName = 'moma_sam31_tracklet_clips_len8_ref';
p.stageStrideMax = 4;
p.maxTracksPerDatapoint = 8;
p.smokeOnly = false;
p.chunkSize = 0;
p.chunkOverlap = 0;
p.prompt = 'cell';
p.promptMode = 'text';
p.minScore = 0;
p.outputName = '';
end

function value = firstPathFromEnvOrCandidates(envName, candidates)
value = getenv(envName);
if ~isempty(value)
    return;
end
value = '';
for i = 1:numel(candidates)
    c = char(string(candidates{i}));
    if ~isempty(c) && (exist(c, 'dir') == 7 || isempty(value))
        value = c;
        if exist(c, 'dir') == 7
            return;
        end
    end
end
end

function value = getenvOrDefault(envName, defaultValue)
value = getenv(envName);
if isempty(value)
    value = defaultValue;
end
end
