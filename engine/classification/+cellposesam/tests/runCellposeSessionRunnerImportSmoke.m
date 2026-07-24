function runCellposeSessionRunnerImportSmoke
% runCellposeSessionRunnerImportSmoke  Batch entry point for worker QA.
testDir = fileparts(mfilename('fullpath'));
classificationDir = fileparts(fileparts(testDir));
addpath(classificationDir);
results = runtests(fullfile(testDir, 'testCellposeSessionRunnerImport.m'));
assertSuccess(results);
end
