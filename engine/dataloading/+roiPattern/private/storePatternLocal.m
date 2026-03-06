function storePatternLocal(shallowObj, pattern)
% storePatternLocal  Store ROI pattern in shallowObj.runProfiles.

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

    if ~isfield(rp.dataloading,'roiPattern') || ~isstruct(rp.dataloading.roiPattern)
        rp.dataloading.roiPattern = struct();
    end
    rp.dataloading.roiPattern.patternList = upsertPatternList(rp.dataloading.roiPattern, pattern);

    % Legacy mirror to keep old callers functional during migration.
    if ~isfield(rp.dataloading,'roiIdentify') || ~isstruct(rp.dataloading.roiIdentify)
        rp.dataloading.roiIdentify = struct();
    end
    rp.dataloading.roiIdentify.patternList = upsertPatternList(rp.dataloading.roiIdentify, pattern);

    shallowObj.runProfiles = rp;
end

function list = upsertPatternList(cfg, pattern)
list = struct([]);
if isfield(cfg,'patternList') && isstruct(cfg.patternList) && ~isempty(cfg.patternList)
    list = cfg.patternList;
end

if isempty(list)
    list = pattern;
    return;
end

allFields = union(fieldnames(pattern), fieldnames(list));
for i = 1:numel(allFields)
    fn = allFields{i};
    if ~isfield(pattern, fn)
        pattern.(fn) = [];
    end
    for j = 1:numel(list)
        if ~isfield(list(j), fn)
            list(j).(fn) = [];
        end
    end
end

replaced = false;
for i = 1:numel(list)
    if samePatternScope(list(i), pattern)
        list(i) = orderfields(pattern, list(i));
        replaced = true;
        break;
    end
end

if ~replaced
    list(end+1) = pattern;
end

list = orderfields(list);
end

function tf = samePatternScope(a, b)
tf = false;
try
    if isfield(a,'fovId') && isfield(b,'fovId') && ~isempty(a.fovId) && ~isempty(b.fovId)
        tf = strcmp(char(string(a.fovId)), char(string(b.fovId)));
        if tf
            return;
        end
    end
catch
end
try
    if isfield(a,'fovIndex') && isfield(b,'fovIndex') && ~isempty(a.fovIndex) && ~isempty(b.fovIndex)
        tf = isequal(a.fovIndex, b.fovIndex);
    end
catch
end
end