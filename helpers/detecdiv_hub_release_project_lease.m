function lease = detecdiv_hub_release_project_lease(projectId, lockId, hubSettings)
% detecdiv_hub_release_project_lease  Release a client edit lease.

    if nargin < 1 || strlength(string(projectId)) == 0
        error('detecdiv_hub_release_project_lease:MissingProjectId', ...
            'A project id is required.');
    end
    if nargin < 2 || strlength(string(lockId)) == 0
        error('detecdiv_hub_release_project_lease:MissingLockId', ...
            'A lock id is required.');
    end
    if nargin < 3 || isempty(hubSettings)
        hubSettings = detecdiv_hub_settings_get();
    end

    endpoint = sprintf('/projects/%s/leases/%s', ...
        char(string(projectId)), char(string(lockId)));
    lease = localDeleteJson(endpoint, hubSettings);
end

function payload = localDeleteJson(endpoint, hubSettings)
    baseUrl = regexprep(char(string(hubSettings.baseUrl)), '[\\/]+$', '');
    endpoint = char(string(endpoint));
    if isempty(endpoint)
        endpoint = '/';
    end
    if endpoint(1) ~= '/'
        endpoint = ['/' endpoint];
    end
    requestUrl = localAppendIdentity([baseUrl endpoint], hubSettings);

    import matlab.net.URI
    import matlab.net.http.RequestMessage
    import matlab.net.http.MessageBody
    import matlab.net.http.HeaderField
    import matlab.net.http.field.ContentTypeField

    request = RequestMessage( ...
        'delete', ...
        localRequestFields(hubSettings, ContentTypeField('application/json')), ...
        MessageBody(''));
    response = send(request, URI(requestUrl));
    if response.StatusCode ~= matlab.net.http.StatusCode.OK
        bodyText = localResponseText(response);
        error('detecdiv_hub_release_project_lease:ReleaseFailed', ...
            'Hub release failed (%s): %s', char(response.StatusCode), bodyText);
    end

    bodyText = localResponseText(response);
    if isempty(bodyText)
        payload = struct();
    else
        payload = jsondecode(bodyText);
    end
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

function fields = localRequestFields(hubSettings, varargin)
    import matlab.net.http.HeaderField
    fields = HeaderField.empty;
    for i = 1:numel(varargin)
        fields(end + 1) = varargin{i}; %#ok<AGROW>
    end
    if ~isfield(hubSettings, 'sessionToken')
        return;
    end
    token = strtrim(char(string(hubSettings.sessionToken)));
    if isempty(token)
        return;
    end
    import matlab.net.http.field.GenericField
    fields(end + 1) = GenericField('Authorization', ['Bearer ' token]);
end

function txt = localResponseText(response)
    txt = '';
    try
        txt = char(string(response.Body.Data));
    catch
    end
end
