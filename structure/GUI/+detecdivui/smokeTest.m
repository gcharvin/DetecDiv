function smokeTest()
%SMOKETEST Exercise real TIFF reading and hidden viewer navigation.
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@()rmdir(folder,'s')); %#ok<NASGU>
pixels = uint16(reshape(1:120,10,12));
imwrite(pixels,fullfile(folder,'frame1.tif'));
project = shallow();
project.io.file = 'Synthetic viewer validation';
position = project.fov(1);
position.channel = {'Phase'};
position.frames = 1;
position.interval = 1;
position.srcpath = {folder};
position.srclist = {dir(fullfile(folder,'*.tif'))};
position.roi = roi('zone1',[2 3 5 4]);
position.roi.image = pixels(3:6,2:6);
session = detecdivui.Session(project);
assert(isequal(session.readPlane(1,1),pixels));
session.selectZone(1);
assert(isequal(session.readPlane(1,1),pixels(3:6,2:6)));
assert(contains(session.breadcrumb(),'Zone 1'));
session.selectZone(0);
assert(isequal(session.readPlane(1,1),pixels));
viewer = detecdiv_ui(project,'Visible','off');
closeViewer = onCleanup(@()delete(viewer)); %#ok<NASGU>
drawnow;
assert(isvalid(viewer.Figure));
lists = findall(viewer.Figure,'Type','uilistbox');
zones = lists(arrayfun(@(x)any(strcmp(x.Items,'Vue de la position')),lists));
zones.Value = 1;
zones.ValueChangedFcn(zones,[]);
assert(viewer.Session.Zone == 1);
axesHandle = findall(viewer.Figure,'Type','axes');
imageHandle = findall(axesHandle,'Type','image');
assert(isequal(imageHandle.CData,pixels(3:6,2:6)));
buttons = findall(viewer.Figure,'Type','uibutton');
back = buttons(arrayfun(@(x)strcmp(x.Text,'Revenir à la position'),buttons));
back.ButtonPushedFcn(back,[]);
assert(viewer.Session.Zone == 0);
imageHandle = findall(axesHandle,'Type','image');
assert(isequal(imageHandle.CData,pixels));
assert(~isfile(fullfile(folder,'im_zone1.h5')));
disp('Unified viewer smoke test passed.');
end
