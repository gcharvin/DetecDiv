function runCellposeProductionRunnerImportSmoke
% runCellposeProductionRunnerImportSmoke  Import a configured real runner.
classificationDir = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(classificationDir);
runnerPath = getenv('DETECDIV_CELLPOSERUNNER_PATH');
assert(~isempty(runnerPath), ...
    'DETECDIV_CELLPOSERUNNER_PATH must point to cellposesam_runner.py.');
[runnerModule, runnerCallable, resolvedPath] = ...
    cellposesam.utils.loadRunnerModule(runnerPath);
assert(logical(py.hasattr(runnerModule, 'run')), ...
    'Loaded CellposeSAM runner has no run() entry point.');
assert(~isempty(runnerCallable), ...
    'CellposeSAM run() callable was not resolved.');
fprintf('CellposeSAM session runner import OK: %s\n', resolvedPath);
end
