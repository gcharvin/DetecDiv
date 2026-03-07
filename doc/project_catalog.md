# Project Catalog MVP

This first catalog layer indexes DetecDiv projects into a local SQLite database.
It is designed as an index only: the project `.mat` file and its project folder
remain the source of truth.

## What is indexed

- Project root, project `.mat` absolute path, and project folder absolute path
- Root-relative path to make future path relinking easier
- Coarse project counts:
  - FOV count
  - ROI count
  - classifier count
  - processor count
  - pipeline run count
- Raw data pointers found in the `shallow` object:
  - `srcpath`
  - `tiffSource`
  - `ndtiffPath`
- Pipeline run summaries parsed from `project/pipeline/*/run.json`
- Health flags:
  - `ok`
  - `raw_missing`
  - `missing_project_mat`
  - `missing_project_dir`

## MATLAB entry points

Initialize the SQLite database:

```matlab
conn = detecdiv_catalog_init();
close(conn);
```

Initialize a DB local to the current worktree:

```matlab
dbFile = detecdiv_catalog_worktree_dbfile();
conn = detecdiv_catalog_init(dbFile);
close(conn);
```

Index one or several roots:

```matlab
report = detecdiv_catalog_index_projects('D:\DetecDivProjects');
report = detecdiv_catalog_index_projects( ...
    {'D:\DetecDivProjects', 'E:\Archive\DetecDiv'}, ...
    fullfile(prefdir, 'detecdiv_catalog.sqlite'));
```

List indexed projects:

```matlab
projects = detecdiv_catalog_list_projects();
projects = detecdiv_catalog_list_projects([], 'HealthStatus', 'raw_missing');
```

Open the standalone catalog browser GUI:

```matlab
detecdivCatalogBrowser()
detecdivCatalogBrowser('RootPath', 'D:\DetecDivProjects')
```

Launch it from a clean MATLAB session without using the Path UI:

```matlab
run('C:\Users\charvin\Documents\MATLAB\DetecDiv-catalog\launch_catalog_browser.m')
```

Configure a clean path manually for either the main repo or a worktree:

```matlab
detecdiv_setup_path('C:\Users\charvin\Documents\MATLAB\DetecDiv-catalog')
detecdiv_setup_path('C:\Users\charvin\Documents\MATLAB\DetecDiv')
```

The browser can:

- choose and save a default project root folder
- launch root indexing on demand
- run indexing in a separate MATLAB batch job so the GUI stays responsive
- browse indexed projects from the local SQLite DB
- load a selected project into the MATLAB workspace

## Current project detection rule

A project candidate is currently detected when both exist:

- `MyProject.mat`
- `MyProject/`

This is intentionally conservative to avoid indexing classifier or processor files
stored inside projects.

## Current limitations

- The browser is currently a standalone `.m` GUI, not yet integrated into `detecdiv.mlapp`
- No stable project UUID written back into project files yet
- The indexer loads the `shallow` object to extract FOV, ROI, and raw-path metadata
- Labguru integration is not implemented yet
