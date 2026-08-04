function session = createSession(classif, roiIndex)
%ANNOTATIONMANAGER.CREATESESSION Create the backend context for one ROI.
if nargin < 2, roiIndex = 1; end
session = annotationManager.Session(classif, roiIndex);
end
