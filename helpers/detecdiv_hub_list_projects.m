function projects = detecdiv_hub_list_projects(hubSettings, varargin)
% detecdiv_hub_list_projects  Fetch project summaries from detecdiv-hub.

    if nargin < 1 || isempty(hubSettings)
        hubSettings = detecdiv_hub_settings_get();
    end

    ip = inputParser;
    ip.addParameter('GroupId', '', @(x)ischar(x) || isstring(x));
    ip.addParameter('OwnerKey', '', @(x)ischar(x) || isstring(x));
    ip.addParameter('OwnedOnly', false, @(x)islogical(x) || isnumeric(x));
    ip.addParameter('Search', '', @(x)ischar(x) || isstring(x));
    ip.addParameter('Limit', 1000, @(x)isnumeric(x) && isscalar(x));
    ip.parse(varargin{:});
    opts = ip.Results;

    endpoint = '/projects';
    params = strings(0, 1);

    groupId = strtrim(char(string(opts.GroupId)));
    if ~isempty(groupId)
        params(end + 1, 1) = "group_id=" + string(urlencode(groupId));
    end
    ownerKey = strtrim(char(string(opts.OwnerKey)));
    if ~isempty(ownerKey)
        params(end + 1, 1) = "owner_key=" + string(urlencode(ownerKey));
    end
    if logical(opts.OwnedOnly)
        params(end + 1, 1) = "owned_only=true";
    end
    searchText = strtrim(char(string(opts.Search)));
    if ~isempty(searchText)
        params(end + 1, 1) = "search=" + string(urlencode(searchText));
    end
    limitValue = max(1, round(double(opts.Limit)));
    if ~isnan(limitValue) && isfinite(limitValue)
        params(end + 1, 1) = "limit=" + string(limitValue);
    end
    if ~isempty(params)
        endpoint = [endpoint '?' strjoin(cellstr(params), '&')];
    end

    projects = detecdiv_hub_request_json(endpoint, hubSettings);
end
