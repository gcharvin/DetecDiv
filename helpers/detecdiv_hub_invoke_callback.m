function alive = detecdiv_hub_invoke_callback(callback, payload)
%DETECDIV_HUB_INVOKE_CALLBACK Dispatch without retaining an MLAPP closure.
% Public method descriptors survive App Designer source repacking. A deleted
% owner ends monitoring quietly. Legacy function callbacks remain supported.
alive = true;
if isa(callback, 'function_handle')
    callback(payload);
    return;
end
if ~isstruct(callback) || ~isscalar(callback) || ...
        ~all(isfield(callback, {'owner', 'method', 'args'})) || ~iscell(callback.args)
    error('detecdiv_hub:InvalidCallback', 'Invalid Hub callback descriptor.');
end
owner = callback.owner;
if isempty(owner) || ~isa(owner, 'handle') || ~isscalar(owner) || ~isvalid(owner)
    alive = false;
    return;
end
feval(char(string(callback.method)), owner, payload, callback.args{:});
end
