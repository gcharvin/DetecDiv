function [mode, choices] = driftReferenceMode(method, requested)
% DRIFTREFERENCEMODE Normalize the effective policy, including legacy aliases.
% Explicit robust/fixed retains the historical immutable-anchor policy.
% Robust/previous historically meant fixed; keep that interpretation.
if nargin<2, requested=''; end
mode=lower(char(string(requested)));
if any(strcmp(mode,{'anchor','first'})), mode='fixed'; end
if strcmpi(method,'robust')
    choices={'adaptive','fixed'};
    if isempty(mode), mode='adaptive'; end
    if strcmp(mode,'previous'), mode='fixed'; end
else
    choices={'fixed','previous'};
    if isempty(mode), mode='fixed'; end
end
if ~any(strcmp(mode,choices))
    error('roiExtract:InvalidDriftReferenceMode', ...
        'Reference mode "%s" is not supported for drift method "%s".',mode,method);
end
end
