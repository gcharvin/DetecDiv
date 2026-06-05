function event = pipelineRunEvent(ctx, eventType, varargin)
% pipelineRunEvent  Append a structured pipeline run event to JSONL.
%
% Usage:
%   pipelineRunEvent(ctx, 'node_start', 'NodeId', nodeId, 'NodeType', nodeType)
%
% The target ledger path is resolved from ctx.run.eventLogPath,
% ctx.io.eventLogPath, or ctx.store.eventLogPath. If no path is configured,
% the function only returns the event struct and does not write.

    if nargin < 1 || ~isstruct(ctx)
        ctx = struct();
    end
    if nargin < 2 || isempty(eventType)
        eventType = 'event';
    end

    event = struct();
    event.ts = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss.SSS'));
    event.type = char(string(eventType));
    event.runId = localText(localNested(ctx, {'runId'}, localNested(ctx, {'run','runId'}, '')));

    [event, opts] = localApplyNameValue(event, varargin{:});
    event = localSanitizeEvent(event);

    logPath = localResolveEventLogPath(ctx, opts);
    if isempty(logPath)
        return;
    end
    localAppendJsonLine(logPath, event);
end

function [event, opts] = localApplyNameValue(event, varargin)
    opts = struct('EventLogPath', '');
    i = 1;
    while i <= numel(varargin)
        key = char(string(varargin{i}));
        value = [];
        if i < numel(varargin)
            value = varargin{i+1};
        end
        i = i + 2;

        switch lower(key)
            case {'eventlogpath','logpath'}
                opts.EventLogPath = char(string(value));
            otherwise
                fieldName = matlab.lang.makeValidName(key);
                if isempty(fieldName)
                    continue;
                end
                event.(fieldName) = value;
        end
    end
end

function logPath = localResolveEventLogPath(ctx, opts)
    logPath = '';
    if isstruct(opts) && isfield(opts, 'EventLogPath') && ~isempty(opts.EventLogPath)
        logPath = char(string(opts.EventLogPath));
        return;
    end
    logPath = localText(localNested(ctx, {'run','eventLogPath'}, ''));
    if isempty(logPath)
        logPath = localText(localNested(ctx, {'io','eventLogPath'}, ''));
    end
    if isempty(logPath)
        logPath = localText(localNested(ctx, {'store','eventLogPath'}, ''));
    end
end

function localAppendJsonLine(logPath, event)
    folder = fileparts(logPath);
    if ~isempty(folder) && exist(folder, 'dir') ~= 7
        mkdir(folder);
    end
    try
        line = jsonencode(event);
    catch
        line = jsonencode(localSanitizeEvent(event));
    end
    fid = fopen(logPath, 'a');
    if fid < 0
        warning('pipelineRunEvent:IO', 'Unable to append run event log: %s', logPath);
        return;
    end
    cleaner = onCleanup(@()fclose(fid)); %#ok<NASGU>
    fwrite(fid, [line newline], 'char');
end

function event = localSanitizeEvent(event)
    names = fieldnames(event);
    for i = 1:numel(names)
        event.(names{i}) = localSanitizeValue(event.(names{i}));
    end
end

function value = localSanitizeValue(value)
    if isstring(value)
        value = cellstr(value);
        if numel(value) == 1
            value = value{1};
        end
    elseif ischar(value) || isnumeric(value) || islogical(value)
        return;
    elseif iscell(value)
        for i = 1:numel(value)
            value{i} = localSanitizeValue(value{i});
        end
    elseif isstruct(value)
        for i = 1:numel(value)
            names = fieldnames(value(i));
            for j = 1:numel(names)
                value(i).(names{j}) = localSanitizeValue(value(i).(names{j}));
            end
        end
    elseif isobject(value)
        try
            value = char(string(value));
        catch
            value = class(value);
        end
    else
        try
            value = char(string(value));
        catch
            value = [];
        end
    end
end

function value = localNested(S, path, defaultValue)
    value = defaultValue;
    try
        cur = S;
        for i = 1:numel(path)
            key = path{i};
            if isstruct(cur) && isfield(cur, key)
                cur = cur.(key);
            else
                return;
            end
        end
        if ~isempty(cur)
            value = cur;
        end
    catch
        value = defaultValue;
    end
end

function text = localText(value)
    text = '';
    try
        if isempty(value)
            return;
        end
        text = char(string(value));
    catch
        text = '';
    end
end
