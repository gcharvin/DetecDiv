function detecdiv_local_watch_pipeline_result(resultPath, resultQueue, timeoutSeconds)
% detecdiv_local_watch_pipeline_result  Wait off-thread for a worker result.

    if nargin < 3 || isempty(timeoutSeconds)
        timeoutSeconds = 7 * 24 * 60 * 60;
    end
    resultPath = char(string(resultPath));
    started = tic;
    while toc(started) < timeoutSeconds
        if exist(resultPath, 'file') == 2
            try
                result = jsondecode(fileread(resultPath));
                pause(0.5);
                send(resultQueue, result);
                return;
            catch
                % The worker may still be completing its atomic file write.
            end
        end
        pause(0.2);
    end

    result = struct('status', 'failed', 'run_id', '', ...
        'project_mat_path', '', 'pipeline_json_path', '', ...
        'run_json_path', '', 'artifacts', struct([]), ...
        'summary', struct(), ...
        'error', sprintf('Timed out waiting for local worker result: %s', resultPath));
    send(resultQueue, result);
end
