function info = select_and_load_conda_env(varargin)
% SELECT_AND_LOAD_CONDA_ENV (forced detecdiv_python + self-heal)
%
% Strategy (standardised):
%   - If pyenv is already Loaded AND OutOfProcess AND passes a quick health check:
%       -> keep it and return summary
%   - Otherwise:
%       1) Resolve conda command (prefs path first, then PATH)
%          - store absolute conda path in userprefs (editable later in GUI via struct2GUI)
%       2) Ensure conda env "detecdiv_python" exists (python=3.10)
%       3) Ensure required packages:
%            - torch (GPU: pytorch-cuda=12.1 if NVIDIA detected, else CPU)
%            - cellpose (Cellpose-SAM) via pip "cellpose[gui]"
%          and verify torch execution (version + cuda availability)
%       4) Set MATLAB pyenv to detecdiv_python (OutOfProcess)
%       5) Print final report + return info struct
%
% Options (Name,Value):
%   'debug'   (logical, default true)

    % -------- Parse options --------
    opts = struct('debug', true);
    if mod(nargin,2)~=0
        error('Arguments must be Name,Value pairs.');
    end
    for k = 1:2:nargin
        name = lower(string(varargin{k}));
        val  = varargin{k+1};
        switch name
            case "debug", opts.debug = logical(val);
            otherwise, error('Unknown option "%s".', name);
        end
    end
    debug = opts.debug;

    fprintf('\n[Detecdiv] Python bootstrap starting...\n');

    % -------- 0) If Python already loaded: require Loaded + OutOfProcess + healthy --------
    pe = pyenv;
    if pe.Status == "Loaded"
        fprintf('[Detecdiv] Detected existing pyenv: Loaded (mode=%s)\n', char(string(pe.ExecutionMode)));

        if string(pe.ExecutionMode) ~= "OutOfProcess"
            fprintf('[Detecdiv] Existing pyenv is not OutOfProcess -> terminating...\n');
            try, terminate(pyenv); catch, end
        else
            fprintf('[Detecdiv] Existing pyenv is OutOfProcess -> quick health check...\n');
            [ok, sysver, torchInfo] = quickPythonHealthCheck(debug);
            if ok
                fprintf('[Detecdiv] Existing pyenv is healthy -> keeping it.\n');
                printSummary(pe, sysver, torchInfo);
                info = packInfoExisting(pe, sysver, torchInfo, debug);
                return;
            else
                fprintf('[Detecdiv] Existing pyenv unhealthy -> terminating...\n');
                try, terminate(pyenv); catch, end
            end
        end
    else
        fprintf('[Detecdiv] No active pyenv (Status=%s)\n', char(string(pe.Status)));
    end

    % -------- 1) Resolve conda command (prefs/path) --------
    fprintf('[Detecdiv] Step 1/5: Resolving conda...\n');
    userprefs = dd_loadUserPrefs();
    [condaCmd, userprefs] = resolveCondaCmd(userprefs, debug);
    dd_saveUserPrefs(userprefs);
    fprintf('[Detecdiv] Conda command: %s\n', char(condaCmd));

    % -------- 2) Ensure env detecdiv_python (python=3.10) --------
    fprintf('[Detecdiv] Step 2/5: Ensuring conda env "detecdiv_python" (python=3.10)...\n');
    [detPath, detPy] = ensureDetecdivEnv(condaCmd, debug);
    fprintf('[Detecdiv] detecdiv_python path: %s\n', char(detPath));
    fprintf('[Detecdiv] detecdiv_python python: %s\n', char(detPy));

    % -------- 3) Ensure packages (torch + cellpose) --------
    fprintf('[Detecdiv] Step 3/5: Ensuring required Python packages (torch + cellpose)...\n');
    ensureDetecdivPackages(condaCmd, debug);

    % -------- 4) Configure MATLAB pyenv to detecdiv_python (OutOfProcess) --------
    fprintf('[Detecdiv] Step 4/5: Configuring MATLAB pyenv (OutOfProcess)...\n');
    pe = pyenv;
    if pe.Status == "Loaded"
        if ~strcmpi(char(pe.Executable), char(detPy)) || string(pe.ExecutionMode) ~= "OutOfProcess"
            fprintf('[Detecdiv] Terminating existing Python engine...\n');
            try, terminate(pyenv); catch, end
        end
    end
    pe = pyenv('Version', char(detPy), 'ExecutionMode', 'OutOfProcess');

    % -------- 5) Final checks + report --------
    fprintf('[Detecdiv] Step 5/5: Final checks (sys + torch import in MATLAB)...\n');
    [okSys, pyVer, okTorch, torchVer, torchCUDA, torchAvail] = matlabTorchChecks(debug);

    printFinal(pe, okSys, pyVer, okTorch, torchVer, torchCUDA, torchAvail);

    info = struct( ...
        'name', "detecdiv_python", ...
        'path', string(detPath), ...
        'python', string(detPy), ...
        'pyenv', pe, ...
        'python_sys_version', string(pyVer), ...
        'torch', struct('installed', okTorch, 'version', string(torchVer), 'cuda', string(torchCUDA), 'is_available', logical(torchAvail)), ...
        'debug', debug ...
    );
end

% =================== Helpers ===================

function [ok, sysver, torchInfo] = quickPythonHealthCheck(debug)
    % "Healthy" here:
    %   - sys import works
    %   - torch import may fail (not mandatory to declare Python broken),
    %     but we still report it.
    ok = false;
    sysver = "";
    torchInfo = struct('installed',false,'version',"",'cuda',"",'is_available',false);

    try
        pysys  = py.importlib.import_module('sys');
        sysver = toStringSafe(py.getattr(pysys,'version'));
        ok = true;
    catch ME
        if debug, fprintf('[DEBUG] quick check: sys import failed: %s\n', ME.message); end
        return;
    end

    try
        oldWarn = warning;
        warning('off','all');
        c = onCleanup(@() warning(oldWarn));

        evalc('py.importlib.invalidate_caches();');
        evalc('torch = py.importlib.import_module(''torch'');');

        torchInfo.installed = true;
        torchInfo.version   = toStringSafe(py.getattr(torch,'__version__'));

        vermod = py.getattr(torch,'version');
        torchInfo.cuda = toStringSafe(py.getattr(vermod,'cuda'));

        cudamod = py.getattr(torch,'cuda');
        is_av   = py.getattr(cudamod,'is_available');
        torchInfo.is_available = toBoolSafe(is_av());
    catch ME
        if debug, fprintf('[DEBUG] quick check: torch inspect failed (non-fatal): %s\n', ME.message); end
    end
end

function [okSys, pyVer, okTorch, torchVer, torchCUDA, torchAvail] = matlabTorchChecks(debug)
    okSys = false; pyVer = "";
    okTorch = false; torchVer = ""; torchCUDA = ""; torchAvail = false;

    try
        pysys = py.importlib.import_module('sys');
        pyVer = toStringSafe(pysys.("version"));
        okSys = true;
        if debug, fprintf('[DEBUG] sys.version: %s\n', char(pyVer)); end
    catch ME
        warning('Import "sys" failed: %s\n', ME.message);
        try, terminate(pyenv); catch, end
        return;
    end

    try
        oldWarn = warning;
        warning('off','all');
        c = onCleanup(@() warning(oldWarn));

        evalc('torch = py.importlib.import_module(''torch'');');

        okTorch  = true;
        torchVer = toStringSafe(py.getattr(torch, '__version__'));

        tv        = py.getattr(torch, 'version');
        torchCUDA = toStringSafe(py.getattr(tv, 'cuda'));

        tc        = py.getattr(torch, 'cuda');
        is_av_fn  = py.getattr(tc, 'is_available');
        torchAvail = toBoolSafe(is_av_fn());

        if debug
            tcdisp = torchCUDA; if tcdisp == "", tcdisp = "(None)"; end
            avdisp = tern(torchAvail, "true", "false");
            fprintf('[DEBUG] torch.__version__: %s | torch.version.cuda: %s | cuda.is_available(): %s\n', ...
                char(torchVer), char(tcdisp), char(avdisp));
        end
    catch ME
        if debug, fprintf('[DEBUG] Torch import failed: %s\n', ME.message); end
        try, terminate(pyenv); catch, end
    end
end

function printFinal(pe, okSys, pyVer, okTorch, torchVer, torchCUDA, torchAvail)
    if torchCUDA == "", torchCUDA = "(None)"; end
    av = "false"; if torchAvail, av = "true"; end

    fprintf('\n=== MATLAB Python Configuration (Detecdiv) ===\n');
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
    fprintf('=============================================\n');
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
        'python_sys_version', string(sysver), ...
        'torch', torchInfo, ...
        'debug', debug ...
    );
end

function [st,out] = runConda(subcmd, debug, condaCmd)
    cc = string(condaCmd);

    if ispc
        % Always use absolute condaCmd (bat or exe) through cmd /c
        cmd = sprintf('cmd /c ""%s" %s"', cc, subcmd);
    else
        % On Unix/mac: if condaCmd is an absolute path, use it directly.
        % Otherwise rely on shell "conda".
        if cc ~= "" && isfile(cc)
            cmd = sprintf('bash -lc "%s %s"', cc, subcmd);
        else
            cmd = sprintf('bash -lc "conda %s"', subcmd);
        end
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

function [data, out, src] = getCondaEnvs(debug, condaCmd)
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

function userprefs = dd_loadUserPrefs()
    folder = fullfile(prefdir,'Detecdiv');
    fle = fullfile(folder,'userprefs.mat');
    if ~exist(folder,'dir'), mkdir(folder); end

    if exist(fle,'file')
        S = load(fle);
        if isfield(S,'userprefs') && isstruct(S.userprefs)
            userprefs = S.userprefs;
        else
            userprefs = struct();
        end
    else
        userprefs = struct();
    end

    if ~isfield(userprefs,'conda') || ~isstruct(userprefs.conda)
        userprefs.conda = struct();
    end
    if ~isfield(userprefs.conda,'condaCmd')
        userprefs.conda.condaCmd = "";
    end
    if ~isfield(userprefs.conda,'lastCheck')
        userprefs.conda.lastCheck = "";
    end
end

function dd_saveUserPrefs(userprefs)
    folder = fullfile(prefdir,'Detecdiv');
    fle = fullfile(folder,'userprefs.mat');
    if ~exist(folder,'dir'), mkdir(folder); end
    save(fle,'userprefs');
end

function [condaCmd, userprefs] = resolveCondaCmd(userprefs, debug)
    % 1) prefs first (absolute path)
    prefCmd = "";
    if isfield(userprefs,'conda') && isfield(userprefs.conda,'condaCmd')
        prefCmd = string(userprefs.conda.condaCmd);
    end
    if prefCmd ~= ""
        if probeConda(prefCmd, debug)
            condaCmd = prefCmd;
            userprefs.conda.lastCheck = char(datetime('now'));
            return;
        else
            if debug, fprintf('[DEBUG] Pref condaCmd invalid/unusable: %s\n', char(prefCmd)); end
        end
    end

    % 2) PATH lookup
    condaCmd = "";
    if ispc
        [st,out] = system('where conda');
        if st == 0
            lines = splitlines(string(out));
            lines(lines=="") = [];
            if ~isempty(lines)
                condaCmd = strtrim(lines(1)); % may be conda.bat; OK
            end
        end
    else
        [st,out] = system('which conda');
        if st == 0
            condaCmd = strtrim(string(out)); % absolute path
        end
    end

    if condaCmd ~= "" && probeConda(condaCmd, debug)
        userprefs.conda.condaCmd = condaCmd;
        userprefs.conda.lastCheck = char(datetime('now'));
        return;
    end

    % 3) fail with actionable guidance
    userprefs.conda.lastCheck = char(datetime('now'));
    dd_saveUserPrefs(userprefs);

    msg = [
        "Conda est introuvable (ni dans le PATH, ni via le chemin stocké dans les préférences).", newline, ...
        "➡️ Installe Miniconda/Miniforge, puis relance Detecdiv.", newline, ...
        "➡️ Ou renseigne manuellement le chemin absolu dans Detecdiv > Preferences :", newline, ...
        "   userprefs.conda.condaCmd", newline, ...
        "Exemples Windows:", newline, ...
        "  C:\Users\<you>\miniconda3\condabin\conda.bat", newline, ...
        "  C:\Users\<you>\miniconda3\Scripts\conda.exe"
    ];
    error('%s', char(msg));
end

function ok = probeConda(condaCmd, debug)
    ok = false;
    c = string(condaCmd);

    if ispc
        % always test through cmd /c
        cmd = sprintf('cmd /c ""%s" --version"', c);
    else
        if isfile(c)
            cmd = sprintf('bash -lc "%s --version"', c);
        else
            cmd = sprintf('bash -lc "conda --version"');
        end
    end

    [st,out] = system(cmd);
    if debug
        fprintf('[DEBUG] probeConda: rc=%d | %s\n', st, strtrim(out));
    end
    ok = (st == 0);
end

function [envPath, pyexe] = ensureDetecdivEnv(condaCmd, debug)
    envName = "detecdiv_python";

    [data, ~, ~] = getCondaEnvs(debug, condaCmd);
    envPaths = string(data.envs);

    envPath = "";
    for i=1:numel(envPaths)
        if strcmpi(char(getLastPathComponent(envPaths(i))), char(envName))
            envPath = envPaths(i);
            break;
        end
    end

    if envPath == ""
        if debug, fprintf('[DEBUG] Env "%s" not found -> creating (python=3.10)...\n', envName); end
        sub = sprintf('create -y -n %s python=3.10', envName);
        [st,out] = runConda(sub, debug, condaCmd);
        if st ~= 0
            error('Failed to create conda env "%s". Output:\n%s', envName, out);
        end

        [data2, ~, ~] = getCondaEnvs(debug, condaCmd);
        envPaths2 = string(data2.envs);
        for i=1:numel(envPaths2)
            if strcmpi(char(getLastPathComponent(envPaths2(i))), char(envName))
                envPath = envPaths2(i);
                break;
            end
        end
        if envPath == ""
            error('Env "%s" was created but cannot be found in conda env list.', envName);
        end
    else
        if debug, fprintf('[DEBUG] Env "%s" exists: %s\n', envName, char(envPath)); end
    end

    if ispc
        pyexe = fullfile(envPath, "python.exe");
    else
        pyexe = fullfile(envPath, "bin", "python");
    end

    if ~isfile(pyexe)
        error('Python executable missing for env "%s": %s', envName, pyexe);
    end
end

function ensureDetecdivPackages(condaCmd, debug)
    envName = "detecdiv_python";

    % --- torch ---
    fprintf('[Detecdiv]   - Checking torch...\n');
    hasTorch = condaRunPyImport(condaCmd, envName, "torch", debug);
    if ~hasTorch
        useGPU = hasNvidiaGPU(debug);
        fprintf('[Detecdiv]   - Installing torch (GPU=%d, cuda=12.1 if GPU)... Be patient !\n', useGPU);

        if useGPU
            sub = "install -y -n detecdiv_python pytorch torchvision torchaudio pytorch-cuda=12.1 -c pytorch -c nvidia";
        else
            sub = "install -y -n detecdiv_python pytorch torchvision torchaudio cpuonly -c pytorch";
        end

        [st,out] = runConda(sub, debug, condaCmd);
        if st ~= 0
            error('Torch install failed. Output:\n%s', out);
        end
    else
        fprintf('[Detecdiv]   - torch already installed.\n');
    end

    % --- cellpose (Cellpose-SAM) ---
    fprintf('[Detecdiv]   - Checking cellpose...\n');
    hasCellpose = condaRunPyImport(condaCmd, envName, "cellpose", debug);
    if ~hasCellpose
        fprintf('[Detecdiv]   - Installing cellpose[gui]...\n');
        [st1,o1] = runConda("run -n detecdiv_python python -m pip install --upgrade pip", debug, condaCmd);
        if st1 ~= 0, error('pip upgrade failed:\n%s', o1); end

        [st2,o2] = runConda('run -n detecdiv_python python -m pip install "cellpose[gui]"', debug, condaCmd);
        if st2 ~= 0, error('cellpose install failed:\n%s', o2); end
    else
        fprintf('[Detecdiv]   - cellpose already installed.\n');
    end

    % --- final torch verification via conda run ---
    fprintf('[Detecdiv]   - Verifying torch execution...\n');
    verifyTorch(condaCmd, envName, debug);
end

function ok = condaRunPyImport(condaCmd, envName, moduleName, debug)
    code = sprintf("import %s; print('OK')", moduleName);
    sub  = sprintf('run -n %s python -c "%s"', envName, code);
    [st,out] = runConda(sub, debug, condaCmd);
    ok = (st == 0) && contains(string(out), "OK");
    if debug
        fprintf('[DEBUG] import %s => %d\n', moduleName, ok);
    end
end

function verifyTorch(condaCmd, envName, debug)
    pycode = [
        "import torch;", ...
        "print('torch', torch.__version__);", ...
        "print('cuda_version', getattr(torch.version,'cuda',None));", ...
        "print('cuda_available', torch.cuda.is_available());"
    ];
    code = strjoin(pycode, " ");
    sub  = sprintf('run -n %s python -c "%s"', envName, code);

    [st,out] = runConda(sub, debug, condaCmd);
    if st ~= 0
        error('Torch verification failed:\n%s', out);
    end
    fprintf('[Detecdiv]   - torch verification OK:\n%s\n', out);
end

function tf = hasNvidiaGPU(debug)
    tf = false;
    if ispc
        [st,~] = system('where nvidia-smi');
        if st == 0
            [st2,out2] = system('nvidia-smi -L');
            tf = (st2 == 0) && ~contains(lower(string(out2)),'no devices were found');
        end
    else
        [st,~] = system('which nvidia-smi');
        if st == 0
            [st2,out2] = system('nvidia-smi -L');
            tf = (st2 == 0) && ~contains(lower(string(out2)),'no devices were found');
        end
    end
    if debug
        fprintf('[DEBUG] hasNvidiaGPU=%d\n', tf);
    end
end

function warnJson(ME, raw)
    tmp = [tempname,'.json'];
    fid = fopen(tmp,'w');
    if fid>0, fwrite(fid,raw); fclose(fid); end
    warning('JSON decode failed: %s\nRaw saved to: %s', ME.message, tmp);
end

function leaf = getLastPathComponent(p)
    p = char(p);
    if ~isempty(p) && any(p(end) == [filesep '/' '\']), p = p(1:end-1); end
    parts = regexp(p, '[\\/]', 'split');
    leaf = string(parts{end});
end

function s = toStringSafe(pyobj)
    if isa(pyobj, 'py.NoneType'), s = ""; return; end
    try, s = string(char(pyobj));
    catch, s = string(char(py.str(pyobj)));
    end
end

function b = toBoolSafe(pybool)
    try, b = logical(pybool);
    catch, b = logical(pybool == true);
    end
end

function x = tern(cond, a, b)
    if cond, x = a; else, x = b; end
end
