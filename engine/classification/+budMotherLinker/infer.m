function result = infer(tracks, param, roiId, ctx)
%BUDMOTHERLINKER.INFER Call the external cell_lineage_linker Python package.
%
% DetecDiv owns ROI adaptation and persistence. Candidate generation,
% LYN-16 descriptors, ranking, and scientific audit metadata live in the
% independent cell_lineage_linker repository/package.

if nargin < 3 || isempty(roiId), roiId = 'roi'; end
if nargin < 4 || isempty(ctx), ctx = struct(); end
tracks = uint32(tracks);
if ndims(tracks) ~= 3
    error('budMotherLinker:InvalidTrackStack', ...
        'Tracked labels must have shape Y-by-X-by-time.');
end

[workDir, removeWorkDir] = runtimeWorkDir(ctx, roiId);
cleanup = onCleanup(@() cleanupRuntime(workDir, removeWorkDir));
inputPath = fullfile(workDir, 'tracks.h5');
configPath = fullfile(workDir, 'infer_config.json');
outputPath = fullfile(workDir, 'relations.json');
stdoutPath = fullfile(workDir, 'runner_stdout.txt');

% MATLAB reverses dimensions in its HDF5 high-level API. Writing X-Y-T
% therefore exposes the documented T-Y-X contract to h5py.
stored = permute(tracks, [2 1 3]);
storedSize = [size(tracks, 2), size(tracks, 1), size(tracks, 3)];
h5create(inputPath, '/tracks', storedSize, 'Datatype', 'uint32');
h5write(inputPath, '/tracks', stored);
h5writeatt(inputPath, '/tracks', 'axis_order', 'time,y,x');

cfg = struct();
cfg.schema_version = 1;
cfg.input_path = normalizedPath(inputPath);
cfg.dataset = '/tracks';
cfg.output_path = normalizedPath(outputPath);
cfg.roi_id = char(string(roiId));
cfg.parameters = struct( ...
    'frame_end', double(param.frameEnd), ...
    'min_lifetime', double(param.minLifetime), ...
    'max_birth_area', double(param.maxBirthArea), ...
    'min_parent_age', double(param.minParentAge), ...
    'max_parent_centroid_distance', double(param.maxParentCentroidDistance), ...
    'max_parent_contour_distance', double(param.maxParentContourDistance), ...
    'max_candidates', double(param.maxCandidates), ...
    'rank_margin_threshold', double(param.rankMarginThreshold), ...
    'tracking_load_guard_enabled', logical(param.trackingLoadGuard), ...
    'tracking_load_guard_max_new_tracks', ...
        double(param.maxNewTracksPerFrame));
cfg.global_solver = struct( ...
    'enabled', logical(param.globalSolver), ...
    'mother_refractory_frames', double(param.motherRefractoryFrames), ...
    'young_mother_frames', double(param.youngMotherFrames), ...
    'beam_size', double(param.solverBeamSize), ...
    'top_k_candidates', double(param.maxCandidates), ...
    'review_changed_assignments', logical(param.reviewGlobalReassignments));
cfg.model = struct('source', char(string(param.modelSource)), 'path', '');
if strcmpi(char(string(param.modelSource)), 'trained')
    cfg.model.path = normalizedPath(param.modelPath);
end
writeJson(configPath, cfg);

if exist('detecdiv_progress', 'file') == 2
    detecdiv_progress(ctx, 0, ...
        'Running cell_lineage_linker candidate and relation inference...', ...
        'Scope', 'event', 'Indeterminate', true);
end
detecdiv_check_cancel(ctx, 'budMotherLinker before cell_lineage_linker');
runtime = budMotherLinker.utils.runPythonModule( ...
    'infer', configPath, ctx, stdoutPath);
detecdiv_check_cancel(ctx, 'budMotherLinker after cell_lineage_linker');
if ~isfile(outputPath)
    error('budMotherLinker:MissingExternalOutput', ...
        'cell_lineage_linker completed without producing %s.', outputPath);
end
result = jsondecode(fileread(outputPath));
result.detecdiv_runtime = runtime;
result.detecdiv_runtime.work_dir = workDir;
result.detecdiv_runtime.stdout = stdoutPath;

if exist('detecdiv_progress', 'file') == 2
    total = 0;
    linked = 0;
    try total = double(result.summary.events); catch, end
    try linked = double(result.summary.linked); catch, end
    detecdiv_progress(ctx, 1, ...
        sprintf('Linked %d/%d bud events.', linked, total), ...
        'Scope', 'event', 'Current', total, 'Total', total);
end

% Runtime files under a pipeline work directory are intentional audit
% artifacts. Ephemeral command-line calls are cleaned by the onCleanup.
clear cleanup;
cleanupRuntime(workDir, removeWorkDir);
end

function [workDir, removeAtEnd] = runtimeWorkDir(ctx, roiId)
root = '';
try
    if isfield(ctx, 'store') && isstruct(ctx.store) && ...
            isfield(ctx.store, 'workDir') && ~isempty(ctx.store.workDir)
        root = char(string(ctx.store.workDir));
    end
catch
end
if isempty(root)
    root = tempname;
    mkdir(root);
    removeAtEnd = true;
else
    if ~isfolder(root), mkdir(root); end
    removeAtEnd = false;
end
safeRoi = regexprep(char(string(roiId)), '[^A-Za-z0-9_.-]+', '_');
stamp = char(datetime('now', 'Format', 'yyyyMMdd''T''HHmmssSSS'));
workDir = fullfile(root, ['cell_lineage_linker_' safeRoi '_' stamp]);
mkdir(workDir);
end

function cleanupRuntime(workDir, removeAtEnd)
if ~removeAtEnd || ~isfolder(workDir), return; end
try rmdir(workDir, 's'); catch, end
parent = fileparts(workDir);
try
    if isfolder(parent) && isempty(dir(fullfile(parent, '*')))
        rmdir(parent);
    end
catch
end
end

function writeJson(filename, value)
fid = fopen(filename, 'w');
if fid < 0
    error('budMotherLinker:ConfigWriteFailed', ...
        'Cannot create external linker configuration: %s', filename);
end
cleanup = onCleanup(@() fclose(fid));
fwrite(fid, jsonencode(value, 'PrettyPrint', true), 'char');
end

function value = normalizedPath(value)
value = strrep(char(string(value)), '\', '/');
end
