function contoursTest(previewPath)
%CONTOURSTEST Score vector contours without changing stored masks/display data.
if nargin < 1, previewPath = ''; end
project = shallow(); project.io.file = 'Contours'; project.fov.id = 'Position';
project.fov.roi = roi('Cells',[1 1 30 24]); source = project.fov.roi;
phase = uint32(repmat(1:30,24,1)); labels = zeros(24,30,'uint32');
labels(4:12,4:12) = 1; labels(15:21,18:26) = 65536;
source.image = cat(3,phase,labels); source.channelid = [1 2];
source.display.channel = {'Phase','Cells'}; source.display.rgb = [1 1 1;0 1 0];
source.display.indexed = [false true]; source.display.selectedchannel = [true true];
source.display.alpha = [1 .35]; source.display.contour = [false true]; source.display.width = [1 2.5];
original = source.image; metadata = source.display;
viewer = detecdiv_ui(project,'Visible','off','LayoutFile','','AutoSaveLayout',false,'RecentProjectsFile','');
cleanup = onCleanup(@()delete(viewer));
tree = findall(viewer.widgetFigure('Projects'),'Tag','projects-tree');
tree.SelectedNodes = findall(tree,'Tag','roi-node'); tree.SelectionChangedFcn(tree,[]);
figure = viewer.widgetFigure('Display'); active = findall(figure,'Tag','channels');
active.Value = 2; active.ValueChangedFcn(active,[]);
style = findall(figure,'Tag','mask-style'); width = findall(figure,'Tag','mask-width');
assert(strcmp(style.Value,'Fill + Contours') && width.Value == 2.5);
ax = viewer.roiAxes(); contours = findall(ax,'Tag','mask-contour');
assert(numel(contours) == 2 && all([contours.LineWidth] == 2.5));
assert(all([contours.FaceAlpha] == 0) && all(strcmp({contours.PickableParts},'none')));
style.Value = 'Fill'; style.ValueChangedFcn(style,[]);
assert(isempty(findall(ax,'Tag','mask-contour')));
filled = viewer.DisplayModel.compose(1,2); assert(isempty(filled.vectors));
style.Value = 'Contours'; style.ValueChangedFcn(style,[]);
viewer.DisplayModel.setColor(1,'0.8 0.8 0.8');
outline = viewer.DisplayModel.compose(1,2);
viewer.DisplayModel.setVisible(2,false); base = viewer.DisplayModel.compose(1,1);
assert(isequal(outline.pixels,base.pixels) && numel(outline.vectors) == 2);
viewer.DisplayModel.setVisible(2,true);
width.Value = 4; width.ValueChangedFcn(width,[]);
assert(all([findall(ax,'Tag','mask-contour').LineWidth] == 4));
width.Value = 0; width.ValueChangedFcn(width,[]);
assert(width.Value == 4); % Invalid width is rejected and the control restores state.
viewer.DisplayModel.setVisible(2,false); active.Value = 1; active.ValueChangedFcn(active,[]);
assert(isempty(findall(ax,'Tag','mask-contour')));
viewer.DisplayModel.setVisible(2,true); active.Value = 2; active.ValueChangedFcn(active,[]);
viewer.Host.setDocked('Display',false); viewer.Host.setDocked('Display',true);
assert(strcmp(style.Value,'Contours') && width.Value == 4);
assert(isequal(source.image,original) && isequal(source.display,metadata));
if ~isempty(previewPath)
    viewer.Host.show(); viewer.Host.focusWidget('Display'); drawnow; viewer.Host.capture(previewPath);
end
disp('Contours test passed: Score vectors, fill/contour styles, width, visibility, metadata and source immutability.');
end
