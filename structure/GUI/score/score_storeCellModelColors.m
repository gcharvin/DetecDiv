function changed = score_storeCellModelColors(app)
%SCORE_STORECELLMODELCOLORS Persist selected family/state picker colors.

changed = false;
[roiobj, channelName] = score_selectedObjectChannel(app);
[model, status] = score_getCellModel(roiobj);
if ~strcmp(status, 'ok')
    return;
end
cfg = score_getObjectDisplayConfig(roiobj, channelName);
[familyIndex, ~] = score_resolveCellModelFamily(model, cfg, channelName);
if isempty(familyIndex)
    return;
end

familyColor = uint8(round(255 * max(0, min(1, ...
    double(app.FamilyColorPicker.Value(:).')))));
if ~isequal(model.families.color_rgb(familyIndex,:), familyColor)
    model.families.color_rgb(familyIndex,:) = familyColor;
    changed = true;
end

if strcmp(char(string(app.DisplayCriterionDropDown.Value)), 'Cell state')
    stateName = string(app.SemanticValueDropDown.Value);
    stateIndex = find(strcmp(string(model.states.name), stateName), 1, 'first');
    if ~isempty(stateIndex)
        stateColor = uint8(round(255 * max(0, min(1, ...
            double(app.SemanticValueColorPicker.Value(:).')))));
        if ~isequal(model.states.color_rgb(stateIndex,:), stateColor)
            model.states.color_rgb(stateIndex,:) = stateColor;
            changed = true;
        end
    end
end

if changed
    roiobj.saveCellModel(model);
end
end
