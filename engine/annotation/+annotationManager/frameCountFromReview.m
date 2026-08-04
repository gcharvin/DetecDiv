function count = frameCountFromReview(entry, reviewIndex)
%ANNOTATIONMANAGER.FRAMECOUNTFROMREVIEW Internal coverage helper.
count = 0;
if isempty(reviewIndex) || ~isfield(entry, 'review') || isempty(entry.review)
    return;
end
try, count = numel(entry.review(reviewIndex).frames); catch, count = 0; end
end
