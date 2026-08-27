function score_updateSelectedObjectFields(app)
%SCORE_UPDATESELECTEDOBJECTFIELDS Show the selected model object and track.

label = NaN;
try
    if ~isempty(app.SelectedObjectLabelCell)
        label = double(app.SelectedObjectLabelCell);
    elseif ~isempty(app.SelectedObjectLabel)
        label = double(app.SelectedObjectLabel);
    end
catch
end

objectText = '';
trackText = '';
stateItems = {'<none>'};
stateIds = 0;
stateValue = '<none>';
stateEnabled = false;

if ~isempty(label) && isscalar(label) && isfinite(label) && label > 0
    objectText = sprintf('label:%g', label);
    trackText = sprintf('legacy:%g', label);
    [roiobj, channelName] = score_selectedObjectChannel(app);
    [model, modelStatus] = score_getCellModel(roiobj);
    if strcmp(modelStatus, 'ok')
        cfg = score_getObjectDisplayConfig(roiobj, channelName);
        [~, familyId] = score_resolveCellModelFamily(model, cfg, channelName);
        if ~isempty(familyId)
            frame = double(roiobj.display.frame);
            instance = cellModel.findInstance(model, familyId, frame, label);
            if isempty(instance)
                objectText = sprintf('unmapped:%g', label);
                trackText = '';
                try app.SelectedTrackIDCell = NaN; catch, end
            else
                objectText = char(string(instance.object_id));
                if instance.track_id > 0
                    trackText = char(string(instance.track_id));
                    try app.SelectedTrackIDCell = double(instance.track_id); catch, end
                else
                    trackText = '<unassigned>';
                    try app.SelectedTrackIDCell = NaN; catch, end
                end
                stateItems = [{'<none>'}; model.states.name(:)];
                stateIds = [0; double(model.states.state_id(:))];
                hit = find(model.states.state_id == instance.state_id, 1, 'first');
                if ~isempty(hit)
                    stateValue = model.states.name{hit};
                end
                stateEnabled = true;
            end
        end
    end
end
try app.SelectedObjectIDEditField.Value = objectText; catch, end
try app.SelectedTrackIDEditField.Value = trackText; catch, end
try
    app.SelectedCellStateDropDown.Items = stateItems;
    app.SelectedCellStateDropDown.ItemsData = stateIds;
    selectedIndex = find(strcmp(stateItems, stateValue), 1, 'first');
    if isempty(selectedIndex), selectedIndex = 1; end
    app.SelectedCellStateDropDown.Value = stateIds(selectedIndex);
    app.SelectedCellStateDropDown.Enable = onOff(stateEnabled);
catch
end
score_updateSelectedCensoringFields(app);
end

function value = onOff(tf)
if tf, value = 'on'; else, value = 'off'; end
end
