function [paramout, dataout, imageout] = process(param, roiobj, ctx)
% computeLineage.process  Pipeline-compatible wrapper for computeLineage.

if nargin < 3
    ctx = struct();
elseif ~isstruct(ctx)
    ctx = struct('frames', ctx);
end

if nargin == 0 || isempty(param)
    paramout = computeLineage.setparam(ctx);
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
    [paramout, dataout, imageout] = computeLineage.core(paramout, roiobj);
else
    [paramout, dataout, imageout] = computeLineage.core(paramout, roiobj, frames);
end
end
