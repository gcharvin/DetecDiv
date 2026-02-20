function [paramout, dataout, imageout] = process(param, roiobj, ctx)
% computeRLS.process  Pipeline-compatible wrapper for computeRLS.

if nargin < 3
    ctx = struct();
elseif ~isstruct(ctx)
    ctx = struct('frames', ctx);
end

if nargin == 0 || isempty(param)
    paramout = computeRLS.setparam(ctx);
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
    [paramout, dataout, imageout] = computeRLS.core(paramout, roiobj);
else
    [paramout, dataout, imageout] = computeRLS.core(paramout, roiobj, frames);
end
end
