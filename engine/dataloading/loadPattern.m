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
            idx = 1;
            if isfield(ri,'activePatternIndex') && ~isempty(ri.activePatternIndex)
                try
                    if ri.activePatternIndex >= 1 && ri.activePatternIndex <= numel(ri.patternList)
                        idx = ri.activePatternIndex;
                    end
                catch
                end
            end
            pattern = ri.patternList(idx);
            return;
        end
    end
    if isfield(rp.dataloading,'pattern') && ~isempty(rp.dataloading.pattern)
        pattern = rp.dataloading.pattern;
    end
end
