function detecdiv_hub_broker_worker(resultQueue, bootstrapQueue)
% detecdiv_hub_broker_worker  Background event loop for Hub communications.

    % The worker must create the command queue so it can poll it on MATLAB
    % releases before R2025a. Return the connected queue to the client
    % through a client-owned bootstrap queue.
    commandQueue = parallel.pool.PollableDataQueue;
    send(bootstrapQueue, commandQueue);

    tasks = struct();
    epoch = tic;
    keepRunning = true;
    hasSeenTask = false;

    while keepRunning
        [command, hasCommand] = poll(commandQueue, 0.2);
        while hasCommand
            [tasks, keepRunning] = localApplyCommand(tasks, command, toc(epoch));
            if isstruct(command) && isfield(command, 'action') && ...
                    strcmpi(char(string(command.action)), 'register')
                hasSeenTask = true;
            end
            if ~keepRunning
                return;
            end
            [command, hasCommand] = poll(commandQueue, 0);
        end

        names = fieldnames(tasks);
        nowSeconds = toc(epoch);
        for i = 1:numel(names)
            key = names{i};
            if ~isfield(tasks, key)
                continue;
            end
            task = tasks.(key);
            if nowSeconds < task.nextDue
                continue;
            end
            payload = localExecuteTask(task);
            payload.stop = payload.stop || (task.iteration + 1 >= task.maxIterations);
            send(resultQueue, payload);
            task.iteration = task.iteration + 1;
            if payload.stop || task.iteration >= task.maxIterations
                tasks = rmfield(tasks, key);
            else
                task.nextDue = toc(epoch) + task.periodSeconds;
                tasks.(key) = task;
            end
        end
        if hasSeenTask && isempty(fieldnames(tasks))
            return;
        end
    end
end

function [tasks, keepRunning] = localApplyCommand(tasks, command, nowSeconds)
    keepRunning = true;
    if ~isstruct(command) || ~isfield(command, 'action')
        return;
    end
    action = lower(char(string(command.action)));
    switch action
        case 'register'
            token = char(string(command.token));
            key = localTokenKey(token);
            config = command.config;
            tasks.(key) = struct( ...
                'token', token, ...
                'kind', lower(char(string(command.kind))), ...
                'config', config, ...
                'periodSeconds', localNumber(config, 'periodSeconds', 15), ...
                'maxIterations', localNumber(config, 'maxIterations', Inf), ...
                'iteration', 0, ...
                'nextDue', nowSeconds);
        case 'unregister'
            key = localTokenKey(command.token);
            if isfield(tasks, key)
                tasks = rmfield(tasks, key);
            end
        case 'shutdown'
            keepRunning = false;
    end
end

function payload = localExecuteTask(task)
    payload = struct('token', task.token, 'kind', task.kind, ...
        'ok', false, 'stop', false, 'data', struct(), ...
        'errorIdentifier', '', 'errorMessage', '', ...
        'completedAt', char(datetime('now')));
    try
        switch task.kind
            case 'run_status'
                job = detecdiv_hub_get_pipeline_run( ...
                    task.config.jobId, task.config.hub);
                payload.ok = true;
                payload.data = job;
                status = localTextField(job, 'status');
                payload.stop = any(strcmpi(status, {'done','failed','cancelled'}));
            case 'lease_heartbeat'
                lease = detecdiv_hub_heartbeat_project_lease( ...
                    task.config.projectRef, task.config.lockId, ...
                    'Hub', task.config.hub, ...
                    'TtlSeconds', task.config.ttlSeconds);
                payload.ok = true;
                payload.data = lease;
            case 'request'
                requestPayload = [];
                if isfield(task.config, 'payload')
                    requestPayload = task.config.payload;
                end
                [data, info] = detecdiv_hub_request( ...
                    task.config.method, task.config.apiPath, ...
                    requestPayload, task.config.hub);
                payload.ok = true;
                payload.data = struct('body', data, 'info', info);
                payload.stop = true;
            otherwise
                error('detecdiv_hub_broker_worker:BadTask', ...
                    'Unsupported Hub broker task: %s', task.kind);
        end
    catch ME
        payload.errorIdentifier = char(string(ME.identifier));
        payload.errorMessage = char(string(ME.message));
        if strcmp(task.kind, 'lease_heartbeat')
            payload.stop = localIsMissingLeaseError(ME);
        end
    end
end

function tf = localIsMissingLeaseError(ME)
    msg = lower(char(string(ME.message)));
    id = lower(char(string(ME.identifier)));
    tf = contains(msg, 'active project lease not found') || ...
        contains(msg, 'lease not found') || contains(id, 'http404');
end

function value = localNumber(S, name, defaultValue)
    value = defaultValue;
    try
        if isstruct(S) && isfield(S, name) && ~isempty(S.(name))
            value = double(S.(name));
        end
    catch
    end
end

function txt = localTextField(S, name)
    txt = '';
    try
        if isstruct(S) && isfield(S, name) && ~isempty(S.(name))
            txt = char(string(S.(name)));
        end
    catch
    end
end

function key = localTokenKey(token)
    key = matlab.lang.makeValidName(['k_' char(string(token))]);
end
