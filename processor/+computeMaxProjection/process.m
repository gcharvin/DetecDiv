function [paramout, dataout, imageout] = process(param, roiobj, ctx)
% computeMaxProjection.process  Pipeline-compatible wrapper.

if nargin < 3
    ctx = struct();
elseif ~isstruct(ctx)
    ctx = struct('frames', ctx);
end

if nargin == 0 || isempty(param)
    paramout = computeMaxProjection.setparam(ctx);
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
    if isempty(roiobj.image)
        try
            roiobj.load;
        catch
        end
    end
    if ~isempty(roiobj.image)
        frames = 1:size(roiobj.image,4);
    end
end

if isempty(frames)
    [paramout, dataout, imageout] = computeMaxProjection(paramout, roiobj);
else
    [paramout, dataout, imageout] = computeMaxProjection(paramout, roiobj, frames);
end
end
