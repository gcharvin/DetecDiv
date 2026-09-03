function tests = testClassiAddRoiImport
%TESTCLASSIADDROIIMPORT Regression tests for classifier ROI imports.
tests = functiontests(localfunctions);
end

function setupOnce(~)
repoRoot = fileparts(fileparts(fileparts(fileparts(fileparts( ...
    mfilename('fullpath'))))));
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
