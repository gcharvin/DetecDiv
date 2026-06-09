function groups = detecdiv_hub_list_project_groups(hubSettings)
% detecdiv_hub_list_project_groups  Fetch the current user's project groups.

    if nargin < 1 || isempty(hubSettings)
        hubSettings = detecdiv_hub_settings_get();
    end

    groups = detecdiv_hub_request_json('/project-groups', hubSettings);
end
