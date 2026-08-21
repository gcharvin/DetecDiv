function tests = testClassifyDataRequiredChannels
%TESTCLASSIFYDATAREQUIREDCHANNELS Required-channel cache integration tests.
tests = functiontests(localfunctions);
end

function setupOnce(~)
repoRoot = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(genpath(repoRoot));
end

function setup(~)
clearProbe();
end

function teardown(~)
clearProbe();
end

function testFirstPassLoadsEveryRequiredChannelFromPartialH5Cache(testCase)
root = tempname;
mkdir(root);
addTeardown(testCase, @() removeFolder(root));

writer = writerRoi(root, 'partial_cache');
verifyTrue(testCase, writer.save([], false));

% Reproduce the state left by a targeted CellposeSAM mutation refresh: the
% newly produced mask is in memory, while brightfield exists only on disk.
stale = roi('partial_cache', [1 1 4 3]);
stale.path = root;
stale.load('Channel', 'results_cellposeSAM_cell', ...
    'Data', false, 'Silent');
verifyEqual(testCase, size(stale.image, 3), 1);
verifyNotEmpty(testCase, stale.findChannelID( ...
    'results_cellposeSAM_cell', 'exact'));
verifyEmpty(testCase, stale.findChannelID('Channel1_z2', 'exact'));

classifier = probeClassifier(root, stale);
required = {'results_cellposeSAM_cell', 'Channel1_z2'};
ctx = struct('io', struct('requiredChannels', {required}, ...
    'strictRequiredChannels', true));
classifier.classifyData(stale, 'Frames', -1, ...
    'Channel', {required}, 'Ctx', ctx, 'OutputName', 'probe');

captured = getappdata(0, 'DetecDivClassifyDataProbe');
verifyEqual(testCase, captured.selectedChannels, required, ...
    'The outer per-ROI cell must preserve the inner multi-channel list.');
verifyTrue(testCase, all(~cellfun(@isempty, captured.indices)), ...
    'Every required channel must be addressable on the first execution.');
verifyEqual(testCase, captured.values{1}, uint16([11 12 13]));
verifyEqual(testCase, captured.values{2}, uint16([101 102 103]));
verifyEqual(testCase, size(stale.image, 3), 2);
end

function testMissingRequiredChannelFailsDeterministically(testCase)
root = tempname;
mkdir(root);
addTeardown(testCase, @() removeFolder(root));

writer = writerRoi(root, 'missing_required');
verifyTrue(testCase, writer.save([], false));
stale = roi('missing_required', [1 1 4 3]);
stale.path = root;
stale.load('Channel', 'results_cellposeSAM_cell', ...
    'Data', false, 'Silent');
classifier = probeClassifier(root, stale);
required = {'results_cellposeSAM_cell', 'not_on_disk'};
ctx = struct('io', struct('requiredChannels', {required}, ...
    'strictRequiredChannels', true));

verifyError(testCase, @() classifier.classifyData(stale, ...
    'Frames', -1, 'Channel', {required}, 'Ctx', ctx), ...
    'classifyData:RequiredChannelLoadFailed');
verifyFalse(testCase, isappdata(0, 'DetecDivClassifyDataProbe'), ...
    'Classification must not run after a required-channel load failure.');
end

function testNonStrictMissingRequiredChannelKeepsHistoricalFallback(testCase)
root = tempname;
mkdir(root);
addTeardown(testCase, @() removeFolder(root));

writer = writerRoi(root, 'tolerant_missing_required');
verifyTrue(testCase, writer.save([], false));
stale = roi('tolerant_missing_required', [1 1 4 3]);
stale.path = root;
stale.load('Channel', 'results_cellposeSAM_cell', ...
    'Data', false, 'Silent');
classifier = probeClassifier(root, stale);
required = {'results_cellposeSAM_cell', 'not_on_disk'};
ctx = struct('io', struct('requiredChannels', {required}));

classifier.classifyData(stale, 'Frames', -1, ...
    'Channel', {required}, 'Ctx', ctx, 'OutputName', 'probe');

captured = getappdata(0, 'DetecDivClassifyDataProbe');
verifyEqual(testCase, captured.selectedChannels, ...
    {'results_cellposeSAM_cell'}, ...
    ['Without the explicit annotation strictness flag, an unavailable ' ...
     'advisory channel must be ignored as before.']);
verifyNotEmpty(testCase, captured.indices{1});
end

function classifier = probeClassifier(root, roiObj)
classifier = classi(root, 'required_channel_probe', 1);
classifier.classifierPkg = 'classifyDataProbe';
classifier.classifyFun = 'classifyDataProbe.classify';
classifier.category = {'Tracking'};
classifier.description = {'Required-channel probe'};
classifier.classes = {};
classifier.channelName = {'results_cellposeSAM_cell', 'Channel1_z2'};
classifier.roi = roiObj;
end

function r = writerRoi(root, id)
r = roi(id, [1 1 4 3]);
r.path = root;
r.image = zeros(3, 4, 2, 3, 'uint16');
r.image(:,:,1,1) = 101;
r.image(:,:,1,2) = 102;
r.image(:,:,1,3) = 103;
r.image(:,:,2,1) = 11;
r.image(:,:,2,2) = 12;
r.image(:,:,2,3) = 13;
r.channelid = [1 2];
r.display = struct( ...
    'intensity', [1 1 1; 0 0 0], ...
    'frame', 1, ...
    'selectedchannel', [1 1], ...
    'binning', 1, ...
    'rgb', [1 1 1; 1 0 0], ...
    'channel', {{'Channel1_z2', 'results_cellposeSAM_cell'}}, ...
    'stretchlim', [], ...
    'displaylim', [0 0; 200 20], ...
    'indexed', [false true], ...
    'alpha', [1 0.35], ...
    'contour', [false true], ...
    'width', [1 1]);
end

function clearProbe()
if isappdata(0, 'DetecDivClassifyDataProbe')
    rmappdata(0, 'DetecDivClassifyDataProbe');
end
end

function removeFolder(folder)
if isfolder(folder), rmdir(folder, 's'); end
end
