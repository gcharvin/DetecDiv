function params = pipelineApplyPythonBackendToNodeParams(params, packageName, ctx)
% pipelineApplyPythonBackendToNodeParams  Apply the run Python target to a node.

    if nargin < 1 || ~isstruct(params)
        params = struct();
    end
    if nargin < 2
        packageName = '';
    end
    if nargin < 3 || ~isstruct(ctx)
        ctx = struct();
    end

    packageName = lower(strtrim(char(string(packageName))));
    if ~strcmp(packageName, 'sam31')
        return;
    end

    target = localExecutionTarget(ctx);
    target = strrep(target, '-', '_');
    target = strrep(target, ' ', '_');
    if any(strcmp(target, {'local_wsl','wsl','localwsl','local_linux','local/wsl','linux'}))
        params.backend = 'wsl';
    elseif any(strcmp(target, {'local','windows','local_windows','local_matlab'}))
        params.backend = 'local';
    end
end

function target = localExecutionTarget(ctx)
    target = '';
    try
        if isfield(ctx, 'run') && isstruct(ctx.run) && ...
                isfield(ctx.run, 'executionTarget') && ~isempty(ctx.run.executionTarget)
            target = lower(strtrim(char(string(ctx.run.executionTarget))));
            return;
        end
    catch
    end
    try
        if isfield(ctx, 'exec') && isstruct(ctx.exec) && ...
                isfield(ctx.exec, 'python') && isstruct(ctx.exec.python) && ...
                isfield(ctx.exec.python, 'backend') && ~isempty(ctx.exec.python.backend)
            target = lower(strtrim(char(string(ctx.exec.python.backend))));
            return;
        end
    catch
    end
    try
        if isfield(ctx, 'run') && isstruct(ctx.run) && ...
                isfield(ctx.run, 'control') && isstruct(ctx.run.control) && ...
                isfield(ctx.run.control, 'pythonBackend') && ~isempty(ctx.run.control.pythonBackend)
            target = lower(strtrim(char(string(ctx.run.control.pythonBackend))));
        end
    catch
    end
end
