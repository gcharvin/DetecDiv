function [sessionInfo, hub] = detecdiv_hub_login(userKey, password, hub)
% detecdiv_hub_login  Open a password-backed hub session and persist token.

    if nargin < 3 || isempty(hub)
        hub = detecdiv_hub_settings_get();
    end
    if nargin < 1 || isempty(userKey)
        userKey = hub.userKey;
    end
    if nargin < 2
        password = '';
    end
    if isempty(userKey) || isempty(password)
        error('detecdiv_hub_login:MissingCredentials', 'userKey and password are required.');
    end

    loginHub = hub;
    loginHub.sessionToken = '';
    loginHub.userKey = '';
    payload = struct('user_key', char(string(userKey)), 'password', char(string(password)), 'client_label', 'DetecDiv MATLAB');
    sessionInfo = detecdiv_hub_request('POST', '/auth/login', payload, loginHub);
    hub.userKey = char(string(userKey));
    hub.sessionToken = char(string(sessionInfo.session_token));
    detecdiv_hub_settings_set(hub);
end
