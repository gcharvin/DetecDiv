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

## Remote hub API

The worktree also includes a minimal MATLAB client for `detecdiv-hub`.
It can list projects from the remote API, fetch one project detail, resolve
the best local path, and call `shallowLoad` locally.

The catalog browser GUI now supports two modes:

- `Local SQLite`
- `Hub API`

In hub mode:

- `Hub Root` is the canonical root known by the server or API
- `Local Mount` is the client-side path that maps the same storage over Samba
- saving the configuration stores a remote-to-local path-prefix mapping
- `User` sets the hub identity used for ownership and visibility filtering
- `Index Root` calls `POST /indexing` on the hub instead of the local MATLAB indexer
- `Refresh` lists projects from the API
- `Load Project` resolves the local `.mat` path from the remote metadata and the saved mapping
- `Group` filters the visible project list to one user-owned project group
- `Owned only` restricts the listing to projects owned by the current hub user
- the details panel shows owner, visibility, size, notes count, ACL count, and group membership
- `Notes...`, `Group...`, `Share...`, and `Delete...` expose the first governance actions directly from MATLAB

Configure the hub URL:

```matlab
hub = detecdiv_hub_settings_get();
hub.baseUrl = 'http://127.0.0.1:8000';
hub.userKey = 'localdev';
detecdiv_hub_settings_set(hub);
```

List projects from the API:

```matlab
projects = detecdiv_hub_list_projects();
projects(1)
```

Get one project detail and inspect its published locations:

```matlab
projectDetail = detecdiv_hub_get_project(projects(1).id);
projectDetail.locations
```

Load a project locally from hub metadata:

```matlab
[shallowObj, msg, projectDetail, resolutionInfo] = detecdiv_hub_load_project(projects(1).id);
```

If the API only knows a server-side root, define a local override in
`hub.storageRootMap` using the storage root name as the field key:

```matlab
hub = detecdiv_hub_settings_get();
hub.storageRootMap.server_projects = 'Z:\detecdiv';
detecdiv_hub_settings_set(hub);
```

The resolver tries:

- the path returned directly by the hub
- then `hub.storageRootMap.<storage_root.name>` if present
- then any saved remote-prefix to local-prefix mapping in `hub.pathPrefixMap`

If the hub enforces per-user visibility, set `hub.userKey` so MATLAB sends
`?user_key=...` on API requests.

The browser uses these governance endpoints when running against the hub:

- `GET /users/me`
- `GET /project-groups`
- `GET /project-groups/{id}`
- `POST /project-groups`
- `POST /project-groups/{id}/projects/{project_id}`
- `GET /projects/{id}/notes`
- `POST /projects/{id}/notes`
- `GET /projects/{id}/acl`
- `POST /projects/{id}/acl`
- `POST /projects/{id}/deletion-preview`
- `DELETE /projects/{id}`

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
