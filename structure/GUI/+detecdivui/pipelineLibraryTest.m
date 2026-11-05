function pipelineLibraryTest(previewPath)
%PIPELINELIBRARYTEST Open and recent pipelines belong to Pipeline, not Projects.
if nargin < 1, previewPath = ''; end
folder = tempname; mkdir(folder); cleanFolder = onCleanup(@()rmdir(folder,'s'));
recentFile = fullfile(folder,'recentPipelines.mat');
firstSource = makeSource('A'); secondSource = makeSource('B');
firstFile = fullfile(firstSource.path,'pipeline.json'); secondFile = fullfile(secondSource.path,'pipeline.json');
firstBytes = readBytes(firstFile); secondBytes = readBytes(secondFile);
project = shallow(); project.io.file = 'Pipeline library project';
project.fov.id = 'Position'; project.fov.srcpath = {'Z:\unavailable-source'};
project.fov.roi = roi('Existing',[1 1 3 3]); project.fov.roi.image = uint16(ones(3));
originalROI = project.fov.roi;
v = launch(project,false); cleanViewer = onCleanup(@()deleteIfValid(v));
w = v.Pipeline;
assert(isempty(w.Templates) && isempty(w.RecentPipelines.Paths));
first = v.openPipeline(firstFile);
assert(isa(first,'pipeline') && w.Template == first);
assert(isscalar(w.RecentPipelines.Paths) && samePath(w.RecentPipelines.Paths(1),firstFile));
assertNoProjectPipelines(v);
settings = w.Setup.values(); settings.runId = 'Retained run draft'; settings.frames = '1:2';
w.Draft.configure(settings); w.Draft.set('grid','referenceFrame',2); w.refresh();
first.nodes(1).name = 'Unsaved module label';
savedSettings = w.Draft.Settings; savedOverrides = w.Draft.Overrides;

second = v.openPipeline(secondFile);
assert(isa(second,'pipeline') && first ~= second && strcmp(first.strid,second.strid));
assert(numel(w.Templates) == 2 && numel(w.RecentPipelines.Paths) == 2);
assert(samePath(w.RecentPipelines.Paths(1),secondFile));
w.showLibrary(); tree = libraryTree(v); opened = libraryNodes(tree,'open');
assert(numel(opened) == 2,'Pipelines with equal names but different folders were merged.');
selectOpen(v,first);
assert(w.Template == first && isequaln(w.Draft.Settings,savedSettings) && isequaln(w.Draft.Overrides,savedOverrides));
assert(strcmp(w.Template.nodes(1).name,'Unsaved module label'));
w.openRecent(firstFile);
assert(w.Template == first && numel(w.Templates) == 2);
assert(isequaln(w.Draft.Settings,savedSettings) && isequaln(w.Draft.Overrides,savedOverrides));
assert(samePath(w.RecentPipelines.Paths(1),firstFile));
assertNoProjectPipelines(v);

% An unavailable recent entry stays in history and cannot replace the live
% definition or its pending configuration when an explicit open fails.
missing = fullfile(folder,'not-mounted','pipeline.json');
w.RecentPipelines.remember(missing); savedPaths = w.RecentPipelines.Paths;
w.openRecent(missing);
assert(w.Template == first && isequal(w.RecentPipelines.Paths,savedPaths));
assert(isequaln(w.Draft.Settings,savedSettings) && isequaln(w.Draft.Overrides,savedOverrides));
assert(isequal(readBytes(firstFile),firstBytes) && isequal(readBytes(secondFile),secondBytes));

% A fresh viewer reads history without opening templates or probing sources.
again = launch(project,false); cleanAgain = onCleanup(@()deleteIfValid(again));
assert(isempty(again.Pipeline.Templates) && isempty(again.Pipeline.Template));
assert(isequal(again.Pipeline.RecentPipelines.Paths,savedPaths));
again.Pipeline.showLibrary(); tree = libraryTree(again);
assert(isempty(libraryNodes(tree,'open')) && numel(libraryNodes(tree,'recent')) == 3);
selectRecent(again,firstFile);
reopened = again.Pipeline.Template;
assert(isa(reopened,'pipeline') && reopened ~= first);
assert(strcmp(reopened.nodes(1).name,firstSource.nodes(1).name));
assert(isempty(again.Pipeline.Draft.Overrides));
assertNoProjectPipelines(again);
opened = libraryNodes(libraryTree(again),'open');
assert(isscalar(opened) && samePath(opened.UserData.path,firstFile), ...
    'Selecting a recent pipeline did not add it to Open.');
recent = libraryNodes(libraryTree(again),'recent');
assert(~any(arrayfun(@(n)samePath(n.UserData.path,firstFile),recent)), ...
    'An opened file is duplicated in Recent.');

% Saving a new independent definition makes it available in the same recent
% store; no project/ROI data or run is created by these file operations.
fresh = again.Pipeline.newTemplate('Saved from widget'); fresh.nodes = firstSource.nodes;
again.Pipeline.saveTemplate(folder); savedFile = fullfile(fresh.path,'pipeline.json');
assert(isfile(savedFile) && samePath(again.Pipeline.RecentPipelines.Paths(1),savedFile));
assertNoProjectPipelines(again);

% Workspace discovery contributes live handles only to the opened list. It
% must not manufacture recent-file records or write the persistent history.
workspace = pipeline(); workspace.strid = 'Workspace only'; workspace.path = fullfile(folder,'missing-workspace-folder');
workspace.nodes = firstSource.nodes; workspaceNodes = workspace.nodes;
variable = matlab.lang.makeUniqueStrings('ddUiLibraryPipeline',evalin('base','who'),namelengthmax);
assignin('base',variable,workspace); cleanPublished = onCleanup(@()evalin('base',['clear ' variable]));
beforeHistory = readBytes(recentFile);
discovered = launch([],true); cleanDiscovered = onCleanup(@()deleteIfValid(discovered));
assert(any(cellfun(@(p)isequal(p,workspace),discovered.Pipeline.Templates)));
assert(~any(strcmp({discovered.WorkspaceObjects.kind},'pipeline')));
assert(isequal(readBytes(recentFile),beforeHistory));
assert(isequaln(workspace.nodes,workspaceNodes));
assertNoProjectPipelines(discovered);
assert(isequal(project.fov.roi,originalROI) && isequal(project.fov.roi.image,uint16(ones(3))));
assert(isempty(project.processing.pipelineRun) && isempty(dir(fullfile(folder,'**','*.h5'))));
assert(isequal(readBytes(firstFile),firstBytes) && isequal(readBytes(secondFile),secondBytes));
if ~isempty(previewPath)
    again.Pipeline.showLibrary(); again.Host.show(); again.Host.focusWidget('Pipeline'); drawnow; pause(.3);
    again.Host.capture(previewPath);
end
disp('Pipeline library test passed: separate opened/recent lists, source identity, live draft reuse, persistent reopen, missing-file recovery, workspace discovery and unchanged project/source data.');

    function template = makeSource(name)
        parent = fullfile(folder,name); mkdir(parent);
        template = pipelineConstruct(parent,'Shared name',1);
        template.nodes = struct('id','grid','name',['Grid ' name],'type','roiGrid','pkg','roiGrid', ...
            'func','roiGrid.process','enabled',true,'params',roiGrid.setparam());
        pipelineSave(template,'Artifacts',false);
    end
    function viewer = launch(target,discover)
        % Native menu polling is irrelevant to direct library callbacks and
        % can reenter CEF while several hidden test viewers are constructed.
        menuTimers = timerfindall('Tag','DetecDivDockMenu');
        if ~isempty(menuTimers), stop(menuTimers); end
        viewer = detecdiv_ui(target,'Visible','off','DiscoverWorkspace',discover,'LayoutFile','', ...
            'AutoSaveLayout',false,'RecentProjectsFile','','RecentPipelinesFile',recentFile);
        menuTimers = timerfindall('Tag','DetecDivDockMenu');
        if ~isempty(menuTimers), stop(menuTimers); end
    end
end

function tree = libraryTree(viewer)
tree = findall(viewer.widgetFigure('Pipeline'),'Tag','pipeline-library');
assert(isscalar(tree),'The Pipeline library is unavailable.');
end

function nodes = libraryNodes(tree,kind)
all = findall(tree,'Type','uitreenode'); keep = false(size(all));
for k = 1:numel(all)
    data = all(k).UserData;
    keep(k) = isstruct(data) && isfield(data,'kind') && strcmp(data.kind,kind);
end
nodes = all(keep);
end

function selectOpen(viewer,template)
tree = libraryTree(viewer); nodes = libraryNodes(tree,'open'); selected = [];
for k = 1:numel(nodes)
    if isequal(nodes(k).UserData.template,template), selected = nodes(k); break; end
end
selectNode(tree,selected);
end

function selectRecent(viewer,path)
tree = libraryTree(viewer); nodes = libraryNodes(tree,'recent'); selected = [];
for k = 1:numel(nodes)
    if samePath(nodes(k).UserData.path,path), selected = nodes(k); break; end
end
selectNode(tree,selected);
end

function selectNode(tree,node)
assert(~isempty(node),'The pipeline library entry is missing.');
tree.SelectedNodes = node;
if ~isempty(tree.SelectionChangedFcn)
    detecdivui.Callback.call(tree.SelectionChangedFcn,tree,struct('SelectedNodes',node));
end
end

function assertNoProjectPipelines(viewer)
assert(~any(strcmp({viewer.WorkspaceObjects.kind},'pipeline')));
tree = findall(viewer.widgetFigure('Projects'),'Tag','projects-tree');
assert(isempty(findall(tree,'Type','uitreenode','Text','Pipelines')));
end

function yes = samePath(a,b)
yes = detecdivui.RecentPipelines.samePath(a,b);
end

function bytes = readBytes(file)
fid = fopen(file,'rb'); assert(fid >= 0,'Cannot read fixture file.'); clean = onCleanup(@()fclose(fid));
bytes = fread(fid,Inf,'*uint8');
end

function deleteIfValid(object)
if ~isempty(object) && isvalid(object), delete(object); end
end
