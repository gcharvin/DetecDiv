repoRoot = fileparts(mfilename('fullpath'));
if isfolder(fullfile(repoRoot, 'structure')) && isfolder(fullfile(repoRoot, 'helpers'))
    detecdivRoot = repoRoot;
else
    detecdivRoot = fullfile(fileparts(repoRoot), 'DetecDiv');
end
detecdiv_setup_path(repoRoot, 'ResetPath', true, 'Verbose', true, 'DetecDivRoot', detecdivRoot);
detecdiv_require_toolbox('Database Toolbox', 'sqlite');
detecdivCatalogBrowser('DbFile', detecdiv_catalog_worktree_dbfile());
