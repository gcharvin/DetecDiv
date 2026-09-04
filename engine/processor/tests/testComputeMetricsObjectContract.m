function tests = testComputeMetricsObjectContract
tests=functiontests(localfunctions);
end

function testPersistsAbsoluteFramesAndMaskBinding(testCase)
r=roi('metric_contract',[1 1 5 5]);
r.image=zeros(5,5,2,4,'uint16');
r.image(2:3,2:3,1,2)=uint16(4);
r.image(3:4,3:4,1,4)=uint16(7);
r.image(:,:,2,:)=uint16(10);
r.channelid=[1 2];
r.display.channel={'tracked_cells','redox'};
r.display.indexed=[true false];
r.display.intensity=[0 0 0;1 1 1];
param=struct('maskChannelCount',1,'scoreChannelCount',1, ...
    'mask1_name','tracked_cells','mask1_stat',true,'mask1_label','cells', ...
    'mask1_backgroundLabel',0,'mask1_scoreLabel','all', ...
    'channel1_name','redox','computeMaskCombinations',false, ...
    'outputName','channel_quantification');
[~,dataout]=computeMetrics.core(param,r,[2 4]);
ids=arrayfun(@(x)string(x.groupid),dataout);
geometry=dataout(ids=="mask_quantification_cells");
fluo=dataout(ids=="channel_quantification");
verifyEqual(testCase,geometry.userData.source_frames,uint32([2;4]));
verifyEqual(testCase,fluo.userData.source_frames,uint32([2;4]));
verifyEqual(testCase,fluo.userData.mask_bindings.mask_channel,'tracked_cells');
verifyEqual(testCase,fluo.userData.mask_bindings.index_variable,'MaskIdx_cells');
end

function testObjectMetricsPipelineMaterializesIdentityTable(testCase)
r=roi('object_pipeline',[1 1 5 5]);
r.image=zeros(5,5,2,2,'uint16');
r.image(2:3,2:3,1,1)=uint16(1); r.image(2:4,2:4,1,2)=uint16(2);
r.image(:,:,2,:)=uint16(10); r.channelid=[1 2];
r.display.channel={'tracked_cells','redox'}; r.display.indexed=[true false];
r.display.intensity=[0 0 0;1 1 1];
model=cellModel.create(r.id);
model.families.family_id=uint32(1); model.families.name={'cells'};
model.families.mask_provider={'tracked_cells'}; model.families.lineage_source={'latent'};
model.families.color_rgb=uint8([1 2 3]);
model.instances.object_id=uint64([10;11]); model.instances.family_id=uint32([1;1]);
model.instances.frame=uint32([1;2]); model.instances.mask_label=uint32([1;2]);
model.instances.track_id=uint64([5;5]); model.instances.state_id=uint16([0;0]);
r.cellModel=model; r.cellModelInfo=struct('loaded',true,'filename','','datenum',NaN);
param=struct('maskChannelCount',1,'scoreChannelCount',1, ...
    'mask1_name','tracked_cells','mask1_stat',true,'mask1_label','cells', ...
    'mask1_backgroundLabel',0,'mask1_scoreLabel','all', ...
    'channel1_name','redox','computeMaskCombinations',false, ...
    'outputName','channel_quantification');
[~,r.data]=computeMetrics.core(param,r);
op=objectMetrics.setparam(struct()); op.family='cells'; op.frameIntervalMinutes=2;
[~,dataout]=objectMetrics.core(op,r);
ids=arrayfun(@(x)string(x.groupid),dataout);
result=dataout(ids=="object_metrics");
verifyEqual(testCase,result.data.ObjectId,uint64([10;11]));
verifyTrue(testCase,ismember('Area_CellGrowthPerMinute',result.data.Properties.VariableNames));
verifyEqual(testCase,result.userData.join_report.matched_count,2);
end
