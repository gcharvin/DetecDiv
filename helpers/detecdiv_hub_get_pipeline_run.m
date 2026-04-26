function job = detecdiv_hub_get_pipeline_run(jobId, hub)
% detecdiv_hub_get_pipeline_run  Fetch hub status for a pipeline-run job.

    if nargin < 2 || isempty(hub)
        hub = detecdiv_hub_settings_get();
    end
    if nargin < 1 || isempty(jobId)
        error('detecdiv_hub_get_pipeline_run:MissingJobId', 'jobId is required.');
    end
    job = detecdiv_hub_request('GET', ['/pipeline-runs/' char(string(jobId))], [], hub);
end
