classdef pipelineGUI < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                      matlab.ui.Figure
        FileMenu                      matlab.ui.container.Menu
        NewpipelineMenu               matlab.ui.container.Menu
        SavepipelineMenu              matlab.ui.container.Menu
        SavepipelineasMenu            matlab.ui.container.Menu
        ExportpipelineMenu            matlab.ui.container.Menu
        RevealpipelineinexplorerMenu  matlab.ui.container.Menu
        OpenpipelineJSONfileMenu      matlab.ui.container.Menu
        RunMenu                       matlab.ui.container.Menu
        CheckpipelineMenu             matlab.ui.container.Menu
        CreaterunMenu                 matlab.ui.container.Menu
        UITable                       matlab.ui.control.Table
        PipelinesketchLabel           matlab.ui.control.Label
        ModulesinworkspaceLabel       matlab.ui.control.Label
        ButtonMoveToCanva             matlab.ui.control.Button
        UIModuleParametersTable       matlab.ui.control.Table
        CheckpipelineButton           matlab.ui.control.Button
        CreaterunButton               matlab.ui.control.Button
        CloseButton                   matlab.ui.control.Button
        UIModuleListTable             matlab.ui.control.Table
        UIModulesAxes                 matlab.ui.control.UIAxes
    end

    properties (Access = private)
        Data struct = struct('nodes',[],'edges',[])
        ModuleHandles = gobjects(0)
        ModuleTextHandles = gobjects(0)
        ModuleBadgeHandles = gobjects(0)
        ModuleMarkers = gobjects(0)
        LibraryHandles = gobjects(0)
        LibraryTextHandles = gobjects(0)
        LibraryBadgeHandles = gobjects(0)
        EdgeHandles = gobjects(0)
        EdgeLabelHandles = gobjects(0)
        InPortHandles cell = {}
        OutPortHandles cell = {}
        InPortLabelHandles cell = {}
        OutPortLabelHandles cell = {}
        SelectedPorts struct = struct('moduleIdx',{},'isOut',{},'portName',{})
        SelectedModules double = []
        PendingAddModule logical = false
        PendingTemplate struct = struct()
        DraggingModule double = NaN
        DragOffset double = [0 0]
        ModuleIdCounter double = 0
        CanvasContextPoint double = [32 12]
        LibraryEntries struct = struct('name',{},'type',{},'pkg',{},'source',{},'node',{},'signature',{}, ...
            'refPath',{},'refId',{},'refKind',{},'isOffline',{})
        SelectedLibraryRow double = NaN
        Context struct = struct()
        Dirty logical = false
    end

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app, shallowObj, pipeObj)
            if nargin >= 2 && ~isempty(shallowObj)
                app.Context.shallow = shallowObj;
                app.Context.shallowObj = shallowObj;
            end
            if nargin >= 3 && ~isempty(pipeObj)
                if isa(pipeObj, 'pipeline')
                    app.Context.pipeObj = pipeObj;
                end
                [nodes, edges] = unpackPipeline(app, pipeObj);
                app.Data.nodes = nodes;
                app.Data.edges = edges;
            end

            app.ModuleIdCounter = numel(app.Data.nodes);

            initAxes(app);
            initMenus(app);
            initTables(app);
            initButtons(app);
            app.Dirty = false;
            refreshAppTitle(app);
            redrawAll(app);
        end

        % Button pushed function: AddmoduleButton
        function AddmoduleButtonPushed(app, event)
            app.PendingAddModule = true;
            app.PendingTemplate = getTemplateByDisplay(app, app.ModuletypeDropDown.Value);
        end

        % Selection changed function: UIModuleLibraryTable
        function UIModuleLibraryTableSelectionChanged(app, event)
            sel = app.UIModuleLibraryTable.Selection;
            if isempty(sel)
                app.SelectedLibraryRow = NaN;
                return;
            end
            app.SelectedLibraryRow = sel(1,1);
        end

        % Button pushed function: DuplicatefromlibraryButton
        function DuplicatefromlibraryButtonPushed(app, event)
            duplicateSelectedLibraryModule(app);
        end

        % Button pushed function: RefreshlibraryButton
        function RefreshlibraryButtonPushed(app, event)
            updateModuleLibraryTable(app);
        end

        function LinkselectednodefromlibraryMenuSelected(app, event)
            linkSelectedNodeFromLibrary(app);
        end

        function SaveselectednodetolibraryMenuSelected(app, event)
            saveSelectedNodeToOfflineLibrary(app);
        end

        function UnlinkselectednodeMenuSelected(app, event)
            unlinkSelectedNodeReference(app);
        end

        % Button pushed function: ConnectDisconnectmodulesButton
        function ConnectDisconnectmodulesButtonPushed(app, event)
            if numel(app.SelectedPorts) == 2
                connectDisconnectFromSelectedPorts(app);
                return;
            end

            if numel(app.SelectedModules) ~= 2
                uialert(app.UIFigure, 'Select 2 modules, or click 2 ports, before connecting.', 'Info');
                return;
            end

            a = app.SelectedModules(1);
            b = app.SelectedModules(2);
            if a == b
                return;
            end

            fromId = char(string(app.Data.nodes(a).id));
            toId = char(string(app.Data.nodes(b).id));
            pairEdges = [findEdgesBetween(app, fromId, toId), findEdgesBetween(app, toId, fromId)];
            pairEdges = unique(pairEdges, 'stable');

            if ~isempty(pairEdges)
                action = 'Connect new port pair';
                opts = {'Connect new port pair','Disconnect existing connection','Connect new port pair'};
                res = myDialog({'Action'}, {opts}, 'CallingApp', app.UIFigure, 'Title', 'Connection action');
                if isempty(res)
                    return;
                end
                action = char(string(res.Action{end}));

                if strcmp(action, 'Disconnect existing connection')
                    [ok, edgeIdx] = askDisconnectEdge(app, pairEdges);
                    if ok
                        app.Data.edges(edgeIdx) = [];
                        markDirty(app, true);
                        redrawEdges(app);
                        refreshStatus(app);
                    end
                    return;
                end
            end

            [ok, fromIdx, toIdx, fromPort, toPort, reason] = askConnectPorts(app, a, b);
            if ~ok
                if ~isempty(reason)
                    uialert(app.UIFigure, reason, 'Cannot connect', 'Icon','warning');
                end
                return;
            end

            fromId = char(string(app.Data.nodes(fromIdx).id));
            toId = char(string(app.Data.nodes(toIdx).id));
            e = struct('from',fromId,'to',toId,'fromPort',fromPort,'toPort',toPort,'condition','');
            if isempty(app.Data.edges)
                app.Data.edges = e;
            else
                app.Data.edges(end+1) = e;
            end

            autoHarmonizeConnection(app, fromId, toId, fromPort, toPort);

            markDirty(app, true);
            redrawEdges(app);
            refreshStatus(app);
        end

        % Button down function: UIModulesAxes
        function UIModulesAxesButtonDown(app, event)
            pt = app.UIModulesAxes.CurrentPoint;
            app.CanvasContextPoint = [pt(1,1) pt(1,2)];

            if strcmp(app.UIFigure.SelectionType, 'alt')
                return;
            end
            clearSelection(app);
        end

        function UILibraryAxesButtonDown(app, event)
            if strcmp(app.UIFigure.SelectionType, 'alt')
                return;
            end
            app.SelectedLibraryRow = NaN;
            updateLibrarySelectionStyle(app);
        end

        function UITableSelectionChanged(app, event)
            sel = app.UITable.Selection;
            if isempty(sel)
                app.SelectedLibraryRow = NaN;
            else
                app.SelectedLibraryRow = sel(1,1);
            end
            updateLibrarySelectionStyle(app);
        end

        % Selection changed function: UIModuleListTable
        function UIModuleListTableSelectionChanged(app, event)
            sel = app.UIModuleListTable.Selection;
            if isempty(sel)
                return;
            end
            row = sel(1,1);
            if row > numel(app.Data.nodes)
                return;
            end

            clearPortSelection(app);
            setSelection(app, row, false);
            updateParamsTable(app, row);
        end

        % Cell edit callback: UIModuleListTable
        function UIModuleListTableCellEdit(app, event)
            idx = event.Indices;
            if isempty(idx)
                return;
            end
            row = idx(1);
            col = idx(2);

            if row > numel(app.Data.nodes)
                return;
            end

            node = app.Data.nodes(row);
            val = event.NewData;

            switch col
                case 1
                    node.enabled = logical(val);
                case 2
                    node.name = char(string(val));
            end

            app.Data.nodes(row) = node;
            markDirty(app, true);
            redrawModule(app, row);
            updateModuleListTable(app);
            refreshStatus(app);
        end

        % Cell edit callback: UIModuleParametersTable
        function UIModuleParametersTableCellEdit(app, event)
            idx = event.Indices;
            if isempty(idx)
                return;
            end
            row = idx(1);
            col = idx(2);
            if col ~= 2
                return;
            end
            if isempty(app.SelectedModules)
                return;
            end

            modIdx = app.SelectedModules(1);
            if modIdx > numel(app.Data.nodes)
                return;
            end

            data = app.UIModuleParametersTable.Data;
            if isempty(data) || row > size(data,1)
                return;
            end

            key = char(string(data{row,1}));
            if isReadOnlyParamKey(app, key)
                updateParamsTable(app, modIdx);
                return;
            end
            rawVal = event.NewData;

            node = app.Data.nodes(modIdx);
            if ~isfield(node,'params') || isempty(node.params)
                node.params = struct();
            end

            oldVal = '';
            if isfield(node.params, key)
                oldVal = node.params.(key);
            end
            node.params.(key) = parseParamValueFromTable(app, rawVal, oldVal);
            app.Data.nodes(modIdx) = node;

            markDirty(app, true);
            updateParamsTable(app, modIdx);
            refreshStatus(app);
        end

        % Selection changed function: UIModuleParametersTable
        function UIModuleParametersTableSelectionChanged(app, event)
            selection = app.UIModuleParametersTable.Selection;
            if isempty(selection) || size(selection,1) ~= 1
                return;
            end
            if selection(1,2) ~= 2 || isempty(app.SelectedModules)
                return;
            end

            modIdx = app.SelectedModules(1);
            if modIdx < 1 || modIdx > numel(app.Data.nodes)
                return;
            end

            data = app.UIModuleParametersTable.Data;
            row = selection(1,1);
            if isempty(data) || row > size(data,1)
                return;
            end

            node = app.Data.nodes(modIdx);
            key = char(string(data{row,1}));
            if ~isChannelSelectorParam(app, node, key)
                return;
            end

            [newVal, applied] = chooseChannelSelectorForNode(app, node, key);
            if ~applied
                return;
            end

            if ~isfield(node,'params') || isempty(node.params)
                node.params = struct();
            end
            node.params.(key) = newVal;
            app.Data.nodes(modIdx) = node;

            markDirty(app, true);
            updateParamsTable(app, modIdx);
            refreshStatus(app);
        end

        % Button pushed function: RunpipelineButton
        function RunpipelineButtonPushed(app, event)
            CreaterunButtonPushed(app, event);
        end

        % Button pushed function: SavepipelineButton
        function SavepipelineButtonPushed(app, event)
            commitVisibleParamTable(app);
            try
                savePipelineFromGUI(app);
            catch ME
                uialert(app.UIFigure, ME.message, 'Save failed', 'Icon','error');
            end
        end

        % Button pushed function: CheckpipelineButton
        function CheckpipelineButtonPushed(app, event)
            refreshStatus(app, true);
        end

        % Button pushed function: OpenselectedmoduleButton
        function OpenselectedmoduleButtonPushed(app, event)
            if isempty(app.SelectedModules)
                return;
            end
            openModule(app, app.SelectedModules(1));
        end

        % Button pushed function: CreaterunButton
        function CreaterunButtonPushed(app, event)
            commitVisibleParamTable(app);
            pipe = buildPipelineStruct(app, true);
            shallowObj = [];
            if isfield(app.Context,'shallow') && ~isempty(app.Context.shallow)
                shallowObj = app.Context.shallow;
            elseif isfield(app.Context,'shallowObj') && ~isempty(app.Context.shallowObj)
                shallowObj = app.Context.shallowObj;
            end

            try
                if isempty(shallowObj)
                    feval('pipelineRunGUI', pipe);
                else
                    feval('pipelineRunGUI', pipe, shallowObj);
                end
            catch ME
                uialert(app.UIFigure, ME.message, 'Run GUI error', 'Icon','error');
            end
        end

        % Button pushed function: CloseButton
        function CloseButtonPushed(app, event)
            UIFigureCloseRequest(app, event);
        end

        function UIFigureCloseRequest(app, event) %#ok<INUSD>
            if ~confirmClosePipelineGUI(app)
                return;
            end
            try
                app.UIFigure.CloseRequestFcn = '';
            catch
            end
            delete(app);
        end

        function ButtonMoveToCanvaPushed(app, event)
            duplicateSelectedLibraryModule(app);
        end

        function NewpipelineMenuSelected(app, event)
            if ~confirmDiscardCurrentPipeline(app)
                return;
            end

            app.Data.nodes = struct([]);
            app.Data.edges = struct('from',{},'to',{},'fromPort',{},'toPort',{},'condition',{});
            app.ModuleIdCounter = 0;
            app.SelectedModules = [];
            app.SelectedPorts = struct('moduleIdx',{},'isOut',{},'portName',{});
            app.SelectedLibraryRow = NaN;
            app.Context.pipeObj = pipelineConstruct('', 'pipeline', 1);

            markDirty(app, true);
            refreshAppTitle(app);
            redrawAll(app);
            updateParamsTable(app, inf);
        end

        function SavepipelineMenuSelected(app, event)
            SavepipelineButtonPushed(app, event);
        end

        function SavepipelineasMenuSelected(app, event)
            try
                savePipelineFromGUI(app, true);
            catch ME
                uialert(app.UIFigure, ME.message, 'Save failed', 'Icon','error');
            end
        end

        function ExportpipelineMenuSelected(app, event)
            try
                exportPipelineFromGUI(app);
            catch ME
                uialert(app.UIFigure, ME.message, 'Export failed', 'Icon','error');
            end
        end

        function RevealpipelineinexplorerMenuSelected(app, event)
            pipeObj = getCurrentPipelineObject(app);
            if isempty(pipeObj) || isempty(pipeObj.path) || ~isfolder(pipeObj.path)
                uialert(app.UIFigure, 'Save the pipeline first to create its folder.', 'No saved pipeline', 'Icon','info');
                return;
            end
            try
                winopen(pipeObj.path);
            catch ME
                uialert(app.UIFigure, ME.message, 'Explorer error', 'Icon','warning');
            end
        end

        function OpenpipelineJSONfileMenuSelected(app, event)
            pipeObj = getCurrentPipelineObject(app);
            if isempty(pipeObj) || isempty(pipeObj.path)
                uialert(app.UIFigure, 'Save the pipeline first to create pipeline.json.', 'No saved pipeline', 'Icon','info');
                return;
            end

            jsonFile = fullfile(pipeObj.path, 'pipeline.json');
            if ~exist(jsonFile, 'file')
                uialert(app.UIFigure, sprintf('File not found:\n%s', jsonFile), 'Missing file', 'Icon','warning');
                return;
            end

            try
                winopen(jsonFile);
            catch ME
                uialert(app.UIFigure, ME.message, 'Open file error', 'Icon','warning');
            end
        end

        function CheckpipelineMenuSelected(app, event)
            CheckpipelineButtonPushed(app, event);
        end

        function CreaterunMenuSelected(app, event)
            CreaterunButtonPushed(app, event);
        end

        % Window motion for dragging
        function UIFigureWindowButtonMotion(app, event)
            if isnan(app.DraggingModule)
                return;
            end
            idx = app.DraggingModule;
            if idx > numel(app.Data.nodes)
                return;
            end

            pt = app.UIModulesAxes.CurrentPoint;
            x = pt(1,1) - app.DragOffset(1);
            y = pt(1,2) - app.DragOffset(2);

            node = app.Data.nodes(idx);
            node.layout(1) = x;
            node.layout(2) = y;
            app.Data.nodes(idx) = node;

            redrawModule(app, idx);
            redrawEdges(app);
        end

        % Window up to stop dragging
        function UIFigureWindowButtonUp(app, event)
            if ~isnan(app.DraggingModule)
                markDirty(app, true);
            end
            app.DraggingModule = NaN;
        end
    end

    % Internal helpers
    methods (Access = private)

        function initAxes(app)
            cla(app.UIModulesAxes);
            disableDefaultInteractivity(app.UIModulesAxes);
            app.UIModulesAxes.XLim = [0 100];
            app.UIModulesAxes.YLim = [0 100];
            app.UIModulesAxes.YDir = 'reverse';
            axis(app.UIModulesAxes, 'manual');
            hold(app.UIModulesAxes, 'on');
        end

        function initTables(app)
            app.UIModuleListTable.ColumnEditable = [true true false false false false];
            app.UIModuleListTable.ColumnFormat = { ...
                'logical', ...
                'char', ...
                'char', ...
                'char', ...
                'char', ...
                'char' ...
            };

            app.UIModuleParametersTable.ColumnEditable = [false true];
            app.UITable.ColumnEditable = [false false false false];
            app.UITable.ColumnName = {'Name'; 'Type'; 'Package'; 'Location'};
            app.UITable.SelectionChangedFcn = createCallbackFcn(app, @UITableSelectionChanged, true);
            updateModuleListTable(app);
            updateModuleLibraryTable(app);
        end

        function initButtons(app)
            app.ButtonMoveToCanva.ButtonPushedFcn = createCallbackFcn(app, @ButtonMoveToCanvaPushed, true);
            app.CreaterunButton.ButtonPushedFcn = createCallbackFcn(app, @CreaterunButtonPushed, true);
            app.CheckpipelineButton.ButtonPushedFcn = createCallbackFcn(app, @CheckpipelineButtonPushed, true);
            app.CloseButton.ButtonPushedFcn = createCallbackFcn(app, @CloseButtonPushed, true);
            app.UIFigure.WindowButtonMotionFcn = createCallbackFcn(app, @UIFigureWindowButtonMotion, true);
            app.UIFigure.WindowButtonUpFcn = createCallbackFcn(app, @UIFigureWindowButtonUp, true);
        end

        function initMenus(app)
            app.NewpipelineMenu.MenuSelectedFcn = createCallbackFcn(app, @NewpipelineMenuSelected, true);
            app.SavepipelineMenu.MenuSelectedFcn = createCallbackFcn(app, @SavepipelineMenuSelected, true);
            app.SavepipelineasMenu.MenuSelectedFcn = createCallbackFcn(app, @SavepipelineasMenuSelected, true);
            app.ExportpipelineMenu.MenuSelectedFcn = createCallbackFcn(app, @ExportpipelineMenuSelected, true);
            app.RevealpipelineinexplorerMenu.MenuSelectedFcn = createCallbackFcn(app, @RevealpipelineinexplorerMenuSelected, true);
            app.OpenpipelineJSONfileMenu.MenuSelectedFcn = createCallbackFcn(app, @OpenpipelineJSONfileMenuSelected, true);
            app.CheckpipelineMenu.MenuSelectedFcn = createCallbackFcn(app, @CheckpipelineMenuSelected, true);
            app.CreaterunMenu.MenuSelectedFcn = createCallbackFcn(app, @CreaterunMenuSelected, true);

            cm = uicontextmenu(app.UIFigure);
            reg = getModuleRegistry(app);
            for i = 1:numel(reg)
                mi = uimenu(cm, 'Text', ['Add ' char(string(reg(i).display))]);
                mi.UserData = char(string(reg(i).display));
                mi.MenuSelectedFcn = @(src,evt)addModuleFromCanvasContext(app, src.UserData);
            end
            app.UIModulesAxes.ContextMenu = cm;
        end

        function list = getModuleTypeDisplay(app)
            reg = getModuleRegistry(app);
            list = {reg.display};
        end

        function list = getModulePackageList(app)
            proc = getProcessorPackageList(app);
            clas = getClassifierPackageList(app);
            list = unique([proc(:)', clas(:)'], 'stable');
            list = list(~cellfun(@isempty, list));
            if isempty(list)
                list = {'<none>'};
            else
                list = [{'<none>'}, list];
            end
        end
        function names = getProcessorPackageList(app)
            names = listPlusPackages(app, 'processor');
        end
        function names = getClassifierPackageList(app)
            names = listPlusPackages(app, 'classification');
        end

        function names = listPlusPackages(app, kind) %#ok<INUSD>
            names = {};
            try
                here = fileparts(mfilename('fullpath'));
                repoRoot = fileparts(fileparts(here));
                root = fullfile(repoRoot, 'engine', kind);
                if ~isfolder(root)
                    return;
                end

                d = dir(fullfile(root, '+*'));
                d = d([d.isdir]);
                names = cell(1, numel(d));
                for i = 1:numel(d)
                    names{i} = erase(d(i).name, '+');
                end
                names = unique(names, 'stable');
            catch
                names = {};
            end
        end

        function row = getClasslistRowByName(app, name)
            row = [];
            try
                clFile = which('classlist.mat');
                if isempty(clFile)
                    classFile = which('classi.m');
                    if ~isempty(classFile)
                        repoRoot = fileparts(fileparts(fileparts(fileparts(classFile))));
                        clFile = fullfile(repoRoot, 'engine', 'classification', 'classlist.mat');
                    end
                end
                if ~exist(clFile,'file')
                    return;
                end
                S = load(clFile, 'classlist');
                classlist = S.classlist;
                if istable(classlist)
                    idx = find(strcmp(classlist.Name, name), 1);
                    if isempty(idx)
                        return;
                    end
                    row = classlist(idx,:);
                else
                    idx = find(strcmp(classlist(:,2), name), 1);
                    if isempty(idx)
                        return;
                    end
                    row = classlist(idx,:);
                end
            catch
                row = [];
            end
        end

        function fun = getClassifyFunFromRow(app, row)
            fun = '';
            try
                if istable(row)
                    if width(row) >= 6
                        fun = row{1,6};
                    end
                else
                    fun = row{1,6};
                end
                if iscell(fun)
                    fun = fun{1};
                end
                if isstring(fun)
                    fun = char(fun);
                end
            catch
                fun = '';
            end
        end

        function reg = getModuleRegistry(app)
            reg = struct('display',{},'type',{},'func',{},'gui',{}, ...
                'paramRequired',{},'inputs',{},'outputs',{},'defaultParams',{},'color',{});

            reg(1) = struct( ...
                'display','Dataloader', ...
                'type','dataLoader', ...
                'func','dataLoader.process', ...
                'gui','dataLoader.ui', ...
                'paramRequired',{{'path'}}, ...
                'inputs',{{}}, ...
                'outputs',{{'images'}}, ...
                'defaultParams',safeSetParam(app, 'dataLoader.setparam'), ...
                'color',[0.18 0.52 0.94]);

            reg(2) = struct( ...
                'display','ROI pattern', ...
                'type','roiPattern', ...
                'func','roiPattern.process', ...
                'gui','roiPattern.ui', ...
                'paramRequired',{{}}, ...
                'inputs',{{'images'}}, ...
                'outputs',{{'roiList'}}, ...
                'defaultParams',safeSetParam(app, 'roiPattern.setparam'), ...
                'color',[0.98 0.60 0.20]);

            reg(3) = struct( ...
                'display','ROI pattern (legacy)', ...
                'type','roiIdentify', ...
                'func','roiIdentify.process', ...
                'gui','roiIdentify.ui', ...
                'paramRequired',{{}}, ...
                'inputs',{{'images'}}, ...
                'outputs',{{'roiList'}}, ...
                'defaultParams',safeSetParam(app, 'roiIdentify.setparam'), ...
                'color',[0.98 0.60 0.20]);

            reg(4) = struct( ...
                'display','ROI manual', ...
                'type','roiManual', ...
                'func','roiManual.process', ...
                'gui','roiManual.ui', ...
                'paramRequired',{{}}, ...
                'inputs',{{'images'}}, ...
                'outputs',{{'roiList'}}, ...
                'defaultParams',safeSetParam(app, 'roiManual.setparam'), ...
                'color',[0.82 0.74 0.28]);

            reg(5) = struct( ...
                'display','ROI grid', ...
                'type','roiGrid', ...
                'func','roiGrid.process', ...
                'gui','roiGrid.ui', ...
                'paramRequired',{{}}, ...
                'inputs',{{'images'}}, ...
                'outputs',{{'roiList'}}, ...
                'defaultParams',safeSetParam(app, 'roiGrid.setparam'), ...
                'color',[0.15 0.72 0.72]);

            reg(6) = struct( ...
                'display','ROI tracked', ...
                'type','roiTracked', ...
                'func','roiTracked.process', ...
                'gui','roiTracked.ui', ...
                'paramRequired',{{}}, ...
                'inputs',{{'roiList','masks'}}, ...
                'outputs',{{'roiList'}}, ...
                'defaultParams',safeSetParam(app, 'roiTracked.setparam'), ...
                'color',[0.76 0.44 0.88]);

            reg(7) = struct( ...
                'display','ROI extraction', ...
                'type','roiExtract', ...
                'func','roiExtract.process', ...
                'gui','roiExtract.ui', ...
                'paramRequired',{{}}, ...
                'inputs',{{'roiList'}}, ...
                'outputs',{{'channels'}}, ...
                'defaultParams',safeSetParam(app, 'roiExtract.setparam'), ...
                'color',[0.10 0.68 0.38]);

            reg(8) = struct( ...
                'display','Processor', ...
                'type','processor', ...
                'func','', ...
                'gui','processDataGUI', ...
                'paramRequired',{{'pkg'}}, ...
                'inputs',{{'inputChannels'}}, ...
                'outputs',{{'dataSeries'}}, ...
                'defaultParams',struct('pkg',''), ...
                'color',[0.55 0.55 0.55]);

            reg(9) = struct( ...
                'display','Classifier', ...
                'type','classifier', ...
                'func','', ...
                'gui','classifierGUI', ...
                'paramRequired',{{'pkg'}}, ...
                'inputs',{{'inputChannels'}}, ...
                'outputs',{{'dataSeries'}}, ...
                'defaultParams',struct('pkg',''), ...
                'color',[0.40 0.40 0.70]);
        end

        function params = safeSetParam(app, funName)
            try
                params = feval(funName, struct());
            catch
                params = struct();
            end
        end

        function tpl = getTemplateByDisplay(app, displayName)
            reg = getModuleRegistry(app);
            idx = find(strcmpi({reg.display}, displayName), 1);
            if isempty(idx)
                tpl = reg(1);
            else
                tpl = reg(idx);
            end
        end

        function displayName = getDisplayFromType(app, typeName)
            reg = getModuleRegistry(app);
            idx = find(strcmpi({reg.type}, typeName), 1);
            if isempty(idx)
                displayName = typeName;
            else
                displayName = reg(idx).display;
            end
        end

        function addModuleAt(app, pos, tpl)
            if nargin < 3 || isempty(tpl) || ~isstruct(tpl) || isempty(fieldnames(tpl))
                tpl = app.PendingTemplate;
            end
            if isempty(fieldnames(tpl))
                reg = getModuleRegistry(app);
                tpl = reg(1);
            end

            app.ModuleIdCounter = app.ModuleIdCounter + 1;
            id = sprintf('%s_%d', lower(tpl.type), app.ModuleIdCounter);
            if ~isempty(app.Data.nodes)
                existing = {app.Data.nodes.id};
                while any(strcmp(existing, id))
                    app.ModuleIdCounter = app.ModuleIdCounter + 1;
                    id = sprintf('%s_%d', lower(tpl.type), app.ModuleIdCounter);
                end
            end

            node = struct();
            node.id = id;
            node.name = id;
            node.type = tpl.type;
            node.func = tpl.func;
            node.gui = tpl.gui;
            node.guiMode = 'replace';
            node.paramRequired = tpl.paramRequired;
            node.inputs = tpl.inputs;
            node.outputs = tpl.outputs;
            node.params = tpl.defaultParams;
            node.enabled = true;
            node.status = '';
            node.pkg = '';
            node.importMode = 'blank';
            node.layout = [pos(1) pos(2) 26 16];
            node.contract = makeNodeContract(app, node.type, node.pkg);
            [node.inputs, node.outputs] = ioFromContract(app, node.contract);
            node = normalizeLibraryNode(app, node);
            app.Data.nodes = normalizeNodeArray(app, app.Data.nodes);

            if isempty(app.Data.nodes)
                app.Data.nodes = node;
            else
                app.Data.nodes(end+1) = node;
            end

            markDirty(app, true);
            drawModule(app, numel(app.Data.nodes));
            updateModuleListTable(app);
            refreshStatus(app);
        end

        function drawModule(app, idx)
            node = app.Data.nodes(idx);
            layout = normalizeModuleLayout(app, node);
            node.layout = layout;
            app.Data.nodes(idx) = node;
            [x,y,w,h] = deal(node.layout(1), node.layout(2), node.layout(3), node.layout(4));
            pts = [x y; x+w y; x+w y+h; x y+h];

            hPatch = patch(app.UIModulesAxes, pts(:,1), pts(:,2), [1 1 1], ...
                'EdgeColor','k','LineWidth',0.5,'ButtonDownFcn',@app.modulePatchButtonDown, ...
                'PickableParts','all');
            hPatch.UserData = idx;

            hText = text(app.UIModulesAxes, x+1.2, y+2.0, buildNodeCaption(app,node), ...
                'VerticalAlignment','middle', 'HorizontalAlignment','left', ...
                'FontSize',12, 'FontWeight','bold', 'Interpreter','none', ...
                'ButtonDownFcn',@app.modulePatchButtonDown, ...
                'PickableParts','all');
            hText.UserData = idx;
            hBadge = text(app.UIModulesAxes, x+1.2, y+4.4, buildNodeBadge(app,node), ...
                'HorizontalAlignment','left', ...
                'VerticalAlignment','middle', ...
                'FontSize',9, ...
                'Interpreter','tex', ...
                'Color',[0.25 0.25 0.25], ...
                'ButtonDownFcn',@app.modulePatchButtonDown, ...
                'PickableParts','all');
            hBadge.UserData = idx;

            hMarker = plot(app.UIModulesAxes, [x+1.0 x+w-1.0], [y+6.0 y+6.0], '-', ...
                'Color',[0.85 0.85 0.85], 'LineWidth',1.0, 'HitTest','off');

            if idx > numel(app.ModuleHandles)
                app.ModuleHandles(idx) = hPatch;
                app.ModuleTextHandles(idx) = hText;
                app.ModuleBadgeHandles(idx) = hBadge;
                app.ModuleMarkers(idx) = hMarker;
            else
                app.ModuleHandles(idx) = hPatch;
                app.ModuleTextHandles(idx) = hText;
                app.ModuleBadgeHandles(idx) = hBadge;
                app.ModuleMarkers(idx) = hMarker;
            end

            cm = uicontextmenu(app.UIFigure);
            miOpen = uimenu(cm,'Text','Open module');
            miOpen.UserData = idx;
            miOpen.MenuSelectedFcn = @(src,evt)openModule(app, src.UserData);
            miDuplicate = uimenu(cm,'Text','Duplicate module');
            miDuplicate.UserData = idx;
            miDuplicate.MenuSelectedFcn = @(src,evt)duplicateModule(app, src.UserData);
            miExport = uimenu(cm,'Text','Export module...');
            miExport.UserData = idx;
            miExport.MenuSelectedFcn = @(src,evt)exportModuleBundle(app, src.UserData);
            miLocal = uimenu(cm,'Text','Convert to local copy');
            miLocal.UserData = idx;
            miLocal.MenuSelectedFcn = @(src,evt)convertNodeToLocalCopy(app, src.UserData);
            miDelete = uimenu(cm,'Text','Delete module');
            miDelete.UserData = idx;
            miDelete.MenuSelectedFcn = @(src,evt)deleteModule(app, src.UserData, true);
            hPatch.ContextMenu = cm;
            hText.ContextMenu = cm;
            hBadge.ContextMenu = cm;

            drawPortsForModule(app, idx);
            redrawModule(app, idx);
            redrawEdges(app);
        end

        function redrawModule(app, idx)
            if idx > numel(app.Data.nodes) || idx > numel(app.ModuleHandles)
                return;
            end
            node = app.Data.nodes(idx);
            layout = normalizeModuleLayout(app, node);
            node.layout = layout;
            app.Data.nodes(idx) = node;
            hPatch = app.ModuleHandles(idx);
            hText = app.ModuleTextHandles(idx);
            hBadge = app.ModuleBadgeHandles(idx);
            hMarker = app.ModuleMarkers(idx);
            if isempty(hPatch) || ~isvalid(hPatch)
                return;
            end

            [x,y,w,h] = deal(node.layout(1), node.layout(2), node.layout(3), node.layout(4));
            pts = [x y; x+w y; x+w y+h; x y+h];
            hPatch.XData = pts(:,1);
            hPatch.YData = pts(:,2);
            hPatch.FaceColor = [1 1 1];
            hPatch.UserData = idx;

            hText.Position = [x+1.2 y+2.0 0];
            hText.String = buildNodeCaption(app,node);
            hText.UserData = idx;
            if ~isempty(hBadge) && isvalid(hBadge)
                badgeTxt = buildNodeBadge(app,node);
                hBadge.Position = [x+1.2 y+4.4 0];
                hBadge.String = badgeTxt;
                hBadge.UserData = idx;
                if isempty(badgeTxt)
                    hBadge.Visible = 'off';
                else
                    hBadge.Visible = 'on';
                end
            end

            if ~isempty(hMarker) && isvalid(hMarker)
                hMarker.Visible = 'on';
                hMarker.XData = [x+1.0 x+w-1.0];
                hMarker.YData = [y+6.0 y+6.0];
            end

            applyModuleOutlineStyle(app, idx);
            drawPortsForModule(app, idx);
            updateSelectionStyle(app);
        end

        function cap = buildNodeCaption(app, node)
            cap = char(string(node.name));
        end

        function badge = buildNodeBadge(app, node)
            typeLabel = getDisplayFromType(app, getfielddefault(app, node, 'type', ''));
            pkg = char(string(getfielddefault(app, node, 'pkg', '')));
            typeLabel = strrep(char(string(typeLabel)), '_', '\_');
            pkg = strrep(pkg, '_', '\_');
            if isempty(pkg)
                badge = ['\it ' char(string(typeLabel))];
            else
                badge = ['\it ' char(string(typeLabel)) ' - ' pkg];
            end
            if nodeHasReference(app, node)
                badge = [badge '   \bf[ref]'];
            end
        end

        function drawPortsForModule(app, idx)
            if idx > numel(app.Data.nodes)
                return;
            end

            clearPortGraphicsForModule(app, idx);

            node = app.Data.nodes(idx);
            c = getNodeContract(app, node);

            inH = gobjects(0);
            inL = gobjects(0);
            for k = 1:numel(c.in)
                pname = c.in(k).name;
                [x,y] = edgeAnchor(app, node, false, pname);
                meta = struct('moduleIdx',idx,'isOut',false,'portName',char(string(pname)));
                portColor = getPortDisplayColor(app, idx, false, pname);
                h = plot(app.UIModulesAxes, x, y, 'o', ...
                    'MarkerSize',9, ...
                    'MarkerEdgeColor',portColor, ...
                    'MarkerFaceColor',[1 1 1], ...
                    'LineWidth',1.6, ...
                    'ButtonDownFcn',@app.portButtonDown);
                h.UserData = meta;

                ht = text(app.UIModulesAxes, x+2.0, y, buildPortDisplayText(app, node, false, pname), ...
                    'HorizontalAlignment','left', ...
                    'VerticalAlignment','middle', ...
                    'FontSize',10, ...
                    'FontAngle','italic', ...
                    'Color',[0.08 0.08 0.08], ...
                    'Interpreter','none', ...
                    'ButtonDownFcn',@app.portButtonDown);
                ht.UserData = meta;

                cm = uicontextmenu(app.UIFigure);
                mi = uimenu(cm,'Text','Disconnect links on this input');
                mi.UserData = meta;
                mi.MenuSelectedFcn = @(s,e)disconnectEdgesForPort(app,s.UserData);
                h.ContextMenu = cm;
                ht.ContextMenu = cm;

                inH(end+1) = h; %#ok<AGROW>
                inL(end+1) = ht; %#ok<AGROW>
            end

            outH = gobjects(0);
            outL = gobjects(0);
            for k = 1:numel(c.out)
                pname = c.out(k).name;
                [x,y] = edgeAnchor(app, node, true, pname);
                meta = struct('moduleIdx',idx,'isOut',true,'portName',char(string(pname)));
                portColor = getPortDisplayColor(app, idx, true, pname);
                h = plot(app.UIModulesAxes, x, y, 'o', ...
                    'MarkerSize',9, ...
                    'MarkerEdgeColor',portColor, ...
                    'MarkerFaceColor',[1 1 1], ...
                    'LineWidth',1.6, ...
                    'ButtonDownFcn',@app.portButtonDown);
                h.UserData = meta;

                ht = text(app.UIModulesAxes, x-2.0, y, buildPortDisplayText(app, node, true, pname), ...
                    'HorizontalAlignment','right', ...
                    'VerticalAlignment','middle', ...
                    'FontSize',10, ...
                    'FontAngle','italic', ...
                    'Color',[0.08 0.08 0.08], ...
                    'Interpreter','none', ...
                    'ButtonDownFcn',@app.portButtonDown);
                ht.UserData = meta;

                cm = uicontextmenu(app.UIFigure);
                mo = uimenu(cm,'Text','Disconnect links on this output');
                mo.UserData = meta;
                mo.MenuSelectedFcn = @(s,e)disconnectEdgesForPort(app,s.UserData);
                h.ContextMenu = cm;
                ht.ContextMenu = cm;

                outH(end+1) = h; %#ok<AGROW>
                outL(end+1) = ht; %#ok<AGROW>
            end

            app.InPortHandles{idx} = inH;
            app.OutPortHandles{idx} = outH;
            app.InPortLabelHandles{idx} = inL;
            app.OutPortLabelHandles{idx} = outL;
            updatePortSelectionStyle(app);
        end

        function clearPortGraphicsForModule(app, idx)
            if idx <= numel(app.InPortHandles) && ~isempty(app.InPortHandles{idx})
                hh = app.InPortHandles{idx};
                hh = hh(isgraphics(hh));
                if ~isempty(hh), delete(hh); end
                app.InPortHandles{idx} = gobjects(0);
            end
            if idx <= numel(app.OutPortHandles) && ~isempty(app.OutPortHandles{idx})
                hh = app.OutPortHandles{idx};
                hh = hh(isgraphics(hh));
                if ~isempty(hh), delete(hh); end
                app.OutPortHandles{idx} = gobjects(0);
            end
            if idx <= numel(app.InPortLabelHandles) && ~isempty(app.InPortLabelHandles{idx})
                hh = app.InPortLabelHandles{idx};
                hh = hh(isgraphics(hh));
                if ~isempty(hh), delete(hh); end
                app.InPortLabelHandles{idx} = gobjects(0);
            end
            if idx <= numel(app.OutPortLabelHandles) && ~isempty(app.OutPortLabelHandles{idx})
                hh = app.OutPortLabelHandles{idx};
                hh = hh(isgraphics(hh));
                if ~isempty(hh), delete(hh); end
                app.OutPortLabelHandles{idx} = gobjects(0);
            end
        end

        function portButtonDown(app, src, event)
            if ~isprop(src,'UserData') || isempty(src.UserData)
                return;
            end
            meta = src.UserData;
            if ~isstruct(meta) || ~all(isfield(meta, {'moduleIdx','isOut','portName'}))
                return;
            end

            mod = app.UIFigure.CurrentModifier;
            additive = any(strcmp(mod,'shift'));
            setPortSelection(app, meta, additive);
            setSelection(app, meta.moduleIdx, additive);

            if numel(app.SelectedPorts) == 2
                connectDisconnectFromSelectedPorts(app);
            end
        end

        function setPortSelection(app, meta, additive)
            if nargin < 3
                additive = false;
            end

            if ~additive
                app.SelectedPorts = meta;
            else
                cur = app.SelectedPorts;
                if isempty(cur)
                    app.SelectedPorts = meta;
                else
                    same = false(1,numel(cur));
                    for i = 1:numel(cur)
                        same(i) = cur(i).moduleIdx == meta.moduleIdx && ...
                            logical(cur(i).isOut) == logical(meta.isOut) && ...
                            strcmp(char(string(cur(i).portName)), char(string(meta.portName)));
                    end
                    if any(same)
                        cur(same) = [];
                        app.SelectedPorts = cur;
                    else
                        app.SelectedPorts = [cur, meta];
                    end
                end
            end

            if numel(app.SelectedPorts) > 2
                app.SelectedPorts = app.SelectedPorts(end-1:end);
            end

            updatePortSelectionStyle(app);
        end

        function clearPortSelection(app)
            app.SelectedModules = [];
            app.SelectedPorts = struct('moduleIdx',{},'isOut',{},'portName',{});
            updatePortSelectionStyle(app);
        end

        function connectDisconnectFromSelectedPorts(app)
            if numel(app.SelectedPorts) ~= 2
                return;
            end

            p1 = app.SelectedPorts(1);
            p2 = app.SelectedPorts(2);

            if logical(p1.isOut) == logical(p2.isOut)
                uialert(app.UIFigure, 'Select one output port and one input port.', 'Invalid selection', 'Icon','warning');
                return;
            end

            if p1.isOut
                fromMeta = p1;
                toMeta = p2;
            else
                fromMeta = p2;
                toMeta = p1;
            end

            if fromMeta.moduleIdx > numel(app.Data.nodes) || toMeta.moduleIdx > numel(app.Data.nodes)
                return;
            end

            fromNode = app.Data.nodes(fromMeta.moduleIdx);
            toNode = app.Data.nodes(toMeta.moduleIdx);

            [okCompat, why] = arePortsCompatible(app, fromNode, fromMeta.portName, toNode, toMeta.portName);
            if ~okCompat
                uialert(app.UIFigure, ['Incompatible ports: ' why], 'Cannot connect', 'Icon','warning');
                return;
            end

            fromId = char(string(fromNode.id));
            toId = char(string(toNode.id));
            edgeIdx = findEdgeByPortMap(app, fromId, toId, fromMeta.portName, toMeta.portName);

            if ~isempty(edgeIdx)
                app.Data.edges(edgeIdx) = [];
            else
                e = struct('from',fromId,'to',toId,'fromPort',char(string(fromMeta.portName)), ...
                    'toPort',char(string(toMeta.portName)),'condition','');
                if isempty(app.Data.edges)
                    app.Data.edges = e;
                else
                    app.Data.edges(end+1) = e;
                end
                autoHarmonizeConnection(app, fromId, toId, fromMeta.portName, toMeta.portName);
            end

            markDirty(app, true);
            redrawEdges(app);
            refreshStatus(app);
            clearPortSelection(app);
        end

        function edgeIdx = findEdgeByPortMap(app, fromId, toId, fromPort, toPort)
            edgeIdx = [];
            if isempty(app.Data.edges)
                return;
            end

            for i = 1:numel(app.Data.edges)
                e = app.Data.edges(i);
                if strcmp(getEdgeField(app, e,'from',''), fromId) && ...
                   strcmp(getEdgeField(app, e,'to',''), toId) && ...
                   strcmp(getEdgeField(app, e,'fromPort',''), char(string(fromPort))) && ...
                   strcmp(getEdgeField(app, e,'toPort',''), char(string(toPort)))
                    edgeIdx = i;
                    return;
                end
            end
        end

        function disconnectEdgesForPort(app, meta)
            if isempty(app.Data.edges)
                return;
            end
            if meta.moduleIdx > numel(app.Data.nodes)
                return;
            end

            nodeId = char(string(app.Data.nodes(meta.moduleIdx).id));
            pname = char(string(meta.portName));
            edgeList = [];

            for i = 1:numel(app.Data.edges)
                e = app.Data.edges(i);
                if meta.isOut
                    if strcmp(getEdgeField(app, e,'from',''), nodeId) && strcmp(getEdgeField(app, e,'fromPort',''), pname)
                        edgeList(end+1) = i; %#ok<AGROW>
                    end
                else
                    if strcmp(getEdgeField(app, e,'to',''), nodeId) && strcmp(getEdgeField(app, e,'toPort',''), pname)
                        edgeList(end+1) = i; %#ok<AGROW>
                    end
                end
            end

            if isempty(edgeList)
                return;
            end

            if numel(edgeList) == 1
                edgeIdx = edgeList(1);
            else
                [ok, edgeIdx] = askDisconnectEdge(app, edgeList);
                if ~ok
                    return;
                end
            end

            app.Data.edges(edgeIdx) = [];
            markDirty(app, true);
            redrawEdges(app);
            refreshStatus(app);
        end

        function redrawAll(app)
            cla(app.UIModulesAxes);
            hold(app.UIModulesAxes,'on');

            app.ModuleHandles = gobjects(0);
            app.ModuleTextHandles = gobjects(0);
            app.ModuleBadgeHandles = gobjects(0);
            app.ModuleMarkers = gobjects(0);
            app.EdgeHandles = gobjects(0);
            app.EdgeLabelHandles = gobjects(0);
            app.InPortHandles = {};
            app.OutPortHandles = {};
            app.InPortLabelHandles = {};
            app.OutPortLabelHandles = {};
            app.SelectedPorts = struct('moduleIdx',{},'isOut',{},'portName',{});

            for i = 1:numel(app.Data.nodes)
                drawModule(app, i);
            end
            redrawEdges(app);
            updateModuleListTable(app);
            refreshStatus(app);
        end

        function redrawEdges(app)
            if ~isempty(app.EdgeHandles)
                try
                    delete(app.EdgeHandles(ishandle(app.EdgeHandles)));
                catch
                end
            end
            if ~isempty(app.EdgeLabelHandles)
                try
                    delete(app.EdgeLabelHandles(ishandle(app.EdgeLabelHandles)));
                catch
                end
            end
            app.EdgeHandles = gobjects(0);
            app.EdgeLabelHandles = gobjects(0);

            if isempty(app.Data.edges)
                return;
            end

            for i = 1:numel(app.Data.edges)
                e = app.Data.edges(i);
                [ok1, fromIdx] = getNodeIndexById(app, getEdgeField(app, e,'from',''));
                [ok2, toIdx] = getNodeIndexById(app, getEdgeField(app, e,'to',''));
                if ~ok1 || ~ok2
                    continue;
                end

                n1 = app.Data.nodes(fromIdx);
                n2 = app.Data.nodes(toIdx);
                [x1,y1] = edgeAnchor(app, n1, true,  getEdgeField(app, e,'fromPort',''));
                [x2,y2] = edgeAnchor(app, n2, false, getEdgeField(app, e,'toPort',''));

                h = plot(app.UIModulesAxes, [x1 x2], [y1 y2], '-', 'Color',[0 0 0], 'HitTest','off');
                app.EdgeHandles(end+1) = h; %#ok<AGROW>
            end
        end

        function setSelection(app, idx, additive)
            if nargin < 3
                additive = false;
            end
            if ~additive
                app.SelectedModules = idx;
            else
                app.SelectedModules = unique([app.SelectedModules idx]);
                if numel(app.SelectedModules) > 2
                    app.SelectedModules = app.SelectedModules(end-1:end);
                end
            end
            updateSelectionStyle(app);

            if idx <= size(app.UIModuleListTable.Data,1)
                app.UIModuleListTable.Selection = [idx 2];
            end
        end

        function clearSelection(app)
            app.SelectedModules = [];
            clearPortSelection(app);
            updateSelectionStyle(app);
        end

        function updateSelectionStyle(app)
            for i = 1:numel(app.ModuleHandles)
                if isempty(app.ModuleHandles(i)) || ~isvalid(app.ModuleHandles(i))
                    continue;
                end
                applyModuleOutlineStyle(app, i);
            end
            updatePortSelectionStyle(app);
        end

        function applyModuleOutlineStyle(app, idx)
            if idx < 1 || idx > numel(app.Data.nodes) || idx > numel(app.ModuleHandles)
                return;
            end
            hPatch = app.ModuleHandles(idx);
            if isempty(hPatch) || ~isvalid(hPatch)
                return;
            end

            node = app.Data.nodes(idx);
            [edgeColor, lineWidth] = getModuleOutlineStyle(app, node);
            if ismember(idx, app.SelectedModules)
                lineWidth = max(lineWidth, 2.5);
            end
            hPatch.EdgeColor = edgeColor;
            hPatch.LineWidth = lineWidth;
        end

        function [edgeColor, lineWidth] = getModuleOutlineStyle(app, node) %#ok<INUSD>
            edgeColor = [0.20 0.20 0.20];
            lineWidth = 1.0;

            if ~getfielddefault(app, node, 'enabled', true)
                edgeColor = [0.55 0.55 0.55];
                return;
            end

            status = strtrim(char(string(getfielddefault(app, node, 'status', ''))));
            if isNodeStatusOk(app, status)
                edgeColor = [0.12 0.62 0.27];
                lineWidth = 1.4;
            else
                edgeColor = [0.86 0.20 0.18];
                lineWidth = 1.4;
            end
        end

        function tf = isNodeStatusOk(app, status) %#ok<INUSD>
            status = strtrim(char(string(status)));
            tf = startsWith(lower(status), 'ok');
        end

        function updatePortSelectionStyle(app)
            for i = 1:numel(app.InPortHandles)
                hh = app.InPortHandles{i};
                if isempty(hh), continue; end
                for k = 1:numel(hh)
                    if ~isgraphics(hh(k)), continue; end
                    hh(k).MarkerFaceColor = [1 1 1];
                    hh(k).MarkerSize = 9;
                end
            end

            for i = 1:numel(app.OutPortHandles)
                hh = app.OutPortHandles{i};
                if isempty(hh), continue; end
                for k = 1:numel(hh)
                    if ~isgraphics(hh(k)), continue; end
                    hh(k).MarkerFaceColor = [1 1 1];
                    hh(k).MarkerSize = 9;
                end
            end

            for i = 1:numel(app.SelectedPorts)
                meta = app.SelectedPorts(i);
                if meta.moduleIdx < 1
                    continue;
                end

                if meta.isOut
                    if meta.moduleIdx > numel(app.OutPortHandles)
                        continue;
                    end
                    hh = app.OutPortHandles{meta.moduleIdx};
                else
                    if meta.moduleIdx > numel(app.InPortHandles)
                        continue;
                    end
                    hh = app.InPortHandles{meta.moduleIdx};
                end

                if isempty(hh)
                    continue;
                end

                for k = 1:numel(hh)
                    if ~isgraphics(hh(k))
                        continue;
                    end
                    if ~isprop(hh(k),'UserData') || isempty(hh(k).UserData)
                        continue;
                    end
                    ud = hh(k).UserData;
                    if isstruct(ud) && strcmp(char(string(ud.portName)), char(string(meta.portName)))
                        hh(k).MarkerFaceColor = [1.0 0.85 0.15];
                        hh(k).MarkerSize = 11;
                    end
                end
            end
        end

        function tf = isBuiltinNodeType(app, nodeType) %#ok<INUSD>
            t = lower(char(string(nodeType)));
            tf = any(strcmp(t, {'dataloader','roiidentify','roipattern','roimanual','roigrid','roiextract','roitracked'}));
        end

        function updateModuleListTable(app)
            n = numel(app.Data.nodes);
            data = cell(n,6);
            for i = 1:n
                node = app.Data.nodes(i);
                data{i,1} = logical(getfielddefault(app, node,'enabled',true));
                data{i,2} = getfielddefault(app, node,'name',node.id);
                data{i,3} = getDisplayFromType(app, getfielddefault(app, node,'type',''));
                data{i,4} = strjoin(cellstr(node.inputs(:)), ', ');
                data{i,5} = strjoin(cellstr(node.outputs(:)), ', ');
                data{i,6} = getfielddefault(app, node,'status','');
            end
            app.UIModuleListTable.Data = data;
            if ~isempty(app.UITable) && isvalid(app.UITable)
                updateModuleLibraryTable(app);
            end
        end

        function updateModuleLibraryTable(app)
            entries = collectModuleLibraryEntries(app);
            app.LibraryEntries = entries;

            n = numel(entries);
            if n == 0
                app.SelectedLibraryRow = NaN;
                app.ButtonMoveToCanva.Enable = 'off';
                app.UITable.Data = cell(0,4);
                app.UITable.Selection = [];
                return;
            end
            if isnan(app.SelectedLibraryRow) || app.SelectedLibraryRow < 1 || app.SelectedLibraryRow > n
                app.SelectedLibraryRow = 1;
            end

            data = cell(n,4);
            for i = 1:n
                data{i,1} = char(string(entries(i).name));
                data{i,2} = char(string(getDisplayFromType(app, entries(i).type)));
                if isempty(entries(i).pkg)
                    data{i,3} = 'builtin';
                else
                    data{i,3} = char(string(entries(i).pkg));
                end
                data{i,4} = formatLibraryLocation(app, entries(i));
            end
            app.UITable.Data = data;
            updateLibrarySelectionStyle(app);
            app.ButtonMoveToCanva.Enable = 'on';
        end

        function drawLibraryEntry(app, idx, layout)
            if idx < 1 || idx > numel(app.LibraryEntries)
                return;
            end

            entry = app.LibraryEntries(idx);
            node = normalizeLibraryNode(app, entry.node);
            node.layout = normalizeModuleLayout(app, node, layout);
            [x,y,w,h] = deal(node.layout(1), node.layout(2), node.layout(3), node.layout(4));
            pts = [x y; x+w y; x+w y+h; x y+h];

            hPatch = patch(app.UILibraryAxes, pts(:,1), pts(:,2), [1 1 1], ...
                'EdgeColor',[0.72 0.72 0.72], ...
                'LineWidth',0.8, ...
                'ButtonDownFcn',@app.libraryItemButtonDown);
            hPatch.UserData = idx;

            hText = text(app.UILibraryAxes, x+1.2, y+1.9, buildLibraryCaption(app, entry), ...
                'HorizontalAlignment','left', ...
                'VerticalAlignment','middle', ...
                'FontSize',10, ...
                'FontWeight','bold', ...
                'Interpreter','none', ...
                'ButtonDownFcn',@app.libraryItemButtonDown);
            hText.UserData = idx;

            hBadge = text(app.UILibraryAxes, x+1.2, y+4.1, buildLibraryBadge(app, entry), ...
                'HorizontalAlignment','left', ...
                'VerticalAlignment','middle', ...
                'FontSize',8, ...
                'Interpreter','tex', ...
                'Color',[0.25 0.25 0.25], ...
                'ButtonDownFcn',@app.libraryItemButtonDown);
            hBadge.UserData = idx;

            line(app.UILibraryAxes, [x+1.0 x+w-1.0], [y+5.6 y+5.6], 'Color',[0.88 0.88 0.88], 'LineWidth',1.0, 'HitTest','off');

            c = getNodeContract(app, node);
            for k = 1:numel(c.in)
                py = getPortRowY(app, node, false, k);
                plot(app.UILibraryAxes, x+1.5, py, 'o', ...
                    'MarkerSize',8, ...
                    'MarkerEdgeColor',[0.55 0.55 0.55], ...
                    'MarkerFaceColor',[1 1 1], ...
                    'LineWidth',1.3, ...
                    'HitTest','off');
                text(app.UILibraryAxes, x+4.0, py, buildPortDisplayText(app, node, false, c.in(k).name), ...
                    'HorizontalAlignment','left', ...
                    'VerticalAlignment','middle', ...
                    'FontSize',9, ...
                    'FontAngle','italic', ...
                    'Color',[0.10 0.10 0.10], ...
                    'Interpreter','none', ...
                    'HitTest','off');
            end

            for k = 1:numel(c.out)
                py = getPortRowY(app, node, true, k);
                plot(app.UILibraryAxes, x+w-1.5, py, 'o', ...
                    'MarkerSize',8, ...
                    'MarkerEdgeColor',[0.55 0.55 0.55], ...
                    'MarkerFaceColor',[1 1 1], ...
                    'LineWidth',1.3, ...
                    'HitTest','off');
                text(app.UILibraryAxes, x+w-4.0, py, buildPortDisplayText(app, node, true, c.out(k).name), ...
                    'HorizontalAlignment','right', ...
                    'VerticalAlignment','middle', ...
                    'FontSize',9, ...
                    'FontAngle','italic', ...
                    'Color',[0.10 0.10 0.10], ...
                    'Interpreter','none', ...
                    'HitTest','off');
            end

            app.LibraryHandles(idx) = hPatch;
            app.LibraryTextHandles(idx) = hText;
            app.LibraryBadgeHandles(idx) = hBadge;
        end

        function caption = buildLibraryCaption(app, entry) %#ok<INUSD>
            caption = char(string(entry.name));
        end

        function badge = buildLibraryBadge(app, entry)
            badge = ['\it ' strrep(char(string(getDisplayFromType(app, entry.type))), '_', '\_')];
        end

        function libraryItemButtonDown(app, src, event)
            if ~isprop(src, 'UserData') || isempty(src.UserData)
                return;
            end
            row = double(src.UserData);
            if row < 1 || row > numel(app.LibraryEntries)
                return;
            end
            app.SelectedLibraryRow = row;
            updateLibrarySelectionStyle(app);
            if strcmp(app.UIFigure.SelectionType, 'open')
                duplicateSelectedLibraryModule(app);
            end
        end

        function updateLibrarySelectionStyle(app)
            if ~isempty(app.UITable) && isvalid(app.UITable)
                if isnan(app.SelectedLibraryRow)
                    app.UITable.Selection = [];
                else
                    app.UITable.Selection = [app.SelectedLibraryRow 1];
                end
            end

            if isnan(app.SelectedLibraryRow)
                app.ButtonMoveToCanva.Enable = 'off';
            else
                app.ButtonMoveToCanva.Enable = 'on';
            end
        end

        function entries = collectModuleLibraryEntries(app)
            entries = struct('name',{},'type',{},'pkg',{},'source',{},'node',{},'signature',{}, ...
                'refPath',{},'refId',{},'refKind',{},'isOffline',{});
            currentNodeSigs = getCurrentCanvasLibrarySignatures(app);

            try
                vars = evalin('base', 'whos');
            catch
                vars = struct('name',{},'class',{});
            end

            for i = 1:numel(vars)
                cls = char(string(vars(i).class));
                vname = char(string(vars(i).name));
                try
                    switch lower(cls)
                        case 'pipeline'
                            obj = evalin('base', vname);
                            for j = 1:numel(obj)
                                if isSameAsCurrentPipeline(app, obj(j))
                                    continue;
                                end
                                [nodes, ~] = unpackPipeline(app, obj(j));
                                for k = 1:numel(nodes)
                                    entry = makeLibraryEntryFromNode(app, nodes(k), ['workspace pipeline: ' vname]);
                                    if shouldSkipLibraryEntry(app, entry, currentNodeSigs)
                                        continue;
                                    end
                                    entries = appendLibraryEntry(app, entries, entry);
                                end
                            end
                        case 'process'
                            obj = evalin('base', vname);
                            for j = 1:numel(obj)
                                entry = makeLibraryEntryFromProcess(app, obj(j), ['workspace processor: ' vname]);
                                if shouldSkipLibraryEntry(app, entry, currentNodeSigs)
                                    continue;
                                end
                                entries = appendLibraryEntry(app, entries, entry);
                            end
                        case 'classi'
                            obj = evalin('base', vname);
                            for j = 1:numel(obj)
                                entry = makeLibraryEntryFromClassi(app, obj(j), ['workspace classifier: ' vname]);
                                if shouldSkipLibraryEntry(app, entry, currentNodeSigs)
                                    continue;
                                end
                                entries = appendLibraryEntry(app, entries, entry);
                            end
                        case 'shallow'
                            obj = evalin('base', vname);
                            entries = appendProjectLibraryEntries(app, entries, obj, ['workspace project: ' vname], currentNodeSigs);
                    end
                catch
                end
            end

            shallowObj = [];
            if isfield(app.Context,'shallow') && ~isempty(app.Context.shallow)
                shallowObj = app.Context.shallow;
            elseif isfield(app.Context,'shallowObj') && ~isempty(app.Context.shallowObj)
                shallowObj = app.Context.shallowObj;
            end
            if ~isempty(shallowObj)
                entries = appendProjectLibraryEntries(app, entries, shallowObj, 'current project', currentNodeSigs);
            end

        end

        function entries = appendProjectLibraryEntries(app, entries, shallowObj, sourcePrefix, currentNodeSigs)
            if nargin < 5
                currentNodeSigs = getCurrentCanvasLibrarySignatures(app);
            end
            if isempty(shallowObj) || ~isa(shallowObj, 'shallow')
                return;
            end
            if numel(shallowObj) > 1
                for ii = 1:numel(shallowObj)
                    entries = appendProjectLibraryEntries(app, entries, shallowObj(ii), sprintf('%s #%d', sourcePrefix, ii), currentNodeSigs);
                end
                return;
            end
            try
                procList = getfielddefault(app, shallowObj.processing, 'processor', []);
                for i = 1:numel(procList)
                    try
                        if isa(procList(i), 'process') && isvalid(procList(i))
                            entry = makeLibraryEntryFromProcess(app, procList(i), [sourcePrefix ' processors']);
                            if shouldSkipLibraryEntry(app, entry, currentNodeSigs)
                                continue;
                            end
                            entries = appendLibraryEntry(app, entries, entry);
                        end
                    catch
                    end
                end
            catch
            end
            try
                classList = getfielddefault(app, shallowObj.processing, 'classification', []);
                for i = 1:numel(classList)
                    try
                        if isa(classList(i), 'classi') && isvalid(classList(i))
                            entry = makeLibraryEntryFromClassi(app, classList(i), [sourcePrefix ' classifiers']);
                            if shouldSkipLibraryEntry(app, entry, currentNodeSigs)
                                continue;
                            end
                            entries = appendLibraryEntry(app, entries, entry);
                        end
                    catch
                    end
                end
            catch
            end
        end

        function entries = appendLibraryEntry(app, entries, entry) %#ok<INUSD>
            if isempty(entry) || ~isstruct(entry) || ~isfield(entry,'signature')
                return;
            end
            if isempty(entries)
                entries = entry;
                return;
            end
            existingCanonical = arrayfun(@(e) canonicalLibrarySignature(app, e), entries, 'UniformOutput', false);
            if any(strcmp(existingCanonical, canonicalLibrarySignature(app, entry)))
                return;
            end
            entries(end+1) = entry; %#ok<AGROW>
        end

        function txt = formatLibraryLocation(app, entry) %#ok<INUSD>
            txt = '';
            if isempty(entry) || ~isstruct(entry)
                return;
            end
            src = char(string(getObjectFieldDefault(app, entry, 'source', '')));
            src = regexprep(src, '\s+', ' ');
            src = strtrim(src);
            if isempty(src)
                return;
            end

            if startsWith(lower(src), 'workspace project:')
                tail = strtrim(extractAfter(string(src), ':'));
                txt = char(tail);
                txt = strrep(txt, ' classifiers', ' / classifiers');
                txt = strrep(txt, ' processors', ' / processors');
                return;
            end

            if startsWith(lower(src), 'current project')
                txt = strrep(src, ' classifiers', ' / classifiers');
                txt = strrep(txt, ' processors', ' / processors');
                return;
            end

            if startsWith(lower(src), 'workspace pipeline:')
                tail = strtrim(extractAfter(string(src), ':'));
                txt = ['pipeline / ' char(tail)];
                return;
            end

            if startsWith(lower(src), 'workspace classifier:')
                tail = strtrim(extractAfter(string(src), ':'));
                txt = ['workspace / classifier / ' char(tail)];
                return;
            end

            if startsWith(lower(src), 'workspace processor:')
                tail = strtrim(extractAfter(string(src), ':'));
                txt = ['workspace / processor / ' char(tail)];
                return;
            end

            if contains(lower(src), 'offline library')
                txt = '';
                return;
            end

            txt = src;
        end

        function entries = loadOfflineLibraryEntries(app)
            entries = struct('name',{},'type',{},'pkg',{},'source',{},'node',{},'signature',{}, ...
                'refPath',{},'refId',{},'refKind',{},'isOffline',{});
            libFile = getOfflineLibraryFile(app);
            if exist(libFile, 'file') ~= 2
                return;
            end
            try
                S = load(libFile, 'entries');
                if isfield(S, 'entries') && isstruct(S.entries)
                    tmp = S.entries;
                    for i = 1:numel(tmp)
                        tmp(i) = finalizeLibraryEntry(app, tmp(i)); %#ok<AGROW>
                    end
                    entries = tmp;
                end
            catch
            end
        end

        function saveOfflineLibraryEntries(app, entries)
            libFile = getOfflineLibraryFile(app);
            libDir = fileparts(libFile);
            if exist(libDir, 'dir') ~= 7
                mkdir(libDir);
            end
            save(libFile, 'entries');
        end

        function libFile = getOfflineLibraryFile(app) %#ok<INUSD>
            root = '';
            try
                guiPath = which('pipelineGUI');
                if ~isempty(guiPath)
                    root = fileparts(fileparts(char(string(guiPath))));
                end
            catch
            end
            if isempty(root) || exist(root, 'dir') ~= 7
                root = fullfile(pwd, 'structure');
            end
            libFile = fullfile(root, 'cache', 'pipeline_module_library.mat');
        end

        function rememberLibraryEntry(app, entry)
            if isempty(entry) || ~isstruct(entry)
                return;
            end
            entry = finalizeLibraryEntry(app, entry);
            cur = loadOfflineLibraryEntries(app);
            cur = appendLibraryEntry(app, cur, entry);
            saveOfflineLibraryEntries(app, cur);
        end

        function rememberNodeInOfflineLibrary(app, node, source)
            entry = makeLibraryEntryFromNode(app, node, source);
            rememberLibraryEntry(app, entry);
        end

        function rememberPipelineNodesInOfflineLibrary(app, nodes, source)
            if isempty(nodes)
                return;
            end
            cur = loadOfflineLibraryEntries(app);
            for i = 1:numel(nodes)
                entry = makeLibraryEntryFromNode(app, nodes(i), source);
                cur = appendLibraryEntry(app, cur, entry);
            end
            saveOfflineLibraryEntries(app, cur);
        end

        function entry = finalizeLibraryEntry(app, entry)
            if isempty(entry) || ~isstruct(entry)
                return;
            end
            node = getObjectFieldDefault(app, entry, 'node', struct());
            [refPath, refId, refKind] = extractNodeReference(app, node);
            entry = ensureLibraryEntryFields(app, entry);
            entry.refPath = refPath;
            entry.refId = refId;
            entry.refKind = refKind;
            if isempty(entry.source)
                entry.source = 'offline library';
            end
            if ~isfield(entry, 'isOffline') || isempty(entry.isOffline)
                entry.isOffline = contains(lower(entry.source), 'offline');
            end
            sigPath = lower(char(string(refPath)));
            entry.signature = lower(sprintf('%s|%s|%s|%s|%s|%s', ...
                char(string(entry.source)), char(string(entry.type)), char(string(entry.pkg)), ...
                char(string(entry.name)), sigPath, char(string(refId))));
        end

        function sig = canonicalLibrarySignature(app, entry)
            sig = '';
            if isempty(entry) || ~isstruct(entry)
                return;
            end

            node = getObjectFieldDefault(app, entry, 'node', struct());
            node = normalizeLibraryNode(app, node);
            [refPath, refId, refKind] = extractNodeReference(app, node);
            params = getfielddefault(app, node, 'params', struct());
            if ~isstruct(params)
                params = struct();
            end
            drop = intersect(fieldnames(params), {'linkSource'});
            if ~isempty(drop)
                params = rmfield(params, drop);
            end

            paramText = safeJsonText(app, params);
            sig = lower(sprintf('%s|%s|%s|%s|%s|%s', ...
                char(string(getfielddefault(app, node, 'type', ''))), ...
                char(string(getfielddefault(app, node, 'pkg', ''))), ...
                char(string(getfielddefault(app, node, 'name', ''))), ...
                lower(char(string(refPath))), ...
                char(string(refId)), ...
                char(string(refKind))));
            sig = [sig '|' lower(paramText)];
        end

        function txt = safeJsonText(app, value) %#ok<INUSD>
            try
                txt = jsonencode(orderfields(value));
            catch
                try
                    txt = evalc('disp(value)');
                catch
                    txt = class(value);
                end
            end
        end

        function sigs = getCurrentCanvasLibrarySignatures(app)
            sigs = cell(0,1);
            if isempty(app.Data.nodes)
                return;
            end
            sigs = cell(numel(app.Data.nodes),1);
            for ii = 1:numel(app.Data.nodes)
                entry = makeLibraryEntryFromNode(app, app.Data.nodes(ii), 'current pipeline');
                sigs{ii} = canonicalLibrarySignature(app, entry);
            end
        end

        function tf = shouldSkipLibraryEntry(app, entry, currentNodeSigs)
            if nargin < 3
                currentNodeSigs = getCurrentCanvasLibrarySignatures(app);
            end
            tf = false;
            if isempty(entry) || ~isstruct(entry)
                return;
            end
            tf = any(strcmp(currentNodeSigs, canonicalLibrarySignature(app, entry)));
        end

        function tf = isSameAsCurrentPipeline(app, pipeObj)
            tf = false;
            if isempty(pipeObj) || ~isa(pipeObj, 'pipeline')
                return;
            end
            if ~isfield(app.Context, 'pipeObj') || ~isa(app.Context.pipeObj, 'pipeline') || isempty(app.Context.pipeObj)
                return;
            end
            cur = app.Context.pipeObj;
            try
                if isequal(cur, pipeObj)
                    tf = true;
                    return;
                end
            catch
            end

            try
                curPath = lower(strrep(char(string(cur.path)), '\', '/'));
                objPath = lower(strrep(char(string(pipeObj.path)), '\', '/'));
                curId = char(string(cur.strid));
                objId = char(string(pipeObj.strid));
                tf = ~isempty(curPath) && strcmp(curPath, objPath) && strcmp(curId, objId);
            catch
                tf = false;
            end
        end

        function entry = ensureLibraryEntryFields(app, entry) %#ok<INUSD>
            defaults = struct('name','','type','','pkg','','source','','node',struct(), ...
                'signature','','refPath','','refId','','refKind','','isOffline',false);
            fn = fieldnames(defaults);
            for i = 1:numel(fn)
                key = fn{i};
                if ~isfield(entry, key)
                    entry.(key) = defaults.(key);
                end
            end
        end

        function [refPath, refId, refKind] = extractNodeReference(app, node) %#ok<INUSD>
            refPath = '';
            refId = '';
            refKind = '';
            if ~isstruct(node) || ~isfield(node, 'params') || ~isstruct(node.params)
                return;
            end
            p = node.params;
            if isfield(p, 'modulePath') && ~isempty(p.modulePath)
                refPath = char(string(p.modulePath));
            end
            if isfield(p, 'moduleId') && ~isempty(p.moduleId)
                refId = char(string(p.moduleId));
            end
            if isfield(p, 'moduleKind') && ~isempty(p.moduleKind)
                refKind = char(string(p.moduleKind));
            elseif any(strcmpi(char(string(getfielddefault(app, node, 'type', ''))), {'processor','classifier'}))
                refKind = char(string(getfielddefault(app, node, 'type', '')));
            end
        end

        function refPath = resolveNodeReferencePathForGui(app, refPath)
            refPath = char(string(refPath));
            if isempty(refPath)
                return;
            end
            if isAbsolutePathGuiLocal(app, refPath)
                return;
            end
            pipeObj = getCurrentPipelineObject(app);
            if isempty(pipeObj) || ~isa(pipeObj, 'pipeline') || isempty(pipeObj.path)
                return;
            end
            base = char(string(pipeObj.path));
            if exist(base, 'file') == 2
                base = fileparts(base);
            end
            if exist(base, 'dir') == 7
                refPath = fullfile(base, refPath);
            end
        end

        function tf = isAbsolutePathGuiLocal(app, p) %#ok<INUSD>
            tf = false;
            p = char(string(p));
            if isempty(p)
                return;
            end
            if ispc
                tf = ~isempty(regexp(p, '^[A-Za-z]:[\\/]', 'once')) || startsWith(p, '\\');
            else
                tf = startsWith(p, '/');
            end
        end

        function procObj = loadLinkedProcessReference(app, node)
            procObj = [];
            [refPath, refId, refKind] = extractNodeReference(app, node);
            if ~strcmpi(refKind, 'processor') || isempty(refPath) || isempty(refId)
                return;
            end
            refPath = resolveNodeReferencePathForGui(app, refPath);
            snap = fullfile(refPath, [refId '_processor.mat']);
            if exist(snap, 'file') ~= 2
                return;
            end
            try
                [procObj, ~] = processLoad(snap);
            catch
                procObj = [];
            end
        end

        function procObj = loadOriginProcessReference(app, node)
            procObj = [];
            [refPath, refId, refKind] = extractNodeOrigin(app, node);
            if ~strcmpi(refKind, 'processor') || isempty(refPath) || isempty(refId)
                return;
            end
            refPath = resolveNodeReferencePathForGui(app, refPath);
            snap = fullfile(refPath, [refId '_processor.mat']);
            if exist(snap, 'file') ~= 2
                return;
            end
            try
                [procObj, ~] = processLoad(snap);
            catch
                procObj = [];
            end
        end

        function classObj = loadLinkedClassifierReference(app, node)
            classObj = [];
            [refPath, refId, refKind] = extractNodeReference(app, node);
            if ~strcmpi(refKind, 'classifier') || isempty(refPath) || isempty(refId)
                return;
            end
            refPath = resolveNodeReferencePathForGui(app, refPath);
            snap = fullfile(refPath, [refId '_classification.mat']);
            if exist(snap, 'file') ~= 2
                return;
            end
            try
                [classObj, ~] = classiLoad(snap);
            catch
                classObj = [];
            end
        end

        function classObj = loadOriginClassifierReference(app, node)
            classObj = [];
            [refPath, refId, refKind] = extractNodeOrigin(app, node);
            if ~strcmpi(refKind, 'classifier') || isempty(refPath) || isempty(refId)
                return;
            end
            refPath = resolveNodeReferencePathForGui(app, refPath);
            snap = fullfile(refPath, [refId '_classification.mat']);
            if exist(snap, 'file') ~= 2
                return;
            end
            try
                [classObj, ~] = classiLoad(snap);
            catch
                classObj = [];
            end
        end

        function tmpProc = applyProcessReferenceForGui(app, tmpProc, refProc) %#ok<INUSD>
            props = {'path','strid','description','category','processFun','processArg','runProfiles'};
            for i = 1:numel(props)
                name = props{i};
                try
                    if isprop(refProc, name)
                        val = refProc.(name);
                        if ~isempty(val)
                            tmpProc.(name) = val;
                        end
                    end
                catch
                end
            end
        end

        function tmpClassi = applyClassifierReferenceForGui(app, tmpClassi, refClassi) %#ok<INUSD>
            props = {'path','strid','description','category','channel','channelName','channelName2', ...
                'classes','classifyFun','trainingFun','classifierPkg','outputType','outputFun','outputArg','trainingParam','runProfiles'};
            for i = 1:numel(props)
                name = props{i};
                try
                    if isprop(refClassi, name)
                        val = refClassi.(name);
                        if ~isempty(val)
                            tmpClassi.(name) = val;
                        end
                    end
                catch
                end
            end
        end

        function entry = makeLibraryEntryFromNode(app, node, source)
            node = normalizeLibraryNode(app, node);
            entry = struct();
            entry.name = char(string(getfielddefault(app, node, 'name', getfielddefault(app, node, 'id', 'module'))));
            entry.type = char(string(getfielddefault(app, node, 'type', 'module')));
            entry.pkg = char(string(getfielddefault(app, node, 'pkg', '')));
            entry.source = char(string(source));
            entry.node = node;
            entry.signature = '';
            entry.refPath = '';
            entry.refId = '';
            entry.refKind = '';
            entry.isOffline = false;
            entry = finalizeLibraryEntry(app, entry);
        end

        function entry = makeLibraryEntryFromProcess(app, procObj, source)
            node = struct();
            node.type = 'processor';
            node.name = char(string(getObjectFieldDefault(app, procObj, 'strid', 'processor')));
            node.id = node.name;
            node.func = char(string(getObjectFieldDefault(app, procObj, 'processFun', '')));
            node.gui = 'processDataGUI';
            node.guiMode = 'replace';
            node.paramRequired = {'pkg'};
            pkgName = inferPkgFromFunction(app, node.func, 'process');
            node.pkg = pkgName;
            params = struct();
            arg = getObjectFieldDefault(app, procObj, 'processArg', struct());
            if isstruct(arg)
                params = arg;
            end
            if ~isempty(pkgName)
                params.pkg = pkgName;
            end
            refPath = char(string(getObjectFieldDefault(app, procObj, 'path', '')));
            refId = char(string(getObjectFieldDefault(app, procObj, 'strid', '')));
            if ~isempty(refPath)
                params.modulePath = refPath;
            end
            if ~isempty(refId)
                params.moduleId = refId;
            end
            params.moduleKind = 'processor';
            node.params = params;
            node.enabled = true;
            node.status = '';
            node.layout = [0 0 20 10];
            entry = makeLibraryEntryFromNode(app, node, source);
        end

        function entry = makeLibraryEntryFromClassi(app, classObj, source)
            node = struct();
            node.type = 'classifier';
            node.name = char(string(getObjectFieldDefault(app, classObj, 'strid', 'classifier')));
            node.id = node.name;
            node.func = char(string(getObjectFieldDefault(app, classObj, 'classifyFun', '')));
            node.gui = 'classifierGUI';
            node.guiMode = 'replace';
            node.paramRequired = {'pkg'};
            pkgName = char(string(getObjectFieldDefault(app, classObj, 'classifierPkg', '')));
            if isempty(pkgName)
                pkgName = inferPkgFromFunction(app, node.func, 'classify');
            end
            node.pkg = pkgName;
            params = struct();
            if ~isempty(pkgName)
                params.pkg = pkgName;
            end
            ch1 = char(string(getObjectFieldDefault(app, classObj, 'channelName', '')));
            ch2 = char(string(getObjectFieldDefault(app, classObj, 'channelName2', '')));
            if ~isempty(ch1) && ~isempty(ch2)
                params.channels = {ch1, ch2};
            elseif ~isempty(ch1)
                params.channel = ch1;
            end
            cls = getObjectFieldDefault(app, classObj, 'classes', {});
            if ~isempty(cls)
                params.classes = cls;
            end
            trainingParam = getObjectFieldDefault(app, classObj, 'trainingParam', struct());
            if isstruct(trainingParam) && ~isempty(fieldnames(trainingParam))
                params.trainingParam = trainingParam;
            end
            outType = char(string(getObjectFieldDefault(app, classObj, 'outputType', '')));
            if ~isempty(outType)
                params.outputType = outType;
            end
            outFun = getObjectFieldDefault(app, classObj, 'outputFun', []);
            if ~isempty(outFun)
                params.outputFun = outFun;
            end
            outArg = getObjectFieldDefault(app, classObj, 'outputArg', []);
            if ~isempty(outArg)
                params.outputArg = outArg;
            end
            refPath = char(string(getObjectFieldDefault(app, classObj, 'path', '')));
            refId = char(string(getObjectFieldDefault(app, classObj, 'strid', '')));
            if ~isempty(refPath)
                params.modulePath = refPath;
            end
            if ~isempty(refId)
                params.moduleId = refId;
            end
            params.moduleKind = 'classifier';
            node.params = params;
            node.enabled = true;
            node.status = '';
            node.layout = [0 0 20 10];
            entry = makeLibraryEntryFromNode(app, node, source);
        end

        function node = normalizeLibraryNode(app, node)
            if ~isfield(node,'id') || isempty(node.id)
                node.id = char(string(getfielddefault(app, node, 'name', getfielddefault(app, node, 'type', 'module'))));
            end
            if ~isfield(node,'name') || isempty(node.name)
                node.name = char(string(node.id));
            end
            if ~isfield(node,'enabled')
                node.enabled = true;
            end
            if ~isfield(node,'pkg')
                node.pkg = '';
            end
            if ~isfield(node,'params') || isempty(node.params) || ~isstruct(node.params)
                node.params = struct();
            end
            if ~isfield(node,'layout') || isempty(node.layout) || numel(node.layout) < 4
                node.layout = [0 0 20 10];
            end
            if ~isfield(node,'guiMode') || isempty(node.guiMode)
                node.guiMode = 'replace';
            end
            if ~isfield(node,'status')
                node.status = '';
            end
            if ~isfield(node,'func')
                node.func = '';
            end
            if ~isfield(node,'gui')
                node.gui = '';
            end
            if ~isfield(node,'paramRequired')
                node.paramRequired = {};
            end
            if ~isfield(node,'origin') || isempty(node.origin) || ~isstruct(node.origin)
                node.origin = struct('path','','id','','kind','');
            else
                if ~isfield(node.origin,'path') || isempty(node.origin.path), node.origin.path = ''; end
                if ~isfield(node.origin,'id') || isempty(node.origin.id), node.origin.id = ''; end
                if ~isfield(node.origin,'kind') || isempty(node.origin.kind), node.origin.kind = ''; end
            end
            if ~isfield(node,'importMode') || isempty(node.importMode)
                if nodeHasReference(app, node)
                    node.importMode = 'reference';
                else
                    node.importMode = 'configured_copy';
                end
            end
            node = populateNodeParamsFromPackage(app, node, false);
            node.contract = getNodeContract(app, node);
            [node.inputs, node.outputs] = ioFromContract(app, node.contract);
        end

        function nodes = normalizeNodeArray(app, nodes)
            if isempty(nodes)
                return;
            end
            src = nodes;
            nodes = struct([]);
            for ii = 1:numel(src)
                nodei = normalizeLibraryNode(app, src(ii));
                if isempty(nodes)
                    nodes = nodei;
                else
                    nodes(end+1) = nodei; %#ok<AGROW>
                end
            end
        end

        function duplicateSelectedLibraryModule(app)
            row = app.SelectedLibraryRow;
            if isnan(row) || row < 1 || row > numel(app.LibraryEntries)
                uialert(app.UIFigure, 'Select a module from the library first.', 'No module selected', 'Icon','info');
                return;
            end

            entry = app.LibraryEntries(row);
            node = buildConfiguredCopyImportedNode(app, entry.node);
            node.layout = getNextLibraryDropLayout(app);
            node.id = nextModuleId(app, node.type);
            node.name = nextModuleName(app, char(string(getfielddefault(app, node, 'name', node.id))));
            node.status = '';
            node.enabled = true;
            app.Data.nodes = normalizeNodeArray(app, app.Data.nodes);

            if isempty(app.Data.nodes)
                app.Data.nodes = node;
            else
                app.Data.nodes(end+1) = node;
            end

            markDirty(app, true);
            idx = numel(app.Data.nodes);
            drawModule(app, idx);
            clearPortSelection(app);
            setSelection(app, idx, false);
            updateParamsTable(app, idx);
            updateModuleListTable(app);
            rememberLibraryEntry(app, entry);
            refreshStatus(app);
        end

        function duplicateModule(app, idx)
            if idx < 1 || idx > numel(app.Data.nodes)
                return;
            end

            node = normalizeLibraryNode(app, app.Data.nodes(idx));
            baseLayout = getfielddefault(app, node, 'layout', [32 12 28 15]);
            node.layout = baseLayout;
            node.layout(1) = node.layout(1) + 4;
            node.layout(2) = node.layout(2) + 4;
            node.id = nextModuleId(app, node.type);
            node.name = nextModuleName(app, char(string(getfielddefault(app, node, 'name', node.id))));
            node.status = '';
            node.enabled = true;
            app.Data.nodes = normalizeNodeArray(app, app.Data.nodes);

            if isempty(app.Data.nodes)
                app.Data.nodes = node;
            else
                app.Data.nodes(end+1) = node;
            end

            markDirty(app, true);
            newIdx = numel(app.Data.nodes);
            drawModule(app, newIdx);
            clearPortSelection(app);
            setSelection(app, newIdx, false);
            updateParamsTable(app, newIdx);
            updateModuleListTable(app);
            refreshStatus(app);
        end

        function linkSelectedNodeFromLibrary(app)
            if isempty(app.SelectedModules)
                uialert(app.UIFigure, 'Select a node in the pipeline first.', 'No node selected', 'Icon', 'info');
                return;
            end
            row = app.SelectedLibraryRow;
            if isnan(row) || row < 1 || row > numel(app.LibraryEntries)
                uialert(app.UIFigure, 'Select a module in the library first.', 'No library module selected', 'Icon', 'info');
                return;
            end

            idx = app.SelectedModules(1);
            if idx < 1 || idx > numel(app.Data.nodes)
                return;
            end

            entry = app.LibraryEntries(row);
            cur = app.Data.nodes(idx);
            refNode = normalizeLibraryNode(app, entry.node);
            if ~strcmpi(char(string(cur.type)), char(string(refNode.type)))
                uialert(app.UIFigure, ...
                    sprintf('Selected node is %s but library module is %s. Link only modules of the same type.', ...
                    char(string(cur.type)), char(string(refNode.type))), ...
                    'Type mismatch', 'Icon', 'warning');
                return;
            end

            keep = struct( ...
                'id', getfielddefault(app, cur, 'id', ''), ...
                'name', getfielddefault(app, cur, 'name', ''), ...
                'layout', getfielddefault(app, cur, 'layout', [0 0 20 10]), ...
                'enabled', getfielddefault(app, cur, 'enabled', true), ...
                'status', '');
            refNode.id = keep.id;
            refNode.name = keep.name;
            refNode.layout = keep.layout;
            refNode.enabled = keep.enabled;
            refNode.status = keep.status;
            if ~isfield(refNode, 'params') || ~isstruct(refNode.params)
                refNode.params = struct();
            end
            refNode.params.linkSource = entry.source;

            app.Data.nodes(idx) = refNode;
            redrawModule(app, idx);
            updateModuleListTable(app);
            updateParamsTable(app, idx);
            rememberLibraryEntry(app, entry);
            refreshStatus(app);
        end

        function saveSelectedNodeToOfflineLibrary(app)
            if isempty(app.SelectedModules)
                uialert(app.UIFigure, 'Select a node in the pipeline first.', 'No node selected', 'Icon', 'info');
                return;
            end
            idx = app.SelectedModules(1);
            if idx < 1 || idx > numel(app.Data.nodes)
                return;
            end
            rememberNodeInOfflineLibrary(app, app.Data.nodes(idx), 'offline library');
            updateModuleLibraryTable(app);
        end

        function unlinkSelectedNodeReference(app)
            if isempty(app.SelectedModules)
                uialert(app.UIFigure, 'Select a node in the pipeline first.', 'No node selected', 'Icon', 'info');
                return;
            end
            idx = app.SelectedModules(1);
            node = app.Data.nodes(idx);
            if ~isfield(node, 'params') || ~isstruct(node.params)
                return;
            end
            drop = {'modulePath','moduleId','moduleVar','moduleKind','linkSource'};
            for i = 1:numel(drop)
                if isfield(node.params, drop{i})
                    node.params = rmfield(node.params, drop{i});
                end
            end
            node.importMode = 'configured_copy';
            app.Data.nodes(idx) = node;
            markDirty(app, true);
            updateModuleListTable(app);
            updateParamsTable(app, idx);
            refreshStatus(app);
        end

        function convertNodeToLocalCopy(app, idx)
            if idx < 1 || idx > numel(app.Data.nodes)
                return;
            end
            node = app.Data.nodes(idx);
            if ~nodeHasReference(app, node)
                return;
            end
            node = stripNodeReference(app, node);
            app.Data.nodes(idx) = node;
            markDirty(app, true);
            redrawModule(app, idx);
            updateModuleListTable(app);
            if ismember(idx, app.SelectedModules)
                updateParamsTable(app, idx);
            end
            refreshStatus(app);
        end

        function node = buildConfiguredCopyImportedNode(app, sourceNode)
            node = sourceNode;
            node = attachImportOrigin(app, node);
            node = stripNodeReference(app, node);
            node = resetImportSensitiveSelectors(app, node);
            node.importMode = 'configured_copy';
        end

        function node = attachImportOrigin(app, node)
            if ~isstruct(node)
                return;
            end
            [refPath, refId, refKind] = extractNodeReference(app, node);
            if isempty(refPath) && isempty(refId)
                return;
            end
            node.origin = struct( ...
                'path', char(string(refPath)), ...
                'id', char(string(refId)), ...
                'kind', char(string(refKind)));
        end

        function node = stripNodeReference(app, node)
            if ~isfield(node,'params') || ~isstruct(node.params)
                node.params = struct();
                return;
            end
            drop = intersect(fieldnames(node.params), {'modulePath','moduleId','moduleVar','moduleKind','linkSource'});
            if ~isempty(drop)
                node.params = rmfield(node.params, drop);
            end
            if isfield(node,'importMode')
                node.importMode = 'configured_copy';
            end
        end

        function node = resetImportSensitiveSelectors(app, node)
            if ~isfield(node,'params') || ~isstruct(node.params)
                return;
            end
            if requiresSingleExplicitChannel(app, node)
                drop = intersect(fieldnames(node.params), {'channel','channels'});
                if ~isempty(drop)
                    node.params = rmfield(node.params, drop);
                end
            end
        end

        function tf = nodeHasReference(app, node)
            [refPath, refId, ~] = extractNodeReference(app, node);
            tf = ~isempty(refPath) || ~isempty(refId);
        end

        function [refPath, refId, refKind] = extractNodeOrigin(app, node) %#ok<INUSD>
            refPath = '';
            refId = '';
            refKind = '';
            if ~isstruct(node) || ~isfield(node, 'origin') || ~isstruct(node.origin)
                return;
            end
            if isfield(node.origin, 'path') && ~isempty(node.origin.path)
                refPath = char(string(node.origin.path));
            end
            if isfield(node.origin, 'id') && ~isempty(node.origin.id)
                refId = char(string(node.origin.id));
            end
            if isfield(node.origin, 'kind') && ~isempty(node.origin.kind)
                refKind = char(string(node.origin.kind));
            end
        end

        function layout = getNextLibraryDropLayout(app)
            w = 28;
            h = 15;
            if isempty(app.Data.nodes)
                layout = [32 12 w h];
                return;
            end

            xVals = zeros(1, numel(app.Data.nodes));
            yVals = zeros(1, numel(app.Data.nodes));
            for ii = 1:numel(app.Data.nodes)
                lay = getfielddefault(app, app.Data.nodes(ii), 'layout', [32 12 w h]);
                xVals(ii) = double(lay(1));
                yVals(ii) = double(lay(2));
            end
            x = max(28, min(75, max(xVals) - 6));
            y = max(6, min(84, max(yVals) + 6));
            layout = [x y w h];
        end

        function id = nextModuleId(app, typeName)
            base = lower(char(string(typeName)));
            app.ModuleIdCounter = max(app.ModuleIdCounter, numel(app.Data.nodes));
            while true
                app.ModuleIdCounter = app.ModuleIdCounter + 1;
                id = sprintf('%s_%d', base, app.ModuleIdCounter);
                if isempty(app.Data.nodes) || ~any(strcmp({app.Data.nodes.id}, id))
                    return;
                end
            end
        end

        function nameOut = nextModuleName(app, baseName)
            nameOut = char(string(baseName));
            if isempty(app.Data.nodes)
                return;
            end
            existing = cellstr(string({app.Data.nodes.name}));
            if ~any(strcmp(existing, nameOut))
                return;
            end
            root = nameOut;
            k = 2;
            while any(strcmp(existing, sprintf('%s_copy%d', root, k)))
                k = k + 1;
            end
            nameOut = sprintf('%s_copy%d', root, k);
        end

        function layout = normalizeModuleLayout(app, node, layoutIn)
            c = getNodeContract(app, node);
            rowCount = max([numel(c.in), numel(c.out), 1]);
            minW = 28;
            minH = 9.5 + 3.0 * rowCount;

            if nargin >= 3 && ~isempty(layoutIn)
                layout = layoutIn;
            else
                layout = getfielddefault(app, node, 'layout', [0 0 minW minH]);
            end
            if numel(layout) < 4
                layout = [layout(1:min(end,2)) minW minH];
            end
            if numel(layout) < 4
                layout = [0 0 minW minH];
            end

            layout = double(layout(:)');
            layout(3) = max(layout(3), minW);
            layout(4) = max(layout(4), minH);
        end

        function txt = buildPortDisplayText(app, node, isOut, portName)
            c = getNodeContract(app, node);
            txt = normalizePortDisplayName(app, portName);
            qualifier = '';

            if ~isOut
                req = getfielddefault(app, c, 'requirements', struct());
                switch lower(char(string(portName)))
                    case 'images'
                        qualifier = formatCountQualifier(app, getfielddefault(app, getfielddefault(app, req, 'images', struct()), 'channelsMin', 0));
                    case 'roilist'
                        roiReq = getfielddefault(app, req, 'roi', struct());
                        if isstruct(roiReq)
                            parts = {};
                            n = double(getfielddefault(app, roiReq, 'channelsMin', 0));
                            if n > 0
                                parts{end+1} = num2str(round(n)); %#ok<AGROW>
                            end
                            if logical(getfielddefault(app, roiReq, 'masks', false))
                                parts{end+1} = 'masks'; %#ok<AGROW>
                            end
                            if logical(getfielddefault(app, roiReq, 'dataSeries', false))
                                parts{end+1} = 'data'; %#ok<AGROW>
                            end
                            qualifier = strjoin(parts, ', ');
                        end
                end
            else
                switch lower(char(string(portName)))
                    case 'channels'
                        qualifier = inferChannelQualifierFromNode(app, node);
                end
            end

            if ~isempty(qualifier)
                txt = sprintf('%s (%s)', txt, qualifier);
            end
        end

        function nameOut = normalizePortDisplayName(app, portName) %#ok<INUSD>
            key = lower(char(string(portName)));
            switch key
                case 'images'
                    nameOut = 'Images';
                case 'roilist'
                    nameOut = 'ROI List';
                case 'channels'
                    nameOut = 'Channels';
                case 'dataseries'
                    nameOut = 'Data Series';
                case 'fovlist'
                    nameOut = 'FOV List';
                case 'masks'
                    nameOut = 'Masks';
                case 'inputchannels'
                    nameOut = 'Channels';
                otherwise
                    nameOut = char(string(portName));
            end
        end

        function qualifier = formatCountQualifier(app, count) %#ok<INUSD>
            qualifier = '';
            try
                count = double(count);
            catch
                count = 0;
            end
            if ~isfinite(count) || count <= 1
                return;
            end
            qualifier = num2str(round(count));
        end

        function qualifier = inferChannelQualifierFromNode(app, node) %#ok<INUSD>
            qualifier = '';
            params = getfielddefault(app, node, 'params', struct());
            if ~isstruct(params)
                return;
            end

            if isfield(params, 'channels')
                qualifier = countSelectionValues(app, params.channels);
                if ~isempty(qualifier)
                    return;
                end
            end
            if isfield(params, 'channel')
                qualifier = countSelectionValues(app, params.channel);
            end
        end

        function qualifier = countSelectionValues(app, value) %#ok<INUSD>
            qualifier = '';
            if isempty(value)
                return;
            end

            if isnumeric(value)
                if isscalar(value)
                    return;
                end
                qualifier = num2str(numel(value));
                return;
            end

            if isstring(value)
                value = cellstr(value);
            end
            if iscell(value)
                if numel(value) <= 1
                    return;
                end
                qualifier = num2str(numel(value));
                return;
            end

            s = strtrim(char(string(value)));
            if isempty(s) || any(strcmpi(s, {'all','*',':'}))
                return;
            end

            if contains(s, ',')
                parts = strtrim(strsplit(s, ','));
                parts = parts(~cellfun(@isempty, parts));
                if numel(parts) > 1
                    qualifier = num2str(numel(parts));
                end
            end
        end

        function tf = isChannelSelectorParam(app, node, key) %#ok<INUSD>
            tf = false;
            if ~isstruct(node)
                return;
            end
            key = lower(strtrim(char(string(key))));
            if ~any(strcmp(key, {'channel','channels'}))
                return;
            end
            params = struct();
            if isfield(node,'params') && isstruct(node.params)
                params = node.params;
            end
            if isfield(params, key)
                tf = true;
                return;
            end
            if strcmp(key, 'channel') && requiresSingleExplicitChannel(app, node)
                tf = true;
            end
        end

        function [newVal, applied] = chooseChannelSelectorForNode(app, node, key)
            newVal = [];
            applied = false;

            choices = getNodeSelectableChannels(app, node);
            if isempty(choices)
                return;
            end

            key = lower(strtrim(char(string(key))));
            allowMulti = strcmp(key, 'channels') && ~requiresSingleExplicitChannel(app, node);

            currentVal = [];
            if isfield(node,'params') && isstruct(node.params) && isfield(node.params, key)
                currentVal = node.params.(key);
            end
            initialNames = normalizeChannelChoiceList(app, currentVal);
            initialIdx = find(ismember(lower(choices), lower(initialNames)));
            if isempty(initialIdx) && ~isempty(choices)
                initialIdx = 1;
            end

            prompt = 'Select input channel';
            titleText = 'Choose channel';
            mode = 'single';
            if allowMulti
                prompt = 'Select input channels';
                titleText = 'Choose channels';
                mode = 'multiple';
            end

            [sel, ok] = listdlg( ...
                'ListString', choices, ...
                'SelectionMode', mode, ...
                'InitialValue', initialIdx, ...
                'PromptString', prompt, ...
                'Name', titleText);
            if ~ok || isempty(sel)
                return;
            end

            picked = choices(sel);
            if allowMulti
                newVal = picked(:)';
            else
                newVal = picked{1};
            end
            applied = true;
        end

        function names = getNodeSelectableChannels(app, nodeOrIdx)
            names = {};

            if isnumeric(nodeOrIdx)
                idx = double(nodeOrIdx);
                if idx < 1 || idx > numel(app.Data.nodes)
                    return;
                end
                node = app.Data.nodes(idx);
            else
                node = nodeOrIdx;
                idx = find(strcmp(cellstr(string({app.Data.nodes.id})), char(string(getfielddefault(app, node, 'id', '')))), 1, 'first');
            end

            names = mergeChannelChoiceLists(app, names, getContextChannelChoices(app));
            names = mergeChannelChoiceLists(app, names, getNodeLocalChannelHints(app, node));

            if ~isempty(idx)
                upstreamIdx = getUpstreamNodeIndices(app, idx);
                for ii = 1:numel(upstreamIdx)
                    upNode = app.Data.nodes(upstreamIdx(ii));
                    names = mergeChannelChoiceLists(app, names, getNodeLocalChannelHints(app, upNode));
                end
            end
        end

        function names = getContextChannelChoices(app)
            names = {};
            ctx = app.Context;
            if ~isstruct(ctx)
                return;
            end

            if isfield(ctx,'channels') && ~isempty(ctx.channels)
                names = mergeChannelChoiceLists(app, names, ctx.channels);
            end

            try
                if isfield(ctx,'fovList') && ~isempty(ctx.fovList)
                    f0 = ctx.fovList(1);
                    if isprop(f0,'channel') && ~isempty(f0.channel)
                        names = mergeChannelChoiceLists(app, names, f0.channel);
                    elseif isfield(f0,'channel') && ~isempty(f0.channel)
                        names = mergeChannelChoiceLists(app, names, f0.channel);
                    end
                end
            catch
            end

            try
                shallowObj = [];
                if isfield(ctx,'shallow') && ~isempty(ctx.shallow)
                    shallowObj = ctx.shallow;
                elseif isfield(ctx,'shallowObj') && ~isempty(ctx.shallowObj)
                    shallowObj = ctx.shallowObj;
                end
                if ~isempty(shallowObj) && isprop(shallowObj,'fov') && ~isempty(shallowObj.fov)
                    f0 = shallowObj.fov(1);
                    if isprop(f0,'channel') && ~isempty(f0.channel)
                        names = mergeChannelChoiceLists(app, names, f0.channel);
                    end
                end
            catch
            end
        end

        function names = getNodeLocalChannelHints(app, node)
            names = {};
            params = getfielddefault(app, node, 'params', struct());
            if ~isstruct(params)
                return;
            end

            probeFields = {'channel','channels','channelFilter','channelName'};
            for ii = 1:numel(probeFields)
                key = probeFields{ii};
                if isfield(params, key) && ~isempty(params.(key))
                    names = mergeChannelChoiceLists(app, names, params.(key));
                end
            end
        end

        function idxList = getUpstreamNodeIndices(app, idx)
            idxList = [];
            if idx < 1 || idx > numel(app.Data.nodes) || isempty(app.Data.edges)
                return;
            end

            targetId = char(string(app.Data.nodes(idx).id));
            visited = false(1, numel(app.Data.nodes));
            stack = {targetId};

            while ~isempty(stack)
                curId = stack{1};
                stack(1) = [];
                for ee = 1:numel(app.Data.edges)
                    ed = app.Data.edges(ee);
                    if ~strcmp(getEdgeField(app, ed, 'to', ''), curId)
                        continue;
                    end
                    srcId = char(string(getEdgeField(app, ed, 'from', '')));
                    srcIdx = find(strcmp(cellstr(string({app.Data.nodes.id})), srcId), 1, 'first');
                    if isempty(srcIdx) || visited(srcIdx)
                        continue;
                    end
                    visited(srcIdx) = true;
                    idxList(end+1) = srcIdx; %#ok<AGROW>
                    stack{end+1} = srcId; %#ok<AGROW>
                end
            end
        end

        function names = mergeChannelChoiceLists(app, a, b) %#ok<INUSD>
            names = unique([normalizeChannelChoiceList(app, a), normalizeChannelChoiceList(app, b)], 'stable');
        end

        function names = normalizeChannelChoiceList(app, v) %#ok<INUSD>
            names = {};
            if isempty(v)
                return;
            end

            if ischar(v) || (isstring(v) && isscalar(v))
                s = strtrim(char(string(v)));
                if isempty(s) || isAllChannelToken(app, s)
                    return;
                end
                if startsWith(s, '[') && endsWith(s, ']')
                    try
                        tmp = jsondecode(s);
                        names = normalizeChannelChoiceList(app, tmp);
                        return;
                    catch
                    end
                end
                if contains(s, ',')
                    parts = strtrim(strsplit(s, ','));
                    parts = parts(~cellfun(@isempty, parts));
                    for ii = 1:numel(parts)
                        if ~isAllChannelToken(app, parts{ii})
                            names{end+1} = parts{ii}; %#ok<AGROW>
                        end
                    end
                    names = unique(names, 'stable');
                    return;
                end
                names = {s};
                return;
            end

            if isstring(v)
                names = normalizeChannelChoiceList(app, cellstr(v(:)'));
                return;
            end

            if iscell(v)
                tmp = {};
                for ii = 1:numel(v)
                    tmp = [tmp normalizeChannelChoiceList(app, v{ii})]; %#ok<AGROW>
                end
                names = unique(tmp, 'stable');
                return;
            end

            if isnumeric(v)
                vals = double(v(:)');
                vals = vals(isfinite(vals));
                for ii = 1:numel(vals)
                    names{end+1} = num2str(vals(ii)); %#ok<AGROW>
                end
                names = unique(names, 'stable');
            end
        end

        function tf = isAllChannelToken(app, s) %#ok<INUSD>
            s = lower(strtrim(char(string(s))));
            tf = any(strcmp(s, {'all','*',':'}));
        end

        function tf = requiresSingleExplicitChannel(app, node) %#ok<INUSD>
            if ~strcmpi(char(string(getfielddefault(app, node, 'type', ''))), 'classifier')
                tf = false;
                return;
            end
            pkg = lower(char(string(getfielddefault(app, node, 'pkg', ''))));
            tf = any(strcmp(pkg, {'cellposesam','cnn_lstm'}));
        end

        function issue = getCustomNodeValidationIssue(app, node)
            issue = '';
            if ~requiresSingleExplicitChannel(app, node)
                return;
            end

            params = getfielddefault(app, node, 'params', struct());
            if ~isstruct(params)
                issue = 'Choose exactly 1 input channel';
                return;
            end

            if isfield(params,'channel') && ~isempty(params.channel)
                selected = normalizeChannelChoiceList(app, params.channel);
                usedKey = 'channel';
            elseif isfield(params,'channels') && ~isempty(params.channels)
                selected = normalizeChannelChoiceList(app, params.channels);
                usedKey = 'channels';
            else
                selected = {};
                usedKey = '';
            end

            if isempty(selected)
                rawSelection = [];
                if ~isempty(usedKey) && isfield(params, usedKey)
                    rawSelection = params.(usedKey);
                end
                rawNames = normalizeChannelChoiceList(app, rawSelection);
                if isempty(rawNames) && (ischar(rawSelection) || (isstring(rawSelection) && isscalar(rawSelection))) && ...
                        isAllChannelToken(app, rawSelection)
                    issue = 'Choose 1 input channel, not "all"';
                else
                    issue = 'Choose exactly 1 input channel';
                end
                return;
            end

            if numel(selected) ~= 1
                issue = 'Choose exactly 1 input channel';
                return;
            end

            available = getNodeSelectableChannels(app, node);
            if ~isempty(available) && ~any(strcmpi(selected{1}, available))
                issue = ['Unknown input channel: ' selected{1}];
            end
        end

        function col = getPortDisplayColor(app, idx, isOut, portName)
            node = app.Data.nodes(idx);
            if ~getfielddefault(app, node, 'enabled', true)
                col = [0.60 0.60 0.60];
                return;
            end

            if isOut
                col = [0.12 0.78 0.24];
                return;
            end

            nodeId = char(string(getfielddefault(app, node, 'id', '')));
            tf = false;
            for ii = 1:numel(app.Data.edges)
                e = app.Data.edges(ii);
                if strcmp(getEdgeField(app, e, 'to', ''), nodeId) && strcmp(getEdgeField(app, e, 'toPort', ''), char(string(portName)))
                    tf = true;
                    break;
                end
            end

            if tf
                col = [0.12 0.78 0.24];
            else
                col = [0.90 0.12 0.12];
            end
        end

        function pkgName = inferPkgFromFunction(app, funName, suffix) %#ok<INUSD>
            pkgName = '';
            funName = char(string(funName));
            suffix = char(string(suffix));
            if isempty(funName)
                return;
            end
            token = regexp(funName, ['^([A-Za-z]\\w*)\\.' suffix '$'], 'tokens', 'once');
            if isempty(token)
                return;
            end
            pkgName = token{1};
        end

        function val = getObjectFieldDefault(app, obj, name, default) %#ok<INUSD>
            try
                if isstruct(obj) && isfield(obj, name)
                    val = obj.(name);
                    return;
                end
                if isobject(obj) && isprop(obj, name)
                    val = obj.(name);
                    return;
                end
            catch
            end
            val = default;
        end

        function refreshPackageColumnForRow(app, row)
            list = {'<none>'};
            if nargin >= 2 && row >= 1 && row <= numel(app.Data.nodes)
                t = lower(char(string(app.Data.nodes(row).type)));
                switch t
                    case 'processor'
                        list = getProcessorPackageList(app);
                        list = list(~cellfun(@isempty, list));
                        list = unique(list, 'stable');
                        list = [{'<none>'} list(:)'];
                    case 'classifier'
                        list = getClassifierPackageList(app);
                        list = list(~cellfun(@isempty, list));
                        list = unique(list, 'stable');
                        list = [{'<none>'} list(:)'];
                    otherwise
                        if isBuiltinNodeType(app, t)
                            list = {'builtin'};
                        else
                            list = {'<none>'};
                        end
                end
            end

            fmt = app.UIModuleListTable.ColumnFormat;
            fmt{3} = list;
            app.UIModuleListTable.ColumnFormat = fmt;
        end

        function updateParamsTable(app, idx)
            if idx > numel(app.Data.nodes)
                app.UIModuleParametersTable.Data = {};
                return;
            end
            node = app.Data.nodes(idx);
            data = {};
            if isfield(node,'params') && ~isempty(node.params)
                fn = fieldnames(node.params);
                data = cell(numel(fn),2);
                for i = 1:numel(fn)
                    data{i,1} = fn{i};
                    data{i,2} = toUITableCellValue(app, paramValueToTableCell(app, node.params.(fn{i})));
                end
            end
            data = injectExpectedSelectorRows(app, node, data);
            availableChannels = getNodeSelectableChannels(app, node);
            if ~isempty(availableChannels)
                data(end+1,:) = {'[contract] available channels', strjoin(availableChannels, ', ')}; %#ok<AGROW>
            elseif requiresSingleExplicitChannel(app, node)
                data(end+1,:) = {'[contract] available channels', '<unknown until data are loaded>'}; %#ok<AGROW>
            end
            data = [data; buildLinkedModuleRows(app, node); buildContractTableRows(app, node)];
            app.UIModuleParametersTable.Data = data;
        end

        function data = injectExpectedSelectorRows(app, node, data)
            if nargin < 3 || isempty(data)
                data = cell(0,2);
            end

            if requiresSingleExplicitChannel(app, node)
                keys = lower(string(data(:,1)));
                if ~any(keys == "channel")
                    defaultVal = '';
                    params = getfielddefault(app, node, 'params', struct());
                    if isstruct(params)
                        if isfield(params,'channel') && ~isempty(params.channel)
                            defaultVal = params.channel;
                        elseif isfield(params,'channels') && ~isempty(params.channels)
                            ch = normalizeChannelChoiceList(app, params.channels);
                            if ~isempty(ch)
                                defaultVal = ch{1};
                            end
                        end
                    end
                    data(end+1,:) = {'channel', toUITableCellValue(app, paramValueToTableCell(app, defaultVal))}; %#ok<AGROW>
                end
            end
        end

        function tf = isReadOnlyParamKey(app, key) %#ok<INUSD>
            key = char(string(key));
            tf = startsWith(key, '[contract]') || startsWith(key, '[link]');
        end

        function rows = buildLinkedModuleRows(app, node)
            rows = cell(0,2);
            [refPath, refId, refKind] = extractNodeReference(app, node);
            if isempty(refPath) && isempty(refId)
                return;
            end
            rows(end+1,:) = {'[link] mode', 'Reference with local pipeline overrides'}; %#ok<AGROW>
            if ~isempty(refKind)
                rows(end+1,:) = {'[link] kind', refKind}; %#ok<AGROW>
            end
            if ~isempty(refId)
                rows(end+1,:) = {'[link] source id', refId}; %#ok<AGROW>
            end
            if ~isempty(refPath)
                rows(end+1,:) = {'[link] source folder', refPath}; %#ok<AGROW>
            end
            if isfield(node, 'params') && isstruct(node.params) && isfield(node.params, 'linkSource') && ~isempty(node.params.linkSource)
                srcEntry = char(string(node.params.linkSource));
                if ~contains(lower(srcEntry), 'offline library')
                    rows(end+1,:) = {'[link] source entry', srcEntry}; %#ok<AGROW>
                end
            end
        end

        function rows = buildContractTableRows(app, node)
            rows = cell(0,2);
            c = getNodeContract(app, node);
            if isempty(c) || ~isstruct(c)
                return;
            end

            rows(end+1,:) = {'[contract] summary', summarizeContract(app, c)}; %#ok<AGROW>
            rows(end+1,:) = {'[contract] support', formatContractSupport(app, c)}; %#ok<AGROW>

            reqText = formatContractRequirements(app, c);
            if ~isempty(reqText)
                rows(end+1,:) = {'[contract] requires', reqText}; %#ok<AGROW>
            end

            selText = formatContractSelectors(app, c);
            if ~isempty(selText)
                rows(end+1,:) = {'[contract] selectors', selText}; %#ok<AGROW>
            end

            capText = formatContractCapabilities(app, c);
            if ~isempty(capText)
                rows(end+1,:) = {'[contract] produces', capText}; %#ok<AGROW>
            end
        end

        function txt = summarizeContract(app, c) %#ok<INUSD>
            txt = char(string(getfielddefault(app, c, 'summary', '')));
            if isempty(strtrim(txt))
                txt = 'No semantic summary.';
            end
        end

        function txt = formatContractSupport(app, c) %#ok<INUSD>
            parts = {};
            if isfield(c,'in') && ~isempty(c.in)
                parts{end+1} = ['in: ' strjoin({c.in.name}, ', ')]; %#ok<AGROW>
            end
            if isfield(c,'out') && ~isempty(c.out)
                parts{end+1} = ['out: ' strjoin({c.out.name}, ', ')]; %#ok<AGROW>
            end
            txt = strjoin(parts, ' | ');
        end

        function txt = formatContractRequirements(app, c) %#ok<INUSD>
            txt = '';
            if ~isfield(c,'requirements') || ~isstruct(c.requirements)
                return;
            end
            req = c.requirements;
            parts = {};

            if isfield(req,'images') && isstruct(req.images) && logical(getfielddefault(app, req.images, 'required', false))
                n = double(getfielddefault(app, req.images, 'channelsMin', 0));
                if n > 0
                    parts{end+1} = sprintf('images with >=%d channel(s)', n); %#ok<AGROW>
                else
                    parts{end+1} = 'images'; %#ok<AGROW>
                end
            end

            if isfield(req,'roi') && isstruct(req.roi) && logical(getfielddefault(app, req.roi, 'required', false))
                sub = {'roiList'};
                n = double(getfielddefault(app, req.roi, 'channelsMin', 0));
                if n > 0
                    sub{end+1} = sprintf('>= %d ROI channel(s)', n); %#ok<AGROW>
                end
                if logical(getfielddefault(app, req.roi, 'masks', false))
                    sub{end+1} = 'masks'; %#ok<AGROW>
                end
                if logical(getfielddefault(app, req.roi, 'dataSeries', false))
                    sub{end+1} = 'dataSeries'; %#ok<AGROW>
                end
                parts{end+1} = strjoin(sub, ', '); %#ok<AGROW>
            end

            if isfield(req,'params') && isstruct(req.params)
                pReq = getfielddefault(app, req.params, 'required', {});
                if ~isempty(pReq)
                    parts{end+1} = ['params: ' strjoin(cellstr(string(pReq)), ', ')]; %#ok<AGROW>
                end
            end

            txt = strjoin(parts, ' | ');
        end

        function txt = formatContractSelectors(app, c) %#ok<INUSD>
            txt = '';
            if ~isfield(c,'selectors') || ~isstruct(c.selectors)
                return;
            end
            s = c.selectors;
            parts = {};

            if ~isempty(getfielddefault(app, s, 'channelParam', ''))
                parts{end+1} = ['channel=' char(string(s.channelParam))]; %#ok<AGROW>
            end
            if ~isempty(getfielddefault(app, s, 'channelsParam', ''))
                parts{end+1} = ['channels=' char(string(s.channelsParam))]; %#ok<AGROW>
            end
            if ~isempty(getfielddefault(app, s, 'framesParam', ''))
                parts{end+1} = ['frames=' char(string(s.framesParam))]; %#ok<AGROW>
            end
            if ~isempty(getfielddefault(app, s, 'outputNameParam', ''))
                parts{end+1} = ['output=' char(string(s.outputNameParam))]; %#ok<AGROW>
            end
            if isfield(s,'defaultChannels') && ~isempty(s.defaultChannels)
                parts{end+1} = ['default channels: ' strjoin(cellstr(string(s.defaultChannels)), ', ')]; %#ok<AGROW>
            end
            txt = strjoin(parts, ' | ');
        end

        function txt = formatContractCapabilities(app, c) %#ok<INUSD>
            txt = '';
            if ~isfield(c,'capabilities') || ~isstruct(c.capabilities)
                return;
            end
            cap = c.capabilities;
            parts = {};

            if logical(getfielddefault(app, cap, 'createsRoiList', false))
                parts{end+1} = 'create ROI'; %#ok<AGROW>
            end
            if logical(getfielddefault(app, cap, 'preservesRoiList', false))
                parts{end+1} = 'preserve ROI'; %#ok<AGROW>
            end
            if logical(getfielddefault(app, cap, 'outputsChannels', false))
                parts{end+1} = 'channels'; %#ok<AGROW>
            end
            if logical(getfielddefault(app, cap, 'outputsMasks', false)) || logical(getfielddefault(app, cap, 'roiMasks', false))
                parts{end+1} = 'masks'; %#ok<AGROW>
            end
            if logical(getfielddefault(app, cap, 'outputsDataSeries', false)) || logical(getfielddefault(app, cap, 'roiDataSeries', false))
                parts{end+1} = 'dataSeries'; %#ok<AGROW>
            end
            if logical(getfielddefault(app, cap, 'outputsFovList', false))
                parts{end+1} = 'fovList'; %#ok<AGROW>
            end

            txt = strjoin(parts, ', ');
        end

        function out = paramValueToTableCell(app, v) %#ok<INUSD>
            if ischar(v)
                out = v;
            elseif isstring(v)
                out = char(v);
            elseif islogical(v)
                if isscalar(v)
                    out = char(string(v));
                else
                    out = mat2str(v);
                end
            elseif isnumeric(v)
                if isempty(v)
                    out = '';
                elseif isscalar(v)
                    out = num2str(v);
                else
                    out = compactNumericDisplay(app, v);
                end
            elseif iscell(v) || isstruct(v)
                try
                    out = jsonencode(v);
                catch
                    try
                        out = evalc('disp(v)');
                        out = strtrim(out);
                    catch
                        out = class(v);
                    end
                end
            else
                try
                    out = char(string(v));
                catch
                    out = class(v);
                end
            end
        end

        function out = compactNumericDisplay(app, v) %#ok<INUSD>
            if ~isnumeric(v) || isempty(v)
                out = '';
                return;
            end

            if ~isvector(v)
                out = mat2str(v);
                return;
            end

            x = double(v(:)');
            if numel(x) <= 1
                out = num2str(x);
                return;
            end

            if all(isfinite(x))
                d = diff(x);
                if ~isempty(d) && all(abs(d - d(1)) < 1e-12)
                    step = d(1);
                    if abs(step - 1) < 1e-12
                        out = sprintf('%s:%s', num2str(x(1)), num2str(x(end)));
                        return;
                    end
                    out = sprintf('%s:%s:%s', num2str(x(1)), num2str(step), num2str(x(end)));
                    return;
                end

                if all(abs(x - round(x)) < 1e-12)
                    parts = {};
                    startVal = x(1);
                    prevVal = x(1);
                    for ii = 2:numel(x)
                        if abs(x(ii) - (prevVal + 1)) < 1e-12
                            prevVal = x(ii);
                            continue;
                        end
                        parts{end+1} = makeIntegerRunString(app, startVal, prevVal); %#ok<AGROW>
                        startVal = x(ii);
                        prevVal = x(ii);
                    end
                    parts{end+1} = makeIntegerRunString(app, startVal, prevVal); %#ok<AGROW>
                    if numel(parts) > 1
                        out = ['[' strjoin(parts, ' ') ']'];
                        return;
                    end
                end
            end

            out = mat2str(v);
        end

        function txt = makeIntegerRunString(app, a, b) %#ok<INUSD>
            if abs(a - b) < 1e-12
                txt = num2str(round(a));
            elseif abs(b - (a + 1)) < 1e-12
                txt = sprintf('%d %d', round(a), round(b));
            else
                txt = sprintf('%d:%d', round(a), round(b));
            end
        end

        function out = toUITableCellValue(app, v) %#ok<INUSD>
            if ischar(v) || isnumeric(v) || islogical(v)
                out = v;
                return;
            end
            if isstring(v)
                out = char(v);
                return;
            end
            try
                out = char(string(v));
            catch
                try
                    out = jsonencode(v);
                catch
                    out = class(v);
                end
            end
        end

        function tf = isNodeConnected(app, node)
            tf = true;
            c = getNodeContract(app, node);
            if ~isfield(c,'in') || isempty(c.in)
                return;
            end

            nodeId = char(string(node.id));
            for k = 1:numel(c.in)
                pin = c.in(k);
                if ~isfield(pin,'required') || ~logical(pin.required)
                    continue;
                end
                srcMode = 'edge';
                if isfield(pin,'source') && ~isempty(pin.source)
                    srcMode = lower(char(string(pin.source)));
                end
                if strcmp(srcMode,'ctx')
                    continue;
                end
                pname = char(string(pin.name));
                ok = false;
                for e = 1:numel(app.Data.edges)
                    ed = app.Data.edges(e);
                    if ~strcmp(getEdgeField(app, ed, 'to', ''), nodeId)
                        continue;
                    end
                    if strcmp(getEdgeField(app, ed, 'toPort', ''), pname)
                        ok = true;
                        break;
                    end
                end
                if ~ok
                    tf = false;
                    return;
                end
            end
        end

        function out = parseParamValueFromTable(app, raw, oldVal) %#ok<INUSD>
            if isstring(raw)
                raw = char(raw);
            end

            if islogical(oldVal)
                s = lower(strtrim(char(string(raw))));
                out = any(strcmp(s, {'1','true','yes','on'}));
                return;
            end

            if isnumeric(oldVal)
                s = strtrim(char(string(raw)));
                if isempty(s)
                    out = oldVal;
                    return;
                end
                if isscalar(oldVal)
                    z = str2double(s);
                    if isnan(z)
                        out = oldVal;
                    else
                        out = z;
                    end
                else
                    z = str2num(s); %#ok<ST2NM>
                    if isempty(z)
                        out = oldVal;
                    else
                        out = z;
                    end
                end
                return;
            end

            if isstruct(oldVal) || iscell(oldVal)
                s = char(string(raw));
                try
                    out = jsondecode(s);
                catch
                    out = oldVal;
                end
                return;
            end

            out = char(string(raw));
        end

        function commitVisibleParamTable(app)
            if isempty(app.SelectedModules)
                return;
            end
            modIdx = app.SelectedModules(1);
            if modIdx < 1 || modIdx > numel(app.Data.nodes)
                return;
            end

            data = app.UIModuleParametersTable.Data;
            if isempty(data)
                return;
            end

            node = app.Data.nodes(modIdx);
            if ~isfield(node,'params') || isempty(node.params) || ~isstruct(node.params)
                node.params = struct();
            end

            for row = 1:size(data,1)
                key = char(string(data{row,1}));
                if isempty(key) || isReadOnlyParamKey(app, key)
                    continue;
                end
                rawVal = data{row,2};
                oldVal = '';
                if isfield(node.params, key)
                    oldVal = node.params.(key);
                end
                node.params.(key) = parseParamValueFromTable(app, rawVal, oldVal);
            end

            app.Data.nodes(modIdx) = node;
        end

        function refreshStatus(app, showAlert)
            if nargin < 2
                showAlert = false;
            end

            if isempty(app.Data.nodes)
                setCheckPipelineVisualState(app, false);
                updateModuleListTable(app);
                app.UIModuleParametersTable.Data = {};
                return;
            end

            pipe = buildPipelineStruct(app, true);
            ctx = app.Context;
            try
                [ok, report] = runPipelineDry(pipe, ctx, struct('allowGui', false));
            catch
                ok = false;
                report = struct('errors',{{'Validation error'}},'missingParams',[]);
            end

            [okPorts, portReport] = validatePortContracts(app, pipe, ctx);

            missingMap = containers.Map();
            deferredMap = containers.Map();
            if isfield(report,'missingParams') && ~isempty(report.missingParams)
                for i = 1:numel(report.missingParams)
                    entry = report.missingParams{i};
                    missingMap(entry.node) = entry.missing;
                end
            end
            if isfield(report,'deferredParams') && ~isempty(report.deferredParams)
                for i = 1:numel(report.deferredParams)
                    entry = report.deferredParams{i};
                    deferredMap(entry.node) = entry.missing;
                end
            end
            semanticHints = extractSemanticHints(app, report);
            customIssueMap = containers.Map('KeyType','char','ValueType','char');
            customErrors = {};

            nodes = app.Data.nodes;
            if isempty(nodes)
                return;
            end
            if ~isfield(nodes,'status')
                [nodes.status] = deal('');
            end
            if ~isfield(nodes,'enabled')
                [nodes.enabled] = deal(true);
            end

            for i = 1:numel(nodes)
                node = nodes(i);
                nodeId = char(string(node.id));
                customIssue = getCustomNodeValidationIssue(app, node);
                if ~isempty(customIssue)
                    customIssueMap(nodeId) = customIssue;
                    customErrors{end+1} = ['Node ' nodeId ': ' customIssue]; %#ok<AGROW>
                end
                if ~getfielddefault(app, node,'enabled',true)
                    node.status = 'Disabled';
                elseif isKey(portReport.nodeIssues, nodeId)
                    msgs = portReport.nodeIssues(nodeId);
                    node.status = ['Contract: ' msgs{1}];
                elseif isKey(missingMap, nodeId)
                    miss = missingMap(nodeId);
                    node.status = ['Missing: ' strjoin(miss, ', ')];
                elseif isKey(deferredMap, nodeId)
                    miss = deferredMap(nodeId);
                    node.status = ['Deferred: ' strjoin(miss, ', ')];
                elseif isKey(customIssueMap, nodeId)
                    node.status = ['Missing: ' customIssueMap(nodeId)];
                elseif isKey(semanticHints, nodeId)
                    node.status = semanticHints(nodeId);
                else
                    node.status = 'OK';
                end
                node.status = decorateNodeStatus(app, node);
                nodes(i) = node;
            end

            app.Data.nodes = nodes;
            updateModuleListTable(app);
            if ~isempty(app.SelectedModules)
                try
                    updateParamsTable(app, app.SelectedModules(1));
                catch
                end
            end
            for ii = 1:numel(app.Data.nodes)
                redrawModule(app, ii);
            end

            hasBlockingError = ~(ok && okPorts) || ~isempty(customErrors);
            setCheckPipelineVisualState(app, ~hasBlockingError);

            if showAlert
                errs = {};
                warns = {};
                if isfield(report,'errors') && ~isempty(report.errors)
                    errs = [errs report.errors];
                end
                if isfield(portReport,'errors') && ~isempty(portReport.errors)
                    errs = [errs portReport.errors];
                end
                if ~isempty(customErrors)
                    errs = [errs customErrors];
                end
                if isfield(report,'warnings') && ~isempty(report.warnings)
                    warns = [warns report.warnings];
                end

                if ~isempty(errs)
                    msg = formatValidationMessage(app, errs, warns, false);
                    uialert(app.UIFigure, msg, 'Pipeline issues', 'Icon','warning');
                elseif ~isempty(warns)
                    msg = formatValidationMessage(app, {}, warns, true);
                    uialert(app.UIFigure, msg, 'Pipeline warnings', 'Icon','warning');
                else
                    msg = sprintf('Pipeline is valid. %d node(s), %d edge(s).', numel(pipe.nodes), numel(pipe.edges));
                    uialert(app.UIFigure, msg, 'Pipeline check', 'Icon','info');
                end
            end
        end

        function out = extractSemanticHints(app, report) %#ok<INUSD>
            out = containers.Map('KeyType','char','ValueType','char');
            if ~isstruct(report) || ~isfield(report,'semantic') || ~isstruct(report.semantic)
                return;
            end
            keys = fieldnames(report.semantic);
            for i = 1:numel(keys)
                sem = report.semantic.(keys{i});
                if ~isstruct(sem)
                    continue;
                end
                label = '';
                reqCh = double(getfielddefault(app, sem, 'requiredChannels', 0));
                if reqCh > 0
                    label = sprintf('OK: needs %d ch', reqCh);
                end
                if logical(getfielddefault(app, sem, 'masksRequired', false))
                    if isempty(label)
                        label = 'OK: needs masks';
                    else
                        label = [label ', masks'];
                    end
                end
                if logical(getfielddefault(app, sem, 'dataSeriesRequired', false))
                    if isempty(label)
                        label = 'OK: needs dataSeries';
                    else
                        label = [label ', dataSeries'];
                    end
                end
                if isempty(label)
                    label = 'OK';
                end
                out(char(string(keys{i}))) = label;
            end
        end

        function msg = formatValidationMessage(app, errs, warns, noBlocking) %#ok<INUSD>
            lines = {};
            if nargin >= 4 && noBlocking
                lines{end+1} = 'No blocking error.'; %#ok<AGROW>
            end
            if ~isempty(errs)
                lines{end+1} = 'Errors:'; %#ok<AGROW>
                for i = 1:numel(errs)
                    lines{end+1} = ['- ' char(string(errs{i}))]; %#ok<AGROW>
                end
            end
            if ~isempty(warns)
                lines{end+1} = 'Warnings:'; %#ok<AGROW>
                for i = 1:numel(warns)
                    lines{end+1} = ['- ' char(string(warns{i}))]; %#ok<AGROW>
                end
            end
            msg = strjoin(lines, newline);
        end

        function idx = findEdgesBetween(app, fromId, toId)
            idx = [];
            if isempty(app.Data.edges)
                return;
            end
            for i = 1:numel(app.Data.edges)
                e = app.Data.edges(i);
                if strcmp(getEdgeField(app, e,'from',''), fromId) && strcmp(getEdgeField(app, e,'to',''), toId)
                    idx(end+1) = i; %#ok<AGROW>
                end
            end
        end

        function status = decorateNodeStatus(app, node) %#ok<INUSD>
            status = char(string(getfielddefault(app, node, 'status', '')));
            nodeType = char(string(getfielddefault(app, node, 'type', '')));
            params = getfielddefault(app, node, 'params', struct());
            if ~isstruct(params)
                return;
            end

            tag = '';
            if strcmpi(nodeType, 'roiIdentify') || strcmpi(nodeType, 'roiPattern')
                if isfield(params, 'patternList') && ~isempty(params.patternList)
                    nPat = numel(params.patternList);
                    patIdx = 1;
                    if isfield(params, 'activePatternIndex') && ~isempty(params.activePatternIndex)
                        try
                            if params.activePatternIndex >= 1 && params.activePatternIndex <= nPat
                                patIdx = params.activePatternIndex;
                            end
                        catch
                        end
                    end
                    tag = sprintf('Pattern #%d/%d', patIdx, nPat);
                end
            elseif strcmpi(nodeType, 'roiTracked')
                tags = {};
                if isfield(params, 'channel') && ~isempty(params.channel)
                    tags{end+1} = ['Channel ' char(string(params.channel))]; %#ok<AGROW>
                end
                if isfield(params, 'margin') && ~isempty(params.margin)
                    tags{end+1} = sprintf('Margin %g', double(params.margin)); %#ok<AGROW>
                end
                if isfield(params, 'fovIndex') && ~isempty(params.fovIndex)
                    try
                        tags{end+1} = sprintf('FOVs %d', numel(params.fovIndex)); %#ok<AGROW>
                    catch
                    end
                end
                tag = strjoin(tags, ', ');
            elseif strcmpi(nodeType, 'roiGrid')
                tags = {};
                modeName = 'fullframe';
                if isfield(params, 'mode') && ~isempty(params.mode)
                    modeName = lower(char(string(params.mode)));
                end
                if strcmp(modeName, 'grid')
                    gridCount = 1;
                    if isfield(params, 'gridCount') && ~isempty(params.gridCount)
                        gridCount = params.gridCount;
                    end
                    tags{end+1} = sprintf('Grid %d', round(double(gridCount))); %#ok<AGROW>
                else
                    tags{end+1} = 'Full frame'; %#ok<AGROW>
                end
                if isfield(params, 'fovIndex') && ~isempty(params.fovIndex)
                    try
                        tags{end+1} = sprintf('FOVs %d', numel(params.fovIndex)); %#ok<AGROW>
                    catch
                    end
                end
                if isfield(params, 'keepExisting') && logical(params.keepExisting)
                    tags{end+1} = 'Keep existing'; %#ok<AGROW>
                end
                tag = strjoin(tags, ', ');
            elseif strcmpi(nodeType, 'roiManual')
                tags = {};
                if isfield(params, 'fovIndex') && ~isempty(params.fovIndex)
                    try
                        tags{end+1} = sprintf('FOVs %d', numel(params.fovIndex)); %#ok<AGROW>
                    catch
                    end
                end
                if isfield(params, 'keepExisting') && logical(params.keepExisting)
                    tags{end+1} = 'Keep existing'; %#ok<AGROW>
                end
                if isfield(params, 'openFirstOnly') && logical(params.openFirstOnly)
                    tags{end+1} = 'First only'; %#ok<AGROW>
                end
                tag = strjoin(tags, ', ');
            elseif strcmpi(nodeType, 'dataLoader')
                tags = {};
                if isfield(params, 'path') && ~isempty(params.path)
                    rawPath = char(string(params.path));
                    rawPath = regexprep(rawPath, '[\/]+$', '');
                    [~, leaf] = fileparts(rawPath);
                    if isempty(leaf)
                        leaf = rawPath;
                    end
                    tags{end+1} = ['Path ' leaf]; %#ok<AGROW>
                end

                nFilters = 0;
                filterKeys = {'positionFilter','channelFilter','stackFilter'};
                for kk = 1:numel(filterKeys)
                    key = filterKeys{kk};
                    if ~isfield(params, key) || isempty(params.(key))
                        continue;
                    end
                    try
                        nFilters = nFilters + numel(params.(key));
                    catch
                        nFilters = nFilters + 1;
                    end
                end
                if nFilters > 0
                    tags{end+1} = sprintf('Filters %d', nFilters); %#ok<AGROW>
                end

                if isfield(params, 'label') && ~isempty(params.label)
                    tags{end+1} = ['Label ' char(string(params.label))]; %#ok<AGROW>
                end

                if ~isempty(tags)
                    tag = strjoin(tags, ', ');
                end
            end

            if isempty(tag)
                return;
            end
            if isempty(status)
                status = tag;
            else
                status = [status ' (' tag ')'];
            end
        end

        function tf = edgeExistsPortMap(app, fromId, toId, fromPort, toPort)
            tf = false;
            if isempty(app.Data.edges)
                return;
            end
            for i = 1:numel(app.Data.edges)
                e = app.Data.edges(i);
                if strcmp(getEdgeField(app, e,'from',''), fromId) && ...
                   strcmp(getEdgeField(app, e,'to',''), toId) && ...
                   strcmp(getEdgeField(app, e,'fromPort',''), fromPort) && ...
                   strcmp(getEdgeField(app, e,'toPort',''), toPort)
                    tf = true;
                    return;
                end
            end
        end

        function [ok, edgeIdx] = askDisconnectEdge(app, edgeIdxList)
            ok = false;
            edgeIdx = [];
            if isempty(edgeIdxList)
                return;
            end
            if numel(edgeIdxList) == 1
                ok = true;
                edgeIdx = edgeIdxList(1);
                return;
            end

            labels = cell(1, numel(edgeIdxList));
            for i = 1:numel(edgeIdxList)
                e = app.Data.edges(edgeIdxList(i));
                fromId = getEdgeField(app, e,'from','?');
                toId = getEdgeField(app, e,'to','?');
                fromPort = getEdgeField(app, e,'fromPort','?');
                toPort = getEdgeField(app, e,'toPort','?');
                labels{i} = [fromId '.' fromPort ' -> ' toId '.' toPort];
            end
            labelsDrop = [labels labels{1}];
            res = myDialog({'Connection'}, {labelsDrop}, 'CallingApp', app.UIFigure, 'Title', 'Disconnect which connection?');
            if isempty(res)
                return;
            end
            sel = char(string(res.Connection{end}));
            pick = find(strcmp(labels, sel), 1, 'first');
            if isempty(pick)
                return;
            end
            ok = true;
            edgeIdx = edgeIdxList(pick);
        end

        function [ok, fromIdxSel, toIdxSel, fromPort, toPort, reason] = askConnectPorts(app, fromIdx, toIdx)
            ok = false;
            fromIdxSel = [];
            toIdxSel = [];
            fromPort = '';
            toPort = '';
            reason = '';

            dirs = [fromIdx toIdx; toIdx fromIdx];
            labels = {};
            pairs = struct('fromIdx',{},'toIdx',{},'fromPort',{},'toPort',{});

            for d = 1:size(dirs,1)
                srcIdx = dirs(d,1);
                dstIdx = dirs(d,2);
                srcNode = app.Data.nodes(srcIdx);
                dstNode = app.Data.nodes(dstIdx);
                [outs, ins] = getNodePortNames(app, srcNode, dstNode);
                if isempty(outs) || isempty(ins)
                    continue;
                end

                for i = 1:numel(outs)
                    for j = 1:numel(ins)
                        [cok, ~] = arePortsCompatible(app, srcNode, outs{i}, dstNode, ins{j});
                        if ~cok
                            continue;
                        end
                        srcId = char(string(srcNode.id));
                        dstId = char(string(dstNode.id));
                        if edgeExistsPortMap(app, srcId, dstId, outs{i}, ins{j})
                            continue;
                        end

                        pairs(end+1) = struct( ...
                            'fromIdx',srcIdx, ...
                            'toIdx',dstIdx, ...
                            'fromPort',outs{i}, ...
                            'toPort',ins{j}); %#ok<AGROW>
                        labels{end+1} = [char(string(srcNode.name)) '.' outs{i} ' -> ' char(string(dstNode.name)) '.' ins{j}]; %#ok<AGROW>
                    end
                end
            end

            if isempty(pairs)
                reason = 'No compatible port pair between selected modules.';
                return;
            end

            if numel(pairs) == 1
                pick = 1;
            else
                pairDrop = [labels labels{1}];
                res = myDialog({'Connection'}, {pairDrop}, 'CallingApp', app.UIFigure, 'Title', 'Connect ports');
                if isempty(res)
                    return;
                end
                sel = char(string(res.Connection{end}));
                pick = find(strcmp(labels, sel), 1, 'first');
                if isempty(pick)
                    return;
                end
            end

            fromIdxSel = pairs(pick).fromIdx;
            toIdxSel = pairs(pick).toIdx;
            fromPort = pairs(pick).fromPort;
            toPort = pairs(pick).toPort;
            ok = true;
        end

        function [outs, ins] = getNodePortNames(app, fromNode, toNode) %#ok<INUSD>
            cOut = getNodeContract(app, fromNode);
            cIn = getNodeContract(app, toNode);
            outs = {cOut.out.name};
            ins = {cIn.in.name};
        end

        function [ok, why] = arePortsCompatible(app, fromNode, fromPort, toNode, toPort)
            ok = false;
            why = '';
            cOut = getNodeContract(app, fromNode);
            cIn = getNodeContract(app, toNode);
            po = cOut.out(strcmp({cOut.out.name}, fromPort));
            pi = cIn.in(strcmp({cIn.in.name}, toPort));
            if isempty(po) || isempty(pi)
                why = 'Port missing';
                return;
            end
            t1 = char(string(po(1).type));
            t2 = char(string(pi(1).type));
            ok = strcmpi(t1, t2) || strcmpi(t1, 'any') || strcmpi(t2, 'any');
            if ~ok
                why = ['Type mismatch: ' t1 ' -> ' t2];
            end
        end

        function autoHarmonizeConnection(app, fromId, toId, fromPort, toPort)
            [ok1, iFrom] = getNodeIndexById(app, fromId);
            [ok2, iTo] = getNodeIndexById(app, toId);
            if ~ok1 || ~ok2
                return;
            end

            src = app.Data.nodes(iFrom);
            dst = app.Data.nodes(iTo);
            cOut = getNodeContract(app, src);
            po = cOut.out(strcmp({cOut.out.name}, fromPort));
            if isempty(po)
                return;
            end

            portType = lower(char(string(po(1).type)));
            isNamedToken = any(strcmp(portType, {'channelset','dataseriesset','maskset'}));
            if ~isNamedToken
                return;
            end

            srcField = ['out_' matlab.lang.makeValidName(fromPort) '_name'];
            dstField = ['in_' matlab.lang.makeValidName(toPort) '_name'];

            if ~isfield(src,'params') || ~isstruct(src.params)
                src.params = struct();
            end
            if ~isfield(dst,'params') || ~isstruct(dst.params)
                dst.params = struct();
            end

            if ~isfield(src.params, srcField) || isempty(src.params.(srcField))
                src.params.(srcField) = [char(string(src.name)) '_' fromPort];
            end

            sharedName = src.params.(srcField);
            dst.params.(dstField) = sharedName;

            % Keep a conventional alias for frequent input naming.
            if strcmpi(portType, 'channelset') && strcmpi(toPort, 'inputChannels')
                dst.params.inputChannels = sharedName;
            elseif strcmpi(portType, 'dataseriesset') && strcmpi(toPort, 'dataSeries')
                dst.params.dataSeries = sharedName;
            end

            app.Data.nodes(iFrom) = src;
            app.Data.nodes(iTo) = dst;
            updateModuleListTable(app);
            if ismember(iTo, app.SelectedModules)
                updateParamsTable(app, iTo);
            end
        end


        function val = getEdgeField(app, e, fname, defaultVal)
            val = defaultVal;
            if isstruct(e) && isfield(e,fname) && ~isempty(e.(fname))
                val = char(string(e.(fname)));
            end
        end

        function [ok, idx] = getNodeIndexById(app, nodeId)
            ok = false;
            idx = [];
            if isempty(app.Data.nodes)
                return;
            end
            ids = arrayfun(@(n) char(string(n.id)), app.Data.nodes, 'UniformOutput', false);
            idx = find(strcmp(ids, nodeId), 1, 'first');
            ok = ~isempty(idx);
        end

        function c = getNodeContract(app, node)
            pkg = '';
            if isfield(node,'pkg') && ~isempty(node.pkg)
                pkg = char(string(node.pkg));
            end

            if isfield(node,'contract') && isstruct(node.contract) && isfield(node.contract,'in') && isfield(node.contract,'out')
                c = node.contract;
                hasSource = true;
                if isfield(c,'in') && ~isempty(c.in)
                    hasSource = all(arrayfun(@(p) isfield(p,'source'), c.in));
                end
                if ~hasSource
                    c = makeNodeContract(app, char(string(node.type)), pkg);
                end
                return;
            end

            c = makeNodeContract(app, char(string(node.type)), pkg);
        end

        function c = makeNodeContract(app, nodeType, pkg) %#ok<INUSD>
            c = pipelineNodeContract(struct('type', nodeType, 'pkg', pkg));
        end

        function [inputs, outputs] = ioFromContract(app, contract) %#ok<INUSD>
            inputs = {};
            outputs = {};
            if isstruct(contract) && isfield(contract,'in') && ~isempty(contract.in)
                inputs = {contract.in.name};
            end
            if isstruct(contract) && isfield(contract,'out') && ~isempty(contract.out)
                outputs = {contract.out.name};
            end
        end

        function [ok, report] = validatePortContracts(app, pipe, ctx)
            ok = true;
            report = struct('errors',{{}}, 'nodeIssues', containers.Map('KeyType','char','ValueType','any'));

            nodes = pipe.nodes;
            edges = pipe.edges;
            if isempty(nodes)
                return;
            end

            nodeIds = arrayfun(@(n) char(string(n.id)), nodes, 'UniformOutput', false);
            connectedIn = containers.Map('KeyType','char','ValueType','any');

            for i = 1:numel(edges)
                e = edges(i);
                fromId = getEdgeField(app, e,'from','');
                toId = getEdgeField(app, e,'to','');
                fromPort = getEdgeField(app, e,'fromPort','');
                toPort = getEdgeField(app, e,'toPort','');

                fromIdx = find(strcmp(nodeIds, fromId), 1, 'first');
                toIdx = find(strcmp(nodeIds, toId), 1, 'first');
                if isempty(fromIdx) || isempty(toIdx)
                    ok = false;
                    report.errors{end+1} = ['Edge references unknown node: ' fromId ' -> ' toId]; %#ok<AGROW>
                    continue;
                end

                if isempty(fromPort) || isempty(toPort)
                    ok = false;
                    report.errors{end+1} = ['Edge missing port mapping: ' fromId ' -> ' toId]; %#ok<AGROW>
                    addIssue(toId, 'missing port mapping');
                    continue;
                end

                [compat, why] = arePortsCompatible(app, nodes(fromIdx), fromPort, nodes(toIdx), toPort);
                if ~compat
                    ok = false;
                    report.errors{end+1} = ['Incompatible ports ' fromId '.' fromPort ' -> ' toId '.' toPort ' (' why ')']; %#ok<AGROW>
                    addIssue(toId, ['incompatible ' toPort]);
                    continue;
                end

                key = [toId '|' toPort];
                if isKey(connectedIn, key)
                    li = connectedIn(key);
                    li{end+1} = fromId; %#ok<AGROW>
                    connectedIn(key) = li;
                    ok = false;
                    report.errors{end+1} = ['Multiple upstream connections to ' toId '.' toPort]; %#ok<AGROW>
                    addIssue(toId, ['multiple inputs on ' toPort]);
                else
                    connectedIn(key) = {fromId};
                end
            end

            for i = 1:numel(nodes)
                n = nodes(i);
                nodeId = char(string(n.id));
                c = getNodeContract(app, n);
                for k = 1:numel(c.in)
                    if ~logical(c.in(k).required)
                        continue;
                    end

                    pname = c.in(k).name;
                    ptype = c.in(k).type;
                    psource = getfielddefault(app, c.in(k), 'source', 'edge');
                    edgeKey = [nodeId '|' pname];
                    hasEdge = isKey(connectedIn, edgeKey);
                    hasCtx = contextProvidesType(ptype, ctx);

                    mustUseEdge = strcmpi(psource, 'edge');
                    mustUseCtx = strcmpi(psource, 'context');

                    if mustUseEdge
                        isSatisfied = hasEdge;
                    elseif mustUseCtx
                        isSatisfied = hasCtx;
                    else
                        isSatisfied = hasEdge || hasCtx;
                    end

                    if ~isSatisfied
                        ok = false;
                        addIssue(nodeId, ['missing ' pname]);
                        if mustUseEdge
                            report.errors{end+1} = ['Node ' nodeId ' missing required connection for input port: ' pname]; %#ok<AGROW>
                        elseif mustUseCtx
                            report.errors{end+1} = ['Node ' nodeId ' missing required context input: ' pname]; %#ok<AGROW>
                        else
                            report.errors{end+1} = ['Node ' nodeId ' missing required input port: ' pname]; %#ok<AGROW>
                        end
                    end
                end
            end

            function addIssue(id, msg)
                if isKey(report.nodeIssues, id)
                    m = report.nodeIssues(id);
                    if ~any(strcmp(m, msg))
                        m{end+1} = msg;
                        report.nodeIssues(id) = m;
                    end
                else
                    report.nodeIssues(id) = {msg};
                end
            end

            function tf = contextProvidesType(tp, cctx)
                tf = false;
                switch lower(char(string(tp)))
                    case {'imageset','fovlist'}
                        tf = (isfield(cctx,'images') && ~isempty(cctx.images)) || ...
                             (isfield(cctx,'fovList') && ~isempty(cctx.fovList));
                        if ~tf
                            tf = isfield(cctx,'shallow') && ~isempty(cctx.shallow);
                        end
                    case 'roilist'
                        tf = (isfield(cctx,'roiList') && ~isempty(cctx.roiList)) || ...
                             (isfield(cctx,'rois') && ~isempty(cctx.rois));
                    case 'channelset'
                        tf = isfield(cctx,'channels') && ~isempty(cctx.channels);
                    case 'dataseriesset'
                        tf = (isfield(cctx,'dataSeries') && ~isempty(cctx.dataSeries)) || ...
                             (isfield(cctx,'dataseries') && ~isempty(cctx.dataseries));
                    case 'maskset'
                        tf = isfield(cctx,'masks') && ~isempty(cctx.masks);
                        if ~tf && isfield(cctx,'roiList') && ~isempty(cctx.roiList)
                            tf = localHasMaskLikeChannels(cctx.roiList);
                        end
                    otherwise
                        tf = false;
                end
            end

            function tf = localHasMaskLikeChannels(rois)
                tf = false;
                try
                    if isempty(rois)
                        return;
                    end
                    r0 = rois(1);
                    if ~isprop(r0,'display') || isempty(r0.display) || ~isfield(r0.display,'channel') || isempty(r0.display.channel)
                        return;
                    end
                    names = lower(cellstr(r0.display.channel(:)));
                    tf = any(contains(names,'mask') | contains(names,'result') | contains(names,'track'));
                catch
                    tf = false;
                end
            end
        end

        function [x,y] = edgeAnchor(app, node, isOut, portName)
            [x0,y0,w,h] = deal(node.layout(1), node.layout(2), node.layout(3), node.layout(4));
            c = getNodeContract(app, node);
            if isOut
                ports = c.out;
                x = x0 + w - 1.5;
            else
                ports = c.in;
                x = x0 + 1.5;
            end
            y = y0 + h/2;
            if isempty(ports)
                return;
            end
            idx = find(strcmp({ports.name}, portName), 1, 'first');
            if isempty(idx)
                idx = 1;
            end
            y = getPortRowY(app, node, isOut, idx);
        end

        function y = getPortRowY(app, node, isOut, idx)
            [~,y0,~,h] = deal(node.layout(1), node.layout(2), node.layout(3), node.layout(4));
            c = getNodeContract(app, node);
            if isOut
                count = numel(c.out);
            else
                count = numel(c.in);
            end
            count = max(count, 1);
            idx = min(max(round(double(idx)), 1), count);

            topY = y0 + 7.6;
            bottomY = y0 + h - 1.6;
            if count == 1
                y = (topY + bottomY) / 2;
            else
                y = topY + (idx - 1) * ((bottomY - topY) / (count - 1));
            end
        end

        function deleteModule(app, idx, askConfirm)
            if nargin < 3
                askConfirm = true;
            end
            if idx > numel(app.Data.nodes)
                return;
            end

            nodeToDelete = app.Data.nodes(idx);

            if askConfirm
                nodeName = char(string(getfielddefault(app, nodeToDelete, 'name', nodeToDelete.id)));
                choice = uiconfirm(app.UIFigure, ...
                    sprintf('Delete module "%s" from the pipeline?', nodeName), ...
                    'Delete module', ...
                    'Options', {'Delete','Cancel'}, ...
                    'DefaultOption', 2, ...
                    'CancelOption', 2, ...
                    'Icon', 'warning');
                if ~strcmp(choice, 'Delete')
                    return;
                end
            end

            nodeId = char(string(nodeToDelete.id));
            keep = true(1,numel(app.Data.edges));
            for i = 1:numel(app.Data.edges)
                if strcmp(getEdgeField(app, app.Data.edges(i),'from',''), nodeId) || strcmp(getEdgeField(app, app.Data.edges(i),'to',''), nodeId)
                    keep(i) = false;
                end
            end
            app.Data.edges = app.Data.edges(keep);

            clearPortGraphicsForModule(app, idx);
            app.Data.nodes(idx) = [];
            cleanupDeletedNodeFolders(app, nodeToDelete);
            markDirty(app, true);

            if idx <= numel(app.ModuleHandles)
                delete(app.ModuleHandles(idx));
                delete(app.ModuleTextHandles(idx));
                if idx <= numel(app.ModuleBadgeHandles)
                    delete(app.ModuleBadgeHandles(idx));
                end
                delete(app.ModuleMarkers(idx));
                app.ModuleHandles(idx) = [];
                app.ModuleTextHandles(idx) = [];
                if idx <= numel(app.ModuleBadgeHandles), app.ModuleBadgeHandles(idx) = []; end
                app.ModuleMarkers(idx) = [];
            end

            if idx <= numel(app.InPortHandles), app.InPortHandles(idx) = []; end
            if idx <= numel(app.OutPortHandles), app.OutPortHandles(idx) = []; end
            if idx <= numel(app.InPortLabelHandles), app.InPortLabelHandles(idx) = []; end
            if idx <= numel(app.OutPortLabelHandles), app.OutPortLabelHandles(idx) = []; end

            app.SelectedModules = app.SelectedModules(app.SelectedModules ~= idx);
            app.SelectedModules(app.SelectedModules > idx) = app.SelectedModules(app.SelectedModules > idx) - 1;
            clearPortSelection(app);
            redrawAll(app);
        end

        function cleanupDeletedNodeFolders(app, node)
            pipeObj = getCurrentPipelineObject(app);
            if isempty(pipeObj) || isempty(pipeObj.path) || ~isfolder(pipeObj.path)
                return;
            end

            nodeId = char(string(getfielddefault(app, node, 'id', '')));
            if ~isempty(nodeId)
                tryDeleteOwnedPathLocal(app, fullfile(pipeObj.path, 'modules', sanitizeOwnedPathNameLocal(app, nodeId)), pipeObj.path);
            end

            owned = collectNodeOwnedPathsLocal(app, node, pipeObj.path);
            for ii = 1:numel(owned)
                tryDeleteOwnedPathLocal(app, owned{ii}, pipeObj.path);
            end

            try
                modulesRoot = fullfile(pipeObj.path, 'modules');
                if isfolder(modulesRoot)
                    d = dir(modulesRoot);
                    d = d(~ismember({d.name}, {'.','..'}));
                    if isempty(d)
                        rmdir(modulesRoot, 's');
                    end
                end
            catch
            end
        end

        function paths = collectNodeOwnedPathsLocal(app, node, pipeRoot)
            paths = {};
            candidates = {};

            try
                params = getfielddefault(app, node, 'params', struct());
                if isstruct(params) && isfield(params, 'modulePath') && ~isempty(params.modulePath)
                    candidates{end+1} = char(string(params.modulePath)); %#ok<AGROW>
                end
            catch
            end
            try
                if isstruct(node) && isfield(node, 'origin') && isstruct(node.origin) ...
                        && isfield(node.origin, 'path') && ~isempty(node.origin.path)
                    candidates{end+1} = char(string(node.origin.path)); %#ok<AGROW>
                end
            catch
            end

            for ii = 1:numel(candidates)
                p = absolutizeOwnedPathLocal(app, candidates{ii}, pipeRoot);
                if isempty(p)
                    continue;
                end
                if isSubPathOfLocal(app, p, pipeRoot)
                    paths{end+1} = p; %#ok<AGROW>
                end
            end
            paths = unique(paths, 'stable');
        end

        function out = absolutizeOwnedPathLocal(app, p, pipeRoot)
            out = char(string(p));
            if isempty(out)
                return;
            end
            if isAbsoluteOwnedPathLocal(app, out)
                return;
            end
            if nargin >= 3 && ~isempty(pipeRoot) && isfolder(pipeRoot)
                out = fullfile(pipeRoot, out);
            end
        end

        function tf = isSubPathOfLocal(app, childPath, parentPath)
            tf = false;
            childPath = normalizeOwnedPathLocal(app, childPath);
            parentPath = normalizeOwnedPathLocal(app, parentPath);
            if isempty(childPath) || isempty(parentPath)
                return;
            end
            if strcmpi(childPath, parentPath)
                tf = true;
                return;
            end
            if ~endsWith(parentPath, '/')
                parentPath = [parentPath '/'];
            end
            tf = startsWith(childPath, parentPath, 'IgnoreCase', true);
        end

        function out = normalizeOwnedPathLocal(~, p)
            out = lower(strrep(char(string(p)), '\', '/'));
            out = regexprep(out, '/+$', '');
        end

        function tf = isAbsoluteOwnedPathLocal(~, p)
            tf = false;
            if isempty(p)
                return;
            end
            p = char(string(p));
            if ispc
                tf = ~isempty(regexp(p, '^[A-Za-z]:[\\/]', 'once')) || startsWith(p, '\\');
            else
                tf = startsWith(p, '/');
            end
        end

        function out = sanitizeOwnedPathNameLocal(~, nameIn)
            out = regexprep(char(string(nameIn)), '[^a-zA-Z0-9_\-]', '_');
            if isempty(out)
                out = 'node';
            end
        end

        function tryDeleteOwnedPathLocal(app, targetPath, pipeRoot)
            if nargin < 2 || isempty(targetPath)
                return;
            end
            targetPath = char(string(targetPath));
            if nargin >= 3 && ~isempty(pipeRoot) && ~isSubPathOfLocal(app, targetPath, pipeRoot)
                return;
            end

            try
                if isfolder(targetPath)
                    rmdir(targetPath, 's');
                elseif exist(targetPath, 'file') == 2
                    delete(targetPath);
                end
            catch
            end
        end

        function openModule(app, idx)
            if idx > numel(app.Data.nodes)
                return;
            end
            node = app.Data.nodes(idx);
            ctx = app.Context;
            shallowObj = [];
            if isfield(ctx,'shallow') && ~isempty(ctx.shallow)
                shallowObj = ctx.shallow;
            elseif isfield(ctx,'shallowObj') && ~isempty(ctx.shallowObj)
                shallowObj = ctx.shallowObj;
            end

            try
                if strcmpi(node.type,'processor')
                    originProc = loadOriginProcessReference(app, node);
                    if ~isempty(originProc)
                        if ~isempty(shallowObj)
                            processDataGUI(shallowObj, originProc);
                        else
                            processDataGUI([], originProc);
                        end
                        return;
                    end
                    refProc = loadLinkedProcessReference(app, node);
                    if ~isempty(refProc)
                        if ~isempty(shallowObj)
                            processDataGUI(shallowObj, refProc);
                        else
                            processDataGUI([], refProc);
                        end
                        return;
                    end

                    tmpProc = process(tempdir, 'pipeline_module', randi(1e9));
                    pkgName = char(string(getfielddefault(app,node,'pkg','')));
                    if ~isempty(pkgName)
                        tmpProc.processFun = [pkgName '.process'];
                        try
                            p0 = feval([pkgName '.setparam'], struct());
                        catch
                            p0 = struct();
                        end
                        if isstruct(p0)
                            tmpProc.processArg = p0;
                        end
                    elseif ~isempty(getfielddefault(app,node,'func',''))
                        tmpProc.processFun = char(string(node.func));
                    end

                    if isfield(node,'params') && isstruct(node.params)
                        if isempty(tmpProc.processArg) || ~isstruct(tmpProc.processArg)
                            tmpProc.processArg = node.params;
                        else
                            fn = fieldnames(node.params);
                            for fi = 1:numel(fn)
                                tmpProc.processArg.(fn{fi}) = node.params.(fn{fi});
                            end
                        end
                    end

                    if ~isempty(shallowObj)
                        processDataGUI(shallowObj, tmpProc);
                    else
                        processDataGUI([], tmpProc);
                    end
                    return;
                end

                if strcmpi(node.type,'dataLoader')
                    ctx = struct();
                    if ~isempty(shallowObj)
                        ctx.shallow = shallowObj;
                    end
                    if isfield(node,'params') && isstruct(node.params)
                        ctx.dataLoader = node.params;
                        ctx.params = node.params;
                    end
                    ctx = dataLoader.ui(ctx);
                    if isfield(ctx,'dataLoader') && isstruct(ctx.dataLoader)
                        params = ctx.dataLoader;
                        filtered = struct();
                        keep = {'path','positionFilter','channelFilter','stackFilter','label','write','interactive'};
                        for kk = 1:numel(keep)
                            key = keep{kk};
                            if isfield(params, key)
                                filtered.(key) = params.(key);
                            end
                        end
                        node.params = filtered;
                        app.Data.nodes(idx) = node;
                        updateModuleListTable(app);
                        updateParamsTable(app, idx);
                    end
                    refreshStatus(app);
                    return;
                end

                if strcmpi(node.type,'classifier')
                    originClassi = loadOriginClassifierReference(app, node);
                    if ~isempty(originClassi)
                        classifierGUI(originClassi);
                        return;
                    end
                    refClassi = loadLinkedClassifierReference(app, node);
                    if ~isempty(refClassi)
                        classifierGUI(refClassi);
                        return;
                    end

                    tmpClassi = classi(tempdir, 'pipeline_module', randi(1e9));

                    pkgName = char(string(getfielddefault(app,node,'pkg','')));
                    if ~isempty(pkgName)
                        tmpClassi.classifierPkg = pkgName;
                        if isempty(tmpClassi.classifyFun)
                            tmpClassi.classifyFun = [pkgName '.classify'];
                        end
                        if isempty(tmpClassi.trainingFun)
                            tmpClassi.trainingFun = [pkgName '.train'];
                        end
                        if strcmpi(pkgName,'cellposesam')
                            tmpClassi.category = {'Pixel'};
                        elseif strcmpi(pkgName,'cnn_lstm')
                            tmpClassi.category = {'LSTM'};
                        else
                            tmpClassi.category = {'Image'};
                        end
                    else
                        tmpClassi.category = {'Image'};
                    end

                    if ~isempty(getfielddefault(app,node,'func',''))
                        tmpClassi.classifyFun = char(string(node.func));
                    end

                    if isfield(node,'params') && isstruct(node.params)
                        if isfield(node.params,'channel') && ~isempty(node.params.channel)
                            tmpClassi.channelName = char(string(node.params.channel));
                        end
                        if isfield(node.params,'channels') && ~isempty(node.params.channels)
                            ch = node.params.channels;
                            if isstring(ch), ch = cellstr(ch); end
                            if ischar(ch), ch = {ch}; end
                            if numel(ch) >= 1 && ~isempty(ch{1})
                                tmpClassi.channelName = char(string(ch{1}));
                            end
                            if numel(ch) >= 2 && ~isempty(ch{2})
                                tmpClassi.channelName2 = char(string(ch{2}));
                            end
                        end
                        if isfield(node.params,'classes') && ~isempty(node.params.classes)
                            cls = node.params.classes;
                            if isstring(cls), cls = cellstr(cls); end
                            if ischar(cls), cls = {cls}; end
                            tmpClassi.classes = cls;
                        end
                        if isfield(node.params,'outputType') && ~isempty(node.params.outputType)
                            tmpClassi.outputType = node.params.outputType;
                        end
                    end

                    tmpClassi.category = classiNormalizeCategory(tmpClassi.category);
                    classifierGUI(tmpClassi);
                    return;
                end

                if strcmpi(node.type,'roiIdentify') || strcmpi(node.type,'roiPattern')
                    if isempty(shallowObj)
                        uialert(app.UIFigure, 'ROI pattern GUI needs a project context.', 'Info');
                        return;
                    end
                    ctx = struct();
                    ctx.shallow = shallowObj;
                    if isfield(node,'params') && isstruct(node.params)
                        ctx.roiPattern = node.params;
                        ctx.params = node.params;
                    end
                    ctx = roiPattern.ui(ctx);
                    if isfield(ctx,'roiPattern') && isstruct(ctx.roiPattern)
                        node.params = ctx.roiPattern;
                        app.Data.nodes(idx) = node;
                        updateModuleListTable(app);
                        updateParamsTable(app, idx);
                    end
                    refreshStatus(app);
                    return;
                end

                if strcmpi(node.type,'roiManual')
                    if isempty(shallowObj)
                        uialert(app.UIFigure, 'ROI manual GUI needs a project context.', 'Info');
                        return;
                    end
                    ctx = struct();
                    ctx.shallow = shallowObj;
                    if isfield(node,'params') && isstruct(node.params)
                        ctx.roiManual = node.params;
                        ctx.params = node.params;
                    end
                    ctx = roiManual.ui(ctx);
                    if isfield(ctx,'roiManual') && isstruct(ctx.roiManual)
                        node.params = ctx.roiManual;
                        app.Data.nodes(idx) = node;
                        updateModuleListTable(app);
                        updateParamsTable(app, idx);
                    end
                    refreshStatus(app);
                    return;
                end

                if strcmpi(node.type,'roiGrid')
                    if isempty(shallowObj)
                        uialert(app.UIFigure, 'ROI grid GUI needs a project context.', 'Info');
                        return;
                    end
                    ctx = struct();
                    ctx.shallow = shallowObj;
                    if isfield(node,'params') && isstruct(node.params)
                        ctx.roiGrid = node.params;
                        ctx.params = node.params;
                    end
                    ctx = roiGrid.ui(ctx);
                    if isfield(ctx,'roiGrid') && isstruct(ctx.roiGrid)
                        node.params = ctx.roiGrid;
                        app.Data.nodes(idx) = node;
                        updateModuleListTable(app);
                        updateParamsTable(app, idx);
                    end
                    refreshStatus(app);
                    return;
                end

                if strcmpi(node.type,'roiTracked')
                    if isempty(shallowObj)
                        uialert(app.UIFigure, 'Tracked ROI GUI needs a project context.', 'Info');
                        return;
                    end
                    ctx = struct();
                    ctx.shallow = shallowObj;
                    if isfield(node,'params') && isstruct(node.params)
                        ctx.roiTracked = node.params;
                        ctx.params = node.params;
                    end
                    ctx = roiTracked.ui(ctx);
                    if isfield(ctx,'roiTracked') && isstruct(ctx.roiTracked)
                        node.params = ctx.roiTracked;
                        app.Data.nodes(idx) = node;
                        updateModuleListTable(app);
                        updateParamsTable(app, idx);
                    end
                    refreshStatus(app);
                    return;
                end

                if strcmpi(node.type,'roiExtract')
                    if isempty(shallowObj)
                        uialert(app.UIFigure, 'ROI extraction GUI needs a project context.', 'Info');
                        return;
                    end
                    ctx = struct();
                    ctx.shallow = shallowObj;
                    if isfield(node,'params') && isstruct(node.params)
                        ctx.roiExtract = node.params;
                        ctx.params = node.params;
                    end
                    ctx = roiExtract.ui(ctx);
                    if isfield(ctx,'roiExtract') && isstruct(ctx.roiExtract)
                        node.params = ctx.roiExtract;
                        app.Data.nodes(idx) = node;
                        updateModuleListTable(app);
                        updateParamsTable(app, idx);
                        if isfield(ctx,'runNow') && ctx.runNow
                            try
                                runCtx = struct('shallow', shallowObj, 'roiExtract', ctx.roiExtract, 'params', ctx.roiExtract);
                                roiExtract.process(runCtx);
                            catch ME
                                uialert(app.UIFigure, ME.message, 'ROI extraction failed', 'Icon','warning');
                            end
                        end
                    end
                    refreshStatus(app);
                    return;
                end

                if ~isfield(node,'gui') || isempty(node.gui)
                    uialert(app.UIFigure, 'No GUI associated with this module.', 'Info');
                    return;
                end

                guiFn = node.gui;
                if isstring(guiFn)
                    guiFn = char(guiFn);
                end
                if ischar(guiFn)
                    if exist(guiFn,'file') == 0 && exist(guiFn,'class') == 0
                        uialert(app.UIFigure, ['GUI not available: ' guiFn], 'Info');
                        return;
                    end
                end

                if ~isempty(shallowObj)
                    feval(guiFn, shallowObj);
                else
                    feval(guiFn);
                end
            catch ME
                uialert(app.UIFigure, ME.message, 'GUI error', 'Icon','warning');
            end

            refreshStatus(app);
        end

        function applyTypeToNode(app, idx, displayName)
            tpl = getTemplateByDisplay(app, displayName);
            node = app.Data.nodes(idx);
            node.type = tpl.type;
            node.func = tpl.func;
            node.gui = tpl.gui;
            node.paramRequired = tpl.paramRequired;
            node.params = tpl.defaultParams;
            node.pkg = '';

            if strcmpi(node.type,'processor') || strcmpi(node.type,'classifier')
                node.paramRequired = {'pkg'};
                if strcmpi(node.type,'processor')
                    node.gui = 'processDataGUI';
                else
                    node.gui = 'classifierGUI';
                end
            end

            node.contract = makeNodeContract(app, node.type, node.pkg);
            [node.inputs, node.outputs] = ioFromContract(app, node.contract);
            app.Data.nodes(idx) = node;
        end

        function applyPackageToNode(app, idx, pkgName)
            if idx > numel(app.Data.nodes)
                return;
            end
            node = app.Data.nodes(idx);
            if nargin < 3
                pkgName = '';
            end
            pkgName = char(string(pkgName));

            node.pkg = pkgName;
            if ~isfield(node,'params') || isempty(node.params)
                node.params = struct();
            end
            node.params.pkg = pkgName;

            % Infer specialized node kind from package when possible.
            if ~isempty(pkgName)
                if any(strcmp(getProcessorPackageList(app), pkgName))
                    node.type = 'processor';
                elseif any(strcmp(getClassifierPackageList(app), pkgName))
                    node.type = 'classifier';
                end
            end

            if strcmpi(node.type,'processor')
                node.func = '';
                if ~isempty(pkgName)
                    node.func = [pkgName '.process'];
                    try
                        node.params = safeSetParam(app, [pkgName '.setparam']);
                    catch
                        if ~isstruct(node.params), node.params = struct(); end
                    end
                    if ~isfield(node.params,'pkg')
                        node.params.pkg = pkgName;
                    end
                end
                node.gui = 'processDataGUI';
                node.paramRequired = {'pkg'};

            elseif strcmpi(node.type,'classifier')
                node.func = '';
                if ~isempty(pkgName)
                    row = getClasslistRowByName(app, pkgName);
                    fun = getClassifyFunFromRow(app, row);
                    if ~isempty(fun)
                        node.func = fun;
                    end
                    if ~isfield(node.params,'pkg')
                        node.params.pkg = pkgName;
                    end
                end
                node.gui = 'classifierGUI';
                node.paramRequired = {'pkg'};
            end

            node.contract = makeNodeContract(app, node.type, node.pkg);
            [node.inputs, node.outputs] = ioFromContract(app, node.contract);
            app.Data.nodes(idx) = node;
        end

        function node = populateNodeParamsFromPackage(app, node, forceRefresh)
            if nargin < 3
                forceRefresh = false;
            end

            pkgName = char(string(getfielddefault(app, node, 'pkg', '')));
            if isempty(pkgName)
                return;
            end

            if ~isfield(node,'params') || ~isstruct(node.params) || isempty(node.params)
                node.params = struct();
            end

            if strcmpi(char(string(node.type)), 'processor')
                hasOnlyPkg = numel(fieldnames(node.params)) <= 1 && isfield(node.params,'pkg');
                if forceRefresh || isempty(fieldnames(node.params)) || hasOnlyPkg
                    p0 = safeSetParam(app, [pkgName '.setparam']);
                    if isstruct(p0) && ~isempty(fieldnames(p0))
                        fn = fieldnames(p0);
                        for fi = 1:numel(fn)
                            if forceRefresh || ~isfield(node.params, fn{fi}) || isempty(node.params.(fn{fi}))
                                node.params.(fn{fi}) = p0.(fn{fi});
                            end
                        end
                    end
                end
                node.params.pkg = pkgName;
                node.func = [pkgName '.process'];
                node.gui = 'processDataGUI';
                node.paramRequired = {'pkg'};

            elseif strcmpi(char(string(node.type)), 'classifier')
                node.params.pkg = pkgName;
                if ~isfield(node,'func') || isempty(node.func)
                    row = getClasslistRowByName(app, pkgName);
                    fun = getClassifyFunFromRow(app, row);
                    if ~isempty(fun)
                        node.func = fun;
                    end
                end
                node.gui = 'classifierGUI';
                node.paramRequired = {'pkg'};
            end
        end

        function col = getModuleColor(app, node)
            reg = getModuleRegistry(app);
            idx = find(strcmpi({reg.type}, node.type), 1);
            if isempty(idx)
                col = [0.7 0.7 0.7];
            else
                col = reg(idx).color;
            end
            if isfield(node,'enabled') && ~node.enabled
                col = col*0.5 + 0.5;
            end
        end
        function [nodes, edges] = unpackPipeline(app, pipeObj)
            nodes = [];
            edges = [];
            if isempty(pipeObj)
                return;
            end
            if isa(pipeObj,'pipeline')
                nodes = pipeObj.nodes;
                edges = pipeObj.edges;
            elseif isstruct(pipeObj)
                if isfield(pipeObj,'nodes'), nodes = pipeObj.nodes; end
                if isfield(pipeObj,'edges'), edges = pipeObj.edges; end
            end

            if isempty(nodes)
                return;
            end

            srcNodes = nodes;
            nodes = struct([]);
            for i = 1:numel(srcNodes)
                nodei = srcNodes(i);
                if ~isfield(nodei,'layout') || isempty(nodei.layout)
                    nodei.layout = [10 10 20 10];
                end
                if ~isfield(nodei,'name') || isempty(nodei.name)
                    nodei.name = char(string(nodei.id));
                end
                if ~isfield(nodei,'enabled')
                    nodei.enabled = true;
                end
                if ~isfield(nodei,'pkg')
                    nodei.pkg = '';
                end
                nodei = normalizeLibraryNode(app, nodei);
                if isempty(nodes)
                    nodes = nodei;
                else
                    nodes(end+1) = nodei; %#ok<AGROW>
                end
            end

            % Normalize edges to id/port form
            normEdges = struct('from',{},'to',{},'fromPort',{},'toPort',{},'condition',{});
            if isempty(edges)
                edges = normEdges;
                return;
            end

            for i = 1:numel(edges)
                e = edges(i);
                fromId = '';
                toId = '';
                fromPort = '';
                toPort = '';
                cond = '';

                if isfield(e,'from') && isnumeric(e.from)
                    ii = e.from;
                    if ii >= 1 && ii <= numel(nodes)
                        fromId = char(string(nodes(ii).id));
                    end
                elseif isfield(e,'from')
                    fromId = char(string(e.from));
                end

                if isfield(e,'to') && isnumeric(e.to)
                    ii = e.to;
                    if ii >= 1 && ii <= numel(nodes)
                        toId = char(string(nodes(ii).id));
                    end
                elseif isfield(e,'to')
                    toId = char(string(e.to));
                end

                if isfield(e,'fromPort') && ~isempty(e.fromPort)
                    fromPort = char(string(e.fromPort));
                end
                if isfield(e,'toPort') && ~isempty(e.toPort)
                    toPort = char(string(e.toPort));
                end
                if isfield(e,'condition') && ~isempty(e.condition)
                    cond = char(string(e.condition));
                end

                if isempty(fromId) || isempty(toId)
                    continue;
                end

                if isempty(fromPort)
                    nodeIdsLocal = arrayfun(@(n) char(string(n.id)), nodes, 'UniformOutput', false);
                    ii = find(strcmp(nodeIdsLocal, fromId), 1, 'first');
                    if ~isempty(ii)
                        c = getNodeContract(app, nodes(ii));
                        if ~isempty(c.out), fromPort = c.out(1).name; end
                    end
                end
                if isempty(toPort)
                    nodeIdsLocal = arrayfun(@(n) char(string(n.id)), nodes, 'UniformOutput', false);
                    ii = find(strcmp(nodeIdsLocal, toId), 1, 'first');
                    if ~isempty(ii)
                        c = getNodeContract(app, nodes(ii));
                        if ~isempty(c.in), toPort = c.in(1).name; end
                    end
                end

                normEdges(end+1) = struct('from',fromId,'to',toId,'fromPort',fromPort,'toPort',toPort,'condition',cond); %#ok<AGROW>
            end

            edges = normEdges;
        end

        function pipe = buildPipelineStruct(app, includeDisabled)
            if nargin < 2
                includeDisabled = true;
            end
            pipe = struct();
            pipe.name = 'pipeline_gui';
            pipe.nodes = app.Data.nodes;
            pipe.edges = app.Data.edges;

            if ~includeDisabled
                for i = 1:numel(pipe.nodes)
                    if isfield(pipe.nodes(i),'enabled') && ~pipe.nodes(i).enabled
                        pipe.nodes(i).condition = 'false';
                    end
                end
            end
        end

        function savePipelineFromGUI(app, forcePrompt)
            if nargin < 2
                forcePrompt = false;
            end
            pipeObj = [];
            if isfield(app.Context,'pipeObj') && isa(app.Context.pipeObj,'pipeline')
                pipeObj = app.Context.pipeObj;
            end

            if isempty(pipeObj) || forcePrompt || isempty(pipeObj.path)
                [parentPath, pipeName, ok] = promptPipelineLocation(app, getDefaultPipelineName(app));
                if ~ok
                    return;
                end

                if isempty(pipeObj)
                    pipeObj = pipelineConstruct(parentPath, pipeName, 1);
                    app.Context.pipeObj = pipeObj;
                else
                    pipeObj.path = fullfile(parentPath, pipeName);
                    pipeObj.strid = pipeName;
                    if ~exist(pipeObj.path, 'dir')
                        mkdir(pipeObj.path);
                    end
                end
            end

            pipe = buildPipelineStruct(app, true);
            pipeObj.nodes = pipe.nodes;
            pipeObj.edges = pipe.edges;
            pipelineSave(pipeObj);
            markDirty(app, false);
            refreshAppTitle(app);
            rememberPipelineNodesInOfflineLibrary(app, pipe.nodes, 'offline library');
            updateModuleLibraryTable(app);
        end

        function exportPipelineFromGUI(app)
            exportCfg = promptPipelineExportOptions(app);
            if ~isstruct(exportCfg) || ~isfield(exportCfg, 'ok') || ~exportCfg.ok
                return;
            end

            defaultName = [getDefaultPipelineName(app) '_export'];
            [bundlePath, ok] = promptExportBundleLocation(app, defaultName);
            if ~ok
                return;
            end
            overwrite = false;
            if exist(bundlePath, 'dir') == 7
                choice = uiconfirm(app.UIFigure, ...
                    sprintf('Export folder already exists:\n%s\n\nReplace it?', bundlePath), ...
                    'Overwrite export', ...
                    'Options', {'Replace','Cancel'}, ...
                    'DefaultOption', 2, ...
                    'CancelOption', 2, ...
                    'Icon', 'warning');
                if ~strcmp(choice, 'Replace')
                    return;
                end
                overwrite = true;
            end

            pipeStruct = buildPipelineStruct(app, true);
            pipeObj = getCurrentPipelineObject(app);
            if ~isempty(pipeObj)
                pipeStruct.name = char(string(pipeObj.strid));
                pipeStruct.path = char(string(pipeObj.path));
                pipeStruct.id = pipeObj.id;
                pipeStruct.description = pipeObj.description;
                pipeStruct.version = pipeObj.version;
                pipeStruct.runProfiles = pipeObj.runProfiles;
                pipeStruct.runState = pipeObj.runState;
            else
                pipeStruct.name = getDefaultPipelineName(app);
                pipeStruct.path = '';
                pipeStruct.id = 1;
                pipeStruct.description = '';
                pipeStruct.version = '1.0';
            end

            shallowObj = getCurrentProjectObject(app);
            runList = pipelineRun.empty;
            if exportCfg.includeRunResults
                runList = collectRunsForCurrentPipelineExport(app, shallowObj, pipeObj, pipeStruct);
            end

            progressDlg = uiprogressdlg(app.UIFigure, ...
                'Title', 'Exporting pipeline...', ...
                'Message', 'Preparing export...', ...
                'Indeterminate', 'on', ...
                'Cancelable', 'off');
            exportProgress = struct('done', 0, 'total', 1);
            cleanupProgress = onCleanup(@()closeExportProgressLocal(progressDlg));

            [bundlePath, manifest] = pipelineExport( ...
                pipeStruct, bundlePath, ...
                'includeWeights', exportCfg.includeWeights, ...
                'includeTrainingData', exportCfg.includeTrainingData, ...
                'includeTrainingRois', exportCfg.includeTrainingRois, ...
                'includeRunResults', exportCfg.includeRunResults, ...
                'runObjects', runList, ...
                'projectObj', shallowObj, ...
                'overwrite', overwrite, ...
                'progressFcn', @updateExportProgressLocal);

            clear cleanupProgress

            warnCount = countExportWarningsLocal(app, manifest);
            msg = sprintf('Pipeline export created:\n%s', bundlePath);
            if warnCount > 0
                msg = sprintf('%s\n\nWarnings: %d', msg, warnCount);
            end
            choice = uiconfirm(app.UIFigure, msg, 'Export complete', ...
                'Options', {'Open folder','OK'}, ...
                'DefaultOption', 2, ...
                'CancelOption', 2, ...
                'Icon', 'info');
            if strcmp(choice, 'Open folder')
                try
                    winopen(bundlePath);
                catch
                end
            end

            function updateExportProgressLocal(action, info)
                if isempty(progressDlg) || ~isvalid(progressDlg)
                    return;
                end
                if nargin < 2 || ~isstruct(info)
                    info = struct();
                end
                switch lower(char(string(action)))
                    case 'begin'
                        exportProgress.total = max(1, double(getfielddefault(app, info, 'totalUnits', 1)));
                        exportProgress.done = 0;
                        progressDlg.Indeterminate = 'off';
                        progressDlg.Value = 0;
                        progressDlg.Message = 'Preparing export...';
                    case {'node','file','run','write'}
                        exportProgress.done = min(exportProgress.total, exportProgress.done + 1);
                        progressDlg.Indeterminate = 'off';
                        progressDlg.Value = exportProgress.done / exportProgress.total;
                        progressDlg.Message = char(string(getfielddefault(app, info, 'message', 'Working...')));
                    case 'phase'
                        progressDlg.Message = char(string(getfielddefault(app, info, 'message', 'Working...')));
                    case 'end'
                        progressDlg.Indeterminate = 'off';
                        progressDlg.Value = 1;
                        progressDlg.Message = 'Export complete.';
                    otherwise
                        progressDlg.Message = char(string(getfielddefault(app, info, 'message', 'Working...')));
                end
                drawnow limitrate
            end

            function closeExportProgressLocal(dlg)
                try
                    if ~isempty(dlg) && isvalid(dlg)
                        close(dlg);
                    end
                catch
                end
            end
        end

        function exportModuleBundle(app, idx)
            if idx < 1 || idx > numel(app.Data.nodes)
                return;
            end

            exportCfg = promptPipelineExportOptions(app);
            if ~isstruct(exportCfg) || ~isfield(exportCfg, 'ok') || ~exportCfg.ok
                return;
            end
            exportCfg.includeRunResults = false;

            node = app.Data.nodes(idx);
            pipeObj = getCurrentPipelineObject(app);
            pipePath = '';
            pipeName = getDefaultPipelineName(app);
            if ~isempty(pipeObj)
                pipePath = char(string(pipeObj.path));
                pipeName = char(string(pipeObj.strid));
            end

            defaultName = sprintf('%s_%s_export', pipeName, char(string(getfielddefault(app, node, 'id', sprintf('node_%d', idx)))));
            [bundlePath, ok] = promptExportBundleLocation(app, defaultName);
            if ~ok
                return;
            end
            overwrite = false;
            if exist(bundlePath, 'dir') == 7
                choice = uiconfirm(app.UIFigure, ...
                    sprintf('Export folder already exists:\n%s\n\nReplace it?', bundlePath), ...
                    'Overwrite export', ...
                    'Options', {'Replace','Cancel'}, ...
                    'DefaultOption', 2, ...
                    'CancelOption', 2, ...
                    'Icon', 'warning');
                if ~strcmp(choice, 'Replace')
                    return;
                end
                overwrite = true;
            end

            moduleStruct = struct();
            moduleStruct.name = char(string(getfielddefault(app, node, 'name', getfielddefault(app, node, 'id', 'module'))));
            moduleStruct.path = pipePath;
            moduleStruct.id = idx;
            moduleStruct.description = sprintf('Single-module export for %s', moduleStruct.name);
            moduleStruct.version = '1.0';
            moduleStruct.nodes = node;
            moduleStruct.edges = struct([]);
            moduleStruct.runProfiles = struct();
            moduleStruct.runState = struct();

            shallowObj = getCurrentProjectObject(app);
            progressDlg = uiprogressdlg(app.UIFigure, ...
                'Title', 'Exporting module...', ...
                'Message', 'Preparing export...', ...
                'Indeterminate', 'on', ...
                'Cancelable', 'off');
            exportProgress = struct('done', 0, 'total', 1);
            cleanupProgress = onCleanup(@()closeExportProgressLocal(progressDlg));

            [bundlePath, manifest] = pipelineExport( ...
                moduleStruct, bundlePath, ...
                'includeWeights', exportCfg.includeWeights, ...
                'includeTrainingData', exportCfg.includeTrainingData, ...
                'includeTrainingRois', exportCfg.includeTrainingRois, ...
                'includeRunResults', false, ...
                'runObjects', pipelineRun.empty, ...
                'projectObj', shallowObj, ...
                'overwrite', overwrite, ...
                'progressFcn', @updateExportProgressLocal);

            clear cleanupProgress

            warnCount = countExportWarningsLocal(app, manifest);
            msg = sprintf('Module export created:\n%s', bundlePath);
            if warnCount > 0
                msg = sprintf('%s\n\nWarnings: %d', msg, warnCount);
            end
            choice = uiconfirm(app.UIFigure, msg, 'Export complete', ...
                'Options', {'Open folder','OK'}, ...
                'DefaultOption', 2, ...
                'CancelOption', 2, ...
                'Icon', 'info');
            if strcmp(choice, 'Open folder')
                try
                    winopen(bundlePath);
                catch
                end
            end

            function updateExportProgressLocal(action, info)
                if isempty(progressDlg) || ~isvalid(progressDlg)
                    return;
                end
                if nargin < 2 || ~isstruct(info)
                    info = struct();
                end
                switch lower(char(string(action)))
                    case 'begin'
                        exportProgress.total = max(1, double(getfielddefault(app, info, 'totalUnits', 1)));
                        exportProgress.done = 0;
                        progressDlg.Indeterminate = 'off';
                        progressDlg.Value = 0;
                        progressDlg.Message = 'Preparing export...';
                    case {'node','file','run','write'}
                        exportProgress.done = min(exportProgress.total, exportProgress.done + 1);
                        progressDlg.Indeterminate = 'off';
                        progressDlg.Value = exportProgress.done / exportProgress.total;
                        progressDlg.Message = char(string(getfielddefault(app, info, 'message', 'Working...')));
                    case 'phase'
                        progressDlg.Message = char(string(getfielddefault(app, info, 'message', 'Working...')));
                    case 'end'
                        progressDlg.Indeterminate = 'off';
                        progressDlg.Value = 1;
                        progressDlg.Message = 'Export complete.';
                    otherwise
                        progressDlg.Message = char(string(getfielddefault(app, info, 'message', 'Working...')));
                end
                drawnow limitrate
            end

            function closeExportProgressLocal(dlg)
                try
                    if ~isempty(dlg) && isvalid(dlg)
                        close(dlg);
                    end
                catch
                end
            end
        end

        function cfg = promptPipelineExportOptions(app)
            cfg = struct('ok', false, ...
                'includeWeights', true, ...
                'includeTrainingData', false, ...
                'includeTrainingRois', false, ...
                'includeRunResults', false);

            dlg = uifigure('Name', 'Export pipeline', ...
                'Position', [100 100 460 270], ...
                'Resize', 'off', ...
                'WindowStyle', 'modal');
            dlg.UserData = cfg;
            dlg.CloseRequestFcn = @(src,evt)uiresume(src);

            uilabel(dlg, ...
                'Text', 'Choose which assets should be bundled with the pipeline export.', ...
                'Position', [20 225 420 24]);

            cbWeights = uicheckbox(dlg, ...
                'Text', 'Include model weights / inference assets', ...
                'Value', true, ...
                'Position', [24 185 320 22]);
            cbTraining = uicheckbox(dlg, ...
                'Text', 'Include training assets', ...
                'Value', false, ...
                'Position', [24 155 320 22]);
            cbRois = uicheckbox(dlg, ...
                'Text', 'Include training ROIs', ...
                'Value', false, ...
                'Position', [24 125 320 22]);
            cbRuns = uicheckbox(dlg, ...
                'Text', 'Include run results', ...
                'Value', false, ...
                'Position', [24 95 320 22]);

            uibutton(dlg, 'push', ...
                'Text', 'Cancel', ...
                'Position', [250 24 90 34], ...
                'ButtonPushedFcn', @(src,evt)uiresume(dlg));
            uibutton(dlg, 'push', ...
                'Text', 'Export', ...
                'Position', [350 24 90 34], ...
                'ButtonPushedFcn', @(src,evt)confirmExportDialogLocal(dlg, cbWeights, cbTraining, cbRois, cbRuns));

            uiwait(dlg);
            if isvalid(dlg)
                cfg = dlg.UserData;
                delete(dlg);
            end

            function confirmExportDialogLocal(fig, c1, c2, c3, c4)
                fig.UserData = struct( ...
                    'ok', true, ...
                    'includeWeights', logical(c1.Value), ...
                    'includeTrainingData', logical(c2.Value), ...
                    'includeTrainingRois', logical(c3.Value), ...
                    'includeRunResults', logical(c4.Value));
                uiresume(fig);
            end
        end

        function [bundlePath, ok] = promptExportBundleLocation(app, defaultName)
            ok = false;
            bundlePath = '';
            if nargin < 2 || isempty(defaultName)
                defaultName = 'pipeline_export';
            end

            startDir = pwd;
            pipeObj = getCurrentPipelineObject(app);
            if ~isempty(pipeObj) && ~isempty(pipeObj.path)
                try
                    startDir = fileparts(pipeObj.path);
                catch
                end
            end

            selectedPath = uigetdir(startDir, sprintf('Select export folder (%s)', char(string(defaultName))));
            if isequal(selectedPath, 0)
                return;
            end

            bundlePath = char(string(selectedPath));
            ok = true;
        end

        function shallowObj = getCurrentProjectObject(app)
            shallowObj = [];
            if isfield(app.Context, 'shallowObj') && isa(app.Context.shallowObj, 'shallow')
                shallowObj = app.Context.shallowObj;
            elseif isfield(app.Context, 'shallow') && isa(app.Context.shallow, 'shallow')
                shallowObj = app.Context.shallow;
            end
        end

        function runs = collectRunsForCurrentPipelineExport(app, shallowObj, pipeObj, pipeStruct) %#ok<INUSD>
            runs = pipelineRun.empty;
            if isempty(shallowObj) || ~isa(shallowObj, 'shallow')
                return;
            end
            if ~isfield(shallowObj.processing, 'pipelineRun') || isempty(shallowObj.processing.pipelineRun)
                return;
            end

            if ~isempty(pipeObj) && isa(pipeObj, 'pipeline')
                [runs, ~] = pipeObj.findDependentRuns(shallowObj);
                return;
            end

            targetId = char(string(getfielddefault(app, pipeStruct, 'name', '')));
            targetPath = char(string(getfielddefault(app, pipeStruct, 'path', '')));
            for ii = 1:numel(shallowObj.processing.pipelineRun)
                pr = shallowObj.processing.pipelineRun(ii);
                try
                    if isstruct(pr.pipelineRef)
                        if ~isempty(targetPath) && isfield(pr.pipelineRef, 'path') && strcmpi(normalizePathForExportCompareLocal(app, pr.pipelineRef.path), normalizePathForExportCompareLocal(app, targetPath))
                            runs(end+1) = pr; %#ok<AGROW>
                            continue;
                        end
                        if ~isempty(targetId) && isfield(pr.pipelineRef, 'id') && strcmp(char(string(pr.pipelineRef.id)), targetId)
                            runs(end+1) = pr; %#ok<AGROW>
                        end
                    end
                catch
                end
            end
        end

        function out = normalizePathForExportCompareLocal(~, in)
            out = lower(strrep(char(string(in)), '\', '/'));
            out = regexprep(out, '/+$', '');
        end

        function n = countExportWarningsLocal(~, manifest)
            n = 0;
            try
                if isfield(manifest, 'nodes') && ~isempty(manifest.nodes)
                    for ii = 1:numel(manifest.nodes)
                        if isfield(manifest.nodes(ii), 'warnings') && ~isempty(manifest.nodes(ii).warnings)
                            n = n + numel(manifest.nodes(ii).warnings);
                        end
                    end
                end
                if isfield(manifest, 'runs') && ~isempty(manifest.runs)
                    for ii = 1:numel(manifest.runs)
                        if isfield(manifest.runs(ii), 'warnings') && ~isempty(manifest.runs(ii).warnings)
                            n = n + numel(manifest.runs(ii).warnings);
                        end
                    end
                end
            catch
            end
        end

        function createDynamicSaveButton(app)
            if isfield(app.Context,'savePipelineButton')
                hb = app.Context.savePipelineButton;
                if ~isempty(hb) && isvalid(hb)
                    return;
                end
            end

            hb = uibutton(app.UIFigure, 'push');
            hb.ButtonPushedFcn = createCallbackFcn(app, @SavepipelineButtonPushed, true);
            hb.Position = [1160 822 120 24];
            hb.Text = 'Save pipeline...';
            app.Context.savePipelineButton = hb;
        end

        function modulePatchButtonDown(app, src, event)
            idx = src.UserData;
            if strcmp(app.UIFigure.SelectionType,'alt')
                clearPortSelection(app);
                setSelection(app, idx, false);
                updateParamsTable(app, idx);
                return;
            end
            if strcmp(app.UIFigure.SelectionType,'open')
                openModule(app, idx);
                return;
            end

            mod = app.UIFigure.CurrentModifier;
            additive = any(strcmp(mod,'shift'));
            clearPortSelection(app);
            setSelection(app, idx, additive);
            updateParamsTable(app, idx);

            pt = app.UIModulesAxes.CurrentPoint;
            node = app.Data.nodes(idx);
            app.DraggingModule = idx;
            app.DragOffset = [pt(1,1) - node.layout(1), pt(1,2) - node.layout(2)];
        end

        function addModuleFromCanvasContext(app, displayName)
            pt = app.CanvasContextPoint;
            if numel(pt) < 2 || any(isnan(pt))
                pt = [32 12];
            end
            tpl = getTemplateByDisplay(app, displayName);
            addModuleAt(app, pt, tpl);
        end

        function tf = confirmDiscardCurrentPipeline(app)
            tf = true;
            if isempty(app.Data.nodes) && isempty(app.Data.edges)
                return;
            end

            choice = uiconfirm(app.UIFigure, ...
                'Discard the current pipeline and start a new one?', ...
                'New pipeline', ...
                'Options', {'Discard','Cancel'}, ...
                'DefaultOption', 2, ...
                'CancelOption', 2, ...
                'Icon', 'warning');
            tf = strcmp(choice, 'Discard');
        end

        function tf = confirmClosePipelineGUI(app)
            tf = true;
            if ~app.Dirty
                return;
            end

            choice = uiconfirm(app.UIFigure, ...
                'This pipeline has unsaved changes. Close anyway?', ...
                'Unsaved pipeline', ...
                'Options', {'Close without saving','Cancel'}, ...
                'DefaultOption', 2, ...
                'CancelOption', 2, ...
                'Icon', 'warning');
            tf = strcmp(choice, 'Close without saving');
        end

        function pipeObj = getCurrentPipelineObject(app)
            pipeObj = [];
            if isfield(app.Context,'pipeObj') && isa(app.Context.pipeObj,'pipeline')
                pipeObj = app.Context.pipeObj;
            end
        end

        function nameOut = getDefaultPipelineName(app)
            nameOut = 'pipeline';
            pipeObj = getCurrentPipelineObject(app);
            if ~isempty(pipeObj) && ~isempty(pipeObj.strid)
                nameOut = char(string(pipeObj.strid));
                return;
            end
            if ~isempty(app.Data.nodes)
                nameOut = 'pipeline_gui';
            end
        end

        function [parentPath, pipeName, ok] = promptPipelineLocation(app, defaultName)
            ok = false;
            parentPath = '';
            pipeName = char(string(defaultName));

            if nargin < 2 || isempty(pipeName)
                pipeName = 'pipeline';
            end

            parentPath = uigetdir(pwd, 'Select parent folder for the pipeline');
            if isequal(parentPath, 0)
                parentPath = '';
                return;
            end

            answer = inputdlg({'Pipeline name:'}, 'Save pipeline', [1 60], {pipeName});
            if isempty(answer)
                parentPath = '';
                return;
            end

            pipeName = strtrim(char(string(answer{1})));
            if isempty(pipeName)
                uialert(app.UIFigure, 'Pipeline name cannot be empty.', 'Invalid name', 'Icon','warning');
                parentPath = '';
                return;
            end

            ok = true;
        end

        function refreshAppTitle(app)
            baseTitle = 'Pipeline GUI';
            pipeObj = getCurrentPipelineObject(app);
            if isempty(pipeObj)
                if app.Dirty
                    app.UIFigure.Name = [baseTitle ' *'];
                else
                    app.UIFigure.Name = baseTitle;
                end
                return;
            end

            pipeName = '';
            hasSavedPath = false;
            try
                pipeName = char(string(pipeObj.strid));
                hasSavedPath = ~isempty(char(string(pipeObj.path)));
            catch
            end
            isUnsaved = logical(app.Dirty) || ~hasSavedPath;
            if isempty(pipeName)
                titleText = baseTitle;
            else
                titleText = sprintf('%s - %s', baseTitle, pipeName);
            end
            if isUnsaved
                app.UIFigure.Name = [titleText ' *'];
            else
                app.UIFigure.Name = titleText;
            end
        end

        function markDirty(app, tf)
            app.Dirty = logical(tf);
            refreshAppTitle(app);
        end

        function setCheckPipelineVisualState(app, isValid)
            if isValid
                app.CheckpipelineButton.BackgroundColor = [0.18 0.62 0.27];
                app.CheckpipelineButton.FontColor = [1 1 1];
            else
                app.CheckpipelineButton.BackgroundColor = [0.82 0.22 0.20];
                app.CheckpipelineButton.FontColor = [1 1 1];
            end
        end

        function val = getfielddefault(varargin)
            if nargin == 4
                s = varargin{2};
                f = varargin{3};
                default = varargin{4};
            elseif nargin == 3
                s = varargin{1};
                f = varargin{2};
                default = varargin{3};
            else
                val = [];
                return;
            end

            if isstruct(s) && isfield(s,f)
                val = s.(f);
            else
                val = default;
            end
        end

    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @UIFigureCloseRequest, true);
            app.UIFigure.Position = [100 100 1160 766];
            app.UIFigure.Name = 'MATLAB App';

            % Create FileMenu
            app.FileMenu = uimenu(app.UIFigure);
            app.FileMenu.Text = 'File';

            % Create NewpipelineMenu
            app.NewpipelineMenu = uimenu(app.FileMenu);
            app.NewpipelineMenu.Text = 'New pipeline';

            % Create SavepipelineMenu
            app.SavepipelineMenu = uimenu(app.FileMenu);
            app.SavepipelineMenu.Text = 'Save pipeline';

            % Create SavepipelineasMenu
            app.SavepipelineasMenu = uimenu(app.FileMenu);
            app.SavepipelineasMenu.Text = 'Save pipeline as...';

            % Create ExportpipelineMenu
            app.ExportpipelineMenu = uimenu(app.FileMenu);
            app.ExportpipelineMenu.Text = 'Export pipeline...';

            % Create RevealpipelineinexplorerMenu
            app.RevealpipelineinexplorerMenu = uimenu(app.FileMenu);
            app.RevealpipelineinexplorerMenu.Separator = 'on';
            app.RevealpipelineinexplorerMenu.Text = 'Reveal pipeline in explorer';

            % Create OpenpipelineJSONfileMenu
            app.OpenpipelineJSONfileMenu = uimenu(app.FileMenu);
            app.OpenpipelineJSONfileMenu.Text = 'Open pipeline JSON file';

            % Create RunMenu
            app.RunMenu = uimenu(app.UIFigure);
            app.RunMenu.Text = 'Run';

            % Create CheckpipelineMenu
            app.CheckpipelineMenu = uimenu(app.RunMenu);
            app.CheckpipelineMenu.Text = 'Check pipeline...';

            % Create CreaterunMenu
            app.CreaterunMenu = uimenu(app.RunMenu);
            app.CreaterunMenu.Text = 'Create run...';

            % Create UIModulesAxes
            app.UIModulesAxes = uiaxes(app.UIFigure);
            zlabel(app.UIModulesAxes, 'Z')
            app.UIModulesAxes.XTick = [];
            app.UIModulesAxes.YTick = [];
            app.UIModulesAxes.ButtonDownFcn = createCallbackFcn(app, @UIModulesAxesButtonDown, true);
            app.UIModulesAxes.Position = [363 403 786 333];

            % Create UIModuleListTable
            app.UIModuleListTable = uitable(app.UIFigure);
            app.UIModuleListTable.ColumnName = {'Select'; 'Name'; 'Type'; 'Requires'; 'Provides'; 'Status'};
            app.UIModuleListTable.RowName = {};
            app.UIModuleListTable.ColumnEditable = [true true true false false false];
            app.UIModuleListTable.CellEditCallback = createCallbackFcn(app, @UIModuleListTableCellEdit, true);
            app.UIModuleListTable.SelectionChangedFcn = createCallbackFcn(app, @UIModuleListTableSelectionChanged, true);
            app.UIModuleListTable.Position = [12 219 1129 185];

            % Create CloseButton
            app.CloseButton = uibutton(app.UIFigure, 'push');
            app.CloseButton.ButtonPushedFcn = createCallbackFcn(app, @CloseButtonPushed, true);
            app.CloseButton.Position = [752 22 389 39];
            app.CloseButton.Text = 'Close';

            % Create CreaterunButton
            app.CreaterunButton = uibutton(app.UIFigure, 'push');
            app.CreaterunButton.ButtonPushedFcn = createCallbackFcn(app, @CreaterunButtonPushed, true);
            app.CreaterunButton.Position = [752 79 389 56];
            app.CreaterunButton.Text = 'Create run';

            % Create CheckpipelineButton
            app.CheckpipelineButton = uibutton(app.UIFigure, 'push');
            app.CheckpipelineButton.ButtonPushedFcn = createCallbackFcn(app, @CheckpipelineButtonPushed, true);
            app.CheckpipelineButton.Position = [752 145 389 62];
            app.CheckpipelineButton.Text = 'Check pipeline';

            % Create UIModuleParametersTable
            app.UIModuleParametersTable = uitable(app.UIFigure);
            app.UIModuleParametersTable.ColumnName = {'Parameter'; 'Value'};
            app.UIModuleParametersTable.RowName = {};
            app.UIModuleParametersTable.CellEditCallback = createCallbackFcn(app, @UIModuleParametersTableCellEdit, true);
            app.UIModuleParametersTable.SelectionChangedFcn = createCallbackFcn(app, @UIModuleParametersTableSelectionChanged, true);
            app.UIModuleParametersTable.Position = [12 22 724 185];

            % Create ButtonMoveToCanva
            app.ButtonMoveToCanva = uibutton(app.UIFigure, 'push');
            app.ButtonMoveToCanva.Position = [314 417 52 316];
            app.ButtonMoveToCanva.Text = '>>>';

            % Create ModulesinworkspaceLabel
            app.ModulesinworkspaceLabel = uilabel(app.UIFigure);
            app.ModulesinworkspaceLabel.Position = [4 732 130 35];
            app.ModulesinworkspaceLabel.Text = 'Modules in workspace: ';

            % Create PipelinesketchLabel
            app.PipelinesketchLabel = uilabel(app.UIFigure);
            app.PipelinesketchLabel.Position = [381 732 130 35];
            app.PipelinesketchLabel.Text = 'Pipeline sketch:';

            % Create UITable
            app.UITable = uitable(app.UIFigure);
            app.UITable.ColumnName = {'Column 1'; 'Column 2'; 'Column 3'; 'Column 4'};
            app.UITable.RowName = {};
            app.UITable.Position = [12 417 295 316];

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = pipelineGUI(varargin)

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @(app)startupFcn(app, varargin{:}))

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
