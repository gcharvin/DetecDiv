function tests = testBenchmarkSnapshotExport
%TESTBENCHMARKSNAPSHOTEXPORT Leak-proof DetecDiv benchmark handoff.
tests = functiontests(localfunctions);
end

function testExportIsImmutableSeparatedHashedAndFrameBounded(testCase)
fixture = benchmarkFixture(testCase);
cleanup = onCleanup(@() removeFolder(fixture.root));
sourceBefore = directoryHashes(fixture.classifier.path, fixture.roiPaths);

result = cellLatentModel.exportBenchmarkSnapshot( ...
    fixture.classifier, fixture.split, ...
    'synthetic_detecdiv_benchmark_v001', ...
    'ExternalRoot', fixture.externalRoot, ...
    'AllowUnitTestRoot', true);

verifyTrue(testCase, isfolder(result.directory));
verifyTrue(testCase, isfile(result.manifest));
verifyEqual(testCase, directoryHashes( ...
    fixture.classifier.path, fixture.roiPaths), sourceBefore, ...
    'A read-only export changed a classifier or ROI source file.');

top = jsondecode(fileread(result.manifest));
inputs = jsondecode(fileread(result.inputs_manifest));
targets = jsondecode(fileread(result.targets_manifest));
verifyEqual(testCase, top.format, ...
    'detecdiv_external_benchmark_snapshot_v1');
verifyEqual(testCase, inputs.format, 'detecdiv_benchmark_inputs_v1');
verifyEqual(testCase, targets.format, 'detecdiv_benchmark_targets_v1');
verifyEqual(testCase, inputs.export_id, ...
    'synthetic_detecdiv_benchmark_v001');
verifyEqual(testCase, inputs.creation_time_utc, top.creation_time_utc);
verifyEqual(testCase, inputs.code.git_commit, top.code.git_commit);
verifyEqual(testCase, strlength(string( ...
    inputs.code.worktree_status_sha256)), 64);
verifyEqual(testCase, inputs.source_classifier.snapshot_sha256, ...
    top.source_classifier.files.sha256);
verifyEqual(testCase, string({inputs.source_rois.roi_id}), ...
    string({top.source_rois.roi_id}));
verifyEqual(testCase, top.inputs_manifest.sha256, ...
    fileSha256(result.inputs_manifest));
verifyEqual(testCase, top.targets_manifest.sha256, ...
    fileSha256(result.targets_manifest));
verifyEqual(testCase, string(top.split_contract.train.roi_ids), ...
    "benchmark_roi_a");
verifyEqual(testCase, string(top.split_contract.test.roi_ids), ...
    "benchmark_roi_b");

inputA = itemForRoi(inputs.items, 'benchmark_roi_a');
targetA = itemForRoi(targets.items, 'benchmark_roi_a');
targetB = itemForRoi(targets.items, 'benchmark_roi_b');
verifyEqual(testCase, double(inputA.source_frames(:).'), 2:6);
verifyEqual(testCase, double(inputA.frame_bounds(:).'), [2 6]);
verifyEqual(testCase, double(targetA.source_frames(:).'), 2:6);
inputFile = fullfile(result.directory, ...
    strrep(inputA.payload_path, '/', filesep));
targetFile = fullfile(result.directory, ...
    strrep(targetA.payload_path, '/', filesep));
verifyEqual(testCase, inputA.payload_sha256, fileSha256(inputFile));
verifyEqual(testCase, targetA.payload_sha256, fileSha256(targetFile));
verifyEqual(testCase, size(h5read(inputFile, ...
    '/frame_local_instance_masks'), 3), 5);
verifyEqual(testCase, sort(unique(h5read(inputFile, ...
    '/frame_local_instance_masks'))).', uint32([0 1 2]));
verifyEqual(testCase, sort(unique(h5read(targetFile, ...
    '/stable_track_ids'))).', uint32([0 100 200]));
verifyEqual(testCase, double(h5read(targetFile, ...
    '/relations/parent_track_id')), 100);
verifyEqual(testCase, double(h5read(targetFile, ...
    '/relations/child_track_id')), 200);
verifyEqual(testCase, double(targetA.parent_count), 1);
verifyEqual(testCase, double(targetA.null_count), 0, ...
    ['The mother is left-censored by the 2:6 bound and must not be ' ...
     'silently relabeled NULL.']);
verifyEqual(testCase, double(targetA.end_count), 1, ...
    'The bud ends at source frame 5 and frame 6 proves END.');
verifyEqual(testCase, double(targetB.null_count), 1, ...
    ['DetecDiv contract: a cell present on source frame 1 is NULL unless ' ...
     'the reviewer explicitly links it to a mother.']);
verifyEqual(testCase, targets.first_frame_policy, ...
    'NULL unless an explicit reviewed mother relation exists');
verifyEqual(testCase, targets.parentage_event_policy.convention, ...
    'child_birth_v2');
verifyEqual(testCase, targets.parentage_event_policy.canonical_event, ...
    'child_birth');
verifyFalse(testCase, ...
    targets.parentage_event_policy.source_mutated_during_export);
verifyEqual(testCase, top.label_contract.parentage_event_policy, ...
    targets.parentage_event_policy);
verifyTrue(testCase, contains( ...
    targets.parentage_event_policy.legacy_transform, ...
    'parent and child track IDs are unchanged'));

manifestBefore = fileread(result.manifest);
verifyError(testCase, @() cellLatentModel.exportBenchmarkSnapshot( ...
    fixture.classifier, fixture.split, ...
    'synthetic_detecdiv_benchmark_v001', ...
    'ExternalRoot', fixture.externalRoot, ...
    'AllowUnitTestRoot', true), ...
    'cellLatentModel:ImmutableBenchmarkExists');
verifyEqual(testCase, fileread(result.manifest), manifestBefore);
end

function testInferenceTreeContainsNoTargetTokensOrDatasets(testCase)
fixture = benchmarkFixture(testCase);
cleanup = onCleanup(@() removeFolder(fixture.root));
result = cellLatentModel.exportBenchmarkSnapshot( ...
    fixture.classifier, fixture.split, ...
    'synthetic_anti_leak_v001', ...
    'ExternalRoot', fixture.externalRoot, ...
    'AllowUnitTestRoot', true);

inputRoot = fullfile(result.directory, 'inputs');
forbidden = {'ground_truth','groundtruth','stable_track','track_id', ...
    'parent','lineage','relation','approval','birth','end_event', ...
    'target','genealogy','identity'};
files = dir(fullfile(inputRoot, '**', '*'));
files = files(~[files.isdir]);
for i = 1:numel(files)
    filename = fullfile(files(i).folder, files(i).name);
    [~, name, ext] = fileparts(filename);
    assertCleanText(testCase, [name ext], forbidden);
    if strcmpi(ext, '.json')
        decoded = jsondecode(fileread(filename));
        scanJson(testCase, decoded, forbidden);
        scanNoExternalPaths(testCase, decoded, 'inputs_manifest');
    elseif strcmpi(ext, '.h5')
        scanH5(testCase, h5info(filename), forbidden);
    else
        verifyFail(testCase, ['Unexpected inference artifact: ' filename]);
    end
end
end

function testRelationNamespacesAreRoiScopedAndClosed(testCase)
fixture = benchmarkFixture(testCase);
cleanup = onCleanup(@() removeFolder(fixture.root));
result = cellLatentModel.exportBenchmarkSnapshot( ...
    fixture.classifier, fixture.split, ...
    'synthetic_namespace_v001', ...
    'ExternalRoot', fixture.externalRoot, ...
    'AllowUnitTestRoot', true);
targets = jsondecode(fileread(result.targets_manifest));
verifyEqual(testCase, numel(targets.items), 2);
namespaces = string(arrayfun(@(x) ...
    x.relation_namespace.namespace_id, targets.items, ...
    'UniformOutput', false));
verifyEqual(testCase, numel(unique(namespaces)), 2, ...
    'Track IDs reused in different ROIs must not share a namespace.');
for i = 1:numel(targets.items)
    item = targets.items(i);
    verifyEqual(testCase, item.relation_namespace.schema, ...
        'detecdiv.cell_model.roi_family_track_id.v1');
    verifyEqual(testCase, item.relation_namespace.roi_id, item.roi_id);
    verifyEqual(testCase, item.relation_namespace.approval_sha256, ...
        item.approval.approved_sha256);
    targetFile = fullfile(result.directory, ...
        strrep(item.payload_path, '/', filesep));
    identities = unique(uint64(h5read(targetFile, ...
        '/stable_track_ids')));
    identities(identities == 0) = [];
    parents = uint64(h5read(targetFile, '/relations/parent_track_id'));
    children = uint64(h5read(targetFile, '/relations/child_track_id'));
    verifyTrue(testCase, all(ismember(parents, identities)));
    verifyTrue(testCase, all(ismember(children, identities)));
    verifyEqual(testCase, item.approval.approved_sha256, ...
        approvalHash(fixture.classifier, item.roi_id));
end
end

function testReviewedMaskCannotBeUsedAsInferenceMask(testCase)
fixture = benchmarkFixture(testCase);
cleanup = onCleanup(@() removeFolder(fixture.root));
target = fullfile(fixture.externalRoot, 'experiments', ...
    'synthetic_collision_v001');
verifyError(testCase, @() cellLatentModel.exportBenchmarkSnapshot( ...
    fixture.classifier, fixture.split, 'synthetic_collision_v001', ...
    'ExternalRoot', fixture.externalRoot, ...
    'AllowUnitTestRoot', true, ...
    'InputMaskChannel', fixture.gtMaskChannel), ...
    'cellLatentModel:BenchmarkInputTargetCollision');
verifyFalse(testCase, isfolder(target));
verifyEmpty(testCase, dir(fullfile(fixture.externalRoot, 'experiments', ...
    '.synthetic_collision_v001.staging_*')));
end

function testReviewedMaskCannotBeBoundAsBrightfield(testCase)
fixture = benchmarkFixture(testCase);
cleanup = onCleanup(@() removeFolder(fixture.root));
target = fullfile(fixture.externalRoot, 'experiments', ...
    'synthetic_raw_collision_v001');
verifyError(testCase, @() cellLatentModel.exportBenchmarkSnapshot( ...
    fixture.classifier, fixture.split, ...
    'synthetic_raw_collision_v001', ...
    'ExternalRoot', fixture.externalRoot, ...
    'AllowUnitTestRoot', true, ...
    'BrightfieldChannel', fixture.gtMaskChannel), ...
    'cellLatentModel:BenchmarkInputTargetCollision');
verifyFalse(testCase, isfolder(target));
end

function testAtomicPublisherNeverNestsOrReplacesExistingVersion(testCase)
root = tempname;
mkdir(root);
cleanup = onCleanup(@() removeFolder(root));
stage = fullfile(root, '.benchmark_v001.staging_fixture');
final = fullfile(root, 'benchmark_v001');
mkdir(stage);
mkdir(final);
writeText(fullfile(stage, 'new.txt'), 'new');
writeText(fullfile(final, 'sentinel.txt'), 'immutable');

verifyError(testCase, @() ...
    cellLatentModel.utils.atomicPublishDirectory(stage, final), ...
    'cellLatentModel:ImmutableBenchmarkExists');
verifyTrue(testCase, isfile(fullfile(final, 'sentinel.txt')));
verifyFalse(testCase, isfolder(fullfile(final, ...
    '.benchmark_v001.staging_fixture')));
verifyTrue(testCase, isfile(fullfile(stage, 'new.txt')), ...
    'Failed publication must preserve staging for caller cleanup/audit.');
end

function testFailedExportLeavesNoPublishedOrStagingDirectory(testCase)
fixture = benchmarkFixture(testCase);
cleanup = onCleanup(@() removeFolder(fixture.root));
target = fullfile(fixture.externalRoot, 'experiments', ...
    'synthetic_atomic_failure_v001');
verifyError(testCase, @() cellLatentModel.exportBenchmarkSnapshot( ...
    fixture.classifier, fixture.split, ...
    'synthetic_atomic_failure_v001', ...
    'ExternalRoot', fixture.externalRoot, ...
    'AllowUnitTestRoot', true, ...
    'BrightfieldChannel', 'missing_brightfield'), ...
    'cellLatentModel:BenchmarkChannelNotFound');
verifyFalse(testCase, isfolder(target));
verifyEmpty(testCase, dir(fullfile(fixture.externalRoot, 'experiments', ...
    '.synthetic_atomic_failure_v001.staging_*')));
end

function testRelationEventOutsideBoundsFailsClosed(testCase)
fixture = benchmarkFixture(testCase);
cleanup = onCleanup(@() removeFolder(fixture.root));
trainingBounds.setRoi(fixture.classifier, 1, '4:6', 'FrameCount', 6);
classiSave(fixture.classifier);
target = fullfile(fixture.externalRoot, 'experiments', ...
    'synthetic_event_bounds_v001');
verifyError(testCase, @() cellLatentModel.exportBenchmarkSnapshot( ...
    fixture.classifier, fixture.split, ...
    'synthetic_event_bounds_v001', ...
    'ExternalRoot', fixture.externalRoot, ...
    'AllowUnitTestRoot', true), ...
    'cellLatentModel:BenchmarkRelationOutsideFrameBounds');
verifyFalse(testCase, isfolder(target));
verifyEmpty(testCase, dir(fullfile(fixture.externalRoot, 'experiments', ...
    '.synthetic_event_bounds_v001.staging_*')));
end

function testSameRoiSourceCannotCrossPartitionsUnderAliases(testCase)
fixture = benchmarkFixture(testCase);
cleanup = onCleanup(@() removeFolder(fixture.root));
fixture.classifier.roi(2).path = fixture.classifier.roi(1).path;
fixture.classifier.roi(2).id = 'different_alias';
verifyError(testCase, @() cellLatentModel.exportBenchmarkSnapshot( ...
    fixture.classifier, fixture.split, 'synthetic_split_leak_v001', ...
    'ExternalRoot', fixture.externalRoot, ...
    'AllowUnitTestRoot', true), ...
    'cellLatentModel:InvalidBenchmarkSplit');
end

function testByteIdenticalRoiCopiesCannotCrossPartitions(testCase)
fixture = benchmarkFixture(testCase);
cleanup = onCleanup(@() removeFolder(fixture.root));
sourceFile = fullfile(fixture.roiPaths{1}, 'im_benchmark_roi_a.h5');
targetFile = fullfile(fixture.roiPaths{2}, 'im_benchmark_roi_b.h5');
copyfile(sourceFile, targetFile, 'f');
verifyError(testCase, @() cellLatentModel.exportBenchmarkSnapshot( ...
    fixture.classifier, fixture.split, 'synthetic_copy_leak_v001', ...
    'ExternalRoot', fixture.externalRoot, ...
    'AllowUnitTestRoot', true), ...
    'cellLatentModel:InvalidBenchmarkSplit');
end

function testAnyGroundTruthFamilyProviderIsForbiddenAsRawInput(testCase)
fixture = benchmarkFixture(testCase);
cleanup = onCleanup(@() removeFolder(fixture.root));
roiObj = fixture.classifier.roi(1);
[model, ~] = roiObj.loadCellModel('MigrateLegacy', true);
model.families.family_id(end+1,1) = uint32(8);
model.families.name{end+1,1} = 'Other reviewed family';
model.families.mask_provider{end+1,1} = 'Channel1_z2';
model.families.lineage_source{end+1,1} = 'ground_truth';
model.families.color_rgb(end+1,:) = uint8([255 120 80]);
roiObj.saveCellModel(model, 'KeepBackup', false);
verifyError(testCase, @() cellLatentModel.exportBenchmarkSnapshot( ...
    fixture.classifier, fixture.split, 'synthetic_other_gt_v001', ...
    'ExternalRoot', fixture.externalRoot, ...
    'AllowUnitTestRoot', true), ...
    'cellLatentModel:BenchmarkInputTargetCollision');
end

function testUnsavedActiveRoiCropIsRejected(testCase)
fixture = benchmarkFixture(testCase);
cleanup = onCleanup(@() removeFolder(fixture.root));
fixture.classifier.roi(1).value = ...
    fixture.classifier.roi(1).value + [1 0 0 0];
verifyError(testCase, @() cellLatentModel.exportBenchmarkSnapshot( ...
    fixture.classifier, fixture.split, 'synthetic_stale_crop_v001', ...
    'ExternalRoot', fixture.externalRoot, ...
    'AllowUnitTestRoot', true), ...
    'cellLatentModel:BenchmarkClassifierSnapshotMismatch');
end

function fixture = benchmarkFixture(testCase)
root = tempname;
mkdir(root);
classifierRoot = fullfile(root, 'classifier');
externalRoot = fullfile(root, 'external_data_root');
mkdir(classifierRoot);
mkdir(externalRoot);
classifier = classi(classifierRoot, 'benchmark_classifier', 1);
roiA = makeRoi(fullfile(root, 'roi_a'), 'benchmark_roi_a');
roiB = makeRoi(fullfile(root, 'roi_b'), 'benchmark_roi_b');
classifier.roi = [roiA roiB];
classifier.channelName = {'pred_instance_masks', ...
    'gt_reviewed_masks', 'Channel1_z2'};
classifier.dataset.split = struct('train', 1, 'val', [], 'test', 2);
cellLatentModel.setparam(classifier);
classifier.trainingParam.instanceChannelName = 'pred_instance_masks';
classifier.trainingParam.trackChannelName = 'gt_reviewed_masks';
classifier.trainingParam.brightfieldChannelName = 'Channel1_z2';
classifier.trainingParam.groundTruthFamily = 'Reviewed stable lineage';
classifier.trainingParam.trainingDomain = 'synthetic_cavity_mother';
trainingBounds.setRoi(classifier, 1, '2:6', 'FrameCount', 6);
trainingBounds.setRoi(classifier, 2, '1:6', 'FrameCount', 6);
approve(testCase, classifier, roiA);
approve(testCase, classifier, roiB);
classiSave(classifier);

fixture = struct( ...
    'root', root, ...
    'externalRoot', externalRoot, ...
    'classifier', classifier, ...
    'split', struct('train', 1, 'validation', [], 'test', 2), ...
    'roiPaths', {{roiA.path, roiB.path}}, ...
    'gtMaskChannel', 'gt_reviewed_masks');
end

function roiObj = makeRoi(folder, id)
mkdir(folder);
height = 24;
width = 28;
frames = 6;
[xx, yy] = meshgrid(1:width, 1:height);
pred = zeros(height, width, frames, 'single');
gt = zeros(height, width, frames, 'single');
bf = zeros(height, width, frames, 'single');
for frame = 1:frames
    mother = (xx - 9).^2 + (yy - 12).^2 <= 16;
    bud = frame >= 3 & frame <= 5 & ...
        (xx - 17).^2 + (yy - 12).^2 <= 6;
    predPlane = zeros(height, width, 'single');
    predPlane(mother) = single(10 + frame);
    predPlane(bud) = single(30 + frame);
    pred(:,:,frame) = predPlane;
    gtPlane = zeros(height, width, 'single');
    gtPlane(mother) = 5;
    gtPlane(bud) = 9;
    gt(:,:,frame) = gtPlane;
    bf(:,:,frame) = single(frame/10 + xx/100 + yy/200);
end
roiObj = roi(id, [1 1 width height]);
roiObj.path = folder;
roiObj.image = zeros(height, width, 3, frames, 'single');
roiObj.image(:,:,1,:) = pred;
roiObj.image(:,:,2,:) = gt;
roiObj.image(:,:,3,:) = bf;
roiObj.channelid = [1 2 3];
displayState = roiObj.display;
displayState.channel = {'pred_instance_masks', ...
    'gt_reviewed_masks', 'Channel1_z2'};
displayState.indexed = [true true false];
displayState.rgb = ones(3,3);
roiObj.display = displayState;
if ~roiObj.save([], false)
    error('testBenchmarkSnapshotExport:FixtureSaveFailed', ...
        'Could not save ROI fixture %s.', id);
end
saveReviewedModel(roiObj, uint32(gt));
end

function saveReviewedModel(roiObj, labels)
model = cellModel.create(roiObj.id);
familyId = uint32(7);
model.families.family_id = familyId;
model.families.name = {'Reviewed stable lineage'};
model.families.mask_provider = {'gt_reviewed_masks'};
model.families.lineage_source = {'ground_truth'};
model.families.color_rgb = uint8([99 214 255]);
nextObject = uint64(1);
for frame = 1:size(labels,3)
    frameLabels = unique(labels(:,:,frame));
    frameLabels(frameLabels == 0) = [];
    for label = double(frameLabels(:).')
        row = numel(model.instances.object_id) + 1;
        model.instances.object_id(row,1) = nextObject;
        nextObject = nextObject + 1;
        model.instances.family_id(row,1) = familyId;
        model.instances.frame(row,1) = uint32(frame);
        model.instances.mask_label(row,1) = uint32(label);
        if label == 5
            model.instances.track_id(row,1) = uint64(100);
        else
            model.instances.track_id(row,1) = uint64(200);
        end
        model.instances.state_id(row,1) = uint16(0);
    end
end
model.relations.relation_id = uint64(1);
model.relations.family_id = familyId;
model.relations.parent_track_id = uint64(100);
model.relations.child_track_id = uint64(200);
model.relations.event_frame = uint32(3);
model.relations.type_id = uint8(1);
model.relations.confidence = single(1);
roiObj.saveCellModel(model, 'KeepBackup', false);
end

function approve(testCase, classifier, roiObj)
spec = annotationManager.specForClassifier(classifier);
annotationManager.markReviewed(roiObj, spec, 'Save', true);
report = annotationManager.validate(roiObj, spec, 'RequireReviewed', true);
verifyTrue(testCase, report.valid, strjoin(cellstr(report.errors), ' '));
entry = annotationManager.recordValidation(roiObj, spec, report, ...
    'Save', true);
verifyEqual(testCase, entry.status, 'approved');
verifyEqual(testCase, strlength(string(entry.approved_hash)), 64);
end

function hash = approvalHash(classifier, roiId)
match = find(strcmp(string({classifier.roi.id}), string(roiId)), 1);
approvals = cellLatentModel.assertGroundTruthReady(classifier, match);
hash = approvals.approved_hash;
end

function item = itemForRoi(items, roiId)
match = find(strcmp(string({items.roi_id}), string(roiId)), 1);
if isempty(match), error('testBenchmarkSnapshotExport:MissingRoi', roiId); end
item = items(match);
end

function records = directoryHashes(classifierPath, roiPaths)
roots = [{classifierPath}, roiPaths(:).'];
records = strings(0,1);
for i = 1:numel(roots)
    files = dir(fullfile(roots{i}, '**', '*'));
    files = files(~[files.isdir]);
    for j = 1:numel(files)
        filename = fullfile(files(j).folder, files(j).name);
        records(end+1,1) = string(strrep(filename, '\', '/')) + ...
            "|" + fileSha256(filename); %#ok<AGROW>
    end
end
records = sort(unique(records));
end

function scanJson(testCase, value, forbidden)
if isstruct(value)
    names = fieldnames(value);
    for row = 1:numel(value)
        for i = 1:numel(names)
            assertCleanText(testCase, names{i}, forbidden);
            scanJson(testCase, value(row).(names{i}), forbidden);
        end
    end
elseif iscell(value)
    for i = 1:numel(value), scanJson(testCase, value{i}, forbidden); end
elseif ischar(value) || isstring(value)
    values = string(value);
    for i = 1:numel(values)
        assertCleanText(testCase, char(values(i)), forbidden);
    end
end
end

function scanNoExternalPaths(testCase, value, location)
if isstruct(value)
    names = fieldnames(value);
    for row = 1:numel(value)
        for i = 1:numel(names)
            scanNoExternalPaths(testCase, value(row).(names{i}), ...
                [location '.' names{i}]);
        end
    end
elseif iscell(value)
    for i = 1:numel(value)
        scanNoExternalPaths(testCase, value{i}, location);
    end
elseif ischar(value) || isstring(value)
    values = string(value);
    for i = 1:numel(values)
        textValue = char(values(i));
        windowsAbsolute = ~isempty(regexp(textValue, ...
            '^[A-Za-z]:[\\/]', 'once'));
        uncAbsolute = startsWith(textValue, '\\') || ...
            startsWith(textValue, '//');
        posixAbsolute = startsWith(textValue, '/') && ...
            ~contains(lower(location), 'dataset');
        verifyFalse(testCase, ...
            windowsAbsolute || uncAbsolute || posixAbsolute, ...
            sprintf('External absolute path leaked at %s: %s', ...
            location, textValue));
        if contains(lower(location), 'payload_path')
            verifyTrue(testCase, startsWith(textValue, 'inputs/'));
            verifyFalse(testCase, contains(textValue, '..'));
        end
    end
end
end

function scanH5(testCase, info, forbidden)
for i = 1:numel(info.Datasets)
    assertCleanText(testCase, info.Datasets(i).Name, forbidden);
end
for i = 1:numel(info.Groups)
    assertCleanText(testCase, info.Groups(i).Name, forbidden);
    scanH5(testCase, info.Groups(i), forbidden);
end
end

function assertCleanText(testCase, value, forbidden)
value = lower(char(string(value)));
for i = 1:numel(forbidden)
    verifyFalse(testCase, contains(value, forbidden{i}), ...
        sprintf('Forbidden token "%s" leaked through "%s".', ...
        forbidden{i}, value));
end
end

function value = fileSha256(filename)
fid = fopen(filename, 'r');
if fid < 0, error('testBenchmarkSnapshotExport:HashRead', filename); end
cleanup = onCleanup(@() fclose(fid));
bytes = fread(fid, Inf, '*uint8');
digest = java.security.MessageDigest.getInstance('SHA-256');
hash = typecast(digest.digest(bytes), 'uint8');
value = lower(reshape(dec2hex(hash, 2).', 1, []));
end

function writeText(filename, value)
fid = fopen(filename, 'w');
if fid < 0, error('testBenchmarkSnapshotExport:WriteFailed', filename); end
cleanup = onCleanup(@() fclose(fid));
fwrite(fid, value, 'char');
end

function removeFolder(folder)
if isfolder(folder), try rmdir(folder, 's'); catch, end, end
end
