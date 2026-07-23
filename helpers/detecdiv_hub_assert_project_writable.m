function ok = detecdiv_hub_assert_project_writable(shallowObj, varargin)
% detecdiv_hub_assert_project_writable  Error when hub policy says read-only.

    opts = localParse(varargin{:});
    ok = true;
    if exist('detecdiv_local_run_lock', 'file') == 2
        detecdiv_local_run_lock('assert', shallowObj);
    end
    ref = detecdiv_hub_project_ref(shallowObj, opts.hub);
    if ~ref.hubManaged
        return;
    end

    hubState = localHubState(shallowObj);
    if isfield(hubState, 'read_only') && logical(hubState.read_only)
        ok = false;
        error('detecdiv_hub_assert_project_writable:ReadOnly', ...
            'Project is read-only under hub coordination: %s', localFieldText(hubState, 'reason', 'no active lease'));
    end

    if isfield(hubState, 'lease') && isstruct(hubState.lease) && isfield(hubState.lease, 'id') && ~isempty(hubState.lease.id)
        try
            detecdiv_hub_heartbeat_project_lease(ref, hubState.lease.id, 'Hub', opts.hub, 'TtlSeconds', opts.ttlSeconds);
        catch ME
            ok = false;
            error('detecdiv_hub_assert_project_writable:LeaseLost', ...
                'Hub edit lease is lost or expired; save blocked. %s', ME.message);
        end
    else
        ok = false;
        error('detecdiv_hub_assert_project_writable:NoLease', ...
            'Hub-managed project has no active local edit lease; save blocked.');
    end
end

function opts = localParse(varargin)
    opts = struct('hub', detecdiv_hub_settings_get(), 'ttlSeconds', 300);
    i = 1;
    while i <= numel(varargin)
        key = lower(char(string(varargin{i})));
        if i == numel(varargin), break; end
        value = varargin{i+1};
        switch key
            case 'hub'
                opts.hub = value;
            case 'ttlseconds'
                opts.ttlSeconds = double(value);
        end
        i = i + 2;
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

function txt = localFieldText(S, name, defaultValue)
    txt = defaultValue;
    try
        if isstruct(S) && isfield(S, name) && ~isempty(S.(name))
            txt = char(string(S.(name)));
        end
    catch
    end
end
