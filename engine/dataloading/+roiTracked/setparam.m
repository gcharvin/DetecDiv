function p = setparam(p)
% roiTracked.setparam  Default parameters for tracked-cell ROI generation.

    if nargin < 1 || isempty(p) || ~isstruct(p)
        p = struct();
    end

    defaults = struct( ...
        'fovIndex', [], ...
        'roiIndex', [], ...
        'channel', '', ...
        'margin', 0, ...
        'extract', true, ...
        'extractFrames', [], ...
        'extractChannels', [], ...
        'saveArgs', {{}});

    fn = fieldnames(defaults);
    for i = 1:numel(fn)
        k = fn{i};
        if ~isfield(p, k) || isempty(p.(k))
            p.(k) = defaults.(k);
        end
    end

    if ~isempty(p.fovIndex)
        p.fovIndex = round(double(p.fovIndex(:)'));
        p.fovIndex = p.fovIndex(isfinite(p.fovIndex) & p.fovIndex >= 1);
        p.fovIndex = unique(p.fovIndex, 'stable');
    else
        p.fovIndex = [];
    end

    if ~isempty(p.roiIndex)
        p.roiIndex = round(double(p.roiIndex(:)'));
        p.roiIndex = p.roiIndex(isfinite(p.roiIndex) & p.roiIndex >= 1);
        p.roiIndex = unique(p.roiIndex, 'stable');
    else
        p.roiIndex = [];
    end

    if isempty(p.channel)
        p.channel = '';
    else
        p.channel = char(string(p.channel));
    end

    if isempty(p.margin) || ~isscalar(p.margin) || ~isfinite(p.margin)
        p.margin = 0;
    end
    p.margin = max(0, double(p.margin));

    p.extract = logical(p.extract);

    if isempty(p.extractFrames)
        p.extractFrames = [];
    else
        p.extractFrames = round(double(p.extractFrames(:)'));
        p.extractFrames = p.extractFrames(isfinite(p.extractFrames) & p.extractFrames >= 1);
        p.extractFrames = unique(p.extractFrames, 'stable');
    end

    if isempty(p.extractChannels)
        p.extractChannels = [];
    else
        p.extractChannels = round(double(p.extractChannels(:)'));
        p.extractChannels = p.extractChannels(isfinite(p.extractChannels) & p.extractChannels >= 1);
        p.extractChannels = unique(p.extractChannels, 'stable');
    end

    if ~iscell(p.saveArgs)
        p.saveArgs = {};
    end
end
