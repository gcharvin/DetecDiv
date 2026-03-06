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

    if isfield(ctx, 'fovIndex') && ~isempty(ctx.fovIndex)
        fovIdx = reshape(double(ctx.fovIndex), 1, []);
    elseif ~isempty(p.fovIndex)
        fovIdx = reshape(double(p.fovIndex), 1, []);
    else
        fovIdx = 1:numel(shallowObj.fov);
    end
    fovIdx = unique(fovIdx(isfinite(fovIdx) & fovIdx >= 1 & fovIdx <= numel(shallowObj.fov)));
    if isempty(fovIdx)
        return;
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
