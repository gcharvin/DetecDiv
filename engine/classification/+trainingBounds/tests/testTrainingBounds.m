function tests = testTrainingBounds
tests = functiontests(localfunctions);
end

function testDefaultIsAll(testCase)
[c, cleanup] = classifierFixture(); %#ok<ASGLU>
[bounds, info] = trainingBounds.resolve(c, 1, 'FrameCount', 5);
verifyEmpty(testCase, bounds);
verifyEqual(testCase, info.text, 'all');
verifyEqual(testCase, trainingBounds.frames(c,1,5,[]), 1:5);
end

function testPerRoiBoundsAndRunSelectionAreIntersected(testCase)
[c, cleanup] = classifierFixture(); %#ok<ASGLU>
trainingBounds.setRoi(c,1,'2:4','FrameCount',5);

verifyEqual(testCase, trainingBounds.resolve(c,1), [2 4]);
verifyEmpty(testCase, trainingBounds.resolve(c,2));
verifyEqual(testCase, trainingBounds.frames(c,1,5,3:5), 3:4);
verifyEqual(testCase, trainingBounds.frames(c,2,6,3:5), 3:5);

spec = trainingBounds.selectionSpec(c,3:5);
verifyEqual(testCase, spec.roi1, 3:4);
verifyEqual(testCase, spec.roi2, 3:5);
end

function testAllClearsOnlySelectedRoi(testCase)
[c, cleanup] = classifierFixture(); %#ok<ASGLU>
trainingBounds.setRoi(c,1,[2 4]);
trainingBounds.setRoi(c,2,[3 5]);
trainingBounds.setRoi(c,1,'all');

verifyEmpty(testCase, trainingBounds.resolve(c,1));
verifyEqual(testCase, trainingBounds.resolve(c,2), [3 5]);
verifyEqual(testCase, trainingBounds.text([]), 'all');
end

function testRoiIdKeepsBoundsStableAfterReorder(testCase)
[c, cleanup] = classifierFixture(); %#ok<ASGLU>
trainingBounds.setRoi(c,1,[2 4]);
c.roi = c.roi([2 1]);

verifyEmpty(testCase, trainingBounds.resolve(c,1));
verifyEqual(testCase, trainingBounds.resolve(c,2), [2 4]);
trainingBounds.setRoi(c,1,[1 2]);
verifyEqual(testCase, trainingBounds.resolve(c,1), [1 2]);
verifyEqual(testCase, trainingBounds.resolve(c,2), [2 4]);
end

function testGlobalModeRemainsSupported(testCase)
[c, cleanup] = classifierFixture(); %#ok<ASGLU>
c.bounds.Type = 'Auto';
c.bounds.Values = [2 3];

verifyEqual(testCase, trainingBounds.resolve(c,1), [2 3]);
verifyEqual(testCase, trainingBounds.frames(c,2,6,[]), 2:3);
end

function testInvalidRangeIsRejected(testCase)
verifyError(testCase, @()trainingBounds.parse('2:9','FrameCount',5), ...
    'trainingBounds:OutOfRange');
verifyError(testCase, @()trainingBounds.parse('2'), ...
    'trainingBounds:InvalidText');
end

function testBulkRangeClipsEachRoiAndPreservesPersistentSelection(testCase)
[c, cleanup] = classifierFixture(); %#ok<ASGLU>
report = trainingBounds.apply(c, [1 2], 'range', 'Bounds', [2 6]);

verifyEqual(testCase, report.count, 2);
verifyEqual(testCase, trainingBounds.resolve(c,1), [2 5]);
verifyEqual(testCase, trainingBounds.resolve(c,2), [2 6]);
spec = trainingBounds.selectionSpec(c, []);
verifyEqual(testCase, spec.roi1, 2:5);
verifyEqual(testCase, spec.roi2, 2:6);
end

function testBulkAllClearsOnlyTargetedRois(testCase)
[c, cleanup] = classifierFixture(); %#ok<ASGLU>
trainingBounds.apply(c, [1 2], 'range', 'Bounds', [2 4]);
trainingBounds.apply(c, 1, 'all');

verifyEmpty(testCase, trainingBounds.resolve(c,1));
verifyEqual(testCase, trainingBounds.resolve(c,2), [2 4]);
end

function testBulkEditMaterializesLegacyGlobalBounds(testCase)
[c, cleanup] = classifierFixture(); %#ok<ASGLU>
c.bounds.Type = 'Auto';
c.bounds.Values = [2 4];

trainingBounds.apply(c, 1, 'all');

verifyEmpty(testCase, trainingBounds.resolve(c,1));
verifyEqual(testCase, trainingBounds.resolve(c,2), [2 4], ...
    'Changing one ROI must preserve the old global bound on other ROIs.');
verifyEqual(testCase, c.bounds.Type, 'Manual');
verifyEmpty(testCase, c.bounds.Values);
end

function testBulkRangeRejectsRoiBeforeStart(testCase)
[c, cleanup] = classifierFixture(); %#ok<ASGLU>
verifyError(testCase, @()trainingBounds.apply( ...
    c, [1 2], 'range', 'Bounds', [6 8]), ...
    'trainingBounds:RangeStartsAfterRoi');
verifyEmpty(testCase, trainingBounds.resolve(c,1));
verifyEmpty(testCase, trainingBounds.resolve(c,2));
end

function [c, cleanup] = classifierFixture()
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@()removeFolder(folder));
c = classi(folder,'bounds_test',1);
r1 = roi('R1',[1 1 4 4]);
r1.image = zeros(4,4,1,5,'uint16');
r2 = roi('R2',[1 1 4 4]);
r2.image = zeros(4,4,1,6,'uint16');
c.roi = [r1 r2];
end

function removeFolder(folder)
if isfolder(folder), rmdir(folder,'s'); end
end
