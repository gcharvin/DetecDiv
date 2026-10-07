function tests=testCellMetricsGenerations
tests=functiontests(localfunctions);
end

function testHalfOpenCyclesAndTerminalFrame(testCase)
[model,tbl]=fixture();
[out,report]=cellMetrics.averageByGeneration(model,tbl);
mother=out(out.FamilyId==1 & out.TrackId==1,:);
verifyEqual(testCase,mother.StartFrame,[1;3;7]);
verifyEqual(testCase,mother.EndFrameExclusive,[3;7;11]);
verifyEqual(testCase,mother.CompleteCycle,[false;true;false]);
verifyEqual(testCase,mother.Signal,[15;45;85]);
verifyEqual(testCase,mother.ValidCount_Signal,[2;4;4]);
verifyTrue(testCase,all(mother.CompleteSampling));
verifyEqual(testCase,report.event_convention,'child_birth_v2');
% Child 2 has no observed own division: one partial interval, not age 1.
daughter=out(out.FamilyId==1 & out.TrackId==2,:);
verifyEqual(testCase,height(daughter),1);
verifyFalse(testCase,daughter.CompleteCycle);
verifyEqual(testCase,daughter.Signal,102);
verifyFalse(testCase,ismember('StateId',out.Properties.VariableNames));
end

function testMetricCountsGapsAndScopedIdentities(testCase)
[model,tbl]=fixture();
tbl(tbl.FamilyId==1 & tbl.TrackId==1 & tbl.Frame==4,:)=[];
tbl.Signal(tbl.FamilyId==1 & tbl.TrackId==1 & tbl.Frame==5)=NaN;
tbl.Signal(tbl.FamilyId==1 & tbl.TrackId==1 & tbl.Frame==6)=Inf;
tbl.Second(tbl.FamilyId==1 & tbl.TrackId==1 & tbl.Frame==3)=0;
out=cellMetrics.averageByGeneration(model,tbl);
middle=out(out.FamilyId==1 & out.TrackId==1 & out.StartFrame==3,:);
verifyEqual(testCase,middle.ObservedFrames,3);
verifyEqual(testCase,middle.Coverage,0.75);
verifyEqual(testCase,middle.ValidCount_Signal,1);
verifyEqual(testCase,middle.Signal,30);
verifyEqual(testCase,middle.ValidCount_Second,3);
verifyEqual(testCase,middle.Second,(0+5+6)/3,'AbsTol',1e-12);
verifyFalse(testCase,middle.CompleteSampling);
% Track 1 in family 2 is an independent cell with no birth boundaries.
other=out(out.FamilyId==2 & out.TrackId==1,:);
verifyEqual(testCase,height(other),1);
verifyEqual(testCase,other.Signal,900);
end

function testPartialFrameSelectionRetainsModelBoundaries(testCase)
[model,tbl]=fixture();
tbl=tbl(tbl.FamilyId==1 & tbl.TrackId==1 & ismember(tbl.Frame,uint32([4 6])),:);
out=cellMetrics.averageByGeneration(model,tbl);
verifyEqual(testCase,height(out),1);
verifyEqual(testCase,out.Generation,uint32(2));
verifyEqual(testCase,out.StartFrame,3);
verifyEqual(testCase,out.EndFrameExclusive,7);
verifyEqual(testCase,out.Signal,50);
verifyEqual(testCase,out.Coverage,0.5);
end

function testExplicitSegmentationAndParentageCensoring(testCase)
[model,tbl]=fixture();
model=addCensor(model,1,1,4,4,cellModel.censorScope('segmentation'));
out=cellMetrics.averageByGeneration(model,tbl);
middle=out(out.FamilyId==1 & out.TrackId==1 & out.StartFrame==3,:);
verifyEqual(testCase,middle.ValidCount_Signal,3);
verifyEqual(testCase,middle.Signal,(30+50+60)/3,'AbsTol',1e-12);
verifyEqual(testCase,middle.ValidFrames,3);
% Censor a daughter's birth: no silently accepted complete cycle.
model=addCensor(model,1,3,7,7,cellModel.censorScope('parentage'));
[out,report]=cellMetrics.averageByGeneration(model,tbl);
mother=out(out.FamilyId==1 & out.TrackId==1,:);
verifyEqual(testCase,mother.StartFrame,[1;3]);
verifyTrue(testCase,mother.HasExcludedEvents(2));
verifyFalse(testCase,any(mother.CompleteCycle));
verifyNotEmpty(testCase,report.diagnostics);
unfiltered=cellMetrics.averageByGeneration(model,tbl,'ExcludeCensored',false);
middle=unfiltered(unfiltered.FamilyId==1 & unfiltered.TrackId==1 & unfiltered.StartFrame==3,:);
verifyTrue(testCase,middle.CompleteCycle);
verifyEqual(testCase,middle.Signal,45);
end

function testParentageExclusionOnMissingSampleInvalidatesCycle(testCase)
[model,tbl]=fixture();
tbl(tbl.FamilyId==1 & tbl.TrackId==1 & tbl.Frame==5,:)=[];
model=addCensor(model,1,1,5,5,cellModel.censorScope('parentage'));
out=cellMetrics.averageByGeneration(model,tbl);
middle=out(out.FamilyId==1 & out.TrackId==1 & out.StartFrame==3,:);
verifyTrue(testCase,middle.StartObserved && middle.EndObserved);
verifyTrue(testCase,middle.ParentageCensored);
verifyFalse(testCase,middle.CompleteCycle);
end

function testJointEntryIsStaticAndEmptyMetricsKeepSchema(testCase)
[model,tbl]=fixture();
model.instances.frame(model.instances.track_id==2 & model.instances.family_id==1)=uint32(1);
tbl.Frame(tbl.TrackId==2 & tbl.FamilyId==1)=uint32(1);
[out,report]=cellMetrics.averageByGeneration(model,tbl);
mother=out(out.FamilyId==1 & out.TrackId==1,:);
verifyEqual(testCase,mother.StartFrame,[1;7]);
verifyFalse(testCase,any(mother.CompleteCycle));
verifyNotEmpty(testCase,report.diagnostics);
empty=cellMetrics.averageByGeneration(model,tbl([],:));
verifyEqual(testCase,height(empty),0);
verifyTrue(testCase,ismember('ValidCount_Signal',empty.Properties.VariableNames));
end

function testNoFiniteSamplesReturnsNaNWithZeroCount(testCase)
[model,tbl]=fixture();
tbl.Signal(tbl.FamilyId==1 & tbl.TrackId==1)=NaN;
out=cellMetrics.averageByGeneration(model,tbl);
mother=out(out.FamilyId==1 & out.TrackId==1,:);
verifyTrue(testCase,all(isnan(mother.Signal)));
verifyEqual(testCase,mother.ValidCount_Signal,zeros(3,1));
verifyTrue(testCase,all(mother.ValidCount_Second>0));
end

function testRejectsIdentityMismatch(testCase)
[model,tbl]=fixture();
tbl.Frame(1)=uint32(8);
verifyError(testCase,@()cellMetrics.averageByGeneration(model,tbl), ...
    'cellMetrics:MetricIdentityMismatch');
end

function testProcessorCreatesAndReplacesSeparateGenerationSeries(testCase)
[model,~]=fixture();
folder=tempname; mkdir(folder);
cleanup=onCleanup(@()removeFixture(folder)); %#ok<NASGU>
r=roi('generation_test',[]); r.path=folder;
model.roi_id=r.id;
cellModel.writeH5(cellModel.pathForROI(r),model);
labels=cell(10,1); values=cell(10,1);
for f=1:10
    rows=model.instances.family_id==1 & model.instances.frame==f;
    labels{f}=model.instances.mask_label(rows);
    values{f}=10*f*ones(nnz(rows),1);
end
t=table(labels,values,'VariableNames',{'MaskIdx_cells','Signal_cells'});
ds=dataseries(t,t.Properties.VariableNames,'groupid','channel_quantification');
ds.userData=struct('source_frames',uint32((1:10)'), ...
    'mask_bindings',struct('index_variable','MaskIdx_cells', ...
    'mask_channel','cells','mask_label','cells'));
r.data=ds;
p=objectMetrics.setparam(struct());
p.family=1; p.geometryData='none'; p.deriveGrowth=false;
[~,legacy]=objectMetrics.process(p,r,struct());
verifyEqual(testCase,numel(legacy),2);
p.averageByGeneration=true;
[~,dataout,imageout]=objectMetrics.process(p,r,struct());
verifyEmpty(testCase,imageout);
verifyEqual(testCase,numel(dataout),3);
verifyEqual(testCase,dataout(2).type,"temporal");
verifyEqual(testCase,dataout(3).type,"generation");
verifyEqual(testCase,dataout(3).groupid,'object_metrics_generation');
verifyEqual(testCase,nnz(dataout(3).data.CompleteCycle),1);
r.data=dataout;
[~,rerun]=objectMetrics.process(p,r,struct());
verifyEqual(testCase,numel(rerun),3);
verifyEqual(testCase,rerun(3).data,dataout(3).data);
p.generationOutputName=p.inputData;
verifyError(testCase,@()objectMetrics.process(p,r,struct()),'objectMetrics:InvalidGenerationOutput');
end

function testPipelineAdvertisesOptionalGenerationOutput(testCase)
node=struct('id','metrics','type','processor','pkg','objectMetrics', ...
    'func','objectMetrics.process','params',objectMetrics.setparam(struct()));
contract=pipelineNodeContract(node);
verifyEqual(testCase,numel(contract.resources.out),1);
node.params.averageByGeneration=true;
contract=pipelineNodeContract(node);
verifyEqual(testCase,numel(contract.resources.out),2);
verifyEqual(testCase,contract.resources.out(2).nameParam,'generationOutputName');
end

function [model,tbl]=fixture()
model=cellModel.create('generation_test');
model.families.family_id=uint32([1;2]); model.families.name={'pred';'gt'};
model.families.mask_provider={'cells';'gt_cells'};
model.families.lineage_source={'pred:cellLatentModel';'ground_truth'};
model.families.color_rgb=uint8([1 2 3;4 5 6]);
model.instances.object_id=uint64((101:114)');
model.instances.family_id=uint32([ones(12,1);2;2]);
model.instances.track_id=uint64([ones(10,1);2;3;1;1]);
model.instances.frame=uint32([(1:10)';3;7;2;4]);
model.instances.mask_label=uint32([ones(10,1);2;3;1;1]);
model.instances.state_id=zeros(14,1,'uint16');
model.relations.relation_id=uint64([1;2]); model.relations.family_id=uint32([1;1]);
model.relations.parent_track_id=uint64([1;1]); model.relations.child_track_id=uint64([2;3]);
model.relations.event_frame=uint32([3;7]); model.relations.type_id=uint8([1;1]);
model.relations.confidence=single([1;1]);
tbl=table(model.instances.family_id,model.instances.object_id,model.instances.track_id, ...
    model.instances.frame,model.instances.mask_label,model.instances.state_id, ...
    [(10:10:100)';102;103;900;900],[(1:10)';12;13;90;90], ...
    'VariableNames',{'FamilyId','ObjectId','TrackId','Frame','MaskLabel','StateId','Signal','Second'});
end

function model=addCensor(model,family,track,start,finish,scope)
c=model.censoring; i=numel(c.censor_id)+1;
c.censor_id(i,1)=uint64(i); c.family_id(i,1)=uint32(family); c.track_id(i,1)=uint64(track);
c.frame_start(i,1)=uint32(start); c.frame_end(i,1)=uint32(finish); c.scope_flags(i,1)=scope;
c.reason_id(i,1)=uint16(5); c.source_id(i,1)=uint8(1); model.censoring=c;
end

function removeFixture(folder)
% Delete only the files created in this unique temporary fixture directory.
files=dir(fullfile(folder,'objects_generation_test.h5'));
for i=1:numel(files), delete(fullfile(folder,files(i).name)); end
rmdir(folder);
end
