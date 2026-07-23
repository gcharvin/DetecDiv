function [cfg, args] = pipelinePythonPreflightConfig(ctx)
% pipelinePythonPreflightConfig  Normalize Python bootstrap settings for a run.

    if nargin < 1 || ~isstruct(ctx)
        ctx = struct();
    end
    cfg = struct('mode', 'default', 'envName', '', 'envPath', '', ...
        'backend', 'local', 'wslDistro', '', 'wslEnvPath', '');
    try
        if isfield(ctx,'exec') && isstruct(ctx.exec) && ...
                isfield(ctx.exec,'python') && isstruct(ctx.exec.python)
            py = ctx.exec.python;
            cfg.mode = localText(py, 'mode', cfg.mode);
            cfg.envName = localText(py, 'envName', cfg.envName);
            cfg.envPath = localText(py, 'envPath', cfg.envPath);
            cfg.backend = lower(localText(py, 'backend', cfg.backend));
            cfg.wslDistro = localText(py, 'wslDistro', cfg.wslDistro);
            cfg.wslEnvPath = localText(py, 'wslEnvPath', cfg.wslEnvPath);
        end
    catch
    end

    target = '';
    try
        if isfield(ctx,'run') && isstruct(ctx.run) && ...
                isfield(ctx.run,'executionTarget') && ~isempty(ctx.run.executionTarget)
            target = lower(char(string(ctx.run.executionTarget)));
        end
    catch
    end
    if any(strcmp(target, {'local_wsl','wsl','local_linux','linux'}))
        cfg.backend = 'wsl';
    end
    if ~any(strcmp(cfg.mode, {'default','custom'}))
        cfg.mode = 'default';
    end
    if any(strcmp(cfg.backend, {'local_wsl','wsl','local_linux','linux'}))
        cfg.backend = 'wsl';
    else
        cfg.backend = 'local';
    end

    args = {'debug', true, 'mode', cfg.mode, 'backend', cfg.backend};
    if strcmp(cfg.mode, 'custom')
        args = [args {'envName', cfg.envName}]; %#ok<AGROW>
        if ~isempty(cfg.envPath)
            args = [args {'envPath', cfg.envPath}]; %#ok<AGROW>
        end
    end
    if strcmp(cfg.backend, 'wsl')
        if ~isempty(cfg.wslDistro)
            args = [args {'wslDistro', cfg.wslDistro}]; %#ok<AGROW>
        end
        if ~isempty(cfg.wslEnvPath)
            args = [args {'wslEnvPath', cfg.wslEnvPath}]; %#ok<AGROW>
        end
    end
end

function value = localText(S, name, fallback)
    value = fallback;
    if isstruct(S) && isfield(S, name) && ~isempty(S.(name))
        value = char(string(S.(name)));
    end
end
