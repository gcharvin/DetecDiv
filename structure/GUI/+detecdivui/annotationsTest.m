function annotationsTest(preview)
%ANNOTATIONSTEST Shared layers are explicit; semantic GT uses the same editor.
if nargin<1, preview=''; end
folder=tempname; mkdir(folder); files=onCleanup(@()rmdir(folder,'s'));
c=classi(folder,'Semantic',1); c.classifierPkg='deeplab_pixel_classification';
c.category={'Pixel'}; c.classes={'Background','Cell'}; c.channelName={'Phase'};
r=roi('Training ROI',[1 1 24 28]); r.path=c.path;
r.image=repmat(uint16(100),28,24,1,2); r.channelid=1; r.display.channel={'Phase'};
r.save(); c.roi=r; c.trainingset=1;
v=detecdiv_ui([],'Visible','off','DiscoverWorkspace',false,'LayoutFile','', ...
    'AutoSaveLayout',false,'RecentProjectsFile','','RecentPipelinesFile','','RecentClassifiersFile','');
cleanup=onCleanup(@()closeViewer(v)); v.Classifiers.add(c);
v.Classifiers.setMode('Edit'); assert(v.Classifiers.initializeGT(c,1,'Blank GT'));
spec=annotationManager.specForClassifier(c); gt=spec.components(1).groundTruth.channel;
target=v.annotationTarget(gt); assert(target.semantic && target.editable && isequal(target.classes,c.classes));
v.openMasksTool(); assert(v.Masks.Active);
palette=findall(v.widgetFigure('Annotations'),'Tag','mask-class');
assert(strcmp(palette.Visible,'on') && isequal(palette.ItemsData,[0 1 2]));
assert(strcmp(palette.Items{1},'Unlabeled') && strcmp(palette.Items{3},'Cell'));
assert(strcmp(palette.Parent.Parent.Scrollable,'on'));
assert(findall(v.widgetFigure('Annotations'),'Tag','mask-overwrite').Value);
assert(strcmp(findall(v.widgetFigure('Annotations'),'Tag','mask-provider').Visible,'off'));
palette.Value=2; palette.ValueChangedFcn(palette,[]);
assert(findall(v.widgetFigure('Annotations'),'Tag','mask-label').Value==2);
d=v.Masks.current(); v.Masks.assertEditable(d,false);
d.edit(1,'paint',[10 12],2,2,true); v.contourChanged(); assert(d.Dirty);
v.Masks.action('undo'); assert(~d.Dirty);
v.Masks.action('redo'); assert(d.Dirty);
v.Masks.action('save'); assert(~d.Dirty && r.image(12,10,r.findChannelID(gt),1)==2);
v.openTracksTool(); assert(isempty(v.Tracks)||~v.Tracks.Active);
v.openAnnotations();
assert(strcmp(v.Host.Widgets.objects.Title,'Annotations'));
assert(strcmp(findall(v.widgetFigure('Annotations'),'Tag','objects-tracks').Enable,'off'));
table=findall(v.widgetFigure('Annotations'),'Tag','objects-table');
assert(any(strcmp(table.Data(:,1),'Cell')));
% Classifier predictions cannot be painted, even while GT is in Edit.
prediction=spec.components(1).prediction.channel;
r.addChannel(zeros(28,24,1,2,'uint16'),prediction,[1 1 1],[0 0 0]);
r.save({prediction},false); r.load('Silent'); v.annotationMetadataSaved(r); v.annotationSaved(r);
v.selectDisplayLayer(prediction); assert(~v.annotationLayerEditable(prediction));
v.openMasksTool(); assert(~v.Masks.Active);
v.selectDisplayLayer(gt); v.openMasksTool(); assert(v.Masks.Active);
v.Classifiers.setMode('Review'); assert(~v.Masks.Active && ~v.annotationLayerEditable(gt));
if ~isempty(preview)
    v.Classifiers.setMode('Edit'); v.selectDisplayLayer(gt); v.openMasksTool();
    v.Host.focusWidget('Annotations'); v.Host.show(); drawnow; pause(.3); v.Host.capture(preview);
end
fprintf('Annotations passed: semantic class palette, shared draft/history/save, classifier Review/Edit and prediction protection, flat target selection and widget title.\n');
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
