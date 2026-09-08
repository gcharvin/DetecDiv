function tests = testCellposeVariableSizeFramebank
tests = functiontests(localfunctions);
end

function setupOnce(~)
repoRoot = fileparts(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))));
addpath(genpath(repoRoot));
end

function testFormatterPadsCopiesWithoutChangingRawRois(testCase)
root = tempname;
mkdir(root);
cleanup = onCleanup(@() removeTestFolder(root));

classifier = classi(root, 'variable_cellpose', 1, 'InitTraining', false);
classifier.channelName = 'raw';
classifier.classes = {'cell'};
classifier.trainingParam = struct( ...
    'min_train_masks', 0, ...
    'min_train_pixels', 0, ...
    'MaxTrainImages', 0, ...
    'NegDownsampleTrainRatio', 0, ...
    'CPSAM_ValFraction', 0, ...
    'Seed', 11);

nativeSizes = [60 59; 137 66];
rois(1,2) = roi;
for index = 1:2
    height = nativeSizes(index, 1);
    width = nativeSizes(index, 2);
    item = roi(sprintf('roi_%d', index), [1 1 width height]);
    item.path = classifier.path;

    raw = uint8(reshape(mod(0:(height * width - 1), 251), height, width));
    mask = zeros(height, width, 'uint16');
    mask(5:min(15,height), 4:min(12,width)) = uint16(index);
    item.addChannel(reshape(raw, height, width, 1, 1), 'raw');
    item.addChannel(reshape(mask, height, width, 1, 1), ...
        [classifier.strid '_cell'], [1 1 1], [0 0 0]);
    verifyTrue(testCase, item.save([], false));
    item.clear;
    rois(index) = item;
end
classifier.roi = rois;

outputCount = formatPixelTrainingSetCPSAM( ...
    'trainingdataset', classifier, [1 2], [], 'Frames', 0);
verifyEqual(testCase, outputCount, 2);

framebank = fullfile(classifier.path, [classifier.strid '_framebank.h5']);
verifyTrue(testCase, isfile(framebank));
verifyEqual(testCase, h5read(framebank, '/original_size'), int32(nativeSizes.'));
verifyEqual(testCase, h5read(framebank, '/pad_offset'), int32([38 0; 3 0]));

images = h5read(framebank, '/images');
masks = h5read(framebank, '/masks');
verifyEqual(testCase, size(images), [137 66 1 2]);
verifyEqual(testCase, size(masks), [137 66 2]);

firstRows = 39:98;
firstCols = 4:62;
expectedRaw = uint16(reshape(mod(0:(60 * 59 - 1), 251), 60, 59));
expectedRaw = uint8(255 * mat2gray(expectedRaw));
verifyEqual(testCase, images(firstRows, firstCols, 1, 1), ...
    expectedRaw);
verifyEqual(testCase, masks(firstRows, firstCols, 1), ...
    expectedMask(60, 59, 1));
verifyEqual(testCase, nnz(images(1:38,:,:,1)), 0);
verifyEqual(testCase, nnz(masks(1:38,:,1)), 0);

for index = 1:2
    classifier.roi(index).load('Silent');
    verifyEqual(testCase, size(classifier.roi(index).image, 1), nativeSizes(index,1));
    verifyEqual(testCase, size(classifier.roi(index).image, 2), nativeSizes(index,2));
end
end

function mask = expectedMask(height, width, value)
mask = zeros(height, width, 'uint16');
mask(5:min(15,height), 4:min(12,width)) = uint16(value);
end

function removeTestFolder(folder)
if isfolder(folder)
    rmdir(folder, 's');
end
end
