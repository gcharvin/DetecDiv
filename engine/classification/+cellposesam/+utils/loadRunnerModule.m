function [runnerModule, runnerCallable, resolvedPath] = loadRunnerModule(runnerPath)
% loadRunnerModule  Load the exact CellposeSAM runner file for session use.
%
% Importing by the generic name "cellposesam_runner" can return an existing
% entry from Python's sys.modules. In MATLAB that stale/wrong module may be a
% valid py.module proxy without the expected run() function. Load from the
% explicit file path under a unique module name instead, then resolve run()
% through py.getattr so the callable remains stable for the MATLAB session.

runnerPath = char(string(runnerPath));
if exist(runnerPath, 'file') ~= 2
    error('cellposesam:RunnerModuleMissing', ...
        'CellposeSAM session runner not found: %s', runnerPath);
end

moduleRegistry = [];
moduleName = '';
moduleRegistered = false;
try
    importlibUtil = py.importlib.import_module('importlib.util');
    pySys = py.importlib.import_module('sys');
    moduleRegistry = py.getattr(pySys, 'modules');
    moduleName = localUniqueModuleName();
    spec = importlibUtil.spec_from_file_location(moduleName, runnerPath);
    runnerModule = importlibUtil.module_from_spec(spec);
    % exec_module does not add a module created from a spec to sys.modules.
    % Register it first, as Python's import machinery does, because imported
    % libraries may resolve objects through sys.modules[obj.__module__].
    % Leaving the uniquely named runner unregistered caused the next pyenv
    % health check to raise KeyError and terminate the persistent interpreter.
    setModule = py.getattr(moduleRegistry, '__setitem__');
    setModule(moduleName, runnerModule);
    moduleRegistered = true;
    loader = py.getattr(spec, 'loader');
    execModule = py.getattr(loader, 'exec_module');
    execModule(runnerModule);

    resolvedPath = char(string(py.getattr(runnerModule, '__file__')));
    if ~localSamePath(resolvedPath, runnerPath)
        error('cellposesam:RunnerModulePathMismatch', ...
            'Requested runner "%s", but Python loaded "%s".', ...
            runnerPath, resolvedPath);
    end
    if ~logical(py.hasattr(runnerModule, 'run'))
        error('cellposesam:RunnerEntryPointMissing', ...
            'CellposeSAM runner "%s" does not expose run().', resolvedPath);
    end
    runnerCallable = py.getattr(runnerModule, 'run');
catch ME
    % Do not retain a partially initialized module when execution fails.
    if moduleRegistered && ~isempty(moduleRegistry) && ~isempty(moduleName)
        try
            popModule = py.getattr(moduleRegistry, 'pop');
            popModule(moduleName, py.None);
        catch
            % Preserve the original runner-loading exception.
        end
    end
    if startsWith(ME.identifier, 'cellposesam:')
        rethrow(ME);
    end
    error('cellposesam:RunnerModuleLoadFailed', ...
        'Unable to load CellposeSAM session runner "%s": %s', ...
        runnerPath, ME.message);
end
end

function name = localUniqueModuleName()
[~, token] = fileparts(tempname);
token = regexprep(token, '[^A-Za-z0-9_]', '_');
name = ['detecdiv_cellposesam_runner_' token];
end

function tf = localSamePath(left, right)
left = strrep(char(string(left)), '\', '/');
right = strrep(char(string(right)), '\', '/');
left = regexprep(left, '/+', '/');
right = regexprep(right, '/+', '/');
if ispc
    tf = strcmpi(left, right);
else
    tf = strcmp(left, right);
end
end
