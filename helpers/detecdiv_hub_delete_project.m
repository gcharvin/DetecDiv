function result = detecdiv_hub_delete_project(projectId, hubSettings, varargin)
% detecdiv_hub_delete_project  Delete one hub project after preview/confirmation.

    if nargin < 1 || strlength(string(projectId)) == 0
        error('detecdiv_hub_delete_project:MissingProjectId', ...
            'A project id is required.');
    end
    if nargin < 2 || isempty(hubSettings)
        hubSettings = detecdiv_hub_settings_get();
    end

    ip = inputParser;
    ip.addParameter('DeleteProjectFiles', false, @(x)islogical(x) || isnumeric(x));
    ip.addParameter('DeleteLinkedRawData', false, @(x)islogical(x) || isnumeric(x));
    ip.addParameter('Confirm', true, @(x)islogical(x) || isnumeric(x));
    ip.parse(varargin{:});
    opts = ip.Results;

    baseUrl = regexprep(char(string(hubSettings.baseUrl)), '[\\/]+$', '');
    endpoint = sprintf('/projects/%s?delete_project_files=%s&delete_linked_raw_data=%s&confirm=%s', ...
        char(string(projectId)), ...
        localLogicalString(opts.DeleteProjectFiles), ...
        localLogicalString(opts.DeleteLinkedRawData), ...
        localLogicalString(opts.Confirm));
    requestUrl = localAppendUserKey([baseUrl endpoint], hubSettings);

    import matlab.net.URI
    import matlab.net.http.RequestMessage
    import matlab.net.http.MessageBody
    import matlab.net.http.field.ContentTypeField

    request = RequestMessage( ...
        'delete', ...
        ContentTypeField('application/json'), ...
        MessageBody(''));
    response = send(request, URI(requestUrl));
    if response.StatusCode ~= matlab.net.http.StatusCode.OK
        bodyText = localResponseText(response);
        error('detecdiv_hub_delete_project:DeleteFailed', ...
            'Hub delete failed (%s): %s', char(response.StatusCode), bodyText);
    end

    bodyText = localResponseText(response);
    if isempty(bodyText)
        result = struct();
    else
        result = jsondecode(bodyText);
    end
end

function out = localLogicalString(value)
    if logical(value)
        out = 'true';
    else
        out = 'false';
    end
end

function url = localAppendUserKey(url, hubSettings)
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

function txt = localResponseText(response)
    txt = '';
    try
        if ischar(response.Body.Data) || isStringScalar(response.Body.Data)
            txt = char(string(response.Body.Data));
        else
            txt = char(string(response.Body.Data));
        end
    catch
        txt = '';
    end
end
