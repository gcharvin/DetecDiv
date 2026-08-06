function score_updateSelectedCellState(app)
%SCORE_UPDATESELECTEDCELLSTATE Persist the selected object's semantic state.

[roiobj, channelName] = score_selectedObjectChannel(app);
[model, status] = score_getCellModel(roiobj);
if ~strcmp(status, 'ok')
    return;
end

label = app.SelectedObjectLabelCell;
if isempty(label) || ~isscalar(label) || ~isfinite(label) || label <= 0
    return;
end
cfg = score_getObjectDisplayConfig(roiobj, channelName);
[~, familyId] = score_resolveCellModelFamily(model, cfg, channelName);
if isempty(familyId)
    return;
end

frame = uint32(roiobj.display.frame);
row = find(model.instances.family_id == familyId & ...
    model.instances.frame == frame & ...
    model.instances.mask_label == uint32(label), 1, 'first');
if isempty(row)
    return;
end

stateId = uint16(app.SelectedCellStateDropDown.Value);
if stateId > 0 && ~any(model.states.state_id == stateId)
    error('score:InvalidCellState', 'Unknown cell state id %d.', stateId);
end
model.instances.state_id(row) = stateId;
roiobj.saveCellModel(model);
app.notifyAnnotationChanged('lineage', double(frame));
score_updateSelectedObjectFields(app);
score_display(app, 'refresh');
end
