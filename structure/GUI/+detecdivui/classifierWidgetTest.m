function classifierWidgetTest(preview)
%CLASSIFIERWIDGETTEST Canonical classifier ROIs in the shared image workspace.
if nargin < 1, preview = ''; end
folder = tempname; mkdir(folder); files = onCleanup(@()rmdir(folder,'s'));
c = classi(folder,'cellpose',4);
c.trainingParam = struct('epochs',uint16(10),'useGPU',true,'mode',{{'fast','accurate','fast'}});
c.executionParam = struct('threshold',.5); c.classes = {'cell','background'};
c.category = {'Pixel'};
for k = 1:2
    r = roi(sprintf('Training cell %d',k),[1 1 12 16]);
    r.image = repmat(reshape(uint16(1:3)+100*k,1,1,1,3),16,12,1,1);
    r.channelid = 1; r.display.channel = {'Phase'}; c.roi(k) = r;
    r.path = c.path;
end
c.trainingset = 1; originalPixels = c.roi(1).image;
p = shallow(); p.io.file = 'Real project'; p.fov.id = 'Position';
v = detecdiv_ui(p,'Visible','off','LayoutFile','','AutoSaveLayout',false, ...
    'RecentProjectsFile','','RecentPipelinesFile','','RecentClassifiersFile','');
cleanup = onCleanup(@()delete(v));
legacy = v.Host.snapshot(); legacy.widgets = rmfield(legacy.widgets,'classifier');
for k = 1:numel(legacy.layout.documentLayout.tileOccupancy)
    tile = legacy.layout.documentLayout.tileOccupancy(k);
    tile.children(strcmp({tile.children.id},'workspace_classifier')) = [];
    if isfield(tile,'showingChildId') && strcmp(tile.showingChildId,'workspace_classifier')
        tile.showingChildId = '';
        if ~isempty(tile.children), tile.showingChildId = tile.children(1).id; end
    end
    legacy.layout.documentLayout.tileOccupancy(k) = tile;
end
layoutFile = fullfile(folder,'legacy-layout.json');
fid = fopen(layoutFile,'w'); fprintf(fid,'%s',jsonencode(legacy)); fclose(fid);
assert(v.Host.restoreLayout(layoutFile) && ~v.Host.isWidgetVisible('Classifier'));
v.Classifiers.add(c);
assert(~isempty(detecdivui.WorkspaceLayout.tile(v.Host.App.DocumentLayout,'workspace_classifier')));
assert(isequal(v.Session.Classifier,c) && v.Session.Zone == 1);
assert(isequal(v.Session.Project.fov(1).roi(1),c.roi(1)));
assert(isequal(v.Classifiers.Current,c));
projects = findall(v.widgetFigure('Projects'),'Tag','projects-tree');
assert(isscalar(projects.Children) && strcmp(projects.Children.Text,'Real project'));
assert(isempty(findall(projects,'Text','Classifiers')));
rois = findall(v.widgetFigure('Classifier'),'Tag','classifier-rois');
assert(strcmp(v.Classifiers.Mode,'Review') && ~any(rois.ColumnEditable));
rois.CellEditCallback(rois,struct('Indices',[2 3],'NewData','Training'));
assert(isequal(c.trainingset,1));
v.Classifiers.setMode('Edit');
assert(rois.ColumnEditable(3) && rois.ColumnEditable(4));
assert(size(rois.Data,1)==2 && strcmp(rois.Data{1,3},'Training') && strcmp(rois.Data{2,3},'Test'));
assert(isempty(findall(v.widgetFigure('Classifier'),'Tag','classifier-tree')));
assert(strcmp(rois.Data{1,4},'all') && ~strcmp(rois.Data{1,5},'Not checked'));
assert(contains(findall(v.Figure,'Tag','breadcrumb').Text,'Classifier: cellpose_4'));
assert(strcmp(v.Host.findCommand('Define ROIs...').Enable,'off'));
assert(strcmp(findall(v.Figure,'Tag','parent-fov').Enable,'off'));
ax = v.roiAxes(); image = findall(ax,'Type','image'); assert(all(image.CData(:) == 101));
rois.CellSelectionCallback(rois,struct('Indices',[2 1]));
assert(v.Session.Zone == 2 && all(findall(v.roiAxes(),'Type','image').CData(:) == 201));
tabs = findall(v.Figure,'Tag','image-tabs'); roi2 = tabs.SelectedTab;
rois.CellSelectionCallback(rois,struct('Indices',[1 1]));
tabs.SelectedTab = roi2; tabs.SelectionChangedFcn(tabs,[]);
assert(rois.Selection(1) == 2);
rois.CellEditCallback(rois,struct('Indices',[2 3],'NewData','Training'));
assert(isequal(c.trainingset,[1 2]) && isequal(c.dataset.split.train,[1 2]));
rois.CellEditCallback(rois,struct('Indices',[1 3],'NewData','Test'));
assert(isequal(c.trainingset,2) && isequal(c.dataset.split.test,1));
rois.CellEditCallback(rois,struct('Indices',[2 4],'NewData','1:2'));
assert(isequal(trainingBounds.resolve(c,2),[1 2]) && strcmp(rois.Data{2,4},'1:2'));
rois.CellEditCallback(rois,struct('Indices',[2 4],'NewData','1:99'));
assert(isequal(trainingBounds.resolve(c,2),[1 2]) && strcmp(rois.Data{2,4},'1:2'));
stale = rois.CellEditCallback;
scope = findall(v.widgetFigure('Classifier'),'Tag','classifier-parameter-scope');
scope.Value = 'Training Parameters'; scope.ValueChangedFcn(scope,[]);
editor = v.Classifiers.editParameters(); editor.Figure.Visible = 'off';
editor.Controls.epochs.Value = 20; editor.Controls.useGPU.Value = false;
editor.Controls.mode.Value = 'accurate';
assert(c.trainingParam.epochs == 10); % Staged until Apply.
assert(editor.apply());
assert(isa(c.trainingParam.epochs,'uint16') && c.trainingParam.epochs == 20 && ...
    ~c.trainingParam.useGPU && strcmp(c.trainingParam.mode{end},'accurate'));
editor = v.Classifiers.editParameters(); editor.Figure.Visible = 'off';
editor.Controls.epochs.Value = 30; c.trainingParam.epochs = uint16(25);
assert(~editor.apply() && c.trainingParam.epochs == 25); delete(editor);
floating = floatingCount();
v.Host.setDocked('Classifier',false); waitUntil(@()floatingCount()>floating);
v.Host.setDocked('Classifier',true); waitUntil(@()floatingCount()==floating);
v.Host.closeWidget('Classifier'); assert(~v.Host.isWidgetVisible('Classifier'));
v.Host.focusWidget('Classifier'); assert(v.Session.Zone == 2);
assert(v.Host.Widgets.classifier.Showing);
assert(isequal(c.roi(1).image,originalPixels));
if ~isempty(preview)
    layout = detecdivui.WorkspaceLayout.geometry(v.Host.App.DocumentLayout);
    if numel(layout.columnWeights)==3, layout.columnWeights = [.38 .46 .16]; v.Host.App.DocumentLayout = layout; end
    v.Host.capture(preview);
end
c.description = {'Pixel classifier','Segmentation',{'classifyCells'}};
scope.Value = 'Properties'; scope.ValueChangedFcn(scope,[]); % Nested legacy metadata stays readable.
v.Classifiers.save();
saved = load(fullfile(c.path,[c.strid '_classification.mat']),'classiObj');
assert(saved.classiObj.trainingParam.epochs == 25 && numel(saved.classiObj.roi) == 2);
assert(isequal(saved.classiObj.trainingset,2) && isequal(trainingBounds.resolve(saved.classiObj,2),[1 2]));
v.loadCurrentImage(); assert(isequal(c.roi(1).image,[]) && ~isempty(c.roi(2).image));
% Return to a real project without exposing the transient classifier adapter.
projects.SelectedNodes = projects.Children(1); projects.SelectionChangedFcn(projects,[]);
assert(isempty(v.Session.Classifier) && isequal(v.Session.Project,p));
other = classi(folder,'Second',5); v.Classifiers.add(other);
stale(rois,struct('Indices',[2 3],'NewData','Test'));
assert(isequal(c.trainingset,2) && isempty(other.trainingset));
fprintf('Classifier widget test passed: separate browser, canonical ROI handles, image tabs, typed/stale edits and docking.\n');
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
    assert(toc(started)<12,'Native docking did not settle.'); pause(.05); drawnow;
end
end
