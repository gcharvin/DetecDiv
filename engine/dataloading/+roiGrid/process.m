function ctx = process(ctx)
% roiGrid.process  Create full-frame or grid ROIs on selected FOVs.

    if nargin < 1 || isempty(ctx)
        ctx = struct();
    end

    if isfield(ctx, 'interactive') && ctx.interactive
        ctx = roiGrid.ui(ctx);
        if isfield(ctx, 'cancelled') && ctx.cancelled
            return;
        end
    end

    shallowObj = [];
    fovList = [];
    if isfield(ctx, 'shallow') && ~isempty(ctx.shallow)
        shallowObj = ctx.shallow;
        fovList = shallowObj.fov;
    elseif isfield(ctx, 'fovList') && ~isempty(ctx.fovList)
        fovList = ctx.fovList;
    else
        error('roiGrid.process:NoFOV', 'No shallow or fovList provided.');
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

    if isfield(ctx, 'fovIndex') && ~isempty(ctx.fovIndex)
        fovIdx = reshape(double(ctx.fovIndex), 1, []);
    elseif isfield(p, 'fovIndex') && ~isempty(p.fovIndex)
        fovIdx = reshape(double(p.fovIndex), 1, []);
    else
        fovIdx = 1:numel(fovList);
    end
    fovIdx = unique(fovIdx(isfinite(fovIdx) & fovIdx >= 1 & fovIdx <= numel(fovList)));
    if isempty(fovIdx)
        return;
    end

    for i = 1:numel(fovIdx)
        idx = fovIdx(i);
        img = readImage(fovList(idx), 1, 1);
        if isempty(img)
            error('roiGrid.process:ReadImageFailed', 'Cannot read reference image for FOV %d.', idx);
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

        if strcmpi(p.mode, 'grid') && p.gridCount > 1
            addGridRois(target, img, p.gridCount);
        else
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

function addGridRois(fovObj, img, gridCount)
rows = sqrt(gridCount);
cols = rows;
if abs(rows - round(rows)) > eps
    error('roiGrid.process:InvalidGrid', 'Grid count must be a perfect square.');
end
rows = round(rows);
cols = round(cols);
N = size(img,1);
M = size(img,2);
squareSizeRows = N / rows;
squareSizeCols = M / cols;
for ii = 1:gridCount
    rowIdx = ceil(ii / cols);
    colIdx = mod(ii - 1, cols) + 1;
    topLeftRow = (rowIdx - 1) * squareSizeRows + 1;
    topLeftCol = (colIdx - 1) * squareSizeCols + 1;
    bottomRightRow = min(rowIdx * squareSizeRows, N);
    bottomRightCol = min(colIdx * squareSizeCols, M);
    roival = [topLeftCol, topLeftRow, bottomRightCol-topLeftCol+1, bottomRightRow-topLeftRow+1];
    fovObj.addROI(uint16(roival), fovObj.id);
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
