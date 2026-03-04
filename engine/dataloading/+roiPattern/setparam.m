function p = setparam(p)
% roiPattern.setparam  Default parameters for pattern-based ROI detection.

    if nargin < 1 || isempty(p) || ~isstruct(p)
        p = struct();
    end

    try
        defaults = roiIdentify.setparam(struct());
    catch
        defaults = struct();
    end

    if isempty(fieldnames(defaults))
        defaults = struct( ...
            'referenceFrame', 1, ...
            'threshold', 0.5, ...
            'channel', '', ...
            'channelIndex', [], ...
            'keepExisting', false, ...
            'patternList', [], ...
            'activePatternIndex', 1, ...
            'fallbackFullFrame', true, ...
            'fovIndex', []);
    end

    if ~isfield(defaults, 'fovIndex')
        defaults.fovIndex = [];
    end

    fn = fieldnames(defaults);
    for i = 1:numel(fn)
        k = fn{i};
        if ~isfield(p, k) || isempty(p.(k))
            p.(k) = defaults.(k);
        end
    end
end
