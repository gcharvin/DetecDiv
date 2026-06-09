function out = detecdiv_event(action, eventName, varargin)
% detecdiv_event  Small in-process event broker for decoupled DetecDiv apps.
%
%   id = detecdiv_event('subscribe', 'workspaceChanged', callback)
%   detecdiv_event('unsubscribe', id)
%   detecdiv_event('emit', 'workspaceChanged', payload)
%
% Callbacks receive (payload, eventName). The broker is process-local and
% intentionally lightweight: it only coordinates MATLAB apps sharing the
% same session/workspace.

    if nargin < 1
        error('detecdiv_event:MissingAction', 'Action is required.');
    end

    action = lower(strtrim(char(string(action))));
    switch action
        case {'subscribe', 'on'}
            if nargin < 3 || isempty(varargin{1}) || ~isa(varargin{1}, 'function_handle')
                error('detecdiv_event:MissingCallback', 'A callback function handle is required.');
            end
            out = localSubscribe(eventName, varargin{1});
        case {'unsubscribe', 'off'}
            if nargin < 2
                out = false;
            else
                out = localUnsubscribe(eventName);
            end
        case {'emit', 'publish', 'notify'}
            payload = struct();
            if ~isempty(varargin)
                payload = varargin{1};
            end
            out = localEmit(eventName, payload);
        case {'clear', 'reset'}
            if isappdata(groot, localAppdataKey())
                rmappdata(groot, localAppdataKey());
            end
            out = true;
        otherwise
            error('detecdiv_event:BadAction', 'Unknown action: %s.', action);
    end
end

function id = localSubscribe(eventName, callback)
    eventName = localEventName(eventName);
    listeners = localGetListeners();
    id = char(java.util.UUID.randomUUID);
    listeners(end + 1) = struct( ...
        'id', id, ...
        'eventName', eventName, ...
        'callback', callback); %#ok<AGROW>
    localSetListeners(listeners);
end

function removed = localUnsubscribe(id)
    removed = false;
    id = char(string(id));
    if isempty(id)
        return;
    end
    listeners = localGetListeners();
    if isempty(listeners)
        return;
    end
    keep = ~strcmp({listeners.id}, id);
    removed = any(~keep);
    listeners = listeners(keep);
    localSetListeners(listeners);
end

function nCalled = localEmit(eventName, payload)
    eventName = localEventName(eventName);
    listeners = localGetListeners();
    nCalled = 0;
    if isempty(listeners)
        return;
    end

    stale = false(size(listeners));
    for i = 1:numel(listeners)
        if ~strcmp(listeners(i).eventName, eventName) && ~strcmp(listeners(i).eventName, '*')
            continue;
        end
        try
            listeners(i).callback(payload, eventName);
            nCalled = nCalled + 1;
        catch ME
            stale(i) = true;
            warning('detecdiv_event:ListenerFailed', ...
                'Listener %s failed for event %s: %s', listeners(i).id, eventName, ME.message);
        end
    end
    if any(stale)
        listeners = listeners(~stale);
        localSetListeners(listeners);
    end
end

function listeners = localGetListeners()
    key = localAppdataKey();
    if isappdata(groot, key)
        listeners = getappdata(groot, key);
    else
        listeners = struct('id', {}, 'eventName', {}, 'callback', {});
    end
end

function localSetListeners(listeners)
    setappdata(groot, localAppdataKey(), listeners);
end

function name = localEventName(eventName)
    name = strtrim(char(string(eventName)));
    if isempty(name)
        error('detecdiv_event:MissingEventName', 'Event name is required.');
    end
end

function key = localAppdataKey()
    key = 'detecdivEventListeners';
end
