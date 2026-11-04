function detecdiv_close_progress(dialog)
%DETECDIV_CLOSE_PROGRESS Idempotent cleanup of a caller-owned UI dialog.
% Safe after manual close, a deleted parent window, or constructor failure.
try
    if ~isempty(dialog) && isvalid(dialog), close(dialog); end
catch
end
end
