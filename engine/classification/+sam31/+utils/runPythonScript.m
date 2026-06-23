function [status, cmdout, cmd] = runPythonScript(scriptPath, configPath, ~, workDir)
% sam31.utils.runPythonScript
% Run a SAM31 Python bridge through the SAM31 runtime, not the generic
% DetecDiv Python environment.

if nargin < 4 || isempty(workDir)
    workDir = pwd;
end
if ~exist(workDir, 'dir')
    mkdir(workDir);
end

runtime = resolveSam31Runtime(configPath);
cmd = buildCommand(runtime, scriptPath, configPath);
cancelTokenFile = readCancelTokenFile(configPath);

disp(['[SAM31] ' cmd]);
if ~isempty(cancelTokenFile)
    detecdiv_check_cancel(cancelTokenFile, 'SAM31 Python before launch');
end

if ~isempty(cancelTokenFile) && ~ispc
    [status, cmdout] = runCommandWithCancel(cmd, workDir, cancelTokenFile);
else
    [status, cmdout] = system(cmd);
end

try
    fid = fopen(fullfile(workDir, 'sam31_runner_stdout.txt'), 'w');
    if fid ~= -1
        fwrite(fid, cmdout, 'char');
        fclose(fid);
    end
catch
end

if status ~= 0
    error('sam31:PythonRunnerFailed', 'SAM31 Python runner failed (%d):\n%s', status, cmdout);
end
end

function cancelTokenFile = readCancelTokenFile(configPath)
cancelTokenFile = '';
try
    cfg = jsondecode(fileread(configPath));
    if isstruct(cfg) && isfield(cfg, 'cancel_path') && ~isempty(cfg.cancel_path)
        cancelTokenFile = char(string(cfg.cancel_path));
    elseif isstruct(cfg) && isfield(cfg, 'cancelTokenFile') && ~isempty(cfg.cancelTokenFile)
        cancelTokenFile = char(string(cfg.cancelTokenFile));
    end
catch
    cancelTokenFile = '';
end
end

function [status, cmdout] = runCommandWithCancel(cmd, workDir, cancelTokenFile)
stdoutPath = fullfile(workDir, 'sam31_runner_stdout.txt');
statusPath = fullfile(workDir, 'sam31_runner_status.txt');
scriptPath = fullfile(workDir, 'sam31_runner.sh');

deleteIfExists(stdoutPath);
deleteIfExists(statusPath);

fid = fopen(scriptPath, 'w');
if fid == -1
    error('sam31:RunnerWriteFailed', 'Unable to write SAM31 runner script: %s', scriptPath);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '#!/usr/bin/env bash\n');
fprintf(fid, 'set +e\n');
fprintf(fid, 'cd %s\n', shellQuote(workDir));
fprintf(fid, '%s\n', cmd);
fprintf(fid, 'status=$?\n');
fprintf(fid, 'printf "%%s\\n" "$status" > %s\n', shellQuote(statusPath));
fprintf(fid, 'exit "$status"\n');
clear cleanup

launchCmd = sprintf('setsid bash %s > %s 2>&1 < /dev/null & echo $!', ...
    shellQuote(scriptPath), shellQuote(stdoutPath));
[launchStatus, launchOut] = system(launchCmd);
if launchStatus ~= 0
    error('sam31:PythonRunnerFailed', ...
        'Unable to launch SAM31 Python runner (%d):%s%s', launchStatus, newline, launchOut);
end

pid = str2double(strtrim(launchOut));
if isnan(pid) || pid <= 0
    error('sam31:PythonRunnerFailed', 'SAM31 Python runner did not return a valid PID: %s', launchOut);
end

while true
    if exist(statusPath, 'file') == 2
        status = readExitStatus(statusPath);
        if isnan(status)
            status = 1;
        end
        cmdout = readTextFile(stdoutPath);
        return;
    end

    if ~isProcessAlive(pid)
        pause(0.5);
        status = readExitStatus(statusPath);
        if isnan(status)
            status = 1;
        end
        cmdout = readTextFile(stdoutPath);
        return;
    end

    try
        detecdiv_check_cancel(cancelTokenFile, 'SAM31 Python runner');
    catch ME
        terminateProcessGroup(pid);
        cmdout = readTextFile(stdoutPath);
        if isempty(strtrim(cmdout))
            cmdout = ME.message;
        else
            cmdout = sprintf('%s%s%s', cmdout, newline, ME.message);
        end
        rethrow(ME);
    end

    pause(2);
end
end

function deleteIfExists(pathValue)
try
    if exist(pathValue, 'file') == 2
        delete(pathValue);
    end
catch
end
end

function text = readTextFile(pathValue)
text = '';
try
    if exist(pathValue, 'file') == 2
        text = fileread(pathValue);
    end
catch
    text = '';
end
end

function status = readExitStatus(statusPath)
status = NaN;
try
    raw = strtrim(fileread(statusPath));
    status = str2double(raw);
catch
    status = NaN;
end
end

function tf = isProcessAlive(pid)
[status, ~] = system(sprintf('kill -0 %d 2>/dev/null', round(pid)));
tf = status == 0;
end

function terminateProcessGroup(pid)
pgid = round(pid);
system(sprintf('kill -TERM -- -%d 2>/dev/null', pgid));
pause(5);
if isProcessAlive(pid)
    system(sprintf('kill -KILL -- -%d 2>/dev/null', pgid));
end
end

function runtime = resolveSam31Runtime(configPath)
cfg = struct();
try
    cfg = jsondecode(fileread(configPath));
catch
end

internal = sam31.utils.internalDefaults();
repoRoot = readConfigPath(cfg, 'repo_root', internal.repoRoot);
repoRoot = resolveImportableRepoRoot(repoRoot, internal.repoRoot);

sam3Repo = readConfigPath(cfg, 'sam3_repo', internal.sam3Repo);
if isempty(sam3Repo) || exist(sam3Repo, 'dir') ~= 7
    candidate = fullfile(repoRoot, 'artifacts', 'sam3_official');
    if exist(candidate, 'dir') == 7
        sam3Repo = candidate;
    end
end

pythonExe = getenv('SAM31_PYTHON_EXE');
if isempty(pythonExe)
    candidates = { ...
        '/home/charvin-admin/venvs/sam3/bin/python', ...
        '/home/gilles/venvs/sam3/bin/python', ...
        fullfile(getenv('USERPROFILE'), '.conda', 'envs', 'sam3', 'python.exe')};
    for i = 1:numel(candidates)
        c = char(string(candidates{i}));
        if ~isempty(c) && exist(c, 'file') == 2
            pythonExe = c;
            break;
        end
    end
end

if isempty(pythonExe)
    try
        pe = pyenv;
        if pe.Status == "NotLoaded"
            select_and_load_conda_env('debug', true);
            pe = pyenv;
        end
        pythonExe = char(pe.Executable);
    catch ME
        error('sam31:PythonBootstrapFailed', ...
            'Unable to resolve the SAM3.1 Python environment:%s%s', newline, ME.message);
    end
end
if isempty(pythonExe)
    error('sam31:PythonBootstrapFailed', 'Unable to resolve a Python executable for SAM31.');
end

runtime = struct();
runtime.pythonExe = pythonExe;
runtime.repoRoot = repoRoot;
runtime.sam3Repo = sam3Repo;
end

function pathValue = readConfigPath(cfg, fieldName, defaultValue)
pathValue = char(string(defaultValue));
try
    if isstruct(cfg) && isfield(cfg, fieldName) && ~isempty(cfg.(fieldName))
        pathValue = char(string(cfg.(fieldName)));
    end
catch
end
pathValue = strrep(pathValue, '\', filesep);
pathValue = strrep(pathValue, '/', filesep);
end

function repoRoot = resolveImportableRepoRoot(configRepoRoot, defaultRepoRoot)
repoRoot = char(string(configRepoRoot));
if hasSam31Package(repoRoot)
    return;
end
candidates = { ...
    char(string(defaultRepoRoot)), ...
    '/home/charvin-admin/repos/SAM31_zero_shot_ctc_benchmark', ...
    '/data/Gilles/SAM31_zero_shot_ctc_benchmark'};
for i = 1:numel(candidates)
    c = char(string(candidates{i}));
    if hasSam31Package(c)
        repoRoot = c;
        return;
    end
end
end

function tf = hasSam31Package(repoRoot)
tf = false;
try
    tf = exist(fullfile(char(string(repoRoot)), 'sam31_ctc_benchmark'), 'dir') == 7;
catch
end
end

function cmd = buildCommand(runtime, scriptPath, configPath)
pythonPath = strjoin({ ...
    char(string(runtime.repoRoot)), ...
    fullfile(char(string(runtime.repoRoot)), 'scripts'), ...
    char(string(runtime.sam3Repo))}, pathsep);

if ispc
    cmd = sprintf('set "PYTHONPATH=%s;%s" && "%s" "%s" --config "%s"', ...
        pythonPath, getenv('PYTHONPATH'), runtime.pythonExe, scriptPath, configPath);
else
    cmd = sprintf('PYTHONPATH=%s:%s "%s" "%s" --config "%s"', ...
        shellQuote(pythonPath), shellQuote(getenv('PYTHONPATH')), ...
        runtime.pythonExe, scriptPath, configPath);
end
end

function out = shellQuote(value)
value = char(string(value));
value = strrep(value, '''', '''"''"''');
out = ['''' value ''''];
end
