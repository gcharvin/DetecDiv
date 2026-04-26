function lease = detecdiv_hub_acquire_project_lease(project, varargin)
% detecdiv_hub_acquire_project_lease  Acquire a client_edit_lease for a project.

    [hub, ttlSeconds, reason, writeScope] = localParse(varargin{:});
    ref = localProjectRef(project, hub);
    if isempty(ref.project_id)
        error('detecdiv_hub_acquire_project_lease:MissingProjectId', ...
            'Hub project id is required before acquiring a lease.');
    end

    payload = struct();
    payload.holder_key = localHolderKey(hub);
    payload.holder_host = char(string(java.net.InetAddress.getLocalHost.getHostName));
    payload.ttl_seconds = ttlSeconds;
    payload.write_scope = writeScope;
    payload.reason = reason;
    payload.metadata_json = struct('client', 'DetecDiv MATLAB', 'project_mat_path', ref.project_mat_path);

    lease = detecdiv_hub_request('POST', ['/projects/' ref.project_id '/leases'], payload, hub);
end

function [hub, ttlSeconds, reason, writeScope] = localParse(varargin)
    hub = detecdiv_hub_settings_get();
    ttlSeconds = 300;
    reason = 'DetecDiv local edit';
    writeScope = 'project_update';
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
            case 'reason'
                reason = char(string(value));
            case 'writescope'
                writeScope = char(string(value));
        end
        i = i + 2;
    end
end

function key = localHolderKey(hub)
    key = '';
    try
        if isfield(hub, 'userKey') && ~isempty(hub.userKey)
            key = char(string(hub.userKey));
        end
    catch
    end
    if isempty(key)
        key = getenv('USERNAME');
    end
    if isempty(key)
        key = 'matlab-client';
    end
end
