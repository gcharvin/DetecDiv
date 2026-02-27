classdef pipelineGUI < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                        matlab.ui.Figure
        ConnectDisconnectmodulesButton  matlab.ui.control.Button
        UIModuleParametersTable         matlab.ui.control.Table
        OpenselectedmoduleButton        matlab.ui.control.Button
        CreaterunButton                 matlab.ui.control.Button
        CheckpipelineButton             matlab.ui.control.Button
        CloseButton                     matlab.ui.control.Button
        RunpipelineButton               matlab.ui.control.Button
        UIModuleListTable               matlab.ui.control.Table
        AddmoduleButton                 matlab.ui.control.Button
        ModuletypeDropDown              matlab.ui.control.DropDown
        ModuletypeDropDownLabel         matlab.ui.control.Label
        UIModulesAxes                   matlab.ui.control.UIAxes
    end

    properties (Access = private)
        Data struct = struct('nodes',[],'edges',[])
        ModuleHandles = gobjects(0)
        ModuleTextHandles = gobjects(0)
        ModuleMarkers = gobjects(0)
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
        Context struct = struct()
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
            initTables(app);
            redrawAll(app);
            createDynamicSaveButton(app);
        end

        % Button pushed function: AddmoduleButton
        function AddmoduleButtonPushed(app, event)
            app.PendingAddModule = true;
            app.PendingTemplate = getTemplateByDisplay(app, app.ModuletypeDropDown.Value);
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

            redrawEdges(app);
            refreshStatus(app);
        end

        % Button down function: UIModulesAxes
        function UIModulesAxesButtonDown(app, event)
            if app.PendingAddModule
                pt = app.UIModulesAxes.CurrentPoint;
                pos = [pt(1,1) pt(1,2)];
                addModuleAt(app, pos);
                app.PendingAddModule = false;
                return;
            end

            clearSelection(app);
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
            refreshPackageColumnForRow(app, row);
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
                case 3
                    pkgVal = char(string(val));
                    if strcmp(pkgVal, '<none>')
                        pkgVal = '';
                    end
                    node.pkg = pkgVal;
                    applyPackageToNode(app, row, node.pkg);
                    node = app.Data.nodes(row);
            end

            app.Data.nodes(row) = node;
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

            updateParamsTable(app, modIdx);
            refreshStatus(app);
        end

        % Selection changed function: UIModuleParametersTable
        function UIModuleParametersTableSelectionChanged(app, event)
            selection = app.UIModuleParametersTable.Selection;
            
        end

        % Button pushed function: RunpipelineButton
        function RunpipelineButtonPushed(app, event)
            pipe = buildPipelineStruct(app, false);
            ctx = app.Context;
            if ~isfield(ctx,'allowGUI')
                ctx.allowGUI = true;
            end
            try
                runPipeline(pipe, ctx);
            catch ME
                uialert(app.UIFigure, ME.message, 'Run failed', 'Icon','error');
            end
            refreshStatus(app);
        end

        % Button pushed function: SavepipelineButton
        function SavepipelineButtonPushed(app, event)
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
            delete(app)
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
            app.DraggingModule = NaN;
        end
    end

    % Internal helpers
    methods (Access = private)

        function initAxes(app)
            cla(app.UIModulesAxes);
            app.UIModulesAxes.XLim = [0 100];
            app.UIModulesAxes.YLim = [0 100];
            app.UIModulesAxes.YDir = 'reverse';
            axis(app.UIModulesAxes, 'manual');
            hold(app.UIModulesAxes, 'on');
        end

        function initTables(app)
            app.UIModuleListTable.ColumnEditable = [true true true false false false];
            app.UIModuleListTable.ColumnFormat = { ...
                'logical', ...
                'char', ...
                getModulePackageList(app), ...
                'char', ...
                'char', ...
                'char' ...
            };

            app.UIModuleParametersTable.ColumnEditable = [false true];
            updateModuleListTable(app);
            refreshPackageColumnForRow(app, 1);
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
                'display','ROI identification', ...
                'type','roiIdentify', ...
                'func','roiIdentify.process', ...
                'gui','roiIdentify.ui', ...
                'paramRequired',{{}}, ...
                'inputs',{{'images'}}, ...
                'outputs',{{'roiList'}}, ...
                'defaultParams',safeSetParam(app, 'roiIdentify.setparam'), ...
                'color',[0.98 0.60 0.20]);

            reg(3) = struct( ...
                'display','ROI extraction', ...
                'type','roiExtract', ...
                'func','roiExtract.process', ...
                'gui','', ...
                'paramRequired',{{}}, ...
                'inputs',{{'roiList'}}, ...
                'outputs',{{'channels'}}, ...
                'defaultParams',safeSetParam(app, 'roiExtract.setparam'), ...
                'color',[0.10 0.68 0.38]);

            reg(4) = struct( ...
                'display','Processor', ...
                'type','processor', ...
                'func','', ...
                'gui','processDataGUI', ...
                'paramRequired',{{'pkg'}}, ...
                'inputs',{{'inputChannels'}}, ...
                'outputs',{{'dataSeries'}}, ...
                'defaultParams',struct('pkg',''), ...
                'color',[0.55 0.55 0.55]);

            reg(5) = struct( ...
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

        function addModuleAt(app, pos)
            tpl = app.PendingTemplate;
            if isempty(fieldnames(tpl))
                tpl = getTemplateByDisplay(app, app.ModuletypeDropDown.Value);
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
            node.layout = [pos(1) pos(2) 20 10];
            node.contract = makeNodeContract(app, node.type, node.pkg);
            [node.inputs, node.outputs] = ioFromContract(app, node.contract);

            if isempty(app.Data.nodes)
                app.Data.nodes = node;
            else
                app.Data.nodes(end+1) = node;
            end

            drawModule(app, numel(app.Data.nodes));
            updateModuleListTable(app);
            refreshStatus(app);
        end

        function drawModule(app, idx)
            node = app.Data.nodes(idx);
            [x,y,w,h] = deal(node.layout(1), node.layout(2), node.layout(3), node.layout(4));
            pts = [x y; x+w-4 y; x+w y+h/2; x+w-4 y+h; x y+h];

            col = getModuleColor(app, node);

            hPatch = patch(app.UIModulesAxes, pts(:,1), pts(:,2), col, ...
                'EdgeColor','k','LineWidth',0.5,'ButtonDownFcn',@app.modulePatchButtonDown);
            hPatch.UserData = idx;

            hText = text(app.UIModulesAxes, x+1, y+h/2, buildNodeCaption(app,node), ...
                'VerticalAlignment','middle', 'FontSize',12, 'Interpreter','none');

            hMarker = plot(app.UIModulesAxes, x+w-2, y+2, 'o', 'MarkerSize',6, ...
                'MarkerEdgeColor','k', 'MarkerFaceColor',[0 0.8 0], 'Visible','off');

            if idx > numel(app.ModuleHandles)
                app.ModuleHandles(idx) = hPatch;
                app.ModuleTextHandles(idx) = hText;
                app.ModuleMarkers(idx) = hMarker;
            else
                app.ModuleHandles(idx) = hPatch;
                app.ModuleTextHandles(idx) = hText;
                app.ModuleMarkers(idx) = hMarker;
            end

            cm = uicontextmenu(app.UIFigure);
            uimenu(cm,'Text','Open module','MenuSelectedFcn',@(s,e)openModule(app, idx));
            uimenu(cm,'Text','Delete module','MenuSelectedFcn',@(s,e)deleteModule(app, idx));
            hPatch.ContextMenu = cm;

            drawPortsForModule(app, idx);
            redrawModule(app, idx);
            redrawEdges(app);
        end

        function redrawModule(app, idx)
            if idx > numel(app.Data.nodes) || idx > numel(app.ModuleHandles)
                return;
            end
            node = app.Data.nodes(idx);
            hPatch = app.ModuleHandles(idx);
            hText = app.ModuleTextHandles(idx);
            hMarker = app.ModuleMarkers(idx);
            if isempty(hPatch) || ~isvalid(hPatch)
                return;
            end

            [x,y,w,h] = deal(node.layout(1), node.layout(2), node.layout(3), node.layout(4));
            pts = [x y; x+w-4 y; x+w y+h/2; x+w-4 y+h; x y+h];
            hPatch.XData = pts(:,1);
            hPatch.YData = pts(:,2);
            hPatch.FaceColor = getModuleColor(app, node);

            hText.Position = [x+1 y+h/2 0];
            hText.String = buildNodeCaption(app,node);

            if node.enabled
                hMarker.Visible = 'on';
                hMarker.XData = x+w-2;
                hMarker.YData = y+2;
                st = lower(char(string(getfielddefault(app, node, 'status', ''))));
                if isNodeConnected(app, node)
                    hMarker.MarkerFaceColor = [0 0.75 0.2];
                elseif contains(st,'disabled')
                    hMarker.MarkerFaceColor = [0.6 0.6 0.6];
                else
                    hMarker.MarkerFaceColor = [0.90 0.20 0.20];
                end
            else
                hMarker.Visible = 'on';
                hMarker.XData = x+w-2;
                hMarker.YData = y+2;
                hMarker.MarkerFaceColor = [0.6 0.6 0.6];
            end

            drawPortsForModule(app, idx);
            updateSelectionStyle(app);
        end

        function cap = buildNodeCaption(app, node)
            pkg = getfielddefault(app, node, 'pkg', '');
            if isempty(pkg)
                cap = char(string(node.name));
            else
                cap = sprintf('%s\n[%s]', char(string(node.name)), char(string(pkg)));
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
                h = plot(app.UIModulesAxes, x, y, 'o', ...
                    'MarkerSize',7, ...
                    'MarkerEdgeColor',[0.00 0.45 0.74], ...
                    'MarkerFaceColor',[1 1 1], ...
                    'LineWidth',1.2, ...
                    'ButtonDownFcn',@app.portButtonDown);
                h.UserData = meta;

                ht = text(app.UIModulesAxes, x-0.8, y, char(string(pname)), ...
                    'HorizontalAlignment','right', ...
                    'VerticalAlignment','middle', ...
                    'FontSize',11, ...
                    'Color',[0.00 0.45 0.74], ...
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
                h = plot(app.UIModulesAxes, x, y, 'o', ...
                    'MarkerSize',7, ...
                    'MarkerEdgeColor',[0.47 0.67 0.19], ...
                    'MarkerFaceColor',[1 1 1], ...
                    'LineWidth',1.2, ...
                    'ButtonDownFcn',@app.portButtonDown);
                h.UserData = meta;

                ht = text(app.UIModulesAxes, x+0.8, y, char(string(pname)), ...
                    'HorizontalAlignment','left', ...
                    'VerticalAlignment','middle', ...
                    'FontSize',11, ...
                    'Color',[0.20 0.50 0.10], ...
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
            redrawEdges(app);
            refreshStatus(app);
        end

        function redrawAll(app)
            cla(app.UIModulesAxes);
            hold(app.UIModulesAxes,'on');

            app.ModuleHandles = gobjects(0);
            app.ModuleTextHandles = gobjects(0);
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

                h = plot(app.UIModulesAxes, [x1 x2], [y1 y2], '-', 'Color',[0 0 0]);
                app.EdgeHandles(end+1) = h; %#ok<AGROW>

                lbl = [getEdgeField(app, e,'fromPort','') ' -> ' getEdgeField(app, e,'toPort','')];
                if ~strcmp(strtrim(lbl), '->')
                    ht = text(app.UIModulesAxes, (x1+x2)/2, (y1+y2)/2, lbl, ...
                        'FontSize',10, 'Color',[0.2 0.2 0.2], 'Interpreter','none', ...
                        'BackgroundColor',[1 1 1], 'Margin',1, 'HorizontalAlignment','center');
                    app.EdgeLabelHandles(end+1) = ht; %#ok<AGROW>
                end
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
                if ismember(i, app.SelectedModules)
                    app.ModuleHandles(i).LineWidth = 2;
                else
                    app.ModuleHandles(i).LineWidth = 0.5;
                end
            end
            updatePortSelectionStyle(app);
        end

        function updatePortSelectionStyle(app)
            for i = 1:numel(app.InPortHandles)
                hh = app.InPortHandles{i};
                if isempty(hh), continue; end
                for k = 1:numel(hh)
                    if ~isgraphics(hh(k)), continue; end
                    hh(k).MarkerFaceColor = [1 1 1];
                    hh(k).MarkerSize = 7;
                end
            end

            for i = 1:numel(app.OutPortHandles)
                hh = app.OutPortHandles{i};
                if isempty(hh), continue; end
                for k = 1:numel(hh)
                    if ~isgraphics(hh(k)), continue; end
                    hh(k).MarkerFaceColor = [1 1 1];
                    hh(k).MarkerSize = 7;
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
                        hh(k).MarkerSize = 9;
                    end
                end
            end
        end

        function updateModuleListTable(app)
            n = numel(app.Data.nodes);
            data = cell(n,6);
            for i = 1:n
                node = app.Data.nodes(i);
                data{i,1} = logical(getfielddefault(app, node,'enabled',true));
                data{i,2} = getfielddefault(app, node,'name',node.id);
                pkg = getfielddefault(app, node,'pkg','');
                if isempty(pkg)
                    pkg = '<none>';
                end
                data{i,3} = pkg;
                data{i,4} = strjoin(cellstr(node.inputs(:)), ', ');
                data{i,5} = strjoin(cellstr(node.outputs(:)), ', ');
                data{i,6} = getfielddefault(app, node,'status','');
            end
            app.UIModuleListTable.Data = data;
        end

        function refreshPackageColumnForRow(app, row)
            list = {'<none>'};
            if nargin >= 2 && row >= 1 && row <= numel(app.Data.nodes)
                t = lower(char(string(app.Data.nodes(row).type)));
                switch t
                    case 'processor'
                        list = getProcessorPackageList(app);
                    case 'classifier'
                        list = getClassifierPackageList(app);
                end
                list = list(~cellfun(@isempty, list));
                list = unique(list, 'stable');
                list = [{'<none>'} list(:)'];
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
            if ~isfield(node,'params') || isempty(node.params)
                app.UIModuleParametersTable.Data = {};
                return;
            end
            fn = fieldnames(node.params);
            data = cell(numel(fn),2);
            for i = 1:numel(fn)
                data{i,1} = fn{i};
                data{i,2} = toUITableCellValue(app, paramValueToTableCell(app, node.params.(fn{i})));
            end
            app.UIModuleParametersTable.Data = data;
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
                    out = mat2str(v);
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
        function refreshStatus(app, showAlert)
            if nargin < 2
                showAlert = false;
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
            if isfield(report,'missingParams') && ~isempty(report.missingParams)
                for i = 1:numel(report.missingParams)
                    entry = report.missingParams{i};
                    missingMap(entry.node) = entry.missing;
                end
            end

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
                if ~getfielddefault(app, node,'enabled',true)
                    node.status = 'Disabled';
                elseif isKey(portReport.nodeIssues, nodeId)
                    msgs = portReport.nodeIssues(nodeId);
                    node.status = ['Contract: ' msgs{1}];
                elseif isKey(missingMap, nodeId)
                    miss = missingMap(nodeId);
                    node.status = ['Missing: ' strjoin(miss, ', ')];
                else
                    node.status = 'OK';
                end
                nodes(i) = node;
            end

            app.Data.nodes = nodes;
            updateModuleListTable(app);
            for ii = 1:numel(app.Data.nodes)
                redrawModule(app, ii);
            end

            if showAlert && (~ok || ~okPorts)
                errs = {};
                if isfield(report,'errors') && ~isempty(report.errors)
                    errs = [errs report.errors];
                end
                if isfield(portReport,'errors') && ~isempty(portReport.errors)
                    errs = [errs portReport.errors];
                end
                if isempty(errs)
                    errs = {'Pipeline validation failed.'};
                end
                msg = strjoin(errs, newline);
                uialert(app.UIFigure, msg, 'Pipeline issues', 'Icon','warning');
            end
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
            in = struct('name',{},'type',{},'required',{},'source',{});
            out = struct('name',{},'type',{},'required',{},'source',{});

            t = lower(char(string(nodeType)));
            p = lower(char(string(pkg)));

            switch t
                case 'dataloader'
                    out = portDef('images','imageSet',true,'edge');

                case 'roiidentify'
                    in  = portDef('images','imageSet',true,'edge');
                    out = portDef('roiList','roiList',true,'edge');

                case 'roiextract'
                    in  = portDef('roiList','roiList',true,'edge');
                    out = portDef('channels','channelSet',true,'edge');

                case 'processor'
                    in  = portDef('inputChannels','channelSet',true,'edge');
                    if strcmp(p, 'combinemultiplechannels')
                        out = portDef('combinedChannel','channelSet',true,'edge');
                    else
                        out = portDef('dataSeries','dataSeriesSet',true,'edge');
                    end

                case 'classifier'
                    in = portDef('inputChannels','channelSet',true,'edge');
                    if strcmp(p, 'cellposesam')
                        out = [portDef('masks','maskSet',true,'edge'), portDef('dataSeries','dataSeriesSet',false,'edge')];
                    else
                        out = portDef('dataSeries','dataSeriesSet',true,'edge');
                    end

                otherwise
                    in = struct('name',{},'type',{},'required',{},'source',{});
                    out = struct('name',{},'type',{},'required',{},'source',{});
            end

            c = struct('in',in,'out',out);

            function pdef = portDef(name, type, required, source)
                if nargin < 4 || isempty(source)
                    source = 'edge';
                end
                pdef = struct( ...
                    'name',name, ...
                    'type',type, ...
                    'required',logical(required), ...
                    'source',char(string(source)));
            end
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
                    otherwise
                        tf = false;
                end
            end
        end

        function [x,y] = edgeAnchor(app, node, isOut, portName)
            [x0,y0,w,h] = deal(node.layout(1), node.layout(2), node.layout(3), node.layout(4));
            c = getNodeContract(app, node);
            if isOut
                ports = c.out;
                x = x0 + w;
            else
                ports = c.in;
                x = x0;
            end
            y = y0 + h/2;
            if isempty(ports)
                return;
            end
            idx = find(strcmp({ports.name}, portName), 1, 'first');
            if isempty(idx)
                idx = 1;
            end
            y = y0 + (idx * h) / (numel(ports)+1);
        end

        function deleteModule(app, idx)
            if idx > numel(app.Data.nodes)
                return;
            end

            nodeId = char(string(app.Data.nodes(idx).id));
            keep = true(1,numel(app.Data.edges));
            for i = 1:numel(app.Data.edges)
                if strcmp(getEdgeField(app, app.Data.edges(i),'from',''), nodeId) || strcmp(getEdgeField(app, app.Data.edges(i),'to',''), nodeId)
                    keep(i) = false;
                end
            end
            app.Data.edges = app.Data.edges(keep);

            clearPortGraphicsForModule(app, idx);
            app.Data.nodes(idx) = [];

            if idx <= numel(app.ModuleHandles)
                delete(app.ModuleHandles(idx));
                delete(app.ModuleTextHandles(idx));
                delete(app.ModuleMarkers(idx));
                app.ModuleHandles(idx) = [];
                app.ModuleTextHandles(idx) = [];
                app.ModuleMarkers(idx) = [];
            end

            if idx <= numel(app.InPortHandles), app.InPortHandles(idx) = []; end
            if idx <= numel(app.OutPortHandles), app.OutPortHandles(idx) = []; end
            if idx <= numel(app.InPortLabelHandles), app.InPortLabelHandles(idx) = []; end
            if idx <= numel(app.OutPortLabelHandles), app.OutPortLabelHandles(idx) = []; end

            app.SelectedModules = app.SelectedModules(app.SelectedModules ~= idx);
            app.SelectedModules(app.SelectedModules > idx) = app.SelectedModules(app.SelectedModules > idx) - 1;
            clearPortSelection(app);

            for i = 1:numel(app.ModuleHandles)
                if isvalid(app.ModuleHandles(i))
                    app.ModuleHandles(i).UserData = i;
                end
            end

            redrawEdges(app);
            updateModuleListTable(app);
            refreshStatus(app);
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

                if strcmpi(node.type,'classifier')
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
                        if isfield(node.params,'classes') && ~isempty(node.params.classes)
                            cls = node.params.classes;
                            if isstring(cls), cls = cellstr(cls); end
                            if ischar(cls), cls = {cls}; end
                            tmpClassi.classes = cls;
                        end
                    end

                    tmpClassi.category = classiNormalizeCategory(tmpClassi.category);
                    classifierGUI(tmpClassi);
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

            for i = 1:numel(nodes)
                if ~isfield(nodes(i),'layout') || isempty(nodes(i).layout)
                    nodes(i).layout = [10 10 20 10];
                end
                if ~isfield(nodes(i),'name') || isempty(nodes(i).name)
                    nodes(i).name = char(string(nodes(i).id));
                end
                if ~isfield(nodes(i),'enabled')
                    nodes(i).enabled = true;
                end
                if ~isfield(nodes(i),'pkg')
                    nodes(i).pkg = '';
                end
                nodes(i) = populateNodeParamsFromPackage(app, nodes(i), false);
                nodes(i).contract = getNodeContract(app, nodes(i));
                [nodes(i).inputs, nodes(i).outputs] = ioFromContract(app, nodes(i).contract);
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

        function savePipelineFromGUI(app)
            pipeObj = [];
            if isfield(app.Context,'pipeObj') && isa(app.Context.pipeObj,'pipeline')
                pipeObj = app.Context.pipeObj;
            end

            if isempty(pipeObj)
                pipeObj = pipelineNew();
                if isempty(pipeObj)
                    return;
                end
                app.Context.pipeObj = pipeObj;
            end

            pipe = buildPipelineStruct(app, true);
            pipeObj.nodes = pipe.nodes;
            pipeObj.edges = pipe.edges;
            pipelineSave(pipeObj);
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
            hb.Position = [520 759 120 23];
            hb.Text = 'Save pipeline...';
            app.Context.savePipelineButton = hb;
        end

        function modulePatchButtonDown(app, src, event)
            idx = src.UserData;
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
            app.UIFigure.Position = [100 100 661 799];
            app.UIFigure.Name = 'MATLAB App';
            app.UIFigure.WindowButtonMotionFcn = createCallbackFcn(app, @UIFigureWindowButtonMotion, true);
            app.UIFigure.WindowButtonUpFcn = createCallbackFcn(app, @UIFigureWindowButtonUp, true);

            % Create UIModulesAxes
            app.UIModulesAxes = uiaxes(app.UIFigure);
            zlabel(app.UIModulesAxes, 'Z')
            app.UIModulesAxes.XTick = [];
            app.UIModulesAxes.YTick = [];
            app.UIModulesAxes.ButtonDownFcn = createCallbackFcn(app, @UIModulesAxesButtonDown, true);
            app.UIModulesAxes.Position = [19 436 627 311];

            % Create ModuletypeDropDownLabel
            app.ModuletypeDropDownLabel = uilabel(app.UIFigure);
            app.ModuletypeDropDownLabel.HorizontalAlignment = 'right';
            app.ModuletypeDropDownLabel.Position = [20 760 70 22];
            app.ModuletypeDropDownLabel.Text = 'Module type';

            % Create ModuletypeDropDown
            app.ModuletypeDropDown = uidropdown(app.UIFigure);
            app.ModuletypeDropDown.Items = {'Dataloader', 'ROI identification', 'ROI extraction', 'Processor', 'Classifier'};
            app.ModuletypeDropDown.Position = [105 760 100 22];
            app.ModuletypeDropDown.Value = 'Dataloader';

            % Create AddmoduleButton
            app.AddmoduleButton = uibutton(app.UIFigure, 'push');
            app.AddmoduleButton.ButtonPushedFcn = createCallbackFcn(app, @AddmoduleButtonPushed, true);
            app.AddmoduleButton.Position = [221 760 100 23];
            app.AddmoduleButton.Text = 'Add module';

            % Create UIModuleListTable
            app.UIModuleListTable = uitable(app.UIFigure);
            app.UIModuleListTable.ColumnName = {'Select'; 'Name'; 'Package'; 'Requires'; 'Provides'; 'Status'};
            app.UIModuleListTable.RowName = {};
            app.UIModuleListTable.ColumnEditable = [true true true false false false];
            app.UIModuleListTable.CellEditCallback = createCallbackFcn(app, @UIModuleListTableCellEdit, true);
            app.UIModuleListTable.SelectionChangedFcn = createCallbackFcn(app, @UIModuleListTableSelectionChanged, true);
            app.UIModuleListTable.Position = [37 252 593 185];
            app.UIModuleListTable.FontSize = 14;

            % Create RunpipelineButton
            app.RunpipelineButton = uibutton(app.UIFigure, 'push');
            app.RunpipelineButton.ButtonPushedFcn = createCallbackFcn(app, @RunpipelineButtonPushed, true);
            app.RunpipelineButton.Position = [17 18 100 23];
            app.RunpipelineButton.Text = 'Run pipeline';

            % Create CloseButton
            app.CloseButton = uibutton(app.UIFigure, 'push');
            app.CloseButton.ButtonPushedFcn = createCallbackFcn(app, @CloseButtonPushed, true);
            app.CloseButton.Position = [547 18 100 23];
            app.CloseButton.Text = 'Close';

            % Create CheckpipelineButton
            app.CheckpipelineButton = uibutton(app.UIFigure, 'push');
            app.CheckpipelineButton.ButtonPushedFcn = createCallbackFcn(app, @CheckpipelineButtonPushed, true);
            app.CheckpipelineButton.Position = [129 17 100 23];
            app.CheckpipelineButton.Text = 'Check pipeline';

            % Create OpenselectedmoduleButton
            app.OpenselectedmoduleButton = uibutton(app.UIFigure, 'push');
            app.OpenselectedmoduleButton.ButtonPushedFcn = createCallbackFcn(app, @OpenselectedmoduleButtonPushed, true);
            app.OpenselectedmoduleButton.Position = [243 18 135 23];
            app.OpenselectedmoduleButton.Text = 'Open selected module';

            % Create CreaterunButton
            app.CreaterunButton = uibutton(app.UIFigure, 'push');
            app.CreaterunButton.ButtonPushedFcn = createCallbackFcn(app, @CreaterunButtonPushed, true);
            app.CreaterunButton.Position = [391 18 145 23];
            app.CreaterunButton.Text = 'Create run...';

            % Create UIModuleParametersTable
            app.UIModuleParametersTable = uitable(app.UIFigure);
            app.UIModuleParametersTable.ColumnName = {'Parameter'; 'Value'};
            app.UIModuleParametersTable.RowName = {};
            app.UIModuleParametersTable.CellEditCallback = createCallbackFcn(app, @UIModuleParametersTableCellEdit, true);
            app.UIModuleParametersTable.SelectionChangedFcn = createCallbackFcn(app, @UIModuleParametersTableSelectionChanged, true);
            app.UIModuleParametersTable.Position = [40 55 590 185];
            app.UIModuleParametersTable.FontSize = 14;

            % Create ConnectDisconnectmodulesButton
            app.ConnectDisconnectmodulesButton = uibutton(app.UIFigure, 'push');
            app.ConnectDisconnectmodulesButton.ButtonPushedFcn = createCallbackFcn(app, @ConnectDisconnectmodulesButtonPushed, true);
            app.ConnectDisconnectmodulesButton.Position = [335 759 171 23];
            app.ConnectDisconnectmodulesButton.Tooltip = {'Click 2 ports to connect/disconnect directly, or select 2 modules then press this button.'};
            app.ConnectDisconnectmodulesButton.Text = 'Connect/Disconnect modules';

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
