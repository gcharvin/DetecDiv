function bounds = setRoi(classif, roiRef, raw, varargin)
%TRAININGBOUNDS.SETROI Persist inclusive manual bounds for one classifier ROI.

p = inputParser;
p.addParameter('FrameCount', [], @(x) isempty(x) || isnumeric(x));
p.parse(varargin{:});
bounds = trainingBounds.parse(raw, 'FrameCount', p.Results.FrameCount);
if isempty(bounds)
    trainingBounds.clearRoi(classif, roiRef);
    return;
end

[roiIndex, roiId] = roiIdentity(classif, roiRef);
cfg = ensureConfig(classif);
entries = cfg.RoiValues;
match = findEntry(entries, roiIndex, roiId);
entry = struct('roi_id',roiId,'roi_index',roiIndex,'values',bounds, ...
    'updated_at',char(datetime('now','Format','yyyy-MM-dd''T''HH:mm:ss')));
if isempty(match), entries(end+1) = entry; else, entries(match) = entry; end
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

function index = findEntry(entries, roiIndex, roiId)
index = [];
if isempty(entries), return; end
ids = strings(size(entries));
try
    ids = string({entries.roi_id});
    if ~isempty(roiId), index = find(ids == string(roiId),1); end
catch
end
if isempty(index)
    try
        matches = double([entries.roi_index]) == roiIndex;
        if ~isempty(roiId), matches = matches & strlength(ids) == 0; end
        index = find(matches,1);
    catch
    end
end
end

function [roiIndex, roiId] = roiIdentity(classif, roiRef)
if isa(roiRef,'roi')
    roiId = char(string(roiRef.id));
    ids = string({classif.roi.id});
    roiIndex = find(ids == string(roiId),1);
else
    roiIndex = round(double(roiRef));
    if ~isscalar(roiIndex) || ~isfinite(roiIndex) || roiIndex < 1 || roiIndex > numel(classif.roi)
        error('trainingBounds:InvalidRoi','Invalid classifier ROI index.');
    end
    roiId = char(string(classif.roi(roiIndex).id));
end
if isempty(roiIndex)
    error('trainingBounds:InvalidRoi','The ROI is not owned by this classifier.');
end
end
