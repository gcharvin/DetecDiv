function payload = detecdiv_hub_request_json(endpoint, hubSettings)
% detecdiv_hub_request_json  Perform a JSON GET request against detecdiv-hub.

    if nargin < 2 || isempty(hubSettings)
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
        'ContentType', 'json');
    headerFields = localAuthHeaders(hubSettings);
    if ~isempty(headerFields)
        options.HeaderFields = headerFields;
    end

    requestUrl = localAppendIdentity([baseUrl endpoint], hubSettings);
    payload = webread(requestUrl, options);
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
