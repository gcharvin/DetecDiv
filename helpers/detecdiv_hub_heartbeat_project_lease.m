function lease = detecdiv_hub_heartbeat_project_lease(projectId, lockId, hubSettings, varargin)
% detecdiv_hub_heartbeat_project_lease  Refresh a client edit lease TTL.

    if nargin < 1 || strlength(string(projectId)) == 0
        error('detecdiv_hub_heartbeat_project_lease:MissingProjectId', ...
            'A project id is required.');
    end
    if nargin < 2 || strlength(string(lockId)) == 0
        error('detecdiv_hub_heartbeat_project_lease:MissingLockId', ...
            'A lock id is required.');
    end
    if nargin < 3 || isempty(hubSettings)
        hubSettings = detecdiv_hub_settings_get();
    end

    ip = inputParser;
    ip.addParameter('TtlSeconds', 300, @(x)isnumeric(x) && isscalar(x));
    ip.addParameter('HolderKey', '', @(x)ischar(x) || isstring(x));
    ip.addParameter('HolderHost', '', @(x)ischar(x) || isstring(x));
    ip.addParameter('WriteScope', 'project_update', @(x)ischar(x) || isstring(x));
    ip.addParameter('Reason', '', @(x)ischar(x) || isstring(x));
    ip.addParameter('Metadata', struct(), @(x)isstruct(x));
    ip.parse(varargin{:});
    opts = ip.Results;

    body = struct();
    body.ttl_seconds = max(30, min(86400, round(double(opts.TtlSeconds))));
    body.holder_key = char(string(opts.HolderKey));
    body.holder_host = char(string(opts.HolderHost));
    body.write_scope = char(string(opts.WriteScope));
    body.reason = char(string(opts.Reason));
    body.metadata_json = opts.Metadata;

    endpoint = sprintf('/projects/%s/leases/%s/heartbeat', ...
        char(string(projectId)), char(string(lockId)));
    lease = detecdiv_hub_write_json(endpoint, body, hubSettings);
end
