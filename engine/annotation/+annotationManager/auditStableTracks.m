function issues = auditStableTracks(roiObj, model, family, varargin)
%ANNOTATIONMANAGER.AUDITSTABLETRACKS Flag conservative identity anomalies.
% Warnings are navigable but do not invalidate GT or training eligibility.
% Centroid motion is never a hard validity criterion. Consecutive observations
% from one stable track are flagged as possible ID reuse when either:
%   - area_after / area_before <= 0.42 and area_before >= 64 pixels; or
%   - centroid displacement is >= 5 px and >= 1.75 mean equivalent radii.
% These deliberately conservative thresholds catch mature-bud-to-new-bud
% reuse while avoiding ordinary one-frame mask fluctuations near 45-55%.
% Strong, repeated contact with the actual image boundary is also emitted as
% a *suggestion* to censor segmentation. It is never applied automatically,
% and contact with an internal cavity wall is not an image-boundary event.

p = inputParser;
p.addParameter('Frames', [], @isnumeric);
p.addParameter('MaximumAreaRatio', 0.42, ...
    @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x > 0 && x < 1);
p.addParameter('MinimumAreaBefore', 64, ...
    @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x >= 1);
p.addParameter('MinimumCentroidJumpPx', 5, ...
    @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x >= 0);
p.addParameter('MinimumNormalizedCentroidJump', 1.75, ...
    @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x > 0);
p.addParameter('MinimumBoundaryPixels', 5, ...
    @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x >= 1);
p.addParameter('MinimumBoundaryFraction', 0.22, ...
    @(x) isnumeric(x) && isscalar(x) && isfinite(x) && x > 0 && x <= 1);
p.parse(varargin{:});

issues = annotationManager.emptyValidationIssues();
[familyIndex, familyId] = cellModel.familyIndex(model, family);
if isempty(familyIndex), return; end
provider = char(string(model.families.mask_provider{familyIndex}));
if isempty(provider), return; end

values = annotationManager.readChannel(roiObj, provider);
dims = size(values);
dims(end+1:4) = 1;
if dims(3) ~= 1, return; end
values = reshape(values, dims(1), dims(2), dims(3), dims(4));
values = reshape(values(:,:,1,:), dims(1), dims(2), dims(4));

rows = find(model.instances.family_id == familyId & ...
    model.instances.track_id > 0 & model.instances.mask_label > 0);
if isempty(rows), return; end
frames = double(model.instances.frame(rows));
if ~isempty(p.Results.Frames)
    selectedFrames = unique(round(double(p.Results.Frames(:))));
    rows = rows(ismember(frames, selectedFrames));
    frames = double(model.instances.frame(rows));
end
if isempty(rows), return; end

tracks = double(model.instances.track_id(rows));
[~, order] = sortrows([tracks(:) frames(:)], [1 2]);
rows = rows(order);
tracks = tracks(order);
frames = frames(order);
metrics = instanceMetrics(values, model, rows);

% Group consecutive strongly clipped observations so the reviewer handles
% an interval once, not one finding per cell and frame.
issues = [issues; boundarySuggestions(model, familyId, tracks, ...
    frames, metrics, p.Results.MinimumBoundaryPixels, ...
    p.Results.MinimumBoundaryFraction)];

for i = 2:numel(rows)
    if tracks(i) ~= tracks(i-1) || frames(i) ~= frames(i-1) + 1
        continue;
    end
    if explicitlyCensored(model, familyId, uint64(tracks(i)), ...
            [frames(i-1) frames(i)], cellModel.censorScope('tracking'))
        continue;
    end
    before = metrics(i-1);
    after = metrics(i);
    if before.area < 1 || after.area < 1 || ...
            any(~isfinite([before.centroid after.centroid]))
        continue;
    end

    areaRatio = after.area / before.area;
    displacement = hypot(after.centroid(1) - before.centroid(1), ...
        after.centroid(2) - before.centroid(2));
    meanRadius = mean([sqrt(before.area/pi), sqrt(after.area/pi)]);
    normalizedJump = displacement / max(meanRadius, eps);
    areaDrop = before.area >= p.Results.MinimumAreaBefore && ...
        areaRatio <= p.Results.MaximumAreaRatio;
    centroidJump = displacement >= p.Results.MinimumCentroidJumpPx && ...
        normalizedJump >= p.Results.MinimumNormalizedCentroidJump;
    if ~areaDrop && ~centroidJump, continue; end

    if areaDrop && centroidJump
        code = 'possible_id_reuse_area_drop_and_centroid_jump';
        summary = 'Possible ID reuse: area drop and jump';
        thresholdName = 'area_ratio_and_normalized_centroid_jump';
        thresholdValue = p.Results.MaximumAreaRatio;
    elseif areaDrop
        code = 'possible_id_reuse_area_drop';
        summary = 'Possible ID reuse: strong area drop';
        thresholdName = 'maximum_area_ratio';
        thresholdValue = p.Results.MaximumAreaRatio;
    else
        code = 'possible_id_reuse_centroid_jump';
        summary = 'Possible ID reuse: large centroid jump';
        thresholdName = 'minimum_normalized_centroid_jump';
        thresholdValue = p.Results.MinimumNormalizedCentroidJump;
    end
    message = sprintf([ ...
        'Advisory only (does not block validation or training): possible ' ...
        'ID reuse for stable Track %u between frames %u and %u: ' ...
        'area %d -> %d (ratio %.3f), centroid displacement %.2f px ' ...
        '(%.2f equivalent radii). Inspect both frames; create a new track ' ...
        'if a new bud replaced the previous object.'], ...
        uint64(tracks(i)), uint32(frames(i-1)), uint32(frames(i)), ...
        round(before.area), round(after.area), areaRatio, displacement, ...
        normalizedJump);
    issues(end+1,1) = annotationManager.newValidationIssue( ... %#ok<AGROW>
        'code', code, ...
        'severity', 'warning', ...
        'component', 'Tracking', ...
        'summary', summary, ...
        'message', message, ...
        'family_id', familyId, ...
        'event_frame', uint32(frames(i)), ...
        'focus_track_id', uint64(tracks(i)), ...
        'focus_frame', uint32(frames(i)), ...
        'from_frame', uint32(frames(i-1)), ...
        'to_frame', uint32(frames(i)), ...
        'area_before', before.area, ...
        'area_after', after.area, ...
        'area_ratio', areaRatio, ...
        'centroid_displacement_px', displacement, ...
        'normalized_centroid_jump', normalizedJump, ...
        'threshold_name', thresholdName, ...
        'threshold_value', thresholdValue, ...
        'suggested_censor', true, ...
        'suggested_scope_flags', cellModel.censorScope('tracking'), ...
        'suggested_reason', 'ambiguous_identity', ...
        'suggested_frame_start', uint32(frames(i)), ...
        'suggested_frame_end', uint32(frames(i)), ...
        'suggestion_confidence', identityConfidence(areaDrop, centroidJump), ...
        'repairable', false);
end
end

function issues = boundarySuggestions(model, familyId, tracks, frames, ...
        metrics, minimumPixels, minimumFraction)
issues = annotationManager.emptyValidationIssues();
candidate = [metrics.boundary_pixels].' >= minimumPixels & ...
    [metrics.boundary_fraction].' >= minimumFraction;
if ~any(candidate), return; end

candidateRows = find(candidate);
startIndex = 1;
while startIndex <= numel(candidateRows)
    lastIndex = startIndex;
    while lastIndex < numel(candidateRows)
        left = candidateRows(lastIndex);
        right = candidateRows(lastIndex + 1);
        if tracks(right) ~= tracks(left) || frames(right) ~= frames(left) + 1
            break;
        end
        lastIndex = lastIndex + 1;
    end
    members = candidateRows(startIndex:lastIndex);
    trackId = uint64(tracks(members(1)));
    frameStart = frames(members(1));
    frameEnd = frames(members(end));
    if explicitlyCensored(model, familyId, trackId, ...
            frameStart:frameEnd, cellModel.censorScope('segmentation'))
        startIndex = lastIndex + 1;
        continue;
    end
    peakFraction = max([metrics(members).boundary_fraction]);
    peakPixels = max([metrics(members).boundary_pixels]);
    % A single borderline touch is intentionally ignored. A single frame is
    % proposed only when the clipping signature is very strong.
    if numel(members) == 1 && peakFraction < max(0.34, minimumFraction)
        startIndex = lastIndex + 1;
        continue;
    end
    message = sprintf([ ...
        'Censor suggestion only: Track %u has a mask strongly clipped by ' ...
        'the actual ROI image boundary from frame %u to %u (up to %d edge ' ...
        'pixels; boundary fraction %.2f). Inspect the cell. Accepting the ' ...
        'suggestion excludes segmentation only; tracking and lineage remain ' ...
        'usable. Mere contact with a cavity wall is not detected here.'], ...
        trackId, uint32(frameStart), uint32(frameEnd), round(peakPixels), ...
        peakFraction);
    issues(end+1,1) = annotationManager.newValidationIssue( ... %#ok<AGROW>
        'code', 'possible_roi_boundary_truncation', ...
        'severity', 'warning', ...
        'component', 'Censor suggestion', ...
        'summary', 'Possible mask truncation at ROI image boundary', ...
        'message', message, ...
        'family_id', familyId, ...
        'focus_track_id', trackId, ...
        'focus_frame', uint32(frameStart), ...
        'from_frame', uint32(frameStart), ...
        'to_frame', uint32(frameEnd), ...
        'threshold_name', 'boundary_fraction', ...
        'threshold_value', minimumFraction, ...
        'suggested_censor', true, ...
        'suggested_scope_flags', cellModel.censorScope('segmentation'), ...
        'suggested_reason', 'truncated_at_roi_boundary', ...
        'suggested_frame_start', uint32(frameStart), ...
        'suggested_frame_end', uint32(frameEnd), ...
        'suggestion_confidence', min(0.99, 0.55 + peakFraction), ...
        'repairable', false);
    startIndex = lastIndex + 1;
end
end

function value = identityConfidence(areaDrop, centroidJump)
if areaDrop && centroidJump, value = 0.95;
else, value = 0.80;
end
end

function tf = explicitlyCensored(model, familyId, trackId, frames, scopeFlag)
rows = model.censoring.family_id == familyId & ...
    model.censoring.track_id == trackId & ...
    bitand(model.censoring.scope_flags, scopeFlag) ~= 0;
tf = false;
for row = find(rows(:)).'
    if any(frames >= double(model.censoring.frame_start(row)) & ...
            frames <= double(model.censoring.frame_end(row)))
        tf = true;
        return;
    end
end
end

function metrics = instanceMetrics(values, model, rows)
template = struct('area', 0, 'centroid', [NaN NaN], ...
    'boundary_pixels', 0, 'boundary_fraction', 0);
metrics = repmat(template, numel(rows), 1);
nFrames = size(values, 3);
height = size(values, 1);
width = size(values, 2);
rowFrames = double(model.instances.frame(rows));
rowLabels = double(model.instances.mask_label(rows));
for frame = unique(rowFrames(:)).'
    if frame < 1 || frame > nFrames, continue; end
    positions = find(rowFrames == frame);
    labelImage = double(values(:,:,frame));
    pixelIndices = find(labelImage > 0);
    if isempty(pixelIndices), continue; end
    [y, x] = ind2sub([height width], pixelIndices);
    pixelLabels = labelImage(pixelIndices);
    [presentLabels, ~, groups] = unique(pixelLabels);
    areas = accumarray(groups, 1);
    sumsX = accumarray(groups, double(x));
    sumsY = accumarray(groups, double(y));

    % Count each physical image-edge pixel once; corners are excluded from
    % the vertical segments because they already occur in top/bottom rows.
    edgeLabels = [labelImage(1,:).'; labelImage(height,:).'];
    if height > 2
        edgeLabels = [edgeLabels; labelImage(2:height-1,1); ...
            labelImage(2:height-1,width)]; %#ok<AGROW>
    end
    edgeLabels = edgeLabels(edgeLabels > 0);
    [edgePresent, edgeGroups] = ismember(edgeLabels, presentLabels);
    boundaryCounts = accumarray(edgeGroups(edgePresent), 1, ...
        [numel(presentLabels) 1]);

    [found, labelGroups] = ismember(rowLabels(positions), presentLabels);
    for local = find(found(:)).'
        metricIndex = positions(local);
        group = labelGroups(local);
        area = areas(group);
        metrics(metricIndex).area = area;
        metrics(metricIndex).centroid = ...
            [sumsX(group)/area sumsY(group)/area];
        metrics(metricIndex).boundary_pixels = boundaryCounts(group);
        equivalentCircumference = 2 * pi * sqrt(area / pi);
        metrics(metricIndex).boundary_fraction = boundaryCounts(group) / ...
            max(equivalentCircumference, 1);
    end
end
end
