function tests=testAssignedAreas
tests=functiontests(localfunctions);
end
function setupOnce(~)
detecdiv_setup_path;
end
function testMotherBudMissingAndAbsentBud(testCase)
r=roi('area_fixture',[]);m=zeros(4,4,1,4,'uint8');b=m;
m(1:2,1:2,1,[1 2 4])=1;b(3,3:4,1,1)=1;b(4,4,1,3)=1;
r.addChannel(m,'V_cell',[1 0 0],[0 0 0]);r.addChannel(b,'V_bud',[0 1 0],[0 0 0]);
original=r.image;originalData=r.data;ds=trackMotherLineageViterbi.areaSeries(r,[1 2 3],'V');
verifyEqual(testCase,ds.data.Area_Mother,[4;4;NaN;NaN]);
verifyEqual(testCase,ds.data.Area_Bud,[2;0;NaN;NaN]);
verifyEqual(testCase,r.image,original);verifyEqual(testCase,r.data,originalData);
r.data=ds;next=trackMotherLineageViterbi.areaSeries(r,4,'V');
verifyEqual(testCase,next.data.Area_Mother,[4;4;NaN;4]);
verifyEqual(testCase,next.data.Area_Bud,[2;0;NaN;0]);
r.image(1,1,1,1)=2;
verifyError(testCase,@()trackMotherLineageViterbi.areaSeries(r,1,'V'),'trackMotherLineageViterbi:NonBinaryAssignedMasks');
end
function testPipelineExposesAssignedAreas(testCase)
n=struct('id','mother','type','processor','pkg','trackMotherLineageViterbi', ...
    'params',struct('outputChannelName','V','instanceChannelName','cells'));
c=pipelineNodeContract(n);spec=c.resources.out(strcmp({c.resources.out.role},'lineage_areas'));
verifyNumElements(testCase,spec,1);
verifyEqual(testCase,pipelinePhysicalResourceOutputName(n,spec,'V'),'V_areas');
t=struct('id','state','type','classifier','pkg','lstm_timeseries', ...
    'params',struct('featureCount',1,'feature1','@resource:lineage_areas:mother / Area_Bud','outputName','state'));
n.func='trackMotherLineageViterbi.process';t.func='lstm_timeseries.classify';n.enabled=true;t.enabled=true;
pipe=struct('nodes',[n t],'edges',struct('from','mother','to','state'),'branches',struct([]));
[resolved,~]=pipelineResolveBindings(pipe,struct('roiList',1,'channels',{{'cells'}}),struct('allowGui',false));
verifyEqual(testCase,resolved.nodes(2).params.feature1,'V_areas / Area_Bud');
end
function testProcessorPublishesAreasAndUpdatesOnlySelectedFrames(testCase)
r=roi('track_fixture',[]);r.image=zeros(20,20,1,3,'uint16');
r.image(7:13,7:13,1,:)=1;r.image(14:16,9:11,1,:)=2;
r.channelid=1;r.display.channel={'instances'};
p=trackMotherLineageViterbi.setparam(struct('channels',{{'instances'}},'useProvidedChannels',true));
p.instanceChannelName={'instances','instances'};p.outputChannelName='V';p.debug=false;
[~,data,~]=trackMotherLineageViterbi.process(p,r,struct('frames',[1 3]));
ds=data(strcmp(string({data.groupid}),'V_areas'));verifyNumElements(testCase,ds,1);
verifyTrue(testCase,isnan(ds.data.Area_Mother(2)));
mother=r.findChannelID('V_cell');bud=r.findChannelID('V_bud');
for f=[1 3]
 expected=nnz(r.image(:,:,mother,f));
 if expected>0
  verifyEqual(testCase,ds.data.Area_Mother(f),double(expected));
  verifyEqual(testCase,ds.data.Area_Bud(f),double(nnz(r.image(:,:,bud,f))));
 end
end
r.data=data;[~,updated,~]=trackMotherLineageViterbi.process(p,r,struct('frames',2));
ds2=updated(strcmp(string({updated.groupid}),'V_areas'));verifyNumElements(testCase,ds2,1);
verifyEqual(testCase,ds2.data.Area_Mother([1 3]),ds.data.Area_Mother([1 3]));
verifyEqual(testCase,ds2.data.Area_Bud([1 3]),ds.data.Area_Bud([1 3]));
end
function testUnloadedDataCachePreservesPersistedAreasWithoutMutation(testCase)
folder=tempname;mkdir(folder);finish=onCleanup(@()rmdir(folder,'s')); %#ok<NASGU>
r=roi('cached',[]);r.path=folder;r.image=zeros(2,2,2,3,'uint8');
r.image(:,:,1,:)=1;r.channelid=[1 2];r.display.channel={'V_cell','V_bud'};
data=trackMotherLineageViterbi.areaSeries(r,1,'V');save(fullfile(folder,'data_cached.mat'),'data');
r.data=dataseries.empty;next=trackMotherLineageViterbi.areaSeries(r,3,'V');
verifyEqual(testCase,next.data.Area_Mother,[4;NaN;4]);
verifyEqual(testCase,next.data.Area_Bud,[0;NaN;0]);verifyEmpty(testCase,r.data);
end
