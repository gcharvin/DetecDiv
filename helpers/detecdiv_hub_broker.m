function out = detecdiv_hub_broker(action, varargin)
% detecdiv_hub_broker  Manage one background worker for all Hub traffic.
%
% Register periodic or one-shot tasks without placing timers or network I/O
% on MATLAB's UI thread. The broker owns one background Future and routes
% small result payloads back to client callbacks through a DataQueue.

    persistent broker
    if isempty(broker)
        broker = localEmptyBroker();
    end
    out = [];
    action = lower(char(string(action)));

    switch action
        case 'register'
            kind = char(string(varargin{1}));
            config = varargin{2};
            callback = varargin{3};
            [broker, token] = localEnsureBroker(broker);
            key = localTokenKey(token);
            broker.callbacks.(key) = callback;
            send(broker.commandQueue, struct('action', 'register', ...
                'token', token, 'kind', kind, 'config', config));
            out = token;

        case 'unregister'
            token = char(string(varargin{1}));
            key = localTokenKey(token);
            if isfield(broker.callbacks, key)
                broker.callbacks = rmfield(broker.callbacks, key);
            end
            if localBrokerRunning(broker)
                send(broker.commandQueue, struct('action', 'unregister', ...
                    'token', token, 'kind', '', 'config', struct()));
            end
            out = true;

        case 'dispatch'
            payload = varargin{1};
            if ~isstruct(payload) || ~isfield(payload, 'token')
                return;
            end
            key = localTokenKey(payload.token);
            if isfield(broker.callbacks, key)
                callback = broker.callbacks.(key);
                try
                    callback(payload);
                catch ME
                    warning('detecdiv_hub:brokerCallback', ...
                        'Hub background callback failed: %s', ME.message);
                end
                if isfield(payload, 'stop') && logical(payload.stop) && ...
                        isfield(broker.callbacks, key)
                    broker.callbacks = rmfield(broker.callbacks, key);
                end
            end

        case 'shutdown'
            if localBrokerRunning(broker)
                try
                    send(broker.commandQueue, struct('action', 'shutdown', ...
                        'token', '', 'kind', '', 'config', struct()));
                catch
                end
                try
                    cancel(broker.future);
                catch
                end
            end
            try
                if ~isempty(broker.listener) && isvalid(broker.listener)
                    delete(broker.listener);
                end
            catch
            end
            broker = localEmptyBroker();
            out = true;

        case 'status'
            out = struct('running', localBrokerRunning(broker), ...
                'subscriptionCount', numel(fieldnames(broker.callbacks)), ...
                'futureState', localFutureField(broker.future, 'State'), ...
                'futureError', localFutureErrorText(broker.future), ...
                'futureDiary', localFutureField(broker.future, 'Diary'));

        otherwise
            error('detecdiv_hub_broker:BadAction', ...
                'Unsupported Hub broker action: %s', action);
    end
end

function [broker, token] = localEnsureBroker(broker)
    if ~localBrokerRunning(broker)
        try
            if ~isempty(broker.listener) && isvalid(broker.listener)
                delete(broker.listener);
            end
        catch
        end
        broker = localEmptyBroker();
        broker.commandQueue = parallel.pool.PollableDataQueue(Destination="any");
        broker.resultQueue = parallel.pool.DataQueue;
        broker.listener = afterEach(broker.resultQueue, ...
            @(payload)detecdiv_hub_broker('dispatch', payload));
        broker.future = parfeval(backgroundPool, @detecdiv_hub_broker_worker, ...
            0, broker.commandQueue, broker.resultQueue);
    end
    token = char(java.util.UUID.randomUUID);
end

function tf = localBrokerRunning(broker)
    tf = false;
    try
        tf = ~isempty(broker.future) && isvalid(broker.future) && ...
            any(strcmpi(char(string(broker.future.State)), {'queued','running'}));
    catch
    end
end

function broker = localEmptyBroker()
    broker = struct('future', [], 'commandQueue', [], 'resultQueue', [], ...
        'listener', [], 'callbacks', struct());
end

function key = localTokenKey(token)
    key = matlab.lang.makeValidName(['k_' char(string(token))]);
end

function value = localFutureField(future, name)
    value = '';
    try
        if ~isempty(future) && isvalid(future)
            value = char(string(future.(name)));
        end
    catch
    end
end

function value = localFutureErrorText(future)
    value = '';
    try
        if ~isempty(future) && isvalid(future) && ~isempty(future.Error)
            value = char(string(future.Error.message));
        end
    catch
    end
end
