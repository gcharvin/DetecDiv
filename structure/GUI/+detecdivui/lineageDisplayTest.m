function lineageDisplayTest(preview)
%LINEAGEDISPLAYTEST Parent links in ordinary display and immutable exports.
if nargin<1, preview=''; end
folder=tempname; mkdir(folder); files=onCleanup(@()rmdir(folder,'s'));
r=fixture(folder,'Cells'); other=fixture(folder,'Other');
pixels=r.image; metadata=r.display; baseline=r.cellModel;
modelFile=fullfile(folder,'objects_Cells.h5'); hash=detecdivui.MovieExportSnapshot.hashFile(modelFile);
p=shallow(); p.io.file='Parent links'; p.fov.id='Position'; p.fov.roi=[r other];
v=detecdiv_ui(p,'Visible','off','DiscoverWorkspace',false,'LayoutFile','','AutoSaveLayout',false, ...
    'RecentProjectsFile','','RecentPipelinesFile','','RecentClassifiersFile','');
cleanup=onCleanup(@()closeViewer(v));
tree=findall(v.widgetFigure('Projects'),'Tag','projects-tree'); selectROI(1);
v.selectDisplayLayer('HOCT'); v.openAnnotations();
checkbox=findall(v.widgetFigure('Annotations'),'Tag','annotations-parent-links');
assert(strcmp(checkbox.Enable,'on')&&checkbox.Value);
assert(contains(checkbox.Tooltip,'frame 2'));
assert(isempty(findall(v.roiAxes(),'Tag','track-link')),'Future parentage was drawn before birth.');
setFrame(2);
links=findall(v.roiAxes(),'Tag','track-link');
assert(isscalar(links),'Missing native parent link (%d). Renderer: %s; status: %s',numel(links), ...
    v.DisplayModel.LineageError,findall(v.Figure,'Tag','status').Text);
assert(isequal(links.XData(:)',[6 6])&&isequal(links.YData(:)',[6 21]));
assert(strcmp(links.HitTest,'off')&&strcmp(links.PickableParts,'none'));
assert(v.Objects.ObjectsRows(2).parent==10);
setFrame(3); links=findall(v.roiAxes(),'Tag','track-link'); assert(isscalar(links));
assert(isequal(links.XData(:)',[6 6]),'Historical parent was replaced by a reused mask label.');
checkbox.Value=false; checkbox.ValueChangedFcn(checkbox,[]); assert(isempty(findall(v.roiAxes(),'Tag','track-link')));
saved=v.displayPreset('save',fullfile(folder,'links-off.json'));
checkbox.Value=true; checkbox.ValueChangedFcn(checkbox,[]);
v.displayPreset('load',saved); assert(~checkbox.Value&&isempty(findall(v.roiAxes(),'Tag','track-link')));
checkbox.Value=true; checkbox.ValueChangedFcn(checkbox,[]);

% A visible unrelated provider never borrows this family's relationships.
v.DisplayModel.setVisible(3,false); v.selectDisplayLayer('Unrelated');
assert(strcmp(checkbox.Enable,'off')&&isempty(findall(v.roiAxes(),'Tag','track-link')));
v.DisplayModel.setVisible(4,false); v.selectDisplayLayer('HOCT');
v.Host.setWidgetVisible('Annotations',false); setFrame(2);
assert(isscalar(findall(v.roiAxes(),'Tag','track-link')),'Links depended on opening the editor.');
overlay=findall(v.widgetFigure('Display'),'Tag','display-overlay');
overlay.Value=false; overlay.ValueChangedFcn(overlay,[]);
panels=findall(v.Figure,'Type','axes'); panels=panels(arrayfun(@(ax)ismember(ax.Tag,{'image-view','channel-view'}),panels));
assert(numel(panels)==2);
for ax=reshape(panels,1,[]), assert(isscalar(findall(ax,'Tag','track-link'))); end

% The shared renderer follows staged parent edits and undo without saving.
d=v.annotationDraft('HOCT'); d.editTrack('unparent',1,2,2,0,'frame'); v.contourChanged();
assert(isempty(findall(v.roiAxes(),'Tag','track-link'))&&d.Dirty);
settings=detecdivui.MovieExportJob.defaults(); settings.mode='images'; settings.frames='3';
sources=v.movieSources('current'); noParent=detecdivui.MovieExportJob(sources,settings,v.Masks.Drafts);
assert(isempty(noParent.Entries(1).model.lineageVectors(3,3)));
settings.includeDrafts=false; persisted=detecdivui.MovieExportJob(sources,settings,v.Masks.Drafts);
assert(isscalar(persisted.Entries(1).model.lineageVectors(3,3)));
d.undo(); v.contourChanged(); assert(isscalar(findall(v.roiAxes(),'Tag','track-link')));
v.openTracksTool(); assert(isscalar(findall(v.roiAxes(),'Tag','track-link')),'Tracks duplicated the Display link.');
v.closeTracksTool(); assert(isscalar(findall(v.roiAxes(),'Tag','track-link')),'Closing Tracks removed Display parentage.');

% Freeze frame 3 alone: its parent endpoint is from omitted frame 2.
settings.includeDrafts=true; job=detecdivui.MovieExportJob(v.movieSources('current'),settings,v.Masks.Drafts);
expected=job.frameViews(1,3);
assert(expected{1}.parentLinkCount==1,'The frozen export lost parentage: %s',job.Entries(1).model.LineageError);
descriptor=job.saveSnapshot(fullfile(folder,'snapshot'));
restored=detecdivui.MovieExportJob.fromSnapshot(descriptor.path,descriptor.sha256);
actual=restored.frameViews(1,3);
for k=1:numel(expected), assert(isequal(actual{k}.pixels,expected{k}.pixels)&&isequal(actual{k}.vectors,expected{k}.vectors)); end
local=job.write(fullfile(folder,'local_png')); replay=restored.write(fullfile(folder,'replay_png'));
assert(isequal(imread(fullfile(local,'frame_000003.png')),imread(fullfile(replay,'frame_000003.png'))), ...
    'The portable export rendered different parent links.');
d.editTrack('unparent',1,3,2,0,'frame'); v.contourChanged();
assert(isempty(findall(v.roiAxes(),'Tag','track-link')));
after=job.frameViews(1,3); assert(isequal(after{1}.vectors,expected{1}.vectors),'The export kept a live lineage callback.');
d.undo(); v.contourChanged();

% Selection/navigation and UI layout are independent of parentage storage.
v.Host.setWidgetVisible('Annotations',true); v.Host.openObjects();
checkbox=findall(v.widgetFigure('Annotations'),'Tag','annotations-parent-links');
checkbox.Value=false; checkbox.ValueChangedFcn(checkbox,[]);
selectROI(2); v.selectDisplayLayer('HOCT'); setFrame(2); assert(checkbox.Value);
selectROI(1); assert(~checkbox.Value); checkbox.Value=true; checkbox.ValueChangedFcn(checkbox,[]);
setFrame(3); overlay.Value=true; overlay.ValueChangedFcn(overlay,[]);
v.Host.show(); v.Host.focusWidget('Display');
if ~isempty(preview), drawnow; v.Host.capture(preview); end
assert(isequal(r.image,pixels)&&isequal(r.display,metadata)&&isequal(r.cellModel,baseline));
assert(strcmp(detecdivui.MovieExportSnapshot.hashFile(modelFile),hash));
disp('Lineage Display passed: temporal/historical links, provider isolation, read-only view, toggles/presets, shared drafts/undo, separate panels and frozen export replay.');
    function selectROI(index)
        nodes=findall(tree,'Tag','roi-node'); node=nodes(arrayfun(@(n)n.UserData.roi==index,nodes));
        tree.SelectedNodes=node; tree.SelectionChangedFcn(tree,[]);
    end
    function setFrame(frame)
        control=findall(v.Figure,'Tag','frame-number'); control.Value=frame; control.ValueChangedFcn(control,[]);
    end
end
function r=fixture(folder,id)
r=roi(id,[1 1 36 30]); r.path=folder;
r.image=zeros(30,36,4,4,'uint16'); r.image(:,:,1:2,:)=100;
r.image(4:8,4:8,3,1:2)=1; r.image(19:23,4:8,3,2:4)=2;
r.image(24:28,28:32,3,3:4)=1; r.image(:,:,4,:)=r.image(:,:,3,:);
r.channelid=1:4; r.display.channel={'Phase','GFP','HOCT','Unrelated'};
r.display.indexed=[false false true true]; r.display.rgb=ones(4,3);
r.display.intensity=[1 1 1;1 1 1;0 0 0;0 0 0]; r.display.selectedchannel=[true true true false];
[model,report]=cellModel.fromLegacy(r,'Channels',{'HOCT','Unrelated'}); assert(report.validation.ok);
model.instances.track_id=uint64(10)*uint64(model.instances.mask_label);
model.instances.track_id(model.instances.mask_label==1 & model.instances.frame>=3)=30;
[model,~]=cellModel.setParentTrack(model,1,2,uint64(20),uint64(10));
r.save([],false); r.load('Silent'); r.saveCellModel(model);
end
function closeViewer(v)
if ~isvalid(v), return; end
if ~isempty(v.Masks), for k=1:numel(v.Masks.Drafts), v.Masks.Drafts{k}.discard(); end; end
delete(v);
end
