function p = setparam(p)
% roiPattern.setparam  Default parameters for pattern-based ROI detection.

    if nargin < 1 || isempty(p) || ~isstruct(p)
        p = struct();
    end

    defaults = struct( ...
        'referenceFrame', 1, ...
        'threshold', 0.5, ...
        'channel', '', ...
        'channelIndex', [], ...
        'keepExisting', false, ...
        'pattern', struct([]), ...
        'fovIndex', []);

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
end
