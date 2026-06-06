function [shallowObj, ref, status] = detecdiv_hub_ensure_project(shallowObj, varargin)
% detecdiv_hub_ensure_project  Resolve or queue Hub registration for a project.
%
% The Hub executes pipeline runs against catalogued projects. New local
% projects may not have a hub_project_id yet; this helper attempts to resolve
% one, queue a server-side index job when needed, then persist the resolved id
% in shallowObj.runProfiles.hub.

    if nargin < 1 || isempty(shallowObj) || ~isa(shallowObj, 'shallow')
        error('detecdiv_hub_ensure_project:MissingProject', 'A shallow project is required.');
    end

    opts = localParse(varargin{:});
    status = struct('ok', false, 'createdOrQueued', false, 'message', '', ...
        'job', struct(), 'attemptedPath', '', 'refreshedAt', char(datetime('now')));

    ref = detecdiv_hub_project_ref(shallowObj, opts.hub);
    if ~isempty(ref.project_id)
        shallowObj = localStoreHubRef(shallowObj, ref, status);
        status.ok = true;
        status.message = 'Hub project id already resolved.';
        return;
    end

    serverPath = localProjectIndexPath(ref, opts.hub);
    status.attemptedPath = serverPath;
    if isempty(serverPath)
        status.message = 'Unable to resolve a server-visible project path for Hub indexing.';
        if opts.ErrorIfQueued
            error('detecdiv_hub_ensure_project:NoServerPath', '%s', status.message);
        end
        return;
    end

    [hasPendingJob, pendingStatus] = localExistingPendingJob(shallowObj, opts.hub);
    if hasPendingJob
        status = pendingStatus;
        status.message = 'Hub project indexing is already queued or running.';
        pause(max(0, opts.InitialWaitSec));
        for i = 1:max(1, opts.ResolveAttempts)
            ref = detecdiv_hub_project_ref(shallowObj, opts.hub);
            if ~isempty(ref.project_id)
                status.ok = true;
                status.message = 'Hub project id resolved after pending indexing job.';
                shallowObj = localStoreHubRef(shallowObj, ref, status);
                return;
            end
            pause(max(0, opts.ResolveIntervalSec));
        end
        if opts.ErrorIfQueued
            error('detecdiv_hub_ensure_project:IndexQueued', ...
                ['Project is already queued for Hub indexing, but no hub_project_id is available yet.' newline ...
                 'Retry Hub run submission after the indexing job completes.' newline ...
                 'Indexed path: %s'], status.attemptedPath);
        end
        return;
    end

    payload = struct();
    payload.source_path = serverPath;
    payload.source_kind = 'project_root';
    payload.storage_root_name = localStorageRootNameForPath(serverPath);
    payload.host_scope = 'server';
    payload.root_type = 'project_root';
    payload.owner_user_key = localHubUser(opts.hub);
    payload.visibility = opts.Visibility;
    payload.clear_existing_for_root = false;
    payload.scan_orphan_raw = true;
    payload.queue_previews = false;
    payload.requested_by = localHubUser(opts.hub);
    payload.metadata_json = struct( ...
        'requested_by', 'DetecDiv MATLAB', ...
        'reason', 'pipeline run hub submission', ...
        'project_name', ref.project_name, ...
        'local_project_mat_path', ref.local_project_mat_path, ...
        'local_project_dir_path', ref.local_project_dir_path, ...
        'server_project_path', serverPath);

    try
        status.job = detecdiv_hub_request('POST', '/indexing/jobs', payload, opts.hub);
        status.createdOrQueued = true;
        status.message = 'Hub project indexing job queued.';
    catch ME
        status.message = ['Unable to queue Hub project indexing: ' ME.message];
        if opts.ErrorIfQueued
            error('detecdiv_hub_ensure_project:IndexQueueFailed', '%s', status.message);
        end
        return;
    end

    pause(max(0, opts.InitialWaitSec));
    for i = 1:max(1, opts.ResolveAttempts)
        ref = detecdiv_hub_project_ref(shallowObj, opts.hub);
        if ~isempty(ref.project_id)
            status.ok = true;
            status.message = 'Hub project id resolved after indexing.';
            shallowObj = localStoreHubRef(shallowObj, ref, status);
            return;
        end
        pause(max(0, opts.ResolveIntervalSec));
    end

    shallowObj = localStoreHubState(shallowObj, status);
    if opts.ErrorIfQueued
        error('detecdiv_hub_ensure_project:IndexQueued', ...
            ['Project was queued for Hub indexing, but no hub_project_id is available yet.' newline ...
             'Retry Hub run submission after the indexing job completes.' newline ...
             'Indexed path: %s'], serverPath);
    end
end

function [tf, status] = localExistingPendingJob(shallowObj, hub)
    tf = false;
    status = struct('ok', false, 'createdOrQueued', true, 'message', '', ...
        'job', struct(), 'attemptedPath', '', 'refreshedAt', char(datetime('now')));
    try
        hubState = shallowObj.runProfiles.hub;
        prev = hubState.last_ensure_status;
        if ~isstruct(prev) || ~isfield(prev, 'job') || ~isstruct(prev.job)
            return;
        end
        jobId = '';
        if isfield(prev.job, 'job_id') && ~isempty(prev.job.job_id)
            jobId = char(string(prev.job.job_id));
        elseif isfield(prev.job, 'id') && ~isempty(prev.job.id)
            jobId = char(string(prev.job.id));
        end
        if isempty(jobId)
            return;
        end
        job = detecdiv_hub_request('GET', ['/jobs/' jobId], [], hub);
        jobStatus = '';
        if isstruct(job) && isfield(job, 'status') && ~isempty(job.status)
            jobStatus = lower(char(string(job.status)));
        end
        if any(strcmp(jobStatus, {'queued','running','submitted'}))
            tf = true;
            status = prev;
            status.job = job;
            status.refreshedAt = char(datetime('now'));
        end
    catch
        tf = false;
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

function serverPath = localProjectIndexPath(ref, hub)
    serverPath = '';
    candidates = {};
    if isfield(ref, 'local_project_mat_path') && ~isempty(ref.local_project_mat_path)
        [parentPath, ~, ~] = fileparts(char(string(ref.local_project_mat_path)));
        candidates{end+1} = parentPath; %#ok<AGROW>
    end
    if isfield(ref, 'local_project_root_path') && ~isempty(ref.local_project_root_path)
        candidates{end+1} = ref.local_project_root_path; %#ok<AGROW>
    end
    for i = 1:numel(candidates)
        translated = localTranslatePathForServer(candidates{i}, hub);
        if ~isempty(translated)
            serverPath = translated;
            return;
        end
    end
end

function pathOut = localTranslatePathForServer(pathIn, hub)
    pathOut = char(string(pathIn));
    if isempty(pathOut)
        return;
    end
    pathOut = detecdiv_paths_map_module_path(pathOut, struct('hub', hub), 'server');
    pathOut = strrep(pathOut, '\', '/');
end

function rootName = localStorageRootNameForPath(serverPath)
    rootName = '';
    parts = split(string(regexprep(serverPath, '^/+', '')), '/');
    if numel(parts) >= 2 && strcmp(parts(1), "data")
        rootName = char(parts(2));
    end
end

function user = localHubUser(hub)
    user = '';
    try
        if isfield(hub, 'userKey') && ~isempty(hub.userKey)
            user = char(string(hub.userKey));
        end
    catch
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
