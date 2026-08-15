function entry = recordValidation(roiObj, spec, report, varargin)
%ANNOTATIONMANAGER.RECORDVALIDATION Persist validation for the GT revision.

p = inputParser;
p.addParameter('Save', true, @(x) islogical(x) && isscalar(x));
p.parse(varargin{:});

[entry, found] = annotationManager.entryForSpec(roiObj, spec);
if ~found, return; end
entry.validated_at = char(datetime('now', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ssXXX'));
entry.validated_revision = uint32(entry.revision);
if report.valid
    entry.validation_status = 'valid';
    entry.validation_message = '';
    try
        entry.validated_hash = annotationManager.contentHash(roiObj, spec);
    catch
        entry.validated_hash = '';
    end
    % A successful validation is the single user-facing transition to a
    % training-ready GT. Keep the historical approval fields as internal
    % audit metadata, but do not require a second UI action.
    entry.status = 'approved';
    entry.approved_at = entry.validated_at;
    entry.approved_hash = entry.validated_hash;
else
    entry.validation_status = 'invalid';
    entry.validated_hash = '';
    entry.validation_message = char(strjoin( ...
        cellstr(string(report.errors)), newline));
    entry.status = 'draft';
    entry.approved_at = '';
    entry.approved_hash = '';
end
entry = annotationManager.setEntry(roiObj, spec, entry, ...
    'Save', p.Results.Save);
end
