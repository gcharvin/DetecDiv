function result = infer(tracks,observations,param,roiId,ctx)
%CELLLATENTMODEL.INFER Run external multimodal relation inference.
if nargin < 4 || isempty(roiId), roiId = 'roi'; end
if nargin < 5 || isempty(ctx), ctx = struct(); end
tracks = uint32(tracks);
if ndims(tracks) ~= 3
    error('cellLatentModel:InvalidTrackStack', ...
        'Tracked labels must have shape Y-by-X-by-time.');
end
observations = normalizeObservations(observations,tracks);
[workDir,removeWorkDir] = runtimeWorkDir(ctx,roiId);
cleanup = onCleanup(@() cleanupRuntime(workDir,removeWorkDir));
inputPath = fullfile(workDir,'observations.h5');
configPath = fullfile(workDir,'infer_config.json');
outputPath = fullfile(workDir,'relations.json');
stdoutPath = fullfile(workDir,'runner_stdout.txt');

writeStack(inputPath,'/tracks',tracks,'uint32');
device = char(string(param.device));
if strcmpi(device,'auto'), device = 'cuda'; end
backend = 'legacy';
if isfield(param,'backend') && ~isempty(param.backend)
    backend = lower(strtrim(char(string(param.backend))));
end
if any(strcmp(backend,{'relation_ensemble','relationensemble'}))
    backend = 'legacy';
end
cfg = struct();
cfg.schema_version = 1;
cfg.backend = backend;
cfg.input_path = normalizedPath(inputPath);
cfg.tracks_dataset = '/tracks';
cfg.output_path = normalizedPath(outputPath);
cfg.roi_id = char(string(roiId));
cfg.device = device;
if strcmp(backend,'legacy')
    cfg.linker_parameters = linkerParameters(param);
    cfg.global_solver = globalSolverParameters(param);
    cfg.gfp_dataset = '';
    if ~isempty(observations.gfp)
        writeStack(inputPath,'/gfp',observations.gfp,'single');
        cfg.gfp_dataset = '/gfp';
    end
    cfg.checkpoint = struct( ...
        'source',char(string(param.modelSource)),'path','');
    if strcmpi(char(string(param.modelSource)),'trained')
        cfg.checkpoint.path = normalizedPath(param.modelPath);
    end
elseif strcmp(backend,'temporal_lineage')
    cfg.linker_parameters = linkerParameters(param);
    cfg.global_solver = globalSolverParameters(param);
    % Omitting package_path deliberately selects the package-bundled,
    % checksum-verified temporal_lineage_multidomain_v002 artifacts.
    cfg.variant = char(string(param.temporalVariant));
    cfg.frame_interval_minutes = double(param.frameIntervalMinutes);
    cfg.nucleus_dataset = '';
    cfg.budneck_dataset = '';
    if ~isempty(observations.nucleus)
        writeStack(inputPath,'/nucleus',observations.nucleus,'single');
        cfg.nucleus_dataset = '/nucleus';
    end
    if ~isempty(observations.budneck)
        writeStack(inputPath,'/budneck',observations.budneck,'single');
        cfg.budneck_dataset = '/budneck';
    end
elseif strcmp(backend,'continuous_cell_state')
    cfg.frame_interval_minutes = double(param.frameIntervalMinutes);
    cfg.checkpoint = struct( ...
        'source','trained','path',normalizedPath(param.modelPath));
    cfg.adaptive_marker_checkpoint = struct('source','none','path','');
    if strcmpi(char(string(param.adaptiveMarkerModelSource)),'trained')
        cfg.adaptive_marker_checkpoint.source = 'trained';
        cfg.adaptive_marker_checkpoint.path = ...
            normalizedPath(param.adaptiveMarkerModelPath);
    end
    cfg.brightfield_dataset = '';
    cfg.nucleus_dataset = '';
    cfg.budneck_dataset = '';
    if ~isempty(observations.brightfield)
        writeStack(inputPath,'/brightfield', ...
            observations.brightfield,'single');
        cfg.brightfield_dataset = '/brightfield';
    end
    if ~isempty(observations.nucleus)
        writeStack(inputPath,'/nucleus',observations.nucleus,'single');
        cfg.nucleus_dataset = '/nucleus';
    end
    if ~isempty(observations.budneck)
        writeStack(inputPath,'/budneck',observations.budneck,'single');
        cfg.budneck_dataset = '/budneck';
    end
    % The continuous checkpoint owns candidate count, contour radius and
    % sample grid. Do not forward the incompatible legacy defaults.
    cfg.linker_parameters = continuousLinkerParameters(param);
    cfg.global_solver = continuousGlobalSolverParameters(param);
    cfg.causal_solver_feedback = logical(param.causalSolverFeedback);
else
    error('cellLatentModel:InvalidBackend', ...
        'Unsupported inference backend "%s".',backend);
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
if strcmp(backend,'continuous_cell_state')
    validateContinuousResult(result);
end
result.detecdiv_runtime = runtime;
result.detecdiv_runtime.work_dir = workDir;
clear cleanup;
cleanupRuntime(workDir,removeWorkDir);
end

function observations = normalizeObservations(value,tracks)
if nargin < 1 || isempty(value)
    observations = struct();
elseif isstruct(value)
    observations = value;
else
    % Backward-compatible direct calls used the second argument as GFP.
    observations = struct('gfp',value);
end
names = {'gfp','brightfield','nucleus','budneck'};
for i = 1:numel(names)
    name = names{i};
    if ~isfield(observations,name) || isempty(observations.(name))
        observations.(name) = [];
        continue;
    end
    stack = single(observations.(name));
    if ~isequal(size(stack),size(tracks))
        error('cellLatentModel:ObservationShapeMismatch', ...
            ['%s and tracked-label stacks must have identical ' ...
             'dimensions.'],name);
    end
    observations.(name) = stack;
end
end

function parameters = continuousGlobalSolverParameters(p)
parameters = struct( ...
    'enabled',logical(p.globalSolver), ...
    'mother_refractory_frames',0, ...
    'young_mother_frames',0, ...
    'beam_size',double(p.solverBeamSize), ...
    'review_changed_assignments',logical(p.reviewGlobalReassignments));
end

function parameters = continuousLinkerParameters(p)
parameters = struct( ...
    'frame_end',-1, ...
    'min_lifetime',1, ...
    'tracking_load_guard_enabled',logical(p.trackingLoadGuard), ...
    'tracking_load_guard_max_new_tracks', ...
        double(p.maxNewTracksPerFrame));
end

function validateContinuousResult(result)
if ~isstruct(result) || ~isfield(result,'backend') || ...
        ~strcmp(char(string(result.backend)),'continuous_cell_state')
    error('cellLatentModel:InvalidContinuousResult', ...
        'Python returned no continuous_cell_state result contract.');
end
required = {'summary','events','edges','biological_state'};
missing = required(~isfield(result,required));
if ~isempty(missing)
    error('cellLatentModel:InvalidContinuousResult', ...
        'Continuous result lacks: %s.',strjoin(missing,', '));
end
if ~isstruct(result.biological_state) || ...
        ~isfield(result.biological_state,'records')
    error('cellLatentModel:InvalidContinuousResult', ...
        'Continuous result lacks biological_state.records.');
end
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
