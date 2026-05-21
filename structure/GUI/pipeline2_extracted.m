classdef pipeline2 < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                        matlab.ui.Figure
        FileMenu                        matlab.ui.container.Menu
        NewpipelineMenu                 matlab.ui.container.Menu
        SavecurrentpipelineMenu         matlab.ui.container.Menu
        SavepipelineasMenu              matlab.ui.container.Menu
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
        DynamicModuleTabs = gobjects(0)
        AvailableModules cell = {}
        IsRefreshingTabs logical = false
        RuntimeFieldHandles struct = struct()
        RuntimeButtonHandles struct = struct()
        RuntimeValues struct = struct()
        RuntimeNodeParams struct = struct()
        RuntimeParseInfo struct = struct()
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

            app.TypeDropDown.Items = {'dataLoader','ROI definition','roiExtract','processor','classifier'};
            app.TypeDropDown.Value = 'dataLoader';
            app.TypeDropDown.ValueChangedFcn = createCallbackFcn(app, @TypeDropDownValueChanged, true);
            updateSubtypeChoices(app);
            app.SubtypeDropDown.ValueChangedFcn = createCallbackFcn(app, @SubtypeDropDownValueChanged, true);
            app.AdvancedmodeCheckBox.ValueChangedFcn = createCallbackFcn(app, @AdvancedmodeCheckBoxValueChanged, true);
            app.TabGroup.SelectionChangedFcn = createCallbackFcn(app, @TabGroupSelectionChanged, true);

            app.UIWorkspacePipelineTable.ColumnName = {'Module','Type','Package','Status'};
            app.UIWorkspacePipelineTable.ColumnEditable = false(1,4);
            app.UIWorkspacePipelineTable.ColumnWidth = {82 82 62 'auto'};
            app.UIWorkspacePipelineTable.SelectionChangedFcn = createCallbackFcn(app, @UIWorkspacePipelineTableSelectionChanged, true);

            app.UISelectedModuleTable.ColumnName = {'Run','Module','Type','Package'};
            app.UISelectedModuleTable.ColumnEditable = [true false false false];
            app.UISelectedModuleTable.ColumnWidth = {42 82 70 'auto'};

            app.ResumeoptionsDropDown.Items = {'Resume previous progress','Restart from scratch'};
            app.ResumeoptionsDropDown.Value = 'Resume previous progress';
            app.ExecutionDropDown.Items = {'Auto','GPU','CPU'};
            app.ExecutionDropDown.Value = 'Auto';
            buildRuntimeControls(app);

            app.ForkgraphButton.ButtonPushedFcn = createCallbackFcn(app, @ForkgraphButtonPushed, true);
            app.MergegraphButton.ButtonPushedFcn = createCallbackFcn(app, @MergegraphButtonPushed, true);
            app.CloseappButton.ButtonPushedFcn = createCallbackFcn(app, @CloseappButtonPushed, true);
            app.RunButton.ButtonPushedFcn = createCallbackFcn(app, @RunButtonPushed, true);
            app.CheckpipelineButton.ButtonPushedFcn = createCallbackFcn(app, @CheckpipelineButtonPushed, true);
            app.NewpipelineMenu.MenuSelectedFcn = createCallbackFcn(app, @NewpipelineMenuSelected, true);
            app.SavecurrentpipelineMenu.MenuSelectedFcn = createCallbackFcn(app, @SavecurrentpipelineMenuSelected, true);

            app.RuninformationhereLabel.Text = 'Template mode - click the grey block to add a module.';
            app.PipelineandRuncheckreportLabel.Text = 'No pipeline yet.';

            app.ModuleContextMenu = uicontextmenu(app.UIFigure);
            uimenu(app.ModuleContextMenu, 'Text', 'Delete module', ...
                'MenuSelectedFcn', @(~,~)deleteSelectedModule(app));

            app.IdEditField.ValueChangedFcn = createCallbackFcn(app, @IdEditFieldValueChanged, true);
            updateCommonControlsEnableState(app);
        end

        function modules = defaultModuleLibrary(app) %#ok<MANU>
            modules = { ...
                'dataLoader',       'dataLoader',     '',                         'Load raw image data'; ...
                'roiPattern',       'roiPattern',     '',                         'Pattern-based ROI definition'; ...
                'roiManual',        'roiManual',      '',                         'Manual ROI definition'; ...
                'roiGrid',          'roiGrid',        '',                         'Grid/full-frame ROI definition'; ...
                'roiTracked',       'roiTracked',     '',                         'Tracked/mobile ROI definition'; ...
                'roiExtract',       'roiExtract',     '',                         'Extract ROI H5 image stores'; ...
                'combineChannels',  'processor',      'combineMultipleChannels',  'Combine ROI channels'; ...
                'computeMetrics',   'processor',      'computeMetrics',           'Compute ROI metrics'; ...
                'computeLineage',   'processor',      'computeLineage',           'Compute lineage outputs'; ...
                'cellposeSAM',      'classifier',     'cellposesam',              'Segment with CellposeSAM'; ...
                'cnn_lstm',         'classifier',     'cnn_lstm',                 'Sequence classifier' ...
                };
        end

        function refreshAvailableModuleTable(app)
            app.UIWorkspacePipelineTable.Data = app.AvailableModules;
        end

        function refreshSelectedModuleTable(app)
            nodes = app.Data.nodes;
            data = cell(numel(nodes), 4);
            for i = 1:numel(nodes)
                data{i,1} = true;
                data{i,2} = char(string(getField(app, nodes(i), 'id', '')));
                data{i,3} = char(string(getField(app, nodes(i), 'type', '')));
                data{i,4} = char(string(getField(app, nodes(i), 'pkg', '')));
            end
            app.UISelectedModuleTable.Data = data;
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
            refreshSelectedModuleTable(app);
            renameSelectedModuleTab(app, oldId, newId);
            redrawGraph(app);
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
        end

        function addModuleFromCurrentSelection(app)
            [nodeType, pkg] = selectedModuleTypeAndPackage(app);
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
                face = [0.90 0.94 0.98];
                edge = [0.24 0.36 0.50];
                if selected
                    face = [0.78 0.88 1.00];
                    edge = [0.05 0.32 0.68];
                end
                h = rectangle(app.UIGraphAxes, 'Position', [x y blockW blockH], ...
                    'Curvature', 0.08, 'FaceColor', face, 'EdgeColor', edge, ...
                    'LineWidth', 1.5, 'ButtonDownFcn', @(~,~)selectNode(app, i));
                h.UIContextMenu = app.ModuleContextMenu;
                t1 = text(app.UIGraphAxes, x + blockW/2, y + blockH*0.60, ...
                    char(string(getField(app, nodes(i), 'id', 'module'))), ...
                    'HorizontalAlignment', 'center', 'Interpreter', 'none', ...
                    'FontWeight', 'bold', 'FontSize', 9, 'ButtonDownFcn', @(~,~)selectNode(app, i));
                t1.UIContextMenu = app.ModuleContextMenu;
                t2 = text(app.UIGraphAxes, x + blockW/2, y + blockH*0.28, ...
                    blockTypeLabel(app, nodes(i)), ...
                    'HorizontalAlignment', 'center', 'Interpreter', 'none', ...
                    'FontSize', 8, 'Color', [0.25 0.25 0.25], 'ButtonDownFcn', @(~,~)selectNode(app, i));
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
            gt = text(app.UIGraphAxes, gx + blockW/2, gy + blockH/2, '+ module', ...
                'HorizontalAlignment', 'center', 'Interpreter', 'none', ...
                'Color', [0.35 0.35 0.35], 'FontWeight', 'bold', ...
                'ButtonDownFcn', @(~,~)addModuleFromCurrentSelection(app));
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
                h = quiver(app.UIGraphAxes, x1, y1, x2 - x1, y2 - y1, 0, ...
                    'Color', [0.42 0.48 0.55], ...
                    'LineWidth', 1.2, ...
                    'MaxHeadSize', 0.45, ...
                    'AutoScale', 'off', ...
                    'HitTest', 'off');
                app.EdgeHandles(end+1) = h; %#ok<AGROW>
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
            if ~isnan(app.SelectedNodeIndex) && app.SelectedNodeIndex >= 1 && app.SelectedNodeIndex <= numel(app.DynamicModuleTabs)
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
            try
                delete(app.UIFOVTable);
            catch
            end
            try
                delete(app.PathProjectBox);
            catch
            end
            try
                delete(app.ListofpathprojectsLabel);
            catch
            end

            panel = uipanel(app.RuntimeTab, 'Title', 'Run inputs', 'Position', [279 42 417 288]);
            grid = uigridlayout(panel, [7 3]);
            grid.RowHeight = {28, 28, 28, 28, 28, 28, 28};
            grid.ColumnWidth = {110, '1x', 86};
            grid.Padding = [8 8 8 8];
            grid.RowSpacing = 8;
            grid.ColumnSpacing = 8;

            app.RuntimeFieldHandles = struct();
            app.RuntimeButtonHandles = struct();
            app.RuntimeValues = struct();
            app.RuntimeParseInfo = struct();

            addRuntimeRow(app, grid, 1, 'Project', 'projectPath', 'Existing project folder or .mat file', 'Browse...');
            addRuntimeRow(app, grid, 2, 'Raw data', 'rawDataPath', 'Raw image/data folder used by dataloader', 'Browse...');
            addRuntimeRow(app, grid, 3, 'FOVs', 'fovs', 'all / 1,3,5 / 1:4', 'Pick...');
            addRuntimeRow(app, grid, 4, 'Frames', 'frames', 'all / 1:50 / 1,5,9', 'Pick...');
            addRuntimeChannelRow(app, grid, 5);
            addRuntimeRow(app, grid, 6, 'ROIs', 'rois', 'all / selected ROI ids', 'Pick...');
            addRuntimePolicyRow(app, grid, 7);
            updateRuntimeInputStates(app);
        end

        function addRuntimeRow(app, grid, row, labelText, key, placeholder, buttonText)
            label = uilabel(grid, 'Text', labelText);
            label.Layout.Row = row;
            label.Layout.Column = 1;

            field = uieditfield(grid, 'text');
            field.Layout.Row = row;
            field.Layout.Column = 2;
            try
                field.Placeholder = placeholder;
            catch
                field.Value = '';
            end
            field.ValueChangedFcn = @(src,~)runtimeFieldChanged(app, key, src.Value);

            btn = uibutton(grid, 'push', 'Text', buttonText);
            btn.Layout.Row = row;
            btn.Layout.Column = 3;
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
            dd.Layout.Column = 2;
            dd.Items = {'resolved after project/raw data load'};
            dd.Value = dd.Items{1};
            dd.ValueChangedFcn = @(src,~)runtimeFieldChanged(app, 'channels', src.Value);

            btn = uibutton(grid, 'push', 'Text', 'Select...');
            btn.Layout.Row = row;
            btn.Layout.Column = 3;
            btn.Tooltip = 'Select channel after project/raw data parsing.';
            btn.ButtonPushedFcn = @(~,~)runtimeButtonPushed(app, 'channels');

            app.RuntimeFieldHandles.channels = dd;
            app.RuntimeButtonHandles.channels = btn;
            app.RuntimeValues.channels = '';
        end

        function addRuntimePolicyRow(app, grid, row)
            label = uilabel(grid, 'Text', 'Output policy');
            label.Layout.Row = row;
            label.Layout.Column = 1;

            dd = uidropdown(grid);
            dd.Layout.Row = row;
            dd.Layout.Column = 2;
            dd.Items = {'Skip existing outputs','Replace existing outputs','Append/update existing outputs','Error if outputs exist'};
            dd.ItemsData = {'skip','replace','upsert','error'};
            dd.Value = 'skip';
            dd.Tooltip = 'Controls what happens when module outputs already exist. Resume controls checkpoints separately.';
            dd.ValueChangedFcn = @(src,~)runtimeFieldChanged(app, 'outputPolicy', src.Value);

            btn = uibutton(grid, 'push', 'Text', 'Explain');
            btn.Layout.Row = row;
            btn.Layout.Column = 3;
            btn.ButtonPushedFcn = @(~,~)showOutputPolicyHelp(app);

            app.RuntimeFieldHandles.outputPolicy = dd;
            app.RuntimeButtonHandles.outputPolicy = btn;
            app.RuntimeValues.outputPolicy = 'skip';
        end

        function runtimeFieldChanged(app, key, value)
            app.RuntimeValues.(key) = char(string(value));
            syncRuntimeValueToNodeParams(app, key);
            if strcmp(char(string(key)), 'rawDataPath')
                parseRuntimeRawDataPath(app, char(string(value)));
            end
            updateRuntimeInputStates(app);
            refreshValidationReport(app);
        end

        function runtimeButtonPushed(app, key)
            switch char(string(key))
                case 'projectPath'
                    [file, pth] = uigetfile({'*.mat;pipeline.json','Project files (*.mat, pipeline.json)'; '*.*','All files'}, ...
                        'Select existing DetecDiv project file');
                    if isequal(file, 0)
                        pth = uigetdir(pwd, 'Select existing DetecDiv project folder');
                        if isequal(pth, 0)
                            return;
                        end
                        setRuntimeValue(app, key, pth);
                    else
                        setRuntimeValue(app, key, fullfile(pth, file));
                    end
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
                case 'channels'
                    channels = {};
                    if isfield(app.RuntimeParseInfo, 'channels')
                        channels = app.RuntimeParseInfo.channels;
                    end
                    if isempty(channels)
                        current = getRuntimeValue(app, key);
                        answer = inputdlg('Channels to use (comma-separated names, or leave empty until data are loaded):', 'Set channels', 1, {current});
                        if isempty(answer)
                            return;
                        end
                        setRuntimeValue(app, key, strtrim(answer{1}));
                        return;
                    end
                    items = [{'all'}, cellstr(string(channels(:)'))];
                    current = getRuntimeValue(app, key);
                    idx = find(strcmp(items, current), 1);
                    if isempty(idx), idx = 1; end
                    [sel, ok] = listdlg('PromptString', 'Select source channel:', ...
                        'SelectionMode', 'single', 'ListString', items, 'InitialValue', idx);
                    if ok && ~isempty(sel)
                        setRuntimeValue(app, key, items{sel(1)});
                    end
                case 'outputPolicy'
                    showOutputPolicyHelp(app);
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
                    'Message', 'Parsing raw data metadata...', 'Indeterminate', 'on');
            catch
            end
            try
                out = parseInputData(rawDataPath);
                info = summarizeParsedRawData(app, out, rawDataPath);
                app.RuntimeParseInfo = info;
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
        end

        function updateChannelDropdownItems(app, channels)
            if ~isfield(app.RuntimeFieldHandles, 'channels') || ~isvalid(app.RuntimeFieldHandles.channels)
                return;
            end
            dd = app.RuntimeFieldHandles.channels;
            try
                if isempty(channels)
                    dd.Items = {'resolved after project/raw data load'};
                    dd.Value = dd.Items{1};
                    app.RuntimeValues.channels = '';
                    return;
                end
                items = [{'all'}, cellstr(string(channels(:)'))];
                items = unique(items(~cellfun(@isempty, items)), 'stable');
                dd.Items = items;
                cur = getRuntimeValue(app, 'channels');
                if isempty(cur) || ~any(strcmp(items, cur)) || startsWith(cur, 'resolved after')
                    cur = 'all';
                end
                dd.Value = cur;
                app.RuntimeValues.channels = cur;
                dd.Tooltip = ['Detected channels: ' strjoin(items(2:end), ', ')];
            catch
            end
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

            staticData = paramsToTableData(app, node, 'static');
            runtimeData = paramsToTableData(app, node, 'runtime');
            showStatic = ~isempty(staticData);
            showRuntime = ~isempty(runtimeData);

            if ~showStatic && ~showRuntime
                grid = uigridlayout(parentTab, [1 1]);
                grid.Padding = [12 10 12 12];
                uilabel(grid, 'Text', 'No module-specific parameters for this module.', ...
                    'FontAngle', 'italic', 'FontColor', [0.35 0.35 0.35]);
                return;
            end

            colCount = double(showStatic) + double(showRuntime);
            grid = uigridlayout(parentTab, [2 colCount]);
            grid.RowHeight = {24, '1x'};
            grid.ColumnWidth = repmat({'1x'}, 1, colCount);
            grid.Padding = [12 10 12 12];
            grid.ColumnSpacing = 16;

            col = 1;
            if showStatic
                leftLabel = uilabel(grid, 'Text', 'Static parameters');
                leftLabel.FontWeight = 'bold';
                leftLabel.Layout.Row = 1;
                leftLabel.Layout.Column = col;

                section = buildParamSection(app, grid, staticData, node, true);
                section.Layout.Row = 2;
                section.Layout.Column = col;
                col = col + 1;
            end

            if showRuntime
                rightLabel = uilabel(grid, 'Text', 'Runtime parameters');
                rightLabel.FontWeight = 'bold';
                rightLabel.Layout.Row = 1;
                rightLabel.Layout.Column = col;

                section = buildParamSection(app, grid, runtimeData, node, app.Data.runMode);
                section.Layout.Row = 2;
                section.Layout.Column = col;
            end
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
            if ~isempty(choices)
                ctrl = uidropdown(parent);
                ctrl.Items = choices;
                displayValue = paramValueToDisplay(app, node, key, value);
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
            elseif isfield(app.RuntimeFieldHandles, 'channels') && isvalid(app.RuntimeFieldHandles.channels) && isa(app.RuntimeFieldHandles.channels, 'matlab.ui.control.DropDown')
                items = app.RuntimeFieldHandles.channels.Items;
                items = items(~startsWith(string(items), 'resolved after'));
                choices = [choices cellstr(string(items(:)'))]; %#ok<AGROW>
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
                        keys = {'outputName'};
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

        function keys = processorStaticKeys(app, pkg) %#ok<INUSD>
            switch pkg
                case 'combinemultiplechannels'
                    keys = {'outputChannelName','requiredChannelCount'};
                case 'computemetrics'
                    keys = {'mask1_name','mask1_class','mask1_label','mask1_stat','channel1_name','channel2_name','channel3_name','channel4_name','BrightestPixels'};
                otherwise
                    keys = {'outputName'};
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
                        keys = {'mask1_name','channel1_name','channel2_name','channel3_name','channel4_name','BrightestPixels','outputName'};
                    else
                        keys = {'channels','channel','frames','outputName'};
                    end
                case 'classifier'
                    keys = {'channel','channels','frames','outputName','pkg'};
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
            out = valueToDisplay(app, value);
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

        function refreshValidationReport(app)
            pipe = buildPipelineStruct(app);
            ctx = struct('allowGUI', false);
            if isempty(pipe.nodes)
                app.RuninformationhereLabel.Text = 'Template mode - no module yet.';
                app.PipelineandRuncheckreportLabel.Text = 'Click the grey block to add the first module.';
                return;
            end

            try
                [ok, report] = validatePipeline(pipe, ctx, struct('allowGui', false));
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
            ctx = struct('allowGUI', false);
            if isempty(pipe.nodes)
                ok = false;
                report = struct('errors', {{'No module in pipeline.'}}, 'warnings', {{}}, 'solver', struct());
                refreshValidationReport(app);
                return;
            end
            try
                [ok, report] = validatePipeline(pipe, ctx, struct('allowGui', false));
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
                '- Resume: ' resumeLabel newline ...
                '- Existing outputs: ' policyLabel roiExtractMode];
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
            end
            txt = strjoin(lines, newline);
        end

        function pipe = buildPipelineStruct(app)
            pipe = struct();
            pipe.name = 'pipelineGUI2';
            pipe.nodes = app.Data.nodes;
            pipe.nodes = applyRuntimeDerivedNodePolicies(app, pipe.nodes);
            pipe.edges = app.Data.edges;
            pipe.branches = struct([]);
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

        function NewpipelineMenuSelected(app, event) %#ok<INUSD>
            app.Data.nodes = struct([]);
            app.Data.edges = struct('from',{},'to',{},'fromPort',{},'toPort',{},'condition',{});
            app.SelectedNodeIndex = NaN;
            app.NodeCounter = 0;
            app.RuntimeNodeParams = struct();
            app.RoiManualSelectedRectangle = NaN;
            clearRoiManualPreviewHandles(app);
            refreshAfterModelChange(app);
        end

        function SavecurrentpipelineMenuSelected(app, event) %#ok<INUSD>
            uialert(app.UIFigure, 'Template save will be implemented after the parameter tabs are stable.', 'Save pipeline', 'Icon', 'info');
        end

        function RunButtonPushed(app, event) %#ok<INUSD>
            refreshValidationReport(app);
            uialert(app.UIFigure, 'Brick 1 validates the template only. Dry-run and local run come next.', 'Run', 'Icon', 'info');
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
            app.UIFigure.Position = [100 100 1011 943];
            app.UIFigure.Name = 'MATLAB App';

            % Create FileMenu
            app.FileMenu = uimenu(app.UIFigure);
            app.FileMenu.Text = 'File';

            % Create NewpipelineMenu
            app.NewpipelineMenu = uimenu(app.FileMenu);
            app.NewpipelineMenu.Text = 'New pipeline';

            % Create SavecurrentpipelineMenu
            app.SavecurrentpipelineMenu = uimenu(app.FileMenu);
            app.SavecurrentpipelineMenu.Text = 'Save current pipeline';

            % Create SavepipelineasMenu
            app.SavepipelineasMenu = uimenu(app.FileMenu);
            app.SavepipelineasMenu.Text = 'Save pipeline as...';

            % Create SaverunMenu
            app.SaverunMenu = uimenu(app.FileMenu);
            app.SaverunMenu.Separator = 'on';
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
            app.GraphPanel.Position = [272 621 726 304];

            % Create UIGraphAxes
            app.UIGraphAxes = uiaxes(app.GraphPanel);
            title(app.UIGraphAxes, 'Title')
            xlabel(app.UIGraphAxes, 'X')
            ylabel(app.UIGraphAxes, 'Y')
            zlabel(app.UIGraphAxes, 'Z')
            app.UIGraphAxes.Position = [15 9 694 265];

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

            % Create UIWorkspacePipelineTable
            app.UIWorkspacePipelineTable = uitable(app.BuildPanel);
            app.UIWorkspacePipelineTable.ColumnName = {'Column 1'; 'Column 2'; 'Column 3'; 'Column 4'};
            app.UIWorkspacePipelineTable.RowName = {};
            app.UIWorkspacePipelineTable.Position = [17 9 218 134];

            % Create ParametersPanel
            app.ParametersPanel = uipanel(app.UIFigure);
            app.ParametersPanel.Title = 'Parameters';
            app.ParametersPanel.Position = [13 14 985 592];

            % Create TabGroup
            app.TabGroup = uitabgroup(app.ParametersPanel);
            app.TabGroup.Position = [18 51 700 459];

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
            app.IdEditFieldLabel.Position = [213 535 16 22];
            app.IdEditFieldLabel.Text = 'Id';

            % Create IdEditField
            app.IdEditField = uieditfield(app.ParametersPanel, 'text');
            app.IdEditField.Position = [244 535 154 22];

            % Create AdvancedmodeCheckBox
            app.AdvancedmodeCheckBox = uicheckbox(app.ParametersPanel);
            app.AdvancedmodeCheckBox.Text = 'Advanced mode';
            app.AdvancedmodeCheckBox.Position = [421 535 109 22];

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
            app.RuninformationhereLabel.Position = [214 510 470 22];
            app.RuninformationhereLabel.Text = 'Run information here';

            % Create PipelineandRuncheckreportLabel
            app.PipelineandRuncheckreportLabel = uilabel(app.ParametersPanel);
            app.PipelineandRuncheckreportLabel.Position = [742 25 226 479];
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
