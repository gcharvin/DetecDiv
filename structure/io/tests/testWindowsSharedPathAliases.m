function tests = testWindowsSharedPathAliases
tests = functiontests(localfunctions);
end

function testDriveAliasComesFromTheOsSnapshot(testCase)
mapping = struct('localRoot', 'Z:\Abhilasha', 'remoteRoot', '/alias_test/Abhilasha');
drives = struct('driveRoot', 'Z:\', 'uncRoot', '\\test-storage\DATA');
expanded = detecdiv_paths_expand_windows_aliases(mapping, drives);
verifyEqual(testCase, expanded(1), mapping);
verifyEqual(testCase, expanded(2).localRoot, '\\test-storage\DATA\Abhilasha');
verifyEqual(testCase, expanded(2).remoteRoot, '/alias_test/Abhilasha');
verifyEqual(testCase, detecdiv_paths_expand_windows_aliases(mapping, ...
    struct('driveRoot', 'Y:\', 'uncRoot', '\\other-storage\DATA')), mapping);
end

function testUncAliasesRespectShareBoundaries(testCase)
drives = struct('driveRoot', 'R:\', 'uncRoot', '\\test-storage\DATA');
mapping = struct('localRoot', '//TEST-STORAGE/data', 'remoteRoot', '/alias_test');
expanded = detecdiv_paths_expand_windows_aliases(mapping, drives);
verifyEqual(testCase, expanded(2).localRoot, 'R:\');
mapping.localRoot = '//test-storage/DATABASE';
verifyEqual(testCase, detecdiv_paths_expand_windows_aliases(mapping, drives), mapping);
end

function testRecordedRunDoesNotInferAliasesFromThisWorkstation(testCase)
drives = detecdiv_paths_windows_drive_mappings();
assumeTrue(testCase, ~isempty(drives), 'Requires a mapped Windows network drive.');
recorded = struct('localRoot', drives(1).driveRoot, 'remoteRoot', '/foreign_client_alias_test');
ctx.run.paths.path_mappings = recorded;
mappings = detecdiv_paths_module_mappings(ctx);
foreign = mappings(strcmp({mappings.remoteRoot}, recorded.remoteRoot));
verifyEqual(testCase, numel(foreign), 1);
verifyEqual(testCase, foreign.localRoot, recorded.localRoot);
end

function testUncAndDriveSubmitTheSameServerPath(testCase)
hub = aliasSettings('R:\', '\\test-storage\DATA', '/alias_test');
ctx = struct('hub', hub);
[drivePath, driveMapped] = detecdiv_paths_map_module_path('R:\Abhilasha\Sample.ome.zarr', ctx, 'server');
[uncPath, uncMapped] = detecdiv_paths_map_module_path('\\TEST-STORAGE\data\Abhilasha\Sample.ome.zarr', ctx, 'server');
verifyTrue(testCase, driveMapped && uncMapped);
verifyEqual(testCase, drivePath, '/alias_test/Abhilasha/Sample.ome.zarr');
verifyEqual(testCase, uncPath, drivePath);
payload.paths.server_raw_data_path = uncPath;
payload.paths.path_mappings = detecdiv_paths_run_payload_mappings(ctx);
detecdiv_paths_assert_hub_payload_safe(payload, 'run_request');
end

function testPreferredClientRootWinsOverOldUncEntry(testCase)
hub = aliasSettings('R:\', '\\test-storage\DATA', '/alias_test');
% Persisted worker/previous-client entry appears first in the explicit list.
hub.pathMappings = fliplr(hub.pathMappings);
[path, method] = detecdiv_hub_apply_path_mapping('\\test-storage\DATA\Abhilasha\Sample.ome.zarr', hub);
verifyEqual(testCase, path, 'R:\Abhilasha\Sample.ome.zarr');
verifyNotEmpty(testCase, method);
[root, mapped] = detecdiv_paths_map_module_path('/alias_test', struct('hub', hub), 'local');
verifyTrue(testCase, mapped);
verifyEqual(testCase, root, 'R:\');
end

function testOtherSharesAndPrefixLookalikesRemainUnmapped(testCase)
hub = aliasSettings('R:\', '\\test-storage\DATA', '/alias_test');
for path = {'\\other-storage\DATA\Sample.ome.zarr', '\\test-storage\DATABASE\Sample.ome.zarr'}
    [result, mapped] = detecdiv_paths_map_module_path(path{1}, struct('hub', hub), 'server');
    verifyFalse(testCase, mapped);
    verifyEqual(testCase, result, path{1});
end
end

function testMostSpecificAliasWins(testCase)
hub = aliasSettings('R:\', '\\test-storage\DATA', '/alias_test');
hub.pathMappings(end+1) = struct('localRoot', '\\test-storage\DATA\protected', 'remoteRoot', '/private_alias_test');
[result, mapped] = detecdiv_paths_map_module_path('\\test-storage\DATA\protected\file.mat', struct('hub', hub), 'server');
verifyTrue(testCase, mapped);
verifyEqual(testCase, result, '/private_alias_test/file.mat');
end

function testServerRootCaseIsPreserved(testCase)
hub = aliasSettings('R:\', '\\test-storage\DATA', '/CaseSensitiveAliasTest');
[~, mapped] = detecdiv_paths_map_module_path('/casesensitivealiastest/file.mat', struct('hub', hub), 'local');
verifyFalse(testCase, mapped);
end

function testSavingAnAliasDoesNotDeleteTheDriveMapping(testCase)
hub = struct();
hub = detecdiv_hub_upsert_path_mapping(hub, '/alias_test', 'R:\');
hub = detecdiv_hub_upsert_path_mapping(hub, '/alias_test', '\\test-storage\DATA');
verifyEqual(testCase, numel(hub.pathMappings), 2);
hub = detecdiv_hub_upsert_path_mapping(hub, '/new_alias_test', 'r:/');
verifyEqual(testCase, numel(hub.pathMappings), 2);
verifyEqual(testCase, hub.pathMappings(1).remoteRoot, '/new_alias_test');
end

function testLegacyPrefixMapUsesTheSameResolver(testCase)
hub = struct('pathPrefixMap', struct('data', struct('remotePrefix', '/legacy_alias_test', 'localPrefix', 'R:\')));
[path, method] = detecdiv_hub_apply_path_mapping('/legacy_alias_test/Abhilasha/file.mat', hub);
verifyEqual(testCase, path, 'R:\Abhilasha\file.mat');
verifyNotEmpty(testCase, method);
end

function testExistingProjectSourcesAreRebasedInMemory(testCase)
[root, preferred, foreign, cleanup] = existingViews(); %#ok<ASGLU>
hub = aliasSettings(preferred, foreign, '/fixture_alias_test');
project = shallow();
project.io.path = root;
project.io.file = 'project';
mkdir(fullfile(root, 'project'));
field = fov();
field.id = 'Pos1';
field.isOMEZarr = true;
field.omeZarrPath = fullfile(foreign, 'Sample.ome.zarr');
field.srcpath = {field.omeZarrPath};
field.ndtiffPath = field.omeZarrPath;
field.tiffSource = {fullfile(foreign, 'Sample.ome.zarr', 'zarr.json')};
field.srclist = {struct('folder', field.omeZarrPath, 'name', 'zarr.json')};
field.channel = {'Green'};
field.roi = roi.empty;
project.fov = field;
detecdiv_paths_localize_project(project, hub);
expected = fullfile(preferred, 'Sample.ome.zarr');
verifyEqual(testCase, field.srcpath{1}, expected);
verifyEqual(testCase, field.omeZarrPath, expected);
verifyEqual(testCase, field.ndtiffPath, expected);
verifyEqual(testCase, field.srclist{1}.folder, expected);
verifyEqual(testCase, field.tiffSource{1}, fullfile(expected, 'zarr.json'));
end

function testJsonImportRebasesEvenWhenTheOldSourceExists(testCase)
[root, preferred, foreign, cleanup] = existingViews(); %#ok<ASGLU>
hub = aliasSettings(preferred, foreign, '/fixture_alias_test');
project = shallow();
project.io.path = root;
project.io.file = 'project';
mkdir(fullfile(root, 'project'));
field = fov();
field.id = 'Pos1';
field.isOMEZarr = true;
field.omeZarrPath = fullfile(foreign, 'Sample.ome.zarr');
field.srcpath = {field.omeZarrPath};
field.channel = {'Green'};
field.frames = 1;
field.roi = roi.empty;
project.fov = field;
jsonFile = fullfile(root, 'project.json');
shallowProjectExportLight(project, jsonFile);
before = fileread(jsonFile);
loaded = shallowLoad(jsonFile, 'HubPathSettings', hub);
verifyEqual(testCase, loaded.fov(1).omeZarrPath, fullfile(preferred, 'Sample.ome.zarr'));
verifyEqual(testCase, loaded.fov(1).srcpath{1}, fullfile(preferred, 'Sample.ome.zarr'));
verifyEqual(testCase, fileread(jsonFile), before, 'Loading must not rewrite a shared project.');
end

function testRunReferencesAreLocalizedWithoutChangingTheExecutionRecord(testCase)
[root, preferred, foreign, cleanup] = existingViews(); %#ok<ASGLU>
hub = aliasSettings(preferred, foreign, '/fixture_alias_test');
run = pipelineRun('', '', 1);
run.pipelineRef.path = fullfile(foreign, 'Sample.ome.zarr');
run.templatePath = run.pipelineRef.path;
run.ctx.workerSource = run.pipelineRef.path;
run.targetRef.projectPath = run.pipelineRef.path;
run.projectPath = run.pipelineRef.path;
detecdiv_paths_localize_run(run, hub);
verifyEqual(testCase, run.pipelineRef.path, fullfile(preferred, 'Sample.ome.zarr'));
verifyEqual(testCase, run.templatePath, run.pipelineRef.path);
verifyEqual(testCase, run.targetRef.projectPath, run.pipelineRef.path);
verifyEqual(testCase, run.ctx.workerSource, fullfile(foreign, 'Sample.ome.zarr'));
end

function hub = aliasSettings(preferred, alias, server)
hub = struct('defaultLocalProjectRoot', preferred, 'defaultRemoteProjectRoot', server, ...
    'pathMappings', [struct('localRoot', preferred, 'remoteRoot', server), ...
        struct('localRoot', alias, 'remoteRoot', server)]);
end

function testWorkerResolvesAllOmeZarrPointersToItsOwnRoot(testCase)
hub = aliasSettings('R:\', '\\test-storage\DATA', '/alias_test');
clientMappings = hub.pathMappings;
workerRoot = fullfile(tempname, 'worker_mount');
payload = struct('run_request', struct('paths', struct('path_mappings', clientMappings)), ...
    'execution', struct('worker_path_mappings', struct('source', '/alias_test', 'target', workerRoot)));
field = fov();
field.srcpath = {'R:\Abhilasha\Sample.ome.zarr'};
field.omeZarrPath = '\\test-storage\DATA\Abhilasha\Sample.ome.zarr';
field.srclist = {struct('folder', field.omeZarrPath, 'name', 'omezarr_1_0')};
detecdiv_paths_map_fov_sources(field, @(path)detecdiv_paths_worker_path(path, payload));
expected = fullfile(workerRoot, 'Abhilasha', 'Sample.ome.zarr');
verifyEqual(testCase, field.srcpath{1}, expected);
verifyEqual(testCase, field.omeZarrPath, expected);
verifyEqual(testCase, field.srclist{1}.folder, expected);
verifyEqual(testCase, payload.run_request.paths.path_mappings, clientMappings);
end

function testWorkerMappingsWorkWithoutAnyClientMapping(testCase)
workerRoot = fullfile(tempname, 'worker_mount');
payload.execution.worker_path_mappings = struct('source', '/alias_test', 'target', workerRoot);
verifyEqual(testCase, detecdiv_paths_worker_path('/alias_test/Abhilasha/file.mat', payload), ...
    fullfile(workerRoot, 'Abhilasha', 'file.mat'));
end

function [root, preferred, foreign, cleanup] = existingViews()
root = tempname;
mkdir(root);
cleanup = onCleanup(@() rmdir(root, 's'));
preferred = fullfile(root, 'preferred');
foreign = fullfile(root, 'previous_view');
for folder = {preferred, foreign}
    dataset = fullfile(folder{1}, 'Sample.ome.zarr');
    mkdir(dataset);
    fid = fopen(fullfile(dataset, 'zarr.json'), 'w');
    fprintf(fid, '%s', '{"zarr_format":3,"node_type":"group","attributes":{}}');
    fclose(fid);
end
end
