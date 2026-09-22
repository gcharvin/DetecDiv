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
    param.binning = [];
    param.cropDrift = 1.0;
    % Number of independent FOV tasks.  One remains the safe local default;
    % Hub workers may override it when enough memory/cores are available.
    param.parallelFovWorkers = 1;

    if nargin < 1 || isempty(ctx)
        return;
    end
end
