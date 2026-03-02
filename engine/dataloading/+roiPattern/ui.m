function ctx = ui(ctx)
% roiPattern.ui  Launch ROI pattern parameter editor and persist settings.

    if nargin < 1 || isempty(ctx)
        ctx = struct();
    end
    if isa(ctx, 'shallow')
        ctx = struct('shallow', ctx);
    end
    if ~isstruct(ctx)
        error('roiPattern.ui:InvalidInput', 'Input must be a ctx struct or shallow object.');
    end

    shallowObj = [];
    if isfield(ctx, 'shallow')
        shallowObj = ctx.shallow;
    end
    if isempty(shallowObj) || ~isa(shallowObj, 'shallow')
        error('roiPattern.ui:ProjectRequired', 'ROI pattern GUI needs a project context.');
    end

    p = roiPattern.setparam(struct());

    try
        if isfield(shallowObj.runProfiles, 'dataloading')
            dl = shallowObj.runProfiles.dataloading;
            if isfield(dl, 'roiPattern') && isstruct(dl.roiPattern)
                p = mergeStructOverride(p, dl.roiPattern);
            elseif isfield(dl, 'roiIdentify') && isstruct(dl.roiIdentify)
                p = mergeStructOverride(p, dl.roiIdentify);
            end
        end
    catch
    end

    if isfield(ctx, 'roiPattern') && isstruct(ctx.roiPattern) && ~isempty(ctx.roiPattern)
        p = mergeStructOverride(p, ctx.roiPattern);
    elseif isfield(ctx, 'roiIdentify') && isstruct(ctx.roiIdentify) && ~isempty(ctx.roiIdentify)
        p = mergeStructOverride(p, ctx.roiIdentify);
    elseif isfield(ctx, 'params') && isstruct(ctx.params) && ~isempty(ctx.params)
        p = mergeStructOverride(p, ctx.params);
    end

    dlg = roiIdentifyGUI(shallowObj, p);
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

    ctx.roiPattern = p;
    ctx.params = p;

    try
        if ~isfield(shallowObj.runProfiles, 'dataloading') || isempty(shallowObj.runProfiles.dataloading)
            shallowObj.runProfiles.dataloading = struct();
        end
    catch
        shallowObj.runProfiles = struct('dataloading', struct());
    end
    shallowObj.runProfiles.dataloading.roiPattern = p;
    try
        shallowSave(shallowObj);
    catch
    end
    ctx.shallow = shallowObj;
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
