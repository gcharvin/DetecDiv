function frames = reviewedFramesForClassifier(classif, roiIndices)
%ANNOTATIONMANAGER.REVIEWEDFRAMESFORCLASSIFIER Per-ROI reviewed GT frames.
% Returned struct fields (roi<N>) can be passed directly as a Frames
% selector to normalizeTrainingFrameSelection.  This is intentionally only
% available to contracts that explicitly allow partial approval.

spec = annotationManager.specForClassifier(classif);
if ~spec.allowPartialApproval
    frames = [];
    return;
end
if nargin < 2 || isempty(roiIndices)
    roiIndices = 1:numel(classif.roi);
end

frames = struct();
for i = 1:numel(roiIndices)
    roiIndex = round(double(roiIndices(i)));
    if roiIndex < 1 || roiIndex > numel(classif.roi), continue; end
    roiObj = classif.roi(roiIndex);
    summary = annotationManager.inspect(roiObj, spec);
    selected = [];
    for c = 1:numel(spec.components)
        component = spec.components(c);
        if ~component.required || ~strcmp(component.coverageUnit, 'frame')
            continue;
        end
        reviewIndex = find(strcmp(string({summary.entry.review.component_id}), ...
            string(component.id)), 1, 'first');
        if isempty(reviewIndex)
            selected = [];
            break;
        end
        reviewed = find(logical(summary.entry.review(reviewIndex).frames));
        if isempty(selected)
            selected = reviewed;
        else
            selected = intersect(selected, reviewed, 'stable');
        end
    end
    frames.(sprintf('roi%d', roiIndex)) = selected;
end
end
