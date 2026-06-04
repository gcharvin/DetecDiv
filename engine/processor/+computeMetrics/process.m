function [paramout, dataout, imageout] = process(param, roiobj, ctx)
% computeMetrics.process  Pipeline-compatible wrapper for computeMetrics.

if nargin < 3
    ctx = struct();
elseif ~isstruct(ctx)
    ctx = struct('frames', ctx);
end

if nargin == 0 || isempty(param)
    paramout = computeMetrics.setparam(ctx);
    dataout = [];
    imageout = [];
    return;
end

ctxWithParams = ctx;
if isstruct(ctxWithParams)
    ctxWithParams.params = param;
end
paramout = mergeComputeMetricsDefaults(computeMetrics.setparam(ctxWithParams), param);
dataout = [];
imageout = [];

frames = [];
if isfield(ctx,'frames') && ~isempty(ctx.frames)
    frames = ctx.frames;
end

if isempty(frames) || (isnumeric(frames) && all(frames == -1))
    [paramout, dataout, imageout] = computeMetrics.core(paramout, roiobj);
else
    [paramout, dataout, imageout] = computeMetrics.core(paramout, roiobj, frames);
end
end

function out = mergeComputeMetricsDefaults(defaults, override)
out = defaults;
if isempty(override)
    return;
end
if ~isstruct(override)
    out = override;
    return;
end
names = fieldnames(override);
for i = 1:numel(names)
    out.(names{i}) = override.(names{i});
end
end
