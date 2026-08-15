function report = apply(classif, roiIndices, mode, varargin)
%TRAININGBOUNDS.APPLY Apply one persistent frame policy to several ROIs.

p = inputParser;
p.addParameter('Bounds', [], @(x) isempty(x) || isnumeric(x) || ...
    ischar(x) || isstring(x));
p.parse(varargin{:});

nRois = numel(classif.roi);
roiIndices = unique(round(double(roiIndices(:).')), 'stable');
roiIndices = roiIndices(isfinite(roiIndices) & roiIndices >= 1 & ...
    roiIndices <= nRois);
mode = lower(strtrim(char(string(mode))));

if strcmp(mode, 'per_roi')
    materializeGlobalBounds(classif);
    cfg = normalizedConfig(classif);
    cfg.SchemaVersion = 2;
    cfg.Type = 'Manual';
    cfg.Values = [];
    classif.bounds = cfg;
    report = makeReport(mode, roiIndices, cell(0,1));
    return;
end
if isempty(roiIndices)
    error('trainingBounds:EmptyScope', ...
        'No ROI belongs to the selected frame-bounds scope.');
end

effective = cell(numel(roiIndices), 1);
switch mode
    case 'all'
        materializeGlobalBounds(classif);
        for i = 1:numel(roiIndices)
            trainingBounds.clearRoi(classif, roiIndices(i));
            effective{i} = [];
        end

    case 'range'
        requested = trainingBounds.parse(p.Results.Bounds);
        if isempty(requested)
            error('trainingBounds:MissingRange', ...
                'Enter a start and end frame for the shared range.');
        end
        tooShort = strings(0,1);
        frameCounts = zeros(size(roiIndices));
        for i = 1:numel(roiIndices)
            frameCounts(i) = roiFrameCount(classif.roi(roiIndices(i)));
            if frameCounts(i) > 0 && requested(1) > frameCounts(i)
                tooShort(end+1,1) = sprintf('%s (%d frames)', ...
                    char(string(classif.roi(roiIndices(i)).id)), ...
                    frameCounts(i)); %#ok<AGROW>
            end
        end
        if ~isempty(tooShort)
            error('trainingBounds:RangeStartsAfterRoi', ...
                ['Start frame %d lies after the end of these ROIs:' ...
                 newline '%s'], ...
                requested(1), strjoin(tooShort, newline));
        end
        materializeGlobalBounds(classif);
        for i = 1:numel(roiIndices)
            bounds = requested;
            if frameCounts(i) > 0
                bounds(2) = min(bounds(2), frameCounts(i));
            end
            trainingBounds.setRoi(classif, roiIndices(i), bounds, ...
                'FrameCount', frameCounts(i));
            effective{i} = bounds;
        end

    otherwise
        error('trainingBounds:InvalidApplyMode', ...
            'Frame mode must be all, range, or per_roi.');
end

report = makeReport(mode, roiIndices, effective);
end

function materializeGlobalBounds(classif)
cfg = normalizedConfig(classif);
if ~strcmpi(char(string(cfg.Type)), 'Auto') || ...
        ~isfield(cfg, 'Values') || isempty(cfg.Values)
    return;
end
requested = trainingBounds.parse(cfg.Values);
if isempty(requested), return; end
for i = 1:numel(classif.roi)
    count = roiFrameCount(classif.roi(i));
    bounds = requested;
    if count > 0
        bounds(1) = min(max(1, bounds(1)), count);
        bounds(2) = min(max(bounds(1), bounds(2)), count);
    end
    trainingBounds.setRoi(classif, i, bounds, 'FrameCount', count);
end
end

function count = roiFrameCount(roiObj)
count = 0;
try count = annotationManager.frameCount(roiObj); catch, end
if count < 1
    try count = size(roiObj.image, 4); catch, end
end
count = round(double(count));
end

function cfg = normalizedConfig(classif)
cfg = struct('SchemaVersion',2,'Type','Manual','Values',[], ...
    'RoiValues',emptyEntries(),'Rules',struct());
try
    raw = classif.bounds;
    if isstruct(raw)
        names = fieldnames(raw);
        for i = 1:numel(names), cfg.(names{i}) = raw.(names{i}); end
    end
catch
end
if ~isfield(cfg, 'RoiValues') || ~isstruct(cfg.RoiValues)
    cfg.RoiValues = emptyEntries();
end
end

function entries = emptyEntries()
entries = struct('roi_id',{},'roi_index',{},'values',{},'updated_at',{});
end

function report = makeReport(mode, roiIndices, effective)
report = struct('mode', mode, 'roiIndices', roiIndices, ...
    'effectiveBounds', {effective}, 'count', numel(roiIndices));
end
