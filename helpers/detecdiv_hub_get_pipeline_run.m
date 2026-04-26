function job = detecdiv_hub_get_pipeline_run(jobId, hubSettings)
% detecdiv_hub_get_pipeline_run  Fetch one hub pipeline_run job.

    if nargin < 1 || strlength(string(jobId)) == 0
        error('detecdiv_hub_get_pipeline_run:MissingJobId', ...
            'A job id is required.');
    end
    if nargin < 2 || isempty(hubSettings)
        hubSettings = detecdiv_hub_settings_get();
    end

    endpoint = sprintf('/pipeline-runs/%s', char(string(jobId)));
    job = detecdiv_hub_request_json(endpoint, hubSettings);
end
