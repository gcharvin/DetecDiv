repoRoot = fileparts(mfilename('fullpath'));
detecdiv_setup_path(repoRoot, 'ResetPath', true, 'Verbose', true);
detecdivCatalogBrowser('DbFile', detecdiv_catalog_worktree_dbfile());
