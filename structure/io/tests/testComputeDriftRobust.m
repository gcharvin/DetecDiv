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
