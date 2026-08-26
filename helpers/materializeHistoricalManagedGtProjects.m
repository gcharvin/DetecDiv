function reports = materializeHistoricalManagedGtProjects(varargin)
%MATERIALIZEHISTORICALMANAGEDGTPROJECTS Import reviewed legacy lineage GT.
%
% This migration is intentionally source-specific and operates only on
% pre-created working copies. Original Project47 and X: SAM31 files remain
% read-only. The resulting classifiers keep partial review coverage as Draft.

p = inputParser;
p.addParameter('Project47WorkingRoot', '', @isText);
p.addParameter('MomaWorkingRoot', '', @isText);
p.addParameter('Project47ReviewCsv', '', @isText);
p.addParameter('Project47ReviewManifest', '', @isText);
p.addParameter('MomaReviewCsv', '', @isText);
p.addParameter('MomaReviewSummary', '', @isText);
p.parse(varargin{:});
cfg = normalizeConfig(p.Results);

reports = struct();
reports.project47 = materializeProject47(cfg);
reports.moma15_44 = materializeMoma(cfg);
end

function report = materializeProject47(cfg)
projectJson = fullfile(cfg.Project47WorkingRoot, 'project47.json');
projectDir = fullfile(cfg.Project47WorkingRoot, 'project47');
assertFile(projectJson);
[project, message] = shallowProjectImportLight(projectJson);
if isempty(project), error('historicalGt:ProjectLoadFailed', '%s', message); end

classifierParent = fullfile(projectDir, 'classification');
latent = classi(classifierParent, 'latent_project47_gt', 1);
cellLatentModel.setparam(latent);
latent.trainingParam.trainingDomain = ...
    'project47_reviewed_weak_descriptive_only';
latent.trainingParam.trainTrackingActions = false;
latent.trainingParam.trainMotherNull = false;
latent.executionParam.trackChannelName = 'results_trackastra';
latent.executionParam.instanceChannelName = 'results_cellposeSAM_cell';
latent.channelName = {'ch1-PH', 'results_cellposeSAM_cell'};
latent.roi = roi.empty;
for i = 1:numel(project.fov)
    for j = 1:numel(project.fov(i).roi)
        item = project.fov(i).roi(j);
        item.parent = latent;
        latent.roi(end+1) = item;
    end
end
latent.dataset = struct('classes', {latent.classes}, ...
    'channels', {latent.channelName}, ...
    'split', struct('train', [], 'val', [], 'test', []));
latent.trainingset = [];

review = readtable(cfg.Project47ReviewCsv, 'TextType', 'string');
if ismember('decision', review.Properties.VariableNames)
    review = review(strcmpi(review.decision, 'accepted'), :);
end
expected = 494;
if height(review) ~= expected
    error('historicalGt:UnexpectedProject47Count', ...
        'Expected %d Project47 accepted links, found %d.', expected, height(review));
end

items = repmat(importItemTemplate(), numel(latent.roi), 1);
for i = 1:numel(latent.roi)
    roiId = char(string(latent.roi(i).id));
    reviewId = regexprep(roiId, '_1$', '');
    rows = review(strcmpi(review.roi, reviewId), :);
    bundle = baseBundle(roiId, 'results_trackastra', ...
        'project47_gfp_gt_v005', cfg.Project47ReviewManifest, ...
        'reviewed_weak_ground_truth');
    bundle.relations = relationStruct(rows, ...
        'parent_track_id', 'child_track_id', 'bud_appearance_frame');
    bundle.notes = ['Accepted positive parentage links reconciled exactly ' ...
        'against the current results_trackastra TrackIDs. No negative/NULL ' ...
        'coverage is inferred.'];
    bundle.exclusions = { ...
        '58 reviewed tracking_error decisions excluded from parentage', ...
        '21 ambiguous decisions excluded', ...
        '4 explicit not_bud decisions retained only as audit metadata', ...
        '1 skipped decision excluded'};
    bundlePath = fullfile(cfg.Project47WorkingRoot, 'gt_bundles', ...
        [roiId '_managed_gt_import_v001.json']);
    writeJsonAtomic(bundlePath, bundle);
    session = latent.annotationSession(i);
    imported = session.importBundle(bundlePath, ...
        'SourceFamily', 'results_trackastra');
    items(i) = reportItem(imported, bundlePath);
end

materializeClassifierRoiFiles(latent);
classiSave(latent);
project.processing.classification = latent;
shallowProjectExportLight(project, projectJson);
report = struct( ...
    'classifier_file', fullfile(latent.path, ...
        [latent.strid '_classification.mat']), ...
    'project_file', projectJson, ...
    'roi_count', numel(items), ...
    'relation_count', sum([items.relation_count]), ...
    'items', items);
writeJsonAtomic(fullfile(cfg.Project47WorkingRoot, 'import_report.json'), report);
end

function report = materializeMoma(cfg)
sourceClassifier = fullfile(cfg.MomaWorkingRoot, ...
    'sam31_1_classification.mat');
assertFile(sourceClassifier);
[latent, message] = classiLoad(sourceClassifier);
if isempty(latent), error('historicalGt:ClassifierLoadFailed', '%s', message); end
if numel(latent.roi) < 44
    error('historicalGt:MissingMomaRois', ...
        'Expected at least 44 SAM31 ROI, found %d.', numel(latent.roi));
end
latent.roi = latent.roi(15:44);
latent.strid = 'latent_moma15_44_gt';
latent.id = 1;
cellLatentModel.setparam(latent);
latent.trainingParam.trainingDomain = ...
    'moma_roi15_44_reviewed_parentage_partial';
latent.trainingParam.trainTrackingActions = false;
latent.trainingParam.trainMotherNull = false;
latent.executionParam.trackChannelName = 'sam31_1_cell';
latent.executionParam.instanceChannelName = 'sam31_1_cell';
latent.channelName = {'Channel0', 'sam31_1_cell'};
latent.dataset = struct('classes', {latent.classes}, ...
    'channels', {latent.channelName}, ...
    'split', struct('train', [], 'val', [], 'test', []));
latent.trainingset = [];

review = readtable(cfg.MomaReviewCsv, 'TextType', 'string');
if ismember('manual_usable', review.Properties.VariableNames)
    usable = str2double(string(review.manual_usable)) == 1;
    review = review(usable, :);
end
expected = 434;
if height(review) ~= expected
    error('historicalGt:UnexpectedMomaCount', ...
        'Expected %d MoMA usable links, found %d.', expected, height(review));
end

items = repmat(importItemTemplate(), numel(latent.roi), 1);
for i = 1:numel(latent.roi)
    roiId = char(string(latent.roi(i).id));
    rows = review(strcmpi(review.movie, roiId), :);
    bundle = baseBundle(roiId, 'sam31_1_cell', ...
        'moma_roi15_44_pairing_short_rebud_corrected', ...
        cfg.MomaReviewSummary, 'human_ground_truth_positive_parentage');
    bundle.relations = relationStruct(rows, ...
        'manual_parent_pred_id', 'child_track_id', 'eval_frame');
    bundle.notes = ['Short-rebud-corrected manual parent choices. Source ' ...
        'eval_frame is zero-based; DetecDiv stores each relation at the ' ...
        'child track first visible frame. Tracking/mask review and exhaustive ' ...
        'NULL coverage are not inferred.'];
    bundle.exclusions = { ...
        '45 manually banned nonsensical/non-bud cases are not positive links', ...
        '2 cases without a valid displayed candidate remain excluded', ...
        'Only 434 manually usable positive links are imported'};
    bundlePath = fullfile(cfg.MomaWorkingRoot, 'gt_bundles', ...
        [safeName(roiId) '_managed_gt_import_v001.json']);
    writeJsonAtomic(bundlePath, bundle);
    session = latent.annotationSession(i);
    imported = session.importBundle(bundlePath, ...
        'SourceFamily', 'sam31_1_cell');
    items(i) = reportItem(imported, bundlePath);
end

classiSave(latent);
report = struct( ...
    'classifier_file', fullfile(latent.path, ...
        [latent.strid '_classification.mat']), ...
    'roi_count', numel(items), ...
    'relation_count', sum([items.relation_count]), ...
    'items', items);
writeJsonAtomic(fullfile(fileparts(cfg.MomaWorkingRoot), ...
    'import_report.json'), report);
end

function bundle = baseBundle(roiId, sourceFamily, sourceId, manifestPath, authority)
bundle = struct();
bundle.format = 'detecdiv_managed_gt_import_v1';
bundle.roi_id = roiId;
bundle.source_family = sourceFamily;
bundle.relations = struct([]);
bundle.coverage = struct('parentage_complete', false);
bundle.provenance = struct( ...
    'source_id', sourceId, ...
    'source_run_id', '', ...
    'manifest_path', manifestPath, ...
    'manifest_sha256', sha256File(manifestPath), ...
    'label_authority', authority);
bundle.notes = '';
bundle.exclusions = {};
end

function relations = relationStruct(rows, parentField, childField, eventField)
template = struct('parent_track_id', 0, 'child_track_id', 0, ...
    'event_frame', 0, 'confidence', 1);
relations = repmat(template, height(rows), 1);
for i = 1:height(rows)
    relations(i).parent_track_id = scalarNumber(rows.(parentField)(i));
    relations(i).child_track_id = scalarNumber(rows.(childField)(i));
    relations(i).event_frame = scalarNumber(rows.(eventField)(i));
end
end

function value = scalarNumber(raw)
if iscell(raw), raw = raw{1}; end
if isstring(raw) || ischar(raw), value = str2double(string(raw)); else, value = double(raw); end
if ~isscalar(value) || ~isfinite(value)
    error('historicalGt:BadNumericField', 'Expected one finite numeric value.');
end
end

function item = reportItem(imported, bundlePath)
item = importItemTemplate();
item.roi_id = imported.roi_id;
item.bundle_path = bundlePath;
item.bundle_sha256 = sha256File(bundlePath);
item.relation_count = numel(imported.relations);
item.status = imported.status;
item.target_channel = imported.target_channel;
item.target_family = imported.target_family;
end

function item = importItemTemplate()
item = struct('roi_id', '', 'bundle_path', '', 'bundle_sha256', '', ...
    'relation_count', 0, 'status', '', 'target_channel', '', ...
    'target_family', '');
end

function cfg = normalizeConfig(value)
cfg = value;
names = fieldnames(cfg);
for i = 1:numel(names), cfg.(names{i}) = char(string(cfg.(names{i}))); end
required = {'Project47WorkingRoot','MomaWorkingRoot', ...
    'Project47ReviewCsv','Project47ReviewManifest', ...
    'MomaReviewCsv','MomaReviewSummary'};
for i = 1:numel(required)
    if isempty(cfg.(required{i}))
        error('historicalGt:MissingPath', '%s is required.', required{i});
    end
end
assertFile(cfg.Project47ReviewCsv);
assertFile(cfg.Project47ReviewManifest);
assertFile(cfg.MomaReviewCsv);
assertFile(cfg.MomaReviewSummary);
end

function assertFile(path)
if ~isfile(path), error('historicalGt:MissingFile', 'Missing file: %s', path); end
end

function writeJsonAtomic(path, value)
folder = fileparts(path);
if ~isfolder(folder), mkdir(folder); end
temporary = [path '.tmp.' char(java.util.UUID.randomUUID)];
cleanup = onCleanup(@() deleteIfPresent(temporary));
fid = fopen(temporary, 'w', 'n', 'UTF-8');
if fid < 0, error('historicalGt:WriteFailed', 'Cannot write %s.', temporary); end
closeFile = onCleanup(@() fclose(fid));
fprintf(fid, '%s\n', jsonencode(value, 'PrettyPrint', true));
delete(closeFile);
jsondecode(fileread(temporary));
movefile(temporary, path, 'f');
delete(cleanup);
end

function hash = sha256File(path)
digest = java.security.MessageDigest.getInstance('SHA-256');
stream = java.io.FileInputStream(java.io.File(path));
cleanup = onCleanup(@() stream.close());
buffer = zeros(1, 1024 * 1024, 'int8');
while true
    count = stream.read(buffer, 0, numel(buffer));
    if count < 0, break; end
    digest.update(buffer(1:count));
end
delete(cleanup);
raw = typecast(digest.digest(), 'uint8');
hash = lower(reshape(dec2hex(raw, 2).', 1, []));
end

function value = safeName(value)
value = regexprep(char(string(value)), '[^A-Za-z0-9_.-]', '_');
end

function deleteIfPresent(path)
try
    if isfile(path), delete(path); end
catch
end
end

function tf = isText(value)
tf = ischar(value) || (isstring(value) && isscalar(value));
end
