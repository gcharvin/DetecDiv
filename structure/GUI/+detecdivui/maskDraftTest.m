function maskDraftTest()
%MASKDRAFTTEST Pixel parity, isolated edits, lifecycle/model sync and retry.
folder = tempname; mkdir(folder); clean = onCleanup(@()rmdir(folder,'s'));
r = roi('Masks',[1 1 24 24]); r.path = folder;
r.image = zeros(24,24,2,2,'uint16'); r.image(:,:,1,:) = 100;
r.image(4:12,4:12,2,:) = 1; r.image(7:9,7:9,2,:) = 0;
r.channelid = [1 2]; r.display.channel = {'BF','gt_cells'};
r.display.intensity = [1 1 1;0 0 0]; r.display.rgb = ones(2,3);
r.display.selectedchannel = [true true]; r.display.indexed = [false true];
r.display.alpha = [1 .4]; r.display.contour = [false false]; r.display.width = [1 1];
r.display.displaylim = repmat([0;1],1,2);
m = cellModel.create(r.id);
m.families = struct('family_id',uint32(1),'name',{{'GT'}},'mask_provider',{{'gt_cells'}}, ...
    'lineage_source',{{'human_review'}},'color_rgb',uint8([99 214 255]));
for f = 1:2, [m,~] = cellModel.syncFrame(m,1,f,r.image(:,:,2,f),'TrackPolicy','preserve_or_label'); end
r.save([],false); r.load('Silent'); r.saveCellModel(m);
spec = annotationManager.newSpec(); spec.id = 'test_annotation';
spec.components = annotationManager.newComponent('id','mask','kind','mask');
entry = annotationManager.newEntry(spec,2); entry.status = 'approved'; entry.approved_hash = 'old';
entry.review.frames = [true true]; entry.review.complete = true;
annotationManager.setEntry(r,spec,entry,'Save',true);
r.load('data','Silent');
pixels = r.image; model = r.cellModel; data = r.data;
for xy = {[1 1],[12 14],[24 24]}
    point = xy{1}; [x,y] = meshgrid(1:24,1:24);
    expected = r.image(:,:,2,1); disk = (x-point(1)).^2+(y-point(2)).^2 <= 3^2;
    expected(disk) = 8;
    actual = score_editMaskPlane('paint',r.image(:,:,2,1),point,8,3,true);
    assert(isequal(actual,expected));
end
d = detecdivui.MaskDraft(r,'gt_cells');
d.edit(1,'fill',[],1,3,false); assert(d.Dirty && d.Masks(8,8,1,1)==1);
assert(isequal(r.image,pixels) && isequal(r.cellModel,model) && isequal(r.data,data));
d.undo(); assert(~d.Dirty); d.redo(); assert(d.Dirty);
d.edit(1,'delete',[],1,3,false); assert(~any(d.read(1),'all'));
d.undo(); assert(d.Masks(8,8,1,1)==1);
d.save(); assert(~d.Dirty && r.image(8,8,2,1)==1 && r.image(8,8,2,2)==0);
assert(isequal(r.image(:,:,1,:),pixels(:,:,1,:)));
[manifest,~] = annotationManager.readManifest(r);
assert(strcmp(manifest.entries.status,'draft') && isempty(manifest.entries.approved_hash));
assert(~manifest.entries.review.frames(1) && manifest.entries.review.frames(2));
instance = cellModel.findInstance(r.cellModel,1,2,1);
original = cellModel.findInstance(model,1,2,1); assert(instance.track_id==original.track_id);
loaded = roi(r.id,r.value); loaded.path = folder; loaded.load('Data',false,'Silent');
assert(isequal(loaded.image,r.image));
before = r.image; d.edit(1,'paint',[20 20],2,2,false);
lock = System.IO.FileStream(fullfile(folder,['data_' r.id '.mat']), ...
    System.IO.FileMode.Open,System.IO.FileAccess.ReadWrite,System.IO.FileShare.None);
unlock = onCleanup(@()lock.Dispose());
failed = false;
try
    d.save();
catch
    failed = true;
end
assert(failed && d.Dirty && d.SaveFailed && isequal(r.image,before));
clear unlock;
d.save(); assert(~d.Dirty && ~d.SaveFailed && r.image(20,20,2,1)==2);
d.edit(2,'paint',[20 20],3,2,false); r.image(1,1,2,2)=5;
conflict = false;
try
    d.save();
catch err
    conflict = strcmp(err.identifier,'detecdivui:MaskConflict');
end
assert(conflict && d.Dirty); d.discard();
restored = detecdivui.MaskDraft(r,'gt_cells'); restored.edit(1,'paint',[20 4],4,2,false);
state = restored.recovery(); restored.discard(); restored.restore(state);
assert(restored.Dirty && restored.Masks(4,20,1,1)==4); restored.discard();
dual = roi('Dual',[1 1 8 8]); dual.path = folder;
dual.image = zeros(8,8,3,2,'uint16'); dual.channelid = [1 2 3];
dual.display.channel = {'BF','A','B'}; dual.display.indexed = [false true true];
dual.display.intensity = [1 1 1;0 0 0;0 0 0];
a = detecdivui.MaskDraft(dual,'A'); b = detecdivui.MaskDraft(dual,'B');
a.edit(1,'paint',[3 3],1,1,false); b.edit(2,'paint',[6 6],2,1,false);
a.save(); b.followSave(a); b.save();
assert(dual.image(3,3,2,1)==1 && dual.image(6,6,3,2)==2 && ~a.Dirty && ~b.Dirty);
disp('Mask draft test passed: Score brush parity, undo/redo, source isolation, H5/model/review save, partial-save retry and conflicts.');
end
