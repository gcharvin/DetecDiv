function [data, info] = detecdiv_hub_request(method, apiPath, payload, hub)
% detecdiv_hub_request  Minimal JSON HTTP client for detecdiv-hub.

    if nargin < 1 || isempty(method)
        method = 'GET';
    end
    if nargin < 2 || isempty(apiPath)
        error('detecdiv_hub_request:MissingPath', 'apiPath is required.');
    end
    if nargin < 3
        payload = [];
    end
    if nargin < 4 || isempty(hub)
        hub = detecdiv_hub_settings_get();
    end

    method = upper(char(string(method)));
    url = localBuildUrl(hub, apiPath);
    info = struct('ok', false, 'statusCode', NaN, 'url', url, 'message', '');

    try
        import matlab.net.*
        import matlab.net.http.*
        import matlab.net.http.field.*

        headers = [HeaderField('Accept', 'application/json')];
        if isfield(hub, 'sessionToken') && ~isempty(hub.sessionToken)
            headers(end+1) = AuthorizationField('Bearer', char(string(hub.sessionToken))); %#ok<AGROW>
        end
        body = [];
        if ~isempty(payload)
            body = MessageBody(payload);
            headers(end+1) = ContentTypeField('application/json'); %#ok<AGROW>
        end

        req = RequestMessage(localRequestMethod(method), headers, body);
        opts = HTTPOptions('ConnectTimeout', localTimeout(hub), 'ConvertResponse', true);
        resp = req.send(URI(url), opts);
        info.statusCode = double(resp.StatusCode);
        info.ok = info.statusCode >= 200 && info.statusCode < 300;
        data = resp.Body.Data;
        if isempty(data)
            data = struct();
        end
        if ~info.ok
            info.message = localResponseMessage(data, resp.StatusLine.ReasonPhrase);
            error('detecdiv_hub_request:HTTP%d', info.statusCode, '%s', info.message);
        end
    catch ME
        info.message = ME.message;
        data = struct();
        if startsWith(ME.identifier, 'detecdiv_hub_request:HTTP')
            rethrow(ME);
        end
        error('detecdiv_hub_request:Unreachable', 'Hub request failed: %s', ME.message);
    end
end

function rm = localRequestMethod(method)
    import matlab.net.http.RequestMethod
    switch upper(char(string(method)))
        case 'GET'
            rm = RequestMethod.GET;
        case 'POST'
            rm = RequestMethod.POST;
        case 'PATCH'
            rm = RequestMethod.PATCH;
        case 'DELETE'
            rm = RequestMethod.DELETE;
        otherwise
            error('detecdiv_hub_request:BadMethod', 'Unsupported HTTP method: %s', method);
    end
end

function url = localBuildUrl(hub, apiPath)
    baseUrl = 'http://127.0.0.1:8000';
    if isfield(hub, 'baseUrl') && ~isempty(hub.baseUrl)
        baseUrl = char(string(hub.baseUrl));
    end
    baseUrl = regexprep(baseUrl, '/+$', '');

    apiPath = char(string(apiPath));
    if ~startsWith(apiPath, '/')
        apiPath = ['/' apiPath];
    end

    url = [baseUrl apiPath];
    if localUseUserKeyQuery(hub)
        sep = '?';
        if contains(url, '?')
            sep = '&';
        end
        url = [url sep 'user_key=' localUrlEncode(hub.userKey)];
    end
end

function out = localUrlEncode(value)
    try
        out = char(java.net.URLEncoder.encode(char(string(value)), 'UTF-8'));
        out = strrep(out, '+', '%20');
    catch
        out = char(string(value));
    end
end

function tf = localUseUserKeyQuery(hub)
    tf = isfield(hub, 'userKey') && ~isempty(hub.userKey) && ...
        (~isfield(hub, 'sessionToken') || isempty(hub.sessionToken));
end

function t = localTimeout(hub)
    t = 20;
    if isfield(hub, 'timeout') && ~isempty(hub.timeout)
        t = double(hub.timeout);
    end
end

function msg = localResponseMessage(data, fallback)
    msg = char(string(fallback));
    try
        if isstruct(data) && isfield(data, 'detail')
            detail = data.detail;
            if ischar(detail) || isstring(detail)
                msg = char(string(detail));
            else
                msg = jsonencode(detail);
            end
        end
    catch
    end
end
