function ctx = ui(ctx)
% roiManual.ui  Launch manual ROI parameter editor and persist settings.

    if nargin < 1 || isempty(ctx)
        ctx = struct();
    end
    if isa(ctx, 'shallow')
        ctx = struct('shallow', ctx);
    end
    if ~isstruct(ctx)
        error('roiManual.ui:InvalidInput', 'Input must be a ctx struct or shallow object.');
    end

    shallowObj = [];
    if isfield(ctx, 'shallow')
        shallowObj = ctx.shallow;
    end

    p = roiManual.setparam(struct());

    if ~isempty(shallowObj)
        try
            if isfield(shallowObj.runProfiles, 'dataloading') && isfield(shallowObj.runProfiles.dataloading, 'roiManual')
                stored = shallowObj.runProfiles.dataloading.roiManual;
                if isstruct(stored)
                    p = mergeStructOverride(p, stored);
                end
            end
        catch
        end
    end

    if isfield(ctx, 'roiManual') && isstruct(ctx.roiManual) && ~isempty(ctx.roiManual)
        p = mergeStructOverride(p, ctx.roiManual);
    elseif isfield(ctx, 'params') && isstruct(ctx.params) && ~isempty(ctx.params)
        p = mergeStructOverride(p, ctx.params);
    end

    dlg = roiManualGUI(p, inferFovCount(shallowObj));
    try
        uiwait(dlg.UIFigure);
    catch
    end

    cancelled = true;
    try
        cancelled = dlg.Cancelled;
    catch
    end
    if cancelled
        ctx.cancelled = true;
        try
            delete(dlg);
        catch
        end
        return;
    end

    p = dlg.Result;
    try
        delete(dlg);
    catch
    end

    ctx.roiManual = p;
    ctx.params = p;

    if ~isempty(shallowObj)
        try
            if ~isfield(shallowObj.runProfiles, 'dataloading') || isempty(shallowObj.runProfiles.dataloading)
                shallowObj.runProfiles.dataloading = struct();
            end
        catch
            shallowObj.runProfiles = struct('dataloading', struct());
        end
        shallowObj.runProfiles.dataloading.roiManual = p;
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
