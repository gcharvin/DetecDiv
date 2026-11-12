function widgetPagesTest(preview)
%WIDGETPAGESTEST Flat dockable widgets and contextual tools retain their drafts.
if nargin<1, preview=''; end
folder=tempname; mkdir(folder); files=onCleanup(@()rmdir(folder,'s'));
imwrite(uint16(magic(64)),fullfile(folder,'raw.tif'));
p=shallow(); p.io.file='Flat widgets'; p.fov.id='Position'; p.fov.channel={'Phase'};
p.fov.srcpath={folder}; p.fov.srclist={dir(fullfile(folder,'raw.tif'))}; p.fov.frames=1;
r=roi('Cells',[4 5 32 32]); r.path=folder; r.image=zeros(32,32,2,2,'uint16');
r.image(:,:,1,:)=100; r.image(6:12,6:12,2,:)=1; r.channelid=[1 2];
r.display.channel={'Phase','Mask'}; r.display.indexed=[false true];
r.display.intensity=[1 1 1;0 0 0]; p.fov.roi=r; original=r.image;
v=detecdiv_ui(p,'Visible','off','DiscoverWorkspace',false,'LayoutFile','','AutoSaveLayout',false, ...
    'RecentProjectsFile','','RecentPipelinesFile','','RecentClassifiersFile','');
cleanup=onCleanup(@()closeViewer(v));
display=v.widgetFigure('Display'); assertFlat(display);
layers=findall(display,'Tag','layers'); assert(isempty(ancestor(layers,'uitab')));
base=findall(display,'Tag','display-page'); assert(strcmp(base.Visible,'on'));
v.loadCurrentImage(); v.Host.findCommand('Define ROIs...').invoke();
assistant=v.ROIs; assistant.addRectangle([3 4 10 12]); assertFlat(display);
page=findall(display,'Tag','roi-page'); assert(strcmp(page.Visible,'on') && strcmp(base.Visible,'off'));
mode=findall(display,'Tag','roi-mode'); assert(isempty(ancestor(mode,'uitab')));
back=findall(display,'Tag','roi-done'); back.ButtonPushedFcn(back,[]);
assert(strcmp(page.Visible,'off') && strcmp(base.Visible,'on') && isequal(layers,findall(display,'Tag','layers')));
v.Host.findCommand('Define ROIs...').invoke(); assert(v.ROIs==assistant && isequal(assistant.Rects,[3 4 10 12]));
shapes=findall(v.roiAxes(),'Tag','roi-draft-shape');
assert(isscalar(shapes),'ROI draft should have one shape; found %d, image count %d, rectangles %d, context %s.', ...
    numel(shapes),numel(findall(v.roiAxes(),'Type','image')),size(assistant.Rects,1), ...
    findall(display,'Tag','roi-status').Text);
back.ButtonPushedFcn(back,[]);
tree=findall(v.widgetFigure('Projects'),'Tag','projects-tree');
tree.SelectedNodes=findall(tree,'Tag','roi-node'); tree.SelectionChangedFcn(tree,[]);
v.selectDisplayLayer('Mask');
v.openObjects(); objects=v.widgetFigure('Objects'); assertFlat(objects);
paint=findall(objects,'Tag','objects-contours');
assert(~paint.Value && strcmp(paint.Enable,'on') && isempty(v.Masks));
paint.Value=true; paint.ValueChangedFcn(paint,[]);
assert(paint.Value && v.Masks.Active);
browser=findall(objects,'Tag','objects-page'); contours=findall(objects,'Tag','mask-page');
assert(strcmp(browser.Visible,'off') && strcmp(contours.Visible,'on'));
draft=v.Masks.current(); draft.edit(1,'paint',[18 19],2,1,false); v.contourChanged();
paint.Value=false; paint.ValueChangedFcn(paint,[]);
assert(~paint.Value && ~v.Masks.Active && strcmp(browser.Visible,'on') && strcmp(contours.Visible,'off') && draft.Dirty);
v.openTracksTool(); assertFlat(objects);
tracks=findall(objects,'Tag','tracks-page'); assert(strcmp(tracks.Visible,'on') && strcmp(browser.Visible,'off'));
assert(v.Tracks.current()==draft);
back=findall(objects,'Tag','tracks-done'); back.ButtonPushedFcn(back,[]);
assert(strcmp(tracks.Visible,'off') && strcmp(browser.Visible,'on') && draft.Dirty);
v.Host.setDocked('Objects',false); v.Host.setDocked('Objects',true);
v.openContourTool(); assert(v.Masks.current()==draft && strcmp(contours.Visible,'on')); assertFlat(objects);
assert(paint.Value);
v.closeContourTool(); assert(~paint.Value);
draft.discard(); v.contourChanged(); assert(isequal(r.image,original));
if ~isempty(preview)
    v.Host.focusWidget('Display'); v.Host.show(); drawnow; pause(.3); v.Host.capture(preview);
end
fprintf('Widget pages passed: no nested visible tabs, flat controls, contextual back actions, shared drafts and docking.\n');
end
function assertFlat(figure)
assert(isempty(findall(figure,'Type','uitabgroup','Visible','on')),'A nested tab strip is visible.');
end
function closeViewer(v)
if ~isvalid(v), return; end
if ~isempty(v.Masks) && isvalid(v.Masks)
    for k=1:numel(v.Masks.Drafts)
        d=v.Masks.Drafts{k}; if d.Dirty && ~d.SaveFailed, d.discard(); end
    end
end
delete(v);
end
