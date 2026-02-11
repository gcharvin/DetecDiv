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

paramout = param;
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
