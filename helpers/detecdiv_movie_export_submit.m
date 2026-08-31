function [runObj, result] = detecdiv_movie_export_submit(targetObj, params, varargin)
%detecdiv_movie_export_submit  Run a one-node movie export locally or on Hub.
%
% The GUI supplies only a serializable recipe.  This helper builds the
% transient pipeline template required by the existing pipelineRun/Hub
% protocol; pipeline2 is intentionally not involved.

if nargin < 1 || isempty(targetObj) || ~(isa(targetObj, 'shallow') || isa(targetObj, 'classi'))
    error('detecdiv_movie_export_submit:MissingTarget', 'A shallow project or classifier is required.');
end
if nargin < 2 || ~isstruct(params)
    error('detecdiv_movie_export_submit:MissingParams', 'Movie export parameters are required.');
end
opts = localParse(varargin{:});
target = lower(char(string(opts.Target)));
if ~any(strcmp(target, {'local','hub'}))
    error('detecdiv_movie_export_submit:Target', 'Target must be local or hub.');
end
if strcmp(target, 'hub')
    params = localMapHubOutputPath(params);
end
isClassifierTarget = isa(targetObj, 'classi');

ctx = struct();
if isClassifierTarget
    ctx.targetRef = localClassifierTargetRef(targetObj);
    ctx.sel = struct('fovs', [], 'frames', [], ...
        'rois', localField(params, 'classifierRoiIndices', []), 'channels', {{}});
else
    ctx.shallow = targetObj;
    ctx.shallowObj = targetObj;
    ctx.sel = struct('fovs', [], 'frames', [], 'rois', [], 'channels', {{}});
end
ctx.params = params;
inputSource = 'existing_project'; if isClassifierTarget, inputSource = 'classifier_snapshot'; end
ctx.run = struct('runPolicy', 'restart', 'inputSource', inputSource, ...
    'selectedNodes', {{'movie_export_1'}}, 'nodeParams', struct('movie_export_1', params), ...
    'intent', 'export', 'executionTarget', target);
ctx.io = struct('existingPolicy', 'replace', 'cachePolicy', 'none');
ctx.store = struct();
ctx.allowGUI = false;
ctx.interactive = false;

if isClassifierTarget
    runObj = localNewClassifierRun(targetObj, ctx, params);
else
    runObj = pipelineRunNew(targetObj, 'movie_export', '', ...
        'Description', localDescription(params), 'Ctx', ctx, 'Status', 'new');
end
pipeObj = localCreatePipeline(runObj, params);
runObj.pipelineRef = struct('id', pipeObj.strid, 'path', pipeObj.path, 'version', char(string(pipeObj.version)));
runObj.templateId = runObj.pipelineRef.id;
runObj.templatePath = runObj.pipelineRef.path;
runObj.ctx.pipelineRef = runObj.pipelineRef;
runObj.ctx.pipelineSpec = localPipelineSpec(pipeObj);
pipelineRunSave(runObj);

result = struct('target', target, 'status', 'new', 'job', struct(), 'report', struct());
if strcmp(target, 'hub')
    pipelineRunSave(runObj);
    hubProject = [];
    if ~isClassifierTarget, hubProject = targetObj; end
    [job, runObj] = detecdiv_hub_submit_pipeline_run(runObj, hubProject, ...
        'SaveProject', false, 'WriteScope', 'project_update');
    result.status = char(string(job.status));
    result.job = job;
    return;
end

runObj.status = 'running';
% pipelineRun persistence deliberately strips handle-heavy objects.  The
% local execution path still needs the in-memory project; the Hub worker
% reconstructs it from the submitted project reference instead.
if isClassifierTarget
    runObj.ctx.roiList = targetObj.roi;
    runObj.ctx.rois = targetObj.roi;
else
    runObj.ctx.shallow = targetObj;
    runObj.ctx.shallowObj = targetObj;
end
pipelineRunSave(runObj);
try
    [ctxOut, report] = runPipelineDetecDiv(pipeObj, runObj.ctx);
    runObj.status = 'done';
    runObj.ctx = localStripRuntimeContext(ctxOut);
    runObj.outputs = struct('report', report, 'artifacts', localField(ctxOut, 'artifacts', struct([])));
    pipelineRunSave(runObj);
    result.status = 'done';
    result.report = report;
catch ME
    runObj.status = 'failed';
    pipelineRunSave(runObj);
    rethrow(ME);
end

function runObj = localNewClassifierRun(classiObj, ctx, params)
    runId = sprintf('movie_export_%s', datestr(now, 'yyyymmdd_HHMMSSFFF'));
    runRoot = fullfile(char(string(classiObj.path)), 'pipeline_runs', runId);
    if exist(runRoot, 'dir') ~= 7, mkdir(runRoot); end
    runObj = pipelineRun('', runId, 1);
    runObj.path = runRoot;
    runObj.description = localDescription(params);
    runObj.status = 'new';
    runObj.targetRef = ctx.targetRef;
    ctx.run.path = runRoot;
    ctx.run.classiPath = char(string(classiObj.path));
    runObj.ctx = ctx;
end

function ref = localClassifierTargetRef(classiObj)
    ref = struct('type', 'classi', 'projectPath', '', 'projectName', '', ...
        'fovIds', [], 'roiIds', {{}}, 'classiPath', char(string(classiObj.path)), ...
        'notes', 'Score movie export');
end
end

function params = localMapHubOutputPath(params)
    requested = char(string(localField(params, 'outputPath', '')));
    if isempty(strtrim(requested))
        error('detecdiv_movie_export_submit:HubOutputPathMissing', ...
            ['Select a local output path before submitting to the Hub. ' ...
             'It must be under the Local root configured in Hub connection settings.']);
    end
    hub = detecdiv_hub_settings_get();
    [remotePath, mapped] = detecdiv_paths_map_module_path(requested, struct('hub', hub), 'server');
    if ~mapped
        error('detecdiv_movie_export_submit:HubOutputPathUnmapped', ...
            ['The selected output path is not compatible with the Hub path mapping:\n%s\n\n' ...
             'Configure a matching Local root and Remote root in Hub connection settings, ' ...
             'then choose a path below that Local root.'], requested);
    end
    params.outputPath = remotePath;
    params.useRunArtifactFolder = false;
    params.hubOutputPath = struct('localPath', requested, 'remotePath', remotePath);
end

function pipeObj = localCreatePipeline(runObj, params)
pipeObj = pipelineNew('path', runObj.path, 'name', 'movie_export_template', 'id', 1, 'workspace', false);
node = struct('id', 'movie_export_1', 'name', 'Movie export', 'type', 'exporter', ...
    'func', 'movieExport.process', 'gui', '', 'guiMode', '', 'paramRequired', {{}}, ...
    'pkg', 'movieExport', 'params', params, 'inputs', {{}}, ...
    'outputs', {{'files','artifacts'}}, 'enabled', true, 'status', '', 'layout', struct());
pipeObj.nodes = node;
pipeObj.edges = struct('from', {}, 'to', {}, 'fromPort', {}, 'toPort', {}, 'condition', {});
pipeObj.description = 'Transient Score/Workflow movie export pipeline.';
pipelineSave(pipeObj, 'Artifacts', false);
end

function spec = localPipelineSpec(pipeObj)
spec = struct('id', char(string(pipeObj.strid)), 'path', char(string(pipeObj.path)), ...
    'nodes', pipeObj.nodes, 'edges', pipeObj.edges);
end

function out = localStripRuntimeContext(ctx)
out = ctx;
for name = {'shallow','shallowObj','progressCallback','cancel'}
    if isfield(out, name{1}), out = rmfield(out, name{1}); end
end
end

function text = localDescription(params)
source = char(string(localField(params, 'sourceType', 'movie')));
mode = char(string(localField(params, 'outputMode', 'Movie')));
text = sprintf('%s export (%s)', source, mode);
end

function opts = localParse(varargin)
opts = struct('Target', 'local');
if mod(numel(varargin), 2) ~= 0
    error('detecdiv_movie_export_submit:Args', 'Options must be Name/Value pairs.');
end
for i = 1:2:numel(varargin)
    switch lower(char(string(varargin{i})))
        case 'target'
            opts.Target = varargin{i+1};
        otherwise
            error('detecdiv_movie_export_submit:Args', 'Unknown option: %s', char(string(varargin{i})));
    end
end
end

function value = localField(S, name, defaultValue)
value = defaultValue;
if isstruct(S) && isfield(S, name) && ~isempty(S.(name)), value = S.(name); end
end
