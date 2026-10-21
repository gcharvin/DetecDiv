function tests=testCellModelCorrectBinaryFission
tests=functiontests(localfunctions);
end
function setupOnce(~)
detecdiv_setup_path;
end
function testContinuingParentBecomesTwoNewDaughters(testCase)
m=fixture(true);before=m;
[m,r]=cellModel.correctBinaryFission(m,1,2,1,[2 3]);
verifyEqual(testCase,r.daughter_track_ids,uint64([31 32]));
verifyEqual(testCase,m.instances.track_id,uint64([10;10;31;32;31;32]));
verifyEqual(testCase,m.instances.object_id,before.instances.object_id);
verifyEqual(testCase,m.instances.mask_label,before.instances.mask_label);
verifyEqual(testCase,m.relations.parent_track_id,uint64([10;10]));
verifyEqual(testCase,m.relations.event_frame,uint32([3;3]));
verifyTrue(testCase,annotationManager.validateParentage(m,1).valid);
end
function testExistingPairIsReplacedWithoutDuplicateLinks(testCase)
m=fixture(false);m=cellModel.setParentTrack(m,1,3,20,10);m=cellModel.setParentTrack(m,1,3,30,10);
[m,r]=cellModel.correctBinaryFission(m,1,2,1,[2 3]);
verifyEqual(testCase,r.replaced_parent_links,2);
verifyEqual(testCase,numel(m.relations.relation_id),2);
verifyEqual(testCase,sort(m.relations.child_track_id),uint64([31;32]));
end
function testLaterDescendantsFollowDaughterSegment(testCase)
m=fixture(true);
m.instances.object_id=[m.instances.object_id;uint64([7;8])];
m.instances.family_id=[m.instances.family_id;uint32([1;1])];
m.instances.frame=[m.instances.frame;uint32([5;5])];
m.instances.mask_label=[m.instances.mask_label;uint32([4;5])];
m.instances.track_id=[m.instances.track_id;uint64([40;50])];
m.instances.state_id=[m.instances.state_id;uint16([0;0])];
m=cellModel.setParentTrack(m,1,5,40,10);m=cellModel.setParentTrack(m,1,5,50,10);
[m,r]=cellModel.correctBinaryFission(m,1,2,1,[2 3]);
later=m.relations.event_frame==5;
verifyEqual(testCase,m.relations.parent_track_id(later),repmat(r.daughter_track_ids(1),2,1));
verifyTrue(testCase,annotationManager.validateParentage(m,1).valid);
end
function testSameDaughterRejectedWithoutInputMutation(testCase)
m=fixture(true);before=m;
verifyError(testCase,@()cellModel.correctBinaryFission(m,1,2,1,[2 2]),'cellModel:SameFissionDaughter');
verifyEqual(testCase,m,before);
end
function testMissingDaughterRejected(testCase)
verifyError(testCase,@()cellModel.correctBinaryFission(fixture(true),1,2,1,[2 9]),'cellModel:UnknownFissionDaughter');
end
function testBuddingFamilyUntouched(testCase)
m=fixture(true);m.provenance=rmfield(m.provenance,'family_division_modes');
verifyError(testCase,@()cellModel.correctBinaryFission(m,1,2,1,[2 3]),'cellModel:NotBinaryFission');
end
function testSeparatePredictionFamilyIsPreserved(testCase)
m=fixture(true);
m.families.family_id(2)=uint32(2);m.families.name{2}='prediction';
m.families.mask_provider{2}='prediction_mask';m.families.lineage_source{2}='model';
m.families.color_rgb(2,:)=[255 99 99];
names=fieldnames(m.instances);
for k=1:numel(names)
    values=m.instances.(names{k});
    if strcmp(names{k},'object_id'),values=values+uint64(6);end
    if strcmp(names{k},'family_id'),values(:)=uint32(2);end
    m.instances.(names{k})=[m.instances.(names{k});values];
end
before=m.instances.track_id(m.instances.family_id==2);
m=cellModel.correctBinaryFission(m,1,2,1,[2 3]);
verifyEqual(testCase,m.instances.track_id(m.instances.family_id==2),before);
verifyFalse(testCase,any(m.relations.family_id==2));
end
function testParentContinuingElsewhereRejected(testCase)
m=fixture(false);m.instances.track_id(2)=uint64(20);m.instances.track_id(4)=uint64(10);
verifyError(testCase,@()cellModel.correctBinaryFission(m,1,1,1,[1 99]),'cellModel:UnknownFissionDaughter');
% Select two genuine daughters while a third parent segment survives.
m=fixture(false);m.instances.track_id(5)=uint64(10);
verifyError(testCase,@()cellModel.correctBinaryFission(m,1,2,1,[2 3]),'cellModel:FissionParentContinues');
end
function m=fixture(continuing)
m=cellModel.create('fission-command');
m.families=struct('family_id',uint32(1),'name',{{'GT'}},'mask_provider',{{'gt_tracks'}}, ...
    'lineage_source',{{'human_review'}},'color_rgb',uint8([99 214 255]));
m.provenance.family_division_modes=struct('family_id',1,'mode','binary_fission');
m.instances.object_id=uint64((1:6)');m.instances.family_id=ones(6,1,'uint32');
m.instances.frame=uint32([1;2;3;4;3;4]);m.instances.mask_label=uint32([1;1;2;2;3;3]);
m.instances.track_id=uint64([10;10;20;20;30;30]);
if continuing,m.instances.track_id(3:4)=uint64(10);end
m.instances.state_id=zeros(6,1,'uint16');m=cellModel.normalize(m);
end
