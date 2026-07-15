function ctx = runCore(ctx)
% roiManual.runCore  Core manual ROI generation/editing logic.

    if nargin < 1 || isempty(ctx)
        ctx = struct();
    end

    if ~isfield(ctx, 'shallow') || isempty(ctx.shallow) || ~isa(ctx.shallow, 'shallow')
        error('roiManual.runCore:ProjectRequired', 'Manual ROI editing requires a shallow project context.');
    end
    shallowObj = ctx.shallow;

    p = roiManual.setparam(struct());
    try
        if isfield(shallowObj.runProfiles, 'dataloading') && isfield(shallowObj.runProfiles.dataloading, 'roiManual')
            stored = shallowObj.runProfiles.dataloading.roiManual;
            if isstruct(stored)
                p = mergeStructOverride(p, stored);
            end
        end
    catch
    end
    if isfield(ctx, 'roiManual') && isstruct(ctx.roiManual) && ~isempty(ctx.roiManual)
        p = mergeStructOverride(p, ctx.roiManual);
    elseif isfield(ctx, 'params') && isstruct(ctx.params) && ~isempty(ctx.params)
        p = mergeStructOverride(p, ctx.params);
    end
    p = roiManual.setparam(p);
    p = applyExistingPolicyToManualParams(p, ctx);

    fovIdx = resolveFovIndexLocal(ctx, p, numel(shallowObj.fov));
    if isempty(fovIdx)
        ctx.shallow = shallowObj;
        ctx.roiManual = p;
        ctx.params = p;
        ctx.roiList = [];
        return;
    end

    records = manualRecordsLocal(p, fovIdx);
    if ~isempty(records)
        shallowObj = applyManualRecordsLocal(shallowObj, fovIdx, records, p);
        openList = unique([records.fovIndex], 'stable');
        openList = openList(openList >= 1 & openList <= numel(shallowObj.fov));
    else
        shallowObj = runLegacyManualViewerLocal(shallowObj, fovIdx, p);
        if p.openFirstOnly
            openList = fovIdx(1);
        else
            openList = fovIdx;
        end
    end

    try
        if ~isfield(shallowObj.runProfiles, 'dataloading') || isempty(shallowObj.runProfiles.dataloading)
            shallowObj.runProfiles.dataloading = struct();
        end
        shallowObj.runProfiles.dataloading.roiManual = p;
    catch
    end

    ctx.shallow = shallowObj;
    ctx.roiManual = p;
    ctx.params = p;
    ctx.roiList = collectSelectedRois(shallowObj, openList);
end

function fovIdx = resolveFovIndexLocal(ctx, p, nFov)
if isfield(ctx, 'fovIndex') && ~isempty(ctx.fovIndex)
    fovIdx = reshape(double(ctx.fovIndex), 1, []);
else
    manualFovIdx = manualRecordFovIndicesLocal(p);
    if ~isempty(manualFovIdx)
        fovIdx = manualFovIdx;
    elseif ~isempty(p.fovIndex)
        fovIdx = reshape(double(p.fovIndex), 1, []);
    else
        fovIdx = 1:nFov;
    end
end
fovIdx = unique(fovIdx(isfinite(fovIdx) & fovIdx >= 1 & fovIdx <= nFov));
end

function fovIdx = manualRecordFovIndicesLocal(p)
fovIdx = [];
if ~isfield(p, 'manualRois') || ~isstruct(p.manualRois) || isempty(p.manualRois)
    return;
end
for i = 1:numel(p.manualRois)
    rec = p.manualRois(i);
    if isfield(rec, 'fovIndex') && ~isempty(rec.fovIndex)
        idx = round(double(rec.fovIndex(1)));
        if isfinite(idx) && idx >= 1
            fovIdx(end+1) = idx; %#ok<AGROW>
        end
    end
end
fovIdx = unique(fovIdx, 'stable');
end

function records = manualRecordsLocal(p, fovIdx)
records = repmat(struct('fovIndex', [], 'rect', []), 0, 1);

if isfield(p, 'manualRois') && isstruct(p.manualRois) && ~isempty(p.manualRois)
    for i = 1:numel(p.manualRois)
        rec = p.manualRois(i);
        rect = firstRectFromRecordLocal(rec);
        if isempty(rect)
            continue;
        end
        idx = [];
        if isfield(rec, 'fovIndex') && ~isempty(rec.fovIndex)
            idx = round(double(rec.fovIndex(1)));
        end
        if isempty(idx) || ~isfinite(idx)
            idx = fovIdx(1);
        end
        records(end+1,1) = struct('fovIndex', idx, 'rect', rect); %#ok<AGROW>
    end
end

if ~isempty(records)
    return;
end

rects = [];
for key = {'manualRects','candidateRects','previewRects'}
    k = key{1};
    if isfield(p, k) && isnumeric(p.(k)) && ~isempty(p.(k)) && size(p.(k),2) >= 4
        rects = round(double(p.(k)(:,1:4)));
        break;
    end
end
if isempty(rects)
    return;
end
targetFov = fovIdx(1);
if isfield(p, 'fovIndex') && ~isempty(p.fovIndex)
    targetFov = round(double(p.fovIndex(1)));
end
for i = 1:size(rects,1)
    records(end+1,1) = struct('fovIndex', targetFov, 'rect', rects(i,1:4)); %#ok<AGROW>
end
end

function rect = firstRectFromRecordLocal(rec)
rect = [];
for key = {'rect','position','value'}
    k = key{1};
    if isfield(rec, k) && isnumeric(rec.(k)) && numel(rec.(k)) >= 4
        rect = reshape(round(double(rec.(k)(1:4))), 1, 4);
        if all(isfinite(rect)) && rect(3) > 0 && rect(4) > 0
            return;
        end
        rect = [];
    end
end
end

function shallowObj = applyManualRecordsLocal(shallowObj, fovIdx, records, p)
targetFovs = unique([records.fovIndex], 'stable');
targetFovs = targetFovs(targetFovs >= 1 & targetFovs <= numel(shallowObj.fov));
targetFovs = intersect(targetFovs, fovIdx, 'stable');
if isempty(targetFovs)
    return;
end

if p.errorOnExisting
    for i = 1:numel(targetFovs)
        if fovHasValidRois(shallowObj.fov(targetFovs(i)))
            error('roiManual.runCore:ExistingROI', ...
                'FOV %d already contains ROIs and existingPolicy=error.', targetFovs(i));
        end
    end
end

if ~p.keepExisting
    for i = 1:numel(targetFovs)
        shallowObj.fov(targetFovs(i)).roi = roi;
    end
end

for i = 1:numel(records)
    idx = records(i).fovIndex;
    if ~ismember(idx, targetFovs)
        continue;
    end
    if p.skipExisting && fovHasValidRois(shallowObj.fov(idx))
        continue;
    end
    shallowObj.fov(idx).addROI(uint16(records(i).rect), shallowObj.fov(idx).id);
end
end

function shallowObj = runLegacyManualViewerLocal(shallowObj, fovIdx, p)
if p.errorOnExisting
    for i = 1:numel(fovIdx)
        if fovHasValidRois(shallowObj.fov(fovIdx(i)))
            error('roiManual.runCore:ExistingROI', ...
                'FOV %d already contains ROIs and existingPolicy=error.', fovIdx(i));
        end
    end
end
if p.skipExisting
    keep = false(size(fovIdx));
    for i = 1:numel(fovIdx)
        keep(i) = ~fovHasValidRois(shallowObj.fov(fovIdx(i)));
    end
    fovIdx = fovIdx(keep);
    if isempty(fovIdx)
        return;
    end
end

if ~p.keepExisting
    for i = 1:numel(fovIdx)
        shallowObj.fov(fovIdx(i)).roi = roi;
    end
end

if p.openFirstOnly
    openList = fovIdx(1);
else
    openList = fovIdx;
end

for iOpen = 1:numel(openList)
    openIdx = openList(iOpen);
    try
        h = shallowObj.fov(openIdx).view(shallowObj.fov(openIdx).display.frame, []);
        if ~isempty(h) && isgraphics(h)
            waitfor(h);
        end
    catch
        shallowObj.fov(openIdx).view(shallowObj.fov(openIdx).display.frame, []);
    end
end
end

function p = applyExistingPolicyToManualParams(p, ctx)
policy = resolveExistingPolicy(ctx, p, 'replace');
switch lower(policy)
    case 'skip'
        p.keepExisting = true;
        p.skipExisting = true;
        p.errorOnExisting = false;
    case {'upsert','append'}
        p.keepExisting = true;
        p.skipExisting = false;
        p.errorOnExisting = false;
    case 'error'
        p.keepExisting = true;
        p.skipExisting = false;
        p.errorOnExisting = true;
    otherwise
        p.keepExisting = false;
        p.skipExisting = false;
        p.errorOnExisting = false;
end
end

function policy = resolveExistingPolicy(ctx, p, fallback)
policy = '';
try
    if isfield(ctx,'executionPolicy') && isstruct(ctx.executionPolicy) && ...
            isfield(ctx.executionPolicy,'existingPolicy') && ~isempty(ctx.executionPolicy.existingPolicy)
        policy = char(string(ctx.executionPolicy.existingPolicy));
    elseif isfield(ctx,'io') && isstruct(ctx.io) && isfield(ctx.io,'effectiveExistingPolicy') && ~isempty(ctx.io.effectiveExistingPolicy)
        policy = char(string(ctx.io.effectiveExistingPolicy));
    elseif isfield(ctx,'io') && isstruct(ctx.io) && isfield(ctx.io,'existingPolicy') && ~isempty(ctx.io.existingPolicy)
        policy = char(string(ctx.io.existingPolicy));
    elseif isstruct(p) && isfield(p,'existingPolicy') && ~isempty(p.existingPolicy)
        policy = char(string(p.existingPolicy));
    end
catch
    policy = '';
end
if isempty(policy)
    policy = fallback;
end
policy = lower(strtrim(policy));
if strcmp(policy, 'update')
    policy = 'upsert';
elseif strcmp(policy, 'replace_existing')
    policy = 'replace';
end
if ~any(strcmp(policy, {'replace','skip','upsert','append','error'}))
    policy = fallback;
end
end

function roiList = collectSelectedRois(shallowObj, fovIdx)
roiList = [];
for i = 1:numel(fovIdx)
    try
        r = shallowObj.fov(fovIdx(i)).roi;
        if ~isempty(r)
            roiList = [roiList r(:)']; %#ok<AGROW>
        end
    catch
    end
end
end

function tf = fovHasValidRois(fovObj)
tf = false;
try
    r = fovObj.roi;
    if isempty(r)
        return;
    end
    tf = ~(numel(r) == 1 && isempty(r(1).id));
catch
    tf = false;
end
end

function out = mergeStructOverride(base, override)
out = base;
if isempty(override)
    return;
end
fn = fieldnames(override);
for i = 1:numel(fn)
    if isempty(override.(fn{i}))
        continue;
    end
    out.(fn{i}) = override.(fn{i});
end
end
