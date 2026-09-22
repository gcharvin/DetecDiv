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
