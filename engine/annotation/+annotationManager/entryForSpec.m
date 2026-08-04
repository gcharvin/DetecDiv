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
    idx = find(strcmp(string({oldReview.component_id}), ...
        string(entry.review(i).component_id)), 1, 'first');
    if isempty(idx), continue; end
    entry.review(i).complete = logical(oldReview(idx).complete);
    frames = logical(oldReview(idx).frames(:)');
    if strcmp(entry.review(i).unit, 'frame')
        n = numel(entry.review(i).frames);
        entry.review(i).frames(1:min(n, numel(frames))) = frames(1:min(n, numel(frames)));
    end
end
end
