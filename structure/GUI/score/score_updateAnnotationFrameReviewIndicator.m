function score_updateAnnotationFrameReviewIndicator(app, roiObj, frame)
%SCORE_UPDATEANNOTATIONFRAMEREVIEWINDICATOR Refresh the lightweight UI cue.
try
    if isempty(app.AnnotationSessionPanel) || ~isvalid(app.AnnotationSessionPanel)
        return;
    end
    [label, color] = score_annotationFrameReviewStatus(app, roiObj, frame);
    if isempty(label), return; end
    app.AnnotationSessionPanel.Title = sprintf( ...
        'Annotation Session — Frame %d: %s', frame, upper(label(2:end-1)));
    app.AnnotationStatusLabel.FontColor = color;
catch
    % Never let a display refresh fail because of an optional status cue.
end
end
