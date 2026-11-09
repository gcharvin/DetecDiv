function workspaceTest()
%WORKSPACETEST Live handle discovery, aliases, arrays and native browser refresh.
names = {'ddUiTestProject','ddUiTestAlias','ddUiTestModels','ddUiTestProcessor', ...
    'ddUiTestPipeline','ddUiTestDeleted'};
for k = 1:numel(names)
    assert(~evalin('base',sprintf('exist(''%s'',''var'')',names{k})), ...
        'Test variable already exists: %s',names{k});
end
cleanup = onCleanup(@()evalin('base',['clear ' strjoin(names,' ')]));
project = shallow(); project.io.file = 'Workspace experiment';
model = classi(); model.strid = 'Workspace model';
models = [model,classi()]; models(2).strid = 'Second model';
processor = process(); processor.strid = 'Workspace processor';
template = pipeline(); template.strid = 'Workspace pipeline';
deleted = shallow(); delete(deleted);
assignin('base',names{1},project); assignin('base',names{2},project);
assignin('base',names{3},models); assignin('base',names{4},processor);
assignin('base',names{5},template); assignin('base',names{6},deleted);
entries = detecdivui.workspaceObjects();
hit = find(arrayfun(@(entry)isequal(entry.object,project),entries));
assert(isscalar(hit) && numel(entries(hit).variables) == 2);
viewer = detecdiv_ui([],'DiscoverWorkspace',true,'Visible','off', ...
    'LayoutFile','','AutoSaveLayout',false,'RecentProjectsFile','','RecentPipelinesFile','');
closeViewer = onCleanup(@()delete(viewer));
assert(any(cellfun(@(session)isequal(session.Project,project),viewer.Sessions)));
assert(any(arrayfun(@(entry)isequal(entry.object,model),viewer.WorkspaceObjects)));
assert(~any(strcmp({viewer.WorkspaceObjects.kind},'pipeline')));
assert(any(cellfun(@(p)isequal(p,template),viewer.Pipeline.Templates)));
assert(isempty(viewer.Pipeline.RecentPipelines.Paths),'Workspace discovery added a recent-file entry.');
tree = findall(viewer.widgetFigure('Projects'),'Tag','projects-tree');
nodes = findall(tree,'Tag','workspace-object');
assert(~any(strcmp({nodes.Text},template.strid)));
assert(~any(strcmp({nodes.Text},'Workspace model')));
selector = findall(viewer.widgetFigure('Classifier'),'Tag','classifier-selector');
index = find(strcmp(selector.Items,'Workspace model'));
assert(isscalar(index)); selector.Value = index; selector.ValueChangedFcn(selector,[]);
info = findall(viewer.widgetFigure('Projects'),'Tag','project-information');
assert(isequal(viewer.Classifiers.Current,model) && isempty(info.Data));
projectNode = findall(tree,'Tag','project-node'); tree.SelectedNodes = projectNode;
tree.SelectionChangedFcn(tree,[]);
viewer.showProjectRuns();
assert(strcmp(info.Visible,'off'));
assert(strcmp(findall(viewer.widgetFigure('Projects'),'Tag','project-runs').Parent.Visible,'on'));
before = numel(viewer.Sessions);
viewer.Host.findCommand('Refresh Workspace').invoke();
assert(numel(viewer.Sessions) == before);
assert(isequal(evalin('base',names{1}),project));
delete(viewer);
% Relaunch uses the same project/model handles, without scientific loading.
viewer = detecdiv_ui([],'DiscoverWorkspace',true,'Visible','off', ...
    'LayoutFile','','AutoSaveLayout',false,'RecentProjectsFile','','RecentPipelinesFile','');
closeAgain = onCleanup(@()delete(viewer));
assert(any(cellfun(@(session)isequal(session.Project,project),viewer.Sessions)));
assert(any(cellfun(@(p)isequal(p,template),viewer.Pipeline.Templates)));
assert(~any(strcmp({viewer.WorkspaceObjects.kind},'pipeline')));
evalin('base',['clear ' names{3}]);
viewer.refreshWorkspace();
assert(~any(arrayfun(@(entry)isequal(entry.object,model),viewer.WorkspaceObjects)));
disp('Workspace test passed: discovery, aliases, arrays, invalid handles, typed collections and relaunch.');
end
