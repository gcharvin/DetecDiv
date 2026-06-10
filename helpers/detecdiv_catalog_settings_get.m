function catalogSettings = detecdiv_catalog_settings_get()
% detecdiv_catalog_settings_get  Load catalog GUI settings from userprefs.

    userprefs = detecdiv_prefs_load();
    defaults = localDefaultSettings();

    if ~isfield(userprefs, 'catalog') || ~isstruct(userprefs.catalog)
        catalogSettings = defaults;
        return;
    end

    catalogSettings = localMergeStruct(userprefs.catalog, defaults);
    if strcmpi(char(string(catalogSettings.dbFile)), localLegacyWorktreeDbFile())
        catalogSettings.dbFile = defaults.dbFile;
    end
end

function settings = localDefaultSettings()
    settings = struct( ...
        'defaultProjectRoot', '', ...
        'recentProjectRoots', {{}}, ...
        'dbFile', detecdiv_catalog_user_dbfile(), ...
        'backgroundIndexing', true, ...
        'lastSelectedProjectMat', '');
end

function out = localMergeStruct(in, defaults)
    out = defaults;
    fields = fieldnames(defaults);
    for i = 1:numel(fields)
        key = fields{i};
        if isfield(in, key) && ~isempty(in.(key))
            out.(key) = in.(key);
        end
    end
end

function dbFile = localLegacyWorktreeDbFile()
    helperDir = fileparts(mfilename('fullpath'));
    repoDir = fileparts(helperDir);
    dbFile = fullfile(repoDir, 'catalog', 'detecdiv_catalog.sqlite');
end
