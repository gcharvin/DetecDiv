function intentWorkflowTest(previewPath)
%INTENTWORKFLOWTEST Native proposal graph, fork/apply, saved run and stale context.
if nargin<1, previewPath = ''; end
folder = tempname; mkdir(folder); cleanFolder = onCleanup(@()rmdir(folder,'s'));
p = shallow(); p.io.path = folder; p.io.file = 'Intent project'; mkdir(fullfile(folder,p.io.file));
p.fov.id = 'Position'; p.fov.srcpath = {'Z:\unavailable-raw'};
r = roi('R1',[1 1 12 12]); r.path = folder;
r.display.channel = {'BF'}; r.display.indexed = false; r.setExtractionStatus('extracted'); p.fov.roi = r;
t = pipeline(); t.strid = 'Original pipeline';
t.nodes = struct('id','segment','name','Existing segmentation','type','classifier','pkg','cellposesam', ...
    'func','cellposesam.classify','enabled',true,'params',struct('pkg','cellposesam','outputType','segmentation','diameter',17,'frames',1:4));
original = t.nodes;
v = detecdiv_ui(p,'Visible','off','DiscoverWorkspace',false,'LayoutFile','','AutoSaveLayout',false,'RecentProjectsFile','');
cleanup = onCleanup(@()safeDelete(v));
stop(timerfindall('Tag','DetecDivDockMenu'));
w = v.Pipeline; w.addTemplate(t);
w.Draft.import(w.Setup.values(),struct('id','segment','params',struct('frames',[2 3])));
v.Session.selectZone(1); w.setContext(v.Session);
v.planWorkflow('track_cells'); dialog = w.Planner.Figure;
assert(isempty(r.image) && isempty(fieldnames(r.cellModel)) && isempty(p.processing.pipelineRun));
assert(~w.Proposal.canApply && any(strcmp(w.Proposal.statuses,'Reused step')));
method = findall(dialog,'Tag','intent-method-track');
method.Value = 'module:legacy.classifier.trackastra'; method.ValueChangedFcn(method,[]);
assert(w.Proposal.canApply && any(strcmp(w.CompactGraph.Model.statuses,'Added')));
assert(isequaln(t.nodes,original) && isequal(w.Proposal.nodes(1).params.frames,[2 3]));
% A changed effective setting rejects the open proposal rather than overwriting it.
w.Draft.import(w.Setup.values(),struct('id','segment','params',struct('frames',[1 4]))); rejected = false;
try
    w.applyProposal();
catch err
    rejected = strcmp(err.identifier,'detecdivui:PlannerStale');
end
assert(rejected && w.Template==t);
refresh = findall(dialog,'Tag','intent-refresh'); refresh.ButtonPushedFcn(refresh,[]);
assert(isequal(w.Proposal.nodes(1).params.frames,[1 4]) && w.Proposal.canApply);
apply = findall(dialog,'Tag','intent-apply'); apply.ButtonPushedFcn(apply,[]);
copy = w.Template;
assert(copy~=t && isempty(copy.path) && numel(copy.nodes)==2 && isequal(copy.nodes(1).params.frames,[1 4]));
assert(isequaln(t.nodes,original) && w.Proposal.applied);
assert(any(strcmp(w.CompactGraph.Model.statuses,'Added')) && any(strcmp(w.CompactGraph.Model.statuses,'Reused step')));
assert(isempty(r.image) && isempty(p.processing.pipelineRun));
if ~isempty(previewPath)
    v.Host.show(); drawnow; pause(.3);
    v.Host.capture([previewPath '.before.png']);
end
floating = floatingCount(); v.Host.setDocked('Pipeline',false);
waitUntil(@()floatingCount()>floating); v.Host.setDocked('Pipeline',true);
waitUntil(@()floatingCount()==floating);
assert(w.Proposal.applied && copy==w.Template);
if ~isempty(previewPath), v.Host.focusWidget('Pipeline'); drawnow; pause(.3); v.Host.capture(previewPath); end
% Persist through the existing run path: no processing or result writes.
run = w.saveRun(); assert(~isempty(run) && strcmp(run.status,'new'));
[loaded,msg] = pipelineRunLoad(fullfile(run.path,'run.json')); assert(~isempty(loaded),msg);
assert(strcmp(loaded.ctx.workflowIntent.intent,'track_cells') && numel(loaded.ctx.pipelineSpec.nodes)==2);
assert(~loaded.ctx.workflowIntent.modifiedAfterProposal);
p.processing.pipelineRun = loaded; w.refresh();
assert(isempty(r.image) && isempty(fieldnames(r.cellModel)) && ~isfile(fullfile(folder,'im_R1.h5')));
snapshot = run.ctx.pipelineSpec;
w.showPlanHistory(); list = findall(groot,'Tag','intent-history-list'); assert(size(list.Data,1)==2);
list.CellSelectionCallback(list,struct('Indices',[1 1]));
details = findall(groot,'Tag','intent-history-details'); assert(any(contains(string(details.Value),'track_cells')));
% A proposal from a saved run uses its frozen graph even if the template changes.
copy.nodes(1).params.diameter = 99;
fields = w.Setup.Controls; fields.frames.Value = '2'; fields.frames.ValueChangedFcn(fields.frames,[]);
v.planWorkflow('measure_signals'); metric = findall(dialog,'Tag','intent-method-measure');
metric.Value = 'module:legacy.processor.computeMetrics'; metric.ValueChangedFcn(metric,[]);
assert(w.Proposal.nodes(1).params.diameter==17 && w.Proposal.canApply);
base = jsondecode(w.Proposal.baseSignature); assert(strcmp(base.settings.frames,'all'));
apply.ButtonPushedFcn(apply,[]); assert(isequaln(run.ctx.pipelineSpec,snapshot));
context = w.context(); assert(~isfield(context.run,'runId') && ~isfield(context.io,'eventLogPath'));
% Advanced edits retain the intent origin and mark the effective graph as amended.
context = w.context(); state = struct('project',p,'pipeline',struct('nodes',w.Template.nodes, ...
    'edges',w.Template.edges,'branches',w.Template.branches),'settings',w.Draft.Settings, ...
    'ctx',struct('run',struct('nodeParams',w.Draft.Overrides),'workflowIntent',context.workflowIntent));
state.pipeline.nodes(end).params.outputName = 'quantified_signal'; w.acceptAdvanced(state);
context = w.context(); assert(strcmp(context.workflowIntent.intent,'measure_signals') && context.workflowIntent.modifiedAfterProposal);
assert(isequaln(run.ctx.pipelineSpec,snapshot));
% New independent workflow storage never replaces the source template.
w.saveTemplate(folder); assert(isfile(fullfile(w.Template.path,'pipeline.json')) && isempty(t.path));
% Context changes invalidate the proposal and disable its native Apply button.
v.planWorkflow('track_cells'); method = findall(dialog,'Tag','intent-method-track');
method.Value = 'module:legacy.classifier.trackastra'; method.ValueChangedFcn(method,[]);
assert(w.Proposal.canApply);
other = shallow(); other.io.file = 'Other project'; other.fov.id = 'Other position';
v.addProject(other); assert(isempty(w.Proposal) && strcmp(apply.Enable,'off'));
assert(isempty(other.processing.pipelineRun) && isempty(r.image));
% Current project history is isolated; previous project events stay in its runs.
w.showPlanHistory(); list = findall(groot,'Tag','intent-history-list'); assert(isempty(list.Data));
disp('Intent workflow test passed: native choices, added/reused graph, stale-draft rejection, independent effective forks, docking, frozen run provenance, history, Save As and project isolation without image I/O.');
end
function safeDelete(v)
if isvalid(v), delete(v); end
end
function count = floatingCount()
windows = matlab.internal.webwindowmanager.instance.windowList; count = 0;
for k = 1:numel(windows)
    if contains(char(windows(k).URL),'undocked.html') && windows(k).isVisible(), count = count+1; end
end
end
function waitUntil(condition)
started = tic;
while ~condition()
    assert(toc(started)<12,'detecdivui:DockTimeout','Docking operation timed out.'); pause(.05); drawnow;
end
end
