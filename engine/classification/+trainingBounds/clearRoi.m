function clearRoi(classif, roiRef)
%TRAININGBOUNDS.CLEARROI Restore the per-ROI default, which is "all".

[roiIndex, roiId] = roiIdentity(classif, roiRef);
cfg = ensureConfig(classif);
entries = cfg.RoiValues;
remove = false(size(entries));
for i = 1:numel(entries)
    try
        entryId = char(string(entries(i).roi_id));
        remove(i) = (~isempty(roiId) && strcmp(entryId,roiId)) || ...
            (isempty(entryId) && double(entries(i).roi_index) == roiIndex);
    catch
    end
end
entries(remove) = [];
cfg.SchemaVersion = 2;
cfg.Type = 'Manual';
cfg.Values = [];
cfg.RoiValues = entries;
classif.bounds = cfg;
end

function cfg = ensureConfig(classif)
cfg = struct('SchemaVersion',2,'Type','Auto','Values',[], ...
    'RoiValues',emptyEntries(),'Rules',struct());
try
    raw = classif.bounds;
    if isstruct(raw)
        names = fieldnames(raw);
        for i = 1:numel(names), cfg.(names{i}) = raw.(names{i}); end
    end
catch
end
if ~isfield(cfg,'RoiValues') || ~isstruct(cfg.RoiValues)
    cfg.RoiValues = emptyEntries();
else
    cfg.RoiValues = canonicalEntries(cfg.RoiValues);
end
end

function entries = emptyEntries()
entries = struct('roi_id',{},'roi_index',{},'values',{},'updated_at',{});
end

function out = canonicalEntries(raw)
out = emptyEntries();
for i = 1:numel(raw)
    entry = struct('roi_id','','roi_index',NaN,'values',[], ...
        'updated_at','');
    names = fieldnames(entry);
    for j = 1:numel(names)
        try entry.(names{j}) = raw(i).(names{j}); catch, end
    end
    out(end+1) = entry; %#ok<AGROW>
end
end

function [roiIndex, roiId] = roiIdentity(classif, roiRef)
if isa(roiRef,'roi')
    roiId = char(string(roiRef.id));
    roiIndex = find(string({classif.roi.id}) == string(roiId),1);
else
    roiIndex = round(double(roiRef));
    if ~isscalar(roiIndex) || ~isfinite(roiIndex) || roiIndex < 1 || roiIndex > numel(classif.roi)
        error('trainingBounds:InvalidRoi','Invalid classifier ROI index.');
    end
    roiId = char(string(classif.roi(roiIndex).id));
end
if isempty(roiIndex), error('trainingBounds:InvalidRoi','Unknown classifier ROI.'); end
end
