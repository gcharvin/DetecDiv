function entry = resetValidationState(entry)
%ANNOTATIONMANAGER.RESETVALIDATIONSTATE Clear a recorded validation result.

entry.validation_status = 'not_run';
entry.validated_at = '';
entry.validated_hash = '';
entry.validation_message = '';
entry.validated_revision = uint32(0);
end
