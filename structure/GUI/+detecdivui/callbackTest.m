function callbackTest()
%CALLBACKTEST Named widget dispatch and recovery of a live legacy status link.
project = shallow(); project.io.file = 'Callback test'; project.fov.id = 'Position';
project.fov.roi = roi('Cells',[1 1 8 8]); pixels = uint16(magic(8));
project.fov.roi.image = pixels; project.fov.roi.display.channel = {'Phase'};
project.fov.roi.channelid = 1;
viewer = detecdiv_ui(project,'Visible','off','LayoutFile','','AutoSaveLayout',false,'RecentProjectsFile','');
cleanup = onCleanup(@()safeDelete(viewer));
assert(isa(viewer.Pipeline.OnStatus,'detecdivui.Callback'));
viewer.Pipeline.OnStatus = @(message)error('test:StaleStatus','A legacy callback must be rebound.');
viewer.Pipeline.OnChanged = @()error('test:StaleChanged','A legacy callback must be rebound.');
% Exercise the reported Patch -> openZone -> refreshView -> Pipeline path.
ax = viewer.roiAxes();
tree = findall(viewer.widgetFigure('Projects'),'Tag','projects-tree');
node = findall(tree,'Tag','roi-node');
% The overlay's real callback is installed by the FOV renderer; a temporary
% TIFF supplies raw pixels so that exact native callback can be used.
folder = tempname; mkdir(folder); removeFolder = onCleanup(@()rmdir(folder,'s'));
file = fullfile(folder,'frame1.tif'); imwrite(uint16(ones(12)),file);
project.fov.channel = {'Phase'}; project.fov.frames = 1; project.fov.srcpath = {folder};
project.fov.srclist = {dir(file)}; viewer.loadCurrentImage();
% Restore a stale link immediately before the actual ROI-outline click.
viewer.Pipeline.OnStatus = @(message)error('test:StaleStatus','A legacy callback must be rebound.');
overlay = findall(ax,'Tag','zone-overlay'); assert(isscalar(overlay));
overlay.ButtonDownFcn(overlay,[]);
assert(viewer.Session.Zone == 1 && isequal(tree.SelectedNodes,node));
assert(isa(viewer.Pipeline.OnStatus,'detecdivui.Callback') && isa(viewer.Pipeline.OnChanged,'detecdivui.Callback'));
item = findall(ax,'Type','image'); assert(isequal(item.CData,pixels));
viewer.rebindCallbacks();
scope = detecdivui.Callback.call(detecdivui.Callback(viewer.Progress,'begin'),'Scoped callback'); %#ok<NASGU>
assert(viewer.Progress.Active); clear scope; assert(~viewer.Progress.Active);
assert(detecdivui.Callback.call(@plus,2,3) == 5);
savedCallback = viewer.Pipeline.OnStatus; delete(viewer);
result = detecdivui.Callback.call(savedCallback,'Ignore deleted owner'); assert(isempty(result));
disp('Callback test passed: native ROI click, stale-link recovery, named dispatch, output scopes and deleted owners.');
end
function safeDelete(object)
if isvalid(object), delete(object); end
end
