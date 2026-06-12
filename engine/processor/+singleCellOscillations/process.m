function [paramout, dataout, imageout] = process(param, roiobj, ctx)
% singleCellOscillations.process  Pipeline-compatible oscillation analysis.

if nargin < 3
    ctx = struct();
elseif ~isstruct(ctx)
    ctx = struct('frames', ctx);
end

if nargin == 0 || isempty(param)
    paramout = singleCellOscillations.setparam(ctx);
    dataout = [];
    imageout = [];
    return;
end

paramout = mergeOscillationDefaults(singleCellOscillations.setparam(ctx), param);
dataout = [];
imageout = [];

frames = localFramesFromCtx(ctx);
if isempty(frames) || (isnumeric(frames) && all(frames == -1))
    [paramout, dataout, imageout] = singleCellOscillations.core(paramout, roiobj);
else
    [paramout, dataout, imageout] = singleCellOscillations.core(paramout, roiobj, frames);
end
end

function out = mergeOscillationDefaults(defaults, override)
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

function frames = localFramesFromCtx(ctx)
frames = [];
if isstruct(ctx) && isfield(ctx, 'frames')
    frames = ctx.frames;
elseif isstruct(ctx) && isfield(ctx, 'sel') && isstruct(ctx.sel) && isfield(ctx.sel, 'frames')
    frames = ctx.sel.frames;
end
end
