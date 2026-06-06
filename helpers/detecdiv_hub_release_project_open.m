function released = detecdiv_hub_release_project_open(shallowObj, hub)
% detecdiv_hub_release_project_open  Stop heartbeat and release any open edit lease.

    if nargin < 2 || isempty(hub)
        hub = detecdiv_hub_settings_get();
    end
    released = false;
    ref = detecdiv_hub_project_ref(shallowObj, hub);
    if isempty(ref.project_id)
        return;
    end

    state = localHubState(shallowObj);
    storedLockId = '';
    if isfield(state, 'lease') && isstruct(state.lease) && isfield(state.lease, 'id') && ~isempty(state.lease.id)
        storedLockId = char(string(state.lease.id));
        localStopHeartbeat(ref, storedLockId);
        released = localReleaseLease(ref, storedLockId, hub) || released;
    end

    try
        status = detecdiv_hub_project_locks(ref, hub);
        locks = localLocks(status);
        for i = 1:numel(locks)
            lockId = localFieldText(locks(i), 'id', '');
            if isempty(lockId) || strcmp(lockId, storedLockId)
                continue;
            end
            if localIsOwnClientEditLease(locks(i), hub)
                localStopHeartbeat(ref, lockId);
                released = localReleaseLease(ref, lockId, hub) || released;
            end
        end
    catch
    end

    if released
        localClearLeaseState(shallowObj);
    end
end

function state = localHubState(shallowObj)
    state = struct();
    try
        if isprop(shallowObj, 'runProfiles') && isstruct(shallowObj.runProfiles) && ...
                isfield(shallowObj.runProfiles, 'hub') && isstruct(shallowObj.runProfiles.hub)
            state = shallowObj.runProfiles.hub;
        end
    catch
    end
end

function ok = localReleaseLease(ref, lockId, hub)
    ok = false;
    try
        detecdiv_hub_release_project_lease(ref, lockId, hub);
        ok = true;
    catch
    end
end

function locks = localLocks(status)
    locks = struct([]);
    if ~isstruct(status)
        return;
    end
    value = [];
    try
        if isfield(status, 'locks')
            value = status.locks;
        end
    catch
    end
    locks = localAsStructArray(value);
end

function locks = localAsStructArray(value)
    if isempty(value)
        locks = struct([]);
    elseif isstruct(value)
        locks = value(:)';
    elseif iscell(value)
        locks = struct([]);
        for i = 1:numel(value)
            item = localAsStructArray(value{i});
            if ~isempty(item)
                locks = [locks item]; %#ok<AGROW>
            end
        end
    else
        locks = struct([]);
    end
end

function tf = localIsOwnClientEditLease(lock, hub)
    tf = false;
    if ~strcmp(localFieldText(lock, 'lock_kind', ''), 'client_edit_lease')
        return;
    end
    if ~localIsEmptyField(lock, 'job_id')
        return;
    end
    holderKey = localFieldText(lock, 'holder_key', '');
    if isempty(holderKey) || ~strcmp(holderKey, localHolderKey(hub))
        return;
    end
    holderHost = localFieldText(lock, 'holder_host', '');
    localHost = localHostName();
    if ~isempty(holderHost) && ~isempty(localHost) && ~strcmpi(holderHost, localHost)
        return;
    end
    tf = true;
end

function tf = localIsEmptyField(S, name)
    tf = true;
    try
        if isstruct(S) && isfield(S, name)
            tf = isempty(S.(name));
        end
    catch
        tf = true;
    end
end

function value = localFieldText(S, name, defaultValue)
    value = defaultValue;
    try
        if isstruct(S) && isfield(S, name) && ~isempty(S.(name))
            value = char(string(S.(name)));
        end
    catch
        value = defaultValue;
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

function host = localHostName()
    host = '';
    try
        host = char(string(java.net.InetAddress.getLocalHost.getHostName));
    catch
    end
end

function localClearLeaseState(shallowObj)
    try
        if isprop(shallowObj, 'runProfiles') && isstruct(shallowObj.runProfiles) && ...
                isfield(shallowObj.runProfiles, 'hub') && isstruct(shallowObj.runProfiles.hub) && ...
                isfield(shallowObj.runProfiles.hub, 'lease')
            shallowObj.runProfiles.hub = rmfield(shallowObj.runProfiles.hub, 'lease');
        end
    catch
    end
end

function localStopHeartbeat(ref, lockId)
    key = matlab.lang.makeValidName(['k_' regexprep([char(string(ref.project_id)) '_' char(string(lockId))], '[^a-zA-Z0-9_]', '_')]);
    timers = struct();
    try
        existing = getappdata(0, 'DetecDivHubLeaseTimers');
        if isstruct(existing)
            timers = existing;
        end
    catch
    end
    if isfield(timers, key)
        t = timers.(key);
        try
            stop(t);
            delete(t);
        catch
        end
        timers = rmfield(timers, key);
        setappdata(0, 'DetecDivHubLeaseTimers', timers);
    end
end
