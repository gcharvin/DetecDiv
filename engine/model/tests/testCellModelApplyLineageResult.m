function tests = testCellModelApplyLineageResult
tests = functiontests(localfunctions);
end

function testAutoSourceExcludesExistingOutputFamily(testCase)
model = cellModel.create('shared_provider');
model.families.family_id = uint32([1;2]);
model.families.name = {'Cell latent lineage GFP v001'; ...
    'latent_model_1 reviewed GT'};
model.families.mask_provider = {'latent_model_1_cell'; ...
    'latent_model_1_cell'};
model.families.lineage_source = {'cellLatentModel';'ground_truth'};
model.families.color_rgb = uint8([10 20 30;40 50 60]);
model.instances.object_id = uint64([1;2]);
model.instances.family_id = uint32([1;2]);
model.instances.frame = uint32([1;1]);
model.instances.mask_label = uint32([1;1]);
model.instances.track_id = uint64([1;1]);
model.instances.state_id = uint16([0;1]);
model.states.state_id = uint16(1);
model.states.name = {'reviewed'};
model.states.color_rgb = uint8([1 2 3]);
model = cellModel.normalize(model);

stack = uint32(ones(2,2,1));
result = struct('edges',struct([]));
[actual,familyId] = cellModel.applyLineageResult( ...
    model,stack,'latent_model_1_cell','<auto>', ...
    'Cell latent lineage GFP v001',result,true,'cellLatentModel');

verifyEqual(testCase,familyId,uint32(1));
outputRows = actual.instances.family_id == uint32(1);
sourceRows = actual.instances.family_id == uint32(2);
verifyEqual(testCase,actual.instances.state_id(outputRows),uint16(1));
verifyEqual(testCase,actual.instances.state_id(sourceRows),uint16(1));
verifyEqual(testCase,actual.families.lineage_source{2},'ground_truth');
verifyTrue(testCase,cellModel.validate(actual).ok);
end

function testExplicitOutputAsSourceStillFails(testCase)
model = cellModel.create('collision');
model.families.family_id = uint32(1);
model.families.name = {'prediction'};
model.families.mask_provider = {'tracked'};
model.families.lineage_source = {'cellLatentModel'};
model.families.color_rgb = uint8([10 20 30]);
model = cellModel.normalize(model);

verifyError(testCase,@()cellModel.applyLineageResult( ...
    model,uint32(ones(2,2,1)),'tracked','prediction', ...
    'prediction',struct('edges',struct([])),true,'cellLatentModel'), ...
    'cellModel:SourceOutputCollision');
end
