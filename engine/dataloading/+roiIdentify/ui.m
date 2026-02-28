function ctx = ui(ctx)
% roiIdentify.ui  Launch standardized ROI identification editor and persist settings.

    if nargin < 1 || isempty(ctx)
        ctx = struct();
    end

    if isa(ctx,'shallow')
        ctx = struct('shallow', ctx);
    elseif isa(ctx,'fov')
        error('roiIdentify.ui:FovInput', 'Use a project context for roiIdentify.ui.');
    end

    if ~isstruct(ctx)
        error('roiIdentify.ui:InvalidInput','Input must be a ctx struct or shallow object.');
    end
    if ~isfield(ctx,'shallow') || isempty(ctx.shallow) || ~isa(ctx.shallow, 'shallow')
        error('roiIdentify.ui:NoProject','A shallow project is required.');
    end

    shallowObj = ctx.shallow;

    p = roiIdentify.setparam(struct());
    if isprop(shallowObj,'runProfiles') && isstruct(shallowObj.runProfiles)
        try
            if isfield(shallowObj.runProfiles,'dataloading') && isfield(shallowObj.runProfiles.dataloading,'roiIdentify')
                stored = shallowObj.runProfiles.dataloading.roiIdentify;
                if isstruct(stored)
                    p = mergeStructOverride(p, stored);
                end
            end
        catch
        end
    end

    if isfield(ctx,'roiIdentify') && isstruct(ctx.roiIdentify) && ~isempty(ctx.roiIdentify)
        p = mergeStructOverride(p, ctx.roiIdentify);
    elseif isfield(ctx,'params') && isstruct(ctx.params) && ~isempty(ctx.params)
        p = mergeStructOverride(p, ctx.params);
    end

    if (~isfield(p,'patternList') || isempty(p.patternList))
        try
            pat = loadPattern(shallowObj);
            if isstruct(pat) && ~isempty(fieldnames(pat))
                p.patternList = pat;
            end
        catch
        end
    end

    app = roiIdentifyGUI(shallowObj, p);
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

    try
        if ~isfield(shallowObj.runProfiles,'dataloading') || isempty(shallowObj.runProfiles.dataloading)
            shallowObj.runProfiles.dataloading = struct();
        end
    catch
        shallowObj.runProfiles = struct('dataloading', struct());
    end

    shallowObj.runProfiles.dataloading.roiIdentify = p;
    if isfield(p,'patternList') && isstruct(p.patternList) && ~isempty(p.patternList)
        patIdx = 1;
        if isfield(p,'activePatternIndex') && ~isempty(p.activePatternIndex)
            try
                if p.activePatternIndex >= 1 && p.activePatternIndex <= numel(p.patternList)
                    patIdx = p.activePatternIndex;
                end
            catch
            end
        end
        storePattern(shallowObj, p.patternList(patIdx));
        ctx.pattern = p.patternList(patIdx);
        ctx.patternList = p.patternList;
    end

    try
        shallowSave(shallowObj);
    catch
    end

    ctx.roiIdentify = p;
    ctx.params = p;
    ctx.shallow = shallowObj;
    ctx.fovList = shallowObj.fov;
    ctx.roiList = collectROIs(ctx.fovList);
end

function roiList = collectROIs(fovList)
roiList = [];
for i = 1:numel(fovList)
    r = fovList(i).roi;
    if ~isempty(r)
        roiList = [roiList r(:)']; %#ok<AGROW>
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
