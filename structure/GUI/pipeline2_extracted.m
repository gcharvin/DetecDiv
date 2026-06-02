classdef pipeline2 < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                        matlab.ui.Figure
        FileMenu                        matlab.ui.container.Menu
        NewpipelineMenu                 matlab.ui.container.Menu
        LoadpipelineMenu                matlab.ui.container.Menu
        LoadrecentpipelineMenu          matlab.ui.container.Menu
        SavecurrentpipelineMenu         matlab.ui.container.Menu
        SavepipelineasMenu              matlab.ui.container.Menu
        LoadrunMenu                     matlab.ui.container.Menu
        SaverunMenu                     matlab.ui.container.Menu
        SaverunasMenu                   matlab.ui.container.Menu
        ExportpipelineMenu              matlab.ui.container.Menu
        ParametersPanel                 matlab.ui.container.Panel
        RunButton                       matlab.ui.control.Button
        CheckpipelineButton             matlab.ui.control.Button
        CloseappButton                  matlab.ui.control.Button
        PipelineandRuncheckreportLabel  matlab.ui.control.Label
        RuninformationhereLabel         matlab.ui.control.Label
        TabGroup                        matlab.ui.container.TabGroup
        SubtypeDropDown                 matlab.ui.control.DropDown
        SubtypeDropDownLabel            matlab.ui.control.Label
        AdvancedmodeCheckBox            matlab.ui.control.CheckBox
        IdEditField                     matlab.ui.control.EditField
        IdEditFieldLabel                matlab.ui.control.Label
        TypeDropDown                    matlab.ui.control.DropDown
        TypeDropDownLabel               matlab.ui.control.Label
        RuntimeTab                      matlab.ui.container.Tab
        RuntimeInputsTab                matlab.ui.container.Tab
        SelectedmodulesLabel            matlab.ui.control.Label
        UISelectedModuleTable           matlab.ui.control.Table
        ResumeoptionsDropDown           matlab.ui.control.DropDown
        ResumeoptionsDropDownLabel      matlab.ui.control.Label
        ExecutionDropDown               matlab.ui.control.DropDown
        ExecutionDropDownLabel          matlab.ui.control.Label
        PathProjectBox                  matlab.ui.control.ListBox
        ListofpathprojectsLabel         matlab.ui.control.Label
        UIFOVTable                      matlab.ui.control.Table
        BuildPanel                      matlab.ui.container.Panel
        UIWorkspacePipelineTable        matlab.ui.control.Table
        DeleteselectedButton            matlab.ui.control.Button
        InsertbeforeselectedButton      matlab.ui.control.Button
        MergegraphButton                matlab.ui.control.Button
        ForkgraphButton                 matlab.ui.control.Button
        GraphPanel                      matlab.ui.container.Panel
        UIGraphAxes                     matlab.ui.control.UIAxes
    end

    properties (Access = private)
        Data struct = struct( ...
            'nodes', struct([]), ...
            'edges', struct('from',{},'to',{},'fromPort',{},'toPort',{},'condition',{}), ...
            'runMode', false)
        SelectedNodeIndex double = NaN
        NodeCounter double = 0
        BlockHandles = gobjects(0)
        GhostHandles = gobjects(0)
        EdgeHandles = gobjects(0)
        ModuleContextMenu matlab.ui.container.ContextMenu
        GraphContextMenu matlab.ui.container.ContextMenu
        DynamicModuleTabs = gobjects(0)
        AvailableModules cell = {}
        IsRefreshingTabs logical = false
        RuntimeFieldHandles struct = struct()
        RuntimeButtonHandles struct = struct()
        RuntimeValues struct = struct()
        RuntimeNodeParams struct = struct()
        RuntimeParseInfo struct = struct()
        HubFieldHandles struct = struct()
        RunArtifactButtonHandles struct = struct()
        CurrentPipeline = []
        CurrentPipelinePath char = ''
        CurrentPipelineWorkspaceVar char = ''
        CurrentRun = []
        CurrentRunPath char = ''
        CurrentProject = []
        CurrentProjectVarName char = ''
        RoiManualPreviewHandles cell = {}
        RoiManualPreviewListeners cell = {}
        RoiManualSelectedRectangle double = NaN
    end

    methods (Access = private)

        function startupFcn(app)
            app.UIFigure.Name = 'pipelineGUI2';
            app.AvailableModules = defaultModuleLibrary(app);

            configureControls(app);
            refreshAvailableModuleTable(app);
            refreshSelectedModuleTable(app);
            redrawGraph(app);
            refreshValidationReport(app);
        end

        function configureControls(app)
            app.UIGraphAxes.XTick = [];
            app.UIGraphAxes.YTick = [];
            app.UIGraphAxes.Box = 'on';
            app.UIGraphAxes.Toolbar.Visible = 'off';
            title(app.UIGraphAxes, '');
            xlabel(app.UIGraphAxes, '');
            ylabel(app.UIGraphAxes, '');
            zlabel(app.UIGraphAxes, '');
            app.UIFigure.Position = [80 80 1240 960];
            app.GraphPanel.Position = [13 628 1214 304];
            app.UIGraphAxes.Position = [15 9 1184 265];
            app.ParametersPanel.Position = [13 14 1214 598];
            app.TabGroup.Position = [18 51 820 465];
            app.RuninformationhereLabel.Position = [214 516 610 22];
            app.PipelineandRuncheckreportLabel.Position = [862 25 335 485];
            app.BuildPanel.Visible = 'off';

            app.TypeDropDown.Items = {'dataLoader','ROI definition','roiExtract','processor','classifier'};
            app.TypeDropDown.Value = 'dataLoader';
            app.TypeDropDown.ValueChangedFcn = createCallbackFcn(app, @TypeDropDownValueChanged, true);
            updateSubtypeChoices(app);
            app.SubtypeDropDown.ValueChangedFcn = createCallbackFcn(app, @SubtypeDropDownValueChanged, true);
            app.TypeDropDown.Visible = 'off';
            app.TypeDropDownLabel.Visible = 'off';
            app.SubtypeDropDown.Visible = 'off';
            app.SubtypeDropDownLabel.Visible = 'off';
            configureRuntimeTabs(app);
            app.AdvancedmodeCheckBox.ValueChangedFcn = createCallbackFcn(app, @AdvancedmodeCheckBoxValueChanged, true);
            app.TabGroup.SelectionChangedFcn = createCallbackFcn(app, @TabGroupSelectionChanged, true);

            app.UIWorkspacePipelineTable.ColumnName = {'Module','Type','Package','Status'};
            app.UIWorkspacePipelineTable.ColumnEditable = false(1,4);
            app.UIWorkspacePipelineTable.ColumnWidth = {82 82 62 'auto'};
            app.UIWorkspacePipelineTable.SelectionChangedFcn = createCallbackFcn(app, @UIWorkspacePipelineTableSelectionChanged, true);

            app.UISelectedModuleTable.ColumnName = {'Run','Module','Type','Package'};
            app.UISelectedModuleTable.ColumnEditable = [true false false false];
            app.UISelectedModuleTable.ColumnWidth = {42 82 70 'auto'};
            app.UISelectedModuleTable.CellEditCallback = @(~,~)selectedModuleTableEdited(app);

            app.ResumeoptionsDropDown.Items = {'Resume previous progress','Restart from scratch'};
            app.ResumeoptionsDropDown.Value = 'Resume previous progress';
            app.ResumeoptionsDropDown.ValueChangedFcn = createCallbackFcn(app, @ResumeoptionsDropDownValueChanged, true);
            app.ExecutionDropDown.Items = {'Auto','GPU','CPU'};
            app.ExecutionDropDown.Value = 'Auto';
            layoutRuntimeOptionsTab(app);
            buildHubRuntimeControls(app);
            buildRunArtifactControls(app);
            buildRuntimeControls(app);

            app.ForkgraphButton.ButtonPushedFcn = createCallbackFcn(app, @ForkgraphButtonPushed, true);
            app.MergegraphButton.ButtonPushedFcn = createCallbackFcn(app, @MergegraphButtonPushed, true);
            app.InsertbeforeselectedButton.ButtonPushedFcn = createCallbackFcn(app, @InsertbeforeselectedButtonPushed, true);
            app.DeleteselectedButton.ButtonPushedFcn = createCallbackFcn(app, @DeleteselectedButtonPushed, true);
            app.CloseappButton.ButtonPushedFcn = createCallbackFcn(app, @CloseappButtonPushed, true);
            app.RunButton.ButtonPushedFcn = createCallbackFcn(app, @RunButtonPushed, true);
            app.CheckpipelineButton.ButtonPushedFcn = createCallbackFcn(app, @CheckpipelineButtonPushed, true);
            app.NewpipelineMenu.MenuSelectedFcn = createCallbackFcn(app, @NewpipelineMenuSelected, true);
            app.LoadpipelineMenu.MenuSelectedFcn = createCallbackFcn(app, @LoadpipelineMenuSelected, true);
            updateRecentPipelinesMenu(app);
            app.SavecurrentpipelineMenu.MenuSelectedFcn = createCallbackFcn(app, @SavecurrentpipelineMenuSelected, true);
            app.SavepipelineasMenu.MenuSelectedFcn = createCallbackFcn(app, @SavepipelineasMenuSelected, true);
            app.LoadrunMenu.MenuSelectedFcn = createCallbackFcn(app, @LoadrunMenuSelected, true);
            app.SaverunMenu.MenuSelectedFcn = createCallbackFcn(app, @SaverunMenuSelected, true);
            app.SaverunasMenu.MenuSelectedFcn = createCallbackFcn(app, @SaverunasMenuSelected, true);
            uimenu(app.FileMenu, 'Text', 'Open current run folder', 'Separator', 'on', ...
                'MenuSelectedFcn', @(~,~)openCurrentRunArtifact(app, 'folder'));
            uimenu(app.FileMenu, 'Text', 'Open current run log', ...
                'MenuSelectedFcn', @(~,~)showCurrentRunLog(app));
            uimenu(app.FileMenu, 'Text', 'Open current run params', ...
                'MenuSelectedFcn', @(~,~)openCurrentRunArtifact(app, 'params'));

            app.RuninformationhereLabel.Text = 'Template mode - click the grey block to add a module.';
            app.PipelineandRuncheckreportLabel.Text = 'No pipeline yet.';
            try
                app.PipelineandRuncheckreportLabel.WordWrap = 'on';
            catch
            end

            app.ModuleContextMenu = uicontextmenu(app.UIFigure);
            addModuleLibraryMenu(app, app.ModuleContextMenu, 'Insert module after...', @(nodeType,pkg)addModuleAfterSelected(app, nodeType, pkg));
            addModuleLibraryMenu(app, app.ModuleContextMenu, 'Insert module before...', @(nodeType,pkg)insertModuleBeforeSelected(app, nodeType, pkg));
            addModuleLibraryMenu(app, app.ModuleContextMenu, 'Change module type...', @(nodeType,pkg)changeSelectedModuleType(app, nodeType, pkg));
            uimenu(app.ModuleContextMenu, 'Text', 'Fork graph', ...
                'MenuSelectedFcn', @(~,~)ForkgraphButtonPushed(app, []));
            uimenu(app.ModuleContextMenu, 'Text', 'Merge graph', ...
                'MenuSelectedFcn', @(~,~)MergegraphButtonPushed(app, []));
            uimenu(app.ModuleContextMenu, 'Text', 'Delete module', ...
                'MenuSelectedFcn', @(~,~)deleteSelectedModule(app));

            app.GraphContextMenu = uicontextmenu(app.UIFigure);
            addModuleLibraryMenu(app, app.GraphContextMenu, 'Add module...', @(nodeType,pkg)addModuleOfType(app, nodeType, pkg));
            try
                app.UIGraphAxes.ContextMenu = app.GraphContextMenu;
            catch
                try, app.UIGraphAxes.UIContextMenu = app.GraphContextMenu; catch, end
            end

            app.IdEditField.ValueChangedFcn = createCallbackFcn(app, @IdEditFieldValueChanged, true);
            updateCommonControlsEnableState(app);
        end

        function configureRuntimeTabs(app)
            app.RuntimeTab.Title = 'Runtime options';
            if isempty(app.RuntimeInputsTab) || ~isvalid(app.RuntimeInputsTab)
                app.RuntimeInputsTab = uitab(app.TabGroup);
                app.RuntimeInputsTab.Title = 'Runtime inputs';
            else
                app.RuntimeInputsTab.Title = 'Runtime inputs';
            end
        end

        function layoutRuntimeOptionsTab(app)
            app.SelectedmodulesLabel.Position = [18 410 130 22];
            app.UISelectedModuleTable.Position = [18 90 320 318];
            app.UISelectedModuleTable.ColumnWidth = {42 132 78 'auto'};

            app.ExecutionDropDownLabel.Position = [388 404 64 22];
            app.ExecutionDropDown.Position = [462 404 120 22];
            app.ResumeoptionsDropDownLabel.Position = [356 368 96 22];
            app.ResumeoptionsDropDown.Position = [462 368 170 22];
        end

        function modules = defaultModuleLibrary(app)
            rootDir = repoRoot(app);
            modules = {};

            modules = appendModuleRows(app, modules, dataloadingModuleRows(app, rootDir));
            modules = appendModuleRows(app, modules, packageModuleRows(app, fullfile(rootDir, 'engine', 'processor'), 'processor'));
            modules = appendModuleRows(app, modules, packageModuleRows(app, fullfile(rootDir, 'engine', 'classification'), 'classifier'));

            if isempty(modules)
                modules = { ...
                    'dataLoader', 'dataLoader', '', 'Load raw image data'; ...
                    'roiPattern', 'roiPattern', '', 'Pattern-based ROI definition'; ...
                    'roiExtract', 'roiExtract', '', 'Extract ROI H5 image stores' ...
                    };
            end
        end

        function rootDir = repoRoot(app) %#ok<INUSD>
            rootDir = pwd;
            try
                appPath = which('pipeline2');
                if ~isempty(appPath)
                    candidate = fileparts(fileparts(fileparts(appPath)));
                    if isfolder(fullfile(candidate, 'engine')) && isfolder(fullfile(candidate, 'structure'))
                        rootDir = candidate;
                    end
                end
            catch
            end
        end

        function rows = dataloadingModuleRows(app, rootDir) %#ok<INUSD>
            rows = {};
            dlDir = fullfile(rootDir, 'engine', 'dataloading');
            preferred = { ...
                'dataLoader', 'dataLoader', '', 'Load raw image data'; ...
                'roiPattern', 'roiPattern', '', 'Pattern-based ROI definition'; ...
                'roiManual',  'roiManual',  '', 'Manual ROI definition'; ...
                'roiGrid',    'roiGrid',    '', 'Grid/full-frame ROI definition'; ...
                'roiTracked', 'roiTracked', '', 'Tracked/mobile ROI definition'; ...
                'roiExtract', 'roiExtract', '', 'Extract ROI H5 image stores' ...
                };
            for i = 1:size(preferred, 1)
                pkgDir = fullfile(dlDir, ['+' preferred{i,1}]);
                if isfolder(pkgDir)
                    rows(end+1,:) = preferred(i,:); %#ok<AGROW>
                end
            end
            if isempty(rows) && isfolder(dlDir)
                dirs = packageDirs(app, dlDir);
                for i = 1:numel(dirs)
                    name = dirs{i};
                    rows(end+1,:) = {name, name, '', ['Dataloading module: ' name]}; %#ok<AGROW>
                end
            end
        end

        function rows = packageModuleRows(app, parentDir, nodeType)
            rows = {};
            dirs = packageDirs(app, parentDir);
            for i = 1:numel(dirs)
                pkg = dirs{i};
                rows(end+1,:) = {pkg, nodeType, pkg, moduleDescription(app, nodeType, pkg)}; %#ok<AGROW>
            end
        end

        function names = packageDirs(app, parentDir) %#ok<INUSD>
            names = {};
            if ~isfolder(parentDir)
                return;
            end
            d = dir(parentDir);
            for i = 1:numel(d)
                if ~d(i).isdir || ~startsWith(d(i).name, '+')
                    continue;
                end
                name = erase(d(i).name, '+');
                if isempty(name)
                    continue;
                end
                names{end+1} = name; %#ok<AGROW>
            end
            names = sort(unique(names, 'stable'));
        end

        function txt = moduleDescription(app, nodeType, pkg) %#ok<INUSD>
            switch lower(char(string(nodeType)))
                case 'processor'
                    txt = ['Processor package: ' char(string(pkg))];
                case 'classifier'
                    txt = ['Classifier package: ' char(string(pkg))];
                otherwise
                    txt = ['Pipeline module: ' char(string(pkg))];
            end
        end

        function out = appendModuleRows(app, out, rows) %#ok<INUSD>
            if isempty(rows)
                return;
            end
            if isempty(out)
                out = rows;
            else
                out = [out; rows]; %#ok<AGROW>
            end
        end

        function refreshAvailableModuleTable(app)
            app.UIWorkspacePipelineTable.Data = app.AvailableModules;
        end

        function refreshSelectedModuleTable(app)
            nodes = app.Data.nodes;
            previous = currentSelectedRunMap(app);
            data = cell(numel(nodes), 4);
            for i = 1:numel(nodes)
                nodeId = char(string(getField(app, nodes(i), 'id', '')));
                if isKey(previous, nodeId)
                    data{i,1} = previous(nodeId);
                else
                    data{i,1} = true;
                end
                data{i,2} = nodeId;
                data{i,3} = char(string(getField(app, nodes(i), 'type', '')));
                data{i,4} = char(string(getField(app, nodes(i), 'pkg', '')));
            end
            app.UISelectedModuleTable.Data = data;
        end

        function map = currentSelectedRunMap(app)
            map = containers.Map('KeyType', 'char', 'ValueType', 'logical');
            try
                data = app.UISelectedModuleTable.Data;
                for i = 1:size(data, 1)
                    nodeId = char(string(data{i,2}));
                    if isempty(nodeId)
                        continue;
                    end
                    include = true;
                    try
                        include = logical(data{i,1});
                    catch
                    end
                    map(nodeId) = include;
                end
            catch
            end
        end

        function selectedModuleTableEdited(app)
            redrawGraph(app);
            refreshModuleTabs(app);
            refreshValidationReport(app);
        end

        function IdEditFieldValueChanged(app, event) %#ok<INUSD>
            if isnan(app.SelectedNodeIndex) || app.SelectedNodeIndex < 1 || app.SelectedNodeIndex > numel(app.Data.nodes)
                return;
            end
            oldId = char(string(app.Data.nodes(app.SelectedNodeIndex).id));
            newId = matlab.lang.makeValidName(strtrim(char(string(app.IdEditField.Value))));
            if isempty(newId)
                newId = oldId;
            end
            ids = {app.Data.nodes.id};
            otherIdx = setdiff(1:numel(ids), app.SelectedNodeIndex);
            if any(strcmp(ids(otherIdx), newId))
                newId = makeUniqueNodeId(app, newId);
            end
            app.IdEditField.Value = newId;
            app.Data.nodes(app.SelectedNodeIndex).id = newId;
            app.Data.nodes(app.SelectedNodeIndex).name = newId;
            app.Data.edges = replaceNodeIdInEdges(app, app.Data.edges, oldId, newId);
            renameRuntimeNodeParams(app, oldId, newId);
            renameSymbolicBindingReferences(app, oldId, newId);
            refreshSelectedModuleTable(app);
            redrawGraph(app);
            refreshModuleTabs(app);
            refreshValidationReport(app);
            updateCommonControlsEnableState(app);
        end

        function TypeDropDownValueChanged(app, event) %#ok<INUSD>
            updateSubtypeChoices(app);
            applyTypeControlsToSelectedNode(app);
        end

        function SubtypeDropDownValueChanged(app, event) %#ok<INUSD>
            applyTypeControlsToSelectedNode(app);
        end

        function AdvancedmodeCheckBoxValueChanged(app, event) %#ok<INUSD>
            if isnan(app.SelectedNodeIndex) || app.SelectedNodeIndex < 1 || app.SelectedNodeIndex > numel(app.Data.nodes)
                return;
            end
            app.Data.nodes(app.SelectedNodeIndex).uiAdvanced = logical(app.AdvancedmodeCheckBox.Value);
            rebuildSelectedModuleTab(app);
        end

        function ResumeoptionsDropDownValueChanged(app, event) %#ok<INUSD>
            applyRecommendedOutputPolicyForResume(app);
            updateRuntimeInputStates(app);
            refreshValidationReport(app);
        end

        function TabGroupSelectionChanged(app, event)
            if app.IsRefreshingTabs
                return;
            end
            tab = event.NewValue;
            if isempty(tab) || ~isvalid(tab) || ~isstruct(tab.UserData) || ~isfield(tab.UserData, 'nodeId')
                return;
            end
            ids = {app.Data.nodes.id};
            idx = find(strcmp(ids, char(string(tab.UserData.nodeId))), 1);
            if isempty(idx) || isequal(idx, app.SelectedNodeIndex)
                return;
            end
            selectNode(app, idx);
        end

        function applyTypeControlsToSelectedNode(app)
            if isnan(app.SelectedNodeIndex) || app.SelectedNodeIndex < 1 || app.SelectedNodeIndex > numel(app.Data.nodes)
                return;
            end
            [nodeType, pkg] = selectedModuleTypeAndPackage(app);
            node = app.Data.nodes(app.SelectedNodeIndex);
            if strcmp(char(string(getField(app, node, 'type', ''))), nodeType) && strcmp(char(string(getField(app, node, 'pkg', ''))), pkg)
                return;
            end
            node.type = nodeType;
            node.pkg = pkg;
            node.func = defaultNodeFunction(app, nodeType, pkg);
            node.gui = defaultNodeGui(app, nodeType, pkg);
            node.params = applyRuntimeDefaultsToParams(app, nodeType, defaultNodeParams(app, nodeType, pkg));
            if isfield(node, 'contract')
                node = rmfield(node, 'contract');
            end
            node.contract = pipelineNodeContract(node);
            node.inputs = portNames(app, node.contract, 'in');
            node.outputs = portNames(app, node.contract, 'out');
            app.Data.nodes(app.SelectedNodeIndex) = node;
            rebuildEdgesFromLayout(app);
            refreshAfterModelChange(app);
        end

        function updateSubtypeChoices(app)
            typeLabel = char(string(app.TypeDropDown.Value));
            switch lower(typeLabel)
                case 'roi definition'
                    items = {'roiPattern','roiManual','roiGrid','roiTracked'};
                case 'processor'
                    items = {'combineMultipleChannels','computeMetrics','computeLineage','computeRLS','basicObjectTracking','computeMaxProjection'};
                case 'classifier'
                    items = {'cellposesam','cnn_lstm','cnn'};
                otherwise
                    items = {typeLabel};
            end
            app.SubtypeDropDown.Items = items;
            app.SubtypeDropDown.Value = items{1};
        end

        function UIWorkspacePipelineTableSelectionChanged(app, event) %#ok<INUSD>
            sel = app.UIWorkspacePipelineTable.Selection;
            if isempty(sel)
                return;
            end
            row = sel(1,1);
            if row < 1 || row > size(app.AvailableModules, 1)
                return;
            end
            moduleType = app.AvailableModules{row,2};
            pkg = app.AvailableModules{row,3};
            if any(strcmp(moduleType, {'roiPattern','roiManual','roiGrid','roiTracked'}))
                app.TypeDropDown.Value = 'ROI definition';
                updateSubtypeChoices(app);
                app.SubtypeDropDown.Value = moduleType;
            elseif strcmp(moduleType, 'processor')
                app.TypeDropDown.Value = 'processor';
                updateSubtypeChoices(app);
                if any(strcmp(app.SubtypeDropDown.Items, pkg))
                    app.SubtypeDropDown.Value = pkg;
                end
            elseif strcmp(moduleType, 'classifier')
                app.TypeDropDown.Value = 'classifier';
                updateSubtypeChoices(app);
                if any(strcmp(app.SubtypeDropDown.Items, pkg))
                    app.SubtypeDropDown.Value = pkg;
                end
            else
                app.TypeDropDown.Value = moduleType;
                updateSubtypeChoices(app);
            end
            app.RuninformationhereLabel.Text = ['Next module to add: ' app.AvailableModules{row,1}];
        end

        function changeSelectedModuleType(app, nodeType, pkg)
            if isnan(app.SelectedNodeIndex) || app.SelectedNodeIndex < 1 || app.SelectedNodeIndex > numel(app.Data.nodes)
                return;
            end
            node = app.Data.nodes(app.SelectedNodeIndex);
            if strcmp(char(string(getField(app, node, 'type', ''))), nodeType) && strcmp(char(string(getField(app, node, 'pkg', ''))), pkg)
                return;
            end
            node.type = nodeType;
            node.pkg = pkg;
            node.func = defaultNodeFunction(app, nodeType, pkg);
            node.gui = defaultNodeGui(app, nodeType, pkg);
            node.params = applyRuntimeDefaultsToParams(app, nodeType, defaultNodeParams(app, nodeType, pkg));
            if isfield(node, 'contract')
                node = rmfield(node, 'contract');
            end
            node.contract = pipelineNodeContract(node);
            node.inputs = portNames(app, node.contract, 'in');
            node.outputs = portNames(app, node.contract, 'out');
            app.Data.nodes(app.SelectedNodeIndex) = node;
            rebuildEdgesFromLayout(app);
            refreshAfterModelChange(app);
        end

        function addModuleFromCurrentSelection(app)
            choice = chooseModuleFromLibrary(app, 'Add module');
            if isempty(choice)
                return;
            end
            nodeType = choice.type;
            pkg = choice.pkg;
            addModuleOfType(app, nodeType, pkg);
        end

        function addModuleOfType(app, nodeType, pkg)
            app.NodeCounter = app.NodeCounter + 1;
            node = makePipelineNode(app, nodeType, pkg, app.NodeCounter);

            if isempty(app.Data.nodes)
                node.layout = [1 1 1 1];
            else
                maxCol = max(arrayfun(@(n) getLayoutCol(app, n), app.Data.nodes));
                node.layout = [maxCol + 1 1 1 1];
            end

            app.Data.nodes = appendStruct(app, app.Data.nodes, node);
            app.SelectedNodeIndex = numel(app.Data.nodes);
            rebuildEdgesFromLayout(app);
            refreshAfterModelChange(app);
        end

        function addModuleAfterSelected(app, nodeType, pkg)
            if isnan(app.SelectedNodeIndex) || app.SelectedNodeIndex < 1 || app.SelectedNodeIndex > numel(app.Data.nodes)
                addModuleOfType(app, nodeType, pkg);
                return;
            end
            targetCol = getLayoutCol(app, app.Data.nodes(app.SelectedNodeIndex)) + 1;
            targetRow = getLayoutRow(app, app.Data.nodes(app.SelectedNodeIndex));
            for i = 1:numel(app.Data.nodes)
                if getLayoutCol(app, app.Data.nodes(i)) >= targetCol
                    app.Data.nodes(i).layout(1) = getLayoutCol(app, app.Data.nodes(i)) + 1;
                end
            end
            app.NodeCounter = app.NodeCounter + 1;
            node = makePipelineNode(app, nodeType, pkg, app.NodeCounter);
            node.layout = [targetCol targetRow 1 1];
            app.Data.nodes = appendStruct(app, app.Data.nodes, node);
            app.SelectedNodeIndex = numel(app.Data.nodes);
            app.Data.nodes = sortNodesByLayout(app, app.Data.nodes);
            app.SelectedNodeIndex = find(strcmp({app.Data.nodes.id}, node.id), 1);
            rebuildEdgesFromLayout(app);
            refreshAfterModelChange(app);
        end

        function insertModuleBeforeSelected(app, nodeType, pkg)
            if isnan(app.SelectedNodeIndex) || app.SelectedNodeIndex < 1 || app.SelectedNodeIndex > numel(app.Data.nodes)
                uialert(app.UIFigure, 'Select a module before inserting.', 'Insert module', 'Icon', 'info');
                return;
            end
            if nargin < 2
                choice = chooseModuleFromLibrary(app, 'Insert module before selected');
                if isempty(choice)
                    return;
                end
                nodeType = choice.type;
                pkg = choice.pkg;
            end
            targetCol = getLayoutCol(app, app.Data.nodes(app.SelectedNodeIndex));
            targetRow = getLayoutRow(app, app.Data.nodes(app.SelectedNodeIndex));
            for i = 1:numel(app.Data.nodes)
                if getLayoutCol(app, app.Data.nodes(i)) >= targetCol
                    app.Data.nodes(i).layout(1) = getLayoutCol(app, app.Data.nodes(i)) + 1;
                end
            end
            app.NodeCounter = app.NodeCounter + 1;
            node = makePipelineNode(app, nodeType, pkg, app.NodeCounter);
            node.layout = [targetCol targetRow 1 1];
            app.Data.nodes = appendStruct(app, app.Data.nodes, node);
            app.SelectedNodeIndex = numel(app.Data.nodes);
            app.Data.nodes = sortNodesByLayout(app, app.Data.nodes);
            app.SelectedNodeIndex = find(strcmp({app.Data.nodes.id}, node.id), 1);
            rebuildEdgesFromLayout(app);
            refreshAfterModelChange(app);
        end

        function nodes = sortNodesByLayout(app, nodes)
            if numel(nodes) < 2
                return;
            end
            cols = arrayfun(@(n)getLayoutCol(app, n), nodes);
            rows = arrayfun(@(n)getLayoutRow(app, n), nodes);
            [~, order] = sortrows([cols(:) rows(:)], [1 2]);
            nodes = nodes(order);
        end

        function [nodeType, pkg] = selectedModuleTypeAndPackage(app)
            typeLabel = char(string(app.TypeDropDown.Value));
            subtype = char(string(app.SubtypeDropDown.Value));
            pkg = '';
            switch lower(typeLabel)
                case 'roi definition'
                    nodeType = subtype;
                case 'processor'
                    nodeType = 'processor';
                    pkg = subtype;
                case 'classifier'
                    nodeType = 'classifier';
                    pkg = subtype;
                otherwise
                    nodeType = typeLabel;
            end
        end

        function [nodeType, pkg] = selectedLibraryModuleTypeAndPackage(app)
            modules = app.AvailableModules;
            row = [];
            try
                sel = app.UIWorkspacePipelineTable.Selection;
                if ~isempty(sel)
                    row = sel(1,1);
                end
            catch
                row = [];
            end
            if isempty(row) || row < 1 || row > size(modules, 1)
                row = 1;
            end
            nodeType = char(string(modules{row,2}));
            pkg = char(string(modules{row,3}));
        end

        function addModuleLibraryMenu(app, parentMenu, titleText, callback)
            root = uimenu(parentMenu, 'Text', titleText);
            groups = moduleMenuGroups(app);
            for g = 1:numel(groups)
                typeMenu = uimenu(root, 'Text', groups(g).label);
                for j = 1:numel(groups(g).rows)
                    idx = groups(g).rows(j);
                    nodeType = char(string(app.AvailableModules{idx,2}));
                    pkg = char(string(app.AvailableModules{idx,3}));
                    label = moduleSubtypeLabel(app, idx);
                    nt = nodeType;
                    pk = pkg;
                    uimenu(typeMenu, 'Text', label, ...
                        'MenuSelectedFcn', @(~,~)callback(nt, pk));
                end
            end
        end

        function groups = moduleMenuGroups(app)
            groups = struct('key', {}, 'label', {}, 'rows', {});
            for i = 1:size(app.AvailableModules, 1)
                nodeType = char(string(app.AvailableModules{i,2}));
                [key, label] = moduleTypeMenuGroup(app, nodeType);
                idx = find(strcmp({groups.key}, key), 1);
                if isempty(idx)
                    groups(end+1) = struct('key', key, 'label', label, 'rows', i); %#ok<AGROW>
                else
                    groups(idx).rows(end+1) = i;
                end
            end
        end

        function [key, label] = moduleTypeMenuGroup(app, nodeType) %#ok<INUSD>
            switch lower(char(string(nodeType)))
                case 'dataloader'
                    key = 'dataLoader';
                    label = 'Data loader';
                case {'roipattern','roimanual','roigrid','roitracked'}
                    key = 'roi';
                    label = 'ROI definition';
                case 'roiextract'
                    key = 'roiExtract';
                    label = 'ROI extract';
                case 'processor'
                    key = 'processor';
                    label = 'Processor';
                case 'classifier'
                    key = 'classifier';
                    label = 'Classifier';
                otherwise
                    key = char(string(nodeType));
                    label = char(string(nodeType));
            end
        end

        function label = moduleSubtypeLabel(app, idx) %#ok<INUSD>
            nodeType = char(string(app.AvailableModules{idx,2}));
            pkg = char(string(app.AvailableModules{idx,3}));
            name = char(string(app.AvailableModules{idx,1}));
            if any(strcmpi(nodeType, {'roiPattern','roiManual','roiGrid','roiTracked'}))
                label = nodeType;
            elseif isempty(pkg)
                label = name;
            else
                label = pkg;
            end
        end

        function choice = chooseModuleFromLibrary(app, titleText)
            choice = [];
            labels = cell(size(app.AvailableModules, 1), 1);
            for i = 1:size(app.AvailableModules, 1)
                labels{i} = moduleLibraryLabel(app, i);
            end
            [idx, ok] = listdlg('PromptString', titleText, ...
                'SelectionMode', 'single', ...
                'ListString', labels, ...
                'ListSize', [260 220], ...
                'Name', titleText);
            if ~ok || isempty(idx)
                return;
            end
            choice = struct( ...
                'type', char(string(app.AvailableModules{idx,2})), ...
                'pkg', char(string(app.AvailableModules{idx,3})));
        end

        function label = moduleLibraryLabel(app, idx) %#ok<INUSD>
            nodeType = char(string(app.AvailableModules{idx,2}));
            pkg = char(string(app.AvailableModules{idx,3}));
            name = char(string(app.AvailableModules{idx,1}));
            if isempty(pkg)
                label = [name ' (' nodeType ')'];
            else
                label = [name ' (' nodeType ' / ' pkg ')'];
            end
        end

        function node = makePipelineNode(app, nodeType, pkg, idx)
            baseId = lower(regexprep([nodeType '_' char(string(pkg))], '[^a-zA-Z0-9]+', '_'));
            baseId = regexprep(baseId, '_+$', '');
            if isempty(baseId)
                baseId = 'module';
            end
            nodeId = sprintf('%s_%d', baseId, idx);

            node = struct();
            node.id = nodeId;
            node.name = nodeId;
            node.type = nodeType;
            node.pkg = pkg;
            node.func = defaultNodeFunction(app, nodeType, pkg);
            node.gui = defaultNodeGui(app, nodeType, pkg);
            node.guiMode = 'replace';
            node.params = applyRuntimeDefaultsToParams(app, nodeType, defaultNodeParams(app, nodeType, pkg));
            node.enabled = true;
            node.status = '';
            node.layout = [1 1 1 1];
            node.uiAdvanced = false;
            node.contract = pipelineNodeContract(node);
            node.inputs = portNames(app, node.contract, 'in');
            node.outputs = portNames(app, node.contract, 'out');
        end

        function f = defaultNodeFunction(app, nodeType, pkg) %#ok<INUSD>
            switch lower(char(string(nodeType)))
                case 'dataloader'
                    f = 'dataLoader.process';
                case {'roipattern','roiidentify'}
                    f = 'roiPattern.process';
                case 'roimanual'
                    f = 'roiManual.process';
                case 'roigrid'
                    f = 'roiGrid.process';
                case 'roitracked'
                    f = 'roiTracked.process';
                case 'roiextract'
                    f = 'roiExtract.process';
                case 'processor'
                    f = [char(string(pkg)) '.process'];
                case 'classifier'
                    f = [char(string(pkg)) '.classify'];
                otherwise
                    f = '';
            end
        end

        function g = defaultNodeGui(app, nodeType, pkg) %#ok<INUSD>
            switch lower(char(string(nodeType)))
                case 'dataloader'
                    g = 'dataLoader.ui';
                case {'roipattern','roiidentify'}
                    g = 'roiPattern.ui';
                case 'roimanual'
                    g = 'roiManual.ui';
                case 'roigrid'
                    g = 'roiGrid.ui';
                case 'roitracked'
                    g = 'roiTracked.ui';
                case 'roiextract'
                    g = 'roiExtract.ui';
                otherwise
                    g = '';
            end
        end

        function p = defaultNodeParams(app, nodeType, pkg) %#ok<INUSD>
            p = struct();
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
                case {'processor','classifier'}
                    if ~isempty(pkg)
                        candidates = {[char(string(pkg)) '.setparam']};
                    end
            end

            for i = 1:numel(candidates)
                try
                    p = feval(candidates{i}, struct());
                    return;
                catch
                end
            end

            if strcmpi(nodeType, 'processor') || strcmpi(nodeType, 'classifier')
                p.pkg = pkg;
                if strcmpi(nodeType, 'classifier')
                    switch lower(char(string(pkg)))
                        case 'cnn_lstm'
                            p.outputName = 'div_1';
                        case 'cellposesam'
                            p.outputName = 'cellposeSAM';
                        otherwise
                            p.outputName = char(string(pkg));
                    end
                end
            end
        end

        function params = applyRuntimeDefaultsToParams(app, nodeType, params)
            if ~strcmpi(char(string(nodeType)), 'dataLoader')
                return;
            end
            rawDataPath = getRuntimeValue(app, 'rawDataPath');
            if isempty(strtrim(rawDataPath))
                return;
            end
            if ~isstruct(params)
                params = struct();
            end
            params.path = rawDataPath;
        end

        function names = portNames(app, contract, direction) %#ok<INUSD>
            names = {};
            if ~isstruct(contract)
                return;
            end
            fieldName = 'in';
            if strcmp(direction, 'out')
                fieldName = 'out';
            end
            if isfield(contract, fieldName) && ~isempty(contract.(fieldName))
                names = {contract.(fieldName).name};
            end
        end

        function redrawGraph(app)
            cla(app.UIGraphAxes);
            hold(app.UIGraphAxes, 'on');
            app.BlockHandles = gobjects(0);
            app.GhostHandles = gobjects(0);
            app.EdgeHandles = gobjects(0);

            nodes = app.Data.nodes;
            selectedRunIds = selectedRunNodeIds(app);
            blockW = 1.55;
            blockH = 0.75;
            gapX = 0.55;
            gapY = 0.28;

            drawImplicitEdges(app, blockW, blockH, gapX, gapY);

            for i = 1:numel(nodes)
                col = getLayoutCol(app, nodes(i));
                row = getLayoutRow(app, nodes(i));
                x = (col - 1) * (blockW + gapX);
                y = -(row - 1) * (blockH + gapY);
                selected = isequal(i, app.SelectedNodeIndex);
                runSelected = isempty(selectedRunIds) || any(strcmp(selectedRunIds, char(string(getField(app, nodes(i), 'id', '')))));
                face = [0.90 0.94 0.98];
                edge = [0.24 0.36 0.50];
                textColor = [0.14 0.18 0.22];
                subTextColor = [0.25 0.25 0.25];
                if ~runSelected
                    face = [0.88 0.88 0.88];
                    edge = [0.68 0.68 0.68];
                    textColor = [0.48 0.48 0.48];
                    subTextColor = [0.58 0.58 0.58];
                end
                if selected
                    if runSelected
                        face = [0.78 0.88 1.00];
                        edge = [0.05 0.32 0.68];
                    else
                        face = [0.84 0.88 0.92];
                        edge = [0.36 0.42 0.48];
                    end
                end
                h = rectangle(app.UIGraphAxes, 'Position', [x y blockW blockH], ...
                    'Curvature', 0.08, 'FaceColor', face, 'EdgeColor', edge, ...
                    'LineWidth', ternary(app, selected, 1.8, 1.5), 'ButtonDownFcn', @(~,~)selectNode(app, i));
                h.UIContextMenu = app.ModuleContextMenu;
                t1 = text(app.UIGraphAxes, x + blockW/2, y + blockH*0.60, ...
                    char(string(getField(app, nodes(i), 'id', 'module'))), ...
                    'HorizontalAlignment', 'center', 'Interpreter', 'none', ...
                    'FontWeight', 'bold', 'FontSize', 9, 'Color', textColor, 'ButtonDownFcn', @(~,~)selectNode(app, i));
                t1.UIContextMenu = app.ModuleContextMenu;
                t2 = text(app.UIGraphAxes, x + blockW/2, y + blockH*0.28, ...
                    blockTypeLabel(app, nodes(i)), ...
                    'HorizontalAlignment', 'center', 'Interpreter', 'none', ...
                    'FontSize', 8, 'Color', subTextColor, 'ButtonDownFcn', @(~,~)selectNode(app, i));
                t2.UIContextMenu = app.ModuleContextMenu;
                app.BlockHandles(end+1:end+3) = [h t1 t2]; %#ok<AGROW>
            end

            if isempty(nodes)
                ghostCol = 1;
            else
                ghostCol = max(arrayfun(@(n) getLayoutCol(app, n), nodes)) + 1;
            end
            gx = (ghostCol - 1) * (blockW + gapX);
            gy = 0;
            gh = rectangle(app.UIGraphAxes, 'Position', [gx gy blockW blockH], ...
                'Curvature', 0.08, 'FaceColor', [0.92 0.92 0.92], ...
                'EdgeColor', [0.55 0.55 0.55], 'LineStyle', '--', ...
                'LineWidth', 1.4, 'ButtonDownFcn', @(~,~)addModuleFromCurrentSelection(app));
            gh.UIContextMenu = app.GraphContextMenu;
            gt = text(app.UIGraphAxes, gx + blockW/2, gy + blockH/2, '+ module', ...
                'HorizontalAlignment', 'center', 'Interpreter', 'none', ...
                'Color', [0.35 0.35 0.35], 'FontWeight', 'bold', ...
                'ButtonDownFcn', @(~,~)addModuleFromCurrentSelection(app));
            gt.UIContextMenu = app.GraphContextMenu;
            app.GhostHandles = [gh gt];

            maxCol = max(ghostCol, 3);
            maxRow = 1;
            if ~isempty(nodes)
                maxRow = max(arrayfun(@(n) getLayoutRow(app, n), nodes));
            end
            xlim(app.UIGraphAxes, [-0.3 maxCol * (blockW + gapX)]);
            ylim(app.UIGraphAxes, [-(maxRow) * (blockH + gapY) blockH + 0.35]);
            axis(app.UIGraphAxes, 'manual');
            hold(app.UIGraphAxes, 'off');
        end

        function drawImplicitEdges(app, blockW, blockH, gapX, gapY)
            nodes = app.Data.nodes;
            edges = app.Data.edges;
            if isempty(nodes) || isempty(edges)
                return;
            end
            ids = {nodes.id};
            selectedRunIds = selectedRunNodeIds(app);
            for i = 1:numel(edges)
                srcIdx = find(strcmp(ids, char(string(edges(i).from))), 1);
                dstIdx = find(strcmp(ids, char(string(edges(i).to))), 1);
                if isempty(srcIdx) || isempty(dstIdx)
                    continue;
                end
                src = nodes(srcIdx);
                dst = nodes(dstIdx);
                x1 = (getLayoutCol(app, src) - 1) * (blockW + gapX) + blockW;
                y1 = -(getLayoutRow(app, src) - 1) * (blockH + gapY) + blockH/2;
                x2 = (getLayoutCol(app, dst) - 1) * (blockW + gapX);
                y2 = -(getLayoutRow(app, dst) - 1) * (blockH + gapY) + blockH/2;
                srcSelected = isempty(selectedRunIds) || any(strcmp(selectedRunIds, char(string(src.id))));
                dstSelected = isempty(selectedRunIds) || any(strcmp(selectedRunIds, char(string(dst.id))));
                if ~(srcSelected && dstSelected)
                    edgeColor = [0.72 0.72 0.72];
                    edgeWidth = 1.0;
                elseif edgeContractsCompatible(app, src, dst)
                    edgeColor = [0.10 0.55 0.28];
                    edgeWidth = 1.8;
                else
                    edgeColor = [0.72 0.48 0.18];
                    edgeWidth = 1.2;
                end
                h = quiver(app.UIGraphAxes, x1, y1, x2 - x1, y2 - y1, 0, ...
                    'Color', edgeColor, ...
                    'LineWidth', edgeWidth, ...
                    'MaxHeadSize', 0.45, ...
                    'AutoScale', 'off', ...
                    'HitTest', 'off');
                app.EdgeHandles(end+1) = h; %#ok<AGROW>
            end
        end

        function tf = edgeContractsCompatible(app, src, dst)
            tf = false;
            try
                srcContract = pipelineNodeContract(src);
                dstContract = pipelineNodeContract(dst);
                srcOut = getField(app, srcContract, 'out', struct([]));
                dstIn = getField(app, dstContract, 'in', struct([]));
                for i = 1:numel(srcOut)
                    for j = 1:numel(dstIn)
                        if compatiblePortTypes(app, char(string(srcOut(i).type)), char(string(dstIn(j).type)))
                            tf = true;
                            return;
                        end
                    end
                end
            catch
                tf = false;
            end
        end

        function tf = compatiblePortTypes(app, outType, inType) %#ok<INUSD>
            outType = lower(char(string(outType)));
            inType = lower(char(string(inType)));
            tf = strcmp(outType, inType);
            if tf
                return;
            end
            if strcmp(outType, 'dataseriesset') && strcmp(inType, 'dataseriesset')
                tf = true;
            elseif strcmp(outType, 'channelset') && any(strcmp(inType, {'imageset','channelset'}))
                tf = true;
            elseif strcmp(outType, 'imageset') && strcmp(inType, 'imageset')
                tf = true;
            elseif strcmp(outType, 'roilist') && strcmp(inType, 'roilist')
                tf = true;
            elseif strcmp(outType, 'maskset') && strcmp(inType, 'maskset')
                tf = true;
            end
        end

        function label = blockTypeLabel(app, node) %#ok<INUSD>
            label = char(string(getField(app, node, 'type', '')));
            pkg = char(string(getField(app, node, 'pkg', '')));
            if ~isempty(pkg)
                label = [label ' / ' pkg];
            end
        end

        function selectNode(app, idx)
            if idx < 1 || idx > numel(app.Data.nodes)
                return;
            end
            app.SelectedNodeIndex = idx;
            node = app.Data.nodes(idx);
            app.IdEditField.Value = char(string(getField(app, node, 'id', '')));
            app.AdvancedmodeCheckBox.Value = logical(getField(app, node, 'uiAdvanced', false));
            selectTypeControlsForNode(app, node);
            redrawGraph(app);
            selectExistingModuleTab(app, node);
            refreshValidationReport(app);
            updateCommonControlsEnableState(app);
        end

        function selectTypeControlsForNode(app, node)
            nodeType = char(string(getField(app, node, 'type', '')));
            pkg = char(string(getField(app, node, 'pkg', '')));
            if any(strcmpi(nodeType, {'roiPattern','roiManual','roiGrid','roiTracked'}))
                app.TypeDropDown.Value = 'ROI definition';
                updateSubtypeChoices(app);
                app.SubtypeDropDown.Value = nodeType;
            elseif strcmpi(nodeType, 'processor')
                app.TypeDropDown.Value = 'processor';
                updateSubtypeChoices(app);
                if any(strcmp(app.SubtypeDropDown.Items, pkg))
                    app.SubtypeDropDown.Value = pkg;
                end
            elseif strcmpi(nodeType, 'classifier')
                app.TypeDropDown.Value = 'classifier';
                updateSubtypeChoices(app);
                if any(strcmp(app.SubtypeDropDown.Items, pkg))
                    app.SubtypeDropDown.Value = pkg;
                end
            elseif any(strcmp(app.TypeDropDown.Items, nodeType))
                app.TypeDropDown.Value = nodeType;
                updateSubtypeChoices(app);
            end
        end

        function ForkgraphButtonPushed(app, event) %#ok<INUSD>
            if isnan(app.SelectedNodeIndex) || app.SelectedNodeIndex < 1 || app.SelectedNodeIndex > numel(app.Data.nodes)
                uialert(app.UIFigure, 'Select a module before forking.', 'Fork graph', 'Icon', 'info');
                return;
            end
            src = app.Data.nodes(app.SelectedNodeIndex);
            app.NodeCounter = app.NodeCounter + 1;
            node = src;
            node.id = sprintf('%s_branch_%d', char(string(src.id)), app.NodeCounter);
            node.name = node.id;
            node.layout = [getLayoutCol(app, src), nextFreeRowInColumn(app, getLayoutCol(app, src)), 1, 1];
            node.contract = pipelineNodeContract(node);
            app.Data.nodes = appendStruct(app, app.Data.nodes, node);
            app.SelectedNodeIndex = numel(app.Data.nodes);
            rebuildEdgesFromLayout(app);
            refreshAfterModelChange(app);
        end

        function MergegraphButtonPushed(app, event) %#ok<INUSD>
            if isnan(app.SelectedNodeIndex) || app.SelectedNodeIndex < 1 || app.SelectedNodeIndex > numel(app.Data.nodes)
                uialert(app.UIFigure, 'Select a module before merging.', 'Merge graph', 'Icon', 'info');
                return;
            end
            app.Data.nodes(app.SelectedNodeIndex).layout(2) = 1;
            rebuildEdgesFromLayout(app);
            refreshAfterModelChange(app);
        end

        function InsertbeforeselectedButtonPushed(app, event) %#ok<INUSD>
            insertModuleBeforeSelected(app);
        end

        function DeleteselectedButtonPushed(app, event) %#ok<INUSD>
            deleteSelectedModule(app);
        end

        function row = nextFreeRowInColumn(app, col)
            row = 1;
            if isempty(app.Data.nodes)
                return;
            end
            rows = [];
            for i = 1:numel(app.Data.nodes)
                if getLayoutCol(app, app.Data.nodes(i)) == col
                    rows(end+1) = getLayoutRow(app, app.Data.nodes(i)); %#ok<AGROW>
                end
            end
            if ~isempty(rows)
                row = max(rows) + 1;
            end
        end

        function rebuildEdgesFromLayout(app)
            edges = struct('from',{},'to',{},'fromPort',{},'toPort',{},'condition',{});
            nodes = app.Data.nodes;
            if numel(nodes) < 2
                app.Data.edges = edges;
                return;
            end

            cols = unique(arrayfun(@(n) getLayoutCol(app, n), nodes));
            cols = sort(cols);
            for cIdx = 2:numel(cols)
                curCol = cols(cIdx);
                prevCol = cols(cIdx - 1);
                curIdx = find(arrayfun(@(n) getLayoutCol(app, n) == curCol, nodes));
                prevIdx = find(arrayfun(@(n) getLayoutCol(app, n) == prevCol, nodes));
                for ii = 1:numel(curIdx)
                    dstIdx = curIdx(ii);
                    sameRowPrev = prevIdx(arrayfun(@(k) getLayoutRow(app, nodes(k)) == getLayoutRow(app, nodes(dstIdx)), prevIdx));
                    if isempty(sameRowPrev)
                        sameRowPrev = prevIdx;
                    end
                    for jj = 1:numel(sameRowPrev)
                        srcIdx = sameRowPrev(jj);
                        e = struct( ...
                            'from', char(string(nodes(srcIdx).id)), ...
                            'to', char(string(nodes(dstIdx).id)), ...
                            'fromPort', firstPort(app, nodes(srcIdx), 'out'), ...
                            'toPort', firstPort(app, nodes(dstIdx), 'in'), ...
                            'condition', '');
                        edges = appendStruct(app, edges, e); %#ok<AGROW>
                    end
                end
            end
            app.Data.edges = edges;
        end

        function p = firstPort(app, node, direction)
            p = '';
            try
                c = pipelineNodeContract(node);
                if strcmp(direction, 'out') && isfield(c, 'out') && ~isempty(c.out)
                    p = char(string(c.out(1).name));
                elseif strcmp(direction, 'in') && isfield(c, 'in') && ~isempty(c.in)
                    p = char(string(c.in(1).name));
                end
            catch
            end
        end

        function refreshAfterModelChange(app)
            refreshSelectedModuleTable(app);
            refreshCommonControlsFromSelection(app);
            refreshGlobalRuntimeTable(app);
            redrawGraph(app);
            refreshModuleTabs(app);
            refreshValidationReport(app);
            updateCommonControlsEnableState(app);
        end

        function refreshModuleTabs(app)
            app.IsRefreshingTabs = true;
            cleanupObj = onCleanup(@()setRefreshingTabs(app, false)); %#ok<NASGU>
            previousStaticTab = '';
            previousNodeId = '';
            try
                selectedTab = app.TabGroup.SelectedTab;
                if isequal(selectedTab, app.RuntimeTab)
                    previousStaticTab = 'runtimeOptions';
                elseif isequal(selectedTab, app.RuntimeInputsTab)
                    previousStaticTab = 'runtimeInputs';
                elseif isstruct(selectedTab.UserData) && isfield(selectedTab.UserData, 'nodeId')
                    previousNodeId = char(string(selectedTab.UserData.nodeId));
                end
            catch
            end
            deleteDynamicModuleTabs(app);
            nodes = app.Data.nodes;
            for i = 1:numel(nodes)
                node = nodes(i);
                tabTitle = truncateTabTitle(app, getField(app, node, 'id', 'module'));
                t = uitab(app.TabGroup, 'Title', tabTitle);
                t.UserData = struct('nodeId', char(string(node.id)), 'dynamic', true);
                app.DynamicModuleTabs(end+1) = t; %#ok<AGROW>
                buildModuleTab(app, t, node);
            end

            if strcmp(previousStaticTab, 'runtimeOptions') && isvalid(app.RuntimeTab)
                app.TabGroup.SelectedTab = app.RuntimeTab;
            elseif strcmp(previousStaticTab, 'runtimeInputs') && isvalid(app.RuntimeInputsTab)
                app.TabGroup.SelectedTab = app.RuntimeInputsTab;
            elseif ~isempty(previousNodeId)
                restored = false;
                for i = 1:numel(app.DynamicModuleTabs)
                    try
                        ud = app.DynamicModuleTabs(i).UserData;
                        if isstruct(ud) && isfield(ud, 'nodeId') && strcmp(char(string(ud.nodeId)), previousNodeId)
                            app.TabGroup.SelectedTab = app.DynamicModuleTabs(i);
                            restored = true;
                            break;
                        end
                    catch
                    end
                end
                if ~restored && ~isnan(app.SelectedNodeIndex) && app.SelectedNodeIndex >= 1 && app.SelectedNodeIndex <= numel(app.DynamicModuleTabs)
                    app.TabGroup.SelectedTab = app.DynamicModuleTabs(app.SelectedNodeIndex);
                end
            elseif ~isnan(app.SelectedNodeIndex) && app.SelectedNodeIndex >= 1 && app.SelectedNodeIndex <= numel(app.DynamicModuleTabs)
                app.TabGroup.SelectedTab = app.DynamicModuleTabs(app.SelectedNodeIndex);
            end
        end

        function titleText = truncateTabTitle(app, value) %#ok<INUSD>
            titleText = char(string(value));
            if numel(titleText) > 18
                titleText = [titleText(1:15) '...'];
            end
        end

        function refreshGlobalRuntimeTable(app)
            try
                if isvalid(app.UIFOVTable)
                    app.UIFOVTable.Data = { ...
                        'Project / data path', ''; ...
                        'FOV selection', ''; ...
                        'Frame selection', ''; ...
                        'Source channels', ''; ...
                        'ROI selection', '' ...
                        };
                end
            catch
            end
        end

        function buildRuntimeControls(app)
            try, delete(app.UIFOVTable); catch, end
            try, delete(app.PathProjectBox); catch, end
            try, delete(app.ListofpathprojectsLabel); catch, end

            deleteRuntimeInputChildren(app);
            grid = uigridlayout(app.RuntimeInputsTab, [7 4]);
            grid.RowHeight = {32, 32, 32, 32, 96, 32, 32};
            grid.ColumnWidth = {86, '1x', 115, 88};
            grid.Padding = [14 14 14 14];
            grid.RowSpacing = 10;
            grid.ColumnSpacing = 10;

            app.RuntimeFieldHandles = struct();
            app.RuntimeButtonHandles = struct();
            app.RuntimeValues = struct();
            app.RuntimeParseInfo = struct();

            addRuntimeProjectRow(app, grid, 1);
            addRuntimeRow(app, grid, 2, 'Raw data', 'rawDataPath', 'Raw image/data folder used by dataloader', 'Browse...');
            addRuntimeRow(app, grid, 3, 'FOVs', 'fovs', 'all / 1,3,5 / 1:4', 'Pick...');
            addRuntimeRow(app, grid, 4, 'Frames', 'frames', 'all / 1:50 / 1,5,9', 'Pick...');
            addRuntimeInventoryRow(app, grid, 5);
            addRuntimeRow(app, grid, 6, 'ROIs', 'rois', 'all / selected ROI ids', 'Pick...');
            addRuntimePolicyRow(app, grid, 7);
            updateRuntimeInputStates(app);
        end

        function deleteRuntimeInputChildren(app)
            try
                kids = app.RuntimeInputsTab.Children;
                for k = 1:numel(kids)
                    delete(kids(k));
                end
            catch
            end
        end

        function buildHubRuntimeControls(app)
            deleteHubRuntimeControls(app);
            hub = defaultHubSettingsForUi(app);
            app.HubFieldHandles = struct();

            app.HubFieldHandles.executionTargetLabel = uilabel(app.RuntimeTab, ...
                'Text', 'Run target', 'HorizontalAlignment', 'right', 'Position', [374 330 78 22]);
            target = uidropdown(app.RuntimeTab, ...
                'Items', {'Local MATLAB','Hub'}, ...
                'ItemsData', {'local','hub'}, ...
                'Value', 'local', ...
                'Position', [462 330 170 22]);
            target.ValueChangedFcn = @(src,~)hubRuntimeFieldChanged(app, 'executionTarget', src.Value);
            app.HubFieldHandles.executionTarget = target;
            app.RuntimeValues.executionTarget = 'local';

            labels = {'Hub URL','Fallback URLs','User key','Session token','Timeout','Remote root','Local root'};
            keys = {'baseUrl','fallbackBaseUrls','userKey','sessionToken','timeout','defaultRemoteProjectRoot','defaultLocalProjectRoot'};
            defaults = { ...
                getStructText(app, hub, 'baseUrl', 'http://detecdiv-hub.detecdiv.internal'), ...
                strjoin(normalizeHubStringList(app, getStructValue(app, hub, 'fallbackBaseUrls', {'http://127.0.0.1:8000'})), ', '), ...
                getStructText(app, hub, 'userKey', 'localdev'), ...
                getStructText(app, hub, 'sessionToken', ''), ...
                num2str(double(getStructValue(app, hub, 'timeout', 20))), ...
                getStructText(app, hub, 'defaultRemoteProjectRoot', ''), ...
                getStructText(app, hub, 'defaultLocalProjectRoot', '') ...
                };

            y = 292;
            for i = 1:numel(keys)
                lbl = uilabel(app.RuntimeTab, 'Text', labels{i}, 'HorizontalAlignment', 'right', ...
                    'Position', [348 y 104 22]);
                if strcmp(keys{i}, 'timeout')
                    fld = uieditfield(app.RuntimeTab, 'numeric', 'Position', [462 y 170 22], 'Value', str2double(defaults{i}));
                else
                    fld = uieditfield(app.RuntimeTab, 'text', 'Position', [462 y 330 22], 'Value', defaults{i});
                end
                fld.ValueChangedFcn = @(src,~)hubRuntimeFieldChanged(app, '', []);
                app.HubFieldHandles.([keys{i} 'Label']) = lbl;
                app.HubFieldHandles.(keys{i}) = fld;
                y = y - 34;
            end
            updateHubRuntimeControlsVisibility(app);
        end

        function buildRunArtifactControls(app)
            deleteRunArtifactControls(app);
            app.RunArtifactButtonHandles = struct();
            app.RunArtifactButtonHandles.folder = uibutton(app.RuntimeTab, 'push', ...
                'Text', 'Open run folder', 'Position', [660 404 130 24], ...
                'ButtonPushedFcn', @(~,~)openCurrentRunArtifact(app, 'folder'));
            app.RunArtifactButtonHandles.log = uibutton(app.RuntimeTab, 'push', ...
                'Text', 'Run log', 'Position', [660 368 130 24], ...
                'ButtonPushedFcn', @(~,~)showCurrentRunLog(app));
            app.RunArtifactButtonHandles.params = uibutton(app.RuntimeTab, 'push', ...
                'Text', 'Run params', 'Position', [660 332 130 24], ...
                'ButtonPushedFcn', @(~,~)openCurrentRunArtifact(app, 'params'));
        end

        function deleteRunArtifactControls(app)
            if ~isstruct(app.RunArtifactButtonHandles) || isempty(fieldnames(app.RunArtifactButtonHandles))
                return;
            end
            fn = fieldnames(app.RunArtifactButtonHandles);
            for i = 1:numel(fn)
                h = app.RunArtifactButtonHandles.(fn{i});
                try
                    if isvalid(h)
                        delete(h);
                    end
                catch
                end
            end
            app.RunArtifactButtonHandles = struct();
        end

        function deleteHubRuntimeControls(app)
            if ~isstruct(app.HubFieldHandles) || isempty(fieldnames(app.HubFieldHandles))
                return;
            end
            fn = fieldnames(app.HubFieldHandles);
            for i = 1:numel(fn)
                h = app.HubFieldHandles.(fn{i});
                try
                    if isvalid(h)
                        delete(h);
                    end
                catch
                end
            end
            app.HubFieldHandles = struct();
        end

        function hubRuntimeFieldChanged(app, key, value)
            if nargin >= 3 && ~isempty(key)
                app.RuntimeValues.(key) = char(string(value));
            end
            updateHubRuntimeControlsVisibility(app);
            refreshValidationReport(app);
        end

        function updateHubRuntimeControlsVisibility(app)
            if ~isstruct(app.HubFieldHandles) || ~isfield(app.HubFieldHandles, 'executionTarget')
                return;
            end
            isHub = strcmp(char(string(app.HubFieldHandles.executionTarget.Value)), 'hub');
            fn = fieldnames(app.HubFieldHandles);
            for i = 1:numel(fn)
                key = fn{i};
                if any(strcmp(key, {'executionTarget','executionTargetLabel'}))
                    continue;
                end
                try
                    app.HubFieldHandles.(key).Visible = ternary(app, isHub, 'on', 'off');
                catch
                end
            end
        end

        function hub = defaultHubSettingsForUi(app) %#ok<INUSD>
            try
                hub = detecdiv_hub_settings_get();
            catch
                hub = struct('baseUrl', 'http://detecdiv-hub.detecdiv.internal', ...
                    'fallbackBaseUrls', {{'http://127.0.0.1:8000'}}, ...
                    'userKey', 'localdev', 'sessionToken', '', 'timeout', 20, ...
                    'defaultRemoteProjectRoot', '', 'defaultLocalProjectRoot', '');
            end
        end

        function value = getStructValue(app, S, key, defaultValue) %#ok<INUSD>
            value = defaultValue;
            if isstruct(S) && isfield(S, key) && ~isempty(S.(key))
                value = S.(key);
            end
        end

        function value = getStructText(app, S, key, defaultValue)
            value = char(string(getStructValue(app, S, key, defaultValue)));
        end

        function values = normalizeHubStringList(app, value) %#ok<INUSD>
            if isempty(value)
                values = {};
            elseif iscell(value)
                values = cellstr(string(value(:)'));
            elseif isstring(value)
                values = cellstr(value(:)');
            elseif ischar(value)
                values = cellstr(strsplit(value, ','));
            else
                values = cellstr(string(value(:)'));
            end
            values = cellfun(@(s)strtrim(char(string(s))), values, 'UniformOutput', false);
            values = values(~cellfun(@isempty, values));
        end

        function addRuntimeProjectRow(app, grid, row)
            label = uilabel(grid, 'Text', 'Project');
            label.Layout.Row = row;
            label.Layout.Column = 1;

            field = uieditfield(grid, 'text');
            field.Layout.Row = row;
            field.Layout.Column = 2;
            try
                field.Placeholder = 'Current shallow project .mat';
            catch
            end
            field.ValueChangedFcn = @(src,~)runtimeFieldChanged(app, 'projectPath', src.Value);

            dd = uidropdown(grid);
            dd.Layout.Row = row;
            dd.Layout.Column = 3;
            dd.Items = projectDropdownItems(app);
            dd.Value = dd.Items{1};
            dd.ValueChangedFcn = @(src,~)projectDropdownChanged(app, src.Value);

            btn = uibutton(grid, 'push', 'Text', 'Browse...');
            btn.Layout.Row = row;
            btn.Layout.Column = 4;
            btn.Tooltip = 'Load an existing shallow project .mat file.';
            btn.ButtonPushedFcn = @(~,~)runtimeButtonPushed(app, 'projectPath');

            app.RuntimeFieldHandles.projectPath = field;
            app.RuntimeFieldHandles.projectSource = dd;
            app.RuntimeButtonHandles.projectPath = btn;
            app.RuntimeValues.projectPath = '';
        end

        function addRuntimeRow(app, grid, row, labelText, key, placeholder, buttonText)
            label = uilabel(grid, 'Text', labelText);
            label.Layout.Row = row;
            label.Layout.Column = 1;

            field = uieditfield(grid, 'text');
            field.Layout.Row = row;
            field.Layout.Column = [2 3];
            try
                field.Placeholder = placeholder;
            catch
                field.Value = '';
            end
            field.ValueChangedFcn = @(src,~)runtimeFieldChanged(app, key, src.Value);

            btn = uibutton(grid, 'push', 'Text', buttonText);
            btn.Layout.Row = row;
            btn.Layout.Column = 4;
            btn.Tooltip = placeholder;
            btn.ButtonPushedFcn = @(~,~)runtimeButtonPushed(app, key);

            app.RuntimeFieldHandles.(key) = field;
            app.RuntimeButtonHandles.(key) = btn;
            app.RuntimeValues.(key) = '';
        end

        function addRuntimeChannelRow(app, grid, row)
            label = uilabel(grid, 'Text', 'Channels');
            label.Layout.Row = row;
            label.Layout.Column = 1;

            dd = uidropdown(grid);
            dd.Layout.Row = row;
            dd.Layout.Column = [2 3];
            dd.Items = {'resolved after project/raw data load'};
            dd.Value = dd.Items{1};
            dd.ValueChangedFcn = @(src,~)runtimeFieldChanged(app, 'channels', src.Value);

            btn = uibutton(grid, 'push', 'Text', 'Select...');
            btn.Layout.Row = row;
            btn.Layout.Column = 4;
            btn.Tooltip = 'Select channel after project/raw data parsing.';
            btn.ButtonPushedFcn = @(~,~)runtimeButtonPushed(app, 'channels');

            app.RuntimeFieldHandles.channels = dd;
            app.RuntimeButtonHandles.channels = btn;
            app.RuntimeValues.channels = '';
        end

        function addRuntimeInventoryRow(app, grid, row)
            label = uilabel(grid, 'Text', 'Available');
            label.Layout.Row = row;
            label.Layout.Column = 1;
            label.Tooltip = 'Informational inventory exposed to module bindings; not a global run selection.';

            txt = uitextarea(grid);
            txt.Layout.Row = row;
            txt.Layout.Column = [2 4];
            txt.Editable = 'off';
            txt.Value = {'Channels: resolved after project/raw data load'; 'Data series: resolved after project load'};
            txt.Tooltip = 'Channels and dataseries discovered from the selected project/raw data. Use module Bindings to select them.';

            app.RuntimeFieldHandles.availableResources = txt;
        end

        function addRuntimePolicyRow(app, grid, row)
            label = uilabel(grid, 'Text', 'Output policy');
            label.Layout.Row = row;
            label.Layout.Column = 1;

            dd = uidropdown(grid);
            dd.Layout.Row = row;
            dd.Layout.Column = [2 3];
            dd.Items = {'Skip existing outputs','Replace existing outputs','Append/update existing outputs','Error if outputs exist'};
            dd.ItemsData = {'skip','replace','upsert','error'};
            dd.Value = 'skip';
            dd.Tooltip = 'Controls what happens when module outputs already exist. Resume controls checkpoints separately.';
            dd.ValueChangedFcn = @(src,~)runtimeFieldChanged(app, 'outputPolicy', src.Value);

            btn = uibutton(grid, 'push', 'Text', 'Explain');
            btn.Layout.Row = row;
            btn.Layout.Column = 4;
            btn.ButtonPushedFcn = @(~,~)showOutputPolicyHelp(app);

            app.RuntimeFieldHandles.outputPolicy = dd;
            app.RuntimeButtonHandles.outputPolicy = btn;
            app.RuntimeValues.outputPolicy = 'skip';
            app.RuntimeValues.outputPolicyUserChosen = false;
        end

        function runtimeFieldChanged(app, key, value)
            app.RuntimeValues.(key) = char(string(value));
            if strcmp(char(string(key)), 'projectPath')
                bindProjectFromPath(app, char(string(value)), false);
            end
            syncRuntimeValueToNodeParams(app, key);
            if strcmp(char(string(key)), 'rawDataPath')
                parseRuntimeRawDataPath(app, char(string(value)));
            end
            if strcmp(char(string(key)), 'outputPolicy')
                markOutputPolicyUserChosen(app);
            end
            updateRuntimeInputStates(app);
            if any(strcmp(char(string(key)), {'projectPath','rawDataPath','fovs','rois'}))
                updateRuntimeResourceInventory(app);
            end
            if runtimeValueAffectsBindings(app, key)
                refreshModuleTabs(app);
            end
            refreshValidationReport(app);
        end

        function tf = runtimeValueAffectsBindings(app, key) %#ok<INUSD>
            tf = any(strcmp(char(string(key)), {'projectPath','rawDataPath','fovs','frames','rois'}));
        end

        function runtimeButtonPushed(app, key)
            switch char(string(key))
                case 'projectPath'
                    chooseExistingProject(app);
                case 'rawDataPath'
                    pth = uigetdir(pwd, 'Select raw data folder');
                    if isequal(pth, 0)
                        return;
                    end
                    setRuntimeValue(app, key, pth);
                case {'fovs','frames','rois'}
                    current = getRuntimeValue(app, key);
                    answer = inputdlg(runtimePromptForKey(app, key), ['Set ' key], 1, {current});
                    if isempty(answer)
                        return;
                    end
                    setRuntimeValue(app, key, strtrim(answer{1}));
                case 'outputPolicy'
                    showOutputPolicyHelp(app);
            end
        end

        function items = projectDropdownItems(app)
            items = {'Select project...'};
            choices = workspaceShallowProjectChoices(app);
            for i = 1:size(choices, 1)
                items{end+1} = choices{i,1}; %#ok<AGROW>
            end
            items = [items {'Browse existing...','New project...'}];
        end

        function choices = workspaceShallowProjectChoices(app) %#ok<INUSD>
            choices = cell(0, 2);
            try
                vars = evalin('base', 'who');
            catch
                vars = {};
            end
            for i = 1:numel(vars)
                varName = vars{i};
                try
                    obj = evalin('base', varName);
                catch
                    continue;
                end
                if ~isa(obj, 'shallow')
                    continue;
                end
                label = varName;
                try
                    [pth, file] = obj.getPath;
                    if ~isempty(file)
                        label = sprintf('%s (%s)', varName, file);
                    end
                catch
                end
                choices(end+1,:) = {label, varName}; %#ok<AGROW>
            end
        end

        function refreshProjectDropdown(app)
            if ~isfield(app.RuntimeFieldHandles, 'projectSource') || ~isvalid(app.RuntimeFieldHandles.projectSource)
                return;
            end
            dd = app.RuntimeFieldHandles.projectSource;
            old = char(string(dd.Value));
            dd.Items = projectDropdownItems(app);
            if any(strcmp(dd.Items, old))
                dd.Value = old;
            else
                dd.Value = dd.Items{1};
            end
        end

        function projectDropdownChanged(app, value)
            value = char(string(value));
            if strcmp(value, 'Select project...')
                return;
            elseif strcmp(value, 'Browse existing...')
                chooseExistingProject(app);
                refreshProjectDropdown(app);
                return;
            elseif strcmp(value, 'New project...')
                createNewProjectFromDialog(app);
                refreshProjectDropdown(app);
                return;
            end

            choices = workspaceShallowProjectChoices(app);
            idx = find(strcmp(choices(:,1), value), 1);
            if isempty(idx)
                return;
            end
            varName = choices{idx,2};
            d = openRuntimeProgress(app, 'Project', 'Loading selected project metadata...');
            try
                drawnow limitrate;
                shallowObj = evalin('base', varName);
                updateRuntimeProgress(app, d, 'Refreshing FOV, ROI, channel and dataseries inventory...');
                bindCurrentProject(app, shallowObj, varName);
            catch ME
                closeRuntimeProgress(app, d);
                d = [];
                uialert(app.UIFigure, ME.message, 'Project selection', 'Icon', 'warning');
            end
            closeRuntimeProgress(app, d);
        end

        function chooseExistingProject(app)
            [file, pth] = uigetfile({'*.mat','DetecDiv project (*.mat)'; '*.*','All files'}, ...
                'Select existing DetecDiv shallow project');
            if isequal(file, 0)
                pth = uigetdir(pwd, 'Select existing DetecDiv project folder');
                if isequal(pth, 0)
                    return;
                end
                target = pth;
            else
                target = fullfile(pth, file);
            end
            bindProjectFromPath(app, target, true);
        end

        function createNewProjectFromDialog(app)
            [file, pth] = uiputfile('*.mat', 'Create DetecDiv shallow project', fullfile(pwd, 'new_project.mat'));
            if isequal(file, 0)
                return;
            end
            [~, name, ext] = fileparts(file);
            if isempty(ext)
                file = [file '.mat']; %#ok<NASGU>
            end
            projectFolder = fullfile(pth, name);
            if ~exist(projectFolder, 'dir')
                mkdir(projectFolder);
            end
            shallowObj = shallow();
            shallowObj.setPath(ensureTrailingFilesep(app, pth), name);
            if ~isfield(shallowObj.processing, 'pipelineRun') || isempty(shallowObj.processing.pipelineRun)
                shallowObj.processing.pipelineRun = pipelineRun.empty;
            end
            shallowSave(shallowObj, 'shallowObj');
            varName = matlab.lang.makeValidName(name);
            assignin('base', varName, shallowObj);
            bindCurrentProject(app, shallowObj, varName);
        end

        function bindProjectFromPath(app, inputPath, showWarnings)
            if nargin < 3
                showWarnings = true;
            end
            inputPath = strtrim(char(string(inputPath)));
            if isempty(inputPath)
                return;
            end
            matPath = resolveProjectMatPath(app, inputPath);
            if isempty(matPath) || exist(matPath, 'file') ~= 2
                if showWarnings
                    uialert(app.UIFigure, ['Project .mat not found: ' inputPath], 'Project', 'Icon', 'warning');
                end
                return;
            end
            d = openRuntimeProgress(app, 'Project', 'Loading DetecDiv project...');
            try
                drawnow limitrate;
                [shallowObj, msg] = shallowLoad(matPath);
                if isempty(shallowObj)
                    error('pipeline2:ProjectLoadFailed', '%s', msg);
                end
                [~, name] = fileparts(matPath);
                varName = matlab.lang.makeValidName(name);
                assignin('base', varName, shallowObj);
                updateRuntimeProgress(app, d, 'Refreshing FOV, ROI, channel and dataseries inventory...');
                bindCurrentProject(app, shallowObj, varName);
            catch ME
                closeRuntimeProgress(app, d);
                d = [];
                if showWarnings
                    uialert(app.UIFigure, ME.message, 'Project', 'Icon', 'warning');
                end
            end
            closeRuntimeProgress(app, d);
        end

        function d = openRuntimeProgress(app, titleText, messageText)
            d = [];
            try
                d = uiprogressdlg(app.UIFigure, ...
                    'Title', titleText, ...
                    'Message', messageText, ...
                    'Indeterminate', 'on');
            catch
                d = [];
            end
        end

        function updateRuntimeProgress(app, d, messageText) %#ok<INUSD>
            try
                if ~isempty(d) && isvalid(d)
                    d.Message = messageText;
                    drawnow limitrate;
                end
            catch
            end
        end

        function closeRuntimeProgress(app, d) %#ok<INUSD>
            try
                if ~isempty(d) && isvalid(d)
                    close(d);
                end
            catch
            end
        end

        function matPath = resolveProjectMatPath(app, inputPath) %#ok<INUSD>
            matPath = '';
            inputPath = char(string(inputPath));
            if exist(inputPath, 'file') == 2
                [~, ~, ext] = fileparts(inputPath);
                if strcmpi(ext, '.mat')
                    matPath = inputPath;
                end
                return;
            end
            if exist(inputPath, 'dir') ~= 7
                return;
            end
            [parentPath, folderName] = fileparts(inputPath);
            candidate = fullfile(parentPath, [folderName '.mat']);
            if exist(candidate, 'file') == 2
                matPath = candidate;
                return;
            end
            d = dir(fullfile(inputPath, '*.mat'));
            if numel(d) == 1
                matPath = fullfile(d(1).folder, d(1).name);
            end
        end

        function bindCurrentProject(app, shallowObj, varName)
            if isempty(shallowObj) || ~isa(shallowObj, 'shallow')
                return;
            end
            app.CurrentProject = shallowObj;
            app.CurrentProjectVarName = char(string(varName));
            [pth, file] = shallowObj.getPath;
            setRuntimeValuePreserveParse(app, 'projectPath', fullfile(pth, [file '.mat']));
            refreshRuntimeFromProject(app);
            refreshProjectDropdown(app);
            updateRuntimeInputStates(app);
            refreshValidationReport(app);
        end

        function refreshRuntimeFromProject(app)
            shallowObj = app.CurrentProject;
            if isempty(shallowObj) || ~isa(shallowObj, 'shallow')
                return;
            end
            try
                nFov = numel(shallowObj.fov);
                if nFov > 0
                    setRuntimeValuePreserveParse(app, 'fovs', sprintf('1:%d', nFov));
                end
            catch
            end
            try
                frames = [];
                for i = 1:numel(shallowObj.fov)
                    if ~isempty(shallowObj.fov(i).frames)
                        frames = [frames double(shallowObj.fov(i).frames(:)')]; %#ok<AGROW>
                    elseif ~isempty(shallowObj.fov(i).srclist)
                        for ch = 1:numel(shallowObj.fov(i).srclist)
                            frames(end+1) = numel(shallowObj.fov(i).srclist{ch}); %#ok<AGROW>
                        end
                    end
                end
                frames = frames(isfinite(frames) & frames > 0);
                if ~isempty(frames)
                    setRuntimeValuePreserveParse(app, 'frames', sprintf('1:%d', max(round(frames))));
                end
            catch
            end
            channels = {};
            try
                if ~isempty(shallowObj.fov) && iscell(shallowObj.fov(1).channel)
                    channels = shallowObj.fov(1).channel;
                end
            catch
            end
            updateChannelDropdownItems(app, channels);
        end

        function out = ensureTrailingFilesep(app, pth) %#ok<INUSD>
            out = char(string(pth));
            if isempty(out)
                return;
            end
            if ~endsWith(out, filesep)
                out = [out filesep];
            end
        end

        function showOutputPolicyHelp(app)
            msg = [ ...
                "Resume options control progress checkpoints." newline ...
                "Output policy controls what happens when output files/data already exist." newline newline ...
                "Recommended default:" newline ...
                "- Resume previous progress + Skip existing outputs" newline newline ...
                "Full rerun:" newline ...
                "- Restart from scratch + Replace existing outputs" newline newline ...
                "Append/update is for partial ROI extraction continuation or controlled upserts."];
            uialert(app.UIFigure, msg, 'Run policy', 'Icon', 'info');
        end

        function markOutputPolicyUserChosen(app)
            app.RuntimeValues.outputPolicyUserChosen = true;
        end

        function tf = isOutputPolicyUserChosen(app)
            tf = false;
            if isfield(app.RuntimeValues, 'outputPolicyUserChosen') && ~isempty(app.RuntimeValues.outputPolicyUserChosen)
                tf = logical(app.RuntimeValues.outputPolicyUserChosen);
            end
        end

        function applyRecommendedOutputPolicyForResume(app)
            if ~isfield(app.RuntimeFieldHandles, 'outputPolicy') || ~isvalid(app.RuntimeFieldHandles.outputPolicy)
                return;
            end
            resumeMode = char(string(app.ResumeoptionsDropDown.Value));
            current = getRuntimeValue(app, 'outputPolicy');
            recommended = recommendedOutputPolicy(app, resumeMode);

            shouldAutoSet = isempty(current) || ...
                (~isOutputPolicyUserChosen(app) && ~strcmp(current, recommended)) || ...
                (strcmpi(resumeMode, 'Restart from scratch') && strcmp(current, 'skip')) || ...
                (strcmpi(resumeMode, 'Resume previous progress') && strcmp(current, 'replace'));
            if shouldAutoSet
                app.RuntimeValues.outputPolicyUserChosen = false;
                setRuntimeValuePreserveParse(app, 'outputPolicy', recommended);
            end
        end

        function policy = recommendedOutputPolicy(app, resumeMode) %#ok<INUSD>
            if strcmpi(char(string(resumeMode)), 'Restart from scratch')
                policy = 'replace';
            else
                policy = 'skip';
            end
        end

        function setRuntimeValue(app, key, value)
            value = char(string(value));
            app.RuntimeValues.(key) = value;
            if isfield(app.RuntimeFieldHandles, key) && isvalid(app.RuntimeFieldHandles.(key))
                setRuntimeControlValue(app, key, value);
            end
            syncRuntimeValueToNodeParams(app, key);
            if strcmp(char(string(key)), 'rawDataPath')
                parseRuntimeRawDataPath(app, value);
            end
            if strcmp(char(string(key)), 'outputPolicy')
                markOutputPolicyUserChosen(app);
            end
            updateRuntimeInputStates(app);
            refreshValidationReport(app);
        end

        function value = getRuntimeValue(app, key)
            value = '';
            if isfield(app.RuntimeValues, key)
                value = char(string(app.RuntimeValues.(key)));
            elseif isfield(app.RuntimeFieldHandles, key) && isvalid(app.RuntimeFieldHandles.(key))
                value = char(string(app.RuntimeFieldHandles.(key).Value));
            end
        end

        function setRuntimeControlValue(app, key, value)
            if ~isfield(app.RuntimeFieldHandles, key) || ~isvalid(app.RuntimeFieldHandles.(key))
                return;
            end
            ctrl = app.RuntimeFieldHandles.(key);
            value = char(string(value));
            try
                if isa(ctrl, 'matlab.ui.control.DropDown')
                    if isempty(value)
                        return;
                    end
                    if ~any(strcmp(ctrl.Items, value))
                        ctrl.Items = [ctrl.Items {value}];
                    end
                end
                ctrl.Value = value;
            catch
            end
        end

        function parseRuntimeRawDataPath(app, rawDataPath)
            rawDataPath = strtrim(char(string(rawDataPath)));
            if isempty(rawDataPath) || ~(exist(rawDataPath, 'dir') == 7 || exist(rawDataPath, 'file') == 2)
                clearRuntimeParseInfo(app);
                return;
            end
            if isfield(app.RuntimeParseInfo, 'path') && strcmp(char(string(app.RuntimeParseInfo.path)), rawDataPath)
                return;
            end

            d = [];
            try
                d = uiprogressdlg(app.UIFigure, 'Title', 'Raw data parser', ...
                    'Message', 'Loading raw dataset metadata...', 'Indeterminate', 'on');
            catch
            end
            try
                updateRuntimeProgress(app, d, 'Parsing raw dataset metadata...');
                out = parseInputData(rawDataPath);
                updateRuntimeProgress(app, d, 'Refreshing FOV, frame and channel inventory...');
                info = summarizeParsedRawData(app, out, rawDataPath);
                app.RuntimeParseInfo = info;
                updateRuntimeProgress(app, d, 'Updating runtime inputs and module bindings...');
                applyRuntimeParseInfo(app, info);
            catch ME
                app.RuntimeParseInfo = struct('path', rawDataPath, 'ok', false, 'message', ME.message);
                try
                    uialert(app.UIFigure, ['Raw data parsing failed: ' ME.message], 'Raw data parser', 'Icon', 'warning');
                catch
                end
            end
            try, close(d); catch, end
        end

        function clearRuntimeParseInfo(app)
            app.RuntimeParseInfo = struct();
            updateChannelDropdownItems(app, {});
        end

        function info = summarizeParsedRawData(app, out, rawDataPath) %#ok<INUSD>
            info = struct('path', rawDataPath, 'ok', false, 'message', '', ...
                'datatype', '', 'fovCount', 0, 'fovNames', {{}}, 'maxFrame', [], 'channels', {{}});
            if isempty(out) || ~isstruct(out)
                info.message = 'No parser output.';
                return;
            end
            if isfield(out, 'datatype')
                info.datatype = char(string(out.datatype));
            end
            if ~isfield(out, 'pos') || isempty(out.pos)
                info.message = 'No positions detected.';
                return;
            end
            pos = out.pos;
            valid = true(1, numel(pos));
            for i = 1:numel(pos)
                valid(i) = isstruct(pos(i)) && ...
                    ((isfield(pos(i), 'name') && ~isempty(pos(i).name)) || ...
                    (isfield(pos(i), 'channelname') && ~isempty(pos(i).channelname)) || ...
                    (isfield(pos(i), 'frames') && ~isempty(pos(i).frames)));
            end
            pos = pos(valid);
            if isempty(pos)
                info.message = 'No valid positions detected.';
                return;
            end

            info.fovCount = numel(pos);
            names = cell(1, numel(pos));
            for i = 1:numel(pos)
                if isfield(pos(i), 'name') && ~isempty(pos(i).name)
                    names{i} = char(string(pos(i).name));
                else
                    names{i} = sprintf('FOV %d', i);
                end
            end
            info.fovNames = names;

            frames = [];
            for i = 1:numel(pos)
                if isfield(pos(i), 'frames') && ~isempty(pos(i).frames)
                    frames = [frames double(pos(i).frames(:)')]; %#ok<AGROW>
                elseif isfield(pos(i), 'srclist') && iscell(pos(i).srclist) && ~isempty(pos(i).srclist) && ~isempty(pos(i).srclist{1})
                    frames(end+1) = numel(pos(i).srclist{1}); %#ok<AGROW>
                end
            end
            frames = frames(isfinite(frames) & frames > 0);
            if ~isempty(frames)
                info.maxFrame = max(round(frames));
            end

            channels = {};
            for i = 1:numel(pos)
                if isfield(pos(i), 'channelname') && ~isempty(pos(i).channelname)
                    channels = [channels cellstr(string(pos(i).channelname(:)'))]; %#ok<AGROW>
                elseif isfield(pos(i), 'channels') && ~isempty(pos(i).channels)
                    nCh = max(1, round(double(pos(i).channels(1))));
                    channels = [channels arrayfun(@(k)sprintf('ch%d', k), 1:nCh, 'UniformOutput', false)]; %#ok<AGROW>
                end
            end
            info.channels = unique(channels(~cellfun(@isempty, channels)), 'stable');
            info.ok = true;
        end

        function applyRuntimeParseInfo(app, info)
            if ~isstruct(info) || ~isfield(info, 'ok') || ~info.ok
                return;
            end
            if isfield(info, 'fovCount') && info.fovCount > 0
                setRuntimeValuePreserveParse(app, 'fovs', sprintf('1:%d', info.fovCount));
                try
                    app.RuntimeFieldHandles.fovs.Tooltip = sprintf('Detected %d FOV(s): %s', info.fovCount, strjoin(info.fovNames, ', '));
                catch
                end
            end
            if isfield(info, 'maxFrame') && ~isempty(info.maxFrame) && isfinite(info.maxFrame) && info.maxFrame > 0
                setRuntimeValuePreserveParse(app, 'frames', sprintf('1:%d', round(info.maxFrame)));
                try
                    app.RuntimeFieldHandles.frames.Tooltip = sprintf('Detected frames: 1:%d', round(info.maxFrame));
                catch
                end
            end
            if isfield(info, 'channels')
                updateChannelDropdownItems(app, info.channels);
            end
        end

        function setRuntimeValuePreserveParse(app, key, value)
            app.RuntimeValues.(key) = char(string(value));
            setRuntimeControlValue(app, key, value);
            if any(strcmp(char(string(key)), {'projectPath','rawDataPath','fovs','rois'}))
                updateRuntimeResourceInventory(app);
            end
            if runtimeValueAffectsBindings(app, key)
                refreshModuleTabs(app);
            end
        end

        function updateChannelDropdownItems(app, channels)
            try
                channels = unique(cellstr(string(channels(:)')), 'stable');
                channels = channels(~cellfun(@isempty, channels));
                if isempty(channels)
                    if isfield(app.RuntimeParseInfo, 'channels')
                        app.RuntimeParseInfo = rmfield(app.RuntimeParseInfo, 'channels');
                    end
                    app.RuntimeValues.channels = '';
                    updateRuntimeResourceInventory(app);
                    refreshModuleTabs(app);
                    return;
                end
                app.RuntimeParseInfo.channels = channels;
                app.RuntimeValues.channels = '';
                updateRuntimeResourceInventory(app);
                refreshModuleTabs(app);
            catch
            end
        end

        function updateRuntimeResourceInventory(app)
            if ~isfield(app.RuntimeFieldHandles, 'availableResources') || ~isvalid(app.RuntimeFieldHandles.availableResources)
                return;
            end
            channels = runtimeConcreteChannels(app);
            dataSeriesNames = {};
            try
                dataSeriesNames = runtimeDataSeriesNames(app);
            catch
                dataSeriesNames = {};
            end
            if isempty(channels)
                channelText = 'Channels: none detected yet';
            else
                channelText = ['Channels: ' strjoin(channels, ', ')];
            end
            if isempty(dataSeriesNames)
                dsText = 'Data series: none detected yet';
            else
                maxShown = min(numel(dataSeriesNames), 12);
                dsText = ['Data series: ' strjoin(dataSeriesNames(1:maxShown), ', ')];
                if numel(dataSeriesNames) > maxShown
                    dsText = [dsText sprintf(' ... (+%d)', numel(dataSeriesNames) - maxShown)];
                end
            end
            app.RuntimeFieldHandles.availableResources.Value = {channelText; dsText};
        end

        function syncRuntimeValueToNodeParams(app, key)
            if ~strcmp(char(string(key)), 'rawDataPath')
                return;
            end
            rawDataPath = getRuntimeValue(app, 'rawDataPath');
            changed = false;
            for i = 1:numel(app.Data.nodes)
                if ~strcmpi(char(string(getField(app, app.Data.nodes(i), 'type', ''))), 'dataLoader')
                    continue;
                end
                if ~isfield(app.Data.nodes(i), 'params') || ~isstruct(app.Data.nodes(i).params)
                    app.Data.nodes(i).params = struct();
                end
                current = '';
                if isfield(app.Data.nodes(i).params, 'path')
                    current = char(string(app.Data.nodes(i).params.path));
                end
                if ~strcmp(current, rawDataPath)
                    app.Data.nodes(i).params.path = rawDataPath;
                    changed = true;
                end
            end
            if changed
                rebuildModuleTabsByType(app, 'dataLoader');
            end
        end

        function prompt = runtimePromptForKey(app, key) %#ok<INUSD>
            switch char(string(key))
                case 'fovs'
                    prompt = 'FOV selection: all, 1,3,5, or 1:4';
                case 'frames'
                    prompt = 'Frame selection: all, 1:50, or 1,5,9';
                case 'rois'
                    prompt = 'ROI selection: all, selected ROI ids, or leave empty until ROIs exist';
                otherwise
                    prompt = 'Value:';
            end
        end

        function updateRuntimeInputStates(app)
            if isempty(fieldnames(app.RuntimeFieldHandles))
                return;
            end
            keys = fieldnames(app.RuntimeFieldHandles);
            for i = 1:numel(keys)
                key = keys{i};
                field = app.RuntimeFieldHandles.(key);
                if ~isvalid(field)
                    continue;
                end
                field.FontColor = [0 0 0];
                field.BackgroundColor = [1 1 1];
                field.Enable = 'on';
            end

            projectPath = strtrim(getRuntimeValue(app, 'projectPath'));
            projectOk = ~isempty(projectPath) && (exist(projectPath, 'dir') == 7 || exist(projectPath, 'file') == 2);
            rawDataPath = strtrim(getRuntimeValue(app, 'rawDataPath'));
            rawOk = ~isempty(rawDataPath) && exist(rawDataPath, 'dir') == 7;

            if ~isempty(projectPath) && ~projectOk
                markRuntimeField(app, 'projectPath', 'missing', 'Project must be an existing folder or project .mat file.');
            end

            if pipelineHasNodeType(app, 'dataLoader') && ~projectOk && ~rawOk
                markRuntimeField(app, 'rawDataPath', 'missing', 'Required when a dataloader run has no existing project input.');
            end

            if ~projectOk && ~rawOk
                markRuntimeField(app, 'channels', 'blocked', 'Select an existing project or raw data folder before selecting channels.');
                setRuntimeButtonEnabled(app, 'channels', false);
            else
                setRuntimeButtonEnabled(app, 'channels', true);
            end

            [severity, message] = outputPolicyCompatibility(app);
            if ~strcmp(severity, 'ok')
                markRuntimeField(app, 'outputPolicy', severity, message);
            end
        end

        function markRuntimeField(app, key, state, tooltip)
            if ~isfield(app.RuntimeFieldHandles, key)
                return;
            end
            field = app.RuntimeFieldHandles.(key);
            if ~isvalid(field)
                return;
            end
            switch char(string(state))
                case 'missing'
                    field.FontColor = [0.70 0.05 0.05];
                    field.BackgroundColor = [1.00 0.92 0.92];
                    field.Enable = 'on';
                case 'blocked'
                    field.FontColor = [0.45 0.45 0.45];
                    field.BackgroundColor = [0.94 0.94 0.94];
                    field.Enable = 'off';
                case 'warning'
                    field.FontColor = [0.45 0.25 0.00];
                    field.BackgroundColor = [1.00 0.96 0.82];
                    field.Enable = 'on';
            end
            try
                field.Tooltip = tooltip;
            catch
            end
        end

        function setRuntimeButtonEnabled(app, key, tf)
            if isfield(app.RuntimeButtonHandles, key) && isvalid(app.RuntimeButtonHandles.(key))
                app.RuntimeButtonHandles.(key).Enable = ternary(app, tf, 'on', 'off');
            end
        end

        function tf = pipelineHasNodeType(app, nodeType)
            tf = false;
            for i = 1:numel(app.Data.nodes)
                if strcmpi(char(string(getField(app, app.Data.nodes(i), 'type', ''))), nodeType)
                    tf = true;
                    return;
                end
            end
        end

        function setRefreshingTabs(app, value)
            app.IsRefreshingTabs = logical(value);
        end

        function selectExistingModuleTab(app, node)
            if isempty(app.DynamicModuleTabs)
                return;
            end
            nodeId = char(string(getField(app, node, 'id', '')));
            for i = 1:numel(app.DynamicModuleTabs)
                try
                    t = app.DynamicModuleTabs(i);
                    if isvalid(t) && isstruct(t.UserData) && isfield(t.UserData, 'nodeId') && strcmp(char(string(t.UserData.nodeId)), nodeId)
                        app.IsRefreshingTabs = true;
                        cleanupObj = onCleanup(@()setRefreshingTabs(app, false)); %#ok<NASGU>
                        app.TabGroup.SelectedTab = t;
                        return;
                    end
                catch
                end
            end
        end

        function renameSelectedModuleTab(app, oldId, newId)
            for i = 1:numel(app.DynamicModuleTabs)
                try
                    t = app.DynamicModuleTabs(i);
                    if isvalid(t) && isstruct(t.UserData) && isfield(t.UserData, 'nodeId') && strcmp(char(string(t.UserData.nodeId)), oldId)
                        t.UserData.nodeId = newId;
                        t.Title = truncateTabTitle(app, newId);
                        return;
                    end
                catch
                end
            end
        end

        function rebuildSelectedModuleTab(app)
            if isnan(app.SelectedNodeIndex) || app.SelectedNodeIndex < 1 || app.SelectedNodeIndex > numel(app.Data.nodes)
                return;
            end
            node = app.Data.nodes(app.SelectedNodeIndex);
            nodeId = char(string(getField(app, node, 'id', '')));
            for i = 1:numel(app.DynamicModuleTabs)
                try
                    t = app.DynamicModuleTabs(i);
                    if isvalid(t) && isstruct(t.UserData) && isfield(t.UserData, 'nodeId') && strcmp(char(string(t.UserData.nodeId)), nodeId)
                        delete(t.Children);
                        buildModuleTab(app, t, node);
                        return;
                    end
                catch
                end
            end
        end

        function rebuildModuleTabsByType(app, nodeType)
            for nodeIdx = 1:numel(app.Data.nodes)
                node = app.Data.nodes(nodeIdx);
                if ~strcmpi(char(string(getField(app, node, 'type', ''))), nodeType)
                    continue;
                end
                nodeId = char(string(getField(app, node, 'id', '')));
                for tabIdx = 1:numel(app.DynamicModuleTabs)
                    try
                        t = app.DynamicModuleTabs(tabIdx);
                        if isvalid(t) && isstruct(t.UserData) && isfield(t.UserData, 'nodeId') && strcmp(char(string(t.UserData.nodeId)), nodeId)
                            delete(t.Children);
                            buildModuleTab(app, t, node);
                        end
                    catch
                    end
                end
            end
        end

        function deleteDynamicModuleTabs(app)
            if isempty(app.DynamicModuleTabs)
                return;
            end
            for i = 1:numel(app.DynamicModuleTabs)
                try
                    if isvalid(app.DynamicModuleTabs(i))
                        delete(app.DynamicModuleTabs(i));
                    end
                catch
                end
            end
            app.DynamicModuleTabs = gobjects(0);
        end

        function buildModuleTab(app, parentTab, node)
            if strcmpi(char(string(getField(app, node, 'type', ''))), 'roiGrid')
                buildRoiGridTab(app, parentTab, node);
                return;
            end
            if strcmpi(char(string(getField(app, node, 'type', ''))), 'roiManual')
                buildRoiManualTab(app, parentTab, node);
                return;
            end

            bindingData = bindingTableData(app, node);
            staticData = paramsToTableData(app, node, 'static');
            runtimeData = paramsToTableData(app, node, 'runtime');
            showClassifierReference = isClassifierNode(app, node);
            showBindings = ~isempty(bindingData);
            showStatic = ~isempty(staticData);
            showRuntime = ~isempty(runtimeData);

            if ~showClassifierReference && ~showBindings && ~showStatic && ~showRuntime
                grid = uigridlayout(parentTab, [1 1]);
                grid.Padding = [12 10 12 12];
                uilabel(grid, 'Text', 'No module-specific parameters for this module.', ...
                    'FontAngle', 'italic', 'FontColor', [0.35 0.35 0.35]);
                return;
            end

            colCount = max(1, double(showStatic) + double(showRuntime));
            hasParamRows = showStatic || showRuntime;
            rowCount = 2 * double(showClassifierReference) + 2 * double(showBindings) + 2 * double(hasParamRows);
            grid = uigridlayout(parentTab, [rowCount colCount]);
            rowHeights = {};
            if showClassifierReference
                rowHeights = [rowHeights {24, 76}]; %#ok<AGROW>
            end
            if showBindings
                rowHeights = [rowHeights {24, min(160, 42 + 34 * size(bindingData, 1))}]; %#ok<AGROW>
            end
            if hasParamRows
                rowHeights = [rowHeights {24, '1x'}]; %#ok<AGROW>
            end
            grid.RowHeight = rowHeights;
            grid.ColumnWidth = repmat({'1x'}, 1, colCount);
            grid.Padding = [12 10 12 12];
            grid.ColumnSpacing = 16;
            grid.RowSpacing = 8;

            row = 1;
            if showClassifierReference
                refLabel = uilabel(grid, 'Text', 'Classifier artifact');
                refLabel.FontWeight = 'bold';
                refLabel.Layout.Row = row;
                refLabel.Layout.Column = layoutSpan(app, 1, colCount);

                section = buildClassifierReferenceSection(app, grid, node);
                section.Layout.Row = row + 1;
                section.Layout.Column = layoutSpan(app, 1, colCount);
                row = row + 2;
            end

            if showBindings
                bindingLabel = uilabel(grid, 'Text', 'Bindings');
                bindingLabel.FontWeight = 'bold';
                bindingLabel.Layout.Row = row;
                bindingLabel.Layout.Column = layoutSpan(app, 1, colCount);

                section = buildBindingSection(app, grid, bindingData, node, true);
                section.Layout.Row = row + 1;
                section.Layout.Column = layoutSpan(app, 1, colCount);
                row = row + 2;
            end

            col = 1;
            if showStatic
                leftLabel = uilabel(grid, 'Text', 'Static parameters');
                leftLabel.FontWeight = 'bold';
                leftLabel.Layout.Row = row;
                leftLabel.Layout.Column = col;

                section = buildParamSection(app, grid, staticData, node, true);
                section.Layout.Row = row + 1;
                section.Layout.Column = col;
                col = col + 1;
            end

            if showRuntime
                rightLabel = uilabel(grid, 'Text', 'Runtime parameters');
                rightLabel.FontWeight = 'bold';
                rightLabel.Layout.Row = row;
                rightLabel.Layout.Column = col;

                section = buildParamSection(app, grid, runtimeData, node, app.Data.runMode);
                section.Layout.Row = row + 1;
                section.Layout.Column = col;
            end
        end

        function tf = isClassifierNode(app, node) %#ok<INUSD>
            tf = strcmpi(char(string(getField(app, node, 'type', ''))), 'classifier');
        end

        function section = buildClassifierReferenceSection(app, parent, node)
            section = uigridlayout(parent, [2 4]);
            section.RowHeight = {24, 28};
            section.ColumnWidth = {'1x', 150, 170, 110};
            section.Padding = [0 0 0 0];
            section.RowSpacing = 6;
            section.ColumnSpacing = 8;

            status = uilabel(section, 'Text', classifierReferenceSummary(app, node), ...
                'FontColor', classifierReferenceColor(app, node), 'Interpreter', 'none');
            status.Layout.Row = 1;
            status.Layout.Column = [1 4];

            hint = uilabel(section, 'Text', 'Use an existing classi object so training runs, model files, weights and engine metadata are available at run time.', ...
                'FontColor', [0.35 0.35 0.35], 'Interpreter', 'none');
            hint.Layout.Row = 2;
            hint.Layout.Column = 1;

            linkButton = uibutton(section, 'push', 'Text', 'Link classifier...', ...
                'ButtonPushedFcn', @(~,~)linkClassifierArtifact(app, node));
            linkButton.Layout.Row = 2;
            linkButton.Layout.Column = 2;

            openButton = uibutton(section, 'push', 'Text', 'Open linked classifier', ...
                'ButtonPushedFcn', @(~,~)openLinkedClassifier(app, node));
            openButton.Layout.Row = 2;
            openButton.Layout.Column = 3;

            clearButton = uibutton(section, 'push', 'Text', 'Clear link', ...
                'ButtonPushedFcn', @(~,~)clearClassifierArtifactLink(app, node));
            clearButton.Layout.Row = 2;
            clearButton.Layout.Column = 4;
        end

        function txt = classifierReferenceSummary(app, node)
            p = getField(app, node, 'params', struct());
            expected = char(string(getField(app, node, 'pkg', '')));
            if ~isstruct(p) || ~isfield(p, 'modulePath') || isempty(p.modulePath)
                txt = ['No linked classifier object. Expected package: ' expected];
                return;
            end
            modulePath = char(string(p.modulePath));
            moduleId = '';
            if isfield(p, 'moduleId') && ~isempty(p.moduleId)
                moduleId = char(string(p.moduleId));
            end
            if isempty(moduleId)
                [~, moduleId] = fileparts(modulePath);
            end
            txt = ['Linked: ' moduleId '  |  ' modulePath];
        end

        function color = classifierReferenceColor(app, node)
            p = getField(app, node, 'params', struct());
            if isstruct(p) && isfield(p, 'modulePath') && ~isempty(p.modulePath)
                color = [0.10 0.42 0.20];
            else
                color = [0.62 0.32 0.08];
            end
        end

        function linkClassifierArtifact(app, node)
            nodeId = char(string(getField(app, node, 'id', '')));
            idx = find(strcmp({app.Data.nodes.id}, nodeId), 1);
            if isempty(idx)
                return;
            end
            startPath = pwd;
            try
                p = getField(app, app.Data.nodes(idx), 'params', struct());
                if isstruct(p) && isfield(p, 'modulePath') && ~isempty(p.modulePath)
                    startPath = char(string(p.modulePath));
                end
            catch
            end
            [file, pth] = uigetfile({'*classification*.mat','Classifier object (*classification*.mat)'; '*.mat','MAT files'}, ...
                'Link existing classifier object', startPath);
            if isequal(file, 0)
                return;
            end
            filePath = fullfile(pth, file);
            try
                [classiObj, msg] = classiLoad(filePath);
                if isempty(classiObj) || ~isa(classiObj, 'classi')
                    if isempty(msg), msg = 'Selected file is not a classi object.'; end
                    error('pipeline2:BadClassifierLink', '%s', msg);
                end
                expectedPkg = char(string(getField(app, app.Data.nodes(idx), 'pkg', '')));
                actualPkg = classifierPackageName(app, classiObj);
                if ~isempty(expectedPkg) && ~isempty(actualPkg) && ~strcmpi(expectedPkg, actualPkg)
                    error('pipeline2:ClassifierPackageMismatch', ...
                        'This node expects package "%s", but the selected classifier uses "%s".', expectedPkg, actualPkg);
                end
                if ~isfield(app.Data.nodes(idx), 'params') || ~isstruct(app.Data.nodes(idx).params)
                    app.Data.nodes(idx).params = struct();
                end
                [classiPath, classiId] = classiObj.getPath;
                app.Data.nodes(idx).params.modulePath = classiPath;
                app.Data.nodes(idx).params.moduleId = classiId;
                if ~isempty(actualPkg)
                    app.Data.nodes(idx).params.pkg = actualPkg;
                    app.Data.nodes(idx).pkg = actualPkg;
                    app.Data.nodes(idx).func = [actualPkg '.classify'];
                end
                try
                    varName = matlab.lang.makeValidName(['classi_' char(string(classiId))]);
                    assignin('base', varName, classiObj);
                    app.Data.nodes(idx).params.moduleVar = varName;
                catch
                end
                refreshAfterModelChange(app);
            catch ME
                uialert(app.UIFigure, ME.message, 'Link classifier', 'Icon', 'error');
            end
        end

        function pkg = classifierPackageName(app, classiObj) %#ok<INUSD>
            pkg = '';
            try
                if isprop(classiObj, 'classifierPkg') && ~isempty(classiObj.classifierPkg)
                    pkg = char(string(classiObj.classifierPkg));
                    return;
                end
            catch
            end
            fun = '';
            try
                if isprop(classiObj, 'classifyFun') && ~isempty(classiObj.classifyFun)
                    fun = char(string(classiObj.classifyFun));
                end
            catch
            end
            if contains(fun, '.')
                pkg = extractBefore(fun, '.');
            elseif strcmpi(fun, 'classifyImageLSTMNetFun')
                pkg = 'cnn_lstm';
            elseif contains(lower(fun), 'cellpose')
                pkg = 'cellposesam';
            end
        end

        function openLinkedClassifier(app, node)
            try
                classiObj = linkedClassifierObject(app, node);
                if isempty(classiObj) || ~isa(classiObj, 'classi')
                    error('pipeline2:NoLinkedClassifier', 'No valid linked classifier object is available for this module.');
                end
                classifierGUI(classiObj);
            catch ME
                uialert(app.UIFigure, ME.message, 'Open linked classifier', 'Icon', 'error');
            end
        end

        function classiObj = linkedClassifierObject(app, node)
            classiObj = [];
            p = getField(app, node, 'params', struct());
            if ~isstruct(p)
                return;
            end
            if isfield(p, 'moduleVar') && ~isempty(p.moduleVar)
                try
                    cand = evalin('base', char(string(p.moduleVar)));
                    if isa(cand, 'classi')
                        classiObj = cand(1);
                        return;
                    end
                catch
                end
            end
            if ~isfield(p, 'modulePath') || isempty(p.modulePath)
                return;
            end
            modulePath = char(string(p.modulePath));
            moduleId = '';
            if isfield(p, 'moduleId') && ~isempty(p.moduleId)
                moduleId = char(string(p.moduleId));
            end
            if isempty(moduleId)
                [~, moduleId] = fileparts(modulePath);
            end
            snap = fullfile(modulePath, [moduleId '_classification.mat']);
            if exist(snap, 'file') ~= 2
                error('pipeline2:MissingLinkedClassifierFile', 'Linked classifier file not found: %s', snap);
            end
            [classiObj, msg] = classiLoad(snap);
            if isempty(classiObj) || ~isa(classiObj, 'classi')
                if isempty(msg)
                    msg = 'Linked file is not a valid classi object.';
                end
                error('pipeline2:BadLinkedClassifier', '%s', msg);
            end
        end

        function clearClassifierArtifactLink(app, node)
            nodeId = char(string(getField(app, node, 'id', '')));
            idx = find(strcmp({app.Data.nodes.id}, nodeId), 1);
            if isempty(idx) || ~isfield(app.Data.nodes(idx), 'params') || ~isstruct(app.Data.nodes(idx).params)
                return;
            end
            removeKeys = {'modulePath','moduleId','moduleVar','classes','classifyFun','trainingFun','trainingParam','outputType'};
            for i = 1:numel(removeKeys)
                if isfield(app.Data.nodes(idx).params, removeKeys{i})
                    app.Data.nodes(idx).params = rmfield(app.Data.nodes(idx).params, removeKeys{i});
                end
            end
            refreshAfterModelChange(app);
        end

        function buildRoiGridTab(app, parentTab, node)
            grid = uigridlayout(parentTab, [2 2]);
            grid.RowHeight = {24, '1x'};
            grid.ColumnWidth = {250, '1x'};
            grid.Padding = [12 10 12 12];
            grid.ColumnSpacing = 18;

            label = uilabel(grid, 'Text', 'Static parameters');
            label.FontWeight = 'bold';
            label.Layout.Row = 1;
            label.Layout.Column = 1;

            previewLabel = uilabel(grid, 'Text', 'ROI grid preview');
            previewLabel.FontWeight = 'bold';
            previewLabel.Layout.Row = 1;
            previewLabel.Layout.Column = 2;

            paramGrid = uigridlayout(grid, [2 2]);
            paramGrid.RowHeight = {28, 26};
            paramGrid.ColumnWidth = {100, '1x'};
            paramGrid.Padding = [0 0 0 0];
            paramGrid.RowSpacing = 8;
            paramGrid.Layout.Row = 2;
            paramGrid.Layout.Column = 1;

            uilabel(paramGrid, 'Text', 'Grid count', 'Tooltip', '1 creates one full-frame ROI. Values above 1 tile the FOV.');
            countField = uieditfield(paramGrid, 'numeric');
            countField.Limits = [1 Inf];
            countField.RoundFractionalValues = 'on';
            countField.Value = resolveGridCount(app, node);

            hint = uilabel(paramGrid, 'Text', '1 = full frame, >1 = tiling', 'FontAngle', 'italic', 'FontColor', [0.35 0.35 0.35]);
            hint.Layout.Row = 2;
            hint.Layout.Column = [1 2];

            ax = uiaxes(grid);
            ax.Layout.Row = 2;
            ax.Layout.Column = 2;
            ax.Toolbar.Visible = 'off';
            ax.XTick = [];
            ax.YTick = [];
            ax.Box = 'on';
            title(ax, '');
            xlabel(ax, '');
            ylabel(ax, '');
            countField.UserData = struct( ...
                'nodeId', char(string(getField(app, node, 'id', ''))), ...
                'previewAxes', ax);
            countField.ValueChangedFcn = @(src,~)roiGridCountChanged(app, src, []);
            try
                countField.ValueChangingFcn = @(src,event)roiGridCountChanged(app, src, event.Value);
            catch
            end
            tiling = computeRoiGridTiling(app, countField.Value);
            drawRoiGridPreview(app, ax, tiling);
        end

        function roiGridCountChanged(app, src, valueOverride)
            if nargin < 3 || isempty(valueOverride)
                n = max(1, round(double(src.Value)));
            else
                n = max(1, round(double(valueOverride)));
            end
            src.Value = n;

            nodeIdx = roiGridNodeIndexForControl(app, src);
            if isempty(nodeIdx)
                return;
            end

            tiling = computeRoiGridTiling(app, n);
            app.Data.nodes(nodeIdx).params.gridCount = tiling.count;
            app.Data.nodes(nodeIdx).params.tiling = rmfield(tiling, 'active');
            if n <= 1
                app.Data.nodes(nodeIdx).params.mode = 'fullframe';
            else
                app.Data.nodes(nodeIdx).params.mode = 'grid';
            end

            ax = roiGridPreviewAxesForControl(app, src);
            if ~isempty(ax)
                drawRoiGridPreview(app, ax, tiling);
            end
            refreshValidationReport(app);
        end

        function idx = roiGridNodeIndexForControl(app, src)
            idx = [];
            nodeId = '';
            try
                if isstruct(src.UserData) && isfield(src.UserData, 'nodeId')
                    nodeId = char(string(src.UserData.nodeId));
                end
            catch
            end
            if ~isempty(nodeId)
                ids = {app.Data.nodes.id};
                idx = find(strcmp(ids, nodeId), 1);
            end
            if isempty(idx) && ~isnan(app.SelectedNodeIndex) && app.SelectedNodeIndex >= 1 && app.SelectedNodeIndex <= numel(app.Data.nodes)
                idx = app.SelectedNodeIndex;
            end
        end

        function ax = roiGridPreviewAxesForControl(app, src)
            ax = gobjects(0);
            try
                if isstruct(src.UserData) && isfield(src.UserData, 'previewAxes') && isvalid(src.UserData.previewAxes)
                    ax = src.UserData.previewAxes;
                    return;
                end
            catch
            end
            try
                tab = ancestor(src, 'matlab.ui.container.Tab');
                found = findall(tab, 'Type', 'axes');
                if ~isempty(found)
                    ax = found(1);
                end
            catch
                found = findall(app.TabGroup.SelectedTab, 'Type', 'axes');
                if ~isempty(found)
                    ax = found(1);
                end
            end
        end

        function n = resolveGridCount(app, node)
            n = 1;
            p = getField(app, node, 'params', struct());
            if isstruct(p) && isfield(p, 'gridCount') && ~isempty(p.gridCount)
                n = max(1, round(double(p.gridCount)));
            end
        end

        function tiling = computeRoiGridTiling(app, count) %#ok<INUSD>
            count = max(1, round(double(count)));
            if count <= 1
                rows = 1;
                cols = 1;
            else
                cols = ceil(sqrt(count));
                rows = ceil(count / cols);
            end
            active = false(rows, cols);
            active(1:count) = true;
            tiling = struct('count', count, 'rows', rows, 'cols', cols, 'active', active);
        end

        function drawRoiGridPreview(app, ax, tiling) %#ok<INUSD>
            if isnumeric(tiling)
                tiling = computeRoiGridTiling(app, tiling);
            end
            count = tiling.count;
            cla(ax);
            hold(ax, 'on');
            axis(ax, [0 1 0 1]);
            axis(ax, 'ij');
            ax.XTick = [];
            ax.YTick = [];

            rectangle(ax, 'Position', [0.06 0.08 0.88 0.82], 'FaceColor', [0.96 0.97 0.98], ...
                'EdgeColor', [0.18 0.24 0.30], 'LineWidth', 1.4);

            if count <= 1
                text(ax, 0.5, 0.49, '1 full-frame ROI', 'HorizontalAlignment', 'center', ...
                    'FontWeight', 'bold', 'Color', [0.18 0.24 0.30]);
            else
                nRows = tiling.rows;
                nCols = tiling.cols;
                w = 0.88 / nCols;
                h = 0.82 / nRows;
                for r = 1:nRows
                    for c = 1:nCols
                        if ~tiling.active(r, c)
                            continue;
                        end
                        x = 0.06 + (c - 1) * w;
                        y = 0.08 + (r - 1) * h;
                        rectangle(ax, 'Position', [x y w h], 'FaceColor', [0.75 0.86 0.95], ...
                            'EdgeColor', [0.12 0.38 0.62], 'LineWidth', 1.0);
                    end
                end
                text(ax, 0.5, 0.96, sprintf('%d tiled ROIs', count), 'HorizontalAlignment', 'center', ...
                    'FontWeight', 'bold', 'Color', [0.18 0.24 0.30]);
            end
            hold(ax, 'off');
            drawnow limitrate;
        end

        function buildRoiManualTab(app, parentTab, node)
            nodeId = char(string(getField(app, node, 'id', '')));
            runtimeParams = getRuntimeNodeParams(app, nodeId);
            defaults = roiManual.setparam(struct());
            runtimeParams = mergeStructDefaults(app, runtimeParams, defaults);
            rects = getRoiManualRectangles(app, nodeId);

            grid = uigridlayout(parentTab, [2 2]);
            grid.RowHeight = {24, '1x'};
            grid.ColumnWidth = {270, '1x'};
            grid.Padding = [12 10 12 12];
            grid.ColumnSpacing = 18;

            settingsLabel = uilabel(grid, 'Text', 'Manual ROI runtime settings');
            settingsLabel.FontWeight = 'bold';
            settingsLabel.Layout.Row = 1;
            settingsLabel.Layout.Column = 1;

            previewLabel = uilabel(grid, 'Text', 'Manual ROI preview');
            previewLabel.FontWeight = 'bold';
            previewLabel.Layout.Row = 1;
            previewLabel.Layout.Column = 2;

            left = uigridlayout(grid, [9 1]);
            left.RowHeight = {30, 30, 30, 30, 24, 24, 24, 24, '1x'};
            left.Padding = [0 0 0 0];
            left.RowSpacing = 6;
            left.Layout.Row = 2;
            left.Layout.Column = 1;

            addButton = uibutton(left, 'push', 'Text', 'Add rectangle');
            addButton.Layout.Row = 1;

            clearSelectedButton = uibutton(left, 'push', 'Text', 'Clear selected');
            clearSelectedButton.Layout.Row = 2;

            clearAllButton = uibutton(left, 'push', 'Text', 'Clear all');
            clearAllButton.Layout.Row = 3;

            previewButton = uibutton(left, 'push', 'Text', 'Open data previewer...');
            previewButton.Layout.Row = 4;
            previewButton.ButtonPushedFcn = @(~,~)uialert(app.UIFigure, ...
                'The shared raw-data previewer is the next brick. This tab stores runtime rectangles now.', ...
                'Data previewer', 'Icon', 'info');

            keepBox = uicheckbox(left, 'Text', 'Keep existing ROIs');
            keepBox.Layout.Row = 5;
            keepBox.Value = logical(runtimeParams.keepExisting);
            keepBox.ValueChangedFcn = @(src,~)roiManualRuntimeOptionChanged(app, nodeId, 'keepExisting', src.Value);

            skipBox = uicheckbox(left, 'Text', 'Skip FOVs with existing ROIs');
            skipBox.Layout.Row = 6;
            skipBox.Value = logical(runtimeParams.skipExisting);
            skipBox.ValueChangedFcn = @(src,~)roiManualRuntimeOptionChanged(app, nodeId, 'skipExisting', src.Value);

            errorBox = uicheckbox(left, 'Text', 'Error if ROIs already exist');
            errorBox.Layout.Row = 7;
            errorBox.Value = logical(runtimeParams.errorOnExisting);
            errorBox.ValueChangedFcn = @(src,~)roiManualRuntimeOptionChanged(app, nodeId, 'errorOnExisting', src.Value);

            firstBox = uicheckbox(left, 'Text', 'Open/edit first selected FOV only');
            firstBox.Layout.Row = 8;
            firstBox.Value = logical(runtimeParams.openFirstOnly);
            firstBox.ValueChangedFcn = @(src,~)roiManualRuntimeOptionChanged(app, nodeId, 'openFirstOnly', src.Value);

            table = uitable(left);
            table.Layout.Row = 9;
            table.ColumnName = {'#','x','y','w','h'};
            table.ColumnEditable = [false true true true true];
            table.RowName = {};
            table.ColumnWidth = {36, 48, 48, 48, 48};
            table.Data = roiManualRectanglesToTable(app, rects);
            table.CellEditCallback = @(src,event)roiManualRectangleTableEdited(app, nodeId, src, event);
            table.SelectionChangedFcn = @(src,event)roiManualRectangleSelectionChanged(app, event);

            ax = uiaxes(grid);
            ax.Layout.Row = 2;
            ax.Layout.Column = 2;
            ax.Toolbar.Visible = 'off';
            ax.XTick = [];
            ax.YTick = [];
            ax.Box = 'on';
            title(ax, '');
            xlabel(ax, '');
            ylabel(ax, '');

            addButton.ButtonPushedFcn = @(~,~)roiManualAddRectangle(app, nodeId, table, ax);
            clearSelectedButton.ButtonPushedFcn = @(~,~)roiManualClearSelectedRectangle(app, nodeId, table, ax);
            clearAllButton.ButtonPushedFcn = @(~,~)roiManualClearAllRectangles(app, nodeId, table, ax);

            drawRoiManualPreview(app, ax, nodeId, table, rects);
        end

        function params = getRuntimeNodeParams(app, nodeId)
            params = struct();
            key = runtimeNodeKey(app, nodeId);
            if isfield(app.RuntimeNodeParams, key) && isstruct(app.RuntimeNodeParams.(key))
                params = app.RuntimeNodeParams.(key);
            end
        end

        function setRuntimeNodeParams(app, nodeId, params)
            key = runtimeNodeKey(app, nodeId);
            app.RuntimeNodeParams.(key) = params;
        end

        function renameRuntimeNodeParams(app, oldId, newId)
            oldKey = runtimeNodeKey(app, oldId);
            newKey = runtimeNodeKey(app, newId);
            if isfield(app.RuntimeNodeParams, oldKey)
                app.RuntimeNodeParams.(newKey) = app.RuntimeNodeParams.(oldKey);
                app.RuntimeNodeParams = rmfield(app.RuntimeNodeParams, oldKey);
            end
        end

        function renameSymbolicBindingReferences(app, oldId, newId)
            for i = 1:numel(app.Data.nodes)
                if isfield(app.Data.nodes(i), 'params') && isstruct(app.Data.nodes(i).params)
                    app.Data.nodes(i).params = renameSymbolicBindingStruct(app, app.Data.nodes(i).params, oldId, newId);
                end
            end

            keys = fieldnames(app.RuntimeNodeParams);
            for i = 1:numel(keys)
                key = keys{i};
                if isstruct(app.RuntimeNodeParams.(key))
                    app.RuntimeNodeParams.(key) = renameSymbolicBindingStruct(app, app.RuntimeNodeParams.(key), oldId, newId);
                end
            end
        end

        function params = renameSymbolicBindingStruct(app, params, oldId, newId)
            names = fieldnames(params);
            for i = 1:numel(names)
                key = names{i};
                params.(key) = renameSymbolicBindingValue(app, params.(key), oldId, newId);
            end
        end

        function value = renameSymbolicBindingValue(app, value, oldId, newId) %#ok<INUSD>
            if ischar(value) || (isstring(value) && isscalar(value))
                txt = char(string(value));
                if startsWith(strtrim(txt), '@resource:')
                    parts = strsplit(txt, ':');
                    if numel(parts) >= 3 && strcmp(parts{3}, oldId)
                        parts{3} = newId;
                        value = strjoin(parts, ':');
                    end
                elseif startsWith(strtrim(txt), '@')
                    pattern = ['output\s+from\s+' regexptranslate('escape', oldId) '(\s*/|\s*$)'];
                    replacement = ['output from ' newId '$1'];
                    value = regexprep(txt, pattern, replacement);
                end
            elseif iscell(value)
                for j = 1:numel(value)
                    value{j} = renameSymbolicBindingValue(app, value{j}, oldId, newId);
                end
            end
        end

        function removeRuntimeNodeParams(app, nodeId)
            key = runtimeNodeKey(app, nodeId);
            if isfield(app.RuntimeNodeParams, key)
                app.RuntimeNodeParams = rmfield(app.RuntimeNodeParams, key);
            end
        end

        function key = runtimeNodeKey(app, nodeId) %#ok<INUSD>
            key = matlab.lang.makeValidName(['node_' char(string(nodeId))]);
        end

        function out = mergeStructDefaults(app, out, defaults) %#ok<INUSD>
            if ~isstruct(out)
                out = struct();
            end
            fn = fieldnames(defaults);
            for i = 1:numel(fn)
                k = fn{i};
                if ~isfield(out, k) || isempty(out.(k))
                    out.(k) = defaults.(k);
                end
            end
        end

        function rects = getRoiManualRectangles(app, nodeId)
            params = getRuntimeNodeParams(app, nodeId);
            rects = zeros(0,4);
            if isfield(params, 'rectangles') && isnumeric(params.rectangles) && size(params.rectangles, 2) == 4
                rects = clipRoiManualRectangles(app, double(params.rectangles));
            end
        end

        function setRoiManualRectangles(app, nodeId, rects)
            params = getRuntimeNodeParams(app, nodeId);
            params = mergeStructDefaults(app, params, roiManual.setparam(struct()));
            params.rectangles = clipRoiManualRectangles(app, rects);
            setRuntimeNodeParams(app, nodeId, params);
        end

        function rects = clipRoiManualRectangles(app, rects) %#ok<INUSD>
            if isempty(rects)
                rects = zeros(0,4);
                return;
            end
            rects = double(rects(:,1:4));
            rects(~isfinite(rects)) = 0;
            rects(:,3:4) = max(rects(:,3:4), 0.02);
            rects(:,1:2) = max(rects(:,1:2), 0);
            rects(:,3) = min(rects(:,3), 1);
            rects(:,4) = min(rects(:,4), 1);
            rects(:,1) = min(rects(:,1), 1 - rects(:,3));
            rects(:,2) = min(rects(:,2), 1 - rects(:,4));
            rects(:,1:2) = max(rects(:,1:2), 0);
        end

        function data = roiManualRectanglesToTable(app, rects) %#ok<INUSD>
            data = cell(size(rects, 1), 5);
            for i = 1:size(rects, 1)
                data{i,1} = i;
                for j = 1:4
                    data{i,j+1} = rects(i,j);
                end
            end
        end

        function rects = roiManualTableToRectangles(app, data) %#ok<INUSD>
            rects = zeros(0,4);
            if isempty(data)
                return;
            end
            rects = zeros(size(data,1), 4);
            for i = 1:size(data,1)
                for j = 1:4
                    v = data{i,j+1};
                    if ischar(v) || isstring(v)
                        v = str2double(char(string(v)));
                    end
                    if isempty(v) || ~isnumeric(v) || ~isscalar(v) || ~isfinite(v)
                        v = 0;
                    end
                    rects(i,j) = double(v);
                end
            end
            rects = clipRoiManualRectangles(app, rects);
        end

        function drawRoiManualPreview(app, ax, nodeId, table, rects)
            clearRoiManualPreviewHandles(app);
            cla(ax);
            hold(ax, 'on');
            axis(ax, [0 1 0 1]);
            axis(ax, 'ij');
            ax.XTick = [];
            ax.YTick = [];
            rectangle(ax, 'Position', [0.03 0.05 0.94 0.88], 'FaceColor', [0.96 0.97 0.98], ...
                'EdgeColor', [0.18 0.24 0.30], 'LineWidth', 1.4);
            text(ax, 0.5, 0.965, 'normalized preview - data previewer comes next', ...
                'HorizontalAlignment', 'center', 'FontAngle', 'italic', 'Color', [0.35 0.35 0.35]);
            if isempty(rects)
                text(ax, 0.5, 0.49, 'No manual ROI rectangle', 'HorizontalAlignment', 'center', ...
                    'FontWeight', 'bold', 'Color', [0.35 0.35 0.35]);
            end
            for i = 1:size(rects, 1)
                color = [0.12 0.55 0.22];
                if isequal(i, app.RoiManualSelectedRectangle)
                    color = [1.00 0.65 0.00];
                end
                try
                    h = drawrectangle(ax, 'Position', rects(i,:), 'Color', color, 'LineWidth', 1.6);
                    h.UserData = struct('nodeId', nodeId, 'index', i);
                    try, h.Label = sprintf('R%d', i); catch, end
                    app.RoiManualPreviewHandles{end+1} = h; %#ok<AGROW>
                    app.RoiManualPreviewListeners{end+1} = addlistener(h, 'ROIMoved', @(src,~)roiManualRectangleMoved(app, src, table, ax)); %#ok<AGROW>
                catch
                    rectangle(ax, 'Position', rects(i,:), 'EdgeColor', color, 'LineWidth', 1.6);
                    text(ax, rects(i,1), max(0, rects(i,2)-0.02), sprintf('R%d', i), ...
                        'Color', color, 'FontWeight', 'bold');
                end
            end
            hold(ax, 'off');
            drawnow limitrate;
        end

        function clearRoiManualPreviewHandles(app)
            for i = 1:numel(app.RoiManualPreviewListeners)
                try, delete(app.RoiManualPreviewListeners{i}); catch, end
            end
            app.RoiManualPreviewListeners = {};
            for i = 1:numel(app.RoiManualPreviewHandles)
                try
                    if isvalid(app.RoiManualPreviewHandles{i})
                        delete(app.RoiManualPreviewHandles{i});
                    end
                catch
                end
            end
            app.RoiManualPreviewHandles = {};
        end

        function roiManualRuntimeOptionChanged(app, nodeId, key, value)
            params = getRuntimeNodeParams(app, nodeId);
            params = mergeStructDefaults(app, params, roiManual.setparam(struct()));
            params.(char(string(key))) = logical(value);
            setRuntimeNodeParams(app, nodeId, params);
            refreshValidationReport(app);
        end

        function roiManualAddRectangle(app, nodeId, table, ax)
            rects = getRoiManualRectangles(app, nodeId);
            n = size(rects, 1);
            offset = 0.04 * mod(n, 5);
            newRect = [0.18 + offset, 0.18 + offset, 0.28, 0.22];
            rects(end+1,:) = clipRoiManualRectangles(app, newRect); %#ok<AGROW>
            app.RoiManualSelectedRectangle = size(rects, 1);
            setRoiManualRectangles(app, nodeId, rects);
            table.Data = roiManualRectanglesToTable(app, rects);
            drawRoiManualPreview(app, ax, nodeId, table, rects);
            refreshValidationReport(app);
        end

        function roiManualClearSelectedRectangle(app, nodeId, table, ax)
            rects = getRoiManualRectangles(app, nodeId);
            idx = app.RoiManualSelectedRectangle;
            if isempty(idx) || isnan(idx) || idx < 1 || idx > size(rects, 1)
                try
                    sel = table.Selection;
                    if ~isempty(sel)
                        idx = sel(1,1);
                    end
                catch
                end
            end
            if isempty(idx) || isnan(idx) || idx < 1 || idx > size(rects, 1)
                return;
            end
            rects(idx,:) = [];
            app.RoiManualSelectedRectangle = NaN;
            setRoiManualRectangles(app, nodeId, rects);
            table.Data = roiManualRectanglesToTable(app, rects);
            drawRoiManualPreview(app, ax, nodeId, table, rects);
            refreshValidationReport(app);
        end

        function roiManualClearAllRectangles(app, nodeId, table, ax)
            app.RoiManualSelectedRectangle = NaN;
            rects = zeros(0,4);
            setRoiManualRectangles(app, nodeId, rects);
            table.Data = roiManualRectanglesToTable(app, rects);
            drawRoiManualPreview(app, ax, nodeId, table, rects);
            refreshValidationReport(app);
        end

        function roiManualRectangleTableEdited(app, nodeId, table, event)
            rects = roiManualTableToRectangles(app, table.Data);
            setRoiManualRectangles(app, nodeId, rects);
            table.Data = roiManualRectanglesToTable(app, rects);
            app.RoiManualSelectedRectangle = event.Indices(1);
            try
                parentTab = ancestor(table, 'matlab.ui.container.Tab');
                ax = findall(parentTab, 'Type', 'axes');
            catch
                ax = findall(app.TabGroup.SelectedTab, 'Type', 'axes');
            end
            if ~isempty(ax)
                drawRoiManualPreview(app, ax(1), nodeId, table, rects);
            end
            refreshValidationReport(app);
        end

        function roiManualRectangleSelectionChanged(app, event)
            if isempty(event.Selection)
                app.RoiManualSelectedRectangle = NaN;
            else
                app.RoiManualSelectedRectangle = event.Selection(1,1);
            end
        end

        function roiManualRectangleMoved(app, src, table, ax)
            try
                ud = src.UserData;
                nodeId = char(string(ud.nodeId));
                idx = double(ud.index);
            catch
                return;
            end
            rects = getRoiManualRectangles(app, nodeId);
            if idx < 1 || idx > size(rects, 1)
                return;
            end
            rects(idx,:) = clipRoiManualRectangles(app, double(src.Position));
            app.RoiManualSelectedRectangle = idx;
            setRoiManualRectangles(app, nodeId, rects);
            if isvalid(table)
                table.Data = roiManualRectanglesToTable(app, rects);
            end
            drawRoiManualPreview(app, ax, nodeId, table, rects);
            refreshValidationReport(app);
        end

        function grid = buildBindingSection(app, parent, data, node, editable)
            n = max(1, size(data, 1));
            grid = uigridlayout(parent, [n 3]);
            grid.RowHeight = repmat({28}, 1, n);
            grid.ColumnWidth = {96, 170, '1x'};
            grid.Padding = [0 0 0 0];
            grid.RowSpacing = 6;
            grid.ColumnSpacing = 8;

            for i = 1:size(data, 1)
                direction = char(string(data{i,1}));
                resourceLabel = char(string(data{i,2}));
                param = char(string(data{i,3}));
                value = data{i,4};
                choices = data{i,5};
                tooltip = char(string(data{i,6}));

                dirLabel = uilabel(grid, 'Text', direction);
                dirLabel.Layout.Row = i;
                dirLabel.Layout.Column = 1;
                dirLabel.Tooltip = tooltip;

                resLabel = uilabel(grid, 'Text', resourceLabel);
                resLabel.Layout.Row = i;
                resLabel.Layout.Column = 2;
                resLabel.Tooltip = tooltip;

                ctrl = createBindingControl(app, grid, node, param, value, choices, direction, editable);
                ctrl.Layout.Row = i;
                ctrl.Layout.Column = 3;
                ctrl.Tooltip = tooltip;
            end
        end

        function ctrl = createBindingControl(app, parent, node, param, value, choices, direction, editable)
            enableState = ternary(app, editable, 'on', 'off');
            isInput = strcmpi(char(string(direction)), 'Input');
            if isInput || ~isempty(choices)
                if isempty(choices)
                    choices = {choiceScalarText(app, value)};
                end
                choices = flattenChoiceList(app, choices);
                choices = choices(~cellfun(@isempty, choices));
                if isempty(choices)
                    choices = {'<unresolved>'};
                end
                displayValue = choiceScalarText(app, value);
                if isempty(displayValue) || ~any(strcmp(choices, displayValue))
                    displayValue = choices{1};
                end
                ctrl = uidropdown(parent);
                ctrl.Items = choices;
                ctrl.Value = displayValue;
                ctrl.Enable = enableState;
                ctrl.ValueChangedFcn = @(src,~)bindingControlChanged(app, node, param, direction, src.Value);
                return;
            end

            ctrl = uieditfield(parent, 'text');
            ctrl.Value = choiceScalarText(app, value);
            ctrl.Enable = enableState;
            ctrl.ValueChangedFcn = @(src,~)bindingControlChanged(app, node, param, direction, src.Value);
        end

        function bindingControlChanged(app, node, param, direction, value)
            nodeId = char(string(getField(app, node, 'id', '')));
            idx = find(strcmp({app.Data.nodes.id}, nodeId), 1);
            if isempty(idx) || isempty(param)
                return;
            end
            param = char(string(param));
            value = strtrim(char(string(value)));
            isInput = strcmpi(char(string(direction)), 'Input');

            if ~isfield(app.Data.nodes(idx), 'params') || ~isstruct(app.Data.nodes(idx).params)
                app.Data.nodes(idx).params = struct();
            end

            if isSymbolicBindingLabel(app, value)
                symbolicValue = symbolicBindingValueFromLabel(app, value);
                app.Data.nodes(idx).params.(param) = symbolicValue;
                if isInput
                    runtimeParams = getRuntimeNodeParams(app, nodeId);
                    runtimeParams.(param) = symbolicValue;
                    setRuntimeNodeParams(app, nodeId, runtimeParams);
                end
            elseif isempty(value) || strcmp(value, '<unresolved>')
                if isfield(app.Data.nodes(idx).params, param)
                    app.Data.nodes(idx).params = rmfield(app.Data.nodes(idx).params, param);
                end
                if isInput
                    runtimeParams = getRuntimeNodeParams(app, nodeId);
                    if isstruct(runtimeParams) && isfield(runtimeParams, param)
                        runtimeParams = rmfield(runtimeParams, param);
                        setRuntimeNodeParams(app, nodeId, runtimeParams);
                    end
                end
            else
                app.Data.nodes(idx).params.(param) = value;
                if isInput
                    runtimeParams = getRuntimeNodeParams(app, nodeId);
                    runtimeParams.(param) = value;
                    setRuntimeNodeParams(app, nodeId, runtimeParams);
                end
            end

            refreshModuleTabs(app);
            refreshValidationReport(app);
        end

        function data = bindingTableData(app, node)
            data = cell(0, 6);
            try
                contract = pipelineNodeContract(node);
            catch
                contract = getField(app, node, 'contract', struct());
            end
            resources = getField(app, contract, 'resources', struct());
            inputs = getField(app, resources, 'in', struct([]));
            outputs = getField(app, resources, 'out', struct([]));

            for i = 1:numel(inputs)
                spec = inputs(i);
                if isempty(char(string(getField(app, spec, 'type', ''))))
                    continue;
                end
                param = char(string(getField(app, spec, 'param', '')));
                resourceLabel = resourceSpecLabel(app, spec);
                value = bindingDisplayedValue(app, node, spec, true);
                choices = bindingInputChoices(app, node, spec, value);
                tooltip = ['Input binding for ' resourceLabel '. Symbolic choices are resolved from upstream modules at run time.'];
                data(end+1,:) = {'Input', resourceLabel, param, value, {choices}, tooltip}; %#ok<AGROW>
            end

            for i = 1:numel(outputs)
                spec = outputs(i);
                if isempty(char(string(getField(app, spec, 'type', ''))))
                    continue;
                end
                param = char(string(getField(app, spec, 'nameParam', '')));
                if isempty(param)
                    param = char(string(getField(app, spec, 'param', '')));
                end
                if isempty(param)
                    continue;
                end
                resourceLabel = resourceSpecLabel(app, spec);
                value = bindingDisplayedValue(app, node, spec, false);
                tooltip = ['Output binding for ' resourceLabel '. This names the concrete resource written by the module.'];
                data(end+1,:) = {'Output', resourceLabel, param, value, {}, tooltip}; %#ok<AGROW>
            end
        end

        function value = bindingDisplayedValue(app, node, spec, isInput)
            value = '';
            nodeId = char(string(getField(app, node, 'id', '')));
            param = char(string(getField(app, spec, 'param', '')));
            if ~isInput
                nameParam = char(string(getField(app, spec, 'nameParam', '')));
                if ~isempty(nameParam)
                    param = nameParam;
                end
            end

            p = getField(app, node, 'params', struct());
            if isInput && isstruct(p) && isfield(p, param) && isSymbolicStoredBinding(app, p.(param))
                if symbolicBindingIsActive(app, p.(param))
                    value = bindingValueToDisplay(app, choiceScalarText(app, p.(param)), node, spec);
                    return;
                end
            end

            runtimeParams = getRuntimeNodeParams(app, nodeId);
            if isInput && isstruct(runtimeParams) && isfield(runtimeParams, param) && ...
                    isConfiguredBindingValue(app, runtimeParams.(param))
                if isSymbolicStoredBinding(app, runtimeParams.(param)) && ~symbolicBindingIsActive(app, runtimeParams.(param))
                    value = '';
                else
                    value = bindingValueToDisplay(app, choiceScalarText(app, runtimeParams.(param)), node, spec);
                    return;
                end
            end

            if isstruct(p) && isfield(p, param) && (~isInput || isConfiguredBindingValue(app, p.(param))) && ...
                    (~isInput || ~isSymbolicStoredBinding(app, p.(param)) || symbolicBindingIsActive(app, p.(param)))
                value = bindingValueToDisplay(app, choiceScalarText(app, p.(param)), node, spec);
            end
            if ~isInput && isempty(value)
                value = char(string(getField(app, node, 'id', '')));
            end
        end

        function tf = symbolicBindingIsActive(app, value)
            tf = true;
            sourceNode = symbolicBindingSourceNode(app, choiceScalarText(app, value));
            if isempty(sourceNode)
                return;
            end
            tf = isRunNodeActive(app, sourceNode);
        end

        function displayValue = bindingValueToDisplay(app, value, node, spec)
            displayValue = strtrim(char(string(value)));
            if ~startsWith(displayValue, '@')
                return;
            end

            sourceNode = symbolicBindingSourceNode(app, displayValue);
            if ~isempty(sourceNode)
                available = upstreamCompatibleResources(app, node, spec);
                for i = 1:numel(available)
                    if strcmp(char(string(getField(app, available(i), 'sourceNode', ''))), sourceNode)
                        label = resourceChoiceLabel(app, available(i), spec);
                        if ~isempty(label)
                            displayValue = label;
                            return;
                        end
                    end
                end
                inactiveLabel = inactiveSymbolicBindingLabel(app, displayValue, node, spec);
                if ~isempty(inactiveLabel)
                    displayValue = inactiveLabel;
                    return;
                end
            end

            displayValue = ['<' displayValue(2:end) '>'];
        end

        function label = inactiveSymbolicBindingLabel(app, value, node, spec)
            label = '';
            sourceNode = symbolicBindingSourceNode(app, value);
            if isempty(sourceNode)
                return;
            end
            activeIds = selectedRunNodeIds(app);
            if isempty(activeIds) || any(strcmp(activeIds, sourceNode))
                return;
            end
            ids = {};
            if ~isempty(app.Data.nodes)
                ids = cellstr(string({app.Data.nodes.id}));
            end
            srcIdx = find(strcmp(ids, sourceNode), 1);
            if isempty(srcIdx)
                return;
            end
            srcNode = app.Data.nodes(srcIdx);
            role = char(string(getField(app, spec, 'role', 'resource')));
            concrete = '';
            try
                contract = pipelineNodeContract(srcNode);
                outs = getField(app, getField(app, contract, 'resources', struct()), 'out', struct([]));
                wantedType = lower(char(string(getField(app, spec, 'type', ''))));
                wantedRole = lower(char(string(getField(app, spec, 'role', ''))));
                for i = 1:numel(outs)
                    outType = lower(char(string(getField(app, outs(i), 'type', ''))));
                    outRole = lower(char(string(getField(app, outs(i), 'role', ''))));
                    if strcmp(outType, wantedType) && (isempty(wantedRole) || isempty(outRole) || strcmp(outRole, wantedRole))
                        concrete = outputBindingNameForNode(app, srcNode, outs(i));
                        role = char(string(getField(app, outs(i), 'role', role)));
                        break;
                    end
                end
            catch
            end
            if isempty(concrete)
                label = ['<' role ' output from ' sourceNode ' (inactive)>'];
            else
                label = ['<' role ' output from ' sourceNode ' / ' concrete ' (inactive)>'];
            end
        end

        function choices = bindingInputChoices(app, node, spec, currentValue)
            choices = {};
            currentValue = choiceScalarText(app, currentValue);

            inputReport = currentResourceInputReport(app, node, spec);
            available = struct([]);
            if isstruct(inputReport)
                if isfield(inputReport, 'available') && ~isempty(inputReport.available)
                    available = inputReport.available;
                elseif isfield(inputReport, 'autoChoice') && ~isempty(inputReport.autoChoice)
                    available = inputReport.autoChoice;
                end
            end
            if isempty(available)
                available = upstreamCompatibleResources(app, node, spec);
            end
            runtimeChoices = runtimeBindingChoices(app, spec);
            upstreamChoices = {};

            for i = 1:numel(available)
                label = resourceChoiceLabel(app, available(i), spec);
                sourceKind = lower(char(string(getField(app, available(i), 'sourceKind', ''))));
                if ~isempty(label)
                    if any(strcmp(sourceKind, {'context','ctx','runtime'}))
                        runtimeChoices{end+1} = label; %#ok<AGROW>
                    else
                        upstreamChoices{end+1} = label; %#ok<AGROW>
                    end
                end
                concrete = char(string(getField(app, available(i), 'concreteName', '')));
                if ~isempty(concrete) && any(strcmp(sourceKind, {'context','ctx','runtime'}))
                    runtimeChoices{end+1} = concrete; %#ok<AGROW>
                end
            end
            choices = [upstreamChoices runtimeChoices]; %#ok<AGROW>

            if isempty(choices)
                choices = graphResourceChoiceLabels(app, node, spec);
            end

            if isempty(choices) && ~isempty(currentValue)
                choices{end+1} = currentValue; %#ok<AGROW>
            end

            if isempty(choices)
                role = char(string(getField(app, spec, 'role', 'resource')));
                choices = {['<' role ' output>']};
            end
            choices = unique(choices(~cellfun(@isempty, choices)), 'stable');
        end

        function choices = runtimeBindingChoices(app, spec)
            choices = {};
            type = lower(char(string(getField(app, spec, 'type', ''))));
            role = lower(char(string(getField(app, spec, 'role', ''))));
            if strcmp(type, 'channel') && strcmp(role, 'roi_image')
                choices = runtimeConcreteChannels(app);
            elseif strcmp(type, 'channel') && strcmp(role, 'source')
                choices = runtimeConcreteChannels(app);
            elseif strcmp(type, 'dataseries') || strcmp(type, 'dataSeries')
                choices = runtimeDataSeriesChoices(app, role);
            end
        end

        function channels = runtimeConcreteChannels(app)
            channels = {};
            if isfield(app.RuntimeParseInfo, 'channels') && ~isempty(app.RuntimeParseInfo.channels)
                channels = cellstr(string(app.RuntimeParseInfo.channels(:)'));
            end
            skip = startsWith(lower(string(channels)), 'resolved after') | strcmpi(string(channels), 'all') | strcmpi(string(channels), 'auto');
            channels = channels(~skip);
            channels = unique(channels(~cellfun(@isempty, channels)), 'stable');
        end

        function choices = runtimeDataSeriesChoices(app, role)
            choices = {};
            try
                names = runtimeDataSeriesNames(app);
                if isempty(names)
                    return;
                end
                if strcmpi(role, 'classification')
                    keep = contains(lower(string(names)), "div") | contains(lower(string(names)), "class") | contains(lower(string(names)), "cnn") | contains(lower(string(names)), "lstm");
                    names = names(keep);
                end
                choices = unique(names(~cellfun(@isempty, names)), 'stable');
            catch
                choices = {};
            end
        end

        function names = runtimeDataSeriesNames(app)
            names = {};
            try
                roiList = runtimeSelectedRois(app);
                if isempty(roiList)
                    return;
                end
                maxRoi = min(numel(roiList), 10);
                for r = 1:maxRoi
                    roiObj = roiList(r);
                    try
                        roiObj.load('data');
                    catch
                    end
                    if ~isprop(roiObj, 'data') || isempty(roiObj.data)
                        continue;
                    end
                    ds = roiObj.data;
                    for i = 1:numel(ds)
                        if isprop(ds(i), 'groupid') && ~isempty(ds(i).groupid)
                            names{end+1} = char(string(ds(i).groupid)); %#ok<AGROW>
                        elseif isprop(ds(i), 'id') && ~isempty(ds(i).id)
                            names{end+1} = char(string(ds(i).id)); %#ok<AGROW>
                        elseif isprop(ds(i), 'name') && ~isempty(ds(i).name)
                            names{end+1} = char(string(ds(i).name)); %#ok<AGROW>
                        end
                    end
                end
                names = unique(names(~cellfun(@isempty, names)), 'stable');
            catch
                names = {};
            end
        end

        function roiList = runtimeSelectedRois(app)
            roiList = [];
            if isempty(app.CurrentProject) || ~isa(app.CurrentProject, 'shallow')
                return;
            end
            try
                fovIdx = parseIndexSelection(app, getRuntimeValue(app, 'fovs'));
                if isempty(fovIdx)
                    fovIdx = 1:numel(app.CurrentProject.fov);
                end
                fovIdx = fovIdx(fovIdx >= 1 & fovIdx <= numel(app.CurrentProject.fov));
                if isempty(fovIdx)
                    return;
                end
                roiSel = parseLooseSelection(app, getRuntimeValue(app, 'rois'));
                f = app.CurrentProject.fov(fovIdx(1));
                if isempty(f.roi)
                    return;
                end
                if isempty(roiSel)
                    roiIdx = 1:numel(f.roi);
                elseif isnumeric(roiSel)
                    roiIdx = round(double(roiSel(:)'));
                    roiIdx = roiIdx(roiIdx >= 1 & roiIdx <= numel(f.roi));
                else
                    roiIdx = 1:numel(f.roi);
                end
                if isempty(roiIdx)
                    return;
                end
                roiList = f.roi(roiIdx);
            catch
                roiList = [];
            end
        end

        function labels = graphResourceChoiceLabels(app, node, spec)
            labels = {};
            nodeId = char(string(getField(app, node, 'id', '')));
            wantedType = lower(char(string(getField(app, spec, 'type', ''))));
            wantedRole = lower(char(string(getField(app, spec, 'role', ''))));
            if isempty(nodeId) || isempty(app.Data.nodes)
                return;
            end
            for i = 1:numel(app.Data.nodes)
                srcNode = app.Data.nodes(i);
                sourceNode = char(string(getField(app, srcNode, 'id', '')));
                if isempty(sourceNode) || strcmp(sourceNode, nodeId)
                    continue;
                end
                if ~isRunNodeActive(app, sourceNode)
                    continue;
                end
                if isfield(srcNode, 'contract')
                    srcNode = rmfield(srcNode, 'contract');
                end
                try
                    contract = pipelineNodeContract(srcNode);
                catch
                    continue;
                end
                resources = getField(app, contract, 'resources', struct());
                outs = getField(app, resources, 'out', struct([]));
                for j = 1:numel(outs)
                    outSpec = outs(j);
                    outType = lower(char(string(getField(app, outSpec, 'type', ''))));
                    outRole = lower(char(string(getField(app, outSpec, 'role', ''))));
                    if ~strcmp(outType, wantedType)
                        continue;
                    end
                    if ~isempty(wantedRole) && ~isempty(outRole) && ~strcmp(outRole, wantedRole)
                        continue;
                    end
                    concrete = outputBindingNameForNode(app, srcNode, outSpec);
                    role = char(string(getField(app, outSpec, 'role', wantedRole)));
                    if isempty(concrete)
                        labels{end+1} = ['<' role ' output from ' sourceNode '>']; %#ok<AGROW>
                    else
                        labels{end+1} = ['<' role ' output from ' sourceNode ' / ' concrete '>']; %#ok<AGROW>
                    end
                end
            end
            labels = unique(labels(~cellfun(@isempty, labels)), 'stable');
        end

        function name = outputBindingNameForNode(app, node, spec)
            name = '';
            params = getField(app, node, 'params', struct());
            nameParam = char(string(getField(app, spec, 'nameParam', '')));
            if ~isempty(nameParam) && isstruct(params) && isfield(params, nameParam) && ~isempty(params.(nameParam))
                name = choiceScalarText(app, params.(nameParam));
                return;
            end
            param = char(string(getField(app, spec, 'param', '')));
            if ~isempty(param) && isstruct(params) && isfield(params, param) && ~isempty(params.(param))
                name = choiceScalarText(app, params.(param));
                return;
            end
            name = char(string(getField(app, node, 'id', '')));
        end

        function resources = upstreamCompatibleResources(app, node, spec)
            resources = struct([]);
            nodeId = char(string(getField(app, node, 'id', '')));
            if isempty(nodeId) || isempty(app.Data.nodes)
                return;
            end

            sourceIds = {};
            edges = app.Data.edges;
            for i = 1:numel(edges)
                if strcmp(char(string(getField(app, edges(i), 'to', ''))), nodeId)
                    sourceIds{end+1} = char(string(getField(app, edges(i), 'from', ''))); %#ok<AGROW>
                end
            end
            ids = cellstr(string({app.Data.nodes.id}));
            idx = find(strcmp(ids, nodeId), 1);
            if ~isempty(idx) && idx > 1
                sourceIds = [sourceIds ids(1:idx-1)]; %#ok<AGROW>
            end
            sourceIds = unique(sourceIds(~cellfun(@isempty, sourceIds)), 'stable');

            wantedType = lower(char(string(getField(app, spec, 'type', ''))));
            wantedRole = lower(char(string(getField(app, spec, 'role', ''))));
            for i = 1:numel(sourceIds)
                if ~isRunNodeActive(app, sourceIds{i})
                    continue;
                end
                srcIdx = find(strcmp({app.Data.nodes.id}, sourceIds{i}), 1);
                if isempty(srcIdx)
                    continue;
                end
                srcNode = app.Data.nodes(srcIdx);
                if isfield(srcNode, 'contract')
                    srcNode = rmfield(srcNode, 'contract');
                end
                try
                    contract = pipelineNodeContract(srcNode);
                catch
                    continue;
                end
                outs = getField(app, getField(app, contract, 'resources', struct()), 'out', struct([]));
                for j = 1:numel(outs)
                    outSpec = outs(j);
                    outType = lower(char(string(getField(app, outSpec, 'type', ''))));
                    outRole = lower(char(string(getField(app, outSpec, 'role', ''))));
                    if ~strcmp(outType, wantedType)
                        continue;
                    end
                    if ~isempty(wantedRole) && ~isempty(outRole) && ~strcmp(outRole, wantedRole)
                        continue;
                    end
                    resources = appendStruct(app, resources, makeUiResourceChoice(app, srcNode, outSpec)); %#ok<AGROW>
                end
            end
        end

        function resource = makeUiResourceChoice(app, srcNode, outSpec)
            sourceNode = char(string(getField(app, srcNode, 'id', '')));
            sourcePort = char(string(getField(app, outSpec, 'port', '')));
            sourceKind = char(string(getField(app, outSpec, 'transfer', '')));
            concreteName = '';
            nameParam = char(string(getField(app, outSpec, 'nameParam', '')));
            params = getField(app, srcNode, 'params', struct());
            if ~isempty(nameParam) && isstruct(params) && isfield(params, nameParam) && ~isempty(params.(nameParam))
                concreteName = choiceScalarText(app, params.(nameParam));
            end
            if isempty(concreteName)
                param = char(string(getField(app, outSpec, 'param', '')));
                if ~isempty(param) && isstruct(params) && isfield(params, param) && ~isempty(params.(param))
                    concreteName = choiceScalarText(app, params.(param));
                end
            end
            if isempty(concreteName)
                concreteName = sourceNode;
            end
            symbol = char(string(getField(app, outSpec, 'symbol', '')));
            if isempty(symbol)
                symbol = sourcePort;
            end
            if ~contains(symbol, '.')
                symbol = [sourceNode '.' symbol];
            end
            resource = struct( ...
                'type', char(string(getField(app, outSpec, 'type', ''))), ...
                'role', char(string(getField(app, outSpec, 'role', ''))), ...
                'symbol', symbol, ...
                'concreteName', concreteName, ...
                'sourceNode', sourceNode, ...
                'sourcePort', sourcePort, ...
                'sourceKind', sourceKind);
        end

        function tf = isRunNodeActive(app, nodeId)
            tf = true;
            selectedIds = selectedRunNodeIds(app);
            if isempty(selectedIds)
                return;
            end
            tf = any(strcmp(selectedIds, char(string(nodeId))));
        end

        function inputReport = currentResourceInputReport(app, node, spec)
            inputReport = struct();
            try
                pipe = buildPipelineStruct(app);
                ctx = buildBindingValidationContext(app);
                [~, report] = validatePipeline(pipe, ctx, struct('allowGui', false));
                nodeId = char(string(getField(app, node, 'id', '')));
                nodeKey = matlab.lang.makeValidName(nodeId);
                if ~isfield(report, 'binding') || ~isfield(report.binding, 'nodes') || ~isfield(report.binding.nodes, nodeKey)
                    return;
                end
                br = report.binding.nodes.(nodeKey);
                if ~isfield(br, 'resources') || ~isfield(br.resources, 'inputs')
                    return;
                end
                inputs = br.resources.inputs;
                param = char(string(getField(app, spec, 'param', '')));
                for j = 1:numel(inputs)
                    if strcmp(char(string(getField(app, inputs(j), 'param', ''))), param)
                        inputReport = inputs(j);
                        return;
                    end
                end
            catch
                inputReport = struct();
            end
        end

        function label = resourceChoiceLabel(app, resource, spec)
            label = '';
            sourceNode = char(string(getField(app, resource, 'sourceNode', '')));
            sourceKind = lower(char(string(getField(app, resource, 'sourceKind', ''))));
            role = char(string(getField(app, resource, 'role', getField(app, spec, 'role', 'resource'))));
            type = char(string(getField(app, resource, 'type', getField(app, spec, 'type', 'resource'))));
            concrete = char(string(getField(app, resource, 'concreteName', '')));
            if ~isempty(sourceNode) && ~any(strcmp(sourceKind, {'context','ctx','runtime'}))
                if ~isempty(concrete)
                    label = ['<' role ' output from ' sourceNode ' / ' concrete '>'];
                else
                    label = ['<' role ' output from ' sourceNode '>'];
                end
            elseif ~isempty(concrete)
                label = concrete;
            else
                label = ['<' type '/' role '>'];
            end
        end

        function label = resourceSpecLabel(app, spec) %#ok<INUSD>
            type = char(string(getField(app, spec, 'type', 'resource')));
            role = char(string(getField(app, spec, 'role', '')));
            if isempty(role)
                label = type;
            else
                label = [type '/' role];
            end
        end

        function tf = isSymbolicBindingLabel(app, value) %#ok<INUSD>
            value = strtrim(char(string(value)));
            tf = startsWith(value, '<') && endsWith(value, '>');
        end

        function value = symbolicBindingValueFromLabel(app, label)
            label = strtrim(char(string(label)));
            value = label;
            if ~(startsWith(label, '<') && endsWith(label, '>'))
                return;
            end
            inner = strtrim(label(2:end-1));
            tokens = regexp(inner, '^(.+?)\s+output\s+from\s+([^/\s]+)(?:\s*/\s*.*)?$', 'tokens', 'once');
            if ~isempty(tokens)
                role = regexprep(strtrim(tokens{1}), '\s+', '_');
                sourceNode = strtrim(tokens{2});
                value = ['@resource:' role ':' sourceNode];
            else
                value = ['@' inner];
            end
        end

        function sourceNode = symbolicBindingSourceNode(app, value) %#ok<INUSD>
            sourceNode = '';
            value = strtrim(char(string(value)));
            if startsWith(value, '@resource:')
                parts = strsplit(value, ':');
                if numel(parts) >= 3
                    sourceNode = strtrim(parts{3});
                end
                return;
            end
            if startsWith(value, '@')
                value = extractAfter(value, 1);
            end
            tokens = regexp(value, 'output\s+from\s+([^/\s>]+)', 'tokens', 'once');
            if ~isempty(tokens)
                sourceNode = strtrim(tokens{1});
            end
        end

        function tf = isConfiguredBindingValue(app, value) %#ok<INUSD>
            tf = false;
            if isempty(value)
                return;
            end
            if iscell(value)
                flat = value(~cellfun(@isempty, value));
                if isempty(flat)
                    return;
                end
                % setparam often returns cell arrays as choice lists, with the
                % selected/default value duplicated at the end. Those are not
                % explicit user bindings and should not hide upstream symbols.
                if numel(flat) > 1
                    return;
                end
            end
            tf = true;
        end

        function tf = isSymbolicStoredBinding(app, value) %#ok<INUSD>
            tf = startsWith(strtrim(choiceScalarText(app, value)), '@');
        end

        function ctx = buildBindingValidationContext(app)
            ctx = struct('allowGUI', false);
            try
                ctx = buildRunContext(app);
            catch
            end
            ctx.allowGUI = false;
            ctx.interactive = false;
            ctx.dryRun = true;
            if ~isfield(ctx, 'roiList') || isempty(ctx.roiList)
                roiList = runtimeSelectedRois(app);
                if isempty(roiList)
                    ctx.roiList = 1;
                else
                    ctx.roiList = roiList;
                end
            end
            if ~isfield(ctx, 'channels') || isempty(ctx.channels)
                runtimeChannels = runtimeConcreteChannels(app);
                if isempty(runtimeChannels)
                    runtimeChannels = {'<runtime channel>'};
                end
                ctx.channels = runtimeChannels;
            end
            if ~isfield(ctx, 'roiChannels') || isempty(ctx.roiChannels)
                runtimeChannels = runtimeConcreteChannels(app);
                if ~isempty(runtimeChannels)
                    ctx.roiChannels = runtimeChannels;
                end
            end
        end

        function txt = choiceScalarText(app, v) %#ok<INUSD>
            txt = '';
            if isempty(v)
                return;
            end
            if iscell(v)
                flat = v(~cellfun(@isempty, v));
                if isempty(flat)
                    return;
                end
                txt = char(string(flat{end}));
            elseif ischar(v)
                txt = v;
            elseif isstring(v) || isnumeric(v) || islogical(v) || iscategorical(v)
                vals = string(v(:));
                if ~isempty(vals)
                    txt = char(vals(end));
                end
            else
                try
                    txt = char(string(v));
                catch
                    txt = '';
                end
            end
            txt = strtrim(txt);
        end

        function choices = flattenChoiceList(app, value) %#ok<INUSD>
            choices = {};
            if isempty(value)
                return;
            end
            if iscell(value)
                for ii = 1:numel(value)
                    nested = flattenChoiceList(app, value{ii});
                    choices = [choices nested]; %#ok<AGROW>
                end
            elseif ischar(value)
                choices = {strtrim(value)};
            elseif isstring(value) || isnumeric(value) || islogical(value) || iscategorical(value)
                vals = cellstr(string(value(:)'));
                choices = cellfun(@(s)strtrim(char(string(s))), vals, 'UniformOutput', false);
            else
                try
                    choices = {strtrim(char(string(value)))};
                catch
                    choices = {};
                end
            end
            choices = unique(choices(~cellfun(@isempty, choices)), 'stable');
        end

        function grid = buildParamSection(app, parent, data, node, editable)
            n = max(1, size(data, 1));
            grid = uigridlayout(parent, [n 2]);
            grid.RowHeight = repmat({28}, 1, n);
            grid.ColumnWidth = {138, '1x'};
            grid.Padding = [0 0 0 0];
            grid.RowSpacing = 6;
            grid.ColumnSpacing = 8;

            for i = 1:size(data, 1)
                key = char(string(data{i,1}));
                label = uilabel(grid, 'Text', friendlyParamLabel(app, key));
                label.Layout.Row = i;
                label.Layout.Column = 1;
                label.Tooltip = key;

                value = resolveDisplayedParamValue(app, node, key, data{i,2});
                ctrl = createParamControl(app, grid, node, key, value, editable);
                ctrl.Layout.Row = i;
                ctrl.Layout.Column = 2;
            end
        end

        function value = resolveDisplayedParamValue(app, node, key, defaultValue)
            value = defaultValue;
            p = getField(app, node, 'params', struct());
            if isstruct(p) && isfield(p, key)
                value = p.(key);
            end

            nodeType = char(string(getField(app, node, 'type', '')));
            if strcmpi(nodeType, 'dataLoader') && strcmpi(char(string(key)), 'path')
                rawDataPath = getRuntimeValue(app, 'rawDataPath');
                if ~isempty(strtrim(rawDataPath))
                    value = rawDataPath;
                end
            end
        end

        function ctrl = createParamControl(app, parent, node, key, value, editable)
            nodeType = lower(char(string(getField(app, node, 'type', ''))));
            keyLower = lower(char(string(key)));
            enableState = ternary(app, editable, 'on', 'off');

            choices = paramDropdownChoices(app, node, key);
            listChoices = valueListChoices(app, value);
            if isempty(choices) && ~isempty(listChoices)
                choices = listChoices;
            end
            if ~isempty(choices)
                ctrl = uidropdown(parent);
                ctrl.Items = choices;
                displayValue = choiceScalarText(app, value);
                if isempty(displayValue) || ~any(strcmp(choices, displayValue))
                    displayValue = choices{1};
                end
                ctrl.Value = displayValue;
                ctrl.Enable = enableState;
                ctrl.ValueChangedFcn = @(src,~)paramControlChanged(app, node, key, src.Value);
                return;
            end

            if islogical(value) || any(strcmpi(char(string(value)), {'true','false'}))
                ctrl = uicheckbox(parent, 'Text', '');
                if islogical(value)
                    ctrl.Value = logical(value);
                else
                    ctrl.Value = strcmpi(char(string(value)), 'true');
                end
                ctrl.Enable = enableState;
                ctrl.ValueChangedFcn = @(src,~)paramControlChanged(app, node, key, src.Value);
                return;
            end

            if isnumeric(value) && isscalar(value)
                ctrl = uieditfield(parent, 'numeric');
                ctrl.Value = double(value);
                ctrl.Enable = enableState;
                ctrl.ValueChangedFcn = @(src,~)paramControlChanged(app, node, key, src.Value);
                return;
            end

            ctrl = uieditfield(parent, 'text');
            ctrl.Value = paramValueToDisplay(app, node, key, value);
            ctrl.Enable = enableState;
            ctrl.ValueChangedFcn = @(src,~)paramControlChanged(app, node, key, src.Value);
        end

        function choices = paramDropdownChoices(app, node, key) %#ok<INUSD>
            nodeType = lower(char(string(getField(app, node, 'type', ''))));
            keyLower = lower(char(string(key)));
            choices = {};
            switch nodeType
                case 'roiextract'
                    switch keyLower
                        case 'driftmethod'
                            choices = {'subpixel','circshift','register'};
                        case 'driftrefmode'
                            choices = {'previous','first'};
                        case 'driftchannel'
                            choices = runtimeChannelChoices(app, true);
                    end
            end
        end

        function choices = valueListChoices(app, value) %#ok<INUSD>
            choices = {};
            if ~iscell(value) || numel(value) < 2
                return;
            end
            try
                choices = flattenChoiceList(app, value);
            catch
                choices = {};
            end
        end

        function choices = runtimeChannelChoices(app, includeEmpty)
            if nargin < 2
                includeEmpty = false;
            end
            choices = {};
            if includeEmpty
                choices = {'auto'};
            end
            if isfield(app.RuntimeParseInfo, 'channels') && ~isempty(app.RuntimeParseInfo.channels)
                parsed = cellstr(string(app.RuntimeParseInfo.channels(:)'));
                choices = [choices parsed]; %#ok<AGROW>
            end
            choices = unique(choices(~cellfun(@isempty, choices)), 'stable');
        end

        function paramControlChanged(app, node, key, value)
            nodeId = char(string(getField(app, node, 'id', '')));
            idx = find(strcmp({app.Data.nodes.id}, nodeId), 1);
            if isempty(idx)
                return;
            end
            if ~isfield(app.Data.nodes(idx), 'params') || ~isstruct(app.Data.nodes(idx).params)
                app.Data.nodes(idx).params = struct();
            end
            if strcmpi(char(string(key)), 'driftChannel') && strcmpi(char(string(value)), 'auto')
                value = [];
            end
            app.Data.nodes(idx).params.(char(string(key))) = value;

            nodeType = char(string(getField(app, app.Data.nodes(idx), 'type', '')));
            if strcmpi(nodeType, 'dataLoader') && strcmpi(char(string(key)), 'path')
                setRuntimeValue(app, 'rawDataPath', value);
            else
                refreshValidationReport(app);
            end
        end

        function data = paramsToTableData(app, node, scope)
            keys = moduleParamKeys(app, node, scope);
            keys = unique(keys(~cellfun(@isempty, keys)), 'stable');
            keys = filterParamsByAdvancedMode(app, node, keys);
            p = getField(app, node, 'params', struct());
            data = cell(numel(keys), 2);
            for i = 1:numel(keys)
                data{i,1} = keys{i};
                if isstruct(p) && isfield(p, keys{i})
                    data{i,2} = paramValueToDisplay(app, node, keys{i}, p.(keys{i}));
                else
                    data{i,2} = '';
                end
            end
        end

        function vals = getParamList(app, params, fieldName) %#ok<INUSD>
            vals = {};
            if isstruct(params) && isfield(params, fieldName) && ~isempty(params.(fieldName))
                vals = cellstr(string(params.(fieldName)(:)))';
            end
        end

        function keys = moduleParamKeys(app, node, scope)
            nodeType = lower(char(string(getField(app, node, 'type', ''))));
            pkg = lower(char(string(getField(app, node, 'pkg', ''))));
            isStatic = strcmpi(scope, 'static');

            if isStatic
                switch nodeType
                    case 'dataloader'
                        keys = {};
                    case 'roigrid'
                        keys = {'gridCount'};
                    case {'roipattern','roiidentify','roimanual'}
                        keys = {};
                    case 'roiextract'
                        keys = {'correctDrift','driftChannel','driftMethod','driftRefMode','driftSubpixel','driftMaxShift','scale','cropDrift','forceChannelNames'};
                    case 'processor'
                        keys = processorStaticKeys(app, pkg);
                    case 'classifier'
                        keys = {'pkg','modulePath','moduleId','classes','classifyFun','trainingFun','trainingParam','outputType'};
                    otherwise
                        keys = contractParamKeys(app, node, scope);
                end
            else
                switch nodeType
                    case 'dataloader'
                        keys = {'path'};
                    case {'roipattern','roiidentify'}
                        keys = {'threshold','referenceFrame','channel','channelIndex','keepExisting','fallbackFullFrame'};
                    case 'roimanual'
                        keys = {'keepExisting','skipExisting','errorOnExisting','openFirstOnly'};
                    case 'roigrid'
                        keys = {'keepExisting'};
                    case 'roitracked'
                        keys = {'keepExisting'};
                    case 'roiextract'
                        keys = {};
                    case 'processor'
                        keys = processorRuntimeKeys(app, pkg);
                    case 'classifier'
                        keys = {};
                    otherwise
                        keys = contractParamKeys(app, node, scope);
                end
            end
            keys = removeGlobalRuntimeKeys(app, keys);
        end

        function keys = contractParamKeys(app, node, scope)
            try
                contract = pipelineNodeContract(node);
            catch
                contract = struct();
            end
            keys = {};
            if isstruct(contract) && isfield(contract, 'parameters') && isstruct(contract.parameters)
                params = contract.parameters;
                switch lower(scope)
                    case 'static'
                        keys = [cellstr(getParamList(app, params, 'fixed')), ...
                            cellstr(getParamList(app, params, 'design')), ...
                            cellstr(getParamList(app, params, 'template'))];
                    otherwise
                        keys = [cellstr(getParamList(app, params, 'run')), ...
                            cellstr(getParamList(app, params, 'data'))];
                end
            end
        end

        function keys = processorStaticKeys(app, pkg)
            switch pkg
                case 'combinemultiplechannels'
                    keys = {'outputChannelName','requiredChannelCount'};
                case 'computemetrics'
                    keys = {'mask1_name','mask1_class','mask1_label','mask1_stat','channel1_name','channel2_name','channel3_name','channel4_name','BrightestPixels'};
                case 'computerls'
                    keys = moduleSetparamKeys(app, pkg);
                    keys = setdiff(keys, {'classification_data','outputName','pkg','paramTooltip','tip'}, 'stable');
                otherwise
                    keys = moduleSetparamKeys(app, pkg);
                    keys = setdiff(keys, {'outputName','pkg','paramTooltip','tip'}, 'stable');
            end
        end

        function keys = moduleSetparamKeys(app, pkg) %#ok<INUSD>
            keys = {};
            if isempty(pkg)
                return;
            end
            try
                p = feval([char(string(pkg)) '.setparam'], struct());
                if isstruct(p)
                    keys = fieldnames(p)';
                end
            catch
                keys = {};
            end
        end

        function keys = processorRuntimeKeys(app, pkg) %#ok<INUSD>
            switch pkg
                case 'combinemultiplechannels'
                    keys = {'Channel1','Channel2','Channel3','Channel4','Channel5'};
                otherwise
                    keys = {};
            end
        end

        function keys = removeGlobalRuntimeKeys(app, keys) %#ok<INUSD>
            globalKeys = {'fovIndex','roiIndex','roiList','frames','channels','extractFrames','extractChannels','positionFilter','channelFilter','stackFilter'};
            keys = keys(~ismember(lower(keys), lower(globalKeys)));
        end

        function keys = filterParamsByAdvancedMode(app, node, keys)
            if logical(getField(app, node, 'uiAdvanced', false))
                return;
            end
            easyKeys = easyParamKeys(app, node);
            if isempty(easyKeys)
                return;
            end
            keep = ismember(lower(keys), lower(easyKeys));
            keys = keys(keep);
        end

        function keys = easyParamKeys(app, node) %#ok<INUSD>
            nodeType = lower(char(string(getField(app, node, 'type', ''))));
            pkg = lower(char(string(getField(app, node, 'pkg', ''))));
            switch nodeType
                case 'dataloader'
                    keys = {'path','positionFilter','channelFilter','stackFilter','label'};
                case {'roipattern','roiidentify'}
                    keys = {'channel','channelIndex','referenceFrame','threshold','keepExisting','fovIndex'};
                case 'roimanual'
                    keys = {'fovIndex','keepExisting','skipExisting'};
                case 'roigrid'
                    keys = {'gridCount','keepExisting'};
                case 'roitracked'
                    keys = {'fovIndex','roiIndex','channel','extractChannels','keepExisting'};
                case 'roiextract'
                    keys = {'fovIndex','roiIndex','frames','channels','extend','correctDrift'};
                case 'processor'
                    if strcmp(pkg, 'combinemultiplechannels')
                        keys = {'Channel1','Channel2','Channel3','Channel4','Channel5','requiredChannelCount','outputChannelName'};
                    elseif strcmp(pkg, 'computemetrics')
                        keys = {'mask1_name','channel1_name','channel2_name','channel3_name','channel4_name','BrightestPixels'};
                    elseif strcmp(pkg, 'computerls')
                        keys = {'StateDecoder','ExpectedDivisionPeriod','MinDivisionInterval','MinDivisionIntervalFactor','ArrestThreshold','DeathThreshold','ClogThreshold','EmptyThresholdNext','QCMinMeanMargin','QCMaxLowConfidenceFraction'};
                    else
                        keys = {'channels','channel','frames'};
                    end
                case 'classifier'
                    keys = {'channel','channels','frames','pkg'};
                otherwise
                    keys = {};
            end
        end

        function out = valueToDisplay(app, v) %#ok<INUSD>
            if ischar(v)
                out = v;
            elseif isstring(v)
                out = char(strjoin(v(:), ', '));
            elseif isnumeric(v) || islogical(v)
                out = mat2str(v);
            elseif iscell(v) || isstruct(v)
                try
                    out = jsonencode(v);
                catch
                    out = '<complex>';
                end
            else
                try
                    out = char(string(v));
                catch
                    out = '<value>';
                end
            end
            if numel(out) > 120
                out = [out(1:117) '...'];
            end
        end

        function out = paramValueToDisplay(app, node, key, value)
            nodeType = lower(char(string(getField(app, node, 'type', ''))));
            key = char(string(key));
            if iscell(value)
                out = choiceScalarText(app, value);
            else
                out = valueToDisplay(app, value);
            end
        end

        function label = friendlyParamLabel(app, key) %#ok<INUSD>
            switch lower(char(string(key)))
                case 'mode'
                    label = 'ROI layout';
                case 'gridcount'
                    label = 'Grid count';
                case 'extend'
                    label = 'Append existing ROI outputs';
                case 'correctdrift'
                    label = 'Correct drift';
                case 'driftchannel'
                    label = 'Drift channel';
                case 'driftmethod'
                    label = 'Drift method';
                case 'driftrefmode'
                    label = 'Drift reference';
                case 'driftsubpixel'
                    label = 'Subpixel drift';
                case 'driftmaxshift'
                    label = 'Max drift shift';
                case 'cropdrift'
                    label = 'Drift crop fraction';
                case 'forcechannelnames'
                    label = 'Force channel names';
                case 'scale'
                    label = 'Output scale';
                otherwise
                    label = char(string(key));
            end
        end

        function out = ternary(app, cond, ifTrue, ifFalse) %#ok<INUSD>
            if cond
                out = ifTrue;
            else
                out = ifFalse;
            end
        end

        function out = layoutSpan(app, first, last) %#ok<INUSD>
            if first == last
                out = first;
            else
                out = [first last];
            end
        end

        function refreshValidationReport(app)
            pipe = buildPipelineStruct(app);
            pipeForCheck = selectedPipelineStructForRun(app, pipe);
            ctx = buildBindingValidationContext(app);
            if isempty(pipe.nodes)
                app.RuninformationhereLabel.Text = 'Template mode - no module yet.';
                app.PipelineandRuncheckreportLabel.Text = 'Click the grey block to add the first module.';
                return;
            end

            try
                [pipeResolved, bindingResolution] = pipelineResolveBindings(pipeForCheck, ctx, struct('allowGui', false));
                [ok, report] = validatePipeline(pipeResolved, ctx, struct('allowGui', false));
                report.bindingResolution = bindingResolution;
            catch ME
                ok = false;
                report = struct('errors', {{ME.message}}, 'warnings', {{}}, 'solver', struct());
            end

            app.Data.nodes = annotateNodeStatus(app, app.Data.nodes, report);
            refreshSelectedModuleTable(app);

            if ok
                app.RuninformationhereLabel.Text = sprintf('Template mode - %d module(s), %d edge(s), valid.', numel(pipe.nodes), numel(pipe.edges));
            else
                app.RuninformationhereLabel.Text = sprintf('Template mode - %d module(s), %d edge(s), needs attention.', numel(pipe.nodes), numel(pipe.edges));
            end
            app.PipelineandRuncheckreportLabel.Text = [formatValidationReport(app, ok, report) newline newline formatRunPolicySummary(app)];
        end

        function CheckpipelineButtonPushed(app, event) %#ok<INUSD>
            [ok, report] = refreshValidationReportWithOutput(app);
            runtimeIssues = validateRuntimeInputs(app);
            updateRuntimeInputStates(app);

            if isempty(runtimeIssues)
                runtimeText = 'Runtime check: OK';
            else
                runtimeText = ['Runtime check:' newline '- ' strjoin(runtimeIssues, [newline '- '])];
            end

            baseText = formatValidationReport(app, ok, report);
            app.PipelineandRuncheckreportLabel.Text = [baseText newline newline runtimeText newline newline formatRunPolicySummary(app)];
        end

        function [ok, report] = refreshValidationReportWithOutput(app)
            pipe = buildPipelineStruct(app);
            pipeForCheck = selectedPipelineStructForRun(app, pipe);
            ctx = buildBindingValidationContext(app);
            if isempty(pipe.nodes)
                ok = false;
                report = struct('errors', {{'No module in pipeline.'}}, 'warnings', {{}}, 'solver', struct());
                refreshValidationReport(app);
                return;
            end
            try
                [pipeResolved, bindingResolution] = pipelineResolveBindings(pipeForCheck, ctx, struct('allowGui', false));
                [ok, report] = validatePipeline(pipeResolved, ctx, struct('allowGui', false));
                report.bindingResolution = bindingResolution;
            catch ME
                ok = false;
                report = struct('errors', {{ME.message}}, 'warnings', {{}}, 'solver', struct());
            end
            app.Data.nodes = annotateNodeStatus(app, app.Data.nodes, report);
            refreshSelectedModuleTable(app);
            app.RuninformationhereLabel.Text = ternary(app, ok, ...
                sprintf('Template mode - %d module(s), %d edge(s), valid.', numel(pipe.nodes), numel(pipe.edges)), ...
                sprintf('Template mode - %d module(s), %d edge(s), needs attention.', numel(pipe.nodes), numel(pipe.edges)));
        end

        function issues = validateRuntimeInputs(app)
            issues = {};
            projectPath = strtrim(getRuntimeValue(app, 'projectPath'));
            rawDataPath = strtrim(getRuntimeValue(app, 'rawDataPath'));
            projectOk = ~isempty(projectPath) && (exist(projectPath, 'dir') == 7 || exist(projectPath, 'file') == 2);
            rawOk = ~isempty(rawDataPath) && exist(rawDataPath, 'dir') == 7;

            if ~isempty(projectPath) && ~projectOk
                issues{end+1} = ['Project path does not exist: ' projectPath]; %#ok<AGROW>
                markRuntimeField(app, 'projectPath', 'missing', 'Project must be an existing folder or project .mat file.');
            end

            if pipelineHasNodeType(app, 'dataLoader')
                if ~projectOk && ~rawOk
                    issues{end+1} = 'Raw data folder is required when no existing project is provided.'; %#ok<AGROW>
                    markRuntimeField(app, 'rawDataPath', 'missing', 'Required when a dataloader run has no existing project input.');
                elseif ~isempty(rawDataPath) && ~rawOk
                    issues{end+1} = ['Raw data folder does not exist: ' rawDataPath]; %#ok<AGROW>
                    markRuntimeField(app, 'rawDataPath', 'missing', 'Raw data must be an existing folder.');
                end
            end
            if strcmp(runtimeExecutionTarget(app), 'hub')
                hub = hubSettingsFromUi(app);
                if ~isfield(hub, 'baseUrl') || isempty(strtrim(char(string(hub.baseUrl))))
                    issues{end+1} = 'Hub URL is required when run target is Hub.'; %#ok<AGROW>
                end
                hasUserKey = isfield(hub, 'userKey') && ~isempty(strtrim(char(string(hub.userKey))));
                hasToken = isfield(hub, 'sessionToken') && ~isempty(strtrim(char(string(hub.sessionToken))));
                if ~(hasUserKey || hasToken)
                    issues{end+1} = 'Hub user key or session token is required when run target is Hub.'; %#ok<AGROW>
                end
            end
            [severity, message] = outputPolicyCompatibility(app);
            if strcmp(severity, 'warning')
                issues{end+1} = message; %#ok<AGROW>
            end
        end

        function txt = formatRunPolicySummary(app)
            resumeLabel = char(string(app.ResumeoptionsDropDown.Value));
            outputPolicy = getRuntimeValue(app, 'outputPolicy');
            if isempty(outputPolicy)
                outputPolicy = 'skip';
            end
            switch char(string(outputPolicy))
                case 'skip'
                    policyLabel = 'skip existing outputs';
                case 'replace'
                    policyLabel = 'replace existing outputs';
                case 'upsert'
                    policyLabel = 'append/update existing outputs';
                case 'error'
                    policyLabel = 'error if outputs exist';
                otherwise
                    policyLabel = char(string(outputPolicy));
            end
            roiExtractMode = '';
            if pipelineHasNodeType(app, 'roiExtract')
                switch char(string(outputPolicy))
                    case {'upsert','append'}
                        roiExtractMode = [newline 'Effective roiExtract mode: extend/append ROI H5 outputs.'];
                    case 'replace'
                        roiExtractMode = [newline 'Effective roiExtract mode: reset/replace ROI H5 outputs.'];
                    case 'skip'
                        roiExtractMode = [newline 'Effective roiExtract mode: skip completed outputs when possible.'];
                    case 'error'
                        roiExtractMode = [newline 'Effective roiExtract mode: fail if ROI outputs already exist.'];
                end
            end
            txt = ['Run policy:' newline ...
                '- Target: ' runTargetLabel(app) newline ...
                '- Resume: ' resumeLabel newline ...
                '- Existing outputs: ' policyLabel roiExtractMode];
            [severity, message] = outputPolicyCompatibility(app);
            if strcmp(severity, 'warning')
                txt = [txt newline '- Warning: ' message];
            end
            txt = [txt newline '- Recommended: ' recommendedPolicySentence(app)];
        end

        function [severity, message] = outputPolicyCompatibility(app)
            severity = 'ok';
            message = '';
            resumeMode = char(string(app.ResumeoptionsDropDown.Value));
            outputPolicy = getRuntimeValue(app, 'outputPolicy');
            if isempty(outputPolicy)
                outputPolicy = recommendedOutputPolicy(app, resumeMode);
            end

            if strcmpi(resumeMode, 'Resume previous progress') && strcmp(outputPolicy, 'replace')
                severity = 'warning';
                message = 'Resume + replace is unusual: checkpoints are reused while existing outputs may be overwritten.';
            elseif strcmpi(resumeMode, 'Restart from scratch') && strcmp(outputPolicy, 'skip')
                severity = 'warning';
                message = 'Restart + skip is unusual: checkpoints are ignored but existing outputs are preserved.';
            elseif strcmpi(resumeMode, 'Restart from scratch') && strcmp(outputPolicy, 'upsert')
                severity = 'warning';
                message = 'Restart + append/update is only appropriate for controlled partial H5 updates.';
            end
        end

        function sentence = recommendedPolicySentence(app)
            resumeMode = char(string(app.ResumeoptionsDropDown.Value));
            if strcmpi(resumeMode, 'Restart from scratch')
                sentence = 'Restart from scratch -> Replace existing outputs for a clean rerun.';
            else
                sentence = 'Resume previous progress -> Skip existing outputs for the safest continuation.';
            end
        end

        function nodes = annotateNodeStatus(app, nodes, report) %#ok<INUSD>
            for i = 1:numel(nodes)
                nodes(i).status = 'OK';
            end
            if isstruct(report) && isfield(report, 'missingParams') && ~isempty(report.missingParams)
                for k = 1:numel(report.missingParams)
                    entry = report.missingParams{k};
                    idx = find(strcmp({nodes.id}, char(string(entry.node))), 1);
                    if ~isempty(idx)
                        nodes(idx).status = ['Missing: ' strjoin(entry.missing, ', ')];
                    end
                end
            end
            if isstruct(report) && isfield(report, 'deferredParams') && ~isempty(report.deferredParams)
                for k = 1:numel(report.deferredParams)
                    entry = report.deferredParams{k};
                    idx = find(strcmp({nodes.id}, char(string(entry.node))), 1);
                    if ~isempty(idx) && strcmp(nodes(idx).status, 'OK')
                        nodes(idx).status = ['Run: ' strjoin(entry.missing, ', ')];
                    end
                end
            end
        end

        function txt = formatValidationReport(app, ok, report) %#ok<INUSD>
            lines = {};
            if ok
                lines{end+1} = 'Pipeline check: OK'; %#ok<AGROW>
            else
                lines{end+1} = 'Pipeline check: needs attention'; %#ok<AGROW>
            end
            if isstruct(report)
                if isfield(report, 'order') && ~isempty(report.order)
                    lines{end+1} = ['Order: ' strjoin(cellstr(report.order), ' -> ')]; %#ok<AGROW>
                end
                if isfield(report, 'errors') && ~isempty(report.errors)
                    lines{end+1} = ''; %#ok<AGROW>
                    lines{end+1} = 'Errors:'; %#ok<AGROW>
                    for i = 1:numel(report.errors)
                        lines{end+1} = ['- ' char(string(report.errors{i}))]; %#ok<AGROW>
                    end
                end
                if isfield(report, 'warnings') && ~isempty(report.warnings)
                    lines{end+1} = ''; %#ok<AGROW>
                    lines{end+1} = 'Warnings:'; %#ok<AGROW>
                    for i = 1:min(numel(report.warnings), 12)
                        lines{end+1} = ['- ' char(string(report.warnings{i}))]; %#ok<AGROW>
                    end
                end
                if isfield(report, 'solver') && isstruct(report.solver) && isfield(report.solver, 'issues') && ~isempty(report.solver.issues)
                    lines{end+1} = ''; %#ok<AGROW>
                    lines{end+1} = sprintf('Solver issues: %d', numel(report.solver.issues)); %#ok<AGROW>
                end
                if isfield(report, 'bindingResolution') && isstruct(report.bindingResolution) && ...
                        isfield(report.bindingResolution, 'applied') && ~isempty(report.bindingResolution.applied)
                    lines{end+1} = ''; %#ok<AGROW>
                    lines{end+1} = 'Auto bindings:'; %#ok<AGROW>
                    applied = report.bindingResolution.applied;
                    for i = 1:min(numel(applied), 8)
                        lines{end+1} = sprintf('- %s.%s = %s', ...
                            char(string(applied(i).nodeId)), ...
                            char(string(applied(i).param)), ...
                            char(string(applied(i).value))); %#ok<AGROW>
                    end
                end
            end
            txt = strjoin(lines, newline);
        end

        function label = runTargetLabel(app)
            if strcmp(runtimeExecutionTarget(app), 'hub')
                label = 'Hub';
            else
                label = 'Local MATLAB';
            end
        end

        function pipe = buildPipelineStruct(app)
            pipe = struct();
            pipe.name = 'pipelineGUI2';
            pipe.nodes = app.Data.nodes;
            pipe.nodes = applyRuntimeDerivedNodePolicies(app, pipe.nodes);
            pipe.edges = app.Data.edges;
            pipe.branches = struct([]);
        end

        function pipe = selectedPipelineStructForRun(app, pipe)
            selectedIds = selectedRunNodeIds(app);
            if isempty(selectedIds) || ~isfield(pipe, 'nodes') || isempty(pipe.nodes)
                return;
            end
            nodeIds = cellstr(string({pipe.nodes.id}));
            keep = ismember(nodeIds, selectedIds);
            if ~any(keep)
                return;
            end
            pipe.nodes = pipe.nodes(keep);
            if isfield(pipe, 'edges') && ~isempty(pipe.edges)
                edgeKeep = false(size(pipe.edges));
                for i = 1:numel(pipe.edges)
                    edgeKeep(i) = any(strcmp(selectedIds, char(string(pipe.edges(i).from)))) && ...
                        any(strcmp(selectedIds, char(string(pipe.edges(i).to))));
                end
                pipe.edges = pipe.edges(edgeKeep);
            end
        end

        function nodes = applyRuntimeDerivedNodePolicies(app, nodes)
            outputPolicy = getRuntimeValue(app, 'outputPolicy');
            if isempty(outputPolicy)
                outputPolicy = 'skip';
            end
            for i = 1:numel(nodes)
                if ~strcmpi(char(string(getField(app, nodes(i), 'type', ''))), 'roiExtract')
                    continue;
                end
                if ~isfield(nodes(i), 'params') || ~isstruct(nodes(i).params)
                    nodes(i).params = struct();
                end
                switch char(string(outputPolicy))
                    case {'upsert','append'}
                        nodes(i).params.extend = true;
                    case 'replace'
                        nodes(i).params.extend = false;
                    otherwise
                        if isfield(nodes(i).params, 'extend')
                            nodes(i).params = rmfield(nodes(i).params, 'extend');
                        end
                end
            end
        end

        function pipe = buildPipelineTemplateStruct(app)
            pipe = struct();
            pipe.name = currentPipelineName(app);
            pipe.nodes = stripRuntimeParamsFromNodes(app, app.Data.nodes);
            pipe.edges = app.Data.edges;
            pipe.branches = struct([]);
        end

        function nodes = stripRuntimeParamsFromNodes(app, nodes) %#ok<INUSD>
            for i = 1:numel(nodes)
                if ~isfield(nodes(i), 'params') || ~isstruct(nodes(i).params)
                    continue;
                end
                nodeType = lower(char(string(getField(app, nodes(i), 'type', ''))));
                if strcmp(nodeType, 'dataloader') && isfield(nodes(i).params, 'path')
                    nodes(i).params = rmfield(nodes(i).params, 'path');
                end
                if strcmp(nodeType, 'roiextract') && isfield(nodes(i).params, 'extend')
                    nodes(i).params = rmfield(nodes(i).params, 'extend');
                end
                try
                    contract = pipelineNodeContract(nodes(i));
                    resources = getField(app, contract, 'resources', struct());
                    inputs = getField(app, resources, 'in', struct([]));
                    for j = 1:numel(inputs)
                        param = char(string(getField(app, inputs(j), 'param', '')));
                        if ~isempty(param) && isfield(nodes(i).params, param)
                            nodes(i).params = rmfield(nodes(i).params, param);
                        end
                    end
                catch
                end
            end
        end

        function pipeObj = buildPipelineObject(app, targetPath)
            if nargin < 2 || isempty(targetPath)
                targetPath = app.CurrentPipelinePath;
            end
            name = currentPipelineName(app);
            pipeStruct = buildPipelineTemplateStruct(app);
            pipeObj = pipeline('', name, 1);
            pipeObj.setPath(targetPath, name);
            pipeObj.nodes = pipeStruct.nodes;
            pipeObj.edges = pipeStruct.edges;
            pipeObj.branches = pipeStruct.branches;
            pipeObj.description = 'Created from pipelineGUI2';
        end

        function pipeObj = buildExecutablePipelineObject(app, targetPath, ctx)
            pipeObj = buildPipelineObject(app, targetPath);
            pipeStruct = selectedPipelineStructForRun(app, struct('nodes', pipeObj.nodes, 'edges', pipeObj.edges, 'branches', pipeObj.branches));
            pipeObj.nodes = pipeStruct.nodes;
            pipeObj.edges = pipeStruct.edges;
            if isfield(pipeStruct, 'branches')
                pipeObj.branches = pipeStruct.branches;
            end
            pipeObj.nodes = applyRunNodeParamsToNodes(app, pipeObj.nodes, ctx.run.nodeParams);
            pipeObj.nodes = applyRuntimeDerivedNodePolicies(app, pipeObj.nodes);
            try
                [pipeObj, bindingResolution] = pipelineResolveBindings(pipeObj, ctx, struct('allowGui', false));
                app.Data.lastBindingResolution = bindingResolution;
            catch
            end
        end

        function nodes = applyRunNodeParamsToNodes(app, nodes, nodeParams)
            if ~isstruct(nodeParams)
                return;
            end
            for i = 1:numel(nodes)
                nodeId = char(string(getField(app, nodes(i), 'id', '')));
                key = matlab.lang.makeValidName(nodeId);
                if ~isfield(nodeParams, key) || ~isstruct(nodeParams.(key))
                    continue;
                end
                if ~isfield(nodes(i), 'params') || ~isstruct(nodes(i).params)
                    nodes(i).params = struct();
                end
                runParams = nodeParams.(key);
                if isstruct(nodes(i).params)
                    fields = fieldnames(nodes(i).params);
                    for f = 1:numel(fields)
                        pname = fields{f};
                        if isSymbolicStoredBinding(app, nodes(i).params.(pname)) && isfield(runParams, pname)
                            runParams.(pname) = nodes(i).params.(pname);
                        end
                    end
                end
                nodes(i).params = mergeStructDefaults(app, runParams, nodes(i).params);
            end
        end

        function name = currentPipelineName(app)
            name = 'pipelineGUI2';
            if ~isempty(app.CurrentPipeline) && isa(app.CurrentPipeline, 'pipeline') && ~isempty(app.CurrentPipeline.strid)
                name = char(string(app.CurrentPipeline.strid));
            elseif ~isempty(app.CurrentPipelinePath)
                [~, name] = fileparts(app.CurrentPipelinePath);
                if isempty(name)
                    name = 'pipelineGUI2';
                end
            end
        end

        function ok = savePipelineInteractive(app, forceAs)
            ok = false;
            if nargin < 2
                forceAs = false;
            end
            targetPath = app.CurrentPipelinePath;
            if forceAs || isempty(targetPath)
                [file, pth] = uiputfile('pipeline.json', 'Save pipeline template', fullfile(pwd, 'pipeline.json'));
                if isequal(file, 0)
                    return;
                end
                targetPath = pth;
            end
            try
                pipeObj = buildPipelineObject(app, targetPath);
                pipelineSave(pipeObj);
                app.CurrentPipeline = pipeObj;
                app.CurrentPipelinePath = pipeObj.path;
                assignCurrentPipelineToWorkspace(app, pipeObj);
                addRecentPipelinePath(app, fullfile(pipeObj.path, 'pipeline.json'));
                ok = true;
                suffix = '';
                if ~isempty(app.CurrentPipelineWorkspaceVar)
                    suffix = [' | workspace: ' app.CurrentPipelineWorkspaceVar];
                end
                app.RuninformationhereLabel.Text = ['Pipeline saved: ' fullfile(pipeObj.path, 'pipeline.json') suffix];
            catch ME
                uialert(app.UIFigure, ME.message, 'Save pipeline', 'Icon', 'error');
            end
        end

        function assignCurrentPipelineToWorkspace(app, pipeObj)
            if isempty(pipeObj) || ~isa(pipeObj, 'pipeline')
                return;
            end
            varName = '';
            try
                varName = char(string(pipeObj.strid));
            catch
            end
            if isempty(strtrim(varName))
                try
                    [~, varName] = fileparts(pipeObj.path);
                catch
                end
            end
            if isempty(strtrim(varName))
                varName = 'pipelineObj';
            end
            varName = matlab.lang.makeValidName(varName);
            try
                assignin('base', varName, pipeObj);
                app.CurrentPipelineWorkspaceVar = varName;
            catch
            end
        end

        function addRecentPipelinePath(app, pipelineFile)
            pipelineFile = normalizeRecentPipelinePath(app, pipelineFile);
            if isempty(pipelineFile)
                return;
            end
            paths = recentPipelinePaths(app, true);
            paths = paths(~strcmpi(paths, pipelineFile));
            paths = [{pipelineFile} paths];
            maxCount = 10;
            if numel(paths) > maxCount
                paths = paths(1:maxCount);
            end
            try
                setpref('DetecDiv', 'pipeline2RecentPipelines', paths);
            catch
            end
            updateRecentPipelinesMenu(app);
        end

        function paths = recentPipelinePaths(app, keepMissing) %#ok<INUSD>
            if nargin < 2
                keepMissing = false;
            end
            paths = {};
            try
                paths = getpref('DetecDiv', 'pipeline2RecentPipelines', {});
            catch
                paths = {};
            end
            if ischar(paths) || (isstring(paths) && isscalar(paths))
                paths = {char(string(paths))};
            elseif isstring(paths)
                paths = cellstr(paths(:))';
            elseif ~iscell(paths)
                paths = {};
            end
            normalized = {};
            for i = 1:numel(paths)
                p = normalizeRecentPipelinePath(app, paths{i});
                if isempty(p)
                    continue;
                end
                if keepMissing || exist(p, 'file') == 2
                    normalized{end+1} = p; %#ok<AGROW>
                end
            end
            paths = unique(normalized, 'stable');
            if ~keepMissing
                try
                    setpref('DetecDiv', 'pipeline2RecentPipelines', paths);
                catch
                end
            end
        end

        function pipelineFile = normalizeRecentPipelinePath(app, pipelineFile) %#ok<INUSD>
            pipelineFile = strtrim(char(string(pipelineFile)));
            if isempty(pipelineFile)
                return;
            end
            try
                if exist(pipelineFile, 'dir') == 7
                    pipelineFile = fullfile(pipelineFile, 'pipeline.json');
                end
                if exist(pipelineFile, 'file') == 2
                    pipelineFile = char(java.io.File(pipelineFile).getCanonicalPath());
                end
            catch
            end
        end

        function updateRecentPipelinesMenu(app)
            if isempty(app.LoadrecentpipelineMenu) || ~isvalid(app.LoadrecentpipelineMenu)
                return;
            end
            try
                delete(app.LoadrecentpipelineMenu.Children);
            catch
            end
            paths = recentPipelinePaths(app, false);
            if isempty(paths)
                item = uimenu(app.LoadrecentpipelineMenu, 'Text', '(No recent pipelines)');
                item.Enable = 'off';
                app.LoadrecentpipelineMenu.Enable = 'off';
                return;
            end
            app.LoadrecentpipelineMenu.Enable = 'on';
            for i = 1:numel(paths)
                label = recentPipelineMenuLabel(app, paths{i});
                uimenu(app.LoadrecentpipelineMenu, 'Text', label, ...
                    'MenuSelectedFcn', @(~,~)loadRecentPipeline(app, paths{i}));
            end
            uimenu(app.LoadrecentpipelineMenu, 'Text', 'Clear recent pipelines', ...
                'Separator', 'on', 'MenuSelectedFcn', @(~,~)clearRecentPipelines(app));
        end

        function label = recentPipelineMenuLabel(app, pipelineFile) %#ok<INUSD>
            pipelineFile = char(string(pipelineFile));
            [folder, file, ext] = fileparts(pipelineFile);
            [parent, folderName] = fileparts(folder);
            [~, parentName] = fileparts(parent);
            label = [folderName filesep file ext];
            if ~isempty(parentName)
                label = [parentName filesep label];
            end
        end

        function loadRecentPipeline(app, pipelineFile)
            pipelineFile = normalizeRecentPipelinePath(app, pipelineFile);
            if isempty(pipelineFile) || exist(pipelineFile, 'file') ~= 2
                updateRecentPipelinesMenu(app);
                uialert(app.UIFigure, 'This recent pipeline file no longer exists.', 'Load recent pipeline', 'Icon', 'warning');
                return;
            end
            try
                [pipeObj, msg] = pipelineLoad(pipelineFile);
                if isempty(pipeObj)
                    error('pipeline2:PipelineLoadFailed', '%s', msg);
                end
                loadPipelineFromObject(app, pipeObj);
                addRecentPipelinePath(app, pipelineFile);
                if ~isempty(app.CurrentPipelineWorkspaceVar)
                    app.RuninformationhereLabel.Text = ['Pipeline loaded in workspace: ' app.CurrentPipelineWorkspaceVar];
                end
            catch ME
                uialert(app.UIFigure, ME.message, 'Load recent pipeline', 'Icon', 'error');
            end
        end

        function clearRecentPipelines(app)
            try
                setpref('DetecDiv', 'pipeline2RecentPipelines', {});
            catch
            end
            updateRecentPipelinesMenu(app);
        end

        function loadPipelineFromObject(app, pipeObj)
            if isempty(pipeObj) || ~isa(pipeObj, 'pipeline')
                return;
            end
            nodes = pipeObj.nodes;
            if isempty(nodes)
                nodes = struct([]);
            end
            for i = 1:numel(nodes)
                if ~isfield(nodes(i), 'layout') || isempty(nodes(i).layout)
                    nodes(i).layout = [i 1 1 1];
                end
                if ~isfield(nodes(i), 'name') || isempty(nodes(i).name)
                    nodes(i).name = nodes(i).id;
                end
                if ~isfield(nodes(i), 'uiAdvanced') || isempty(nodes(i).uiAdvanced)
                    nodes(i).uiAdvanced = false;
                end
                try
                    nodes(i).contract = pipelineNodeContract(nodes(i));
                    nodes(i).inputs = portNames(app, nodes(i).contract, 'in');
                    nodes(i).outputs = portNames(app, nodes(i).contract, 'out');
                catch
                end
            end
            app.Data.nodes = nodes;
            app.Data.edges = pipeObj.edges;
            if isempty(app.Data.edges)
                rebuildEdgesFromLayout(app);
            end
            app.CurrentPipeline = pipeObj;
            app.CurrentPipelinePath = pipeObj.path;
            assignCurrentPipelineToWorkspace(app, pipeObj);
            app.CurrentRun = [];
            app.CurrentRunPath = '';
            app.RuntimeNodeParams = struct();
            app.SelectedNodeIndex = ternary(app, isempty(nodes), NaN, 1);
            app.NodeCounter = inferNodeCounter(app, nodes);
            refreshAfterModelChange(app);
        end

        function n = inferNodeCounter(app, nodes) %#ok<INUSD>
            n = numel(nodes);
            for i = 1:numel(nodes)
                toks = regexp(char(string(nodes(i).id)), '_(\d+)$', 'tokens', 'once');
                if ~isempty(toks)
                    n = max(n, str2double(toks{1}));
                end
            end
        end

        function ctx = buildRunContext(app)
            ctx = struct();
            ctx.allowGUI = false;
            ctx.interactive = false;
            ctx.dryRun = false;

            if ~isempty(app.CurrentProject) && isa(app.CurrentProject, 'shallow')
                ctx.shallow = app.CurrentProject;
                ctx.shallowObj = app.CurrentProject;
            end

            ctx.run = struct();
            ctx.run.selectedNodes = selectedRunNodeIds(app);
            ctx.run.nodeParams = buildRunNodeParams(app);
            ctx.run.runPolicy = resumeModeToRunPolicy(app, app.ResumeoptionsDropDown.Value);
            ctx.run.resume = strcmp(ctx.run.runPolicy, 'resume');
            ctx.run.gpuPolicy = lower(char(string(app.ExecutionDropDown.Value)));
            if strcmp(ctx.run.gpuPolicy, 'auto')
                ctx.run.gpuPolicy = 'module_default';
            end
            ctx.run.executionTarget = runtimeExecutionTarget(app);
            ctx.run.inputSource = inferRuntimeInputSource(app);
            if strcmp(ctx.run.executionTarget, 'hub')
                ctx.hub = hubSettingsFromUi(app);
            end

            ctx.io = struct();
            policy = getRuntimeValue(app, 'outputPolicy');
            if isempty(policy)
                policy = recommendedOutputPolicy(app, app.ResumeoptionsDropDown.Value);
            end
            ctx.io.existingPolicy = policy;
            ctx.io.globalExistingPolicy = policy;
            ctx.io.cachePolicy = 'auto';
            ctx.store = struct('cacheMode', 'auto');

            ctx.sel = struct();
            ctx.sel.fovs = parseIndexSelection(app, getRuntimeValue(app, 'fovs'));
            ctx.sel.frames = parseIndexSelection(app, getRuntimeValue(app, 'frames'));
            ctx.sel.rois = parseLooseSelection(app, getRuntimeValue(app, 'rois'));
            ctx.run.fovIndex = ctx.sel.fovs;
            ctx.run.frames = ctx.sel.frames;
            ctx.run.rois = ctx.sel.rois;

            availableRuntimeChannels = runtimeConcreteChannels(app);
            ctx.run.availableChannels = availableRuntimeChannels;
            if ~isempty(availableRuntimeChannels)
                ctx.roiChannels = availableRuntimeChannels;
            end
            if ~isfield(ctx, 'channels') && ~isempty(availableRuntimeChannels)
                ctx.channels = availableRuntimeChannels;
            end
            dataSeriesNames = runtimeDataSeriesNames(app);
            if ~isempty(dataSeriesNames)
                ctx.dataSeriesNames = dataSeriesNames;
                ctx.dataSeries = dataSeriesNames;
            end

            rawDataPath = getRuntimeValue(app, 'rawDataPath');
            projectPath = getRuntimeValue(app, 'projectPath');
            ctx.run.rawDataPath = rawDataPath;
            ctx.run.projectPath = projectPath;
            ctx.io.rawDataPath = rawDataPath;
            ctx.io.projectPath = projectPath;
            ctx.rawDataPath = rawDataPath;
            ctx.projectPath = projectPath;
            ctx.dataLoader = struct('path', rawDataPath);

            ctx.pipelineRef = buildPipelineRef(app);
            ctx.targetRef = buildTargetRef(app);
        end

        function source = inferRuntimeInputSource(app)
            source = 'pipeline start (dataloader)';
            if isempty(app.CurrentProject) || ~isa(app.CurrentProject, 'shallow')
                return;
            end
            try
                dataSeriesNames = runtimeDataSeriesNames(app);
                if ~isempty(dataSeriesNames)
                    source = 'existing dataseries';
                    return;
                end
            catch
            end
            try
                if projectHasAnyRoi(app, app.CurrentProject)
                    source = 'existing rois';
                    return;
                end
            catch
            end
            source = 'existing project fovs';
        end

        function tf = projectHasAnyRoi(app, shallowObj) %#ok<INUSD>
            tf = false;
            try
                for i = 1:numel(shallowObj.fov)
                    if isprop(shallowObj.fov(i), 'roi') && ~isempty(shallowObj.fov(i).roi)
                        tf = true;
                        return;
                    end
                end
            catch
            end
        end

        function nodeParams = buildRunNodeParams(app)
            nodeParams = struct();
            fn = fieldnames(app.RuntimeNodeParams);
            for i = 1:numel(fn)
                params = app.RuntimeNodeParams.(fn{i});
                if ~isstruct(params)
                    continue;
                end
                nodeId = runtimeKeyToNodeId(app, fn{i});
                if isempty(nodeId)
                    continue;
                end
                nodeParams.(matlab.lang.makeValidName(nodeId)) = params;
            end

            rawDataPath = getRuntimeValue(app, 'rawDataPath');
            if ~isempty(rawDataPath)
                for i = 1:numel(app.Data.nodes)
                    if strcmpi(char(string(getField(app, app.Data.nodes(i), 'type', ''))), 'dataLoader')
                        nodeId = char(string(app.Data.nodes(i).id));
                        key = matlab.lang.makeValidName(nodeId);
                        if ~isfield(nodeParams, key) || ~isstruct(nodeParams.(key))
                            nodeParams.(key) = struct();
                        end
                        nodeParams.(key).path = rawDataPath;
                    end
                end
            end
        end

        function target = runtimeExecutionTarget(app)
            target = 'local';
            try
                if isstruct(app.HubFieldHandles) && isfield(app.HubFieldHandles, 'executionTarget') && ...
                        isvalid(app.HubFieldHandles.executionTarget)
                    target = char(string(app.HubFieldHandles.executionTarget.Value));
                elseif isfield(app.RuntimeValues, 'executionTarget') && ~isempty(app.RuntimeValues.executionTarget)
                    target = char(string(app.RuntimeValues.executionTarget));
                end
            catch
                target = 'local';
            end
            if isempty(target)
                target = 'local';
            end
        end

        function hub = hubSettingsFromUi(app)
            hub = defaultHubSettingsForUi(app);
            if ~isstruct(app.HubFieldHandles)
                return;
            end
            textKeys = {'baseUrl','userKey','sessionToken','defaultRemoteProjectRoot','defaultLocalProjectRoot'};
            for i = 1:numel(textKeys)
                key = textKeys{i};
                if isfield(app.HubFieldHandles, key) && isvalid(app.HubFieldHandles.(key))
                    hub.(key) = char(string(app.HubFieldHandles.(key).Value));
                end
            end
            if isfield(app.HubFieldHandles, 'fallbackBaseUrls') && isvalid(app.HubFieldHandles.fallbackBaseUrls)
                hub.fallbackBaseUrls = normalizeHubStringList(app, app.HubFieldHandles.fallbackBaseUrls.Value);
            end
            if isfield(app.HubFieldHandles, 'timeout') && isvalid(app.HubFieldHandles.timeout)
                hub.timeout = double(app.HubFieldHandles.timeout.Value);
            end
        end

        function applyHubSettingsToUi(app, hub)
            if ~isstruct(hub) || ~isstruct(app.HubFieldHandles)
                return;
            end
            textKeys = {'baseUrl','userKey','sessionToken','defaultRemoteProjectRoot','defaultLocalProjectRoot'};
            for i = 1:numel(textKeys)
                key = textKeys{i};
                if isfield(hub, key) && isfield(app.HubFieldHandles, key) && isvalid(app.HubFieldHandles.(key))
                    app.HubFieldHandles.(key).Value = char(string(hub.(key)));
                end
            end
            if isfield(hub, 'fallbackBaseUrls') && isfield(app.HubFieldHandles, 'fallbackBaseUrls') && isvalid(app.HubFieldHandles.fallbackBaseUrls)
                app.HubFieldHandles.fallbackBaseUrls.Value = strjoin(normalizeHubStringList(app, hub.fallbackBaseUrls), ', ');
            end
            if isfield(hub, 'timeout') && isfield(app.HubFieldHandles, 'timeout') && isvalid(app.HubFieldHandles.timeout)
                app.HubFieldHandles.timeout.Value = double(hub.timeout);
            end
        end

        function nodeId = runtimeKeyToNodeId(app, key)
            nodeId = '';
            prefix = 'node_';
            key = char(string(key));
            if startsWith(key, prefix)
                candidate = key(numel(prefix)+1:end);
                ids = {};
                if ~isempty(app.Data.nodes)
                    ids = cellstr(string({app.Data.nodes.id}));
                end
                validIds = cellfun(@(s)matlab.lang.makeValidName(s), ids, 'UniformOutput', false);
                idx = find(strcmp(validIds, candidate), 1);
                if ~isempty(idx)
                    nodeId = ids{idx};
                end
            end
        end

        function ids = selectedRunNodeIds(app)
            ids = {};
            data = app.UISelectedModuleTable.Data;
            if isempty(data)
                if ~isempty(app.Data.nodes)
                    ids = cellstr(string({app.Data.nodes.id}));
                end
                return;
            end
            for i = 1:size(data, 1)
                include = true;
                try
                    include = logical(data{i,1});
                catch
                end
                if include
                    ids{end+1} = char(string(data{i,2})); %#ok<AGROW>
                end
            end
        end

        function policy = resumeModeToRunPolicy(app, value) %#ok<INUSD>
            if strcmpi(char(string(value)), 'Restart from scratch')
                policy = 'restart';
            else
                policy = 'resume';
            end
        end

        function idx = parseIndexSelection(app, txt) %#ok<INUSD>
            idx = [];
            txt = strtrim(char(string(txt)));
            if isempty(txt) || strcmpi(txt, 'all') || startsWith(lower(txt), 'all ')
                return;
            end
            try
                idx = str2num(txt); %#ok<ST2NM>
                idx = idx(:)';
                idx = idx(isfinite(idx) & idx > 0);
                idx = unique(round(idx), 'stable');
            catch
                idx = [];
            end
        end

        function out = parseLooseSelection(app, txt) %#ok<INUSD>
            out = [];
            txt = strtrim(char(string(txt)));
            if isempty(txt) || strcmpi(txt, 'all') || startsWith(lower(txt), 'all ')
                return;
            end
            nums = str2num(txt); %#ok<ST2NM>
            if ~isempty(nums)
                out = nums(:)';
            else
                out = cellstr(string(strsplit(txt, ',')));
            end
        end

        function ref = buildPipelineRef(app)
            ref = struct('id', currentPipelineName(app), 'path', app.CurrentPipelinePath, 'version', '');
            if ~isempty(app.CurrentPipeline) && isa(app.CurrentPipeline, 'pipeline')
                ref.id = app.CurrentPipeline.strid;
                ref.path = app.CurrentPipeline.path;
                ref.version = app.CurrentPipeline.version;
            end
        end

        function ref = buildTargetRef(app)
            ref = struct('type', 'shallow', 'projectPath', getRuntimeValue(app, 'projectPath'), ...
                'projectName', '', 'fovIds', parseIndexSelection(app, getRuntimeValue(app, 'fovs')), ...
                'roiIds', {{}}, 'classiPath', '', 'notes', '');
            if ~isempty(app.CurrentProject) && isa(app.CurrentProject, 'shallow')
                [pth, file] = app.CurrentProject.getPath;
                ref.projectPath = fullfile(pth, file);
                ref.projectName = file;
            end
        end

        function ok = ensurePipelineSavedForRun(app)
            ok = true;
            if isempty(app.CurrentPipelinePath)
                choice = uiconfirm(app.UIFigure, ...
                    'This run needs a saved pipeline template reference. Save the pipeline now?', ...
                    'Save pipeline before run', 'Options', {'Save as...','Cancel'}, ...
                    'DefaultOption', 1, 'CancelOption', 2);
                if strcmp(choice, 'Cancel')
                    ok = false;
                    return;
                end
                ok = savePipelineInteractive(app, true);
            else
                ok = savePipelineInteractive(app, false);
            end
        end

        function ok = ensureCurrentProjectForRun(app)
            ok = false;
            if ~isempty(app.CurrentProject) && isa(app.CurrentProject, 'shallow')
                ok = true;
                return;
            end
            projectPath = getRuntimeValue(app, 'projectPath');
            if ~isempty(projectPath)
                bindProjectFromPath(app, projectPath, false);
                if ~isempty(app.CurrentProject) && isa(app.CurrentProject, 'shallow')
                    ok = true;
                    return;
                end
            end
            choice = uiconfirm(app.UIFigure, ...
                'A persistent run requires a shallow project. Create or load a project now?', ...
                'Project required', 'Options', {'New project...','Browse existing...','Cancel'}, ...
                'DefaultOption', 1, 'CancelOption', 3);
            switch choice
                case 'New project...'
                    createNewProjectFromDialog(app);
                case 'Browse existing...'
                    chooseExistingProject(app);
                otherwise
                    return;
            end
            ok = ~isempty(app.CurrentProject) && isa(app.CurrentProject, 'shallow');
        end

        function runObj = createOrUpdateCurrentRun(app, ctx, status)
            if isempty(app.CurrentRun) || ~isa(app.CurrentRun, 'pipelineRun')
                ref = buildPipelineRef(app);
                target = buildTargetRef(app);
                runObj = pipelineRunNew(app.CurrentProject, ref.id, ref.path, ...
                    'ctx', ctx, 'status', status, 'pipelineRef', ref, 'targetRef', target);
                app.CurrentRun = runObj;
                [runPath, ~] = runObj.getPath;
                app.CurrentRunPath = runPath;
            else
                runObj = app.CurrentRun;
                runObj.ctx = ctx;
                runObj.status = status;
                runObj.pipelineRef = buildPipelineRef(app);
                runObj.targetRef = buildTargetRef(app);
                runObj.templateId = runObj.pipelineRef.id;
                runObj.templatePath = runObj.pipelineRef.path;
            end
        end

        function ok = saveCurrentRun(app, forceAs)
            ok = false;
            if nargin < 2
                forceAs = false;
            end
            if ~ensureCurrentProjectForRun(app)
                return;
            end
            ctx = buildRunContext(app);
            runObj = createOrUpdateCurrentRun(app, ctx, 'preflight');
            if forceAs
                pth = uigetdir(fullfile(app.CurrentProject.io.path, app.CurrentProject.io.file), 'Select run output folder');
                if isequal(pth, 0)
                    return;
                end
                [~, runId] = fileparts(pth);
                runObj.setPath(pth, runId);
                app.CurrentRunPath = pth;
            end
            try
                logRunEvent(app, runObj, 'Run parameters saved from pipeline2.', 'pipeline2');
                pipelineRunSave(runObj);
                shallowSave(app.CurrentProject, 'shallowObj');
                ok = true;
                app.RuninformationhereLabel.Text = ['Run saved: ' fullfile(runObj.path, 'run.json')];
            catch ME
                uialert(app.UIFigure, ME.message, 'Save run', 'Icon', 'error');
            end
        end

        function openCurrentRunArtifact(app, kind)
            if nargin < 2 || isempty(kind)
                kind = 'folder';
            end
            runObj = app.CurrentRun;
            if isempty(runObj) || ~isa(runObj, 'pipelineRun')
                if ~saveCurrentRun(app, false)
                    return;
                end
                runObj = app.CurrentRun;
            else
                try
                    pipelineRunSave(runObj);
                catch
                end
            end
            [runPath, ~] = runObj.getPath;
            if isempty(runPath) || ~exist(runPath, 'dir')
                uialert(app.UIFigure, 'No current run folder is available yet.', 'Open run artifact', 'Icon', 'warning');
                return;
            end
            switch lower(char(string(kind)))
                case 'log'
                    target = fullfile(runPath, 'run_log.txt');
                case 'params'
                    target = fullfile(runPath, 'run_params.json');
                case 'summary'
                    target = fullfile(runPath, 'run_summary.txt');
                otherwise
                    target = runPath;
            end
            if ~exist(target, 'file') && ~exist(target, 'dir')
                try
                    pipelineRunSave(runObj);
                catch ME
                    uialert(app.UIFigure, ME.message, 'Open run artifact', 'Icon', 'error');
                    return;
                end
            end
            openPathInSystem(app, target);
        end

        function showCurrentRunLog(app)
            runObj = app.CurrentRun;
            if isempty(runObj) || ~isa(runObj, 'pipelineRun')
                if ~saveCurrentRun(app, false)
                    return;
                end
                runObj = app.CurrentRun;
            else
                try
                    pipelineRunSave(runObj);
                catch
                end
            end
            [runPath, ~] = runObj.getPath;
            logFile = fullfile(runPath, 'run_log.txt');
            if exist(logFile, 'file') ~= 2
                try
                    pipelineRunSave(runObj);
                catch
                end
            end
            txt = {'No run log available yet.'};
            if exist(logFile, 'file') == 2
                try
                    txt = splitlines(fileread(logFile));
                    txt = cellstr(txt(:));
                catch ME
                    txt = {['Unable to read run log: ' ME.message]};
                end
            end

            fig = uifigure('Name', 'Pipeline run log', 'Position', [160 120 920 620]);
            grid = uigridlayout(fig, [3 4]);
            grid.RowHeight = {24, '1x', 32};
            grid.ColumnWidth = {'1x', 120, 120, 120};
            grid.Padding = [12 12 12 12];
            grid.RowSpacing = 8;
            grid.ColumnSpacing = 8;

            titleLabel = uilabel(grid, 'Text', ['Run log: ' logFile], 'Interpreter', 'none');
            titleLabel.Layout.Row = 1;
            titleLabel.Layout.Column = [1 4];

            area = uitextarea(grid, 'Editable', 'off', 'Value', txt);
            area.Layout.Row = 2;
            area.Layout.Column = [1 4];

            runFileLabel = uilabel(grid, 'Text', fullfile(runPath, 'run.json'), 'Interpreter', 'none', 'FontColor', [0.35 0.35 0.35]);
            runFileLabel.Layout.Row = 3;
            runFileLabel.Layout.Column = 1;
            btnFolder = uibutton(grid, 'push', 'Text', 'Open folder', ...
                'ButtonPushedFcn', @(~,~)openPathInSystem(app, runPath));
            btnFolder.Layout.Row = 3;
            btnFolder.Layout.Column = 2;
            btnFile = uibutton(grid, 'push', 'Text', 'Open log file', ...
                'ButtonPushedFcn', @(~,~)openPathInSystem(app, logFile));
            btnFile.Layout.Row = 3;
            btnFile.Layout.Column = 3;
            btnClose = uibutton(grid, 'push', 'Text', 'Close', ...
                'ButtonPushedFcn', @(~,~)delete(fig));
            btnClose.Layout.Row = 3;
            btnClose.Layout.Column = 4;
        end

        function openPathInSystem(app, targetPath) %#ok<INUSD>
            targetPath = char(string(targetPath));
            try
                if ispc
                    winopen(targetPath);
                elseif ismac
                    system(['open "' strrep(targetPath, '"', '\"') '" &']);
                else
                    system(['xdg-open "' strrep(targetPath, '"', '\"') '" &']);
                end
            catch ME
                uialert(app.UIFigure, ME.message, 'Open path', 'Icon', 'error');
            end
        end

        function logRunEvent(app, runObj, message, category) %#ok<INUSD>
            if nargin < 4 || isempty(category)
                category = 'pipeline2';
            end
            if isempty(runObj) || ~isa(runObj, 'pipelineRun')
                return;
            end
            try
                runObj.log(message, category);
            catch
            end
        end

        function loadRunIntoUi(app, runObj)
            if isempty(runObj) || ~isa(runObj, 'pipelineRun')
                return;
            end
            app.CurrentRun = runObj;
            app.CurrentRunPath = runObj.path;
            ctx = runObj.ctx;
            if isstruct(ctx)
                if isfield(ctx, 'run') && isstruct(ctx.run)
                    if isfield(ctx.run, 'runPolicy') && strcmpi(char(string(ctx.run.runPolicy)), 'restart')
                        app.ResumeoptionsDropDown.Value = 'Restart from scratch';
                    else
                        app.ResumeoptionsDropDown.Value = 'Resume previous progress';
                    end
                    if isfield(ctx.run, 'nodeParams') && isstruct(ctx.run.nodeParams)
                        app.RuntimeNodeParams = uiRuntimeNodeParamsFromRun(app, ctx.run.nodeParams);
                    end
                    if isfield(ctx.run, 'selectedNodes')
                        applySelectedRunNodes(app, ctx.run.selectedNodes);
                    end
                    if isfield(ctx.run, 'rawDataPath')
                        setRuntimeValuePreserveParse(app, 'rawDataPath', ctx.run.rawDataPath);
                    end
                    if isfield(ctx.run, 'projectPath')
                        setRuntimeValuePreserveParse(app, 'projectPath', ctx.run.projectPath);
                    end
                    if isfield(ctx.run, 'executionTarget') && isstruct(app.HubFieldHandles) && ...
                            isfield(app.HubFieldHandles, 'executionTarget') && isvalid(app.HubFieldHandles.executionTarget)
                        target = char(string(ctx.run.executionTarget));
                        if any(strcmp(app.HubFieldHandles.executionTarget.ItemsData, target))
                            app.HubFieldHandles.executionTarget.Value = target;
                            app.RuntimeValues.executionTarget = target;
                        end
                    end
                end
                if isfield(ctx, 'hub') && isstruct(ctx.hub)
                    applyHubSettingsToUi(app, ctx.hub);
                    updateHubRuntimeControlsVisibility(app);
                end
                if isfield(ctx, 'sel') && isstruct(ctx.sel)
                    if isfield(ctx.sel, 'fovs'), setRuntimeValuePreserveParse(app, 'fovs', selectionToText(app, ctx.sel.fovs)); end
                    if isfield(ctx.sel, 'frames'), setRuntimeValuePreserveParse(app, 'frames', selectionToText(app, ctx.sel.frames)); end
                    if isfield(ctx.sel, 'rois'), setRuntimeValuePreserveParse(app, 'rois', selectionToText(app, ctx.sel.rois)); end
                end
                if isfield(ctx, 'io') && isstruct(ctx.io) && isfield(ctx.io, 'existingPolicy') && ~isempty(ctx.io.existingPolicy)
                    setRuntimeValuePreserveParse(app, 'outputPolicy', ctx.io.existingPolicy);
                end
            end
            if ~isempty(runObj.projectPath)
                bindProjectFromPath(app, [runObj.projectPath '.mat'], false);
            end
            refreshModuleTabs(app);
            refreshValidationReport(app);
        end

        function params = uiRuntimeNodeParamsFromRun(app, runNodeParams)
            params = struct();
            if ~isstruct(runNodeParams)
                return;
            end
            fn = fieldnames(runNodeParams);
            for i = 1:numel(fn)
                nodeId = '';
                for j = 1:numel(app.Data.nodes)
                    id = char(string(app.Data.nodes(j).id));
                    if strcmp(matlab.lang.makeValidName(id), fn{i})
                        nodeId = id;
                        break;
                    end
                end
                if isempty(nodeId)
                    nodeId = fn{i};
                end
                params.(runtimeNodeKey(app, nodeId)) = runNodeParams.(fn{i});
            end
        end

        function applySelectedRunNodes(app, selectedNodes)
            data = app.UISelectedModuleTable.Data;
            if isempty(data)
                return;
            end
            selectedNodes = cellstr(string(selectedNodes(:)));
            for i = 1:size(data, 1)
                data{i,1} = any(strcmp(selectedNodes, char(string(data{i,2}))));
            end
            app.UISelectedModuleTable.Data = data;
        end

        function txt = selectionToText(app, value) %#ok<INUSD>
            if isempty(value)
                txt = 'all';
            elseif isnumeric(value)
                txt = mat2str(value);
                txt = strrep(txt, '[', '');
                txt = strrep(txt, ']', '');
            elseif iscell(value)
                txt = strjoin(cellstr(string(value)), ',');
            else
                txt = char(string(value));
            end
        end

        function appendRunReport(app, label, report)
            txt = app.PipelineandRuncheckreportLabel.Text;
            lines = {txt, '', label};
            if isstruct(report)
                if isfield(report, 'okStrict')
                    lines{end+1} = ['okStrict: ' char(string(report.okStrict))]; %#ok<AGROW>
                end
                if isfield(report, 'summary') && isstruct(report.summary)
                    lines{end+1} = ['summary: ' jsonencode(report.summary)]; %#ok<AGROW>
                elseif isfield(report, 'order') && ~isempty(report.order)
                    lines{end+1} = ['order: ' strjoin(cellstr(report.order), ' -> ')]; %#ok<AGROW>
                end
                if isfield(report, 'errors') && ~isempty(report.errors)
                    lines{end+1} = ['errors: ' strjoin(cellstr(string(report.errors)), ' | ')]; %#ok<AGROW>
                end
            end
            app.PipelineandRuncheckreportLabel.Text = strjoin(lines, newline);
        end

        function reportText = printExceptionToConsole(app, titleText, ME) %#ok<INUSD>
            if nargin < 2 || isempty(titleText)
                titleText = 'Pipeline error';
            end
            try
                reportText = getReport(ME, 'extended', 'hyperlinks', 'off');
            catch
                reportText = ME.message;
            end
            try
                fprintf(2, '\n==================== %s ====================\n', char(string(titleText)));
                fprintf(2, '%s\n', reportText);
                fprintf(2, '==================== end %s ====================\n\n', char(string(titleText)));
            catch
            end
        end

        function NewpipelineMenuSelected(app, event) %#ok<INUSD>
            app.Data.nodes = struct([]);
            app.Data.edges = struct('from',{},'to',{},'fromPort',{},'toPort',{},'condition',{});
            app.SelectedNodeIndex = NaN;
            app.NodeCounter = 0;
            app.RuntimeNodeParams = struct();
            app.CurrentPipeline = [];
            app.CurrentPipelinePath = '';
            app.CurrentPipelineWorkspaceVar = '';
            app.CurrentRun = [];
            app.CurrentRunPath = '';
            app.RoiManualSelectedRectangle = NaN;
            clearRoiManualPreviewHandles(app);
            refreshAfterModelChange(app);
        end

        function SavecurrentpipelineMenuSelected(app, event) %#ok<INUSD>
            savePipelineInteractive(app, false);
        end

        function SavepipelineasMenuSelected(app, event) %#ok<INUSD>
            savePipelineInteractive(app, true);
        end

        function LoadpipelineMenuSelected(app, event) %#ok<INUSD>
            [file, pth] = uigetfile({'pipeline.json','pipeline.json'; '*.json','JSON files'}, 'Load pipeline template', pwd);
            if isequal(file, 0)
                return;
            end
            try
                [pipeObj, msg] = pipelineLoad(fullfile(pth, file));
                if isempty(pipeObj)
                    error('pipeline2:PipelineLoadFailed', '%s', msg);
                end
                loadPipelineFromObject(app, pipeObj);
                addRecentPipelinePath(app, fullfile(pth, file));
                if ~isempty(app.CurrentPipelineWorkspaceVar)
                    app.RuninformationhereLabel.Text = ['Pipeline loaded in workspace: ' app.CurrentPipelineWorkspaceVar];
                end
            catch ME
                uialert(app.UIFigure, ME.message, 'Load pipeline', 'Icon', 'error');
            end
        end

        function SaverunMenuSelected(app, event) %#ok<INUSD>
            saveCurrentRun(app, false);
        end

        function SaverunasMenuSelected(app, event) %#ok<INUSD>
            saveCurrentRun(app, true);
        end

        function LoadrunMenuSelected(app, event) %#ok<INUSD>
            [file, pth] = uigetfile({'run.json','run.json'; '*.json','JSON files'}, 'Load pipeline run', pwd);
            if isequal(file, 0)
                return;
            end
            try
                [runObj, msg] = pipelineRunLoad(fullfile(pth, file));
                if isempty(runObj)
                    error('pipeline2:RunLoadFailed', '%s', msg);
                end
                loadRunIntoUi(app, runObj);
            catch ME
                uialert(app.UIFigure, ME.message, 'Load run', 'Icon', 'error');
            end
        end

        function RunButtonPushed(app, event) %#ok<INUSD>
            if ~ensurePipelineSavedForRun(app)
                return;
            end
            if ~ensureCurrentProjectForRun(app)
                return;
            end
            runObj = [];
            try
                ctxPreflight = buildRunContext(app);
                runObj = createOrUpdateCurrentRun(app, ctxPreflight, 'preflight');
                logRunEvent(app, runObj, 'Run requested from pipeline2.', 'pipeline2');
                pipelineRunSave(runObj);
                shallowSave(app.CurrentProject, 'shallowObj');
            catch ME
                printExceptionToConsole(app, 'Pipeline prepare failed', ME);
                uialert(app.UIFigure, ME.message, 'Prepare run', 'Icon', 'error');
                return;
            end
            [okTemplate, reportTemplate] = refreshValidationReportWithOutput(app);
            runtimeIssues = validateRuntimeInputs(app);
            if ~okTemplate
                app.PipelineandRuncheckreportLabel.Text = formatValidationReport(app, okTemplate, reportTemplate);
                runObj.status = 'failed';
                runObj.outputs.validationReport = reportTemplate;
                logRunEvent(app, runObj, 'Run blocked by pipeline template validation.', 'pipeline2');
                pipelineRunSave(runObj);
                uialert(app.UIFigure, 'Pipeline template is not valid. Fix blocking issues before run.', 'Run', 'Icon', 'error');
                return;
            end
            blockingRuntimeIssues = runtimeIssues(~contains(string(runtimeIssues), "unusual"));
            if ~isempty(blockingRuntimeIssues)
                CheckpipelineButtonPushed(app, []);
                runObj.status = 'failed';
                runObj.outputs.runtimeIssues = cellstr(string(blockingRuntimeIssues(:)));
                logRunEvent(app, runObj, ['Run blocked by runtime inputs: ' strjoin(cellstr(string(blockingRuntimeIssues(:))), ' | ')], 'pipeline2');
                pipelineRunSave(runObj);
                uialert(app.UIFigure, strjoin(blockingRuntimeIssues, newline), 'Runtime inputs', 'Icon', 'error');
                return;
            end

            d = [];
            try
                d = uiprogressdlg(app.UIFigure, 'Title', 'Pipeline run', ...
                    'Message', 'Saving preflight run...', 'Indeterminate', 'on');
            catch
            end
            try
                ctx = buildRunContext(app);
                pipeObj = buildExecutablePipelineObject(app, app.CurrentPipelinePath, ctx);
                app.CurrentPipeline = pipeObj;
                assignCurrentPipelineToWorkspace(app, pipeObj);
                runObj = createOrUpdateCurrentRun(app, ctx, 'preflight');
                logRunEvent(app, runObj, 'Preflight run context saved.', 'pipeline2');
                pipelineRunSave(runObj);

                if ~isempty(d), d.Message = 'Dry-run validation...'; end
                ctxDry = ctx;
                ctxDry.dryRun = true;
                [~, dryReport] = runPipeline(pipeObj, ctxDry);
                runObj.outputs.dryRunReport = dryReport;
                runObj.status = 'dry_run_ok';
                runObj.ctx = ctxDry;
                logRunEvent(app, runObj, 'Dry-run validation completed.', 'pipeline2');
                pipelineRunSave(runObj);
                appendRunReport(app, 'Dry-run: OK', dryReport);

                if strcmp(runtimeExecutionTarget(app), 'hub')
                    if ~isempty(d), d.Message = 'Submitting run to DetecDiv Hub...'; end
                    hub = hubSettingsFromUi(app);
                    try
                        detecdiv_hub_settings_set(hub);
                    catch
                    end
                    runObj.ctx = ctx;
                    runObj.ctx.hub = hub;
                    logRunEvent(app, runObj, 'Submitting run to DetecDiv Hub.', 'pipeline2');
                    pipelineRunSave(runObj);
                    [job, runObj] = detecdiv_hub_submit_pipeline_run(runObj, app.CurrentProject, 'hub', hub);
                    logRunEvent(app, runObj, 'Hub submission completed.', 'pipeline2');
                    pipelineRunSave(runObj);
                    shallowSave(app.CurrentProject, 'shallowObj');
                    appendRunReport(app, ['Hub submit: ' char(string(getField(app, job, 'status', 'submitted')))], job);
                    app.RuninformationhereLabel.Text = ['Hub run submitted: ' fullfile(runObj.path, 'run.json')];
                else
                    if ~isempty(d), d.Message = 'Running local MATLAB pipeline...'; end
                    ctxRun = ctx;
                    ctxRun.dryRun = false;
                    runObj.status = 'running';
                    runObj.ctx = ctxRun;
                    logRunEvent(app, runObj, 'Local MATLAB run started.', 'pipeline2');
                    pipelineRunSave(runObj);
                    [ctxOut, report] = runPipeline(pipeObj, ctxRun);
                    runObj.ctx = ctxOut;
                    runObj.outputs.report = report;
                    runObj.status = 'done';
                    runObj.progress = getField(app, report, 'summary', struct());
                    logRunEvent(app, runObj, 'Local MATLAB run completed.', 'pipeline2');
                    pipelineRunSave(runObj);
                    shallowSave(app.CurrentProject, 'shallowObj');
                    appendRunReport(app, 'Local run: OK', report);
                    app.RuninformationhereLabel.Text = ['Run done: ' fullfile(runObj.path, 'run.json')];
                end
            catch ME
                fullReport = printExceptionToConsole(app, 'Pipeline run failed', ME);
                try
                    if exist('runObj', 'var') && ~isempty(runObj)
                        runObj.status = 'failed';
                        runObj.outputs.error = struct('identifier', ME.identifier, ...
                            'message', ME.message, 'report', fullReport);
                        runObj.ctx = buildRunContext(app);
                        logRunEvent(app, runObj, ['Run failed: ' ME.message], 'pipeline2');
                        pipelineRunSave(runObj);
                    end
                catch
                end
                app.PipelineandRuncheckreportLabel.Text = [app.PipelineandRuncheckreportLabel.Text newline newline ...
                    'Run failed:' newline ME.identifier newline ME.message newline newline ...
                    getReport(ME, 'basic', 'hyperlinks', 'off')];
                uialert(app.UIFigure, ME.message, 'Run failed', 'Icon', 'error');
            end
            try, close(d); catch, end
        end

        function CloseappButtonPushed(app, event) %#ok<INUSD>
            delete(app);
        end

        function deleteSelectedModule(app)
            if isnan(app.SelectedNodeIndex) || app.SelectedNodeIndex < 1 || app.SelectedNodeIndex > numel(app.Data.nodes)
                return;
            end
            nodeId = char(string(getField(app, app.Data.nodes(app.SelectedNodeIndex), 'id', '')));
            app.Data.nodes(app.SelectedNodeIndex) = [];
            removeRuntimeNodeParams(app, nodeId);
            if isempty(app.Data.nodes)
                app.SelectedNodeIndex = NaN;
            else
                app.SelectedNodeIndex = min(app.SelectedNodeIndex, numel(app.Data.nodes));
            end
            rebuildEdgesFromLayout(app);
            refreshAfterModelChange(app);
        end

        function col = getLayoutCol(app, node) %#ok<INUSD>
            col = 1;
            if isstruct(node) && isfield(node, 'layout') && numel(node.layout) >= 1 && ~isempty(node.layout(1))
                col = max(1, round(double(node.layout(1))));
            end
        end

        function row = getLayoutRow(app, node) %#ok<INUSD>
            row = 1;
            if isstruct(node) && isfield(node, 'layout') && numel(node.layout) >= 2 && ~isempty(node.layout(2))
                row = max(1, round(double(node.layout(2))));
            end
        end

        function out = appendStruct(app, arr, item) %#ok<INUSD>
            if isempty(arr)
                out = item;
            else
                out = arr;
                out(end+1) = item;
            end
        end

        function updateCommonControlsEnableState(app)
            hasNode = ~isnan(app.SelectedNodeIndex) && app.SelectedNodeIndex >= 1 && app.SelectedNodeIndex <= numel(app.Data.nodes);
            state = ternary(app, hasNode, 'on', 'off');
            app.IdEditField.Enable = state;
            app.TypeDropDown.Enable = state;
            app.SubtypeDropDown.Enable = state;
            app.AdvancedmodeCheckBox.Enable = state;
            try, app.InsertbeforeselectedButton.Enable = state; catch, end
            try, app.DeleteselectedButton.Enable = state; catch, end
            if ~hasNode
                app.IdEditField.Value = '';
                app.AdvancedmodeCheckBox.Value = false;
            end
        end

        function refreshCommonControlsFromSelection(app)
            if isnan(app.SelectedNodeIndex) || app.SelectedNodeIndex < 1 || app.SelectedNodeIndex > numel(app.Data.nodes)
                return;
            end
            node = app.Data.nodes(app.SelectedNodeIndex);
            app.IdEditField.Value = char(string(getField(app, node, 'id', '')));
            app.AdvancedmodeCheckBox.Value = logical(getField(app, node, 'uiAdvanced', false));
            selectTypeControlsForNode(app, node);
        end

        function edges = replaceNodeIdInEdges(app, edges, oldId, newId) %#ok<INUSD>
            for i = 1:numel(edges)
                if strcmp(char(string(edges(i).from)), oldId)
                    edges(i).from = newId;
                end
                if strcmp(char(string(edges(i).to)), oldId)
                    edges(i).to = newId;
                end
            end
        end

        function id = makeUniqueNodeId(app, baseId)
            id = char(string(baseId));
            ids = {};
            if ~isempty(app.Data.nodes)
                ids = {app.Data.nodes.id};
            end
            k = 2;
            while any(strcmp(ids, id))
                id = sprintf('%s_%d', char(string(baseId)), k);
                k = k + 1;
            end
        end

        function v = getField(app, S, name, defaultValue) %#ok<INUSD>
            if isstruct(S) && isfield(S, name) && ~isempty(S.(name))
                v = S.(name);
            else
                v = defaultValue;
            end
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [80 80 1240 960];
            app.UIFigure.Name = 'MATLAB App';

            % Create FileMenu
            app.FileMenu = uimenu(app.UIFigure);
            app.FileMenu.Text = 'File';

            % Create NewpipelineMenu
            app.NewpipelineMenu = uimenu(app.FileMenu);
            app.NewpipelineMenu.Text = 'New pipeline';

            % Create LoadpipelineMenu
            app.LoadpipelineMenu = uimenu(app.FileMenu);
            app.LoadpipelineMenu.Text = 'Load pipeline...';

            % Create LoadrecentpipelineMenu
            app.LoadrecentpipelineMenu = uimenu(app.FileMenu);
            app.LoadrecentpipelineMenu.Text = 'Load recent pipeline';

            % Create SavecurrentpipelineMenu
            app.SavecurrentpipelineMenu = uimenu(app.FileMenu);
            app.SavecurrentpipelineMenu.Text = 'Save current pipeline';

            % Create SavepipelineasMenu
            app.SavepipelineasMenu = uimenu(app.FileMenu);
            app.SavepipelineasMenu.Text = 'Save pipeline as...';

            % Create LoadrunMenu
            app.LoadrunMenu = uimenu(app.FileMenu);
            app.LoadrunMenu.Separator = 'on';
            app.LoadrunMenu.Text = 'Load run...';

            % Create SaverunMenu
            app.SaverunMenu = uimenu(app.FileMenu);
            app.SaverunMenu.Text = 'Save run';

            % Create SaverunasMenu
            app.SaverunasMenu = uimenu(app.FileMenu);
            app.SaverunasMenu.Text = 'Save run as ...';

            % Create ExportpipelineMenu
            app.ExportpipelineMenu = uimenu(app.FileMenu);
            app.ExportpipelineMenu.Text = 'Export pipeline...';

            % Create GraphPanel
            app.GraphPanel = uipanel(app.UIFigure);
            app.GraphPanel.Title = 'Graph';
            app.GraphPanel.Position = [13 628 1214 304];

            % Create UIGraphAxes
            app.UIGraphAxes = uiaxes(app.GraphPanel);
            title(app.UIGraphAxes, 'Title')
            xlabel(app.UIGraphAxes, 'X')
            ylabel(app.UIGraphAxes, 'Y')
            zlabel(app.UIGraphAxes, 'Z')
            app.UIGraphAxes.Position = [15 9 1184 265];

            % Create BuildPanel
            app.BuildPanel = uipanel(app.UIFigure);
            app.BuildPanel.Title = 'Build';
            app.BuildPanel.Position = [13 621 250 304];

            % Create ForkgraphButton
            app.ForkgraphButton = uibutton(app.BuildPanel, 'push');
            app.ForkgraphButton.Position = [9 251 100 23];
            app.ForkgraphButton.Text = 'Fork graph';

            % Create MergegraphButton
            app.MergegraphButton = uibutton(app.BuildPanel, 'push');
            app.MergegraphButton.Position = [9 219 100 23];
            app.MergegraphButton.Text = 'Merge graph';

            % Create InsertbeforeselectedButton
            app.InsertbeforeselectedButton = uibutton(app.BuildPanel, 'push');
            app.InsertbeforeselectedButton.Position = [9 187 140 23];
            app.InsertbeforeselectedButton.Text = 'Insert before selected';

            % Create DeleteselectedButton
            app.DeleteselectedButton = uibutton(app.BuildPanel, 'push');
            app.DeleteselectedButton.Position = [9 155 140 23];
            app.DeleteselectedButton.Text = 'Delete selected';

            % Create UIWorkspacePipelineTable
            app.UIWorkspacePipelineTable = uitable(app.BuildPanel);
            app.UIWorkspacePipelineTable.ColumnName = {'Column 1'; 'Column 2'; 'Column 3'; 'Column 4'};
            app.UIWorkspacePipelineTable.RowName = {};
            app.UIWorkspacePipelineTable.Position = [17 9 218 134];

            % Create ParametersPanel
            app.ParametersPanel = uipanel(app.UIFigure);
            app.ParametersPanel.Title = 'Parameters';
            app.ParametersPanel.Position = [13 14 1214 598];

            % Create TabGroup
            app.TabGroup = uitabgroup(app.ParametersPanel);
            app.TabGroup.Position = [18 51 820 465];

            % Create TypeDropDownLabel
            app.TypeDropDownLabel = uilabel(app.ParametersPanel);
            app.TypeDropDownLabel.HorizontalAlignment = 'right';
            app.TypeDropDownLabel.Position = [25 535 31 22];
            app.TypeDropDownLabel.Text = 'Type';

            % Create TypeDropDown
            app.TypeDropDown = uidropdown(app.ParametersPanel);
            app.TypeDropDown.Position = [71 535 118 22];

            % Create IdEditFieldLabel
            app.IdEditFieldLabel = uilabel(app.ParametersPanel);
            app.IdEditFieldLabel.HorizontalAlignment = 'right';
            app.IdEditFieldLabel.Position = [24 535 16 22];
            app.IdEditFieldLabel.Text = 'Id';

            % Create IdEditField
            app.IdEditField = uieditfield(app.ParametersPanel, 'text');
            app.IdEditField.Position = [55 535 230 22];

            % Create AdvancedmodeCheckBox
            app.AdvancedmodeCheckBox = uicheckbox(app.ParametersPanel);
            app.AdvancedmodeCheckBox.Text = 'Advanced mode';
            app.AdvancedmodeCheckBox.Position = [306 535 109 22];

            % Create SubtypeDropDownLabel
            app.SubtypeDropDownLabel = uilabel(app.ParametersPanel);
            app.SubtypeDropDownLabel.HorizontalAlignment = 'right';
            app.SubtypeDropDownLabel.Position = [4 510 52 22];
            app.SubtypeDropDownLabel.Text = 'Sub type';

            % Create SubtypeDropDown
            app.SubtypeDropDown = uidropdown(app.ParametersPanel);
            app.SubtypeDropDown.Position = [71 510 118 22];

            % Create RuntimeTab
            app.RuntimeTab = uitab(app.TabGroup);
            app.RuntimeTab.Title = 'Runtime';

            % Create UIFOVTable
            app.UIFOVTable = uitable(app.RuntimeTab);
            app.UIFOVTable.ColumnName = {'Column 1'; 'Column 2'; 'Column 3'; 'Column 4'};
            app.UIFOVTable.RowName = {};
            app.UIFOVTable.Position = [256 42 417 200];

            % Create ListofpathprojectsLabel
            app.ListofpathprojectsLabel = uilabel(app.RuntimeTab);
            app.ListofpathprojectsLabel.HorizontalAlignment = 'right';
            app.ListofpathprojectsLabel.Position = [270 308 109 22];
            app.ListofpathprojectsLabel.Text = 'List of path/projects';

            % Create PathProjectBox
            app.PathProjectBox = uilistbox(app.RuntimeTab);
            app.PathProjectBox.Position = [395 256 278 74];

            % Create ExecutionDropDownLabel
            app.ExecutionDropDownLabel = uilabel(app.RuntimeTab);
            app.ExecutionDropDownLabel.HorizontalAlignment = 'right';
            app.ExecutionDropDownLabel.Position = [499 396 58 22];
            app.ExecutionDropDownLabel.Text = 'Execution';

            % Create ExecutionDropDown
            app.ExecutionDropDown = uidropdown(app.RuntimeTab);
            app.ExecutionDropDown.Items = {'Auto', 'GPU', 'CPU', ''};
            app.ExecutionDropDown.Position = [572 396 100 22];
            app.ExecutionDropDown.Value = 'Auto';

            % Create ResumeoptionsDropDownLabel
            app.ResumeoptionsDropDownLabel = uilabel(app.RuntimeTab);
            app.ResumeoptionsDropDownLabel.HorizontalAlignment = 'right';
            app.ResumeoptionsDropDownLabel.Position = [457 361 92 22];
            app.ResumeoptionsDropDownLabel.Text = 'Resume options';

            % Create ResumeoptionsDropDown
            app.ResumeoptionsDropDown = uidropdown(app.RuntimeTab);
            app.ResumeoptionsDropDown.Position = [572 361 100 22];

            % Create UISelectedModuleTable
            app.UISelectedModuleTable = uitable(app.RuntimeTab);
            app.UISelectedModuleTable.ColumnName = {'Column 1'; 'Column 2'; 'Column 3'; 'Column 4'};
            app.UISelectedModuleTable.RowName = {};
            app.UISelectedModuleTable.Position = [6 42 236 288];

            % Create SelectedmodulesLabel
            app.SelectedmodulesLabel = uilabel(app.RuntimeTab);
            app.SelectedmodulesLabel.Position = [9 340 100 22];
            app.SelectedmodulesLabel.Text = 'Selected modules';

            % Create RuninformationhereLabel
            app.RuninformationhereLabel = uilabel(app.ParametersPanel);
            app.RuninformationhereLabel.Position = [214 516 610 22];
            app.RuninformationhereLabel.Text = 'Run information here';

            % Create PipelineandRuncheckreportLabel
            app.PipelineandRuncheckreportLabel = uilabel(app.ParametersPanel);
            app.PipelineandRuncheckreportLabel.Position = [862 25 335 485];
            app.PipelineandRuncheckreportLabel.Text = 'Pipeline and Run check report';

            % Create CloseappButton
            app.CloseappButton = uibutton(app.ParametersPanel, 'push');
            app.CloseappButton.Position = [27 12 100 23];
            app.CloseappButton.Text = 'Close app';

            % Create RunButton
            app.RunButton = uibutton(app.ParametersPanel, 'push');
            app.RunButton.Position = [276 11 100 23];
            app.RunButton.Text = 'Run !';

            % Create CheckpipelineButton
            app.CheckpipelineButton = uibutton(app.ParametersPanel, 'push');
            app.CheckpipelineButton.Position = [136 11 130 23];
            app.CheckpipelineButton.Text = 'Check pipeline / run';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = pipeline2

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute startup logic after the designer-created layout exists
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end
