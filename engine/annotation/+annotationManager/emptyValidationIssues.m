function issues = emptyValidationIssues()
%ANNOTATIONMANAGER.EMPTYVALIDATIONISSUES Empty canonical issue array.

issues = repmat(annotationManager.newValidationIssue(), 0, 1);
end
