function projectRunsTest(previewPath)
%PROJECTRUNSTEST Run browsing without templates, frozen reuse and standalone design.
if nargin < 1, previewPath = ''; end
folder = tempname; mkdir(folder); cleanFolder = onCleanup(@()rmdir(folder,'s'));
p = shallow(); p.io.path = folder; p.io.file = 'Run history'; mkdir(fullfile(folder,p.io.file));
p.fov.id = 'Position'; p.fov.srcpath = {'Z:\missing-raw'};
p.fov.roi = roi('Cells',[1 1 10 10]); p.fov.roi.display.channel = {'Phase'};
p.fov.roi.setExtractionStatus('extracted');
node = struct('id','measure','name','Measure Signals','type','processor','pkg','computeMetrics', ...
    'func','computeMetrics.process','enabled',true,'params',struct('pkg','computeMetrics','outputName','original'));
a = makeRun('measure_1','Measurements',node);
node.id = 'segment'; node.name = 'Segment Cells'; node.type = 'classifier'; node.pkg = 'cellposesam';
node.func = 'cellposesam.classify'; node.params = struct('pkg','cellposesam','outputType','segmentation');
b = makeRun('segment_1','Segmentation',node); p.processing.pipelineRun = [a b];
orphan = makeRun('unindexed_1','Segmentation',node); %#ok<NASGU>
v = detecdiv_ui(p,'Visible','off','DiscoverWorkspace',false,'LayoutFile','','AutoSaveLayout',false,'RecentProjectsFile','','RecentPipelinesFile','');
cleanup = onCleanup(@()delete(v)); stop(timerfindall('Tag','DetecDivDockMenu'));
w = v.Pipeline; history = findall(v.widgetFigure('Projects'),'Tag','project-runs');
picker = findall(w.SettingsFigure,'Tag','pipeline-run-picker');
assert(isempty(w.Template) && size(history.Data,1)==2 && numel(p.processing.pipelineRun)==2);
assert(isempty(findall(v.widgetFigure('Pipeline'),'Tag','pipeline-project-runs')));
assert(isempty(findall(v.widgetFigure('Pipeline'),'Type','uitabgroup')));
assert(isequal(history.Data(:,1),{a.runId;b.runId}) && strcmp(picker.Value,'draft'));
assert(isempty(w.CompactGraph.Model.nodes),'Opening a project must not select a historical run.');
newRunButton = findall(v.widgetFigure('Pipeline'),'Tag','pipeline-new-run');
settingsButton = findall(v.widgetFigure('Pipeline'),'Tag','pipeline-settings');
assert(strcmp(newRunButton.Enable,'off') && strcmp(settingsButton.Enable,'off'));
assert(isempty(p.fov.roi.image));
history.CellSelectionCallback(history,struct('Indices',[2 1]));
assert(strcmp(picker.Value,b.runId) && strcmp(w.CompactGraph.Model.nodes.id,'segment'));
assert(contains(history.Tooltip,'Segmentation'));
assert(strcmp(newRunButton.Enable,'on') && strcmp(settingsButton.Enable,'on'));
history.CellSelectionCallback(history,struct('Indices',[1 1]));
assert(strcmp(picker.Value,a.runId) && strcmp(w.CompactGraph.Model.nodes.id,'measure'));
header = findall(v.widgetFigure('Pipeline'),'Tag','pipeline-view-name');
assert(contains(header.Text,a.runId) && contains(header.Text,'Measurements'));
w.openSettings('Runs'); assert(isempty(w.Template));
v.Host.findCommand('Project Runs').invoke();
assert(~isempty(v.Host.findCommand('Edit Pipeline...')) && ~isempty(v.Host.findCommand('New Pipeline...')));
v.Host.findCommand('Track Cells...').invoke();
goal = findall(w.Planner.Figure,'Tag','intent-goal'); assert(strcmp(goal.Value,'track_cells'));
w.Planner.Figure.CloseRequestFcn(w.Planner.Figure,[]);
a.ctx.run.gpuPolicy = 'force_cpu'; original = a.ctx;
template = w.useRunPipeline(); assert(~isempty(template) && isempty(template.path));
assert(strcmp(template.nodes.params.outputName,'effective') && isequaln(a.ctx,original));
assert(strcmp(w.Setup.values().outputPolicy,'upsert'));
assert(strcmp(w.Setup.values().gpuPolicy,'cpu'));
context = w.context(); assert(~isfield(context.run,'runId') && ~isfield(context.io,'eventLogPath'));
w.refreshProjectRuns(); assert(size(history.Data,1)==3 && numel(p.processing.pipelineRun)==3);
assert(isequal(p.processing.pipelineRun(1),a) && isequaln(a.ctx,original));
savedTemplate = w.Template; savedSettings = w.Draft.Settings;
history.CellSelectionCallback(history,struct('Indices',[2 1]));
assert(w.Template == savedTemplate && isequaln(w.Draft.Settings,savedSettings));
w.selectDraft(); assert(w.Template == savedTemplate && strcmp(picker.Value,'draft'));
assert(strcmp(w.CompactGraph.Model.nodes.id,'measure') && isequaln(a.ctx,original));
a.status = 'running'; w.widgetEvent('follow');
assert(strcmp(history.Data{1,2},'running'),'Draft browsing stopped project run status updates.');
a.status = 'done'; w.widgetEvent('follow');
other = shallow(); other.io.file = 'Different project'; v.addProject(other);
assert(isempty(history.Data) && strcmp(picker.Value,'draft'));
assert(~w.selectProjectRun(a.runId,p) && strcmp(picker.Value,'draft'));
v.addProject(p); assert(size(history.Data,1)==3 && strcmp(picker.Value,'draft'));
history.CellSelectionCallback(history,struct('Indices',[1 1]));
assert(strcmp(picker.Value,a.runId) && isequaln(a.ctx,original));
if ~isempty(previewPath)
    v.showProjectRuns(); v.Host.show(); drawnow; pause(.4); v.Host.capture(previewPath);
end
% Definition editing is available without a project or a run. Runtime output
% policy must not rewrite ROI-extraction defaults when returning a definition.
empty = detecdiv_ui([],'Visible','off','DiscoverWorkspace',false,'LayoutFile','','AutoSaveLayout',false,'RecentProjectsFile','','RecentPipelinesFile','');
cleanEmpty = onCleanup(@()delete(empty)); stop(timerfindall('Tag','DetecDivDockMenu'));
t = empty.Pipeline.newTemplate('Independent');
baseNames = evalin('base','who');
t.nodes = struct('id','extract','name','Extract','type','roiExtract','pkg','roiExtract', ...
    'func','roiExtract.process','enabled',true,'params',struct('pkg','roiExtract','extractChannels','@source','extend',true));
saved = t.nodes; editor = empty.Pipeline.openDefinitionEditor(); assert(~isempty(editor));
assert(strcmp(editor.UIFigure.Name,'Pipeline Designer') && strcmp(editor.NewRunButton.Enable,'off'));
state = editor.exportViewerDraft(); assert(isempty(state.project) && state.pipeline.nodes.params.extend);
state.pipeline.nodes.name = 'Extract ROI Images'; empty.Pipeline.acceptAdvanced(state);
assert(strcmp(empty.Pipeline.Template.nodes.name,'Extract ROI Images') && isequaln(t.nodes,saved));
editor.clearViewerBridge(); delete(editor);
empty.Pipeline.saveTemplate(folder);
assert(isfile(fullfile(empty.Pipeline.Template.path,'pipeline.json')) && isempty(empty.Sessions));
assert(isequal(baseNames,evalin('base','who')),'Definition editing unexpectedly changed workspace variables.');
assert(isempty(p.fov.roi.image) && isempty(dir(fullfile(folder,'**','*.h5'))));
disp('Project runs test passed: all-project history without a template, saved graphs, frozen effective forks, Process intents, explicit metadata discovery and standalone pipeline definition editing/saving without image I/O.');

    function run = makeRun(id,templateId,node)
        run = pipelineRun(); run.runId = id; run.templateId = templateId;
        run.templatePath = 'Z:\deleted-worker-template'; run.pipelineRef.id = templateId;
        run.path = fullfile(folder,p.io.file,'pipeline',id); run.status = 'done';
        run.ctx.pipelineSpec = struct('name',templateId,'nodes',node,'edges',struct([]),'branches',struct([]));
        run.ctx.run = struct('runId',id,'eventLogPath','Z:\old-events','selectedNodes',{{node.id}}, ...
            'nodeParams',struct('id',node.id,'params',struct('outputName','effective')));
        run.ctx.io = struct('eventLogPath','Z:\old-events','existingPolicy','upsert');
        pipelineRunSave(run);
    end
end
