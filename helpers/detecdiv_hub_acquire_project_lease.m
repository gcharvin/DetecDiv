function lease = detecdiv_hub_acquire_project_lease(projectId, hubSettings, varargin)
% detecdiv_hub_acquire_project_lease  Acquire a client edit lease for a hub project.

    if nargin < 1 || strlength(string(projectId)) == 0
        error('detecdiv_hub_acquire_project_lease:MissingProjectId', ...
            'A project id is required.');
    end
    if nargin < 2 || isempty(hubSettings)
        hubSettings = detecdiv_hub_settings_get();
    end

    ip = inputParser;
    ip.addParameter('HolderKey', '', @(x)ischar(x) || isstring(x));
    ip.addParameter('HolderHost', localHostName(), @(x)ischar(x) || isstring(x));
    ip.addParameter('TtlSeconds', 300, @(x)isnumeric(x) && isscalar(x));
    ip.addParameter('WriteScope', 'project_update', @(x)ischar(x) || isstring(x));
    ip.addParameter('Reason', 'client_edit', @(x)ischar(x) || isstring(x));
    ip.addParameter('Metadata', struct(), @(x)isstruct(x));
    ip.parse(varargin{:});
    opts = ip.Results;

    holderKey = strtrim(char(string(opts.HolderKey)));
    if isempty(holderKey) && isfield(hubSettings, 'userKey')
        holderKey = char(string(hubSettings.userKey));
    end

    body = struct();
    body.holder_key = holderKey;
    body.holder_host = char(string(opts.HolderHost));
    body.ttl_seconds = max(30, min(86400, round(double(opts.TtlSeconds))));
    body.write_scope = char(string(opts.WriteScope));
    body.reason = char(string(opts.Reason));
    body.metadata_json = opts.Metadata;

    endpoint = sprintf('/projects/%s/leases', char(string(projectId)));
    lease = detecdiv_hub_write_json(endpoint, body, hubSettings);
end

function hostName = localHostName()
    hostName = '';
    try
        hostName = char(java.net.InetAddress.getLocalHost.getHostName);
    catch
    end
    if isempty(hostName)
        hostName = char(string(getenv('COMPUTERNAME')));
    end
    if isempty(hostName)
        hostName = char(string(getenv('HOSTNAME')));
    end
end
