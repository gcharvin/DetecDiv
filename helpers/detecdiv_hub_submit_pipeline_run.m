function job = detecdiv_hub_submit_pipeline_run(projectId, runObj, pipelineRef, hubSettings, varargin)
% detecdiv_hub_submit_pipeline_run  Submit an existing DetecDiv pipelineRun to detecdiv-hub.
%
% The run definition remains owned by DetecDiv. This helper only translates the
% existing run object/struct into the hub PipelineRunCreateRequest payload.

    if nargin < 3
        pipelineRef = [];
    end
    if nargin < 4
        hubSettings = [];
    end
    extraArgs = varargin;
    [projectId, runObj, pipelineRef, hubSettings, extraArgs] = ...
        localNormalizeSubmitArgs(projectId, runObj, pipelineRef, hubSettings, extraArgs);

    if nargin < 1 || strlength(string(projectId)) == 0
        error('detecdiv_hub_submit_pipeline_run:MissingProjectId', ...
            'A project id is required.');
    end
    if nargin < 2 || isempty(runObj)
        error('detecdiv_hub_submit_pipeline_run:MissingRun', ...
            'A pipelineRun object or run request struct is required.');
    end
    if isempty(pipelineRef)
        pipelineRef = struct();
    end
    if isempty(hubSettings)
        hubSettings = detecdiv_hub_settings_get();
    end

    ip = inputParser;
    ip.addParameter('PipelineId', '', @(x)ischar(x) || isstring(x));
    ip.addParameter('ExecutionTargetId', '', @(x)ischar(x) || isstring(x));
    ip.addParameter('RequestedMode', 'server', @(x)ischar(x) || isstring(x));
    ip.addParameter('Priority', 100, @(x)isnumeric(x) && isscalar(x));
    ip.addParameter('RequestedBy', '', @(x)ischar(x) || isstring(x));
    ip.addParameter('RequestedFromHost', localHostName(), @(x)ischar(x) || isstring(x));
    ip.addParameter('ProjectMatPath', '', @(x)ischar(x) || isstring(x));
    ip.addParameter('ProjectRef', struct(), @(x)isstruct(x));
    ip.addParameter('RunRequest', struct(), @(x)isstruct(x));
    ip.addParameter('Execution', struct(), @(x)isstruct(x));
    ip.addParameter('RawRootCandidates', {}, @(x)iscell(x) || isstring(x) || ischar(x));
    ip.parse(extraArgs{:});
    opts = ip.Results;

    requestedBy = strtrim(char(string(opts.RequestedBy)));
    if isempty(requestedBy) && isfield(hubSettings, 'userKey')
        requestedBy = char(string(hubSettings.userKey));
    end

    projectRef = localBuildProjectRef(projectId, runObj, opts);
    normalizedPipelineRef = localNormalizePipelineRef(pipelineRef, projectRef);
    runRequest = localMergeStruct(localRunRequestFromRunObj(runObj), opts.RunRequest);
    execution = localMergeStruct(localDefaultExecution(), opts.Execution);

    payload = struct();
    payload.project_id = char(string(projectId));
    pipelineId = strtrim(char(string(opts.PipelineId)));
    if isempty(pipelineId)
        pipelineId = localStructText(normalizedPipelineRef, 'pipeline_id');
    end
    if ~isempty(pipelineId)
        payload.pipeline_id = pipelineId;
    end
    executionTargetId = strtrim(char(string(opts.ExecutionTargetId)));
    if ~isempty(executionTargetId)
        payload.execution_target_id = executionTargetId;
    end
    payload.requested_mode = char(string(opts.RequestedMode));
    payload.priority = max(0, round(double(opts.Priority)));
    payload.requested_by = requestedBy;
    payload.requested_from_host = char(string(opts.RequestedFromHost));
    payload.project_ref = projectRef;
    payload.pipeline_ref = normalizedPipelineRef;
    payload.run_request = runRequest;
    payload.execution = execution;

    job = detecdiv_hub_create_pipeline_run(payload, hubSettings);
end

function [projectId, runObj, pipelineRef, hubSettings, extraArgs] = localNormalizeSubmitArgs(projectId, runObj, pipelineRef, hubSettings, extraArgs)
    if nargin < 5 || isempty(extraArgs)
        extraArgs = {};
    end

    % Compatibility mode for DetecDiv GUI calls:
    % detecdiv_hub_submit_pipeline_run(runObj, shallowObj, ...)
    if localIsClass(projectId, 'pipelineRun')
        runCandidate = projectId;
        projectCandidate = runObj;

        if nargin < 3 || isempty(pipelineRef)
            pipelineRef = localRunValue(runCandidate, {'pipelineRef'});
        end
        if nargin < 4 || isempty(hubSettings)
            hubSettings = detecdiv_hub_settings_get();
        end

        ref = localResolveProjectRef(projectCandidate, hubSettings);
        if isempty(ref) || ~isstruct(ref) || ~isfield(ref, 'project_id') || strlength(string(ref.project_id)) == 0
            error('detecdiv_hub_submit_pipeline_run:MissingProjectId', ...
                'Cannot resolve hub project id from the provided project object.');
        end

        projectId = char(string(ref.project_id));
        runObj = runCandidate;

        if ~any(strcmpi(extraArgs(1:2:end), 'ProjectRef'))
            extraArgs = [{'ProjectRef', ref}, extraArgs];
        end
        if isfield(ref, 'project_mat_path') && ~isempty(ref.project_mat_path) && ~any(strcmpi(extraArgs(1:2:end), 'ProjectMatPath'))
            extraArgs = [{'ProjectMatPath', char(string(ref.project_mat_path))}, extraArgs];
        end
    end
end

function ref = localResolveProjectRef(projectCandidate, hubSettings)
    ref = struct();
    if localIsClass(projectCandidate, 'shallow')
        ref = detecdiv_hub_project_ref(projectCandidate, hubSettings);
        return;
    end
    if isstruct(projectCandidate)
        ref = projectCandidate;
        if ~isfield(ref, 'project_id') && isfield(ref, 'id')
            ref.project_id = char(string(ref.id));
        end
        if ~isfield(ref, 'project_mat_path')
            ref.project_mat_path = '';
        end
        return;
    end
    if ~isempty(projectCandidate)
        ref.project_id = char(string(projectCandidate));
        ref.project_mat_path = '';
    end
end

function tf = localIsClass(value, className)
    tf = false;
    try
        tf = isa(value, className);
    catch
        tf = false;
    end
end

function projectRef = localBuildProjectRef(projectId, runObj, opts)
    projectRef = struct('project_id', char(string(projectId)));
    projectRef = localMergeStruct(projectRef, opts.ProjectRef);

    projectMatPath = strtrim(char(string(opts.ProjectMatPath)));
    if isempty(projectMatPath)
        projectMatPath = localRunText(runObj, {'projectPath'});
    end
    if isempty(projectMatPath)
        targetRef = localRunValue(runObj, {'targetRef'});
        projectMatPath = localStructText(targetRef, 'projectPath');
    end
    if ~isempty(projectMatPath)
        projectRef.project_mat_path = projectMatPath;
    end

    if ~isfield(projectRef, 'local_project_mat_path') || isempty(projectRef.local_project_mat_path)
        projectRef.local_project_mat_path = projectMatPath;
    end
    if ~isfield(projectRef, 'local_project_dir_path') || isempty(projectRef.local_project_dir_path)
        projectRef.local_project_dir_path = localProjectDirPathFromAny(projectMatPath);
    end
    if ~isfield(projectRef, 'local_project_root_path') || isempty(projectRef.local_project_root_path)
        projectRef.local_project_root_path = localPathRoot(projectRef.local_project_mat_path, projectRef.local_project_dir_path);
    end
    if ~isfield(projectRef, 'project_root_path') || isempty(projectRef.project_root_path)
        projectRef.project_root_path = projectRef.local_project_root_path;
    end

    rawRootCandidates = opts.RawRootCandidates;
    if ischar(rawRootCandidates) || isstring(rawRootCandidates)
        rawRootCandidates = cellstr(string(rawRootCandidates));
    end
    if ~isempty(rawRootCandidates)
        projectRef.raw_root_candidates = rawRootCandidates;
    end
end

function pipelineRef = localNormalizePipelineRef(in, projectRef)
    pipelineRef = struct();
    if ischar(in) || isstring(in)
        text = char(string(in));
        if ~isempty(text)
            if localLooksLikeJson(text)
                pipelineRef.pipeline_json_path = localTranslatePathForServer(text, projectRef);
            elseif exist(text, 'dir') == 7
                pipelineRef.pipeline_json_path = localTranslatePathForServer(fullfile(text, 'pipeline.json'), projectRef);
            else
                pipelineRef.pipeline_json_path = localTranslatePathForServer(text, projectRef);
            end
        end
        return;
    end
    if ~isstruct(in)
        return;
    end

    pipelineRef = in;
    if isfield(pipelineRef, 'id') && ~isempty(pipelineRef.id) && ~isfield(pipelineRef, 'pipeline_key')
        pipelineRef.pipeline_key = char(string(pipelineRef.id));
    end
    if isfield(pipelineRef, 'path') && ~isempty(pipelineRef.path)
        pathText = char(string(pipelineRef.path));
        if localLooksLikeJson(pathText)
            pipelineRef.pipeline_json_path = localTranslatePathForServer(pathText, projectRef);
        elseif exist(pathText, 'dir') == 7
            pipelineRef.pipeline_json_path = localTranslatePathForServer(fullfile(pathText, 'pipeline.json'), projectRef);
        elseif ~isfield(pipelineRef, 'pipeline_bundle_uri')
            pipelineRef.pipeline_bundle_uri = localTranslatePathForServer(pathText, projectRef);
        end
    end
end

function tf = localLooksLikeJson(pathText)
    [~, ~, ext] = fileparts(pathText);
    tf = strcmpi(ext, '.json');
end

function out = localTranslatePathForServer(pathIn, projectRef)
    out = char(string(pathIn));
    if isempty(out)
        return;
    end

    localRoots = {};
    remoteRoots = {};
    try
        if isstruct(projectRef)
            if isfield(projectRef, 'local_project_dir_path') && ~isempty(projectRef.local_project_dir_path)
                localRoots{end+1} = char(string(projectRef.local_project_dir_path)); %#ok<AGROW>
            end
            if isfield(projectRef, 'project_dir_path') && ~isempty(projectRef.project_dir_path)
                remoteRoots{end+1} = char(string(projectRef.project_dir_path)); %#ok<AGROW>
            end
            if isfield(projectRef, 'local_project_root_path') && ~isempty(projectRef.local_project_root_path)
                localRoots{end+1} = char(string(projectRef.local_project_root_path)); %#ok<AGROW>
            end
            if isfield(projectRef, 'project_root_path') && ~isempty(projectRef.project_root_path)
                remoteRoots{end+1} = char(string(projectRef.project_root_path)); %#ok<AGROW>
            end
        end
    catch
    end

    candidateNorm = strrep(out, '/', '\');
    for i = 1:min(numel(localRoots), numel(remoteRoots))
        localNorm = regexprep(strrep(localRoots{i}, '/', '\'), '[\\\/]+$', '');
        remoteNorm = regexprep(strrep(remoteRoots{i}, '\', '/'), '[\\\/]+$', '');
        if isempty(localNorm) || isempty(remoteNorm)
            continue;
        end
        if startsWith(lower(candidateNorm), lower(localNorm))
            suffix = candidateNorm(numel(localNorm)+1:end);
            suffix = strrep(suffix, '\', '/');
            out = [remoteNorm suffix];
            break;
        end
    end
    out = strrep(out, '\', '/');
end

function dirPath = localProjectDirPathFromAny(pathText)
    dirPath = '';
    try
        [dirPath, ~] = fileparts(char(string(pathText)));
    catch
        dirPath = '';
    end
end

function rootPath = localPathRoot(varargin)
    rootPath = '';
    for i = 1:nargin
        candidate = char(string(varargin{i}));
        if isempty(candidate)
            continue;
        end
        try
            [parent1, ~] = fileparts(candidate);
            [parent2, ~] = fileparts(parent1);
            if ~isempty(parent2)
                rootPath = parent2;
                return;
            end
        catch
        end
    end
end

function runRequest = localRunRequestFromRunObj(runObj)
    runRequest = struct();

    runId = localRunText(runObj, {'runId'});
    ctx = localRunValue(runObj, {'ctx'});
    ctxRun = localStructValue(ctx, 'run');
    ctxIo = localStructValue(ctx, 'io');
    ctxExec = localStructValue(ctx, 'exec');

    if isempty(runId)
        runId = localStructText(ctxRun, 'runId');
    end
    if ~isempty(runId)
        runRequest.run_id = runId;
    end

    descr = localRunText(runObj, {'description'});
    if ~isempty(descr)
        runRequest.description = descr;
    end

    selectedNodes = localStructValue(ctxRun, 'selectedNodes');
    if ~isempty(selectedNodes)
        runRequest.selected_nodes = localCellstr(selectedNodes);
    else
        runRequest.selected_nodes = {};
    end

    nodeParams = localStructValue(ctxRun, 'nodeParams');
    if isempty(nodeParams)
        nodeParams = struct('id', {}, 'params', {});
    end
    runRequest.node_params = nodeParams;

    runPolicy = localStructText(ctxRun, 'runPolicy');
    if ~isempty(runPolicy)
        runRequest.run_policy = runPolicy;
    end

    existingPolicy = localFirstText(ctxIo, {'existing_data_policy', 'existingData', 'existingPolicy'});
    if ~isempty(existingPolicy)
        runRequest.existing_data_policy = existingPolicy;
    end

    roiCachePolicy = localFirstText(ctxIo, {'roi_cache_policy', 'roiCache', 'cachePolicy'});
    if ~isempty(roiCachePolicy)
        runRequest.roi_cache_policy = roiCachePolicy;
    end

    selection = localStructValue(ctx, 'sel');
    if isstruct(selection) && ~isempty(fieldnames(selection))
        runRequest.selection = selection;
    end

    python = localStructValue(ctxExec, 'python');
    if isstruct(python) && ~isempty(fieldnames(python))
        runRequest.python = python;
    end

    gpu = localStructValue(ctxExec, 'gpu');
    if isstruct(gpu) && ~isempty(fieldnames(gpu))
        runRequest.gpu = gpu;
    else
        gpuPolicy = localFirstText(ctxExec, {'gpuPolicy', 'gpu_policy'});
        if isempty(gpuPolicy)
            gpuPolicy = localFirstText(ctxRun, {'gpuPolicy', 'gpu_policy'});
        end
        if ~isempty(gpuPolicy)
            runRequest.gpu = struct('mode', gpuPolicy);
        end
    end
end

function execution = localDefaultExecution()
    execution = struct( ...
        'allow_gui', false, ...
        'interactive', false, ...
        'save_project', true, ...
        'write_scope', 'project_update');
end

function out = localMergeStruct(base, override)
    out = base;
    if ~isstruct(override) || isempty(override)
        return;
    end
    fields = fieldnames(override);
    for i = 1:numel(fields)
        out.(fields{i}) = override.(fields{i});
    end
end

function value = localRunValue(runObj, names)
    value = [];
    for i = 1:numel(names)
        name = names{i};
        try
            if isstruct(runObj) && isfield(runObj, name)
                value = runObj.(name);
                return;
            end
            if isobject(runObj) && isprop(runObj, name)
                value = runObj.(name);
                return;
            end
        catch
        end
    end
end

function text = localRunText(runObj, names)
    text = '';
    value = localRunValue(runObj, names);
    if ~isempty(value)
        text = char(string(value));
    end
end

function value = localStructValue(in, fieldName)
    value = [];
    if isstruct(in) && isfield(in, fieldName)
        value = in.(fieldName);
    end
end

function out = localStructText(in, fieldName)
    out = '';
    if isstruct(in) && isfield(in, fieldName) && ~isempty(in.(fieldName))
        out = char(string(in.(fieldName)));
    end
end

function out = localFirstText(in, fieldNames)
    out = '';
    if ~isstruct(in)
        return;
    end
    for i = 1:numel(fieldNames)
        out = localStructText(in, fieldNames{i});
        if ~isempty(out)
            return;
        end
    end
end

function values = localCellstr(in)
    if iscell(in)
        values = cellfun(@(x)char(string(x)), in(:)', 'UniformOutput', false);
    elseif isstring(in)
        values = cellstr(in(:)');
    elseif ischar(in)
        values = {in};
    else
        values = cellstr(string(in(:)'));
    end
end

function hostName = localHostName()
    hostName = '';
    try
        hostName = char(java.net.InetAddress.getLocalHost.getHostName);
    catch
    end
    if isempty(hostName)
        hostName = char(string(getenv('COMPUTERNAME')));
    end
    if isempty(hostName)
        hostName = char(string(getenv('HOSTNAME')));
    end
end
