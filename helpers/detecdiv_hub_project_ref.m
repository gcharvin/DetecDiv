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
    ref.project_dir_path = fullfile(char(string(shallowObj.io.path)), char(string(shallowObj.io.file)));
    ref.source = '';

    hubMeta = localHubMetadata(shallowObj);
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
            ref.project_id = localLookupProjectId(ref, hub);
            if ~isempty(ref.project_id)
                ref.source = 'hub lookup';
            end
        catch
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

function id = localLookupProjectId(ref, hub)
    id = '';
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
            id = char(string(row.id));
            return;
        end
        if isfield(row, 'project_name') && strcmp(char(string(row.project_name)), ref.project_name)
            id = char(string(row.id));
            return;
        end
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
