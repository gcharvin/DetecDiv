function report = stageRoiMetadataRepair(h5Path, classifierMat, roiId, repairRoot, varargin)
%STAGEROIMETADATAREPAIR Audit or stage a metadata-only ROI repair.
%
% report = stageRoiMetadataRepair(h5Path, classifierMat, roiId, repairRoot)
% performs a read-only audit.  Pass 'Stage', true to create an immutable,
% versioned repair bundle below repairRoot.  The source HDF5 and classifier
% MAT files are never modified by this function.
%
% The staged candidate normalizes:
%   * one compact, non-overlapping channel_indices layout;
%   * one identical global channelid vector on every HDF5 dataset;
%   * visible raw-image display semantics for explicitly declared
%     brightfield channels (not indexed, selected, opaque, no contour);
%   * the same brightfield display semantics in the classifier ROI snapshot.
%
% Dataset payload hashes are computed before and after staging.  A candidate
% is rejected if any payload hash changes.

p = inputParser;
p.addParameter('Stage', false, @(x)islogical(x) && isscalar(x));
p.addParameter('RepairStem', 'roi_metadata_repair', @(x)ischar(x) || isstring(x));
p.addParameter('BrightfieldChannels', {}, @(x)iscell(x) || isstring(x) || ischar(x));
p.addParameter('Supersedes', '', @(x)ischar(x) || isstring(x));
p.parse(varargin{:});
opts = p.Results;

h5Path = absoluteExistingFile(h5Path, 'ROI HDF5');
classifierMat = absoluteExistingFile(classifierMat, 'classifier MAT');
roiId = char(string(roiId));
repairRoot = char(string(repairRoot));
if isempty(strtrim(roiId))
    error('stageRoiMetadataRepair:MissingRoiId', 'roiId must not be empty.');
end

[classiObj, roiIndex] = loadClassifierRoi(classifierMat, roiId);
roiObj = classiObj.roi(roiIndex);
catalog = h5Catalog(h5Path);
brightfield = resolveBrightfieldChannels(opts.BrightfieldChannels, classiObj, catalog);
[catalog, canonicalOrder, globalMap] = canonicalizeCatalog(catalog, roiObj);

sourceH5Sha = fileSha256(h5Path);
sourceMatSha = fileSha256(classifierMat);
sourcePayload = datasetPayloadHashes(h5Path, catalog);
sourceAudit = auditMetadata(h5Path, roiObj, catalog, canonicalOrder, globalMap, brightfield);

report = struct();
report.schema_version = 1;
report.roi_id = roiId;
report.mode = ternary(opts.Stage, 'stage', 'audit');
report.source = struct( ...
    'h5_path', h5Path, 'h5_sha256', sourceH5Sha, ...
    'classifier_mat_path', classifierMat, 'classifier_mat_sha256', sourceMatSha);
report.brightfield_channels = brightfield;
report.canonical_channel_order = canonicalOrder;
report.canonical_channelid = globalMap;
report.audit_before = sourceAudit;
report.dataset_payloads_before = sourcePayload;
report.repair_dir = '';
report.candidate = struct();

if ~opts.Stage
    return;
end

if isempty(strtrim(repairRoot))
    error('stageRoiMetadataRepair:MissingRepairRoot', ...
        'repairRoot is required when Stage=true.');
end
if ~isfolder(repairRoot)
    mkdir(repairRoot);
end

stem = sanitizeRepairStem(opts.RepairStem);
[repairId, finalDir] = nextRepairDirectory(repairRoot, stem);
stageDir = fullfile(repairRoot, ['.' repairId '.staging_' char(java.util.UUID.randomUUID)]);
mkdir(stageDir);
stageCleanup = onCleanup(@()cleanupIncompleteStage(stageDir)); %#ok<NASGU>

originalH5 = fullfile(stageDir, 'originals', 'roi_images', fileName(h5Path));
originalMat = fullfile(stageDir, 'originals', 'classifier_snapshot', fileName(classifierMat));
candidateH5 = fullfile(stageDir, 'candidates', 'roi_images', fileName(h5Path));
candidateMat = fullfile(stageDir, 'candidates', 'classifier_snapshot', fileName(classifierMat));
ensureParent(originalH5); ensureParent(originalMat);
ensureParent(candidateH5); ensureParent(candidateMat);

copyfile(h5Path, originalH5, 'f');
copyfile(classifierMat, originalMat, 'f');
copyfile(h5Path, candidateH5, 'f');
copyfile(classifierMat, candidateMat, 'f');

assertSameHash(sourceH5Sha, fileSha256(originalH5), 'HDF5 snapshot');
assertSameHash(sourceMatSha, fileSha256(originalMat), 'classifier snapshot');

changes = normalizeH5Candidate(candidateH5, catalog, globalMap, brightfield);
normalizeClassifierCandidate(candidateMat, roiId, catalog, brightfield);

candidatePayload = datasetPayloadHashes(candidateH5, catalog);
assertPayloadsUnchanged(sourcePayload, candidatePayload);
candidateMatData = load(candidateMat, 'classiObj');
candidateRoiIndex = find(strcmp({candidateMatData.classiObj.roi.id}, roiId), 1);
candidateRoi = candidateMatData.classiObj.roi(candidateRoiIndex);
candidateAudit = auditMetadata(candidateH5, candidateRoi, catalog, ...
    canonicalOrder, globalMap, brightfield);
if ~candidateAudit.is_consistent
    error('stageRoiMetadataRepair:CandidateInvalid', ...
        'The staged candidate failed its metadata consistency audit: %s', ...
        strjoin(candidateAudit.issues, ' | '));
end

repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
[gitCommit, worktreeStatus] = gitState(repoRoot);
createdAt = utcTimestamp();

finalOriginalH5 = swapRoot(originalH5, stageDir, finalDir);
finalOriginalMat = swapRoot(originalMat, stageDir, finalDir);
finalCandidateH5 = swapRoot(candidateH5, stageDir, finalDir);
finalCandidateMat = swapRoot(candidateMat, stageDir, finalDir);

repairReport = struct( ...
    'schema_version', 1, ...
    'repair_id', repairId, ...
    'created_at', createdAt, ...
    'roi_id', roiId, ...
    'source_audit', sourceAudit, ...
    'candidate_audit', candidateAudit, ...
    'metadata_changes', changes, ...
    'dataset_payloads_before', sourcePayload, ...
    'dataset_payloads_after', candidatePayload);
reportPath = fullfile(stageDir, 'repair_report.json');
writeJson(reportPath, repairReport);

manifest = struct();
manifest.schema_version = 1;
manifest.repair_id = repairId;
manifest.creation_time = createdAt;
manifest.format = 'detecdiv_roi_metadata_repair_manifest';
manifest.supersedes = char(string(opts.Supersedes));
manifest.source_classifier_path = fileparts(classifierMat);
manifest.source_files = [ ...
    fileRecord(h5Path, sourceH5Sha), ...
    fileRecord(classifierMat, sourceMatSha), ...
    fileRecord(finalOriginalH5, fileSha256(originalH5), originalH5), ...
    fileRecord(finalOriginalMat, fileSha256(originalMat), originalMat)];
manifest.code_repository = repoRoot;
manifest.git_commit = gitCommit;
manifest.worktree_status_at_repair = worktreeStatus;
manifest.split_contract = ['No classifier ROI membership, frame bounds, or ' ...
    'train/validation/test selection was changed.'];
manifest.label_contract = ['No pixels, labels, tracks, parent links, states, or ' ...
    'annotation status were changed. Only HDF5/display metadata was normalized.'];
manifest.generated_files = [ ...
    fileRecord(finalCandidateH5, fileSha256(candidateH5), candidateH5), ...
    fileRecord(finalCandidateMat, fileSha256(candidateMat), candidateMat), ...
    fileRecord(swapRoot(reportPath, stageDir, finalDir), fileSha256(reportPath), reportPath)];
manifest.dataset_payload_contract = struct( ...
    'unchanged', true, 'before', sourcePayload, 'after', candidatePayload);
manifest.known_exclusions = { ...
    'Prediction-only HDF5 channels absent from the classifier snapshot are appended after classifier channels.', ...
    'The bundle is staged only; installing candidates over active classifier files requires a separate authorized action.'};
manifest.audit_warnings = { ...
    'Close Score/classifierGUI before any later installation so stale handle metadata cannot overwrite the repair.', ...
    'The active source files were not modified by this staging operation.'};
manifestPath = fullfile(stageDir, 'manifest.json');
writeJson(manifestPath, manifest);

[ok, message] = movefile(stageDir, finalDir, 'f');
if ~ok
    error('stageRoiMetadataRepair:FinalizeFailed', ...
        'Could not finalize repair directory: %s', message);
end
% Re-check the active files after staging to catch concurrent mutation.
assertSameHash(sourceH5Sha, fileSha256(h5Path), 'active HDF5 after staging');
assertSameHash(sourceMatSha, fileSha256(classifierMat), 'active classifier MAT after staging');

report.repair_id = repairId;
report.repair_dir = finalDir;
report.candidate = struct( ...
    'h5_path', finalCandidateH5, 'h5_sha256', fileSha256(finalCandidateH5), ...
    'classifier_mat_path', finalCandidateMat, ...
    'classifier_mat_sha256', fileSha256(finalCandidateMat), ...
    'manifest_path', fullfile(finalDir, 'manifest.json'), ...
    'repair_report_path', fullfile(finalDir, 'repair_report.json'), ...
    'audit', candidateAudit, ...
    'dataset_payloads', candidatePayload);
end

function pathOut = absoluteExistingFile(pathIn, label)
pathOut = char(string(pathIn));
if isempty(pathOut) || ~isfile(pathOut)
    error('stageRoiMetadataRepair:MissingFile', '%s not found: %s', label, pathOut);
end
pathOut = char(java.io.File(pathOut).getCanonicalPath());
end

function [obj, roiIndex] = loadClassifierRoi(matPath, roiId)
s = load(matPath, 'classiObj');
if ~isfield(s, 'classiObj') || isempty(s.classiObj)
    error('stageRoiMetadataRepair:MissingClassifier', ...
        'MAT file does not contain classiObj: %s', matPath);
end
obj = s.classiObj;
roiIndex = find(strcmp({obj.roi.id}, roiId), 1);
if isempty(roiIndex)
    error('stageRoiMetadataRepair:MissingRoi', ...
        'ROI "%s" is absent from %s.', roiId, matPath);
end
end

function catalog = h5Catalog(h5Path)
info = h5info(h5Path);
if isempty(info.Datasets)
    error('stageRoiMetadataRepair:EmptyH5', 'No root datasets in %s.', h5Path);
end
catalog = repmat(struct('dataset_name','','path','','channel_name','', ...
    'subchannels',0,'old_indices',[],'old_first_index',inf, ...
    'canonical_indices',[],'logical_index',0), 1, numel(info.Datasets));
for i = 1:numel(info.Datasets)
    name = info.Datasets(i).Name;
    path = ['/' name];
    channelName = readAttribute(h5Path, path, 'channel_name', name);
    channelName = char(string(channelName));
    k = double(readAttribute(h5Path, path, 'num_subchannels', 0));
    k = k(1);
    oldIdx = double(readAttribute(h5Path, path, 'channel_indices', []));
    oldIdx = reshape(oldIdx, 1, []);
    if ~(isfinite(k) && k >= 1 && k == round(k))
        k = numel(oldIdx);
    end
    if k < 1 || numel(oldIdx) ~= k
        error('stageRoiMetadataRepair:UnknownSubchannelCount', ...
            'Dataset %s has inconsistent num_subchannels/channel_indices.', path);
    end
    catalog(i).dataset_name = name;
    catalog(i).path = path;
    catalog(i).channel_name = channelName;
    catalog(i).subchannels = k;
    catalog(i).old_indices = oldIdx;
    if ~isempty(oldIdx) && all(isfinite(oldIdx)), catalog(i).old_first_index = min(oldIdx); end
end
names = lower(string({catalog.channel_name}));
if numel(unique(names)) ~= numel(names)
    error('stageRoiMetadataRepair:DuplicateChannelNames', ...
        'HDF5 contains duplicate logical channel_name values.');
end
end

function channels = resolveBrightfieldChannels(explicit, classiObj, catalog)
channels = normalizeCellstr(explicit);
if isempty(channels)
    try
        value = classiObj.trainingParam.brightfieldChannelName;
        channels = normalizeCellstr(value);
    catch
    end
end
if isempty(channels)
    names = {catalog.channel_name};
    tokens = lower(string(names));
    hit = contains(tokens, 'brightfield') | contains(tokens, 'channel1_z2') | ...
        strcmp(tokens, 'bf') | contains(tokens, 'dic') | contains(tokens, 'phase');
    channels = names(hit);
end
channels = unique(channels, 'stable');
end

function values = normalizeCellstr(value)
if isempty(value), values = {}; return; end
if ischar(value), values = {value};
elseif isstring(value), values = cellstr(value(:).');
elseif iscell(value), values = cellfun(@(x)char(string(x)), value, 'UniformOutput', false);
else, values = cellstr(string(value));
end
values = values(~cellfun(@isempty, values));
end

function [catalog, order, globalMap] = canonicalizeCatalog(catalog, roiObj)
h5Names = {catalog.channel_name};
displayNames = {};
try, displayNames = normalizeCellstr(roiObj.display.channel); catch, end
order = displayNames(ismember(lower(string(displayNames)), lower(string(h5Names))));
remaining = h5Names(~ismember(lower(string(h5Names)), lower(string(order))));
if ~isempty(remaining)
    remainingIdx = zeros(1, numel(remaining));
    for i = 1:numel(remaining)
        k = find(strcmpi(h5Names, remaining{i}), 1);
        remainingIdx(i) = catalog(k).old_first_index;
    end
    tab = table(remainingIdx(:), lower(string(remaining(:))), (1:numel(remaining))', ...
        'VariableNames', {'old_index','name','position'});
    tab = sortrows(tab, {'old_index','name','position'});
    remaining = remaining(tab.position);
end
order = [order remaining];

cursor = 0;
globalMap = [];
for logicalIndex = 1:numel(order)
    k = find(strcmpi(h5Names, order{logicalIndex}), 1);
    count = catalog(k).subchannels;
    catalog(k).canonical_indices = cursor + (1:count);
    catalog(k).logical_index = logicalIndex;
    globalMap = [globalMap repmat(logicalIndex, 1, count)]; %#ok<AGROW>
    cursor = cursor + count;
end
end

function audit = auditMetadata(h5Path, roiObj, catalog, order, globalMap, brightfield)
issues = {};
allIndices = [];
for i = 1:numel(catalog)
    idx = reshape(double(readAttribute(h5Path, catalog(i).path, 'channel_indices', [])), 1, []);
    map = reshape(double(readAttribute(h5Path, catalog(i).path, 'channelid', [])), 1, []);
    if ~isequal(idx, catalog(i).canonical_indices)
        issues{end+1} = sprintf('%s channel_indices=%s, expected=%s', ...
            catalog(i).channel_name, mat2str(idx), mat2str(catalog(i).canonical_indices)); %#ok<AGROW>
    end
    if ~isequal(map, globalMap)
        issues{end+1} = sprintf('%s channelid differs from canonical global mapping', ...
            catalog(i).channel_name); %#ok<AGROW>
    end
    allIndices = [allIndices idx]; %#ok<AGROW>
    if any(strcmpi(brightfield, catalog(i).channel_name))
        issues = auditBrightfieldH5(issues, h5Path, catalog(i));
    end
end
if ~isequal(sort(allIndices), 1:numel(globalMap)) || numel(unique(allIndices)) ~= numel(globalMap)
    issues{end+1} = 'HDF5 channel_indices are overlapping or non-compact.'; %#ok<AGROW>
end

displayNames = normalizeCellstr(roiObj.display.channel);
for i = 1:numel(brightfield)
    pos = find(strcmpi(displayNames, brightfield{i}), 1);
    if isempty(pos)
        issues{end+1} = sprintf('Classifier ROI display omits brightfield channel %s', brightfield{i}); %#ok<AGROW>
    else
        issues = auditBrightfieldDisplay(issues, roiObj.display, pos, brightfield{i});
    end
end

expectedClassifierMap = [];
for i = 1:numel(displayNames)
    k = find(strcmpi({catalog.channel_name}, displayNames{i}), 1);
    if ~isempty(k)
        expectedClassifierMap = [expectedClassifierMap repmat(i,1,catalog(k).subchannels)]; %#ok<AGROW>
    end
end
actualClassifierMap = reshape(double(roiObj.channelid),1,[]);
if ~isequal(actualClassifierMap, expectedClassifierMap)
    issues{end+1} = sprintf('Classifier channelid=%s, expected=%s', ...
        mat2str(actualClassifierMap), mat2str(expectedClassifierMap)); %#ok<AGROW>
end

audit = struct('is_consistent', isempty(issues), 'issues', {issues}, ...
    'h5_channel_order', {order}, 'h5_channelid', globalMap, ...
    'classifier_channels', {displayNames}, ...
    'classifier_channelid', actualClassifierMap, ...
    'expected_classifier_channelid', expectedClassifierMap);
end

function changes = normalizeH5Candidate(h5Path, catalog, globalMap, brightfield)
changes = repmat(struct('channel_name','','old_channel_indices',[], ...
    'new_channel_indices',[],'old_channelid',[],'new_channelid',[], ...
    'old_display_indexed',[],'new_display_indexed',[], ...
    'brightfield_display_before',struct(),'brightfield_display_after',struct()), ...
    1, numel(catalog));
for i = 1:numel(catalog)
    path = catalog(i).path;
    oldIndices = reshape(double(readAttribute(h5Path,path,'channel_indices',[])),1,[]);
    oldMap = reshape(double(readAttribute(h5Path,path,'channelid',[])),1,[]);
    oldIndexed = logical(readAttribute(h5Path,path,'display_indexed',uint8(0)));
    isBrightfield = any(strcmpi(brightfield, catalog(i).channel_name));
    beforeDisplay = struct();
    afterDisplay = struct();
    if isBrightfield
        beforeDisplay = h5DisplayState(h5Path, path);
    end
    newIndexed = desiredIndexed(catalog(i).channel_name, catalog(i).subchannels, ...
        oldIndexed, brightfield);
    h5writeatt(h5Path, path, 'channel_indices', catalog(i).canonical_indices);
    h5writeatt(h5Path, path, 'channelid', globalMap);
    h5writeatt(h5Path, path, 'num_subchannels', catalog(i).subchannels);
    h5writeatt(h5Path, path, 'display_indexed', uint8(newIndexed));
    if isBrightfield
        writeBrightfieldH5Display(h5Path, path);
        afterDisplay = h5DisplayState(h5Path, path);
    end
    changes(i) = struct('channel_name',catalog(i).channel_name, ...
        'old_channel_indices',oldIndices,'new_channel_indices',catalog(i).canonical_indices, ...
        'old_channelid',oldMap,'new_channelid',globalMap, ...
        'old_display_indexed',oldIndexed,'new_display_indexed',newIndexed, ...
        'brightfield_display_before',beforeDisplay, ...
        'brightfield_display_after',afterDisplay);
end
end

function normalizeClassifierCandidate(matPath, roiId, catalog, brightfield)
s = load(matPath);
obj = s.classiObj;
idx = find(strcmp({obj.roi.id}, roiId), 1);
r = obj.roi(idx);
names = normalizeCellstr(r.display.channel);
for i = 1:numel(names)
    catalogIndex = find(strcmpi({catalog.channel_name}, names{i}), 1);
    if isempty(catalogIndex), continue; end
    oldIndexed = false;
    try, oldIndexed = logical(r.display.indexed(i)); catch, end
    r.display.indexed(i) = desiredIndexed(names{i}, ...
        catalog(catalogIndex).subchannels, oldIndexed, brightfield);
    if any(strcmpi(brightfield, names{i}))
        r.display = writeBrightfieldMatDisplay(r.display, i);
    end
end
map = [];
for i = 1:numel(names)
    catalogIndex = find(strcmpi({catalog.channel_name}, names{i}), 1);
    if ~isempty(catalogIndex)
        map = [map repmat(i,1,catalog(catalogIndex).subchannels)]; %#ok<AGROW>
    end
end
r.channelid = map;
obj.roi(idx) = r;
s.classiObj = obj;
saveVersion = detectMatSaveVersion(matPath);
save(matPath, '-struct', 's', saveVersion);
end

function issues = auditBrightfieldH5(issues, h5Path, catalogEntry)
state = h5DisplayState(h5Path, catalogEntry.path);
name = catalogEntry.channel_name;
if state.indexed
    issues{end+1} = sprintf('%s is incorrectly display_indexed in HDF5', name); %#ok<AGROW>
end
if ~isequal(state.intensity, [1 1 1])
    issues{end+1} = sprintf('%s HDF5 intensity is not [1 1 1]', name); %#ok<AGROW>
end
if ~isequal(state.rgb, [1 1 1])
    issues{end+1} = sprintf('%s HDF5 rgb is not [1 1 1]', name); %#ok<AGROW>
end
if state.alpha ~= 1
    issues{end+1} = sprintf('%s HDF5 alpha is not 1', name); %#ok<AGROW>
end
if state.contour
    issues{end+1} = sprintf('%s HDF5 contour is enabled', name); %#ok<AGROW>
end
if ~state.selected
    issues{end+1} = sprintf('%s HDF5 selectedchannel is disabled', name); %#ok<AGROW>
end
end

function issues = auditBrightfieldDisplay(issues, display, pos, name)
try, indexed = logical(display.indexed(pos)); catch, indexed = true; end
try, intensity = reshape(double(display.intensity(pos,:)),1,[]); catch, intensity = []; end
try, rgb = reshape(double(display.rgb(pos,:)),1,[]); catch, rgb = []; end
try, alpha = double(display.alpha(pos)); catch, alpha = nan; end
try, contour = logical(display.contour(pos)); catch, contour = true; end
try, selected = logical(display.selectedchannel(pos)); catch, selected = false; end
if indexed, issues{end+1} = sprintf('%s is incorrectly indexed in classifier MAT', name); end %#ok<AGROW>
if ~isequal(intensity,[1 1 1]), issues{end+1} = sprintf('%s classifier intensity is not [1 1 1]',name); end %#ok<AGROW>
if ~isequal(rgb,[1 1 1]), issues{end+1} = sprintf('%s classifier rgb is not [1 1 1]',name); end %#ok<AGROW>
if alpha ~= 1, issues{end+1} = sprintf('%s classifier alpha is not 1',name); end %#ok<AGROW>
if contour, issues{end+1} = sprintf('%s classifier contour is enabled',name); end %#ok<AGROW>
if ~selected, issues{end+1} = sprintf('%s classifier selectedchannel is disabled',name); end %#ok<AGROW>
end

function state = h5DisplayState(h5Path, path)
state = struct( ...
    'indexed', logical(firstValue(readAttribute(h5Path,path,'display_indexed',uint8(0)))), ...
    'intensity', reshape(double(readAttribute(h5Path,path,'display_intensity',[])),1,[]), ...
    'rgb', reshape(double(readAttribute(h5Path,path,'display_rgb',[])),1,[]), ...
    'alpha', double(firstValue(readAttribute(h5Path,path,'display_alpha',nan))), ...
    'contour', logical(firstValue(readAttribute(h5Path,path,'display_contour',uint8(0)))), ...
    'selected', logical(firstValue(readAttribute(h5Path,path,'display_selectedchannel',uint8(0)))));
end

function writeBrightfieldH5Display(h5Path, path)
h5writeatt(h5Path, path, 'display_indexed', uint8(0));
h5writeatt(h5Path, path, 'display_intensity', [1 1 1]);
h5writeatt(h5Path, path, 'display_rgb', [1 1 1]);
h5writeatt(h5Path, path, 'display_alpha', 1);
h5writeatt(h5Path, path, 'display_contour', uint8(0));
h5writeatt(h5Path, path, 'display_selectedchannel', uint8(1));
end

function display = writeBrightfieldMatDisplay(display, pos)
display.indexed(pos) = false;
display.intensity(pos,:) = [1 1 1];
display.rgb(pos,:) = [1 1 1];
display.alpha(pos) = 1;
display.contour(pos) = false;
display.selectedchannel(pos) = true;
end

function value = firstValue(value)
if isempty(value), value = 0; else, value = value(1); end
end

function version = detectMatSaveVersion(path)
fid = fopen(path,'rb');
if fid < 0, error('stageRoiMetadataRepair:FileReadFailed','Cannot read %s.',path); end
cleanup = onCleanup(@()fclose(fid)); %#ok<NASGU>
signature = fread(fid,8,'*uint8').';
hdf5Signature = uint8([137 72 68 70 13 10 26 10]);
if isequal(signature,hdf5Signature), version = '-v7.3'; else, version = '-v7'; end
end

function indexed = desiredIndexed(name, subchannels, existing, brightfield)
token = lower(strtrim(char(string(name))));
if any(strcmpi(brightfield, name))
    indexed = false;
elseif strcmpi(token, 'combinedchannel') && subchannels > 1
    indexed = false;
elseif startsWith(token, 'results_') || contains(token, 'mask') || ...
        contains(token, 'track') || endsWith(token, '_cell')
    indexed = true;
else
    indexed = logical(existing(1));
end
end

function hashes = datasetPayloadHashes(h5Path, catalog)
hashes = repmat(struct('channel_name','','dataset_path','','sha256','', ...
    'class','','size',[]), 1, numel(catalog));
for i = 1:numel(catalog)
    value = h5read(h5Path, catalog(i).path);
    hashes(i) = struct('channel_name',catalog(i).channel_name, ...
        'dataset_path',catalog(i).path,'sha256',arraySha256(value), ...
        'class',class(value),'size',size(value));
end
end

function assertPayloadsUnchanged(before, after)
for i = 1:numel(before)
    k = find(strcmp({after.channel_name}, before(i).channel_name), 1);
    if isempty(k) || ~strcmp(before(i).sha256, after(k).sha256) || ...
            ~strcmp(before(i).class, after(k).class) || ...
            ~isequal(before(i).size, after(k).size)
        error('stageRoiMetadataRepair:PayloadChanged', ...
            'Dataset payload changed for %s.', before(i).channel_name);
    end
end
end

function value = readAttribute(file, path, name, default)
try, value = h5readatt(file, path, name); catch, value = default; end
end

function hash = arraySha256(value)
if ~(isnumeric(value) || islogical(value) || ischar(value))
    error('stageRoiMetadataRepair:UnsupportedPayload', ...
        'Unsupported HDF5 payload class for hashing: %s', class(value));
end
digest = java.security.MessageDigest.getInstance('SHA-256');
bytes = typecast(value(:), 'uint8');
digest.update(bytes);
hash = digestHex(digest);
end

function hash = fileSha256(path)
fid = fopen(path, 'rb');
if fid < 0, error('stageRoiMetadataRepair:FileReadFailed','Cannot read %s.',path); end
closer = onCleanup(@()fclose(fid)); %#ok<NASGU>
digest = java.security.MessageDigest.getInstance('SHA-256');
while true
    bytes = fread(fid, 1024*1024, '*uint8');
    if isempty(bytes), break; end
    digest.update(bytes);
end
hash = digestHex(digest);
end

function hash = digestHex(digest)
raw = typecast(digest.digest(), 'uint8');
hash = lower(reshape(dec2hex(raw,2).',1,[]));
end

function [repairId, finalDir] = nextRepairDirectory(root, stem)
version = 1;
while true
    repairId = sprintf('%s_v%03d', stem, version);
    finalDir = fullfile(root, repairId);
    if ~exist(finalDir, 'dir'), return; end
    version = version + 1;
end
end

function stem = sanitizeRepairStem(value)
stem = lower(regexprep(char(string(value)), '[^a-zA-Z0-9_-]+', '_'));
stem = regexprep(stem, '^_+|_+$', '');
stem = regexprep(stem, '_v\d+$', '');
if isempty(stem), error('stageRoiMetadataRepair:InvalidRepairStem','Invalid RepairStem.'); end
end

function [commit, status] = gitState(repoRoot)
[code, out] = system(sprintf('git -C "%s" rev-parse HEAD', repoRoot));
if code == 0, commit = strtrim(out); else, commit = ''; end
[~, out] = system(sprintf('git -C "%s" status --short', repoRoot));
out = strtrim(out);
if isempty(out), status = {}; else, status = cellstr(splitlines(string(out))).'; end
end

function record = fileRecord(path, hash, statPath)
if nargin < 3 || isempty(statPath), statPath = path; end
info = dir(statPath);
if isempty(info), error('stageRoiMetadataRepair:MissingManifestFile', ...
        'Cannot stat manifest file: %s', statPath); end
bytes = info(1).bytes;
record = struct('path',path,'sha256',hash,'bytes',bytes);
end

function writeJson(path, value)
try, text = jsonencode(value, 'PrettyPrint', true);
catch, text = jsonencode(value);
end
fid = fopen(path, 'w');
if fid < 0, error('stageRoiMetadataRepair:JsonWriteFailed','Cannot write %s.',path); end
closer = onCleanup(@()fclose(fid)); %#ok<NASGU>
fwrite(fid, text, 'char');
fwrite(fid, newline, 'char');
end

function ensureParent(path)
parent = fileparts(path);
if ~isfolder(parent), mkdir(parent); end
end

function name = fileName(path)
[n,e1,e2] = fileparts(path); %#ok<ASGLU>
name = [e1 e2];
end

function out = swapRoot(path, oldRoot, newRoot)
suffix = extractAfter(string(path), strlength(string(oldRoot)));
suffix = regexprep(char(suffix), '^[\\/]+', '');
out = fullfile(newRoot, suffix);
end

function assertSameHash(expected, actual, label)
if ~strcmp(expected, actual)
    error('stageRoiMetadataRepair:HashMismatch', ...
        '%s hash mismatch: expected %s, got %s.', label, expected, actual);
end
end

function cleanupIncompleteStage(path)
if isfolder(path)
    try, rmdir(path, 's'); catch, end
end
end

function stamp = utcTimestamp()
stamp = char(datetime('now','TimeZone','UTC', ...
    'Format',"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"));
end

function out = ternary(condition, yes, no)
if condition, out = yes; else, out = no; end
end
