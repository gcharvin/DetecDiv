function aclEntry = detecdiv_hub_create_project_acl(projectId, userKey, accessLevel, hubSettings)
% detecdiv_hub_create_project_acl  Add or update one project ACL entry.

    if nargin < 1 || strlength(string(projectId)) == 0
        error('detecdiv_hub_create_project_acl:MissingProjectId', ...
            'A project id is required.');
    end
    if nargin < 2 || strlength(string(userKey)) == 0
        error('detecdiv_hub_create_project_acl:MissingUserKey', ...
            'A target user key is required.');
    end
    if nargin < 3 || strlength(string(accessLevel)) == 0
        accessLevel = 'viewer';
    end
    if nargin < 4 || isempty(hubSettings)
        hubSettings = detecdiv_hub_settings_get();
    end

    endpoint = ['/projects/' char(string(projectId)) '/acl'];
    payload = struct( ...
        'user_key', char(string(userKey)), ...
        'access_level', char(string(accessLevel)));
    aclEntry = detecdiv_hub_write_json(endpoint, payload, hubSettings);
end
