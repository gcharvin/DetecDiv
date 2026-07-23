function payload = detecdiv_progress(ctx, localValue, message, varargin)
%detecdiv_progress Emit a structured, pipeline-wide progress event.
%
% Modules report a local value between 0 and 1. The helper maps it to the
% current node/ROI interval, writes a machine-readable console line, and
% invokes ctx.progressCallback when one is available.
%
% Console protocol:
%   @@DETECDIV_PROGRESS@@ {"protocol":"detecdiv.progress.v1",...}

    payload = struct();
    if nargin < 1 || ~isstruct(ctx) || ~progressEnabled(ctx)
        return;
    end
    if nargin < 2 || isempty(localValue)
        localValue = 0;
    end
    if nargin < 3
        message = '';
    end

    parser = inputParser;
    parser.FunctionName = 'detecdiv_progress';
    addParameter(parser, 'Scope', 'module');
    addParameter(parser, 'Current', []);
    addParameter(parser, 'Total', []);
    addParameter(parser, 'Status', 'running');
    addParameter(parser, 'Indeterminate', false);
    parse(parser, varargin{:});

    localValue = double(localValue);
    if ~isscalar(localValue) || ~isfinite(localValue)
        localValue = 0;
    end
    localValue = max(0, min(1, localValue));
    [baseValue, spanValue] = detecdiv_progress_bounds(ctx);
    globalValue = max(0, min(1, baseValue + spanValue * localValue));

    progress = struct();
    if isfield(ctx, 'progress') && isstruct(ctx.progress)
        progress = ctx.progress;
    end

    payload = struct( ...
        'protocol', 'detecdiv.progress.v1', ...
        'value', globalValue, ...
        'localValue', localValue, ...
        'message', char(string(message)), ...
        'status', char(string(parser.Results.Status)), ...
        'scope', char(string(parser.Results.Scope)), ...
        'indeterminate', logical(parser.Results.Indeterminate), ...
        'nodeId', textField(progress, 'currentNodeId'), ...
        'nodeIndex', numericField(progress, 'currentNodeIndex'), ...
        'totalNodes', numericField(progress, 'totalNodes'), ...
        'current', numericValue(parser.Results.Current), ...
        'total', numericValue(parser.Results.Total), ...
        'updatedAt', char(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ss.SSS')));

    marker = '@@DETECDIV_PROGRESS@@';
    try
        fprintf(1, '%s %s\n', marker, jsonencode(payload));
    catch
    end
    try
        if isfield(ctx, 'progressCallback') && ...
                isa(ctx.progressCallback, 'function_handle')
            ctx.progressCallback(payload);
        end
    catch
    end
end

function tf = progressEnabled(ctx)
    tf = false;
    try
        tf = isfield(ctx, 'progressCallback') && ...
            isa(ctx.progressCallback, 'function_handle');
        if ~tf && isfield(ctx, 'progress') && isstruct(ctx.progress) && ...
                isfield(ctx.progress, 'emitConsoleProtocol')
            tf = logical(ctx.progress.emitConsoleProtocol);
        end
    catch
        tf = false;
    end
end

function value = textField(source, fieldName)
    value = '';
    try
        if isstruct(source) && isfield(source, fieldName) && ...
                ~isempty(source.(fieldName))
            value = char(string(source.(fieldName)));
        end
    catch
        value = '';
    end
end

function value = numericField(source, fieldName)
    value = [];
    try
        if isstruct(source) && isfield(source, fieldName)
            value = numericValue(source.(fieldName));
        end
    catch
        value = [];
    end
end

function value = numericValue(candidate)
    value = [];
    try
        candidate = double(candidate);
        if isscalar(candidate) && isfinite(candidate)
            value = candidate;
        end
    catch
        value = [];
    end
end
