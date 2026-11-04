function fileToolsTest()
%FILETOOLSTEST File-loaded classifiers/pipelines remain independent browser tools.
folder = tempname; mkdir(folder); cleanup = onCleanup(@()rmdir(folder,'s'));
classiObj = classi(); classiObj.strid = 'Test classifier'; classiObj.path = folder;
file = fullfile(folder,'test_classification.mat'); save(file,'classiObj');
template = pipelineConstruct(folder,'Test pipeline',1); pipelineSave(template);
viewer = detecdiv_ui([],'Visible','off','LayoutFile','','AutoSaveLayout',false);
closeViewer = onCleanup(@()delete(viewer));
baseNames = evalin('base','who');
assert(~isempty(viewer.Host.findCommand('Open Classifier...')));
assert(~isempty(viewer.Host.findCommand('Open Pipeline...')));
classifier = viewer.openClassifier(file); assert(isa(classifier,'classi'));
assert(isempty(viewer.Sessions) && isscalar(viewer.WorkspaceObjects));
info = findall(viewer.widgetFigure('Projects'),'Tag','project-information');
assert(strcmp(info.Data{1,2},'Classifier') && strcmp(info.Data{2,2},'File'));
assert(isequal(baseNames,evalin('base','who')));
loaded = viewer.openPipeline(fullfile(template.path,'pipeline.json'));
assert(isa(loaded,'pipeline') && isequal(viewer.Pipeline.Template,loaded));
assert(numel(viewer.WorkspaceObjects) == 2 && isempty(viewer.Sessions));
viewer.refreshWorkspace();
assert(any(arrayfun(@(e)isequal(e.object,classifier),viewer.WorkspaceObjects)));
assert(any(arrayfun(@(e)isequal(e.object,loaded),viewer.WorkspaceObjects)));
fresh = viewer.openClassifier(file);
assert(~isequal(fresh,classifier) && numel(viewer.WorkspaceObjects) == 2);
assert(isempty(viewer.openClassifier(fullfile(folder,'missing.mat'))));
assert(numel(viewer.WorkspaceObjects) == 2 && isequal(viewer.Pipeline.Template,loaded));
assert(isempty(viewer.openPipeline(fullfile(folder,'missing.json'))));
assert(isequal(viewer.Pipeline.Template,loaded));
assert(~viewer.ProjectProgress.Active && ~viewer.Pipeline.Progress.Active);
disp('File tools test passed: loaders, browser persistence, independent objects and failure recovery.');
end
