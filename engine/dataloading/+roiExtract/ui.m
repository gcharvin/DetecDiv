function ctx = ui(ctx)
% roiExtract.ui  Launch ROI extraction parameter editor and persist settings.

    if nargin < 1 || isempty(ctx)
        ctx = struct();
    end

    if isa(ctx,'shallow')
        ctx = struct('shallow', ctx);
    end
    if ~isstruct(ctx)
        error('roiExtract.ui:InvalidInput','Input must be a ctx struct or shallow object.');
    end

    shallowObj = [];
    if isfield(ctx,'shallow')
        shallowObj = ctx.shallow;
    end

    p = roiExtract.setparam(struct());

    if ~isempty(shallowObj)
        try
            if isfield(shallowObj.runProfiles,'dataloading') && isfield(shallowObj.runProfiles.dataloading,'roiExtract')
                stored = shallowObj.runProfiles.dataloading.roiExtract;
                if isstruct(stored)
                    p = mergeStructOverride(p, stored);
                end
            end
        catch
        end
    end

    if isfield(ctx,'roiExtract') && isstruct(ctx.roiExtract) && ~isempty(ctx.roiExtract)
        p = mergeStructOverride(p, ctx.roiExtract);
    elseif isfield(ctx,'params') && isstruct(ctx.params) && ~isempty(ctx.params)
        p = mergeStructOverride(p, ctx.params);
    end

    app = roiExtractGUI(p);
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

    ctx.roiExtract = p;
    ctx.params = p;

    if ~isempty(shallowObj)
        try
            if ~isfield(shallowObj.runProfiles,'dataloading') || isempty(shallowObj.runProfiles.dataloading)
                shallowObj.runProfiles.dataloading = struct();
            end
        catch
            shallowObj.runProfiles = struct('dataloading', struct());
        end
        shallowObj.runProfiles.dataloading.roiExtract = p;
        try
            shallowSave(shallowObj);
        catch
        end
        ctx.shallow = shallowObj;
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
