function report = score_swapSelectedTrackIds(app, destinationTrackId)
%SCORE_SWAPSELECTEDTRACKIDS Exchange the selected and destination tracks.

[roiobj, channelName] = score_selectedObjectChannel(app);
[model, status] = score_getCellModel(roiobj);
if ~strcmp(status, 'ok')
    error('score:MissingCellModel', 'No editable cellular object model is loaded.');
end
label = app.SelectedObjectLabelCell;
if isempty(label) || ~isscalar(label) || ~isfinite(label) || label <= 0
    error('score:NoSelectedObject', 'Double-click an object before swapping tracks.');
end
cfg = score_getObjectDisplayConfig(roiobj, channelName);
[~, familyId] = score_resolveCellModelFamily(model, cfg, channelName);
if isempty(familyId)
    error('score:MissingObjectFamily', 'No editable object family is selected.');
end
instance = cellModel.findInstance(model, familyId, roiobj.display.frame, label);
if isempty(instance) || instance.track_id == 0
    error('score:UnassignedTrack', 'The selected object has no track identity to swap.');
end

[model, report] = cellModel.swapTrackIds( ...
    model, familyId, instance.track_id, destinationTrackId);
roiobj.saveCellModel(model);
app.notifyAnnotationChanged('lineage', report.frames);
score_updateSelectedObjectFields(app);
score_display(app, 'refresh');
end
