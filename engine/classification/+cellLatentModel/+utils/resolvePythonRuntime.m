function runtime = resolvePythonRuntime(ctx)
%CELLLATENTMODEL.UTILS.RESOLVEPYTHONRUNTIME Discover external model runtime.
%
% Python and repository locations are infrastructure and are never exposed
% as classifier static parameters.

if nargin < 1, ctx = struct(); end
try
    resolved = ctx.resolvedPythonRuntime;
    if isstruct(resolved) && isfield(resolved,'pythonExecutable') && ...
            isfile(char(string(resolved.pythonExecutable)))
        runtime = resolved;
        return;
    end
catch
end
runtime = struct('pythonExecutable','','repositoryRoot','', ...
    'lineageRepositoryRoot','', ...
    'packageSource','','backend','local');
environmentNames = {'CELL_LATENT_MODEL_PYTHON','DETECDIV_PYTHON_EXE'};
for i = 1:numel(environmentNames)
    candidate = strtrim(getenv(environmentNames{i}));
    if isfile(candidate)
        runtime.pythonExecutable = candidate;
        runtime.packageSource = ['environment:' environmentNames{i}];
        break;
    end
end
if isempty(runtime.pythonExecutable)
    try
        environment = pyenv();
        if ~strcmp(environment.Status,'NotLoaded') && ...
                isfile(char(environment.Executable))
            runtime.pythonExecutable = char(environment.Executable);
            runtime.packageSource = 'detecdiv_pyenv';
        end
    catch
    end
end
if isempty(runtime.pythonExecutable)
    % A pre-existing canonical environment is already the execution
    % boundary required by this package. Do not run DetecDiv's global
    % CellposeSAM/Trackastra bootstrap for every latent-model subprocess:
    % neither the latent tracker nor its lineage/state heads import
    % Trackastra. Missing latent dependencies will be reported by the real
    % package command, while a genuinely absent environment still falls
    % through to the installer below.
    canonicalPython = fullfile(getenv('USERPROFILE'),'.conda','envs', ...
        'detecdiv_python','python.exe');
    if isfile(canonicalPython)
        runtime.pythonExecutable = canonicalPython;
        runtime.packageSource = 'detecdiv_python_existing';
    end
end
if isempty(runtime.pythonExecutable)
    try
        args = pythonSelectionArgs(ctx);
        select_and_load_conda_env(args{:});
        environment = pyenv();
        if ~strcmp(environment.Status,'NotLoaded') && ...
                isfile(char(environment.Executable))
            runtime.pythonExecutable = char(environment.Executable);
            runtime.packageSource = 'detecdiv_pyenv';
        end
    catch
    end
end
if isempty(runtime.pythonExecutable)
    candidates = { ...
        'python3','python'};
    for i = 1:numel(candidates)
        candidate = candidates{i};
        if isfile(candidate) || commandAvailable(candidate)
            runtime.pythonExecutable = candidate;
            runtime.packageSource = 'internal_candidate';
            break;
        end
    end
end
if isempty(runtime.pythonExecutable)
    error('cellLatentModel:PythonRuntimeUnavailable', ...
        ['No Python runtime is available for cell_latent_model. Install ' ...
         'the repository in the DetecDiv Python environment.']);
end

repo = strtrim(getenv('CELL_LATENT_MODEL_REPO_ROOT'));
if ~hasPackageSource(repo)
    detecdivRoot = fileparts(fileparts(fileparts(fileparts(fileparts( ...
        mfilename('fullpath'))))));
    matlabRoot = fileparts(detecdivRoot);
    candidates = {fullfile(matlabRoot,'cell_latent_model'), ...
        fullfile(getenv('USERPROFILE'),'Documents','MATLAB', ...
        'cell_latent_model')};
    repo = '';
    for i = 1:numel(candidates)
        if hasPackageSource(candidates{i})
            repo = candidates{i};
            break;
        end
    end
end
runtime.repositoryRoot = repo;

lineageRepo = strtrim(getenv('CELL_LINEAGE_LINKER_REPO_ROOT'));
if ~hasPackageSource(lineageRepo,'cell_lineage_linker')
    candidates = {};
    if ~isempty(repo)
        candidates{end+1} = fullfile(fileparts(repo), ...
            'cell_lineage_linker'); %#ok<AGROW>
    end
    candidates{end+1} = fullfile(getenv('USERPROFILE'), ...
        'Documents','MATLAB','cell_lineage_linker'); %#ok<AGROW>
    lineageRepo = '';
    for i = 1:numel(candidates)
        if hasPackageSource(candidates{i},'cell_lineage_linker')
            lineageRepo = candidates{i};
            break;
        end
    end
end
runtime.lineageRepositoryRoot = lineageRepo;
end

function args = pythonSelectionArgs(ctx)
args = {'mode','default'};
try pyCfg = ctx.exec.python; catch, return; end
if ~isstruct(pyCfg) || ~isfield(pyCfg,'mode') || ...
        ~strcmpi(char(string(pyCfg.mode)),'custom')
    return;
end
args = {'mode','custom'};
if isfield(pyCfg,'envName') && ~isempty(pyCfg.envName)
    args = [args {'envName',char(string(pyCfg.envName))}];
end
if isfield(pyCfg,'envPath') && ~isempty(pyCfg.envPath)
    args = [args {'envPath',char(string(pyCfg.envPath))}];
end
end

function tf = commandAvailable(command)
if ispc
    [status,~] = system(sprintf('where "%s" >NUL 2>&1',command));
else
    [status,~] = system(sprintf('command -v %s >/dev/null 2>&1', ...
        shellQuote(command)));
end
tf = status == 0;
end

function tf = hasPackageSource(root,packageName)
if nargin < 2, packageName = 'cell_latent_model'; end
root = char(string(root));
tf = ~isempty(root) && ...
    isfolder(fullfile(root,'src',packageName));
end

function value = shellQuote(raw)
value = ['''' strrep(char(string(raw)),'''','''"''"''') ''''];
end
