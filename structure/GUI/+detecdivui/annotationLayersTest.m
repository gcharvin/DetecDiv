function annotationLayersTest()
%ANNOTATIONLAYERSTEST Independent providers preserve identities and mask pixels.
folder=tempname; mkdir(folder); files=onCleanup(@()rmdir(folder,'s'));
r=roi('Layers',[1 1 12 14]); r.path=folder; r.image=zeros(14,12,2,2,'uint16');
r.image(:,:,1,:)=100; r.image(3:7,3:7,2,:)=1; r.channelid=[1 2];
r.display.channel={'Phase','Masks'}; r.display.intensity=[1 1 1;0 0 0]; r.display.indexed=[false true];
[model,~]=cellModel.fromLegacy(r,'Channels',{'Masks'});
[model,family]=cellModel.cloneFamily(model,1,'Alternative','Masks');
exact=uint64(9007199254740992)+uint64(1); model.instances.track_id(model.instances.family_id==family)=exact;
r.cellModel=model; r.save([],false); r.load('Silent'); r.saveCellModel(model);
pixels=r.image; display=r.display; original=r.cellModel;
draft=detecdivui.AnnotationLayerDraft(r,'Masks','KeepFamily',1);
assert(isequal(r.image,pixels)&&isequal(r.display,display)&&isequal(r.cellModel,original));
assert(numel(draft.Plan.changes)==1 && draft.Plan.changes.familyId==family);
layer=draft.Plan.changes.layer; draft.save(); assert(draft.Saved);
at=cellModel.familyIndex(r.cellModel,family); assert(strcmp(r.cellModel.families.mask_provider{at},layer));
assert(nnz(strcmp(r.cellModel.families.mask_provider,'Masks'))==1);
assert(isequal(r.image(:,:,r.findChannelID(layer),:),pixels(:,:,2,:)));
assert(isequal(r.image(:,:,r.findChannelID('Masks'),:),pixels(:,:,2,:)));
assert(isequal(r.cellModel.instances,original.instances) && isequal(r.cellModel.relations,original.relations));
assert(all(r.cellModel.instances.track_id(r.cellModel.instances.family_id==family)==exact));
loaded=roi(r.id,r.value); loaded.path=folder; loaded.load('Silent'); [stored,~]=loaded.loadCellModel();
assert(strcmp(stored.families.mask_provider{at},layer));
assert(isequal(loaded.image(:,:,loaded.findChannelID(layer),:),pixels(:,:,2,:)));
new=detecdivui.AnnotationLayerDraft(r,layer,'NewResult','Manual tracks'); new.save();
newId=new.Plan.changes.familyId; rows=r.cellModel.instances.family_id==newId;
assert(any(rows)&&all(r.cellModel.instances.track_id(rows)==0));
assert(nnz(strcmp(r.cellModel.families.mask_provider,new.Plan.changes.layer))==1);
assert(detecdivui.MaskDraft.isLabel(r,new.Plan.changes.layer));
% A failure after H5 writes keeps canonical RAM intact and can be retried.
pending=detecdivui.AnnotationLayerDraft(r,layer,'NewResult','Retry tracks'); before=r.image; beforeModel=r.cellModel;
lock=System.IO.FileStream(fullfile(folder,['objects_' r.id '.h5']), ...
    System.IO.FileMode.Open,System.IO.FileAccess.ReadWrite,System.IO.FileShare.None);
unlock=onCleanup(@()lock.Dispose()); failed=false;
try, pending.save(); catch, failed=true; end
assert(failed && pending.SaveFailed && isequal(r.image,before) && isequal(r.cellModel,beforeModel));
clear unlock; pending.save(); assert(pending.Saved && ~pending.SaveFailed);
assert(all(r.cellModel.instances.track_id(r.cellModel.instances.family_id==pending.Plan.changes.familyId)==0));
% New geometry on a later frame does not inherit another frame's ID.
m=cellModel.create('Policy'); m.families=original.families;
m=cellModel.syncFrame(m,1,1,uint16(ones(2)),'TrackPolicy','mask_label');
m=cellModel.syncFrame(m,1,2,uint16(ones(2)),'TrackPolicy','preserve_frame_or_unassigned');
assert(cellModel.findInstance(m,1,1,1).track_id==1 && cellModel.findInstance(m,1,2,1).track_id==0);
fprintf('Annotation layers passed: explicit copies, independent providers, unchanged IDs/masks, disk reload and unassigned new regions.\n');
end
