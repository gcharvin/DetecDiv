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

Index one or several roots:

```matlab
report = detecdiv_catalog_index_projects('D:\DetecDivProjects');
report = detecdiv_catalog_index_projects( ...
    {'D:\DetecDivProjects', 'E:\Archive\DetecDiv'}, ...
    detecdiv_catalog_user_dbfile());
```

List indexed projects:

```matlab
projects = detecdiv_catalog_list_projects();
projects = detecdiv_catalog_list_projects([], 'HealthStatus', 'raw_missing');
```

## Current project detection rule

A project candidate is currently detected when both exist:

- `MyProject.mat`
- `MyProject/`

This is intentionally conservative to avoid indexing classifier or processor files
stored inside projects.

## Current limitations

- No GUI yet: this is the backend needed for a future project browser
- No stable project UUID written back into project files yet
- The indexer loads the `shallow` object to extract FOV, ROI, and raw-path metadata
- Labguru integration is not implemented yet
