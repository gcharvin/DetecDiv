function tests = testCellLatentTrackerContract
tests = functiontests(localfunctions);
end

function testTrainingScopeIsExplicit(testCase)
tp = cellLatentTracker.utils.defaultTrainingParam();
verifyEqual(testCase,textChoice(tp.initialModelSource), ...
    'promoted_cross_domain');
meta = cellLatentTracker.trainingParameterSpec([]);
verifyTrue(testCase,any(strcmp({meta.param},'appearanceLossWeight')));
verifyTrue(testCase,contains( ...
    meta(strcmp({meta.param},'appearanceLossWeight')).tip, ...
    'new trajectory','IgnoreCase',true));
verifyEqual(testCase,tp.successorLossWeight,0);
successor = meta(strcmp({meta.param},'successorLossWeight'));
verifyEqual(testCase,numel(successor),1);
verifyTrue(testCase,contains(successor.tip,'ambiguous', ...
    'IgnoreCase',true));
end

function testTypedInputsSeparateInstancesFromTrackingGT(testCase)
spec = cellLatentTracker.trainingSpec([]);
verifyEqual(testCase,{spec.param}, ...
    {'instanceChannelName','groundTruthChannelName','brightfieldChannelName'});
verifyEqual(testCase,spec(1).role,'mask_roi_image');
verifyEqual(testCase,spec(2).role,'tracked_mask_ground_truth');
verifyNotEqual(testCase,spec(1).role,spec(2).role);
end

function testPipelineProducesStableTrackingChannel(testCase)
p = cellLatentTracker.utils.defaultExecutionParam();
node = struct('type','classifier','pkg','cellLatentTracker','params',p);
contract = pipelineNodeContract(node);
verifyTrue(testCase,any(strcmp({contract.resources.in.role}, ...
    'mask_roi_image')));
verifyTrue(testCase,any(strcmp({contract.resources.out.role},'tracking')));
name = pipelinePhysicalResourceOutputName( ...
    node,contract.resources.out,'pred_latent_tracker_tracks');
verifyEqual(testCase,name,'results_pred_latent_tracker_tracks');
end

function testCompositeClassifierExposesTrackingAndLineage(testCase)
meta = cellLatentModel.trainingParameterSpec([]);
tracking = meta(strcmp({meta.param},'trainTrackingActions'));
lineage = meta(strcmp({meta.param},'trainMotherNull'));
verifyTrue(testCase,contains(tracking.label,'EDGE', ...
    'IgnoreCase',true));
verifyTrue(testCase,contains(tracking.tip,'stable track IDs', ...
    'IgnoreCase',true));
verifyTrue(testCase,contains(lineage.label,'mother / NULL', ...
    'IgnoreCase',true));
successor = meta(strcmp({meta.param},'trackingSuccessorLossWeight'));
verifyEqual(testCase,numel(successor),1);
verifyTrue(testCase,contains(successor.label,'EDGE vs END', ...
    'IgnoreCase',true));
tp = cellLatentModel.utils.defaultTrainingParam();
verifyEqual(testCase,tp.trackingSuccessorLossWeight,0);
mapped = cellLatentModel.trackerTrainingParams(tp);
verifyEqual(testCase,mapped.successorLossWeight,0);
end

function testStableTrackMaterializationDoesNotReuseMaskLabel(testCase)
model = cellModel.create('roi_test');
model.families.family_id = uint32(7);
model.families.name = {'reviewed GT'};
model.families.mask_provider = {'gt_cells'};
model.families.lineage_source = {'ground_truth'};
model.families.color_rgb = uint8([255 255 255]);
model.instances.object_id = uint64([1;2]);
model.instances.family_id = uint32([7;7]);
model.instances.frame = uint32([10;11]);
model.instances.mask_label = uint32([3;3]);
model.instances.track_id = uint64([40;41]);
model.instances.state_id = uint16([0;0]);
masks = zeros(3,3,2,'uint32');
masks(1:2,1:2,1) = 3;
masks(2:3,2:3,2) = 3;

[tracks,family] = cellLatentTracker.materializeStableTracks( ...
    masks,model,[10 11],'gt_cells');

verifyEqual(testCase,unique(tracks(:,:,1)),uint32([0;40]));
verifyEqual(testCase,unique(tracks(:,:,2)),uint32([0;41]));
verifyEqual(testCase,family.family_id,uint32(7));
end

function testStableTrackMaterializationRejectsUnsyncedGt(testCase)
model = cellModel.create('roi_test');
model.families.family_id = uint32(1);
model.families.name = {'reviewed GT'};
model.families.mask_provider = {'gt_cells'};
model.families.lineage_source = {'ground_truth'};
model.families.color_rgb = uint8([255 255 255]);
masks = ones(2,2,1,'uint32');

verifyError(testCase,@() cellLatentTracker.materializeStableTracks( ...
    masks,model,1,'gt_cells'), ...
    'cellLatentTracker:GroundTruthInstanceMapping');
end

function testStableTrackMaterializationRejectsStaleInstanceReference(testCase)
model = cellModel.create('roi_test');
model.families.family_id = uint32(1);
model.families.name = {'reviewed GT'};
model.families.mask_provider = {'gt_cells'};
model.families.lineage_source = {'ground_truth'};
model.families.color_rgb = uint8([255 255 255]);
model.instances.object_id = uint64([1;2]);
model.instances.family_id = uint32([1;1]);
model.instances.frame = uint32([1;1]);
model.instances.mask_label = uint32([1;2]);
model.instances.track_id = uint64([40;41]);
model.instances.state_id = uint16([0;0]);
masks = ones(2,2,1,'uint32');

verifyError(testCase,@() cellLatentTracker.materializeStableTracks( ...
    masks,model,1,'gt_cells'), ...
    'cellLatentTracker:GroundTruthInstanceMapping');
end

function value = textChoice(value)
while iscell(value), value=value{end}; end
value=char(string(value));
end
