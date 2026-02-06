function info = ensurePythonDeps(classif, varargin)
% ENSUREPYTHONDEPS  Ensure Python deps for CellposeSAM (conda first, pip fallback).

    opts = struct('debug', true, 'use_conda', true, 'pip_fallback', true, 'force', false);
    if mod(numel(varargin),2) ~= 0
        error('Arguments must be Name,Value pairs.');
    end
    for k = 1:2:numel(varargin)
        name = lower(string(varargin{k}));
        val  = varargin{k+1};
        switch name
            case "debug",        opts.debug = logical(val);
            case "use_conda",    opts.use_conda = logical(val);
            case "pip_fallback", opts.pip_fallback = logical(val);
            case "force",        opts.force = logical(val);
            otherwise, error('Unknown option "%s".', name);
        end
    end

    info = struct('installed', {{}}, 'failed', {{}}, 'skipped', {{}});

    % Cache results per Python executable+version to avoid rechecking each call
    persistent cache
    if isempty(cache)
        cache = struct('key', {}, 'ok', {}, 'info', {}, 'err', {});
    end

    pe = pyenv;
    if pe.Status ~= "Loaded"
        error('Python environment not loaded. Call select_and_load_conda_env first.');
    end

    cacheKey = string(pe.Executable) + "|" + string(pe.Version);
    if ~opts.force
        hit = find(arrayfun(@(c) c.ok && c.key == cacheKey, cache), 1);
        if ~isempty(hit)
            info = cache(hit).info;
            return;
        end
        hitFail = find(arrayfun(@(c) ~c.ok && c.key == cacheKey, cache), 1);
        if ~isempty(hitFail)
            error(cache(hitFail).err);
        end
    end

    try
    pyExe = char(pe.Executable);
    if ~isfile(pyExe)
        error('Python executable not found: %s', pyExe);
    end

    envPath = string(fileparts(pyExe));
    if isunix && endsWith(envPath, filesep + "bin")
        envPath = string(fileparts(envPath));
    end

    condaMeta = fullfile(char(envPath), 'conda-meta');
    if ~exist(condaMeta, 'dir')
        error(['Current Python env does not look like a conda env: ' char(envPath) newline ...
               'Create a conda env (Python 3.10 recommended):' newline ...
               '  conda create -n cellposesam python=3.10 -y' newline ...
               '  conda activate cellposesam']);
    end

    [condaCmd, condaOk] = findCondaCmdLocal(opts.debug);
    if ~opts.use_conda
        condaOk = false;
    end
    if ~condaOk
        error(['Conda not found. Create a conda env (Python 3.10 recommended) and try again:' newline ...
               '  conda create -n cellposesam python=3.10 -y' newline ...
               '  conda activate cellposesam']);
    end

    % Warn if Python version is not 3.10 (Cellpose recommendation)
    try
        verStr = char(pe.Version);
        if isempty(verStr) || ~contains(verStr, '3.10')
            warning('Cellpose recommends Python 3.10. Current pyenv: %s', verStr);
            fprintf('[PYDEPS] Suggested env: conda create -n cellposesam python=3.10 -y\n');
        end
    catch
    end

    depsConda = ["numpy","scipy","h5py","matplotlib"];
    depsPipOnly = ["cellpose"];

    for i = 1:numel(depsConda)
        pkg = depsConda(i);
        if canImport(pyExe, pkg)
            info.skipped{end+1} = char(pkg);
            continue;
        end
        if condaOk
            if opts.debug
                fprintf('[PYDEPS] conda install %s...\n', char(pkg));
            end
            ok = condaInstall(condaCmd, envPath, pkg, opts.debug);
            if ~ok && opts.pip_fallback
                ok = pipInstall(pyExe, pkg, opts.debug, "");
            end
        else
            ok = pipInstall(pyExe, pkg, opts.debug, "");
        end

        if ok
            info.installed{end+1} = char(pkg);
        else
            info.failed{end+1} = char(pkg);
        end
    end

    for i = 1:numel(depsPipOnly)
        pkg = depsPipOnly(i);
        if canImport(pyExe, pkg)
            info.skipped{end+1} = char(pkg);
            continue;
        end
        ok = false;
        if opts.pip_fallback
            if opts.debug
                fprintf('[PYDEPS] pip install %s --upgrade...\n', char(pkg));
            end
            ok = pipInstall(pyExe, pkg, opts.debug, "--upgrade");
        end
        if ok
            info.installed{end+1} = char(pkg);
        else
            info.failed{end+1} = char(pkg);
        end
    end

    % Torch is required but not auto-installed (manual install).
    if ~canImport(pyExe, "torch")
        info.failed{end+1} = 'torch';
        warning('PyTorch is missing and was not auto-installed. Install torch manually in this env.');
        fprintf('[PYDEPS] Suggested (GPU): conda install -y pytorch torchvision torchaudio pytorch-cuda=11.8 -c pytorch -c nvidia\n');
        fprintf('[PYDEPS] Suggested (CPU): conda install -y pytorch torchvision torchaudio cpuonly -c pytorch\n');
        fprintf('[PYDEPS] If CUDA version differs, use the command from https://pytorch.org/get-started/locally/\n');
    end

    if opts.debug
        fprintf('[PYDEPS] installed: %s\n', strjoin(string(info.installed), ', '));
        fprintf('[PYDEPS] failed: %s\n', strjoin(string(info.failed), ', '));
    end

    if ~isempty(info.failed)
        error('Missing Python dependencies: %s', strjoin(string(info.failed), ', '));
    end

    % Cache success
    cache(end+1) = struct('key', cacheKey, 'ok', true, 'info', info, 'err', "");
    return;
catch ME
    % Cache failure
    cache(end+1) = struct('key', cacheKey, 'ok', false, 'info', info, 'err', string(ME.message));
    rethrow(ME);
end

function ok = canImport(pyExe, pkg)
    cmd = sprintf('"%s" -c "import importlib; importlib.import_module(''%s'')"', pyExe, pkg);
    [st, ~] = system(cmd);
    ok = (st == 0);
end

function ok = pipInstall(pyExe, pkg, debug, extraArgs)
    if nargin < 4, extraArgs = ""; end
    cmd = sprintf('"%s" -m pip install %s %s', pyExe, pkg, char(extraArgs));
    [st, out] = system(cmd);
    ok = (st == 0);
    if debug && ~ok
        fprintf('[PYDEPS] pip failed for %s:\n%s\n', char(pkg), out);
    end
end

function ok = condaInstall(condaCmd, envPath, pkg, debug, extraArgs)
    if nargin < 5, extraArgs = ""; end
    if endsWith(lower(condaCmd), ".bat")
        cmd = sprintf('cmd /c ""%s" install -y -p "%s" %s %s"', condaCmd, char(envPath), char(pkg), char(extraArgs));
    else
        cmd = sprintf('"%s" install -y -p "%s" %s %s', condaCmd, char(envPath), char(pkg), char(extraArgs));
    end
    [st, out] = system(cmd);
    ok = (st == 0);
    if debug && ~ok
        fprintf('[PYDEPS] conda failed for %s:\n%s\n', char(pkg), out);
    end
end

function [cmd, ok] = findCondaCmdLocal(debug)
    ok = false;
    cmd = 'conda';

    % Try PowerShell: conda may be a function, but "conda info --base" works.
    [stPS, outPS] = system('powershell -NoProfile -Command "conda info --base"');
    if stPS == 0
        base = strtrim(string(outPS));
        candBat = fullfile(base, "condabin", "conda.bat");
        candExe = fullfile(base, "Scripts",  "conda.exe");
        if isfile(candBat)
            cmd = char(candBat); ok = true; return;
        elseif isfile(candExe)
            cmd = char(candExe); ok = true; return;
        end
    end

    % Environment variables
    ex = getenv('CONDA_EXE');
    if ~isempty(ex) && isfile(ex), cmd = ex; ok = true; return; end
    ex = getenv('CONDA_BAT');
    if ~isempty(ex) && isfile(ex), cmd = ex; ok = true; return; end

    % PATH
    [st, ~] = system('conda --version');
    if st == 0, ok = true; return; end

    % Fallback: try locating relative to active env
    try
        pe = pyenv;
        if pe.Status == "Loaded"
            envPath = string(fileparts(pe.Executable));
            if isunix && endsWith(envPath, filesep + "bin")
                envPath = string(fileparts(envPath));
            end
            base = envPath;
            if contains(lower(envPath), [filesep 'envs' filesep])
                base = string(fileparts(fileparts(envPath)));
            end
            candBat = fullfile(base, "condabin", "conda.bat");
            candExe = fullfile(base, "Scripts",  "conda.exe");
            if isfile(candBat)
                cmd = char(candBat); ok = true; return;
            elseif isfile(candExe)
                cmd = char(candExe); ok = true; return;
            end
        end
    catch
    end

    if debug
        fprintf('[PYDEPS] conda not found on PATH; will fallback to pip.\n');
    end
end
