function detecdiv_local_finalize_pipeline_run(result, job, completion)
% detecdiv_local_finalize_pipeline_run  Finalize a local batch pipeline run.

    if ~isstruct(result)
        result = localFailureResult(completion, ...
            'The local MATLAB worker returned an invalid result.');
    end
    if isfield(completion, 'lockToken') && ~isempty(completion.lockToken)
        try
            detecdiv_local_run_lock('release', completion.lockToken);
        catch
        end
    end
    if isfield(completion, 'cancelTokenFile') && ~isempty(completion.cancelTokenFile)
        try
            if exist(completion.cancelTokenFile, 'file') == 2
                delete(completion.cancelTokenFile);
            end
        catch
        end
    end
    localDeleteFinishedJob(job);
    if isfield(completion, 'registryKey') && ~isempty(completion.registryKey)
        try
            if isappdata(0, completion.registryKey)
                rmappdata(0, completion.registryKey);
            end
        catch
        end
    end

    callback = [];
    if isfield(completion, 'callback')
        callback = completion.callback;
    end
    if isa(callback, 'function_handle')
        try
            callback(result, job, completion);
        catch ME
            warning('detecdiv_local_finalize_pipeline_run:CallbackFailed', ...
                'Local run completion callback failed: %s', ME.message);
        end
    end
end

function result = localFailureResult(completion, message)
    result = struct('status', 'failed', 'run_id', '', 'project_mat_path', '', ...
        'pipeline_json_path', '', 'run_json_path', '', 'artifacts', struct([]), ...
        'summary', struct(), 'error', char(string(message)));
    if isfield(completion, 'runId')
        result.run_id = char(string(completion.runId));
    end
    if isfield(completion, 'projectPath')
        result.project_mat_path = char(string(completion.projectPath));
    end
    if isfield(completion, 'runPath')
        result.run_json_path = fullfile(char(string(completion.runPath)), 'run.json');
    end
end

function localDeleteFinishedJob(job)
    try
        if isempty(job) || ~isvalid(job)
            return;
        end
        if any(strcmpi(char(string(job.State)), {'finished','failed'}))
            delete(job);
        end
    catch
    end
end
