function [nodes, restoredIds] = pipelineRestoreRoiPatternsFromRun(nodes, ctx)
% Restore ROI detection settings from the run snapshot when reopening a run.
% Shared templates may have been edited for another acquisition meanwhile.
restoredIds = {};
if ~isstruct(nodes) || ~isstruct(ctx) || ~isfield(ctx,'pipelineSpec') || ...
        ~isstruct(ctx.pipelineSpec) || ~isfield(ctx.pipelineSpec,'nodes')
    return;
end
savedNodes = ctx.pipelineSpec.nodes;
if ~isstruct(savedNodes) || isempty(savedNodes) || ~isfield(savedNodes,'id')
    return;
end
for i = 1:numel(nodes)
    if ~any(strcmpi(char(string(nodes(i).type)), {'roiPattern','roiIdentify'}))
        continue;
    end
    j = find(strcmp({savedNodes.id}, nodes(i).id), 1);
    if isempty(j) || ~strcmpi(savedNodes(j).type, nodes(i).type) || ...
            ~isfield(savedNodes(j),'params') || ~isstruct(savedNodes(j).params)
        continue;
    end
    nodes(i).params = savedNodes(j).params;
    restoredIds{end+1} = char(string(nodes(i).id)); %#ok<AGROW>
end
end
