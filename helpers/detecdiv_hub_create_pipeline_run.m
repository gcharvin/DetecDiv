function job = detecdiv_hub_create_pipeline_run(payload, hubSettings)
% detecdiv_hub_create_pipeline_run  Submit a pipeline_run job to detecdiv-hub.

    if nargin < 2 || isempty(hubSettings)
        hubSettings = detecdiv_hub_settings_get();
    end

    if nargin < 1 || ~isstruct(payload)
        error('detecdiv_hub_create_pipeline_run:InvalidPayload', 'A payload struct is required.');
    end

    job = detecdiv_hub_write_json('/pipeline-runs', payload, hubSettings);
end
