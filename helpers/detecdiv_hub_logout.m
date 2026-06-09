function hubSettings = detecdiv_hub_logout(hubSettings)
% detecdiv_hub_logout  Revoke the current detecdiv-hub session and clear local token.

    if nargin < 1 || isempty(hubSettings)
        hubSettings = detecdiv_hub_settings_get();
    end

    try
        detecdiv_hub_write_json('/auth/logout', struct(), hubSettings);
    catch
        % Clear local token even if the remote session has already expired.
    end

    hubSettings.sessionToken = '';
    if isfield(hubSettings, 'authMode')
        hubSettings.authMode = '';
    end
    detecdiv_hub_settings_set(hubSettings);
end
