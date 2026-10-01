function tests = testShallowAddDataPlaceholder
tests = functiontests(localfunctions);
end

function testFirstImportReusesDefaultFov(t)
project = shallow();
parsed = parsedPosition();
verifyEqual(t, project.addData(parsed), 1);
verifyEqual(t, numel(project.fov), 1);
verifyEqual(t, project.fov.id, 'Pos0_1');
verifyEqual(t, project.addData(parsed), 1);
verifyEqual(t, numel(project.fov), 1);
end

function testExistingAnnotationsArePreserved(t)
project = shallow();
project.fov.roi = roi('manual_roi', [1 2 10 20]);
verifyEqual(t, project.addData(parsedPosition()), 2);
verifyEqual(t, project.fov(1).roi.id, 'manual_roi');
verifyEqual(t, project.fov(1).roi.value, [1 2 10 20]);
end

function testLegacyEmptySourceCellIsReused(t)
project = shallow();
project.fov.srcpath = {};
verifyEqual(t, project.addData(parsedPosition()), 1);
verifyEqual(t, numel(project.fov), 1);
end

function testProjectsHaveIndependentPlaceholderFovs(t)
first = shallow();
second = shallow();
first.fov.id = 'first_project_only';
verifyEmpty(t, second.fov.id);
end

function parsed = parsedPosition()
position = struct('name', 'Pos0', 'pathlist', {{fullfile(tempdir, 'fov_source_test')}}, ...
    'filelist', {{struct('name', 'frame.tif')}}, 'channelname', {{'phase'}}, ...
    'binning', 1, 'frames', 1, 'interval', 1);
parsed = struct('pos', position);
end
