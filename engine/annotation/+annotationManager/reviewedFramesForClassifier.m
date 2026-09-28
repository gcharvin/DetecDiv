function [frames, hasSelectedFrames] = reviewedFramesForClassifier( ...
        classif, roiIndices, varargin)
%ANNOTATIONMANAGER.REVIEWEDFRAMESFORCLASSIFIER Per-ROI reviewed GT frames.
% Return the frames eligible for classifier training: every required
% annotation component is reviewed, and the frame is inside both the
% classifier bounds and any caller selection. Returned struct fields
% (roi<N>) can be passed directly as a Frames selector to
% normalizeTrainingFrameSelection.

p = inputParser;
p.addParameter('Frames', [], @(x) isempty(x) || isnumeric(x) || ...
    islogical(x) || ischar(x) || isstring(x) || iscell(x) || isstruct(x));
p.parse(varargin{:});
requestedFrames = p.Results.Frames;
hasSelectedFrames = false;

spec = annotationManager.specForClassifier(classif);
if nargin < 2 || isempty(roiIndices)
    roiIndices = 1:numel(classif.roi);
end

frames = struct();
for i = 1:numel(roiIndices)
    roiIndex = round(double(roiIndices(i)));
    if roiIndex < 1 || roiIndex > numel(classif.roi), continue; end
    roiObj = classif.roi(roiIndex);
    candidateFrames = trainingBounds.frames(classif, roiIndex, ...
        annotationManager.frameCount(roiObj), requestedFrames, ...
        'RoiPosition', i);
    candidateFrames = sort(candidateFrames(:).');
    [entry, ~] = annotationManager.entryForSpec(roiObj, spec);
    selected = candidateFrames;
    hasFrameReviewComponent = false;
    roiScopeAuthorized = true;
    for c = 1:numel(spec.components)
        component = spec.components(c);
        if ~component.required
            continue;
        end
        reviewIndex = find(strcmp(string({entry.review.component_id}), ...
            string(component.id)), 1, 'first');
        switch char(string(component.coverageUnit))
            case 'frame'
                hasFrameReviewComponent = true;
                if isempty(reviewIndex)
                    selected = [];
                    break;
                end
                reviewed = find(logical(entry.review(reviewIndex).frames));
                selected = intersect(selected, reviewed, 'stable');
            case 'roi'
                if isempty(reviewIndex) || ...
                        ~logical(entry.review(reviewIndex).complete)
                    selected = [];
                    roiScopeAuthorized = false;
                    break;
                end
        end
    end
    % ROI-reviewed classifiers have no per-frame review mask; a complete
    % ROI-level review authorizes all frames in the bounded selection.
    if ~hasFrameReviewComponent && roiScopeAuthorized
        selected = candidateFrames;
    end
    policy = 'contiguous';
    if isfield(spec, 'trainingFramePolicy') && ...
            ~isempty(spec.trainingFramePolicy)
        policy = lower(char(string(spec.trainingFramePolicy)));
    end
    if strcmp(policy, 'contiguous') && numel(selected) > 1 && ...
            any(diff(selected) ~= 1)
        error('annotationManager:NonContiguousReviewedFrames', ...
            ['Reviewed frames for ROI "%s" form multiple intervals, but ' ...
             'classifier "%s" requires a continuous frame range. Review ' ...
             'the intervening frames or set one continuous frame bound.'], ...
            char(string(roiObj.id)), spec.displayName);
    elseif ~any(strcmp(policy, {'contiguous','disjoint'}))
        error('annotationManager:InvalidTrainingFramePolicy', ...
            'Unknown training frame policy "%s" for classifier "%s".', ...
            policy, spec.displayName);
    end
    frames.(sprintf('roi%d', roiIndex)) = selected;
    hasSelectedFrames = hasSelectedFrames || ~isempty(selected);
end
end
