function info = select_and_load_conda_env(varargin)
% SELECT_AND_LOAD_CONDA_ENV (GUI optionnel + préférences + self-heal pyenv)
% - Teste d'abord l'environnement Python actuel (si Loaded) :
%     * si OK => on le garde (résumé imprimé)
%     * si KO => terminate(pyenv) puis sélection d'un conda env
% - Récupère la liste des envs conda via JSON
% - Sélection via GUI (listdlg) si 'use_gui' et GUI dispo, sinon prompt console
% - Options (Name,Value):
%     'debug'        (logical, default true)
%     'use_gui'      (logical, default true)   % fallback console si GUI indisponible
%     'preferred'    (string, default "" )     % nom OU chemin de l'env à pré-sélectionner
%     'auto_select'  (logical, default false)  % si preferred matche => choisir sans demander
%     'classif'      (classi handle)           % use/save classif.runProfiles.pythonEnv
%
% Renvoie une struct 'info' (env choisi + résumé torch/sys).

    % -------- Parse options --------
    opts = struct('debug', true, 'use_gui', true, 'preferred', "", 'auto_select', false, 'classif', []);
    if mod(nargin,2)~=0
        error('Arguments must be Name,Value pairs.');
    end
    for k = 1:2:nargin
        name = lower(string(varargin{k}));
        val  = varargin{k+1};
        switch name
            case "debug",       opts.debug = logical(val);
            case "use_gui",     opts.use_gui = logical(val);
            case "preferred",   opts.preferred = string(val);
            case "auto_select", opts.auto_select = logical(val);
            case "classif",     opts.classif = val;
            otherwise, error('Unknown option "%s".', name);
        end
    end
    debug = opts.debug;

    % If classif provided and has saved python env, prefer it and auto-select.
    if opts.preferred == "" && ~isempty(opts.classif)
        pref = getClassifPreferred(opts.classif);
        if pref ~= ""
            opts.preferred = pref;
            opts.auto_select = true;
            if debug
                fprintf('[DEBUG] Using saved python env from classif.runProfiles.pythonEnv: %s\n', char(pref));
            end
        end
    end

    % -------- 0) Si Python déjà chargé, tester santé --------
    pe = pyenv;
    if pe.Status == "Loaded"
        if debug, fprintf('[DEBUG] pyenv loaded -> quick health check...\n'); end
        [ok, sysver, torchInfo] = quickPythonHealthCheck(debug);
        if ok
            if debug
                fprintf('[DEBUG] Current pyenv is healthy. Keeping it.\n');
                printSummary(pe, sysver, torchInfo);
            end
            info = packInfoExisting(pe, sysver, torchInfo, debug);
            envPath = string(fileparts(pe.Executable));
            envName = getLastPathComponent(envPath);
            tryStoreClassifEnv(opts.classif, envName, envPath, string(pe.Executable), debug);
            return;
        else
            if debug, fprintf('[DEBUG] Current pyenv unhealthy -> terminate(pyenv) and select a conda env.\n'); end
            try, terminate(pyenv); catch, end
        end
    end

    % -------- 1) Préparation conda (Win via finder, Unix via bash -lic) --------
    if ispc
        condaCmd = findCondaCmd(debug);
        if debug, fprintf('[DEBUG] Using conda command: %s\n', condaCmd); end
    else
        condaCmd = 'conda'; %#ok<NASGU> % non utilisé directement (runConda encapsule conda-init)
        if debug, fprintf('[DEBUG] Unix: conda via bash -lic "conda-init; conda ..."\n'); end
    end

    % -------- 2) Lister les envs --------
    [data, rawOut, src] = getCondaEnvs(debug,condaCmd);
    if debug, fprintf('[DEBUG] Envs source: %s | JSON length: %d chars\n', src, strlength(string(rawOut))); end
    if ~isfield(data,'envs') || isempty(data.envs)
        rawShort = char(string(rawOut)); if numel(rawShort)>500, rawShort = [rawShort(1:500) ' ... [truncated]']; end
        error('No environments found in conda JSON. Raw (first 500 chars):\n%s', rawShort);
    end
    envPaths = string(data.envs);
    if debug, fprintf('[DEBUG] %d environments reported by conda.\n', numel(envPaths)); end

    defPrefix = "";
    if isfield(data,'default_prefix') && ~isempty(data.default_prefix)
        defPrefix = string(data.default_prefix);
        if debug, fprintf('[DEBUG] default_prefix: %s\n', defPrefix); end
    end

    % -------- 3) Construire la liste --------
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


    % Trouver l'index par défaut (base ou preferred)
    defIdx = pickDefaultIndex(envList, defPrefix, opts.preferred);

    % -------- 4) Affichage + sélection (GUI optionnel) --------
   % -------- 4) Affichage + sélection (GUI optionnel, fallback console) --------
fprintf('\nAvailable environments:\n');
for i = 1:numel(envList)
    existsTag = '[MISSING]';
    if exist(char(envList(i).python), 'file') == 2, existsTag = '[exists]'; end
    fprintf('  [%d] %-20s %s\n', i, char(envList(i).name), char(envList(i).path));
    if debug
        fprintf('       python: %s %s\n', char(envList(i).python), existsTag);
    end
end

% Calcule l'index par défaut de façon robuste
defIdx = pickDefaultIndex(envList, defPrefix, opts.preferred);  % ta fonction existante si tu l'as gardée
if isempty(defIdx), defIdx = 1; end
defIdx = max(1, min(defIdx, numel(envList)));  % clamp 1..N

% Construit ListString en cell array de char (robuste sur toutes versions)
names = string({envList.name});
paths = string({envList.path});
listStr = cellstr(names + "  -  " + paths);

prefIdx = findPreferredIndex(envList, opts.preferred);
idx = [];
useUI = false;
if opts.auto_select && ~isempty(prefIdx)
    idx = prefIdx;
    fprintf('[CONDA] Auto-selecting saved env: %s (%s)\n', char(envList(idx).name), char(envList(idx).path));
elseif opts.auto_select && opts.preferred ~= ""
    fprintf('[CONDA] Saved env not found: %s. Falling back to selection.\n', char(opts.preferred));
end
if isempty(idx) && opts.use_gui && usejava('awt') && feature('ShowFigureWindows')
    useUI = true;
    try
        [idx, ok] = listdlg( ...
            'PromptString','Select a Conda environment:', ...
            'SelectionMode','single', ...
            'ListString', listStr, ...
            'InitialValue', defIdx, ...
            'ListSize',[800 350]);
        if ~(ok && ~isempty(idx))
            % Si l'utilisateur annule ou que la GUI ne s'affiche pas correctement, fallback console
            idx = [];
            useUI = false;
        end
    catch
        idx = [];
        useUI = false;
    end
end

if isempty(idx)
    prompt = sprintf('Enter the number to use [%d=%s]: ', defIdx, char(envList(defIdx).name));
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
end

if debug
    method = tern(useUI,'UI','console');
    if opts.auto_select && ~isempty(prefIdx)
        method = 'auto';
    end
    fprintf('[DEBUG] Selection method: %s | index=%d\n', method, idx);
end

chosen = envList(idx);
if ~isfile(chosen.python)
    error('Python executable not found: %s', chosen.python);
end


    % -------- 5) Configurer pyenv (OutOfProcess) --------
    if debug, fprintf('[DEBUG] Setting pyenv to: %s (OutOfProcess)\n', char(chosen.python)); end
    pe = pyenv;
    if pe.Status == "Loaded"
        if ~strcmpi(char(pe.Executable), char(chosen.python))
            if debug, fprintf('[DEBUG] Terminating existing Python engine...\n'); end
            try, terminate(pyenv); catch, end
        end
    end
    pe = pyenv('Version', char(chosen.python), 'ExecutionMode', 'OutOfProcess');

    % -------- 6) Vérifs sys + torch --------
       % -------- 6) Vérifs sys + torch --------
    okSys    = false; 
    pyVer    = "";
    okTorch  = false; 
    torchVer = ""; 
    torchCUDA = ""; 
    torchAvail = false;

    % ----- sys -----
    try
        pysys = py.importlib.import_module('sys');
        pyVer = toStringSafe(pysys.("version"));
        okSys = true;
        if debug
            fprintf('[DEBUG] sys.version: %s\n', char(pyVer));
        end
    catch ME
        warning('Import "sys" failed: %s\n', ME.message);
        terminate(pyenv);
    end

    % ----- torch (import "silencieux") -----
    try
        % On coupe TEMPORAIREMENT tous les warnings MATLAB pendant l'import de torch,
        % car PyTorch/NumPy déclenchent des warnings du style :
        % "The name 'eq' is already in use as a method name. This will become an error..."
        oldWarn = warning;                       % snapshot config
        warning('off','all');
        c = onCleanup(@() warning(oldWarn));     % restauration auto

        % evalc pour capturer aussi toute sortie texte côté Python
        evalc('torch = py.importlib.import_module(''torch'');');

        okTorch  = true;
        torchVer = toStringSafe(py.getattr(torch, '__version__'));
        tv       = py.getattr(torch, 'version');
        torchCUDA= toStringSafe(py.getattr(tv, 'cuda'));
        tc       = py.getattr(torch, 'cuda');
        is_av_fn = py.getattr(tc, 'is_available');
        torchAvail = toBoolSafe(is_av_fn());

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
        terminate(pyenv);
    end


    % -------- 7) Rapport + sortie --------
    printFinal(pe, okSys, pyVer, okTorch, torchVer, torchCUDA, torchAvail);

    info = struct( ...
        'name', chosen.name, ...
        'path', chosen.path, ...
        'python', chosen.python, ...
        'pyenv', pe, ...
        'python_sys_version', pyVer, ...
        'torch', struct('installed', okTorch, 'version', torchVer, 'cuda', torchCUDA, 'is_available', torchAvail), ...
        'debug', debug ...
    );
    tryStoreClassifEnv(opts.classif, chosen.name, chosen.path, chosen.python, debug);
end

% =================== Helpers ===================

function [ok, sysver, torchInfo] = quickPythonHealthCheck(debug)
    ok = false;
    sysver = "";
    torchInfo = struct('installed',false,'version',"",'cuda',"",'is_available',false);

    % 1) sys.version
    try
        pysys  = py.importlib.import_module('sys');
        sysver = toStringSafe(py.getattr(pysys,'version'));
        ok = true;
    catch ME
        if debug, fprintf('[DEBUG] quick check: sys import failed: %s\n', ME.message); end
        return;
    end

    % 2) torch — import silencieux pour éviter les warnings "cat/eq/…"
    try
        oldWarn = warning;                      %#ok<NASGU>
        warning('off','all');                   % coupe tous les warnings TEMPORAIREMENT
        c = onCleanup(@() warning('on','all')); % restaure à la sortie
        evalc('py.importlib.invalidate_caches();');
        evalc('torch = py.importlib.import_module(''torch'');');

        % Attributs ciblés (pas de conversion globale)
        torchInfo.installed = true;
        torchInfo.version   = toStringSafe(py.getattr(torch,'__version__'));

        vermod = py.getattr(torch,'version');
        torchInfo.cuda = toStringSafe(py.getattr(vermod,'cuda'));

        cudamod = py.getattr(torch,'cuda');
        is_av   = py.getattr(cudamod,'is_available');
        torchInfo.is_available = toBoolSafe(is_av());
    catch ME
        if debug, fprintf('[DEBUG] quick check: torch inspect failed: %s\n', ME.message); end
        % torch absent -> Python OK quand même
    end
end


function printFinal(pe, okSys, pyVer, okTorch, torchVer, torchCUDA, torchAvail)
    if torchCUDA == "", torchCUDA = "(None)"; end
    av = "false"; if torchAvail, av = "true"; end

    fprintf('\n=== MATLAB Python Configuration ===\n');
    fprintf('Python exe     : %s\n', char(pe.Executable));
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
            char(torchVer), char(torchCUDA), char(av));
    else
        fprintf('Torch          : not installed (or import failed)\n');
    end
    fprintf('===================================\n');
end

function printSummary(pe, sysver, torchInfo)
    fprintf('\n=== Python already loaded in MATLAB ===\n');
    fprintf('Python exe     : %s\n', char(pe.Executable));
    fprintf('pyenv.Status   : %s\n', char(string(pe.Status)));
    fprintf('pyenv.Mode     : %s\n', char(string(pe.ExecutionMode)));
    fprintf('pyenv.Version  : %s\n', char(string(pe.Version)));
    fprintf('Python (sys)   : %s\n', char(sysver));
    fprintf('Torch installed: %d\n', torchInfo.installed);
    if torchInfo.installed
        tc = torchInfo.cuda; if tc == "", tc = "(None)"; end
        fprintf('Torch version  : %s | CUDA: %s | is_available: %d\n', ...
            torchInfo.version, tc, torchInfo.is_available);
    end
    fprintf('=======================================\n');
end

function info = packInfoExisting(pe, sysver, torchInfo, debug)
    info = struct( ...
        'name', "(existing)", ...
        'path', fileparts(pe.Executable), ...
        'python', string(pe.Version), ...
        'pyenv', pe, ...
        'python_sys_version', sysver, ...
        'torch', torchInfo, ...
        'debug', debug ...
    );
end

function printEnvList(envList, debug)
    fprintf('\nAvailable environments:\n');
    for i = 1:numel(envList)
        existsTag = '[MISSING]';
        if exist(char(envList(i).python), 'file') == 2, existsTag = '[exists]'; end
        fprintf('  [%d] %-20s %s\n', i, char(envList(i).name), char(envList(i).path));
        if debug
            fprintf('       python: %s %s\n', char(envList(i).python), existsTag);
        end
    end
end

function defIdx = pickDefaultIndex(envList, defPrefix, preferred)
    defIdx = [];
    % 1) preferred par chemin
    if preferred ~= ""
        for i=1:numel(envList)
            if strcmpi(char(envList(i).path), char(preferred))
                defIdx = i; return;
            end
        end
        % 2) preferred par nom
        for i=1:numel(envList)
            if strcmpi(char(envList(i).name), char(preferred))
                defIdx = i; return;
            end
        end
    end
    % 3) base / default_prefix
    if defPrefix ~= ""
        for i=1:numel(envList)
            if envList(i).path == defPrefix
                defIdx = i; return;
            end
        end
    end
    % 4) fallback
    if isempty(defIdx), defIdx = 1; end
end

function idx = findPreferredIndex(envList, preferred)
    idx = [];
    if preferred == ""
        return;
    end
    for i = 1:numel(envList)
        if strcmpi(char(envList(i).path), char(preferred)) ...
                || strcmpi(char(envList(i).name), char(preferred)) ...
                || strcmpi(char(envList(i).python), char(preferred))
            idx = i;
            return;
        end
    end
end

function pref = getClassifPreferred(classif)
    pref = "";
    try
        if isempty(classif), return; end
        if ~isprop(classif,'runProfiles') || ~isstruct(classif.runProfiles), return; end
        if ~isfield(classif.runProfiles,'pythonEnv'), return; end
        pe = classif.runProfiles.pythonEnv;
        if isstruct(pe)
            if isfield(pe,'path') && ~isempty(pe.path)
                pref = string(pe.path);
                return;
            end
            if isfield(pe,'name') && ~isempty(pe.name)
                pref = string(pe.name);
                return;
            end
            if isfield(pe,'python') && ~isempty(pe.python)
                pref = string(pe.python);
                return;
            end
        end
    catch
    end
end

function tryStoreClassifEnv(classif, name, path, python, debug)
    if nargin < 5, debug = false; end
    try
        if isempty(classif), return; end
        if ~isprop(classif,'runProfiles') || ~isstruct(classif.runProfiles)
            classif.runProfiles = struct();
        end
        classif.runProfiles.pythonEnv = struct( ...
            'name', char(string(name)), ...
            'path', char(string(path)), ...
            'python', char(string(python)) ...
        );
        if debug
            fprintf('[DEBUG] Saved python env to classif.runProfiles.pythonEnv: %s\n', char(string(path)));
        end
    catch
    end
end

function [st,out] = runConda(subcmd, debug, condaCmd)
    if isunix
        cmd = sprintf('bash -lic "conda-init; conda %s"', subcmd);
    else
        % condaCmd pointe vers conda.bat OU conda.exe
        cmd = sprintf('cmd /c ""%s" %s"', condaCmd, subcmd);
    end
    [st,out] = system(cmd);

    if debug
        fprintf('[DEBUG] runConda: %s\n[DEBUG] rc=%d\n', cmd, st);
        if ~isempty(out)
            if contains(subcmd,'--json')
                trunc = char(out); if numel(trunc) > 300, trunc = [trunc(1:300) ' ... [truncated]']; end
                fprintf('[DEBUG] out(json): %s\n', trunc);
            else
                fprintf('[DEBUG] out: %s\n', out);
            end
        end
    end
end


function [data, out, src] = getCondaEnvs(debug,condaCmd)
     [st, out] = runConda('info --json', debug, condaCmd);
    if st == 0
        try
            data = jsondecode(out);
            if isfield(data,'envs') && ~isempty(data.envs)
                src = 'conda info --json'; return;
            end
        catch ME
            warnJson(ME, out);
        end
    end
   [st2, out2] = runConda('env list --json', debug, condaCmd);
    if st2 ~= 0, error('Both "conda info --json" and "conda env list --json" failed.'); end
    try
        data = jsondecode(out2); src = 'conda env list --json'; out = out2;
    catch ME
        warnJson(ME, out2); error('JSON parse failed for both commands.');
    end
end

function cmd = findCondaCmd(debug)

        % 0) Try PowerShell: conda may be a PowerShell function, but "conda info --base" works.
    [stPS, outPS] = system('powershell -NoProfile -Command "conda info --base"');
    if stPS == 0
        base = strtrim(string(outPS));
        candBat = fullfile(base, "condabin", "conda.bat");
        candExe = fullfile(base, "Scripts",  "conda.exe");
        if isfile(candBat)
            cmd = char(candBat);
            if debug, fprintf('[DEBUG] conda base via PS: %s\n', cmd); end
            return;
        elseif isfile(candExe)
            cmd = char(candExe);
            if debug, fprintf('[DEBUG] conda base via PS: %s\n', cmd); end
            return;
        end
    end

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
                li = strtrim(lines{i}); if ~isempty(li), candidates{end+1} = li; end
            end
        end
    else
        cmd = 'conda'; return; % non utilisé sous Unix (runConda gère tout)
    end
    % Dédup/probe
    seen = containers.Map('KeyType','char','ValueType','logical'); pruned = {};
    for i = 1:numel(candidates)
        p = candidates{i}; if isempty(p), continue; end
        if isKey(seen,p), continue; end; seen(p) = true; pruned{end+1} = p; %#ok<AGROW>
    end
    for i = 1:numel(pruned)
        p = pruned{i}; testCmd = buildProbeCmd(p);
        [st, out] = system(testCmd);
        if st == 0 && contains(lower(out),'conda')
            if debug, fprintf('[DEBUG] conda OK: %s\n', p); end
            cmd = p; return;
        else
            if debug, fprintf('[DEBUG] Skip conda candidate: %s (rc=%d)\n', p, st); end
        end
    end
    cmd = 'conda';

    error('Conda introuvable depuis MATLAB/cmd. PowerShell ok mais conda.bat/conda.exe non localisé.');
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
    tmp = [tempname,'.json']; fid = fopen(tmp,'w'); if fid>0, fwrite(fid,raw); fclose(fid); end
    warning('JSON decode failed: %s\nRaw saved to: %s', ME.message, tmp);
end

function s = quoteIfNeeded(p)
    if any(isspace(p)), s = ['"' p '"']; else, s = p; end
end

function leaf = getLastPathComponent(p)
    p = char(p);
    if ~isempty(p) && any(p(end) == [filesep '/' '\']), p = p(1:end-1); end
    parts = regexp(p, '[\\/]', 'split'); leaf = string(parts{end});
end

function s = toStringSafe(pyobj)
    if isa(pyobj, 'py.NoneType'), s = ""; return; end
    try, s = string(char(pyobj)); catch, s = string(char(py.str(pyobj))); end
end

function b = toBoolSafe(pybool)
    try, b = logical(pybool); catch, b = logical(pybool == true); end
end

function x = tern(cond, a, b), if cond, x = a; else, x = b; end, end
