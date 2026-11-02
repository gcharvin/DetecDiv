function tests = testComputeDriftIncremental
tests = functiontests(localfunctions);
end

function testMotionAtEveryBlockBoundaryMatchesOneBlock(testCase)
rows = [0 1 2 9 10 11 17 16 15];
cols = [0 -.5 -1 -8 -8.5 -9 -3 -2.5 -2];
images = sequence(rows, cols);
verifyBlocks(testCase, images, 1:numel(rows), {1:3, 4:6, 7:9}, {});
end

function testFractionalMotionWithCropMatchesOneBlock(testCase)
rows = [0 .3 1.1 2.7 3.2 4.8 5.1 6.9 7.3];
cols = [0 -.2 -.8 -1.3 -2.6 -3.1 -4.7 -4.9 -5.4];
images = sequence(rows, cols);
verifyBlocks(testCase, images, 1:numel(rows), {1:2, 3:5, 6:9}, {'crop', .75});
end

function testSingleFrameBlocksAndSparseFrameIdsMatchOneBlock(testCase)
images = sequence([0 .5 1.8 3.1 4.2], [0 -.3 -1.2 -2.4 -3.1]);
verifyBlocks(testCase, images, [1 4 7 10 13], {1, 2, 3, 4, 5}, {});
end

function testNewSequenceCanStartAfterFrameOne(testCase)
images = sequence([0 1 2], [0 -.5 -1]);
verifyBlocks(testCase, images, 11:13, {1, 2:3}, {});
end

function testMissingPreviousImageIsLoadedFromFovSource(testCase)
images = sequence([0 1 7 8], [0 -1 -6 -7]);
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@()rmdir(folder, 's')); %#ok<NASGU>
for k = 1:size(images, 4)
    imwrite(images(:,:,1,k), fullfile(folder, sprintf('frame_%03d.tif', k)));
end
f = fov();
f.srcpath = {folder};
f.srclist = {dir(fullfile(folder, 'frame_*.tif'))};
f.channel = {'phase'};
f.frames = size(images, 4);
f.interval = 1;
args = {'method', 'subpixel', 'refmode', 'previous', 'maxstep', 20};
whole = fov();
[~, expected] = whole.computeDrift('images', images(:,:,1,:), args{:});
f.computeDrift('images', images(:,:,1,1:2), 'framesid', 1:2, args{:});
[~, actual] = f.computeDrift('images', images(:,:,1,3:4), 'framesid', 3:4, args{:});
verifyEqual(testCase, actual.x, expected.x, 'AbsTol', 1e-8);
verifyEqual(testCase, actual.y, expected.y, 'AbsTol', 1e-8);
verifyTrue(testCase, all(actual.accepted));
end

function testMissingPreviousImageAndSourceFailsExplicitly(testCase)
images = sequence([0 1 7], [0 -1 -6]);
f = fov();
args = {'method', 'subpixel', 'refmode', 'previous'};
f.computeDrift('images', images(:,:,:,1:2), 'framesid', 1:2, args{:});
verifyError(testCase, @()f.computeDrift('images', images(:,:,:,3), ...
    'framesid', 3, args{:}), 'computeDrift:MissingPreviousImage');
end

function verifyBlocks(testCase, images, frames, blocks, extraArgs)
args = [{'method', 'subpixel', 'refmode', 'previous', ...
    'maxshift', 20, 'maxstep', 20, 'psrmin', 10}, extraArgs];
f = fov();
[expectedImages, expected] = f.computeDrift('images', images, 'framesid', frames, args{:});
f = fov();
actualImages = zeros(size(images), 'like', images);
for b = 1:numel(blocks)
    indices = blocks{b};
    previous = {};
    if b > 1
        previous = {'previousimage', images(:,:,1,indices(1)-1)};
    end
    [actualImages(:,:,:,indices), actual] = f.computeDrift( ...
        'images', images(:,:,:,indices), 'framesid', frames(indices), ...
        previous{:}, args{:});
end
verifyEqual(testCase, actual.x, expected.x, 'AbsTol', 1e-8);
verifyEqual(testCase, actual.y, expected.y, 'AbsTol', 1e-8);
verifyEqual(testCase, actualImages, expectedImages);
verifyEqual(testCase, actual.decision(frames), expected.decision(frames));
verifyTrue(testCase, all(actual.accepted(frames)));
for b = 2:numel(blocks)
    first = frames(blocks{b}(1));
    verifyGreaterThan(testCase, actual.score(first), 10);
end
end

function images = sequence(rows, cols)
rng(208);
ref = uint16(15000 + 2500*imgaussfilt(randn(192), 1.2));
images = zeros(192, 192, 2, numel(rows), 'uint16');
for k = 1:numel(rows)
    images(:,:,1,k) = imtranslate(ref, [cols(k) rows(k)], ...
        'linear', 'FillValues', median(ref(:)));
    images(:,:,2,k) = uint16(400 + .7*double(images(:,:,1,k)));
end
end
