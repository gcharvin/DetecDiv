function tracksTest(previewPath)
%TRACKSTEST Native linking assistant, shared drafts and explicit model saves.
if nargin < 1, previewPath = ''; end
folder = tempname; mkdir(folder); clean = onCleanup(@()rmdir(folder,'s'));
r = fixture(folder,'Tracks'); other = fixture(folder,'Other');
source = r.image; baseline = r.cellModel; otherBaseline = other.cellModel;
project = shallow(); project.io.file = 'Track editing'; project.fov.id = 'Position';
project.fov.roi = [r other];
viewer = detecdiv_ui(project,'Visible','off','DiscoverWorkspace',false, ...
    'LayoutFile','','AutoSaveLayout',false,'RecentProjectsFile','','RecentPipelinesFile','');
cleanup = onCleanup(@()closeTestViewer(viewer));
stop(timerfindall('Tag','DetecDivDockMenu'));
assert(isempty(viewer.Tracks) && isempty(viewer.Masks));
tree = findall(viewer.widgetFigure('Projects'),'Tag','projects-tree'); choose(tree,1);
oldDown = viewer.Figure.WindowButtonDownFcn;
viewer.Host.findCommand('Edit Tracks...').invoke();
widget = viewer.Tracks; assert(widget.Active && ~viewer.Masks.Active);
tabs = findall(viewer.widgetFigure('Objects'),'Tag','objects-tools');
assert(isempty(findall(tabs,'Tag','mask-tab')));
slider = findall(viewer.Figure,'Tag','time-slider');
setFrame(slider,2); widget.pick(5,21); d = widget.current();
info = findall(viewer.widgetFigure('Objects'),'Tag','tracks-info');
assert(strcmp(info.UserData{1,2},'2') && strcmp(info.UserData{2,2},'20'));
widget.beginPick('parent'); setFrame(slider,1); widget.pick(5,5);
assert(d.WorkingModel.relations.parent_track_id==10 && d.WorkingModel.relations.event_frame==2);
assert(isequal(r.cellModel,baseline) && isequal(r.image,source));
widget.showLineage(); lineage = widget.LineageFigure; assert(isgraphics(lineage));
track = findall(lineage,'Type','text','String','20'); assert(isscalar(track));
staleTreeClick = track.ButtonDownFcn;
setFrame(slider,4); track.ButtonDownFcn(track,[]);
assert(viewer.annotationFrame()==2 && strcmp(info.UserData{2,2},'20'));
legacy = score_lineageTreeDialog(d.previewModel(),1);
widget.showLineage(); assert(widget.LineageFigure==lineage && isgraphics(legacy)); delete(legacy);
setFrame(slider,2); assert(~isempty(findall(viewer.roiAxes(),'Tag','track-link')));
viewer.Host.show(); viewer.Host.focusWidget('Image'); settle();
window = mainWindow(viewer);
send(window,'z',true); settle(); assert(isempty(d.WorkingModel.relations.relation_id));
send(window,'y',true); settle(); assert(d.WorkingModel.relations.parent_track_id==10);
setFrame(slider,3); widget.pick(5,21);
scope = findall(viewer.widgetFigure('Objects'),'Tag','tracks-scope'); scope.Value = 'to-last';
widget.beginPick('assign'); setFrame(slider,2); widget.pick(5,21);
assert(all(d.WorkingModel.instances.track_id(d.WorkingModel.instances.mask_label==4)==20));
setFrame(slider,4); assert(strcmp(info.UserData{1,2},'4') && strcmp(info.UserData{2,2},'20'));
target = findall(viewer.widgetFigure('Objects'),'Tag','tracks-destination'); target.Value = '20';
before = d.WorkingModel; widget.action('parent'); assert(isequal(before,d.WorkingModel));
widget.action('unparent'); assert(isempty(d.WorkingModel.relations.relation_id));
widget.action('undo'); assert(d.WorkingModel.relations.parent_track_id==10);
target.Value = '30'; widget.action('swap'); assert(d.WorkingModel.relations.child_track_id==30);
widget.action('undo'); assert(d.WorkingModel.relations.child_track_id==20);
% Leaving the ROI cancels an armed pick, without modifying another ROI.
widget.beginPick('parent'); choose(tree,2); widget.pick(5,5);
assert(~isgraphics(lineage)); oldFrame = viewer.annotationFrame(); staleTreeClick([],[]);
assert(viewer.annotationFrame()==oldFrame);
assert(~widget.current().Dirty && isequal(other.cellModel,otherBaseline));
choose(tree,1); assert(widget.current()==d && d.Dirty);
setFrame(slider,4); widget.pick(5,21);
% Contours and Tracks own a single provider draft and history.
viewer.openContourTool(); assert(~widget.Active && viewer.Masks.Active && viewer.Masks.current()==d);
selectedLabel = findall(viewer.widgetFigure('Objects'),'Tag','mask-label'); assert(selectedLabel.Value==4);
% Provider selection now belongs to Display; the old hidden dropdown is only
% a compatibility bridge and intentionally snaps back to the active layer.
viewer.closeContourTool(); viewer.selectDisplayLayer('Extra'); viewer.openContourTool();
assert(strcmp(viewer.Masks.current().Channel,'Extra')); selectedLabel.Value = 1;
viewer.Masks.action('fill'); assert(~viewer.Masks.current().Dirty);
message = findall(viewer.widgetFigure('Objects'),'Tag','mask-status'); assert(contains(message.Text,'Save or discard'));
viewer.closeContourTool(); viewer.selectDisplayLayer('Mask'); viewer.openContourTool(); viewer.Masks.select(5,21);
d.edit(4,'paint',[15 15],5,1,false); viewer.contourChanged();
viewer.Masks.mouseDown(viewer.roiAxes(),[5 21],'open',{});
status = findall(viewer.Figure,'Tag','status');
messageText = ''; if ~isempty(status), messageText = status.Text; end
assert(widget.Active && ~viewer.Masks.Active,['Track assistant failed to become active: ' messageText]);
outlines = findall(viewer.roiAxes(),'Tag','track-selection');
assert(~isempty(outlines) && all(strcmp({outlines.LineStyle},'--')));
assert(~isempty(findall(viewer.roiAxes(),'Tag','track-label','String','Track 20')));
widget.action('undo'); assert(d.Masks(15,15,1,4)==0 && d.Dirty);
setFrame(slider,1); widget.pick(22,5); target.Value = '9007199254740993'; scope.Value = 'all';
widget.action('assign'); assert(strcmp(info.UserData{2,2},target.Value));
widget.showLineage(); lineage = widget.LineageFigure;
exact = findall(lineage,'Type','text','String','9007199254740993'); assert(isscalar(exact));
setFrame(slider,4); exact.ButtonDownFcn(exact,[]);
assert(viewer.annotationFrame()==1 && strcmp(info.UserData{2,2},'9007199254740993'));
refresh = findall(lineage,'Type','uibutton','Text','Refresh'); refresh.ButtonPushedFcn(refresh,[]);
assert(widget.LineageFigure==lineage);
viewer.closeTracksTool(); assert(~widget.Active && isequal(viewer.Figure.WindowButtonDownFcn,oldDown));
assert(~isgraphics(lineage));
assert(isempty(findall(tabs,'Tag','tracks-tab')) && isempty(findall(viewer.roiAxes(),'Tag','track-label')));
viewer.openTracksTool(); viewer.Host.setDocked('Objects',false); viewer.Host.setDocked('Objects',true);
assert(widget.Active && widget.current()==d);
if ~isempty(previewPath), viewer.Host.capture(previewPath); end
h5 = fullfile(folder,['im_' r.id '.h5']); stamp = dir(h5);
widget.action('save');
status = findall(viewer.widgetFigure('Objects'),'Tag','tracks-status');
assert(~d.Dirty && isequal(r.image,source),status.Text);
after = dir(h5); assert(stamp.datenum==after.datenum && stamp.bytes==after.bytes);
loaded = roi(r.id,r.value); loaded.path = folder; [model,report] = loaded.loadCellModel();
assert(report.validation.ok && isequal(model.instances.track_id,r.cellModel.instances.track_id));
widget.action('new'); assert(d.Dirty);
viewer.Host.App.close(); button = findall(groot,'Tag','mask-close-cancel'); assert(isscalar(button));
button.ButtonPushedFcn(button,[]); assert(isvalid(viewer) && d.Dirty);
viewer.Host.App.close(); button = findall(groot,'Tag','mask-close-discard'); assert(isscalar(button));
button.ButtonPushedFcn(button,[]); assert(~isvalid(viewer)); clear cleanup;
disp('Tracks test passed: parent/continuity picks across frames, genealogy overlay, scope/uint64 IDs, shared Contours undo, ROI isolation, Done, float/redock, model-only saves and close protection.');
end
function r = fixture(folder,id)
r = roi(id,[1 1 30 30]); r.path = folder;
r.image = zeros(30,30,3,4,'uint16'); r.image(:,:,1,:) = 100;
r.image(3:8,3:8,2,:) = 1; r.image(3:8,20:25,2,:) = 3;
r.image(18:24,3:8,2,2) = 2; r.image(18:24,4:9,2,3:4) = 4;
r.channelid = [1 2 3]; r.display.channel = {'BF','Mask','Extra'}; r.display.indexed = [false true true];
r.display.intensity = [1 1 1;0 0 0;0 0 0]; r.display.rgb = ones(3,3); r.display.selectedchannel = [true true false];
[m,report] = cellModel.fromLegacy(r,'Channels',{'Mask'}); assert(report.validation.ok);
m.instances.track_id = uint64(10)*uint64(m.instances.mask_label);
r.save([],false); r.load('Silent'); r.saveCellModel(m);
end
function choose(tree,index)
nodes = findall(tree,'Tag','roi-node'); node = nodes(arrayfun(@(n)n.UserData.roi==index,nodes));
tree.SelectedNodes = node; tree.SelectionChangedFcn(tree,[]);
end
function setFrame(slider,frame)
slider.Value = frame; slider.ValueChangedFcn(slider,[]);
end
function window = mainWindow(viewer)
windows = matlab.internal.webwindowmanager.instance.windowList;
window = windows(arrayfun(@(w)contains(w.URL,viewer.Host.App.Tag),windows)); assert(isscalar(window));
end
function send(window,key,ctrl)
script = "(()=>{const f=Array.from(document.querySelectorAll('iframe')).find(f=>f.src.includes('/imageKeyboard.html'));" + ...
    "const scope=f.closest('.figureContainerNode');const target=scope.querySelector('canvas div');target.focus();" + ...
    "target.dispatchEvent(new KeyboardEvent('keydown',{key:" + jsonencode(key) + ",ctrlKey:" + ...
    lower(string(ctrl)) + ",bubbles:true,cancelable:true}));return true;})()";
window.executeJS(char(script),5);
end
function settle()
drawnow; pause(.3); drawnow;
end
function closeTestViewer(viewer)
if ~isvalid(viewer), return; end
if isa(viewer.Masks,'detecdivui.MaskWidget') && isvalid(viewer.Masks)
    for k = 1:numel(viewer.Masks.Drafts)
        draft = viewer.Masks.Drafts{k};
        if draft.Dirty && ~draft.SaveFailed, draft.discard(); end
    end
end
delete(viewer);
end
