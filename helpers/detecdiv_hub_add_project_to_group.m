function group = detecdiv_hub_add_project_to_group(groupId, projectId, hubSettings)
% detecdiv_hub_add_project_to_group  Add a project to one hub group.

    if nargin < 1 || strlength(string(groupId)) == 0
        error('detecdiv_hub_add_project_to_group:MissingGroupId', ...
            'A group id is required.');
    end
    if nargin < 2 || strlength(string(projectId)) == 0
        error('detecdiv_hub_add_project_to_group:MissingProjectId', ...
            'A project id is required.');
    end
    if nargin < 3 || isempty(hubSettings)
        hubSettings = detecdiv_hub_settings_get();
    end

    endpoint = sprintf('/project-groups/%s/projects/%s', ...
        char(string(groupId)), char(string(projectId)));
    group = detecdiv_hub_write_json(endpoint, struct(), hubSettings);
end
