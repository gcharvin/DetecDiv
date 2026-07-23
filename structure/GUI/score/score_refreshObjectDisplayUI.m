function score_refreshObjectDisplayUI(app)
%SCORE_REFRESHOBJECTDISPLAYUI Load the selected channel's compact preset.

[roiobj, channelName] = score_selectedObjectChannel(app);
hasChannel = ~isempty(roiobj) && ~isempty(channelName);
setObjectControlsEnabled(app, hasChannel);
if ~hasChannel
    setStatus(app, 'No object channel selected');
    score_updateSelectedObjectFields(app);
    return;
end

cfg = score_getObjectDisplayConfig(roiobj, channelName);
[model, modelStatus] = score_getCellModel(roiobj);
setMode(app, cfg.mode);
setDropDown(app.DisplayCriterionDropDown, app.DisplayCriterionDropDown.Items, cfg.criterion);

families = configuredFamilies(roiobj, model);
familyValue = effectiveFamilyName(model, cfg, channelName);
setDropDown(app.ObjectFamilyDropDown, [{'<auto>'}, families], familyValue);

providers = indexedChannels(roiobj);
providerValue = effectiveMaskProvider(model, cfg, familyValue, channelName);
setDropDown(app.MaskProviderDropDown, [{'<family default>'}, providers], providerValue);

sources = lineageSources(roiobj, model);
setDropDown(app.LineageSourceDropDown, [{'<family default>','<none>'}, sources], cfg.lineageSource);
setLineageMode(app, cfg.lineageMode);

app.FamilyColorPicker.Value = familyColor(model, familyValue, cfg.familyColor);
app.BudlinkcolorColorPicker.Value = cfg.budLinkColor;
app.GenealogyLinkColorPicker.Value = cfg.genealogyLinkColor;
semanticItems = semanticValues(cfg.criterion, families, model);
setDropDown(app.SemanticValueDropDown, semanticItems, cfg.semanticValue);
app.SemanticValueColorPicker.Value = cfg.semanticColor;
app.SemanticValueColorPicker.Value = semanticColor( ...
    model, cfg.criterion, app.SemanticValueDropDown.Value, cfg.semanticColor);

isSemantic = strcmp(cfg.mode, 'semantic');
app.DisplayCriterionDropDown.Enable = onOff(~strcmp(cfg.mode, 'normal'));
app.SemanticValueDropDown.Enable = onOff(isSemantic);
app.SemanticValueColorPicker.Enable = onOff(isSemantic);
app.MasklabelEditField.Enable = onOff(strcmp(cfg.mode, 'edit'));
app.SelectedTrackIDEditField.Editable = 'off';

if strcmp(modelStatus, 'ok')
    setStatus(app, sprintf('Cell model v1: %d families', numel(model.families.family_id)));
elseif hasLegacyCellInformation(roiobj)
    setStatus(app, 'Legacy cell_information');
else
    setStatus(app, 'No cellular object model');
end
score_updateSelectedObjectFields(app);
end

function setMode(app, mode)
switch lower(char(string(mode)))
    case 'multicolor'
        app.ChannelModeButtonGroup.SelectedObject = app.MulticolorButton;
    case 'semantic'
        app.ChannelModeButtonGroup.SelectedObject = app.SemanticButton;
    case 'edit'
        app.ChannelModeButtonGroup.SelectedObject = app.EditButton;
    otherwise
        app.ChannelModeButtonGroup.SelectedObject = app.NormalButton;
end
end

function setLineageMode(app, mode)
switch lower(char(string(mode)))
    case 'bud'
        app.LineageDisplayButtonGroup.SelectedObject = app.BudLinksRadioButton;
    case 'genealogy'
        app.LineageDisplayButtonGroup.SelectedObject = app.FullGenealogyRadioButton;
    otherwise
        app.LineageDisplayButtonGroup.SelectedObject = app.NoLineageRadioButton;
end
end

function setDropDown(control, items, value)
items = cellstr(string(items));
items = items(~cellfun('isempty', items));
items = unique(items, 'stable');
value = char(string(value));
if isempty(items)
    items = {'<none>'};
end
if isempty(value) || ~any(strcmp(items, value))
    value = items{1};
end
control.Items = items;
control.Value = value;
end

function families = configuredFamilies(roiobj, model)
families = {};
if ~isempty(model)
    families = model.families.name(:).';
    return;
end
try
    store = roiobj.display.objectDisplay;
    if isstruct(store) && isfield(store, 'channels') && ~isempty(store.channels)
        families = cellstr(string({store.channels.objectFamily}));
        families = families(~strcmp(families, '<auto>'));
    end
catch
end
end

function value = effectiveFamilyName(model, cfg, channelName)
value = cfg.objectFamily;
if ~strcmp(value, '<auto>') || isempty(model), return; end
provider = cfg.maskProvider;
if any(strcmp(provider, {'','<family default>'})), provider = channelName; end
hit = find(strcmp(string(model.families.mask_provider), string(provider)), 1, 'first');
if isempty(hit)
    hit = find(strcmp(string(model.families.mask_provider), string(channelName)), 1, 'first');
end
if ~isempty(hit), value = model.families.name{hit}; end
end

function value = effectiveMaskProvider(model, cfg, familyName, channelName)
value = cfg.maskProvider;
if isempty(model) || strcmp(familyName, '<auto>'), return; end
[idx,~] = cellModel.familyIndex(model, familyName);
if isempty(idx), return; end
% In a structured model the family owns the authoritative provider.
value = model.families.mask_provider{idx};
end

function providers = indexedChannels(roiobj)
providers = {};
try
    mask = logical(roiobj.display.indexed(:).');
    names = cellstr(string(roiobj.display.channel));
    n = min(numel(mask), numel(names));
    providers = names(find(mask(1:n))); %#ok<FNDSB>
catch
end
end

function sources = lineageSources(roiobj, model)
sources = {};
if ~isempty(model)
    sources = cellstr(string(model.families.lineage_source(:).'));
    sources = sources(~cellfun('isempty', sources));
end
try
    idx = find(arrayfun(@(x) isprop(x,'groupid') && ...
        strcmp(char(string(x.groupid)), 'cell_information'), roiobj.data), 1, 'first');
    if isempty(idx) || ~isstruct(roiobj.data(idx).userData) || ...
            ~isfield(roiobj.data(idx).userData, 'lineageSources')
        return;
    end
    legacy = fieldnames(roiobj.data(idx).userData.lineageSources).';
    sources = unique([sources legacy], 'stable');
catch
end
end

function color = familyColor(model, familyName, fallback)
color = fallback;
if isempty(model), return; end
[idx, ~] = cellModel.familyIndex(model, familyName);
if ~isempty(idx), color = double(model.families.color_rgb(idx,:)) ./ 255; end
end

function color = semanticColor(model, criterion, value, fallback)
color = fallback;
if isempty(model) || ~strcmp(char(string(criterion)), 'Cell state'), return; end
idx = find(strcmp(string(model.states.name), string(value)), 1, 'first');
if ~isempty(idx), color = double(model.states.color_rgb(idx,:)) ./ 255; end
end

function values = semanticValues(criterion, families, model)
switch char(string(criterion))
    case 'New bud'
        values = {'New bud'};
    case 'Cell state'
        values = {'<none>'};
        if ~isempty(model), values = [{'<none>'}, model.states.name(:).']; end
    case 'Family'
        values = [{'<auto>'}, families];
    otherwise
        values = {'<none>'};
end
end

function tf = hasLegacyCellInformation(roiobj)
tf = false;
try
    tf = any(arrayfun(@(x) isprop(x,'groupid') && ...
        strcmp(char(string(x.groupid)), 'cell_information'), roiobj.data));
catch
end
end

function setObjectControlsEnabled(app, tf)
names = {'ChannelModeButtonGroup','DisplayCriterionDropDown','LineageDisplayButtonGroup', ...
    'ObjectFamilyDropDown','MaskProviderDropDown','LineageSourceDropDown', ...
    'FamilyColorPicker','SemanticValueDropDown','SemanticValueColorPicker', ...
    'BudlinkcolorColorPicker','GenealogyLinkColorPicker'};
for i = 1:numel(names)
    try
        app.(names{i}).Enable = onOff(tf);
    catch
    end
end
end

function setStatus(app, text)
try
    app.CellModelStatusLabel.Text = text;
catch
end
end

function value = onOff(tf)
if tf, value = 'on'; else, value = 'off'; end
end
