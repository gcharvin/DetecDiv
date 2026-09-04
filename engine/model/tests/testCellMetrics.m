function tests = testCellMetrics
tests=functiontests(localfunctions);
end

function testLinksPartialFrameMetricsByMaskIdentity(testCase)
model=fixtureModel();
tbl=table({uint32([2 5])';uint32([3 7])'}, ...
    {[20 50]';[30 70]'},'VariableNames',{'MaskIdx_cells','Mean_redox_cells'});
series=struct('data',tbl,'groupid','channel_quantification','userData',struct( ...
    'source_frames',uint32([2;4]),'mask_bindings',struct( ...
    'index_variable','MaskIdx_cells','mask_channel','tracked_cells','mask_label','cells')));
[out,report]=cellMetrics.link(model,'cells',series);
verifyEqual(testCase,out.Frame,uint32([2;3;4]));
verifyEqual(testCase,out.Mean_redox_cells,[20;NaN;70]);
verifyEqual(testCase,report.matched_count,2);
verifyEqual(testCase,report.missing_frame_object_ids,uint64(102));
end

function testDerivesTrackAndMotherBudGrowth(testCase)
t=table(uint64([1;1;1;2;2]),uint32([1;2;3;2;3]), ...
    uint64([0;0;0;1;1]),[10;12;14;2;4], ...
    'VariableNames',{'TrackId','Frame','ParentTrackId','Area_Cell'});
out=cellMetrics.deriveGrowth(t,'FrameIntervalMinutes',2,'Window',3);
bud=out.TrackId==2;
verifyEqual(testCase,out.MotherSize(bud),[12;14]);
verifyEqual(testCase,out.PairSize(bud),[14;18]);
verifyEqual(testCase,out.Area_CellGrowthPerMinute(bud),[1;1],'AbsTol',1e-12);
verifyEqual(testCase,out.PairGrowthPerMinute(bud),[2;2],'AbsTol',1e-12);
verifyEqual(testCase,out.BudGrowthAllocation(bud),[0.5;0.5],'AbsTol',1e-12);
end

function testReadsRawTrackAndMotherCrop(testCase)
r=roi('raw',[1 1 7 6]);
raw=zeros(6,7,3,3,'uint16');
for f=1:3, raw(:,:,1,f)=uint16(f*100+reshape(1:42,6,7)); end
raw(2:3,2:3,3,1)=1; raw(2:3,3:4,3,2)=2; raw(2:3,4:5,3,3)=3;
raw(4:5,3:4,3,2)=4; raw(4:5,4:5,3,3)=5;
r.image=raw; r.channelid=[1 2 3];
r.display.channel={'BF','redox','tracked_cells'};
r.display.indexed=[false false true];
r.display.intensity=[1 1 1;1 1 1;0 0 0];
model=fixtureRawModel();
seq=cellMetrics.readRaw(r,'cells',uint64(2),'Channels',{'BF','redox'}, ...
    'Scope','mother_bud_pair','MarginPixels',1,'Model',model);
verifyEqual(testCase,seq.frames,uint32([2;3]));
verifyEqual(testCase,seq.parent_track_id,uint64(1));
verifyEqual(testCase,size(seq.images,3),2);
verifyTrue(testCase,any(seq.primary_mask(:)));
verifyTrue(testCase,any(seq.parent_mask(:)));
verifyEqual(testCase,seq.object_ids,uint64([204;205]));
end

function model=fixtureModel()
model=cellModel.create('metrics');
model.families.family_id=uint32(1); model.families.name={'cells'};
model.families.mask_provider={'tracked_cells'}; model.families.lineage_source={'latent'};
model.families.color_rgb=uint8([1 2 3]);
model.instances.object_id=uint64([101;102;103]);
model.instances.family_id=uint32([1;1;1]); model.instances.frame=uint32([2;3;4]);
model.instances.mask_label=uint32([2;9;7]); model.instances.track_id=uint64([11;11;11]);
model.instances.state_id=uint16([0;0;0]);
end

function model=fixtureRawModel()
model=cellModel.create('raw');
model.families.family_id=uint32(1); model.families.name={'cells'};
model.families.mask_provider={'tracked_cells'}; model.families.lineage_source={'latent'};
model.families.color_rgb=uint8([1 2 3]);
model.instances.object_id=uint64([201;202;203;204;205]);
model.instances.family_id=uint32(ones(5,1)); model.instances.frame=uint32([1;2;3;2;3]);
model.instances.mask_label=uint32([1;2;3;4;5]); model.instances.track_id=uint64([1;1;1;2;2]);
model.instances.state_id=uint16(zeros(5,1));
model.relations.relation_id=uint64(1); model.relations.family_id=uint32(1);
model.relations.parent_track_id=uint64(1); model.relations.child_track_id=uint64(2);
model.relations.event_frame=uint32(2); model.relations.type_id=uint8(1);
model.relations.confidence=single(1);
end
