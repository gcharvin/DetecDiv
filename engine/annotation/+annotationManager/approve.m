function [entry, report] = approve(roiObj, spec, varargin)
%ANNOTATIONMANAGER.APPROVE Validate and freeze the current GT revision.

p = inputParser;
p.addParameter('AllowPartial', spec.allowPartialApproval, ...
    @(x) islogical(x) && isscalar(x));
p.addParameter('Force', false, @(x) islogical(x) && isscalar(x));
p.addParameter('Save', true, @(x) islogical(x) && isscalar(x));
p.addParameter('ReviewFrames', [], @isnumeric);
p.parse(varargin{:});

report = annotationManager.validate(roiObj, spec, ...
    'RequireReviewed', ~p.Results.Force, ...
    'AllowPartial', p.Results.AllowPartial, ...
    'ReviewFrames', p.Results.ReviewFrames);
if ~report.valid && ~p.Results.Force
    error('annotationManager:ApprovalValidationFailed', ...
        'Annotation cannot be approved: %s', ...
        strjoin(cellstr(report.errors), ' '));
end

[entry, ~] = annotationManager.entryForSpec(roiObj, spec);
entry.status = 'approved';
entry.approved_at = char(datetime('now', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ssXXX'));
entry.approved_hash = annotationManager.contentHash(roiObj, spec);
entry.revision = uint32(double(entry.revision) + 1);
entry.validation_status = 'valid';
entry.validated_at = entry.approved_at;
entry.validated_hash = entry.approved_hash;
entry.validation_message = '';
entry.validated_revision = uint32(entry.revision);
entry = annotationManager.setEntry(roiObj, spec, entry, 'Save', p.Results.Save);
end
