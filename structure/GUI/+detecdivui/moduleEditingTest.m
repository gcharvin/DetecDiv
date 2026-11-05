function moduleEditingTest(previewPath)
%MODULEEDITINGTEST Targeted module editing, replacement and protected drafts.
if nargin < 1, previewPath = ''; end
folder = tempname; mkdir(folder); cleanFolder = onCleanup(@()rmdir(folder,'s'));
project = shallow(); project.io.path = folder; project.io.file = 'Module editing';
project.fov.id = 'Position'; project.fov.srcpath = {'Z:\missing-raw'};
template = pipeline(); template.strid = 'Editable';
params = roiGrid.setparam(); params.mode = 'grid'; params.gridCount = 4;
node = struct('id','grid_a','name','First grid','type','roiGrid','pkg','roiGrid', ...
    'func','roiGrid.process','params',params,'enabled',true);
template.nodes = repmat(node,1,3);
template.nodes(2).id = 'grid_b'; template.nodes(2).name = 'Second grid';
template.nodes(3).id = 'grid_c'; template.nodes(3).name = 'Third grid';
template.edges = [edge('grid_a','grid_b'),edge('grid_a','grid_c'),edge('grid_b','grid_c')];
originalNodes = template.nodes; originalEdges = template.edges;
v = detecdiv_ui(project,'Visible','off','DiscoverWorkspace',false,'LayoutFile','', ...
    'AutoSaveLayout',false,'RecentProjectsFile','','RecentPipelinesFile','');
cleanup = onCleanup(@()delete(v)); stop(timerfindall('Tag','DetecDivDockMenu'));
w = v.Pipeline; w.addTemplate(template); w.openSettings('Steps');
settings = w.Setup.values(); settings.runId = 'My draft'; settings.frames = '2:5';
settings.selectedNodes = {'grid_a','grid_b','grid_c'};
overrides = [struct('id','grid_a','params',struct('referenceFrame',2)), ...
    struct('id','grid_b','params',struct('referenceFrame',3))];
w.Draft.import(settings,overrides); w.refresh();
steps = findall(w.SettingsFigure,'Tag','pipeline-steps');
steps.CellSelectionCallback(steps,struct('Indices',[2 1]));
edit = findall(w.SettingsFigure,'Tag','pipeline-edit-module');
change = findall(w.SettingsFigure,'Tag','pipeline-change-type');
assert(strcmp(edit.Enable,'on') && strcmp(change.Enable,'on'));
edit.ButtonPushedFcn(edit,[]); editor = w.AdvancedEditor;
assert(strcmp(editor.TabGroup.SelectedTab.UserData.nodeId,'grid_b'));
assert(editor.MainTabGroup.SelectedTab == editor.BuildTab && strcmp(editor.RunButton.Enable,'off'));
% Selecting another module reuses the open designer and its pending edits.
same = w.editModule('grid_a'); assert(same == editor);
editor.changeViewerModuleType('grid_a',[]); % cancelled catalogue selection
assert(strcmp(editor.exportViewerDraft().pipeline.nodes(1).type,'roiGrid'));
editor.changeViewerModuleType('grid_a',struct('type','roiManual','pkg','roiManual', ...
    'paramsPatch',struct('keepExisting',true)));
state = editor.exportViewerDraft();
assert(strcmp(state.pipeline.nodes(1).id,'grid_a') && strcmp(state.pipeline.nodes(1).type,'roiManual'));
assert(~isfield(state.pipeline.nodes(1).params,'gridCount') && state.pipeline.nodes(1).params.keepExisting);
assert(isequaln(state.pipeline.edges,originalEdges),'Module replacement rewired the graph.');
assert(isequaln(template.nodes,originalNodes));
editor.returnToViewer();
assert(strcmp(w.Template.nodes(1).type,'roiManual') && w.Template ~= template);
assert(strcmp(w.Setup.values().runId,'My draft') && strcmp(w.Setup.values().frames,'2:5'));
assert(~w.Draft.has('grid_a','referenceFrame') && w.Draft.has('grid_b','referenceFrame'));
effective = w.Draft.effectiveNodes(); assert(effective(2).params.referenceFrame == 3);
assert(isequaln(w.Template.edges,originalEdges) && isequaln(template.nodes,originalNodes));
% Right-click actions target IDs rather than a previous table selection.
menus = findall(v.widgetFigure('Pipeline'),'Tag','pipeline-module-menu');
menu = menus(strcmp({menus.UserData},'grid_c'));
action = findall(menu,'Tag','pipeline-module-edit'); action.MenuSelectedFcn(action,[]);
editor = w.AdvancedEditor; assert(strcmp(editor.TabGroup.SelectedTab.UserData.nodeId,'grid_c'));
% Exercise the existing designer's type-change catalogue callback as well.
items = findall(editor.UIFigure,'Type','uimenu'); chosen = [];
for k = 1:numel(items)
    data = items(k).UserData;
    if isstruct(data) && isfield(data,'action') && strcmp(data.action,'change_type') && ...
            strcmp(data.nodeType,'roiManual') && strcmp(data.pkg,'roiManual')
        chosen = items(k); break;
    end
end
assert(~isempty(chosen) && strcmp(chosen.Enable,'on'));
chosen.MenuSelectedFcn(chosen,struct('Source',chosen));
assert(strcmp(editor.exportViewerDraft().pipeline.nodes(3).type,'roiManual'));
beforeDiscard = w.Template; editor.discardViewerDraft(); w.openSettings('Steps');
assert(w.Template == beforeDiscard && strcmp(w.Template.nodes(3).type,'roiGrid'));
assert(strcmp(w.Setup.values().frames,'2:5') && w.Draft.has('grid_b','referenceFrame'));
if ~isempty(previewPath)
    w.SettingsFigure.Position = [230 140 700 800]; drawnow;
    exportapp(w.SettingsFigure,previewPath);
end
% Editing a historical graph forks its snapshot and never changes run.json.
run = pipelineRun(); run.runId = 'completed_1'; run.templateId = template.strid;
run.status = 'done'; run.path = fullfile(folder,project.io.file,'pipeline',run.runId);
run.ctx.pipelineSpec = struct('name',template.strid,'nodes',template.nodes, ...
    'edges',template.edges,'branches',struct([]));
run.ctx.run = struct('nodeParams',overrides,'selectedNodes',{{'grid_a','grid_b','grid_c'}});
pipelineRunSave(run); source = fileread(fullfile(run.path,'run.json')); originalContext = run.ctx;
project.processing.pipelineRun = run; w.refresh();
picker = findall(w.SettingsFigure,'Tag','pipeline-run-picker');
picker.Value = run.runId; picker.ValueChangedFcn(picker,[]);
editor = w.editModule('grid_b');
assert(~isempty(editor) && isempty(w.Template.path));
assert(strcmp(editor.TabGroup.SelectedTab.UserData.nodeId,'grid_b'));
editor.changeViewerModuleType('grid_b',struct('type','roiManual','pkg','roiManual'));
editor.returnToViewer();
assert(strcmp(w.Template.nodes(2).type,'roiManual') && isempty(w.Setup.values().runId));
assert(isequaln(run.ctx,originalContext) && strcmp(fileread(fullfile(run.path,'run.json')),source));
assert(isempty(dir(fullfile(folder,'**','*.h5'))));
disp('Module editing test passed: direct selected-module editing, catalogue replacement, intact graph links, preserved draft settings, discard and protected historical runs.');
end

function e = edge(from,to)
e = struct('from',from,'to',to,'fromPort','roiList','toPort','roiList','condition','');
end
