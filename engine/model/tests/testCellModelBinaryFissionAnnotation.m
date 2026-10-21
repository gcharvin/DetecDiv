function tests=testCellModelBinaryFissionAnnotation
tests=functiontests(localfunctions);
end
function setupOnce(~)
root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(genpath(root));
end
function testFissionRelationsCanBeEditedAndValidated(testCase)
m=fixture();
[m,~]=cellModel.setParentTrack(m,1,4,20,10);
[m,~]=cellModel.setParentTrack(m,1,4,30,10);
verifyEqual(testCase,m.relations.event_frame,uint32([3;3]));
report=annotationManager.validateParentage(m,1);
verifyTrue(testCase,report.valid);
e=cellModel.parentageEvidence(m,1);
verifyTrue(testCase,all([e.static_parentage_eligible]));
verifyFalse(testCase,any([e.parent_present_at_event]));
end
function testSingleDaughterIsIncomplete(testCase)
m=fixture();m=cellModel.setParentTrack(m,1,3,20,10);
report=annotationManager.validateParentage(m,1);
verifyFalse(testCase,report.valid);
verifyEqual(testCase,report.issues(1).code,'invalid_binary_fission');
end
function testContinuingParentIsRejected(testCase)
m=fixture();m.instances.frame(2)=uint32(3);
verifyError(testCase,@()cellModel.setParentTrack(m,1,3,20,10),'cellModel:InvalidFissionParent');
end
function testBuddingDefaultRemainsStrict(testCase)
m=fixture();m.provenance=rmfield(m.provenance,'family_division_modes');
verifyEqual(testCase,cellModel.divisionMode(m,1),'budding');
verifyError(testCase,@()cellModel.setParentTrack(m,1,3,20,10),'cellModel:ParentAbsentAtChildBirth');
end
function testTopologySurvivesHdf5RoundTrip(testCase)
m=fixture();file=[tempname '.h5'];cleanup=onCleanup(@()delete(file)); %#ok<NASGU>
cellModel.writeH5(file,m);copy=cellModel.readH5(file);
verifyEqual(testCase,cellModel.divisionMode(copy,1),'binary_fission');
end
function m=fixture()
m=cellModel.create('fission-review');
m.families.family_id=uint32(1);m.families.name={'draft'};
m.families.mask_provider={'draft_mask'};m.families.lineage_source={'AI_preannotation'};
m.families.color_rgb=uint8([99 214 255]);
m.provenance.family_division_modes=struct('family_id',1,'mode','binary_fission');
m.instances.object_id=uint64((1:6)');m.instances.family_id=ones(6,1,'uint32');
m.instances.frame=uint32([1;2;3;4;3;4]);m.instances.track_id=uint64([10;10;20;20;30;30]);
m.instances.mask_label=uint32([1;1;2;2;3;3]);m.instances.state_id=zeros(6,1,'uint16');
m=cellModel.normalize(m);
end
