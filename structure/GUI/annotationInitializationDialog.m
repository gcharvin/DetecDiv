function [recipe, accepted] = annotationInitializationDialog(parent, catalog, varargin)
%ANNOTATIONINITIALIZATIONDIALOG Choose a coherent GT starting point.

p = inputParser;
p.addParameter('RoiCount', 1, @(x) isnumeric(x) && isscalar(x) && x >= 1);
p.addParameter('HasExistingGT', false, @(x) islogical(x) && isscalar(x));
p.addParameter('Title', 'Initialize ground truth', @(x) ischar(x) || isstring(x));
p.parse(varargin{:});

recipe = catalog.defaultRecipe;
accepted = false;
[modeLabels, modeIds] = availableModes(catalog);
families = catalog.families([catalog.families.usable]);

fig = uifigure('Name', char(string(p.Results.Title)), ...
    'Position', [100 100 650 410], 'Resize', 'off', ...
    'WindowStyle', 'modal', 'CloseRequestFcn', @cancelDialog);
positionNearParent(fig, parent);
grid = uigridlayout(fig, [8 2]);
grid.ColumnWidth = {145, '1x'};
grid.RowHeight = {34, 34, 34, 34, 64, 45, '1x', 38};
grid.Padding = [18 15 18 15];
grid.RowSpacing = 8;

intro = uilabel(grid, 'Text', introductionText(p.Results.RoiCount), ...
    'FontWeight', 'bold');
intro.Layout.Row = 1;
intro.Layout.Column = [1 2];

uilabel(grid, 'Text', 'Starting point:');
modeDropDown = uidropdown(grid, 'Items', modeLabels, 'ItemsData', modeIds, ...
    'ValueChangedFcn', @updateUi);

uilabel(grid, 'Text', 'Object family:');
familyDropDown = uidropdown(grid, 'ValueChangedFcn', @updateUi);
if isempty(families)
    familyDropDown.Items = {'<none available>'};
    familyDropDown.ItemsData = {''};
else
    familyDropDown.Items = {families.label};
    familyDropDown.ItemsData = {families.name};
end

uilabel(grid, 'Text', 'Segmentation mask:');
maskDropDown = uidropdown(grid, 'ValueChangedFcn', @updateUi);
if isempty(catalog.maskChannels)
    maskDropDown.Items = {'<none available>'};
    maskDropDown.ItemsData = {''};
else
    maskDropDown.Items = catalog.maskChannels;
    maskDropDown.ItemsData = catalog.maskChannels;
end

uilabel(grid, 'Text', 'Parentage:');
parentageDropDown = uidropdown(grid, ...
    'Items', {'Copy existing parentage','Start with blank parentage'}, ...
    'ItemsData', {'copy','blank'}, 'ValueChangedFcn', @updateUi);

preview = uilabel(grid, 'Text', '', 'WordWrap', 'on', ...
    'BackgroundColor', [0.95 0.96 0.97]);
preview.Layout.Row = 5;
preview.Layout.Column = [1 2];

warningLabel = uilabel(grid, 'WordWrap', 'on', ...
    'FontColor', [0.75 0.18 0.10]);
warningLabel.Layout.Row = 6;
warningLabel.Layout.Column = [1 2];
if p.Results.HasExistingGT
    warningLabel.Text = ['This will replace existing draft or approved GT ' ...
        'for at least one selected ROI. The prediction sources are not modified.'];
else
    warningLabel.Text = '';
end

helpLabel = uilabel(grid, 'WordWrap', 'on', 'FontColor', [0.35 0.35 0.35], ...
    'Text', ['An object family always brings its own mask provider and tracks. ' ...
        'This prevents mixing masks with incompatible identities.']);
helpLabel.Layout.Row = 7;
helpLabel.Layout.Column = [1 2];

buttonGrid = uigridlayout(grid, [1 3]);
buttonGrid.Layout.Row = 8;
buttonGrid.Layout.Column = [1 2];
buttonGrid.ColumnWidth = {'1x', 100, 125};
buttonGrid.Padding = [0 0 0 0];
cancelButton = uibutton(buttonGrid, 'Text', 'Cancel', ...
    'ButtonPushedFcn', @cancelDialog);
cancelButton.Layout.Column = 2;
actionText = 'Initialize GT';
if p.Results.HasExistingGT, actionText = 'Replace GT'; end
actionButton = uibutton(buttonGrid, 'Text', actionText, ...
    'ButtonPushedFcn', @acceptDialog, 'FontWeight', 'bold');
actionButton.Layout.Column = 3;

applyDefaultRecipe();
updateUi();
uiwait(fig);
if isvalid(fig), delete(fig); end

    function applyDefaultRecipe()
        mode = char(string(recipe.mode));
        if any(strcmp(modeIds, mode))
            modeDropDown.Value = mode;
        else
            modeDropDown.Value = modeIds{1};
        end
        if ~isempty(recipe.family) && any(strcmpi({families.name}, recipe.family))
            idx = find(strcmpi({families.name}, recipe.family), 1, 'first');
            familyDropDown.Value = families(idx).name;
        end
        if ~isempty(recipe.channel) && any(strcmpi(catalog.maskChannels, recipe.channel))
            idx = find(strcmpi(catalog.maskChannels, recipe.channel), 1, 'first');
            maskDropDown.Value = catalog.maskChannels{idx};
        end
        if recipe.copyParentage
            parentageDropDown.Value = 'copy';
        else
            parentageDropDown.Value = 'blank';
        end
    end

    function updateUi(varargin) %#ok<INUSD>
        mode = char(string(modeDropDown.Value));
        switch mode
            case 'prediction'
                familyDropDown.Enable = 'off';
                maskDropDown.Enable = 'off';
                hasFamily = ~isempty(catalog.prediction.family);
                parentageDropDown.Enable = onOff(hasFamily);
                if hasFamily
                    setFamilyValue(catalog.prediction.family);
                    setMaskValue(catalog.prediction.maskProvider);
                else
                    parentageDropDown.Value = 'blank';
                end
                source = catalog.prediction;
                valid = catalog.prediction.available;
                if hasFamily
                    preview.Text = familyPreview('Model prediction', source, ...
                        strcmp(parentageDropDown.Value, 'copy'));
                else
                    preview.Text = ['Copy all classifier prediction components ' ...
                        'into editable GT.'];
                end
            case 'family'
                familyDropDown.Enable = 'on';
                maskDropDown.Enable = 'off';
                parentageDropDown.Enable = 'on';
                source = selectedFamily();
                valid = ~isempty(source) && source.providerExists;
                if valid, setMaskValue(source.maskProvider); end
                preview.Text = familyPreview('Existing tracked objects', source, ...
                    strcmp(parentageDropDown.Value, 'copy'));
            case 'mask'
                familyDropDown.Enable = 'off';
                maskDropDown.Enable = 'on';
                parentageDropDown.Value = 'blank';
                parentageDropDown.Enable = 'off';
                valid = ~isempty(char(string(maskDropDown.Value)));
                preview.Text = sprintf(['Segmentation: %s\n' ...
                    'Tracking: blank\nParentage: blank'], ...
                    char(string(maskDropDown.Value)));
            otherwise
                familyDropDown.Enable = 'off';
                maskDropDown.Enable = 'off';
                parentageDropDown.Value = 'blank';
                parentageDropDown.Enable = 'off';
                valid = true;
                preview.Text = ['Segmentation: blank' newline ...
                    'Tracking: blank' newline 'Parentage: blank'];
        end
        actionButton.Enable = onOff(valid);
    end

    function source = selectedFamily()
        source = [];
        if isempty(families), return; end
        idx = find(strcmpi({families.name}, ...
            char(string(familyDropDown.Value))), 1, 'first');
        if ~isempty(idx), source = families(idx); end
    end

    function setFamilyValue(name)
        if isempty(families), return; end
        idx = find(strcmpi({families.name}, char(string(name))), 1, 'first');
        if ~isempty(idx), familyDropDown.Value = families(idx).name; end
    end

    function setMaskValue(name)
        idx = find(strcmpi(catalog.maskChannels, char(string(name))), 1, 'first');
        if ~isempty(idx), maskDropDown.Value = catalog.maskChannels{idx}; end
    end

    function acceptDialog(~, ~)
        mode = char(string(modeDropDown.Value));
        recipe = struct('mode', mode, 'family', '', 'channel', '', ...
            'copyParentage', strcmp(parentageDropDown.Value, 'copy'));
        switch mode
            case 'prediction'
                recipe.family = catalog.prediction.family;
                recipe.channel = catalog.prediction.maskProvider;
            case 'family'
                source = selectedFamily();
                if isempty(source), return; end
                recipe.family = source.name;
                recipe.channel = source.maskProvider;
            case 'mask'
                recipe.channel = char(string(maskDropDown.Value));
                recipe.copyParentage = false;
            otherwise
                recipe.copyParentage = false;
        end
        accepted = true;
        uiresume(fig);
    end

    function cancelDialog(~, ~)
        accepted = false;
        if isvalid(fig), uiresume(fig); end
    end
end

function [labels, ids] = availableModes(catalog)
labels = {};
ids = {};
if catalog.prediction.available
    labels{end+1} = 'Model prediction'; %#ok<AGROW>
    ids{end+1} = 'prediction'; %#ok<AGROW>
end
if catalog.supports.family && any([catalog.families.usable])
    labels{end+1} = 'Existing tracked objects'; %#ok<AGROW>
    ids{end+1} = 'family'; %#ok<AGROW>
end
if catalog.supports.mask && ~isempty(catalog.maskChannels)
    labels{end+1} = 'Existing segmentation mask'; %#ok<AGROW>
    ids{end+1} = 'mask'; %#ok<AGROW>
end
labels{end+1} = 'Blank GT';
ids{end+1} = 'blank';
end

function text = familyPreview(prefix, source, copyParentage)
if isempty(source)
    text = 'No compatible object family is available.';
    return;
end
if copyParentage
    parentage = sprintf('%d existing parent links', source.relationCount);
else
    parentage = 'blank';
end
text = sprintf(['%s\nSegmentation: %s\n' ...
    'Tracking: %s (%d tracks) | Parentage: %s'], ...
    prefix, source.maskProvider, familyName(source), source.trackCount, parentage);
end

function name = familyName(source)
if isfield(source, 'family')
    name = source.family;
else
    name = source.name;
end
end

function text = introductionText(roiCount)
if roiCount == 1
    text = 'Choose how the editable GT should be initialized for this ROI.';
else
    text = sprintf('Choose one initialization recipe for %d selected ROIs.', roiCount);
end
end

function positionNearParent(fig, parent)
try
    parentFigure = ancestor(parent, 'figure');
    p = parentFigure.Position;
    f = fig.Position;
    f(1) = p(1) + max(0, (p(3) - f(3)) / 2);
    f(2) = p(2) + max(0, (p(4) - f(4)) / 2);
    fig.Position = f;
catch
    movegui(fig, 'center');
end
end

function value = onOff(condition)
if condition, value = 'on'; else, value = 'off'; end
end
