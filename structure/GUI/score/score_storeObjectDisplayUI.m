function [roiobj, channelName, cfg] = score_storeObjectDisplayUI(app)
%SCORE_STOREOBJECTDISPLAYUI Save current controls for the selected channel.

[roiobj, channelName] = score_selectedObjectChannel(app);
cfg = struct();
if isempty(roiobj) || isempty(channelName)
    return;
end

updates = struct();
if app.EditButton.Value
    updates.mode = 'edit';
elseif app.SemanticButton.Value
    updates.mode = 'semantic';
elseif app.MulticolorButton.Value
    updates.mode = 'multicolor';
else
    updates.mode = 'normal';
end
updates.criterion = char(string(app.DisplayCriterionDropDown.Value));
if strcmp(updates.mode, 'multicolor') && strcmp(updates.criterion, 'Channel color')
    updates.criterion = 'Track';
end
updates.objectFamily = char(string(app.ObjectFamilyDropDown.Value));
updates.maskProvider = char(string(app.MaskProviderDropDown.Value));
updates.lineageSource = char(string(app.LineageSourceDropDown.Value));
lineage = score_lineageDisplayOptions(app);
updates.lineageMode = lineage.mode;
updates.familyColor = double(app.FamilyColorPicker.Value);
updates.semanticValue = char(string(app.SemanticValueDropDown.Value));
updates.semanticColor = double(app.SemanticValueColorPicker.Value);
updates.budLinkColor = lineage.budLinkColor;
updates.genealogyLinkColor = lineage.genealogyLinkColor;
updates.linkWidthPx = lineage.linkWidthPx;

cfg = score_setObjectDisplayConfig(roiobj, channelName, updates);
app.ShowBudPairingOverlay = lineage.showBudPairing;
app.ShowLineageOverlay = lineage.showGenealogy;
end
