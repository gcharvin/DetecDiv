function fileToolsTest()
%FILETOOLSTEST File tools keep pipelines in their own widget and preserve objects.
folder = tempname; mkdir(folder); cleanup = onCleanup(@()rmdir(folder,'s'));
classiObj = classi(); classiObj.strid = 'Test classifier'; classiObj.path = folder;
file = fullfile(folder,'test_classification.mat'); save(file,'classiObj');
template = pipelineConstruct(folder,'Test pipeline',1); pipelineSave(template);
viewer = detecdiv_ui([],'Visible','off','LayoutFile','','AutoSaveLayout',false, ...
    'RecentProjectsFile','','RecentPipelinesFile','');
closeViewer = onCleanup(@()delete(viewer));
baseNames = evalin('base','who');
assert(~isempty(viewer.Host.findCommand('Open Classifier...')));
assert(~isempty(viewer.Host.findCommand('Open Pipeline...')));
classifier = viewer.openClassifier(file); assert(isa(classifier,'classi'));
assert(isempty(viewer.Sessions) && isscalar(viewer.WorkspaceObjects));
info = findall(viewer.widgetFigure('Projects'),'Tag','project-information');
assert(strcmp(info.Data{1,2},'Classifier') && strcmp(info.Data{2,2},'File'));
assert(strcmp(info.Visible,'on'));
assert(strcmp(findall(viewer.widgetFigure('Projects'),'Tag','project-runs').Parent.Visible,'off'));
assert(isequal(baseNames,evalin('base','who')));
loaded = viewer.openPipeline(fullfile(template.path,'pipeline.json'));
assert(isa(loaded,'pipeline') && isequal(viewer.Pipeline.Template,loaded));
assert(isscalar(viewer.WorkspaceObjects) && isempty(viewer.Sessions));
assert(~any(strcmp({viewer.WorkspaceObjects.kind},'pipeline')));
assert(any(cellfun(@(p)isequal(p,loaded),viewer.Pipeline.Templates)));
tree = findall(viewer.widgetFigure('Projects'),'Tag','projects-tree');
assert(isempty(findall(tree,'Type','uitreenode','Text','Pipelines')));
viewer.refreshWorkspace();
assert(any(arrayfun(@(e)isequal(e.object,classifier),viewer.WorkspaceObjects)));
assert(any(cellfun(@(p)isequal(p,loaded),viewer.Pipeline.Templates)));
fresh = viewer.openClassifier(file);
assert(~isequal(fresh,classifier) && isscalar(viewer.WorkspaceObjects));
assert(isempty(viewer.openClassifier(fullfile(folder,'missing.mat'))));
assert(isscalar(viewer.WorkspaceObjects) && isequal(viewer.Pipeline.Template,loaded));
assert(isempty(viewer.openPipeline(fullfile(folder,'missing.json'))));
assert(isequal(viewer.Pipeline.Template,loaded));
assert(~viewer.ProjectProgress.Active && ~viewer.Pipeline.Progress.Active);
disp('File tools test passed: loaders, classifier browser, pipeline widget ownership and failure recovery.');
end
