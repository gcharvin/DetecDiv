function notes = detecdiv_hub_list_project_notes(projectId, hubSettings)
% detecdiv_hub_list_project_notes  Fetch notes for one hub project.

    if nargin < 1 || strlength(string(projectId)) == 0
        error('detecdiv_hub_list_project_notes:MissingProjectId', ...
            'A project id is required.');
    end
    if nargin < 2 || isempty(hubSettings)
        hubSettings = detecdiv_hub_settings_get();
    end

    endpoint = ['/projects/' char(string(projectId)) '/notes'];
    notes = detecdiv_hub_request_json(endpoint, hubSettings);
end
