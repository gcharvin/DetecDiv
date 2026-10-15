# Local FOV extraction pool

Local `pipeline2` runs use a MATLAB `batch` job. When the selected pipeline
contains parallel `roiExtract` work on multiple FOVs, the local submitter now
reserves a pool with `batch(..., 'Pool', N)` before starting the job. Extraction
reuses that pool; it does not create or delete the batch-owned pool.

Admission is bounded by the selected FOV count, ten pool workers, the local
CPU/thread ceiling minus one coordinator slot, the cluster's worker capacity
minus the coordinator, and available physical RAM. RAM keeps the existing 20%
safety reserve, excludes swap, and reserves a MATLAB coordinator baseline in
addition to each FOV's estimated process, raw-block and drift footprint. An
unknown footprint or fewer than two admitted workers uses sequential extraction.
The pool remains reserved for the lifetime of the batch job.

When a selected dataloader imports new movies, planning probes its raw metadata
on a separate memory-only project before submission. The user's project and
its ROI definitions are not modified by this probe.

Sequential extraction settings, a single selected FOV, and runs without a
selected ROI extraction node reserve no pool. `PoolSize` is an optional local
upper bound; omit it for automatic sizing or use zero to disable the pool.

The run directory contains `local_pool_plan.json`. The worker console records
the actual available pool, and the saved run context records both planned and
actual worker counts under `execution.localFovPool`.

This policy belongs only to `detecdiv_local_submit_pipeline_run`. Hub/server
jobs do not use the local planner or its metadata and retain their existing
allocation and extraction-pool policy.

After updating DetecDiv on the `unstable` branch, close and reopen pipeline2
and create a new local run. No DetecDiv-plugins update is required for this fix.
