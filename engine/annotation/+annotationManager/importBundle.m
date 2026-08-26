function report = importBundle(classif, roiObj, spec, bundleInput, varargin)
%ANNOTATIONMANAGER.IMPORTBUNDLE Import external GT into managed Draft storage.
%
% The v1 bundle may provide either:
%   - tracked_mask: a HxWxT stable-track label stack; or
%   - source_family: an existing DetecDiv cell-model family to clone.
% It may additionally provide parent relations, explicit per-component
% review coverage, provenance, notes, and exclusions. Merely supplying an
% asset never marks it reviewed.

p = inputParser;
p.addParameter('Overwrite', false, @(x) islogical(x) && isscalar(x));
p.addParameter('Save', true, @(x) islogical(x) && isscalar(x));
p.addParameter('SourceFamily', '', @(x) ischar(x) || isstring(x));
p.parse(varargin{:});

[bundle, bundlePath, bundleHash] = loadBundle(bundleInput);
bundle = normalizeBundle(bundle, roiObj, bundlePath, bundleHash);
sourceFamily = char(string(p.Results.SourceFamily));
if isempty(sourceFamily), sourceFamily = bundle.source_family; end

hasMask = ~isempty(bundle.tracked_mask);
if ~hasMask && isempty(sourceFamily)
    error('annotationManager:BundleMissingTrackingSource', ...
        ['The bundle must contain tracked_mask or name an existing ' ...
         'source_family whose TrackIDs match the imported relations.']);
end

if hasMask
    [initialReport, targetChannel, targetFamily] = importTrackedMask( ...
        classif, roiObj, spec, bundle, p.Results.Overwrite);
else
    recipe = struct('mode', 'family', 'family', sourceFamily, ...
        'channel', '', 'copyParentage', false);
    initialReport = annotationManager.initialize( ...
        classif, roiObj, spec, recipe, ...
        'Overwrite', p.Results.Overwrite, 'Save', false, ...
        'SourceRunId', bundle.provenance.source_run_id);
    targetChannel = groundTruthChannel(spec);
    targetFamily = groundTruthFamily(spec);
end

[model, ~] = roiObj.loadCellModel('MigrateLegacy', true);
[model, relationReport] = importRelations( ...
    model, targetFamily, bundle.relations);
roiObj.cellModel = model;

entry = initialReport.entry;
entry.status = 'draft';
entry = annotationManager.resetValidationState(entry);
entry.source_type = 'external_bundle';
entry.source_id = bundle.provenance.source_id;
entry.source_run_id = bundle.provenance.source_run_id;
entry.source_manifest_path = bundle.provenance.manifest_path;
entry.source_manifest_sha256 = bundle.provenance.manifest_sha256;
entry.source_bundle_sha256 = bundle.provenance.bundle_sha256;
entry.label_authority = bundle.provenance.label_authority;
entry.import_notes = bundle.notes;
entry.import_exclusions = bundle.exclusions;
entry = applyCoverage(entry, bundle.coverage, ...
    annotationManager.frameCount(roiObj));

if p.Results.Save
    if hasMask
        didSave = roiObj.save({targetChannel}, false);
        if ~didSave
            error('annotationManager:GroundTruthPersistenceFailed', ...
                'Imported GT channel "%s" could not be saved.', targetChannel);
        end
    end
    roiObj.saveCellModel(model);
end
entry = annotationManager.setEntry(roiObj, spec, entry, ...
    'Save', p.Results.Save);

report = struct( ...
    'status', entry.status, ...
    'roi_id', char(string(roiObj.id)), ...
    'target_channel', targetChannel, ...
    'target_family', targetFamily, ...
    'source_family', sourceFamily, ...
    'relations', relationReport, ...
    'coverage', bundle.coverage, ...
    'exclusions', {bundle.exclusions}, ...
    'provenance', bundle.provenance, ...
    'entry', entry);
end

function [report, targetChannel, targetFamily] = importTrackedMask( ...
        classif, roiObj, spec, bundle, overwrite)
stack = normalizeMask(bundle.tracked_mask);
totalFrames = annotationManager.frameCount(roiObj);
if size(stack, 3) ~= totalFrames
    error('annotationManager:BundleFrameCountMismatch', ...
        'Bundle mask has %d frame(s), but ROI "%s" has %d.', ...
        size(stack, 3), char(string(roiObj.id)), totalFrames);
end

roiObj.load('Silent');
if isempty(roiObj.image) || size(stack,1) ~= size(roiObj.image,1) || ...
        size(stack,2) ~= size(roiObj.image,2)
    error('annotationManager:BundleMaskSizeMismatch', ...
        'Bundle mask dimensions do not match ROI "%s".', ...
        char(string(roiObj.id)));
end

report = annotationManager.startBlank(classif, roiObj, spec, ...
    'Overwrite', overwrite, 'Save', false);
targetChannel = groundTruthChannel(spec);
targetFamily = groundTruthFamily(spec);
targetIndex = roiObj.findChannelID(targetChannel);
if isempty(targetIndex)
    error('annotationManager:MissingGroundTruthBinding', ...
        'Blank initialization did not create GT channel "%s".', targetChannel);
end
roiObj.image(:,:,targetIndex,:) = cast(reshape(stack, ...
    size(stack,1), size(stack,2), 1, size(stack,3)), class(roiObj.image));

[model, ~] = roiObj.loadCellModel('MigrateLegacy', true);
result = struct('edges', struct([]));
[model, ~] = cellModel.applyLineageResult(model, stack, ...
    targetChannel, '', targetFamily, result, true, 'external_ground_truth');
roiObj.cellModel = model;
end

function [model, report] = importRelations(model, family, relations)
template = struct('child_track_id', uint64(0), ...
    'parent_track_id', uint64(0), 'source_event_frame', uint32(0), ...
    'stored_event_frame', uint32(0), 'status', '');
report = repmat(template, numel(relations), 1);
for i = 1:numel(relations)
    relation = relations(i);
    requestedFrame = double(relation.event_frame);
    if requestedFrame < 1, requestedFrame = 1; end
    [model, item] = cellModel.setParentTrack(model, family, ...
        requestedFrame, relation.child_track_id, ...
        relation.parent_track_id);
    [~, familyId] = cellModel.familyIndex(model, family);
    row = find(model.relations.family_id == familyId & ...
        model.relations.child_track_id == uint64(relation.child_track_id) & ...
        model.relations.type_id == uint8(1), 1, 'first');
    if isfinite(relation.confidence)
        model.relations.confidence(row) = single(relation.confidence);
    end
    report(i).child_track_id = uint64(relation.child_track_id);
    report(i).parent_track_id = uint64(relation.parent_track_id);
    report(i).source_event_frame = uint32(max(0, relation.event_frame));
    report(i).stored_event_frame = item.event_frame;
    report(i).status = item.status;
end
model = cellModel.normalize(model);
cellModel.validate(model, 'Throw', true);
end

function entry = applyCoverage(entry, coverage, totalFrames)
for i = 1:numel(entry.review)
    id = char(string(entry.review(i).component_id));
    if strcmp(entry.review(i).unit, 'roi')
        field = [id '_complete'];
        if isfield(coverage, field)
            entry.review(i).complete = logical(coverage.(field));
        end
        continue;
    end
    field = [id '_frames'];
    if ~isfield(coverage, field), continue; end
    frames = unique(round(double(coverage.(field)(:).')));
    frames = frames(isfinite(frames) & frames >= 1 & frames <= totalFrames);
    entry.review(i).frames(:) = false;
    entry.review(i).frames(frames) = true;
    entry.review(i).complete = all(entry.review(i).frames);
end
end

function [bundle, path, hash] = loadBundle(value)
path = '';
hash = '';
if isstruct(value)
    bundle = value;
    return;
end
path = char(string(value));
if ~isfile(path)
    error('annotationManager:BundleNotFound', ...
        'GT bundle file does not exist: %s', path);
end
hash = fileSha256(path);
[~,~,extension] = fileparts(path);
switch lower(extension)
    case '.mat'
        stored = load(path);
        if isfield(stored, 'bundle')
            bundle = stored.bundle;
        else
            names = fieldnames(stored);
            if numel(names) ~= 1 || ~isstruct(stored.(names{1}))
                error('annotationManager:InvalidBundleFile', ...
                    'MAT bundle must contain one struct variable named bundle.');
            end
            bundle = stored.(names{1});
        end
    case '.json'
        bundle = jsondecode(fileread(path));
    otherwise
        error('annotationManager:UnsupportedBundleFile', ...
            'GT bundles must be MAT or JSON files.');
end
end

function bundle = normalizeBundle(value, roiObj, bundlePath, bundleHash)
if ~isstruct(value) || ~isscalar(value)
    error('annotationManager:InvalidBundle', ...
        'GT bundle must be a scalar struct.');
end
format = textField(value, 'format', '');
if ~strcmp(format, 'detecdiv_managed_gt_import_v1')
    error('annotationManager:UnsupportedBundleFormat', ...
        'Expected bundle format detecdiv_managed_gt_import_v1.');
end
roiId = textField(value, 'roi_id', '');
if isempty(roiId) || ~strcmp(roiId, char(string(roiObj.id)))
    error('annotationManager:BundleRoiMismatch', ...
        'Bundle ROI "%s" does not match selected ROI "%s".', ...
        roiId, char(string(roiObj.id)));
end

bundle = struct();
bundle.format = format;
bundle.roi_id = roiId;
bundle.source_family = textField(value, 'source_family', '');
bundle.tracked_mask = fieldOr(value, 'tracked_mask', []);
bundle.relations = normalizeRelations(fieldOr(value, 'relations', struct([])));
bundle.coverage = fieldOr(value, 'coverage', struct());
if ~isstruct(bundle.coverage) || ~isscalar(bundle.coverage)
    error('annotationManager:InvalidBundleCoverage', ...
        'Bundle coverage must be a scalar struct.');
end
bundle.notes = textField(value, 'notes', '');
bundle.exclusions = textList(fieldOr(value, 'exclusions', {}));
bundle.provenance = normalizeProvenance( ...
    fieldOr(value, 'provenance', struct()), bundlePath, bundleHash);
end

function provenance = normalizeProvenance(value, bundlePath, bundleHash)
if ~isstruct(value) || ~isscalar(value), value = struct(); end
provenance = struct( ...
    'source_id', textField(value, 'source_id', ''), ...
    'source_run_id', textField(value, 'source_run_id', ''), ...
    'manifest_path', textField(value, 'manifest_path', ''), ...
    'manifest_sha256', lower(textField(value, 'manifest_sha256', '')), ...
    'bundle_path', bundlePath, ...
    'bundle_sha256', lower(bundleHash), ...
    'label_authority', textField(value, 'label_authority', ''));
if isempty(provenance.source_id)
    error('annotationManager:MissingBundleProvenance', ...
        'Bundle provenance.source_id is required.');
end
if isempty(provenance.label_authority)
    error('annotationManager:MissingBundleAuthority', ...
        'Bundle provenance.label_authority is required.');
end
if ~isempty(provenance.manifest_sha256) && ...
        isempty(regexp(provenance.manifest_sha256, '^[0-9a-f]{64}$', 'once'))
    error('annotationManager:InvalidManifestHash', ...
        'provenance.manifest_sha256 must be a SHA-256 hex digest.');
end
end

function relations = normalizeRelations(value)
template = struct('parent_track_id', uint64(0), ...
    'child_track_id', uint64(0), 'event_frame', 0, 'confidence', NaN);
if isempty(value)
    relations = repmat(template, 0, 1);
    return;
end
if istable(value), value = table2struct(value); end
if ~isstruct(value)
    error('annotationManager:InvalidBundleRelations', ...
        'Bundle relations must be a struct array or table.');
end
relations = repmat(template, numel(value), 1);
for i = 1:numel(value)
    parent = numericField(value(i), {'parent_track_id','parent_id'});
    child = numericField(value(i), {'child_track_id','child_id'});
    if parent < 1 || child < 1 || parent ~= round(parent) || ...
            child ~= round(child)
        error('annotationManager:InvalidBundleRelation', ...
            'Every relation needs positive integer parent and child TrackIDs.');
    end
    relations(i).parent_track_id = uint64(parent);
    relations(i).child_track_id = uint64(child);
    relations(i).event_frame = numericField(value(i), ...
        {'event_frame','bud_appearance_frame'}, 0);
    relations(i).confidence = numericField(value(i), ...
        {'confidence','score','top_score'}, NaN);
end
end

function stack = normalizeMask(value)
if ~isnumeric(value) && ~islogical(value)
    error('annotationManager:InvalidBundleMask', ...
        'tracked_mask must be a numeric stable-track label stack.');
end
if ndims(value) == 4 && size(value,3) == 1
    value = reshape(value, size(value,1), size(value,2), size(value,4));
elseif ismatrix(value)
    value = reshape(value, size(value,1), size(value,2), 1);
end
if ndims(value) ~= 3
    error('annotationManager:InvalidBundleMask', ...
        'tracked_mask must have shape HxWxT or HxWx1xT.');
end
if any(~isfinite(double(value(:)))) || any(value(:) < 0) || ...
        any(double(value(:)) ~= round(double(value(:)))) || ...
        any(double(value(:)) > double(intmax('uint32')))
    error('annotationManager:InvalidBundleMask', ...
        'tracked_mask labels must be uint32-compatible non-negative integers.');
end
stack = uint32(value);
end

function name = groundTruthChannel(spec)
name = '';
for i = 1:numel(spec.components)
    if strcmp(char(string(spec.components(i).storage)), 'channel')
        name = char(string(spec.components(i).groundTruth.channel));
        if ~isempty(name), return; end
    end
end
error('annotationManager:MissingGroundTruthBinding', ...
    'Annotation spec has no GT channel binding.');
end

function name = groundTruthFamily(spec)
name = '';
for i = 1:numel(spec.components)
    if strcmp(char(string(spec.components(i).storage)), 'cell_model_family')
        name = char(string(spec.components(i).groundTruth.family));
        if ~isempty(name), return; end
    end
end
error('annotationManager:MissingGroundTruthBinding', ...
    'Annotation spec has no GT object-family binding.');
end

function value = fieldOr(source, name, fallback)
value = fallback;
if isstruct(source) && isfield(source, name) && ~isempty(source.(name))
    value = source.(name);
end
end

function value = textField(source, name, fallback)
value = fallback;
if isstruct(source) && isfield(source, name) && ~isempty(source.(name))
    value = char(string(source.(name)));
end
end

function value = numericField(source, names, varargin)
if isempty(varargin), fallback = NaN; else, fallback = varargin{1}; end
value = fallback;
for i = 1:numel(names)
    if isfield(source, names{i}) && ~isempty(source.(names{i}))
        value = double(source.(names{i}));
        break;
    end
end
if ~isscalar(value) || (~isfinite(value) && ~isnan(value))
    error('annotationManager:InvalidBundleRelation', ...
        'Relation fields must be scalar numeric values.');
end
end

function values = textList(value)
if isempty(value)
    values = cell(0,1);
elseif ischar(value) || isstring(value)
    values = cellstr(string(value(:)));
elseif iscell(value)
    values = cellfun(@(x) char(string(x)), value(:), ...
        'UniformOutput', false);
elseif isstruct(value)
    values = cellstr(string(jsonencode(value)));
else
    error('annotationManager:InvalidBundleExclusions', ...
        'Bundle exclusions must be text or a struct array.');
end
end

function hash = fileSha256(path)
digest = java.security.MessageDigest.getInstance('SHA-256');
stream = java.io.FileInputStream(java.io.File(path));
cleanup = onCleanup(@() stream.close()); %#ok<NASGU>
buffer = zeros(1, 1024 * 1024, 'int8');
while true
    count = stream.read(buffer, 0, numel(buffer));
    if count < 0, break; end
    digest.update(buffer(1:count));
end
raw = typecast(digest.digest(), 'uint8');
hash = lower(reshape(dec2hex(raw, 2).', 1, []));
end
