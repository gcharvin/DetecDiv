function group = detecdiv_hub_create_project_group(groupKey, displayName, description, hubSettings)
% detecdiv_hub_create_project_group  Create one project group on the hub.

    if nargin < 1 || strlength(string(groupKey)) == 0
        error('detecdiv_hub_create_project_group:MissingGroupKey', ...
            'A group key is required.');
    end
    if nargin < 2 || strlength(string(displayName)) == 0
        error('detecdiv_hub_create_project_group:MissingDisplayName', ...
            'A display name is required.');
    end
    if nargin < 3 || isempty(description)
        description = '';
    end
    if nargin < 4 || isempty(hubSettings)
        hubSettings = detecdiv_hub_settings_get();
    end

    payload = struct( ...
        'group_key', char(string(groupKey)), ...
        'display_name', char(string(displayName)), ...
        'description', char(string(description)), ...
        'metadata_json', struct());
    group = detecdiv_hub_write_json('/project-groups', payload, hubSettings);
end
