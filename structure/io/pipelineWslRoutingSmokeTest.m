function report = pipelineWslRoutingSmokeTest()
% pipelineWslRoutingSmokeTest  Verify WSL settings survive pipeline routing.

    ctx = struct( ...
        'run', struct('executionTarget', 'local_wsl'), ...
        'exec', struct('python', struct( ...
            'backend', 'wsl', ...
            'wslDistro', 'Ubuntu-Test', ...
            'wslEnvPath', '/home/test/venvs/detecdiv_python')));
    [cfg, args] = pipelinePythonPreflightConfig(ctx);
    assert(strcmp(cfg.backend, 'wsl'));
    assert(strcmp(cfg.wslDistro, 'Ubuntu-Test'));
    assert(strcmp(cfg.wslEnvPath, '/home/test/venvs/detecdiv_python'));
    assert(strcmp(localArg(args, 'backend'), 'wsl'));
    assert(strcmp(localArg(args, 'wslDistro'), 'Ubuntu-Test'));
    assert(strcmp(localArg(args, 'wslEnvPath'), ...
        '/home/test/venvs/detecdiv_python'));

    params = pipelineApplyPythonBackendToNodeParams( ...
        struct('backend', 'local'), 'sam31', ctx);
    assert(strcmp(params.backend, 'wsl'));

    controlCtx = struct('run', struct('control', ...
        struct('pythonBackend', 'wsl')));
    params = pipelineApplyPythonBackendToNodeParams( ...
        struct(), 'sam31', controlCtx);
    assert(strcmp(params.backend, 'wsl'));

    unrelated = pipelineApplyPythonBackendToNodeParams( ...
        struct('backend', 'local'), 'cellposesam', ctx);
    assert(strcmp(unrelated.backend, 'local'));

    report = struct('ok', true, 'backend', cfg.backend, ...
        'wslDistro', cfg.wslDistro, 'wslEnvPath', cfg.wslEnvPath);
end

function value = localArg(args, name)
    idx = find(strcmpi(args, name), 1);
    assert(~isempty(idx) && idx < numel(args), ...
        'Missing Python preflight argument: %s', name);
    value = char(string(args{idx+1}));
end
