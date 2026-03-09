function payload = detecdiv_hub_write_json(endpoint, body, hubSettings)
% detecdiv_hub_write_json  Perform a JSON POST request against detecdiv-hub.

    if nargin < 3 || isempty(hubSettings)
        hubSettings = detecdiv_hub_settings_get();
    end

    baseUrl = localTrimTrailingSlash(char(string(hubSettings.baseUrl)));
    endpoint = char(string(endpoint));
    if isempty(endpoint)
        endpoint = '/';
    end
    if endpoint(1) ~= '/'
        endpoint = ['/' endpoint];
    end

    options = weboptions( ...
        'Timeout', double(hubSettings.timeoutSeconds), ...
        'MediaType', 'application/json', ...
        'ContentType', 'json');
    headerFields = localAuthHeaders(hubSettings);
    if ~isempty(headerFields)
        options.HeaderFields = headerFields;
    end

    requestUrl = localAppendIdentity([baseUrl endpoint], hubSettings);
    payload = webwrite(requestUrl, body, options);
end

function out = localTrimTrailingSlash(in)
    out = regexprep(in, '[\\/]+$', '');
end

function url = localAppendIdentity(url, hubSettings)
    if isfield(hubSettings, 'sessionToken')
        token = strtrim(char(string(hubSettings.sessionToken)));
        if ~isempty(token)
            return;
        end
    end
    if ~isfield(hubSettings, 'userKey')
        return;
    end
    userKey = strtrim(char(string(hubSettings.userKey)));
    if isempty(userKey)
        return;
    end
    separator = '?';
    if contains(url, '?')
        separator = '&';
    end
    url = [url separator 'user_key=' urlencode(userKey)];
end

function headerFields = localAuthHeaders(hubSettings)
    headerFields = {};
    if ~isfield(hubSettings, 'sessionToken')
        return;
    end
    token = strtrim(char(string(hubSettings.sessionToken)));
    if isempty(token)
        return;
    end
    headerFields = {'Authorization' ['Bearer ' token]};
end
