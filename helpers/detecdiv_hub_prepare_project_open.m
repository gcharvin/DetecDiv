function [shallowObj, access] = detecdiv_hub_prepare_project_open(shallowObj, varargin)
% detecdiv_hub_prepare_project_open  Apply hub write-coordination policy on open.

    opts = localParse(varargin{:});
    ref = detecdiv_hub_project_ref(shallowObj, opts.hub);
    access = struct('hubManaged', ref.hubManaged, 'editable', true, 'readOnly', false, ...
        'mode', 'local', 'reason', '', 'project_id', ref.project_id, 'lease', struct(), 'status', struct());

    if ~ref.hubManaged
        shallowObj = localSetHubState(shallowObj, access);
        return;
    end
    if isempty(ref.project_id)
        access.editable = false;
        access.readOnly = true;
        access.mode = 'read_only';
        access.reason = 'Hub-managed project has no resolved hub project id.';
        shallowObj = localSetHubState(shallowObj, access);
        return;
    end

    try
        status = detecdiv_hub_project_locks(ref, opts.hub);
        access.status = status;
        if isfield(status, 'editable') && logical(status.editable)
            access.editable = true;
            access.readOnly = false;
            access.mode = 'write_granted';
            access.reason = localFieldText(status, 'reason', 'No active project lock.');
            if opts.acquireLease
                lease = detecdiv_hub_acquire_project_lease(ref, 'Hub', opts.hub, ...
                    'TtlSeconds', opts.ttlSeconds, 'Reason', 'DetecDiv project open');
                access.lease = lease;
                access.mode = 'lease_active';
                access.reason = 'Hub edit lease acquired.';
                detecdiv_hub_start_lease_heartbeat(ref, lease.id, 'Hub', opts.hub, 'TtlSeconds', opts.ttlSeconds);
            end
        else
            access.editable = false;
            access.readOnly = true;
            access.mode = 'read_only';
            access.reason = localFieldText(status, 'reason', 'Project has an active hub lock.');
        end
    catch ME
        access.editable = false;
        access.readOnly = true;
        access.mode = 'read_only';
        access.reason = ['Hub unreachable or refused status request: ' ME.message];
    end

    shallowObj = localSetHubState(shallowObj, access);
end

function token = detecdiv_hub_start_lease_heartbeat(project, lockId, varargin)
% detecdiv_hub_start_lease_heartbeat  Start a background lease heartbeat.

    [hub, ttlSeconds] = localTimerParse(varargin{:});
    ref = localProjectRef(project, hub);
    key = localWorkerKey(ref, lockId);
    localStopProjectHeartbeats(ref);

    hub.timeout = min(5, double(hub.timeout));
    config = struct('hub', hub, 'projectRef', ref, ...
        'lockId', char(string(lockId)), 'ttlSeconds', ttlSeconds, ...
        'periodSeconds', max(15, floor(double(ttlSeconds) / 3)), ...
        'maxIterations', Inf);
    token = detecdiv_hub_broker('register', 'lease_heartbeat', config, ...
        @(payload)localHandleHeartbeatPayload(payload, ref, lockId));

    workers = localGetWorkers();
    workers.(key) = struct('token', token, ...
        'project_id', char(string(ref.project_id)), ...
        'lock_id', char(string(lockId)));
    setappdata(0, 'DetecDivHubLeaseWorkers', workers);
end

function detecdiv_hub_stop_lease_heartbeat(project, lockId)
% detecdiv_hub_stop_lease_heartbeat  Stop and remove a heartbeat worker.

    ref = localProjectRef(project, detecdiv_hub_settings_get());
    key = localWorkerKey(ref, lockId);
    workers = localGetWorkers();
    if isfield(workers, key)
        localCancelWorkerRecord(workers.(key));
        workers = rmfield(workers, key);
        setappdata(0, 'DetecDivHubLeaseWorkers', workers);
    end
    localStopLegacyProjectTimers(ref, lockId);
end

function localStopProjectHeartbeats(ref)
    workers = localGetWorkers();
    names = fieldnames(workers);
    prefix = matlab.lang.makeValidName(['k_' regexprep([char(string(ref.project_id)) '_'], '[^a-zA-Z0-9_]', '_')]);
    changed = false;
    for i = 1:numel(names)
        name = names{i};
        if ~startsWith(name, prefix)
            continue;
        end
        localCancelWorkerRecord(workers.(name));
        workers = rmfield(workers, name);
        changed = true;
    end
    if changed
        setappdata(0, 'DetecDivHubLeaseWorkers', workers);
    end
    localStopLegacyProjectTimers(ref, '');
end

function opts = localParse(varargin)
    opts = struct('hub', detecdiv_hub_settings_get(), 'acquireLease', true, 'ttlSeconds', 300);
    i = 1;
    while i <= numel(varargin)
        key = lower(char(string(varargin{i})));
        if i == numel(varargin), break; end
        value = varargin{i+1};
        switch key
            case 'hub'
                opts.hub = value;
            case 'acquirelease'
                opts.acquireLease = logical(value);
            case 'ttlseconds'
                opts.ttlSeconds = double(value);
        end
        i = i + 2;
    end
end

function [hub, ttlSeconds] = localTimerParse(varargin)
    opts = localParse(varargin{:});
    hub = opts.hub;
    ttlSeconds = opts.ttlSeconds;
end

function shallowObj = localSetHubState(shallowObj, access)
    if ~isprop(shallowObj, 'runProfiles') || ~isstruct(shallowObj.runProfiles)
        shallowObj.runProfiles = struct();
    end
    if ~isfield(shallowObj.runProfiles, 'hub') || ~isstruct(shallowObj.runProfiles.hub)
        shallowObj.runProfiles.hub = struct();
    end
    shallowObj.runProfiles.hub.hub_project_id = access.project_id;
    shallowObj.runProfiles.hub.read_only = access.readOnly;
    shallowObj.runProfiles.hub.mode = access.mode;
    shallowObj.runProfiles.hub.reason = access.reason;
    shallowObj.runProfiles.hub.checked_at = char(datetime('now'));
    if isfield(access, 'lease') && isstruct(access.lease) && isfield(access.lease, 'id')
        shallowObj.runProfiles.hub.active_locks = access.lease;
    elseif isfield(access, 'status') && isstruct(access.status)
        if isfield(access.status, 'active_locks')
            shallowObj.runProfiles.hub.active_locks = access.status.active_locks;
        elseif isfield(access.status, 'locks')
            shallowObj.runProfiles.hub.active_locks = access.status.locks;
        else
            shallowObj.runProfiles.hub.active_locks = struct([]);
        end
    end
    if isfield(access, 'lease') && isstruct(access.lease) && isfield(access.lease, 'id')
        shallowObj.runProfiles.hub.lease = access.lease;
    end
end

function txt = localFieldText(S, name, defaultValue)
    txt = defaultValue;
    try
        if isstruct(S) && isfield(S, name) && ~isempty(S.(name))
            txt = char(string(S.(name)));
        end
    catch
    end
end

function localHandleHeartbeatPayload(payload, ref, lockId)
    if ~isstruct(payload) || ~isfield(payload, 'ok') || logical(payload.ok)
        return;
    end
    warning('detecdiv_hub:heartbeat', 'Hub lease heartbeat failed: %s', ...
        char(string(payload.errorMessage)));
    if isfield(payload, 'stop') && logical(payload.stop)
        detecdiv_hub_stop_lease_heartbeat(ref, lockId);
    end
end

function localCancelWorkerRecord(worker)
    try
        if isfield(worker, 'token') && ~isempty(worker.token)
            detecdiv_hub_broker('unregister', worker.token);
        end
    catch
    end
end

function localStopLegacyProjectTimers(ref, lockId)
    timers = struct();
    try
        existing = getappdata(0, 'DetecDivHubLeaseTimers');
        if isstruct(existing)
            timers = existing;
        end
    catch
    end
    names = fieldnames(timers);
    prefix = matlab.lang.makeValidName(['k_' regexprep([char(string(ref.project_id)) '_'], '[^a-zA-Z0-9_]', '_')]);
    exactKey = '';
    if ~isempty(lockId)
        exactKey = localWorkerKey(ref, lockId);
    end
    changed = false;
    for i = 1:numel(names)
        name = names{i};
        if (~isempty(exactKey) && ~strcmp(name, exactKey)) || ...
                (isempty(exactKey) && ~startsWith(name, prefix))
            continue;
        end
        try
            stop(timers.(name));
            delete(timers.(name));
        catch
        end
        timers = rmfield(timers, name);
        changed = true;
    end
    if changed
        setappdata(0, 'DetecDivHubLeaseTimers', timers);
    end
end

function workers = localGetWorkers()
    workers = struct();
    try
        existing = getappdata(0, 'DetecDivHubLeaseWorkers');
        if isstruct(existing)
            workers = existing;
        end
    catch
    end
end

function key = localWorkerKey(ref, lockId)
    raw = [char(string(ref.project_id)) '_' char(string(lockId))];
    key = matlab.lang.makeValidName(['k_' regexprep(raw, '[^a-zA-Z0-9_]', '_')]);
end
