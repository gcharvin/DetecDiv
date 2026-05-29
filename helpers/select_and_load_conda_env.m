function info = select_and_load_conda_env(varargin)
% SELECT_AND_LOAD_CONDA_ENV (interactive env selection + optional auto-setup)
%
% Strategy (standardised):
%   - Ask user (GUI) to choose:
%       * default env "detecdiv_python" (auto-configure/install allowed)
%       * another existing conda env (no install done by Detecdiv)
%   - Optional checkbox can lock this choice in userprefs until 'reset' is used.
%   - If pyenv is already Loaded + OutOfProcess + healthy and matches selected env:
%       -> keep it and return summary.
%
% Options (Name,Value):
%   'debug'   (logical, default true)
%   'reset'   (logical, default false) clear remembered env choice
%   'mode'    ('default'|'custom') bypass GUI selection
%   'envName' custom conda env name when mode='custom'
%   'envPath' custom conda env path hint when mode='custom'
%   'remember' (logical) persist the provided selection
%   'classif' / 'classifier' : legacy no-op, accepted for backward compatibility

    % -------- Parse options --------
    opts = struct('debug', true, 'reset', false, ...
        'mode', "", 'envName', "", 'envPath', "", 'remember', []);
    if nargin == 1 && (strcmpi(string(varargin{1}), "reset"))
        opts.reset = true;
    else
        if mod(nargin,2)~=0
            error('Arguments must be Name,Value pairs (or ''reset'').');
        end
        for k = 1:2:nargin
            name = lower(string(varargin{k}));
            val  = varargin{k+1};
            switch name
                case "debug", opts.debug = logical(val);
                case "reset", opts.reset = logical(val);
                case "mode", opts.mode = string(val);
                case "envname", opts.envName = string(val);
                case "envpath", opts.envPath = string(val);
                case "remember", opts.remember = logical(val);
                case {"classif","classifier"}
                    % Legacy callers still pass the classifier object here.
                    % The current helper no longer needs it, but keeping this
                    % option avoids breaking existing package code.
                otherwise, error('Unknown option "%s".', name);
            end
        end
    end
    debug = opts.debug;
    doReset = opts.reset;

    fprintf('\n[Detecdiv] Python bootstrap starting...\n');

    % -------- 0) Selection mode (default/custom) --------
    userprefs = dd_loadUserPrefs();
    if doReset
        userprefs = clearRememberedCondaSelection(userprefs);
        dd_saveUserPrefs(userprefs);
        fprintf('[Detecdiv] Reset requested: remembered env choice cleared.\n');
    end

    forcedSelection = buildForcedSelection(opts);
    if isempty(forcedSelection)
        [selection, userprefs] = resolveCondaSelection(userprefs, debug);
    else
        selection = forcedSelection;
        userprefs = persistForcedSelection(userprefs, selection);
    end
    dd_saveUserPrefs(userprefs);
    fprintf('[Detecdiv] Selected mode: %s', char(selection.mode));
    if selection.mode == "custom"
        fprintf(' | env=%s', char(selection.envName));
    end
    if selection.remember
        fprintf(' | remembered=1');
    end
    fprintf('\n');

    % -------- 1) If Python already loaded: require Loaded + OutOfProcess + healthy --------
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
                if pyenvMatchesSelection(pe, selection)
                    if selection.mode == "default" && ~existingTorchRuntimeCompatible(torchInfo, debug)
                        fprintf('[Detecdiv] Existing pyenv matches selection but torch runtime is not suitable -> terminating...\n');
                        try, terminate(pyenv); catch, end
                    else
                        fprintf('[Detecdiv] Existing pyenv is healthy and matches selection -> keeping it.\n');
                        printSummary(pe, sysver, torchInfo);
                        info = packInfoExisting(pe, sysver, torchInfo, debug);
                        return;
                    end
                else
                    fprintf('[Detecdiv] Existing pyenv does not match selection -> terminating...\n');
                    try, terminate(pyenv); catch, end
                end
            else
                fprintf('[Detecdiv] Existing pyenv unhealthy -> terminating...\n');
                try, terminate(pyenv); catch, end
            end
        end
    else
        fprintf('[Detecdiv] No active pyenv (Status=%s)\n', char(string(pe.Status)));
    end

    % -------- 2) Resolve conda command (prefs/path) --------
    fprintf('[Detecdiv] Step 1/5: Resolving conda...\n');
    try
        [condaCmd, userprefs] = resolveCondaCmd(userprefs, debug);
    catch ME
        if selection.mode == "custom"
            uiErrorAndThrow( ...
                "Conda was not found. Cannot use a custom conda environment.", ...
                "Detecdiv - Conda Not Found", ME);
        else
            rethrow(ME);
        end
    end
    dd_saveUserPrefs(userprefs);
    fprintf('[Detecdiv] Conda command: %s\n', char(condaCmd));

    if selection.mode == "custom"
        % Custom env: do not install anything, just resolve + load.
        fprintf('[Detecdiv] Step 2/5: Resolving selected conda env...\n');
        [detPath, detPy] = resolveExistingCondaEnv(condaCmd, selection, debug);
        fprintf('[Detecdiv] Selected env path: %s\n', char(detPath));
        fprintf('[Detecdiv] Selected env python: %s\n', char(detPy));

        fprintf('[Detecdiv] Step 3/5: Custom mode -> no package installation.\n');
        fprintf('[Detecdiv] Step 4/5: Configuring MATLAB pyenv (OutOfProcess)...\n');
        pe = configurePyenvOutOfProcess(detPy, debug);

        fprintf('[Detecdiv] Step 5/5: Final checks (sys + torch import in MATLAB)...\n');
        [okSys, pyVer, okTorch, torchVer, torchCUDA, torchAvail] = matlabTorchChecks(debug);
        if ~okSys
            fprintf('[Detecdiv] MATLAB pyenv check failed once -> resetting and retrying...\n');
            pe = configurePyenvOutOfProcess(detPy, debug);
            [okSys, pyVer, okTorch, torchVer, torchCUDA, torchAvail] = matlabTorchChecks(debug);
        end
        printFinal(pe, okSys, pyVer, okTorch, torchVer, torchCUDA, torchAvail);

        info = struct( ...
            'name', string(selection.envName), ...
            'path', string(detPath), ...
            'python', string(detPy), ...
            'pyenv', pe, ...
            'python_sys_version', string(pyVer), ...
            'torch', struct('installed', okTorch, 'version', string(torchVer), 'cuda', string(torchCUDA), 'is_available', logical(torchAvail)), ...
            'debug', debug ...
        );
        return;
    end

    % -------- 3) Ensure env detecdiv_python (python=3.10) --------
    fprintf('[Detecdiv] Step 2/5: Ensuring conda env "detecdiv_python" (python=3.10)...\n');
    [detPath, detPy] = ensureDetecdivEnv(condaCmd, debug);
    fprintf('[Detecdiv] detecdiv_python path: %s\n', char(detPath));
    fprintf('[Detecdiv] detecdiv_python python: %s\n', char(detPy));

    % -------- 4) Ensure packages (torch + cellpose) --------
    fprintf('[Detecdiv] Step 3/5: Ensuring required Python packages (torch + cellpose)...\n');
    ensureDetecdivPackages(condaCmd, debug);

    % -------- 5) Configure MATLAB pyenv to detecdiv_python (OutOfProcess) --------
    fprintf('[Detecdiv] Step 4/5: Configuring MATLAB pyenv (OutOfProcess)...\n');
    pe = configurePyenvOutOfProcess(detPy, debug);

    % -------- 6) Final checks + report --------
    fprintf('[Detecdiv] Step 5/5: Final checks (sys + torch import in MATLAB)...\n');
    [okSys, pyVer, okTorch, torchVer, torchCUDA, torchAvail] = matlabTorchChecks(debug);
    if ~okSys
        fprintf('[Detecdiv] MATLAB pyenv check failed once -> resetting and retrying...\n');
        pe = configurePyenvOutOfProcess(detPy, debug);
        [okSys, pyVer, okTorch, torchVer, torchCUDA, torchAvail] = matlabTorchChecks(debug);
    end

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

function selection = buildForcedSelection(opts)
selection = [];
mode = lower(strtrim(char(string(opts.mode))));
if isempty(mode)
    return;
end

switch mode
    case 'default'
        selection = struct( ...
            'mode', "default", ...
            'envName', "detecdiv_python", ...
            'envPath', "", ...
            'remember', logical(defaultRememberValue(opts)));
    case 'custom'
        envName = string(opts.envName);
        envPath = string(opts.envPath);
        if strlength(envName) == 0 && strlength(envPath) == 0
            error('select_and_load_conda_env:CustomEnvMissing', ...
                'A custom Python env requires envName or envPath.');
        end
        if strlength(envName) == 0 && strlength(envPath) > 0
            [~, nm] = fileparts(char(envPath));
            envName = string(nm);
        end
        selection = struct( ...
            'mode', "custom", ...
            'envName', envName, ...
            'envPath', envPath, ...
            'remember', logical(defaultRememberValue(opts)));
    otherwise
        error('select_and_load_conda_env:UnknownMode', 'Unknown Python env mode "%s".', mode);
end
end

function tf = defaultRememberValue(opts)
tf = false;
if ~isempty(opts.remember)
    tf = logical(opts.remember);
end
end

function userprefs = persistForcedSelection(userprefs, selection)
if selection.remember
    if ~isfield(userprefs,'conda') || ~isstruct(userprefs.conda)
        userprefs.conda = struct();
    end
    userprefs.conda.selectionLock = true;
    userprefs.conda.selectionMode = char(selection.mode);
    userprefs.conda.selectionEnvName = char(selection.envName);
    userprefs.conda.selectionEnvPath = char(selection.envPath);
else
    userprefs = clearRememberedCondaSelection(userprefs);
end
end

% =================== Helpers ===================

function pe = configurePyenvOutOfProcess(detPy, debug)
    pe = pyenv;
    if pe.Status ~= "NotLoaded"
        if debug
            fprintf('[Detecdiv] Resetting existing Python engine (Status=%s)...\n', char(string(pe.Status)));
        end
        try
            terminate(pyenv);
        catch
        end
    end
    pe = pyenv('Version', char(detPy), 'ExecutionMode', 'OutOfProcess');
end

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

function tf = existingTorchRuntimeCompatible(torchInfo, debug)
tf = true;
gpuText = lower(string(getNvidiaGPUText()));
isBlackwell = contains(gpuText, "blackwell") || contains(gpuText, "rtx 50") || contains(gpuText, "rtx pro 500");
if isBlackwell
    tf = torchInfo.installed && contains(string(torchInfo.version), "+cu128") && string(torchInfo.cuda) == "12.8";
end
if debug
    fprintf('[DEBUG] existingTorchRuntimeCompatible=%d (version=%s cuda=%s gpu="%s")\n', ...
        tf, char(string(torchInfo.version)), char(string(torchInfo.cuda)), char(gpuText));
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

function userprefs = clearRememberedCondaSelection(userprefs)
if ~isfield(userprefs,'conda') || ~isstruct(userprefs.conda)
    userprefs.conda = struct();
end
userprefs.conda.selectionLock = false;
userprefs.conda.selectionMode = "default";
userprefs.conda.selectionEnvName = "detecdiv_python";
userprefs.conda.selectionEnvPath = "";
end

function [selection, userprefs] = resolveCondaSelection(userprefs, debug)
selection = struct( ...
    'mode', "default", ...
    'envName', "detecdiv_python", ...
    'envPath', "", ...
    'remember', false);

% If locked, reuse stored choice and skip UI entirely.
if isfield(userprefs,'conda') && isstruct(userprefs.conda) && ...
        isfield(userprefs.conda,'selectionLock') && logical(userprefs.conda.selectionLock)
    mode = lower(string(userprefs.conda.selectionMode));
    if ~any(mode == ["default","custom"])
        mode = "default";
    end
    selection.mode = mode;
    if mode == "custom"
        nm = string(userprefs.conda.selectionEnvName);
        if strlength(nm) == 0, nm = "base"; end
        selection.envName = nm;
        selection.envPath = string(userprefs.conda.selectionEnvPath);
    end
    selection.remember = true;
    if debug
        fprintf('[DEBUG] Using remembered conda selection: mode=%s env=%s\n', ...
            char(selection.mode), char(selection.envName));
    end
    return;
end

if ~usejava('desktop')
    if debug
        fprintf('[DEBUG] No desktop UI available -> defaulting to detecdiv_python.\n');
    end
    return;
end

[mode, remember, ok] = promptCondaSelectionDialog();
if ~ok
    error('Conda environment selection cancelled by user.');
end
selection.mode = mode;
selection.remember = remember;

if mode == "custom"
    try
        [condaCmd, userprefs] = resolveCondaCmd(userprefs, debug);
    catch ME
        uiErrorAndThrow( ...
            "Conda was not found. Cannot list conda environments.", ...
            "Detecdiv - Conda Not Found", ME);
    end

    try
        [data, ~, ~] = getCondaEnvs(debug, condaCmd);
    catch ME
        uiErrorAndThrow( ...
            "Unable to read the conda environment list.", ...
            "Detecdiv - Conda Error", ME);
    end
    [names, paths, labels] = buildCondaEnvList(data);
    if isempty(labels)
        uiErrorAndThrow( ...
            "No conda environments were found.", ...
            "Detecdiv - No Conda Environments");
    end

    [idx, okSel] = listdlg( ...
        'PromptString', 'Select a conda environment:', ...
        'SelectionMode', 'single', ...
        'ListString', cellstr(labels), ...
        'ListSize', [760 320], ...
        'Name', 'Detecdiv - Select Conda Environment');

    if ~okSel || isempty(idx)
        error('Conda environment selection cancelled by user.');
    end

    selection.envName = names(idx(1));
    selection.envPath = paths(idx(1));
end

if remember
    if ~isfield(userprefs,'conda') || ~isstruct(userprefs.conda)
        userprefs.conda = struct();
    end
    userprefs.conda.selectionLock = true;
    userprefs.conda.selectionMode = char(selection.mode);
    userprefs.conda.selectionEnvName = char(selection.envName);
    userprefs.conda.selectionEnvPath = char(selection.envPath);
else
    userprefs = clearRememberedCondaSelection(userprefs);
end
end

function [mode, remember, ok] = promptCondaSelectionDialog()
mode = "default";
remember = false;
ok = false;

dlg = dialog( ...
    'Name', 'Detecdiv Python Environment', ...
    'Position', [400 320 560 260], ...
    'WindowStyle', 'modal', ...
    'Resize', 'off');

uicontrol(dlg, ...
    'Style', 'text', ...
    'Position', [20 190 520 50], ...
    'HorizontalAlignment', 'left', ...
    'String', ['Select Python environment mode.' newline ...
               'Default: detecdiv_python (auto-install allowed).']);

bg = uibuttongroup(dlg, ...
    'Position', [0.04 0.36 0.92 0.30], ...
    'BorderType', 'none');

uicontrol(bg, ...
    'Style', 'radiobutton', ...
    'String', 'Use detecdiv_python (recommended)', ...
    'Tag', 'default', ...
    'Position', [10 36 460 22], ...
    'Value', 1);

uicontrol(bg, ...
    'Style', 'radiobutton', ...
    'String', 'Choose another conda environment (no automatic installation)', ...
    'Tag', 'custom', ...
    'Position', [10 10 520 22], ...
    'Value', 0);

hRemember = uicontrol(dlg, ...
    'Style', 'checkbox', ...
    'Position', [20 74 520 22], ...
    'String', 'Remember this choice permanently (use reset to change)');

uicontrol(dlg, ...
    'Style', 'pushbutton', ...
    'Position', [360 20 80 34], ...
    'String', 'Cancel', ...
    'Callback', @(~,~) onCancel());

uicontrol(dlg, ...
    'Style', 'pushbutton', ...
    'Position', [450 20 80 34], ...
    'String', 'OK', ...
    'Callback', @(~,~) onOk());

uiwait(dlg);

if ishghandle(dlg)
    if isappdata(dlg, 'selection_ok')
        ok = logical(getappdata(dlg, 'selection_ok'));
        mode = string(getappdata(dlg, 'selection_mode'));
        remember = logical(getappdata(dlg, 'selection_remember'));
    end
    delete(dlg);
end

    function onCancel()
        setappdata(dlg, 'selection_ok', false);
        uiresume(dlg);
    end

    function onOk()
        modeTag = string(bg.SelectedObject.Tag);
        setappdata(dlg, 'selection_ok', true);
        setappdata(dlg, 'selection_mode', modeTag);
        setappdata(dlg, 'selection_remember', logical(hRemember.Value));
        uiresume(dlg);
    end
end

function tf = pyenvMatchesSelection(pe, selection)
tf = false;
if pe.Status ~= "Loaded" || string(pe.ExecutionMode) ~= "OutOfProcess"
    return;
end

target = "detecdiv_python";
if selection.mode == "custom"
    target = string(selection.envName);
end

exe = string(pe.Executable);
currentName = inferCondaEnvNameFromPythonExe(exe);
if strcmpi(char(currentName), char(target))
    tf = true;
    return;
end

if selection.mode == "custom" && strlength(selection.envPath) > 0
    exeN = normalizePathForCompare(exe);
    rootN = normalizePathForCompare(selection.envPath);
    tf = startsWith(exeN, rootN + "/");
end
end

function name = inferCondaEnvNameFromPythonExe(pyexe)
name = "";
p = lower(replace(string(pyexe), "\", "/"));
token = "/envs/";
ix = strfind(char(p), token);
if ~isempty(ix)
    k = ix(end) + strlength(token);
    tail = extractAfter(p, k-1);
    parts = split(tail, "/");
    parts(parts=="") = [];
    if ~isempty(parts)
        name = string(parts(1));
        return;
    end
end
name = "base";
end

function s = normalizePathForCompare(p)
s = replace(string(p), "\", "/");
s = regexprep(s, '/+', '/');
s = strip(s);
if strlength(s) > 1 && endsWith(s, "/")
    s = extractBefore(s, strlength(s));
end
if ispc
    s = lower(s);
end
end

function [envPath, pyexe] = resolveExistingCondaEnv(condaCmd, selection, debug)
[data, ~, ~] = getCondaEnvs(debug, condaCmd);
[names, paths, ~] = buildCondaEnvList(data);

envPath = "";
if strlength(selection.envPath) > 0
    target = normalizePathForCompare(selection.envPath);
    for i = 1:numel(paths)
        if normalizePathForCompare(paths(i)) == target
            envPath = paths(i);
            break;
        end
    end
end

if envPath == ""
    nm = lower(string(selection.envName));
    idx = find(lower(names) == nm, 1, 'first');
    if ~isempty(idx)
        envPath = paths(idx);
    end
end

if envPath == ""
    error('Selected conda environment "%s" not found.', char(selection.envName));
end

if ispc
    pyexe = fullfile(envPath, "python.exe");
else
    pyexe = fullfile(envPath, "bin", "python");
end
if ~isfile(pyexe)
    error('Python executable missing for selected env: %s', pyexe);
end
end

function [names, paths, labels] = buildCondaEnvList(data)
paths = strings(0,1);
if isfield(data,'envs') && ~isempty(data.envs)
    paths = string(data.envs(:));
end
paths = paths(strlength(paths) > 0);
paths = unique(paths, 'stable');

rootPrefix = "";
if isfield(data,'root_prefix') && ~isempty(data.root_prefix)
    rootPrefix = string(data.root_prefix);
end
rootN = normalizePathForCompare(rootPrefix);

names = strings(numel(paths),1);
labels = strings(numel(paths),1);
for i = 1:numel(paths)
    p = paths(i);
    pN = normalizePathForCompare(p);
    if strlength(rootN) > 0 && pN == rootN
        nm = "base";
    else
        nm = getLastPathComponent(p);
    end
    if strlength(nm) == 0
        nm = "env_" + string(i);
    end
    names(i) = nm;
    labels(i) = nm + "    |    " + p;
end
end

function uiErrorAndThrow(msg, titleText, ME)
if nargin < 2 || strlength(string(titleText)) == 0
    titleText = "Detecdiv error";
end
if usejava('desktop')
    try
        errordlg(char(string(msg)), char(string(titleText)), 'modal');
    catch
    end
end
if nargin >= 3 && ~isempty(ME)
    error('%s\n\n%s', char(string(msg)), ME.message);
else
    error('%s', char(string(msg)));
end
end

function [st,out] = runConda(subcmd, debug, condaCmd)
    cc = string(condaCmd);

    if ispc
        % Always use absolute condaCmd (bat or exe) through cmd /c
        cmd = sprintf('cmd /c ""%s" %s"', cc, subcmd);
    else
        % On Unix/mac: if condaCmd is an absolute path, execute it directly.
        % Otherwise rely on shell initialization via bash -lc.
        if cc ~= "" && isfile(cc)
            cmd = sprintf('"%s" %s', cc, subcmd);
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
    if ~isfield(userprefs.conda,'selectionLock')
        userprefs.conda.selectionLock = false;
    end
    if ~isfield(userprefs.conda,'selectionMode')
        userprefs.conda.selectionMode = "default";
    end
    if ~isfield(userprefs.conda,'selectionEnvName')
        userprefs.conda.selectionEnvName = "detecdiv_python";
    end
    if ~isfield(userprefs.conda,'selectionEnvPath')
        userprefs.conda.selectionEnvPath = "";
    end
end

function dd_saveUserPrefs(userprefs)
    folder = fullfile(prefdir,'Detecdiv');
    fle = fullfile(folder,'userprefs.mat');
    if ~exist(folder,'dir'), mkdir(folder); end
    save(fle,'userprefs');
end

function [condaCmd, userprefs] = resolveCondaCmd(userprefs, debug)
    % Build candidate list (prefs, env vars, PATH, common locations)
    candidates = strings(0,1);

    % 1) prefs first
    prefCmd = "";
    if isfield(userprefs,'conda') && isfield(userprefs.conda,'condaCmd')
        prefCmd = string(userprefs.conda.condaCmd);
    end
    if prefCmd ~= ""
        candidates = localPushUnique(candidates, prefCmd);
    end

    % 2) env hints
    condaExe = string(getenv('CONDA_EXE'));
    if strlength(condaExe) > 0
        candidates = localPushUnique(candidates, condaExe);
    end

    condaPrefix = string(getenv('CONDA_PREFIX'));
    if strlength(condaPrefix) > 0
        if ispc
            candidates = localPushUnique(candidates, fullfile(condaPrefix, 'condabin', 'conda.bat'));
            candidates = localPushUnique(candidates, fullfile(condaPrefix, 'Scripts', 'conda.exe'));
        else
            candidates = localPushUnique(candidates, fullfile(condaPrefix, 'bin', 'conda'));
            parentPrefix = string(fileparts(condaPrefix));
            if strlength(parentPrefix) > 0
                candidates = localPushUnique(candidates, fullfile(parentPrefix, 'bin', 'conda'));
            end
        end
    end

    % 3) PATH lookup
    if ispc
        [st,out] = system('where conda');
        if st == 0
            lines = splitlines(string(out));
            lines(lines=="") = [];
            for i = 1:numel(lines)
                candidates = localPushUnique(candidates, strtrim(lines(i)));
            end
        end
    else
        [st,out] = system('bash -lc "command -v conda"');
        if st == 0
            lines = splitlines(string(out));
            lines(lines=="") = [];
            for i = 1:numel(lines)
                candidates = localPushUnique(candidates, strtrim(lines(i)));
            end
        end
    end

    % 4) common install locations
    commonCands = localCommonCondaCandidates();
    for i = 1:numel(commonCands)
        candidates = localPushUnique(candidates, commonCands(i));
    end

    % 5) probe in order
    condaCmd = "";
    for i = 1:numel(candidates)
        cand = localNormalizeCandidate(candidates(i));
        if strlength(cand) == 0
            continue;
        end
        if probeConda(cand, debug)
            condaCmd = cand;
            userprefs.conda.condaCmd = condaCmd;
            userprefs.conda.lastCheck = char(datetime('now'));
            return;
        end
        if debug
            fprintf('[DEBUG] Conda candidate not usable: %s\n', char(cand));
        end
    end

    % 6) fail with actionable guidance
    userprefs.conda.lastCheck = char(datetime('now'));
    dd_saveUserPrefs(userprefs);

    if ispc
        osExamples = [
            "Windows examples:", newline, ...
            "  C:\Users\<you>\miniconda3\condabin\conda.bat", newline, ...
            "  C:\Users\<you>\miniconda3\Scripts\conda.exe"
        ];
    else
        osExamples = [
            "Linux/macOS examples:", newline, ...
            "  /home/<you>/miniconda3/bin/conda", newline, ...
            "  /home/<you>/miniforge3/bin/conda", newline, ...
            "  /opt/conda/bin/conda"
        ];
    end

    msg = [
        "Conda was not found (preferences, environment variables, PATH, standard locations).", newline, ...
        "-> Install Miniconda/Miniforge, then restart Detecdiv.", newline, ...
        "-> Or set the absolute path manually in Detecdiv > Preferences:", newline, ...
        "   userprefs.conda.condaCmd", newline, ...
        osExamples
    ];
    error('%s', char(msg));
end

function out = localPushUnique(arr, v)
out = arr;
sv = localNormalizeCandidate(v);
if strlength(sv) == 0
    return;
end
if ~any(out == sv)
    out(end+1,1) = sv;
end
end

function sv = localNormalizeCandidate(v)
sv = string(v);
if numel(sv) ~= 1
    sv = join(sv, " ");
end
sv = strtrim(sv);
if strlength(sv) >= 2
    if (startsWith(sv, '"') && endsWith(sv, '"')) || (startsWith(sv, "'") && endsWith(sv, "'"))
        sv = extractBetween(sv, 2, strlength(sv)-1);
        sv = string(sv);
        if isempty(sv), sv = ""; end
    end
end
end

function cands = localCommonCondaCandidates()
cands = strings(0,1);

if ispc
    home = string(getenv('USERPROFILE'));
    local = string(getenv('LOCALAPPDATA'));
    bases = [ ...
        fullfile(home, "miniconda3"); ...
        fullfile(home, "anaconda3"); ...
        fullfile(home, "miniforge3"); ...
        fullfile(home, "mambaforge") ...
    ];
    if strlength(local) > 0
        bases = [bases; fullfile(local, "miniforge3")];
    end
    for i = 1:numel(bases)
        b = bases(i);
        cands(end+1,1) = fullfile(b, "condabin", "conda.bat"); %#ok<AGROW>
        cands(end+1,1) = fullfile(b, "Scripts", "conda.exe"); %#ok<AGROW>
    end
else
    home = string(getenv('HOME'));
    cands = [ ...
        fullfile(home, "miniconda3", "bin", "conda"); ...
        fullfile(home, "anaconda3", "bin", "conda"); ...
        fullfile(home, "miniforge3", "bin", "conda"); ...
        fullfile(home, "mambaforge", "bin", "conda"); ...
        fullfile(home, ".local", "miniforge3", "bin", "conda"); ...
        "/opt/conda/bin/conda"; ...
        "/usr/local/miniconda3/bin/conda"; ...
        "/usr/local/miniforge3/bin/conda" ...
    ];
end
end

function ok = probeConda(condaCmd, debug)
    ok = false;
    c = string(condaCmd);

    if ispc
        % always test through cmd /c
        cmd = sprintf('cmd /c ""%s" --version"', c);
    else
        if isfile(c)
            cmd = sprintf('"%s" --version', c);
        else
            cmd = sprintf('bash -lc "%s --version"', c);
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
    useGPU = hasNvidiaGPU(debug);

    % --- torch ---
    fprintf('[Detecdiv]   - Checking torch...\n');
    hasTorch = condaRunPyImport(condaCmd, envName, "torch", debug);
    installTorch = ~hasTorch;
    if hasTorch
        [okTorchInitial, outTorchInitial] = verifyTorch(condaCmd, envName, debug);
        installTorch = ~okTorchInitial;
        if installTorch
            fprintf('[Detecdiv]   - Existing torch is not compatible with this GPU/runtime; reinstalling.\n');
            if debug
                fprintf('[DEBUG] Initial torch verification failed:\n%s\n', outTorchInitial);
            end
        else
            fprintf('[Detecdiv]   - torch already installed and verified.\n');
        end
    end

    if installTorch
        if useGPU
            fprintf('[Detecdiv]   - Installing torch GPU build selected for detected NVIDIA architecture...\n');
            okPipTorch = attemptTorchPipFallback(condaCmd, envName, true, debug);
            if ~okPipTorch
                error('Torch GPU install failed or installed build did not pass CUDA verification.');
            end
        else
            fprintf('[Detecdiv]   - Installing torch CPU build...\n');
            okPipTorch = attemptTorchPipFallback(condaCmd, envName, false, debug);
            if ~okPipTorch
                error('Torch CPU install failed or installed build did not verify.');
            end
        end
    else
        fprintf('[Detecdiv]   - torch install step skipped.\n');
    end

    % --- OME-Zarr I/O ---
    fprintf('[Detecdiv]   - Checking zarr...\n');
    hasZarr = condaRunPyImport(condaCmd, envName, "zarr", debug);
    if ~hasZarr
        fprintf('[Detecdiv]   - Installing zarr for OME-Zarr data loading...\n');
        [stZ,oZ] = runConda("run -n detecdiv_python python -m pip install zarr", debug, condaCmd);
        if stZ ~= 0, error('zarr install failed:\n%s', oZ); end
    else
        fprintf('[Detecdiv]   - zarr already installed.\n');
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
    [okTorch, outTorch] = verifyTorch(condaCmd, envName, debug);
    if okTorch
        return;
    end

    % Auto-heal for known Linux runtime issue:
    % ImportError ... libtorch_cpu.so: undefined symbol: iJIT_NotifyEvent
    if isTorchIjitError(outTorch)
        fprintf('[Detecdiv]   - Detected Torch iJIT runtime issue -> trying auto-repair...\n');
        repaired = attemptTorchIjitRepair(condaCmd, envName, debug);
        if repaired
            [okTorch2, outTorch2] = verifyTorch(condaCmd, envName, debug);
            if okTorch2
                fprintf('[Detecdiv]   - Torch runtime repaired successfully.\n');
                return;
            end
            outTorch = outTorch2;
        end
    end

    % Last resort: pip wheels fallback (often more robust for mixed conda stacks).
    fprintf('[Detecdiv]   - Trying pip fallback for torch...\n');
    if attemptTorchPipFallback(condaCmd, envName, useGPU, debug)
        fprintf('[Detecdiv]   - Torch pip fallback succeeded.\n');
        return;
    end

    error('Torch verification failed:\n%s', outTorch);
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

function [ok, out] = verifyTorch(condaCmd, envName, debug)
    pycode = [
        "import torch;", ...
        "print('torch', torch.__version__);", ...
        "print('cuda_version', getattr(torch.version,'cuda',None));", ...
        "avail=torch.cuda.is_available();", ...
        "print('cuda_available', avail);", ...
        "cap=torch.cuda.get_device_capability(0) if avail else (0,0);", ...
        "sm=('sm_%d%d' % cap) if avail else '';", ...
        "arch=list(torch.cuda.get_arch_list()) if avail else [];", ...
        "print('cuda_device', torch.cuda.get_device_name(0) if avail else '');", ...
        "print('cuda_capability', sm);", ...
        "print('cuda_arch_list', arch);", ...
        "assert (not avail) or (not arch) or (sm in arch), 'PyTorch CUDA build does not support device capability ' + sm;", ...
        "x=(torch.ones((1,),device='cuda')+1).cpu().numpy()[0] if avail else 2.0;", ...
        "print('cuda_tensor_ok', x);"
    ];
    code = strjoin(pycode, " ");
    sub  = sprintf('run -n %s python -c "%s"', envName, code);

    [st,out] = runConda(sub, debug, condaCmd);
    ok = (st == 0);
    if ok
        fprintf('[Detecdiv]   - torch verification OK:\n%s\n', out);
    else
        if debug
            fprintf('[DEBUG] torch verification failed:\n%s\n', out);
        end
    end
end

function tf = isTorchIjitError(out)
s = lower(string(out));
tf = contains(s, "ijit_notifyevent") || ...
     (contains(s, "libtorch_cpu.so") && contains(s, "undefined symbol"));
end

function ok = attemptTorchIjitRepair(condaCmd, envName, debug)
ok = false;

repairCmds = [
    "install -y -n " + envName + " intel-openmp mkl mkl-service", ...
    "install -y -n " + envName + " -c conda-forge libgcc-ng libstdcxx-ng"
];

for i = 1:numel(repairCmds)
    sub = repairCmds(i);
    fprintf('[Detecdiv]   - Repair step %d/%d: %s\n', i, numel(repairCmds), char(sub));
    [st,out] = runConda(sub, debug, condaCmd);
    if st ~= 0
        if debug
            fprintf('[DEBUG] Repair step failed (non-fatal for next step):\n%s\n', out);
        end
    else
        ok = true;
    end
end
end

function ok = attemptTorchPipFallback(condaCmd, envName, useGPU, debug)
ok = false;

% Cleanup existing torch stack (best effort; failures are non-fatal).
cleanupCmds = [
    "remove -y -n " + envName + " pytorch torchvision torchaudio pytorch-cuda", ...
    "run -n " + envName + " python -m pip uninstall -y torch torchvision torchaudio", ...
    "run -n " + envName + " python -m pip install --upgrade pip"
];
for i = 1:numel(cleanupCmds)
    [st,out] = runConda(cleanupCmds(i), debug, condaCmd);
    if st ~= 0 && debug
        fprintf('[DEBUG] pip fallback cleanup step failed (non-fatal):\n%s\n', out);
    end
end

if useGPU
    wheelTags = preferredTorchWheelTags(debug);
else
    wheelTags = ["cpu"];
end

for i = 1:numel(wheelTags)
    tag = wheelTags(i);
    fprintf('[Detecdiv]   - pip torch candidate %d/%d: %s\n', i, numel(wheelTags), char(tag));

    sub = sprintf([ ...
        'run -n %s python -m pip install --no-cache-dir --force-reinstall ' ...
        '--index-url https://download.pytorch.org/whl/%s torch==2.7.0 torchvision==0.22.0 torchaudio==2.7.0'], ...
        envName, tag);
    [st,out] = runConda(sub, debug, condaCmd);
    if st ~= 0
        if debug
            fprintf('[DEBUG] pip torch install failed for %s:\n%s\n', char(tag), out);
        end
        continue;
    end

    [okTorch, outTorch] = verifyTorch(condaCmd, envName, debug);
    if okTorch
        ok = true;
        return;
    elseif debug
        fprintf('[DEBUG] pip torch candidate %s did not verify:\n%s\n', char(tag), outTorch);
    end
end
end

function wheelTags = preferredTorchWheelTags(debug)
gpuText = lower(string(getNvidiaGPUText()));
if contains(gpuText, "blackwell") || contains(gpuText, "rtx 50") || contains(gpuText, "rtx pro 500")
    wheelTags = ["cu128"];
else
    wheelTags = ["cu128", "cu126", "cu118"];
end
if debug
    fprintf('[DEBUG] preferredTorchWheelTags GPU="%s" -> %s\n', char(gpuText), strjoin(wheelTags, ', '));
end
end

function txt = getNvidiaGPUText()
txt = "";
if ispc
    [st,out] = system('where nvidia-smi >nul 2>nul && nvidia-smi -L');
else
    [st,out] = system('which nvidia-smi >/dev/null 2>/dev/null && nvidia-smi -L');
end
if st == 0
    txt = string(out);
end
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

