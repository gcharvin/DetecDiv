function tf = score_isEditMode(app)
%SCORE_ISEDITMODE True when the selected score channel is in Edit mode.
% Supports the new radio-button UI and the legacy Paint state button during
% the transition between layouts.

tf = false;
try
    if isprop(app, 'EditButton') && ~isempty(app.EditButton) && isvalid(app.EditButton)
        tf = logical(app.EditButton.Value);
        return;
    end
catch
end

try
    if isprop(app, 'PaintButton') && ~isempty(app.PaintButton) && isvalid(app.PaintButton)
        tf = logical(app.PaintButton.Value);
    end
catch
    tf = false;
end
end
