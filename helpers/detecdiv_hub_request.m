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
    urls = localBuildUrls(hub, apiPath);
    info = struct('ok', false, 'statusCode', NaN, 'url', urls{1}, 'message', '');

    lastError = [];
    for iUrl = 1:numel(urls)
        url = urls{iUrl};
        info.url = url;
        try
        import matlab.net.*
        import matlab.net.http.*
        import matlab.net.http.field.*

        headers = [HeaderField('Accept', 'application/json')];
        if isfield(hub, 'sessionToken') && ~isempty(hub.sessionToken)
            headers(end+1) = HeaderField('Authorization', ['Bearer ' char(string(hub.sessionToken))]); %#ok<AGROW>
        end
        body = [];
        if ~isempty(payload)
            body = MessageBody(payload);
            headers(end+1) = ContentTypeField('application/json'); %#ok<AGROW>
        end

        req = RequestMessage(localRequestMethod(method), headers, body);
        timeoutSeconds = localTimeout(hub);
        opts = HTTPOptions( ...
            'ConnectTimeout', timeoutSeconds, ...
            'ResponseTimeout', timeoutSeconds, ...
            'DataTimeout', timeoutSeconds, ...
            'ConvertResponse', true);
        resp = req.send(URI(url), opts);
        info.statusCode = double(resp.StatusCode);
        info.ok = info.statusCode >= 200 && info.statusCode < 300;
        data = resp.Body.Data;
        if isempty(data)
            data = struct();
        end
        if ~info.ok
            info.message = localResponseMessage(data, resp.StatusLine.ReasonPhrase);
            error(sprintf('detecdiv_hub_request:HTTP%d', info.statusCode), '%s', info.message);
        end
            return;
        catch ME
            info.message = ME.message;
            data = struct();
            if startsWith(ME.identifier, 'detecdiv_hub_request:HTTP')
                rethrow(ME);
            end
            lastError = ME;
        end
    end

    if isempty(lastError)
        error('detecdiv_hub_request:Unreachable', 'Hub request failed.');
    end
    error('detecdiv_hub_request:Unreachable', 'Hub request failed: %s', lastError.message);
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

function urls = localBuildUrls(hub, apiPath)
    baseUrl = 'http://detecdiv-hub.detecdiv.internal';
    if isfield(hub, 'baseUrl') && ~isempty(hub.baseUrl)
        baseUrl = char(string(hub.baseUrl));
    end

    apiPath = char(string(apiPath));
    if ~startsWith(apiPath, '/')
        apiPath = ['/' apiPath];
    end

    baseUrls = [{baseUrl} localFallbackBaseUrls(hub)];
    baseUrls = unique(cellfun(@localTrimUrl, baseUrls, 'UniformOutput', false), 'stable');
    urls = cell(size(baseUrls));
    for i = 1:numel(baseUrls)
        urls{i} = localBuildUrlForBase(baseUrls{i}, apiPath, hub);
    end
end

function url = localBuildUrlForBase(baseUrl, apiPath, hub)
    url = [baseUrl apiPath];
    if localUseUserKeyQuery(hub)
        sep = '?';
        if contains(url, '?')
            sep = '&';
        end
        url = [url sep 'user_key=' localUrlEncode(hub.userKey)];
    end
end

function values = localFallbackBaseUrls(hub)
    values = {};
    if isfield(hub, 'fallbackBaseUrls') && ~isempty(hub.fallbackBaseUrls)
        if iscell(hub.fallbackBaseUrls)
            values = hub.fallbackBaseUrls;
        elseif isstring(hub.fallbackBaseUrls)
            values = cellstr(hub.fallbackBaseUrls(:)');
        elseif ischar(hub.fallbackBaseUrls)
            values = {hub.fallbackBaseUrls};
        end
    end
end

function out = localTrimUrl(value)
    out = regexprep(char(string(value)), '/+$', '');
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
        elseif ischar(data) || isstring(data)
            msg = localCompactTextMessage(data, fallback);
        end
    catch
    end
end

function msg = localCompactTextMessage(data, fallback)
    msg = char(string(data));
    lowerMsg = lower(msg);
    if contains(lowerMsg, '<html')
        if contains(lowerMsg, '502') || contains(lowerMsg, 'bad gateway')
            msg = 'Hub temporarily unavailable (502 Bad Gateway).';
            return;
        end
        msg = regexprep(msg, '<[^>]*>', ' ');
    end
    msg = regexprep(msg, '\s+', ' ');
    if isempty(strtrim(msg))
        msg = char(string(fallback));
    end
    maxLen = 240;
    if strlength(string(msg)) > maxLen
        msg = char(extractBefore(string(msg), maxLen + 1));
        msg = [msg '...'];
    end
end
