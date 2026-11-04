function trackDraftTest()
%TRACKDRAFTTEST Score model contracts, shared undo and explicit persistence.
folder = tempname; mkdir(folder); clean = onCleanup(@()rmdir(folder,'s'));
r = roi('Tracks',[1 1 30 30]); r.path = folder;
r.image = zeros(30,30,2,4,'uint16'); r.image(:,:,1,:) = 100;
r.image(3:8,3:8,2,:) = 1; r.image(3:8,20:25,2,:) = 3;
r.image(18:24,3:8,2,2) = 2; r.image(18:24,4:9,2,3:4) = 4;
r.channelid = [1 2]; r.display.channel = {'BF','Mask'};
r.display.indexed = [false true]; r.display.intensity = [1 1 1;0 0 0];
r.display.rgb = ones(2,3); r.display.selectedchannel = [true true];
[m,report] = cellModel.fromLegacy(r,'Channels',{'Mask'}); assert(report.validation.ok);
m.instances.track_id = uint64(10)*uint64(m.instances.mask_label);
[m,~] = cellModel.setParentTrack(m,1,2,uint64(20),uint64(10));
r.save([],false); r.load('Silent'); r.saveCellModel(m);
spec = annotationManager.newSpec(); spec.id = 'tracking';
spec.components = annotationManager.newComponent('id','tracking','kind','tracking');
entry = annotationManager.newEntry(spec,4); entry.status = 'approved'; entry.approved_hash = 'old';
entry.review.frames = true(1,4); entry.review.complete = true;
annotationManager.setEntry(r,spec,entry,'Save',true); r.load('data','Silent');
source = r.image; model = r.cellModel;
d = detecdivui.MaskDraft(r,'Mask');
report = d.editTrack('assign',1,3,4,uint64(20),'to-last');
assert(isequal(report.frames,[3 4]) && strcmp(report.scope,'to-last'));
assert(all(d.WorkingModel.instances.track_id(d.WorkingModel.instances.mask_label == 4)==20));
assert(d.Dirty && isequal(r.cellModel,model) && isequal(r.image,source));
d.undo(); assert(~d.Dirty && isequal(d.WorkingModel,model)); d.redo();
before = d.WorkingModel; count = numel(d.UndoStack); conflict = false;
try
    d.editTrack('assign',1,1,1,uint64(30),'frame');
catch err
    conflict = strcmp(err.identifier,'cellModel:TrackFrameConflict');
end
assert(conflict && isequal(d.WorkingModel,before) && numel(d.UndoStack)==count);
d.editTrack('swap',1,2,2,uint64(30),'all');
assert(d.WorkingModel.relations.child_track_id == 30);
d.editTrack('unparent',1,2,2,0,'frame'); assert(isempty(d.WorkingModel.relations.relation_id));
d.undo(); assert(d.WorkingModel.relations.parent_track_id==10); d.redo();
big = detecdivui.trackId('9007199254740993');
d.editTrack('assign',1,1,3,big,'all');
assert(all(d.WorkingModel.instances.track_id(d.WorkingModel.instances.mask_label==3)==big));
assert(detecdivui.trackId('18446744073709551615')==intmax('uint64'));
h5 = fullfile(folder,['im_' r.id '.h5']); stamp = dir(h5);
d.save(); after = dir(h5);
assert(~d.Dirty && stamp.datenum==after.datenum && stamp.bytes==after.bytes && isequal(r.image,source));
loaded = roi(r.id,r.value); loaded.path = folder; [saved,report] = loaded.loadCellModel();
assert(report.validation.ok && isequal(saved.instances.track_id,r.cellModel.instances.track_id));
[manifest,~] = annotationManager.readManifest(r); assert(strcmp(manifest.entries.status,'draft'));
assert(~any(manifest.entries.review.frames));
before = d.WorkingModel; masks = d.Masks;
d.editTrack('delete',1,2,2,0,'all');
assert(~any(d.Masks(:,:,1,2)==2,'all') && ~any(d.Masks(:,:,1,3:4)==4,'all'));
d.undo(); assert(isequal(d.Masks,masks) && isequal(d.WorkingModel,before)); d.redo();
d.save(); assert(~any(r.image(:,:,2,2)==2,'all') && isequal(r.image(:,:,1,:),source(:,:,1,:)));
% Pixel and model operations have one chronology across Contours/Tracks.
d.edit(1,'paint',[15 15],5,2,false);
d.editTrack('new',1,1,5,0,'frame'); assert(d.Dirty);
d.undo(); assert(d.Masks(15,15,1,1)==5); d.undo(); assert(~d.Dirty);
legacy = roi('Legacy',[1 1 30 30]); legacy.path = folder; legacy.image = source;
legacy.display = r.display; legacy.channelid = [1 2];
imported = detecdivui.MaskDraft(legacy,'Mask'); imported.importLegacy();
assert(imported.Dirty && ~isfield(legacy.cellModel,'schema_version'));
state = imported.recovery(); imported.discard(); imported.restore(state);
imported.undo(); % Recovery intentionally starts a new history.
assert(imported.Dirty); imported.save(); assert(legacy.hasCellModel());
bare = roi('Bare',[1 1 30 30]); bare.path = folder; bare.image = source;
bare.display = r.display; bare.channelid = [1 2];
bare.save([],false); bare.load('Silent'); bare.saveCellModel(cellModel.normalize(model,bare.id));
noManifest = detecdivui.MaskDraft(bare,'Mask'); noManifest.editTrack('new',1,1,3,0,'frame');
stamp = dir(fullfile(folder,'im_Bare.h5')); noManifest.save(); after = dir(fullfile(folder,'im_Bare.h5'));
assert(~noManifest.Dirty && stamp.datenum==after.datenum);
% Every family referencing one physical provider sees the same mask edits.
multi = roi('Families',[1 1 30 30]); multi.path = folder; multi.image = source;
multi.display = r.display; multi.channelid = [1 2];
two = cellModel.normalize(model,multi.id);
two.families.family_id(2,1) = uint32(2); two.families.name{2,1} = 'Alternate';
two.families.mask_provider{2,1} = 'Mask'; two.families.lineage_source{2,1} = '';
two.families.color_rgb(2,:) = uint8([255 100 0]);
for frame = 1:4, [two,~] = cellModel.syncFrame(two,2,frame,source(:,:,2,frame)); end
multi.saveCellModel(two);
families = detecdivui.MaskDraft(multi,'Mask'); families.edit(1,'delete',[],3,1,false);
preview = families.previewModel();
assert(isempty(cellModel.findInstance(preview,1,1,3)) && isempty(cellModel.findInstance(preview,2,1,3)));
families.undo(); families.editTrack('assign',2,1,1,uint64(99),'frame');
preview = families.previewModel(); first = cellModel.findInstance(preview,1,1,1);
second = cellModel.findInstance(preview,2,1,1); assert(first.track_id==10 && second.track_id==99);
families.discard();
% Binary fission keeps Score's immediately-preceding-parent convention.
fission = roi('Fission',[1 1 30 30]); fission.path = folder;
fission.image = zeros(30,30,2,4,'uint16'); fission.channelid = [1 2]; fission.display = r.display;
fission.image(3:8,3:8,2,1:2) = 1;
fission.image(3:8,3:8,2,3:4) = 2; fission.image(3:8,20:25,2,3:4) = 3;
[binary,~] = cellModel.fromLegacy(fission,'Channels',{'Mask'});
binary.instances.track_id = uint64(10)*uint64(binary.instances.mask_label);
binary.provenance.family_division_modes = struct('family_id',1,'mode','binary_fission');
fission.saveCellModel(binary); division = detecdivui.MaskDraft(fission,'Mask');
division.editTrack('parent',1,4,2,uint64(10),'frame');
division.editTrack('parent',1,4,3,uint64(10),'frame');
assert(all(division.WorkingModel.relations.event_frame==3));
segments = cellModelLineageSegments(division.previewModel(),1,3,division.Masks,true);
assert(isscalar(segments) && isequal(segments.siblingTracks,uint64([20 30])));
before = division.WorkingModel; rejected = false;
try
    division.editTrack('parent',1,4,2,uint64(30),'frame');
catch err
    rejected = strcmp(err.identifier,'cellModel:InvalidFissionParent');
end
assert(rejected && isequal(before,division.WorkingModel)); division.discard();
% Committing another provider cannot leave a redo of an obsolete whole model.
pair = roi('Providers',[1 1 8 8]); pair.path = folder;
pair.image = zeros(8,8,2,2,'uint16'); pair.image(2:5,2:5,:,:) = 1;
pair.channelid = [1 2]; pair.display.channel = {'A','B'};
pair.display.indexed = [true true]; pair.display.intensity = zeros(2,3);
[paired,~] = cellModel.fromLegacy(pair); pair.save([],false); pair.load('Silent'); pair.saveCellModel(paired);
a = detecdivui.MaskDraft(pair,'A'); b = detecdivui.MaskDraft(pair,'B');
b.editTrack('assign',2,1,1,uint64(22),'frame'); b.undo(); assert(~b.Dirty && ~isempty(b.RedoStack));
a.editTrack('assign',1,1,1,uint64(11),'frame'); a.save(); b.followSave(a); b.redo();
kept = cellModel.findInstance(b.WorkingModel,1,1,1);
assert(kept.track_id==11 && isempty(b.RedoStack) && ~b.Dirty);
disp('Track draft test passed: scoped reassignment/conflicts, swaps/links, uint64 IDs, model-only saves, track deletion, shared undo and explicit legacy import.');
end
