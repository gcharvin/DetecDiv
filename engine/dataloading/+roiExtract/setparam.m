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
    drift = roiExtract.driftDefaults();
    param.driftMethod = drift.method;
    param.driftRefMode = drift.refMode;
    param.driftSubpixel = drift.subpixel;
    param.driftMaxShift = drift.maxShift;
    param.driftMaxStep = drift.maxStep;
    param.driftPsrMin = drift.psrMin;
    param.driftReferenceInterval = drift.referenceInterval;
    param.scale = 1;
    param.binning = [];
    param.cropDrift = 1.0;
    % Execution mode is persisted with the roiExtract node.  In parallel
    % mode, the Hub-provided worker limit below remains a capacity ceiling.
    param.executionMode = 'parallel';
    % Number of independent FOV tasks. One remains the safe local default;
    % Hub workers may raise it when enough memory/cores are available.
    param.parallelFovWorkers = 1;

    if nargin < 1 || isempty(ctx)
        return;
    end
end
