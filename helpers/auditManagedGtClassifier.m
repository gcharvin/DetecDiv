function report = auditManagedGtClassifier(classifierFile, varargin)
%AUDITMANAGEDGTCLASSIFIER Reopen and audit a managed lineage GT classifier.

% The audit is read-only: review coverage is inspected but never promoted.
% Parentage timestamps are checked against the first visible child frame.

p = inputParser;
p.addParameter('ExpectedRoiCount', [], @isnumeric);
p.addParameter('ExpectedRelationCount', [], @isnumeric);
p.addParameter('OutputFile', '', @(x)ischar(x) || isstring(x));
p.parse(varargin{:});

classifierFile = char(string(classifierFile));
[classif, message] = classiLoad(classifierFile);
if isempty(classif)
    error('auditManagedGtClassifier:LoadFailed', '%s', message);
end

itemTemplate = struct('roi_id', '', 'status', '', 'relation_count', 0, ...
    'validation_error_count', 0, 'validation_issue_count', 0, ...
    'noncanonical_event_count', 0, 'storage_path', '', ...
    'durable_file_count', 0);
items = repmat(itemTemplate, numel(classif.roi), 1);
allErrors = strings(0, 1);
issueCodes = strings(0, 1);

for i = 1:numel(classif.roi)
    session = classif.annotationSession(i);
    summary = session.summary();
    validation = annotationManager.validate(classif.roi(i), session.Spec, ...
        'RequireReviewed', false, 'ReviewFrames', session.trainingFrames());
    allErrors = [allErrors; string(validation.errors(:))]; %#ok<AGROW>
    if ~isempty(validation.issues)
        issueCodes = [issueCodes; string({validation.issues.code}).']; %#ok<AGROW>
    end

    lineage = session.Spec.components(strcmp( ...
        {session.Spec.components.kind}, 'lineage'));
    if numel(lineage) ~= 1
        error('auditManagedGtClassifier:LineageSpec', ...
            'ROI "%s" has no unique lineage component.', classif.roi(i).id);
    end
    [model, ~] = classif.roi(i).loadCellModel('MigrateLegacy', true);
    [familyIndex, familyId] = cellModel.familyIndex( ...
        model, lineage.groundTruth.family);
    if isempty(familyIndex)
        error('auditManagedGtClassifier:MissingGtFamily', ...
            'ROI "%s" is missing GT family "%s".', ...
            classif.roi(i).id, lineage.groundTruth.family);
    end
    relationRows = find(model.relations.family_id == familyId & ...
        model.relations.type_id == uint8(1));
    noncanonical = 0;
    for row = relationRows(:).'
        childId = model.relations.child_track_id(row);
        childRows = model.instances.family_id == familyId & ...
            model.instances.track_id == childId;
        birth = min(model.instances.frame(childRows));
        noncanonical = noncanonical + double(isempty(birth) || ...
            model.relations.event_frame(row) ~= birth);
    end

    storagePath = char(string(classif.roi(i).path));
    roiId = char(string(classif.roi(i).id));
    durableNames = {['im_' roiId '.h5'], ['im_' roiId '.mat'], ...
        ['data_' roiId '.mat'], ['objects_' roiId '.h5']};
    durableCount = sum(cellfun(@(name)isfile(fullfile(storagePath, name)), ...
        durableNames));

    items(i).roi_id = roiId;
    items(i).status = char(string(summary.status));
    items(i).relation_count = numel(relationRows);
    items(i).validation_error_count = numel(validation.errors);
    items(i).validation_issue_count = numel(validation.issues);
    items(i).noncanonical_event_count = noncanonical;
    items(i).storage_path = storagePath;
    items(i).durable_file_count = durableCount;
end

counts = countStrings(issueCodes);
statuses = countStrings(string({items.status}).');
report = struct( ...
    'schema_version', 'detecdiv_managed_gt_audit_v001', ...
    'created_utc', utcTimestamp(), ...
    'classifier_file', classifierFile, ...
    'classifier_id', char(string(classif.strid)), ...
    'roi_count', numel(items), ...
    'relation_count', sum([items.relation_count]), ...
    'validation_error_count', numel(allErrors), ...
    'validation_errors', {cellstr(allErrors)}, ...
    'validation_issue_count', numel(issueCodes), ...
    'validation_issue_counts', {counts}, ...
    'noncanonical_event_count', sum([items.noncanonical_event_count]), ...
    'status_counts', {statuses}, ...
    'review_promoted_by_audit', false, ...
    'items', {items});

if ~isempty(p.Results.ExpectedRoiCount) && ...
        report.roi_count ~= p.Results.ExpectedRoiCount
    error('auditManagedGtClassifier:UnexpectedRoiCount', ...
        'Expected %d ROI, found %d.', p.Results.ExpectedRoiCount, report.roi_count);
end
if ~isempty(p.Results.ExpectedRelationCount) && ...
        report.relation_count ~= p.Results.ExpectedRelationCount
    error('auditManagedGtClassifier:UnexpectedRelationCount', ...
        'Expected %d relations, found %d.', ...
        p.Results.ExpectedRelationCount, report.relation_count);
end
if report.validation_error_count ~= 0 || report.noncanonical_event_count ~= 0
    error('auditManagedGtClassifier:AuditFailed', ...
        'Audit found %d validation error(s) and %d noncanonical event(s).', ...
        report.validation_error_count, report.noncanonical_event_count);
end

outputFile = char(string(p.Results.OutputFile));
if ~isempty(outputFile)
    writeJsonAtomic(outputFile, report);
end
end

function counts = countStrings(values)
values = values(strlength(values) > 0);
template = struct('value', '', 'count', 0);
if isempty(values)
    counts = repmat(template, 0, 1);
    return;
end
[uniqueValues, ~, groups] = unique(values, 'stable');
counts = repmat(template, numel(uniqueValues), 1);
for i = 1:numel(uniqueValues)
    counts(i).value = char(uniqueValues(i));
    counts(i).count = sum(groups == i);
end
end

function value = utcTimestamp()
value = char(datetime('now', 'TimeZone', 'UTC', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ss.SSSXXX'));
end

function writeJsonAtomic(path, value)
folder = fileparts(path);
if ~isempty(folder) && ~isfolder(folder), mkdir(folder); end
temporary = [path '.tmp.' char(java.util.UUID.randomUUID)];
cleanup = onCleanup(@() deleteIfPresent(temporary));
fid = fopen(temporary, 'w', 'n', 'UTF-8');
if fid < 0
    error('auditManagedGtClassifier:WriteFailed', ...
        'Cannot open audit output: %s', temporary);
end
fileCleanup = onCleanup(@() fcloseIfOpen(fid));
fprintf(fid, '%s\n', jsonencode(value, 'PrettyPrint', true));
fclose(fid);
delete(fileCleanup);
movefile(temporary, path, 'f');
delete(cleanup);
end

function fcloseIfOpen(fid)
try fclose(fid); catch, end
end

function deleteIfPresent(path)
try if isfile(path), delete(path); end, catch, end
end
