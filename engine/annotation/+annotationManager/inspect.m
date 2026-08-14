function summary = inspect(roiObj, spec, varargin)
%ANNOTATIONMANAGER.INSPECT Summarize lifecycle, coverage and asset availability.

p = inputParser;
p.addParameter('VerifyHash', false, @(x) islogical(x) && isscalar(x));
p.addParameter('CheckAssets', true, @(x) islogical(x) && isscalar(x));
p.addParameter('ReviewFrames', [], @isnumeric);
p.parse(varargin{:});

[entry, found] = annotationManager.entryForSpec(roiObj, spec);
if p.Results.CheckAssets
    states = componentStates(roiObj, spec);
else
    states = uncheckedComponentStates(spec);
end
legacy = ~found;
if legacy && p.Results.CheckAssets
    entry = inferredLegacyEntry(entry, states);
end
reviewFrames = normalizeReviewFrames(p.Results.ReviewFrames, ...
    reviewFrameCount(entry,roiObj));
coverage = coverageFromEntry(entry, spec, reviewFrames);
status = char(string(entry.status));
if isempty(status), status = 'missing'; end
if strcmp(status,'approved') && coverage.fraction < 1
    status = 'draft';
end

staleApproval = false;
if strcmp(status, 'approved') && p.Results.VerifyHash && ~isempty(entry.approved_hash)
    currentHash = annotationManager.contentHash(roiObj, spec);
    staleApproval = ~strcmpi(currentHash, entry.approved_hash);
    if staleApproval, status = 'draft'; end
end

summary = struct( ...
    'annotationId', char(string(spec.id)), ...
    'classifierId', char(string(spec.classifierId)), ...
    'roiId', char(string(roiObj.id)), ...
    'status', status, ...
    'legacy', legacy, ...
    'revision', double(entry.revision), ...
    'coverage', coverage, ...
    'reviewFrames', reviewFrames, ...
    'approvedAt', char(string(entry.approved_at)), ...
    'staleApproval', staleApproval, ...
    'components', states, ...
    'entry', entry);
end

function states = uncheckedComponentStates(spec)
template = struct('id', '', 'kind', '', 'storage', '', ...
    'required', true, 'groundTruthExists', false, ...
    'predictionExists', false, 'groundTruthName', '', ...
    'predictionName', '');
states = repmat(template, numel(spec.components), 1);
for i = 1:numel(spec.components)
    component = spec.components(i);
    states(i).id = component.id;
    states(i).kind = component.kind;
    states(i).storage = component.storage;
    states(i).required = component.required;
end
end

function states = componentStates(roiObj, spec)
template = struct('id', '', 'kind', '', 'storage', '', ...
    'required', true, 'groundTruthExists', false, ...
    'predictionExists', false, 'groundTruthName', '', ...
    'predictionName', '');
states = repmat(template, numel(spec.components), 1);
for i = 1:numel(spec.components)
    component = spec.components(i);
    states(i).id = component.id;
    states(i).kind = component.kind;
    states(i).storage = component.storage;
    states(i).required = component.required;
    [states(i).groundTruthExists, states(i).groundTruthName] = ...
        assetExists(roiObj, component.storage, component.groundTruth);
    [states(i).predictionExists, states(i).predictionName] = ...
        assetExists(roiObj, component.storage, component.prediction);
end
end

function [tf, resolvedName] = assetExists(roiObj, storage, asset)
tf = false;
resolvedName = '';
switch char(string(storage))
    case 'channel'
        [resolvedName, tf] = annotationManager.resolveChannel(roiObj, asset);
    case 'dataseries'
        ensureData(roiObj);
        groupId = char(string(asset.groupId));
        field = char(string(asset.valueField));
        try
            idx = find(arrayfun(@(x) strcmp(char(string(x.groupid)), groupId), roiObj.data), 1);
            tf = ~isempty(idx) && ismember(field, roiObj.data(idx).data.Properties.VariableNames);
            if tf, resolvedName = [groupId '.' field]; end
        catch
            tf = false;
        end
    case 'cell_model_family'
        family = char(string(asset.family));
        try
            [tf, resolvedName] = cachedOrStoredFamilyExists(roiObj, family);
        catch
            tf = false;
        end
end
end

function [tf, resolvedName] = cachedOrStoredFamilyExists(roiObj, family)
[tf, resolvedName] = cellModel.findStoredFamily(roiObj, family);
end

function ensureData(roiObj)
try
    if isempty(roiObj.data) || (numel(roiObj.data) == 1 && ...
            isempty(char(string(roiObj.data(1).groupid))))
        roiObj.load('Data', 'Silent');
    end
catch
end
end

function entry = inferredLegacyEntry(entry, states)
required = [states.required];
if isempty(required), required = true(1, numel(states)); end
exists = [states.groundTruthExists];
if any(required) && all(exists(required))
    entry.status = 'draft';
else
    entry.status = 'missing';
end
end

function coverage = coverageFromEntry(entry, spec, reviewFrames)
reviewed = 0;
total = 0;
components = repmat(struct('id', '', 'unit', '', 'reviewed', 0, ...
    'total', 0, 'fraction', 0), numel(spec.components), 1);
for i = 1:numel(spec.components)
    component = spec.components(i);
    components(i).id = component.id;
    components(i).unit = component.coverageUnit;
    reviewIdx = find(strcmp(string({entry.review.component_id}), ...
        string(component.id)), 1, 'first');
    if strcmp(component.coverageUnit, 'roi')
        componentTotal = 1;
        componentReviewed = 0;
        if ~isempty(reviewIdx), componentReviewed = double(entry.review(reviewIdx).complete); end
    else
        componentTotal = numel(reviewFrames);
        componentReviewed = 0;
        if ~isempty(reviewIdx)
            stored = logical(entry.review(reviewIdx).frames);
            validFrames = reviewFrames(reviewFrames <= numel(stored));
            componentReviewed = nnz(stored(validFrames));
        end
    end
    components(i).reviewed = componentReviewed;
    components(i).total = componentTotal;
    if componentTotal > 0
        components(i).fraction = componentReviewed / componentTotal;
    end
    if component.required
        reviewed = reviewed + componentReviewed;
        total = total + componentTotal;
    end
end
fraction = 0;
if total > 0, fraction = reviewed / total; end
coverage = struct('reviewed', reviewed, 'total', total, ...
    'fraction', fraction, 'components', components);
end

function frames = normalizeReviewFrames(value,total)
if isempty(value)
    frames = 1:total;
    return;
end
frames = unique(round(double(value(:).')),'stable');
frames = frames(isfinite(frames) & frames >= 1 & frames <= total);
end

function total = reviewFrameCount(entry,roiObj)
total = 0;
try
    frameReview = entry.review(strcmp({entry.review.unit},'frame'));
    if ~isempty(frameReview)
        total = max(arrayfun(@(x)numel(x.frames),frameReview));
    end
catch
end
if total < 1, total = annotationManager.frameCount(roiObj); end
end
