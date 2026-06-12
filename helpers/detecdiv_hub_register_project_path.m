function [project, info] = detecdiv_hub_register_project_path(ref, varargin)
% detecdiv_hub_register_project_path  Directly register a known project path in Hub.
%
% This fast path creates/updates the Hub project row from the exact project
% paths supplied by the MATLAB client. It avoids queuing a broad indexing job
% before a pipeline run can be submitted.

    if nargin < 1 || ~isstruct(ref)
        error('detecdiv_hub_register_project_path:MissingRef', 'A project reference struct is required.');
    end

    opts = localParse(varargin{:});
    info = struct('ok', false, 'message', '', 'serverMatPath', '', 'serverDirPath', '', ...
        'serverRootPath', '', 'storageRootName', '', 'request', struct());

    serverMatPath = localTranslatePathForServer(localFirstText(ref, {'local_project_mat_path','project_mat_path'}), opts.hub);
    serverDirPath = localTranslatePathForServer(localFirstText(ref, {'local_project_dir_path','project_dir_path'}), opts.hub);
    if isempty(serverMatPath)
        error('detecdiv_hub_register_project_path:NoServerMatPath', ...
            'Unable to resolve a server-visible .mat project path.');
    end
    if isempty(serverDirPath)
        [parentPath, fileName, ~] = fileparts(serverMatPath);
        serverDirPath = [parentPath '/' fileName];
    end

    serverRootPath = localServerRootForPath(serverMatPath);
    storageRootName = localStorageRootNameForPath(serverMatPath);

    payload = struct();
    payload.project_name = localFirstText(ref, {'project_name'});
    payload.project_mat_path = serverMatPath;
    payload.project_dir_path = serverDirPath;
    payload.root_path = serverRootPath;
    payload.storage_root_name = storageRootName;
    payload.host_scope = 'server';
    payload.root_type = 'project_root';
    payload.owner_user_key = localHubUser(opts.hub);
    payload.visibility = opts.Visibility;
    payload.metadata_json = struct( ...
        'requested_by', 'DetecDiv MATLAB', ...
        'reason', 'pipeline run hub submission', ...
        'local_project_mat_path', localFirstText(ref, {'local_project_mat_path','project_mat_path'}), ...
        'local_project_dir_path', localFirstText(ref, {'local_project_dir_path','project_dir_path'}));

    info.serverMatPath = serverMatPath;
    info.serverDirPath = serverDirPath;
    info.serverRootPath = serverRootPath;
    info.storageRootName = storageRootName;
    info.request = payload;

    [project, requestInfo] = detecdiv_hub_request('POST', '/projects/register-path', payload, opts.hub);
    info.ok = true;
    info.message = 'Hub project registered directly.';
    info.requestInfo = requestInfo;
end

function opts = localParse(varargin)
    opts = struct();
    opts.hub = detecdiv_hub_settings_get();
    opts.Visibility = 'private';
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
        end
        i = i + 2;
    end
end

function txt = localFirstText(S, names)
    txt = '';
    for i = 1:numel(names)
        name = names{i};
        if isstruct(S) && isfield(S, name) && ~isempty(S.(name))
            txt = char(string(S.(name)));
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

function rootPath = localServerRootForPath(serverPath)
    rootPath = '';
    parts = split(string(regexprep(serverPath, '^/+', '')), '/');
    if numel(parts) >= 2 && strcmp(parts(1), "data")
        rootPath = ['/data/' char(parts(2))];
    end
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
