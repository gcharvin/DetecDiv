function tests = testComputeDriftGeneral
tests = functiontests(localfunctions);
end

function testDefaultOptionsCorrectEveryImageChannel(testCase)
ref=genericTexture(256); rows=0:2:10; cols=0:-1:-5;
images=translateSequence(ref,rows,cols);
other=uint16(500+.7*double(ref));
images(:,:,2,:)=translateSequence(other,rows,cols);
f=fov(); [corrected,d]=f.computeDrift('images',images);
verifyEqual(testCase,d.method,'robust');
verifyEqual(testCase,d.refMode,'fixed');
verifyTrue(testCase,all(d.accepted));
verifyLessThan(testCase,max(hypot(d.x+rows,d.y+cols)),.1);
for channel=1:2
    anchor=double(images(28:228,28:228,channel,1));
    for k=2:numel(rows)
        aligned=double(corrected(28:228,28:228,channel,k));
        verifyGreaterThan(testCase,corr2(anchor,aligned),.999);
    end
end
end

function testSmoothDriftCanExceedTwentyPixels(testCase)
ref = genericTexture(256);
rows = 0:2:40; cols = 0:-1:-20;
ims = translateSequence(ref,rows,cols);
f = fov();
[~,d] = f.computeDrift('images',ims,'method','robust', ...
    'maxshift',20,'maxstep',5,'refimage',ref);
verifyLessThan(testCase,max(abs(d.x+rows)),0.75);
verifyLessThan(testCase,max(abs(d.y+cols)),0.75);
end

function testDisabledBoundsPreserveUnboundedRegistration(testCase)
ref=genericTexture(256); rows=0:4:40; cols=-rows/2;
f=fov(); [~,d]=f.computeDrift('images',translateSequence(ref,rows,cols), ...
    'method','robust','maxshift',0,'maxstep',0);
verifyLessThan(testCase,max(hypot(d.x+rows,d.y+cols)),.5);
verifyTrue(testCase,all(d.accepted));
end

function testSmallFractionalMotionNearZero(testCase)
ref = genericTexture(256);
rows = [0 .2 .35 -.2 -.4 .15]; cols = [0 -.3 .25 .35 -.2 -.4];
ims = translateSequence(ref,rows,cols);
f = fov();
[~,d] = f.computeDrift('images',ims,'method','robust','refimage',ref);
verifyLessThan(testCase,max(abs(d.x+rows)),0.2);
verifyLessThan(testCase,max(abs(d.y+cols)),0.2);
end

function testGainAndOffsetDoNotChangeRegistration(testCase)
ref = genericTexture(256);
rows = [0 1.2 2.4 -1.4 3.1]; cols = [0 -2.1 1.3 2.4 -3.2];
ims = translateSequence(ref,rows,cols);
for k=2:size(ims,4)
    ims(:,:,1,k)=uint16(double(ims(:,:,1,k))*(.6+.2*k)+300*k);
end
f=fov();
[~,d]=f.computeDrift('images',ims,'method','robust','refimage',ref);
verifyLessThan(testCase,max(abs(d.x+rows)),0.6);
verifyLessThan(testCase,max(abs(d.y+cols)),0.6);
end

function testMovingForegroundDoesNotMoveTheBackground(testCase)
ref=genericTexture(256);
rows=[0 1 2 3 4 5]; cols=[0 -.5 -1 -1.5 -2 -2.5];
ims=translateSequence(ref,rows,cols);
[x,y]=meshgrid(1:256);
for k=1:size(ims,4)
    foreground=12000*exp(-((x-(105+5*k)).^2+(y-(100+3*k)).^2)/500);
    ims(:,:,1,k)=uint16(double(ims(:,:,1,k))+foreground);
end
f=fov();
[~,d]=f.computeDrift('images',ims,'method','robust');
verifyLessThan(testCase,max(abs(d.x+rows)),0.75);
verifyLessThan(testCase,max(abs(d.y+cols)),0.75);
end

function testUninformativeFrameDoesNotPreventRecovery(testCase)
ref=genericTexture(256);
ims=translateSequence(ref,[0 1 2 3],[0 1 2 3]);
ims(:,:,1,3)=0;
f=fov();
[~,d]=f.computeDrift('images',ims,'method','robust');
verifyEqual(testCase,d.x(3),d.x(2));
verifyEqual(testCase,d.y(3),d.y(2));
verifyLessThan(testCase,abs(d.x(4)+3),.75);
verifyLessThan(testCase,abs(d.y(4)+3),.75);
verifyFalse(testCase,d.accepted(3));
verifyTrue(testCase,d.accepted(4));
end

function testConflictingMotionsAreFlaggedInsteadOfAveraged(testCase)
ref=genericTexture(512);
mov=ref;
mov(:,1:256)=circshift(ref(:,1:256),[0 8]);
mov(:,257:end)=circshift(ref(:,257:end),[0 -8]);
f=fov();
[~,d]=f.computeDrift('images',cat(4,ref,mov),'method','robust');
verifyFalse(testCase,d.accepted(2));
verifyEqual(testCase,d.x(2),d.x(1));
verifyEqual(testCase,d.y(2),d.y(1));
verifyEqual(testCase,d.estimation{2},'ambiguousConsensus');
end

function testUnrelatedTexturedFrameIsRejected(testCase)
ref=genericTexture(256);
rng(92);
unrelated=uint16(15000+2500*imgaussfilt(randn(256),1.2));
f=fov();
[~,d]=f.computeDrift('images',cat(4,ref,unrelated),'method','robust');
verifyFalse(testCase,d.accepted(2));
verifyEqual(testCase,d.x(2),0,'AbsTol',1e-8);
verifyEqual(testCase,d.y(2),0,'AbsTol',1e-8);
end

function testEvolvingTextureUsesTraceableTemporalFallbackAcrossBlocks(testCase)
ref=genericTexture(256); rng(93);
other=uint16(15000+2500*imgaussfilt(randn(256),1.2));
rows=0:.15:6; cols=-rows/2;
images=zeros(256,256,1,numel(rows),'uint16');
for k=1:numel(rows)
    fraction=(k-1)/(numel(rows)-1);
    texture=uint16((1-fraction)*double(ref)+fraction*double(other));
    images(:,:,1,k)=imtranslate(texture,[cols(k) rows(k)],'linear','FillValues',15000);
end
f=fov(); [~,full]=f.computeDrift('images',images,'refimage',ref,'method','robust');
verifyLessThan(testCase,max(hypot(full.x+rows,full.y+cols)),.75);
verifyTrue(testCase,any(startsWith(full.estimation,'temporalFallback')));
fallback=startsWith(full.estimation,'temporalFallback');
verifyFalse(testCase,any(full.anchorValidated(fallback)));
verifyTrue(testCase,all(full.accepted(fallback)));
verifyGreaterThanOrEqual(testCase,min(full.temporalCorrelation(fallback)),.5);
f=fov(); f.computeDrift('images',images(:,:,:,1:20),'refimage',ref,'method','robust');
[~,blocks]=f.computeDrift('images',images(:,:,:,21:end),'framesid',21:numel(rows), ...
    'previousimage',images(:,:,1,20),'refimage',ref,'method','robust');
verifyEqual(testCase,blocks.x,full.x,'AbsTol',1e-8);
verifyEqual(testCase,blocks.y,full.y,'AbsTol',1e-8);
verifyEqual(testCase,blocks.anchorValidated,full.anchorValidated);
end

function testIndependentCameraNoiseDoesNotBecomeDrift(testCase)
ref=genericTexture(256); rng(94);
rows=0:.5:4; cols=-rows/2;
ims=translateSequence(ref,rows,cols);
for k=1:numel(rows), ims(:,:,1,k)=uint16(double(ims(:,:,1,k))+1500*randn(256)); end
f=fov(); [~,d]=f.computeDrift('images',ims,'method','robust');
verifyLessThan(testCase,max(hypot(d.x+rows,d.y+cols)),.75);
verifyTrue(testCase,all(d.accepted));
end

function testContrastPolarityChangePreservesGeometry(testCase)
ref=genericTexture(256);
rows=[0 .8 1.4 2.3 3.1]; cols=[0 -.5 -.9 -1.5 -2];
ims=translateSequence(ref,rows,cols);
for k=2:numel(rows), ims(:,:,1,k)=uint16(30000-double(ims(:,:,1,k))); end
f=fov(); [~,d]=f.computeDrift('images',ims,'method','robust');
verifyLessThan(testCase,max(hypot(d.x+rows,d.y+cols)),.35);
verifyTrue(testCase,all(d.accepted));
verifyTrue(testCase,any(startsWith(d.estimation,'structural:')));
end

function testSparseDiffuseSignal(testCase)
[x,y]=meshgrid(1:256);
ref=uint16(1000+9000*exp(-((x-50).^2+(y-55).^2)/200)+ ...
    6000*exp(-((x-190).^2+(y-75).^2)/450)+ ...
    7500*exp(-((x-110).^2+(y-200).^2)/300));
rows=[0 .3 1.2 2.1 3.4]; cols=[0 -.4 -1.1 -2.4 -3.2];
f=fov();
[~,d]=f.computeDrift('images',translateSequence(ref,rows,cols),'method','robust');
verifyLessThan(testCase,max(abs(d.x+rows)),.35);
verifyLessThan(testCase,max(abs(d.y+cols)),.35);
end

function testSmallFieldUsesValidatedFallback(testCase)
ref=genericTexture(48);
rows=[0 .3 1.2]; cols=[0 -.4 -1.1];
f=fov();
[~,d]=f.computeDrift('images',translateSequence(ref,rows,cols),'method','robust');
verifyLessThan(testCase,max(abs(d.x+rows)),.2);
verifyLessThan(testCase,max(abs(d.y+cols)),.2);
verifyTrue(testCase,all(d.accepted));
end

function testPeriodicTextureUsesTemporalContinuity(testCase)
rng(44);
patch=uint16(10000+1000*imgaussfilt(randn(24),1));
ref=repmat(patch,12,12);
rows=0:1:30; cols=0:-.5:-15;
f=fov();
[~,d]=f.computeDrift('images',translateSequence(ref,rows,cols), ...
    'method','robust','maxshift',10,'maxstep',5);
verifyLessThan(testCase,max(abs(d.x+rows)),.4);
verifyLessThan(testCase,max(abs(d.y+cols)),.4);
end

function testSparseFrameBlocksHoldTheLastProcessedFrame(testCase)
ref=genericTexture(256);
ims=translateSequence(ref,[0 1 2 3],[0 -.5 -1 -1.5]);
f=fov();
[~,first]=f.computeDrift('images',ims(:,:,:,1:3), ...
    'framesid',[1 4 7],'refimage',ref,'method','robust');
[~,last]=f.computeDrift('images',zeros(size(ref),'uint16'), ...
    'framesid',10,'refimage',ref,'method','robust');
verifyEqual(testCase,last.x(10),first.x(7));
verifyEqual(testCase,last.y(10),first.y(7));
verifyFalse(testCase,last.accepted(10));
end

function testDefocusDoesNotBecomeMotion(testCase)
ref=genericTexture(256);
rows=[0 .5 1.2 2.2 3.4 4.4]; cols=[0 .25 1.2 -.8 -1.5 -2.2];
ims=translateSequence(ref,rows,cols);
for k=2:size(ims,4), ims(:,:,1,k)=imgaussfilt(ims(:,:,1,k),.3*(k-1)); end
f=fov();
[~,d]=f.computeDrift('images',ims,'method','robust');
verifyLessThan(testCase,max(abs(d.x+rows)),.3);
verifyLessThan(testCase,max(abs(d.y+cols)),.3);
end

function testRectangularFieldAndCentralCrop(testCase)
rng(91);
ref=uint16(12000+2500*imgaussfilt(randn(160,512),1.2));
rows=[0 1.2 2.5 3.2]; cols=[0 -.5 -1.3 -2.4];
f=fov();
[~,d]=f.computeDrift('images',translateSequence(ref,rows,cols), ...
    'method','robust','crop',.8);
verifyLessThan(testCase,max(abs(d.x+rows)),.2);
verifyLessThan(testCase,max(abs(d.y+cols)),.2);
end

function ref = genericTexture(n)
rng(81);
ref=uint16(15000+2500*imgaussfilt(randn(n),1.2));
end

function ims = translateSequence(ref,rows,cols)
ims=zeros(size(ref,1),size(ref,2),1,numel(rows),'like',ref);
for k=1:numel(rows)
    ims(:,:,1,k)=imtranslate(ref,[cols(k) rows(k)], ...
        'linear','FillValues',median(ref(:)));
end
end
