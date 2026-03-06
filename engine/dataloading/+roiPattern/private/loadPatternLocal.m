function pattern = loadPatternLocal(shallowObj)
% loadPatternLocal  Load stored ROI pattern from shallowObj.runProfiles.

    pattern = struct();
    if nargin < 1 || isempty(shallowObj)
        return;
    end
    if ~isprop(shallowObj,'runProfiles') || isempty(shallowObj.runProfiles)
        return;
    end

    rp = shallowObj.runProfiles;
    if ~isfield(rp,'dataloading') || isempty(rp.dataloading)
        return;
    end
    dl = rp.dataloading;

    if isfield(dl,'roiPattern') && isstruct(dl.roiPattern)
        pattern = pickActivePattern(dl.roiPattern);
        if ~isempty(pattern)
            return;
        end
    end

    % Legacy compatibility path.
    if isfield(dl,'roiIdentify') && isstruct(dl.roiIdentify)
        pattern = pickActivePattern(dl.roiIdentify);
        if ~isempty(pattern)
            return;
        end
    end

    if isfield(dl,'pattern') && ~isempty(dl.pattern)
        pattern = dl.pattern;
    end
end

function pattern = pickActivePattern(cfg)
pattern = struct();
if ~isstruct(cfg)
    return;
end
if ~isfield(cfg,'patternList') || ~isstruct(cfg.patternList) || isempty(cfg.patternList)
    return;
end
idx = 1;
if isfield(cfg,'activePatternIndex') && ~isempty(cfg.activePatternIndex)
    try
        if cfg.activePatternIndex >= 1 && cfg.activePatternIndex <= numel(cfg.patternList)
            idx = cfg.activePatternIndex;
        end
    catch
    end
end
pattern = cfg.patternList(idx);
end