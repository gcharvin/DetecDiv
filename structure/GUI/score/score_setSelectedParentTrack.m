function report = score_setSelectedParentTrack(app, parentTrackId)
%SCORE_SETSELECTEDPARENTTRACK Set/remove the selected track's parent.

[roiobj, channelName] = score_selectedObjectChannel(app);
[model, status] = score_getCellModel(roiobj);
if ~strcmp(status, 'ok')
    error('score:MissingCellModel', 'No editable cellular object model is loaded.');
end
label = app.SelectedObjectLabelCell;
if isempty(label) || ~isscalar(label) || ~isfinite(label) || label <= 0
    error('score:NoSelectedObject', 'Double-click a child object first.');
end
cfg = score_getObjectDisplayConfig(roiobj, channelName);
[~, familyId] = score_resolveCellModelFamily(model, cfg, channelName);
if isempty(familyId)
    error('score:MissingObjectFamily', 'No editable object family is selected.');
end
instance = cellModel.findInstance(model, familyId, roiobj.display.frame, label);
if isempty(instance) || instance.track_id == 0
    error('score:UntrackedSelectedObject', 'The selected object has no track ID.');
end

[model, report] = cellModel.setParentTrack(model, familyId, ...
    roiobj.display.frame, instance.track_id, parentTrackId);
roiobj.saveCellModel(model);
app.notifyAnnotationChanged('lineage', double(roiobj.display.frame));
score_updateSelectedObjectFields(app);
score_display(app, 'refresh');
end
