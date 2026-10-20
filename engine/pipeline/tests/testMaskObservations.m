function tests=testMaskObservations
tests=functiontests(localfunctions);
end

function setupOnce(t)
root=fileparts(fileparts(mfilename('fullpath')));
t.TestData.oldPath=path;
addpath(fullfile(root,'templates'));
end

function teardownOnce(t)
path(t.TestData.oldPath);
end

function testRepeatedMaskLabelGetsDistinctObservationIdentities(t)
[r,cleanup]=fixture(); %#ok<ASGLU>
out=detecdivMaskObservations(context(r));
verifyEqual(t,out.roiList,r);
m=r.loadCellModel();
verifyEqual(t,m.instances.frame,uint32([1;1;2;2]));
verifyEqual(t,m.instances.mask_label,uint32([7;9;7;12]));
verifyEqual(t,numel(unique(m.instances.track_id)),4);
verifyNotEqual(t,m.instances.track_id(1),m.instances.track_id(3));
verifyFalse(t,any(m.instances.track_id==uint64(m.instances.mask_label)));
verifyEmpty(t,m.relations.relation_id);
verifyTrue(t,all(m.instances.state_id==0));
verifyEqual(t,m.provenance.mask_observation_sources.identity_policy,'unique_per_observation');
verifyTrue(t,cellModel.validate(m).ok);
end

function testIdenticalRerunDoesNotWriteAndSurvivesDiskRoundTrip(t)
[r,cleanup]=fixture(); %#ok<ASGLU>
detecdivMaskObservations(context(r));
file=cellModel.pathForROI(r); before=readBytes(file);
r.cellModel=struct(); r.cellModelInfo=struct('loaded',false);
detecdivMaskObservations(context(r));
verifyEqual(t,readBytes(file),before);
verifyFalse(t,isfile([file '.bak']));
end

function testPixelChangesRejectedEvenWhenLabelSetIsUnchanged(t)
[r,cleanup]=fixture(); %#ok<ASGLU>
detecdivMaskObservations(context(r));
file=cellModel.pathForROI(r); before=readBytes(file);
r.image(1,1,1,1)=0;
verifyError(t,@()detecdivMaskObservations(context(r)), ...
    'detecdivMaskObservations:ExistingFamily');
verifyEqual(t,readBytes(file),before);
end

function testForeignFamilyAndAlteredIdentityAreRejected(t)
[r,cleanup]=fixture(); %#ok<ASGLU>
m=cellModel.create(r.id);
m.families.family_id=uint32(1); m.families.name={'observations'};
m.families.mask_provider={'mask'}; m.families.lineage_source={'foreign'};
m.families.color_rgb=uint8([1 2 3]); r.saveCellModel(m);
verifyError(t,@()detecdivMaskObservations(context(r)), ...
    'detecdivMaskObservations:ExistingFamily');
ctx=context(r); ctx.params.familyName='fresh';
detecdivMaskObservations(ctx);
m=r.loadCellModel(); m.instances.track_id(1)=uint64(99); r.saveCellModel(m);
verifyError(t,@()detecdivMaskObservations(ctx), ...
    'detecdivMaskObservations:ExistingFamily');
end

function testOwnedFamilyWithStateLineageOrCensoringIsRejected(t)
for annotation={'state','lineage','censoring'}
    [r,cleanup]=fixture(); %#ok<ASGLU>
    detecdivMaskObservations(context(r)); m=r.loadCellModel();
    switch annotation{1}
        case 'state'
            m.states.state_id=uint16(1); m.states.name={'reviewed'};
            m.states.color_rgb=uint8([1 2 3]); m.instances.state_id(1)=uint16(1);
        case 'lineage'
            m.relations.relation_id=uint64(1); m.relations.family_id=uint32(1);
            m.relations.parent_track_id=m.instances.track_id(1);
            m.relations.child_track_id=m.instances.track_id(2);
            m.relations.event_frame=uint32(1); m.relations.type_id=uint8(1);
            m.relations.confidence=single(1);
        case 'censoring'
            m.censoring.censor_id=uint64(1); m.censoring.family_id=uint32(1);
            m.censoring.track_id=m.instances.track_id(1);
            m.censoring.frame_start=uint32(1); m.censoring.frame_end=uint32(1);
            m.censoring.scope_flags=cellModel.censorScope('all');
            m.censoring.reason_id=uint16(1); m.censoring.source_id=uint8(1);
    end
    r.saveCellModel(m);
    verifyError(t,@()detecdivMaskObservations(context(r)), ...
        'detecdivMaskObservations:ExistingFamily');
    clear cleanup;
end
end

function testOtherFamiliesAndAnnotationsArePreserved(t)
[r,cleanup]=fixture(); %#ok<ASGLU>
m=cellModel.create(r.id);
m.families.family_id=uint32(8); m.families.name={'reference'};
m.families.mask_provider={'other_mask'}; m.families.lineage_source={'human'};
m.families.color_rgb=uint8([1 2 3]);
m.instances=struct('object_id',uint64([20;21]),'family_id',uint32([8;8]), ...
    'frame',uint32([1;1]),'mask_label',uint32([10;11]), ...
    'track_id',uint64([70;71]),'state_id',uint16([0;0]));
m.relations=struct('relation_id',uint64(4),'family_id',uint32(8), ...
    'parent_track_id',uint64(70),'child_track_id',uint64(71), ...
    'event_frame',uint32(1),'type_id',uint8(1),'confidence',single(1));
m.provenance.user_note='Keep this annotation'; r.saveCellModel(m);
detecdivMaskObservations(context(r)); after=r.loadCellModel();
verifyEqual(t,after.relations,m.relations);
verifyEqual(t,after.instances.track_id(after.instances.family_id==8),m.instances.track_id);
verifyEqual(t,after.provenance.user_note,m.provenance.user_note);
verifyEqual(t,after.families.lineage_source{1},'human');
verifyGreaterThan(t,min(after.instances.track_id(after.instances.family_id==9)),uint64(71));
end

function testFrameSubsetIsExplicitAndChangedSelectionRejected(t)
[r,cleanup]=fixture(); %#ok<ASGLU>
ctx=context(r); ctx.sel.frames=2;
detecdivMaskObservations(ctx); m=r.loadCellModel();
verifyEqual(t,m.instances.frame,uint32([2;2]));
verifyEqual(t,m.provenance.mask_observation_sources.source_frames_one_based,2);
verifyError(t,@()detecdivMaskObservations(context(r)), ...
    'detecdivMaskObservations:ExistingFamily');
end

function testAllRoisValidatedBeforeFirstSidecarWrite(t)
[a,cleanupA]=fixture(); [b,cleanupB]=fixture(); %#ok<ASGLU>
b.id='invalid'; b.image=double(b.image); b.image(1,1,1,1)=0.5;
ctx=context([a b]);
verifyError(t,@()detecdivMaskObservations(ctx),'detecdivMaskObservations:MaskPixels');
verifyFalse(t,isfile(cellModel.pathForROI(a)));
verifyFalse(t,isfile(cellModel.pathForROI(b)));
end

function testResidentPixelsUsedInsteadOfDiskCopy(t)
[r,cleanup]=fixture(); %#ok<ASGLU>
r.save;
r.image(1,1,1,1)=uint16(15);
resident=r.image;
detecdivMaskObservations(context(r)); m=r.loadCellModel();
verifyTrue(t,any(m.instances.mask_label==15));
verifyEqual(t,r.image,resident);
end

function testMissingPixelsLoadedFromScalarMaskChannel(t)
[r,cleanup]=fixture(); %#ok<ASGLU>
r.save;
r.image=[];
detecdivMaskObservations(context(r));
m=r.loadCellModel(); verifyEqual(t,numel(m.instances.object_id),4);
end

function testDirectDryRunAndDeferredGuardHaveNoWrites(t)
[r,cleanup]=fixture(); %#ok<ASGLU>
ctx=context(r); ctx.dryRun=true;
verifyEqual(t,detecdivMaskObservations(ctx),ctx);
verifyFalse(t,isfile(cellModel.pathForROI(r)));
ctx=rmfield(ctx,'dryRun'); ctx.io.saveMode='defer';
ctx.params.requireImmediatePersistence=true;
verifyError(t,@()detecdivMaskObservations(ctx), ...
    'detecdivMaskObservations:DeferredImages');
verifyFalse(t,isfile(cellModel.pathForROI(r)));
end

function testInvalidFramesAndEmptyMasksRejected(t)
for frames={[0 1],[2 1],[1 3],1.5,3}
    [r,cleanup]=fixture(); %#ok<ASGLU>
    ctx=context(r); ctx.sel.frames=frames{1};
    verifyError(t,@()detecdivMaskObservations(ctx),'detecdivMaskObservations:Frames');
    verifyFalse(t,isfile(cellModel.pathForROI(r)));
    clear cleanup;
end
[r,cleanup]=fixture(); %#ok<ASGLU>
r.image(:)=0;
verifyError(t,@()detecdivMaskObservations(context(r)), ...
    'detecdivMaskObservations:NoObservations');
end

function [r,cleanup]=fixture()
folder=tempname; mkdir(folder);
cleanup=onCleanup(@()rmdir(folder,'s'));
r=roi('observation_test',[1 1 3 3]); r.path=folder;
r.image=zeros(3,3,1,2,'uint16');
r.image(:,:,1,1)=uint16([7 7 0;0 9 9;0 0 0]);
r.image(:,:,1,2)=uint16([7 7 0;0 12 12;0 0 0]);
r.channelid=1; r.display.channel={'mask'};
r.display.indexed=true; r.display.intensity=[0 0 0];
r.display.rgb=[1 1 1]; r.display.selectedchannel=true;
end

function ctx=context(r)
ctx=struct('roiList',r,'params',struct('maskChannelName','mask','familyName','observations'));
end

function bytes=readBytes(file)
fid=fopen(file,'rb'); cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
bytes=fread(fid,Inf,'*uint8');
end
