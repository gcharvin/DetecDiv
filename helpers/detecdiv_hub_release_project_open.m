function detecdiv_hub_release_project_open(shallowObj, hub)
% detecdiv_hub_release_project_open  Stop heartbeat and release any open edit lease.

    if nargin < 2 || isempty(hub)
        hub = detecdiv_hub_settings_get();
    end
    state = localHubState(shallowObj);
    if ~isfield(state, 'lease') || ~isstruct(state.lease) || ~isfield(state.lease, 'id') || isempty(state.lease.id)
        return;
    end
    ref = detecdiv_hub_project_ref(shallowObj, hub);
    localStopHeartbeat(ref, state.lease.id);
    try
        detecdiv_hub_release_project_lease(ref, state.lease.id, hub);
    catch
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
