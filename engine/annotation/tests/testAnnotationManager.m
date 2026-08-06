function tests = testAnnotationManager
%TESTANNOTATIONMANAGER Backend annotation lifecycle integration tests.
tests = functiontests(localfunctions);
end

function setupOnce(~)
repoRoot = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(genpath(repoRoot));
end

function testPackageSpecsAndLegacyFallback(testCase)
c = struct('strid', 'demo_1', 'classifierPkg', 'cnn_lstm', ...
    'category', {{'LSTM'}}, 'classes', {{'alpha','beta'}}, ...
    'executionParam', struct('outputName', 'pred'), ...
    'trainingParam', struct(), 'channelName', {{'raw'}});
spec = annotationManager.specForClassifier(c);
verifyEqual(testCase, spec.defaultEditor, 'class_palette');
verifyEqual(testCase, spec.components.kind, 'frame_labels');
verifyEqual(testCase, spec.components.groundTruth.valueField, 'labels_training');

c.classifierPkg = '';
c.category = {'Pixel'};
spec = annotationManager.specForClassifier(c);
verifyTrue(testCase, spec.legacyFallback);
verifyEqual(testCase, spec.components.storage, 'channel');
end

function testMaskBootstrapReviewApprovalAndHash(testCase)
[folder, c, r] = maskFixture(testCase);
session = c.annotationSession(1);
verifyEqual(testCase, session.summary().status, 'missing');

report = session.bootstrap();
verifyEqual(testCase, report.status, 'draft');
verifyNotEmpty(testCase, r.findChannelID('demo_1_cell'));
verifyEqual(testCase, session.summary().coverage.fraction, 0);

failed = session.validate();
verifyFalse(testCase, failed.valid);
session.markReviewed('Frames', 1:3);
validation = session.validate();
verifyTrue(testCase, validation.valid, strjoin(cellstr(validation.errors), ' '));
[entry, ~] = session.approve();
verifyEqual(testCase, entry.status, 'approved');
verifyNotEmpty(testCase, entry.approved_hash);
verifyEqual(testCase, session.summary('VerifyHash', true).status, 'approved');

fresh = roi('R1', [1 1 4 4]);
fresh.path = folder;
fresh.load('Data', 'Silent');
persisted = annotationManager.inspect(fresh, session.Spec);
verifyEqual(testCase, persisted.status, 'approved');

idx = r.findChannelID('demo_1_cell');
r.image(1,1,idx,1) = uint16(9);
r.save({'demo_1_cell'}, false);
verifyEqual(testCase, session.summary('VerifyHash', true).status, 'draft');
end

function testBootstrapDoesNotOverwriteReviewedMask(testCase)
[~, c, r] = maskFixture(testCase);
session = c.annotationSession(1);
session.bootstrap();
idx = r.findChannelID('demo_1_cell');
r.image(1,1,idx,1) = uint16(7);
verifyError(testCase, @() session.bootstrap(), ...
    'annotationManager:GroundTruthExists');
session.bootstrap('Overwrite', true);
verifyEqual(testCase, r.image(1,1,idx,1), uint16(0));
end

function testStartBlankCreatesExplicitEditableEmptyMask(testCase)
[~, c, r] = maskFixture(testCase);
session = c.annotationSession(1);
report = session.startBlank();
verifyEqual(testCase, report.status, 'draft');
idx = r.findChannelID('demo_1_cell');
verifyNotEmpty(testCase, idx);
verifyEqual(testCase, nnz(r.image(:,:,idx,:)), 0);
verifyFalse(testCase, session.validate().valid);
session.markReviewed('Frames', 1:3);
verifyTrue(testCase, session.validate().valid);
end

function testFrameLabelBootstrap(testCase)
folder = freshFolder(testCase);
c = classi(folder, 'labels', 1);
c.classifierPkg = 'cnn_lstm';
c.category = {'LSTM'};
c.classes = {'alpha','beta'};
c.executionParam = struct('outputName', 'pred_labels');
r = roi('R1', [1 1 3 3]);
r.path = c.path;
r.image = uint16(ones(3,3,1,4));
r.channelid = 1;
r.display.channel = {'raw'};
ds = dataseries;
ds.groupid = 'pred_labels';
ds.parentid = 'R1';
ds.class = "classification";
ds.data = table(categorical({'alpha';'beta';'alpha';'beta'}, c.classes), ...
    [1;2;1;2], 'VariableNames', {'labels','id'});
r.data = ds;
c.roi = r;

session = c.annotationSession(1);
report = session.bootstrap('Save', false);
verifyTrue(testCase, report.dataChanged);
idx = find(arrayfun(@(x) strcmp(x.groupid, c.strid), r.data), 1);
verifyNotEmpty(testCase, idx);
verifyEqual(testCase, string(r.data(idx).data.labels_training), ...
    string(ds.data.labels));
verifyError(testCase, @() session.bootstrap('Save', false), ...
    'annotationManager:GroundTruthExists');
session.markReviewed('Frames', 1:4, 'Save', false);
verifyTrue(testCase, session.validate().valid);
end

function testLatentBundleClonesFamilyAndRebindsMask(testCase)
folder = freshFolder(testCase);
c = classi(folder, 'latent', 1);
c.classifierPkg = 'cellLatentModel';
c.category = {'Tracking'};
c.classes = {'latent lineage link'};
c.executionParam = struct( ...
    'trackChannelName', '', ...
    'outputFamilyName', 'Predicted lineage');
c.channelName = {'raw'};
c.trainingParam = struct('groundTruthFamily', '<auto>', ...
    'trackChannelName', '');
r = roiWithRaw(c.path, 'R1', 4, 4, 3);
masks = zeros(4,4,1,3, 'uint16');
masks(1:2,1:2,1,:) = 1;
masks(3:4,3:4,1,2:3) = 2;
r.addChannel(masks, 'results_cellposeSAM_cell', [1 1 1], [0 0 0]);
r.save([], false);

edge = struct('status', 'linked', 'pred_parent_id', 1, ...
    'child_track_id', 2, 'bud_appearance_frame', 2, 'top_score', 0.9);
model = cellModel.create(r.id);
[model, ~, ~] = cellModel.applyLineageResult(model, squeeze(masks(:,:,1,:)), ...
    'results_cellposeSAM_cell', '', 'Predicted lineage', ...
    struct('edges', edge), true, 'classifier');
r.saveCellModel(model);
c.roi = r;

session = c.annotationSession(1);
summary = session.summary();
maskState = summary.components(strcmp({summary.components.id}, 'tracked_mask'));
verifyEqual(testCase, maskState.predictionName, 'results_cellposeSAM_cell', ...
    'The stored family provider must take precedence over raw classifier inputs.');
report = session.bootstrap();
verifyTrue(testCase, report.modelChanged);
[gtChannel, gtExists] = annotationManager.resolveChannel(r, ...
    annotationManager.newAsset('channel', 'latent_1_cell'));
verifyTrue(testCase, gtExists);
verifyEqual(testCase, gtChannel, 'latent_1_cell');
verifyEqual(testCase, r.image(:,:,r.findChannelID(gtChannel),:), masks);
[model, ~] = r.loadCellModel();
[sourceIdx, sourceId] = cellModel.familyIndex(model, 'Predicted lineage');
[gtIdx, gtId] = cellModel.familyIndex(model, 'latent_1 reviewed GT');
verifyNotEmpty(testCase, sourceIdx);
verifyNotEmpty(testCase, gtIdx);
verifyEqual(testCase, model.families.mask_provider{sourceIdx}, ...
    'results_cellposeSAM_cell');
verifyEqual(testCase, model.families.mask_provider{gtIdx}, 'latent_1_cell');
verifyEqual(testCase, nnz(model.instances.family_id == sourceId), ...
    nnz(model.instances.family_id == gtId));
verifyEqual(testCase, nnz(model.relations.family_id == sourceId), 1);
verifyEqual(testCase, nnz(model.relations.family_id == gtId), 1);
verifyEqual(testCase, c.trainingParam.groundTruthFamily, ...
    'latent_1 reviewed GT');
verifyEqual(testCase, c.trainingParam.trackChannelName, 'latent_1_cell');

session.markReviewed('Frames', 1:3, 'Components', {'tracked_mask'});
session.markReviewed('Components', {'lineage'});
verifyTrue(testCase, session.validate().valid);

gtIdx = r.findChannelID('latent_1_cell');
r.image(:,:,gtIdx,:) = uint16(17);
r.save({'latent_1_cell'}, false);
invalid = session.validate();
verifyFalse(testCase, invalid.valid);
verifyTrue(testCase, any(contains(invalid.errors, ...
    'does not match object family')));
end

function testClassifierSummaryUsesSharedStatus(testCase)
[~, c, ~] = maskFixture(testCase);
rows = c.annotationSummary();
verifyEqual(testCase, rows.status, 'missing');
rows = annotationManager.summarizeClassifier(c, [], 'Fast', true);
verifyEqual(testCase, rows.status, 'missing');
session = c.annotationSession(1);
session.bootstrap();
rows = c.annotationSummary();
verifyEqual(testCase, rows.status, 'draft');
verifyEqual(testCase, rows.supportsBootstrap, true);
rows = annotationManager.summarizeClassifier(c, [], 'Fast', true);
verifyEqual(testCase, rows.status, 'draft');
end

function [roiFolder, c, r] = maskFixture(testCase)
folder = freshFolder(testCase);
c = classi(folder, 'demo', 1);
c.classifierPkg = 'cellposesam';
c.category = {'Pixel'};
c.classes = {'cell'};
c.executionParam = struct('outputName', 'demo_pred');
r = roiWithRaw(c.path, 'R1', 4, 4, 3);
prediction = zeros(4,4,1,3, 'uint16');
prediction(2:3,2:3,1,:) = 1;
r.addChannel(prediction, 'results_demo_pred_cell', [1 1 1], [0 0 0]);
r.save([], false);
c.roi = r;
roiFolder = c.path;
end

function r = roiWithRaw(folder, id, height, width, frames)
r = roi(id, [1 1 width height]);
r.path = folder;
r.image = uint16(ones(height, width, 1, frames));
r.channelid = 1;
r.display.channel = {'raw'};
r.display.intensity = [1 1 1];
r.display.rgb = [1 1 1];
r.display.selectedchannel = 1;
r.display.indexed = false;
r.display.alpha = 1;
r.display.contour = false;
r.display.width = 1;
end

function folder = freshFolder(testCase)
folder = tempname;
mkdir(folder);
addTeardown(testCase, @() removeFolder(folder));
end

function removeFolder(folder)
if isfolder(folder), rmdir(folder, 's'); end
end
