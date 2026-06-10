function ref = detecdiv_hub_project_ref(shallowObj, hub)
% detecdiv_hub_project_ref  Resolve hub identity metadata for a shallow project.

    if nargin < 1 || isempty(shallowObj) || ~isa(shallowObj, 'shallow')
        error('detecdiv_hub_project_ref:MissingProject', 'A shallow project is required.');
    end
    if nargin < 2 || isempty(hub)
        hub = detecdiv_hub_settings_get();
    end

    ref = struct();
    ref.hubManaged = false;
    ref.project_id = '';
    ref.project_key = '';
    ref.project_name = localProjectName(shallowObj);
    ref.project_mat_path = localProjectMatPath(shallowObj);
    ref.local_project_mat_path = ref.project_mat_path;
    ref.project_dir_path = fullfile(char(string(shallowObj.io.path)), char(string(shallowObj.io.file)));
    ref.local_project_dir_path = ref.project_dir_path;
    ref.local_project_root_path = localPathRoot(ref.local_project_mat_path, ref.local_project_dir_path);
    ref.project_root_path = ref.local_project_root_path;
    ref.source = '';

    hubMeta = localHubMetadata(shallowObj);
    ref = localApplyHubMetadataPaths(ref, hubMeta);
    [hubManagedFlag, hasHubManagedFlag] = localFirstLogical(hubMeta, {'hubManaged','hub_managed'});
    if hasHubManagedFlag && hubManagedFlag
        ref.hubManaged = true;
        ref.source = 'runProfiles.hub.hubManaged';
    end
    [ref.project_id, idSource] = localFirstText(hubMeta, {'hub_project_id','hubProjectId','project_id','projectId','id'});
    [ref.project_key, keySource] = localFirstText(hubMeta, {'project_key','projectKey','hub_project_key','hubProjectKey'});
    if ~isempty(ref.project_id)
        ref.hubManaged = true;
        ref.source = idSource;
        return;
    end
    if ~isempty(ref.project_key)
        ref.hubManaged = true;
        ref.source = keySource;
    end

    if ref.hubManaged && isempty(ref.project_id)
        try
            row = localLookupProject(ref, hub);
            if ~isempty(row)
                ref.hubManaged = true;
                ref.project_id = localFieldText(row, 'id');
                if isempty(ref.project_key)
                    ref.project_key = localFieldText(row, 'project_key');
                end
                [serverMatPath, serverDirPath] = localServerProjectPathsFromRow(row);
                if ~isempty(serverMatPath)
                    ref.project_mat_path = serverMatPath;
                end
                if ~isempty(serverDirPath)
                    ref.project_dir_path = serverDirPath;
                end
                ref.project_root_path = localPathRoot(ref.project_mat_path, ref.project_dir_path);
                ref.source = 'hub lookup';
            end
        catch
        end
    end
end

function ref = localApplyHubMetadataPaths(ref, hubMeta)
    if ~isstruct(hubMeta)
        return;
    end
    matPath = localFirstExistingText(hubMeta, {'project_mat_path','local_project_mat_path','projectMatPath','localProjectMatPath'});
    dirPath = localFirstExistingText(hubMeta, {'project_dir_path','local_project_dir_path','projectDirPath','localProjectDirPath'});
    if ~isempty(matPath)
        ref.project_mat_path = matPath;
        ref.local_project_mat_path = matPath;
    end
    if ~isempty(dirPath)
        ref.project_dir_path = dirPath;
        ref.local_project_dir_path = dirPath;
    end
    ref.local_project_root_path = localPathRoot(ref.local_project_mat_path, ref.local_project_dir_path);
    ref.project_root_path = localPathRoot(ref.project_mat_path, ref.project_dir_path);
end

function txt = localFirstExistingText(S, names)
    txt = '';
    if ~isstruct(S)
        return;
    end
    for i = 1:numel(names)
        name = names{i};
        if isfield(S, name) && ~isempty(S.(name))
            txt = char(string(S.(name)));
            return;
        end
    end
end

function [matPath, dirPath] = localServerProjectPathsFromRow(row)
    matPath = '';
    dirPath = '';
    if ~isstruct(row)
        return;
    end

    % Prefer preferred location paths from the hub catalog.
    if isfield(row, 'locations') && ~isempty(row.locations)
        locs = localAsStructArray(row.locations);
        if ~isempty(locs)
            preferredIdx = [];
            for i = 1:numel(locs)
                try
                    if isfield(locs(i), 'is_preferred') && logical(locs(i).is_preferred)
                        preferredIdx = i;
                        break;
                    end
                catch
                end
            end
            if isempty(preferredIdx)
                preferredIdx = 1;
            end
            matPath = localFieldText(locs(preferredIdx), 'project_mat_path');
            dirPath = localFieldText(locs(preferredIdx), 'project_dir_path');
        end
    end

    % Fallback to metadata paths set by indexer.
    if (isempty(matPath) || isempty(dirPath)) && isfield(row, 'metadata_json') && isstruct(row.metadata_json)
        meta = row.metadata_json;
        if isempty(matPath)
            matPath = localFieldText(meta, 'project_mat_abs');
        end
        if isempty(dirPath)
            dirPath = localFieldText(meta, 'project_dir_abs');
        end
    end
end

function meta = localHubMetadata(shallowObj)
    meta = struct();
    try
        if isprop(shallowObj, 'runProfiles') && isstruct(shallowObj.runProfiles)
            rp = shallowObj.runProfiles;
            if isfield(rp, 'hub') && isstruct(rp.hub)
                meta = rp.hub;
                return;
            end
            if isfield(rp, 'catalog') && isstruct(rp.catalog) && isfield(rp.catalog, 'hub') && isstruct(rp.catalog.hub)
                meta = rp.catalog.hub;
                return;
            end
        end
    catch
    end
end

function [txt, source] = localFirstText(S, names)
    txt = '';
    source = '';
    if ~isstruct(S)
        return;
    end
    for i = 1:numel(names)
        name = names{i};
        if isfield(S, name) && ~isempty(S.(name))
            txt = char(string(S.(name)));
            source = ['runProfiles.hub.' name];
            return;
        end
    end
end

function [value, found] = localFirstLogical(S, names)
    value = false;
    found = false;
    if ~isstruct(S)
        return;
    end
    for i = 1:numel(names)
        name = names{i};
        if ~isfield(S, name) || isempty(S.(name))
            continue;
        end
        found = true;
        raw = S.(name);
        try
            if islogical(raw)
                value = logical(raw(1));
            elseif isnumeric(raw)
                value = logical(raw(1));
            else
                txt = lower(strtrim(char(string(raw))));
                value = any(strcmp(txt, {'1','true','yes','on'}));
            end
        catch
            value = false;
        end
        return;
    end
end

function rowOut = localLookupProject(ref, hub)
    rowOut = [];
    if isempty(ref.project_key) && isempty(ref.project_name)
        return;
    end
    query = ref.project_key;
    if isempty(query)
        query = ref.project_name;
    end
    data = detecdiv_hub_request('GET', ['/projects?search=' localUrlEncode(query) '&limit=20'], [], hub);
    rows = localAsStructArray(data);
    for i = 1:numel(rows)
        row = rows(i);
        if ~isempty(ref.project_key) && isfield(row, 'project_key') && strcmp(char(string(row.project_key)), ref.project_key)
            rowOut = row;
            return;
        end
        if isfield(row, 'project_name') && strcmp(char(string(row.project_name)), ref.project_name)
            rowOut = row;
            return;
        end
    end
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

function out = localUrlEncode(value)
    try
        out = char(java.net.URLEncoder.encode(char(string(value)), 'UTF-8'));
        out = strrep(out, '+', '%20');
    catch
        out = char(string(value));
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

function name = localProjectName(shallowObj)
    name = '';
    try
        name = char(string(shallowObj.io.file));
    catch
    end
end

function path = localProjectMatPath(shallowObj)
    path = '';
    try
        if ~isempty(shallowObj.io.path) && ~isempty(shallowObj.io.file)
            path = fullfile(char(string(shallowObj.io.path)), [char(string(shallowObj.io.file)) '.mat']);
        end
    catch
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
