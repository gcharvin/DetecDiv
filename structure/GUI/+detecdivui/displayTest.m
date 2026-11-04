function displayTest(previewPath)
%DISPLAYTEST Exercise the actual Display controls with a multi-layer ROI.
if nargin < 1, previewPath = ''; end
[y,x] = ndgrid(1:120,1:160);
a = exp(-((x-52).^2/100+(y-48).^2/180));
b = exp(-((x-110).^2/100+(y-78).^2/180));
phase = uint16(300+1800*(a+b)); green = uint16(4000*b);
labels = uint16(a > 0.2) + 2*uint16(b > 0.2);
project = shallow(); project.io.file = 'Layer preview'; project.fov.id = 'FOV A';
project.fov.roi = roi('Cells',[1 1 160 120]); source = project.fov.roi;
source.image = cat(3,phase,green,labels);
source.image(:,:,:,2) = cat(3,phase+100,green+200,labels);
source.channelid = [1 2 3]; source.display.channel = {'Phase','GFP','Cells'};
source.display.rgb = [1 1 1;0 1 0;1 1 1];
source.display.indexed = [false false true];
source.display.selectedchannel = [true true true]; source.display.alpha = [1 1 0.4];
originalPixels = source.image; originalDisplay = source.display;
viewer = detecdiv_ui(project,'Visible','off','LayoutFile','','AutoSaveLayout',false);
cleanup = onCleanup(@()delete(viewer));
tree = findall(viewer.widgetFigure('Projects'),'Tag','projects-tree');
tree.SelectedNodes = findall(tree,'Tag','roi-node'); tree.SelectionChangedFcn(tree,[]);
figure = viewer.widgetFigure('Display');
table = findall(figure,'Tag','layers'); active = findall(figure,'Tag','channels');
ax = findall(viewer.Figure,'Tag','image-view');
assert(size(table.Data,1) == 3 && all([viewer.DisplayModel.Layers.visible]));
before = pixels(ax);
table.CellEditCallback(table,struct('Indices',[3 1],'NewData',false));
after = pixels(ax);
assert(any(before(:) ~= after(:)) && ~viewer.DisplayModel.Layers(3).visible);
assert(isequal(before(1,1,:),after(1,1,:))); % background stays transparent
active.Value = 2; active.ValueChangedFcn(active,[]);
assert(isequal([viewer.DisplayModel.Layers.visible],[true true false]));
solo = findall(figure,'Tag','solo-layer'); solo.ButtonPushedFcn(solo,[]);
color = findall(figure,'Tag','layer-color'); color.Value = '1 0 0'; color.ValueChangedFcn(color,[]);
opacity = findall(figure,'Tag','layer-opacity'); opacity.Value = 0.25; opacity.ValueChangedFcn(opacity,[]);
rendered = pixels(ax);
assert(max(rendered(:,:,1),[],'all') <= 64 && ~any(rendered(:,:,2:3),'all'));
active.Value = 1; active.ValueChangedFcn(active,[]); solo.ButtonPushedFcn(solo,[]);
range = findall(figure,'Tag','contrast-range'); range.Value = [500 1800]; range.ValueChangedFcn(range,[]);
assert(isequal(viewer.DisplayModel.Layers(1).limits,[500 1800]));
frame = findall(viewer.Figure,'Tag','frame-number'); frame.Value = 2; frame.ValueChangedFcn(frame,[]);
assert(isequal(viewer.DisplayModel.Layers(1).limits,[500 1800]));
minimum = findall(figure,'Tag','contrast-min'); minimum.Value = 2000; minimum.ValueChangedFcn(minimum,[]);
assert(isequal(viewer.DisplayModel.Layers(1).limits,[500 1800]) && minimum.Value == 500);
auto = findall(figure,'Tag','auto-contrast'); auto.ButtonPushedFcn(auto,[]);
assert(isequal(viewer.DisplayModel.Layers(1).limits, ...
    double([min(phase(:))+100 max(phase(:))+100])));
viewer.Host.setDocked('Display',false);
opacity.Value = 0.8; opacity.ValueChangedFcn(opacity,[]);
assert(viewer.DisplayModel.Layers(1).opacity == 0.8);
viewer.Host.setDocked('Display',true);
assert(isequal(opacity,findall(viewer.widgetFigure('Display'),'Tag','layer-opacity')));
assert(isequal(source.image,originalPixels) && isequal(source.display,originalDisplay));
% Restore a useful composite for visual inspection.
for index = 1:3, table.CellEditCallback(table,struct('Indices',[index 1],'NewData',true)); end
active.Value = 2; active.ValueChangedFcn(active,[]);
color.Value = '0 1 0'; color.ValueChangedFcn(color,[]);
opacity.Value = 0.65; opacity.ValueChangedFcn(opacity,[]);
viewer.Host.resetLayout();
if ~isempty(previewPath)
    viewer.Host.show(); pause(0.5); drawnow;
    viewer.Host.capture(previewPath);
end
disp('Display test passed: controls, visibility, color, opacity, contrast, docking and unchanged source data.');
end

function data = pixels(ax)
item = findall(ax,'Type','image'); assert(isscalar(item)); data = item.CData;
end
