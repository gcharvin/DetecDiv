function targets = detecdiv_hub_list_execution_targets(hubSettings, varargin)
% detecdiv_hub_list_execution_targets  Fetch execution target summaries from detecdiv-hub.

    if nargin < 1 || isempty(hubSettings)
        hubSettings = detecdiv_hub_settings_get();
    end

    ip = inputParser;
    ip.addParameter('Status', '', @(x)ischar(x) || isstring(x));
    ip.parse(varargin{:});
    opts = ip.Results;

    endpoint = '/execution-targets';
    statusFilter = strtrim(char(string(opts.Status)));
    if ~isempty(statusFilter)
        endpoint = [endpoint '?status_filter=' urlencode(statusFilter)];
    end
    targets = detecdiv_hub_request_json(endpoint, hubSettings);
end
