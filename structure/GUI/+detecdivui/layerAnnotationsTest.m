function layerAnnotationsTest(preview)
%LAYERANNOTATIONSTEST Checking a mask selects it and opens a separate inspector.
if nargin<1, preview=''; end
folder=tempname; mkdir(folder); files=onCleanup(@()rmdir(folder,'s'));
r=roi('Cells',[1 1 60 48]); r.path=folder;
r.image=zeros(48,60,3,2,'uint16'); r.image(:,:,1,:)=150;
r.image(7:17,8:18,2,:)=1; r.image(26:38,30:44,2,:)=2;
r.image(15:25,35:47,3,:)=3;
r.channelid=1:3; r.display.channel={'Phase','HOCT','Cellpose'};
r.display.selectedchannel=[true false false]; r.display.indexed=[false true true];
r.display.rgb=ones(3,3); r.display.intensity=[1 1 1;0 0 0;0 0 0];
[model,report]=cellModel.fromLegacy(r,'Channels',{'HOCT','Cellpose'}); assert(report.validation.ok);
model.instances.track_id=uint64(model.instances.family_id)*100+uint64(model.instances.mask_label);
r.save([],false); r.load('Silent'); r.saveCellModel(model);
pixels=r.image; metadata=r.display; baseline=r.cellModel;
p=shallow(); p.io.file='Layer annotations'; p.fov.id='Position'; p.fov.roi=r;
v=detecdiv_ui(p,'Visible','off','DiscoverWorkspace',false,'LayoutFile','','AutoSaveLayout',false, ...
    'RecentProjectsFile','','RecentPipelinesFile','','RecentClassifiersFile','');
cleanup=onCleanup(@()delete(v));
tree=findall(v.widgetFigure('Projects'),'Tag','projects-tree'); tree.SelectedNodes=findall(tree,'Tag','roi-node');
tree.SelectionChangedFcn(tree,[]); v.Host.show(); v.Host.focusWidget('Display'); settle();
initial=v.Host.snapshot();
windows=matlab.internal.webwindowmanager.instance.windowList;
window=windows(find(arrayfun(@(w)contains(w.URL,v.Host.App.Tag),windows),1));
menus=timerfindall('Tag','DetecDivDockMenu'); if ~isempty(menus), stop(menus); end
assert(~v.Host.isWidgetVisible('Annotations'));
check(2); assert(strcmp(v.activeLayer(),'HOCT'));
assert(v.Host.Widgets.display.Showing&&v.Host.Widgets.objects.Showing);
assertBelow(v.Host.App.DocumentLayout);
assert(numel(v.Objects.ObjectsRows)==2&&isequal([v.Objects.ObjectsRows.track],uint64([101 102])));
assert(strcmp(v.Host.App.SelectedChild.tag,'display'),'Checking a mask stole focus from Display.');
check(3); assert(strcmp(v.activeLayer(),'Cellpose'));
assert(isscalar(v.Objects.ObjectsRows)&&v.Objects.ObjectsRows.track==203);
check(2); assert(strcmp(v.activeLayer(),'Cellpose')&&isscalar(v.Objects.ObjectsRows)); % Hiding another layer preserves selection.
check(1); check(1); assert(strcmp(v.activeLayer(),'Phase')&&isempty(v.Objects.ObjectsRows));
check(2); assert(strcmp(v.activeLayer(),'HOCT')&&numel(v.Objects.ObjectsRows)==2);
assert(isequal(r.image,pixels)&&isequal(r.display,metadata)&&isequal(r.cellModel,baseline));
for k=1:numel(v.Masks.Drafts), assert(~v.Masks.Drafts{k}.Dirty); end

% Model metadata is read without needing to activate a paint/edit draft.
v.Host.setWidgetVisible('Annotations',false); v.Masks.forgetCleanSource(r);
r.cellModel=[]; r.cellModelInfo=struct('loaded',false);
select(1); select(2);
assert(~v.Host.isWidgetVisible('Annotations')&&~v.Masks.Active);
assert(v.Objects.SelectedFamily==1&&numel(v.Objects.ObjectsRows)==2&&v.Objects.ObjectsRows(1).track==101);
check(2); check(2); assert(v.Host.isWidgetVisible('Annotations'));

% Legacy shared-tab layouts split once. A new explicitly saved custom stack
% remains user-controlled on subsequent restores.
record=v.Host.snapshot(); geometry=detecdivui.WorkspaceLayout.geometry(initial.layout.documentLayout);
at=detecdivui.WorkspaceLayout.tile(geometry,'workspace_display');
geometry.tileOccupancy(at).children(end+1).id='workspace_objects';
geometry.tileOccupancy(at).showingChildId='workspace_objects';
record.layout.documentLayout=geometry;
legacy=rmfield(record,'annotationsLayoutVersion'); file=fullfile(folder,'legacy-stacked.json'); writeJSON(file,legacy);
assert(v.Host.restoreLayout(file)); assertBelow(v.Host.App.DocumentLayout);
assert(v.Host.Widgets.display.Showing&&v.Host.Widgets.objects.Showing);
writeJSON(fullfile(folder,'custom-stacked.json'),record);
assert(v.Host.restoreLayout(fullfile(folder,'custom-stacked.json')));
layout=v.Host.App.DocumentLayout;
assert(detecdivui.WorkspaceLayout.tile(layout,'workspace_display')==detecdivui.WorkspaceLayout.tile(layout,'workspace_objects'));
v.Host.resetLayout(); v.Host.setWidgetVisible('Annotations',true); assertBelow(v.Host.App.DocumentLayout);
v.Host.saveLayout(fullfile(folder,'split.json')); assert(v.Host.restoreLayout(fullfile(folder,'split.json')));
assertBelow(v.Host.App.DocumentLayout);
if ~isempty(preview), v.Host.focusWidget('Display'); drawnow; v.Host.capture(preview); end
disp('Layer annotations passed: real checkbox selection, automatic tracks, separate panels, retained Display focus, nonmutating view, legacy layout migration and saved custom placement.');
    function check(index)
        browser(index,'input[type=checkbox]');
    end
    function select(index)
        browser(index,'.name');
    end
    function browser(index,selector)
        script="(()=>{const f=Array.from(document.querySelectorAll('iframe')).find(f=>f.src.includes('/layers.html'));"+ ...
            "if(!f?.contentDocument)return false;f.contentDocument.querySelectorAll("+jsonencode(selector)+")["+ ...
            (index-1)+"].click();return true;})()";
        assert(jsondecode(window.executeJS(char(script),5))); settle();
    end
end
function assertBelow(layout)
a=detecdivui.WorkspaceLayout.tile(layout,'workspace_display'); b=detecdivui.WorkspaceLayout.tile(layout,'workspace_objects');
assert(~isempty(a)&&~isempty(b)&&a~=b,'Annotations is still tabbed with Display.');
[ar,ac]=find(layout.tileCoverage==a); [br,bc]=find(layout.tileCoverage==b);
assert(max(ar)<min(br)&&isequal(unique(ac),unique(bc)),'Annotations is not directly below Display.');
end
function writeJSON(path,value)
fid=fopen(path,'w'); cleaner=onCleanup(@()fclose(fid)); fprintf(fid,'%s',jsonencode(value));
end
function settle()
drawnow; pause(.4); drawnow;
end
