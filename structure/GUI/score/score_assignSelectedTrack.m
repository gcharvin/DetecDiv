function report = score_assignSelectedTrack(app, newTrackId, scope)
%SCORE_ASSIGNSELECTEDTRACK Reassign the selected model object to a track.

if nargin < 3 || isempty(scope), scope = 'frame'; end
[roiobj, channelName] = score_selectedObjectChannel(app);
[model, status] = score_getCellModel(roiobj);
if ~strcmp(status, 'ok')
    error('score:MissingCellModel', 'No editable cellular object model is loaded.');
end
label = app.SelectedObjectLabelCell;
if isempty(label) || ~isscalar(label) || ~isfinite(label) || label <= 0
    error('score:NoSelectedObject', 'Double-click an object before assigning its track.');
end
cfg = score_getObjectDisplayConfig(roiobj, channelName);
[~, familyId] = score_resolveCellModelFamily(model, cfg, channelName);
if isempty(familyId)
    error('score:MissingObjectFamily', 'No editable object family is selected.');
end

[model, report] = cellModel.reassignTrack(model, familyId, ...
    roiobj.display.frame, label, newTrackId, scope, 'Fast', true);
roiobj.cellModel = model;
app.notifyAnnotationChanged('tracking', report.frames, 'Save', false);
score_updateSelectedObjectFields(app);
score_display(app, 'fast');
end
