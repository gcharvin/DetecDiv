function instance = score_resolveSelectedTrackForFrame(app, roiobj)
%SCORE_RESOLVESELECTEDTRACKFORFRAME Follow the selected track across frames.
% The mask label is frame-local storage. During tracking annotation the
% persistent human selection is the track identity, and this helper maps it
% back to the provider label required by pixel editing on the current frame.

instance = [];
trackId = NaN;
try trackId = double(app.SelectedTrackIDCell); catch, end
if isempty(trackId) || ~isscalar(trackId) || ~isfinite(trackId) || trackId <= 0
    return;
end
try
    if app.SelectedObjectRoiId ~= string(roiobj.id)
        return;
    end
catch
    return;
end

[selectedRoi, channelName] = score_selectedObjectChannel(app);
if isempty(selectedRoi) || isempty(channelName) || ...
        string(selectedRoi.id) ~= string(roiobj.id)
    return;
end
[model, status] = score_getCellModel(roiobj);
if ~strcmp(status, 'ok')
    return;
end
cfg = score_getObjectDisplayConfig(roiobj, channelName);
[~, familyId] = score_resolveCellModelFamily(model, cfg, channelName);
if isempty(familyId)
    return;
end

instance = cellModel.findTrackInstance( ...
    model, familyId, roiobj.display.frame, trackId);
if isempty(instance)
    % Keep the track identity selected, but never reuse a stale provider
    % label belonging to another trajectory on this frame.
    app.SelectedObjectLabelCell = NaN;
    app.SelectedObjectLabel = NaN;
    try app.MasklabelEditField.Value = 0; catch, end
    try
        if ~isempty(app.SelectedObjectRectangle) && ...
                isgraphics(app.SelectedObjectRectangle)
            app.SelectedObjectRectangle.Visible = 'off';
        end
    catch
    end
    return;
end

label = double(instance.mask_label);
app.SelectedObjectLabelCell = label;
app.SelectedObjectLabel = label;
try app.MasklabelEditField.Value = label; catch, end
end
