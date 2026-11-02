function [hubSettings, status] = detecdiv_hub_logout(hubSettings, onLocalLogout)
% detecdiv_hub_logout  Revoke the current detecdiv-hub session and clear local token.

    if nargin < 1 || isempty(hubSettings)
        hubSettings = detecdiv_hub_settings_get();
    end
    if nargin < 2, onLocalLogout = []; end
    remoteSettings = hubSettings;
    status = struct('remoteRevoked', false, 'message', '');

    hubSettings.sessionToken = '';
    if isfield(hubSettings, 'authMode')
        hubSettings.authMode = '';
    end
    detecdiv_hub_settings_set(hubSettings);
    % settings_get gives environment tokens priority over saved preferences.
    setenv('DETECDIV_HUB_SESSION_TOKEN', '');
    if ~isempty(onLocalLogout)
        onLocalLogout(hubSettings);
    end

    % Revoke the original token after the local session and UI are cleared.
    % A slow or unavailable Hub must not retain the local connection.
    if ~isfield(remoteSettings, 'sessionToken') || isempty(remoteSettings.sessionToken)
        return;
    end
    remoteSettings.timeout = 3;
    remoteSettings.timeoutSeconds = 3;
    try
        detecdiv_hub_write_json('/auth/logout', struct(), remoteSettings);
        status.remoteRevoked = true;
    catch ME
        status.message = ME.message;
    end
end
