function tf = score_isEditMode(app)
%SCORE_ISEDITMODE True when the selected score channel is editable.
% A managed annotation target remains editable while its visual mode is
% Multicolor/Semantic. Outside managed sessions, preserve the radio-button
% and legacy Paint-button behavior.

tf = false;
try
    if isprop(app, 'EditButton') && ~isempty(app.EditButton) && isvalid(app.EditButton)
        tf = logical(app.EditButton.Value);
        if tf, return; end
    end
catch
end

try
    if isprop(app, 'AnnotationSession') && ...
            ~isempty(app.AnnotationSession) && ...
            isvalid(app.AnnotationSession) && ...
            isprop(app, 'AnnotationDisplayPreset') && ...
            isstruct(app.AnnotationDisplayPreset)
        [~, channelName] = score_selectedObjectChannel(app);
        preset = app.AnnotationDisplayPreset;
        editable = {};
        if isfield(preset, 'editableChannels')
            editable = [editable cellstr(string( ...
                preset.editableChannels))]; %#ok<AGROW>
        end
        if isfield(preset, 'selectionChannels')
            editable = [editable cellstr(string( ...
                preset.selectionChannels))]; %#ok<AGROW>
        end
        editable = editable(~cellfun('isempty', editable));
        tf = ~isempty(channelName) && any(strcmpi(editable, channelName));
        if tf, return; end
    end
catch
    tf = false;
end

try
    if isprop(app, 'PaintButton') && ~isempty(app.PaintButton) && isvalid(app.PaintButton)
        tf = logical(app.PaintButton.Value);
    end
catch
    tf = false;
end
end
