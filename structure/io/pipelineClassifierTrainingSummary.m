function lines = pipelineClassifierTrainingSummary(nodes, nodeParams, selectedNodes)
%PIPELINECLASSIFIERTRAININGSUMMARY Review effective bindings before submission.
% Pure presentation of the node snapshot and per-run overrides; no ROI I/O,
% classifier persistence, formatting, or training is performed here.
if nargin<2,nodeParams=struct();end
if nargin<3,selectedNodes={};end
nodes=pipelineApplyRunNodeParams(nodes,nodeParams);lines={};
for k=1:numel(nodes)
    node=nodes(k);
    if ~isempty(selectedNodes)&&~any(strcmp(string(node.id),string(selectedNodes))),continue;end
    if isfield(node,'enabled')&&~node.enabled,continue;end
    if ~isfield(node,'pkg')||~strcmpi(node.pkg,'lstm_timeseries'),continue;end
    p=node.params;intent='';
    for key={'operation','intent'}
        if isfield(p,key{1})&&~isempty(p.(key{1})),intent=p.(key{1});break;end
    end
    if ~any(strcmpi(string(intent),{'train','training','fit'})),continue;end
    selected=lstm_timeseries.inputBindingSummary(struct('trainingParam',p));
    lines{end+1}=sprintf('Model input bindings - %s (%d, all ROIs):',node.id,numel(selected)); %#ok<AGROW>
    lines=[lines selected(:)']; %#ok<AGROW>
end
end
