function user = detecdiv_hub_get_current_user(hubSettings)
% detecdiv_hub_get_current_user  Fetch the current hub user identity.

    if nargin < 1 || isempty(hubSettings)
        hubSettings = detecdiv_hub_settings_get();
    end

    user = detecdiv_hub_request_json('/users/me', hubSettings);
end
