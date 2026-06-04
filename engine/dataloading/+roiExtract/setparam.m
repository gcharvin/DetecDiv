function param = setparam(ctx)
% roiExtract.setparam  Default params for ROI extraction.

    param = struct();
    param.fovIndex = [];
    param.frames = [];
    param.channels = {};
    param.extractChannels = '@source';
    param.roiList = [];
    param.extend = false;
    param.forceChannelNames = true;
    param.correctDrift = true;
    param.driftChannel = [];
    param.driftMethod = 'subpixel';
    param.driftRefMode = 'previous';
    param.driftSubpixel = true;
    param.driftMaxShift = 20;
    param.scale = 1;
    param.cropDrift = 1.0;

    if nargin < 1 || isempty(ctx)
        return;
    end
end
