function approvals = assertGroundTruthReady(classif, roiIndices, varargin)
%CELLLATENTMODEL.ASSERTGROUNDTRUTHREADY Gate managed GT used for learning.
% Legacy ROIs without an annotation lifecycle entry remain compatible. Once
% a ROI is managed by annotationManager, however, only a fully reviewed,
% explicitly validated approval whose content hash still matches is safe.

p = inputParser;
p.addParameter('ExpectedApprovals', struct([]), @isstruct);
p.addParameter('ExpectedRoiIds', {}, ...
    @(x) ischar(x) || isstring(x) || iscell(x));
p.parse(varargin{:});

roiIndices = normalizeIndices(roiIndices, numel(classif.roi));
spec = annotationManager.specForClassifier(classif);
template = struct('roi_index', 0, 'roi_id', '', 'annotation_id', '', ...
    'revision', 0, 'approved_hash', '', 'validated_at', '', ...
    'frame_bounds', []);
approvals = repmat(template, 0, 1);
problems = strings(0,1);
expectedValues = p.Results.ExpectedApprovals;
expectedIds = textList(p.Results.ExpectedRoiIds);
if ~isempty(expectedValues)
    approvalIds = {};
    try approvalIds = textList({expectedValues.roi_id}); catch, end
    expectedIds = unique([expectedIds approvalIds], 'stable');
end
if ~isempty(expectedIds)
    currentIds = roiIds(classif);
    for i = 1:numel(expectedIds)
        expectedId = expectedIds{i};
        match = find(currentIds == string(expectedId), 1, 'first');
        if isempty(match)
            problems(end+1,1) = sprintf([ ...
                'ROI %s: the ROI recorded by the formatted dataset is no ' ...
                'longer attached to this classifier.'], expectedId); %#ok<AGROW>
        else
            roiIndices = unique([roiIndices match], 'stable');
        end
    end
end

for i = 1:numel(roiIndices)
    roiIndex = roiIndices(i);
    roiObj = classif.roi(roiIndex);
    bounds = trainingBounds.resolve(classif, roiIndex);
    effectiveBounds = effectiveFrameBounds(bounds, roiObj);
    reviewFrames = [];
    if ~isempty(bounds), reviewFrames = bounds(1):bounds(2); end
    try
        summary = annotationManager.inspect(roiObj, spec, ...
            'CheckAssets', true, 'VerifyHash', true, ...
            'ReviewFrames', reviewFrames);
    catch ME
        problems(end+1,1) = sprintf('ROI %s: GT inspection failed: %s', ...
            char(string(roiObj.id)), char(string(ME.message))); %#ok<AGROW>
        continue;
    end

    expected = expectedApproval(p.Results.ExpectedApprovals, ...
        roiIndex, roiObj.id);
    % No lifecycle entry means legacy data, not an approval. Preserve that
    % historical import path unless the formatted dataset explicitly froze
    % a managed approval for this ROI, in which case its disappearance is a
    % provenance failure.
    if summary.legacy
        if ~isempty(expected)
            problems(end+1,1) = sprintf([ ...
                'ROI %s: the annotation approval recorded by the formatted ' ...
                'dataset is no longer present.'], ...
                char(string(roiObj.id))); %#ok<AGROW>
        end
        continue;
    end

    reason = '';
    if summary.staleApproval
        reason = ['approved GT content no longer matches its approval hash; ' ...
            'open this ROI and run Validate GT again'];
        if ~isempty(summary.hashVerificationError)
            reason = sprintf('%s (%s)', reason, ...
                char(string(summary.hashVerificationError)));
        end
    elseif strcmpi(summary.status, 'missing')
        reason = 'GT is not initialized';
    elseif ~strcmpi(summary.status, 'approved')
        reason = ['GT lifecycle is Draft; review it and run Validate GT ' ...
            'explicitly'];
    elseif ~strcmpi(summary.validationStatus, 'valid')
        reason = 'the current GT revision has no valid approval';
    elseif summary.coverage.fraction < 1
        reason = 'the selected training frame range is not fully reviewed';
    end

    if isempty(reason) && ~isempty(expected)
        expectedHash = textField(expected, 'approved_hash');
        currentHash = char(string(summary.entry.approved_hash));
        if isempty(expectedHash) || ~strcmpi(expectedHash, currentHash)
            reason = ['GT approval differs from the snapshot recorded when ' ...
                'the dataset was formatted; format the dataset again'];
        elseif isfield(expected, 'frame_bounds') && ...
                ~isequal(effectiveFrameBounds( ...
                    expected.frame_bounds, roiObj), effectiveBounds)
            reason = ['training frame bounds differ from the snapshot ' ...
                'recorded when the dataset was formatted; restore those ' ...
                'bounds or format the dataset again'];
        end
    end
    if ~isempty(reason)
        problems(end+1,1) = sprintf('ROI %s: %s.', ...
            char(string(roiObj.id)), reason); %#ok<AGROW>
        continue;
    end

    row = template;
    row.roi_index = roiIndex;
    row.roi_id = char(string(roiObj.id));
    row.annotation_id = char(string(spec.id));
    row.revision = double(summary.entry.revision);
    row.approved_hash = char(string(summary.entry.approved_hash));
    row.validated_at = char(string(summary.entry.validated_at));
    % Store an explicit effective range so "all" and 1:N remain equivalent
    % while any scientifically meaningful narrowing/extension is detected.
    row.frame_bounds = effectiveBounds;
    approvals(end+1,1) = row; %#ok<AGROW>
end

if ~isempty(problems)
    error('cellLatentModel:GroundTruthNotReady', ...
        ['Selected ROI ground truth is not safe for model training:' ...
         newline '%s' newline ...
         'No dataset was replaced and no training was started.'], ...
        strjoin(problems, newline));
end
end

function expected = expectedApproval(values, roiIndex, roiId)
expected = struct([]);
if isempty(values), return; end
for i = 1:numel(values)
    indexMatch = false;
    idMatch = false;
    if isfield(values, 'roi_index') && ~isempty(values(i).roi_index)
        indexMatch = double(values(i).roi_index) == double(roiIndex);
    end
    expectedId = '';
    if isfield(values, 'roi_id')
        expectedId = char(string(values(i).roi_id));
        idMatch = strcmp(expectedId, char(string(roiId)));
    end
    if idMatch || (isempty(expectedId) && indexMatch)
        expected = values(i);
        return;
    end
end
end

function values = roiIds(classif)
values = strings(1, numel(classif.roi));
for i = 1:numel(classif.roi)
    values(i) = string(classif.roi(i).id);
end
end

function values = textList(raw)
if isempty(raw)
    values = {};
elseif ischar(raw) || isstring(raw)
    values = cellstr(string(raw));
else
    values = cellfun(@(x)char(string(x)), raw, 'UniformOutput', false);
end
values = values(~cellfun(@isempty, values));
end

function value = textField(row, name)
value = '';
if isfield(row, name), value = char(string(row.(name))); end
end

function value = effectiveFrameBounds(raw, roiObj)
value = [];
try value = round(double(raw(:).')); catch, end
value = value(isfinite(value));
if numel(value) >= 2
    value = value(1:2);
    return;
end
total = annotationManager.frameCount(roiObj);
if isfinite(total) && total >= 1
    value = [1 round(double(total))];
else
    value = [];
end
end

function values = normalizeIndices(raw, n)
if isempty(raw), values = []; return; end
values = unique(round(double(raw(:).')), 'stable');
values = values(isfinite(values) & values >= 1 & values <= n);
end
