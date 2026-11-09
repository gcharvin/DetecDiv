function imageTabsTest(preview)
%IMAGETABSTEST Independent image contexts, shared inspectors and safe closing.
if nargin < 1, preview = ''; end
folder = tempname; mkdir(folder);
files = onCleanup(@()rmdir(folder,'s'));
raw = uint16(reshape(1:2400,40,60));
imwrite(raw,fullfile(folder,'frame1.tif'));
imwrite(raw+100,fullfile(folder,'frame2.tif'));
p = shallow(); p.io.file = 'Tabbed experiment'; p.io.path = folder;
p.fov(1).id = 'Position A'; p.fov(1).channel = {'Phase'};
p.fov(1).frames = 2; p.fov(1).srcpath = {folder};
p.fov(1).srclist = {dir(fullfile(folder,'*.tif'))};
for k = 1:2
    p.fov(1).roi(k) = roi(sprintf('Cell %d',k),[1 1 20 30]);
    p.fov(1).roi(k).image = cat(4,raw(1:30,1:20)+1000*k,raw(1:30,1:20)+1000*k+100);
    p.fov(1).roi(k).display.channel = {'Phase'};
end
fprintf('Image tabs: opening viewer.\n');
v = detecdiv_ui(p,'Visible','off','LayoutFile','','AutoSaveLayout',false, ...
    'RecentProjectsFile','','RecentPipelinesFile','');
cleanup = onCleanup(@()delete(v));
menus = timerfindall('Tag','DetecDivDockMenu'); if ~isempty(menus), stop(menus); end
fprintf('Image tabs: loading FOV.\n');
v.loadCurrentImage();
tabs = findall(v.Figure,'Tag','image-tabs');
fovTab = tabs.SelectedTab;
assert(strcmp(fovTab.Title,'Image: FOV Position A'));
ax = findall(v.Figure,'Tag','image-view');
tree = findall(v.widgetFigure('Projects'),'Tag','projects-tree');
% A queued refresh can arrive after the active tab changes but before the
% new image replaces the outgoing ROI pixels. Do not snapshot those limits.
selectROI(1);
armed = true; originalReader = v.DisplayModel.ReadOverride;
v.DisplayModel.ReadOverride = @reentrantRead;
back = findall(v.Figure,'Tag','parent-fov'); back.ButtonPushedFcn(back,[]);
v.DisplayModel.ReadOverride = originalReader;
assert(~armed && v.Session.Zone == 0);
assert(isequal(ax.XLim,[.5 60.5]) && isequal(ax.YLim,[.5 40.5]), ...
    'Returning to the FOV retained the ROI viewport.');
ax.XLim = [5 35]; ax.YLim = [5 30];
selectROI(1); roi1 = tabs.SelectedTab;
assert(strcmp(roi1.Title,'ROI 1') && numel(tabs.Children) == 2);
slider = findall(v.Figure,'Tag','time-slider'); slider.Value = 2;
slider.ValueChangedFcn(slider,[]);
v.DisplayModel.setLimits(1,[1100 1250]);
ax.XLim = [2 12]; ax.YLim = [3 23];
overlay = findall(v.widgetFigure('Display'),'Tag','display-overlay');
assert(isscalar(overlay)); overlay.Value = false; overlay.ValueChangedFcn(overlay,[]);
selectROI(2); roi2 = tabs.SelectedTab;
assert(strcmp(roi2.Title,'ROI 2') && numel(tabs.Children) == 3);
selectTab(fovTab);
assert(v.Session.Zone == 0 && findall(v.Figure,'Tag','frame-number').Value == 1);
assert(isequal(ax.XLim,[5 35]) && isequal(ax.YLim,[5 30]));
% Fit must discard the stored zoom instead of immediately restoring it.
v.Host.findCommand('Fit Image').invoke();
assert(isequal(ax.XLim,[.5 60.5]) && isequal(ax.YLim,[.5 40.5]));
selectTab(roi1);
assert(v.Session.Zone == 1 && findall(v.Figure,'Tag','frame-number').Value == 2);
assert(~overlay.Value && isequal(ax.XLim,[2 12]) && isequal(ax.YLim,[3 23]));
assert(isequal(v.DisplayModel.Layers(1).limits,[1100 1250]));
assert(tree.SelectedNodes.UserData.roi == 1);
selectROI(1); assert(numel(tabs.Children) == 3); % Reuse existing tab.
oldId = roi2.UserData;
closeButton(roi2);
assert(~isvalid(roi2) && v.Session.Zone == 1 && numel(tabs.Children) == 2);
closeButton(roi1);
assert(~isvalid(roi1) && v.Session.Zone == 0 && isequal(tabs.SelectedTab,fovTab));
selectROI(2); assert(numel(tabs.Children) == 2);
if ~isempty(preview), v.Host.capture(preview); end
closeButton(tabs.SelectedTab); closeButton(fovTab);
assert(isempty(findall(tabs,'Tag','image-context-tab')));
assert(strcmp(findall(v.Figure,'Tag','frame-number').Enable,'off'));
selectROI(2); reopened = tabs.SelectedTab;
assert(~strcmp(reopened.UserData,oldId));
strip = findall(v.Figure,'Tag','image-tab-strip');
strip.DataChangedFcn(strip,struct('Data',struct('action','close','id',oldId)));
assert(isvalid(reopened) && isequal(tabs.SelectedTab,reopened));
v.closeProject(); assert(isempty(findall(tabs,'Tag','image-context-tab')));
fprintf('Image tabs test passed.\n');
    function selectROI(index)
        nodes = findall(tree,'Tag','roi-node');
        node = nodes(arrayfun(@(item)item.UserData.roi == index,nodes));
        tree.SelectedNodes = node; tree.SelectionChangedFcn(tree,[]);
    end
    function selectTab(tab)
        clickHeader(tab,'.select'); started = tic;
        while ~isequal(tabs.SelectedTab,tab)
            assert(toc(started)<12,'Image tab selection was not handled.'); pause(.05); drawnow;
        end
    end
    function plane = reentrantRead(session,~,~,plane)
        if armed && session.Zone == 0
            armed = false; v.loadCurrentImage();
        end
    end
    function closeButton(tab)
        clickHeader(tab,'.close'); started = tic;
        while isvalid(tab)
            assert(toc(started)<12,'Image tab close was not handled.'); pause(.05); drawnow;
        end
    end
    function clickHeader(tab,selector)
        id = tab.UserData; started = tic;
        script = "(()=>{const f=Array.from(document.querySelectorAll('iframe')).find(f=>f.src.includes('/imageTabs.html')&&f.contentDocument?.body.dataset.ready==='true');" + ...
            "if(!f)return false;const t=Array.from(f.contentDocument.querySelectorAll('[data-id]')).find(t=>t.dataset.id===" + jsonencode(id) + ...
            ");if(!t)return false;t.querySelector(" + jsonencode(selector) + ").click();return true;})()";
        while ~jsondecode(v.Host.menuScript(char(script)))
            assert(toc(started)<12,'Image tab close button did not appear.'); pause(.05); drawnow;
        end
    end
end
