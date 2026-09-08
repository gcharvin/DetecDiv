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
    if string(roiObj.id) ~= app.AnnotationFrameReviewRoiId
        label = '';
        color = [1 1 1];
        return;
    end
    if isempty(app.AnnotationFrameReviewMask)
        label = '[no frame review required]';
        color = [0.35 0.35 0.35];
        return;
    end
    reviewed = frame >= 1 && frame <= numel(app.AnnotationFrameReviewMask) && ...
        app.AnnotationFrameReviewMask(frame);
    if reviewed
        label = '[reviewed]';
        color = [0.10 0.55 0.20];
    end
catch
    % Rendering must remain available if annotation metadata is incomplete.
end

end
