function users = detecdiv_hub_list_users(hubSettings)
% detecdiv_hub_list_users  Fetch hub users visible to the current session.

    if nargin < 1 || isempty(hubSettings)
        hubSettings = detecdiv_hub_settings_get();
    end

    users = detecdiv_hub_request_json('/users', hubSettings);
end
