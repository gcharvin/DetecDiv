function detecdiv_hub_run_legacy_matlab_job(jobJsonPath)
% Execute one published legacy routine described by a Hub JSON payload.
payload = jsondecode(fileread(jobJsonPath));
try
    addpath(fileparts(payload.routine_path));
    args = {};
    if isfield(payload, 'arguments') && ~isempty(payload.arguments)
        args = payload.arguments;
        if ~iscell(args), args = {args}; end
    end
    result = feval(payload.function_name, args{:});
    if isempty(result), result = struct(); end
    if ~isstruct(result), result = struct('value', result); end
    result.status = 'done';
    result.job_id = payload.job_id;
catch ME
    result = struct('status', 'failed', 'job_id', payload.job_id, ...
        'error', getReport(ME, 'extended', 'hyperlinks', 'off'));
    writeResult(payload.result_json_path, result);
    rethrow(ME);
end
writeResult(payload.result_json_path, result);
end

function writeResult(pathText, result)
fid = fopen(pathText, 'w');
assert(fid >= 0, 'Could not write Hub result JSON.');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s', jsonencode(result));
end
