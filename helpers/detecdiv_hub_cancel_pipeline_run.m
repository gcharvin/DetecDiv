function job = detecdiv_hub_cancel_pipeline_run(jobId, hubSettings)
% detecdiv_hub_cancel_pipeline_run  Request cancellation for a hub pipeline_run job.

    if nargin < 1 || strlength(string(jobId)) == 0
        error('detecdiv_hub_cancel_pipeline_run:MissingJobId', ...
            'A job id is required.');
    end
    if nargin < 2 || isempty(hubSettings)
        hubSettings = detecdiv_hub_settings_get();
    end

    endpoint = sprintf('/pipeline-runs/%s/cancel', char(string(jobId)));
    job = detecdiv_hub_write_json(endpoint, struct(), hubSettings);
end
