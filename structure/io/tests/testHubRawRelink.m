function tests = testHubRawRelink
tests = functiontests(localfunctions);
end

function setupOnce(tc)
root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
tc.TestData.oldPath = path;
addpath(root, fullfile(root,'helpers'), fullfile(root,'structure','classes'));
end

function teardownOnce(tc)
path(tc.TestData.oldPath);
end

function testLinkedMovedDatasetUsesClientMapping(tc)
[p,hub,detail,folder] = fixture();
cleanup = onCleanup(@()rmdir(folder,'s')); %#ok<NASGU>
[p,report] = detecdiv_hub_relink_raw_project(p,hub,detail);
target = fullfile(folder,'moved','experiment','Pos0');
verifyEqual(tc,p.fov.srcpath,{target,target});
verifyEqual(tc,p.fov.srclist{1}.folder,target);
verifyEqual(tc,report.changedCount,3);
verifyEmpty(tc,report.unresolved);
verifyEqual(tc,p.runProfiles.hub.raw_path_resolution,report);
end

function testMissingAndUnrelatedDatasetStayUnchanged(tc)
[p,hub,detail,folder] = fixture();
cleanup = onCleanup(@()rmdir(folder,'s')); %#ok<NASGU>
p.fov.srcpath = {'/old/another/Pos0'}; p.fov.srclist = {};
[p,report] = detecdiv_hub_relink_raw_project(p,hub,detail);
verifyEqual(tc,p.fov.srcpath,{'/old/another/Pos0'});
verifyEqual(tc,report.changedCount,0);
verifyEqual(tc,report.unresolved,{'/old/another/Pos0'});
end

function testAmbiguousLocationsAreNotGuessed(tc)
[p,hub,detail,folder] = fixture();
cleanup = onCleanup(@()rmdir(folder,'s')); %#ok<NASGU>
mkdir(fullfile(folder,'second','experiment','Pos0'));
detail.raw_datasets.locations(1).is_preferred = false;
detail.raw_datasets.locations(2) = detail.raw_datasets.locations(1);
detail.raw_datasets.locations(2).relative_path = 'second/experiment';
before = p.fov.srcpath;
[p,report] = detecdiv_hub_relink_raw_project(p,hub,detail);
verifyEqual(tc,p.fov.srcpath,before);
verifyEqual(tc,report.changedCount,0);
verifyNotEmpty(tc,report.unresolved);
end

function testPreferredReplicaAndFilePointers(tc)
[p,hub,detail,folder] = fixture();
cleanup = onCleanup(@()rmdir(folder,'s')); %#ok<NASGU>
target = fullfile(folder,'moved','experiment','stack.tif');
fid=fopen(target,'w'); fclose(fid);
p.fov.srcpath = {'/old/experiment'};
p.fov.isMultiTiff = true;
p.fov.tiffSource = {'/old/experiment/stack.tif'};
mkdir(fullfile(folder,'second','experiment'));
fid=fopen(fullfile(folder,'second','experiment','stack.tif'),'w'); fclose(fid);
detail.raw_datasets.locations(2) = detail.raw_datasets.locations(1);
detail.raw_datasets.locations(2).is_preferred = false;
detail.raw_datasets.locations(2).relative_path = 'second/experiment';
[p,report] = detecdiv_hub_relink_raw_project(p,hub,detail);
verifyEqual(tc,p.fov.tiffSource,{target});
verifyGreaterThan(tc,report.changedCount,0);
end

function testValidPathsNeverMove(tc)
[p,hub,detail,folder] = fixture();
cleanup = onCleanup(@()rmdir(folder,'s')); %#ok<NASGU>
p.fov.srcpath = {folder}; p.fov.srclist = {};
[p,report] = detecdiv_hub_relink_raw_project(p,hub,detail);
verifyEqual(tc,p.fov.srcpath,{folder});
verifyEqual(tc,report.changedCount,0);
end

function testStaleCatalogAndOfflineHubDoNotBreakLoading(tc)
[p,hub,detail,folder] = fixture();
cleanup = onCleanup(@()rmdir(folder,'s')); %#ok<NASGU>
detail.raw_datasets.locations.relative_path = 'missing/experiment';
before = p.fov.srcpath;
[p,report] = detecdiv_hub_relink_raw_project(p,hub,detail);
verifyEqual(tc,p.fov.srcpath,before);
verifyNotEmpty(tc,report.unresolved);
p.runProfiles.hub.hub_project_id = 'offline-test';
[p,report] = detecdiv_hub_relink_raw_project(p,hub);
verifyEqual(tc,p.fov.srcpath,before);
verifyNotEmpty(tc,report.message);
end

function [p,hub,detail,folder] = fixture()
folder=tempname; mkdir(fullfile(folder,'moved','experiment','Pos0'));
p=shallow(); p.fov.srcpath={'/old/experiment/Pos0','/old/experiment/Pos0'};
p.fov.srclist={struct('folder','/old/experiment/Pos0','name','frame.tif')};
hub=struct('baseUrl','http://127.0.0.1:1','timeout',1,'fallbackBaseUrls',{{}}, ...
    'pathMappings',struct('remoteRoot','/hub-store','localRoot',folder));
loc=struct('relative_path','moved/experiment','is_preferred',true, ...
    'storage_root',struct('path_prefix','/hub-store','name','test'));
detail=struct('raw_datasets',struct('id','test-raw','acquisition_label','experiment','locations',loc));
end
