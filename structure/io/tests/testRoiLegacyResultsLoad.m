function tests = testRoiLegacyResultsLoad
tests = functiontests(localfunctions);
end

function setupOnce(~)
root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(genpath(root));
end

function testDataLoadRestoresResultsWithoutDataseries(testCase)
[r, cleanup] = fixture(); %#ok<ASGLU>
results = struct('div_1', struct('id', [1 2 3], 'prob', [0.9 NaN 0.1]));
save(fullfile(r.path, 'results_legacy.mat'), 'results');
r.load('data');
verifyEqual(testCase, r.results, results);
verifyEmpty(testCase, r.data);
end

function testMissingSidecarPreservesResults(testCase)
[r, cleanup] = fixture(); %#ok<ASGLU>
r.results = struct('existing', 42);
r.load('data');
verifyEqual(testCase, r.results, struct('existing', 42));
end

function testMalformedSidecarDoesNotSilentlySucceed(testCase)
[r, cleanup] = fixture(); %#ok<ASGLU>
results = 42; %#ok<NASGU>
save(fullfile(r.path, 'results_legacy.mat'), 'results');
verifyError(testCase, @() r.load('data'), 'loadROI:InvalidLegacyResults');
end

function [r, cleanup] = fixture()
root = tempname; mkdir(root);
cleanup = onCleanup(@() removeFixture(root));
r = roi('legacy', [1 1 2 2]); r.path = root;
end

function removeFixture(root)
assert(startsWith(root, tempdir, 'IgnoreCase', true));
if isfolder(root), rmdir(root, 's'); end
end
