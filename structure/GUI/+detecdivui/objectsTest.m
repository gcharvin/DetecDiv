function objectsTest(previewPath)
%OBJECTSTEST Family browsing and shared edits beside independent Display.
if nargin < 1, previewPath = ''; end
folder = tempname; mkdir(folder); cleanFolder = onCleanup(@()rmdir(folder,'s'));
[source,secondFamily,exact] = fixture(folder,'Objects');
[other,~,~] = fixture(folder,'Other');
pixels = source.image; metadata = source.display; baseline = source.cellModel;
otherPixels = other.image; otherModel = other.cellModel;
project = shallow(); project.io.file = 'Object families'; project.fov.id = 'Position';
project.fov.roi = [source other];
viewer = detecdiv_ui(project,'Visible','off','DiscoverWorkspace',false,'LayoutFile','', ...
    'AutoSaveLayout',false,'RecentProjectsFile','','RecentPipelinesFile','');
cleanup = onCleanup(@()closeViewer(viewer));
menus = timerfindall('Tag','DetecDivDockMenu'); if ~isempty(menus), stop(menus); end
tree = findall(viewer.widgetFigure('Projects'),'Tag','projects-tree'); choose(tree,1);
assert(isempty(viewer.Objects) && isempty(viewer.Masks));
viewer.openObjects(); widget = viewer.Objects;
assert(viewer.Host.isWidgetVisible('Objects') && viewer.Host.isWidgetVisible('Display'));
assert(isempty(findall(viewer.widgetFigure('Objects'),'Tag','objects-families')));
assert(isempty(widget.ObjectsRows) && isempty(widget.SelectedProvider)); % Phase has no family.
selectLayer('Prediction');
assert((isempty(viewer.Masks)||~viewer.Masks.Active) && ~isempty(widget.Rows));
assert(widget.SelectedFamily==0);
assert(strcmp(findall(viewer.widgetFigure('Annotations'),'Tag','objects-contours').Enable,'off'));
cancelled=viewer.createAnnotationLayers(); assert(~isempty(cancelled)); cancelled.close();
assert(isequal(source.image,pixels) && isequal(source.display,metadata) && isequal(source.cellModel,baseline));
separation=viewer.createAnnotationLayers(); assert(~isempty(separation));
resultLayer=separation.Draft.Plan.changes(1).layer;
assert(separation.apply()); delete(separation);
originalLayer=find(strcmp({viewer.DisplayModel.Layers.name},'Prediction'));
assert(~viewer.DisplayModel.Layers(originalLayer).visible);
pixels=source.image; metadata=source.display; baseline=source.cellModel;
row = find([widget.Rows.familyId] == secondFamily); widget.selectFamily(row);
assert(widget.SelectedFamily == secondFamily && strcmp(widget.SelectedProvider,resultLayer));
assert(numel(widget.ObjectsRows)==2 && widget.ObjectsRows(1).track==exact);
table = findall(viewer.widgetFigure('Objects'),'Tag','objects-table');
assert(strcmp(table.Data{1,2},char(string(exact))) && strcmp(table.Data{1,4},'Dividing'));
widget.selectObject(1); selection = viewer.selectedAnnotation();
assert(selection.label==1 && selection.family==secondFamily);
assert(~isempty(findall(viewer.roiAxes(),'Tag','mask-selection')));
layer = find(strcmp({viewer.DisplayModel.Layers.name},resultLayer));
assert(viewer.DisplayModel.Layers(layer).visible && strcmp(viewer.DisplayModel.Layers(layer).color,'Labels'));
draft = viewer.annotationDraft(resultLayer);
assert(viewer.Masks.current()==draft && ~draft.Dirty);
assert(isequal(source.image,pixels) && isequal(source.display,metadata) && isequal(source.cellModel,baseline));

% The separated tracking result remains selected when entering the track editor.
viewer.Host.findCommand('Edit Tracks...').invoke();
family = findall(viewer.widgetFigure('Objects'),'Tag','tracks-family'); assert(family.Value==double(secondFamily));
info = findall(viewer.widgetFigure('Objects'),'Tag','tracks-info');
assert(strcmp(info.UserData{2,2},char(string(exact))));
tabs = findall(viewer.widgetFigure('Objects'),'Tag','objects-tools');
browser = findall(tabs,'Tag','objects-browser-tab'); tabs.SelectedTab = browser;
detecdivui.Callback.call(tabs.SelectionChangedFcn,tabs,[]);
assert(viewer.Masks.Active && ~viewer.Tracks.Active && viewer.Masks.current()==draft);
selection = viewer.selectedAnnotation(); assert(selection.family==secondFamily && selection.label==1);
widget.action('tracks'); assert(viewer.Tracks.Active && viewer.Tracks.current()==draft);
family = findall(viewer.widgetFigure('Objects'),'Tag','tracks-family'); assert(family.Value==double(secondFamily));
info = findall(viewer.widgetFigure('Objects'),'Tag','tracks-info');
assert(strcmp(info.UserData{2,2},char(string(exact))));
widget.action('contours'); assert(viewer.Masks.Active && ~viewer.Tracks.Active && viewer.Masks.current()==draft);
draft.edit(1,'paint',[12 14],7,1,false); viewer.contourChanged();
assert(draft.Dirty && any([widget.ObjectsRows.label]==7));
assert(isequal(source.image,pixels) && isequal(source.cellModel,baseline));
widget.action('undo'); assert(~draft.Dirty && ~any([widget.ObjectsRows.label]==7));
widget.action('redo'); assert(draft.Dirty && any([widget.ObjectsRows.label]==7));
widget.action('save'); assert(~draft.Dirty && source.image(14,12,source.findChannelID(resultLayer),1)==7);
assert(isequal(source.image(:,:,1,:),pixels(:,:,1,:)));
assert(isequal(source.image(:,:,2,:),pixels(:,:,2,:)),'Editing the copied result modified the original masks.');
loaded = roi(source.id,source.value); loaded.path = folder; loaded.load('Data',false,'Silent');
assert(isequal(source.image,loaded.image));

viewer.navigateDataFrame(source,2);
assert(~any([widget.ObjectsRows.label]==7) && numel(widget.ObjectsRows)==2);
stale = table.CellSelectionCallback;
choose(tree,2); before = viewer.selectedAnnotation();
stale(table,struct('Indices',[1 1]));
assert(isequal(viewer.selectedAnnotation(),before) && isequal(other.image,otherPixels) && isequal(other.cellModel,otherModel));
choose(tree,1); selectLayer(resultLayer); viewer.openObjects();
viewer.Host.setDocked('Objects',false); viewer.Host.setDocked('Objects',true);
assert(viewer.Objects==widget && viewer.annotationDraft(resultLayer)==draft);
assert(viewer.Host.isWidgetVisible('Display'));
if ~isempty(previewPath)
    viewer.Host.show(); viewer.Host.focusWidget('Objects'); drawnow; pause(.3); viewer.Host.capture(previewPath);
end
% Native Close preserves an actual unsaved scientific draft, not only its
% document controls. Reopening must reconnect that same provider draft.
frame = viewer.annotationFrame(); baselinePixel = source.image(14,12,source.findChannelID(resultLayer),frame);
draft.edit(frame,'paint',[12 14],8,1,false); viewer.contourChanged();
assert(draft.Dirty);
viewer.Host.Widgets.objects.close(); started = tic;
while viewer.Host.isWidgetVisible('Objects')
    assert(toc(started)<12,'Objects did not close.'); pause(.05); drawnow;
end
assert(draft.Dirty && source.image(14,12,source.findChannelID(resultLayer),frame)==baselinePixel && ~viewer.Masks.Active);
viewer.openObjects();
assert(viewer.annotationDraft(resultLayer)==draft && draft.Dirty);
draft.discard(); viewer.contourChanged();
viewer.Host.setWidgetVisible('Objects',false);
assert(~viewer.Masks.Active && (isempty(viewer.Tracks) || ~viewer.Tracks.Active));
hiddenSelection = table.CellSelectionCallback;
hiddenSelection(table,struct('Indices',[1 1]));
assert(~viewer.Masks.Active && ~widget.resumeSelection(), ...
    'A hidden Objects document resumed image editing from a queued selection.');
assert(isequal(other.image,otherPixels) && isequal(other.cellModel,otherModel));
viewer.openObjects(); selectLayer('Alternative');
assert(strcmp(widget.SelectedProvider,'Alternative') && numel(widget.ObjectsRows)==1 && widget.ObjectsRows.label==5);
assert(strcmp(viewer.Masks.current().Channel,'Alternative'));
selectLayer('Phase');
assert(isempty(widget.ObjectsRows) && isempty(widget.SelectedProvider) && ~viewer.Masks.Active);
assert(strcmp(findall(viewer.widgetFigure('Objects'),'Tag','objects-family').Text,'—'));
disp('Objects test passed: family/provider distinction, multicolor editing defaults, exact track IDs, shared drafts/history/save, frame and selection updates, stale events, ROI isolation and independent Display docking.');
    function selectLayer(name)
        layers = findall(viewer.widgetFigure('Display'),'Tag','layers');
        index = find(strcmp({viewer.DisplayModel.Layers.name},name));
        event = struct('revision',layers.Data.revision,'action','select','index',index,'value',[]);
        layers.DataChangedFcn(layers,struct('Data',event));
        visible = struct('revision',layers.Data.revision,'action','visible','index',index,'value',true);
        layers.DataChangedFcn(layers,struct('Data',visible));
    end
end

function [r,family,exact] = fixture(folder,id)
r = roi(id,[1 1 24 22]); r.path = folder;
r.image = zeros(22,24,3,2,'uint16'); r.image(:,:,1,:) = 100;
r.image(3:7,3:7,2,:) = 1; r.image(12:17,16:21,2,:) = 2;
r.image(4:8,14:18,3,:) = 5;
r.channelid = [1 2 3]; r.display.channel = {'Phase','Prediction','Alternative'};
r.display.indexed = [false true true]; r.display.intensity = [1 1 1;0 0 0;0 0 0];
r.display.rgb = [1 1 1;0 1 0;1 0 0]; r.display.selectedchannel = [true false false];
[model,report] = cellModel.fromLegacy(r,'Channels',{'Prediction','Alternative'}); assert(report.validation.ok);
[model,family,report] = cellModel.cloneFamily(model,1,'Reviewed cells','Prediction'); assert(report.validation.ok);
exact = uint64(9007199254740992)+uint64(1);
rows = model.instances.family_id==family;
model.instances.track_id(rows) = exact+uint64(model.instances.mask_label(rows)-1);
model.states.state_id = uint16(5); model.states.name = {'Dividing'}; model.states.color_rgb = uint8([255 190 0]);
model.instances.state_id(rows) = uint16(5);
model = cellModel.normalize(model); cellModel.validate(model,'Throw',true);
r.save([],false); r.load('Silent'); r.saveCellModel(model);
end

function choose(tree,index)
nodes = findall(tree,'Tag','roi-node'); node = nodes(arrayfun(@(n)n.UserData.roi==index,nodes));
tree.SelectedNodes = node; tree.SelectionChangedFcn(tree,[]);
end

function closeViewer(viewer)
if ~isvalid(viewer), return; end
if ~isempty(viewer.Masks) && isvalid(viewer.Masks)
    for k = 1:numel(viewer.Masks.Drafts)
        if viewer.Masks.Drafts{k}.Dirty && ~viewer.Masks.Drafts{k}.SaveFailed, viewer.Masks.Drafts{k}.discard(); end
    end
end
delete(viewer);
end
