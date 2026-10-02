function tests = testHubProjectResumeRefresh
tests = functiontests(localfunctions);
end

function testJsonInventoryReplacesStaleMatAndWorkspace(testCase)
root = tempname;
mkdir(root);
cleanup = onCleanup(@()rmdir(root, 's')); %#ok<NASGU>
shallowObj = shallow();
shallowObj.setPath([root filesep], 'hub_refresh_test');
shallowObj.fov = fov();
shallowObj.fov(1).id = 'Pos0';
matPath = fullfile(root, 'hub_refresh_test.mat');
save(matPath, 'shallowObj');
shallowObj.fov(2) = fov();
shallowObj.fov(2).id = 'Pos11';
shallowObj.fov(3) = fov();
shallowObj.fov(3).id = 'Pos15';
shallowProjectExportLight(shallowObj);
stale = load(matPath, 'shallowObj');
assignin('base', 'hubRefreshStaleProject', stale.shallowObj);
workspaceCleanup = onCleanup(@()evalin('base', 'clear hubRefreshStaleProject')); %#ok<NASGU>
[fresh, ~, info] = detecdiv_hub_resume_project_editing(stale.shallowObj);
verifyTrue(testCase, info.reloaded);
verifyEqual(testCase, {fresh.fov.id}, {'Pos0', 'Pos11', 'Pos15'});
verifyEqual(testCase, numel(stale.shallowObj.fov), 1);
end

function testLegacyMatStillReloads(testCase)
root = tempname;
mkdir(root);
cleanup = onCleanup(@()rmdir(root, 's')); %#ok<NASGU>
shallowObj = shallow();
shallowObj.setPath([root filesep], 'hub_refresh_legacy');
shallowObj.fov(1).id = 'Legacy';
save(fullfile(root, 'hub_refresh_legacy.mat'), 'shallowObj');
[fresh, ~, info] = detecdiv_hub_resume_project_editing(shallowObj);
verifyTrue(testCase, info.reloaded);
verifyEqual(testCase, fresh.fov(1).id, 'Legacy');
end
