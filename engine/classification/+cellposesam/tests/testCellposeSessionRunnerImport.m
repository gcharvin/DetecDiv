function tests = testCellposeSessionRunnerImport
tests = functiontests(localfunctions);
end

function testLoadsExactFileAndKeepsCallable(testCase)
testDir = fileparts(mfilename('fullpath'));
runnerPath = fullfile(testDir, 'fixtures', 'session_runner_fixture.py');

[runnerModule, runnerCallable, resolvedPath] = ...
    cellposesam.utils.loadRunnerModule(runnerPath);

verifyEqual(testCase, localNormalizePath(resolvedPath), ...
    localNormalizePath(runnerPath));
verifyTrue(testCase, logical(py.hasattr(runnerModule, 'run')));
verifyEqual(testCase, char(string(runnerCallable('first'))), 'first:1');
verifyEqual(testCase, char(string(runnerCallable('second'))), 'second:2');
end

function out = localNormalizePath(value)
out = regexprep(strrep(char(string(value)), '\', '/'), '/+', '/');
if ispc
    out = lower(out);
end
end
