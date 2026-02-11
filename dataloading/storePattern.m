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
    shallowObj.runProfiles = rp;
end
