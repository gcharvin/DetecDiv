function projectDetail = detecdiv_hub_get_project(projectId, hubSettings)
% detecdiv_hub_get_project  Fetch one project detail from detecdiv-hub.

    if nargin < 1 || strlength(string(projectId)) == 0
        error('detecdiv_hub_get_project:MissingProjectId', ...
            'A project id is required.');
    end
    if nargin < 2 || isempty(hubSettings)
        hubSettings = detecdiv_hub_settings_get();
    end

    endpoint = ['/projects/' char(string(projectId))];
    projectDetail = detecdiv_hub_request_json(endpoint, hubSettings);
end
