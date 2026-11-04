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
project.io.file = 'Démo synthétique';
% Empty legacy placeholders must not become user-selectable data.
project.fov(2) = fov();
position = project.fov(2);
position.id = 'Chambre A';
position.channel = {'Phase'};
position.frames = 2;
position.interval = 1;
position.srcpath = {folder};
position.srclist = {dir(fullfile(folder,'*.tif'))};
position.roi = roi();
position.roi(2) = roi('Cellules 01',[40 30 50 65]);
gray = pixels(30:94,40:89);
rgb = cat(3,gray,gray+200,gray+400);
% Non-contiguous stored planes still belong to the same logical RGB channel.
position.roi(2).image = cat(3,rgb(:,:,1),gray,rgb(:,:,2),rgb(:,:,3));
position.roi(2).image(:,:,:,2) = position.roi(2).image(:,:,:,1)+100;
position.roi(2).channelid = [2 1 2 2];
position.roi(2).display.channel = {'Phase','Fluorescence RGB'};
position.roi(3) = roi('Cellules 02',[135 85 50 65]);
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
assert(contains(session.breadcrumb(),'Cellules 01'));
session.selectZone(0);
assert(numel(session.referenceRegions()) == 2);
viewer = detecdiv_ui(project,'Visible','off');
closeViewer = onCleanup(@()delete(viewer));
drawnow;
ax = findall(viewer.Figure,'Tag','image-view');
assert(isequal(ax.XLim,[0.5 240.5]) && isequal(ax.YLim,[0.5 180.5]));
assert(isequal(ax.CLim,double([min(pixels(:)) max(pixels(:))])));
regions = findall(ax,'Tag','zone-overlay');
assert(numel(regions) == 2);
region = regions(arrayfun(@(item)item.UserData == 2,regions));
region.ButtonDownFcn(region,[]);
assert(viewer.Session.Zone == 2);
channels = findall(viewer.Figure,'Tag','channels');
assert(strcmp(channels.Items{channels.Value},'Phase'));
assert(isequal(getPixels(ax),gray));
channels.Value = find(strcmp(channels.Items,'Fluorescence RGB'));
channels.ValueChangedFcn(channels,[]);
assert(isequal(getPixels(ax),rgb));
% Zoom must survive temporal navigation within the same view.
ax.XLim = [10 35]; ax.YLim = [10 40];
slider = findall(viewer.Figure,'Tag','time-slider');
slider.Value = 2; slider.ValueChangedFcn(slider,[]);
assert(isequal(getPixels(ax),rgb+100));
assert(isequal(ax.XLim,[10 35]) && isequal(ax.YLim,[10 40]));
buttons = findall(viewer.Figure,'Type','uibutton');
back = buttons(arrayfun(@(item)strcmp(item.Text,'← Position'),buttons));
back.ButtonPushedFcn(back,[]);
assert(viewer.Session.Zone == 0);
assert(isequal(getPixels(ax),pixels+100));
% An unreadable frame must clear old pixels, then recover on navigation.
position.srclist{1}(2).name = 'missing-frame.tif';
slider.ValueChangedFcn(slider,[]);
assert(isempty(findall(ax,'Type','image')));
status = findall(viewer.Figure,'Tag','status');
assert(contains(status.Text,'indisponible'));
slider.Value = 1; slider.ValueChangedFcn(slider,[]);
assert(isequal(getPixels(ax),pixels));
assert(isequal(ax.XLim,[0.5 240.5]) && isequal(ax.YLim,[0.5 180.5]));
assert(isequal(ax.CLim,double([min(pixels(:)) max(pixels(:))])));
overlay = findall(viewer.Figure,'Tag','reference-zones');
overlay.Value = false; overlay.ValueChangedFcn(overlay,[]);
assert(isempty(findall(ax,'Tag','zone-overlay')));
overlay.Value = true; overlay.ValueChangedFcn(overlay,[]);
% Panel buttons must actually release horizontal space.
toggles = findall(viewer.Figure,'Type','uistatebutton');
for k = 1:numel(toggles)
    toggles(k).Value = false; toggles(k).ValueChangedFcn(toggles(k),[]);
    toggles(k).Value = true; toggles(k).ValueChangedFcn(toggles(k),[]);
end
if ~isempty(previewPath)
    viewer.Figure.Visible = 'on';
    drawnow;
    exportapp(viewer.Figure,previewPath);
end
empty = detecdiv_ui(shallow(),'Visible','off');
closeEmpty = onCleanup(@()delete(empty));
assert(empty.Session.Position == 0);
assert(~isfile(fullfile(folder,'im_zone1.h5')));
disp('Unified viewer smoke test passed: pixels, RGB, overlays, timeline, errors and empty project.');
end

function pixels = getPixels(ax)
imageHandle = findall(ax,'Type','image');
assert(isscalar(imageHandle),'Expected exactly one displayed image.');
pixels = imageHandle.CData;
end
