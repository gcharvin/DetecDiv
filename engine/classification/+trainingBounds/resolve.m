function [bounds, info] = resolve(classif, roiRef, varargin)
%TRAININGBOUNDS.RESOLVE Resolve the effective stored bounds for one ROI.

p = inputParser;
p.addParameter('FrameCount', [], @(x) isempty(x) || isnumeric(x));
p.parse(varargin{:});
frameCount = p.Results.FrameCount;

[roiObj, roiIndex, roiId] = resolveRoi(classif, roiRef);
cfg = normalizedConfig(classif);
mode = lower(strtrim(char(string(cfg.Type))));
bounds = [];
source = 'all';

switch mode
    case 'auto'
        bounds = normalizeStored(cfg.Values);
        if ~isempty(bounds), source = 'global'; end
    case 'manual'
        bounds = roiValue(cfg.RoiValues, roiIndex, roiId);
        if ~isempty(bounds)
            source = 'roi';
        else
            bounds = legacyValue(roiObj, classif, 'userbounds');
            if isempty(bounds)
                bounds = legacyValue(roiObj, classif, 'bounds');
            end
            if ~isempty(bounds), source = 'legacy-roi'; end
        end
    case 'rules'
        bounds = roiValue(cfg.RoiValues, roiIndex, roiId);
        if isempty(bounds), bounds = legacyValue(roiObj, classif, 'bounds'); end
        if ~isempty(bounds), source = 'rules'; end
    otherwise
        bounds = roiValue(cfg.RoiValues, roiIndex, roiId);
        if ~isempty(bounds), source = 'roi'; end
end

if ~isempty(bounds) && ~isempty(frameCount)
    n = round(double(frameCount(1)));
    if isfinite(n) && n > 0
        bounds(1) = min(max(1, bounds(1)), n);
        bounds(2) = min(max(bounds(1), bounds(2)), n);
    end
end
info = struct('mode', mode, 'source', source, 'roiIndex', roiIndex, ...
    'roiId', roiId, 'text', trainingBounds.text(bounds));
end

function cfg = normalizedConfig(classif)
cfg = struct('SchemaVersion',2,'Type','Auto','Values',[], ...
    'RoiValues',emptyEntries(),'Rules',struct());
try
    raw = classif.bounds;
    if isstruct(raw)
        fields = fieldnames(raw);
        for i = 1:numel(fields), cfg.(fields{i}) = raw.(fields{i}); end
    end
catch
end
if ~isfield(cfg,'Type') || isempty(cfg.Type), cfg.Type = 'Auto'; end
if ~isfield(cfg,'Values'), cfg.Values = []; end
if ~isfield(cfg,'RoiValues') || ~isstruct(cfg.RoiValues)
    cfg.RoiValues = emptyEntries();
end
end

function entries = emptyEntries()
entries = struct('roi_id',{},'roi_index',{},'values',{},'updated_at',{});
end

function value = roiValue(entries, roiIndex, roiId)
value = [];
if isempty(entries), return; end
match = [];
ids = strings(size(entries));
try
    ids = string({entries.roi_id});
    if strlength(string(roiId)) > 0
        match = find(ids == string(roiId), 1);
    end
catch
end
if isempty(match)
    try
        indexMatches = double([entries.roi_index]) == roiIndex;
        if strlength(string(roiId)) > 0
            % Index fallback is allowed only for migrated entries that do
            % not yet own a stable id.  It must never capture another
            % id-bearing ROI after a table reorder.
            indexMatches = indexMatches & strlength(ids) == 0;
        end
        match = find(indexMatches, 1);
    catch
    end
end
if isempty(match), return; end
try value = normalizeStored(entries(match).values); catch, value = []; end
end

function value = legacyValue(roiObj, classif, fieldName)
value = [];
if isempty(roiObj), return; end
try data = roiObj.data; catch, data = []; end
if isempty(data), return; end
classifierId = '';
try classifierId = char(string(classif.strid)); catch, end
for i = 1:numel(data)
    try
        if ~isempty(classifierId) && ~strcmp(char(string(data(i).groupid)), classifierId)
            continue;
        end
        ud = data(i).userData;
        candidate = [];
        if isstruct(ud) && isfield(ud, fieldName)
            candidate = ud.(fieldName);
        elseif isa(ud,'containers.Map') && isKey(ud, fieldName)
            candidate = ud(fieldName);
        end
        candidate = normalizeStored(candidate);
        if ~isempty(candidate), value = candidate; return; end
    catch
    end
end
end

function value = normalizeStored(raw)
value = [];
if isempty(raw), return; end
try
    value = trainingBounds.parse(raw);
catch
    value = [];
end
end

function [roiObj, roiIndex, roiId] = resolveRoi(classif, roiRef)
roiObj = [];
roiIndex = NaN;
roiId = '';
if isa(roiRef, 'roi')
    roiObj = roiRef;
    roiId = char(string(roiObj.id));
    try
        ids = string({classif.roi.id});
        roiIndex = find(ids == string(roiId), 1);
    catch
    end
else
    roiIndex = round(double(roiRef));
    try
        if isfinite(roiIndex) && roiIndex >= 1 && roiIndex <= numel(classif.roi)
            roiObj = classif.roi(roiIndex);
            roiId = char(string(roiObj.id));
        end
    catch
    end
end
if isempty(roiIndex) || ~isscalar(roiIndex) || ~isfinite(roiIndex)
    roiIndex = NaN;
end
end
