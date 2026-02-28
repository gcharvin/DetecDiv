function param = setparam(ctx)
% roiIdentify.setparam  Default params for ROI identification.

    param = struct();
    param.referenceFrame = 1;
    param.threshold = 0.5;
    param.channel = '';
    param.channelIndex = [];
    param.keepExisting = false;
    param.crop = [];
    param.fallbackFullFrame = true;
    param.patternList = struct([]);

    if nargin < 1 || isempty(ctx)
        return;
    end

    if isfield(ctx,'referenceFrame'), param.referenceFrame = ctx.referenceFrame; end
    if isfield(ctx,'threshold'),      param.threshold = ctx.threshold; end
    if isfield(ctx,'channel'),        param.channel = ctx.channel; end
    if isfield(ctx,'channelIndex'),   param.channelIndex = ctx.channelIndex; end
    if isfield(ctx,'keepExisting'),   param.keepExisting = ctx.keepExisting; end
    if isfield(ctx,'crop'),           param.crop = ctx.crop; end
    if isfield(ctx,'fallbackFullFrame'), param.fallbackFullFrame = ctx.fallbackFullFrame; end
end
