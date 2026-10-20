function fig = detecdiv_modules_browser(varargin)
%DETECDIV_MODULES_BROWSER Browse the common, read-only module catalogue.
% Catalogue options Root, PluginRoots, PackagePaths and IncludeActivePackages
% are forwarded to detecdiv_modules_ui. Visible='off' permits UI inspection
% without showing a window. Browsing never executes module metadata hooks,
% changes the MATLAB path or prepares a Python/model runtime.

[catalogueOptions, visible] = localOptions(varargin{:});
[~, items, diagnostics] = detecdiv_modules_ui(catalogueOptions{:});

fig = uifigure('Name', 'DetecDiv module catalogue', ...
    'Position', [120 120 1220 760], 'Visible', visible, ...
    'Tag', 'DetecdivModuleCatalogue');
main = uigridlayout(fig, [4 1]);
main.RowHeight = {24, '1x', 130, 34};
main.ColumnWidth = {'1x'};
main.Padding = [12 12 12 12];
main.RowSpacing = 10;
uilabel(main, 'Text', ...
    'Module catalogue: availability describes MATLAB code; runtime and models are not checked.', ...
    'FontWeight', 'bold');

content = uigridlayout(main, [1 2]);
content.ColumnWidth = {'2x', '1x'};
content.RowHeight = {'1x'};
content.Padding = [0 0 0 0];
content.ColumnSpacing = 14;
tbl = uitable(content, 'Tag', 'DetecdivModuleCatalogueTable');
tbl.ColumnName = {'Name', 'Type', 'Package', 'Distribution', ...
    'Adapter version', 'Availability'};
tbl.ColumnWidth = {125, 85, 130, 90, 95, 150};
tbl.RowName = {};
tbl.ColumnEditable = false(1,6);
tbl.Data = localTableData(items);
tbl.UserData = items;

detailPanel = uigridlayout(content, [2 1]);
detailPanel.RowHeight = {24, '1x'};
detailPanel.ColumnWidth = {'1x'};
detailPanel.Padding = [0 0 0 0];
titleLabel = uilabel(detailPanel, 'Text', 'Select a module', ...
    'FontWeight', 'bold', 'FontSize', 15);
detailsBox = uitextarea(detailPanel, 'Editable', 'off', ...
    'Tag', 'DetecdivModuleCatalogueDetails', 'Value', {''});

diagnosticPanel = uigridlayout(main, [2 1]);
diagnosticPanel.RowHeight = {24, '1x'};
diagnosticPanel.ColumnWidth = {'1x'};
diagnosticPanel.Padding = [0 0 0 0];
uilabel(diagnosticPanel, 'Text', 'Catalogue diagnostics', 'FontWeight', 'bold');
diagnosticsBox = uitextarea(diagnosticPanel, 'Editable', 'off', ...
    'Tag', 'DetecdivModuleCatalogueDiagnostics', ...
    'Value', localDiagnosticLines(diagnostics));

bar = uigridlayout(main, [1 4]);
bar.ColumnWidth = {'1x', 110, 110, 110};
bar.Padding = [0 0 0 0];
status = uilabel(bar, 'Text', localStatus(items, diagnostics), ...
    'Tag', 'DetecdivModuleCatalogueStatus');
uibutton(bar, 'Text', 'Refresh', 'ButtonPushedFcn', @refreshModules);
openFolderButton = uibutton(bar, 'Text', 'Open folder', 'Enable', 'off', ...
    'ButtonPushedFcn', @openSelectedFolder);
copyPathButton = uibutton(bar, 'Text', 'Copy path', 'Enable', 'off', ...
    'ButtonPushedFcn', @copySelectedPath);

tbl.SelectionChangedFcn = @selectionChanged;
updateSnapshot();
selectFirst();

    function refreshModules(~, ~)
        [~, items, diagnostics] = detecdiv_modules_ui(catalogueOptions{:});
        tbl.Data = localTableData(items);
        tbl.UserData = items;
        diagnosticsBox.Value = localDiagnosticLines(diagnostics);
        status.Text = localStatus(items, diagnostics);
        updateSnapshot();
        selectFirst();
    end

    function updateSnapshot()
        fig.UserData = struct('items', items, 'diagnostics', diagnostics);
    end

    function selectFirst()
        if isempty(items)
            tbl.Selection = [];
            renderEmpty();
        else
            tbl.Selection = [1 1];
            renderModule(1);
        end
    end

    function selectionChanged(~, event)
        row = [];
        try
            if ~isempty(event.Selection), row = event.Selection(1,1); end
        catch
        end
        if isempty(row)
            try
                if ~isempty(tbl.Selection), row = tbl.Selection(1,1); end
            catch
            end
        end
        if isempty(row) || row < 1 || row > numel(items)
            renderEmpty();
        else
            renderModule(row);
        end
    end

    function renderEmpty()
        titleLabel.Text = 'No module selected';
        detailsBox.Value = {'No module was found in the configured catalogue locations.'};
        openFolderButton.Enable = 'off';
        copyPathButton.Enable = 'off';
    end

    function renderModule(row)
        item = items(row);
        titleLabel.Text = sprintf('%s (%s)', item.module.name, item.module.type);
        detailsBox.Value = localColumn(item.details);
        openFolderButton.Enable = localOnOff(isfolder(item.module.path));
        copyPathButton.Enable = localOnOff(~isempty(item.module.path));
    end

    function item = selectedItem()
        item = [];
        try
            row = tbl.Selection(1,1);
            if row >= 1 && row <= numel(items), item = items(row); end
        catch
        end
    end

    function openSelectedFolder(~, ~)
        item = selectedItem();
        if isempty(item) || ~isfolder(item.module.path), return; end
        if ispc
            winopen(item.module.path);
        elseif ismac
            system(['open ' localQuote(item.module.path)]);
        else
            system(['xdg-open ' localQuote(item.module.path)]);
        end
    end

    function copySelectedPath(~, ~)
        item = selectedItem();
        if isempty(item), return; end
        clipboard('copy', item.module.path);
        status.Text = ['Copied: ' item.module.path];
    end
end

function [options, visible] = localOptions(varargin)
options = {};
visible = 'on';
if mod(numel(varargin),2) ~= 0
    error('detecdiv_modules_browser:BadInputs', 'Use name/value inputs.');
end
for i = 1:2:numel(varargin)
    key = lower(char(string(varargin{i})));
    if strcmp(key, 'visible')
        visible = validatestring(varargin{i+1}, {'on','off'});
    elseif any(strcmp(key, {'root','pluginroots','packagepaths','includeactivepackages'}))
        options = [options varargin(i:i+1)]; %#ok<AGROW>
    else
        error('detecdiv_modules_browser:BadInput', 'Unknown option: %s', key);
    end
end
end

function data = localTableData(items)
data = cell(numel(items),6);
for i = 1:numel(items)
    module = items(i).module;
    version = module.adapterVersion;
    if isempty(version), version = 'Unspecified'; end
    data(i,:) = {module.name, module.type, module.pkg, ...
        module.distribution, char(string(version)), items(i).statusLabel};
end
end

function lines = localDiagnosticLines(diagnostics)
if isempty(diagnostics)
    lines = {'No catalogue diagnostics. Runtime dependencies and model releases have not been checked.'};
    return;
end
lines = cell(numel(diagnostics),1);
for i = 1:numel(diagnostics)
    d = diagnostics(i);
    lines{i} = sprintf('%s [%s] %s', upper(d.severity), d.code, d.message);
    if ~isempty(d.path), lines{i} = [lines{i} ' (' d.path ')']; end
end
end

function text = localStatus(items, diagnostics)
text = sprintf('%d module(s), %d diagnostic(s)', numel(items), numel(diagnostics));
end

function value = localOnOff(test)
if test, value = 'on'; else, value = 'off'; end
end

function value = localColumn(value)
value = cellstr(string(value(:)));
if isempty(value), value = {''}; end
end

function value = localQuote(value)
% POSIX shell quoting is used only for the explicit Open folder action.
value = ['''' strrep(value, '''', '''"''"''') ''''];
end
