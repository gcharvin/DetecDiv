function aclEntries = detecdiv_hub_list_project_acl(projectId, hubSettings)
% detecdiv_hub_list_project_acl  Fetch ACL entries for one hub project.

    if nargin < 1 || strlength(string(projectId)) == 0
        error('detecdiv_hub_list_project_acl:MissingProjectId', ...
            'A project id is required.');
    end
    if nargin < 2 || isempty(hubSettings)
        hubSettings = detecdiv_hub_settings_get();
    end

    endpoint = ['/projects/' char(string(projectId)) '/acl'];
    aclEntries = detecdiv_hub_request_json(endpoint, hubSettings);
end
