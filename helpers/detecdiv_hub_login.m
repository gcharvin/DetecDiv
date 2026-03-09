function [sessionInfo, hubSettings] = detecdiv_hub_login(userKey, password, hubSettings)
% detecdiv_hub_login  Open a detecdiv-hub session and persist the bearer token.

    if nargin < 3 || isempty(hubSettings)
        hubSettings = detecdiv_hub_settings_get();
    end
    userKey = strtrim(char(string(userKey)));
    password = char(string(password));
    if isempty(userKey) || isempty(password)
        error('detecdiv_hub_login:InvalidCredentials', ...
            'Both user key and password are required.');
    end

    baseUrl = regexprep(char(string(hubSettings.baseUrl)), '[\\/]+$', '');
    options = weboptions( ...
        'Timeout', double(hubSettings.timeoutSeconds), ...
        'MediaType', 'application/json', ...
        'ContentType', 'json');
    sessionInfo = webwrite([baseUrl '/auth/login'], struct( ...
        'user_key', userKey, ...
        'password', password, ...
        'client_label', 'matlab-catalog'), options);

    hubSettings.userKey = userKey;
    hubSettings.sessionToken = char(string(sessionInfo.session_token));
    hubSettings.authMode = 'session';
    detecdiv_hub_settings_set(hubSettings);
end
