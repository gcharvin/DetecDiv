function pattern = loadPattern(shallowObj)
% loadPattern  Load stored ROI pattern from shallowObj.runProfiles.

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
    if isfield(rp.dataloading,'roiIdentify') && isstruct(rp.dataloading.roiIdentify)
        ri = rp.dataloading.roiIdentify;
        if isfield(ri,'patternList') && isstruct(ri.patternList) && ~isempty(ri.patternList)
            pattern = ri.patternList(1);
            return;
        end
    end
    if isfield(rp.dataloading,'pattern') && ~isempty(rp.dataloading.pattern)
        pattern = rp.dataloading.pattern;
    end
end
