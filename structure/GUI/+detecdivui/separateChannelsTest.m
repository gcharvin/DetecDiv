function separateChannelsTest(previewPath)
%SEPARATECHANNELSTEST Score-style channel tiles, shared masks and one timeline.
if nargin < 1, previewPath = ''; end
folder = tempname; mkdir(folder); removeFolder = onCleanup(@()rmdir(folder,'s'));
phase = uint16(repmat(100:100:1000,10,1)); green = uint16(400*ones(10));
mask = zeros(10,'uint16'); mask(4:7,4:7) = 1;
rgb = cat(3,uint16(5000*ones(10)),uint16(12000*ones(10)),uint16(20000*ones(10)));
project = shallow(); project.io.file = 'Separate channels'; project.fov.id = 'Position';
project.fov.channel = {'Phase','GFP'}; project.fov.frames = 2;
for frame = 1:2
    imwrite(phase+uint16(100*(frame-1)),fullfile(folder,sprintf('phase%d.tif',frame)));
    imwrite(green+uint16(200*(frame-1)),fullfile(folder,sprintf('green%d.tif',frame)));
end
project.fov.srcpath = {folder,folder};
project.fov.srclist = {dir(fullfile(folder,'phase*.tif')),dir(fullfile(folder,'green*.tif'))};
project.fov.roi = roi('Cells',[1 1 10 10]); source = project.fov.roi;
source.image = cat(3,phase,green,rgb(:,:,1),mask,rgb(:,:,2:3));
source.image(:,:,:,2) = cat(3,phase+100,green+200,rgb(:,:,1),mask,rgb(:,:,2:3));
source.channelid = [1 2 3 4 3 3];
source.display.channel = {'Phase','GFP','RGB','Cells'};
source.display.rgb = [1 1 1;0 1 0;1 1 1;1 0 0]; source.display.indexed = [false false false true];
source.display.selectedchannel = [true true false true]; source.display.alpha = [1 1 1 .5];
source.display.contour = [false false false true]; source.display.width = [1 1 1 1.5];
original = source.image; metadata = source.display;
viewer = detecdiv_ui(project,'Visible','off','LayoutFile','','AutoSaveLayout',false,'RecentProjectsFile','','RecentPipelinesFile','');
cleanup = onCleanup(@()delete(viewer));
figure = viewer.widgetFigure('Display'); layout = findall(figure,'Tag','display-overlay');
assert(layout.Value && strcmp(layout.Enable,'off'));
layout.Value = false; layout.ValueChangedFcn(layout,[]);
assert(isempty(findall(viewer.Figure,'Type','image')));
tree = findall(viewer.widgetFigure('Projects'),'Tag','projects-tree');
roiNode = findall(tree,'Tag','roi-node'); tree.SelectedNodes = roiNode; tree.SelectionChangedFcn(tree,[]);
viewer.DisplayModel.setLimits(1,[0 1000]); viewer.DisplayModel.setLimits(2,[0 2000]);
viewer.DisplayModel.setColor(4,'1 0 0');
assert(strcmp(layout.Enable,'on') && ~layout.Value);
layout.ValueChangedFcn(layout,[]);
axes = panels(viewer); assert(numel(axes) == 2);
assert(strcmp(axes(1).Title.String,'Phase') && strcmp(axes(2).Title.String,'GFP'));
assert(isscalar(findall(axes(1),'Tag','mask-contour')) && isscalar(findall(axes(2),'Tag','mask-contour')));
first = pixels(axes(1)); second = pixels(axes(2));
assert(isequal(reshape(first(1,1,:),1,3),uint8([26 26 26])));
assert(isequal(reshape(second(1,1,:),1,3),uint8([0 51 0])));
assert(first(5,5,1) > first(5,5,2) && second(5,5,1) > second(5,5,2), ...
    'Mask pixels: first %s; second %s',mat2str(reshape(first(5,5,:),1,3)),mat2str(reshape(second(5,5,:),1,3)));
% A panel click selects that channel; spatial limits and time remain shared.
image = findall(axes(2),'Type','image'); detecdivui.Callback.call(image.ButtonDownFcn,image,[]);
active = findall(figure,'Tag','channels'); assert(active.Value == 2 && viewer.roiAxes().UserData.layer == 2);
axes = panels(viewer); axes(2).XLim = [2 8]; axes(2).YLim = [3 9]; drawnow;
assert(isequal(axes(1).XLim,[2 8]) && isequal(axes(1).YLim,[3 9]));
frame = findall(viewer.Figure,'Tag','frame-number'); frame.Value = 2; frame.ValueChangedFcn(frame,[]);
axes = panels(viewer); assert(isequal(axes(1).XLim,[2 8]));
first = pixels(axes(1)); assert(first(1,1,1) == 51);
% Overlay round-trip preserves visibility, channel levels and the current zoom.
visibility = [viewer.DisplayModel.Layers.visible];
layout.Value = true; layout.ValueChangedFcn(layout,[]); assert(isscalar(panels(viewer)));
assert(isequal(viewer.roiAxes().XLim,[2 8]));
layout.Value = false; layout.ValueChangedFcn(layout,[]);
assert(numel(panels(viewer)) == 2 && isequal([viewer.DisplayModel.Layers.visible],visibility));
assert(isequal(viewer.DisplayModel.Layers(2).limits,[0 2000]));
if ~isempty(previewPath)
    viewer.Host.show(); viewer.Host.focusWidget('Display'); viewer.Host.findCommand('Fit Image').invoke();
    drawnow; viewer.Host.capture(previewPath);
end
% Masks do not create an extra tile; mask-only/empty states clear old tiles.
setVisible(viewer,2,false); assert(isscalar(panels(viewer)));
setVisible(viewer,1,false); assert(isscalar(panels(viewer)) && strcmp(viewer.roiAxes().Title.String,'Masks'));
setVisible(viewer,4,false); assert(~any(pixels(viewer.roiAxes()),'all'));
setVisible(viewer,3,true); setVisible(viewer,4,true);
assert(isscalar(panels(viewer)) && viewer.roiAxes().UserData.layer == 3);
% The raw ROI assistant uses the clicked panel's source channel/provenance.
viewer.Host.findCommand('Parent FOV').invoke(); setVisible(viewer,1,true); setVisible(viewer,2,true);
% FOV tabs retain their own presentation and frame, independently of ROIs.
layout.Value = false; layout.ValueChangedFcn(layout,[]);
frame.Value = 2; frame.ValueChangedFcn(frame,[]);
axes = panels(viewer); image = findall(axes(2),'Type','image');
detecdivui.Callback.call(image.ButtonDownFcn,image,[]);
viewer.openROITool(); mode = findall(figure,'Tag','roi-mode'); mode.Value = 'roiPattern'; mode.ValueChangedFcn(mode,[]);
viewer.ROIs.setPattern([2 2 4 4]);
assert(viewer.ROIs.Params.pattern.channelIndex == 2 && all(viewer.ROIs.Params.pattern.image == 600,'all'));
assert(viewer.roiAxes().UserData.layer == 2);
% A rendering error clears every previous panel, not only the active one.
tree.SelectedNodes = roiNode; tree.SelectionChangedFcn(tree,[]);
setVisible(viewer,1,true); setVisible(viewer,2,true); setVisible(viewer,3,false);
assert(numel(panels(viewer)) == 2);
source.image = double(original); source.image(1,1,4,2) = NaN;
viewer.loadCurrentImage(); assert(isempty(findall(viewer.Figure,'Type','image')));
assert(isscalar(panels(viewer))); source.image = original;
assert(isequal(source.image,original) && isequal(source.display,metadata));
disp('Separate channels test passed: channel tiles, shared masks/contours, RGB grouping, linked view/time, raw drawing and failure cleanup.');
end
function axes = panels(viewer)
axes = [findall(viewer.Figure,'Tag','image-view');findall(viewer.Figure,'Tag','channel-view')];
layers = arrayfun(@(ax)ax.UserData.layer,axes); [~,order] = sort(layers); axes = axes(order);
end
function data = pixels(ax)
image = findall(ax,'Type','image'); assert(isscalar(image)); data = image.CData;
end
function setVisible(viewer,index,value)
table = findall(viewer.widgetFigure('Display'),'Tag','layers');
event = struct('revision',table.Data.revision,'action','visible','index',index,'value',value);
table.DataChangedFcn(table,struct('Data',event));
end
