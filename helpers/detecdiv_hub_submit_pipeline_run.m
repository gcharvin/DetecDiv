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
        [shallowObj, ref, ensureStatus] = localRunStage('ensure hub project registration', ...
            @() detecdiv_hub_ensure_project(shallowObj, 'Hub', opts.hub, ...
                'ErrorIfQueued', false, ...
                'InitialWaitSec', opts.projectResolveInitialWaitSec, ...
                'ResolveAttempts', opts.projectResolveAttempts, ...
                'ResolveIntervalSec', opts.projectResolveIntervalSec));
        if ~isempty(ref.project_id)
            localRunStageNoOutput('save project after hub registration check', @() localSaveProject(shallowObj, opts.hub));
        end
        if isempty(ref.project_id)
            msg = ['This project is not yet registered in the Hub project catalogue.' newline ...
                char(string(ensureStatus.message)) newline ...
                'Project indexing path: ' char(string(ensureStatus.attemptedPath)) newline ...
                'Retry Hub submission after the Hub indexing job completes.'];
            if isfield(ensureStatus, 'job') && isstruct(ensureStatus.job) && isfield(ensureStatus.job, 'job_id')
                msg = [msg newline 'Hub indexing job id: ' char(string(ensureStatus.job.job_id))]; %#ok<AGROW>
            elseif isfield(ensureStatus, 'job') && isstruct(ensureStatus.job) && isfield(ensureStatus.job, 'id')
                msg = [msg newline 'Hub indexing job id: ' char(string(ensureStatus.job.id))]; %#ok<AGROW>
            end
            error('detecdiv_hub_submit_pipeline_run:ProjectIndexQueued', '%s', msg);
        end
    else
        [shallowObj, ref] = localRunStage('store resolved hub project reference', ...
            @() detecdiv_hub_ensure_project(shallowObj, 'Hub', opts.hub, 'ResolveAttempts', 1));
        localRunStageNoOutput('save project after hub project resolution', @() localSaveProject(shallowObj, opts.hub));
    end

    payload = struct();
    payload.project_id = ref.project_id;
    payload.requested_mode = opts.requestedMode;
    payload.priority = opts.priority;
    payload.requested_by = opts.requestedBy;
    payload.requested_from_host = localRunStage('resolve local host name', @() localHostName());
    payload.project_ref = localRunStage('build project reference payload', @() localBuildProjectRef(ref, opts.hub));
    payload.pipeline_ref = localRunStage('build pipeline reference payload', @() localBuildPipelineRef(runObj, ref, opts.hub));
    payload.run_request = localRunStage('build run request payload', @() localBuildRunRequest(runObj, opts.hub, ref));
    payload.execution = localRunStage('build execution payload', @() localBuildExecution(opts));

    localRunStageNoOutput('release local hub edit lease', @() detecdiv_hub_release_project_open(shallowObj, opts.hub));
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

function varargout = localRunStage(stageName, fn)
    try
        [varargout{1:nargout}] = fn();
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

function localSaveProject(shallowObj, hub)
    localEnsureProjectSavePathIsLocal(shallowObj, hub);
    try
        shallowSave(shallowObj, 'shallowObj');
    catch
    end
end

function localEnsureProjectSavePathIsLocal(shallowObj, hub)
    try
        if isempty(shallowObj) || ~isprop(shallowObj, 'io') || ~isstruct(shallowObj.io) || ...
                ~isfield(shallowObj.io, 'path') || isempty(shallowObj.io.path)
            return;
        end
        ctx = struct();
        ctx.hub = hub;
        [localPath, mapped] = detecdiv_paths_map_module_path(shallowObj.io.path, ctx, 'local');
        if mapped && ~isempty(localPath)
            shallowObj.io.path = localPath;
        end
    catch
    end
end

function wrapped = localWrapStageError(stageName, ME)
    locked = localProjectLockedStageError(stageName, ME);
    if ~isempty(locked)
        wrapped = locked;
        return;
    end

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

function wrapped = localProjectLockedStageError(stageName, ME)
    wrapped = [];
    if ~strcmp(ME.identifier, 'detecdiv_hub_request:HTTP409')
        return;
    end

    lockInfo = localDecodeHubLockMessage(ME.message);
    if isempty(lockInfo)
        return;
    end

    lines = {
        'This project is locked on DetecDiv Hub.'
        localLockHumanSummary(lockInfo)
        ''
        'A new Hub run cannot be submitted until the active job finishes, is cancelled, or the lock is released.'
        'Use the Run Monitor to follow or cancel the active run, then retry submission.'
        };
    msg = strjoin(lines, newline);
    if ~isempty(stageName)
        msg = sprintf('%s\n\nHub stage: %s', msg, char(string(stageName)));
    end

    wrapped = MException('detecdiv_hub_submit_pipeline_run:ProjectLocked', '%s', msg);
    wrapped = addCause(wrapped, ME);
end

function lockInfo = localDecodeHubLockMessage(messageText)
    lockInfo = [];
    raw = char(string(messageText));
    try
        payload = jsondecode(raw);
    catch
        return;
    end
    if ~isstruct(payload) || ~isfield(payload, 'locks')
        return;
    end
    msg = localTextField(payload, 'message', '');
    if ~contains(lower(msg), 'locked')
        return;
    end

    locks = payload.locks;
    if isempty(locks)
        return;
    end
    if numel(locks) > 1
        locks = locks(1);
    end

    lockInfo = struct();
    lockInfo.message = msg;
    lockInfo.lockKind = localTextField(locks, 'lock_kind', '');
    lockInfo.jobId = localTextField(locks, 'job_id', '');
    lockInfo.holderKey = localTextField(locks, 'holder_key', '');
    lockInfo.holderHost = localTextField(locks, 'holder_host', '');
    lockInfo.reason = localTextField(locks, 'reason', '');
    lockInfo.expiresAt = localTextField(locks, 'expires_at', '');
end

function value = localTextField(s, fieldName, fallback)
    value = fallback;
    try
        if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
            value = char(string(s.(fieldName)));
        end
    catch
        value = fallback;
    end
end

function msg = localLockHumanSummary(lockInfo)
    if strcmpi(lockInfo.lockKind, 'server_job')
        msg = 'Another Hub pipeline run is currently using this project.';
    elseif strcmpi(lockInfo.lockKind, 'client_edit_lease')
        msg = 'This project is currently open for editing in a DetecDiv client.';
    else
        msg = 'Hub has an active project lock.';
    end

    details = {};
    if ~isempty(lockInfo.jobId)
        details{end+1} = ['Job id: ' lockInfo.jobId]; %#ok<AGROW>
    end
    if ~isempty(lockInfo.reason)
        details{end+1} = ['Reason: ' lockInfo.reason]; %#ok<AGROW>
    end
    if ~isempty(lockInfo.holderHost)
        details{end+1} = ['Host: ' lockInfo.holderHost]; %#ok<AGROW>
    end
    if ~isempty(lockInfo.expiresAt)
        details{end+1} = ['Expires: ' lockInfo.expiresAt]; %#ok<AGROW>
    end

    if ~isempty(details)
        msg = [msg newline strjoin(details, newline)];
    end
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
    opts.projectResolveInitialWaitSec = 1;
    opts.projectResolveAttempts = 60;
    opts.projectResolveIntervalSec = 3;
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
            case {'projectresolveinitialwaitsec','initialwaitsec'}
                opts.projectResolveInitialWaitSec = double(value);
            case {'projectresolveattempts','resolveattempts'}
                opts.projectResolveAttempts = double(value);
            case {'projectresolveintervalsec','resolveintervalsec'}
                opts.projectResolveIntervalSec = double(value);
        end
        i = i + 2;
    end
    if isempty(opts.requestedBy) && isfield(opts.hub, 'userKey')
        opts.requestedBy = char(string(opts.hub.userKey));
    end
end

function projectRef = localBuildProjectRef(ref, hub)
    projectRef = struct();
    projectRef.project_id = ref.project_id;
    projectRef.project_key = ref.project_key;
    projectRef.project_name = ref.project_name;
    if isfield(ref, 'local_project_mat_path') && ~isempty(ref.local_project_mat_path)
        projectRef.local_project_mat_path = ref.local_project_mat_path;
    else
        projectRef.local_project_mat_path = ref.project_mat_path;
    end
    projectRef.project_mat_path = localTranslatePathForServer(ref.project_mat_path, ref, hub);
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
    [out, translated] = detecdiv_paths_map_module_path(out, localPathMappingCtx(ref, hub), 'server');
    % Ensure POSIX separators for server-side worker.
    out = strrep(out, '\', '/');
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
    runRequest.node_params = localBuildNodeParamsList( ...
        localNested(ctx, {'run','nodeParams'}, struct()), runRequest.selected_nodes, ref, hub);
    runRequest.run_policy = localText(localNested(ctx, {'run','runPolicy'}, 'resume'));
    runRequest.input_source = localText(localNested(ctx, {'run','inputSource'}, ''));
    runRequest.existing_data_policy = localText(localNested(ctx, {'io','existingPolicy'}, ''));
    runRequest.roi_cache_policy = localText(localNested(ctx, {'io','cachePolicy'}, 'auto'));
    runRequest.paths = localBuildRunPaths(ctx, ref, hub);
    runRequest.selection = struct( ...
        'fovs', localNested(ctx, {'sel','fovs'}, []), ...
        'frames', localNested(ctx, {'sel','frames'}, []), ...
        'rois', localNested(ctx, {'sel','rois'}, []), ...
        'channels', {localCellText(localNested(ctx, {'sel','channels'}, {}))});
    runRequest.available_channels = localCellText(localNested(ctx, {'run','availableChannels'}, localNested(ctx, {'channels'}, {})));
    runRequest.roi_channels = localCellText(localNested(ctx, {'roiChannels'}, localNested(ctx, {'run','availableChannels'}, {})));
    runRequest.masks = localCellText(localNested(ctx, {'masks'}, {}));
    runRequest.data_series = localCellText(localNested(ctx, {'dataSeriesNames'}, localNested(ctx, {'dataSeries'}, {})));
    runRequest.control = localBuildRunControl(ctx);
    runRequest.python = localNested(ctx, {'exec','python'}, struct());
    runRequest.gpu = struct('mode', localText(localNested(ctx, {'run','gpuPolicy'}, localNested(ctx, {'exec','gpuPolicy'}, 'module_default'))));
end

function items = localBuildNodeParamsList(nodeParams, selectedNodes, ref, hub)
    items = {};
    if isempty(nodeParams)
        return;
    end

    if iscell(nodeParams)
        for i = 1:numel(nodeParams)
            item = localNormalizeNodeParamEntry(nodeParams{i}, '', ref, hub);
            if ~isempty(item)
                items{end+1} = item; %#ok<AGROW>
            end
        end
        return;
    end

    if ~isstruct(nodeParams)
        return;
    end

    if isfield(nodeParams, 'id') && isfield(nodeParams, 'params')
        for i = 1:numel(nodeParams)
            item = localNormalizeNodeParamEntry(nodeParams(i), '', ref, hub);
            if ~isempty(item)
                items{end+1} = item; %#ok<AGROW>
            end
        end
        return;
    end

    keys = fieldnames(nodeParams);
    used = false(size(keys));
    selectedNodes = localCellText(selectedNodes);
    for i = 1:numel(selectedNodes)
        nodeId = char(string(selectedNodes{i}));
        key = localNodeParamsKey(nodeParams, nodeId);
        if isempty(key)
            continue;
        end
        item = localNormalizeNodeParamEntry(nodeParams.(key), nodeId, ref, hub);
        if ~isempty(item)
            items{end+1} = item; %#ok<AGROW>
        end
        used(strcmp(keys, key)) = true;
    end

    for i = 1:numel(keys)
        if used(i)
            continue;
        end
        key = keys{i};
        item = localNormalizeNodeParamEntry(nodeParams.(key), key, ref, hub);
        if ~isempty(item)
            items{end+1} = item; %#ok<AGROW>
        end
    end
end

function key = localNodeParamsKey(nodeParams, nodeId)
    key = '';
    if isfield(nodeParams, nodeId)
        key = nodeId;
        return;
    end
    validKey = matlab.lang.makeValidName(nodeId);
    if isfield(nodeParams, validKey)
        key = validKey;
    end
end

function item = localNormalizeNodeParamEntry(value, fallbackId, ref, hub)
    item = [];
    nodeId = fallbackId;
    params = value;
    if isstruct(value) && isfield(value, 'id') && isfield(value, 'params')
        nodeId = localText(value.id);
        params = value.params;
    end
    if isempty(nodeId)
        return;
    end
    if isempty(params)
        params = struct();
    end
    item = struct('id', char(string(nodeId)), ...
        'params', localTranslateValuePathsForServer(params, ref, hub));
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
    mappings = detecdiv_paths_module_mappings(localPathMappingCtx(struct(), hub));
end

function ctx = localPathMappingCtx(ref, hub)
    ctx = struct();
    if nargin >= 2 && isstruct(hub)
        ctx.hub = hub;
    else
        ctx.hub = struct();
    end
    extra = struct('localRoot', {}, 'remoteRoot', {});
    try
        if isstruct(ref) && isfield(ref, 'local_project_dir_path') && isfield(ref, 'project_dir_path') && ...
                ~isempty(ref.local_project_dir_path) && ~isempty(ref.project_dir_path)
            extra(end+1).localRoot = char(string(ref.local_project_dir_path)); %#ok<AGROW>
            extra(end).remoteRoot = char(string(ref.project_dir_path));
        end
        if isstruct(ref) && isfield(ref, 'local_project_root_path') && isfield(ref, 'project_root_path') && ...
                ~isempty(ref.local_project_root_path) && ~isempty(ref.project_root_path)
            extra(end+1).localRoot = char(string(ref.local_project_root_path)); %#ok<AGROW>
            extra(end).remoteRoot = char(string(ref.project_root_path));
        end
    catch
    end
    if ~isempty(extra)
        existing = struct('localRoot', {}, 'remoteRoot', {});
        try
            if isfield(ctx.hub, 'pathMappings') && isstruct(ctx.hub.pathMappings)
                existing = ctx.hub.pathMappings;
            end
        catch
        end
        ctx.hub.pathMappings = [extra existing];
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
