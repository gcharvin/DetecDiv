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

moduleName = char(string(py.getattr(runnerModule, '__name__')));
pySys = py.importlib.import_module('sys');
moduleRegistry = py.getattr(pySys, 'modules');
getModule = py.getattr(moduleRegistry, 'get');
registeredModule = getModule(moduleName, py.None);
operatorModule = py.importlib.import_module('operator');
isSameObject = py.getattr(operatorModule, 'is_');
verifyTrue(testCase, logical(isSameObject(registeredModule, runnerModule)), ...
    'The runner must remain registered in sys.modules for its session lifetime.');
end

function out = localNormalizePath(value)
out = regexprep(strrep(char(string(value)), '\', '/'), '/+', '/');
if ispc
    out = lower(out);
end
end
