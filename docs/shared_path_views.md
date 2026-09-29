# Shared storage paths on clients and workers

A drive letter, its UNC share and a canonical Hub path can identify the same
file. For example, a client may use `Z:\Abhilasha\Sample.ome.zarr`, a Windows
worker `\\storage\DATA\Abhilasha\Sample.ome.zarr`, and the Linux worker
`/data/Abhilasha/Sample.ome.zarr`. Drive letters belong to one Windows logon
session; they do not identify storage across machines.

Hub submission resolves configured client roots to their canonical server
roots. DetecDiv obtains network-drive/UNC equivalences from Windows in the
current session, caches them for 30 seconds, and expands configured
mappings. It does not guess a share from the dataset name or a drive letter.
The legacy `X:\` default alone is not used to infer UNC aliases.
Recorded mappings from another client's run are retained as declared; their
drive letters are not expanded using the current workstation's SMB session.

On loading a project or parsing raw data, DetecDiv prefers the configured
Local root when the equivalent local path is available. This also applies to
an UNC path that remains accessible. Loading updates in-memory paths without
rewriting project files or historical execution context. Both JSON and
legacy MAT projects are supported; OME-Zarr, NDTiff, TIFF and frame-list
pointers stay consistent. Reusable pipeline/run references use the same
resolver. Existing projects do not need to be reparsed to submit them again.

If Windows drive discovery is unavailable, add the verified UNC prefix as
another `hub.pathMappings` entry pointing to the same server root. Upserting
an alias preserves other local roots. Local root remains the preferred
client view, even if an older UNC entry appears first in the saved list.

The Hub worker supplies its trusted `execution.worker_path_mappings`
snapshot to MATLAB. MATLAB resolves stored project sources through the client
mapping to a canonical path, then through the worker mapping to its execution
path. It translates `omeZarrPath`, `srcpath`, `ndtiffPath`, `tiffSource` and
frame-list folders together. Windows workers may save UNC paths; clients
resolve those back to their preferred drive on the next load.

Regression coverage:

```matlab
detecdiv_setup_path(pwd);
assertSuccess(runtests('structure/io/tests/testWindowsSharedPathAliases.m'));
pipelinePathMappingSmokeTest();
```

This change requires the updated DetecDiv helpers on MATLAB clients and
compute hosts, and the updated Hub pipeline executor for the worker mapping
snapshot. Reopen the project after updating a client. A running worker job
must finish before its code or service is updated.
