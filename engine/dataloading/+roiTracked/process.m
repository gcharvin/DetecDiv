function ctx = process(ctx)
% roiTracked.process  Create moving ROIs from tracked-mask labels.

    if nargin < 1 || isempty(ctx)
        ctx = struct();
    end

    if isfield(ctx, 'interactive') && ctx.interactive
        ctx = roiTracked.ui(ctx);
        if isfield(ctx, 'cancelled') && ctx.cancelled
            return;
        end
    end

    if ~isfield(ctx, 'shallow') || isempty(ctx.shallow) || ~isa(ctx.shallow, 'shallow')
        error('roiTracked.process:ProjectRequired', 'Tracked ROI generation requires a shallow project context.');
    end

    shallowObj = ctx.shallow;

    p = roiTracked.setparam(struct());

    try
        if isfield(shallowObj.runProfiles, 'dataloading') && isfield(shallowObj.runProfiles.dataloading, 'roiTracked')
            stored = shallowObj.runProfiles.dataloading.roiTracked;
            if isstruct(stored)
                p = mergeStructOverrideLocal(p, stored);
            end
        end
    catch
    end

    if isfield(ctx, 'roiTracked') && isstruct(ctx.roiTracked) && ~isempty(ctx.roiTracked)
        p = mergeStructOverrideLocal(p, ctx.roiTracked);
    elseif isfield(ctx, 'params') && isstruct(ctx.params) && ~isempty(ctx.params)
        p = mergeStructOverrideLocal(p, ctx.params);
    end

    p = roiTracked.setparam(p);

    if isfield(ctx, 'fovIndex') && ~isempty(ctx.fovIndex)
        p.fovIndex = round(double(ctx.fovIndex(:)'));
        p.fovIndex = p.fovIndex(isfinite(p.fovIndex) & p.fovIndex >= 1);
        p.fovIndex = unique(p.fovIndex, 'stable');
    end

    callArgs = {};
    if ~isempty(p.fovIndex)
        callArgs = [callArgs, {'FOV', p.fovIndex}]; %#ok<AGROW>
    end
    if ~isempty(p.roiIndex)
        callArgs = [callArgs, {'ROI', p.roiIndex}]; %#ok<AGROW>
    end
    if ~isempty(p.channel)
        callArgs = [callArgs, {'Channel', p.channel}]; %#ok<AGROW>
    end
    if ~isempty(p.margin)
        callArgs = [callArgs, {'Margin', p.margin}]; %#ok<AGROW>
    end

    callArgs = [callArgs, {'Extract', logical(p.extract)}]; %#ok<AGROW>

    if ~isempty(p.extractFrames)
        callArgs = [callArgs, {'ExtractFrames', p.extractFrames}]; %#ok<AGROW>
    end
    if ~isempty(p.extractChannels)
        callArgs = [callArgs, {'ExtractChannels', p.extractChannels}]; %#ok<AGROW>
    end
    if ~isempty(p.saveArgs)
        callArgs = [callArgs, {'SaveArgs', p.saveArgs}]; %#ok<AGROW>
    end

    created = createTrackedCellROIs(shallowObj, callArgs{:});

    try
        if ~isfield(shallowObj.runProfiles, 'dataloading') || isempty(shallowObj.runProfiles.dataloading)
            shallowObj.runProfiles.dataloading = struct();
        end
        shallowObj.runProfiles.dataloading.roiTracked = p;
    catch
    end

    ctx.shallow = shallowObj;
    ctx.roiTracked = p;
    ctx.params = p;
    ctx.createdTracked = created;
    ctx.roiList = collectROIsLocal(shallowObj.fov);
end

function out = mergeStructOverrideLocal(base, override)
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
