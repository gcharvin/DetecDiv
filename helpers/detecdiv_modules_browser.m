function fig = detecdiv_modules_browser(varargin)
%DETECDIV_MODULES_BROWSER Browse built-in DetecDiv pipeline modules.

opts = localParseInputs(varargin{:});
modules = localDiscoverModules(opts.Root);

fig = uifigure('Name', 'DetecDiv built-in modules', 'Position', [120 120 1200 760]);
try
    fig.WindowState = 'maximized';
catch
end

main = uigridlayout(fig, [1 2]);
main.ColumnWidth = {400, '1x'};
main.RowHeight = {'1x'};
main.Padding = [12 12 12 12];
main.ColumnSpacing = 14;

left = uigridlayout(main, [3 1]);
left.RowHeight = {24, '1x', 34};
left.ColumnWidth = {'1x'};
left.Padding = [0 0 0 0];

uilabel(left, 'Text', 'Built-in modules', 'FontWeight', 'bold');
tbl = uitable(left);
tbl.ColumnName = {'Name', 'Type', 'Package'};
tbl.ColumnWidth = {130, 95, 140};
tbl.RowName = {};
tbl.Data = localTableData(modules);

bar = uigridlayout(left, [1 2]);
bar.ColumnWidth = {'1x', 110};
bar.Padding = [0 0 0 0];
status = uilabel(bar, 'Text', sprintf('%d module(s)', numel(modules)));
uibutton(bar, 'Text', 'Refresh', 'ButtonPushedFcn', @refreshModules);

right = uigridlayout(main, [5 1]);
right.RowHeight = {30, 120, '1x', 190, 34};
right.ColumnWidth = {'1x'};
right.Padding = [0 0 0 0];
right.RowSpacing = 10;

titleLabel = uilabel(right, 'Text', 'Select a module', 'FontWeight', 'bold', 'FontSize', 15);
summaryBox = localLabeledTextArea(right, 'Business description');

middle = uigridlayout(right, [1 3]);
middle.ColumnWidth = {'1x', '1x', '1x'};
middle.RowHeight = {'1x'};
middle.Padding = [0 0 0 0];
middle.ColumnSpacing = 10;
contractBox = localLabeledTextArea(middle, 'Prerequisites / behavior');
ioBox = localLabeledTextArea(middle, 'Ports / resources');
paramsBox = localLabeledTextArea(middle, 'Parameters');

codeBox = localLabeledTextArea(right, 'Code and implementation');
buttonRow = uigridlayout(right, [1 3]);
buttonRow.ColumnWidth = {130, 130, '1x'};
buttonRow.Padding = [0 0 0 0];
openFolderButton = uibutton(buttonRow, 'Text', 'Open folder', 'Enable', 'off', 'ButtonPushedFcn', @openSelectedFolder);
copyPathButton = uibutton(buttonRow, 'Text', 'Copy path', 'Enable', 'off', 'ButtonPushedFcn', @copySelectedPath);
uilabel(buttonRow, 'Text', '');

tbl.SelectionChangedFcn = @selectionChanged;
if ~isempty(modules)
    tbl.Selection = [1 1];
    renderModule(1);
end

    function refreshModules(~, ~)
        modules = localDiscoverModules(opts.Root);
        tbl.Data = localTableData(modules);
        status.Text = sprintf('%d module(s)', numel(modules));
        if isempty(modules)
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
            if ~isempty(event.Selection)
                row = event.Selection(1, 1);
            end
        catch
            try
                if ~isempty(tbl.Selection)
                    row = tbl.Selection(1, 1);
                end
            catch
            end
        end
        if isempty(row) || row < 1 || row > numel(modules)
            renderEmpty();
            return;
        end
        renderModule(row);
    end

    function renderEmpty()
        titleLabel.Text = 'No module selected';
        summaryBox.Value = {'No built-in module was found.'};
        contractBox.Value = {''};
        ioBox.Value = {''};
        paramsBox.Value = {''};
        codeBox.Value = {''};
        openFolderButton.Enable = 'off';
        copyPathButton.Enable = 'off';
    end

    function renderModule(row)
        m = modules(row);
        titleLabel.Text = sprintf('%s (%s)', m.name, m.type);
        summaryBox.Value = localSummaryLines(m);
        contractBox.Value = localContractLines(m.contract);
        ioBox.Value = localIoLines(m.contract);
        paramsBox.Value = localParamLines(m);
        codeBox.Value = localCodeLines(m);
        openFolderButton.Enable = localOnOff(isfolder(m.path));
        copyPathButton.Enable = localOnOff(~isempty(m.path));
    end

    function m = selectedModule()
        m = [];
        try
            row = tbl.Selection(1, 1);
            if row >= 1 && row <= numel(modules)
                m = modules(row);
            end
        catch
        end
    end

    function openSelectedFolder(~, ~)
        m = selectedModule();
        if isempty(m) || ~isfolder(m.path), return; end
        localOpenPath(m.path);
    end

    function copySelectedPath(~, ~)
        m = selectedModule();
        if isempty(m), return; end
        clipboard('copy', m.path);
        status.Text = ['Copied: ' m.path];
    end
end

function opts = localParseInputs(varargin)
opts = struct('Root', '');
if mod(numel(varargin), 2) ~= 0
    error('detecdiv_modules_browser:BadInputs', 'Use name/value inputs.');
end
for i = 1:2:numel(varargin)
    key = lower(char(string(varargin{i})));
    switch key
        case 'root'
            opts.Root = char(string(varargin{i+1}));
        otherwise
            error('detecdiv_modules_browser:BadInput', 'Unknown option: %s', key);
    end
end
end

function modules = localDiscoverModules(rootDir)
if nargin < 1 || isempty(rootDir)
    rootDir = fileparts(fileparts(mfilename('fullpath')));
end

modules = struct('name', {}, 'type', {}, 'pkg', {}, 'path', {}, ...
    'entrypoint', {}, 'summary', {}, 'contract', {}, 'defaults', {});

modules = [modules, localDataloadingModules(rootDir)]; %#ok<AGROW>
modules = [modules, localPackageModules(rootDir, fullfile(rootDir, 'engine', 'processor'), 'processor')]; %#ok<AGROW>
modules = [modules, localPackageModules(rootDir, fullfile(rootDir, 'engine', 'classification'), 'classifier')]; %#ok<AGROW>
end

function modules = localDataloadingModules(rootDir)
dlDir = fullfile(rootDir, 'engine', 'dataloading');
preferred = { ...
    'dataLoader', 'dataLoader', 'Load raw image data'; ...
    'roiPattern', 'roiPattern', 'Pattern-based ROI definition'; ...
    'roiManual',  'roiManual',  'Manual ROI definition'; ...
    'roiGrid',    'roiGrid',    'Grid/full-frame ROI definition'; ...
    'roiTracked', 'roiTracked', 'Tracked/mobile ROI definition'; ...
    'roiExtract', 'roiExtract', 'Extract ROI H5 image stores' ...
    };

modules = struct('name', {}, 'type', {}, 'pkg', {}, 'path', {}, ...
    'entrypoint', {}, 'summary', {}, 'contract', {}, 'defaults', {});
for i = 1:size(preferred, 1)
    pkgDir = fullfile(dlDir, ['+' preferred{i, 1}]);
    if ~isfolder(pkgDir)
        continue;
    end
    nodeType = preferred{i, 2};
    modules(end+1) = localModuleInfo(preferred{i, 1}, nodeType, '', pkgDir, preferred{i, 3}); %#ok<AGROW>
end
end

function modules = localPackageModules(rootDir, parentDir, nodeType) %#ok<INUSD>
modules = struct('name', {}, 'type', {}, 'pkg', {}, 'path', {}, ...
    'entrypoint', {}, 'summary', {}, 'contract', {}, 'defaults', {});
if ~isfolder(parentDir)
    return;
end

dirs = dir(fullfile(parentDir, '+*'));
dirs = dirs([dirs.isdir]);
[~, idx] = sort({dirs.name});
dirs = dirs(idx);
for i = 1:numel(dirs)
    pkg = erase(dirs(i).name, '+');
    pkgDir = fullfile(parentDir, dirs(i).name);
    modules(end+1) = localModuleInfo(pkg, nodeType, pkg, pkgDir, ''); %#ok<AGROW>
end
end

function info = localModuleInfo(name, nodeType, pkg, modulePath, fallbackSummary)
entrypoint = localEntrypoint(nodeType, pkg);
contract = localContract(nodeType, pkg);
summary = fallbackSummary;
if isfield(contract, 'summary') && ~isempty(contract.summary)
    summary = char(string(contract.summary));
end
defaults = localDefaults(nodeType, pkg);

info = struct( ...
    'name', char(string(name)), ...
    'type', char(string(nodeType)), ...
    'pkg', char(string(pkg)), ...
    'path', char(string(modulePath)), ...
    'entrypoint', char(string(entrypoint)), ...
    'summary', char(string(summary)), ...
    'contract', contract, ...
    'defaults', defaults);
end

function entrypoint = localEntrypoint(nodeType, pkg)
switch lower(char(string(nodeType)))
    case 'dataloader'
        entrypoint = 'dataLoader.process';
    case {'roipattern','roiidentify'}
        entrypoint = 'roiPattern.process';
    case 'roimanual'
        entrypoint = 'roiManual.process';
    case 'roigrid'
        entrypoint = 'roiGrid.process';
    case 'roitracked'
        entrypoint = 'roiTracked.process';
    case 'roiextract'
        entrypoint = 'roiExtract.process';
    case 'processor'
        entrypoint = [char(string(pkg)) '.process'];
    case 'classifier'
        entrypoint = [char(string(pkg)) '.classify'];
    otherwise
        entrypoint = '';
end
end

function contract = localContract(nodeType, pkg)
contract = struct();
try
    if exist('pipelineNodeContract', 'file') == 2
        contract = pipelineNodeContract(nodeType, pkg);
    end
catch ME
    contract = struct('summary', ['Contract unavailable: ' ME.message]);
end
end

function defaults = localDefaults(nodeType, pkg)
defaults = struct();
candidates = {};
switch lower(char(string(nodeType)))
    case 'dataloader'
        candidates = {'dataLoader.setparam'};
    case {'roipattern','roiidentify'}
        candidates = {'roiPattern.setparam'};
    case 'roimanual'
        candidates = {'roiManual.setparam'};
    case 'roigrid'
        candidates = {'roiGrid.setparam'};
    case 'roitracked'
        candidates = {'roiTracked.setparam'};
    case 'roiextract'
        candidates = {'roiExtract.setparam'};
    case 'processor'
        if ~isempty(pkg)
            candidates = {[char(string(pkg)) '.setparam']};
        end
end

for i = 1:numel(candidates)
    try
        defaults = feval(candidates{i}, struct());
        if isstruct(defaults)
            return;
        end
    catch
    end
end
if ~isstruct(defaults)
    defaults = struct();
end
end

function txt = localLabeledTextArea(parent, labelText)
panel = uigridlayout(parent, [2 1]);
panel.RowHeight = {22, '1x'};
panel.ColumnWidth = {'1x'};
panel.Padding = [0 0 0 0];
panel.RowSpacing = 3;
uilabel(panel, 'Text', labelText, 'FontWeight', 'bold');
txt = uitextarea(panel, 'Editable', 'off', 'Value', {labelText});
end

function data = localTableData(modules)
data = cell(numel(modules), 3);
for i = 1:numel(modules)
    data{i,1} = modules(i).name;
    data{i,2} = modules(i).type;
    data{i,3} = modules(i).pkg;
end
end

function lines = localSummaryLines(m)
lines = {
    ['Name: ' m.name]
    ['Type: ' m.type]
    ['Package: ' m.pkg]
    ['Entrypoint: ' m.entrypoint]
    ['Folder: ' m.path]
    ''
    char(string(m.summary))
    };
end

function lines = localContractLines(contract)
lines = {};
if ~isstruct(contract)
    lines = {'No contract found.'};
    return;
end

if isfield(contract, 'summary') && ~isempty(contract.summary)
    lines = [lines; {'Summary:'; char(string(contract.summary)); ''}]; %#ok<AGROW>
end
lines = [lines; {'Prerequisites:'}; localColumn(localRequirementLines(localGetField(contract, 'requirements', struct())))]; %#ok<AGROW>
lines = [lines; {''; 'Binding / resolution:'}; localColumn(localStructTreeLines(localGetField(contract, 'binding', struct()), '- '))]; %#ok<AGROW>
lines = [lines; {''; 'Selectors / output naming:'}; localColumn(localStructTreeLines(localGetField(contract, 'selectors', struct()), '- '))]; %#ok<AGROW>
lines = [lines; {''; 'Capabilities:'}; localColumn(localStructTreeLines(localGetField(contract, 'capabilities', struct()), '- '))]; %#ok<AGROW>
end

function lines = localIoLines(contract)
lines = {};
if ~isstruct(contract)
    lines = {'No contract found.'};
    return;
end
lines = [lines; {'Input ports:'}; localColumn(localPortLines(localGetField(contract, 'in', [])))]; %#ok<AGROW>
lines = [lines; {''; 'Output ports:'}; localColumn(localPortLines(localGetField(contract, 'out', [])))]; %#ok<AGROW>
resources = localGetField(contract, 'resources', struct());
if isstruct(resources)
    lines = [lines; {''; 'Input resources:'}; localColumn(localResourceLines(localGetField(resources, 'in', [])))]; %#ok<AGROW>
    lines = [lines; {''; 'Output resources:'}; localColumn(localResourceLines(localGetField(resources, 'out', [])))]; %#ok<AGROW>
end
end

function lines = localParamLines(m)
lines = {};
contract = m.contract;
if isstruct(contract) && isfield(contract, 'parameters') && isstruct(contract.parameters)
    lines = [lines; {'Contract parameter groups:'}; localColumn(localStructTreeLines(contract.parameters, '- '))]; %#ok<AGROW>
end
if isstruct(contract) && isfield(contract, 'requirements') && isfield(contract.requirements, 'params')
    lines = [lines; {''; 'Required / optional params:'}; localColumn(localStructTreeLines(contract.requirements.params, '- '))]; %#ok<AGROW>
end
if isstruct(m.defaults) && ~isempty(fieldnames(m.defaults))
    lines = [lines; {''; 'Defaults from setparam:'}; localColumn(localStructValueLines(m.defaults))]; %#ok<AGROW>
end
if isempty(lines)
    lines = {'No parameter metadata found.'};
end
end

function lines = localCodeLines(m)
lines = {
    ['Module folder: ' m.path]
    ['Entrypoint: ' m.entrypoint]
    };
files = dir(fullfile(m.path, '*.m'));
if ~isempty(files)
    lines{end+1} = '';
    lines{end+1} = 'MATLAB files:';
    for i = 1:numel(files)
        lines{end+1} = ['- ' files(i).name]; %#ok<AGROW>
    end
end
end

function lines = localPortLines(ports)
if isempty(ports)
    lines = {'- none declared'};
    return;
end
lines = {};
for i = 1:numel(ports)
    item = ports(i);
    name = localGetField(item, 'name', '');
    type = localGetField(item, 'type', '');
    required = localGetField(item, 'required', false);
    source = localGetField(item, 'source', '');
    lines{end+1} = sprintf('- %s : %s | required=%s | source=%s', ...
        char(string(name)), char(string(type)), mat2str(logical(required)), char(string(source))); %#ok<AGROW>
end
end

function lines = localResourceLines(resources)
if isempty(resources)
    lines = {'- none declared'};
    return;
end
lines = {};
for i = 1:numel(resources)
    r = resources(i);
    type = localGetField(r, 'type', '');
    role = localGetField(r, 'role', '');
    symbol = localGetField(r, 'symbol', '');
    param = localGetField(r, 'param', '');
    port = localGetField(r, 'port', '');
    nameParam = localGetField(r, 'nameParam', '');
    required = localGetField(r, 'required', false);
    transfer = localGetField(r, 'transfer', '');
    lines{end+1} = sprintf('- %s | role=%s | symbol=%s | param=%s | port=%s | nameParam=%s | required=%s | transfer=%s', ...
        char(string(type)), char(string(role)), char(string(symbol)), char(string(param)), ...
        char(string(port)), char(string(nameParam)), mat2str(logical(required)), char(string(transfer))); %#ok<AGROW>
end
end

function lines = localRequirementLines(requirements)
if isempty(requirements) || ~isstruct(requirements) || isempty(fieldnames(requirements))
    lines = {'- none declared'};
    return;
end
lines = {};
groups = fieldnames(requirements);
for i = 1:numel(groups)
    groupName = groups{i};
    value = requirements.(groupName);
    if isstruct(value)
        lines{end+1} = ['- ' groupName ':']; %#ok<AGROW>
        lines = [lines; localColumn(localStructTreeLines(value, '  - '))]; %#ok<AGROW>
    else
        lines{end+1} = ['- ' groupName ': ' localValueToText(value)]; %#ok<AGROW>
    end
end
end

function lines = localStructValueLines(S)
fn = fieldnames(S);
lines = cell(numel(fn), 1);
for i = 1:numel(fn)
    lines{i} = ['- ' fn{i} ': ' localValueToText(S.(fn{i}))];
end
end

function lines = localStructTreeLines(S, prefix)
if nargin < 2
    prefix = '- ';
end
if isempty(S) || ~isstruct(S) || isempty(fieldnames(S))
    lines = {'- none declared'};
    return;
end
lines = {};
fn = fieldnames(S);
for i = 1:numel(fn)
    key = fn{i};
    val = S.(key);
    if isstruct(val) && isscalar(val)
        lines{end+1} = [prefix key ':']; %#ok<AGROW>
        lines = [lines; localColumn(localStructTreeLines(val, ['  ' prefix]))]; %#ok<AGROW>
    else
        lines{end+1} = [prefix key ': ' localValueToText(val)]; %#ok<AGROW>
    end
end
end

function out = localColumn(values)
out = cellstr(string(values));
out = out(:);
end

function txt = localValueToText(val)
if ischar(val) || (isstring(val) && isscalar(val))
    txt = char(string(val));
elseif isnumeric(val) || islogical(val)
    txt = mat2str(val);
elseif iscell(val)
    txt = strjoin(cellstr(string(val)), ', ');
else
    txt = ['<' class(val) '>'];
end
end

function val = localGetField(S, fieldName, defaultVal)
val = defaultVal;
try
    if isstruct(S) && isfield(S, fieldName)
        val = S.(fieldName);
    end
catch
end
end

function state = localOnOff(tf)
if tf
    state = 'on';
else
    state = 'off';
end
end

function localOpenPath(pathStr)
if ispc
    winopen(pathStr);
elseif ismac
    system(['open "' pathStr '"']);
else
    system(['xdg-open "' pathStr '" &']);
end
end
