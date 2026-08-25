function issues = auditStableTracks(roiObj, model, family, varargin)
%ANNOTATIONMANAGER.AUDITSTABLETRACKS Flag conservative identity anomalies.
% Warnings are navigable but do not invalidate GT or training eligibility.
% Centroid motion is never a hard validity criterion. Consecutive observations
% from one stable track are flagged as possible ID reuse when either:
%   - area_after / area_before <= 0.42 and area_before >= 64 pixels; or
%   - centroid displacement is >= 5 px and >= 1.75 mean equivalent radii.
% These deliberately conservative thresholds catch mature-bud-to-new-bud
% reuse while avoiding ordinary one-frame mask fluctuations near 45-55%.

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

for i = 2:numel(rows)
    if tracks(i) ~= tracks(i-1) || frames(i) ~= frames(i-1) + 1
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
        'repairable', false);
end
end

function metrics = instanceMetrics(values, model, rows)
template = struct('area', 0, 'centroid', [NaN NaN]);
metrics = repmat(template, numel(rows), 1);
nFrames = size(values, 3);
for i = 1:numel(rows)
    row = rows(i);
    frame = double(model.instances.frame(row));
    if frame < 1 || frame > nFrames, continue; end
    label = double(model.instances.mask_label(row));
    [y, x] = find(double(values(:,:,frame)) == label);
    metrics(i).area = numel(x);
    if ~isempty(x)
        metrics(i).centroid = [mean(x) mean(y)];
    end
end
end
