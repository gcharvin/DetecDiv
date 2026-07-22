function score_setEditMode(app, enabled)
%SCORE_SETEDITMODE Select Edit or Normal in either score GUI generation.

enabled = logical(enabled);

try
    if isprop(app, 'ChannelModeButtonGroup') && ...
            isprop(app, 'EditButton') && isprop(app, 'NormalButton') && ...
            ~isempty(app.ChannelModeButtonGroup) && isvalid(app.ChannelModeButtonGroup)
        if enabled
            app.ChannelModeButtonGroup.SelectedObject = app.EditButton;
        elseif isequal(app.ChannelModeButtonGroup.SelectedObject, app.EditButton)
            app.ChannelModeButtonGroup.SelectedObject = app.NormalButton;
        end
        return;
    end
catch
end

try
    if isprop(app, 'PaintButton') && ~isempty(app.PaintButton) && isvalid(app.PaintButton)
        app.PaintButton.Value = enabled;
    end
catch
end
end
