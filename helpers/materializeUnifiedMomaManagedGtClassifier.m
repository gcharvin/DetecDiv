function report = materializeUnifiedMomaManagedGtClassifier(varargin)
%MATERIALIZEUNIFIEDMOMAMANAGEDGTCLASSIFIER Build one editable MoMA GT classi.
%
% ROI 01--14 are imported from complete CTC tracking/lineage GT. ROI 15--44
% are normalized from the reviewed MoMA15--44 DetecDiv classifier. Every
% imported ROI remains Draft so opening this classifier never impersonates
% a new DetecDiv review by the current user.

p = inputParser;
p.addParameter('CtcRoot', '', @isText);
p.addParameter('Moma15Classifier', '', @isText);
p.addParameter('OutputRoot', '', @isText);
p.addParameter('CtcManifest', '', @isText);
p.addParameter('CtcManifestSha256', '', @isText);
p.addParameter('Moma15Manifest', '', @isText);
p.addParameter('Moma15ManifestSha256', '', @isText);
p.parse(varargin{:});
cfg = normalizeConfig(p.Results);

classifier = classi(cfg.OutputRoot, 'moma01_44_managed_gt', 1);
assertEmptyClassifierTarget(classifier.path);
cellLatentModel.setparam(classifier);
targetChannel = 'gt_moma01_44_stable_tracks';
targetFamily = 'MoMA unified reviewed GT';
sourceFamily = 'MoMA import source tracks';

tp = classifier.trainingParam;
tp.trainingDomain = 'moma01_44_managed_gt_review';
tp.trackChannelName = targetChannel;
tp.brightfieldChannelName = 'brightfield';
tp.groundTruthChannelName = targetChannel;
tp.groundTruthFamily = targetFamily;
tp.trainTrackingActions = true;
tp.trainMotherNull = true;
classifier.trainingParam = tp;
classifier.executionParam.trackChannelName = targetChannel;
classifier.executionParam.instanceChannelName = targetChannel;
classifier.executionParam.brightfieldChannelName = 'brightfield';
classifier.channelName = {'brightfield', targetChannel};
classifier.roi = roi.empty;
classifier.dataset = struct('classes', {classifier.classes}, ...
    'channels', {classifier.channelName}, ...
    'split', struct('train', 1:9, 'val', 10:11, 'test', 12:14));
classifier.trainingset = [];

bundleRoot = fullfile(cfg.OutputRoot, 'gt_bundles');
if ~isfolder(bundleRoot), mkdir(bundleRoot); end
items = repmat(itemTemplate(), 44, 1);

for sequence = 1:14
    sequenceId = sprintf('%02d', sequence);
    [brightfield, tracks, relations, source] = ...
        readCtcSequence(cfg.CtcRoot, sequenceId);
    provenance = struct( ...
        'source_id', ['moma_roi01_14_ctc_' sequenceId], ...
        'source_run_id', 'moma_roi01_14_ctc_authoritative_gt', ...
        'manifest_path', cfg.CtcManifest, ...
        'manifest_sha256', cfg.CtcManifestSha256, ...
        'label_authority', 'authoritative_manual_gt');
    notes = sprintf(['MoMA CTC ROI %s. Stable masks and complete lineage ' ...
        'come from TRA/man_track.txt; zero-based CTC frames were converted ' ...
        'to one-based DetecDiv frames. Source: %s'], sequenceId, source);
    exclusions = {'No fluorescence channels are available', ...
        'Imported coverage remains Draft until reviewed in this DetecDiv classifier'};
    items(sequence) = materializeRoi(classifier, ...
        ['moma_' sequenceId], brightfield, tracks, relations, ...
        sourceFamily, targetFamily, bundleRoot, provenance, notes, exclusions);
end

[sourceClassifier, message] = classiLoad(cfg.Moma15Classifier);
if isempty(sourceClassifier)
    error('unifiedMomaGt:SourceClassifierLoadFailed', '%s', message);
end
if numel(sourceClassifier.roi) ~= 30
    error('unifiedMomaGt:UnexpectedMoma15RoiCount', ...
        'Expected 30 MoMA15--44 source ROI, found %d.', ...
        numel(sourceClassifier.roi));
end
sourceSpec = annotationManager.specForClassifier(sourceClassifier);
sourceMaskChannel = componentGroundTruth(sourceSpec, 'tracked_instances');
sourceGtFamily = componentGroundTruth(sourceSpec, 'lineage');

for sourceIndex = 1:30
    targetIndex = sourceIndex + 14;
    sourceRoi = sourceClassifier.roi(sourceIndex);
    sourceRoi.load('Silent');
    brightfieldChannel = resolveBrightfieldChannel(sourceRoi, sourceMaskChannel);
    brightfield = channelStack(sourceRoi, brightfieldChannel);
    tracks = channelStack(sourceRoi, sourceMaskChannel);
    relations = relationsForFamily(sourceRoi, sourceGtFamily);
    provenance = struct( ...
        'source_id', sprintf('moma15_44_managed_gt_v001_roi_%02d', targetIndex), ...
        'source_run_id', 'moma15_44_managed_gt_v001', ...
        'manifest_path', cfg.Moma15Manifest, ...
        'manifest_sha256', cfg.Moma15ManifestSha256, ...
        'label_authority', 'reviewed_positive_parentage_with_predicted_tracking');
    notes = sprintf(['Unified MoMA ROI %02d from source classifier ROI %d ' ...
        '(%s). Parentage is manually reviewed; masks and TrackIDs remain ' ...
        'model-derived until reviewed in this classifier.'], ...
        targetIndex, sourceIndex, char(string(sourceRoi.id)));
    exclusions = {'Exhaustive NULL parentage was not asserted by the legacy review', ...
        'Tracking and masks must be reviewed before use as complete tracking GT'};
    items(targetIndex) = materializeRoi(classifier, ...
        sprintf('moma_%02d', targetIndex), brightfield, tracks, relations, ...
        sourceFamily, targetFamily, bundleRoot, provenance, notes, exclusions);
    sourceRoi.clear;
end

classiSave(classifier);
report = struct( ...
    'schema_version', 'detecdiv_unified_moma_import_v001', ...
    'created_utc', utcTimestamp(), ...
    'classifier_file', fullfile(classifier.path, ...
        [classifier.strid '_classification.mat']), ...
    'roi_count', numel(items), ...
    'relation_count', sum([items.relation_count]), ...
    'ctc_relation_count', sum([items(1:14).relation_count]), ...
    'moma15_44_relation_count', sum([items(15:44).relation_count]), ...
    'target_channel', targetChannel, ...
    'target_family', targetFamily, ...
    'split_contract', classifier.dataset.split, ...
    'items', {items});
writeJsonAtomic(fullfile(cfg.OutputRoot, 'import_report.json'), report);
end

function item = materializeRoi(classifier, roiId, brightfield, tracks, ...
        relations, sourceFamily, targetFamily, bundleRoot, provenance, ...
        notes, exclusions)
brightfield = normalizeStack(brightfield, 'brightfield');
tracks = normalizeStack(tracks, 'tracks');
if ~isequal(size(brightfield), size(tracks))
    error('unifiedMomaGt:StackSizeMismatch', ...
        'Brightfield and tracks differ for ROI %s.', roiId);
end
if any(double(tracks(:)) > double(intmax('uint16')))
    error('unifiedMomaGt:TrackIdOverflow', ...
        'ROI %s contains a TrackID above uint16.', roiId);
end

sourceChannel = 'moma_import_source_tracks';
target = roi(roiId, [1 1 size(brightfield,2) size(brightfield,1)]);
target.path = classifier.path;
target.parent = classifier;
target.setExtractionStatus('extracted', 'moma01_44_managed_gt_v001');
target.addChannel(reshape(uint16(brightfield), size(brightfield,1), ...
    size(brightfield,2), 1, size(brightfield,3)), ...
    'brightfield', [1 1 1], [1 1 1]);
target.addChannel(reshape(uint16(tracks), size(tracks,1), ...
    size(tracks,2), 1, size(tracks,3)), ...
    sourceChannel, [1 1 1], [0 0 0]);
if ~target.save([], false)
    error('unifiedMomaGt:RoiSaveFailed', ...
        'Could not save initial ROI %s.', roiId);
end

model = cellModel.create(roiId);
[model, ~] = cellModel.applyLineageResult(model, uint32(tracks), ...
    sourceChannel, '', sourceFamily, struct('edges', struct([])), ...
    true, 'migration_source');
target.cellModel = model;
target.saveCellModel(model);
classifier.roi(end+1) = target;
targetIndex = numel(classifier.roi);

bundle = struct();
bundle.format = 'detecdiv_managed_gt_import_v1';
bundle.roi_id = roiId;
bundle.source_family = sourceFamily;
bundle.relations = relations;
bundle.coverage = struct();
bundle.provenance = provenance;
bundle.notes = notes;
bundle.exclusions = exclusions;
bundlePath = fullfile(bundleRoot, [roiId '_managed_gt_import_v001.json']);
writeJsonAtomic(bundlePath, bundle);

session = classifier.annotationSession(targetIndex);
imported = session.importBundle(bundlePath, 'SourceFamily', sourceFamily);
if ~strcmp(imported.target_family, targetFamily)
    error('unifiedMomaGt:UnexpectedTargetFamily', ...
        'ROI %s imported into unexpected family %s.', ...
        roiId, imported.target_family);
end

removeStoredRoiChannel(target, sourceChannel);
[cleanModel, ~] = target.loadCellModel('MigrateLegacy', true);
cleanModel = removeFamily(cleanModel, sourceFamily);
target.cellModel = cleanModel;
if ~target.save([], false)
    error('unifiedMomaGt:RoiCleanupSaveFailed', ...
        'Could not save cleaned ROI %s.', roiId);
end
target.saveCellModel(cleanModel);
target.clear;

item = itemTemplate();
item.roi_index = targetIndex;
item.roi_id = roiId;
item.source_id = provenance.source_id;
item.label_authority = provenance.label_authority;
item.frame_count = size(tracks, 3);
item.relation_count = numel(relations);
item.status = imported.status;
item.bundle_path = bundlePath;
item.bundle_sha256 = sha256File(bundlePath);
end

function [brightfield, tracks, relations, source] = readCtcSequence(root, id)
sequenceNumber = str2double(id);
if sequenceNumber <= 11, split = 'train'; else, split = 'val'; end
ctcRoot = fullfile(root, split, 'CTC');
imageRoot = fullfile(ctcRoot, id);
trackRoot = fullfile(ctcRoot, [id '_GT'], 'TRA');
trackTablePath = fullfile(trackRoot, 'man_track.txt');
assertFile(trackTablePath);

imageFiles = indexedTiffs(imageRoot, '^t(\d+)\.tif$');
trackFiles = indexedTiffs(trackRoot, '^man_track(\d+)\.tif$');
if isempty(imageFiles) || numel(imageFiles) ~= numel(trackFiles) || ...
        ~isequal([imageFiles.index], [trackFiles.index])
    error('unifiedMomaGt:CtcFrameMismatch', ...
        'CTC image/track frame mismatch for sequence %s.', id);
end
firstImage = imread(imageFiles(1).path);
firstTrack = imread(trackFiles(1).path);
if ~isequal(size(firstImage), size(firstTrack))
    error('unifiedMomaGt:CtcShapeMismatch', ...
        'CTC image/track shape mismatch for sequence %s.', id);
end
brightfield = zeros(size(firstImage,1), size(firstImage,2), ...
    numel(imageFiles), 'uint16');
tracks = zeros(size(firstTrack,1), size(firstTrack,2), ...
    numel(trackFiles), 'uint16');
for i = 1:numel(imageFiles)
    brightfield(:,:,i) = uint16(imread(imageFiles(i).path));
    frameTracks = imread(trackFiles(i).path);
    if any(double(frameTracks(:)) > double(intmax('uint16')))
        error('unifiedMomaGt:CtcTrackIdOverflow', ...
            'CTC sequence %s has TrackIDs above uint16.', id);
    end
    tracks(:,:,i) = uint16(frameTracks);
end

tableRows = readmatrix(trackTablePath, 'FileType', 'text');
tableRows = tableRows(all(isfinite(tableRows),2), :);
if size(tableRows,2) < 4
    error('unifiedMomaGt:MalformedTrackTable', ...
        'Malformed CTC track table: %s', trackTablePath);
end
relations = relationTemplate(nnz(tableRows(:,4) > 0));
relationIndex = 0;
for row = find(tableRows(:,4) > 0).'
    relationIndex = relationIndex + 1;
    relations(relationIndex).parent_track_id = uint64(tableRows(row,4));
    relations(relationIndex).child_track_id = uint64(tableRows(row,1));
    relations(relationIndex).event_frame = double(tableRows(row,2)) + 1;
    relations(relationIndex).confidence = 1;
end
source = trackRoot;
end

function values = indexedTiffs(root, expression)
listing = dir(fullfile(root, '*.tif'));
template = struct('index', 0, 'path', '');
values = repmat(template, 0, 1);
for i = 1:numel(listing)
    token = regexp(listing(i).name, expression, 'tokens', 'once');
    if isempty(token), continue; end
    value = template;
    value.index = str2double(token{1});
    value.path = fullfile(listing(i).folder, listing(i).name);
    values(end+1,1) = value; %#ok<AGROW>
end
if isempty(values), return; end
[~, order] = sort([values.index]);
values = values(order);
end

function name = resolveBrightfieldChannel(roiObj, gtChannel)
names = cellstr(string(roiObj.display.channel));
candidate = find(~strcmpi(names, gtChannel) & ...
    ~contains(lower(string(names)), 'cell') & ...
    ~contains(lower(string(names)), 'track'), 1, 'first');
if isempty(candidate), candidate = find(~strcmpi(names, gtChannel), 1, 'first'); end
if isempty(candidate)
    error('unifiedMomaGt:MissingBrightfield', ...
        'No brightfield-like channel found for ROI %s.', roiObj.id);
end
name = names{candidate};
end

function stack = channelStack(roiObj, name)
indices = roiObj.findChannelID(name, 'exact');
if isempty(indices) || numel(indices) ~= 1
    error('unifiedMomaGt:ChannelResolutionFailed', ...
        'Expected one plane for channel %s in ROI %s.', name, roiObj.id);
end
stack = reshape(roiObj.image(:,:,indices,:), ...
    size(roiObj.image,1), size(roiObj.image,2), size(roiObj.image,4));
end

function value = componentGroundTruth(spec, kind)
index = find(strcmp({spec.components.kind}, kind), 1, 'first');
if isempty(index)
    error('unifiedMomaGt:MissingAnnotationComponent', ...
        'Source annotation spec has no %s component.', kind);
end
component = spec.components(index);
if strcmp(component.storage, 'channel')
    value = char(string(component.groundTruth.channel));
else
    value = char(string(component.groundTruth.family));
end
end

function relations = relationsForFamily(roiObj, family)
[model, ~] = roiObj.loadCellModel('MigrateLegacy', true);
[familyIndex, familyId] = cellModel.familyIndex(model, family);
if isempty(familyIndex)
    error('unifiedMomaGt:MissingSourceFamily', ...
        'ROI %s is missing source family %s.', roiObj.id, family);
end
rows = find(model.relations.family_id == familyId & ...
    model.relations.type_id == uint8(1));
relations = relationTemplate(numel(rows));
for i = 1:numel(rows)
    row = rows(i);
    relations(i).parent_track_id = model.relations.parent_track_id(row);
    relations(i).child_track_id = model.relations.child_track_id(row);
    relations(i).event_frame = double(model.relations.event_frame(row));
    relations(i).confidence = double(model.relations.confidence(row));
end
end

function values = relationTemplate(count)
template = struct('parent_track_id', uint64(0), ...
    'child_track_id', uint64(0), 'event_frame', 0, 'confidence', NaN);
values = repmat(template, count, 1);
end

function model = removeFamily(model, family)
[familyIndex, familyId] = cellModel.familyIndex(model, family);
if isempty(familyIndex), return; end
model.instances = subsetRows(model.instances, ...
    model.instances.family_id ~= familyId);
model.relations = subsetRows(model.relations, ...
    model.relations.family_id ~= familyId);
keep = true(numel(model.families.family_id), 1);
keep(familyIndex) = false;
model.families = subsetRows(model.families, keep);
model = cellModel.normalize(model);
cellModel.validate(model, 'Throw', true);
end

function value = subsetRows(value, rows)
names = fieldnames(value);
for i = 1:numel(names)
    value.(names{i}) = value.(names{i})(rows,:);
end
end

function stack = normalizeStack(stack, label)
if ndims(stack) == 4 && size(stack,3) == 1
    stack = reshape(stack, size(stack,1), size(stack,2), size(stack,4));
elseif ismatrix(stack)
    stack = reshape(stack, size(stack,1), size(stack,2), 1);
end
if ndims(stack) ~= 3
    error('unifiedMomaGt:InvalidStack', ...
        '%s stack must be HxWxT.', label);
end
end

function cfg = normalizeConfig(cfg)
names = fieldnames(cfg);
for i = 1:numel(names), cfg.(names{i}) = char(string(cfg.(names{i}))); end
requiredFiles = {'Moma15Classifier','CtcManifest','Moma15Manifest'};
for i = 1:numel(requiredFiles), assertFile(cfg.(requiredFiles{i})); end
if ~isfolder(cfg.CtcRoot)
    error('unifiedMomaGt:MissingCtcRoot', ...
        'CTC root does not exist: %s', cfg.CtcRoot);
end
if isempty(cfg.OutputRoot), error('unifiedMomaGt:MissingOutputRoot', ...
        'OutputRoot is required.'); end
if ~isfolder(cfg.OutputRoot), mkdir(cfg.OutputRoot); end
for name = {'CtcManifestSha256','Moma15ManifestSha256'}
    value = lower(cfg.(name{1}));
    if isempty(regexp(value, '^[0-9a-f]{64}$', 'once'))
        error('unifiedMomaGt:InvalidManifestHash', ...
            '%s must be a SHA-256 digest.', name{1});
    end
    cfg.(name{1}) = value;
end
end

function assertEmptyClassifierTarget(path)
if ~isfolder(path), return; end
listing = dir(path);
listing = listing(~ismember({listing.name}, {'.','..'}));
if ~isempty(listing)
    error('unifiedMomaGt:OutputExists', ...
        'Classifier target is not empty: %s', path);
end
end

function assertFile(path)
if ~isfile(path)
    error('unifiedMomaGt:MissingFile', 'Required file not found: %s', path);
end
end

function item = itemTemplate()
item = struct('roi_index', 0, 'roi_id', '', 'source_id', '', ...
    'label_authority', '', 'frame_count', 0, 'relation_count', 0, ...
    'status', '', 'bundle_path', '', 'bundle_sha256', '');
end

function writeJsonAtomic(path, value)
folder = fileparts(path);
if ~isempty(folder) && ~isfolder(folder), mkdir(folder); end
temporary = [path '.tmp.' char(java.util.UUID.randomUUID)];
cleanup = onCleanup(@() deleteIfPresent(temporary));
fid = fopen(temporary, 'w', 'n', 'UTF-8');
if fid < 0, error('unifiedMomaGt:WriteFailed', ...
        'Cannot write JSON: %s', temporary); end
fileCleanup = onCleanup(@() fcloseIfOpen(fid));
fprintf(fid, '%s\n', jsonencode(value, 'PrettyPrint', true));
fclose(fid);
delete(fileCleanup);
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

function value = utcTimestamp()
value = char(datetime('now', 'TimeZone', 'UTC', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss.SSSXXX'));
end

function fcloseIfOpen(fid)
try fclose(fid); catch, end
end

function deleteIfPresent(path)
try if isfile(path), delete(path); end, catch, end
end

function tf = isText(value)
tf = ischar(value) || isstring(value);
end
