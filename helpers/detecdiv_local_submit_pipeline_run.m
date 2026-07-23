function submission = detecdiv_local_submit_pipeline_run(runObj, project, pipelineInputPath, varargin)
% detecdiv_local_submit_pipeline_run  Submit a pipeline run to a process worker.

    ip = inputParser;
    ip.addParameter('CompletionCallback', [], @(x)isempty(x) || isa(x, 'function_handle'));
    ip.addParameter('EventCallback', [], @(x)isempty(x) || isa(x, 'function_handle'));
    ip.addParameter('PoolSize', 1, @(x)isnumeric(x) && isscalar(x) && x >= 1);
    ip.parse(varargin{:});
    opts = ip.Results;

    if ~license('test', 'Distrib_Computing_Toolbox')
        error('detecdiv_local_submit_pipeline_run:MissingToolbox', ...
            'Parallel Computing Toolbox is required for process-backed local runs.');
    end
    if isempty(runObj) || ~isa(runObj, 'pipelineRun')
        error('detecdiv_local_submit_pipeline_run:MissingRun', ...
            'A pipelineRun object is required.');
    end

    runPath = char(string(runObj.path));
    if isempty(runPath)
        error('detecdiv_local_submit_pipeline_run:MissingRunPath', ...
            'The pipeline run must be saved before local submission.');
    end
    if exist(runPath, 'dir') ~= 7
        mkdir(runPath);
    end

    cancelTokenFile = fullfile(runPath, 'cancel.request');
    resultPath = fullfile(runPath, 'local_process_result.json');
    progressPath = fullfile(runPath, 'progress.json');
    consolePath = fullfile(runPath, 'worker_console.log');
    localDeleteIfPresent(cancelTokenFile);
    localDeleteIfPresent(resultPath);
    localDeleteIfPresent(progressPath);
    localDeleteIfPresent(consolePath);

    lockRecord = [];
    if isa(project, 'shallow') || ischar(project) || isstring(project)
        lockRecord = detecdiv_local_run_lock('acquire', project, runObj.runId);
    end
    job = [];
    try
        payload = pipelineRunJobPayload(runObj, project, pipelineInputPath, ...
            'RequestedMode', 'local_process', ...
            'ResultPath', resultPath, ...
            'CancelTokenFile', cancelTokenFile, ...
            'ProgressPath', progressPath, ...
            'ConsolePath', consolePath, ...
            'SaveProject', true, ...
            'SaveProjectMode', 'shallowObj');

        if round(double(opts.PoolSize)) ~= 1
            error('detecdiv_local_submit_pipeline_run:PoolSize', ...
                'Local pipeline runs currently use one isolated MATLAB batch worker.');
        end
        completion = struct( ...
            'lockToken', localLockToken(lockRecord), ...
            'registryKey', localRegistryKey(lockRecord), ...
            'resultPath', resultPath, ...
            'cancelTokenFile', cancelTokenFile, ...
            'runPath', runPath, ...
            'runId', char(string(runObj.runId)), ...
            'projectPath', localProjectPath(project), ...
            'callback', opts.CompletionCallback);

        repoRoot = fileparts(fileparts(mfilename('fullpath')));
        cluster = parcluster('Processes');
        batchArgs = { ...
            'CurrentFolder', repoRoot, ...
            'AutoAddClientPath', false, ...
            'AutoAttachFiles', false, ...
            'Pool', 0};
        environmentVariables = localWorkerEnvironmentVariables();
        if ~isempty(environmentVariables)
            batchArgs = [batchArgs {'EnvironmentVariables', environmentVariables}]; %#ok<AGROW>
        end
        job = batch(cluster, @detecdiv_run_pipeline_job_guarded, 1, {payload}, ...
            batchArgs{:});
        resultQueue = parallel.pool.DataQueue;
        resultListener = afterEach(resultQueue, ...
            @(result)detecdiv_local_finalize_pipeline_run(result, job, completion));
        eventQueue = parallel.pool.DataQueue;
        eventListener = [];
        if ~isempty(opts.EventCallback)
            eventListener = afterEach(eventQueue, opts.EventCallback);
        end
        watcherFuture = parfeval(backgroundPool, ...
            @detecdiv_local_watch_pipeline_result, 0, ...
            resultPath, resultQueue, 7 * 24 * 60 * 60, ...
            consolePath, progressPath, eventQueue);

        submission = struct( ...
            'future', watcherFuture, ...
            'completionFuture', watcherFuture, ...
            'job', job, ...
            'resultQueue', resultQueue, ...
            'resultListener', resultListener, ...
            'eventQueue', eventQueue, ...
            'eventListener', eventListener, ...
            'payload', payload, ...
            'lock', lockRecord, ...
            'resultPath', resultPath, ...
            'progressPath', progressPath, ...
            'consolePath', consolePath, ...
            'cancelTokenFile', cancelTokenFile, ...
            'runPath', runPath);
        if ~isempty(completion.registryKey)
            setappdata(0, completion.registryKey, submission);
        end
    catch ME
        localDeleteJobOnFailure(job);
        localReleaseOnFailure(lockRecord);
        rethrow(ME);
    end
end

function key = localRegistryKey(record)
    token = localLockToken(record);
    if isempty(token)
        token = char(java.util.UUID.randomUUID);
    end
    key = matlab.lang.makeValidName(['DetecDivLocalRunSubmission_' token]);
end

function names = localWorkerEnvironmentVariables()
    candidates = { ...
        'DETECDIV_WSL_DISTRO', ...
        'DETECDIV_WSL_ENV_PATH', ...
        'SAM31_BACKEND', ...
        'SAM31_PYTHON_EXE', ...
        'SAM31_RUNNER_MODE', ...
        'SAM31_WSL_DISTRO', ...
        'SAM31_WSL_PYTHON_EXE', ...
        'PYTHONPATH'};
    names = {};
    for i = 1:numel(candidates)
        if ~isempty(getenv(candidates{i}))
            names{end+1} = candidates{i}; %#ok<AGROW>
        end
    end
end

function token = localLockToken(record)
    token = '';
    if isstruct(record) && isfield(record, 'token') && ~isempty(record.token)
        token = char(string(record.token));
    end
end

function pathText = localProjectPath(project)
    pathText = '';
    if isa(project, 'shallow')
        try
            [projectDir, projectName] = project.getPath;
            pathText = fullfile(projectDir, [projectName '.mat']);
        catch
        end
    elseif ischar(project) || isstring(project)
        pathText = char(string(project));
    end
end

function localReleaseOnFailure(record)
    if ~isstruct(record) || ~isfield(record, 'token') || isempty(record.token)
        return;
    end
    try
        detecdiv_local_run_lock('release', record.token);
    catch
    end
end

function localDeleteJobOnFailure(job)
    try
        if ~isempty(job) && isvalid(job)
            cancel(job);
            delete(job);
        end
    catch
    end
end

function localDeleteIfPresent(pathText)
    if exist(pathText, 'file') == 2
        delete(pathText);
    end
end
