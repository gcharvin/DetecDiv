function tests = testShallowProjectInventory
tests = functiontests(localfunctions);
end

function testInventoryKeepsFovAndRoiDetailsOutsideRoot(testCase)
root = tempname;
mkdir(root);
cleanup = onCleanup(@() rmdir(root, 's')); %#ok<NASGU>

name = 'inventory_project';
projectDir = fullfile(root, name);
mkdir(projectDir);
projectObj = shallow();
projectObj.io.path = root;
projectObj.io.file = name;
projectObj.runProfiles.dataloading.dataLoader = struct('path', 'raw_data');

field = fov();
field.id = 'Pos1_1';
field.srcpath = {'raw_data'};
field.roi = roi.empty;
first = roi('Pos1_1_1', [10 20 30 40]);
first.path = fullfile(projectDir, 'wrong_folder');
first.display.frame = 7;
field.roi(1) = first;
field.roi(2) = roi('Pos1_1_2', [50 60 30 40]);
projectObj.fov = field;

jsonPath = fullfile(root, [name '.json']);
shallowProjectExportLight(projectObj, jsonPath);
manifest = jsondecode(fileread(jsonPath));

verifyEqual(testCase, manifest.schemaVersion, 3);
verifyEqual(testCase, manifest.fovs.roiCount, 2);
verifyFalse(testCase, isfield(manifest.fovs, 'rois'));
verifyFalse(testCase, isfield(manifest, 'runProfiles'));
verifyEqual(testCase, manifest.fovs.metadataPath, 'project_metadata/fov_00001.json');
verifyEqual(testCase, manifest.runProfilesPath, 'project_metadata/run_profiles.json');
verifyTrue(testCase, isfile(fullfile(projectDir, manifest.fovs.metadataPath)));
verifyTrue(testCase, isfile(fullfile(projectDir, manifest.runProfilesPath)));
repairAudit = shallowRepairRoiManifestPaths(jsonPath);
verifyEqual(testCase, repairAudit.roiCount, 2);

loaded = shallowProjectImportLight(jsonPath);
verifyEqual(testCase, numel(loaded.fov), 1);
verifyEqual(testCase, numel(loaded.fov(1).roi), 2);
verifyEqual(testCase, loaded.fov(1).roi(1).value, [10 20 30 40]);
verifyEqual(testCase, loaded.fov(1).roi(1).display.frame, 7);
verifyEqual(testCase, loaded.runProfiles.dataloading.dataLoader.path, 'raw_data');

fovDir = fullfile(projectDir, field.id);
mkdir(fovDir);
h5Path = fullfile(fovDir, 'im_Pos1_1_1.h5');
fid = fopen(h5Path, 'w');
fclose(fid);
repair = shallowRepairRoiManifestPaths(jsonPath, 'Apply', true);
verifyEqual(testCase, repair.changedCount, 1);
verifyTrue(testCase, isfile(repair.backupPath));
metadata = jsondecode(fileread(fullfile(projectDir, manifest.fovs.metadataPath)));
verifyEqual(testCase, metadata.rois(1).path, field.id);
end

function testImportAcceptsWindowsSeparatorsInExistingManifest(testCase)
root = tempname;
mkdir(root);
cleanup = onCleanup(@() rmdir(root, 's')); %#ok<NASGU>

name = 'windows_manifest_project';
projectDir = fullfile(root, name);
mkdir(projectDir);
projectObj = shallow();
projectObj.io.path = root;
projectObj.io.file = name;
field = fov();
field.id = 'Pos1_1';
field.roi = roi.empty;
projectObj.fov = field;

jsonPath = fullfile(root, [name '.json']);
shallowProjectExportLight(projectObj, jsonPath);
manifest = jsondecode(fileread(jsonPath));
manifest.runProfilesPath = strrep(manifest.runProfilesPath, '/', '\');
manifest.fovs(1).metadataPath = strrep(manifest.fovs(1).metadataPath, '/', '\');
fid = fopen(jsonPath, 'w');
verifyGreaterThan(testCase, fid, 0);
fprintf(fid, '%s\n', jsonencode(manifest));
fclose(fid);

loaded = shallowProjectImportLight(jsonPath);
verifyEqual(testCase, numel(loaded.fov), 1);
verifyEqual(testCase, loaded.fov(1).id, 'Pos1_1');
end

function testLegacyManifestRecoversOmeZarrFieldsWhenSourcePathExists(testCase)
root = tempname;
mkdir(root);
cleanup = onCleanup(@() rmdir(root, 's')); %#ok<NASGU>

name = 'legacy_omezarr_project';
projectDir = fullfile(root, name);
mkdir(projectDir);
projectObj = shallow();
projectObj.io.path = root;
projectObj.io.file = name;
field = fov();
field.id = 'Pos1_1';
field.srcpath = {'/data/sample.ome.zarr'};
field.channel = {'Green'};
field.frames = 1;
field.isOMEZarr = true;
field.omeZarrPath = '/data/sample.ome.zarr';
field.omeZarrSeries = '0';
field.omeZarrArrayPath = '0';
field.omeZarrShape = [1 1 64 64];
field.omeZarrChunkShape = [1 1 64 64];
field.omeZarrDtype = 'uint16';
field.omeZarrDimensionNames = {'t','c','y','x'};
field.omeZarrChannelIndices = 0;
field.omeZarrZIndices = 0;
field.roi = roi.empty;
projectObj.fov = field;

jsonPath = fullfile(root, [name '.json']);
shallowProjectExportLight(projectObj, jsonPath);
manifest = jsondecode(fileread(jsonPath));
sidecarPath = fullfile(projectDir, manifest.fovs.metadataPath);
sidecar = jsondecode(fileread(sidecarPath));

% Recreate the legacy v2 inline record: srcpath survived, while the OME-Zarr
% metadata became empty in the root manifest and remained in the sidecar.
sidecar.raw.isOMEZarr = true;
sidecar.raw.omeZarrPath = '/data/sample.ome.zarr';
sidecar.raw.omeZarrSeries = '0';
sidecar.raw.omeZarrArrayPath = '0';
sidecar.raw.omeZarrShape = [1 1 64 64];
sidecar.raw.omeZarrChunkShape = [1 1 64 64];
sidecar.raw.omeZarrDtype = 'uint16';
sidecar.raw.omeZarrDimensionNames = {'t','c','y','x'};
sidecar.raw.omeZarrChannelIndices = 0;
sidecar.raw.omeZarrZIndices = 0;
fid = fopen(sidecarPath, 'w');
verifyGreaterThan(testCase, fid, 0);
fprintf(fid, '%s\n', jsonencode(sidecar));
fclose(fid);

legacyFov = sidecar;
legacyFov.raw.isOMEZarr = false;
legacyFov.raw.omeZarrPath = '';
legacyFov.raw.omeZarrSeries = '';
legacyFov.raw.omeZarrArrayPath = '';
legacyFov.raw.omeZarrShape = [];
legacyFov.raw.omeZarrChunkShape = [];
legacyFov.raw.omeZarrDtype = '';
legacyFov.raw.omeZarrDimensionNames = {};
legacyFov.raw.omeZarrChannelIndices = [];
legacyFov.raw.omeZarrZIndices = [];
legacyFov.srcpath = {'/data/sample.ome.zarr'};
legacyFov = rmfield(legacyFov, intersect(fieldnames(legacyFov), {'metadataPath','roiCount'}));
manifest.schemaVersion = 2;
manifest.fovs = legacyFov;
fid = fopen(jsonPath, 'w');
verifyGreaterThan(testCase, fid, 0);
fprintf(fid, '%s\n', jsonencode(manifest));
fclose(fid);

loaded = shallowProjectImportLight(jsonPath);
verifyEqual(testCase, numel(loaded.fov), 1);
verifyTrue(testCase, loaded.fov(1).isOMEZarr);
verifyEqual(testCase, loaded.fov(1).omeZarrPath, '/data/sample.ome.zarr');
verifyEqual(testCase, loaded.fov(1).omeZarrShape(:), [1; 1; 64; 64]);
verifyEqual(testCase, loaded.fov(1).omeZarrArrayPath, '0');
end
