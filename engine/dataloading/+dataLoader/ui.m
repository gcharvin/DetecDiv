function ctx = ui(ctx)
% dataLoader.ui  Launch standardized data loader parameter editor.

    if nargin < 1 || isempty(ctx)
        ctx = struct();
    end

    if isa(ctx,'shallow')
        ctx = struct('shallow', ctx);
    end
    if ~isstruct(ctx)
        error('dataLoader.ui:InvalidInput','Input must be a ctx struct or shallow object.');
    end

    p = dataLoader.setparam(struct());

    shallowObj = [];
    if isfield(ctx,'shallow') && ~isempty(ctx.shallow)
        shallowObj = ctx.shallow;
        try
            if isfield(shallowObj.runProfiles,'dataloading') && isfield(shallowObj.runProfiles.dataloading,'dataLoader')
                stored = shallowObj.runProfiles.dataloading.dataLoader;
                if isstruct(stored)
                    p = mergeStructOverride(p, stored);
                end
            end
        catch
        end
    end

    if isfield(ctx,'dataLoader') && isstruct(ctx.dataLoader) && ~isempty(ctx.dataLoader)
        p = mergeStructOverride(p, ctx.dataLoader);
    elseif isfield(ctx,'params') && isstruct(ctx.params) && ~isempty(ctx.params)
        p = mergeStructOverride(p, ctx.params);
    end

    app = dataLoaderGUI(p);
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

    ctx.dataLoader = p;
    ctx.params = p;

    if ~isempty(shallowObj)
        try
            if ~isfield(shallowObj.runProfiles,'dataloading') || isempty(shallowObj.runProfiles.dataloading)
                shallowObj.runProfiles.dataloading = struct();
            end
        catch
            shallowObj.runProfiles = struct('dataloading', struct());
        end
        shallowObj.runProfiles.dataloading.dataLoader = p;
        try
            shallowSave(shallowObj);
        catch
        end
        ctx.shallow = shallowObj;
        try
            ctx.fovList = shallowObj.fov;
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
