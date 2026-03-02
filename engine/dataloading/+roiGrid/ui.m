function ctx = ui(ctx)
% roiGrid.ui  Launch ROI grid/full-frame parameter editor and persist settings.

    if nargin < 1 || isempty(ctx)
        ctx = struct();
    end

    if isa(ctx, 'shallow')
        ctx = struct('shallow', ctx);
    end
    if ~isstruct(ctx)
        error('roiGrid.ui:InvalidInput', 'Input must be a ctx struct or shallow object.');
    end

    shallowObj = [];
    if isfield(ctx, 'shallow')
        shallowObj = ctx.shallow;
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

    app = roiGridGUI(p, inferFovCount(shallowObj));
    try
        uiwait(app.UIFigure);
    catch
    end

    cancelled = true;
    try
        cancelled = app.Cancelled;
    catch
    end
    if cancelled
        ctx.cancelled = true;
        try
            delete(app);
        catch
        end
        return;
    end

    p = app.Result;
    try
        delete(app);
    catch
    end

    ctx.roiGrid = p;
    ctx.params = p;

    if ~isempty(shallowObj)
        try
            if ~isfield(shallowObj.runProfiles, 'dataloading') || isempty(shallowObj.runProfiles.dataloading)
                shallowObj.runProfiles.dataloading = struct();
            end
        catch
            shallowObj.runProfiles = struct('dataloading', struct());
        end
        shallowObj.runProfiles.dataloading.roiGrid = p;
        try
            shallowSave(shallowObj);
        catch
        end
        ctx.shallow = shallowObj;
    end
end

function n = inferFovCount(shallowObj)
    n = 0;
    if isempty(shallowObj) || ~isa(shallowObj, 'shallow')
        return;
    end
    try
        n = numel(shallowObj.fov);
        if n == 1 && (isempty(shallowObj.fov(1).srcpath) || isempty(shallowObj.fov(1).srcpath{1}))
            n = 0;
        end
    catch
        n = 0;
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
