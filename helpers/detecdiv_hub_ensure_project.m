function [shallowObj, ref, status] = detecdiv_hub_ensure_project(shallowObj, varargin)
% detecdiv_hub_ensure_project  Resolve or directly register a Hub project.
%
% The Hub executes pipeline runs against catalogued projects. New local
% projects may not have a hub_project_id yet; this helper attempts to resolve
% one, directly register the exact project path when needed, then persist the
% resolved id in shallowObj.runProfiles.hub. It deliberately does not launch
% broad project-root indexing as a fallback.

    if nargin < 1 || isempty(shallowObj) || ~isa(shallowObj, 'shallow')
        error('detecdiv_hub_ensure_project:MissingProject', 'A shallow project is required.');
    end

    opts = localParse(varargin{:});
    status = struct('ok', false, 'createdOrQueued', false, 'message', '', ...
        'job', struct(), 'attemptedPath', '', 'registration', struct(), ...
        'registrationError', '', 'refreshedAt', char(datetime('now')));

    ref = detecdiv_hub_project_ref(shallowObj, opts.hub);
    if ~isempty(ref.project_id)
        shallowObj = localStoreHubRef(shallowObj, ref, status);
        status.ok = true;
        status.message = 'Hub project id already resolved.';
        return;
    end

    [registered, ref, status] = localTryDirectRegistration(ref, opts, status);
    if registered
        shallowObj = localStoreHubRef(shallowObj, ref, status);
        return;
    end

    status.message = ['Hub direct project registration failed: ' status.registrationError];
    shallowObj = localStoreHubState(shallowObj, status);
    if opts.ErrorIfQueued
        error('detecdiv_hub_ensure_project:DirectRegistrationFailed', '%s', status.message);
    end
end

function opts = localParse(varargin)
    opts = struct();
    opts.hub = detecdiv_hub_settings_get();
    opts.Visibility = 'private';
    opts.InitialWaitSec = 1;
    opts.ResolveAttempts = 4;
    opts.ResolveIntervalSec = 1.5;
    opts.ErrorIfQueued = false;
    i = 1;
    while i <= numel(varargin)
        key = lower(char(string(varargin{i})));
        if i == numel(varargin)
            break;
        end
        value = varargin{i+1};
        switch key
            case 'hub'
                opts.hub = value;
            case 'visibility'
                opts.Visibility = char(string(value));
            case 'initialwaitsec'
                opts.InitialWaitSec = double(value);
            case 'resolveattempts'
                opts.ResolveAttempts = double(value);
            case 'resolveintervalsec'
                opts.ResolveIntervalSec = double(value);
            case 'errorifqueued'
                opts.ErrorIfQueued = logical(value);
        end
        i = i + 2;
    end
end

function [registered, ref, status] = localTryDirectRegistration(ref, opts, status)
    registered = false;
    try
        [project, info] = detecdiv_hub_register_project_path(ref, 'Hub', opts.hub, 'Visibility', opts.Visibility);
        status.registration = info;
        if isstruct(project) && isfield(project, 'id') && ~isempty(project.id)
            ref = localApplyProjectDetail(ref, project);
            status.ok = true;
            status.createdOrQueued = true;
            status.message = 'Hub project registered directly.';
            registered = true;
        end
    catch ME
        status.registrationError = ME.message;
    end
end

function ref = localApplyProjectDetail(ref, project)
    ref.project_id = localFieldText(project, 'id');
    key = localFieldText(project, 'project_key');
    if ~isempty(key)
        ref.project_key = key;
    end
    name = localFieldText(project, 'project_name');
    if ~isempty(name)
        ref.project_name = name;
    end
    [serverMatPath, serverDirPath] = localServerProjectPathsFromDetail(project);
    if ~isempty(serverMatPath)
        ref.project_mat_path = serverMatPath;
    end
    if ~isempty(serverDirPath)
        ref.project_dir_path = serverDirPath;
    end
    ref.project_root_path = localPathRoot(ref.project_mat_path, ref.project_dir_path);
    ref.hubManaged = true;
    ref.source = 'hub direct registration';
end

function [matPath, dirPath] = localServerProjectPathsFromDetail(project)
    matPath = '';
    dirPath = '';
    if ~isstruct(project) || ~isfield(project, 'locations') || isempty(project.locations)
        return;
    end
    locs = localAsStructArray(project.locations);
    if isempty(locs)
        return;
    end
    idx = 1;
    for i = 1:numel(locs)
        try
            if isfield(locs(i), 'is_preferred') && logical(locs(i).is_preferred)
                idx = i;
                break;
            end
        catch
        end
    end
    matPath = localFieldText(locs(idx), 'project_mat_path');
    dirPath = localFieldText(locs(idx), 'project_dir_path');
end

function txt = localFieldText(S, name)
    txt = '';
    try
        if isstruct(S) && isfield(S, name) && ~isempty(S.(name))
            txt = char(string(S.(name)));
        end
    catch
    end
end

function rows = localAsStructArray(data)
    if isstruct(data)
        rows = data;
    elseif iscell(data)
        rows = [data{:}];
    else
        rows = struct([]);
    end
end

function rootPath = localPathRoot(varargin)
    rootPath = '';
    for i = 1:nargin
        candidate = char(string(varargin{i}));
        if isempty(candidate)
            continue;
        end
        try
            [parent1, ~] = fileparts(candidate);
            [parent2, ~] = fileparts(parent1);
            if ~isempty(parent2)
                rootPath = parent2;
                return;
            end
        catch
        end
    end
end

function shallowObj = localStoreHubRef(shallowObj, ref, status)
    if ~isprop(shallowObj, 'runProfiles') || ~isstruct(shallowObj.runProfiles)
        shallowObj.runProfiles = struct();
    end
    if ~isfield(shallowObj.runProfiles, 'hub') || ~isstruct(shallowObj.runProfiles.hub)
        shallowObj.runProfiles.hub = struct();
    end
    shallowObj.runProfiles.hub.hub_project_id = ref.project_id;
    shallowObj.runProfiles.hub.project_id = ref.project_id;
    shallowObj.runProfiles.hub.project_key = ref.project_key;
    shallowObj.runProfiles.hub.project_name = ref.project_name;
    shallowObj.runProfiles.hub.project_mat_path = ref.project_mat_path;
    shallowObj.runProfiles.hub.project_dir_path = ref.project_dir_path;
    shallowObj.runProfiles.hub.hubManaged = true;
    shallowObj.runProfiles.hub.last_ensure_status = status;
    shallowObj.runProfiles.hub.checked_at = char(datetime('now'));
end

function shallowObj = localStoreHubState(shallowObj, status)
    if ~isprop(shallowObj, 'runProfiles') || ~isstruct(shallowObj.runProfiles)
        shallowObj.runProfiles = struct();
    end
    if ~isfield(shallowObj.runProfiles, 'hub') || ~isstruct(shallowObj.runProfiles.hub)
        shallowObj.runProfiles.hub = struct();
    end
    shallowObj.runProfiles.hub.last_ensure_status = status;
    shallowObj.runProfiles.hub.checked_at = char(datetime('now'));
end
