function ctx = runCore(ctx)
% roiGrid.runCore  Core full-frame/grid ROI generation logic.

    if nargin < 1 || isempty(ctx)
        ctx = struct();
    end
    detecdiv_check_cancel(ctx, 'roiGrid runCore start');

    shallowObj = [];
    fovList = [];
    if isfield(ctx, 'shallow') && ~isempty(ctx.shallow)
        shallowObj = ctx.shallow;
        fovList = shallowObj.fov;
    elseif isfield(ctx, 'fovList') && ~isempty(ctx.fovList)
        fovList = ctx.fovList;
    else
        error('roiGrid.runCore:NoFOV', 'No shallow or fovList provided.');
    end

    if isempty(fovList)
        return;
    end

    p = roiGrid.setparam(struct());
    if ~isempty(shallowObj)
        try
            if isfield(shallowObj.runProfiles, 'dataloading') && isfield(shallowObj.runProfiles.dataloading, 'roiGrid')
                stored = shallowObj.runProfiles.dataloading.roiGrid;
                if isstruct(stored)
                    p = mergeStructOverride(p, stored);
                end
            end
        catch
        end
    end
    if isfield(ctx, 'roiGrid') && isstruct(ctx.roiGrid) && ~isempty(ctx.roiGrid)
        p = mergeStructOverride(p, ctx.roiGrid);
    elseif isfield(ctx, 'params') && isstruct(ctx.params) && ~isempty(ctx.params)
        p = mergeStructOverride(p, ctx.params);
    end
    p = roiGrid.setparam(p);
    p = applyExistingPolicyToGridParams(p, ctx);

    hasRuntimeFovSelection = isfield(ctx, 'sel') && isstruct(ctx.sel) && isfield(ctx.sel, 'fovs');
    if hasRuntimeFovSelection
        if isempty(ctx.sel.fovs)
            fovIdx = 1:numel(fovList);
        else
            fovIdx = normalizeFovSelection(ctx.sel.fovs, numel(fovList));
        end
    elseif isfield(ctx, 'fovIndex') && ~isempty(ctx.fovIndex)
        fovIdx = reshape(double(ctx.fovIndex), 1, []);
    elseif isfield(p, 'fovIndex') && ~isempty(p.fovIndex)
        fovIdx = reshape(double(p.fovIndex), 1, []);
    else
        fovIdx = 1:numel(fovList);
    end
    fovIdx = normalizeFovSelection(fovIdx, numel(fovList));
    if isempty(fovIdx)
        return;
    end

    for i = 1:numel(fovIdx)
        idx = fovIdx(i);
        detecdiv_check_cancel(ctx, sprintf('roiGrid FOV %d/%d', i, numel(fovIdx)));
        if p.errorOnExisting && fovHasValidRois(fovList(idx))
            error('roiGrid.runCore:ExistingROI', ...
                'FOV %d already contains ROIs and existingPolicy=error.', idx);
        end
        if p.skipExisting && fovHasValidRois(fovList(idx))
            continue;
        end
        if ~p.keepExisting
            if ~isempty(shallowObj)
                shallowObj.fov(idx).roi = roi;
            else
                fovList(idx).roi = roi;
            end
        end

        if ~isempty(shallowObj)
            target = shallowObj.fov(idx);
        else
            target = fovList(idx);
        end

        explicitRects = explicitGridRectsLocal(p);
        if ~isempty(explicitRects)
            addExplicitRois(target, explicitRects);
        else
            refFrame = resolveReferenceFrameLocal(p);
            refChannel = resolveReferenceChannelLocal(p, fovList(idx), ctx);
            detecdiv_check_cancel(ctx, sprintf('roiGrid before readImage FOV %d', idx));
            img = readImage(fovList(idx), refFrame, refChannel);
            detecdiv_check_cancel(ctx, sprintf('roiGrid after readImage FOV %d', idx));
            if isempty(img)
                error('roiGrid.runCore:ReadImageFailed', ...
                    'Cannot read reference image for FOV %d at frame %d, channel %d.', idx, refFrame, refChannel);
            end
            if strcmpi(p.mode, 'grid') && p.gridCount > 1
                addGridRois(target, img, p.gridCount);
                if isempty(shallowObj)
                    fovList(idx) = target;
                end
                continue;
            end
            roival = uint16([1 1 size(img,2) size(img,1)]);
            target.addROI(roival, target.id);
        end

        if isempty(shallowObj)
            fovList(idx) = target;
        end
    end

    if ~isempty(shallowObj)
        try
            if ~isfield(shallowObj.runProfiles, 'dataloading') || isempty(shallowObj.runProfiles.dataloading)
                shallowObj.runProfiles.dataloading = struct();
            end
            shallowObj.runProfiles.dataloading.roiGrid = p;
        catch
        end
        ctx.shallow = shallowObj;
        fovList = shallowObj.fov;
    else
        ctx.fovList = fovList;
    end

    ctx.roiGrid = p;
    ctx.params = p;
    ctx.roiList = collectROIsLocal(fovList(fovIdx));
end

function p = applyExistingPolicyToGridParams(p, ctx)
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

function addGridRois(fovObj, img, gridCount)
N = size(img,1);
M = size(img,2);
gridCount = max(1, round(double(gridCount)));
cols = ceil(sqrt(gridCount));
rows = ceil(gridCount / cols);
squareSizeRows = N / rows;
squareSizeCols = M / cols;
for ii = 1:gridCount
    rowIdx = ceil(ii / cols);
    colIdx = mod(ii - 1, cols) + 1;
    topLeftRow = round((rowIdx - 1) * squareSizeRows) + 1;
    topLeftCol = round((colIdx - 1) * squareSizeCols) + 1;
    bottomRightRow = round(min(rowIdx * squareSizeRows, N));
    bottomRightCol = round(min(colIdx * squareSizeCols, M));
    roival = [topLeftCol, topLeftRow, bottomRightCol-topLeftCol+1, bottomRightRow-topLeftRow+1];
    fovObj.addROI(uint16(roival), fovObj.id);
end
end

function addExplicitRois(fovObj, rects)
rects = round(double(rects));
for ii = 1:size(rects,1)
    roival = rects(ii,1:4);
    if any(~isfinite(roival)) || roival(3) <= 0 || roival(4) <= 0
        continue;
    end
    fovObj.addROI(uint16(roival), fovObj.id);
end
end

function rects = explicitGridRectsLocal(p)
rects = [];
keys = {'gridRects','candidateRects','previewRects'};
for i = 1:numel(keys)
    k = keys{i};
    if isfield(p, k) && isnumeric(p.(k)) && ~isempty(p.(k)) && size(p.(k),2) >= 4
        rects = round(double(p.(k)(:,1:4)));
        rects = rects(all(isfinite(rects),2) & rects(:,3) > 0 & rects(:,4) > 0, :);
        return;
    end
end
end

function frame = resolveReferenceFrameLocal(p)
frame = 1;
keys = {'referenceFrame','frame','sourceFrame','patternSourceFrame'};
for i = 1:numel(keys)
    k = keys{i};
    if isfield(p, k) && ~isempty(p.(k))
        try
            value = round(double(p.(k)(1)));
            if isfinite(value) && value >= 1
                frame = value;
                return;
            end
        catch
        end
    end
end
end

function channel = resolveReferenceChannelLocal(p, fovObj, ctx)
channel = [];
if isfield(p, 'channelIndex') && ~isempty(p.channelIndex)
    channel = numericChannelLocal(p.channelIndex);
end
if isempty(channel) && isfield(p, 'channel') && ~isempty(p.channel)
    channel = channelNameToIndexLocal(p.channel, fovObj);
end
if isempty(channel) && isfield(ctx, 'channelIdx') && ~isempty(ctx.channelIdx)
    channel = numericChannelLocal(ctx.channelIdx);
end
if isempty(channel)
    channel = firstAvailableChannelLocal(fovObj);
end
if isempty(channel)
    channel = 1;
end
end

function idx = numericChannelLocal(value)
idx = [];
try
    idx = round(double(value(1)));
    if ~isfinite(idx) || idx < 1
        idx = [];
    end
catch
    idx = [];
end
end

function idx = channelNameToIndexLocal(value, fovObj)
idx = [];
txt = char(string(value));
if isempty(strtrim(txt))
    return;
end
num = str2double(txt);
if isfinite(num)
    idx = numericChannelLocal(num);
    return;
end
try
    names = fovObj.channel;
    if iscell(names) && ~isempty(names)
        hit = find(strcmpi(names, txt), 1, 'first');
        if ~isempty(hit)
            idx = hit;
        end
    end
catch
end
end

function idx = firstAvailableChannelLocal(fovObj)
idx = [];
try
    if ~isempty(fovObj.channel)
        idx = 1;
    end
catch
end
end

function out = mergeStructOverride(base, override)
out = base;
if isempty(override)
    return;
end
fn = fieldnames(override);
for i = 1:numel(fn)
    out.(fn{i}) = override.(fn{i});
end
end

function roiList = collectROIsLocal(fovList)
roiList = [];
for i = 1:numel(fovList)
    try
        r = fovList(i).roi;
        if ~isempty(r)
            roiList = [roiList r(:)']; %#ok<AGROW>
        end
    catch
    end
end
end

function fovIdx = normalizeFovSelection(selection, nFov)
if isempty(selection)
    fovIdx = [];
    return;
end
if isnumeric(selection) || islogical(selection)
    fovIdx = reshape(double(selection), 1, []);
elseif iscell(selection)
    fovIdx = [];
    for i = 1:numel(selection)
        fovIdx = [fovIdx normalizeFovSelection(selection{i}, nFov)]; %#ok<AGROW>
    end
elseif ischar(selection) || (isstring(selection) && isscalar(selection))
    nums = regexp(char(selection), '\d+', 'match');
    fovIdx = str2double(nums);
else
    fovIdx = [];
end
fovIdx = unique(round(fovIdx(isfinite(fovIdx) & fovIdx >= 1 & fovIdx <= nFov)), 'stable');
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
