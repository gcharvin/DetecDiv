function [nodes, restoredIds] = pipelineRestoreClassifierLinksFromRun(nodes, ctx)
%PIPELINERESTORECLASSIFIERLINKSFROMRUN Restore run-owned classifier links.
% A pipeline template can predate a run's linked model. Keep the template's
% graph and settings, but recover classifier module references saved in the
% run's immutable pipelineSpec when reopening that run in Pipeline2.

restoredIds = {};
if ~isstruct(nodes) || isempty(nodes) || ~isstruct(ctx) || ...
        ~isfield(ctx,'pipelineSpec') || ~isstruct(ctx.pipelineSpec) || ...
        ~isfield(ctx.pipelineSpec,'nodes') || ...
        ~isstruct(ctx.pipelineSpec.nodes) || isempty(ctx.pipelineSpec.nodes)
    return;
end
savedNodes = ctx.pipelineSpec.nodes;
if ~isfield(savedNodes,'id'),return;end
savedIds = cellstr(string({savedNodes.id}));

for i = 1:numel(nodes)
    if ~strcmpi(nodeText(nodes(i),'type'),'classifier'),continue;end
    nodeId = nodeText(nodes(i),'id');
    if isempty(nodeId),continue;end
    j = find(strcmp(savedIds,nodeId),1);
    if isempty(j) || ~strcmpi(nodeText(savedNodes(j),'type'),'classifier')
        continue;
    end
    currentPkg = nodeText(nodes(i),'pkg');
    savedPkg = nodeText(savedNodes(j),'pkg');
    if ~isempty(currentPkg) && ~isempty(savedPkg) && ...
            ~strcmpi(currentPkg,savedPkg)
        continue;
    end
    if ~isfield(savedNodes(j),'params') || ...
            ~isstruct(savedNodes(j).params) || ...
            ~isfield(savedNodes(j).params,'modulePath')
        continue;
    end
    savedParams = savedNodes(j).params;
    modulePath = nodeText(savedParams,'modulePath');
    if isempty(modulePath),continue;end
    moduleId = nodeText(savedParams,'moduleId');
    if isempty(moduleId)
        [~,moduleId] = fileparts(regexprep(modulePath,'[\\/]+$',''));
    end
    if isempty(moduleId),continue;end
    if ~isfield(nodes(i),'params') || ~isstruct(nodes(i).params)
        nodes(i).params = struct();
    end
    currentPath = nodeText(nodes(i).params,'modulePath');
    currentId = nodeText(nodes(i).params,'moduleId');
    if strcmpi(currentPath,modulePath) && strcmp(currentId,moduleId)
        continue;
    end
    nodes(i).params.modulePath = modulePath;
    nodes(i).params.moduleId = moduleId;
    % A MATLAB base-workspace variable from the old session is not durable.
    if isfield(nodes(i).params,'moduleVar')
        nodes(i).params = rmfield(nodes(i).params,'moduleVar');
    end
    restoredIds{end+1} = nodeId; %#ok<AGROW>
end
end

function value = nodeText(source,key)
value = '';
try
    if isstruct(source) && isfield(source,key) && ~isempty(source.(key))
        value = strtrim(char(string(source.(key))));
    end
catch
end
end
