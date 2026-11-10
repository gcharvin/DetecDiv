function displayPresetTest(preview)
%DISPLAYPRESETTEST Name mapping, persistence, isolated edits and real UI actions.
if nargin<1, preview=''; end
folder=tempname; mkdir(folder); files=onCleanup(@()rmdir(folder,'s'));
p=shallow(); p.io.file='Display presets'; p.fov.id='Position';
phase=uint16(reshape(1:1200,30,40)); signal=phase*2;
mask=zeros(30,40,'uint16'); mask(8:18,10:20)=1;
names={{'Phase','GFP','Cells'},{'Cells','Extra','GFP','Phase'}};
planes={cat(3,phase,signal,mask),cat(3,mask,phase+500,signal,phase)};
for k=1:2
    r=roi(sprintf('Cells %d',k),[1 1 40 30]); r.path=folder;
    r.image=cat(4,planes{k},planes{k}); r.channelid=1:numel(names{k});
    r.display.channel=names{k}; r.display.indexed=strcmp(names{k},'Cells');
    r.display.rgb=ones(numel(names{k}),3); r.display.selectedchannel=true(1,numel(names{k}));
    p.fov.roi(k)=r;
end
before={p.fov.roi(1).image,p.fov.roi(2).image}; metadata={p.fov.roi(1).display,p.fov.roi(2).display};
v=detecdiv_ui(p,'Visible','off','DiscoverWorkspace',false,'LayoutFile','','AutoSaveLayout',false, ...
    'RecentProjectsFile','','RecentPipelinesFile','','RecentClassifiersFile','');
cleanup=onCleanup(@()closeViewer(v));
tree=findall(v.widgetFigure('Projects'),'Tag','projects-tree');
selectROI(1); model=v.DisplayModel;
model.setLimits(1,[100 1000]); model.setLimits(2,[250 2000]); model.setColor(2,'0.123456789 0.6 0.9');
model.setOpacity(2,.65); model.setOpacity(3,.3); model.setLabelStyle(3,'Contours',2.5);
model.setVisible(1,false); v.selectDisplayLayer('GFP');
overlay=findall(v.widgetFigure('Display'),'Tag','display-overlay'); overlay.Value=false; overlay.ValueChangedFcn(overlay,[]);
v.Host.findCommand('Copy Display Preset').invoke();
saved=v.displayPreset('save',fullfile(folder,'settings.json')); assert(isfile(saved));
preset=detecdivui.DisplayPreset.read(saved); assert(~preset.overlay&&strcmp(preset.active,'GFP'));
assert(strcmp(preset.layers(2).color,'0.123456789 0.6 0.9'));
assert(strcmp(preset.styles(3).mode,'Contours')&&preset.styles(3).width==2.5);
assert(isempty(dir(fullfile(folder,'*.h5')))&&isempty(dir(fullfile(folder,'*.mat'))));

selectROI(2); extra=v.DisplayModel.Layers(2);
draft=v.annotationDraft('Cells'); draft.edit(1,'paint',[30 22],2,2,false);
v.contourChanged();
draftPixels=draft.Masks; undoCount=numel(draft.UndoStack);
v.Host.findCommand('Paste Display Preset').invoke();
layers=v.DisplayModel.Layers;
assert(isequal(layers(2),extra),'An unmatched layer changed.');
assert(~layers(4).visible&&isequal(layers(4).limits,[100 1000]));
assert(strcmp(layers(3).color,preset.layers(2).color)&&layers(3).opacity==.65&&isequal(layers(3).limits,[250 2000]));
assert(layers(1).opacity==.3&&isequal(v.DisplayModel.labelStyle(1),preset.styles(3)));
assert(strcmp(v.activeLayer(),'GFP')&&~overlay.Value);
assert(draft.Dirty&&numel(draft.UndoStack)==undoCount&&isequal(draft.Masks,draftPixels));
assert(isequal(v.DisplayModel.read(1,1),draft.read(1)),'The active draft was lost.');
frame=findall(v.Figure,'Tag','frame-number'); frame.Value=2; frame.ValueChangedFcn(frame,[]);
assert(~overlay.Value&&isequal(v.DisplayModel.Layers(3).limits,[250 2000]));

% Incompatible types are skipped; invalid files and no matches apply nothing.
bad=preset; bad.layers(1).kind='Labels'; bad.layers(1).color='Labels';
state=v.DisplayModel.Layers; report=v.DisplayModel.applyPreset(bad);
assert(isequal(report.incompatible,{'Phase'})&&isequal(v.DisplayModel.Layers(4),state(4)));
bad=preset; bad.layers(3).opacity=2; invalid(fullfile(folder,'invalid.json'),bad);
state=v.DisplayModel.Layers; assert(isempty(v.displayPreset('load',fullfile(folder,'invalid.json'))));
assert(isequal(v.DisplayModel.Layers,state));
bad=preset; for k=1:numel(bad.layers), bad.layers(k).name=['Unknown ' bad.layers(k).name]; end
bad.active=bad.layers(1).name; invalid(fullfile(folder,'missing.json'),bad);
assert(isempty(v.displayPreset('load',fullfile(folder,'missing.json')))&&isequal(v.DisplayModel.Layers,state));

% The native button opens the same actions, including in a floating document.
v.Host.show(); v.Host.focusWidget('Display'); drawnow;
button=findall(v.widgetFigure('Display'),'Tag','display-presets');
callback=button.ButtonPushedFcn; feval(callback{1},button,[],callback{2:end});
menu=button.ContextMenu; assert(strcmp(menu.Visible,'on')); menu.Visible='off';
item=findall(menu,'Text','Copy Display Preset'); callback=item.MenuSelectedFcn;
feval(callback{1},item,[],callback{2:end});
v.DisplayModel.setLimits(3,[0 300]); v.selectDisplayLayer('GFP');
report=v.displayPreset('load',saved); assert(numel(report.matched)==3);
v.openMovieExport(); job=v.MovieExport.makeJob(); views=job.frameViews(1,2);
expected=v.DisplayModel.separate(2,3);
assert(numel(views)==numel(expected));
% Frozen exporter uses the same intensity/contour settings after preset load.
actual=job.Entries(1).model.separate(2,3);
for k=1:numel(expected)
    assert(isequal(actual{k}.pixels,expected{k}.pixels)&&isequal(actual{k}.vectors,expected{k}.vectors));
end
v.closeMovieExport();
v.Host.setDocked('Display',false); drawnow;
callback=button.ButtonPushedFcn; feval(callback{1},button,[],callback{2:end});
assert(strcmp(menu.Visible,'on')); menu.Visible='off'; v.Host.setDocked('Display',true);
for k=1:2
    assert(isequal(p.fov.roi(k).image,before{k})&&isequal(p.fov.roi(k).display,metadata{k}));
end
selectROI(1); assert(isequal(v.DisplayModel.Layers(1).limits,[100 1000])&&~overlay.Value);
if ~isempty(preview), v.Host.focusWidget('Display'); drawnow; v.Host.capture(preview); end
draft.discard();
disp('Display presets passed: name mapping, exact colors, contours, JSON, native menus, floating UI, frame/tab persistence, export parity and unchanged pixels/drafts.');
    function selectROI(index)
        nodes=findall(tree,'Tag','roi-node'); node=nodes(arrayfun(@(n)n.UserData.roi==index,nodes));
        tree.SelectedNodes=node; tree.SelectionChangedFcn(tree,[]);
    end
end
function invalid(path,value)
fid=fopen(path,'w'); closer=onCleanup(@()fclose(fid)); fprintf(fid,'%s',jsonencode(value));
end
function closeViewer(v)
if ~isvalid(v), return; end
if ~isempty(v.Masks)
    for k=1:numel(v.Masks.Drafts), v.Masks.Drafts{k}.discard(); end
end
delete(v);
end
