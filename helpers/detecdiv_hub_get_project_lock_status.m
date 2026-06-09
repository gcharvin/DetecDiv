function status = detecdiv_hub_get_project_lock_status(projectId, hubSettings)
% detecdiv_hub_get_project_lock_status  Fetch hub write-lock status for a project.

    if nargin < 1 || strlength(string(projectId)) == 0
        error('detecdiv_hub_get_project_lock_status:MissingProjectId', ...
            'A project id is required.');
    end
    if nargin < 2 || isempty(hubSettings)
        hubSettings = detecdiv_hub_settings_get();
    end

    endpoint = sprintf('/projects/%s/locks', char(string(projectId)));
    status = detecdiv_hub_request_json(endpoint, hubSettings);
end
