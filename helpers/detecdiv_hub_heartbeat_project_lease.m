function lease = detecdiv_hub_heartbeat_project_lease(project, lockId, varargin)
% detecdiv_hub_heartbeat_project_lease  Refresh a client edit lease TTL.

    [hub, ttlSeconds] = localParse(varargin{:});
    ref = localProjectRef(project, hub);
    if isempty(ref.project_id) || isempty(lockId)
        error('detecdiv_hub_heartbeat_project_lease:MissingInput', 'project id and lockId are required.');
    end
    payload = struct('ttl_seconds', ttlSeconds);
    lease = detecdiv_hub_request('POST', ['/projects/' ref.project_id '/leases/' char(string(lockId)) '/heartbeat'], payload, hub);
end

function [hub, ttlSeconds] = localParse(varargin)
    hub = detecdiv_hub_settings_get();
    ttlSeconds = 300;
    i = 1;
    while i <= numel(varargin)
        key = lower(char(string(varargin{i})));
        if i == numel(varargin)
            break;
        end
        value = varargin{i+1};
        switch key
            case 'hub'
                hub = value;
            case 'ttlseconds'
                ttlSeconds = double(value);
        end
        i = i + 2;
    end
end
