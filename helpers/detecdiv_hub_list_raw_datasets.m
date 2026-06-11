function datasets = detecdiv_hub_list_raw_datasets(hubSettings, varargin)
% detecdiv_hub_list_raw_datasets  Fetch raw dataset summaries from detecdiv-hub.

    if nargin < 1 || isempty(hubSettings)
        hubSettings = detecdiv_hub_settings_get();
    end

    ip = inputParser;
    ip.addParameter('OwnerKey', '', @(x)ischar(x) || isstring(x));
    ip.addParameter('OwnedOnly', false, @(x)islogical(x) || isnumeric(x));
    ip.addParameter('Search', '', @(x)ischar(x) || isstring(x));
    ip.addParameter('Limit', 1000, @(x)isnumeric(x) && isscalar(x));
    ip.parse(varargin{:});
    opts = ip.Results;

    endpoint = localBuildRawDatasetEndpoint('/raw-datasets', opts);
    try
        datasets = detecdiv_hub_request_json(endpoint, hubSettings);
    catch firstError
        fallbackEndpoint = localBuildRawDatasetEndpoint('/datasets', opts);
        try
            datasets = detecdiv_hub_request_json(fallbackEndpoint, hubSettings);
        catch
            rethrow(firstError);
        end
    end
end

function endpoint = localBuildRawDatasetEndpoint(baseEndpoint, opts)
    endpoint = char(string(baseEndpoint));
    params = strings(0, 1);

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
end
