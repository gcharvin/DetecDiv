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
    localStopProjectHeartbeats(ref);

    state = localHubState(shallowObj);
    if isfield(state, 'lease') && isstruct(state.lease) && isfield(state.lease, 'id') && ~isempty(state.lease.id)
        storedLockId = char(string(state.lease.id));
        localStopHeartbeat(ref, storedLockId);
        released = localReleaseLease(ref, storedLockId, hub) || released;
    end

    % Never release additional leases merely because their user or host
    % resembles the current client. Only the exact lease id retained by this
    % shallow object is safe to release automatically. Ambiguous/stale leases
    % must go through the explicit, informed unlock action in the GUI.

    if released
        localClearLeaseState(shallowObj);
    end
end

function localStopProjectHeartbeats(ref)
    prefix = matlab.lang.makeValidName(['k_' regexprep([char(string(ref.project_id)) '_'], '[^a-zA-Z0-9_]', '_')]);
    workers = localGetRegistry('DetecDivHubLeaseWorkers');
    names = fieldnames(workers);
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

    % Clean timers created by older DetecDiv code in an already-running
    % MATLAB session.
    timers = struct();
    try
        existing = getappdata(0, 'DetecDivHubLeaseTimers');
        if isstruct(existing)
            timers = existing;
        end
    catch
    end
    names = fieldnames(timers);
    changed = false;
    for i = 1:numel(names)
        name = names{i};
        if ~startsWith(name, prefix)
            continue;
        end
        t = timers.(name);
        try
            stop(t);
            delete(t);
        catch
        end
        timers = rmfield(timers, name);
        changed = true;
    end
    if changed
        setappdata(0, 'DetecDivHubLeaseTimers', timers);
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
    workers = localGetRegistry('DetecDivHubLeaseWorkers');
    if isfield(workers, key)
        localCancelWorkerRecord(workers.(key));
        workers = rmfield(workers, key);
        setappdata(0, 'DetecDivHubLeaseWorkers', workers);
    end

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

function registry = localGetRegistry(name)
    registry = struct();
    try
        existing = getappdata(0, name);
        if isstruct(existing)
            registry = existing;
        end
    catch
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
