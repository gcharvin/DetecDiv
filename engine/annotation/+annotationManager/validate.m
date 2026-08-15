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
report = struct('valid', isempty(errors), 'errors', errors, ...
    'warnings', warnings, 'summary', summary, 'issues', issues);
end

function issues = collectStructuredIssues(roiObj, spec, summary)
issues = struct([]);
model = [];
for i = 1:numel(spec.components)
    component = spec.components(i);
    if ~strcmp(component.kind, 'lineage') || ...
            ~strcmp(component.storage, 'cell_model_family') || ...
            ~summary.components(i).groundTruthExists
        continue;
    end
    try
        if isempty(model)
            [model, ~] = roiObj.loadCellModel('MigrateLegacy', true);
        end
        parentage = annotationManager.validateParentage(model, ...
            component.groundTruth.family, 'Frames', summary.reviewFrames);
        if isempty(parentage.issues), continue; end
        if isempty(issues)
            issues = parentage.issues;
        else
            issues = [issues; parentage.issues]; %#ok<AGROW>
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
            values = selectChannelFrames(readChannel(roiObj, channel),reviewFrames);
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
        values = roiObj.data(idx).data.(asset.valueField);
        if isempty(values), error('GT label field is empty.'); end
        reviewIdx = find(strcmp(string({entry.review.component_id}), ...
            string(component.id)), 1, 'first');
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
                validateFamilyMaskLabels(roiObj, model, ...
                    model.families.family_id(idx), expected, ...
                    model.families.name{idx},reviewFrames);
            end
        end
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

function validateFamilyMaskLabels(roiObj, model, familyId, channel, familyName,frames)
values = squeeze(readChannel(roiObj, channel));
if ismatrix(values)
    values = reshape(values, size(values,1), size(values,2), 1);
end
nFrames = size(values, 3);
rows = model.instances.family_id == familyId;
instanceFrames = double(model.instances.frame(rows));
instanceLabels = double(model.instances.mask_label(rows));
relevantRows = ismember(instanceFrames,frames);
if any(instanceFrames(relevantRows) < 1 | instanceFrames(relevantRows) > nFrames)
    error('Object family "%s" references frames outside mask provider "%s".', ...
        familyName, channel);
end

mismatched = zeros(0,1);
frames = frames(frames >= 1 & frames <= nFrames);
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
    frames = frames(frames <= size(values,4));
    values = values(:,:,:,frames);
elseif ndims(values) == 3
    frames = frames(frames <= size(values,3));
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

function values = readChannel(roiObj, channel)
h5File = fullfile(char(string(roiObj.path)), ...
    ['im_' char(string(roiObj.id)) '.h5']);
if isfile(h5File)
    info = h5info(h5File);
    for i = 1:numel(info.Datasets)
        path = ['/' info.Datasets(i).Name];
        logicalName = info.Datasets(i).Name;
        try, logicalName = h5readatt(h5File, path, 'channel_name'); catch, end
        if strcmpi(char(string(logicalName)), channel)
            values = h5read(h5File, path);
            return;
        end
    end
end
if isempty(roiObj.image), roiObj.load('Silent'); end
idx = roiObj.findChannelID(channel);
values = roiObj.image(:,:,idx,:);
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
