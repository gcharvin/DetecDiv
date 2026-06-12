function datasets = detecdiv_catalog_list_raw_datasets(dbFile, varargin)
% detecdiv_catalog_list_raw_datasets  Return locally indexed raw datasets.

    if nargin < 1 || isempty(dbFile)
        dbFile = detecdiv_catalog_user_dbfile();
    end

    detecdiv_require_toolbox('Database Toolbox', 'sqlite');

    ip = inputParser;
    ip.addParameter('Status', '', @(x)ischar(x) || isstring(x));
    ip.addParameter('RootPath', '', @(x)ischar(x) || isstring(x));
    ip.parse(varargin{:});
    opts = ip.Results;

    if ~isfile(dbFile)
        datasets = table();
        return;
    end

    initConn = detecdiv_catalog_init(dbFile);
    close(initConn);
    conn = sqlite(dbFile, 'connect');
    cleanupObj = onCleanup(@() close(conn)); %#ok<NASGU>

    whereParts = {};
    if strlength(string(opts.Status)) > 0
        whereParts{end+1} = sprintf('d.status = %s', localSqlQuote(opts.Status)); %#ok<AGROW>
    end
    if strlength(string(opts.RootPath)) > 0
        rootPath = localCanonicalPath(opts.RootPath);
        whereParts{end+1} = sprintf('r.abs_path = %s', localSqlQuote(rootPath)); %#ok<AGROW>
    end

    sql = ['SELECT d.id AS dataset_id, COALESCE(d.external_key, '''') AS external_key, d.name, d.status, d.completeness_status, ' ...
        'd.dataset_kind, COALESCE(d.microscope_name, '''') AS microscope_name, d.visibility, COALESCE(d.owner_user_key, '''') AS owner_user_key, d.project_count, ' ...
        'd.position_count, d.total_bytes, COALESCE(d.storage_uri, '''') AS storage_uri, COALESCE(d.archive_uri, '''') AS archive_uri, COALESCE(d.local_path_hint, '''') AS local_path_hint, ' ...
        'COALESCE(d.created_at, '''') AS created_at, COALESCE(d.updated_at, '''') AS updated_at, COALESCE(d.last_scan_at, '''') AS last_scan_at, ' ...
        'COALESCE(l.abs_path, '''') AS raw_root, COALESCE(l.relative_path, '''') AS raw_rel_from_root, COALESCE(r.abs_path, '''') AS root_abs_path ' ...
        'FROM catalog_raw_datasets d ' ...
        'LEFT JOIN catalog_raw_dataset_locations l ON l.raw_dataset_id = d.id AND l.is_preferred = 1 ' ...
        'LEFT JOIN catalog_roots r ON r.id = l.root_id '];

    if ~isempty(whereParts)
        sql = [sql ' WHERE ' strjoin(whereParts, ' AND ')];
    end

    sql = [sql ' ORDER BY d.updated_at DESC, d.name ASC'];
    datasets = fetch(conn, sql);
end

function out = localCanonicalPath(pathIn)
    out = char(string(pathIn));
    if isempty(out)
        return;
    end
    if ispc
        out = strrep(out, '/', '\');
    else
        out = strrep(out, '\', '/');
    end
    try
        out = char(java.io.File(out).getCanonicalPath());
    catch
    end
end

function txt = localSqlQuote(value)
    if nargin < 1 || isempty(value)
        txt = 'NULL';
        return;
    end
    txt = char(string(value));
    txt = strrep(txt, '''', '''''');
    txt = ['''' txt ''''];
end
