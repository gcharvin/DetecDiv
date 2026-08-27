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
verifyNotEmpty(testCase, r.findChannelID('gt_demo_1_instances'));
verifyEqual(testCase, session.summary().coverage.fraction, 0);

failed = session.validate();
verifyFalse(testCase, failed.valid);
verifyEqual(testCase, session.LastValidationStatus, 'invalid');
reopened = c.annotationSession(1);
verifyEqual(testCase, reopened.LastValidationStatus, 'invalid', ...
    'A failed validation must survive replacement of the active Score session.');
session.markReviewed('Frames', 1:3);
verifyEqual(testCase, session.LastValidationStatus, 'not_run');
reopened = c.annotationSession(1);
verifyEqual(testCase, reopened.LastValidationStatus, 'not_run', ...
    'Review or GT edits must invalidate the persisted validation result.');
validation = session.validate();
verifyTrue(testCase, validation.valid, strjoin(cellstr(validation.errors), ' '));
verifyEqual(testCase, session.LastValidationStatus, 'valid');
validatedSummary = session.summary('VerifyHash', true);
verifyEqual(testCase, validatedSummary.status, 'approved', ...
    'Successful validation must finalize the current GT revision.');
verifyNotEmpty(testCase, validatedSummary.entry.approved_hash);
reopened = c.annotationSession(1);
verifyEqual(testCase, reopened.LastValidationStatus, 'valid', ...
    'A successful validation must survive replacement of the active session.');
rows = annotationManager.summarizeClassifier(c, 1, 'Fast', true);
verifyEqual(testCase, rows.validationStatus, 'valid', ...
    'classifierGUI summaries must expose the persisted per-ROI validation.');
[entry, ~] = session.approve();
verifyEqual(testCase, entry.status, 'approved');
verifyEqual(testCase, session.LastValidationStatus, 'valid');
verifyNotEmpty(testCase, entry.approved_hash);
verifyEqual(testCase, session.summary('VerifyHash', true).status, 'approved');

fresh = roi('R1', [1 1 4 4]);
fresh.path = folder;
fresh.load('Data', 'Silent');
persisted = annotationManager.inspect(fresh, session.Spec);
verifyEqual(testCase, persisted.status, 'approved');

idx = r.findChannelID('gt_demo_1_instances');
r.image(1,1,idx,1) = uint16(9);
r.save({'gt_demo_1_instances'}, false);
verifyEqual(testCase, session.summary('VerifyHash', true).status, 'draft');
rows = annotationManager.summarizeClassifier(c, 1, 'Fast', true);
verifyEqual(testCase, rows.status, 'draft', ...
    'classifierGUI must hash-check approved GT even in Fast summaries.');
verifyEqual(testCase, rows.validationStatus, 'not_run');
verifyTrue(testCase, rows.staleApproval);
verifyNotEmpty(testCase, rows.hashVerificationError);
end

function testFastSummaryRequiresExplicitApprovalForDraftValidMetadata(testCase)
[~, c, ~] = maskFixture(testCase);
session = c.annotationSession(1);
session.bootstrap();
session.markReviewed('Frames', 1:3);
verifyTrue(testCase, session.validate().valid);
[entry, found] = annotationManager.entryForSpec(session.Roi, session.Spec);
verifyTrue(testCase, found);
verifyEqual(testCase, entry.status, 'approved');

% Reproduce the inconsistent historical metadata observed on Pos0_1_47:
% the validation hash is current, but the lifecycle was left Draft.
entry.status = 'draft';
annotationManager.setEntry(session.Roi, session.Spec, entry, 'Save', false);
rows = annotationManager.summarizeClassifier(c, 1, 'Fast', true);

verifyEqual(testCase, rows.status, 'draft');
verifyEqual(testCase, rows.validationStatus, 'not_run', ...
    'A Draft must require an explicit Validate GT transition.');
verifyFalse(testCase, rows.staleApproval);
end

function testBootstrapDoesNotOverwriteReviewedMask(testCase)
[~, c, r] = maskFixture(testCase);
session = c.annotationSession(1);
session.bootstrap();
idx = r.findChannelID('gt_demo_1_instances');
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
idx = r.findChannelID('gt_demo_1_instances');
verifyNotEmpty(testCase, idx);
verifyEqual(testCase, nnz(r.image(:,:,idx,:)), 0);
verifyFalse(testCase, session.validate().valid);
session.markReviewed('Frames', 1:3);
verifyTrue(testCase, session.validate().valid);
end

function testSessionOwnsPerRoiTrainingBounds(testCase)
[~, c, ~] = maskFixture(testCase);
session = c.annotationSession(1);

verifyEmpty(testCase, session.frameBounds());
verifyEqual(testCase, session.uiContext().frameBoundsText, 'all');
session.setFrameBounds('2:3');
verifyEqual(testCase, session.frameBounds(), [2 3]);
verifyEqual(testCase, session.uiContext().frameBoundsText, '2:3');
verifyEqual(testCase, c.bounds.Type, 'Manual');
session.bootstrap();
session.markReviewed();
boundedSummary = session.summary();
verifyEqual(testCase,boundedSummary.reviewFrames,2:3);
verifyEqual(testCase,boundedSummary.coverage.reviewed,2);
verifyEqual(testCase,boundedSummary.coverage.total,2);
verifyFalse(testCase,boundedSummary.entry.review(1).frames(1));
verifyTrue(testCase,session.validate().valid, ...
    'Frames outside the training bounds must not block validation.');
boundedSummary = session.summary('VerifyHash', true);
verifyEqual(testCase, boundedSummary.status, 'approved');
verifyEqual(testCase, boundedSummary.reviewFrames, 2:3);
rows = annotationManager.summarizeClassifier(c,1,'Fast',true);
verifyEqual(testCase,rows.total,2);
verifyEqual(testCase,rows.reviewed,2);
verifyEqual(testCase, rows.status, 'approved', ...
    'Classifier-bound summaries must use the same partial bounds as Score.');
fullRoiSummary = annotationManager.inspect(c.roi(1), session.Spec, ...
    'CheckAssets', false);
verifyEqual(testCase, fullRoiSummary.status, 'draft', ...
    ['Bare inspect is deliberately full-ROI and must not be used by ' ...
     'classifier-bound UI or preflight callers.']);
verifyEqual(testCase, fullRoiSummary.coverage.total, 3);
verifyEqual(testCase, fullRoiSummary.coverage.reviewed, 2);
session.clearFrameBounds();
verifyEmpty(testCase, session.frameBounds());
verifyEqual(testCase, session.uiContext().frameBoundsText, 'all');
verifyEqual(testCase,session.summary().coverage.total,3);
verifyFalse(testCase,session.validate().valid, ...
    'Returning to all must expose the still-unreviewed frame.');
end

function testChangedFramesReviewOnlyFrameUnits(testCase)
r = roi('review', [1 1 2 2]);
r.image = zeros(2,2,1,3,'uint16');
r.display.channel = {'mask'};
spec = annotationManager.newSpec(struct('strid','review'));
frameComponent = annotationManager.newComponent( ...
    'id','segmentation','kind','instance_mask','storage','channel', ...
    'coverageUnit','frame', ...
    'groundTruth',annotationManager.newAsset('channel','mask'));
roiComponent = annotationManager.newComponent( ...
    'id','parentage','kind','lineage','storage','cell_model_family', ...
    'coverageUnit','roi');
spec.components = [frameComponent; roiComponent];

annotationManager.markReviewed(r, spec, 'Frames', 1, ...
    'Components', {'segmentation'}, 'Save', false);
annotationManager.markReviewed(r, spec, 'Components', {'parentage'}, 'Save', false);
annotationManager.markChanged(r, spec, 'Frames', 2, ...
    'Components', {'segmentation','parentage'}, 'Save', false);
summary = annotationManager.inspect(r, spec, 'CheckAssets', false);
segmentation = summary.coverage.components(strcmp( ...
    {summary.coverage.components.id}, 'segmentation'));
parentage = summary.coverage.components(strcmp( ...
    {summary.coverage.components.id}, 'parentage'));
verifyEqual(testCase, segmentation.reviewed, 2);
verifyEqual(testCase, parentage.reviewed, 0, ...
    'Editing one relation must require a later explicit ROI confirmation.');
end

function testLegacyLineageCoverageMigration(testCase)
r = roi('migration', [1 1 2 2]);
r.image = zeros(2,2,1,3,'uint16');
r.display.channel = {'mask'};

classifier = struct('strid', 'migration');
oldSpec = annotationManager.newSpec(classifier);
oldMask = annotationManager.newComponent( ...
    'id','tracked_mask','kind','tracked_instances','storage','channel', ...
    'coverageUnit','frame');
oldLineage = annotationManager.newComponent( ...
    'id','lineage','kind','lineage','storage','cell_model_family', ...
    'coverageUnit','roi');
oldSpec.components = [oldMask; oldLineage];

newSpec = annotationManager.newSpec(classifier);
tracking = annotationManager.newComponent( ...
    'id','tracking','kind','tracking','storage','cell_model_family', ...
    'coverageUnit','frame');
parentage = annotationManager.newComponent( ...
    'id','parentage','kind','lineage','storage','cell_model_family', ...
    'coverageUnit','roi');
newSpec.components = [oldMask; tracking; parentage];

legacy = annotationManager.newEntry(oldSpec, 3);
legacy.status = 'approved';
legacy.review(1).frames(:) = true;
legacy.review(1).complete = true;
legacy.review(2).complete = true;
annotationManager.setEntry(r, oldSpec, legacy, 'Save', false);
[migrated, found] = annotationManager.entryForSpec(r, newSpec);
verifyTrue(testCase, found);
verifyTrue(testCase, all(migrated.review(1).frames));
verifyTrue(testCase, all(migrated.review(2).frames));
verifyTrue(testCase, migrated.review(3).complete);

legacy.status = 'draft';
annotationManager.setEntry(r, oldSpec, legacy, 'Save', false);
migrated = annotationManager.entryForSpec(r, newSpec);
verifyTrue(testCase, all(migrated.review(1).frames));
verifyFalse(testCase, any(migrated.review(2).frames));
verifyFalse(testCase, migrated.review(3).complete);
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
verifyEqual(testCase, {session.Spec.components.id}, ...
    {'tracked_mask','tracking','parentage'});
maskState = summary.components(strcmp({summary.components.id}, 'tracked_mask'));
verifyEqual(testCase, maskState.predictionName, 'results_cellposeSAM_cell', ...
    'The stored family provider must take precedence over raw classifier inputs.');
report = session.bootstrap();
verifyTrue(testCase, report.modelChanged);
[gtChannel, gtExists] = annotationManager.resolveChannel(r, ...
    annotationManager.newAsset('channel', 'gt_latent_1_stable_tracks'));
verifyTrue(testCase, gtExists);
verifyEqual(testCase, gtChannel, 'gt_latent_1_stable_tracks');
verifyEqual(testCase, r.image(:,:,r.findChannelID(gtChannel),:), masks);
[model, ~] = r.loadCellModel();
[sourceIdx, sourceId] = cellModel.familyIndex(model, 'Predicted lineage');
[gtIdx, gtId] = cellModel.familyIndex(model, 'latent_1 reviewed GT');
verifyNotEmpty(testCase, sourceIdx);
verifyNotEmpty(testCase, gtIdx);
verifyEqual(testCase, model.families.mask_provider{sourceIdx}, ...
    'results_cellposeSAM_cell');
verifyEqual(testCase, model.families.mask_provider{gtIdx}, ...
    'gt_latent_1_stable_tracks');
verifyEqual(testCase, nnz(model.instances.family_id == sourceId), ...
    nnz(model.instances.family_id == gtId));
verifyEqual(testCase, nnz(model.relations.family_id == sourceId), 1);
verifyEqual(testCase, nnz(model.relations.family_id == gtId), 1);
verifyEqual(testCase, c.trainingParam.groundTruthFamily, ...
    'latent_1 reviewed GT');
verifyEqual(testCase, c.trainingParam.trackChannelName, ...
    'gt_latent_1_stable_tracks');

quickTracking = session.quickValidate('Frames', 1:3, ...
    'Components', {'tracking'});
verifyTrue(testCase, quickTracking.valid, ...
    strjoin(cellstr(quickTracking.errors), ' '));
quickParentage = session.quickValidate('Components', {'parentage'});
verifyTrue(testCase, quickParentage.valid, ...
    strjoin(cellstr(quickParentage.errors), ' '));

validModel = model;
gtRelation = find(model.relations.family_id == gtId, 1, 'first');
model.relations.child_track_id(gtRelation) = uint64(999);
r.saveCellModel(model);
quickParentage = session.quickValidate('Components', {'parentage'});
verifyFalse(testCase, quickParentage.valid);
verifyTrue(testCase, any(contains(quickParentage.errors, ...
    'Missing child Track 999')));
invalidParentage = session.validate('RequireReviewed', false);
verifyFalse(testCase, invalidParentage.valid);
verifyTrue(testCase, any(contains(invalidParentage.errors, ...
    'Missing child Track 999')));
verifyEqual(testCase, numel(invalidParentage.issues), 1);
issueRows = annotationManager.validationIssueRows(invalidParentage);
verifyEqual(testCase, numel(issueRows), 1, ...
    'The structured parentage error must not be duplicated as free text.');
verifyEqual(testCase, issueRows.component, 'Parentage');
verifyEqual(testCase, issueRows.summary, 'Missing child track');
verifyEqual(testCase, issueRows.frame, 2);
verifyEqual(testCase, issueRows.related_track, 1);
verifyEqual(testCase, issueRows.missing_track, 999);
verifyTrue(testCase, issueRows.repairable);
verifyEqual(testCase, issueRows.issue_index, 1);
parentageReport = annotationManager.validateParentage(model, gtId);
verifyEqual(testCase, numel(parentageReport.issues), 1);
verifyEqual(testCase, parentageReport.issues.role, 'child');
verifyEqual(testCase, parentageReport.issues.missing_track_id, uint64(999));
verifyEqual(testCase, parentageReport.issues.parent_track_id, uint64(1));
verifyEqual(testCase, parentageReport.issues.event_frame, uint32(2));
verifyEqual(testCase, parentageReport.issues.focus_track_id, uint64(1));
verifyEqual(testCase, parentageReport.issues.focus_frame, uint32(2));

model.relations.child_track_id(gtRelation) = uint64(2);
model.relations.parent_track_id(gtRelation) = uint64(999);
parentageReport = annotationManager.validateParentage(model, gtId);
verifyFalse(testCase, parentageReport.valid);
verifyEqual(testCase, numel(parentageReport.issues), 1);
verifyEqual(testCase, parentageReport.issues.role, 'parent');
verifyEqual(testCase, parentageReport.issues.missing_track_id, uint64(999));
verifyEqual(testCase, parentageReport.issues.child_track_id, uint64(2));
verifyEqual(testCase, parentageReport.issues.focus_track_id, uint64(2));
verifyEqual(testCase, parentageReport.issues.focus_frame, uint32(2));
verifyTrue(testCase, contains(parentageReport.errors, ...
    'remove or reassign its parent'));
r.saveCellModel(validModel);

session.markReviewed('Frames', 1:3, ...
    'Components', {'tracked_mask','tracking'});
reviewSummary = session.summary();
parentageCoverage = reviewSummary.coverage.components(strcmp( ...
    {reviewSummary.coverage.components.id}, 'parentage'));
verifyEqual(testCase, parentageCoverage.reviewed, 1, ...
    'Completing every bounded frame must also complete ROI-level review.');
verifyTrue(testCase, session.validate().valid);

% Reproduce a relation created by an older Score build at the frame of the
% reviewer click. Validation must migrate only its derived event timestamp,
% persist child birth, and keep the chosen parent/child identities.
[cachedModel,~] = r.loadCellModel();
gtRelation = find(cachedModel.relations.family_id == gtId, 1, 'first');
predictionRelation = find( ...
    cachedModel.relations.family_id == sourceId, 1, 'first');
parentBefore = cachedModel.relations.parent_track_id(gtRelation);
childBefore = cachedModel.relations.child_track_id(gtRelation);
cachedModel.relations.event_frame(gtRelation) = uint32(43);
cachedModel.relations.event_frame(predictionRelation) = uint32(42);
r.cellModel = cachedModel;
migrated = session.validate();
verifyTrue(testCase, migrated.valid, strjoin(cellstr(migrated.errors), ' '));
verifyTrue(testCase, migrated.parentageEventMigration.changed);
verifyEqual(testCase, migrated.parentageEventMigration.count, 1);
verifyTrue(testCase, any(contains(migrated.warnings, ...
    'parent/child track IDs were unchanged')));
verifyEqual(testCase, r.cellModel.relations.event_frame(gtRelation), uint32(2));
verifyEqual(testCase, r.cellModel.relations.parent_track_id(gtRelation), ...
    parentBefore);
verifyEqual(testCase, r.cellModel.relations.child_track_id(gtRelation), ...
    childBefore);
verifyEqual(testCase, ...
    r.cellModel.relations.event_frame(predictionRelation), uint32(42), ...
    'Validating GT must not rewrite a separate prediction family.');
diskModel = cellModel.readH5(cellModel.pathForROI(r));
diskRelation = find(diskModel.relations.family_id == gtId, 1, 'first');
diskPredictionRelation = find( ...
    diskModel.relations.family_id == sourceId, 1, 'first');
verifyEqual(testCase, diskModel.relations.event_frame(diskRelation), uint32(2));
verifyEqual(testCase, diskModel.relations.parent_track_id(diskRelation), ...
    parentBefore);
verifyEqual(testCase, diskModel.relations.child_track_id(diskRelation), ...
    childBefore);
verifyEqual(testCase, ...
    diskModel.relations.event_frame(diskPredictionRelation), uint32(42));

% Reproduce an older session (and the stale-link repair workflow): all
% frame units remain reviewed while a parentage edit resets its ROI flag.
annotationManager.markChanged(r, session.Spec, 'Frames', 2, ...
    'Components', {'parentage'}, 'Save', false);
reviewSummary = session.summary();
parentageCoverage = reviewSummary.coverage.components(strcmp( ...
    {reviewSummary.coverage.components.id}, 'parentage'));
verifyEqual(testCase, parentageCoverage.reviewed, 0);
verifyTrue(testCase, session.validate().valid, ...
    'Validate must reconcile ROI review after all bounded frames were reviewed.');
reviewSummary = session.summary();
parentageCoverage = reviewSummary.coverage.components(strcmp( ...
    {reviewSummary.coverage.components.id}, 'parentage'));
verifyEqual(testCase, parentageCoverage.reviewed, 1);

gtIdx = r.findChannelID('gt_latent_1_stable_tracks');
r.image(:,:,gtIdx,:) = uint16(17);
r.save({'gt_latent_1_stable_tracks'}, false);
invalid = session.validate();
verifyFalse(testCase, invalid.valid);
verifyTrue(testCase, any(contains(invalid.errors, ...
    'does not match object family')));
end

function testValidationIssueRowsKeepGenericErrors(testCase)
report = struct( ...
    'errors', [ ...
        "Component ""tracking"" is not fully reviewed (3/5)."; ...
        "tracking: Mask mismatch on frame 12."], ...
    'issues', struct([]));
rows = annotationManager.validationIssueRows(report);
verifyEqual(testCase, numel(rows), 2);
verifyEqual(testCase, rows(1).component, 'Coverage');
verifyEqual(testCase, rows(2).component, 'Tracking');
verifyEqual(testCase, rows(2).frame, 12);
verifyFalse(testCase, any([rows.repairable]));
end

function testParentageTemporalConventionIgnoresLegacyClickFrame(testCase)
model = temporalParentageModel(1:2, 2, 2);
report = annotationManager.validateParentage(model, uint32(1));
verifyTrue(testCase, report.valid, strjoin(cellstr(report.errors), ' '));
verifyEmpty(testCase, report.issues);

model.relations.event_frame(:) = uint32(43); % frame where reviewer clicked
report = annotationManager.validateParentage(model, uint32(1));
verifyTrue(testCase, report.valid, ...
    'The frame of the UI action must not change the biological relation.');
verifyEmpty(testCase, report.issues);
convention = annotationManager.relationTemporalConvention();
verifyEqual(testCase, convention.canonical_event, 'child_birth');
verifyEqual(testCase, convention.accepted_event_minus_birth, 0);
verifyEqual(testCase, ...
    convention.accepted_presence_frames_relative_to_event, [0 -1]);
verifyEqual(testCase, ...
    convention.required_annotation_parent_frame_relative_to_event, 0);
verifyEqual(testCase, ...
    convention.temporal_training_parent_frames_relative_to_event, [0 -1]);
end

function testParentageTemporalImpossibleRelationsAreHardErrors(testCase)
childLate = temporalParentageModel(1:3, 8:9, 3);
report = annotationManager.validateParentage(childLate, uint32(1));
verifyFalse(testCase, report.valid);
verifyEqual(testCase, numel(report.issues), 1);
verifyEqual(testCase, report.issues.code, ...
    'relation_parent_temporally_incompatible');
verifyEqual(testCase, report.issues.severity, 'error');
verifyFalse(testCase, report.issues.repairable);
rows = annotationManager.validationIssueRows(report);
verifyEqual(testCase, numel(rows), 1, ...
    'Structured temporal error must not be duplicated as free text.');
verifyEqual(testCase, rows.severity, 'error');
verifyEqual(testCase, rows.component, 'Parentage');
verifyEqual(testCase, rows.frame, 8);
verifyEqual(testCase, rows.related_track, 2);

parentGone = temporalParentageModel(1, 3:4, 17);
report = annotationManager.validateParentage(parentGone, uint32(1));
verifyFalse(testCase, report.valid);
verifyEqual(testCase, numel(report.issues), 1);
verifyEqual(testCase, report.issues.code, ...
    'relation_parent_temporally_incompatible');
verifyEqual(testCase, report.issues.focus_track_id, uint64(2));
verifyEqual(testCase, report.issues.focus_frame, uint32(3));
end

function testExplicitParentageCensoringMasksOnlyTheTarget(testCase)
model = temporalParentageModel(1, 3:4, 17);
[model, ~] = cellModel.setCensoring(model, 1, 2, 3, 3, ...
    'Scope', 'parentage', 'Reason', 'ambiguous_parentage');
report = annotationManager.validateParentage(model, uint32(1));
verifyTrue(testCase, report.valid, strjoin(cellstr(report.errors), ' '));
verifyEqual(testCase, numel(report.issues), 1);
verifyEqual(testCase, report.issues.code, ...
    'explicitly_censored_parentage');
verifyEqual(testCase, report.issues.severity, 'warning');
verifyTrue(testCase, contains(report.issues.message, ...
    'excluded from parentage training and scoring'));

% Censoring parentage must not silently censor tracking or segmentation.
verifyTrue(testCase, cellModel.isCensored(model, 1, 2, 3, 'parentage'));
verifyFalse(testCase, cellModel.isCensored(model, 1, 2, 3, 'tracking'));
end

function testOptionalCensorSchemaPreservesLegacyApprovalHash(testCase)
folder = freshFolder(testCase);
r = roiWithRaw(folder, 'R1', 8, 8, 2);
masks = zeros(8,8,1,2,'uint16');
masks(2:4,2:4,1,:) = 1;
r.addChannel(masks,'gt_tracks',[1 1 1],[0 0 0]);
model = cellModel.create(r.id);
model.families.family_id = uint32(1);
model.families.name = {'Reviewed GT'};
model.families.mask_provider = {'gt_tracks'};
model.families.lineage_source = {'human'};
model.families.color_rgb = uint8([1 2 3]);
for frame = 1:2
    [model,~] = cellModel.syncFrame(model,1,frame,masks(:,:,1,frame), ...
        'TrackPolicy','preserve_or_label');
end
r.saveCellModel(model,'KeepBackup',false);
spec = annotationManager.newSpec(struct('strid','hash_compat'));
spec.components = annotationManager.newComponent( ...
    'id','tracking','kind','tracking','storage','cell_model_family', ...
    'required',true,'coverageUnit','frame', ...
    'groundTruth',annotationManager.newAsset( ...
        'family','Reviewed GT','maskProvider','gt_tracks'));

legacyHash = annotationManager.contentHash(r,spec);
catalogOnly = model;
catalogOnly.censor_reasons(1).description = ...
    'Optional catalog metadata added after the historical approval.';
r.saveCellModel(catalogOnly,'KeepBackup',false);
verifyEqual(testCase,annotationManager.contentHash(r,spec),legacyHash, ...
    ['Optional censor schema defaults must not make an unchanged legacy ' ...
     'approval stale.']);

[withCensor,~] = cellModel.setCensoring(model,1,1,1,1, ...
    'Scope','tracking','Reason','ambiguous_identity');
r.saveCellModel(withCensor,'KeepBackup',false);
verifyNotEqual(testCase,annotationManager.contentHash(r,spec),legacyHash, ...
    'An actual explicit censor record must invalidate the approval hash.');
end

function testParentageRequiresMaterializedParentInsideTrainingBounds(testCase)
model = temporalParentageModel(1, 2, 2);
report = annotationManager.validateParentage( ...
    model, uint32(1), 'Frames', 2);
verifyFalse(testCase, report.valid, ...
    ['A parent visible only before the selected range cannot be ' ...
     'materialized by the training formatter.']);
verifyEqual(testCase, numel(report.issues), 1);
verifyEqual(testCase, report.issues.code, ...
    'relation_parent_temporally_incompatible');
end

function testParentageIgnoresRelationsOutsideTrainingBounds(testCase)
model = temporalParentageModel(246:247, 402:403, 402);
fullReport = annotationManager.validateParentage(model, uint32(1));
verifyFalse(testCase, fullReport.valid, ...
    'The synthetic relation is deliberately incoherent without bounds.');

boundedReport = annotationManager.validateParentage( ...
    model, uint32(1), 'Frames', 1:333);
verifyTrue(testCase, boundedReport.valid, ...
    ['A relation whose canonical child-birth event is outside the ' ...
     'configured ROI bounds must not affect validation or training.']);
verifyEmpty(testCase, boundedReport.errors);
verifyEmpty(testCase, boundedReport.issues);
end

function testParentageSeparatesStaticAndTemporalEligibility(testCase)
onlyAtBirth = temporalParentageModel(2, 2, 2);
report = annotationManager.validateParentage(onlyAtBirth, uint32(1));
verifyTrue(testCase, report.valid, strjoin(cellstr(report.errors), ' '));
verifyEqual(testCase, numel(report.issues), 1);
verifyEqual(testCase, report.issues.code, ...
    'relation_static_only_parentage');
verifyEqual(testCase, report.issues.severity, 'warning');
[evidence,~] = cellModel.parentageEvidence(onlyAtBirth, uint32(1));
verifyTrue(testCase, evidence.static_parentage_eligible);
verifyFalse(testCase, evidence.temporal_parentage_eligible);
verifyEqual(testCase, evidence.evidence_mode, 'left_censored_joint_entry');

onlyBeforeBirth = temporalParentageModel(1, 2, 2);
report = annotationManager.validateParentage(onlyBeforeBirth, uint32(1));
verifyFalse(testCase, report.valid);

% Slicing away birth-1 changes head eligibility, not annotation validity.
report = annotationManager.validateParentage( ...
    onlyAtBirth, uint32(1), 'Frames', 2);
verifyTrue(testCase, report.valid, strjoin(cellstr(report.errors), ' '));
verifyEqual(testCase, report.issues.code, 'relation_static_only_parentage');

persistentParent = temporalParentageModel(1:2, 2, 2);
report = annotationManager.validateParentage(persistentParent, uint32(1));
verifyTrue(testCase, report.valid, strjoin(cellstr(report.errors), ' '));
verifyEmpty(testCase, report.issues);
end

function testStableTrackAuditProducesNavigableWarningsOnly(testCase)
folder = freshFolder(testCase);
r = roiWithRaw(folder, 'R1', 40, 40, 2);
masks = zeros(40,40,1,2,'uint16');
% Certain-like reuse: mature 100 px object becomes a 16 px object.
masks(25:34,2:11,1,1) = 1;
masks(28:31,5:8,1,2) = 2;
% Benign fluctuation: 81 -> 40 px (ratio 0.494) stays spatially local.
masks(2:10,2:10,1,1) = 3;
masks(2:6,2:9,1,2) = 4;
% Large jump with unchanged area.
masks(15:18,2:5,1,1) = 5;
masks(15:18,20:23,1,2) = 6;
r.addChannel(masks, 'gt_tracks', [1 1 1], [0 0 0]);
r.save([], false);

model = trackingAuditModel(r.id);
r.saveCellModel(model);
spec = annotationManager.newSpec(struct('strid','audit'));
spec.components = annotationManager.newComponent( ...
    'id','tracking','kind','tracking','storage','cell_model_family', ...
    'required',true,'coverageUnit','frame', ...
    'groundTruth',annotationManager.newAsset( ...
        'family','Reviewed GT','maskProvider','gt_tracks'));

report = annotationManager.validate(r, spec, ...
    'RequireReviewed', false, 'ReviewFrames', 1:2);
verifyTrue(testCase, report.valid, ...
    'Possible ID reuse is advisory and must not hard-fail GT.');
verifyEqual(testCase, numel(report.issues), 2);
verifyTrue(testCase, all(strcmp({report.issues.severity}, 'warning')));
verifyEqual(testCase, sort(double([report.issues.focus_track_id])), [9 52]);
verifyTrue(testCase, any(strcmp({report.issues.code}, ...
    'possible_id_reuse_area_drop')));
verifyTrue(testCase, any(strcmp({report.issues.code}, ...
    'possible_id_reuse_centroid_jump')));
verifyFalse(testCase, any(double([report.issues.focus_track_id]) == 7), ...
    'The conservative area threshold must ignore the benign fluctuation.');
verifyTrue(testCase, all(contains(string({report.issues.message}), ...
    'does not block validation or training')));
rows = annotationManager.validationIssueRows(report);
verifyEqual(testCase, numel(rows), 2, ...
    'Structured warnings must not be duplicated by report.warnings.');
verifyTrue(testCase, all(strcmp({rows.severity}, 'warning')));
verifyTrue(testCase, all(strcmp({rows.component}, 'Tracking')));
verifyTrue(testCase, all([rows.frame] == 2));
verifyFalse(testCase, any([rows.repairable]));

% Human tracking censorship removes only the explicitly covered anomaly.
[censoredModel, ~] = cellModel.setCensoring(model, 1, 52, 1, 2, ...
    'Scope', 'tracking', 'Reason', 'ambiguous_identity');
r.cellModel = censoredModel;
censored = annotationManager.validate(r, spec, ...
    'RequireReviewed', false, 'ReviewFrames', 1:2);
verifyTrue(testCase, censored.valid);
verifyEqual(testCase, numel(censored.issues), 1);
verifyEqual(testCase, censored.issues.focus_track_id, uint64(9));

oversized = model;
oversized.instances.track_id(1:2) = uint64(intmax('uint32')) + uint64(1);
r.cellModel = oversized;
tooLarge = annotationManager.validate(r, spec, ...
    'RequireReviewed', false, 'ReviewFrames', 1:2);
verifyFalse(testCase, tooLarge.valid);
verifyTrue(testCase, any(contains(tooLarge.errors, 'exceeds uint32')));
end

function testStrongImageBoundaryClippingCreatesOneSegmentationSuggestion(testCase)
folder = freshFolder(testCase);
r = roiWithRaw(folder, 'R1', 30, 30, 2);
masks = zeros(30,30,1,2,'uint16');
masks(10:18,1:4,1,1) = 1;
masks(10:18,1:4,1,2) = 2;
r.addChannel(masks,'gt_tracks',[1 1 1],[0 0 0]);
r.save([],false);

model = cellModel.create(r.id);
model.families.family_id = uint32(1);
model.families.name = {'Reviewed GT'};
model.families.mask_provider = {'gt_tracks'};
model.families.lineage_source = {'human'};
model.families.color_rgb = uint8([255 255 255]);
model.instances.object_id = uint64([1;2]);
model.instances.family_id = uint32([1;1]);
model.instances.frame = uint32([1;2]);
model.instances.mask_label = uint32([1;2]);
model.instances.track_id = uint64([4;4]);
model.instances.state_id = uint16([0;0]);
model = cellModel.normalize(model);

issues = annotationManager.auditStableTracks( ...
    r,model,uint32(1),'Frames',1:2);
boundary = issues(strcmp({issues.code}, ...
    'possible_roi_boundary_truncation'));
verifyEqual(testCase,numel(boundary),1);
verifyTrue(testCase,boundary.suggested_censor);
verifyEqual(testCase,boundary.suggested_scope_flags, ...
    cellModel.censorScope('segmentation'));
verifyEqual(testCase,boundary.suggested_reason, ...
    'truncated_at_roi_boundary');
verifyEqual(testCase,boundary.suggested_frame_start,uint32(1));
verifyEqual(testCase,boundary.suggested_frame_end,uint32(2));

[model,~] = cellModel.setCensoring(model,1,4,1,2, ...
    'Scope','segmentation','Reason','truncated_at_roi_boundary');
verifyEmpty(testCase,annotationManager.auditStableTracks( ...
    r,model,uint32(1),'Frames',1:2));
end

function testSessionKeepsRejectedCensorSuggestionOutOfQueueWithoutChangingGt(testCase)
folder = freshFolder(testCase);
c = classi(folder,'latent_triage',1);
c.classifierPkg = 'cellLatentModel';
c.category = {'Tracking'};
c.classes = {'latent lineage link'};
c.executionParam = struct('trackChannelName','', ...
    'outputFamilyName','Predicted lineage');
c.channelName = {'raw'};
familyName = 'latent_triage_1 reviewed GT';
channelName = 'gt_latent_triage_1_stable_tracks';
c.trainingParam = struct('groundTruthFamily',familyName, ...
    'trackChannelName',channelName);

r = roiWithRaw(folder,'R1',30,30,2);
masks = zeros(30,30,1,2,'uint16');
masks(10:18,1:4,1,1) = 1;
masks(10:18,1:4,1,2) = 2;
r.addChannel(masks,channelName,[1 1 1],[0 0 0]);
r.save([],false);
model = cellModel.create(r.id);
model.families.family_id = uint32(1);
model.families.name = {familyName};
model.families.mask_provider = {channelName};
model.families.lineage_source = {'human'};
model.families.color_rgb = uint8([255 255 255]);
model.instances.object_id = uint64([1;2]);
model.instances.family_id = uint32([1;1]);
model.instances.frame = uint32([1;2]);
model.instances.mask_label = uint32([1;2]);
model.instances.track_id = uint64([4;4]);
model.instances.state_id = uint16([0;0]);
r.saveCellModel(cellModel.normalize(model));
c.roi = r;

session = c.annotationSession(1);
report = session.findings();
candidate = report.issues(strcmp({report.issues.code}, ...
    'possible_roi_boundary_truncation'));
verifyEqual(testCase,numel(candidate),1);
verifyNotEmpty(testCase,candidate.suggestion_id);
updated = session.recordCensorSuggestionDecision(candidate,'keep');
verifyFalse(testCase,any(strcmp({updated.issues.code}, ...
    'possible_roi_boundary_truncation')));
verifyGreaterThanOrEqual(testCase, ...
    double(updated.censorSuggestions.resolved),1);
[unchanged,~] = r.loadCellModel('MigrateLegacy',true);
verifyEmpty(testCase,unchanged.censoring.censor_id, ...
    'Keeping a suggestion must not modify scientific GT.');

reopened = c.annotationSession(1);
reopenedReport = reopened.findings('RequireReviewed',false);
verifyFalse(testCase,any(strcmp({reopenedReport.issues.code}, ...
    'possible_roi_boundary_truncation')), ...
    'Rejected suggestions must remain resolved after reopening the session.');
end

function testValidationAndHashUseUnsavedLoadedSnapshot(testCase)
folder = freshFolder(testCase);
c = classi(folder, 'live_snapshot', 1);
c.classifierPkg = 'cellLatentModel';
c.category = {'Tracking'};
c.classes = {'latent lineage link'};
c.executionParam = struct('trackChannelName', '', ...
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

model = cellModel.create(r.id);
[model, ~, ~] = cellModel.applyLineageResult(model, ...
    squeeze(masks(:,:,1,:)), 'results_cellposeSAM_cell', '', ...
    'Predicted lineage', struct('edges', struct([])), true, 'classifier');
r.saveCellModel(model);
c.roi = r;

session = c.annotationSession(1);
session.bootstrap();
gtChannel = session.Spec.components(1).groundTruth.channel;
gtIndex = r.findChannelID(gtChannel);
[model, ~] = r.loadCellModel();
[~, gtFamilyId] = cellModel.familyIndex(model, ...
    'live_snapshot_1 reviewed GT');

% Reproduce Score after an edit and before Save: both live assets agree,
% while the materialized HDF5 mask and object model are still the old pair.
r.image(1,4,gtIndex,2) = uint16(3);
[model, ~] = cellModel.syncFrame(model, gtFamilyId, 2, ...
    r.image(:,:,gtIndex,2), 'TrackPolicy', 'preserve_or_label');
r.cellModel = model;

report = annotationManager.validate(r, session.Spec, ...
    'RequireReviewed', false, 'ReviewFrames', 1:3);
verifyTrue(testCase, report.valid, strjoin(cellstr(report.errors), ' '));

liveHash = annotationManager.contentHash(r, session.Spec);
diskRoi = roi('R1', [1 1 4 4]);
diskRoi.path = r.path;
diskMask = annotationManager.readChannel(diskRoi, gtChannel);
verifyEqual(testCase, squeeze(diskMask), squeeze(masks), ...
    'The fixture must retain a stale materialized mask on disk.');
verifyEqual(testCase, r.image(1,4,gtIndex,2), uint16(3));
diskHash = annotationManager.contentHash(diskRoi, session.Spec);
verifyNotEqual(testCase, liveHash, diskHash, ...
    'The live validation hash must include unsaved Score edits.');

entry = annotationManager.recordValidation(r, session.Spec, report, ...
    'Save', false);
verifyEqual(testCase, entry.validated_hash, liveHash, ...
    'Validation and its audit hash must use the same live snapshot.');

persistedReport = session.validate('RequireReviewed', false);
verifyTrue(testCase, persistedReport.valid);
persistedRoi = roi('R1', [1 1 4 4]);
persistedRoi.path = r.path;
persistedMask = annotationManager.readChannel(persistedRoi, gtChannel);
verifyEqual(testCase, persistedMask(1,4,1,2), uint16(3), ...
    'Session validation must materialize live mask edits before approval.');
[persistedModel, ~] = persistedRoi.loadCellModel();
rows = persistedModel.instances.family_id == gtFamilyId & ...
    persistedModel.instances.frame == uint32(2);
verifyTrue(testCase, any(persistedModel.instances.mask_label(rows) == 3), ...
    'Session validation must materialize the matching live object family.');
persistedRoi.load('Data', 'Silent');
[persistedEntry, found] = annotationManager.entryForSpec( ...
    persistedRoi, session.Spec);
verifyTrue(testCase, found);
verifyEqual(testCase, persistedEntry.status, 'approved');
verifyEqual(testCase, persistedEntry.validated_hash, liveHash);
end

function testValidationRejectsInvalidLiveChannelMapping(testCase)
[~, c, r] = maskFixture(testCase);
session = c.annotationSession(1);
session.bootstrap();
gtChannel = session.Spec.components(1).groundTruth.channel;
r.channelid(end+1) = r.channelid(end);
verifyError(testCase, @() annotationManager.readChannel(r, gtChannel), ...
    'annotationManager:InvalidChannelCache');
verifyError(testCase, @() session.validate('RequireReviewed', false), ...
    'annotationManager:InvalidChannelCache');
end

function testSessionValidationRequiresDurableGtSave(testCase)
[~, c, r] = maskFixture(testCase);
session = c.annotationSession(1);
session.bootstrap();
r.path = fullfile(tempdir, ['missing_annotation_' char(java.util.UUID.randomUUID)]);
verifyError(testCase, @() session.validate('RequireReviewed', false), ...
    'annotationManager:GroundTruthPersistenceFailed');
verifyNotEqual(testCase, session.LastValidationStatus, 'valid');
end

function testSessionValidationRejectsPartialLiveChannelCache(testCase)
[~, c, r] = maskFixture(testCase);
session = c.annotationSession(1);
session.bootstrap();
gtChannel = session.Spec.components(1).groundTruth.channel;

diskRoi = roi(r.id, [1 1 1 1]);
diskRoi.path = r.path;
before = annotationManager.readChannel(diskRoi, gtChannel);
verifyEqual(testCase, size(before, 4), 3);

% A frame-window cache is addressable by name but is unsafe to send to
% roi.save: the partial save fallback could otherwise truncate the HDF5.
r.image = r.image(:,:,:,1:2);
verifyError(testCase, @() session.validate('RequireReviewed', false), ...
    'annotationManager:IncompleteChannelCache');

diskRoi = roi(r.id, [1 1 1 1]);
diskRoi.path = r.path;
after = annotationManager.readChannel(diskRoi, gtChannel);
verifyEqual(testCase, after, before, ...
    'Rejected validation must not replace the complete GT channel.');
verifyNotEqual(testCase, session.LastValidationStatus, 'valid');
end

function testValidReportCannotBeRecordedWithoutHashableGt(testCase)
[~, c, ~] = maskFixture(testCase);
session = c.annotationSession(1);
session.bootstrap();
badSpec = session.Spec;
badSpec.components(1).groundTruth.channel = 'missing_gt_channel';
report = struct('valid', true, 'errors', strings(0,1), ...
    'warnings', strings(0,1));
verifyError(testCase, @() annotationManager.recordValidation( ...
    session.Roi, badSpec, report, 'Save', false), ...
    'annotationManager:MissingGroundTruth');
[entry, found] = annotationManager.entryForSpec(session.Roi, session.Spec);
verifyTrue(testCase, found);
verifyEqual(testCase, entry.status, 'draft');
end

function testFrameCountUsesLongestMaterializedChannel(testCase)
folder = freshFolder(testCase);
r = roi('R1', [1 1 2 2]);
r.path = folder;
r.image = zeros(2,2,1,2, 'uint16');
r.channelid = 1;
r.display.channel = {'short_live'};
h5File = fullfile(folder, 'im_R1.h5');
h5create(h5File, '/long_disk', [2 2 1 5], 'Datatype', 'uint16');
h5writeatt(h5File, '/long_disk', 'channel_name', 'long_disk');
h5writeatt(h5File, '/long_disk', 'frames', 1:5);
verifyEqual(testCase, annotationManager.frameCount(r), 5);
end

function testSingletonSpatialMaskKeepsTemporalDimension(testCase)
folder = freshFolder(testCase);
c = classi(folder, 'singleton', 1);
c.classifierPkg = 'cellLatentModel';
c.category = {'Tracking'};
c.classes = {'latent lineage link'};
c.executionParam = struct('trackChannelName', '', ...
    'outputFamilyName', 'Predicted lineage');
c.channelName = {'raw'};
c.trainingParam = struct('groundTruthFamily', '<auto>', ...
    'trackChannelName', '');
r = roiWithRaw(c.path, 'R1', 1, 1, 3);
masks = ones(1,1,1,3, 'uint16');
r.addChannel(masks, 'results_cellposeSAM_cell', [1 1 1], [0 0 0]);
r.save([], false);
model = cellModel.create(r.id);
[model, ~, ~] = cellModel.applyLineageResult(model, ...
    reshape(masks, 1, 1, 3), 'results_cellposeSAM_cell', '', ...
    'Predicted lineage', struct('edges', struct([])), true, 'classifier');
r.saveCellModel(model);
c.roi = r;
session = c.annotationSession(1);
session.bootstrap();
report = annotationManager.validate(r, session.Spec, ...
    'RequireReviewed', false, 'ReviewFrames', 1:3);
verifyTrue(testCase, report.valid, strjoin(cellstr(report.errors), ' '));
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

function testFastClassifierSummaryFindsLegacyGtWithoutManifest(testCase)
[~, c, r] = maskFixture(testCase);
groundTruth = zeros(4,4,1,3, 'uint16');
groundTruth(2:3,2:3,1,:) = 1;
spec = annotationManager.specForClassifier(c);
groundTruthName = spec.components(1).groundTruth.channel;
r.addChannel(groundTruth, groundTruthName, [1 1 1], [0 0 0]);
r.save([], false);

rows = annotationManager.summarizeClassifier(c, [], 'Fast', true);

verifyTrue(testCase, rows.legacy);
verifyEqual(testCase, rows.status, 'draft', ...
    'Existing legacy GT must not be reported missing without a manifest.');
verifyEqual(testCase, rows.reviewed, 0, ...
    'Asset discovery must not invent lifecycle review coverage.');
end

function testEmptyDataFlushPreservesPersistedAnnotationManifest(testCase)
[folder, c, r] = maskFixture(testCase);
session = c.annotationSession(1);
session.bootstrap();
dataFile = fullfile(folder, ['data_' r.id '.mat']);
before = load(dataFile, 'data');
verifyTrue(testCase, any(strcmp({before.data.groupid}, ...
    'detecdiv_annotation_manifest')));
r.data = dataseries.empty;
verifyEmpty(testCase, r.data, ...
    'The test must reproduce the post-save purged ROI cache.');

didSave = r.save('data', false);

verifyFalse(testCase, didSave);
after = load(dataFile, 'data');
verifyTrue(testCase, any(strcmp({after.data.groupid}, ...
    'detecdiv_annotation_manifest')), ...
    'A second empty flush must not erase persisted annotation metadata.');
end

function testClassifierSummaryRefreshesManifestMissingFromMemory(testCase)
[~, c, r] = maskFixture(testCase);
session = c.annotationSession(1);
session.bootstrap();

% Reproduce a classifier snapshot that has a legitimate legacy dataseries
% cached in memory but predates the annotation manifest saved by Score.
stale = roiWithRaw(c.path, r.id, 4, 4, 3);
legacy = dataseries;
legacy.groupid = 'cell_information';
legacy.parentid = r.id;
stale.data = legacy;
c.roi = stale;

rows = annotationManager.summarizeClassifier(c, [], 'Fast', true);
verifyEqual(testCase, rows.status, 'draft');
verifyEqual(testCase, rows.total, 3);
verifyEqual(testCase, numel(stale.data), 2);
verifyTrue(testCase, any(strcmp({stale.data.groupid}, ...
    'detecdiv_annotation_manifest')));
end

function testInitializeFromExistingFamilyCanBlankParentage(testCase)
folder = freshFolder(testCase);
c = classi(folder, 'latent_existing', 1);
c.classifierPkg = 'cellLatentModel';
c.category = {'Tracking'};
c.classes = {'latent lineage link'};
c.executionParam = struct('trackChannelName', '', ...
    'outputFamilyName', 'Predicted lineage');
c.channelName = {'raw'};
c.trainingParam = struct('groundTruthFamily', '<auto>', ...
    'trackChannelName', '');
r = roiWithRaw(c.path, 'R1', 4, 4, 3);
masks = zeros(4,4,1,3, 'uint16');
masks(1:2,1:2,1,:) = 1;
masks(3:4,3:4,1,2:3) = 2;
r.addChannel(masks, 'existing_tracks', [1 1 1], [0 0 0]);
r.save([], false);
edge = struct('status', 'linked', 'pred_parent_id', 1, ...
    'child_track_id', 2, 'bud_appearance_frame', 2, 'top_score', 0.9);
model = cellModel.create(r.id);
[model, ~, ~] = cellModel.applyLineageResult(model, squeeze(masks(:,:,1,:)), ...
    'existing_tracks', '', 'Imported tracking', struct('edges', edge), ...
    true, 'import');
r.saveCellModel(model);
c.roi = r;

session = c.annotationSession(1);
catalog = session.initializationCatalog();
verifyTrue(testCase, any(strcmp({catalog.families.name}, 'Imported tracking')));
family = catalog.families(strcmp({catalog.families.name}, 'Imported tracking'));
verifyEqual(testCase, family.trackCount, 2);
verifyEqual(testCase, family.relationCount, 1);

recipe = struct('mode', 'family', 'family', 'Imported tracking', ...
    'channel', '', 'copyParentage', false);
report = session.initialize(recipe);
verifyEqual(testCase, report.entry.source_type, 'existing_family');
verifyTrue(testCase, contains(report.entry.source_id, 'blank parentage'));
[model, ~] = r.loadCellModel();
[sourceIndex, sourceId] = cellModel.familyIndex(model, 'Imported tracking');
[targetIndex, targetId] = cellModel.familyIndex(model, ...
    'latent_existing_1 reviewed GT');
verifyNotEmpty(testCase, sourceIndex);
verifyNotEmpty(testCase, targetIndex);
verifyEqual(testCase, nnz(model.instances.family_id == targetId), ...
    nnz(model.instances.family_id == sourceId));
verifyEqual(testCase, nnz(model.relations.family_id == targetId), 0);
end

function testInitializeFromMaskCreatesEmptyTrackingFamily(testCase)
folder = freshFolder(testCase);
c = classi(folder, 'latent_mask', 1);
c.classifierPkg = 'cellLatentModel';
c.category = {'Tracking'};
c.classes = {'latent lineage link'};
c.executionParam = struct('trackChannelName', '', ...
    'outputFamilyName', 'Absent prediction');
c.channelName = {'raw'};
c.trainingParam = struct('groundTruthFamily', '<auto>', ...
    'trackChannelName', '');
r = roiWithRaw(c.path, 'R1', 4, 4, 3);
masks = zeros(4,4,1,3, 'uint16');
masks(2:3,2:3,1,:) = 7;
r.addChannel(masks, 'imported_mask', [1 1 1], [0 0 0]);
r.save([], false);
c.roi = r;

session = c.annotationSession(1);
catalog = session.initializationCatalog();
verifyFalse(testCase, catalog.prediction.available);
verifyTrue(testCase, catalog.supports.mask);
recipe = struct('mode', 'mask', 'family', '', ...
    'channel', 'imported_mask', 'copyParentage', false);
report = session.initialize(recipe);
verifyEqual(testCase, report.entry.source_type, 'existing_mask');
verifyTrue(testCase, contains(report.entry.source_id, 'tracks: blank'));
targetChannel = 'gt_latent_mask_1_stable_tracks';
verifyEqual(testCase, r.image(:,:,r.findChannelID(targetChannel),:), masks);
[model, ~] = r.loadCellModel();
[targetIndex, targetId] = cellModel.familyIndex(model, ...
    'latent_mask_1 reviewed GT');
verifyNotEmpty(testCase, targetIndex);
verifyEqual(testCase, model.families.mask_provider{targetIndex}, targetChannel);
verifyEqual(testCase, nnz(model.instances.family_id == targetId), 0);
verifyEqual(testCase, nnz(model.relations.family_id == targetId), 0);
end

function testImportBundleFromExistingFamilyPreservesPartialCoverage(testCase)
folder = freshFolder(testCase);
c = classi(folder, 'latent_import', 1);
c.classifierPkg = 'cellLatentModel';
c.category = {'Tracking'};
c.classes = {'latent lineage link'};
c.executionParam = struct('trackChannelName', '', ...
    'outputFamilyName', 'Predicted lineage');
c.channelName = {'raw'};
c.trainingParam = struct('groundTruthFamily', '<auto>', ...
    'trackChannelName', '');
r = roiWithRaw(c.path, 'R1', 4, 4, 3);
masks = zeros(4,4,1,3,'uint16');
masks(1:2,1:2,1,:) = 1;
masks(3:4,3:4,1,2:3) = 2;
r.addChannel(masks, 'existing_tracks', [1 1 1], [0 0 0]);
r.save([], false);
model = cellModel.create(r.id);
[model, ~] = cellModel.applyLineageResult(model, squeeze(masks(:,:,1,:)), ...
    'existing_tracks', '', 'Imported tracking', struct('edges', struct([])), ...
    true, 'import');
r.saveCellModel(model);
c.roi = r;

bundle = struct( ...
    'format', 'detecdiv_managed_gt_import_v1', ...
    'roi_id', 'R1', ...
    'source_family', 'Imported tracking', ...
    'relations', struct('parent_track_id', 1, 'child_track_id', 2, ...
        'event_frame', 3, 'confidence', 0.75), ...
    'coverage', struct('tracked_mask_frames', 1:2, ...
        'tracking_frames', 1:2, 'parentage_complete', false), ...
    'provenance', struct('source_id', 'legacy_review_v1', ...
        'source_run_id', 'run7', 'manifest_path', 'manifest.json', ...
        'manifest_sha256', repmat('a',1,64), ...
        'label_authority', 'weak_supervision'), ...
    'notes', 'Positive links only', ...
    'exclusions', {{'ambiguous cases excluded'}});

session = c.annotationSession(1);
bundleFile = fullfile(folder, 'legacy_review_bundle.json');
fid = fopen(bundleFile, 'w');
cleanup = onCleanup(@() fclose(fid));
fwrite(fid, unicode2native(jsonencode(bundle), 'UTF-8'), 'uint8');
clear cleanup;
report = session.importBundle(bundleFile);
verifyEqual(testCase, report.status, 'draft');
verifyEqual(testCase, report.relations.stored_event_frame, uint32(2), ...
    'Import must ignore a late review click and store child birth.');
verifyEqual(testCase, report.entry.label_authority, 'weak_supervision');
verifyEqual(testCase, report.entry.source_manifest_sha256, repmat('a',1,64));
verifyEqual(testCase, strlength(string( ...
    report.entry.source_bundle_sha256)), 64);
verifyEqual(testCase, report.entry.import_exclusions, ...
    {'ambiguous cases excluded'}');
maskReview = report.entry.review(strcmp({report.entry.review.component_id}, ...
    'tracked_mask'));
trackingReview = report.entry.review(strcmp({report.entry.review.component_id}, ...
    'tracking'));
parentReview = report.entry.review(strcmp({report.entry.review.component_id}, ...
    'parentage'));
verifyEqual(testCase, maskReview.frames, logical([1 1 0]));
verifyEqual(testCase, trackingReview.frames, logical([1 1 0]));
verifyFalse(testCase, parentReview.complete);
summary = session.summary();
verifyEqual(testCase, summary.status, 'draft');
verifyLessThan(testCase, summary.coverage.fraction, 1);
end

function testImportBundleWithTrackedMaskCreatesCanonicalFamily(testCase)
folder = freshFolder(testCase);
c = classi(folder, 'latent_mask_import', 1);
c.classifierPkg = 'cellLatentModel';
c.category = {'Tracking'};
c.classes = {'latent lineage link'};
c.executionParam = struct('trackChannelName', '', ...
    'outputFamilyName', 'Predicted lineage');
c.channelName = {'raw'};
c.trainingParam = struct('groundTruthFamily', '<auto>', ...
    'trackChannelName', '');
r = roiWithRaw(c.path, 'R1', 4, 4, 3);
c.roi = r;

stack = zeros(4,4,3,'uint16');
stack(1:2,1:2,:) = 10;
stack(3:4,3:4,2:3) = 20;
bundle = struct( ...
    'format', 'detecdiv_managed_gt_import_v1', ...
    'roi_id', 'R1', ...
    'tracked_mask', stack, ...
    'relations', struct('parent_track_id', 10, 'child_track_id', 20, ...
        'event_frame', 3, 'confidence', 1), ...
    'coverage', struct('tracked_mask_frames', 1:3, ...
        'tracking_frames', 1:3, 'parentage_complete', true), ...
    'provenance', struct('source_id', 'human_export_v1', ...
        'label_authority', 'human_ground_truth'), ...
    'notes', '', 'exclusions', {{}});

session = c.annotationSession(1);
report = session.importBundle(bundle);
verifyEqual(testCase, report.relations.stored_event_frame, uint32(2));
verifyEqual(testCase, report.entry.label_authority, 'human_ground_truth');
verifyTrue(testCase, all([report.entry.review.complete]));
gt = annotationManager.readChannel(r, report.target_channel);
verifyEqual(testCase, squeeze(gt), stack);
[model, ~] = r.loadCellModel();
[familyIndex, familyId] = cellModel.familyIndex(model, report.target_family);
verifyNotEmpty(testCase, familyIndex);
verifyEqual(testCase, sort(unique(model.instances.track_id( ...
    model.instances.family_id == familyId))), uint64([10;20]));
relationRow = model.relations.family_id == familyId;
verifyEqual(testCase, model.relations.event_frame(relationRow), uint32(2));
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

function model = temporalParentageModel(parentFrames, childFrames, eventFrame)
model = cellModel.create('temporal');
model.families.family_id = uint32(1);
model.families.name = {'Reviewed GT'};
model.families.mask_provider = {'gt_tracks'};
model.families.lineage_source = {'human'};
model.families.color_rgb = uint8([255 255 255]);
frames = [parentFrames(:); childFrames(:)];
tracks = [ones(numel(parentFrames),1); 2*ones(numel(childFrames),1)];
n = numel(frames);
model.instances.object_id = uint64((1:n)');
model.instances.family_id = repmat(uint32(1), n, 1);
model.instances.frame = uint32(frames);
model.instances.mask_label = uint32((1:n)');
model.instances.track_id = uint64(tracks);
model.instances.state_id = zeros(n,1,'uint16');
model.relations.relation_id = uint64(1);
model.relations.family_id = uint32(1);
model.relations.parent_track_id = uint64(1);
model.relations.child_track_id = uint64(2);
model.relations.event_frame = uint32(eventFrame);
model.relations.type_id = uint8(1);
model.relations.confidence = single(1);
model = cellModel.normalize(model);
% Allow tests to emulate the raw field written by older Score versions.
model.relations.event_frame(:) = uint32(eventFrame);
end

function model = trackingAuditModel(roiId)
model = cellModel.create(roiId);
model.families.family_id = uint32(1);
model.families.name = {'Reviewed GT'};
model.families.mask_provider = {'gt_tracks'};
model.families.lineage_source = {'human'};
model.families.color_rgb = uint8([255 255 255]);
model.instances.object_id = uint64((1:6)');
model.instances.family_id = repmat(uint32(1),6,1);
model.instances.frame = uint32([1;2;1;2;1;2]);
model.instances.mask_label = uint32([1;2;3;4;5;6]);
model.instances.track_id = uint64([52;52;7;7;9;9]);
model.instances.state_id = zeros(6,1,'uint16');
model = cellModel.normalize(model);
end

function folder = freshFolder(testCase)
folder = tempname;
mkdir(folder);
addTeardown(testCase, @() removeFolder(folder));
end

function removeFolder(folder)
if isfolder(folder), rmdir(folder, 's'); end
end
