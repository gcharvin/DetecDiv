function ctx = ui(ctx)
% roiTracked.ui  Open workflow focused on tracked ROI module.

    if nargin < 1 || isempty(ctx)
        ctx = struct();
    end

    shallowObj = [];

    if isa(ctx, 'shallow')
        shallowObj = ctx;
        ctx = struct('shallow', shallowObj);
    elseif isstruct(ctx) && isfield(ctx, 'shallow') && ~isempty(ctx.shallow) && isa(ctx.shallow, 'shallow')
        shallowObj = ctx.shallow;
    end

    if isempty(shallowObj)
        error('roiTracked.ui:ProjectRequired', 'roiTracked.ui requires a shallow project context.');
    end

    app = workflow(shallowObj, 'FocusModule', 'roiTracked');
    if ~isempty(app)
        try
            if isvalid(app.UIFigure)
                uiwait(app.UIFigure);
            end
        catch
        end
    end

    try
        if isfield(shallowObj.runProfiles, 'dataloading') && isfield(shallowObj.runProfiles.dataloading, 'roiTracked')
            if isstruct(shallowObj.runProfiles.dataloading.roiTracked)
                ctx.roiTracked = shallowObj.runProfiles.dataloading.roiTracked;
            end
        end
    catch
    end

    ctx.shallow = shallowObj;
    ctx.cancelled = false;
end
