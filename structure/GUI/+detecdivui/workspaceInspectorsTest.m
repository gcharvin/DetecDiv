function workspaceInspectorsTest(previewPath)
%WORKSPACEINSPECTORSTEST Display, objects and Score curves share one ROI/frame.
if nargin < 1, previewPath = ''; end
folder = tempname; mkdir(folder); clean = onCleanup(@()rmdir(folder,'s'));
r = roi('Cells',[1 1 64 64]); r.path = folder;
[x,y] = meshgrid(1:64); labels = uint16(((x-21).^2+(y-23).^2<70) + 2*((x-43).^2+(y-43).^2<90));
r.image = zeros(64,64,2,3,'uint16');
for k = 1:3
    r.image(:,:,1,k) = uint16(1100+9*x+5*y+150*sin(x/10+k/8));
    r.image(:,:,2,k) = labels;
end
r.channelid = [1 2]; r.display.channel = {'Phase','Cells'};
r.display.indexed = [false true]; r.display.rgb = [1 1 1;0 1 0];
r.display.selectedchannel = [true false];
r.data = dataseries(table([18;23;27],[100;145;130],'VariableNames',{'MeanArea','Signal'}),{},'groupid','Measurements');
[model,report] = cellModel.fromLegacy(r,'Channels',{'Cells'}); assert(report.validation.ok);
r.save([],false); r.load('Silent'); r.saveCellModel(model);
r.data = dataseries(table([18;23;27],[100;145;130],'VariableNames',{'MeanArea','Signal'}),{},'groupid','Measurements');
pixels = r.image; before = r.cellModel; data = r.data.data;
p = shallow(); p.io.file = 'Analysis workspace'; p.fov.id = 'Position'; p.fov.interval = 5; p.fov.roi = r;
v = detecdiv_ui(p,'Visible','off','DiscoverWorkspace',false,'LayoutFile','', ...
    'AutoSaveLayout',false,'RecentProjectsFile','','RecentPipelinesFile','');
cleanup = onCleanup(@()delete(v));
menus = timerfindall('Tag','DetecDivDockMenu'); if ~isempty(menus), stop(menus); end
tree = findall(v.widgetFigure('Projects'),'Tag','projects-tree');
tree.SelectedNodes = findall(tree,'Tag','roi-node'); tree.SelectionChangedFcn(tree,[]);
v.openObjects(); v.openData();
assert(v.Host.isWidgetVisible('Display') && v.Host.isWidgetVisible('Objects') && v.Host.isWidgetVisible('Data'));
assert(v.Host.Widgets.display.Showing && v.Host.Widgets.objects.Showing && v.Host.Widgets.data.Showing);
assert(v.Masks.Active && numel(v.Objects.ObjectsRows)==2 && isscalar(v.Data.Series));
layers = findall(v.widgetFigure('Display'),'Tag','layers');
assert(v.DisplayModel.Layers(2).visible && ~isempty(layers));
histogram = findall(v.widgetFigure('Display'),'Tag','display-histogram');
toggle = findall(v.widgetFigure('Display'),'Tag','display-histogram-toggle');
assert(strcmp(histogram.Visible,'off') && ~toggle.Value);
toggle.Value = true; detecdivui.Callback.call(toggle.ValueChangedFcn,toggle,[]);
assert(strcmp(histogram.Visible,'on'));
toggle.Value = false; detecdivui.Callback.call(toggle.ValueChangedFcn,toggle,[]);
v.Data.navigate(2);
marker = findall(v.Data.Axes,'Tag','data-frame-marker');
assert(v.annotationFrame()==2 && marker.Value==2);
assert(isequal(r.image,pixels) && isequaln(r.cellModel,before) && isequaln(r.data.data,data));
if ~isempty(previewPath)
    layout = detecdivui.WorkspaceLayout.geometry(v.Host.App.DocumentLayout);
    layout.columnWeights = [.18 .55 .27]; v.Host.App.DocumentLayout = layout;
    v.Host.focusWidget('Image'); drawnow; pause(.4); v.Host.capture(previewPath);
end
disp('Workspace inspectors test passed: parallel Display/Objects, dataseries below Image, shared frame navigation and immutable scientific data.');
end
