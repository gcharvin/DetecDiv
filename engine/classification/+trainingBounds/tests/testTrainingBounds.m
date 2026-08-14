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
