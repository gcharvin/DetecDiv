function suffix = score_annotationFrameReviewSuffix(app, roiObj, frame)
%SCORE_ANNOTATIONFRAMEREVIEWSUFFIX Text appended to the image figure title.
[label, ~] = score_annotationFrameReviewStatus(app, roiObj, frame);
if isempty(label)
    suffix = '';
else
    suffix = [' - GT: ' upper(strrep(strrep(label, '[', ''), ']', ''))];
end
end
