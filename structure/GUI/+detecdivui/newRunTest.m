function newRunTest(previewPath,checkEditor)
%NEWRUNTEST Native run configuration, graph selection and real JSON round-trip.
if nargin < 1, previewPath = ''; end
if nargin < 2, checkEditor = false; end
folder = tempname; mkdir(folder); cleanup = onCleanup(@()rmdir(folder,'s'));
project = shallow(); project.io.path = folder; project.io.file = 'Graph experiment';
mkdir(fullfile(folder,project.io.file));
project.fov(1).id = 'PosA'; project.fov(1).frames = 5;
project.fov(2) = fov(); project.fov(2).id = 'PosB'; project.fov(2).frames = 5;
for k = 1:2
    project.fov(k).roi(1) = roi('trap_a',[1 1 8 8]);
    project.fov(k).roi(2) = roi('trap_b',[9 1 8 8]);
end
template = pipelineConstruct(folder,'Cell analysis',1);
p = roiGrid.setparam(); p.mode = 'grid'; p.gridCount = 2; p.referenceFrame = 1;
node = struct('id','grid_1','name','Find traps','type','roiGrid','pkg','roiGrid', ...
    'func','roiGrid.process','params',p,'enabled',true);
template.nodes = [node node]; template.nodes(2).id = 'grid_2'; template.nodes(2).name = 'Refine traps';
template.edges = struct('from','grid_1','to','grid_2'); original = template.nodes;
viewer = detecdiv_ui(project,'Visible','off','LayoutFile','','AutoSaveLayout',false,'RecentPipelinesFile','');
closeViewer = onCleanup(@()delete(viewer)); viewer.Pipeline.addTemplate(template);
widget = viewer.Pipeline; figure = widget.SettingsFigure;
new = findall(viewer.widgetFigure('Pipeline'),'Tag','pipeline-new-run'); new.ButtonPushedFcn(new,[]);
assert(isempty(project.processing.pipelineRun) && ~isfolder(fullfile(folder,project.io.file,'pipeline')));
fields = widget.Setup.Controls;
setField(fields.runId,'analysis_1'); setField(fields.fovs,'PosB'); setField(fields.rois,'trap_b');
setField(fields.frames,'1:2:5'); setField(fields.runPolicy,'restart'); setField(fields.outputPolicy,'replace');
setField(fields.gpuPolicy,'cpu'); setField(fields.executionTarget,'local_wsl');
setField(fields.description,'Run setup fixture');
toggles = findall(widget.Graph.Axes,'Tag','pipeline-graph-toggle');
toggle = toggles(find(arrayfun(@(h)h.UserData == 1,toggles),1)); toggle.ButtonDownFcn(toggle,[]);
assert(isequal(widget.Graph.Model.included,[false true]));
blocks = findall(widget.Graph.Axes,'Tag','pipeline-graph-node');
block = blocks(find(arrayfun(@(h)h.UserData == 2,blocks),1)); block.ButtonDownFcn(block,[]);
assert(widget.Graph.Model.selected == 2);
params = findall(figure,'Tag','pipeline-parameters'); row = find(strcmp(params.UserData,'referenceFrame'));
params.CellSelectionCallback(params,struct('Indices',[row 1]));
number = findall(figure,'Tag','pipeline-value-number'); number.Value = 3;
apply = findall(figure,'Tag','pipeline-apply-param'); apply.ButtonPushedFcn(apply,[]);
ctx = widget.context();
assert(isequal(ctx.sel.fovs,2) && isequal(ctx.sel.rois,2) && isequal(ctx.sel.frames,[1 3 5]));
assert(isequal(ctx.run.selectedNodes,{'grid_2'}) && strcmp(ctx.run.runPolicy,'restart'));
assert(strcmp(ctx.io.existingPolicy,'replace') && strcmp(ctx.run.gpuPolicy,'cpu'));
assert(isequal(ctx.roiList,project.fov(2).roi(2)) && isempty(ctx.roiList.image));
[~,report] = widget.check('validate');
assert(isscalar(report.nodes) && strcmp(report.nodes.id,'grid_2'));
% Invalid selectors must never broaden to all data or evaluate MATLAB code.
setField(fields.frames,'1+2'); failed = false;
try
    widget.context();
catch
    failed = true;
end
assert(failed); setField(fields.frames,'1:2:5');
if checkEditor
    projectName = matlab.lang.makeValidName(project.io.file);
    projectName = matlab.lang.makeUniqueStrings(projectName,evalin('base','who'),namelengthmax);
    clearPublished = onCleanup(@()evalin('base',['clear ' projectName]));
    editor = widget.openEditor(); assert(~isempty(editor)); closeEditor = onCleanup(@()delete(editor));
    editor.UIFigure.Visible = 'off';
    assert(strcmp(editor.TemplateidEditField.Value,'analysis_1'));
    assert(strcmp(editor.ResumeoptionsDropDown.Value,'Restart from scratch'));
    assert(strcmp(editor.RuntimeOutputPolicyDropDown.Value,'replace'));
    assert(isequal(detecdivui.RunSetup.selection(editor.RuntimeFovsEditField.Value),2));
    assert(isequal(detecdivui.RunSetup.selection(editor.RuntimeRoisEditField.Value),2));
    assert(strcmp(editor.RuntimeFramesEditField.Value,'1  3  5') || ...
        isequal(detecdivui.RunSetup.selection(editor.RuntimeFramesEditField.Value),[1 3 5]));
    clear closeEditor clearPublished;
end
saved = widget.saveRun(); assert(~isempty(saved));
assert(strcmp(saved.status,'new') && isfile(fullfile(saved.path,'run.json')));
[loaded,message] = pipelineRunLoad(saved.path); assert(~isempty(loaded),message);
assert(isequal(loaded.ctx.run.selectedNodes,{'grid_2'}) && strcmp(loaded.ctx.io.existingPolicy,'replace'));
assert(isequal(loaded.ctx.sel.frames(:)',[1 3 5]) && loaded.ctx.run.nodeParams(1).params.referenceFrame == 3);
assert(isequal(template.nodes,original) && ~isfield(loaded.ctx,'images'));
assert(isscalar(project.processing.pipelineRun) && isequal(saved,widget.saveRun()));
% Historic graph uses the saved snapshot, never an edited current template.
template.nodes(2).name = 'Changed after save'; widget.refresh();
runs = findall(figure,'Tag','pipeline-runs'); runs.CellSelectionCallback(runs,struct('Indices',[1 1]));
assert(strcmp(widget.RunGraph.Model.nodes(2).name,'Refine traps'));
assert(isequal(widget.RunGraph.Model.included,[false true]));
other = shallow(); other.io.file = 'Other'; viewer.addProject(other);
assert(isempty(fieldnames(widget.Draft.Settings)));
viewer.addProject(project); assert(strcmp(widget.Setup.Controls.runId.Value,'analysis_1'));
if ~isempty(previewPath)
    viewer.Host.resetLayout(); viewer.Host.show(); viewer.Host.snapshot(); viewer.Host.focusWidget('Pipeline');
    tabs = findall(figure,'Type','uitab','Title','Run'); tabs.Parent.SelectedTab = tabs;
    drawnow; pause(.3); viewer.Host.capture(previewPath);
    tabs = findall(figure,'Type','uitab','Title','Steps');
    tabs = tabs(arrayfun(@(h)numel(h.Parent.Children)==4,tabs)); tabs.Parent.SelectedTab = tabs;
    [parent,name,extension] = fileparts(previewPath); drawnow; pause(.3);
    viewer.Host.capture(fullfile(parent,[name '_graph' extension]));
    % Inspect a longer branched graph at the actual default widget width.
    preview = repmat(node,1,8);
    names = {'Load images','Find traps','Extract ROIs','Combine channels', ...
        'Segment cells','Classify states','Measure fluorescence','Compute lineages'};
    types = {'dataLoader','roiPattern','roiExtract','processor','classifier','classifier','processor','processor'};
    edges = struct('from',{},'to',{});
    for k = 1:8
        preview(k).id = sprintf('step_%d',k); preview(k).name = names{k}; preview(k).type = types{k};
        if k > 1, edges(end+1) = struct('from',sprintf('step_%d',k-1),'to',preview(k).id); end %#ok<AGROW>
    end
    edges(end+1) = struct('from','step_3','to','step_7');
    widget.CompactGraph.show(preview,edges,5,true(1,8)); drawnow; pause(.3);
    assert(widget.CompactGraph.Axes.Parent.Position(4) >= 8*60);
    viewer.Host.capture(fullfile(parent,[name '_long_graph' extension]));
    widget.refresh();
end
widget.newRun(); assert(isempty(widget.Draft.Overrides) && ~isfield(widget.Draft.Settings,'selectedNodes'));
assert(strcmp(widget.Setup.Controls.runId.Value,'') && isscalar(project.processing.pipelineRun));
assert(isequal(detecdivui.RunSetup.selection('2,1:2'),[2 1]));
assert(isequal(detecdivui.RunSetup.selection('FOV B,FOV A',{'FOV A','FOV B'}),[2 1]));
% Empty module selection is an error, never the backend's shorthand for all.
detecdivui.Callback.call(widget.Graph.OnToggle,1); detecdivui.Callback.call(widget.Graph.OnToggle,2); failed = false;
try
    widget.context();
catch
    failed = true;
end
assert(failed); detecdivui.Callback.call(widget.Graph.OnToggle,2);
% Raw-source settings do not inspect/restrict source positions to the current project.
template.nodes(1).type = 'dataLoader';
setField(fields.inputSourceMode,'raw_dataloader'); setField(fields.rawDataPath,fullfile(folder,'missing raw'));
setField(fields.fovs,'3'); setField(fields.rois,'all');
ctx = widget.context(); assert(~isfield(ctx,'images') && isequal(ctx.sel.fovs,3));
index = find(strcmp({ctx.run.nodeParams.id},'grid_1'));
assert(strcmp(ctx.run.nodeParams(index).params.path,fullfile(folder,'missing raw')));
assert(~ctx.run.nodeParams(index).params.useExistingProjectSources);
disp('New run test passed: graph callbacks, selection, settings, save/load, isolation and historic snapshot.');
end
function setField(control,value)
control.Value = value; control.ValueChangedFcn(control,[]);
end
