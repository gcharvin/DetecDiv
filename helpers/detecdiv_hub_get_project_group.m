function group = detecdiv_hub_get_project_group(groupId, hubSettings)
% detecdiv_hub_get_project_group  Fetch one project group and its projects.

    if nargin < 1 || strlength(string(groupId)) == 0
        error('detecdiv_hub_get_project_group:MissingGroupId', ...
            'A group id is required.');
    end
    if nargin < 2 || isempty(hubSettings)
        hubSettings = detecdiv_hub_settings_get();
    end

    endpoint = ['/project-groups/' char(string(groupId))];
    group = detecdiv_hub_request_json(endpoint, hubSettings);
end
