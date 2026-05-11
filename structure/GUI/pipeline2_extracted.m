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
        CloseappButton                  matlab.ui.control.Button
        PipelineandRuncheckreportLabel  matlab.ui.control.Label
        RuninformationhereLabel         matlab.ui.control.Label
        TabGroup                        matlab.ui.container.TabGroup
        Module1Tab                      matlab.ui.container.Tab
        SubtypeDropDown                 matlab.ui.control.DropDown
        SubtypeDropDownLabel            matlab.ui.control.Label
        AdvancedmodeCheckBox            matlab.ui.control.CheckBox
        NameEditField                   matlab.ui.control.EditField
        NameEditFieldLabel              matlab.ui.control.Label
        TypeDropDown                    matlab.ui.control.DropDown
        TypeDropDownLabel               matlab.ui.control.Label
        RuntimeparametersLabel          matlab.ui.control.Label
        StaticparametersLabel           matlab.ui.control.Label
        Module2Tab                      matlab.ui.container.Tab
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

            app.ForkgraphButton.ButtonPushedFcn = createCallbackFcn(app, @ForkgraphButtonPushed, true);
            app.MergegraphButton.ButtonPushedFcn = createCallbackFcn(app, @MergegraphButtonPushed, true);
            app.CloseappButton.ButtonPushedFcn = createCallbackFcn(app, @CloseappButtonPushed, true);
            app.RunButton.ButtonPushedFcn = createCallbackFcn(app, @RunButtonPushed, true);
            app.NewpipelineMenu.MenuSelectedFcn = createCallbackFcn(app, @NewpipelineMenuSelected, true);
            app.SavecurrentpipelineMenu.MenuSelectedFcn = createCallbackFcn(app, @SavecurrentpipelineMenuSelected, true);

            app.RuninformationhereLabel.Text = 'Template mode - click the grey block to add a module.';
            app.PipelineandRuncheckreportLabel.Text = 'No pipeline yet.';

            app.ModuleContextMenu = uicontextmenu(app.UIFigure);
            uimenu(app.ModuleContextMenu, 'Text', 'Delete module', ...
                'MenuSelectedFcn', @(~,~)deleteSelectedModule(app));

            app.NameEditField.ValueChangedFcn = createCallbackFcn(app, @NameEditFieldValueChanged, true);
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
                data{i,2} = char(string(getField(app, nodes(i), 'name', getField(app, nodes(i), 'id', ''))));
                data{i,3} = char(string(getField(app, nodes(i), 'type', '')));
                data{i,4} = char(string(getField(app, nodes(i), 'pkg', '')));
            end
            app.UISelectedModuleTable.Data = data;
        end

        function NameEditFieldValueChanged(app, event) %#ok<INUSD>
            if isnan(app.SelectedNodeIndex) || app.SelectedNodeIndex < 1 || app.SelectedNodeIndex > numel(app.Data.nodes)
                return;
            end
            newName = strtrim(char(string(app.NameEditField.Value)));
            if isempty(newName)
                newName = char(string(app.Data.nodes(app.SelectedNodeIndex).id));
                app.NameEditField.Value = newName;
            end
            app.Data.nodes(app.SelectedNodeIndex).name = newName;
            refreshAfterModelChange(app);
        end

        function TypeDropDownValueChanged(app, event) %#ok<INUSD>
            updateSubtypeChoices(app);
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
            node.params = defaultNodeParams(app, nodeType, pkg);
            node.enabled = true;
            node.status = '';
            node.layout = [1 1 1 1];
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
                    char(string(getField(app, nodes(i), 'name', 'module'))), ...
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
            app.NameEditField.Value = char(string(getField(app, node, 'name', '')));
            selectTypeControlsForNode(app, node);
            redrawGraph(app);
            refreshModuleTabs(app);
            refreshValidationReport(app);
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
            redrawGraph(app);
            refreshModuleTabs(app);
            refreshValidationReport(app);
        end

        function refreshModuleTabs(app)
            deleteDynamicModuleTabs(app);
            nodes = app.Data.nodes;
            for i = 1:numel(nodes)
                node = nodes(i);
                tabTitle = char(string(getField(app, node, 'name', getField(app, node, 'id', 'module'))));
                if numel(tabTitle) > 18
                    tabTitle = [tabTitle(1:15) '...'];
                end
                t = uitab(app.TabGroup, 'Title', tabTitle);
                t.UserData = struct('nodeId', char(string(node.id)), 'dynamic', true);
                app.DynamicModuleTabs(end+1) = t; %#ok<AGROW>
                buildModuleTab(app, t, node);
            end
            if ~isnan(app.SelectedNodeIndex) && app.SelectedNodeIndex >= 1 && app.SelectedNodeIndex <= numel(app.DynamicModuleTabs)
                app.TabGroup.SelectedTab = app.DynamicModuleTabs(app.SelectedNodeIndex);
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
            grid = uigridlayout(parentTab, [2 2]);
            grid.RowHeight = {24, '1x'};
            grid.ColumnWidth = {'1x', '1x'};
            grid.Padding = [12 10 12 12];
            grid.ColumnSpacing = 16;

            leftLabel = uilabel(grid, 'Text', 'Static parameters');
            leftLabel.FontWeight = 'bold';
            leftLabel.Layout.Row = 1;
            leftLabel.Layout.Column = 1;

            rightLabel = uilabel(grid, 'Text', 'Runtime parameters');
            rightLabel.FontWeight = 'bold';
            rightLabel.Layout.Row = 1;
            rightLabel.Layout.Column = 2;

            staticTable = uitable(grid);
            staticTable.Layout.Row = 2;
            staticTable.Layout.Column = 1;
            staticTable.ColumnName = {'Parameter','Value'};
            staticTable.ColumnEditable = [false true];
            staticTable.RowName = {};
            staticTable.Data = paramsToTableData(app, node, 'static');

            runTable = uitable(grid);
            runTable.Layout.Row = 2;
            runTable.Layout.Column = 2;
            runTable.ColumnName = {'Parameter','Value'};
            runTable.ColumnEditable = [false app.Data.runMode];
            runTable.RowName = {};
            runTable.Enable = ternary(app, app.Data.runMode, 'on', 'off');
            runTable.Data = paramsToTableData(app, node, 'runtime');
        end

        function data = paramsToTableData(app, node, scope)
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
            keys = unique(keys(~cellfun(@isempty, keys)), 'stable');
            p = getField(app, node, 'params', struct());
            data = cell(numel(keys), 2);
            for i = 1:numel(keys)
                data{i,1} = keys{i};
                if isstruct(p) && isfield(p, keys{i})
                    data{i,2} = valueToDisplay(app, p.(keys{i}));
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
            app.PipelineandRuncheckreportLabel.Text = formatValidationReport(app, ok, report);
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
            pipe.edges = app.Data.edges;
            pipe.branches = struct([]);
        end

        function NewpipelineMenuSelected(app, event) %#ok<INUSD>
            app.Data.nodes = struct([]);
            app.Data.edges = struct('from',{},'to',{},'fromPort',{},'toPort',{},'condition',{});
            app.SelectedNodeIndex = NaN;
            app.NodeCounter = 0;
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
            app.Data.nodes(app.SelectedNodeIndex) = [];
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

            % Create Module1Tab
            app.Module1Tab = uitab(app.TabGroup);
            app.Module1Tab.Title = 'Module1';

            % Create StaticparametersLabel
            app.StaticparametersLabel = uilabel(app.Module1Tab);
            app.StaticparametersLabel.Position = [20 340 99 22];
            app.StaticparametersLabel.Text = 'Static parameters';

            % Create RuntimeparametersLabel
            app.RuntimeparametersLabel = uilabel(app.Module1Tab);
            app.RuntimeparametersLabel.Position = [344 340 114 22];
            app.RuntimeparametersLabel.Text = 'Runtime parameters';

            % Create TypeDropDownLabel
            app.TypeDropDownLabel = uilabel(app.Module1Tab);
            app.TypeDropDownLabel.HorizontalAlignment = 'right';
            app.TypeDropDownLabel.Position = [44 405 31 22];
            app.TypeDropDownLabel.Text = 'Type';

            % Create TypeDropDown
            app.TypeDropDown = uidropdown(app.Module1Tab);
            app.TypeDropDown.Position = [90 405 100 22];

            % Create NameEditFieldLabel
            app.NameEditFieldLabel = uilabel(app.Module1Tab);
            app.NameEditFieldLabel.HorizontalAlignment = 'right';
            app.NameEditFieldLabel.Position = [227 406 37 22];
            app.NameEditFieldLabel.Text = 'Name';

            % Create NameEditField
            app.NameEditField = uieditfield(app.Module1Tab, 'text');
            app.NameEditField.Position = [279 406 138 22];

            % Create AdvancedmodeCheckBox
            app.AdvancedmodeCheckBox = uicheckbox(app.Module1Tab);
            app.AdvancedmodeCheckBox.Text = 'Advanced mode';
            app.AdvancedmodeCheckBox.Position = [473 405 109 22];

            % Create SubtypeDropDownLabel
            app.SubtypeDropDownLabel = uilabel(app.Module1Tab);
            app.SubtypeDropDownLabel.HorizontalAlignment = 'right';
            app.SubtypeDropDownLabel.Position = [22 375 52 22];
            app.SubtypeDropDownLabel.Text = 'Sub type';

            % Create SubtypeDropDown
            app.SubtypeDropDown = uidropdown(app.Module1Tab);
            app.SubtypeDropDown.Position = [89 375 100 22];

            % Create Module2Tab
            app.Module2Tab = uitab(app.TabGroup);
            app.Module2Tab.Title = 'Module2';

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
            app.RuninformationhereLabel.Position = [18 535 117 22];
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
            app.RunButton.Position = [136 11 100 23];
            app.RunButton.Text = 'Run !';

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
