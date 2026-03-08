function projects = detecdiv_hub_list_projects(hubSettings, varargin)
% detecdiv_hub_list_projects  Fetch project summaries from detecdiv-hub.

    if nargin < 1 || isempty(hubSettings)
        hubSettings = detecdiv_hub_settings_get();
    end

    ip = inputParser;
    ip.addParameter('GroupId', '', @(x)ischar(x) || isstring(x));
    ip.addParameter('OwnedOnly', false, @(x)islogical(x) || isnumeric(x));
    ip.parse(varargin{:});
    opts = ip.Results;

    endpoint = '/projects';
    params = strings(0, 1);

    groupId = strtrim(char(string(opts.GroupId)));
    if ~isempty(groupId)
        params(end + 1, 1) = "group_id=" + string(urlencode(groupId)); %#ok<AGROW>
    end
    if logical(opts.OwnedOnly)
        params(end + 1, 1) = "owned_only=true"; %#ok<AGROW>
    end
    if ~isempty(params)
        endpoint = [endpoint '?' strjoin(cellstr(params), '&')];
    end

    projects = detecdiv_hub_request_json(endpoint, hubSettings);
end
