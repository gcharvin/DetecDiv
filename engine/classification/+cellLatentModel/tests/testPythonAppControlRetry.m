function tests = testPythonAppControlRetry
%TESTPYTHONAPPCONTROLRETRY Exercise the one-shot retry with a fake package.
tests = functiontests(localfunctions);
end

function testStartupBlockRetriesExactlyOnce(testCase)
assumeTrue(testCase,ispc, ...
    'Smart App Control retry is intentionally Windows-only.');
[root,packageFolder,cleanupFolder] = temporaryPackage(); %#ok<ASGLU>
cleanupEnvironment = selectTemporaryRuntime(testCase,root); %#ok<NASGU>
counterPath = fullfile(root,'attempt_count.txt');
stdoutPath = fullfile(root,'python_stdout.log');

writeText(fullfile(packageFolder,'__init__.py'),strjoin({ ...
    'from pathlib import Path', ...
    'import sys', ...
    'counter = Path(sys.argv[-1])', ...
    'attempt = int(counter.read_text(encoding="utf-8")) + 1 if counter.exists() else 1', ...
    'counter.write_text(str(attempt), encoding="utf-8")', ...
    'if attempt == 1:', ...
    '    raise ImportError("DLL load failed while importing _fake_scipy: Une stratégie de contrôle d''application a bloqué ce fichier. (0xC0E90002)")', ...
    ''},newline));
writeText(fullfile(packageFolder,'__main__.py'), ...
    ['print("FAKE_CLI_SUCCESS", flush=True)' newline]);

runtime = cellLatentModel.utils.runPythonModule( ...
    'fake-command',counterPath,struct(),stdoutPath);

verifyEqual(testCase,runtime.status,0);
verifyTrue(testCase,runtime.windowsAppControl.detected);
verifyEqual(testCase,runtime.windowsAppControl.retryCount,1);
verifyEqual(testCase,runtime.windowsAppControl.blockedModule,'_fake_scipy');
verifyEqual(testCase,strtrim(fileread(counterPath)),'2');
logText = fileread(stdoutPath);
verifySubstring(testCase,logText,'Smart App Control');
verifySubstring(testCase,logText,'Retrying once');
verifySubstring(testCase,logText, ...
    'Une stratégie de contrôle d''application a bloqué ce fichier');
verifyFalse(testCase,contains(logText,char(65533)));
verifySubstring(testCase,logText,'FAKE_CLI_SUCCESS');
clear cleanupFolder;
end

function testCommandFailureIsNeverRetried(testCase)
assumeTrue(testCase,ispc, ...
    'Smart App Control retry is intentionally Windows-only.');
[root,packageFolder,cleanupFolder] = temporaryPackage(); %#ok<ASGLU>
cleanupEnvironment = selectTemporaryRuntime(testCase,root); %#ok<NASGU>
counterPath = fullfile(root,'attempt_count.txt');
stdoutPath = fullfile(root,'python_stdout.log');

writeText(fullfile(packageFolder,'__init__.py'),'');
writeText(fullfile(packageFolder,'__main__.py'),strjoin({ ...
    'from pathlib import Path', ...
    'import sys', ...
    'counter = Path(sys.argv[-1])', ...
    'attempt = int(counter.read_text(encoding="utf-8")) + 1 if counter.exists() else 1', ...
    'counter.write_text(str(attempt), encoding="utf-8")', ...
    'raise ImportError("DLL load failed while importing _scientific_solver: An Application Control policy has blocked this file. (0xC0E90002)")', ...
    ''},newline));

try
    cellLatentModel.utils.runPythonModule( ...
        'fake-command',counterPath,struct(),stdoutPath);
    verifyFail(testCase,'The fake scientific command should have failed.');
catch ME
    verifyEqual(testCase,ME.identifier, ...
        'cellLatentModel:ExternalModelFailed');
end

verifyEqual(testCase,strtrim(fileread(counterPath)),'1');
logText = fileread(stdoutPath);
verifyFalse(testCase,contains(logText,'Retrying once'));
clear cleanupFolder;
end

function testLongConfigAndPayloadPathsAreReadable(testCase)
assumeTrue(testCase,ispc, ...
    'Extended-length path handling is intentionally Windows-only.');
[runtimeRoot,packageFolder,cleanupRuntime] = temporaryPackage(); %#ok<ASGLU>
cleanupEnvironment = selectTemporaryRuntime(testCase,runtimeRoot); %#ok<NASGU>

longRoot = tempdir;
while strlength(string(fullfile(longRoot,'infer_config.json'))) < 275
    longRoot = fullfile(longRoot, ...
        'detecdiv_long_path_regression_0123456789');
end
mkdir(longRoot);
cleanupLongRoot = onCleanup(@() removeFolder(longRoot)); %#ok<NASGU>
payloadPath = fullfile(longRoot,'observations_payload.txt');
configPath = fullfile(longRoot,'infer_config.json');
stdoutPath = fullfile(longRoot,'runner_stdout.txt');
writeText(payloadPath,'LONG_PATH_PAYLOAD_OK');
pythonPayloadPath = ...
    cellLatentModel.utils.windowsLongPath(payloadPath);
writeText(configPath,jsonencode(struct('input_path',pythonPayloadPath)));

writeText(fullfile(packageFolder,'__init__.py'),'');
writeText(fullfile(packageFolder,'__main__.py'),strjoin({ ...
    'from pathlib import Path', ...
    'import json, sys', ...
    'config = json.loads(Path(sys.argv[-1]).read_text(encoding="utf-8"))', ...
    'print(Path(config["input_path"]).read_text(encoding="utf-8"), flush=True)', ...
    ''},newline));

runtime = cellLatentModel.utils.runPythonModule( ...
    'fake-command',configPath,struct(),stdoutPath);
verifyEqual(testCase,runtime.status,0);
verifySubstring(testCase,fileread(stdoutPath),'LONG_PATH_PAYLOAD_OK');
clear cleanupLongRoot cleanupRuntime;
end

function [root,packageFolder,cleanup] = temporaryPackage()
root = tempname;
packageFolder = fullfile(root,'src','cell_latent_model');
mkdir(packageFolder);
cleanup = onCleanup(@() removeFolder(root));
end

function cleanup = selectTemporaryRuntime(testCase,root)
pythonExe = locatePythonExecutable();
assumeTrue(testCase,~isempty(pythonExe), ...
    'A Python executable is required for this integration test.');
names = {'CELL_LATENT_MODEL_PYTHON','CELL_LATENT_MODEL_REPO_ROOT'};
oldValues = cellfun(@getenv,names,'UniformOutput',false);
cleanup = onCleanup(@() restoreEnvironment(names,oldValues));
setenv('CELL_LATENT_MODEL_PYTHON',pythonExe);
setenv('CELL_LATENT_MODEL_REPO_ROOT',root);
end

function pythonExe = locatePythonExecutable()
pythonExe = '';
candidates = {getenv('CELL_LATENT_MODEL_PYTHON'), ...
    fullfile(getenv('USERPROFILE'),'.conda','envs', ...
        'detecdiv_python','python.exe')};
for i = 1:numel(candidates)
    if isfile(candidates{i})
        pythonExe = candidates{i};
        return;
    end
end
if ispc
    [status,output] = system('where python 2>NUL');
else
    [status,output] = system('command -v python3 2>/dev/null');
end
if status == 0
    paths = splitlines(strtrim(string(output)));
    if ~isempty(paths) && isfile(char(paths(1)))
        pythonExe = char(paths(1));
    end
end
end

function restoreEnvironment(names,values)
for i = 1:numel(names), setenv(names{i},values{i}); end
end

function writeText(path,text)
fid = fopen(path,'w','n','UTF-8');
if fid < 0, error('testPythonAppControlRetry:WriteFailed','%s',path); end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid,'%s',text);
clear cleanup;
end

function removeFolder(path)
if isfolder(path), rmdir(path,'s'); end
end
