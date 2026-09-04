function tests = testCellLatentSignalGroundTruth
tests=functiontests(localfunctions);
end

function testClassificationAndRegressionObjectGroundTruth(testCase)
[r,model]=fixtureRoi();
classDef=cellLatentModel.signal.definition('TF localization','classification', ...
    'Channels','GFP','Family','cells','Classes',3);
spec=cellLatentModel.signal.annotationSpec(classDef);
verifyEqual(testCase,spec.editor.value_control,'class_palette');
verifyTrue(testCase,classDef.training_policy.freeze_parentage);
cellLatentModel.signal.createGroundTruth(r,classDef,'Model',model,'Save',false);
cellLatentModel.signal.setGroundTruth(r,classDef,'ObjectIds',uint64([11;13]), ...
    'Values',{'class_1';'class_3'},'Save',false);
[tbl,~]=cellLatentModel.signal.readGroundTruth(r,classDef);
verifyEqual(testCase,string(tbl.Label([1 3])),["class_1";"class_3"]);
report=cellLatentModel.signal.validateGroundTruth(r,classDef);
verifyTrue(testCase,report.valid);
verifyEqual(testCase,report.defined_count,2);

regDef=cellLatentModel.signal.definition('redox','regression', ...
    'Channels','GFP','Family','cells','ValueRange',[0 1]);
cellLatentModel.signal.createGroundTruth(r,regDef,'Model',model,'Save',false);
cellLatentModel.signal.setGroundTruth(r,regDef,'ObjectIds',uint64(12), ...
    'Values',0.42,'Save',false);
reg=cellLatentModel.signal.readGroundTruth(r,regDef);
verifyEqual(testCase,reg.Value(2),0.42,'AbsTol',1e-12);
end

function testSubcellularSegmentationGroundTruth(testCase)
[r,model]=fixtureRoi(); %#ok<ASGLU>
def=cellLatentModel.signal.definition('mitochondria morphology','segmentation', ...
    'Channels','GFP','Family','cells','Classes',{'mitochondria','fragment'});
spec=cellLatentModel.signal.annotationSpec(def);
verifyEqual(testCase,spec.editor.value_control,'paint_palette');
cellLatentModel.signal.createGroundTruth(r,def,'Model',model,'Save',false);
mask=zeros(5,6,'uint16'); mask(2,2)=1; mask(3,3)=2;
cellLatentModel.signal.setGroundTruth(r,def,'Frames',2,'Masks',mask,'Save',false);
[stack,~]=cellLatentModel.signal.readGroundTruth(r,def);
verifyEqual(testCase,squeeze(stack(:,:,1,2)),mask);
report=cellLatentModel.signal.validateGroundTruth(r,def);
verifyTrue(testCase,report.valid);
verifyEqual(testCase,report.defined_count,1);
complete=cellLatentModel.signal.validateGroundTruth(r,def,'RequireComplete',true);
verifyFalse(testCase,complete.valid);
end

function [r,model]=fixtureRoi()
r=roi('signals',[1 1 6 5]);
r.image=zeros(5,6,2,3,'uint16');
r.image(:,:,1,:)=uint16(100); r.image(2:4,2:4,2,:)=uint16(1);
r.channelid=[1 2]; r.display.channel={'GFP','tracked_cells'};
r.display.indexed=[false true]; r.display.intensity=[1 1 1;0 0 0];
model=cellModel.create('signals');
model.families.family_id=uint32(1); model.families.name={'cells'};
model.families.mask_provider={'tracked_cells'}; model.families.lineage_source={'latent'};
model.families.color_rgb=uint8([1 2 3]);
model.instances.object_id=uint64([11;12;13]); model.instances.family_id=uint32([1;1;1]);
model.instances.frame=uint32([1;2;3]); model.instances.mask_label=uint32([1;1;1]);
model.instances.track_id=uint64([7;7;7]); model.instances.state_id=uint16([0;0;0]);
end
