function out = detecdiv_local_run_lock(action, project, varargin)
% detecdiv_local_run_lock  Session-local write lock for process-backed runs.
%
% The registry lives in the client MATLAB process. A process-pool worker has
% a separate registry and can therefore save the project while GUI clients
% in this MATLAB session are prevented from saving a stale in-memory copy.

    registryKey = 'DetecDivLocalRunLocks';
    action = lower(strtrim(char(string(action))));
    locks = localRegistry(registryKey);
    out = [];

    switch action
        case 'acquire'
            projectKey = localProjectKey(project);
            if isempty(projectKey)
                error('detecdiv_local_run_lock:MissingProject', ...
                    'A project path is required to acquire a local run lock.');
            end
            existing = localFindByProject(locks, projectKey);
            if ~isempty(existing)
                error('detecdiv_local_run_lock:AlreadyLocked', ...
                    'A local pipeline run already owns this project: %s', existing.runId);
            end
            runId = '';
            if ~isempty(varargin)
                runId = char(string(varargin{1}));
            end
            token = char(java.util.UUID.randomUUID);
            record = struct( ...
                'token', token, ...
                'projectKey', projectKey, ...
                'projectPath', localProjectPath(project), ...
                'runId', runId, ...
                'createdAt', char(datetime('now')));
            locks(end+1) = record; %#ok<AGROW>
            setappdata(0, registryKey, locks);
            out = record;

        case 'release'
            token = char(string(project));
            keep = true(1, numel(locks));
            for i = 1:numel(locks)
                keep(i) = ~strcmp(char(string(locks(i).token)), token);
            end
            released = any(~keep);
            locks = locks(keep);
            setappdata(0, registryKey, locks);
            out = released;

        case {'status','get'}
            out = localFindByProject(locks, localProjectKey(project));

        case 'assert'
            record = localFindByProject(locks, localProjectKey(project));
            if ~isempty(record)
                error('detecdiv_local_run_lock:ReadOnly', ...
                    ['Project is temporarily read-only because local pipeline run "%s" ' ...
                     'is executing in a separate MATLAB process.'], record.runId);
            end
            out = true;

        case 'clear'
            setappdata(0, registryKey, localEmptyRegistry());
            out = true;

        otherwise
            error('detecdiv_local_run_lock:UnknownAction', ...
                'Unknown local run lock action: %s', action);
    end
end

function locks = localRegistry(registryKey)
    locks = localEmptyRegistry();
    try
        existing = getappdata(0, registryKey);
        if isstruct(existing)
            locks = existing;
        end
    catch
    end
end

function locks = localEmptyRegistry()
    locks = struct('token', {}, 'projectKey', {}, 'projectPath', {}, ...
        'runId', {}, 'createdAt', {});
end

function record = localFindByProject(locks, projectKey)
    record = [];
    if isempty(projectKey)
        return;
    end
    for i = 1:numel(locks)
        if strcmp(char(string(locks(i).projectKey)), projectKey)
            record = locks(i);
            return;
        end
    end
end

function key = localProjectKey(project)
    pathText = localProjectPath(project);
    if isempty(pathText)
        key = '';
        return;
    end
    try
        pathText = char(java.io.File(pathText).getCanonicalPath());
    catch
        try
            pathText = char(java.io.File(pathText).getAbsolutePath());
        catch
        end
    end
    key = lower(regexprep(strrep(pathText, '\', '/'), '/+$', ''));
end

function pathText = localProjectPath(project)
    pathText = '';
    if isa(project, 'shallow')
        try
            [projectDir, projectName] = project.getPath;
            pathText = fullfile(projectDir, [projectName '.mat']);
        catch
            pathText = '';
        end
    elseif ischar(project) || isstring(project)
        pathText = char(string(project));
    end
end
