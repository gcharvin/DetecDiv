repoRoot = fileparts(mfilename('fullpath'));
detecdivRoot = fullfile(fileparts(repoRoot), 'DetecDiv');
detecdiv_setup_path(repoRoot, 'ResetPath', true, 'Verbose', true, 'DetecDivRoot', detecdivRoot);
detecdivCatalogBrowser('DbFile', detecdiv_catalog_worktree_dbfile());
