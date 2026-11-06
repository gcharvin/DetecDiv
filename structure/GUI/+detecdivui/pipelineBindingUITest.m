function pipelineBindingUITest()
%PIPELINEBINDINGUITEST Native bindings/static handoff, symbolic graph and drafts.
project = shallow(); project.io.file = 'Bindings project';
source = node('load',struct('channelFilter','Phase')); source.type = 'dataLoader';
target = node('pattern',roiPattern.setparam()); target.type = 'roiPattern'; target.pkg = 'roiPattern';
target.params.channel = '@resource:source:load';
template = pipeline(); template.strid = 'Symbolic analysis'; template.nodes = [source target];
original = template.nodes;
v = detecdiv_ui(project,'Visible','off','DiscoverWorkspace',false,'LayoutFile','', ...
    'AutoSaveLayout',false,'RecentProjectsFile','','RecentPipelinesFile','');
cleanup = onCleanup(@()delete(v)); w = v.Pipeline; w.addTemplate(template);
block = findall(w.Graph.Axes,'Tag','pipeline-graph-node','UserData',2);
block.ButtonDownFcn(block,[]);
bindings = findall(w.SettingsFigure,'Tag','pipeline-bindings');
assert(isscalar(bindings.Data(:,1)) && strcmp(bindings.Data{1,3},target.params.channel));
assert(isscalar(w.CompactGraph.Model.routes) && w.CompactGraph.Model.routes.resource);
assert(isempty(template.edges),'Rendering symbolic links changed the stored execution graph.');
bindings.CellSelectionCallback(bindings,struct('Indices',[1 1]));
choice = findall(w.SettingsFigure,'Tag','pipeline-binding-value');
scope = findall(w.SettingsFigure,'Tag','pipeline-binding-scope');
apply = findall(w.SettingsFigure,'Tag','pipeline-binding-apply');
scope.Value = 'This Run'; choice.Value = '@load.channels'; apply.ButtonPushedFcn(apply,[]);
assert(strcmp(w.Draft.Overrides.params.channel,'@load.channels') && isequaln(template.nodes,original));
assert(strcmp(bindings.Data{1,4},'This Run *'));
bindings.CellSelectionCallback(bindings,struct('Indices',[1 1]));
scope.Value = 'Pipeline'; choice.Value = '@resource:source:load'; apply.ButtonPushedFcn(apply,[]);
assert(isempty(w.Draft.Overrides) && w.Template ~= template && isequaln(template.nodes,original));
dialog = w.openStaticParameters('pattern'); dialog.Controls.threshold.Value = .6;
assert(dialog.apply() && w.Template.nodes(2).params.threshold == .6 && template.nodes(2).params.threshold == target.params.threshold);
dialog = w.openStaticParameters('pattern'); dialog.Controls.threshold.Value = .7;
w.newTemplate('Different definition');
assert(~dialog.apply() && isgraphics(dialog.Figure),'A stale static dialog was allowed to edit another pipeline.');
delete(dialog);
assert(isempty(project.processing.pipelineRun) && isequaln(template.nodes,original));
% A channel set is not an editable scalar text value. Applying its display
% label must never replace the original cell-valued binding.
multi = pipeline(); multi.strid = 'Channel set'; multi.nodes = original;
multi.nodes(2).params.channel = {'Phase','Mask'}; w.addTemplate(multi);
block = findall(w.Graph.Axes,'Tag','pipeline-graph-node','UserData',2); block.ButtonDownFcn(block,[]);
bindings.CellSelectionCallback(bindings,struct('Indices',[1 1]));
assert(strcmp(apply.Enable,'off') && strcmp(choice.Enable,'off'));
apply.ButtonPushedFcn(apply,[]);
assert(w.Template == multi && isequal(multi.nodes(2).params.channel,{'Phase','Mask'}));
dialog = w.openStaticParameters('pattern'); dialog.Controls.threshold.Value = .8;
run = pipelineRun(); run.runId = 'saved'; run.templateId = 'Saved pipeline'; run.status = 'done';
run.ctx.pipelineSpec = struct('nodes',original,'edges',struct([]),'branches',struct([])); before = run.ctx;
project.processing.pipelineRun = run; w.selectProjectRun(run.runId,project);
assert(strcmp(apply.Enable,'off') && ~dialog.apply() && isequaln(run.ctx,before));
delete(dialog);
enum = pipeline(); enum.strid = 'Channel choices'; enum.nodes = original;
enum.nodes(2).params.channel = {'Phase','Mask','Phase'}; w.addTemplate(enum); w.selectDraft();
block = findall(w.Graph.Axes,'Tag','pipeline-graph-node','UserData',2); block.ButtonDownFcn(block,[]);
bindings.CellSelectionCallback(bindings,struct('Indices',[1 1]));
assert(strcmp(apply.Enable,'on') && any(strcmp(choice.Items,'Mask')));
scope.Value = 'This Run'; choice.Value = '@load.channels'; apply.ButtonPushedFcn(apply,[]);
assert(strcmp(w.Draft.Overrides.params.channel{end},'@load.channels') && ...
    isequal(enum.nodes(2).params.channel,{'Phase','Mask','Phase'}));
disp('Pipeline binding UI test passed: symbolic values and graph, typed static edits, run overrides, protected source definitions and stale dialog rejection.');
end

function n = node(id,params)
n = struct('id',id,'name',id,'type','probe','pkg','','func','', ...
    'enabled',true,'params',params,'contract',struct());
n.contract.resources = struct('in',struct([]),'out',struct([]));
n.contract.parameters = struct('static',{{}},'run',{{}});
end
