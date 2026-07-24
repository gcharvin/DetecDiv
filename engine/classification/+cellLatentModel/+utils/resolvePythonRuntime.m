function runtime = resolvePythonRuntime(ctx)
%CELLLATENTMODEL.UTILS.RESOLVEPYTHONRUNTIME Discover external model runtime.
%
% Python and repository locations are infrastructure and are never exposed
% as classifier static parameters.

if nargin < 1, ctx = struct(); end
runtime = struct('pythonExecutable','','repositoryRoot','', ...
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
        fullfile(getenv('USERPROFILE'),'.conda','envs', ...
            'detecdiv_python','python.exe'), ...
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

function tf = hasPackageSource(root)
root = char(string(root));
tf = ~isempty(root) && ...
    isfolder(fullfile(root,'src','cell_latent_model'));
end

function value = shellQuote(raw)
value = ['''' strrep(char(string(raw)),'''','''"''"''') ''''];
end
