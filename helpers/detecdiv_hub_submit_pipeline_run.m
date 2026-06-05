function [job, runObj] = detecdiv_hub_submit_pipeline_run(runObj, shallowObj, varargin)
% detecdiv_hub_submit_pipeline_run  Submit an existing pipelineRun to detecdiv-hub.

    if nargin < 1 || isempty(runObj) || ~localIsClass(runObj, 'pipelineRun')
        error('detecdiv_hub_submit_pipeline_run:MissingRun', 'A pipelineRun object is required.');
    end
    if nargin < 2
        shallowObj = [];
    end
    projectArgClass = localClassName(shallowObj);
    shallowObj = localResolveShallowProject(runObj, shallowObj);
    if isempty(shallowObj)
        error('detecdiv_hub_submit_pipeline_run:MissingProject', ...
            'A shallow project is required. Received project argument class: %s.', projectArgClass);
    end

    opts = localRunStage('parse options', @() localParse(varargin{:}));
    ref = localRunStage('resolve hub project reference', @() detecdiv_hub_project_ref(shallowObj, opts.hub));
    if isempty(ref.project_id)
        error('detecdiv_hub_submit_pipeline_run:MissingProjectId', ...
            'This project has no hub project id. Store it in shallowObj.runProfiles.hub.hub_project_id.');
    end

    payload = struct();
    payload.project_id = ref.project_id;
    payload.requested_mode = opts.requestedMode;
    payload.priority = opts.priority;
    payload.requested_by = opts.requestedBy;
    payload.requested_from_host = localRunStage('resolve local host name', @() localHostName());
    payload.project_ref = localRunStage('build project reference payload', @() localBuildProjectRef(ref));
    payload.pipeline_ref = localRunStage('build pipeline reference payload', @() localBuildPipelineRef(runObj, ref, opts.hub));
    payload.run_request = localRunStage('build run request payload', @() localBuildRunRequest(runObj, opts.hub, ref));
    payload.execution = localRunStage('build execution payload', @() localBuildExecution(opts));

    job = localRunStage('POST /pipeline-runs', @() detecdiv_hub_request('POST', '/pipeline-runs', payload, opts.hub));
    runObj = localRunStage('attach hub job to pipelineRun', @() localAttachHubJob(runObj, job, ref));
    localRunStageNoOutput('save pipelineRun after hub submit', @() localSavePipelineRun(runObj));
end

function tf = localIsClass(value, className)
    tf = false;
    try
        tf = isa(value, className);
    catch
        tf = false;
    end
end

function shallowObj = localResolveShallowProject(runObj, candidate)
    shallowObj = [];
    if localIsClass(candidate, 'shallow')
        shallowObj = candidate;
        return;
    end

    shallowObj = localFindProjectInBaseWorkspace(runObj);
end

function shallowObj = localFindProjectInBaseWorkspace(runObj)
    shallowObj = [];
    try
        names = evalin('base', 'who');
    catch
        names = {};
    end
    for i = 1:numel(names)
        try
            candidate = evalin('base', names{i});
            if ~localIsClass(candidate, 'shallow')
                continue;
            end
            if localProjectContainsRun(candidate, runObj)
                shallowObj = candidate;
                return;
            end
        catch
        end
    end
end

function tf = localProjectContainsRun(shallowObj, runObj)
    tf = false;
    try
        if ~isfield(shallowObj.processing, 'pipelineRun') || isempty(shallowObj.processing.pipelineRun)
            return;
        end
        runs = shallowObj.processing.pipelineRun;
        for i = 1:numel(runs)
            try
                if runs(i) == runObj
                    tf = true;
                    return;
                end
            catch
            end
            try
                if strcmp(char(string(runs(i).runId)), char(string(runObj.runId)))
                    tf = true;
                    return;
                end
            catch
            end
        end
    catch
    end
end

function name = localClassName(value)
    name = '<empty>';
    try
        if ~isempty(value)
            name = class(value);
        end
    catch
        name = '<unknown>';
    end
end

function out = localRunStage(stageName, fn)
    try
        out = fn();
    catch ME
        throwAsCaller(localWrapStageError(stageName, ME));
    end
end

function localRunStageNoOutput(stageName, fn)
    try
        fn();
    catch ME
        throwAsCaller(localWrapStageError(stageName, ME));
    end
end

function localSavePipelineRun(runObj)
    pipelineRunSave(runObj);
end

function wrapped = localWrapStageError(stageName, ME)
    msg = sprintf('Hub submit failed during "%s": %s', char(string(stageName)), ME.message);
    if ~isempty(ME.identifier)
        msg = sprintf('%s\nIdentifier: %s', msg, ME.identifier);
    end
    if ~isempty(ME.stack)
        lines = cell(1, min(numel(ME.stack), 6));
        for i = 1:numel(lines)
            lines{i} = sprintf('%s:%d', ME.stack(i).name, ME.stack(i).line);
        end
        msg = sprintf('%s\nStack:\n%s', msg, strjoin(lines, newline));
    end
    wrapped = MException('detecdiv_hub_submit_pipeline_run:StageFailed', '%s', msg);
    wrapped = addCause(wrapped, ME);
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
    if isfield(ref, 'local_project_mat_path') && ~isempty(ref.local_project_mat_path)
        projectRef.local_project_mat_path = ref.local_project_mat_path;
    else
        projectRef.local_project_mat_path = ref.project_mat_path;
    end
    projectRef.project_mat_path = ref.project_mat_path;
end

function pipelineRef = localBuildPipelineRef(runObj, ref, hub)
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
            pipelineRef.pipeline_json_path = localPipelineJsonPath(runObj.pipelineRef.path, ref, hub);
        end
    catch
    end
    if isempty(pipelineRef.pipeline_json_path)
        try
            pipelineRef.pipeline_json_path = localPipelineJsonPath(runObj.templatePath, ref, hub);
        catch
        end
    end
end

function pathOut = localPipelineJsonPath(pathIn, ref, hub)
    pathOut = char(string(pathIn));
    if isfolder(pathOut)
        pathOut = fullfile(pathOut, 'pipeline.json');
    end
    pathOut = localTranslatePathForServer(pathOut, ref, hub);
end

function [out, translated] = localTranslatePathForServer(pathIn, ref, hub)
    out = char(string(pathIn));
    translated = false;
    if isempty(out)
        return;
    end

    localRoots = {};
    remoteRoots = {};
    try
        if isfield(ref, 'local_project_dir_path') && ~isempty(ref.local_project_dir_path)
            localRoots{end+1} = char(string(ref.local_project_dir_path));
        end
        if isfield(ref, 'project_dir_path') && ~isempty(ref.project_dir_path)
            remoteRoots{end+1} = char(string(ref.project_dir_path));
        end
        if isfield(ref, 'local_project_root_path') && ~isempty(ref.local_project_root_path)
            localRoots{end+1} = char(string(ref.local_project_root_path));
        end
        if isfield(ref, 'project_root_path') && ~isempty(ref.project_root_path)
            remoteRoots{end+1} = char(string(ref.project_root_path));
        end
    catch
    end
    try
        if nargin >= 3 && isstruct(hub)
            if isfield(hub, 'pathMappings') && ~isempty(hub.pathMappings)
                for i = 1:numel(hub.pathMappings)
                    if isfield(hub.pathMappings(i), 'localRoot') && isfield(hub.pathMappings(i), 'remoteRoot')
                        localRoots{end+1} = char(string(hub.pathMappings(i).localRoot)); %#ok<AGROW>
                        remoteRoots{end+1} = char(string(hub.pathMappings(i).remoteRoot)); %#ok<AGROW>
                    end
                end
            end
            if isfield(hub, 'defaultLocalProjectRoot') && isfield(hub, 'defaultRemoteProjectRoot') && ...
                    ~isempty(hub.defaultLocalProjectRoot) && ~isempty(hub.defaultRemoteProjectRoot)
                localRoots{end+1} = char(string(hub.defaultLocalProjectRoot)); %#ok<AGROW>
                remoteRoots{end+1} = char(string(hub.defaultRemoteProjectRoot)); %#ok<AGROW>
            end
        end
    catch
    end

    candidateNorm = strrep(out, '/', '\');
    bestLen = -1;
    bestOut = out;
    for i = 1:min(numel(localRoots), numel(remoteRoots))
        localNorm = regexprep(strrep(localRoots{i}, '/', '\'), '[\\\/]+$', '');
        remoteNorm = regexprep(strrep(remoteRoots{i}, '\', '/'), '[\\\/]+$', '');
        if isempty(localNorm) || isempty(remoteNorm)
            continue;
        end
        if localPathStartsWithRoot(candidateNorm, localNorm) && numel(localNorm) > bestLen
            suffix = candidateNorm(numel(localNorm)+1:end);
            suffix = strrep(suffix, '\', '/');
            bestLen = numel(localNorm);
            bestOut = [remoteNorm suffix];
        end
    end
    if bestLen >= 0
        out = bestOut;
        translated = true;
    end

    % Ensure POSIX separators for server-side worker.
    out = strrep(out, '\', '/');
end

function tf = localPathStartsWithRoot(pathValue, rootValue)
    pathCmp = lower(char(string(pathValue)));
    rootCmp = lower(char(string(rootValue)));
    tf = startsWith(pathCmp, rootCmp);
    if ~tf
        return;
    end
    if numel(pathCmp) == numel(rootCmp)
        return;
    end
    if endsWith(rootCmp, ':')
        return;
    end
    nextChar = pathCmp(numel(rootCmp)+1);
    tf = any(nextChar == ['\' '/']);
end

function runRequest = localBuildRunRequest(runObj, hub, ref)
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
    runRequest.node_params = localTranslateValuePathsForServer( ...
        localNested(ctx, {'run','nodeParams'}, struct('id', {}, 'params', {})), ref, hub);
    runRequest.run_policy = localText(localNested(ctx, {'run','runPolicy'}, 'resume'));
    runRequest.existing_data_policy = localText(localNested(ctx, {'io','existingPolicy'}, ''));
    runRequest.roi_cache_policy = localText(localNested(ctx, {'io','cachePolicy'}, 'auto'));
    runRequest.paths = localBuildRunPaths(ctx, ref, hub);
    runRequest.selection = struct( ...
        'fovs', localNested(ctx, {'sel','fovs'}, []), ...
        'frames', localNested(ctx, {'sel','frames'}, []), ...
        'rois', localNested(ctx, {'sel','rois'}, []), ...
        'channels', {localCellText(localNested(ctx, {'sel','channels'}, {}))});
    runRequest.control = localBuildRunControl(ctx);
    runRequest.python = localNested(ctx, {'exec','python'}, struct());
    runRequest.gpu = struct('mode', localText(localNested(ctx, {'run','gpuPolicy'}, localNested(ctx, {'exec','gpuPolicy'}, 'module_default'))));
end

function paths = localBuildRunPaths(ctx, ref, hub)
    rawDataPath = localText(localNested(ctx, {'run','rawDataPath'}, localNested(ctx, {'io','rawDataPath'}, localNested(ctx, {'rawDataPath'}, ''))));
    projectPath = localText(localNested(ctx, {'run','projectPath'}, localNested(ctx, {'io','projectPath'}, localNested(ctx, {'projectPath'}, ''))));
    paths = struct();
    paths.raw_data_path = rawDataPath;
    paths.project_path = projectPath;
    paths.server_raw_data_path = localText(localNested(ctx, {'run','serverRawDataPath'}, localNested(ctx, {'io','serverRawDataPath'}, '')));
    paths.server_project_path = localText(localNested(ctx, {'run','serverProjectPath'}, localNested(ctx, {'io','serverProjectPath'}, '')));
    if isempty(paths.server_raw_data_path) && ~isempty(rawDataPath)
        paths.server_raw_data_path = localTranslatePathForServer(rawDataPath, ref, hub);
    end
    if isempty(paths.server_project_path) && ~isempty(projectPath)
        paths.server_project_path = localTranslatePathForServer(projectPath, ref, hub);
    end
    paths.server_project_data_folder = localText(localNested(ctx, {'run','serverProjectDataFolder'}, localNested(ctx, {'io','serverProjectDataFolder'}, '')));
    paths.path_mappings = localHubPathMappings(hub);
end

function value = localTranslateValuePathsForServer(value, ref, hub)
    if isstruct(value)
        for i = 1:numel(value)
            names = fieldnames(value(i));
            for j = 1:numel(names)
                value(i).(names{j}) = localTranslateValuePathsForServer(value(i).(names{j}), ref, hub);
            end
        end
    elseif iscell(value)
        for i = 1:numel(value)
            value{i} = localTranslateValuePathsForServer(value{i}, ref, hub);
        end
    elseif isstring(value)
        for i = 1:numel(value)
            textValue = char(value(i));
            if localLooksLikePathText(textValue)
                value(i) = string(localTranslatePathForServer(textValue, ref, hub));
            end
        end
    elseif ischar(value)
        if localLooksLikePathText(value)
            value = localTranslatePathForServer(value, ref, hub);
        end
    end
end

function tf = localLooksLikePathText(value)
    value = char(string(value));
    tf = ~isempty(regexp(value, '^[A-Za-z]:[\\/]', 'once')) || ...
        startsWith(value, '\') || startsWith(value, '/') || ...
        contains(value, '\') || contains(value, '/');
end

function mappings = localHubPathMappings(hub)
    mappings = struct('remoteRoot', {}, 'localRoot', {});
    try
        if isstruct(hub) && isfield(hub, 'pathMappings') && ~isempty(hub.pathMappings)
            mappings = hub.pathMappings;
        end
    catch
        mappings = struct('remoteRoot', {}, 'localRoot', {});
    end
end

function control = localBuildRunControl(ctx)
    control = struct();
    control.resume_policy = localText(localNested(ctx, {'run','runPolicy'}, 'resume'));
    control.cancel_policy = 'cooperative';
    control.progress_granularity = 'roi';
    control.local_cancel_mode = 'file_token';
    control.hub_cancel_mode = 'hub_job_cancel';
    control.hub_cancel_endpoint = '/pipeline-runs/{job_id}/cancel';
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
