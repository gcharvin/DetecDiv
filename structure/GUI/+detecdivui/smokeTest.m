function smokeTest(previewPath)
%SMOKETEST Exercise TIFF reading, logical channels and real UI callbacks.
if nargin < 1, previewPath = ''; end
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@()rmdir(folder,'s'));
[y,x] = ndgrid(1:180,1:240);
pixels = uint16(600 + 1800*exp(-((x-65).^2/180+(y-60).^2/300)) + ...
    2200*exp(-((x-160).^2/180+(y-115).^2/300)) + 70*sin(x/5).*cos(y/7));
imwrite(pixels,fullfile(folder,'frame1.tif'));
imwrite(pixels+100,fullfile(folder,'frame2.tif'));
project = shallow();
project.io.file = 'Experiment A';
project.io.path = folder;
% Empty legacy placeholders must not become user-selectable data.
project.fov(2) = fov();
position = project.fov(2);
position.id = 'Chamber A';
position.channel = {'Phase'};
position.frames = 2;
position.interval = 1;
position.srcpath = {folder};
position.srclist = {dir(fullfile(folder,'*.tif'))};
position.roi = roi();
position.roi(2) = roi('Cells 01',[40 30 50 65]);
gray = pixels(30:94,40:89);
rgb = cat(3,gray,gray+200,gray+400);
% Non-contiguous stored planes still belong to the same logical RGB channel.
position.roi(2).image = cat(3,rgb(:,:,1),gray,rgb(:,:,2),rgb(:,:,3));
position.roi(2).image(:,:,:,2) = position.roi(2).image(:,:,:,1)+100;
position.roi(2).channelid = [2 1 2 2];
position.roi(2).display.channel = {'Phase','Fluorescence RGB'};
position.roi(3) = roi('Cells 02',[135 85 50 65]);
position.roi(3).image = gray;
position.roi(3).display.channel = {'Phase'};
session = detecdivui.Session(project);
assert(session.Position == 2);
[~, indices] = session.positionItems(); assert(isequal(indices,2));
[~, indices] = session.zoneItems(); assert(isequal(indices,[2 3]));
assert(isequal(session.readPlane(2,1),pixels+100));
session.selectZone(2);
[names,frames] = session.dimensions();
assert(frames == 2);
assert(isequal(session.readPlane(1,find(strcmp(names,'Phase'))),gray));
assert(isequal(session.readPlane(1,find(strcmp(names,'Fluorescence RGB'))),rgb));
assert(contains(session.breadcrumb(),'Cells 01'));
assert(contains(session.breadcrumb(),'FOV 2') && contains(session.breadcrumb(),'ROI 2'));
session.selectZone(0);
assert(numel(session.referenceRegions()) == 2);
viewer = detecdiv_ui(project,'Visible','off','LayoutFile','','AutoSaveLayout',false);
closeViewer = onCleanup(@()delete(viewer));
drawnow;
ax = findall(viewer.Figure,'Tag','image-view');
assert(isempty(findall(ax,'Type','image')));
viewer.loadCurrentImage();
assert(isequal(ax.XLim,[0.5 240.5]) && isequal(ax.YLim,[0.5 180.5]));
assert(isequal(ax.CLim,double([min(pixels(:)) max(pixels(:))])));
regions = findall(ax,'Tag','zone-overlay');
assert(numel(regions) == 2);
region = regions(arrayfun(@(item)item.UserData == 2,regions));
region.ButtonDownFcn(region,[]);
assert(viewer.Session.Zone == 2);
tree = findall(viewer.widgetFigure('Projects'),'Tag','projects-tree');
projectPath = findall(viewer.widgetFigure('Projects'),'Tag','project-path');
projectName = findall(viewer.widgetFigure('Projects'),'Tag','project-name');
projectInfo = findall(viewer.widgetFigure('Projects'),'Tag','project-information');
copyPath = findall(viewer.widgetFigure('Projects'),'Tag','copy-project-path');
assert(strcmp(projectPath.Value{1},fullfile(folder,'Experiment A')));
assert(strcmp(projectName.Text,'Experiment A') && strcmp(copyPath.Enable,'on'));
assert(projectInfo.Data{1,2} == 1 && projectInfo.Data{2,2} == 2);
assert(strcmp(copyPath.UserData,fullfile(folder,'Experiment A')));
assert(tree.SelectedNodes.UserData.roi == 2);
assert(isscalar(tree.Children) && isscalar(tree.Children.Children));
channels = findall(viewer.widgetFigure('Display'),'Tag','channels');
assert(strcmp(channels.Items{channels.Value},'Phase'));
assert(isequal(getPixels(ax),gray));
channels.Value = find(strcmp(channels.Items,'Fluorescence RGB'));
channels.ValueChangedFcn(channels,[]);
solo = findall(viewer.widgetFigure('Display'),'Tag','solo-layer');
solo.ButtonPushedFcn(solo,[]);
assert(isequal(getPixels(ax),rgb));
% Zoom must survive temporal navigation within the same view.
ax.XLim = [10 35]; ax.YLim = [10 40];
slider = findall(viewer.Figure,'Tag','time-slider');
slider.Value = 2; slider.ValueChangedFcn(slider,[]);
assert(isequal(getPixels(ax),rgb+100));
assert(isequal(ax.XLim,[10 35]) && isequal(ax.YLim,[10 40]));
back = findall(viewer.Figure,'Tag','parent-fov');
back.ButtonPushedFcn(back,[]);
assert(viewer.Session.Zone == 0);
assert(isequal(getPixels(ax),pixels+100));
% An unreadable frame must clear old pixels, then recover on navigation.
position.srclist{1}(2).name = 'missing-frame.tif';
viewer.Host.findCommand('Reload Image').invoke();
assert(isempty(findall(ax,'Type','image')));
status = findall(viewer.Figure,'Tag','status');
assert(contains(status.Text,'unavailable'));
slider.Value = 1; slider.ValueChangedFcn(slider,[]);
assert(isequal(getPixels(ax),pixels));
assert(isequal(ax.XLim,[0.5 240.5]) && isequal(ax.YLim,[0.5 180.5]));
assert(isequal(ax.CLim,double([min(pixels(:)) max(pixels(:))])));
overlay = findall(viewer.widgetFigure('Display'),'Tag','reference-zones');
overlay.Value = false; overlay.ValueChangedFcn(overlay,[]);
assert(isempty(findall(ax,'Tag','zone-overlay')));
overlay.Value = true; overlay.ValueChangedFcn(overlay,[]);
% Conventional menus and their live panel actions.
menus = [viewer.Host.Commands{:}];
for text = {'File','Edit','View','Navigate','Help'}
    assert(any(arrayfun(@(item)strcmp(item.Text,text{1}),menus)));
end
for text = {'Projects','Display'}
    toggle = viewer.Host.findCommand(text{1});
    toggle.MenuSelectedFcn(toggle,[]); assert(strcmp(toggle.Checked,'off'));
    toggle.MenuSelectedFcn(toggle,[]); assert(strcmp(toggle.Checked,'on'));
end
% Tree selection, frame clamping and independent project navigation.
position.srclist{1}(2).name = 'frame2.tif';
nodes = findall(tree,'Tag','roi-node');
roiNode = nodes(arrayfun(@(item)item.UserData.roi == 3,nodes));
tree.SelectedNodes = roiNode; tree.SelectionChangedFcn(tree,[]);
assert(viewer.Session.Zone == 3);
roiNode = nodes(arrayfun(@(item)item.UserData.roi == 2,nodes));
tree.SelectedNodes = roiNode; tree.SelectionChangedFcn(tree,[]);
channels.Value = find(strcmp(channels.Items,'Phase')); channels.ValueChangedFcn(channels,[]);
solo.ButtonPushedFcn(solo,[]);
slider.Value = 2; slider.ValueChangedFcn(slider,[]);
assert(isequal(getPixels(ax),gray+100));
second = shallow();
second.io.file = 'Experiment B';
second.fov.id = 'Chamber B';
second.fov.channel = {'Phase'}; second.fov.frames = 1; second.fov.interval = 1;
second.fov.srcpath = {folder}; second.fov.srclist = {position.srclist{1}(1)};
viewer.addProject(second);
viewer.loadCurrentImage();
assert(numel(viewer.Sessions) == 2 && numel(tree.Children) == 2);
assert(viewer.ActiveProject == 2 && isequal(getPixels(ax),pixels));
assert(strcmp(projectName.Text,'Experiment B') && strcmp(copyPath.Enable,'off'));
assert(strcmp(projectPath.Value{1},'—'));
projectNodes = findall(tree,'Tag','project-node');
firstNode = projectNodes(arrayfun(@(item)item.UserData.project == 1,projectNodes));
tree.SelectedNodes = firstNode; tree.SelectionChangedFcn(tree,[]);
assert(viewer.ActiveProject == 1 && viewer.Session.Zone == 2);
assert(isequal(tree.SelectedNodes,firstNode));
assert(strcmp(projectPath.Value{1},fullfile(folder,'Experiment A')));
viewer.loadCurrentImage();
assert(isequal(getPixels(ax),gray+100));
viewer.addProject(project); assert(numel(viewer.Sessions) == 2);
viewer.loadCurrentImage();
viewer.closeProject(2); % Closing an inactive project keeps the active ROI.
assert(viewer.ActiveProject == 1 && viewer.Session.Zone == 2);
assert(isequal(getPixels(ax),gray+100));
viewer.addProject(second);
viewer.closeProject(); % Closing the active project restores the other one.
assert(viewer.ActiveProject == 1 && viewer.Session.Zone == 2);
viewer.addProject(second); viewer.addProject(project);
back.ButtonPushedFcn(back,[]);
slider.Value = 1; slider.ValueChangedFcn(slider,[]);
if ~isempty(previewPath)
    viewer.Host.show();
    drawnow;
    viewer.Host.capture(previewPath);
end
closeMenu = menus(arrayfun(@(item)strcmp(item.Text,'Close Project'),menus));
closeMenu.MenuSelectedFcn(closeMenu,[]);
assert(isscalar(viewer.Sessions));
closeMenu.MenuSelectedFcn(closeMenu,[]);
assert(isempty(viewer.Sessions) && isempty(tree.Children));
assert(viewer.ActiveProject == 0 && isempty(findall(ax,'Type','image')));
assert(strcmp(projectName.Text,'—') && isempty(projectInfo.Data));
assert(strcmp(copyPath.Enable,'off') && strcmp(projectPath.Value{1},'—'));
assert(strcmp(closeMenu.Enable,'off'));
empty = detecdiv_ui(shallow(),'Visible','off','LayoutFile','','AutoSaveLayout',false);
closeEmpty = onCleanup(@()delete(empty));
assert(empty.Session.Position == 0);
assert(~isfile(fullfile(folder,'im_zone1.h5')));
disp('Viewer smoke test passed: menus, project tree, multi-project navigation, pixels, RGB and errors.');
end

function pixels = getPixels(ax)
imageHandle = findall(ax,'Type','image');
assert(isscalar(imageHandle),'Expected exactly one displayed image.');
pixels = imageHandle.CData;
end
