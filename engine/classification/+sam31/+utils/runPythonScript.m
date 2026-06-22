function [status, cmdout, cmd] = runPythonScript(scriptPath, configPath, ~, workDir)
% sam31.utils.runPythonScript
% Run a SAM31 Python bridge through the DetecDiv-selected conda Python.

if nargin < 4 || isempty(workDir)
    workDir = pwd;
end
if ~exist(workDir, 'dir')
    mkdir(workDir);
end

try
    pe = pyenv;
    if pe.Status == "NotLoaded"
        select_and_load_conda_env('debug', true);
        pe = pyenv;
    end
    pythonExe = char(pe.Executable);
catch ME
    error('sam31:PythonBootstrapFailed', ...
        'Unable to resolve the SAM3.1 Python environment through select_and_load_conda_env:%s%s', ...
        newline, ME.message);
end

if isempty(pythonExe)
    error('sam31:PythonBootstrapFailed', 'MATLAB pyenv did not provide a Python executable.');
end

cmd = sprintf('"%s" "%s" --config "%s"', pythonExe, scriptPath, configPath);

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
