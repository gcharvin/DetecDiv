function projects = detecdiv_catalog_list_projects(dbFile, varargin)
% detecdiv_catalog_list_projects  Return indexed projects as a table.
%
% Usage
%   projects = detecdiv_catalog_list_projects()
%   projects = detecdiv_catalog_list_projects(dbFile)
%   projects = detecdiv_catalog_list_projects(dbFile, 'HealthStatus', 'ok')

    if nargin < 1 || isempty(dbFile)
        dbFile = fullfile(prefdir, 'detecdiv_catalog.sqlite');
    end

    detecdiv_require_toolbox('Database Toolbox', 'sqlite');

    ip = inputParser;
    ip.addParameter('HealthStatus', '', @(x)ischar(x) || isstring(x));
    ip.addParameter('RootPath', '', @(x)ischar(x) || isstring(x));
    ip.parse(varargin{:});
    opts = ip.Results;

    if ~isfile(dbFile)
        projects = table();
        return;
    end

    conn = sqlite(dbFile, 'connect');
    cleanupObj = onCleanup(@() close(conn)); %#ok<NASGU>

    whereParts = {};
    if strlength(string(opts.HealthStatus)) > 0
        whereParts{end+1} = sprintf('p.health_status = %s', localSqlQuote(opts.HealthStatus)); %#ok<AGROW>
    end
    if strlength(string(opts.RootPath)) > 0
        rootPath = localCanonicalPath(opts.RootPath);
        whereParts{end+1} = sprintf('r.abs_path = %s', localSqlQuote(rootPath)); %#ok<AGROW>
    end

    sql = ['SELECT p.id, p.name, p.health_status, p.raw_status, p.project_mat_abs, p.project_dir_abs, ' ...
        'p.project_rel_from_root, p.fov_count, p.roi_count, p.classifier_count, p.processor_count, ' ...
        'p.pipeline_run_count, p.available_raw_count, p.missing_raw_count, p.last_scan_at, ' ...
        'p.project_mtime, p.created_at, ' ...
        'r.abs_path AS root_abs_path ' ...
        'FROM catalog_projects p ' ...
        'INNER JOIN catalog_roots r ON r.id = p.root_id '];

    if ~isempty(whereParts)
        sql = [sql ' WHERE ' strjoin(whereParts, ' AND ')];
    end

    sql = [sql ' ORDER BY r.abs_path, p.project_rel_from_root, p.name'];
    projects = fetch(conn, sql);
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
