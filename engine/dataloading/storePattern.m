function storePattern(shallowObj, pattern)
% storePattern  Store ROI pattern in shallowObj.runProfiles.

    if nargin < 2 || isempty(pattern) || isempty(shallowObj)
        return;
    end
    if ~isprop(shallowObj,'runProfiles') || isempty(shallowObj.runProfiles)
        shallowObj.runProfiles = struct();
    end
    rp = shallowObj.runProfiles;
    if ~isfield(rp,'dataloading') || isempty(rp.dataloading)
        rp.dataloading = struct();
    end
    pattern.updatedAt = datetime('now');
    rp.dataloading.pattern = pattern;

    if ~isfield(rp.dataloading,'roiIdentify') || ~isstruct(rp.dataloading.roiIdentify)
        rp.dataloading.roiIdentify = struct();
    end
    if ~isfield(rp.dataloading.roiIdentify,'patternList') || ~isstruct(rp.dataloading.roiIdentify.patternList)
        rp.dataloading.roiIdentify.patternList = pattern;
    else
        pats = rp.dataloading.roiIdentify.patternList;
        replaced = false;
        for i = 1:numel(pats)
            sameFov = false;
            try
                sameFov = isfield(pats(i),'fovId') && isfield(pattern,'fovId') && strcmp(char(string(pats(i).fovId)), char(string(pattern.fovId)));
            catch
            end
            if sameFov
                pats(i) = pattern;
                replaced = true;
                break;
            end
        end
        if ~replaced
            pats(end+1) = pattern;
        end
        rp.dataloading.roiIdentify.patternList = pats;
    end

    shallowObj.runProfiles = rp;
end
