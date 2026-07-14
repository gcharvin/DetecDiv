function [status, cmdout, cmd] = runPythonScript(scriptPath, configPath, tp, workDir)
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
runnerMode = resolveRunnerMode(scriptPath, configPath, tp);

disp(['[SAM31] ' cmd]);
if ~isempty(cancelTokenFile)
    detecdiv_check_cancel(cancelTokenFile, 'SAM31 Python before launch');
end

if strcmp(runnerMode, 'session') && strcmp(runtime.backend, 'wsl')
    try
        [status, cmdout] = runWslSession(runtime, scriptPath, configPath, workDir);
    catch ME
        disp(['[WARN] SAM31 WSL session runner failed; falling back to external WSL process: ' ME.message]);
        [status, cmdout] = runExternal(cmd, workDir, cancelTokenFile);
    end
elseif strcmp(runnerMode, 'session')
    try
        [status, cmdout] = runSession(runtime, scriptPath, configPath, workDir);
    catch ME
        disp(['[WARN] SAM31 session runner failed; falling back to external process: ' ME.message]);
        [status, cmdout] = runExternal(cmd, workDir, cancelTokenFile);
    end
else
    [status, cmdout] = runExternal(cmd, workDir, cancelTokenFile);
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

function [status, cmdout] = runWslSession(runtime, scriptPath, configPath, workDir)
persistent serverKey serverReadyFile serverPort serverHost serverLogFile serverCleanup

key = wslServerKey(runtime, scriptPath);
if isempty(serverKey) || ~strcmp(serverKey, key) || isempty(serverPort) || ~isfinite(serverPort)
    [serverReadyFile, serverLogFile, serverHost, serverPort] = startWslServer(runtime, scriptPath);
    serverKey = key;
    serverCleanup = makeWslServerCleanup(runtime, scriptPath, serverHost, serverPort);
end

clientCmd = buildWslClientCommand(runtime, scriptPath, configPath, serverHost, serverPort);
disp(sprintf('[SAM31] WSL session runner: port=%d log=%s', round(serverPort), serverLogFile));
[status, cmdout] = system(clientCmd);
if status ~= 0
    % One retry handles stale ports after WSL was restarted outside MATLAB.
    [serverReadyFile, serverLogFile, serverHost, serverPort] = startWslServer(runtime, scriptPath);
    serverKey = key;
    serverCleanup = makeWslServerCleanup(runtime, scriptPath, serverHost, serverPort);
    clientCmd = buildWslClientCommand(runtime, scriptPath, configPath, serverHost, serverPort);
    [status, cmdout] = system(clientCmd);
end
try
    fid = fopen(fullfile(workDir, 'sam31_wsl_server_ref.json'), 'w');
    if fid ~= -1
        fwrite(fid, jsonencode(struct('readyFile', serverReadyFile, ...
            'logFile', serverLogFile, 'host', serverHost, 'port', serverPort)), 'char');
        fclose(fid);
    end
catch
end
end

function cleanupObj = makeWslServerCleanup(runtime, scriptPath, host, port)
cleanupRuntime = runtime;
cleanupScriptPath = scriptPath;
cleanupHost = host;
cleanupPort = port;
cleanupObj = onCleanup(@() shutdownWslServer(cleanupRuntime, cleanupScriptPath, cleanupHost, cleanupPort));
end

function shutdownWslServer(runtime, scriptPath, host, port)
try
    cmd = buildWslShutdownCommand(runtime, scriptPath, host, port);
    system(cmd);
catch
end
end

function key = wslServerKey(runtime, scriptPath)
serverScript = fullfile(fileparts(scriptPath), 'sam31_wsl_server.py');
key = strjoin({ ...
    char(string(runtime.repoRoot)), ...
    char(string(runtime.sam3Repo)), ...
    char(string(fileparts(scriptPath))), ...
    fileStamp(scriptPath), ...
    fileStamp(serverScript)}, '|');
end

function stamp = fileStamp(pathValue)
stamp = 'missing';
try
    info = dir(pathValue);
    if ~isempty(info)
        stamp = sprintf('%.12g', info.datenum);
    end
catch
end
end

function [readyFile, logFile, host, port] = startWslServer(runtime, scriptPath)
readyFile = fullfile(tempdir, ['detecdiv_sam31_wsl_server_' char(javaMethod('randomUUID', 'java.util.UUID')) '.json']);
logFile = fullfile(tempdir, ['detecdiv_sam31_wsl_server_' datestr(now, 'yyyymmdd_HHMMSS_FFF') '.log']);
launchScript = fullfile(tempdir, ['detecdiv_sam31_wsl_server_' datestr(now, 'yyyymmdd_HHMMSS_FFF') '.sh']);
deleteIfExists(readyFile);
deleteIfExists(launchScript);

serverScript = fullfile(fileparts(scriptPath), 'sam31_wsl_server.py');
wslDistro = getenvOrDefaultLocal('SAM31_WSL_DISTRO', 'Ubuntu-24.04');
pythonExe = getenvOrDefaultLocal('SAM31_WSL_PYTHON_EXE', '/home/gilles/venvs/sam3/bin/python');
pythonPath = wslPythonPath(runtime, scriptPath);
readyWsl = toWslPath(readyFile);
logWsl = toWslPath(logFile);
serverWsl = toWslPath(serverScript);

writeWslLaunchScript(launchScript, { ...
    '#!/usr/bin/env bash', ...
    'set -e', ...
    ['exec > ' shellQuote(logWsl) ' 2>&1'], ...
    wslMountPreludeLine(), ...
    ['cd ' shellQuote(fileparts(serverWsl))], ...
    sprintf('exec env PYTHONPATH=%s:%s %s %s --host 127.0.0.1 --port 0 --ready-file %s', ...
        shellQuote(pythonPath), shellQuote(getenv('PYTHONPATH')), ...
        shellQuote(pythonExe), shellQuote(serverWsl), shellQuote(readyWsl))});
launchWsl = toWslPath(launchScript);
cmd = buildPowershellStartWslCommand(wslDistro, ...
    ['sed -i ''s/\r$//'' ' shellQuote(launchWsl) ' && bash ' shellQuote(launchWsl)]);
disp(['[SAM31] starting WSL session server: ' cmd]);
[status, out] = system(cmd);
if status ~= 0
    error('sam31:WslServerStartFailed', 'Unable to start WSL SAM31 server (%d):%s%s', status, newline, out);
end

deadline = tic;
while exist(readyFile, 'file') ~= 2
    if toc(deadline) > 45
        logText = readTextFile(logFile);
        error('sam31:WslServerStartTimeout', ...
            'Timed out waiting for WSL SAM31 server ready file:%s%s', newline, logText);
    end
    pause(0.25);
end
ready = jsondecode(fileread(readyFile));
host = char(string(ready.host));
port = double(ready.port);
if isempty(host) || ~isfinite(port) || port <= 0
    error('sam31:WslServerBadReadyFile', 'Invalid WSL SAM31 ready file: %s', readyFile);
end
end

function cmd = buildWslClientCommand(runtime, scriptPath, configPath, host, port)
wslDistro = getenvOrDefaultLocal('SAM31_WSL_DISTRO', 'Ubuntu-24.04');
pythonExe = getenvOrDefaultLocal('SAM31_WSL_PYTHON_EXE', '/home/gilles/venvs/sam3/bin/python');
clientScript = fullfile(fileparts(scriptPath), 'sam31_wsl_client.py');
bashCmd = sprintf('PYTHONPATH=%s:%s %s %s --host %s --port %d --config %s', ...
    shellQuote(wslPythonPath(runtime, scriptPath)), shellQuote(getenv('PYTHONPATH')), ...
    shellQuote(pythonExe), shellQuote(toWslPath(clientScript)), ...
    shellQuote(host), round(port), shellQuote(toWslPath(configPath)));
cmd = buildPowershellWslCommand(wslDistro, bashCmd);
end

function cmd = buildWslShutdownCommand(runtime, scriptPath, host, port)
wslDistro = getenvOrDefaultLocal('SAM31_WSL_DISTRO', 'Ubuntu-24.04');
pythonExe = getenvOrDefaultLocal('SAM31_WSL_PYTHON_EXE', '/home/gilles/venvs/sam3/bin/python');
clientScript = fullfile(fileparts(scriptPath), 'sam31_wsl_client.py');
bashCmd = sprintf('PYTHONPATH=%s:%s %s %s --host %s --port %d --shutdown --timeout 10', ...
    shellQuote(wslPythonPath(runtime, scriptPath)), shellQuote(getenv('PYTHONPATH')), ...
    shellQuote(pythonExe), shellQuote(toWslPath(clientScript)), ...
    shellQuote(host), round(port));
cmd = buildPowershellWslCommand(wslDistro, bashCmd);
end

function mode = resolveRunnerMode(scriptPath, configPath, tp)
mode = 'external';
try
    [~, name, ~] = fileparts(scriptPath);
    if strcmp(name, 'classify_sam31')
        mode = 'session';
    end
catch
end
try
    cfg = jsondecode(fileread(configPath));
    if isstruct(cfg) && isfield(cfg, 'runner_mode') && ~isempty(cfg.runner_mode)
        mode = lower(strtrim(char(string(cfg.runner_mode))));
    end
catch
end
try
    if isstruct(tp) && isfield(tp, 'sam31Runner') && ~isempty(tp.sam31Runner)
        mode = lower(strtrim(char(string(tp.sam31Runner))));
    end
catch
end
envMode = getenv('SAM31_RUNNER_MODE');
if ~isempty(envMode)
    mode = lower(strtrim(char(string(envMode))));
end
if any(strcmp(mode, {'persistent','pyenv','inprocess','in_process'}))
    mode = 'session';
elseif ~strcmp(mode, 'session')
    mode = 'external';
end
end

function [status, cmdout] = runExternal(cmd, workDir, cancelTokenFile)
if startsWith(cmd, 'wsl.exe ')
    [status, cmdout] = system(cmd);
elseif ~isempty(cancelTokenFile) && ~ispc
    [status, cmdout] = runCommandWithCancel(cmd, workDir, cancelTokenFile);
else
    [status, cmdout] = system(cmd);
end
end

function [status, cmdout] = runSession(runtime, scriptPath, configPath, workDir)
stdoutPath = fullfile(workDir, 'sam31_runner_stdout.txt');
deleteIfExists(stdoutPath);
ensurePyenv(runtime.pythonExe);
ensurePythonPath(runtime, scriptPath);

persistent moduleCache modulePathCache
[runnerDir, moduleName, ~] = fileparts(scriptPath);
if isempty(moduleCache) || isempty(modulePathCache) || ~strcmp(modulePathCache, scriptPath)
    py.importlib.invalidate_caches();
    py.sys.path().insert(int32(0), runnerDir);
    moduleCache = py.importlib.import_module(moduleName);
    modulePathCache = scriptPath;
end

disp('[SAM31] session runner: reusing MATLAB Python interpreter');
moduleCache.run(configPath);
status = 0;
cmdout = sprintf('[SAM31] session runner completed: %s\n', configPath);
try
    fid = fopen(stdoutPath, 'a');
    if fid ~= -1
        fwrite(fid, cmdout, 'char');
        fclose(fid);
    end
catch
end
end

function ensurePyenv(pythonExe)
try
    pe = pyenv;
    status = char(string(pe.Status));
    if strcmpi(status, 'NotLoaded')
        pyenv('Version', pythonExe);
        return;
    end
    loadedExe = char(string(pe.Executable));
    if ~samePath(loadedExe, pythonExe)
        error('sam31:PythonEnvAlreadyLoaded', ...
            'MATLAB Python is already loaded from "%s"; SAM31 requires "%s". Restart MATLAB or use SAM31_RUNNER_MODE=external.', ...
            loadedExe, pythonExe);
    end
catch ME
    if strcmp(ME.identifier, 'sam31:PythonEnvAlreadyLoaded')
        rethrow(ME);
    end
    error('sam31:PythonBootstrapFailed', ...
        'Unable to load the SAM31 Python environment "%s":%s%s', ...
        pythonExe, newline, ME.message);
end
end

function ensurePythonPath(runtime, scriptPath)
paths = buildPythonPathParts(runtime, scriptPath);
py.importlib.import_module('sys');
for i = numel(paths):-1:1
    p = paths{i};
    if isempty(p)
        continue;
    end
    py.sys.path().insert(int32(0), p);
end
end

function paths = buildPythonPathParts(runtime, scriptPath)
runnerDir = fileparts(scriptPath);
paths = { ...
    runnerDir, ...
    char(string(runtime.repoRoot)), ...
    fullfile(char(string(runtime.repoRoot)), 'scripts'), ...
    char(string(runtime.sam3Repo))};
end

function tf = samePath(a, b)
try
    a = char(string(a));
    b = char(string(b));
    if ispc
        tf = strcmpi(strrep(a, '/', '\'), strrep(b, '/', '\'));
    else
        tf = strcmp(a, b);
    end
catch
    tf = false;
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
runtime.backend = resolveBackend(cfg);
runtime.pythonExe = pythonExe;
runtime.repoRoot = repoRoot;
runtime.sam3Repo = sam3Repo;
end

function backend = resolveBackend(cfg)
backend = getenv('SAM31_BACKEND');
try
    if isempty(backend) && isstruct(cfg) && isfield(cfg, 'backend') && ~isempty(cfg.backend)
        backend = char(string(cfg.backend));
    end
catch
end
backend = lower(strtrim(char(string(backend))));
if any(strcmp(backend, {'wsl','linux'}))
    backend = 'wsl';
else
    backend = 'local';
end
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
    fullfile(getenv('USERPROFILE'), 'Documents', 'MATLAB', 'SAM31_yeast'), ...
    '/mnt/c/Users/Gilles/Documents/MATLAB/SAM31_yeast', ...
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
pythonPath = strjoin(buildPythonPathParts(runtime, scriptPath), pathsep);

if isstruct(runtime) && isfield(runtime, 'backend') && strcmp(runtime.backend, 'wsl')
    cmd = buildWslCommand(runtime, scriptPath, configPath);
    return;
end

if ispc
    cmd = sprintf('set "PYTHONPATH=%s;%s" && "%s" "%s" --config "%s"', ...
        pythonPath, getenv('PYTHONPATH'), runtime.pythonExe, scriptPath, configPath);
else
    cmd = sprintf('PYTHONPATH=%s:%s "%s" "%s" --config "%s"', ...
        shellQuote(pythonPath), shellQuote(getenv('PYTHONPATH')), ...
        runtime.pythonExe, scriptPath, configPath);
end
end

function cmd = buildWslCommand(runtime, scriptPath, configPath)
wslDistro = getenvOrDefaultLocal('SAM31_WSL_DISTRO', 'Ubuntu-24.04');
pythonExe = getenvOrDefaultLocal('SAM31_WSL_PYTHON_EXE', '/home/gilles/venvs/sam3/bin/python');
scriptWsl = toWslPath(scriptPath);
configWsl = toWslPath(configPath);
workDirWsl = fileparts(configWsl);
pythonPath = wslPythonPath(runtime, scriptPath);

bashCmd = sprintf('%scd %s && PYTHONPATH=%s:%s %s %s --config %s', ...
    wslMountPrelude(), shellQuote(workDirWsl), shellQuote(pythonPath), shellQuote(getenv('PYTHONPATH')), ...
    shellQuote(pythonExe), shellQuote(scriptWsl), shellQuote(configWsl));
cmd = buildPowershellWslCommand(wslDistro, bashCmd);
end

function pythonPath = wslPythonPath(runtime, scriptPath)
repoRoot = toWslPath(runtime.repoRoot);
sam3Repo = toWslPath(runtime.sam3Repo);
scriptWsl = toWslPath(scriptPath);
pythonPath = strjoin({fileparts(scriptWsl), repoRoot, [repoRoot '/scripts'], sam3Repo}, ':');
end

function prelude = wslMountPrelude()
prelude = ['sudo mkdir -p /mnt/x && ' ...
    'if ! mountpoint -q /mnt/x; then sudo mount -t drvfs ''//10.20.11.250/Data'' /mnt/x; fi && '];
end

function line = wslMountPreludeLine()
line = 'sudo mkdir -p /mnt/x && if ! mountpoint -q /mnt/x; then sudo mount -t drvfs ''//10.20.11.250/Data'' /mnt/x; fi';
end

function writeWslLaunchScript(pathValue, lines)
fid = fopen(pathValue, 'w');
if fid == -1
    error('sam31:WslLaunchScriptWriteFailed', 'Unable to write WSL launch script: %s', pathValue);
end
cleanup = onCleanup(@() fclose(fid));
for i = 1:numel(lines)
    fprintf(fid, '%s\n', char(string(lines{i})));
end
clear cleanup
end

function cmd = buildPowershellWslCommand(wslDistro, bashCmd)
if ispc
    psCmd = sprintf('& wsl.exe -d %s -- bash -lc %s', powershellQuote(wslDistro), powershellQuote(bashCmd));
    cmd = sprintf('powershell.exe -NoProfile -ExecutionPolicy Bypass -Command %s', windowsQuote(psCmd));
else
    cmd = sprintf('wsl.exe -d %s -- bash -lc %s', shellQuote(wslDistro), shellQuote(bashCmd));
end
end

function cmd = buildPowershellStartWslCommand(wslDistro, bashCmd)
if ispc
    cmd = sprintf('cmd.exe /c start "" /b wsl.exe -d %s -- bash -lc %s', ...
        char(string(wslDistro)), windowsQuote(bashCmd));
else
    cmd = buildPowershellWslCommand(wslDistro, bashCmd);
end
end

function out = powershellQuote(value)
value = char(string(value));
value = strrep(value, '''', '''''');
out = ['''' value ''''];
end

function out = windowsQuote(value)
value = char(string(value));
value = strrep(value, '"', '\"');
out = ['"' value '"'];
end

function pathOut = toWslPath(pathIn)
pathText = char(string(pathIn));
pathText = strrep(pathText, '\', '/');
if numel(pathText) >= 2 && pathText(2) == ':'
    drive = lower(pathText(1));
    rest = pathText(3:end);
    if startsWith(rest, '/')
        rest = rest(2:end);
    end
    pathOut = ['/mnt/' drive '/' rest];
elseif startsWith(pathText, '//10.20.11.250/Data', 'IgnoreCase', true)
    suffix = char(extractAfter(pathText, strlength('//10.20.11.250/Data')));
    pathOut = ['/mnt/x' suffix];
elseif startsWith(pathText, '\\10.20.11.250\Data', 'IgnoreCase', true)
    pathText = strrep(pathText, '\', '/');
    suffix = char(extractAfter(pathText, strlength('//10.20.11.250/Data')));
    pathOut = ['/mnt/x' suffix];
else
    pathOut = pathText;
end
end

function value = getenvOrDefaultLocal(name, defaultValue)
value = getenv(name);
if isempty(value)
    value = defaultValue;
end
end

function out = shellQuote(value)
value = char(string(value));
value = strrep(value, '''', '''"''"''');
out = ['''' value ''''];
end
