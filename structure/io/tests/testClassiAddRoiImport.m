function tests = testClassiAddRoiImport
%TESTCLASSIADDROIIMPORT Regression tests for classifier ROI imports.
tests = functiontests(localfunctions);
end

function setupOnce(~)
repoRoot = fileparts(fileparts(fileparts(fileparts( ...
    mfilename('fullpath')))));
addpath(repoRoot);
detecdiv_setup_path;
end

function testPartialSourceCacheImportsEveryPhysicalChannel(testCase)
root = tempname;
mkdir(root);
cleanup = onCleanup(@()rmdir(root, 's')); %#ok<NASGU>

source = classi(root, 'source', 1, 'InitTraining', false);
source.category = {'Tracking'};
r = roi('source_roi', [1 1 8 8]);
r.path = source.path;
r.addChannel(uint16(11 * ones(8, 8, 1, 3)), 'ch1-PH');
r.addChannel(uint16(22 * ones(8, 8, 1, 3)), 'ch2-GFP');
r.addChannel(uint16(ones(8, 8, 1, 3)), ...
    'results_cellposeSAM_cell', [1 1 1], [0 0 0]);
r.save([], false);
r.clear;
r.load('Channel', 'results_cellposeSAM_cell', 'Silent');
verifyEqual(testCase, size(r.image, 3), 1, ...
    'The fixture must expose the partial-cache import condition.');
source.roi = r;

destination = classi(root, 'destination', 1, 'InitTraining', false);
destination.category = {'Tracking'};
destination.classes = {'stable track'};
destination.addROI(source, 'rois', 1);

target = fullfile(destination.path, 'im_source_roi.h5');
info = h5info(target);
names = sort(string({info.Datasets.Name}));
verifyEqual(testCase, names, sort(string({ ...
    'ch1-PH','ch2-GFP','results_cellposeSAM_cell'})));
verifyEqual(testCase, squeeze(h5read(target, '/ch1-PH')), ...
    uint16(11 * ones(8, 8, 3)));
verifyEqual(testCase, squeeze(h5read(target, '/ch2-GFP')), ...
    uint16(22 * ones(8, 8, 3)));
end

function testSameLocalIdFromDifferentSourcesIsNamespacedAndTraceable(testCase)
root = tempname;
mkdir(root);
cleanup = onCleanup(@()rmdir(root, 's')); %#ok<NASGU>

first = sourceClassifier(root, 'project47', 'shared_roi', 11);
second = sourceClassifier(root, 'project59', 'shared_roi', 22);
destination = classi(root, 'destination', 1, 'InitTraining', false);
destination.category = {'Tracking'};
destination.classes = {'stable track'};

destination.addROI(first, 'rois', 1);
destination.addROI(second, 'rois', 1);
verifyNumElements(testCase, destination.roi, 2);
verifyEqual(testCase, string({destination.roi.id}), ...
    ["shared_roi","project59_1__shared_roi"]);
verifyTrue(testCase, isfield(destination.roi(2).extraction, ...
    'importSourceFile'));

destination.addROI(second, 'rois', 1);
verifyNumElements(testCase, destination.roi, 2, ...
    'Repeating the same physical import must not duplicate the ROI.');
end

function testSelectedInputIsPrunedBeforeClassifierRename(testCase)
root = tempname;
mkdir(root);
cleanup = onCleanup(@()rmdir(root, 's')); %#ok<NASGU>

source = sourceWithRawChannels(root, 'source_selection');
destination = classi(root, 'destination_selection', 1, 'InitTraining', false);
destination.category = {'Tracking'};
destination.classes = {'stable track'};
destination.channelName = {'Channel0'};
map = [ ...
    importMap(true, 'raw_a', 'Channel0'), ...
    importMap(false, 'raw_b', '-'), ...
    importMap(false, 'source_mask', '-')];

destination.addROI(source, 'rois', 1, ...
    'adjustChannel', {'raw_a'}, 'adjustName', {'raw_a'}, 'ioMap', map);

verifyEqual(testCase, destination.roi(1).display.channel, {'Channel0'});
info = h5info(fullfile(destination.path, 'im_source_roi.h5'));
verifyEqual(testCase, string({info.Datasets.Name}), "Channel0");
end

function testIoMapUncheckedRowsAreAuthoritative(testCase)
root = tempname;
mkdir(root);
cleanup = onCleanup(@()rmdir(root, 's')); %#ok<NASGU>

source = sourceWithRawChannels(root, 'source_iomap');
destination = classi(root, 'destination_iomap', 1, 'InitTraining', false);
destination.category = {'Tracking'};
destination.classes = {'stable track'};
map = [ ...
    importMap(false, 'raw_a', '-'), ...
    importMap(true, 'raw_b', '-'), ...
    importMap(false, 'source_mask', '-')];

destination.addROI(source, 'rois', 1, 'ioMap', map);

verifyEqual(testCase, destination.roi(1).display.channel, {'raw_b'});
info = h5info(fullfile(destination.path, 'im_source_roi.h5'));
verifyEqual(testCase, string({info.Datasets.Name}), "raw_b");
end

function testReimportReplacesOrphanH5WithoutStaleChannels(testCase)
root = tempname;
mkdir(root);
cleanup = onCleanup(@()rmdir(root, 's')); %#ok<NASGU>

source = sourceWithRawChannels(root, 'source_reimport');
destination = classi(root, 'destination_reimport', 1, 'InitTraining', false);
destination.category = {'Tracking'};
destination.classes = {'stable track'};

orphan = roi('source_roi', [1 1 8 8]);
orphan.path = destination.path;
orphan.addChannel(uint16(99 * ones(8, 8, 1, 2)), 'stale_channel');
orphan.save([], false);
orphan.clear;

map = [ ...
    importMap(true, 'raw_a', '-'), ...
    importMap(false, 'raw_b', '-'), ...
    importMap(false, 'source_mask', '-')];
destination.addROI(source, 'rois', 1, 'ioMap', map);

info = h5info(fullfile(destination.path, 'im_source_roi.h5'));
verifyEqual(testCase, string({info.Datasets.Name}), "raw_a");
verifyEmpty(testCase, dir(fullfile(destination.path, ...
    'im_source_roi.h5.preimport*.bak')));
end

function testPackedImporterPersistsCompleteMappingTable(testCase)
testDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(fileparts(fileparts(testDir)));
sourcePath = fullfile(repoRoot, 'structure', 'GUI', ...
    'roiImporterGUI_extracted.m');
mlappPath = fullfile(repoRoot, 'structure', 'GUI', 'roiImporterGUI.mlapp');
source = fileread(sourcePath);
needle = ['app.channelMap{pixtable} = ' ...
    'channelMapFromTableData(app, data);'];
verifyTrue(testCase, contains(source, needle));
verifyTrue(testCase, contains(source, ...
    'adjustName{k} = src;'));
verifyTrue(testCase, contains(source, ...
    'roiImporterChannelNames('));

reader = appdesigner.internal.serialization.FileReader(mlappPath);
embedded = reader.readMATLABCodeText();
verifyTrue(testCase, contains(embedded, needle), ...
    'The deployed roiImporterGUI.mlapp must contain the channel-selection fix.');
end

function testImporterNormalizesRowAndColumnChannelCatalogs(testCase)
verifyEqual(testCase, roiImporterChannelNames({'A';'B';'C'}), ...
    {'A','B','C'});
verifyEqual(testCase, roiImporterChannelNames(["A";"B"]), ...
    {'A','B'});
verifyEqual(testCase, roiImporterChannelNames('A'), {'A'});
verifySize(testCase, roiImporterChannelNames({'A';'B'}), [1 2]);
end

function map = importMap(enabled, sourceName, ioChannel)
map = struct('import', enabled, 'sourceName', sourceName, ...
    'type', 'grayscale', 'destName', sourceName, ...
    'ioChannel', ioChannel);
end

function source = sourceWithRawChannels(root, name)
source = classi(root, name, 1, 'InitTraining', false);
source.category = {'Tracking'};
r = roi('source_roi', [1 1 8 8]);
r.path = source.path;
r.addChannel(uint16(11 * ones(8, 8, 1, 2)), 'raw_a');
r.addChannel(uint16(22 * ones(8, 8, 1, 2)), 'raw_b');
r.addChannel(uint16(ones(8, 8, 1, 2)), ...
    'source_mask', [1 1 1], [0 0 0]);
r.save([], false);
r.clear;
source.roi = r;
end

function source = sourceClassifier(root, name, roiId, value)
source = classi(root, name, 1, 'InitTraining', false);
source.category = {'Tracking'};
r = roi(roiId, [1 1 8 8]);
r.path = source.path;
r.addChannel(uint16(value * ones(8, 8, 1, 2)), 'ch1-PH');
r.addChannel(uint16(ones(8, 8, 1, 2)), ...
    'results_cellposeSAM_cell', [1 1 1], [0 0 0]);
r.save([], false);
r.clear;
source.roi = r;
end
