# Project Catalog MVP

This first catalog layer indexes DetecDiv projects and raw datasets into a
local SQLite database.
It is designed as an index only: the project `.mat` file and its project folder
remain the source of truth for projects, and raw acquisition folders remain the
source of truth for raw datasets.

## What is indexed

### Projects

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
- Links from projects to detected raw datasets, stored in
  `catalog_project_raw_links`

### Raw datasets

The local schema mirrors the current Hub concepts at MVP level:

- `catalog_raw_datasets`
- `catalog_raw_dataset_locations`
- `catalog_raw_dataset_positions`
- `catalog_project_raw_links`

Indexed raw dataset fields include:

- stable local `external_key`
- acquisition label / display name
- format such as `single_tiff`, `tiff_sequence`, `ndtiff`, `ome_zarr`,
  `micromanager_tiff_dir`, `nd2`, `czi`, `lif`, `ims`
- completeness/status
- preferred local path
- total byte size
- position count and position rows when directory positions are detected
- linked project count

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

Index raw datasets from a root or a specific dataset folder:

```matlab
report = detecdiv_catalog_index_raw_datasets('D:\RawData');
report = detecdiv_catalog_index_raw_datasets('D:\RawData\Experiment001');
```

List indexed projects:

```matlab
projects = detecdiv_catalog_list_projects();
projects = detecdiv_catalog_list_projects([], 'HealthStatus', 'raw_missing');
```

List indexed raw datasets:

```matlab
datasets = detecdiv_catalog_list_raw_datasets();
```

## Current project detection rule

A project candidate is currently detected when both exist:

- `MyProject.mat`
- `MyProject/`

This is intentionally conservative to avoid indexing classifier or processor files
stored inside projects.

During project indexing, DetecDiv also resolves each project raw pointer into a
raw dataset candidate when possible. This aligns the local browser with Hub
indexing, where projects and raw datasets are separate tables linked by a
relation.

## Current raw dataset detection rule

A raw dataset candidate is detected when a folder looks like one of:

- OME-Zarr / Zarr root
- NDTiff root containing `NDTiff.index`
- Micro-Manager TIFF directory with metadata and position folders
- legacy MATLAB JPEG timelapse folder
- microscopy vendor file folder containing `.nd2`, `.czi`, `.lif`, or `.ims`
- TIFF folder or single TIFF acquisition

The raw dataset indexer accepts either a broad root to scan recursively or a
specific dataset folder.

## Current limitations

- No stable project UUID written back into project files yet
- The indexer loads the `shallow` object to extract FOV, ROI, and raw-path metadata
- Labguru integration is not implemented yet
- Local raw dataset metadata extraction is intentionally lighter than Hub
  ingestion: it records format, size, path, and directory-derived positions but
  does not yet parse every vendor metadata format.
