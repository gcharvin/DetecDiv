function [label, color] = score_annotationFrameReviewStatus(app, roiObj, frame)
%SCORE_ANNOTATIONFRAMEREVIEWSTATUS Human-visible managed-GT frame status.

label = '[not reviewed]';
color = [0.85 0.35 0.10];
try
    session = app.AnnotationSession;
    if isempty(session) || ~isvalid(session) || ...
            ~strcmp(char(string(session.Roi.id)), char(string(roiObj.id)))
        label = '';
        color = [1 1 1];
        return;
    end
    summary = session.summary();
    required = session.Spec.components([session.Spec.components.required]);
    frameComponents = required(strcmp({required.coverageUnit}, 'frame'));
    if isempty(frameComponents)
        label = '[no frame review required]';
        color = [0.35 0.35 0.35];
        return;
    end
    reviewed = true;
    for i = 1:numel(frameComponents)
        reviewIndex = find(strcmp(string({summary.entry.review.component_id}), ...
            string(frameComponents(i).id)), 1, 'first');
        reviewed = reviewed && ~isempty(reviewIndex) && frame >= 1 && ...
            frame <= numel(summary.entry.review(reviewIndex).frames) && ...
            logical(summary.entry.review(reviewIndex).frames(frame));
    end
    if reviewed
        label = '[reviewed]';
        color = [0.10 0.55 0.20];
    end
catch
    % Rendering must remain available if annotation metadata is incomplete.
end

end
