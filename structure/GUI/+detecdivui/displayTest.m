function viewer = displayTest(previewPath,keepOpen)
%DISPLAYTEST Exercise the actual Display controls with a multi-layer ROI.
if nargin < 1, previewPath = ''; end
if nargin < 2, keepOpen = false; end
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
viewer = detecdiv_ui(project,'Visible','off','LayoutFile','','AutoSaveLayout',false,'RecentPipelinesFile','');
if ~keepOpen, cleanup = onCleanup(@()delete(viewer)); end
tree = findall(viewer.widgetFigure('Projects'),'Tag','projects-tree');
tree.SelectedNodes = findall(tree,'Tag','roi-node'); tree.SelectionChangedFcn(tree,[]);
figure = viewer.widgetFigure('Display');
table = findall(figure,'Tag','layers'); active = findall(figure,'Tag','channels');
assert(strcmp(active.Visible,'off')); % Selection is exposed by the table only.
minimum = findall(figure,'Tag','contrast-min'); opacity = findall(figure,'Tag','layer-opacity');
assert(strcmp(minimum.Parent.Visible,'off') && strcmp(opacity.Parent.Visible,'off'));
assert(strcmp(table.Parent.RowHeight{2},'1x'));
ax = findall(viewer.Figure,'Tag','image-view');
assert(numel(table.Data.layers) == 3 && all([viewer.DisplayModel.Layers.visible]));
histogram = findall(figure,'Tag','display-histogram');
assert(histogram.Data.stats.count == numel(phase));
assert(sum(histogram.Data.series.counts) == numel(phase));
assert(histogram.Data.stats.median == median(double(phase(:))));
before = pixels(ax);
tableEdit(table,'visible',3,false);
after = pixels(ax);
assert(any(before(:) ~= after(:)) && ~viewer.DisplayModel.Layers(3).visible);
assert(isequal(before(1,1,:),after(1,1,:))); % background stays transparent
tableEdit(table,'select',2,[]); assert(active.Value == 2);
assert(isequal([viewer.DisplayModel.Layers.visible],[true true false]));
solo = findall(figure,'Tag','solo-layer'); solo.ButtonPushedFcn(solo,[]);
color = findall(figure,'Tag','layer-color'); color.Value = '1 0 0'; color.ValueChangedFcn(color,[]);
picker = findall(figure,'Tag','layer-color-picker'); assert(isequal(picker.Value,[1 0 0]));
picker.Value = [0 0 1]; picker.ValueChangedFcn(picker,[]);
assert(strcmp(viewer.DisplayModel.Layers(2).color,'0 0 1'));
tableEdit(table,'color',2,[1 0 0]);
opacity = findall(figure,'Tag','layer-opacity'); opacity.Value = 0.25; opacity.ValueChangedFcn(opacity,[]);
rendered = pixels(ax);
assert(max(rendered(:,:,1),[],'all') <= 64 && ~any(rendered(:,:,2:3),'all'));
tableEdit(table,'select',1,[]); assert(active.Value == 1); solo.ButtonPushedFcn(solo,[]);
range = findall(figure,'Tag','contrast-range'); range.Value = [500 1800]; range.ValueChangedFcn(range,[]);
assert(isequal(viewer.DisplayModel.Layers(1).limits,[500 1800]));
frame = findall(viewer.Figure,'Tag','frame-number'); frame.Value = 2; frame.ValueChangedFcn(frame,[]);
assert(isequal(viewer.DisplayModel.Layers(1).limits,[500 1800]));
assert(histogram.Data.stats.median == median(double(phase(:)))+100);
stale = struct('revision',table.Data.revision,'action','visible','index',1,'value',false);
tableEdit(table,'opacity',1,.8); table.DataChangedFcn(table,struct('Data',stale));
assert(viewer.DisplayModel.Layers(1).visible); % stale asynchronous edits cannot cross refreshed state
histogramEdit(histogram,'limits',[450 1600]);
assert(isequal(viewer.DisplayModel.Layers(1).limits,[450 1600]));
histogramEdit(histogram,'limits',[500 1800]);
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
for index = 1:3, tableEdit(table,'visible',index,true); end
tableEdit(table,'select',3,true);
assert(strcmp(histogram.Data.kind,'Labels') && isempty(histogram.Data.series));
histogramEdit(histogram,'visible',true); assert(numel(histogram.Data.series) == 2);
active.Value = 2; active.ValueChangedFcn(active,[]);
color.Value = '0 1 0'; color.ValueChangedFcn(color,[]);
opacity.Value = 0.65; opacity.ValueChangedFcn(opacity,[]);
viewer.Host.resetLayout();
% Shared Score histogram handles signed, constant, RGB and nonfinite pixels.
data = score_histogramData([-3 0 2 NaN Inf]); assert(data.count == 3 && sum(data.counts) == 3 && data.median == 0);
data = score_histogramData(ones(4)); assert(sum(data.counts) == 16 && data.range(2) > data.range(1));
data = score_histogramData(cat(3,ones(2),2*ones(2),3*ones(2))); assert(abs(data.median-1.8149) < 1e-10);
data = score_histogramData([NaN Inf]); assert(data.count == 0 && isempty(data.edges));
if ~isempty(previewPath)
    viewer.Host.show(); viewer.Host.focusWidget('Display'); pause(0.5); drawnow;
    viewer.Host.capture(previewPath);
end
disp('Display test passed: controls, visibility, color, opacity, contrast, docking and unchanged source data.');
end

function tableEdit(table,action,index,value)
event = struct('revision',table.Data.revision,'action',action,'index',index,'value',value);
table.DataChangedFcn(table,struct('Data',event));
end
function histogramEdit(histogram,action,value)
event = struct('revision',histogram.Data.revision,'action',action,'value',value);
histogram.DataChangedFcn(histogram,struct('Data',event));
end

function data = pixels(ax)
item = findall(ax,'Type','image'); assert(isscalar(item)); data = item.CData;
end
