function rows = annotationSummary(classif, roiIndices)
%ANNOTATIONSUMMARY Return annotation status rows for classifier frontends.
if nargin < 2, roiIndices = []; end
rows = annotationManager.summarizeClassifier(classif, roiIndices);
end
