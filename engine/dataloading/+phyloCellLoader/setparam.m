function param = setparam(ctx)
% phyloCellLoader.setparam  Defaults for legacy phyloCell project import.

param = dataLoader.setparam(struct());
param.path = '';
param.projectPath = '';
param.projectName = '';
param.includeContours = false;
param.segmentationPolicy = 'prefer_autotrack';
param.write = true;
param.interactive = false;
param.useExistingProjectSources = false;

if nargin < 1 || isempty(ctx) || ~isstruct(ctx)
    return;
end

if isfield(ctx, 'path') && ~isempty(ctx.path)
    param.path = char(string(ctx.path));
end
if isfield(ctx, 'projectPath') && ~isempty(ctx.projectPath)
    param.projectPath = char(string(ctx.projectPath));
end
if isfield(ctx, 'projectName') && ~isempty(ctx.projectName)
    param.projectName = char(string(ctx.projectName));
end
end
