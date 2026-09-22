function tests = testRoiStreamingFrameSave
%TESTROISTREAMINGFRAMESAVE Regression tests for roiExtract block writes.
tests = functiontests(localfunctions);
end

function setupOnce(~)
repoRoot = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(genpath(repoRoot));
end

function testStreamingUpsertAppendsWithoutWholeFileBackup(testCase)
root = tempname;
mkdir(root);
addTeardown(testCase, @() removeFolder(root));

r = makeRoi(root);
r.image = blockWithValues([11 12]);
r.display.write_abs_start = 0;
r.display.write_streaming_inplace = true;
verifyTrue(testCase, r.save({'raw'}, false));

h5File = fullfile(root, 'im_streaming_roi.h5');
bakFile = fullfile(root, 'im_streaming_roi.bak');
verifyTrue(testCase, isfile(h5File));
verifyFalse(testCase, isfile(bakFile));

r.image = blockWithValues([21 22]);
r.display.write_abs_start = 2;
r.display.write_streaming_inplace = true;
verifyTrue(testCase, r.save({'raw'}, false));
verifyFalse(testCase, isfile(bakFile), ...
    'Streaming frame upserts must not copy the complete previous HDF5 to .bak.');

actual = squeeze(h5read(h5File, '/raw'));
verifySize(testCase, actual, [3 4 4]);
verifyEqual(testCase, squeeze(actual(1,1,:))', uint16([11 12 21 22]));
end

function testStreamingRetryOverwritesSameHyperslab(testCase)
root = tempname;
mkdir(root);
addTeardown(testCase, @() removeFolder(root));

r = makeRoi(root);
r.image = blockWithValues([1 2]);
r.display.write_abs_start = 0;
r.display.write_streaming_inplace = true;
verifyTrue(testCase, r.save({'raw'}, false));

r.image = blockWithValues([3 4]);
r.display.write_abs_start = 2;
verifyTrue(testCase, r.save({'raw'}, false));

r.image = blockWithValues([30 40]);
r.display.write_abs_start = 2;
verifyTrue(testCase, r.save({'raw'}, false));

actual = squeeze(h5read(fullfile(root, 'im_streaming_roi.h5'), '/raw'));
verifySize(testCase, actual, [3 4 4]);
verifyEqual(testCase, squeeze(actual(1,1,:))', uint16([1 2 30 40]));
end

function r = makeRoi(root)
r = roi('streaming_roi', [1 1 4 3]);
r.path = root;
r.channelid = 1;
r.display = struct( ...
    'intensity', [1 1 1], ...
    'frame', 1, ...
    'selectedchannel', 1, ...
    'binning', 1, ...
    'rgb', [1 1 1], ...
    'channel', {{'raw'}}, ...
    'stretchlim', [], ...
    'displaylim', [0; 65535], ...
    'indexed', false, ...
    'alpha', 1, ...
    'contour', false, ...
    'width', 1);
end

function image = blockWithValues(values)
image = zeros(3, 4, 1, numel(values), 'uint16');
for i = 1:numel(values)
    image(:,:,1,i) = uint16(values(i));
end
end

function removeFolder(folder)
if isfolder(folder), rmdir(folder, 's'); end
end
