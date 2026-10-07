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
    localReportProgress(opts.progressCallback, 0.01, ...
        'Checking project manifest and MAT file on the client storage...', 'projectFiles');
    [projectParent, projectName] = fileparts(projectMatPath);
    projectJsonPath = fullfile(projectParent, [projectName '.json']);
    if isempty(projectMatPath) || ...
            (exist(projectMatPath, 'file') ~= 2 && exist(projectJsonPath, 'file') ~= 2)
        error('detecdiv_hub_resume_project_editing:MissingProjectFile', ...
            'Cannot reload the Hub-updated project file: %s', projectMatPath);
    end

    % Match normal project opening: workers update the light JSON manifest
    % and its FOV sidecars; the legacy MAT snapshot may still be older.
    % Import directly so a stale base-workspace handle cannot be reused.
    if exist(projectJsonPath, 'file') == 2
        localReportProgress(opts.progressCallback, 0.03, ...
            'Reading the light project manifest and its sidecars...', 'projectImport');
        [reloadedObj, loadMsg] = shallowProjectImportLight(projectJsonPath, ...
            'HubPathSettings', opts.hub, ...
            'ProgressCallback', @(p)localForwardImportProgress(opts.progressCallback, p));
        if isempty(reloadedObj) || ~isa(reloadedObj, 'shallow')
            error('detecdiv_hub_resume_project_editing:InvalidProjectFile', ...
                'Cannot reload project manifest %s: %s', projectJsonPath, loadMsg);
        end
        shallowObj = reloadedObj;
    else
        localReportProgress(opts.progressCallback, 0.03, ...
            'Loading the project MAT snapshot from client storage...', 'projectMat');
        S = load(projectMatPath, 'shallowObj');
        if ~isfield(S, 'shallowObj') || ~isa(S.shallowObj, 'shallow')
            error('detecdiv_hub_resume_project_editing:InvalidProjectFile', ...
                'The project file does not contain a valid shallowObj: %s', projectMatPath);
        end
        shallowObj = S.shallowObj;
        shallowObj = detecdiv_paths_localize_project(shallowObj, opts.hub);
    end
    localReportProgress(opts.progressCallback, 0.80, ...
        'Restoring the project path and Hub identity...', 'projectFinalize');
    localRestoreProjectPath(shallowObj, projectMatPath);
    info.reloaded = true;

    localReportProgress(opts.progressCallback, 0.84, ...
        'Checking Hub edit locks and requesting a local edit lease...', 'hubAccess');
    [shallowObj, access] = detecdiv_hub_prepare_project_open(shallowObj, ...
        'Hub', opts.hub, 'AcquireLease', true, 'TtlSeconds', opts.ttlSeconds, ...
        'ProgressCallback', @(p)localForwardAccessProgress(opts.progressCallback, p));
    if access.readOnly
        info.message = ['Project reloaded, but local editing remains read-only: ' ...
            char(string(access.reason))];
    elseif access.hubManaged
        info.message = 'Project reloaded and local Hub edit lease acquired.';
    else
        info.message = 'Project reloaded; it is not managed by the Hub.';
    end
    localReportProgress(opts.progressCallback, 0.94, info.message, 'projectReady');
end

function opts = localParse(varargin)
    opts = struct('hub', detecdiv_hub_settings_get(), ...
        'ttlSeconds', 300, 'projectMatPath', '', 'progressCallback', []);
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
            case 'progresscallback'
                opts.progressCallback = value;
        end
        i = i + 2;
    end
end

function localForwardImportProgress(callback, progress)
    if isempty(callback) || ~isstruct(progress) || ~isfield(progress, 'message')
        return;
    end
    fraction = 0.03;
    if isfield(progress, 'fraction') && isnumeric(progress.fraction) && isscalar(progress.fraction)
        fraction = 0.03 + 0.77 * min(1, max(0, double(progress.fraction)));
    end
    stage = 'projectImport';
    if isfield(progress, 'stage')
        stage = char(string(progress.stage));
    end
    localReportProgress(callback, fraction, char(string(progress.message)), stage);
end

function localForwardAccessProgress(callback, progress)
    if isempty(callback) || ~isstruct(progress) || ~isfield(progress, 'message')
        return;
    end
    fraction = 0.84;
    if isfield(progress, 'fraction') && isnumeric(progress.fraction) && isscalar(progress.fraction)
        fraction = 0.84 + 0.09 * min(1, max(0, double(progress.fraction)));
    end
    stage = 'hubAccess';
    if isfield(progress, 'stage')
        stage = char(string(progress.stage));
    end
    localReportProgress(callback, fraction, char(string(progress.message)), stage);
end

function localReportProgress(callback, fraction, message, stage)
    if isempty(callback)
        return;
    end
    payload = struct('fraction', min(1, max(0, double(fraction))), ...
        'message', char(string(message)), 'stage', char(string(stage)));
    try
        callback(payload);
    catch
        % UI reporting must not interrupt project recovery.
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
