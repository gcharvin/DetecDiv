function select_and_load_conda_env(debug)
% SELECT_AND_LOAD_CONDA_ENV (robust, no ternary)
% - Locates conda reliably
% - Lists Conda environments (via "conda info --json" then fallback "conda env list --json")
% - Prompts user to select one (UI if available, else console)
% - Sets pyenv to OutOfProcess and verifies Python / Torch
%
% Usage:
%   info = select_and_load_conda_env();        % debug on
%   info = select_and_load_conda_env(false);   % debug off

    if nargin < 1, debug = true; end
    info = struct();

    % 1) Find conda
    % 0) Check if pyenv is already loaded and usable
pe = pyenv;
if pe.Status == "Loaded"
    if debug
        fprintf('[DEBUG] pyenv already loaded: %s\n', pe.Version);
        fprintf('[DEBUG] Skipping environment selection.\n');
    end

    % Try basic verification
    info = struct();
    info.name = "(existing)";
    info.path = fileparts(pe.Executable);
    info.python = string(pe.Version);
    info.pyenv = pe;
    info.debug = debug;

    try
        pysys = py.importlib.import_module('sys');
        info.python_sys_version = toStringSafe(pysys.version);
    catch
        info.python_sys_version = "(import failed)";
    end

    try
        torch = py.importlib.import_module('torch');
        info.torch = struct( ...
            'installed', true, ...
            'version', toStringSafe(pytorch.("__version__")), ...
            'cuda',    toStringSafe(torch.version.cuda), ...
            'is_available', toBoolSafe(torch.cuda.is_available()) ...
        );
    catch
        info.torch = struct( ...
            'installed', false, ...
            'version', "", ...
            'cuda', "", ...
            'is_available', false ...
        );
    end

    % Affichage de résumé (si debug)
    if debug
        fprintf('\n=== Python already loaded in MATLAB ===\n');
        fprintf('Python exe     : %s\n', char(pe.Executable));
        fprintf('pyenv.Status   : %s\n', char(string(pe.Status)));
        fprintf('pyenv.Version  : %s\n', char(string(pe.Version)));
        fprintf('Torch installed: %d\n', info.torch.installed);
        if info.torch.installed
            fprintf('Torch version  : %s | CUDA: %s | is_available: %d\n', ...
                info.torch.version, info.torch.cuda, info.torch.is_available);
        end
        fprintf('=======================================\n');
    end

    return;
end

% 1) Find conda
condaCmd = findCondaCmd(debug);



    if debug
        fprintf('[DEBUG] Using conda command: %s\n', condaCmd);
    end

    % 2) Query conda for envs
    [data, rawOut, src] = getCondaEnvs(condaCmd, debug);
    if debug
        fprintf('[DEBUG] Envs source: %s | JSON length: %d chars\n', src, strlength(string(rawOut)));
    end

    if ~isfield(data,'envs') || isempty(data.envs)
        rawShort = char(string(rawOut));
        if numel(rawShort) > 500, rawShort = rawShort(1:500); end
        error('No environments found in conda JSON. Raw (first 500 chars):\n%s', rawShort);
    end

    envPaths = string(data.envs);
    if debug
        fprintf('[DEBUG] %d environments reported by conda.\n', numel(envPaths));
    end

    defPrefix = "";
    if isfield(data,'default_prefix') && ~isempty(data.default_prefix)
        defPrefix = string(data.default_prefix);
        if debug, fprintf('[DEBUG] default_prefix: %s\n', defPrefix); end
    end

    % 3) Build env list
    isWindows = ispc;
    envList = struct('name', string.empty, 'path', string.empty, 'python', string.empty);
    for i = 1:numel(envPaths)
        p = envPaths(i);
        if defPrefix ~= "" && p == defPrefix
            name = "base";
        else
            name = getLastPathComponent(p);
        end
        if isWindows
            pyexe = fullfile(p, 'python.exe');
        else
            pyexe = fullfile(p, 'bin', 'python');
        end
        envList(end+1) = struct('name', name, 'path', p, 'python', string(pyexe)); %#ok<AGROW>
    end

    % 4) Show list in console (always)
    fprintf('\nAvailable environments:\n');
    for i = 1:numel(envList)
        existsTag = '[MISSING]';
        if exist(char(envList(i).python), 'file') == 2
            existsTag = '[exists]';
        end
        fprintf('  [%d] %-20s %s\n', i, char(envList(i).name), char(envList(i).path));
        if debug
            fprintf('       python: %s %s\n', char(envList(i).python), existsTag);
        end
    end

    % 5) Selection (UI if possible, else console)
    listStr = strcat(envList(:).name, "  -  ", envList(:).path);
    idx = [];
    usedUI = false;
    try
        [idx, ok] = listdlg('PromptString','Select a Conda environment:', ...
                            'SelectionMode','single', ...
                            'ListString', listStr, ...
                            'ListSize',[800 350]);
        usedUI = true;
        if ~ok
            disp('Cancelled.');
            return;
        end
    catch
        % UI not available; will do console input below
    end

    if isempty(idx)
        sel = input('Enter the number of the environment to use: ');
        if isempty(sel) || ~isscalar(sel) || sel < 1 || sel > numel(envList)
            error('Invalid selection.');
        end
        idx = sel;
    end

    if debug
        if usedUI
            fprintf('[DEBUG] Selection method: UI | index=%d\n', idx);
        else
            fprintf('[DEBUG] Selection method: console | index=%d\n', idx);
        end
    end

    chosen = envList(idx);
    if ~isfile(chosen.python)
        error('Python executable not found: %s', chosen.python);
    end

    % 6) Configure pyenv (OutOfProcess)
    if debug
        fprintf('[DEBUG] Setting pyenv to: %s (OutOfProcess)\n', char(chosen.python));
    end
    pe = pyenv;
    if pe.Status == "Loaded"
        if ~strcmp(char(string(pe.Version)), char(chosen.python))
            if debug, fprintf('[DEBUG] Terminating existing Python engine...\n'); end
            terminate(pyenv);
        end
    end
    pe = pyenv('Version', char(chosen.python), 'ExecutionMode', 'OutOfProcess');

    % 7) Verify sys + torch
    okSys = false; pyVer = "";
    okTorch = false; torchVer = ""; torchCUDA = ""; torchAvail = false;

    try
        pysys = py.importlib.import_module('sys');
        pyVer = toStringSafe(pysys.("version"));
        okSys = true;
        if debug
            fprintf('[DEBUG] sys.version: %s\n', char(pyVer));
        end
    catch ME
        warning('Import "sys" failed: %s', ME.message);
    end

    try
        pytorch   = py.importlib.import_module('torch');
        okTorch   = true;
        torchVer  = toStringSafe(pytorch.("__version__"));
        torchCUDA = toStringSafe(pytorch.version.("cuda"));  % may be None
        torchAvail= toBoolSafe(pytorch.cuda.is_available());
        if debug
            if torchCUDA == ""
                tcdisp = "(None)";
            else
                tcdisp = torchCUDA;
            end
            if torchAvail
                avdisp = "true";
            else
                avdisp = "false";
            end
            fprintf('[DEBUG] torch.__version__: %s | torch.version.cuda: %s | cuda.is_available(): %s\n', ...
                char(torchVer), char(tcdisp), char(avdisp));
        end
    catch ME
        if debug
            fprintf('[DEBUG] Torch import failed: %s\n', ME.message);
        end
    end

    % Printable values
    if torchCUDA == ""
        torchCUDA_disp = "(None)";
    else
        torchCUDA_disp = torchCUDA;
    end
    if torchAvail
        availStr = "true";
    else
        availStr = "false";
    end

    % 8) Report
    fprintf('\n=== MATLAB Python Configuration ===\n');
    fprintf('Selected env   : %s\n', char(chosen.name));
    fprintf('Python exe     : %s\n', char(chosen.python));
    fprintf('pyenv.Status   : %s\n', char(string(pe.Status)));
    fprintf('pyenv.Mode     : %s\n', char(string(pe.ExecutionMode)));
    fprintf('pyenv.Version  : %s\n', char(string(pe.Version)));
    if okSys
        fprintf('Python (sys)   : %s\n', char(pyVer));
    else
        fprintf('Python (sys)   : import failed\n');
    end
    if okTorch
        fprintf('Torch          : %s | CUDA: %s | cuda.is_available(): %s\n', ...
            char(torchVer), char(torchCUDA_disp), char(availStr));
    else
        fprintf('Torch          : not installed (or import failed)\n');
    end
    fprintf('===================================\n');

    % % 9) Return struct
    % info = struct( ...
    %     'name', chosen.name, ...
    %     'path', chosen.path, ...
    %     'python', chosen.python, ...
    %     'pyenv', pe, ...
    %     'python_sys_version', pyVer, ...
    %     'torch', struct('installed', okTorch, 'version', torchVer, 'cuda', torchCUDA, 'is_available', torchAvail), ...
    %     'debug', debug ...
    % );
end

% ===== helpers =====

function cmd = findCondaCmd(debug)
    cands = {};
    ex = getenv('CONDA_EXE'); if ~isempty(ex), cands{end+1} = ex; end %#ok<AGROW>
    ex = getenv('CONDA_BAT'); if ~isempty(ex), cands{end+1} = ex; end %#ok<AGROW>
    if ispc
        up = getenv('USERPROFILE');
        cands = [cands, { ...
            fullfile('C:\tools','Anaconda3','condabin','conda.bat'), ...
            fullfile(up,'anaconda3','condabin','conda.bat'), ...
            fullfile(up,'miniconda3','condabin','conda.bat')}];
        [st, out] = system('where conda');
        if st == 0
            lines = strsplit(strtrim(out), {'\r','\n'});
            for i=1:numel(lines)
                if ~isempty(lines{i}), cands{end+1} = strtrim(lines{i}); end %#ok<AGROW>
            end
        end
    else
        cands = [cands, {'conda'}];
    end
    % Dedup and probe
    seen = containers.Map('KeyType','char','ValueType','logical');
    for i = 1:numel(cands)
        p = cands{i};
        if isempty(p), continue; end
        if isKey(seen,p), continue; end
        seen(p) = true;
        test = sprintf('%s --version', quoteIfNeeded(p));
        [st, out] = system(test);
        if st == 0 && contains(lower(out),'conda')
            cmd = p; return;
        else
            if debug
                fprintf('[DEBUG] Skip conda candidate: %s (rc=%d)\n', p, st);
            end
        end
    end
    cmd = 'conda'; % last resort
end

function [data, out, src] = getCondaEnvs(condaCmd, debug)
    % Try "conda info --json" first
    cmd = sprintf('%s info --json', quoteIfNeeded(condaCmd));
    [st, out] = system(cmd);
    if debug
        fprintf('[DEBUG] Run: %s | rc=%d | out.len=%d\n', cmd, st, strlength(string(out)));
    end
    if st == 0
        try
            data = jsondecode(out);
            if isfield(data,'envs') && ~isempty(data.envs)
                src = 'conda info --json';
                return;
            end
        catch ME
            warnJson(ME, out);
        end
    end
    % Fallback: "conda env list --json"
    cmd = sprintf('%s env list --json', quoteIfNeeded(condaCmd));
    [st2, out2] = system(cmd);
    if debug
        fprintf('[DEBUG] Run: %s | rc=%d | out.len=%d\n', cmd, st2, strlength(string(out2)));
    end
    if st2 ~= 0
        error('Both "conda info --json" and "conda env list --json" failed.');
    end
    try
        data = jsondecode(out2);
        src = 'conda env list --json';
        out = out2;
    catch ME
        warnJson(ME, out2);
        error('JSON parse failed for both commands.');
    end
end

function warnJson(ME, raw)
    tmp = [tempname,'.json'];
    fid = fopen(tmp,'w'); if fid>0, fwrite(fid,raw); fclose(fid); end
    warning('JSON decode failed: %s\nRaw saved to: %s', ME.message, tmp);
end

function s = quoteIfNeeded(p)
    if any(isspace(p)), s = ['"' p '"']; else, s = p; end
end

function leaf = getLastPathComponent(p)
    p = char(p);
    if ~isempty(p) && (p(end) == filesep || p(end) == '/' || p(end) == '\')
        p = p(1:end-1);
    end
    parts = regexp(p, '[\\/]', 'split');
    leaf = string(parts{end});
end

function s = toStringSafe(pyobj)
    if isa(pyobj, 'py.NoneType')
        s = "";
        return;
    end
    try
        s = string(char(pyobj));
    catch
        s = string(char(py.str(pyobj)));
    end
end

function b = toBoolSafe(pybool)
    try
        b = logical(pybool);
    catch
        b = logical(pybool == true);
    end
end
