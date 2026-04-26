function [job, runObj] = detecdiv_hub_submit_pipeline_run(runObj, shallowObj, varargin)
% detecdiv_hub_submit_pipeline_run  Submit an existing pipelineRun to detecdiv-hub.

    if nargin < 1 || isempty(runObj) || ~isa(runObj, 'pipelineRun')
        error('detecdiv_hub_submit_pipeline_run:MissingRun', 'A pipelineRun object is required.');
    end
    if nargin < 2 || isempty(shallowObj) || ~isa(shallowObj, 'shallow')
        error('detecdiv_hub_submit_pipeline_run:MissingProject', 'A shallow project is required.');
    end

    opts = localParse(varargin{:});
    ref = detecdiv_hub_project_ref(shallowObj, opts.hub);
    if isempty(ref.project_id)
        error('detecdiv_hub_submit_pipeline_run:MissingProjectId', ...
            'This project has no hub project id. Store it in shallowObj.runProfiles.hub.hub_project_id.');
    end

    payload = struct();
    payload.project_id = ref.project_id;
    payload.requested_mode = opts.requestedMode;
    payload.priority = opts.priority;
    payload.requested_by = opts.requestedBy;
    payload.requested_from_host = localHostName();
    payload.project_ref = localBuildProjectRef(ref);
    payload.pipeline_ref = localBuildPipelineRef(runObj);
    payload.run_request = localBuildRunRequest(runObj);
    payload.execution = localBuildExecution(opts);

    job = detecdiv_hub_request('POST', '/pipeline-runs', payload, opts.hub);
    runObj = localAttachHubJob(runObj, job, ref);
    pipelineRunSave(runObj);
end

function opts = localParse(varargin)
    opts = struct();
    opts.hub = detecdiv_hub_settings_get();
    opts.requestedMode = 'server';
    opts.priority = 100;
    opts.requestedBy = '';
    opts.executionTargetId = '';
    opts.saveProject = true;
    opts.writeScope = 'project_update';
    i = 1;
    while i <= numel(varargin)
        key = lower(char(string(varargin{i})));
        if i == numel(varargin)
            break;
        end
        value = varargin{i+1};
        switch key
            case 'hub'
                opts.hub = value;
            case 'requestedmode'
                opts.requestedMode = char(string(value));
            case 'priority'
                opts.priority = double(value);
            case 'requestedby'
                opts.requestedBy = char(string(value));
            case 'executiontargetid'
                opts.executionTargetId = char(string(value));
            case 'saveproject'
                opts.saveProject = logical(value);
            case 'writescope'
                opts.writeScope = char(string(value));
        end
        i = i + 2;
    end
    if isempty(opts.requestedBy) && isfield(opts.hub, 'userKey')
        opts.requestedBy = char(string(opts.hub.userKey));
    end
end

function projectRef = localBuildProjectRef(ref)
    projectRef = struct();
    projectRef.project_id = ref.project_id;
    projectRef.project_key = ref.project_key;
    projectRef.project_name = ref.project_name;
    projectRef.local_project_mat_path = ref.project_mat_path;
end

function pipelineRef = localBuildPipelineRef(runObj)
    pipelineRef = struct();
    pipelineRef.pipeline_key = '';
    pipelineRef.pipeline_json_path = '';
    try
        pipelineRef.pipeline_key = char(string(runObj.templateId));
    catch
    end
    try
        if isstruct(runObj.pipelineRef) && isfield(runObj.pipelineRef, 'id') && ~isempty(runObj.pipelineRef.id)
            pipelineRef.pipeline_key = char(string(runObj.pipelineRef.id));
        end
        if isstruct(runObj.pipelineRef) && isfield(runObj.pipelineRef, 'path') && ~isempty(runObj.pipelineRef.path)
            pipelineRef.pipeline_json_path = localPipelineJsonPath(runObj.pipelineRef.path);
        end
    catch
    end
    if isempty(pipelineRef.pipeline_json_path)
        try
            pipelineRef.pipeline_json_path = localPipelineJsonPath(runObj.templatePath);
        catch
        end
    end
end

function pathOut = localPipelineJsonPath(pathIn)
    pathOut = char(string(pathIn));
    if isfolder(pathOut)
        pathOut = fullfile(pathOut, 'pipeline.json');
    end
end

function runRequest = localBuildRunRequest(runObj)
    ctx = struct();
    try
        if isstruct(runObj.ctx)
            ctx = runObj.ctx;
        end
    catch
    end

    runRequest = struct();
    runRequest.run_id = char(string(runObj.runId));
    runRequest.description = char(string(runObj.description));
    runRequest.selected_nodes = localCellText(localNested(ctx, {'run','selectedNodes'}, {}));
    runRequest.node_params = localNested(ctx, {'run','nodeParams'}, struct('id', {}, 'params', {}));
    runRequest.run_policy = localText(localNested(ctx, {'run','runPolicy'}, 'resume'));
    runRequest.existing_data_policy = localText(localNested(ctx, {'io','existingPolicy'}, ''));
    runRequest.roi_cache_policy = localText(localNested(ctx, {'io','cachePolicy'}, 'auto'));
    runRequest.selection = struct( ...
        'fovs', localNested(ctx, {'sel','fovs'}, []), ...
        'frames', localNested(ctx, {'sel','frames'}, []), ...
        'channels', {localCellText(localNested(ctx, {'sel','channels'}, {}))});
    runRequest.python = localNested(ctx, {'exec','python'}, struct());
    runRequest.gpu = struct('mode', localText(localNested(ctx, {'run','gpuPolicy'}, localNested(ctx, {'exec','gpuPolicy'}, 'module_default'))));
end

function execution = localBuildExecution(opts)
    execution = struct();
    execution.allow_gui = false;
    execution.interactive = false;
    execution.save_project = opts.saveProject;
    execution.write_scope = opts.writeScope;
    execution.requested_mode = opts.requestedMode;
    if ~isempty(opts.executionTargetId)
        execution.execution_target_id = opts.executionTargetId;
    end
end

function runObj = localAttachHubJob(runObj, job, ref)
    if ~isstruct(runObj.ctx)
        runObj.ctx = struct();
    end
    if ~isfield(runObj.ctx, 'hub') || ~isstruct(runObj.ctx.hub)
        runObj.ctx.hub = struct();
    end
    runObj.ctx.hub.project_id = ref.project_id;
    runObj.ctx.hub.project_key = ref.project_key;
    runObj.ctx.hub.job_id = char(string(job.id));
    runObj.ctx.hub.status = char(string(job.status));
    runObj.ctx.hub.submitted_at = char(datetime('now'));
    runObj.ctx.hub.project_stale_after_job = true;
    runObj.status = ['hub_' char(string(job.status))];
end

function value = localNested(S, pathParts, defaultValue)
    value = defaultValue;
    cur = S;
    for i = 1:numel(pathParts)
        if ~isstruct(cur) || ~isfield(cur, pathParts{i})
            return;
        end
        cur = cur.(pathParts{i});
    end
    if ~isempty(cur)
        value = cur;
    end
end

function out = localCellText(value)
    if isempty(value)
        out = {};
    elseif iscell(value)
        out = cellfun(@(x) char(string(x)), value(:)', 'UniformOutput', false);
    elseif isstring(value)
        out = cellstr(value(:)');
    else
        out = {char(string(value))};
    end
end

function txt = localText(value)
    txt = '';
    if ~isempty(value)
        txt = char(string(value));
    end
end

function host = localHostName()
    host = '';
    try
        host = char(string(java.net.InetAddress.getLocalHost.getHostName));
    catch
    end
end
