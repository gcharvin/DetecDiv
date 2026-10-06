function tests = testComputeDriftRobust
tests = functiontests(localfunctions);
end

function testRobustFixedAnchorRecoversAbsoluteTranslation(testCase)
[images, expectedRow, expectedCol, ref] = syntheticTranslatedSequence();
f = fov();
[~, drift] = f.computeDrift( ...
    'images', images, 'framesid', 1:size(images,4), ...
    'refimage', ref, 'method', 'robust', 'refmode', 'fixed', ...
    'maxshift', 20, 'maxstep', 10, 'psrmin', 5, 'stitch', false);

verifyLessThan(testCase, max(abs(drift.x-expectedRow)), 0.75);
verifyLessThan(testCase, max(abs(drift.y-expectedCol)), 0.75);
verifyLessThanOrEqual(testCase, max(abs(drift.x)), 5);
verifyLessThanOrEqual(testCase, max(abs(drift.y)), 5);
end

function testRobustFixedAnchorMatchesAcrossBlocks(testCase)
[images, expectedRow, expectedCol, ref] = syntheticTranslatedSequence();
f = fov();

f.computeDrift('images', images(:,:,:,1:4), 'framesid', 1:4, ...
    'refimage', ref, 'method', 'robust', 'refmode', 'fixed', ...
    'maxshift', 20, 'maxstep', 10, 'psrmin', 5);
[~, drift] = f.computeDrift('images', images(:,:,:,5:end), ...
    'framesid', 5:size(images,4), 'refimage', ref, ...
    'method', 'robust', 'refmode', 'fixed', ...
    'maxshift', 20, 'maxstep', 10, 'psrmin', 5);

verifyLessThan(testCase, max(abs(drift.x-expectedRow)), 0.75);
verifyLessThan(testCase, max(abs(drift.y-expectedCol)), 0.75);
end

function testNewRunOverwritesOldDriftMetadata(testCase)
[images, expectedRow, expectedCol, ref] = syntheticTranslatedSequence();
f = fov();
f.drift = struct('x', 100*ones(1,size(images,4)), ...
    'y', -100*ones(1,size(images,4)));
[~, drift] = f.computeDrift('images', images, ...
    'framesid', 1:size(images,4), 'refimage', ref, ...
    'method', 'robust', 'refmode', 'fixed', 'stitch', false, ...
    'maxshift', 20, 'maxstep', 10, 'psrmin', 5);

verifyLessThan(testCase, max(abs(drift.x-expectedRow)), 0.75);
verifyLessThan(testCase, max(abs(drift.y-expectedCol)), 0.75);
end

function testPerfectAnchorHasHighConfidence(testCase)
[~,~,~,ref] = syntheticTranslatedSequence();
f = fov();
[~,drift,score] = f.computeDrift('images',ref,'method','robust');
verifyGreaterThan(testCase,score,10);
verifyGreaterThan(testCase,drift.anchorCorrelation,.99);
verifyTrue(testCase,drift.accepted);
verifyEqual(testCase,drift.x,0,'AbsTol',1e-8);
verifyEqual(testCase,drift.y,0,'AbsTol',1e-8);
verifyEqual(testCase,drift.method,'robust');
verifyEqual(testCase,drift.refMode,'fixed');
end

function testRejectedFirstFrameOfNextBlockHoldsCorrection(testCase)
[images,~,~,ref] = syntheticTranslatedSequence();
f = fov();
[~,first] = f.computeDrift('images',images(:,:,:,1:4), ...
    'framesid',1:4,'refimage',ref,'method','robust');
[~,next] = f.computeDrift('images',zeros(size(ref),'uint16'), ...
    'framesid',5,'refimage',ref,'method','robust');
verifyEqual(testCase,next.x(5),first.x(4));
verifyEqual(testCase,next.y(5),first.y(4));
verifyEqual(testCase,next.frames,1:5);
verifyEqual(testCase,next.score(1:4),first.score(1:4));
verifyEqual(testCase,next.consensusCount(1:4),first.consensusCount(1:4));
verifyEqual(testCase,next.consensusSpread(1:4),first.consensusSpread(1:4));
verifyEqual(testCase,next.accepted(1:4),first.accepted(1:4));
verifyEqual(testCase,next.anchorCorrelation(1:4),first.anchorCorrelation(1:4));
end

function testAbsoluteJumpIsRejectedAtBlockBoundary(testCase)
[~,~,~,ref] = syntheticTranslatedSequence();
f = fov();
f.computeDrift('images',ref,'refimage',ref,'method','robust');
mov = imtranslate(ref,[8 8],'FillValues',median(ref(:)));
[~,next] = f.computeDrift('images',mov,'framesid',2, ...
    'refimage',ref,'method','robust','maxstep',3);
verifyEqual(testCase,next.x(2),0,'AbsTol',1e-8);
verifyEqual(testCase,next.y(2),0,'AbsTol',1e-8);
end

function testCompactLegacyHistoryIsNormalized(testCase)
[~,~,~,ref] = syntheticTranslatedSequence();
f = fov();
f.drift = struct('frames',[11;12],'x',[-1;-2],'y',[-3;-4], ...
    'score',[15;16]);
[~,next] = f.computeDrift('images',zeros(size(ref),'uint16'), ...
    'framesid',13,'refimage',ref,'method','robust');
verifyEqual(testCase,next.frames,[11 12 13]);
verifyEqual(testCase,next.x(11:13),[-1 -2 -2]);
verifyEqual(testCase,next.y(11:13),[-3 -4 -4]);
verifyEqual(testCase,next.score(11:12),[15 16]);
end

function testExtractorPreservesHistoryAcrossMemoryBlocks(testCase)
[images,expectedRow,expectedCol] = syntheticTranslatedSequence();
images=repmat(images,1,1,1,6);
expectedRow=repmat(expectedRow,1,6);
expectedCol=repmat(expectedCol,1,6);
folder = tempname; mkdir(folder);
cleanup = onCleanup(@()rmdir(folder,'s')); %#ok<NASGU>
for k=1:size(images,4)
    imwrite(images(:,:,1,k),fullfile(folder,sprintf('frame_%03d.tif',k)));
end
f = fov(); f.id='synthetic'; f.srcpath={folder};
f.srclist={dir(fullfile(folder,'frame_*.tif'))};
f.channel={'phase'}; f.frames=size(images,4); f.interval=1; f.binning=1;
f.roi=roi('synthetic_1',[30 30 60 60]);
s=shallow(); s.fov=f; s.io=struct('path',folder,'file','project');
frameBytes=256*256*2; driftBytes=256*256*128;
available=roiExtract.availableMemoryBytes();
% Force several small streaming blocks while tolerating a 50% drop in free
% RAM between probes. The extractor's production memory guard stays active.
shareCount=max(1,floor(.5*available/(driftBytes+4*2.5*frameBytes)));
blockCount=0;
s.extractAllROICrops('MemoryOnly',true,'MemoryShareCount',shareCount, ...
    'DriftMethod','robust','DriftDebug',false,'ProgressCallback',@trackBlocks);
verifyGreaterThan(testCase,blockCount,1);
verifyEqual(testCase,f.drift.frames,1:size(images,4));
verifyEqual(testCase,numel(f.drift.score),size(images,4));
verifyLessThan(testCase,max(abs(f.drift.x-expectedRow)),0.75);
verifyLessThan(testCase,max(abs(f.drift.y-expectedCol)),0.75);
    function trackBlocks(progress)
        if isfield(progress,'blockIndex'), blockCount=max(blockCount,progress.blockIndex); end
    end
end

function [images, expectedRow, expectedCol, ref] = syntheticTranslatedSequence()
rng(7);
[x,y] = meshgrid(1:256,1:256);
base = 2000 + 300*imgaussfilt(randn(256), 2);
base = base + 8000*exp(-((x-55).^2+(y-65).^2)/(2*11^2));
base = base + 6000*exp(-((x-185).^2+(y-170).^2)/(2*17^2));
base(:,[35:42 210:218]) = base(:,[35:42 210:218]) + 5000;
base = uint16(max(0,min(65535,base)));

rawRow = [0 1.1 2.2 1.4 -0.8 -2.6 -3.1 -1.7 0.4 1.8];
rawCol = [0 -0.7 -1.5 -0.4 0.9 1.7 2.6 1.1 -0.5 -1.3];
images = zeros(256,256,1,numel(rawRow),'uint16');
for k = 1:numel(rawRow)
    frame = imtranslate(base, [rawCol(k) rawRow(k)], ...
        'linear', 'FillValues', median(base(:)));
    % A changing local object exercises the tile-consensus rejection.
    rr = 85:120;
    cc = (75+k):(110+k);
    frame(rr,cc) = uint16(min(65535, double(frame(rr,cc)) + 4000*k));
    images(:,:,1,k) = frame;
end
ref = images(:,:,1,1);
expectedRow = -rawRow;
expectedCol = -rawCol;
end
