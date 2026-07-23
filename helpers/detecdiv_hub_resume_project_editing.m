function [shallowObj, access, info] = detecdiv_hub_resume_project_editing(shallowObj, varargin)
% detecdiv_hub_resume_project_editing  Reload a project and reacquire its edit lease.
%
% Hub submission releases the local client lease and makes the in-memory
% project stale. After a terminal job state, reload the server-written MAT
% file before acquiring a fresh client edit lease.

    opts = localParse(varargin{:});
    info = struct('reloaded', false, 'projectMatPath', '', 'message', '');

    if isempty(shallowObj) || ~isa(shallowObj, 'shallow')
        error('detecdiv_hub_resume_project_editing:MissingProject', ...
            'A shallow project is required.');
    end

    projectMatPath = opts.projectMatPath;
    if isempty(projectMatPath)
        projectMatPath = localProjectMatPath(shallowObj);
    end
    info.projectMatPath = projectMatPath;
    if isempty(projectMatPath) || exist(projectMatPath, 'file') ~= 2
        error('detecdiv_hub_resume_project_editing:MissingProjectFile', ...
            'Cannot reload the Hub-updated project file: %s', projectMatPath);
    end

    S = load(projectMatPath, 'shallowObj');
    if ~isfield(S, 'shallowObj') || ~isa(S.shallowObj, 'shallow')
        error('detecdiv_hub_resume_project_editing:InvalidProjectFile', ...
            'The project file does not contain a valid shallowObj: %s', projectMatPath);
    end

    shallowObj = S.shallowObj;
    localRestoreProjectPath(shallowObj, projectMatPath);
    info.reloaded = true;

    [shallowObj, access] = detecdiv_hub_prepare_project_open(shallowObj, ...
        'Hub', opts.hub, 'AcquireLease', true, 'TtlSeconds', opts.ttlSeconds);
    if access.readOnly
        info.message = ['Project reloaded, but local editing remains read-only: ' ...
            char(string(access.reason))];
    elseif access.hubManaged
        info.message = 'Project reloaded and local Hub edit lease acquired.';
    else
        info.message = 'Project reloaded; it is not managed by the Hub.';
    end
end

function opts = localParse(varargin)
    opts = struct('hub', detecdiv_hub_settings_get(), ...
        'ttlSeconds', 300, 'projectMatPath', '');
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
            case 'ttlseconds'
                opts.ttlSeconds = double(value);
            case 'projectmatpath'
                opts.projectMatPath = char(string(value));
        end
        i = i + 2;
    end
end

function projectMatPath = localProjectMatPath(shallowObj)
    projectMatPath = '';
    try
        if ~isempty(shallowObj.io.path) && ~isempty(shallowObj.io.file)
            projectMatPath = fullfile(char(string(shallowObj.io.path)), ...
                [char(string(shallowObj.io.file)) '.mat']);
        end
    catch
    end
end

function localRestoreProjectPath(shallowObj, projectMatPath)
    try
        [pathstr, namestr] = fileparts(projectMatPath);
        if isunix || ismac
            shallowObj.setPath([pathstr '/'], namestr);
        else
            shallowObj.setPath([pathstr '\'], namestr);
        end
    catch
    end
end
