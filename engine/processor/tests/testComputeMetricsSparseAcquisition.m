function tests=testComputeMetricsSparseAcquisition
tests=functiontests(localfunctions);
end

function testInterpolatesComponentsBeforeRatio(testCase)
[r,p]=fixture();
d=quantify(r,p,[]);
verifyEqual(testCase,vertcat(d.data.MeanNoBckg_green_cyto{:}),[10;20;30;40;50;60;70;NaN]);
verifyEqual(testCase,vertcat(d.data.Ratio_Mean_NoBckg_green_red_cyto{:}), ...
    [1;20/15;30/20;40/25;50/30;60/35;70/40;NaN],'AbsTol',1e-10);
verifyEqual(testCase,d.userData.acquisition_sampling(1).missing_frames,[2 3 5 6 8]);
end

function testPartialSelectionUsesNeighboursAndAbsoluteFrames(testCase)
[r,p]=fixture(); d=quantify(r,p,[6 2]);
verifyEqual(testCase,vertcat(d.data.MeanNoBckg_green_cyto{:}),[60;20]);
verifyEqual(testCase,d.userData.source_frames,uint32([6;2]));
end

function testAcquiredZeroIsPreserved(testCase)
[r,p]=fixture(); r.image(:,:,2,4)=0;
d=quantify(r,p,[]);
verifyEqual(testCase,vertcat(d.data.MeanNoBckg_green_cyto{:}),[10;20/3;10/3;0;70/3;140/3;70;NaN],'AbsTol',1e-10);
end

function testNoInterpolationAcrossMissingMask(testCase)
[r,p]=fixture(); r.image(:,:,1,3)=0;
d=quantify(r,p,[]);
verifyTrue(testCase,isnan(d.data.MeanNoBckg_green_cyto{2}));
verifyEmpty(testCase,d.data.MeanNoBckg_green_cyto{3});
verifyEqual(testCase,d.data.MeanNoBckg_green_cyto{5},50);
end

function testLabelsJoinByIdentityRatherThanVectorPosition(testCase)
metrics=struct('Mean',{{[10 100];[0 0];[200 40]}});
ids={[1 2];[1 2];[2 1]};
out=computeMetrics.interpolateMetrics(metrics,ids,1:3,struct('missing_frames',2));
verifyEqual(testCase,out.Mean{2},[25 150]);
end

function testMetadataAndStandaloneUnknownCadence(testCase)
[r,p]=fixture(); p=rmfield(p,{'channel1_acquisitionPeriod','channel2_acquisitionPeriod'});
d=quantify(r,p,[]);
verifyEqual(testCase,d.data.MeanNoBckg_green_cyto{2},0); % Do not guess from zeros.
root=tempname; mkdir(root); cleanup=onCleanup(@()rmdir(root,'s')); %#ok<NASGU>
attrs=struct('pymmcore_plus',struct('summary_metadata',struct('mda_sequence', ...
    struct('channels',struct('config',{'green','red'},'acquire_every',{3,3})))));
fid=fopen(fullfile(root,'zarr.json'),'w'); fwrite(fid,jsonencode(struct('attributes',attrs))); fclose(fid);
f=fov(); f.isOMEZarr=true; f.omeZarrPath=root; f.omeZarrSeries='';
f.channel={'green','red'}; f.omeZarrChannelIndices=[0 1]; r.parent=f;
d=quantify(r,p,[]);
verifyEqual(testCase,d.data.MeanNoBckg_green_cyto{2},20);
verifyEqual(testCase,d.userData.acquisition_sampling(1).source,'pymmcore_plus.mda_sequence.acquire_every');
end

function testOptOutPreservesLegacyMeasurements(testCase)
[r,p]=fixture(); p.interpolateSparseAcquisition=false; d=quantify(r,p,[]);
verifyEqual(testCase,d.data.MeanNoBckg_green_cyto{2},0);
end

function testUnexpectedAcquisitionIsPreserved(testCase)
[r,p]=fixture(); r.image(2:3,2:3,2,2)=19;
d=quantify(r,p,[]);
verifyEqual(testCase,d.data.MeanNoBckg_green_cyto{2},19);
verifyEqual(testCase,d.data.MeanNoBckg_green_cyto{3},29.5);
end

function testCompositeMasksUseSameInterpolation(testCase)
[r,p]=fixture(); r.image(:,:,4,:)=0; r.image(2,2:3,4,:)=2;
r.channelid=1:4; r.display.channel{4}='other';
p.maskChannelCount=2; p.mask2_name='other'; p.mask2_label='nucleus';
p.mask2_backgroundLabel=0; p.mask2_scoreLabel=2; p.mask1_scoreLabel=1;
p.computeMaskCombinations=true;
d=quantify(r,p,[]);
verifyEqual(testCase,d.data.MeanNoBckg_green_cyto_AND_nucleus{2},20);
verifyEqual(testCase,d.data.Ratio_Mean_NoBckg_green_red_cyto_NOT_nucleus{2},20/15,'AbsTol',1e-10);
end

function testCadenceOffsetAndNoExtrapolation(testCase)
[r,p]=fixture(); r.image(:,:,2:3,:)=0;
r.image(2:3,2:3,2,2)=10; r.image(2:3,2:3,2,5)=40;
p.channel1_firstAcquisitionFrame=2;
d=quantify(r,p,[]);
% Frame 1 is outside the declared acquisition span: it is not fabricated.
verifyTrue(testCase,isnan(d.data.MeanNoBckg_green_cyto{1}));
verifyEqual(testCase,d.data.MeanNoBckg_green_cyto{3},20);
% Frame 8 is an acquired zero and remains a valid interpolation endpoint.
verifyEqual(testCase,d.data.MeanNoBckg_green_cyto{8},0);
end

function [r,p]=fixture()
r=roi('sparse_fluorescence',[1 1 5 5]);
r.image=zeros(5,5,3,8,'uint16');
r.image(2:3,2:3,1,:)=1;
for t=[1 4 7]
    r.image(2:3,2:3,2,t)=uint16(10*t);
    r.image(2:3,2:3,3,t)=uint16(5*t+5);
end
r.channelid=1:3; r.display.channel={'mask','green','red'};
r.display.indexed=[true false false]; r.display.intensity=[0 0 0;1 1 1;1 1 1];
p=struct('maskChannelCount',1,'scoreChannelCount',2,'mask1_name','mask', ...
    'mask1_label','cyto','mask1_backgroundLabel',0,'mask1_scoreLabel','all', ...
    'channel1_name','green','channel2_name','red','channel1_acquisitionPeriod',3, ...
    'channel2_acquisitionPeriod',3,'computeMaskCombinations',false);
end

function d=quantify(r,p,frames)
[~,out]=computeMetrics.core(p,r,frames);
d=out(strcmp({out.groupid},'channel_quantification'));
end
