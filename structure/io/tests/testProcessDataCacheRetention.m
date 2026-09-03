function tests = testProcessDataCacheRetention
%TESTPROCESSDATACACHERETENTION Processor cache integration tests.
tests = functiontests(localfunctions);
end

function setupOnce(~)
repoRoot = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(genpath(repoRoot));
end

function testAutoCacheReleasesImageLoadedForDataOnlyProcessor(testCase)
root = tempname;
mkdir(root);
addTeardown(testCase, @() removeFolder(root));

writer = writerRoi(root, 'processor_transient_image');
verifyTrue(testCase, writer.save([], false));

candidate = roi('processor_transient_image', [1 1 4 3]);
candidate.path = root;
verifyEmpty(testCase, candidate.image);
verifyNotEmpty(testCase, candidate.data, ...
    'The legacy scalar dataseries placeholder is required for this regression test.');

processor = process(root, 'process_probe', 1);
processor.processFun = 'processDataProbe.process';
processor.processArg = struct();
ctx = struct('outputName', 'process_probe', ...
    'io', struct('requiredChannels', {{'Channel1_z2'}}, ...
    'strictRequiredChannels', true, 'cachePolicy', 'auto'));

processor.processData(candidate, 'Ctx', ctx);

verifyEmpty(testCase, candidate.image, ...
    ['cachePolicy=auto must release an image loaded by processData when ' ...
     'the processor returns dataseries only.']);
verifyEmpty(testCase, candidate.data, ...
    'A placeholder must not be treated as a caller-owned data cache.');
verifyTrue(testCase, isfile(fullfile(root, 'data_processor_transient_image.mat')));

candidate.load('data', 'Silent');
verifyTrue(testCase, any(arrayfun( ...
    @(ds) strcmp(ds.groupid, 'process_probe'), candidate.data)));
end

function r = writerRoi(root, id)
r = roi(id, [1 1 4 3]);
r.path = root;
r.image = zeros(3, 4, 1, 3, 'uint16');
r.image(:,:,1,1) = 101;
r.image(:,:,1,2) = 102;
r.image(:,:,1,3) = 103;
r.channelid = 1;
r.display = struct( ...
    'intensity', [1 1 1], ...
    'frame', 1, ...
    'selectedchannel', 1, ...
    'binning', 1, ...
    'rgb', [1 1 1], ...
    'channel', {{'Channel1_z2'}}, ...
    'stretchlim', [], ...
    'displaylim', [0; 200], ...
    'indexed', false, ...
    'alpha', 1, ...
    'contour', false, ...
    'width', 1);
end

function removeFolder(folder)
if isfolder(folder), rmdir(folder, 's'); end
end
