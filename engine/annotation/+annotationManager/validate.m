function report = validate(roiObj, spec, varargin)
%ANNOTATIONMANAGER.VALIDATE Validate GT assets and review coverage.

p = inputParser;
p.addParameter('RequireReviewed', true, @(x) islogical(x) && isscalar(x));
p.addParameter('AllowPartial', spec.allowPartialApproval, ...
    @(x) islogical(x) && isscalar(x));
p.addParameter('ReviewFrames', [], @isnumeric);
p.parse(varargin{:});

summary = annotationManager.inspect(roiObj, spec, ...
    'ReviewFrames',p.Results.ReviewFrames);
errors = strings(0,1);
warnings = strings(0,1);
for i = 1:numel(summary.components)
    component = summary.components(i);
    if component.required && ~component.groundTruthExists
        errors(end+1) = sprintf('Missing GT component "%s" (%s).', ...
            component.id, component.kind); %#ok<AGROW>
    end
end

if p.Results.RequireReviewed
    for i = 1:numel(summary.coverage.components)
        coverage = summary.coverage.components(i);
        component = spec.components(i);
        if ~component.required, continue; end
        if p.Results.AllowPartial
            if coverage.reviewed == 0
                errors(end+1) = sprintf('Component "%s" has no reviewed unit.', ...
                    component.id); %#ok<AGROW>
            elseif coverage.reviewed < coverage.total
                warnings(end+1) = sprintf('Component "%s" is partially reviewed (%d/%d).', ...
                    component.id, coverage.reviewed, coverage.total); %#ok<AGROW>
            end
        elseif coverage.reviewed < coverage.total
            errors(end+1) = sprintf('Component "%s" is not fully reviewed (%d/%d).', ...
                component.id, coverage.reviewed, coverage.total); %#ok<AGROW>
        end
    end
end

for i = 1:numel(spec.components)
    component = spec.components(i);
    if ~summary.components(i).groundTruthExists, continue; end
    try
        validateComponent(roiObj, component, summary.entry,summary.reviewFrames);
    catch ME
        errors(end+1) = sprintf('%s: %s', component.id, ME.message); %#ok<AGROW>
    end
end

issues = collectStructuredIssues(roiObj, spec, summary);
if ~isempty(issues)
    warningMask = strcmpi(string({issues.severity}), 'warning');
    if any(warningMask)
        warnings = unique([warnings(:); ...
            string({issues(warningMask).message}).'], 'stable');
    end
end
report = struct('valid', isempty(errors), 'errors', errors, ...
    'warnings', warnings, 'summary', summary, 'issues', issues);
end

function issues = collectStructuredIssues(roiObj, spec, summary)
issues = annotationManager.emptyValidationIssues();
model = [];
for i = 1:numel(spec.components)
    component = spec.components(i);
    if ~strcmp(component.storage, 'cell_model_family') || ...
            ~summary.components(i).groundTruthExists
        continue;
    end
    try
        if isempty(model)
            [model, ~] = roiObj.loadCellModel('MigrateLegacy', true);
        end
        componentIssues = annotationManager.emptyValidationIssues();
        if strcmp(component.kind, 'lineage')
            parentage = annotationManager.validateParentage(model, ...
                component.groundTruth.family, 'Frames', summary.reviewFrames);
            componentIssues = parentage.issues;
        elseif strcmp(component.kind, 'tracking')
            componentIssues = annotationManager.auditStableTracks( ...
                roiObj, model, component.groundTruth.family, ...
                'Frames', summary.reviewFrames);
        end
        if ~isempty(componentIssues)
            issues = [issues; componentIssues]; %#ok<AGROW>
        end
    catch
        % The textual component validation remains the fallback for model
        % failures that cannot be represented as a navigable issue.
    end
end
end

function validateComponent(roiObj, component, entry,reviewFrames)
switch char(string(component.storage))
    case 'channel'
        [channel, exists] = annotationManager.resolveChannel(roiObj, component.groundTruth);
        if ~exists, return; end
        if any(strcmp(component.kind, {'semantic_mask','instance_mask', ...
                'tracked_instances'}))
            values = selectChannelFrames( ...
                annotationManager.readChannel(roiObj, channel),reviewFrames);
            if ~isnumeric(values) && ~islogical(values)
                error('Mask data must be numeric.');
            end
            if any(~isfinite(double(values(:)))) || any(double(values(:)) < 0)
                error('Mask labels must be finite and non-negative.');
            end
            if any(strcmp(component.kind, {'instance_mask','tracked_instances'})) && ...
                    any(double(values(:)) ~= round(double(values(:))))
                error('Instance labels must be integers.');
            end
        end
    case 'dataseries'
        ensureData(roiObj);
        asset = component.groundTruth;
        idx = find(arrayfun(@(x) strcmp(char(string(x.groupid)), ...
            char(string(asset.groupId))), roiObj.data), 1);
        tableValue = roiObj.data(idx).data;
        values = tableValue.(asset.valueField);
        if isempty(values), error('GT label field is empty.'); end
        reviewIdx = find(strcmp(string({entry.review.component_id}), ...
            string(component.id)), 1, 'first');
        if any(strcmp(component.kind,{'object_classification','object_regression'}))
            validateObjectSignalTable(roiObj,component,tableValue, ...
                reviewFrames,entry,reviewIdx);
            return;
        end
        if ~isempty(reviewIdx) && strcmp(entry.review(reviewIdx).unit, 'frame')
            reviewed = find(entry.review(reviewIdx).frames);
            reviewed = intersect(reviewed,reviewFrames,'stable');
            reviewed = reviewed(reviewed <= numel(values));
            if any(undefinedValues(values(reviewed)))
                error('Reviewed frames still contain undefined labels.');
            end
        elseif ~isempty(reviewIdx) && entry.review(reviewIdx).complete && ...
                all(undefinedValues(values))
            error('Reviewed annotation still contains no defined label.');
        end
    case 'cell_model_family'
        [model, ~] = roiObj.loadCellModel('MigrateLegacy', true);
        [idx, ~] = cellModel.familyIndex(model, component.groundTruth.family);
        if isempty(idx), error('Ground-truth object family is missing.'); end
        expected = char(string(component.groundTruth.maskProvider));
        if strcmp(component.kind, 'lineage')
            annotationManager.validateParentage(model, ...
                model.families.family_id(idx), 'Frames',reviewFrames, ...
                'Throw', true);
        else
            validateTrackingFamily(model,model.families.family_id(idx), ...
                reviewFrames);
            if ~isempty(expected) && ~strcmp( ...
                    char(string(model.families.mask_provider{idx})), expected)
                error('Object family uses mask provider "%s" instead of "%s".', ...
                    model.families.mask_provider{idx}, expected);
            end
            if ~isempty(expected)
                validateUniqueTrainingFamily(model, idx, expected);
                validateFamilyMaskLabels(roiObj, model, ...
                    model.families.family_id(idx), expected, ...
                    model.families.name{idx},reviewFrames);
            end
        end
end
end

function validateObjectSignalTable(roiObj,component,tbl,reviewFrames,entry,reviewIdx)
required={'ObjectId','FamilyId','TrackId','Frame','MaskLabel', ...
    component.groundTruth.valueField};
if ~all(ismember(required,tbl.Properties.VariableNames))
    error('Object signal GT is missing identity columns.');
end
objectIds=uint64(tbl.ObjectId(:));
if numel(unique(objectIds))~=numel(objectIds)||any(objectIds==0)
    error('Object signal GT must contain unique positive ObjectId values.');
end
[model,~]=roiObj.loadCellModel('MigrateLegacy',true);
[familyIndex,familyId]=cellModel.familyIndex(model,component.groundTruth.family);
if isempty(familyIndex), error('Object signal target family is missing.'); end
modelRows=find(model.instances.family_id==familyId);
expectedObjectIds=model.instances.object_id(modelRows);
if numel(objectIds)~=numel(expectedObjectIds)|| ...
        any(~ismember(expectedObjectIds,objectIds))
    error('Object signal GT must contain every object in its target family exactly once.');
end
[found,rows]=ismember(objectIds,model.instances.object_id(modelRows));
if any(~found), error('Object signal GT references objects outside its target family.'); end
resolved=modelRows(rows);
if any(uint32(tbl.FamilyId)~=familyId)|| ...
        any(uint64(tbl.TrackId)~=model.instances.track_id(resolved))|| ...
        any(uint32(tbl.Frame)~=model.instances.frame(resolved))|| ...
        any(uint32(tbl.MaskLabel)~=model.instances.mask_label(resolved))
    error('Object signal identity columns disagree with the cell model.');
end
expectedProvider=char(string(component.groundTruth.maskProvider));
actualProvider=char(string(model.families.mask_provider{familyIndex}));
if ~isempty(expectedProvider)&&~strcmp(expectedProvider,actualProvider)
    error('Object signal selection mask "%s" disagrees with family provider "%s".', ...
        expectedProvider,actualProvider);
end
reviewedFrames=[];
if ~isempty(reviewIdx)
    reviewed=find(entry.review(reviewIdx).frames);
    reviewedFrames=intersect(reviewed,reviewFrames,'stable');
end
rowsToCheck=ismember(double(tbl.Frame),reviewedFrames);
values=tbl.(component.groundTruth.valueField);
if strcmp(component.kind,'object_regression')
    undefined=~isfinite(double(values));
else
    undefined=undefinedValues(values);
end
if any(undefined(rowsToCheck))
    error('At least one object on a reviewed frame has no signal target.');
end
end

function validateTrackingFamily(model,familyId,frames)
rows = model.instances.family_id == familyId & ...
    ismember(double(model.instances.frame),frames);
tracks = model.instances.track_id(rows);
frameValues = model.instances.frame(rows);
labels = model.instances.mask_label(rows);
if any(tracks == 0)
    error('A reviewed object has no track identity.');
end
if any(tracks > uint64(intmax('uint32')))
    error(['A reviewed track identity exceeds uint32 and cannot be ' ...
        'materialized by the training formatter.']);
end
if any(labels == 0)
    error('A reviewed object uses the reserved background mask label.');
end
trackKeys = [double(frameValues(:)) double(tracks(:))];
if size(unique(trackKeys,'rows'),1) ~= size(trackKeys,1)
    error('A reviewed frame contains several objects assigned to the same track.');
end
labelKeys = [double(frameValues(:)) double(labels(:))];
if size(unique(labelKeys,'rows'),1) ~= size(labelKeys,1)
    error('A reviewed frame contains duplicate mask-label references.');
end
end

function validateUniqueTrainingFamily(model, targetIndex, provider)
matches = find(strcmpi(string(model.families.mask_provider), ...
    string(provider)));
if numel(matches) <= 1, return; end
reviewed = matches(strcmpi( ...
    string(model.families.lineage_source(matches)), 'ground_truth'));
if numel(reviewed) == 1 && reviewed == targetIndex, return; end
names = strjoin(string(model.families.name(matches)), ', ');
error(['Mask provider "%s" resolves to several object families (%s). ' ...
    'Training requires one unambiguous reviewed family.'], ...
    provider, char(names));
end

function validateFamilyMaskLabels(roiObj, model, familyId, channel, familyName,frames)
values = annotationManager.readChannel(roiObj, channel);
dims = size(values);
dims(end+1:4) = 1;
if dims(3) ~= 1
    error('Mask provider "%s" must contain exactly one label plane.', channel);
end
values = reshape(values, dims(1), dims(2), dims(3), dims(4));
values = reshape(values(:,:,1,:), dims(1), dims(2), dims(4));
nFrames = dims(4);
rows = model.instances.family_id == familyId;
instanceFrames = double(model.instances.frame(rows));
instanceLabels = double(model.instances.mask_label(rows));
relevantRows = ismember(instanceFrames,frames);
if any(instanceFrames(relevantRows) < 1 | instanceFrames(relevantRows) > nFrames)
    error('Object family "%s" references frames outside mask provider "%s".', ...
        familyName, channel);
end

mismatched = zeros(0,1);
frames = frames(frames >= 1);
if any(frames > nFrames)
    error(['Mask provider "%s" contains %d frame(s), but validation ' ...
        'requires frame %d. Reload the complete ROI before validating.'], ...
        channel, nFrames, max(frames));
end
for frame = frames
    actual = unique(double(values(:,:,frame)));
    actual = actual(actual > 0);
    expected = unique(instanceLabels(instanceFrames == frame));
    expected = expected(expected > 0);
    if ~isequal(actual(:), expected(:))
        mismatched(end+1,1) = frame; %#ok<AGROW>
    end
end
if ~isempty(mismatched)
    error(['Mask provider "%s" does not match object family "%s" on ' ...
        '%d/%d frames (first mismatch: frame %d). Recreate the GT from ' ...
        'the intended prediction before review.'], ...
        channel, familyName, numel(mismatched), numel(frames), mismatched(1));
end
end

function values = selectChannelFrames(values,frames)
if isempty(frames), return; end
if ndims(values) >= 4
    if any(frames > size(values,4))
        error('The loaded GT channel does not cover every reviewed frame.');
    end
    values = values(:,:,:,frames);
elseif ndims(values) == 3
    if any(frames > size(values,3))
        error('The loaded GT channel does not cover every reviewed frame.');
    end
    values = values(:,:,frames);
end
end

function tf = undefinedValues(values)
if isempty(values), tf = false(size(values)); return; end
if iscategorical(values)
    tf = isundefined(values) | lower(string(values)) == "undefined";
elseif isstring(values) || iscellstr(values) || ischar(values)
    text = lower(strtrim(string(values)));
    tf = ismissing(text) | text == "" | text == "undefined";
elseif isnumeric(values)
    tf = ~isfinite(double(values)) | double(values) <= 0;
else
    tf = false(size(values));
end
tf = tf(:);
end

function ensureData(roiObj)
try
    if isempty(roiObj.data) || (numel(roiObj.data) == 1 && ...
            isempty(char(string(roiObj.data(1).groupid))))
        roiObj.load('Data', 'Silent');
    end
catch
end
end
