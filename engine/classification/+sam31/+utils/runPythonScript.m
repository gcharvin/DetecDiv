function [status, cmdout, cmd] = runPythonScript(scriptPath, configPath, params, workDir)
% sam31.utils.runPythonScript
% Run a SAM31 Python bridge through either local Python or WSL.

if nargin < 4 || isempty(workDir)
    workDir = pwd;
end
if ~exist(workDir, 'dir')
    mkdir(workDir);
end

backend = sam31.utils.getParam(params, 'backend', 'local');
backend = lower(strtrim(char(string(backend))));
pythonExe = sam31.utils.getParam(params, {'pythonExecutable','python'}, '');
pythonExe = char(string(pythonExe));
if isempty(pythonExe)
    pe = pyenv;
    pythonExe = char(pe.Executable);
end

if strcmp(backend, 'wsl')
    cmd = sprintf('wsl.exe "%s" "%s" --config "%s"', ...
        pythonExe, toWslPath(scriptPath), toWslPath(configPath));
else
    cmd = sprintf('"%s" "%s" --config "%s"', pythonExe, scriptPath, configPath);
end

disp(['[SAM31] ' cmd]);
[status, cmdout] = system(cmd);

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

function out = toWslPath(pathIn)
pathIn = char(string(pathIn));
if numel(pathIn) >= 3 && pathIn(2) == ':' && (pathIn(3) == '\' || pathIn(3) == '/')
    drive = lower(pathIn(1));
    rest = strrep(pathIn(3:end), '\', '/');
    out = ['/mnt/' drive rest];
else
    out = strrep(pathIn, '\', '/');
end
end
