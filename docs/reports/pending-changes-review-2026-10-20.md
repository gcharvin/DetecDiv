# Pending DetecDiv changes: review, 20 October 2026

Reviewed from `c723441fe4c669f171724205ab59e7ea6ce0b7ee` on `unstable`.
The initial inventory contained 13 modified tracked files and 19 untracked files.
All 32 files were retained and organized by workstream; no previous author is inferred.
Their file hashes remained unchanged throughout review. One existing source
regression test was additionally repaired.

## Commits

| Commit | Workstream |
| --- | --- |
| `58f94f35` | Python/SQLite architecture, Cell-ACDC comparison, napari integration and redirect to the dedicated prototype repository. |
| `243c868b` | Resource-allocation study and cooperative-memory proposal; documentation only. The companion Hub evidence exists. |
| `67f1646a` | Preserve every source channel in ROI resource bindings, including cell/string inventories without a loaded project. |
| `5b2d2d78` | Frame-local mask observations with explicit identities, fingerprints, safe reruns and sidecar persistence. |
| `198c0136` | Shared catalogue UI, selected-package identity, classifier-reference requirements, raw-contract path ownership, synchronized apps and tests. |

The two changes to `validatePipeline.m` were staged separately so the channel
inventory fix is independent from the catalogue/reference workstream. The UI
commit keeps its frontend, policy, validation and tests together.

## Validation

MATLAB 26.1.0.3251617 (R2026a) Update 2 on Windows: **210 distinct tests passed,
zero failed, one skipped**, across 26 suites. Both packed `.mlapp` code payloads
match their editable sources after line-ending normalization.

The first pass exposed a pre-existing stale snapshot-link source test. It expected
the former `pth` variable and `ClassifierSnapshotOnly` option; the current code
already uses `selectedFolder` and `loadClassifierSnapshotStrict`. The test now
checks that path and the strict MAT snapshot loader. All nine tests in that suite
passed on the second pass. Runtime linking code was not changed for old assertions.

The skipped case is
`testPipelineModuleRuntimeIntegration/testWindowsPackageAliasKeepsCanonicalRuntimeIdentity`:
this MATLAB installation does not resolve lowercase aliases for mixed-case
packages. This is an explicit assumption skip, not a passing test.

| Suite | Passed | Failed | Skipped |
| --- | ---: | ---: | ---: |
| [testCellLatentModuleContract](../../engine/classification/+cellLatentModel/tests/testCellLatentModuleContract.m) | 9 | 0 | 0 |
| [testCellLatentModuleRuntime](../../engine/classification/+cellLatentModel/tests/testCellLatentModuleRuntime.m) | 12 | 0 | 0 |
| [testCellposeModuleContract](../../engine/classification/+cellposesam/tests/testCellposeModuleContract.m) | 9 | 0 | 0 |
| [testCellposeModuleRuntime](../../engine/classification/+cellposesam/tests/testCellposeModuleRuntime.m) | 6 | 0 | 0 |
| [testClassifierGUIBindings](../../structure/GUI/classifier/tests/testClassifierGUIBindings.m) | 5 | 0 | 0 |
| [testClassifierTrainingPipelineDefaults](../../structure/io/tests/testClassifierTrainingPipelineDefaults.m) | 18 | 0 | 0 |
| [testDetecdivModuleCatalog](../../helpers/tests/testDetecdivModuleCatalog.m) | 19 | 0 | 0 |
| [testDetecdivModulesBrowser](../../helpers/tests/testDetecdivModulesBrowser.m) | 3 | 0 | 0 |
| [testDetecdivModulesUi](../../helpers/tests/testDetecdivModulesUi.m) | 12 | 0 | 0 |
| [testMaskObservations](../../engine/pipeline/tests/testMaskObservations.m) | 12 | 0 | 0 |
| [testPipeline2ClassifierReferenceUI](../../structure/GUI/tests/testPipeline2ClassifierReferenceUI.m) | 5 | 0 | 0 |
| [testPipeline2CustomModule](../../structure/GUI/tests/testPipeline2CustomModule.m) | 2 | 0 | 0 |
| [testPipeline2ModuleCatalogSource](../../structure/GUI/tests/testPipeline2ModuleCatalogSource.m) | 12 | 0 | 0 |
| [testPipeline2ModuleCatalogueUI](../../structure/GUI/tests/testPipeline2ModuleCatalogueUI.m) | 1 | 0 | 0 |
| [testPipeline2ModuleLibrarySource](../../structure/GUI/tests/testPipeline2ModuleLibrarySource.m) | 9 | 0 | 0 |
| [testPipelineClassifierReferencePolicy](../../structure/io/tests/testPipelineClassifierReferencePolicy.m) | 16 | 0 | 0 |
| [testPipelineExplicitModuleSelection](../../structure/io/tests/testPipelineExplicitModuleSelection.m) | 2 | 0 | 0 |
| [testPipelineImageToRoiTransfer](../../structure/io/tests/testPipelineImageToRoiTransfer.m) | 5 | 0 | 0 |
| [testPipelineModuleCatalogueReadOnly](../../structure/io/tests/testPipelineModuleCatalogueReadOnly.m) | 4 | 0 | 0 |
| [testPipelineModuleRuntime](../../structure/io/tests/testPipelineModuleRuntime.m) | 6 | 0 | 0 |
| [testPipelineModuleRuntimeIntegration](../../structure/io/tests/testPipelineModuleRuntimeIntegration.m) | 6 | 0 | 1 |
| [testPipelinePackageContract](../../structure/io/tests/testPipelinePackageContract.m) | 15 | 0 | 0 |
| [testPipelinePartialRunBindings](../../structure/io/tests/testPipelinePartialRunBindings.m) | 11 | 0 | 0 |
| [testPipelineRestoreClassifierLinksFromRun](../../structure/io/tests/testPipelineRestoreClassifierLinksFromRun.m) | 3 | 0 | 0 |
| [testPipelineRunJobExecutionMode](../../structure/io/tests/testPipelineRunJobExecutionMode.m) | 5 | 0 | 0 |
| [test_plugins_reset_link](../../engine/pipeline/tests/test_plugins_reset_link.m) | 3 | 0 | 0 |

Suites were built with `testsuite(file)` and executed with `run(suite)` after
`detecdiv_setup_path(pwd, 'Verbose', false)`. Later results replace earlier ones
with the same name when counting distinct cases. The final suite exercises a
separate local MATLAB batch process, native Windows worker paths and strict
client preflight. No new Hub job is part of this software review.

Coverage includes read-only browsing/refresh, conflicting packages, explicit
adapter selection, optional/required/broken classifier links, private artifact
paths, pipeline save/load, packed-app callbacks, source-channel transfer,
cell-model persistence and runtime contracts. Synthetic ROIs use temporary
folders. This software regression review adds no biological model validation.

All relative links in the pending Markdown files resolved locally.
`git diff --check` passed. Both remotes initially pointed to the reviewed base.
Publication follows the versioned-release procedure: prepare the final SHA on
both hosts, then publish the Hub default without worker restarts or changing
already submitted jobs. The deployment outcome is checked after publication.
