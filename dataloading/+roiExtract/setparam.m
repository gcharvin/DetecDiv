function param = setparam(ctx)
% roiExtract.setparam  Default params for ROI extraction.

    param = struct();
    param.frames = [];
    param.channels = {};
    param.extend = false;
    param.forceChannelNames = true;
    param.correctDrift = true;
    param.driftChannel = [];
    param.driftMethod = 'subpixel';
    param.scale = 1;
    param.cropDrift = 1.0;

    if nargin < 1 || isempty(ctx)
        return;
    end
end
