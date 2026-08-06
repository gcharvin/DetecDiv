function tests = testScoreMaskEditing
%TESTSCOREMASKEDITING Unit tests for mask editing primitives.
tests = functiontests(localfunctions);
end

function setupOnce(~)
repoRoot = fileparts(fileparts(fileparts(fileparts(fileparts( ...
    mfilename('fullpath'))))));
addpath(repoRoot);
startup;
end

function testDisconnectedPiecesSplitBeforeWatershed(testCase)
mask = zeros(12, 12, 'uint16');
mask(2:6, 2:6) = 5;
mask(9:10, 9:10) = 5;

[result, report] = score_splitMaskObject(mask, 5, ...
    'UsedLabels', [1 2 3 4 5 7]);

verifyEqual(testCase, report.status, 'split');
verifyEqual(testCase, report.method, 'connected_components');
verifyEqual(testCase, report.componentCount, 2);
verifyEqual(testCase, report.newLabels, 6);
verifyTrue(testCase, all(result(2:6, 2:6) == 5, 'all'));
verifyTrue(testCase, all(result(9:10, 9:10) == 6, 'all'));
end

function testCompactObjectDoesNotSplit(testCase)
mask = zeros(12, 12, 'uint16');
mask(3:9, 3:9) = 4;

[result, report] = score_splitMaskObject(mask, 4);

verifyEqual(testCase, report.status, 'unchanged');
verifyEqual(testCase, result, mask);
end
