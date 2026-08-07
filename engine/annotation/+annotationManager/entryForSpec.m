function [entry, found, manifest] = entryForSpec(roiObj, spec)
%ANNOTATIONMANAGER.ENTRYFORSPEC Return normalized metadata for one bundle.

[manifest, ~] = annotationManager.readManifest(roiObj);
found = false;
entry = annotationManager.newEntry(spec, annotationManager.frameCount(roiObj));
if isempty(manifest.entries), return; end

ids = string({manifest.entries.annotation_id});
idx = find(ids == string(spec.id), 1, 'first');
if isempty(idx), return; end
found = true;
entry = normalizeEntry(manifest.entries(idx), spec, annotationManager.frameCount(roiObj));
end

function entry = normalizeEntry(value, spec, totalFrames)
entry = annotationManager.newEntry(spec, totalFrames);
names = fieldnames(entry);
for i = 1:numel(names)
    if isfield(value, names{i})
        entry.(names{i}) = value.(names{i});
    end
end

oldReview = entry.review;
entry.review = annotationManager.newEntry(spec, totalFrames).review;
if ~isstruct(oldReview), return; end
for i = 1:numel(entry.review)
    componentId = string(entry.review(i).component_id);
    idx = find(strcmp(string({oldReview.component_id}), componentId), 1, 'first');
    if isempty(idx) && componentId == "parentage" && ...
            strcmp(char(string(value.status)), 'approved')
        % The previous bundle used one ROI-level "lineage" review. Preserve
        % it only for already approved GT; draft edits never implied that
        % the complete parentage had been reviewed.
        idx = find(strcmp(string({oldReview.component_id}), "lineage"), 1, 'first');
    end
    if isempty(idx), continue; end
    entry.review(i).complete = logical(oldReview(idx).complete);
    frames = logical(oldReview(idx).frames(:)');
    if strcmp(entry.review(i).unit, 'frame')
        n = numel(entry.review(i).frames);
        entry.review(i).frames(1:min(n, numel(frames))) = frames(1:min(n, numel(frames)));
    end
end

% An approved legacy lineage bundle had complete frame-mask coverage plus a
% global lineage confirmation. Treat its new tracking dimension as reviewed
% to avoid silently invalidating already approved training data.
if strcmp(char(string(value.status)), 'approved')
    trackingIdx = find(strcmp(string({entry.review.component_id}), "tracking"), 1);
    legacyIdx = find(strcmp(string({oldReview.component_id}), "lineage"), 1);
    if ~isempty(trackingIdx) && ~isempty(legacyIdx) && oldReview(legacyIdx).complete
        entry.review(trackingIdx).frames(:) = true;
        entry.review(trackingIdx).complete = true;
    end
end
end
