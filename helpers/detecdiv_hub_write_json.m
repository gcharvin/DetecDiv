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

    payload = webwrite([baseUrl endpoint], body, options);
end

function out = localTrimTrailingSlash(in)
    out = regexprep(in, '[\\/]+$', '');
end
