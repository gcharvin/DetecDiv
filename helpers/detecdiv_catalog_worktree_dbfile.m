function dbFile = detecdiv_catalog_worktree_dbfile()
% detecdiv_catalog_worktree_dbfile  Return the catalog DB path stored in this worktree.

    helperDir = fileparts(mfilename('fullpath'));
    repoDir = fileparts(helperDir);
    dbFile = fullfile(repoDir, 'catalog', 'detecdiv_catalog.sqlite');
end
