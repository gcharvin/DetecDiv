function result = infer(tracks,gfp,param,roiId,ctx)
%CELLLATENTMODEL.INFER Run external multimodal relation inference.
if nargin < 4 || isempty(roiId), roiId = 'roi'; end
if nargin < 5 || isempty(ctx), ctx = struct(); end
tracks = uint32(tracks);
if ndims(tracks) ~= 3
    error('cellLatentModel:InvalidTrackStack', ...
        'Tracked labels must have shape Y-by-X-by-time.');
end
if ~isempty(gfp)
    gfp = single(gfp);
    if ~isequal(size(gfp),size(tracks))
        error('cellLatentModel:GfpShapeMismatch', ...
            'GFP and tracked-label stacks must have identical dimensions.');
    end
end
[workDir,removeWorkDir] = runtimeWorkDir(ctx,roiId);
cleanup = onCleanup(@() cleanupRuntime(workDir,removeWorkDir));
inputPath = fullfile(workDir,'observations.h5');
configPath = fullfile(workDir,'infer_config.json');
outputPath = fullfile(workDir,'relations.json');
stdoutPath = fullfile(workDir,'runner_stdout.txt');

writeStack(inputPath,'/tracks',tracks,'uint32');
if ~isempty(gfp), writeStack(inputPath,'/gfp',gfp,'single'); end
device = char(string(param.device));
if strcmpi(device,'auto'), device = 'cuda'; end
cfg = struct( ...
    'schema_version',1, ...
    'input_path',normalizedPath(inputPath), ...
    'tracks_dataset','/tracks', ...
    'gfp_dataset','', ...
    'output_path',normalizedPath(outputPath), ...
    'roi_id',char(string(roiId)), ...
    'device',device, ...
    'checkpoint',struct('source',char(string(param.modelSource)),'path',''), ...
    'linker_parameters',linkerParameters(param), ...
    'global_solver',globalSolverParameters(param));
if ~isempty(gfp), cfg.gfp_dataset = '/gfp'; end
if strcmpi(char(string(param.modelSource)),'trained')
    cfg.checkpoint.path = normalizedPath(param.modelPath);
end
writeJson(configPath,cfg);
detecdiv_check_cancel(ctx,'cellLatentModel before Python inference');
runtime = cellLatentModel.utils.runPythonModule( ...
    'infer-roi',configPath,ctx,stdoutPath);
detecdiv_check_cancel(ctx,'cellLatentModel after Python inference');
if ~isfile(outputPath)
    error('cellLatentModel:MissingExternalOutput', ...
        'cell_latent_model produced no relation artifact.');
end
result = jsondecode(fileread(outputPath));
result.detecdiv_runtime = runtime;
result.detecdiv_runtime.work_dir = workDir;
clear cleanup;
cleanupRuntime(workDir,removeWorkDir);
end

function parameters = globalSolverParameters(p)
parameters = struct( ...
    'enabled',logical(p.globalSolver), ...
    'mother_refractory_frames',double(p.motherRefractoryFrames), ...
    'young_mother_frames',double(p.youngMotherFrames), ...
    'beam_size',double(p.solverBeamSize), ...
    'top_k_candidates',double(p.maxCandidates), ...
    'review_changed_assignments',logical(p.reviewGlobalReassignments));
end

function parameters = linkerParameters(p)
parameters = struct( ...
    'frame_end',double(p.frameEnd), ...
    'min_lifetime',double(p.minLifetime), ...
    'max_birth_area',double(p.maxBirthArea), ...
    'min_parent_age',double(p.minParentAge), ...
    'max_parent_centroid_distance',double(p.maxParentCentroidDistance), ...
    'max_parent_contour_distance',double(p.maxParentContourDistance), ...
    'max_candidates',double(p.maxCandidates), ...
    'tracking_load_guard_enabled',logical(p.trackingLoadGuard), ...
    'tracking_load_guard_max_new_tracks',double(p.maxNewTracksPerFrame));
end

function writeStack(filename,dataset,stack,datatype)
stored = permute(stack,[2 1 3]);
storedSize = [size(stack,2),size(stack,1),size(stack,3)];
chunk = [min(storedSize(1),256),min(storedSize(2),256),1];
h5create(filename,dataset,storedSize,'Datatype',datatype, ...
    'ChunkSize',chunk,'Deflate',1);
h5write(filename,dataset,stored);
h5writeatt(filename,dataset,'axis_order','time,y,x');
end

function [workDir,removeAtEnd] = runtimeWorkDir(ctx,roiId)
root = '';
try
    if isfield(ctx,'store') && isstruct(ctx.store) && ...
            isfield(ctx.store,'workDir') && ~isempty(ctx.store.workDir)
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
safeRoi = regexprep(char(string(roiId)),'[^A-Za-z0-9_.-]+','_');
stamp = char(datetime('now','Format','yyyyMMdd''T''HHmmssSSS'));
workDir = fullfile(root,['cell_latent_model_' safeRoi '_' stamp]);
mkdir(workDir);
end

function cleanupRuntime(workDir,removeAtEnd)
if ~removeAtEnd || ~isfolder(workDir), return; end
try rmdir(workDir,'s'); catch, end
parent = fileparts(workDir);
try
    if isfolder(parent) && isempty(dir(fullfile(parent,'*')))
        rmdir(parent);
    end
catch
end
end

function writeJson(filename,value)
fid = fopen(filename,'w');
if fid < 0
    error('cellLatentModel:ConfigWriteFailed', ...
        'Cannot create configuration %s.',filename);
end
cleanup = onCleanup(@() fclose(fid));
fwrite(fid,jsonencode(value,'PrettyPrint',true),'char');
end

function value = normalizedPath(value)
value = strrep(char(string(value)),'\','/');
end
