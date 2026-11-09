function fileToolsTest()
%FILETOOLSTEST File tools keep pipelines in their own widget and preserve objects.
folder = tempname; mkdir(folder); cleanup = onCleanup(@()rmdir(folder,'s'));
classiObj = classi(); classiObj.strid = 'Test classifier'; classiObj.path = folder;
file = fullfile(folder,'test_classification.mat'); save(file,'classiObj');
template = pipelineConstruct(folder,'Test pipeline',1); pipelineSave(template);
viewer = detecdiv_ui([],'Visible','off','LayoutFile','','AutoSaveLayout',false, ...
    'RecentProjectsFile','','RecentPipelinesFile','','RecentClassifiersFile','');
closeViewer = onCleanup(@()delete(viewer));
baseNames = evalin('base','who');
assert(~isempty(viewer.Host.findCommand('Open Classifier...')));
assert(~isempty(viewer.Host.findCommand('Open Pipeline...')));
classifier = viewer.openClassifier(file); assert(isa(classifier,'classi'));
assert(isscalar(viewer.Sessions) && isscalar(viewer.Classifiers.Classifiers));
info = findall(viewer.widgetFigure('Projects'),'Tag','project-information');
assert(isempty(info.Data) && strcmp(info.Visible,'off'));
assert(strcmp(findall(viewer.widgetFigure('Classifier'),'Tag','classifier-path').Value{1},classifier.path));
assert(isequal(baseNames,evalin('base','who')));
loaded = viewer.openPipeline(fullfile(template.path,'pipeline.json'));
assert(isa(loaded,'pipeline') && isequal(viewer.Pipeline.Template,loaded));
assert(isempty(viewer.WorkspaceObjects) && isscalar(viewer.Sessions));
assert(~any(strcmp({viewer.WorkspaceObjects.kind},'pipeline')));
assert(any(cellfun(@(p)isequal(p,loaded),viewer.Pipeline.Templates)));
tree = findall(viewer.widgetFigure('Projects'),'Tag','projects-tree');
assert(isempty(findall(tree,'Type','uitreenode','Text','Pipelines')));
viewer.refreshWorkspace();
assert(any(cellfun(@(c)isequal(c,classifier),viewer.Classifiers.Classifiers)));
assert(any(cellfun(@(p)isequal(p,loaded),viewer.Pipeline.Templates)));
fresh = viewer.openClassifier(file);
assert(~isequal(fresh,classifier) && numel(viewer.Classifiers.Classifiers) == 2);
assert(isempty(viewer.openClassifier(fullfile(folder,'missing.mat'))));
assert(numel(viewer.Classifiers.Classifiers) == 2 && isequal(viewer.Pipeline.Template,loaded));
assert(isempty(viewer.openPipeline(fullfile(folder,'missing.json'))));
assert(isequal(viewer.Pipeline.Template,loaded));
assert(~viewer.ProjectProgress.Active && ~viewer.Pipeline.Progress.Active);
disp('File tools test passed: loaders, classifier browser, pipeline widget ownership and failure recovery.');
end
