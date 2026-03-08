function projects = detecdiv_hub_list_projects(hubSettings)
% detecdiv_hub_list_projects  Fetch project summaries from detecdiv-hub.

    if nargin < 1 || isempty(hubSettings)
        hubSettings = detecdiv_hub_settings_get();
    end

    projects = detecdiv_hub_request_json('/projects', hubSettings);
end
