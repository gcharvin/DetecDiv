function info = select_and_load_conda_env(debug)
% SELECT_AND_LOAD_CONDA_ENV
% - Linux/macOS : exécute conda via "bash -lic" et lance "conda-init" avant
% - Windows     : détecte conda.exe/conda.bat et appelle directement
% - Liste les environnements conda (JSON), sélection UI/console
% - Configure pyenv (OutOfProcess)
% - Vérifie Python + Torch (version/CUDA/cuda.is_available)
%
% Usage:
%   info = select_and_load_conda_env();        % debug on
%   info = select_and_load_conda_env(false);   % debug off

    if nargin < 1, debug = true; end
    info = struct();

    % 0) Déjà chargé ?
    pe = pyenv;
    if pe.Status == "Loaded"
        if debug
            fprintf('[DEBUG] pyenv already loaded: %s\n', pe.Version);
            fprintf('[DEBUG] Skipping environment selection.\n');
        end

        info = struct();
        info.name    = "(existing)";
        info.path    = fileparts(pe.Executable);
        info.python  = string(pe.Version);
        info.pyenv   = pe;
        info.debug   = debug;

        % sys.version
        try
            pysys = py.importlib.import_module('sys');
            info.python_sys_version = toStringSafe(pysys.version);
        catch
            info.python_sys_version = "(import failed)";
        end

        % torch
        try
            torch = py.importlib.import_module('torch');
            % Utiliser getattr pour __version__ et modules imbriqués
            tver      = toStringSafe(py.getattr(torch, '__version__'));
            torchver  = py.getattr(torch, 'version');
            cudaAttr  = toStringSafe(py.getattr(torchver, 'cuda')); % peut être None
            tcuda     = py.getattr(torch, 'cuda');
            is_av_fun = py.getattr(tcuda, 'is_available');
            is_av     = toBoolSafe(is_av_fun());

            info.torch = struct( ...
                'installed',     true, ...
                'version',       tver, ...
                'cuda',          cudaAttr, ...
                'is_available',  is_av ...
            );
        catch
            info.torch = struct( ...
                'installed', false, ...
                'version',   "", ...
                'cuda',      "", ...
                'is_available', false ...
            );
        end

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

    % 1) Préparation conda (Windows: chemin, Unix: via bash -lic)
    if ispc
        condaCmd = findCondaCmd(debug);
        if debug, fprintf('[DEBUG] Using conda command: %s\n', condaCmd); end
    else
        % Sous Unix, non utilisé directement (runConda encapsule conda-init)
        condaCmd = 'conda'; %#ok<NASGU>
        if debug
            fprintf('[DEBUG] Unix: conda will be invoked via bash -lic "conda-init; conda ..."\n');
        end
    end

    % 2) Récup envs
    [data, rawOut, src] = getCondaEnvs(debug);
    if debug
        fprintf('[DEBUG] Envs source: %s | JSON length: %d chars\n', src, strlength(string(rawOut)));
    end
    if ~isfield(data,'envs') || isempty(data.envs)
        rawShort = char(string(rawOut));
        if numel(rawShort) > 500, rawShort = [rawShort(1:500) ' ... [truncated]']; end
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

    % 3) Construire la liste sans "entrée fantôme"
envList = struct('name', {}, 'path', {}, 'python', {});

    for i = 1:numel(envPaths)
        p = envPaths(i);
        if defPrefix ~= "" && p == defPrefix
            name = "base";
        else
            name = getLastPathComponent(p);
        end
        if ispc
            pyexe = fullfile(p, 'python.exe');
        else
            pyexe = fullfile(p, 'bin', 'python');
        end
        envList(end+1) = struct('name', name, 'path', p, 'python', string(pyexe)); %#ok<AGROW>
    end

% 4) Affichage console (uniquement, pas de GUI)
fprintf('\nAvailable environments:\n');
defIdx = [];
for i = 1:numel(envList)
    if defPrefix ~= "" && envList(i).path == defPrefix
        defIdx = i;  % base par défaut si présente
    end
    existsTag = '[MISSING]';
    if exist(char(envList(i).python), 'file') == 2
        existsTag = '[exists]';
    end
    fprintf('  [%d] %-20s %s\n', i, char(envList(i).name), char(envList(i).path));
    if debug
        fprintf('       python: %s %s\n', char(envList(i).python), existsTag);
    end
end
if isempty(defIdx), defIdx = 1; end  % fallback si pas de default_prefix

% 5) Sélection via prompt
prompt = sprintf('Enter the number of the environment to use [%d=%s]: ', ...
                 defIdx, char(envList(defIdx).name));
sel = input(prompt, 's');
if isempty(sel)
    idx = defIdx;
else
    v = str2double(sel);
    if ~isfinite(v) || v < 1 || v > numel(envList)
        error('Invalid selection: %s', sel);
    end
    idx = round(v);
end

if debug
    fprintf('[DEBUG] Selection method: console | index=%d\n', idx);
end
chosen = envList(idx);
if ~isfile(chosen.python)
    error('Python executable not found: %s', chosen.python);
end

    % 6) pyenv OutOfProcess
    if debug
        fprintf('[DEBUG] Setting pyenv to: %s (OutOfProcess)\n', char(chosen.python));
    end
    pe = pyenv;
    if pe.Status == "Loaded"
        if ~strcmpi(char(pe.Executable), char(chosen.python))
            if debug, fprintf('[DEBUG] Terminating existing Python engine...\n'); end
            terminate(pyenv);
        end
    end
    pe = pyenv('Version', char(chosen.python), 'ExecutionMode', 'OutOfProcess');

    % 7) Vérifs sys + torch (via getattr)
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
        torch     = py.importlib.import_module('torch');
        okTorch   = true;
        torchVer  = toStringSafe(py.getattr(torch, '__version__'));
        tv        = py.getattr(torch, 'version');
        torchCUDA = toStringSafe(py.getattr(tv, 'cuda'));  % peut être None
        tc        = py.getattr(torch, 'cuda');
        is_av_fn  = py.getattr(tc, 'is_available');
        torchAvail= toBoolSafe(is_av_fn());
        if debug
            tcdisp = torchCUDA; if tcdisp == "", tcdisp = "(None)"; end
            avdisp = tern(torchAvail, "true", "false");
            fprintf('[DEBUG] torch.__version__: %s | torch.version.cuda: %s | cuda.is_available(): %s\n', ...
                char(torchVer), char(tcdisp), char(avdisp));
        end
    catch ME
        if debug
            fprintf('[DEBUG] Torch import failed: %s\n', ME.message);
        end
    end

    % 8) Rapport
    torchCUDA_disp = torchCUDA; if torchCUDA_disp == "", torchCUDA_disp = "(None)"; end
    availStr = tern(torchAvail, "true", "false");

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

    % 9) Sortie
    info = struct( ...
        'name', chosen.name, ...
        'path', chosen.path, ...
        'python', chosen.python, ...
        'pyenv', pe, ...
        'python_sys_version', pyVer, ...
        'torch', struct('installed', okTorch, 'version', torchVer, 'cuda', torchCUDA, 'is_available', torchAvail), ...
        'debug', debug ...
    );
end

% =================== Helpers ===================

function [st,out] = runConda(subcmd, debug)
% Exécute une sous-commande conda de manière robuste selon l'OS.
% Unix : bash -lic "conda-init; conda <subcmd>"
% Win  : "<path_to_conda>" <subcmd>
    if isunix
        cmd = sprintf('bash -lic "conda-init; conda %s"', subcmd);
    else
        cmd = sprintf('%s %s', quoteIfNeeded(findCondaCmd(false)), subcmd);
    end
    [st,out] = system(cmd);
    if debug
        fprintf('[DEBUG] runConda: %s\n[DEBUG] rc=%d\n', cmd, st);
        if ~isempty(out)
            if contains(subcmd,'--json')
                trunc = char(out);
                if numel(trunc) > 300, trunc = [trunc(1:300) ' ... [truncated]']; end
                fprintf('[DEBUG] out(json): %s\n', trunc);
            else
                fprintf('[DEBUG] out: %s\n', out);
            end
        end
    end
end

function [data, out, src] = getCondaEnvs(debug)
% Interroge conda (info --json puis fallback env list --json) via runConda.
    [st, out] = runConda('info --json', debug);
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
    [st2, out2] = runConda('env list --json', debug);
    if st2 ~= 0
        error('Both "conda info --json" and "conda env list --json" failed.');
    end
    try
        data = jsondecode(out2);
        src  = 'conda env list --json';
        out  = out2;
    catch ME
        warnJson(ME, out2);
        error('JSON parse failed for both commands.');
    end
end

function cmd = findCondaCmd(debug)
% Windows : détecte conda.exe/.bat ou 'conda' sur le PATH.
    candidates = {};
    ex = getenv('CONDA_EXE'); if ~isempty(ex), candidates{end+1} = ex; end
    ex = getenv('CONDA_BAT'); if ~isempty(ex), candidates{end+1} = ex; end

    if ispc
        up = getenv('USERPROFILE');
        candidates = [candidates, { ...
            fullfile('C:\tools','Anaconda3','Scripts','conda.exe'), ...
            fullfile('C:\tools','Anaconda3','condabin','conda.bat'), ...
            fullfile(up,'anaconda3','Scripts','conda.exe'), ...
            fullfile(up,'anaconda3','condabin','conda.bat'), ...
            fullfile(up,'miniconda3','Scripts','conda.exe'), ...
            fullfile(up,'miniconda3','condabin','conda.bat')}];

        [st, out] = system('where conda');
        if st == 0
            lines = strsplit(strtrim(out), {'\r','\n'});
            for i = 1:numel(lines)
                li = strtrim(lines{i});
                if ~isempty(li), candidates{end+1} = li; end
            end
        end
    else
        cmd = 'conda'; % Sous Unix, non utilisé (runConda gère tout)
        return;
    end

    % Dédup
    seen = containers.Map('KeyType','char','ValueType','logical');
    pruned = {};
    for i = 1:numel(candidates)
        p = candidates{i};
        if isempty(p), continue; end
        if isKey(seen, p), continue; end
        seen(p) = true;
        pruned{end+1} = p; %#ok<AGROW>
    end

    % Probe
    for i = 1:numel(pruned)
        p = pruned{i};
        testCmd = buildProbeCmd(p);
        [st, out] = system(testCmd);
        if st == 0 && contains(lower(out), 'conda')
            if debug, fprintf('[DEBUG] conda OK: %s\n', p); end
            cmd = p; return;
        else
            if debug, fprintf('[DEBUG] Skip conda candidate: %s (rc=%d)\n', p, st); end
        end
    end

    cmd = 'conda'; % dernier recours
end

function c = buildProbeCmd(p)
    if ispc
        if endsWith(lower(p), '.bat')
            c = sprintf('cmd /c "%s --version"', p);
        else
            c = sprintf('"%s" --version', p);
        end
    else
        c = sprintf('%s --version', p);
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

function x = tern(cond, a, b)
    if cond, x = a; else, x = b; end
end
