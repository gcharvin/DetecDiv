function dockingTest(previewPath)
%DOCKINGTEST Native floating windows, menu bridge and cross-instance layouts.
if nargin < 1, previewPath = ''; end
disp('Docking test: constructing viewer.');
folder = tempname; mkdir(folder);
cleanupFolder = onCleanup(@()rmdir(folder,'s'));
file = fullfile(folder,'preferences','layout.json');
project = shallow(); project.io.file = 'Docking test';
project.fov.roi = roi('ROI A',[1 1 10 10]);
pixels = uint16(magic(10));
project.fov.roi.image = cat(3,pixels,pixels+100);
project.fov.roi.channelid = [1 2];
project.fov.roi.display.channel = {'Phase','GFP'};
viewer = detecdiv_ui(project,'Visible','off','LayoutFile',file,'RecentPipelinesFile','');
cleanupViewer = onCleanup(@()safeDelete(viewer));
host = viewer.Host;
disp('Docking test: viewer ready; testing project widget menu.');
tree = findall(viewer.widgetFigure('Projects'),'Tag','projects-tree');
node = findall(tree,'Tag','roi-node'); tree.SelectedNodes = node;
tree.SelectionChangedFcn(tree,[]);
ax = findall(viewer.Figure,'Tag','image-view');
channels = findall(viewer.widgetFigure('Display'),'Tag','channels');
channels.Value = 2; channels.ValueChangedFcn(channels,[]);
solo = findall(viewer.widgetFigure('Display'),'Tag','solo-layer'); solo.ButtonPushedFcn(solo,[]);
assert(isequal(getPixels(ax),pixels+100));
% Exercise the actual HTML menu -> MATLAB timer bridge, not just a setter.
host.syncMenus();
command = host.findCommand('Undock Projects');
floating = floatingCount();
host.menuScript(sprintf('document.querySelector(''[data-command="%s"]'').click()',command.Id));
waitUntil(@()~host.isDocked('Projects') && floatingCount() > floating);
assert(isequal(tree,findall(viewer.widgetFigure('Projects'),'Tag','projects-tree')));
assert(viewer.Session.Zone == 1 && isequal(getPixels(ax),pixels+100));
host.findCommand('Dock Projects').invoke();
disp('Docking test: Projects detached; redocking.');
waitUntil(@()host.isDocked('Projects') && floatingCount() == floating);
for name = {'Image','Display','Pipeline'}
    fprintf('Docking test: %s.\n',name{1});
    host.setDocked(name{1},false);
    waitUntil(@()floatingCount() > floating);
    assert(~host.isDocked(name{1}) && isequal(getPixels(ax),pixels+100));
    host.setDocked(name{1},true);
    waitUntil(@()floatingCount() == floating);
end
assert(isequal(channels,findall(viewer.widgetFigure('Display'),'Tag','channels')));
% Save a non-default arrangement with a floating widget and resized columns.
disp('Docking test: saving layout.');
host.setWidgetVisible('Pipeline',false);
host.setDocked('Display',false);
waitUntil(@()floatingCount() > floating);
host.Widgets.display.WindowBounds = [180 120 300 480];
host.App.DocumentColumnWeights = [0.28 0.72];
host.saveLayout();
saved = jsondecode(fileread(file));
assert(~saved.widgets.display.docked && saved.widgets.projects.visible);
savedDimensions = saved.layout.documentLayout.gridDimensions;
savedWeights = saved.layout.documentLayout.columnWeights;
savedBounds = reshape(saved.widgets.display.windowBounds,1,4);
hiddenFile = fullfile(folder,'hidden.json');
host.setWidgetVisible('Projects',false); host.saveLayout(hiddenFile);
host.setWidgetVisible('Projects',true);
assert(host.restoreLayout(hiddenFile) && ~host.isWidgetVisible('Projects'));
assert(strcmp(host.findCommand('Projects').Checked,'off'));
assert(host.restoreLayout(file) && host.isWidgetVisible('Projects'));
if ~isempty(previewPath)
    host.setWidgetVisible('Projects',true); host.dockAll(); host.resetLayout();
    host.show(); host.capture(previewPath);
    assert(host.restoreLayout());
end
% Normal window-close path must auto-save and release the menu timer.
host.App.close();
disp('Docking test: window closed; reopening.');
waitUntil(@()~isvalid(viewer));
assert(isempty(timerfindall('Tag','DetecDivDockMenu')));
restored = detecdiv_ui(project,'Visible','off','LayoutFile',file,'RecentPipelinesFile','');
disp('Docking test: checking restored layout.');
cleanupRestored = onCleanup(@()safeDelete(restored));
assert(isempty(restored.Host.LastLayoutError),restored.Host.LastLayoutError);
assert(~restored.Host.isDocked('Display') && restored.Host.isWidgetVisible('Projects'));
state = restored.Host.snapshot();
assert(isequal(state.layout.documentLayout.gridDimensions,savedDimensions));
weights = state.layout.documentLayout.columnWeights;
assert(isequal(size(weights(:)),size(savedWeights(:))));
assert(max(abs(weights(:)-savedWeights(:))) < 0.02);
actualBounds = restored.Host.Widgets.display.WindowBounds;
assert(max(abs(actualBounds-savedBounds)) < 5, ...
    sprintf('Floating bounds: saved %s, restored %s',mat2str(savedBounds),mat2str(actualBounds)));
restored.Host.findCommand('Reset Layout').invoke();
assert(all(cellfun(@(name)restored.Host.isDocked(name),{'Projects','Image','Display','Pipeline'})));
delete(restored);
% Corrupt preferences must fall back without overwriting the original file.
badFile = fullfile(folder,'broken.json');
fid = fopen(badFile,'w'); fprintf(fid,'{broken'); fclose(fid);
broken = detecdiv_ui([],'Visible','off','LayoutFile',badFile,'RecentPipelinesFile','');
cleanupBroken = onCleanup(@()safeDelete(broken));
assert(~isempty(broken.Host.LastLayoutError));
assert(broken.Host.isDocked('Projects') && broken.Host.isDocked('Display'));
delete(broken);
assert(strcmp(fileread(badFile),'{broken'));
assert(isempty(timerfindall('Tag','DetecDivDockMenu')));
disp('Docking test passed: real floating windows, all four widgets, menu callbacks, auto-save, restore and corrupt-file recovery.');
end

function count = floatingCount()
windows = matlab.internal.webwindowmanager.instance.windowList;
count = 0;
for k = 1:numel(windows)
    if contains(char(windows(k).URL),'undocked.html') && windows(k).isVisible()
        count = count+1;
    end
end
end
function waitUntil(condition)
started = tic;
while ~condition()
    assert(toc(started) < 12,'detecdivui:TestTimeout','Docking operation timed out.');
    pause(0.05); drawnow;
end
end
function safeDelete(value)
if isvalid(value), delete(value); end
end
function pixels = getPixels(ax)
item = findall(ax,'Type','image'); assert(isscalar(item)); pixels = item.CData;
end
