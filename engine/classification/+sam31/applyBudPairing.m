function report = applyBudPairing(roiobj, classif, varargin)
% sam31.applyBudPairing  Infer bud-mother links from SAM31 tracked labels.
%
% The inferred lineage is stored in ROI dataseries groupid="cell_information".
% Multiple label channels are supported through
% ds.userData.lineageSources.<sourceKey>. The legacy ds.userData.motherOf map
% remains an alias for the active/canonical source.

p = inputParser;
p.addParameter('OutputName', '', @(x) ischar(x) || isstring(x));
p.addParameter('Ctx', struct(), @(x) isempty(x) || isstruct(x));
p.parse(varargin{:});

outputName = char(string(p.Results.OutputName));
ctx = p.Results.Ctx;
params = localPairingParams(classif, ctx);

report = struct('changed', false, 'reason', '', 'channelName', '', ...
    'dataseriesGroupid', 'cell_information', 'sourceKey', '', ...
    'nEvents', 0, 'nAssignedToMotherOf', 0);

if ~localParamBool(params.inferBudPairing, true)
    report.reason = 'disabled';
    return;
end

if isempty(outputName)
    outputName = localClassifStrid(classif, 'sam31');
end

[labels, channelName] = localReadLabelStack(roiobj, classif, outputName);
report.channelName = channelName;
if isempty(labels)
    report.reason = 'no_label_channel';
    return;
end

events = localInferEvents(labels, params);
report.nEvents = numel(events);
if isempty(events)
    report.reason = 'no_candidate_buds';
    return;
end

[ds, dsIdx] = localEnsureCellInformation(roiobj, size(labels, 3));
inferredMap = containers.Map('KeyType', 'int32', 'ValueType', 'double');
for i = 1:numel(events)
    inferredMap(int32(events(i).childId)) = double(events(i).motherId);
end

if ~isstruct(ds.userData)
    ds.userData = struct();
end
if ~isfield(ds.userData, 'lineageSources') || ~isstruct(ds.userData.lineageSources)
    ds.userData.lineageSources = struct();
end

sourceKey = localLineageSourceKey(params, outputName, channelName);
report.sourceKey = sourceKey;
source = struct( ...
    'motherOf', inferredMap, ...
    'events', events, ...
    'channelName', channelName, ...
    'outputName', outputName, ...
    'sourceClassifierStrid', localClassifStrid(classif, ''), ...
    'displayName', localLineageDisplayName(outputName, channelName), ...
    'show', localParamBool(params.budPairingShowSource, true), ...
    'version', 1, ...
    'mode', 'sam31_label_heuristic_v1', ...
    'createdAt', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
ds.userData.lineageSources.(sourceKey) = source;

if ~isfield(ds.userData, 'activeLineageSource') || isempty(ds.userData.activeLineageSource) || ...
        localParamBool(params.budPairingActivateSource, true)
    ds.userData.activeLineageSource = sourceKey;
end

assigned = localUpdateLegacyMotherOf(ds, sourceKey, inferredMap, channelName, outputName, params);
roiobj.data(dsIdx) = ds;

report.changed = true;
report.reason = 'ok';
report.nAssignedToMotherOf = assigned;
end

function params = localPairingParams(classif, ctx)
params = struct();
params.inferBudPairing = true;
params.budPairingSourceKey = '';
params.budPairingShowSource = true;
params.budPairingActivateSource = true;
params.budPairingWriteCanonical = true;
params.budPairingOverwriteMotherOf = false;
params.budPairingMaxBirthArea = 350;
params.budPairingMinParentArea = 80;
params.budPairingMaxParentDistance = 35;
params.budPairingFutureWindow = 6;
params.budPairingMinParentAgeFrames = 6;
params.budPairingMaxFutureDistance = 45;
params.budPairingAngleWeight = 8;
params.budPairingFutureWeight = 0.6;

params = localMergeParams(params, localNestedParams(classif, {'runProfiles','classify','params'}));
params = localMergeParams(params, localNestedParams(ctx, {'params'}));
end

function params = localMergeParams(params, src)
if ~isstruct(src)
    return;
end
names = fieldnames(src);
target = fieldnames(params);
for i = 1:numel(names)
    hit = find(strcmpi(target, names{i}), 1, 'first');
    if ~isempty(hit)
        params.(target{hit}) = src.(names{i});
    end
end
end

function value = localNestedParams(obj, path)
value = struct();
try
    cur = obj;
    for i = 1:numel(path)
        key = path{i};
        if isstruct(cur) && isfield(cur, key)
            cur = cur.(key);
        elseif isobject(cur) && isprop(cur, key)
            cur = cur.(key);
        else
            return;
        end
    end
    if isstruct(cur)
        value = cur;
    end
catch
    value = struct();
end
end

function sourceKey = localLineageSourceKey(params, outputName, channelName)
sourceKey = localParamString(params.budPairingSourceKey, '');
if isempty(sourceKey)
    seed = char(string(outputName));
    if isempty(seed)
        seed = char(string(channelName));
    end
    sourceKey = matlab.lang.makeValidName(seed);
end
if isempty(sourceKey)
    sourceKey = 'sam31';
end
end

function displayName = localLineageDisplayName(outputName, channelName)
displayName = char(string(outputName));
if isempty(displayName)
    displayName = char(string(channelName));
end
if isempty(displayName)
    displayName = 'SAM31 pairing';
end
end

function assigned = localUpdateLegacyMotherOf(ds, sourceKey, inferredMap, channelName, outputName, params)
assigned = 0;
if ~localParamBool(params.budPairingWriteCanonical, true)
    return;
end
if ~isfield(ds.userData, 'motherOf') || isempty(ds.userData.motherOf) || ...
        ~isa(ds.userData.motherOf, 'containers.Map')
    ds.userData.motherOf = containers.Map('KeyType', 'int32', 'ValueType', 'double');
end

overwrite = localParamBool(params.budPairingOverwriteMotherOf, false);
if overwrite || ds.userData.motherOf.Count == 0
    ds.userData.motherOf = inferredMap;
    assigned = inferredMap.Count;
end

if assigned > 0
    ds.userData.motherOfSource = 'sam31.applyBudPairing';
    ds.userData.motherOfSourceKey = sourceKey;
    ds.userData.motherOfSourceOutputName = outputName;
    ds.userData.motherOfSourceChannelName = channelName;
end
end

function value = localParamString(raw, defaultValue)
value = defaultValue;
try
    if ischar(raw) || (isstring(raw) && isscalar(raw))
        txt = strtrim(char(string(raw)));
        if ~isempty(txt)
            value = txt;
        end
    end
catch
    value = defaultValue;
end
end

function tf = localParamBool(value, defaultValue)
tf = defaultValue;
try
    if islogical(value)
        tf = logical(value(1));
    elseif isnumeric(value)
        tf = value(1) ~= 0;
    elseif ischar(value) || (isstring(value) && isscalar(value))
        txt = lower(strtrim(char(string(value))));
        if any(strcmp(txt, {'1','true','yes','on','oui'}))
            tf = true;
        elseif any(strcmp(txt, {'0','false','no','off','non'}))
            tf = false;
        end
    end
catch
    tf = defaultValue;
end
end

function value = localParamNumber(raw, defaultValue)
value = defaultValue;
try
    if ischar(raw) || (isstring(raw) && isscalar(raw))
        raw = str2double(strrep(char(string(raw)), ',', '.'));
    end
    raw = double(raw);
    raw = raw(isfinite(raw));
    if ~isempty(raw)
        value = raw(1);
    end
catch
    value = defaultValue;
end
end

function [labels, channelName] = localReadLabelStack(roiobj, classif, outputName)
labels = [];
channelName = '';
className = 'cell';
try
    if ~isempty(classif.classes)
        className = char(string(classif.classes{1}));
    end
catch
end

candidates = {['results_' outputName '_' className], ...
    ['results_' outputName '_cell'], ...
    ['results_' localClassifStrid(classif, outputName) '_' className], ...
    ['results_' localClassifStrid(classif, outputName) '_cell']};

if isempty(roiobj.image)
    try
        roiobj.load('image', 'Silent');
    catch
        try, roiobj.load; catch, end
    end
end
if isempty(roiobj.image)
    return;
end

for i = 1:numel(candidates)
    ch = candidates{i};
    try
        pix = roiobj.findChannelID(ch);
    catch
        pix = findChannelID(roiobj, ch);
    end
    if iscell(pix), pix = cell2mat(pix); end
    if ~isempty(pix)
        channelName = ch;
        stack = roiobj.image(:, :, pix(1), :);
        stack = squeeze(stack);
        if ndims(stack) == 2
            stack = reshape(stack, size(stack,1), size(stack,2), 1);
        end
        labels = uint32(stack);
        return;
    end
end
end

function events = localInferEvents(labels, params)
ids = unique(labels(:));
ids(ids == 0) = [];
nFrames = size(labels, 3);
events = localEmptyEvents();
if isempty(ids) || nFrames < 2
    return;
end

maxBirthArea = localParamNumber(params.budPairingMaxBirthArea, 350);
minParentArea = localParamNumber(params.budPairingMinParentArea, 80);
maxParentDistance = localParamNumber(params.budPairingMaxParentDistance, 35);
futureWindow = max(0, round(localParamNumber(params.budPairingFutureWindow, 6)));
minParentAge = max(0, round(localParamNumber(params.budPairingMinParentAgeFrames, 6)));
maxFutureDistance = localParamNumber(params.budPairingMaxFutureDistance, 45);

areas = zeros(numel(ids), nFrames);
for t = 1:nFrames
    frame = labels(:, :, t);
    for i = 1:numel(ids)
        areas(i, t) = nnz(frame == ids(i));
    end
end
firstFrame = zeros(numel(ids), 1);
for i = 1:numel(ids)
    f = find(areas(i, :) > 0, 1, 'first');
    if isempty(f), f = 0; end
    firstFrame(i) = f;
end

for i = 1:numel(ids)
    childId = ids(i);
    startFrame = firstFrame(i);
    if startFrame <= 1
        continue;
    end
    birthArea = areas(i, startFrame);
    if birthArea <= 0 || birthArea > maxBirthArea
        continue;
    end

    childMask = labels(:, :, startFrame) == childId;
    best = struct('motherId', 0, 'cost', Inf, 'distance', Inf, ...
        'futureDistance', Inf, 'angleDeg', NaN, 'motherArea', 0);

    for j = 1:numel(ids)
        if j == i
            continue;
        end
        motherId = ids(j);
        if areas(j, startFrame) < minParentArea
            continue;
        end
        if firstFrame(j) > 1 && (startFrame - firstFrame(j)) < minParentAge
            continue;
        end

        motherMask = labels(:, :, startFrame) == motherId;
        d0 = localMaskDistance(childMask, motherMask);
        if d0 > maxParentDistance
            continue;
        end

        [futureDistance, futureSupport] = localFutureDistance(labels, childId, motherId, ...
            startFrame, futureWindow, maxFutureDistance);
        angleDeg = localAxisAngle(childMask, motherMask);
        angleWeight = localParamNumber(params.budPairingAngleWeight, 8);
        futureWeight = localParamNumber(params.budPairingFutureWeight, 0.6);
        angleCost = 0;
        if isfinite(angleDeg)
            angleCost = angleWeight * min(angleDeg, 90) / 90;
        end
        futureCost = futureWeight * futureDistance;
        supportBonus = -4 * futureSupport;
        cost = d0 + futureCost + angleCost + supportBonus;

        if cost < best.cost
            best = struct('motherId', double(motherId), 'cost', cost, ...
                'distance', d0, 'futureDistance', futureDistance, ...
                'angleDeg', angleDeg, 'motherArea', areas(j, startFrame));
        end
    end

    if best.motherId > 0 && isfinite(best.cost)
        events(end+1) = struct( ...
            'childId', double(childId), ...
            'motherId', double(best.motherId), ...
            'startFrame', double(startFrame), ...
            'cost', double(best.cost), ...
            'distance', double(best.distance), ...
            'futureDistance', double(best.futureDistance), ...
            'axisAngleDeg', double(best.angleDeg), ...
            'areaAtBirth', double(birthArea), ...
            'motherAreaAtBirth', double(best.motherArea)); %#ok<AGROW>
    end
end
end

function events = localEmptyEvents()
events = struct('childId', {}, 'motherId', {}, 'startFrame', {}, ...
    'cost', {}, 'distance', {}, 'futureDistance', {}, 'axisAngleDeg', {}, ...
    'areaAtBirth', {}, 'motherAreaAtBirth', {});
end

function d = localMaskDistance(maskA, maskB)
if ~any(maskA(:)) || ~any(maskB(:))
    d = Inf;
    return;
end
try
    distMap = bwdist(maskB);
    d = min(distMap(maskA));
catch
    ca = localCentroid(maskA);
    cb = localCentroid(maskB);
    d = sqrt(sum((ca - cb).^2));
end
end

function [futureDistance, support] = localFutureDistance(labels, childId, motherId, startFrame, futureWindow, maxDistance)
lastFrame = min(size(labels, 3), startFrame + futureWindow);
distances = [];
support = 0;
for t = startFrame:lastFrame
    childMask = labels(:, :, t) == childId;
    motherMask = labels(:, :, t) == motherId;
    if ~any(childMask(:)) || ~any(motherMask(:))
        continue;
    end
    d = localMaskDistance(childMask, motherMask);
    distances(end+1) = d; %#ok<AGROW>
    if d <= maxDistance
        support = support + 1;
    end
end
if isempty(distances)
    futureDistance = maxDistance;
else
    futureDistance = mean(distances(isfinite(distances)));
    if ~isfinite(futureDistance)
        futureDistance = maxDistance;
    end
end
support = support / max(1, numel(distances));
end

function angleDeg = localAxisAngle(childMask, motherMask)
angleDeg = NaN;
try
    sMother = regionprops(motherMask, 'Centroid', 'Orientation');
    sChild = regionprops(childMask, 'Centroid');
    if isempty(sMother) || isempty(sChild)
        return;
    end
    mother = sMother(1);
    child = sChild(1);
    v = child.Centroid - mother.Centroid;
    if norm(v) == 0
        return;
    end
    theta = atan2d(v(2), v(1));
    diffAngle = abs(mod(theta - mother.Orientation + 90, 180) - 90);
    angleDeg = diffAngle;
catch
    angleDeg = NaN;
end
end

function c = localCentroid(mask)
[y, x] = find(mask);
if isempty(x)
    c = [NaN NaN];
else
    c = [mean(x) mean(y)];
end
end

function [ds, idx] = localEnsureCellInformation(roiobj, nFrames, groupid)
if nargin < 3 || isempty(groupid)
    groupid = 'cell_information';
end
if isempty(roiobj.data)
    try
        roiobj.load('data');
    catch
    end
end

idx = [];
try
    idx = find(arrayfun(@(x) isprop(x, 'groupid') && strcmp(char(string(x.groupid)), char(string(groupid))), roiobj.data), 1, 'first');
catch
end

if isempty(idx)
    if isempty(roiobj.data) || (numel(roiobj.data) == 1 && localTableHeight(roiobj.data(1).data) == 0)
        idx = 1;
        roiobj.data(idx) = dataseries;
    else
        idx = numel(roiobj.data) + 1;
        roiobj.data(idx) = dataseries; %#ok<AGROW>
    end
    ds = roiobj.data(idx);
    ds.class = "other";
    ds.type = "temporal";
    ds.groupid = char(string(groupid));
    try, ds.parentid = roiobj.id; catch, end
    ds.data = table(cell(nFrames, 1), 'VariableNames', {'lineage'});
    ds.data.lineage(:) = {nan};
    ds.plotGroup = {[] [] [] [] [] {'lineage'}};
    ds.groupProperties = {'lineage','Plot','auto','auto'};
    ds.userData = struct();
    ds.userData.version = 1;
    ds.userData.note = "lineage stored in userData.motherOf and userData.lineageSources";
    ds.userData.motherOf = containers.Map('KeyType','int32','ValueType','double');
else
    ds = roiobj.data(idx);
    if isempty(ds.data) || ~istable(ds.data) || ~ismember('lineage', ds.data.Properties.VariableNames)
        ds.data = table(cell(nFrames, 1), 'VariableNames', {'lineage'});
        ds.data.lineage(:) = {nan};
    else
        h = height(ds.data);
        if h < nFrames
            extra = table(cell(nFrames - h, 1), 'VariableNames', {'lineage'});
            extra.lineage(:) = {nan};
            ds.data = [ds.data; extra];
        end
    end
    if ~isstruct(ds.userData)
        ds.userData = struct();
    end
    if ~isfield(ds.userData, 'version')
        ds.userData.version = 1;
    end
    if ~isfield(ds.userData, 'note')
        ds.userData.note = "lineage stored in userData.motherOf and userData.lineageSources";
    end
end
end

function h = localTableHeight(T)
if istable(T)
    h = height(T);
else
    h = 0;
end
end

function strid = localClassifStrid(classif, fallback)
strid = fallback;
try
    if isobject(classif) && isprop(classif, 'strid') && ~isempty(classif.strid)
        strid = char(string(classif.strid));
    elseif isstruct(classif) && isfield(classif, 'strid') && ~isempty(classif.strid)
        strid = char(string(classif.strid));
    end
catch
    strid = fallback;
end
end
