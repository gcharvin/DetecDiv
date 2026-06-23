function detecdiv_check_cancel(source, where)
% detecdiv_check_cancel  Cooperative cancellation check for pipeline modules.

if nargin < 1
    source = [];
end
if nargin < 2 || isempty(where)
    where = 'run';
end

tokenFile = '';
cancelRequested = false;

try
    if ischar(source) || (isstring(source) && isscalar(source))
        tokenFile = char(string(source));
    elseif isstruct(source)
        if isfield(source, 'cancel') && isstruct(source.cancel) ...
                && isfield(source.cancel, 'tokenFile') && ~isempty(source.cancel.tokenFile)
            tokenFile = char(string(source.cancel.tokenFile));
        elseif isfield(source, 'tokenFile') && ~isempty(source.tokenFile)
            tokenFile = char(string(source.tokenFile));
        elseif isfield(source, 'CancelTokenFile') && ~isempty(source.CancelTokenFile)
            tokenFile = char(string(source.CancelTokenFile));
        elseif isfield(source, 'cancelTokenFile') && ~isempty(source.cancelTokenFile)
            tokenFile = char(string(source.cancelTokenFile));
        end
        if isfield(source, 'cancelled') && ~isempty(source.cancelled)
            cancelRequested = cancelRequested || logical(source.cancelled);
        end
        if isfield(source, 'canceled') && ~isempty(source.canceled)
            cancelRequested = cancelRequested || logical(source.canceled);
        end
    elseif ~isempty(source) && isvalidHandleLocal(source)
        if isprop(source, 'CancelRequested') && source.CancelRequested
            cancelRequested = true;
        end
    end
catch
    tokenFile = '';
end

try
    if ~isempty(tokenFile) && exist(tokenFile, 'file') == 2
        cancelRequested = true;
    end
catch
end

if cancelRequested
    error('runPipeline:Cancelled', 'Pipeline run cancelled by user at %s.', char(string(where)));
end
end

function tf = isvalidHandleLocal(h)
tf = false;
try
    tf = ~isempty(h) && isvalid(h);
catch
    try
        tf = ~isempty(h) && ishghandle(h);
    catch
        tf = false;
    end
end
end
