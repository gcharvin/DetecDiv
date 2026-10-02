function rois = pipelineScopeRoisToSelectedFovs(rois, ctx)
% Keep fallback/project ROIs inside the run's selected project FOVs.
if isempty(rois) || ~isstruct(ctx) || ~isfield(ctx,'sel') || ...
        ~isstruct(ctx.sel) || ~isfield(ctx.sel,'fovs') || isempty(ctx.sel.fovs)
    return;
end
project = [];
if isfield(ctx,'shallow') && isa(ctx.shallow,'shallow')
    project = ctx.shallow;
elseif isfield(ctx,'shallowObj') && isa(ctx.shallowObj,'shallow')
    project = ctx.shallowObj;
end
if isempty(project)
    return;
end
indices = double(ctx.sel.fovs(:)');
indices = unique(round(indices(isfinite(indices) & indices >= 1 & indices <= numel(project.fov))), 'stable');
allowedIds = {};
for i = indices
    selected = project.fov(i).roi;
    for j = 1:numel(selected)
        if ~isempty(selected(j).id)
            allowedIds{end+1} = char(string(selected(j).id)); %#ok<AGROW>
        end
    end
end
keep = false(1,numel(rois));
for i = 1:numel(rois)
    keep(i) = any(strcmp(allowedIds, char(string(rois(i).id))));
end
rois = rois(keep);
end
