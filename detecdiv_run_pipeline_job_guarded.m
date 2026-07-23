function result = detecdiv_run_pipeline_job_guarded(payload)
% detecdiv_run_pipeline_job_guarded  Ensure a batch worker always reports.

    resultPath = localText(payload, {'execution','result_json_path'});
    try
        result = detecdiv_run_pipeline_job(payload);
        return;
    catch ME
        if ~isempty(resultPath) && exist(resultPath, 'file') == 2
            try
                result = jsondecode(fileread(resultPath));
                return;
            catch
            end
        end
        result = localFailure(payload, ME);
        localWriteResult(resultPath, result);
    end
end

function result = localFailure(payload, ME)
    result = struct( ...
        'status', 'failed', ...
        'job_id', localText(payload, {'job_id'}), ...
        'run_id', localText(payload, {'run_request','run_id'}), ...
        'project_mat_path', localText(payload, {'project_ref','project_mat_path'}), ...
        'pipeline_json_path', localText(payload, {'pipeline_ref','pipeline_json_path'}), ...
        'run_json_path', '', ...
        'artifacts', struct('kind', {}, 'path', {}), ...
        'summary', struct(), ...
        'error', getReport(ME, 'extended', 'hyperlinks', 'off'));
end

function value = localText(S, path)
    value = '';
    current = S;
    try
        for i = 1:numel(path)
            if ~isstruct(current) || ~isfield(current, path{i})
                return;
            end
            current = current.(path{i});
        end
        if ~isempty(current)
            value = char(string(current));
        end
    catch
        value = '';
    end
end

function localWriteResult(pathText, result)
    if isempty(pathText)
        return;
    end
    folder = fileparts(pathText);
    if ~isempty(folder) && exist(folder, 'dir') ~= 7
        mkdir(folder);
    end
    fid = fopen(pathText, 'w');
    if fid < 0
        return;
    end
    cleanup = onCleanup(@()fclose(fid)); %#ok<NASGU>
    fwrite(fid, jsonencode(result, 'PrettyPrint', true), 'char');
end
