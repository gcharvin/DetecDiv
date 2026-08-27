function value = censorScope(name)
%CELLMODEL.CENSORSCOPE Stable bit flags for task-specific GT censoring.
% A record may combine flags.  Boundary contact is deliberately absent:
% geometry may suggest review, but only an explicit record censors data.

scopes = struct( ...
    'segmentation', uint16(1), ...
    'tracking', uint16(2), ...
    'appearance', uint16(4), ...
    'end', uint16(8), ...
    'parentage', uint16(16), ...
    'state', uint16(32));
scopes.all = uint16(63);

if nargin < 1 || isempty(name)
    value = scopes;
    return;
end
name = lower(char(string(name)));
if ~isfield(scopes, name)
    error('cellModel:UnknownCensorScope', ...
        'Unknown censoring scope "%s".', name);
end
value = scopes.(name);
end
