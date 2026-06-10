function dbFile = detecdiv_catalog_user_dbfile()
% detecdiv_catalog_user_dbfile  Return the per-user local catalog SQLite path.

    rootDir = localMatlabUserPath();
    dbDir = fullfile(rootDir, 'DetecDiv', 'catalog');
    dbFile = fullfile(dbDir, 'detecdiv_catalog.sqlite');
end

function rootDir = localMatlabUserPath()
    rawUserPath = strtrim(char(string(userpath)));
    if isempty(rawUserPath)
        rootDir = prefdir;
        return;
    end

    parts = regexp(rawUserPath, pathsep, 'split');
    parts = parts(~cellfun('isempty', parts));
    if isempty(parts)
        rootDir = prefdir;
    else
        rootDir = parts{1};
    end
end
