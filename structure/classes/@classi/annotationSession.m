function session = annotationSession(classif, roiIndex)
%ANNOTATIONSESSION Create the shared backend annotation context for a ROI.
if nargin < 2 || isempty(roiIndex), roiIndex = 1; end
session = annotationManager.createSession(classif, roiIndex);
end
