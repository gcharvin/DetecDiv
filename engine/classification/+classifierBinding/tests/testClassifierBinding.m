function tests = testClassifierBinding
%TESTCLASSIFIERBINDING Typed training-resource catalog tests.
tests = functiontests(localfunctions);
end

function setupOnce(~)
repoRoot = fileparts(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))));
addpath(genpath(repoRoot));
end

function testCellLatentDeclaresTypedTrainingResources(testCase)
c = struct('classifierPkg', 'cellLatentModel');
spec = classifierBinding.trainingSpec(c);
verifyEqual(testCase, {spec.param}, { ...
    'trackChannelName','groundTruthFamily','brightfieldChannelName', ...
    'gfpChannelName','nucleusChannelName','budneckChannelName'});
verifyEqual(testCase, spec(1).role, 'mask_roi_image');
verifyTrue(testCase, spec(1).required);
verifyEqual(testCase, spec(2).type, 'cellModelFamily');
end

function testEveryClassifierPackageDeclaresTrainingBindings(testCase)
classificationRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
folders = dir(fullfile(classificationRoot, '+*'));
folders = folders(arrayfun(@(d) ...
    isfile(fullfile(d.folder, d.name, 'train.m')) && ...
    isfile(fullfile(d.folder, d.name, 'classify.m')), folders));
packages = erase({folders.name}, '+');
verifyNotEmpty(testCase, packages);
for i = 1:numel(packages)
    spec = classifierBinding.trainingSpec(struct('classifierPkg', packages{i}));
    verifyNotEmpty(testCase, spec, sprintf('%s has no training bindings.', packages{i}));
    verifyTrue(testCase, all(strcmp({spec.group}, 'Data bindings')));
    verifyTrue(testCase, all(~cellfun(@isempty, {spec.param})));
    defaults = feval([packages{i} '.utils.defaultTrainingParam']);
    persisted = spec(strcmpi({spec.storage}, 'trainingParam'));
    if ~isempty(persisted)
        verifyTrue(testCase, all(isfield(defaults, {persisted.param})), ...
            sprintf('%s declares a missing trainingParam binding.', packages{i}));
    end
end
end

function testLegacyInputStorageRoundTrip(testCase)
folder = tempname;
mkdir(folder);
addTeardown(testCase, @()removeFolder(folder));

c = classi(folder, 'legacy_inputs', 1);
c.classifierPkg = 'cnn_lstm';
c.trainingParam = cnn_lstm.utils.defaultTrainingParam();
c.channelName = {'old_raw'};
c.dataset.channels = {'old_raw'};

spec = classifierBinding.trainingSpec(c);
input = spec(strcmp({spec.param}, 'inputChannelNames'));
verifyEqual(testCase, classifierBinding.value(c, input), {'old_raw'});

classifierBinding.applyValue(c, input, {'brightfield','nucleus'});
verifyEqual(testCase, c.channelName, {'brightfield','nucleus'});
verifyEqual(testCase, c.dataset.channels, {'brightfield','nucleus'});
verifyEqual(testCase, c.getInputChannels(), {'brightfield','nucleus'});
end

function testNumericLegacyChannelsAreMigrated(testCase)
folder = tempname;
mkdir(folder);
addTeardown(testCase, @()removeFolder(folder));

c = classi(folder, 'numeric_legacy', 1);
c.classifierPkg = 'cellposesam';
c.trainingParam = cellposesam.utils.defaultTrainingParam();
r = roiWithRaw(folder, 'R1');
r.display.channel = {'brightfield','mask'};
r.display.indexed = [false true];
c.roi = r;
c.channel = 2;
c.channelName = {};
c.dataset.channels = {};

report = classifierBinding.normalizeClassifier(c);
verifyTrue(testCase, report.migratedChannels);
verifyEqual(testCase, c.channelName, {'mask'});
verifyEqual(testCase, c.dataset.channels, {'mask'});
end

function testNestedLegacyEnumsAreFlattened(testCase)
folder = tempname;
mkdir(folder);
addTeardown(testCase, @()removeFolder(folder));

c = classi(folder, 'nested_enum', 1);
c.classifierPkg = 'cellLatentModel';
c.trainingParam = struct( ...
    'trainingObjective', {{{'relation_ensemble','continuous_lineage', ...
        'continuous_lineage'}}}, ...
    'tip', {{}});
report = classifierBinding.normalizeClassifier(c);
verifyEqual(testCase, c.trainingParam.trainingObjective, ...
    {'relation_ensemble','continuous_lineage','continuous_lineage'});
verifyTrue(testCase, any(strcmp(report.flattenedParameters, 'trainingObjective')));
end

function testManagedAnnotationBindingIsReadOnly(testCase)
folder = tempname;
mkdir(folder);
addTeardown(testCase, @()removeFolder(folder));

c = classi(folder, 'cpsam_gt', 1);
c.classifierPkg = 'cellposesam';
c.category = {'Pixel'};
c.classes = {'cell'};
c.trainingParam = cellposesam.utils.defaultTrainingParam();
spec = classifierBinding.trainingSpec(c);
gt = spec(strcmp({spec.param}, 'groundTruthChannelName'));
verifyFalse(testCase, gt.editable);
verifyEqual(testCase, classifierBinding.value(c, gt), [c.strid '_cell']);
verifyError(testCase, @()classifierBinding.applyValue(c, gt, 'other'), ...
    'classifierBinding:ReadOnlyBinding');
end

function testCatalogReportsRoiCoverageAndSemanticChoices(testCase)
folder = tempname;
mkdir(folder);
addTeardown(testCase, @()removeFolder(folder));

c = classi(folder, 'binding_demo', 1);
c.classifierPkg = 'cellLatentModel';
c.trainingParam = cellLatentModel.utils.defaultTrainingParam();

r1 = roiWithRaw(folder, 'R1');
mask = zeros(4, 4, 1, 3, 'uint16');
mask(2:3, 2:3, 1, :) = 1;
r1.addChannel(mask, 'reviewed_mask', [1 1 1], [0 0 0]);
maskIdx = r1.findChannelID('reviewed_mask', 'exact');
r1.display.indexed(maskIdx) = true;

model = cellModel.create(r1.id);
[model, ~, ~] = cellModel.applyLineageResult(model, ...
    squeeze(mask), 'reviewed_mask', '', 'Reviewed lineage', ...
    struct('edges', struct([])), true, 'ground_truth');
r1.saveCellModel(model);

r2 = roiWithRaw(folder, 'R2');
c.roi = [r1 r2];

catalog = classifierBinding.catalog(c);
verifyEqual(testCase, catalog.roiCount, 2);

spec = classifierBinding.trainingSpec(c);
maskChoices = classifierBinding.choices(spec(1), catalog, '');
verifyTrue(testCase, any(strcmp(maskChoices.values, 'reviewed_mask')));
label = maskChoices.labels{strcmp(maskChoices.values, 'reviewed_mask')};
verifyTrue(testCase, contains(label, '1/2 ROI'));
verifyFalse(testCase, any(strcmp(maskChoices.values, 'raw')));

familyChoices = classifierBinding.choices(spec(2), catalog, '<auto>');
verifyTrue(testCase, any(strcmp(familyChoices.values, 'Reviewed lineage')));
label = familyChoices.labels{strcmp(familyChoices.values, 'Reviewed lineage')};
verifyTrue(testCase, contains(label, '1/2 ROI'));

imageChoices = classifierBinding.choices(spec(3), catalog, '');
verifyTrue(testCase, any(strcmp(imageChoices.values, 'raw')));
verifyFalse(testCase, any(strcmp(imageChoices.values, 'reviewed_mask')));
end

function r = roiWithRaw(folder, id)
r = roi(id, [1 1 4 4]);
r.path = folder;
r.image = uint16(ones(4, 4, 1, 3));
r.channelid = 1;
r.display.channel = {'raw'};
r.display.intensity = [1 1 1];
r.display.rgb = [1 1 1];
r.display.selectedchannel = true;
r.display.indexed = false;
r.display.alpha = 1;
r.display.contour = false;
r.display.width = 1;
end

function removeFolder(folder)
if isfolder(folder), rmdir(folder, 's'); end
end
