# Catalog Keep Manifest

This document defines the intended scope of `detecdiv-catalog` after the
runtime split with the main `DetecDiv` repository.

## Goal

`detecdiv-catalog` should keep only the code that is specific to:

- project catalog browsing
- local SQLite indexing
- detecdiv-hub client integration
- launch/bootstrap of the external `DetecDiv` runtime

Everything else should come from the main `DetecDiv` repository.

## Keep

Top-level files:

- [detecdiv_setup_path.m](C:\Users\charvin\Documents\MATLAB\detecdiv-catalog\detecdiv_setup_path.m)
- [launch_catalog_browser.m](C:\Users\charvin\Documents\MATLAB\detecdiv-catalog\launch_catalog_browser.m)
- [launch_detecdiv_app.m](C:\Users\charvin\Documents\MATLAB\detecdiv-catalog\launch_detecdiv_app.m)
- [README.md](C:\Users\charvin\Documents\MATLAB\detecdiv-catalog\README.md)
- [LICENSE](C:\Users\charvin\Documents\MATLAB\detecdiv-catalog\LICENSE)
- [AGENT.md](C:\Users\charvin\Documents\MATLAB\detecdiv-catalog\AGENT.md)

Catalog UI:

- [catalog_gui/detecdivCatalogBrowser.m](C:\Users\charvin\Documents\MATLAB\detecdiv-catalog\catalog_gui\detecdivCatalogBrowser.m)

Catalog helpers:

- [helpers/detecdiv_catalog_index_projects.m](C:\Users\charvin\Documents\MATLAB\detecdiv-catalog\helpers\detecdiv_catalog_index_projects.m)
- [helpers/detecdiv_catalog_init.m](C:\Users\charvin\Documents\MATLAB\detecdiv-catalog\helpers\detecdiv_catalog_init.m)
- [helpers/detecdiv_catalog_list_projects.m](C:\Users\charvin\Documents\MATLAB\detecdiv-catalog\helpers\detecdiv_catalog_list_projects.m)
- [helpers/detecdiv_catalog_run_index_job.m](C:\Users\charvin\Documents\MATLAB\detecdiv-catalog\helpers\detecdiv_catalog_run_index_job.m)
- [helpers/detecdiv_catalog_settings_get.m](C:\Users\charvin\Documents\MATLAB\detecdiv-catalog\helpers\detecdiv_catalog_settings_get.m)
- [helpers/detecdiv_catalog_settings_set.m](C:\Users\charvin\Documents\MATLAB\detecdiv-catalog\helpers\detecdiv_catalog_settings_set.m)
- [helpers/detecdiv_catalog_worktree_dbfile.m](C:\Users\charvin\Documents\MATLAB\detecdiv-catalog\helpers\detecdiv_catalog_worktree_dbfile.m)

Hub client helpers:

- all [helpers/detecdiv_hub_*.m](C:\Users\charvin\Documents\MATLAB\detecdiv-catalog\helpers)

Catalog data and docs:

- [catalog](C:\Users\charvin\Documents\MATLAB\detecdiv-catalog\catalog)
- [doc](C:\Users\charvin\Documents\MATLAB\detecdiv-catalog\doc)

## Externalize To Main DetecDiv

These families should no longer be carried by `detecdiv-catalog`:

- `engine/`
- `structure/classes/`
- `structure/io/`
- legacy and duplicated App Designer GUIs
- duplicated synchronization helpers for the DetecDiv apps

They must be resolved from:

- [C:\Users\charvin\Documents\MATLAB\DetecDiv](C:\Users\charvin\Documents\MATLAB\DetecDiv)

## Delete Candidates

The following content is considered duplicated runtime and should be removed
from `detecdiv-catalog` once the external bootstrap is validated:

- [engine](C:\Users\charvin\Documents\MATLAB\detecdiv-catalog\engine)
- [structure](C:\Users\charvin\Documents\MATLAB\detecdiv-catalog\structure)
- [backups](C:\Users\charvin\Documents\MATLAB\detecdiv-catalog\backups)
- [classiNormalizeCategory.m](C:\Users\charvin\Documents\MATLAB\detecdiv-catalog\classiNormalizeCategory.m)
- [codex_extract_detecdiv.m](C:\Users\charvin\Documents\MATLAB\detecdiv-catalog\codex_extract_detecdiv.m)
- [detecdiv.m.old](C:\Users\charvin\Documents\MATLAB\detecdiv-catalog\detecdiv.m.old)
- [sync_mlapp_code.m](C:\Users\charvin\Documents\MATLAB\detecdiv-catalog\sync_mlapp_code.m)
- [sync_workflow_layout.m](C:\Users\charvin\Documents\MATLAB\detecdiv-catalog\sync_workflow_layout.m)
- [sync_pipelineGUI_layout.m](C:\Users\charvin\Documents\MATLAB\detecdiv-catalog\sync_pipelineGUI_layout.m)
- [_tmp_workflow_patch.py](C:\Users\charvin\Documents\MATLAB\detecdiv-catalog\_tmp_workflow_patch.py)
- [unused_functions_report.txt](C:\Users\charvin\Documents\MATLAB\detecdiv-catalog\unused_functions_report.txt)

## Rationale

The catalog-specific surface is intentionally small. The current repository
contains a near-fork of `DetecDiv`, which creates maintenance divergence in:

- pipeline execution
- pipeline GUI
- workflow GUI
- project shell GUI
- classifier and ROI engines

The external bootstrap is now the default path, so the repository should
converge toward a thin client over the main `DetecDiv` runtime.
