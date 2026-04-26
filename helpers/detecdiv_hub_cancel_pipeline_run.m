function job = detecdiv_hub_cancel_pipeline_run(jobId, hub)
% detecdiv_hub_cancel_pipeline_run  Request cancellation of a hub pipeline job.

    if nargin < 2 || isempty(hub)
        hub = detecdiv_hub_settings_get();
    end
    if nargin < 1 || isempty(jobId)
        error('detecdiv_hub_cancel_pipeline_run:MissingJobId', 'jobId is required.');
    end
    job = detecdiv_hub_request('POST', ['/pipeline-runs/' char(string(jobId)) '/cancel'], struct(), hub);
end
