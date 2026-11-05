function contourTest(previewPath)
%CONTOURTEST Native mask assistant, geometry, keyboard, drafts and persistence.
if nargin < 1, previewPath = ''; end
folder = tempname; mkdir(folder); clean = onCleanup(@()rmdir(folder,'s'));
project = shallow(); project.io.file = 'Contour test'; project.fov.id = 'Position';
r = roi('Cells',[1 1 32 32]); r.path = folder;
r.image = zeros(32,32,2,3,'uint16'); r.image(:,:,1,:) = repmat(uint16(magic(32)),1,1,1,3);
r.image(5:18,5:18,2,:) = 1; r.image(10:12,10:12,2,:) = 0;
r.channelid = [1 2]; r.display.channel = {'BF','Mask'};
r.display.intensity = [1 1 1;0 0 0]; r.display.rgb = ones(2,3);
r.display.selectedchannel = [true true]; r.display.indexed = [false true];
r.display.alpha = [1 .4]; r.display.contour = [false false]; r.display.width = [1 1];
r.display.displaylim = repmat([0;1],1,2); source = r.image;
project.fov.roi = r;
viewer = detecdiv_ui(project,'Visible','off','DiscoverWorkspace',false, ...
    'LayoutFile','','AutoSaveLayout',false,'RecentProjectsFile','','RecentPipelinesFile','');
cleanup = onCleanup(@()delete(viewer));
stop(timerfindall('Tag','DetecDivDockMenu'));
assert(isempty(viewer.Masks));
tree = findall(viewer.widgetFigure('Projects'),'Tag','projects-tree');
node = findall(tree,'Tag','roi-node'); tree.SelectedNodes = node; tree.SelectionChangedFcn(tree,[]);
oldDown = viewer.Figure.WindowButtonDownFcn;
viewer.Host.findCommand('Edit Contours...').invoke();
assert(isa(viewer.Masks,'detecdivui.MaskWidget') && viewer.Masks.Active);
widget = viewer.Masks; widget.select(7,7);
label = findall(viewer.widgetFigure('Display'),'Tag','mask-label'); assert(label.Value==1);
assert(~isempty(findall(viewer.roiAxes(),'Tag','mask-selection')));
widget.action('fill'); draft = widget.current();
assert(draft.Dirty && draft.Masks(11,11,1,1)==1 && isequal(r.image,source));
% Browser key events go through the same canvas router as frame navigation.
viewer.Host.focusWidget('Image'); viewer.Host.show(); settle();
window = imageWindow(viewer);
send(window,'z',true); settle(); assert(~draft.Dirty);
send(window,'y',true); settle(); assert(draft.Dirty);
send(window,'Delete',false); settle(); assert(~any(draft.read(1),'all'));
send(window,'z',true); settle(); assert(draft.Masks(11,11,1,1)==1);
before = viewer.DisplayModel.Layers(2).opacity;
[~,special] = detecdiv_prefs_get_shortcuts(); send(window,special{5}{2},false); settle();
assert(viewer.DisplayModel.Layers(2).opacity > before);
send(window,'ArrowRight',false); settle();
frame = findall(viewer.Figure,'Tag','frame-number'); assert(frame.Value==2);
assert(draft.Masks(11,11,1,2)==0);
% Native polygon geometry uses source-pixel coordinates, including zoom.
ax = viewer.roiAxes(); shape = drawpolygon(ax,'Position',[22 22;28 22;28 28;22 28]);
coverage = createMask(shape); delete(shape);
draft.edit(2,'draw',coverage,2,3,false); viewer.contourChanged();
assert(draft.Masks(25,25,1,2)==2 && isequal(r.image,source));
viewer.closeContourTool(); assert(~widget.Active && isequal(viewer.Figure.WindowButtonDownFcn,oldDown));
tabs = findall(viewer.widgetFigure('Display'),'Tag','display-tabs');
assert(isempty(findall(tabs,'Tag','mask-tab')) && draft.Dirty);
viewer.openContourTool(); assert(widget.current()==draft);
% The actual native X-close is vetoed until the asynchronous choice resolves.
viewer.Host.App.close();
button = findall(groot,'Tag','mask-close-cancel'); assert(isscalar(button));
button.ButtonPushedFcn(button,[]);
assert(isvalid(viewer) && draft.Dirty && viewer.Masks.Active);
if ~isempty(previewPath), viewer.Host.capture(previewPath); end
% Widget follows the native Display document through float/redock.
viewer.Host.setDocked('Display',false); viewer.Host.setDocked('Display',true);
assert(widget.current()==draft && widget.Active);
widget.action('save'); assert(~draft.Dirty);
assert(r.image(11,11,2,1)==1 && r.image(25,25,2,2)==2);
assert(isequal(r.image(:,:,1,:),source(:,:,1,:)));
loaded = roi(r.id,r.value); loaded.path=folder; loaded.load('Data',false,'Silent');
assert(isequal(r.image,loaded.image));
% Done removes callbacks; explicit Save Project remains metadata-only.
viewer.closeContourTool(); assert(isempty(findall(viewer.roiAxes(),'Tag','mask-selection')));
assert(~viewer.Progress.Active && ~widget.Progress.Active);
% Save-and-close a project resumes the exact pending action, without a
% blocking question or a global project-index callback.
draft.edit(3,'paint',[25 8],3,2,false); viewer.contourChanged();
viewer.closeProject();
button = findall(groot,'Tag','mask-close-save'); assert(isscalar(button));
button.ButtonPushedFcn(button,[]); assert(isempty(viewer.Sessions) && r.image(8,25,2,3)==3);
viewer.addProject(project); tree = findall(viewer.widgetFigure('Projects'),'Tag','projects-tree');
node = findall(tree,'Tag','roi-node'); tree.SelectedNodes = node; tree.SelectionChangedFcn(tree,[]);
viewer.openContourTool(); draft = widget.current();
draft.edit(3,'delete',[],3,2,false); viewer.contourChanged();
viewer.Host.App.close();
button = findall(groot,'Tag','mask-close-discard'); assert(isscalar(button));
button.ButtonPushedFcn(button,[]);
assert(~isvalid(viewer) && r.image(8,25,2,3)==3);
delete(viewer); clear cleanup;
disp('Contour test passed: native assistant, labels, holes, polygon mask, keyboard undo/delete/opacity/frame, isolated drafts, Done, float/redock and H5 save.');
end
function window = imageWindow(viewer)
windows = matlab.internal.webwindowmanager.instance.windowList;
window = windows(arrayfun(@(w)contains(w.URL,viewer.Host.App.Tag),windows)); assert(isscalar(window));
end
function send(window,key,ctrl)
script = "(()=>{const f=Array.from(document.querySelectorAll('iframe')).find(f=>f.src.includes('/imageKeyboard.html'));" + ...
    "const scope=f.closest('.figureContainerNode');const target=scope.querySelector('canvas div');target.focus();" + ...
    "target.dispatchEvent(new KeyboardEvent('keydown',{key:" + jsonencode(key) + ...
    ",ctrlKey:" + lower(string(ctrl)) + ",bubbles:true,cancelable:true}));return true;})()";
window.executeJS(char(script),5);
end
function settle()
drawnow; pause(.3); drawnow;
end
