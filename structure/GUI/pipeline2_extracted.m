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
        SmokeTestButton                 matlab.ui.control.Button
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
        RuntimeDataSeriesCache struct = struct('key', '', 'names', {{}}, 'sampledRoiCount', 0, 'sampledFovCount', 0);
        RuntimeInventoryRefreshSuspended logical = false
        LastValidationReport struct = struct()
        LastValidationOk logical = false
        WorkflowRawProject = []
        WorkflowRawProjectPath char = ''
        RoiManualPreviewHandles cell = {}
        RoiManualPreviewListeners cell = {}
        RoiManualSelectedRectangle double = NaN
    end

    methods (Access = private)

        function startupFcn(app)
            app.UIFigure.Name = guiAppName(app);
            app.AvailableModules = defaultModuleLibrary(app);

            configureControls(app);
            refreshAvailableModuleTable(app);
            refreshSelectedModuleTable(app);
            redrawGraph(app);
            refreshValidationReport(app);
        end

        function applyStartupArguments(app, varargin)
            if isempty(varargin)
                return;
            end
            projectObj = [];
            pipeObj = [];
            runObj = [];
            for i = 1:numel(varargin)
                arg = varargin{i};
                if isempty(arg)
                    continue;
                elseif isa(arg, 'shallow')
                    projectObj = arg;
                elseif isa(arg, 'pipeline')
                    pipeObj = arg;
                elseif isa(arg, 'pipelineRun')
                    runObj = arg;
                elseif ischar(arg) || isstring(arg)
                    argPath = char(string(arg));
                    if exist(argPath, 'file') == 2
                        try
                            [~, ~, ext] = fileparts(argPath);
                            if strcmpi(ext, '.json') && strcmpi(getFileName(app, argPath), 'run.json')
                                [candidateRun, msg] = pipelineRunLoad(argPath);
                                if isempty(candidateRun)
                                    error('pipeline2:RunLoadFailed', '%s', msg);
                                end
                                runObj = candidateRun;
                            else
                                [candidate, msg] = pipelineLoad(argPath);
                                if isempty(candidate)
                                    error('pipeline2:PipelineLoadFailed', '%s', msg);
                                end
                                pipeObj = candidate;
                            end
                        catch ME
                            uialert(app.UIFigure, ME.message, 'Open pipeline/run', 'Icon', 'error');
                        end
                    end
                end
            end

            if ~isempty(projectObj) && isa(projectObj, 'shallow')
                varName = findWorkspaceVarForObject(app, projectObj, 'shallowObj');
                bindCurrentProject(app, projectObj, varName);
            end
            if ~isempty(pipeObj) && isa(pipeObj, 'pipeline')
                loadPipelineFromObject(app, pipeObj, isempty(runObj));
                try
                    addRecentPipelinePath(app, fullfile(pipeObj.path, 'pipeline.json'));
                catch
                end
            end
            if ~isempty(runObj) && isa(runObj, 'pipelineRun')
                if isempty(pipeObj)
                    [pipeFromRun, msg] = resolvePipelineFromRunForUi(app, runObj);
                    if isempty(pipeFromRun)
                        uialert(app.UIFigure, msg, 'Open pipeline run', 'Icon', 'warning');
                    else
                        loadPipelineFromObject(app, pipeFromRun, false);
                        try
                            addRecentPipelinePath(app, fullfile(pipeFromRun.path, 'pipeline.json'));
                        catch
                        end
                    end
                end
                loadRunIntoUi(app, runObj);
            end
        end

        function name = getFileName(app, filePath) %#ok<INUSD>
            [~, n, e] = fileparts(char(string(filePath)));
            name = [n e];
        end

        function [pipeObj, msg] = resolvePipelineFromRunForUi(app, runObj)
            pipeObj = [];
            msg = 'Could not resolve pipeline template for this run.';
            if isempty(runObj) || ~isa(runObj, 'pipelineRun')
                return;
            end

            try
                spec = runObj.ctx.pipelineSpec;
                if isstruct(spec) && isfield(spec, 'nodes') && ~isempty(spec.nodes)
                    pipeObj = pipeline('', char(string(getNestedRunField(app, runObj, {'pipelineRef','id'}, defaultPipelineTemplateName(app)))), 1);
                    pipeObj.nodes = spec.nodes;
                    if isfield(spec, 'edges')
                        pipeObj.edges = spec.edges;
                    end
                    if isfield(spec, 'branches')
                        pipeObj.branches = spec.branches;
                    end
                    msg = '';
                    return;
                end
            catch
            end

            candidatePaths = {};
            try
                if isstruct(runObj.pipelineRef) && isfield(runObj.pipelineRef, 'path') && ~isempty(runObj.pipelineRef.path)
                    candidatePaths{end+1} = char(string(runObj.pipelineRef.path)); %#ok<AGROW>
                end
            catch
            end
            try
                if ~isempty(runObj.templatePath)
                    candidatePaths{end+1} = char(string(runObj.templatePath)); %#ok<AGROW>
                end
            catch
            end
            try
                if isstruct(runObj.ctx) && isfield(runObj.ctx, 'pipelineRef') && isstruct(runObj.ctx.pipelineRef) && ...
                        isfield(runObj.ctx.pipelineRef, 'path') && ~isempty(runObj.ctx.pipelineRef.path)
                    candidatePaths{end+1} = char(string(runObj.ctx.pipelineRef.path)); %#ok<AGROW>
                end
            catch
            end
            candidatePaths = unique(candidatePaths(~cellfun(@isempty, candidatePaths)), 'stable');
            for i = 1:numel(candidatePaths)
                [pipeObj, loadMsg] = pipelineLoad(candidatePaths{i});
                if ~isempty(pipeObj)
                    msg = '';
                    return;
                end
                if ~isempty(loadMsg)
                    msg = loadMsg;
                end
            end
        end

        function value = getNestedRunField(app, runObj, path, defaultValue) %#ok<INUSD>
            value = defaultValue;
            try
                cur = runObj;
                for i = 1:numel(path)
                    key = path{i};
                    if isa(cur, 'pipelineRun') && isprop(cur, key)
                        cur = cur.(key);
                    elseif isstruct(cur) && isfield(cur, key)
                        cur = cur.(key);
                    else
                        return;
                    end
                end
                if ~isempty(cur)
                    value = cur;
                end
            catch
                value = defaultValue;
            end
        end

        function varName = findWorkspaceVarForObject(app, obj, fallback) %#ok<INUSD>
            varName = '';
            try
                vars = evalin('base', 'who');
            catch
                vars = {};
            end
            for i = 1:numel(vars)
                try
                    cand = evalin('base', vars{i});
                    if isequal(cand, obj)
                        varName = vars{i};
                        return;
                    end
                catch
                end
            end
            if nargin >= 3 && ~isempty(fallback)
                varName = matlab.lang.makeValidName(char(string(fallback)));
            else
                varName = 'detecdivObject';
            end
            try
                assignin('base', varName, obj);
            catch
            end
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
            app.AdvancedmodeCheckBox.Visible = 'off';
            app.AdvancedmodeCheckBox.Enable = 'off';
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
            app.UISelectedModuleTable.CellEditCallback = @(src,event)selectedModuleTableEdited(app, src, event);

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
            app.SmokeTestButton.ButtonPushedFcn = createCallbackFcn(app, @SmokeTestButtonPushed, true);
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
            addModuleLibraryMenu(app, app.ModuleContextMenu, 'Insert module after...', 'insert_after');
            addModuleLibraryMenu(app, app.ModuleContextMenu, 'Insert module before...', 'insert_before');
            addModuleLibraryMenu(app, app.ModuleContextMenu, 'Change module type...', 'change_type');
            uimenu(app.ModuleContextMenu, 'Text', 'Fork graph', ...
                'MenuSelectedFcn', createCallbackFcn(app, @ModuleContextForkSelected, true));
            uimenu(app.ModuleContextMenu, 'Text', 'Merge graph', ...
                'MenuSelectedFcn', createCallbackFcn(app, @ModuleContextMergeSelected, true));
            uimenu(app.ModuleContextMenu, 'Text', 'Delete module', ...
                'MenuSelectedFcn', createCallbackFcn(app, @ModuleContextDeleteSelected, true));

            app.GraphContextMenu = uicontextmenu(app.UIFigure);
            addModuleLibraryMenu(app, app.GraphContextMenu, 'Add module...', 'add');
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
            reorderRuntimeTabs(app);
        end

        function reorderRuntimeTabs(app)
            try
                children = app.TabGroup.Children;
                dynamicTabs = gobjects(0);
                otherTabs = gobjects(0);
                for i = 1:numel(children)
                    if isequal(children(i), app.RuntimeInputsTab) || isequal(children(i), app.RuntimeTab)
                        continue;
                    end
                    try
                        ud = children(i).UserData;
                        if isstruct(ud) && isfield(ud, 'dynamic') && logical(ud.dynamic)
                            dynamicTabs(end+1) = children(i); %#ok<AGROW>
                        else
                            otherTabs(end+1) = children(i); %#ok<AGROW>
                        end
                    catch
                        otherTabs(end+1) = children(i); %#ok<AGROW>
                    end
                end
                app.TabGroup.Children = [otherTabs(:); app.RuntimeInputsTab; app.RuntimeTab; dynamicTabs(:)];
            catch
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

        function selectedModuleTableEdited(app, table, event)
            try
                if nargin >= 3 && ~isempty(event) && ~isempty(event.Indices)
                    data = table.Data;
                    data{event.Indices(1), event.Indices(2)} = logical(event.NewData);
                    table.Data = data;
                    drawnow limitrate;
                end
            catch
            end
            d = openRuntimeProgress(app, 'Runtime modules', 'Updating selected modules...');
            cleanupObj = onCleanup(@()closeRuntimeProgress(app, d)); %#ok<NASGU>
            updateRuntimeProgress(app, d, 'Redrawing pipeline graph...');
            redrawGraph(app);
            updateRuntimeProgress(app, d, 'Refreshing module tabs...');
            refreshModuleTabs(app);
            updateRuntimeProgress(app, d, 'Checking pipeline...');
            refreshValidationReport(app);
        end

        function tf = isRawPrepNode(app, node) %#ok<INUSD>
            nodeType = lower(char(string(getField(app, node, 'type', ''))));
            tf = any(strcmp(nodeType, {'dataloader','roipattern','roiidentify','roimanual','roigrid','roitracked','roiextract'}));
        end

        function tf = runtimeStartsFromExistingProject(app)
            mode = getRuntimeValue(app, 'inputSourceMode');
            if isempty(mode)
                mode = 'existing_rois';
            end
            tf = strcmpi(char(string(mode)), 'existing_rois');
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
            % Deprecated: module parameter visibility is now determined by
            % parameter role (bindings/runtime/static), not by an advanced
            % toggle.
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
            node = pipelineNormalizeNodes(node, 'persist');
            [nodesAligned, node] = alignStructFieldsForAppend(app, app.Data.nodes, node);
            nodesAligned(app.SelectedNodeIndex) = node;
            app.Data.nodes = pipelineNormalizeNodes(nodesAligned, 'persist');
            rebuildEdgesFromLayout(app);
            refreshAfterModelChange(app);
        end

        function updateSubtypeChoices(app)
            typeLabel = char(string(app.TypeDropDown.Value));
            switch lower(typeLabel)
                case 'roi definition'
                    items = moduleLibraryPackagesForType(app, {'roiPattern','roiManual','roiGrid','roiTracked'});
                case 'processor'
                    items = moduleLibraryPackagesForType(app, {'processor'});
                case 'classifier'
                    items = moduleLibraryPackagesForType(app, {'classifier'});
                otherwise
                    items = {typeLabel};
            end
            if isempty(items)
                items = {typeLabel};
            end
            app.SubtypeDropDown.Items = items;
            app.SubtypeDropDown.Value = items{1};
        end

        function items = moduleLibraryPackagesForType(app, types)
            items = {};
            if isempty(app.AvailableModules)
                return;
            end
            types = cellstr(string(types(:)));
            for i = 1:size(app.AvailableModules, 1)
                nodeType = char(string(app.AvailableModules{i,2}));
                pkg = char(string(app.AvailableModules{i,3}));
                if ~any(strcmpi(types, nodeType))
                    continue;
                end
                if strcmpi(nodeType, 'processor') || strcmpi(nodeType, 'classifier')
                    if ~isempty(pkg)
                        items{end+1} = pkg; %#ok<AGROW>
                    end
                else
                    items{end+1} = nodeType; %#ok<AGROW>
                end
            end
            items = unique(items(~cellfun(@isempty, items)), 'stable');
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
            node = pipelineNormalizeNodes(node, 'persist');
            [nodesAligned, node] = alignStructFieldsForAppend(app, app.Data.nodes, node);
            nodesAligned(app.SelectedNodeIndex) = node;
            app.Data.nodes = pipelineNormalizeNodes(nodesAligned, 'persist');
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
            shiftLayoutRowFromColumn(app, targetRow, targetCol);
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
            shiftLayoutRowFromColumn(app, targetRow, targetCol);
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

        function shiftLayoutRowFromColumn(app, row, firstCol)
            for i = 1:numel(app.Data.nodes)
                if getLayoutRow(app, app.Data.nodes(i)) == row && getLayoutCol(app, app.Data.nodes(i)) >= firstCol
                    app.Data.nodes(i).layout(1) = getLayoutCol(app, app.Data.nodes(i)) + 1;
                end
            end
        end

        function compactLayoutRows(app)
            if isempty(app.Data.nodes)
                return;
            end
            rows = unique(arrayfun(@(n)getLayoutRow(app, n), app.Data.nodes));
            for r = 1:numel(rows)
                row = rows(r);
                idx = find(arrayfun(@(n)getLayoutRow(app, n) == row, app.Data.nodes));
                if numel(idx) < 2
                    continue;
                end
                cols = arrayfun(@(k)getLayoutCol(app, app.Data.nodes(k)), idx);
                [cols, order] = sort(cols);
                idx = idx(order);
                startCol = min(cols);
                for k = 1:numel(idx)
                    app.Data.nodes(idx(k)).layout(1) = startCol + k - 1;
                    app.Data.nodes(idx(k)).layout(2) = row;
                end
            end
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

        function addModuleLibraryMenu(app, parentMenu, titleText, action)
            root = uimenu(parentMenu, 'Text', titleText);
            groups = moduleMenuGroups(app);
            for g = 1:numel(groups)
                typeMenu = uimenu(root, 'Text', groups(g).label);
                for j = 1:numel(groups(g).rows)
                    idx = groups(g).rows(j);
                    nodeType = char(string(app.AvailableModules{idx,2}));
                    pkg = char(string(app.AvailableModules{idx,3}));
                    label = moduleSubtypeLabel(app, idx);
                    item = uimenu(typeMenu, 'Text', label, ...
                        'MenuSelectedFcn', createCallbackFcn(app, @ModuleLibraryMenuSelected, true));
                    item.UserData = struct('action', char(string(action)), ...
                        'nodeType', nodeType, 'pkg', pkg);
                end
            end
        end

        function ModuleLibraryMenuSelected(app, event)
            src = getCallbackSource(app, event);
            if isempty(src) || ~isvalid(src) || ~isstruct(src.UserData)
                return;
            end
            data = src.UserData;
            action = char(string(getField(app, data, 'action', '')));
            nodeType = char(string(getField(app, data, 'nodeType', '')));
            pkg = char(string(getField(app, data, 'pkg', '')));
            switch action
                case 'insert_after'
                    addModuleAfterSelected(app, nodeType, pkg);
                case 'insert_before'
                    insertModuleBeforeSelected(app, nodeType, pkg);
                case 'change_type'
                    changeSelectedModuleType(app, nodeType, pkg);
                case 'add'
                    addModuleOfType(app, nodeType, pkg);
            end
        end

        function ModuleContextForkSelected(app, event) %#ok<INUSD>
            ForkgraphButtonPushed(app, []);
        end

        function ModuleContextMergeSelected(app, event) %#ok<INUSD>
            MergegraphButtonPushed(app, []);
        end

        function ModuleContextDeleteSelected(app, event) %#ok<INUSD>
            deleteSelectedModule(app);
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
        end

        function f = defaultNodeFunction(app, nodeType, pkg) %#ok<INUSD>
            pkg = canonicalModulePackageName(app, nodeType, pkg);
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
            pkg = canonicalModulePackageName(app, nodeType, pkg);
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
            pkg = canonicalModulePackageName(app, nodeType, pkg);
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
                case 'processor'
                    if ~isempty(pkg)
                        candidates = {[char(string(pkg)) '.setparam']};
                    end
                case 'classifier'
                    candidates = {};
            end

            for i = 1:numel(candidates)
                try
                    p = feval(candidates{i}, struct());
                    break;
                catch
                end
            end

            if strcmpi(nodeType, 'processor') || strcmpi(nodeType, 'classifier')
                if ~isstruct(p)
                    p = struct();
                end
                if ~isfield(p, 'pkg') || isempty(p.pkg)
                    p.pkg = pkg;
                end
                if strcmpi(nodeType, 'classifier')
                    switch lower(char(string(pkg)))
                        case 'cnn_lstm'
                            if ~isfield(p, 'outputName') || isempty(p.outputName), p.outputName = 'div_1'; end
                            if ~isfield(p, 'outputMode') || isempty(p.outputMode), p.outputMode = 'lstm_only'; end
                            if ~isfield(p, 'cnnOutputName') || isempty(p.cnnOutputName), p.cnnOutputName = 'cnn_div_1'; end
                        case 'cellposesam'
                            if ~isfield(p, 'outputName') || isempty(p.outputName), p.outputName = 'cellposeSAM'; end
                            if ~isfield(p, 'outputType') || isempty(p.outputType), p.outputType = 'segmentation'; end
                            if ~isfield(p, 'probabilityOutputName') || isempty(p.probabilityOutputName), p.probabilityOutputName = 'cellposeSAM_prob'; end
                            if ~isfield(p, 'diameter') || isempty(p.diameter), p.diameter = NaN; end
                            if ~isfield(p, 'min_size') || isempty(p.min_size), p.min_size = 10; end
                            if ~isfield(p, 'flow_threshold') || isempty(p.flow_threshold), p.flow_threshold = 0.4; end
                            if ~isfield(p, 'cell_prob_threshold') || isempty(p.cell_prob_threshold), p.cell_prob_threshold = 0; end
                        otherwise
                            if ~isfield(p, 'outputName') || isempty(p.outputName), p.outputName = char(string(pkg)); end
                    end
                elseif strcmpi(nodeType, 'processor') && strcmpi(char(string(pkg)), 'computeMetrics')
                    if ~isfield(p, 'maskChannelCount') || isempty(p.maskChannelCount), p.maskChannelCount = 2; end
                    if ~isfield(p, 'scoreChannelCount') || isempty(p.scoreChannelCount), p.scoreChannelCount = 4; end
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
                    'LineWidth', ternary(app, selected, 1.8, 1.5), ...
                    'ButtonDownFcn', createCallbackFcn(app, @GraphNodeButtonDown, true));
                h.UserData = struct('nodeIndex', i);
                h.UIContextMenu = app.ModuleContextMenu;
                t1 = text(app.UIGraphAxes, x + blockW/2, y + blockH*0.60, ...
                    char(string(getField(app, nodes(i), 'id', 'module'))), ...
                    'HorizontalAlignment', 'center', 'Interpreter', 'none', ...
                    'FontWeight', 'bold', 'FontSize', 9, 'Color', textColor, ...
                    'ButtonDownFcn', createCallbackFcn(app, @GraphNodeButtonDown, true));
                t1.UserData = struct('nodeIndex', i);
                t1.UIContextMenu = app.ModuleContextMenu;
                t2 = text(app.UIGraphAxes, x + blockW/2, y + blockH*0.28, ...
                    blockTypeLabel(app, nodes(i)), ...
                    'HorizontalAlignment', 'center', 'Interpreter', 'none', ...
                    'FontSize', 8, 'Color', subTextColor, ...
                    'ButtonDownFcn', createCallbackFcn(app, @GraphNodeButtonDown, true));
                t2.UserData = struct('nodeIndex', i);
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
                'LineWidth', 1.4, ...
                'ButtonDownFcn', createCallbackFcn(app, @GraphAddModuleButtonDown, true));
            gh.UIContextMenu = app.GraphContextMenu;
            gt = text(app.UIGraphAxes, gx + blockW/2, gy + blockH/2, '+ module', ...
                'HorizontalAlignment', 'center', 'Interpreter', 'none', ...
                'Color', [0.35 0.35 0.35], 'FontWeight', 'bold', ...
                'ButtonDownFcn', createCallbackFcn(app, @GraphAddModuleButtonDown, true));
            gt.UIContextMenu = app.GraphContextMenu;
            app.GhostHandles = [gh gt];

            drawResourceBindingEdges(app, blockW, blockH, gapX, gapY);

            maxCol = max(ghostCol, 3);
            maxRow = 1;
            if ~isempty(nodes)
                maxRow = max(arrayfun(@(n) getLayoutRow(app, n), nodes));
            end
            drawRuntimeGraphButtons(app, blockW, blockH, gapX, gapY, maxRow);
            xlim(app.UIGraphAxes, [-0.3 maxCol * (blockW + gapX)]);
            ylim(app.UIGraphAxes, [-(maxRow) * (blockH + gapY) blockH + 0.35]);
            axis(app.UIGraphAxes, 'manual');
            hold(app.UIGraphAxes, 'off');
        end

        function GraphNodeButtonDown(app, event)
            src = getCallbackSource(app, event);
            if isempty(src) || ~isvalid(src) || ~isstruct(src.UserData) || ~isfield(src.UserData, 'nodeIndex')
                return;
            end
            idx = src.UserData.nodeIndex;
            if isempty(idx) || ~isscalar(idx)
                return;
            end
            selectNode(app, round(double(idx)));
        end

        function GraphAddModuleButtonDown(app, event) %#ok<INUSD>
            addModuleFromCurrentSelection(app);
        end

        function GraphRuntimeNavButtonDown(app, event)
            src = getCallbackSource(app, event);
            if isempty(src) || ~isvalid(src) || ~isstruct(src.UserData) || ~isfield(src.UserData, 'runtimeTab')
                return;
            end
            target = char(string(src.UserData.runtimeTab));
            try
                switch target
                    case 'inputs'
                        app.TabGroup.SelectedTab = app.RuntimeInputsTab;
                    case 'options'
                        app.TabGroup.SelectedTab = app.RuntimeTab;
                end
            catch
            end
            redrawGraph(app);
        end

        function src = getCallbackSource(app, event) %#ok<INUSD>
            src = [];
            try
                if isobject(event) && isprop(event, 'Source')
                    src = event.Source;
                    return;
                end
            catch
            end
            try
                if isstruct(event) && isfield(event, 'Source')
                    src = event.Source;
                end
            catch
                src = [];
            end
        end

        function drawRuntimeGraphButtons(app, blockW, blockH, gapX, gapY, maxRow)
            btnW = 1.45;
            btnH = 0.30;
            btnGap = 0.14;
            x0 = 0;
            y0 = -(maxRow) * (blockH + gapY) + 0.13;
            drawRuntimeGraphButton(app, x0, y0, btnW, btnH, 'Runtime inputs', 'inputs');
            drawRuntimeGraphButton(app, x0 + btnW + btnGap, y0, btnW, btnH, 'Runtime options', 'options');
        end

        function drawRuntimeGraphButton(app, x, y, w, h, label, target)
            selected = false;
            try
                if strcmp(target, 'inputs')
                    selected = isequal(app.TabGroup.SelectedTab, app.RuntimeInputsTab);
                elseif strcmp(target, 'options')
                    selected = isequal(app.TabGroup.SelectedTab, app.RuntimeTab);
                end
            catch
                selected = false;
            end
            face = [0.94 0.96 0.98];
            edge = [0.40 0.48 0.58];
            textColor = [0.18 0.22 0.28];
            lineWidth = 1.0;
            if selected
                face = [0.78 0.88 1.00];
                edge = [0.05 0.32 0.68];
                lineWidth = 1.6;
            end
            ud = struct('runtimeTab', char(string(target)));
            hRect = rectangle(app.UIGraphAxes, 'Position', [x y w h], ...
                'Curvature', 0.10, 'FaceColor', face, 'EdgeColor', edge, ...
                'LineWidth', lineWidth, ...
                'ButtonDownFcn', createCallbackFcn(app, @GraphRuntimeNavButtonDown, true));
            hRect.UserData = ud;
            hText = text(app.UIGraphAxes, x + w/2, y + h/2, char(string(label)), ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
                'Interpreter', 'none', 'FontSize', 8, 'FontWeight', 'bold', ...
                'Color', textColor, ...
                'ButtonDownFcn', createCallbackFcn(app, @GraphRuntimeNavButtonDown, true));
            hText.UserData = ud;
            app.GhostHandles(end+1:end+2) = [hRect hText]; %#ok<AGROW>
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

        function drawResourceBindingEdges(app, blockW, blockH, gapX, gapY)
            nodes = app.Data.nodes;
            edges = resourceBindingEdgesForGraph(app);
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
                if explicitGraphEdgeExists(app, char(string(edges(i).from)), char(string(edges(i).to)))
                    yOffset = blockH * 0.23;
                    y1 = y1 + yOffset;
                    y2 = y2 + yOffset;
                end
                srcSelected = isempty(selectedRunIds) || any(strcmp(selectedRunIds, char(string(src.id))));
                dstSelected = isempty(selectedRunIds) || any(strcmp(selectedRunIds, char(string(dst.id))));
                if srcSelected && dstSelected
                    edgeColor = [0.16 0.38 0.72];
                    edgeWidth = 1.35;
                else
                    edgeColor = [0.70 0.70 0.70];
                    edgeWidth = 1.0;
                end
                h = quiver(app.UIGraphAxes, x1, y1, x2 - x1, y2 - y1, 0, ...
                    'Color', edgeColor, ...
                    'LineWidth', edgeWidth, ...
                    'MaxHeadSize', 0.40, ...
                    'AutoScale', 'off', ...
                    'HitTest', 'off');
                try
                    h.LineStyle = '--';
                catch
                end
                app.EdgeHandles(end+1) = h; %#ok<AGROW>
            end
        end

        function edges = resourceBindingEdgesForGraph(app)
            edges = struct('from',{},'to',{},'fromPort',{},'toPort',{},'condition',{});
            try
                report = app.LastValidationReport;
                if ~isfield(report, 'edges') || isempty(report.edges)
                    return;
                end
                reportEdges = report.edges;
                conditions = cell(1, numel(reportEdges));
                for i = 1:numel(reportEdges)
                    conditions{i} = char(string(getField(app, reportEdges(i), 'condition', '')));
                end
                reportEdges = reportEdges(strcmpi(conditions, 'resourceBinding'));
                if isempty(reportEdges)
                    return;
                end
                edges = reportEdges;
            catch
                edges = struct('from',{},'to',{},'fromPort',{},'toPort',{},'condition',{});
            end
        end

        function tf = explicitGraphEdgeExists(app, fromId, toId)
            tf = false;
            try
                explicitEdges = app.Data.edges;
                for i = 1:numel(explicitEdges)
                    if strcmp(char(string(getField(app, explicitEdges(i), 'from', ''))), fromId) && ...
                            strcmp(char(string(getField(app, explicitEdges(i), 'to', ''))), toId)
                        tf = true;
                        return;
                    end
                end
            catch
                tf = false;
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
            app.AdvancedmodeCheckBox.Value = false;
            selectTypeControlsForNode(app, node);
            redrawGraph(app);
            selectExistingModuleTab(app, node);
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
            node = pipelineNormalizeNodes(node, 'persist');
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
            compactLayoutRows(app);
            nodes = app.Data.nodes;
            if numel(nodes) < 2
                app.Data.edges = edges;
                return;
            end

            cols = unique(arrayfun(@(n) getLayoutCol(app, n), nodes));
            cols = sort(cols);
            for cIdx = 2:numel(cols)
                curCol = cols(cIdx);
                curIdx = find(arrayfun(@(n) getLayoutCol(app, n) == curCol, nodes));
                for ii = 1:numel(curIdx)
                    dstIdx = curIdx(ii);
                    srcCandidates = upstreamLayoutSourceIndices(app, nodes, dstIdx);
                    for jj = 1:numel(srcCandidates)
                        srcIdx = srcCandidates(jj);
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

        function srcIdx = upstreamLayoutSourceIndices(app, nodes, dstIdx)
            srcIdx = [];
            dstCol = getLayoutCol(app, nodes(dstIdx));
            dstRow = getLayoutRow(app, nodes(dstIdx));
            cols = arrayfun(@(n) getLayoutCol(app, n), nodes);
            rows = arrayfun(@(n) getLayoutRow(app, n), nodes);

            previous = find(cols < dstCol);
            if isempty(previous)
                return;
            end

            sameRow = previous(rows(previous) == dstRow);
            if ~isempty(sameRow)
                nearestCol = max(cols(sameRow));
                srcIdx = sameRow(cols(sameRow) == nearestCol);
                return;
            end

            nearestCol = max(cols(previous));
            srcIdx = previous(cols(previous) == nearestCol);
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
            previousFocus = captureTabFocus(app);
            deleteDynamicModuleTabs(app);
            nodes = app.Data.nodes;
            activeIds = selectedRunNodeIds(app);
            for i = 1:numel(nodes)
                node = nodes(i);
                tabTitle = truncateTabTitle(app, getField(app, node, 'id', 'module'));
                t = uitab(app.TabGroup, 'Title', tabTitle);
                t.UserData = struct('nodeId', char(string(node.id)), 'dynamic', true);
                configureModuleTabActiveState(app, t, node, activeIds);
                app.DynamicModuleTabs(end+1) = t; %#ok<AGROW>
                buildModuleTab(app, t, node);
            end
            reorderRuntimeTabs(app);
            restored = restoreTabFocus(app, previousFocus);
            if ~restored && ~isnan(app.SelectedNodeIndex) && app.SelectedNodeIndex >= 1 && app.SelectedNodeIndex <= numel(app.DynamicModuleTabs)
                selectDynamicModuleTabIfActive(app, app.SelectedNodeIndex);
            end
        end

        function focus = captureTabFocus(app)
            focus = struct('kind', '', 'nodeId', '');
            try
                selectedTab = app.TabGroup.SelectedTab;
                if isequal(selectedTab, app.RuntimeTab)
                    focus.kind = 'runtimeOptions';
                elseif isequal(selectedTab, app.RuntimeInputsTab)
                    focus.kind = 'runtimeInputs';
                elseif isstruct(selectedTab.UserData) && isfield(selectedTab.UserData, 'nodeId')
                    focus.kind = 'module';
                    focus.nodeId = char(string(selectedTab.UserData.nodeId));
                end
            catch
            end
        end

        function restored = restoreTabFocus(app, focus)
            restored = false;
            if ~isstruct(focus)
                return;
            end
            try
                switch char(string(getField(app, focus, 'kind', '')))
                    case 'runtimeOptions'
                        if isvalid(app.RuntimeTab)
                            app.TabGroup.SelectedTab = app.RuntimeTab;
                            restored = true;
                        end
                    case 'runtimeInputs'
                        if isvalid(app.RuntimeInputsTab)
                            app.TabGroup.SelectedTab = app.RuntimeInputsTab;
                            restored = true;
                        end
                    case 'module'
                        nodeId = char(string(getField(app, focus, 'nodeId', '')));
                        for i = 1:numel(app.DynamicModuleTabs)
                            ud = app.DynamicModuleTabs(i).UserData;
                            if isstruct(ud) && isfield(ud, 'nodeId') && strcmp(char(string(ud.nodeId)), nodeId)
                                if isfield(ud, 'active') && ~logical(ud.active)
                                    continue;
                                end
                                app.TabGroup.SelectedTab = app.DynamicModuleTabs(i);
                                idx = find(strcmp({app.Data.nodes.id}, nodeId), 1);
                                if ~isempty(idx)
                                    app.SelectedNodeIndex = idx;
                                end
                                restored = true;
                                return;
                            end
                        end
                end
            catch
                restored = false;
            end
        end

        function tf = selectDynamicModuleTabIfActive(app, idx)
            tf = false;
            if idx < 1 || idx > numel(app.DynamicModuleTabs)
                return;
            end
            try
                ud = app.DynamicModuleTabs(idx).UserData;
                if isstruct(ud) && isfield(ud, 'active') && ~logical(ud.active)
                    return;
                end
                app.TabGroup.SelectedTab = app.DynamicModuleTabs(idx);
                tf = true;
            catch
            end
        end

        function configureModuleTabActiveState(app, tab, node, activeIds)
            nodeId = char(string(getField(app, node, 'id', '')));
            isActive = isempty(activeIds) || any(strcmp(activeIds, nodeId));
            baseTitle = truncateTabTitle(app, nodeId);
            if isActive
                tab.Title = baseTitle;
            else
                tab.Title = ['off: ' baseTitle];
            end
            try
                tab.Enable = ternary(app, isActive, 'on', 'off');
            catch
            end
            try
                ud = tab.UserData;
                if ~isstruct(ud)
                    ud = struct();
                end
                ud.nodeId = nodeId;
                ud.dynamic = true;
                ud.active = isActive;
                tab.UserData = ud;
            catch
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
            grid = uigridlayout(app.RuntimeInputsTab, [8 4]);
            grid.RowHeight = {32, 32, 32, 96, 32, 32, 32, 32};
            grid.ColumnWidth = {86, '1x', 115, 88};
            grid.Padding = [14 14 14 14];
            grid.RowSpacing = 10;
            grid.ColumnSpacing = 10;

            app.RuntimeFieldHandles = struct();
            app.RuntimeButtonHandles = struct();
            app.RuntimeValues = struct();
            app.RuntimeParseInfo = struct();

            addRuntimeInputSourceRow(app, grid, 1);
            addRuntimeProjectRow(app, grid, 2);
            addRuntimeRow(app, grid, 3, 'Raw data', 'rawDataPath', 'Raw image/data folder used by dataloader', 'Browse...');
            addRuntimeInventoryRow(app, grid, 4);
            addRuntimeTextRow(app, grid, 5, 'FOVs', 'fovs', 'all / 1,3,5 / 1:4');
            addRuntimeTextRow(app, grid, 6, 'Frames', 'frames', 'all / 1:50 / 1,5,9');
            addRuntimeTextRow(app, grid, 7, 'ROIs', 'rois', 'all / selected ROI ids');
            addRuntimePolicyRow(app, grid, 8);
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

            labels = {'Hub URL','Fallback URLs','User key','Password','Session token','Timeout','Remote root','Local root'};
            keys = {'baseUrl','fallbackBaseUrls','userKey','password','sessionToken','timeout','defaultRemoteProjectRoot','defaultLocalProjectRoot'};
            defaults = { ...
                getStructText(app, hub, 'baseUrl', 'http://detecdiv-hub.detecdiv.internal'), ...
                strjoin(normalizeHubStringList(app, getStructValue(app, hub, 'fallbackBaseUrls', {'http://127.0.0.1:8000'})), ', '), ...
                getStructText(app, hub, 'userKey', 'localdev'), ...
                '', ...
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
                elseif strcmp(keys{i}, 'password')
                    fld = createHubPasswordControl(app, app.RuntimeTab, [462 y 190 22]);
                    app.HubFieldHandles.connectButton = uibutton(app.RuntimeTab, 'push', ...
                        'Text', 'Connect', 'Position', [660 y-1 130 24], ...
                        'ButtonPushedFcn', @(~,~)connectHubButtonPushed(app));
                else
                    fld = uieditfield(app.RuntimeTab, 'text', 'Position', [462 y 330 22], 'Value', defaults{i});
                end
                if strcmp(keys{i}, 'password') && isprop(fld, 'DataChangedFcn')
                    fld.DataChangedFcn = @(src,~)hubRuntimeFieldChanged(app, 'hubPassword', src.Data);
                else
                    fld.ValueChangedFcn = @(src,~)hubRuntimeFieldChanged(app, '', []);
                end
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
                if strcmp(char(string(key)), 'hubPassword') && isstruct(value)
                    return;
                end
                app.RuntimeValues.(key) = char(string(value));
            end
            persistHubSettingsFromUi(app);
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

        function ctrl = createHubPasswordControl(app, parent, position) %#ok<INUSD>
            try
                ctrl = uihtml(parent, ...
                    'HTMLSource', hubPasswordHtml(app), ...
                    'Position', position, ...
                    'Data', '');
            catch
                ctrl = uieditfield(parent, 'text', 'Position', position, 'Value', '');
            end
        end

        function html = hubPasswordHtml(app) %#ok<INUSD>
            html = [ ...
                '<!doctype html><html><head><meta charset="utf-8">' ...
                '<style>' ...
                'html,body{margin:0;padding:0;background:transparent;overflow:hidden;}' ...
                'input{box-sizing:border-box;width:100%;height:22px;border:1px solid #8f8f8f;' ...
                'font:12px Arial,Helvetica,sans-serif;padding:1px 4px;background:white;color:#111;}' ...
                'input:focus{outline:1px solid #0072bd;border-color:#0072bd;}' ...
                '</style></head><body>' ...
                '<input id="hubPassword" type="password" autocomplete="off" spellcheck="false">' ...
                '<script>' ...
                'const input=document.getElementById("hubPassword");' ...
                'function push(){htmlComponent.Data=input.value;}' ...
                'input.addEventListener("input",push);' ...
                'input.addEventListener("change",push);' ...
                'input.addEventListener("blur",push);' ...
                'input.addEventListener("keyup",push);' ...
                'htmlComponent.addEventListener("DataChanged",function(){' ...
                'const d=htmlComponent.Data;' ...
                'if(d&&typeof d==="object"&&d.command==="flush"){push();return;}' ...
                'const v=(typeof d==="string")?d:"";' ...
                'if(input.value!==v){input.value=v;}' ...
                '});' ...
                '</script></body></html>' ...
                ];
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

            btn = uibutton(grid, 'push', 'Text', 'Browse existing...');
            btn.Layout.Row = row;
            btn.Layout.Column = 4;
            btn.Tooltip = 'Load an existing shallow project .mat file.';
            btn.ButtonPushedFcn = @(~,~)runtimeButtonPushed(app, 'projectPath');

            app.RuntimeFieldHandles.projectPath = field;
            app.RuntimeFieldHandles.projectSource = dd;
            app.RuntimeButtonHandles.projectPath = btn;
            app.RuntimeValues.projectPath = '';
        end

        function addRuntimeInputSourceRow(app, grid, row)
            label = uilabel(grid, 'Text', 'Source');
            label.Layout.Row = row;
            label.Layout.Column = 1;
            label.Tooltip = 'Choose where execution starts: existing extracted project ROIs, or raw data parsed by dataloader/ROI modules.';

            dd = uidropdown(grid);
            dd.Layout.Row = row;
            dd.Layout.Column = [2 4];
            dd.Items = {'Existing project ROIs','Raw data via dataloader'};
            dd.ItemsData = {'existing_rois','raw_dataloader'};
            dd.Value = 'existing_rois';
            dd.Tooltip = ['Existing project ROIs uses channels/dataseries already present in the shallow project. ' ...
                'Raw data via dataloader enables dataloader, ROI definition and roiExtract modules.'];
            dd.ValueChangedFcn = @(src,~)runtimeFieldChanged(app, 'inputSourceMode', src.Value);

            app.RuntimeFieldHandles.inputSourceMode = dd;
            app.RuntimeValues.inputSourceMode = 'existing_rois';
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

        function addRuntimeTextRow(app, grid, row, labelText, key, placeholder)
            label = uilabel(grid, 'Text', labelText);
            label.Layout.Row = row;
            label.Layout.Column = 1;

            field = uieditfield(grid, 'text');
            field.Layout.Row = row;
            field.Layout.Column = [2 4];
            try
                field.Placeholder = placeholder;
            catch
                field.Value = '';
            end
            field.ValueChangedFcn = @(src,~)runtimeFieldChanged(app, key, src.Value);

            app.RuntimeFieldHandles.(key) = field;
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
            dd.Layout.Column = [2 4];
            dd.Items = {'Skip existing outputs','Replace existing outputs','Append/update existing outputs','Error if outputs exist'};
            dd.ItemsData = {'skip','replace','upsert','error'};
            dd.Value = 'skip';
            dd.Tooltip = sprintf(['Controls what happens when module outputs already exist.\n\n' ...
                'Skip existing outputs: keep existing outputs and only compute missing ones when possible. Best with Resume previous progress.\n' ...
                'Replace existing outputs: overwrite outputs produced by the selected modules. Best with Restart from scratch.\n' ...
                'Append/update existing outputs: preserve existing content and add/update entries where the backend supports upsert behavior.\n' ...
                'Error if outputs exist: stop early if a target output already exists.\n\n' ...
                'Resume options are separate: they control run checkpoints/progress, not overwrite behavior.']);
            dd.ValueChangedFcn = @(src,~)runtimeFieldChanged(app, 'outputPolicy', src.Value);

            app.RuntimeFieldHandles.outputPolicy = dd;
            app.RuntimeValues.outputPolicy = 'skip';
            app.RuntimeValues.outputPolicyUserChosen = false;
        end

        function runtimeFieldChanged(app, key, value)
            app.RuntimeValues.(key) = char(string(value));
            if strcmp(char(string(key)), 'inputSourceMode')
                d = openRuntimeProgress(app, 'Runtime source', 'Switching runtime source...');
                cleanupObj = onCleanup(@()closeRuntimeProgress(app, d)); %#ok<NASGU>
                updateRuntimeProgress(app, d, 'Updating selected modules...');
                refreshSelectedModuleTable(app);
                if strcmpi(char(string(value)), 'raw_dataloader')
                    updateRuntimeProgress(app, d, 'Enabling raw-data modules...');
                    enableRawPrepNodesInRunTable(app);
                    if isfield(app.RuntimeValues, 'rawDataPathActive') && ~isempty(app.RuntimeValues.rawDataPathActive)
                        setRuntimeControlValue(app, 'rawDataPath', app.RuntimeValues.rawDataPathActive);
                        app.RuntimeValues.rawDataPath = app.RuntimeValues.rawDataPathActive;
                    end
                    rawDataPath = getRuntimeValue(app, 'rawDataPath');
                    if ~isempty(strtrim(rawDataPath))
                        updateRuntimeProgress(app, d, 'Parsing raw data inventory...');
                        parseRuntimeRawDataPath(app, rawDataPath);
                    else
                        updateRuntimeProgress(app, d, 'Refreshing available resources...');
                        updateRuntimeResourceInventory(app);
                    end
                else
                    updateRuntimeProgress(app, d, 'Keeping existing project ROI modules optional...');
                    disableRawPrepNodesInRunTable(app);
                    if ~isempty(app.CurrentProject) && isa(app.CurrentProject, 'shallow')
                        updateRuntimeProgress(app, d, 'Loading project inventory...');
                        refreshRuntimeFromProject(app);
                    end
                    updateRuntimeProgress(app, d, 'Refreshing available resources...');
                    updateRuntimeResourceInventory(app);
                end
                updateRuntimeProgress(app, d, 'Updating runtime controls...');
                updateRuntimeInputStates(app);
                updateRuntimeProgress(app, d, 'Redrawing pipeline graph...');
                redrawGraph(app);
                updateRuntimeProgress(app, d, 'Refreshing module tabs...');
                refreshModuleTabs(app);
                updateRuntimeProgress(app, d, 'Checking pipeline...');
                refreshValidationReport(app);
                return;
            end
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
                redrawGraph(app);
                refreshModuleTabs(app);
            end
            refreshValidationReport(app);
        end

        function tf = runtimeValueAffectsBindings(app, key) %#ok<INUSD>
            tf = any(strcmp(char(string(key)), {'inputSourceMode','projectPath','rawDataPath','fovs','frames','rois'}));
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
            items = [items {'New project...'}];
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
                drawnow limitrate;
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
            clearRuntimeDataSeriesCache(app);
            app.RuntimeInventoryRefreshSuspended = true;
            cleanupObj = onCleanup(@()setRuntimeInventoryRefreshSuspended(app, false)); %#ok<NASGU>
            [pth, file] = shallowObj.getPath;
            setRuntimeValuePreserveParse(app, 'projectPath', fullfile(pth, [file '.mat']));
            refreshRuntimeFromProject(app);
            app.RuntimeInventoryRefreshSuspended = false;
            updateRuntimeResourceInventory(app);
            if runtimeStartsFromExistingProject(app)
                disableRawPrepNodesInRunTable(app);
            end
            refreshProjectDropdown(app);
            updateRuntimeInputStates(app);
            latestRunApplied = applyLatestRunForCurrentPipeline(app, false);
            redrawGraph(app);
            refreshModuleTabs(app);
            refreshValidationReport(app);
            if latestRunApplied && ~isempty(app.CurrentRun) && isa(app.CurrentRun, 'pipelineRun')
                try
                    app.RuninformationhereLabel.Text = ['Pipeline loaded with latest run: ' char(string(app.CurrentRun.runId))];
                catch
                end
            end
        end

        function setRuntimeInventoryRefreshSuspended(app, value)
            app.RuntimeInventoryRefreshSuspended = logical(value);
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
            sourcePath = projectSourcePath(app, shallowObj);
            if ~isempty(sourcePath)
                setRuntimeValuePreserveParse(app, 'rawDataPath', sourcePath);
            elseif runtimeStartsFromExistingProject(app)
                setRuntimeValuePreserveParse(app, 'rawDataPath', 'Project source path not resolved');
            end
        end

        function sourcePath = projectSourcePath(app, shallowObj) %#ok<INUSD>
            sourcePath = '';
            if isempty(shallowObj) || ~isa(shallowObj, 'shallow')
                return;
            end
            try
                fovs = shallowObj.fov;
            catch
                fovs = [];
            end
            candidates = {};
            for i = 1:numel(fovs)
                candidates = [candidates fovSourcePathCandidates(app, fovs(i))]; %#ok<AGROW>
            end
            candidates = normalizeSourcePathCandidates(app, candidates);
            candidates = unique(candidates(~cellfun(@isempty, candidates)), 'stable');
            if isempty(candidates)
                return;
            end
            sourcePath = candidates{1};
            if numel(candidates) > 1
                sourcePath = [sourcePath sprintf('  (+%d other source paths)', numel(candidates)-1)];
            end
        end

        function candidates = fovSourcePathCandidates(app, f) %#ok<INUSD>
            candidates = {};
            propNames = {'omeZarrPath','ndtiffPath','srcpath','tiffSource'};
            for i = 1:numel(propNames)
                p = propNames{i};
                try
                    if isprop(f, p) && ~isempty(f.(p))
                        candidates{end+1} = char(string(f.(p))); %#ok<AGROW>
                    end
                catch
                end
            end
            try
                if isprop(f, 'srclist') && iscell(f.srclist) && ~isempty(f.srclist)
                    for ch = 1:numel(f.srclist)
                        if isempty(f.srclist{ch})
                            continue;
                        end
                        first = f.srclist{ch}{1};
                        if ischar(first) || isstring(first)
                            [pth, ~, ~] = fileparts(char(string(first)));
                            candidates{end+1} = pth; %#ok<AGROW>
                        end
                    end
                end
            catch
            end
        end

        function candidates = normalizeSourcePathCandidates(app, raw) %#ok<INUSD>
            candidates = {};
            if isempty(raw)
                return;
            end
            for i = 1:numel(raw)
                item = raw{i};
                if isempty(item)
                    continue;
                end
                if iscell(item)
                    sub = normalizeSourcePathCandidates(app, item);
                    candidates = [candidates sub]; %#ok<AGROW>
                elseif ischar(item)
                    if isrow(item)
                        candidates{end+1} = strtrim(item); %#ok<AGROW>
                    elseif ismatrix(item)
                        vals = cellstr(item);
                        vals = cellfun(@strtrim, vals, 'UniformOutput', false);
                        candidates = [candidates vals(:)']; %#ok<AGROW>
                    end
                elseif isstring(item)
                    vals = cellstr(item(:));
                    vals = cellfun(@strtrim, vals, 'UniformOutput', false);
                    candidates = [candidates vals(:)']; %#ok<AGROW>
                else
                    try
                        candidates{end+1} = strtrim(char(string(item))); %#ok<AGROW>
                    catch
                    end
                end
            end
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
                if ~runtimeStartsFromExistingProject(app)
                    app.RuntimeValues.rawDataPathActive = value;
                end
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
                if isfield(app.RuntimeParseInfo, 'ok') && app.RuntimeParseInfo.ok
                    applyRuntimeParseInfo(app, app.RuntimeParseInfo);
                    updateRuntimeResourceInventory(app);
                end
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
            if any(strcmp(char(string(key)), {'projectPath','fovs','rois'}))
                clearRuntimeDataSeriesCache(app);
            end
            if app.RuntimeInventoryRefreshSuspended
                return;
            end
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
            if ~runtimeStartsFromExistingProject(app)
                lines = {'Raw data parser inventory:'};
                rawPath = getRuntimeValue(app, 'rawDataPath');
                if isempty(strtrim(rawPath))
                    lines{end+1} = 'Raw data: not selected';
                    lines{end+1} = 'FOVs: unresolved';
                    lines{end+1} = 'Frames: unresolved';
                    lines{end+1} = 'Channels: unresolved';
                    app.RuntimeFieldHandles.availableResources.Value = lines;
                    return;
                end
                lines{end+1} = ['Raw data: ' rawPath];
                if isfield(app.RuntimeParseInfo, 'ok') && ~app.RuntimeParseInfo.ok
                    msg = '';
                    if isfield(app.RuntimeParseInfo, 'message')
                        msg = char(string(app.RuntimeParseInfo.message));
                    end
                    lines{end+1} = ['Parser status: failed' ternary(app, isempty(msg), '', [' - ' msg])];
                    app.RuntimeFieldHandles.availableResources.Value = lines;
                    return;
                end
                if isfield(app.RuntimeParseInfo, 'fovCount') && app.RuntimeParseInfo.fovCount > 0
                    lines{end+1} = sprintf('FOVs: 1:%d', round(double(app.RuntimeParseInfo.fovCount)));
                else
                    lines{end+1} = 'FOVs: unresolved';
                end
                if isfield(app.RuntimeParseInfo, 'maxFrame') && ~isempty(app.RuntimeParseInfo.maxFrame)
                    lines{end+1} = sprintf('Frames: 1:%d', round(double(app.RuntimeParseInfo.maxFrame)));
                else
                    lines{end+1} = 'Frames: unresolved';
                end
                channels = runtimeConcreteChannels(app);
                if isempty(channels)
                    lines{end+1} = 'Channels: none detected yet';
                else
                    lines{end+1} = ['Channels: ' strjoin(channels, ', ')];
                end
                app.RuntimeFieldHandles.availableResources.Value = lines;
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
                if isfield(app.RuntimeDataSeriesCache, 'sampledRoiCount') && app.RuntimeDataSeriesCache.sampledRoiCount > 0
                    dsText = [dsText sprintf(' (sampled %d ROI(s) across %d FOV(s))', ...
                        app.RuntimeDataSeriesCache.sampledRoiCount, ...
                        max(1, app.RuntimeDataSeriesCache.sampledFovCount))];
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
            startsFromProject = runtimeStartsFromExistingProject(app);

            if ~isempty(projectPath) && ~projectOk
                markRuntimeField(app, 'projectPath', 'missing', 'Project must be an existing folder or project .mat file.');
            end

            if startsFromProject
                sourcePath = projectSourcePath(app, app.CurrentProject);
                if ~isempty(sourcePath)
                    setRuntimeControlValue(app, 'rawDataPath', sourcePath);
                    app.RuntimeValues.rawDataPath = sourcePath;
                    tip = 'Read-only: raw source path recorded in the selected project/FOVs.';
                else
                    setRuntimeControlValue(app, 'rawDataPath', 'Project source path not resolved');
                    app.RuntimeValues.rawDataPath = 'Project source path not resolved';
                    tip = 'Read-only: no raw source path could be inferred from the selected project.';
                end
                markRuntimeField(app, 'rawDataPath', 'blocked', tip);
                setRuntimeButtonEnabled(app, 'rawDataPath', false);
            elseif pipelineHasNodeType(app, 'dataLoader') && ~rawOk
                markRuntimeField(app, 'rawDataPath', 'missing', 'Required when a dataloader run has no existing project input.');
                setRuntimeButtonEnabled(app, 'rawDataPath', true);
            else
                setRuntimeButtonEnabled(app, 'rawDataPath', true);
            end

            if startsFromProject && ~projectOk
                markRuntimeField(app, 'channels', 'blocked', 'Select an existing project before selecting ROI channels.');
                setRuntimeButtonEnabled(app, 'channels', false);
            elseif ~startsFromProject && ~projectOk && ~rawOk
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
            if isRoiDefinitionNode(app, node)
                buildRoiDefinitionModuleTab(app, parentTab, node);
                return;
            end
            if strcmpi(char(string(getField(app, node, 'type', ''))), 'dataLoader')
                buildDataLoaderTab(app, parentTab, node);
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

            colCount = 1;
            rowCount = 2 * double(showClassifierReference) + 2 * double(showBindings) + ...
                2 * double(showRuntime) + double(showStatic);
            grid = uigridlayout(parentTab, [rowCount colCount]);
            rowHeights = {};
            if showClassifierReference
                rowHeights = [rowHeights {24, 76}]; %#ok<AGROW>
            end
            if showBindings
                if strcmpi(char(string(getField(app, node, 'type', ''))), 'roiExtract')
                    rowHeights = [rowHeights {24, 210}]; %#ok<AGROW>
                else
                    rowHeights = [rowHeights {24, min(160, 42 + 34 * size(bindingData, 1))}]; %#ok<AGROW>
                end
            end
            if showRuntime
                rowHeights = [rowHeights {24, '1x'}]; %#ok<AGROW>
            end
            if showStatic
                rowHeights = [rowHeights {34}]; %#ok<AGROW>
            end
            grid.RowHeight = rowHeights;
            grid.ColumnWidth = {'1x'};
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

                if strcmpi(char(string(getField(app, node, 'type', ''))), 'roiExtract')
                    section = buildRoiExtractBindingSection(app, grid, node);
                else
                    section = buildBindingSection(app, grid, bindingData, node, true);
                end
                section.Layout.Row = row + 1;
                section.Layout.Column = layoutSpan(app, 1, colCount);
                row = row + 2;
            end

            if showRuntime
                runtimeLabel = uilabel(grid, 'Text', 'Runtime parameters');
                runtimeLabel.FontWeight = 'bold';
                runtimeLabel.Layout.Row = row;
                runtimeLabel.Layout.Column = 1;

                section = buildParamSection(app, grid, runtimeData, node, app.Data.runMode, 'runtime');
                section.Layout.Row = row + 1;
                section.Layout.Column = 1;
                row = row + 2;
            end

            if showStatic
                staticPanel = uigridlayout(grid, [1 3]);
                staticPanel.ColumnWidth = {160, '1x', 180};
                staticPanel.RowHeight = {28};
                staticPanel.Padding = [0 0 0 0];
                staticPanel.ColumnSpacing = 8;
                staticPanel.Layout.Row = row;
                staticPanel.Layout.Column = 1;

                label = uilabel(staticPanel, 'Text', 'Static parameters');
                label.FontWeight = 'bold';
                label.Layout.Row = 1;
                label.Layout.Column = 1;

                summary = uilabel(staticPanel, 'Text', staticParamSummary(app, staticData), ...
                    'FontColor', [0.35 0.35 0.35], 'Interpreter', 'none');
                summary.Layout.Row = 1;
                summary.Layout.Column = 2;

                btn = uibutton(staticPanel, 'push', 'Text', 'Static parameters...', ...
                    'ButtonPushedFcn', @(~,~)app.openStaticParametersDialog(node));
                btn.Layout.Row = 1;
                btn.Layout.Column = 3;
            end
        end

        function tf = isRoiDefinitionNode(app, node) %#ok<INUSD>
            nodeType = lower(char(string(getField(app, node, 'type', ''))));
            tf = any(strcmp(nodeType, {'roipattern','roiidentify','roimanual','roigrid','roitracked'}));
        end

        function buildRoiDefinitionModuleTab(app, parentTab, node)
            bindingData = bindingTableData(app, node);
            showBindings = ~isempty(bindingData);
            rowCount = 2 * double(showBindings) + 2;
            grid = uigridlayout(parentTab, [rowCount 1]);
            rowHeights = {};
            if showBindings
                rowHeights = [rowHeights {24, min(150, 42 + 34 * size(bindingData, 1))}]; %#ok<AGROW>
            end
            rowHeights = [rowHeights {24, '1x'}];
            grid.RowHeight = rowHeights;
            grid.ColumnWidth = {'1x'};
            grid.Padding = [12 10 12 12];
            grid.RowSpacing = 8;

            row = 1;
            if showBindings
                bindingLabel = uilabel(grid, 'Text', 'Bindings');
                bindingLabel.FontWeight = 'bold';
                bindingLabel.Layout.Row = row;
                section = buildBindingSection(app, grid, bindingData, node, true);
                section.Layout.Row = row + 1;
                row = row + 2;
            end

            titleLabel = uilabel(grid, 'Text', roiDefinitionTitle(app, node));
            titleLabel.FontWeight = 'bold';
            titleLabel.Layout.Row = row;

            body = uipanel(grid, 'BorderType', 'none');
            body.Layout.Row = row + 1;
            switch lower(char(string(getField(app, node, 'type', ''))))
                case {'roipattern','roiidentify'}
                    buildRoiPatternTab(app, body, node);
                case 'roigrid'
                    buildRoiGridTab(app, body, node);
                case 'roimanual'
                    buildRoiManualTab(app, body, node);
                case 'roitracked'
                    buildRoiTrackedTab(app, body, node);
                otherwise
                    buildGenericRoiDefinitionTab(app, body, node);
            end
        end

        function titleText = roiDefinitionTitle(app, node) %#ok<INUSD>
            switch lower(char(string(getField(app, node, 'type', ''))))
                case {'roipattern','roiidentify'}
                    titleText = 'ROI pattern definition';
                case 'roigrid'
                    titleText = 'ROI grid definition';
                case 'roimanual'
                    titleText = 'Manual ROI definition';
                case 'roitracked'
                    titleText = 'Tracked ROI definition';
                otherwise
                    titleText = 'ROI definition';
            end
        end

        function buildDataLoaderTab(app, parentTab, node) %#ok<INUSD>
            grid = uigridlayout(parentTab, [4 1]);
            grid.RowHeight = {24, 48, 24, '1x'};
            grid.Padding = [12 10 12 12];
            grid.RowSpacing = 8;

            title = uilabel(grid, 'Text', 'Runtime parser outputs');
            title.FontWeight = 'bold';
            title.Layout.Row = 1;

            mode = getRuntimeValue(app, 'inputSourceMode');
            if isempty(mode), mode = 'existing_rois'; end
            rawPath = getRuntimeValue(app, 'rawDataPath');
            if isempty(rawPath), rawPath = '<not selected>'; end
            modeText = 'Existing project ROIs';
            if strcmpi(mode, 'raw_dataloader')
                modeText = 'Raw data via dataloader';
            end
            summary = uilabel(grid, 'Text', sprintf('Source: %s\nRaw data: %s', modeText, rawPath), ...
                'Interpreter', 'none', 'FontColor', [0.25 0.25 0.25]);
            summary.Layout.Row = 2;

            invLabel = uilabel(grid, 'Text', 'Detected inventory');
            invLabel.FontWeight = 'bold';
            invLabel.Layout.Row = 3;

            lines = {'Dataloader reads a runtime path and exposes parsed positions/channels/frames to downstream modules.'};
            if runtimeStartsFromExistingProject(app)
                lines{end+1} = 'Inactive for this run: execution starts from existing project ROIs.';
            end
            if isfield(app.RuntimeParseInfo, 'fovCount') && ~isempty(app.RuntimeParseInfo.fovCount)
                lines{end+1} = sprintf('FOVs: 1:%d', app.RuntimeParseInfo.fovCount);
            end
            if isfield(app.RuntimeParseInfo, 'maxFrame') && ~isempty(app.RuntimeParseInfo.maxFrame)
                lines{end+1} = sprintf('Frames: 1:%d', round(double(app.RuntimeParseInfo.maxFrame)));
            end
            channels = runtimeConcreteChannels(app);
            if isempty(channels)
                lines{end+1} = 'Channels: none detected yet';
            else
                lines{end+1} = ['Channels: ' strjoin(channels, ', ')];
            end
            dsNames = runtimeDataSeriesNames(app);
            if ~isempty(dsNames)
                maxShown = min(numel(dsNames), 12);
                lines{end+1} = ['Project dataseries: ' strjoin(dsNames(1:maxShown), ', ')];
            end

            txt = uitextarea(grid, 'Editable', 'off', 'Value', lines);
            txt.Layout.Row = 4;
        end

        function tf = isClassifierNode(app, node) %#ok<INUSD>
            tf = strcmpi(char(string(getField(app, node, 'type', ''))), 'classifier');
        end

        function txt = staticParamSummary(app, staticData) %#ok<INUSD>
            n = size(staticData, 1);
            if n == 0
                txt = 'No static parameter.';
            elseif n == 1
                txt = '1 template parameter';
            else
                txt = sprintf('%d template parameters', n);
            end
        end

        function openStaticParametersDialog(app, node)
            nodeId = char(string(getField(app, node, 'id', 'module')));
            fig = uifigure('Name', ['Static parameters - ' nodeId], ...
                'Position', staticParametersDialogPosition(app, node));
            grid = uigridlayout(fig, [3 1]);
            grid.RowHeight = {34, '1x', 24};
            grid.Padding = [12 12 12 12];
            grid.RowSpacing = 10;

            headerBar = uigridlayout(grid, [1 3]);
            headerBar.ColumnWidth = {'1x', 110, 90};
            headerBar.RowHeight = {28};
            headerBar.Padding = [0 0 0 0];
            headerBar.ColumnSpacing = 8;
            headerBar.Layout.Row = 1;

            header = uilabel(headerBar, 'Text', ['Static/template parameters for ' nodeId], 'Interpreter', 'none');
            header.FontWeight = 'bold';
            header.Layout.Row = 1;
            header.Layout.Column = 1;

            refreshBtn = uibutton(headerBar, 'push', 'Text', 'Refresh', ...
                'ButtonPushedFcn', @(~,~)app.refreshStaticParametersDialog(fig, nodeId));
            refreshBtn.Layout.Row = 1;
            refreshBtn.Layout.Column = 2;

            closeBtn = uibutton(headerBar, 'push', 'Text', 'Close', ...
                'ButtonPushedFcn', @(~,~)delete(fig));
            closeBtn.Layout.Row = 1;
            closeBtn.Layout.Column = 3;

            bodyPanel = uipanel(grid, 'BorderType', 'none');
            bodyPanel.Layout.Row = 2;
            try
                bodyPanel.Scrollable = 'on';
            catch
            end
            fig.UserData = struct('nodeId', nodeId, 'bodyPanel', bodyPanel, 'refreshButton', refreshBtn);
            populateStaticParametersDialogBody(app, bodyPanel, nodeId);

            hint = uilabel(grid, 'Text', 'Changes are saved in the pipeline template.', ...
                'FontColor', [0.35 0.35 0.35], 'Interpreter', 'none');
            hint.Layout.Row = 3;
        end

        function refreshStaticParametersDialog(app, fig, nodeId)
            if isempty(fig) || ~isvalid(fig)
                return;
            end
            focus = captureTabFocus(app);
            d = openRuntimeProgress(app, 'Static parameters', 'Refreshing pipeline tabs...');
            drawnow limitrate;
            idx = find(strcmp({app.Data.nodes.id}, nodeId), 1);
            if isempty(idx)
                closeRuntimeProgress(app, d);
                return;
            end
            bodyPanel = [];
            try
                if isstruct(fig.UserData) && isfield(fig.UserData, 'bodyPanel') && isvalid(fig.UserData.bodyPanel)
                    bodyPanel = fig.UserData.bodyPanel;
                end
            catch
                bodyPanel = [];
            end
            if isempty(bodyPanel)
                closeRuntimeProgress(app, d);
                return;
            end
            refreshBtn = [];
            try
                if isstruct(fig.UserData) && isfield(fig.UserData, 'refreshButton') && isvalid(fig.UserData.refreshButton)
                    refreshBtn = fig.UserData.refreshButton;
                    refreshBtn.Enable = 'off';
                end
            catch
                refreshBtn = [];
            end
            cleanupObj = onCleanup(@()finishStaticParameterRefresh(app, d, refreshBtn, focus)); %#ok<NASGU>
            updateRuntimeProgress(app, d, 'Rebuilding pipeline module tabs...');
            refreshModuleTabs(app);
            updateRuntimeProgress(app, d, 'Checking pipeline bindings...');
            refreshValidationReport(app);
            updateRuntimeProgress(app, d, 'Refreshing static parameter editor...');
            populateStaticParametersDialogBody(app, bodyPanel, nodeId);
            resizeStaticParametersDialog(app, fig, app.Data.nodes(idx));
            drawnow limitrate;
        end

        function finishStaticParameterRefresh(app, progressDlg, refreshBtn, focus)
            try
                closeRuntimeProgress(app, progressDlg);
            catch
            end
            try
                if ~isempty(refreshBtn) && isvalid(refreshBtn)
                    refreshBtn.Enable = 'on';
                end
            catch
            end
            try
                restoreTabFocus(app, focus);
            catch
            end
        end

        function populateStaticParametersDialogBody(app, bodyPanel, nodeId)
            try
                delete(bodyPanel.Children);
            catch
            end
            idx = find(strcmp({app.Data.nodes.id}, nodeId), 1);
            if isempty(idx)
                grid = uigridlayout(bodyPanel, [1 1]);
                grid.Padding = [0 0 0 0];
                uilabel(grid, 'Text', 'Module no longer exists.', ...
                    'FontAngle', 'italic', 'FontColor', [0.35 0.35 0.35]);
                return;
            end
            node = app.Data.nodes(idx);
            staticData = paramsToTableData(app, node, 'static');
            if isempty(staticData)
                grid = uigridlayout(bodyPanel, [1 1]);
                grid.Padding = [0 0 0 0];
                uilabel(grid, 'Text', 'No static parameter is declared for this module.', ...
                    'FontAngle', 'italic', 'FontColor', [0.35 0.35 0.35]);
            else
                buildParamSection(app, bodyPanel, staticData, node, true, 'static');
            end
        end

        function pos = staticParametersDialogPosition(app, node)
            staticData = paramsToTableData(app, node, 'static');
            nParams = max(1, size(staticData, 1));
            rowHeight = 28;
            rowSpacing = 6;
            bodyHeight = nParams * rowHeight + max(0, nParams - 1) * rowSpacing + 18;
            desiredHeight = 34 + bodyHeight + 24 + 48;
            desiredWidth = 900;
            try
                screen = get(0, 'ScreenSize');
            catch
                screen = [1 1 1280 800];
            end
            maxWidth = max(760, screen(3) - 80);
            maxHeight = max(520, screen(4) - 110);
            width = min(max(820, desiredWidth), maxWidth);
            height = min(max(420, desiredHeight), maxHeight);

            base = [];
            try
                if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                    base = app.UIFigure.Position;
                end
            catch
                base = [];
            end
            if isempty(base)
                x = screen(1) + (screen(3) - width) / 2;
                y = screen(2) + (screen(4) - height) / 2;
            else
                x = base(1) + (base(3) - width) / 2;
                y = base(2) + (base(4) - height) / 2;
            end
            x = max(screen(1) + 20, min(x, screen(1) + screen(3) - width - 20));
            y = max(screen(2) + 40, min(y, screen(2) + screen(4) - height - 60));
            pos = [x y width height];
        end

        function resizeStaticParametersDialog(app, fig, node)
            if isempty(fig) || ~isvalid(fig)
                return;
            end
            target = staticParametersDialogPosition(app, node);
            pos = fig.Position;
            if pos(3) < target(3) || pos(4) < target(4)
                fig.Position = [pos(1) pos(2) max(pos(3), target(3)) max(pos(4), target(4))];
            end
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
                [~, baseName, extName] = fileparts(filePath);
                if ~strcmpi(extName, '.mat') || isempty(regexp(baseName, '_classification$', 'once')) || ...
                        ~isempty(regexp(baseName, '_classification_\d+$', 'once'))
                    error('pipeline2:ClassifierSnapshotOnly', ...
                        'Please link the current classifier snapshot named <classifierId>_classification.mat, not a numbered backup.');
                end
                [classiObj, msg] = loadClassifierSnapshotStrict(app, filePath);
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
                if strcmpi(actualPkg, 'cellposesam')
                    app.Data.nodes(idx).params = copyCellposeStaticParamsFromClassi(app, app.Data.nodes(idx).params, classiObj);
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

        function params = copyCellposeStaticParamsFromClassi(app, params, classiObj) %#ok<INUSD>
            if ~isstruct(params)
                params = struct();
            end
            tp = struct();
            try
                if isobject(classiObj) && isprop(classiObj, 'trainingParam') && isstruct(classiObj.trainingParam)
                    tp = classiObj.trainingParam;
                elseif isstruct(classiObj) && isfield(classiObj, 'trainingParam') && isstruct(classiObj.trainingParam)
                    tp = classiObj.trainingParam;
                end
            catch
                tp = struct();
            end
            keys = {'diameter','min_size','flow_threshold','cell_prob_threshold'};
            defaults = {NaN, 10, 0.4, 0};
            for i = 1:numel(keys)
                key = keys{i};
                if isfield(params, key) && ~isempty(params.(key))
                    continue;
                end
                if isfield(tp, key) && ~isempty(tp.(key))
                    params.(key) = tp.(key);
                else
                    params.(key) = defaults{i};
                end
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
            [classiObj, msg] = loadClassifierSnapshotStrict(app, snap);
            if isempty(classiObj) || ~isa(classiObj, 'classi')
                if isempty(msg)
                    msg = 'Linked file is not a valid classi object.';
                end
                error('pipeline2:BadLinkedClassifier', '%s', msg);
            end
        end

        function [classiObj, msg] = loadClassifierSnapshotStrict(app, filePath) %#ok<INUSD>
            classiObj = [];
            msg = '';
            if isempty(filePath) || exist(filePath, 'file') ~= 2
                msg = ['Classifier file not found: ' char(string(filePath))];
                return;
            end
            try
                S = load(filePath);
            catch ME
                msg = ME.message;
                return;
            end

            if isfield(S, 'classiObj') && isa(S.classiObj, 'classi')
                classiObj = S.classiObj;
            else
                names = fieldnames(S);
                for ii = 1:numel(names)
                    cand = S.(names{ii});
                    if isa(cand, 'classi')
                        classiObj = cand;
                        break;
                    end
                end
            end

            if isempty(classiObj) || ~isa(classiObj, 'classi')
                msg = 'This file does not contain a classi object.';
                classiObj = [];
                return;
            end
            if numel(classiObj) > 1
                [~, expectedId] = fileparts(filePath);
                expectedId = regexprep(expectedId, '_classification$', '');
                ids = arrayfun(@(x) char(string(x.strid)), classiObj, 'UniformOutput', false);
                match = find(strcmp(ids, expectedId), 1, 'first');
                if isempty(match)
                    match = 1;
                end
                classiObj = classiObj(match);
            end

            try
                [pth, file] = fileparts(filePath);
                file = regexprep(file, '_classification$', '');
                if ispc
                    pth = [pth '\'];
                else
                    pth = [pth '/'];
                end
                classiObj.setPath(pth, file);
            catch
            end

            try
                classiObj.category = classiNormalizeCategory(classiObj.category);
            catch
            end
            try
                if isprop(classiObj, 'run') && isstruct(classiObj.run) && isfield(classiObj.run, 'active')
                    classiObj.run.active = false;
                end
                classiObj.runNormalizePaths();
            catch
            end
            try
                classiObj.syncDatasetFromLegacy();
                classiObj.syncLegacyFromDataset();
            catch
            end
        end

        function clearClassifierArtifactLink(app, node)
            nodeId = char(string(getField(app, node, 'id', '')));
            idx = find(strcmp({app.Data.nodes.id}, nodeId), 1);
            if isempty(idx) || ~isfield(app.Data.nodes(idx), 'params') || ~isstruct(app.Data.nodes(idx).params)
                return;
            end
            removeKeys = {'modulePath','moduleId','moduleVar','classes','classifyFun','trainingFun','trainingParam'};
            for i = 1:numel(removeKeys)
                if isfield(app.Data.nodes(idx).params, removeKeys{i})
                    app.Data.nodes(idx).params = rmfield(app.Data.nodes(idx).params, removeKeys{i});
                end
            end
            refreshAfterModelChange(app);
        end

        function buildRoiPatternTab(app, parentTab, node)
            nodeId = char(string(getField(app, node, 'id', '')));
            runtimeData = paramsToTableData(app, node, 'runtime');

            grid = uigridlayout(parentTab, [4 1]);
            grid.RowHeight = {86, 32, 24, '1x'};
            grid.ColumnWidth = {'1x'};
            grid.Padding = [12 10 12 12];
            grid.RowSpacing = 8;

            [statusLines, statusColor] = roiPatternStatus(app, node);
            status = uitextarea(grid, 'Editable', 'off', 'Value', statusLines);
            status.Layout.Row = 1;
            try
                status.FontColor = statusColor;
            catch
            end

            actions = uigridlayout(grid, [1 4]);
            actions.RowHeight = {28};
            actions.ColumnWidth = {150, 105, 105, '1x'};
            actions.Padding = [0 0 0 0];
            actions.ColumnSpacing = 8;
            actions.Layout.Row = 2;

            nodePatternParams = getField(app, node, 'params', struct());
            hasNodePattern = hasUsableRoiPattern(app, nodePatternParams);
            editText = ternary(app, hasNodePattern, 'Review pattern', 'Generate pattern');
            hintText = ternary(app, hasNodePattern, ...
                'Pattern is stored in this module; Review pattern opens it with image context.', ...
                'Please generate pattern first. Raw data context is required.');

            editBtn = uibutton(actions, 'push', 'Text', editText, ...
                'ButtonPushedFcn', @(~,~)openWorkflowRoiEditor(app, nodeId));
            editBtn.Layout.Row = 1;
            editBtn.Layout.Column = 1;
            editBtn.Enable = ternary(app, hasRoiWorkflowImageContext(app), 'on', 'off');
            editBtn.Tooltip = 'Open the ROI workflow to generate or review the module pattern from a raw image frame, FOV and channel.';

            viewBtn = uibutton(actions, 'push', 'Text', 'View pattern', ...
                'ButtonPushedFcn', @(~,~)viewRoiPatternArtifact(app, nodeId));
            viewBtn.Layout.Row = 1;
            viewBtn.Layout.Column = 2;
            viewBtn.Enable = ternary(app, hasNodePattern, 'on', 'off');
            viewBtn.Tooltip = 'Display the pattern artifact stored in this module.';

            clearBtn = uibutton(actions, 'push', 'Text', 'Clear artifact', ...
                'ButtonPushedFcn', @(~,~)clearRoiPatternNodeArtifact(app, nodeId));
            clearBtn.Layout.Row = 1;
            clearBtn.Layout.Column = 3;
            clearBtn.Enable = ternary(app, hasNodePattern, 'on', 'off');
            clearBtn.Tooltip = 'Remove the pattern artifact stored in this module.';

            hint = uilabel(actions, 'Text', hintText, ...
                'FontColor', [0.35 0.35 0.35], 'Interpreter', 'none');
            hint.Layout.Row = 1;
            hint.Layout.Column = 4;

            runtimeLabel = uilabel(grid, 'Text', 'Runtime parameters');
            runtimeLabel.FontWeight = 'bold';
            runtimeLabel.Layout.Row = 3;

            if isempty(runtimeData)
                msg = uilabel(grid, 'Text', 'No runtime parameter is declared for this ROI pattern module.', ...
                    'FontAngle', 'italic', 'FontColor', [0.35 0.35 0.35]);
                msg.Layout.Row = 4;
            else
                section = buildParamSection(app, grid, runtimeData, node, app.Data.runMode, 'runtime');
                section.Layout.Row = 4;
            end
        end

        function buildRoiTrackedTab(app, parentTab, node)
            nodeId = char(string(getField(app, node, 'id', '')));
            runtimeData = paramsToTableData(app, node, 'runtime');

            grid = uigridlayout(parentTab, [4 1]);
            grid.RowHeight = {52, 32, 24, '1x'};
            grid.ColumnWidth = {'1x'};
            grid.Padding = [12 10 12 12];
            grid.RowSpacing = 8;

            [statusLines, statusColor] = roiTrackedStatus(app, node);
            txt = uitextarea(grid, 'Editable', 'off', 'Value', statusLines);
            txt.Layout.Row = 1;
            try
                txt.FontColor = statusColor;
            catch
            end

            actions = uigridlayout(grid, [1 3]);
            actions.RowHeight = {28};
            actions.ColumnWidth = {180, 120, '1x'};
            actions.Padding = [0 0 0 0];
            actions.ColumnSpacing = 8;
            actions.Layout.Row = 2;

            editBtn = uibutton(actions, 'push', 'Text', 'Open tracked ROI editor...', ...
                'ButtonPushedFcn', @(~,~)openRoiDefinitionEditor(app, nodeId));
            editBtn.Layout.Row = 1;
            editBtn.Layout.Column = 1;

            resetBtn = uibutton(actions, 'push', 'Text', 'Reset defaults', ...
                'ButtonPushedFcn', @(~,~)resetRoiDefinitionParams(app, nodeId));
            resetBtn.Layout.Row = 1;
            resetBtn.Layout.Column = 2;

            hint = uilabel(actions, 'Text', 'This module remains validated by bindings; the editor only completes module-specific settings.', ...
                'FontColor', [0.35 0.35 0.35], 'Interpreter', 'none');
            hint.Layout.Row = 1;
            hint.Layout.Column = 3;

            runtimeLabel = uilabel(grid, 'Text', 'Runtime parameters');
            runtimeLabel.FontWeight = 'bold';
            runtimeLabel.Layout.Row = 3;

            if isempty(runtimeData)
                msg = uilabel(grid, 'Text', 'No runtime parameter is declared for this tracked ROI module.', ...
                    'FontAngle', 'italic', 'FontColor', [0.35 0.35 0.35]);
                msg.Layout.Row = 4;
            else
                section = buildParamSection(app, grid, runtimeData, node, app.Data.runMode, 'runtime');
                section.Layout.Row = 4;
            end
        end

        function buildGenericRoiDefinitionTab(app, parentTab, node)
            runtimeData = paramsToTableData(app, node, 'runtime');
            grid = uigridlayout(parentTab, [3 1]);
            grid.RowHeight = {32, 24, '1x'};
            grid.Padding = [12 10 12 12];
            grid.RowSpacing = 8;

            nodeId = char(string(getField(app, node, 'id', '')));
            editBtn = uibutton(grid, 'push', 'Text', 'Open ROI editor...', ...
                'ButtonPushedFcn', @(~,~)openRoiDefinitionEditor(app, nodeId));
            editBtn.Layout.Row = 1;

            runtimeLabel = uilabel(grid, 'Text', 'Runtime parameters');
            runtimeLabel.FontWeight = 'bold';
            runtimeLabel.Layout.Row = 2;

            if isempty(runtimeData)
                msg = uilabel(grid, 'Text', 'No runtime parameter is declared for this ROI module.', ...
                    'FontAngle', 'italic', 'FontColor', [0.35 0.35 0.35]);
                msg.Layout.Row = 3;
            else
                section = buildParamSection(app, grid, runtimeData, node, app.Data.runMode, 'runtime');
                section.Layout.Row = 3;
            end
        end

        function openRoiDefinitionEditor(app, nodeId)
            idx = find(strcmp({app.Data.nodes.id}, char(string(nodeId))), 1);
            if isempty(idx)
                return;
            end
            [editorProject, ok, msg] = resolveRoiEditorProject(app);
            if ~ok
                uialert(app.UIFigure, msg, 'ROI editor', 'Icon', 'warning');
                return;
            end

            node = app.Data.nodes(idx);
            nodeType = lower(char(string(getField(app, node, 'type', ''))));
            ctx = buildRoiDefinitionEditorContext(app, node);
            ctx.shallow = editorProject;
            ctx.shallowObj = editorProject;
            try
                switch nodeType
                    case 'roiidentify'
                        ctx = roiIdentify.ui(ctx);
                    case 'roipattern'
                        ctx = roiPattern.ui(ctx);
                    case 'roigrid'
                        ctx = roiGrid.ui(ctx);
                    case 'roimanual'
                        ctx = roiManual.ui(ctx);
                    case 'roitracked'
                        ctx = roiTracked.ui(ctx);
                    otherwise
                        error('pipeline2:UnsupportedRoiEditor', 'No dedicated ROI editor is registered for node type "%s".', nodeType);
                end
                if isfield(ctx, 'cancelled') && logical(ctx.cancelled)
                    return;
                end
                applyRoiDefinitionEditorResult(app, nodeId, nodeType, ctx);
                refreshAfterModelChange(app);
            catch ME
                uialert(app.UIFigure, ME.message, 'ROI editor', 'Icon', 'error');
            end
        end

        function openWorkflowRoiEditor(app, nodeId)
            idx = find(strcmp({app.Data.nodes.id}, char(string(nodeId))), 1);
            if isempty(idx)
                return;
            end
            [editorProject, ok, msg] = resolveRoiEditorProject(app);
            if ~ok
                uialert(app.UIFigure, msg, 'ROI workflow', 'Icon', 'warning');
                return;
            end

            node = app.Data.nodes(idx);
            focus = lower(char(string(getField(app, node, 'type', ''))));
            switch focus
                case 'roiidentify'
                    focus = 'roiPattern';
                case 'roipattern'
                    focus = 'roiPattern';
                case 'roigrid'
                    focus = 'roiGrid';
                case 'roimanual'
                    focus = 'roiManual';
                case 'roitracked'
                    focus = 'roiTracked';
            end

            try
                params = getField(app, node, 'params', struct());
                if any(strcmpi(focus, {'roiPattern','roipattern'}))
                    params = getRoiPatternParamsForDisplay(app, node);
                end
                wf = workflow2(editorProject, 'FocusModule', focus, 'Params', params);
                try
                    if ~isempty(wf) && isvalid(wf.UIFigure)
                        uiwait(wf.UIFigure);
                    end
                catch
                end
                if ~isempty(wf) && isvalid(wf) && ~wf.Cancelled
                    result = wf.Result;
                    params = getField(app, app.Data.nodes(idx), 'params', struct());
                    if ~isstruct(params)
                        params = struct();
                    end
                    if isstruct(result)
                        app.Data.nodes(idx).params = mergeStructOverride(app, params, result);
                        syncRoiPatternBindingFromParams(app, nodeId, result);
                    end
                else
                    try
                        delete(wf);
                    catch
                    end
                    return;
                end
                try
                    delete(wf);
                catch
                end
                refreshAfterModelChange(app);
            catch ME
                uialert(app.UIFigure, ME.message, 'ROI workflow', 'Icon', 'error');
            end
        end

        function [editorProject, ok, msg] = resolveRoiEditorProject(app)
            editorProject = [];
            ok = false;
            msg = '';

            if ~isempty(app.CurrentProject) && isa(app.CurrentProject, 'shallow')
                editorProject = app.CurrentProject;
                ok = true;
                return;
            end

            mode = getRuntimeValue(app, 'inputSourceMode');
            if isempty(mode)
                mode = 'existing_rois';
            end
            if ~strcmpi(char(string(mode)), 'raw_dataloader')
                msg = ['A shallow project must be selected in Runtime inputs before opening workflow, ' ...
                    'unless the runtime source is set to Raw data via dataloader.'];
                return;
            end

            rawDataPath = strtrim(getRuntimeValue(app, 'rawDataPath'));
            if isempty(rawDataPath) || ~(exist(rawDataPath, 'dir') == 7 || exist(rawDataPath, 'file') == 2)
                msg = 'A valid raw data path must be selected before opening the ROI workflow.';
                return;
            end

            try
                editorProject = buildWorkflowProjectFromRawData(app, rawDataPath);
                ok = ~isempty(editorProject) && isa(editorProject, 'shallow') && ...
                    ~isempty(editorProject.fov) && ~isempty(editorProject.fov(1).srcpath);
                if ~ok
                    msg = 'Raw data were parsed, but no displayable FOV was created.';
                end
            catch ME
                msg = ['Could not create a temporary ROI workflow project from raw data: ' ME.message];
            end
        end

        function editorProject = buildWorkflowProjectFromRawData(app, rawDataPath)
            rawDataPath = char(string(rawDataPath));
            if ~isempty(app.WorkflowRawProject) && isa(app.WorkflowRawProject, 'shallow') && ...
                    strcmp(char(string(app.WorkflowRawProjectPath)), rawDataPath)
                editorProject = app.WorkflowRawProject;
                return;
            end

            d = [];
            try
                d = uiprogressdlg(app.UIFigure, 'Title', 'ROI workflow', ...
                    'Message', 'Parsing raw data for ROI editor...', 'Indeterminate', 'on', 'Cancelable', 'off');
            catch
            end

            cleanupObj = onCleanup(@()closeRuntimeProgress(app, d)); %#ok<NASGU>
            updateRuntimeProgress(app, d, 'Creating temporary shallow project...');

            editorProject = shallow();
            [basePath, baseName, baseExt] = fileparts(rawDataPath);
            if isempty(basePath)
                basePath = pwd;
            end
            editorProject.io.path = basePath;
            editorProject.io.file = ['workflow2_raw_' matlab.lang.makeValidName([baseName baseExt])];

            updateRuntimeProgress(app, d, 'Parsing raw FOVs, channels and frames...');
            editorProject.addData(rawDataPath);

            updateRuntimeProgress(app, d, 'Preparing image context...');
            app.WorkflowRawProject = editorProject;
            app.WorkflowRawProjectPath = rawDataPath;
        end

        function ctx = buildRoiDefinitionEditorContext(app, node)
            ctx = struct();
            if ~isempty(app.CurrentProject) && isa(app.CurrentProject, 'shallow')
                ctx.shallow = app.CurrentProject;
                ctx.shallowObj = app.CurrentProject;
            end
            ctx.allowGUI = true;
            ctx.interactive = true;
            ctx.params = getField(app, node, 'params', struct());
            ctx.run = struct();
            ctx.run.nodeParams = buildRunNodeParams(app);
            ctx.run.selectedNodes = selectedRunNodeIds(app);
            ctx.sel = struct();
            ctx.sel.fovs = parseIndexSelection(app, getRuntimeValue(app, 'fovs'));
            ctx.sel.frames = parseIndexSelection(app, getRuntimeValue(app, 'frames'));
            ctx.sel.rois = parseLooseSelection(app, getRuntimeValue(app, 'rois'));
            ctx.fovIndex = ctx.sel.fovs;
            nodeType = lower(char(string(getField(app, node, 'type', ''))));
            switch nodeType
                case 'roiidentify'
                    ctx.roiIdentify = ctx.params;
                case 'roipattern'
                    ctx.roiPattern = ctx.params;
                case 'roigrid'
                    ctx.roiGrid = mergeStructDefaults(app, ctx.params, roiGrid.setparam(struct()));
                case 'roimanual'
                    ctx.roiManual = mergeStructDefaults(app, ctx.params, roiManual.setparam(struct()));
                case 'roitracked'
                    ctx.roiTracked = ctx.params;
            end
        end

        function applyRoiDefinitionEditorResult(app, nodeId, nodeType, ctx)
            idx = find(strcmp({app.Data.nodes.id}, char(string(nodeId))), 1);
            if isempty(idx)
                return;
            end
            params = getField(app, app.Data.nodes(idx), 'params', struct());
            if ~isstruct(params)
                params = struct();
            end

            result = struct();
            switch lower(char(string(nodeType)))
                case 'roiidentify'
                    if isfield(ctx, 'roiIdentify') && isstruct(ctx.roiIdentify)
                        result = ctx.roiIdentify;
                    elseif isfield(ctx, 'roiPattern') && isstruct(ctx.roiPattern)
                        result = ctx.roiPattern;
                    end
                case 'roipattern'
                    if isfield(ctx, 'roiPattern') && isstruct(ctx.roiPattern)
                        result = ctx.roiPattern;
                    elseif isfield(ctx, 'roiIdentify') && isstruct(ctx.roiIdentify)
                        result = ctx.roiIdentify;
                    end
                case 'roigrid'
                    if isfield(ctx, 'roiGrid') && isstruct(ctx.roiGrid)
                        result = ctx.roiGrid;
                    end
                case 'roimanual'
                    if isfield(ctx, 'roiManual') && isstruct(ctx.roiManual)
                        result = ctx.roiManual;
                    end
                case 'roitracked'
                    if isfield(ctx, 'roiTracked') && isstruct(ctx.roiTracked)
                        result = ctx.roiTracked;
                    end
            end
            if isempty(fieldnames(result)) && isfield(ctx, 'params') && isstruct(ctx.params)
                result = ctx.params;
            end
            if ~isempty(fieldnames(result))
                app.Data.nodes(idx).params = mergeStructOverride(app, params, result);
            end
            if isfield(ctx, 'shallow') && isa(ctx.shallow, 'shallow')
                app.CurrentProject = ctx.shallow;
            end
        end

        function reloadRoiDefinitionFromProject(app, nodeId)
            idx = find(strcmp({app.Data.nodes.id}, char(string(nodeId))), 1);
            if isempty(idx)
                return;
            end
            profile = roiDefinitionProfileFromProject(app, app.Data.nodes(idx));
            if isempty(profile)
                uialert(app.UIFigure, 'No saved project profile was found for this ROI module.', ...
                    'Reload ROI profile', 'Icon', 'warning');
                return;
            end
            params = getField(app, app.Data.nodes(idx), 'params', struct());
            if ~isstruct(params)
                params = struct();
            end
            app.Data.nodes(idx).params = mergeStructOverride(app, params, profile);
            refreshAfterModelChange(app);
        end

        function tf = hasRoiWorkflowImageContext(app)
            tf = false;
            rawDataPath = strtrim(getRuntimeValue(app, 'rawDataPath'));
            if ~isempty(rawDataPath) && (exist(rawDataPath, 'dir') == 7 || exist(rawDataPath, 'file') == 2)
                tf = true;
                return;
            end
            if isempty(app.CurrentProject) || ~isa(app.CurrentProject, 'shallow')
                return;
            end
            try
                if isempty(app.CurrentProject.fov)
                    return;
                end
                fovObj = app.CurrentProject.fov(1);
                if isprop(fovObj, 'srcpath') && ~isempty(fovObj.srcpath)
                    tf = true;
                elseif isprop(fovObj, 'src') && ~isempty(fovObj.src)
                    tf = true;
                end
            catch
                tf = false;
            end
        end

        function params = getRoiPatternParamsForDisplay(app, node)
            params = getField(app, node, 'params', struct());
        end

        function syncRoiPatternBindingFromParams(app, nodeId, params)
            if ~isstruct(params)
                return;
            end
            pat = struct();
            if isfield(params, 'pattern') && isstruct(params.pattern) && ~isempty(params.pattern)
                pat = params.pattern(1);
            elseif isfield(params, 'patternList') && isstruct(params.patternList) && ~isempty(params.patternList)
                pat = params.patternList(1);
            end
            channelValue = roiPatternFirstNonEmpty(app, params, pat, {'channel','patternSourceChannel','sourceChannel'});
            if isempty(channelValue)
                channelIndex = roiPatternFirstNonEmpty(app, params, pat, {'channelIndex'});
                channelValue = channelNameFromRuntimeIndex(app, channelIndex);
            end
            channelValue = strtrim(choiceScalarText(app, channelValue));
            if isempty(channelValue) || strcmp(channelValue, '<unresolved>')
                return;
            end
            setNodeInputBindingValue(app, nodeId, 'channel', channelValue);
        end

        function channelName = channelNameFromRuntimeIndex(app, channelIndex)
            channelName = '';
            if isempty(channelIndex)
                return;
            end
            try
                idx = round(double(channelIndex(1)));
                if idx < 1
                    return;
                end
                if isfield(app.RuntimeParseInfo, 'channels') && numel(app.RuntimeParseInfo.channels) >= idx
                    channelName = char(string(app.RuntimeParseInfo.channels(idx)));
                end
            catch
                channelName = '';
            end
        end

        function setNodeInputBindingValue(app, nodeId, param, value)
            idx = find(strcmp({app.Data.nodes.id}, char(string(nodeId))), 1);
            if isempty(idx)
                return;
            end
            if ~isfield(app.Data.nodes(idx), 'params') || ~isstruct(app.Data.nodes(idx).params)
                app.Data.nodes(idx).params = struct();
            end
            app.Data.nodes(idx).params.(char(string(param))) = char(string(value));
            runtimeParams = getRuntimeNodeParams(app, nodeId);
            runtimeParams.(char(string(param))) = char(string(value));
            setRuntimeNodeParams(app, nodeId, runtimeParams);
        end

        function viewRoiPatternArtifact(app, nodeId)
            idx = find(strcmp({app.Data.nodes.id}, char(string(nodeId))), 1);
            if isempty(idx)
                return;
            end
            params = getRoiPatternParamsForDisplay(app, app.Data.nodes(idx));
            if ~hasUsableRoiPattern(app, params)
                uialert(app.UIFigure, 'No pattern is stored in this module. Please generate pattern first.', ...
                    'View pattern', 'Icon', 'warning');
                return;
            end
            pat = struct();
            if isfield(params, 'pattern') && isstruct(params.pattern) && ~isempty(params.pattern)
                pat = params.pattern(1);
            elseif isfield(params, 'patternList') && isstruct(params.patternList) && ~isempty(params.patternList)
                pat = params.patternList(1);
            end
            img = [];
            try
                if isfield(pat, 'image') && ~isempty(pat.image)
                    img = pat.image;
                elseif isfield(params, 'patternImage') && ~isempty(params.patternImage)
                    img = params.patternImage;
                end
            catch
                img = [];
            end
            description = roiPatternDescription(app, params);
            if isempty(img)
                uialert(app.UIFigure, strjoin([{'Pattern metadata is available, but no image patch is stored.'} description], newline), ...
                    'View pattern', 'Icon', 'info');
                return;
            end
            try
                fig = figure('Name', ['ROI pattern - ' char(string(nodeId))], 'NumberTitle', 'off');
                ax = axes(fig);
                if isnumeric(img) && ndims(img) == 3 && size(img, 3) >= 3
                    image(ax, img);
                else
                    imagesc(ax, img);
                    colormap(ax, gray);
                end
                axis(ax, 'image');
                axis(ax, 'off');
                title(ax, strjoin(description, ' | '), 'Interpreter', 'none');
            catch ME
                uialert(app.UIFigure, ME.message, 'View pattern', 'Icon', 'error');
            end
        end

        function resetRoiDefinitionParams(app, nodeId)
            idx = find(strcmp({app.Data.nodes.id}, char(string(nodeId))), 1);
            if isempty(idx)
                return;
            end
            nodeType = lower(char(string(getField(app, app.Data.nodes(idx), 'type', ''))));
            switch nodeType
                case 'roiidentify'
                    defaults = roiIdentify.setparam(struct());
                case 'roipattern'
                    defaults = roiPattern.setparam(struct());
                case 'roigrid'
                    defaults = roiGrid.setparam(struct());
                case 'roimanual'
                    defaults = roiManual.setparam(struct());
                case 'roitracked'
                    defaults = roiTracked.setparam(struct());
                otherwise
                    defaults = struct();
            end
            app.Data.nodes(idx).params = defaults;
            removeRuntimeNodeParams(app, nodeId);
            refreshAfterModelChange(app);
        end

        function profile = roiDefinitionProfileFromProject(app, node)
            profile = [];
            if isempty(app.CurrentProject) || ~isa(app.CurrentProject, 'shallow')
                return;
            end
            try
                rp = app.CurrentProject.runProfiles;
                if ~isstruct(rp) || ~isfield(rp, 'dataloading') || ~isstruct(rp.dataloading)
                    return;
                end
                dl = rp.dataloading;
                switch lower(char(string(getField(app, node, 'type', ''))))
                    case {'roipattern','roiidentify'}
                        keys = {'roiPattern','roiIdentify'};
                    case 'roigrid'
                        keys = {'roiGrid'};
                    case 'roimanual'
                        keys = {'roiManual'};
                    case 'roitracked'
                        keys = {'roiTracked'};
                    otherwise
                        keys = {};
                end
                for i = 1:numel(keys)
                    if isfield(dl, keys{i}) && isstruct(dl.(keys{i})) && ~isempty(dl.(keys{i}))
                        profile = dl.(keys{i});
                        return;
                    end
                end
            catch
                profile = [];
            end
        end

        function clearRoiPatternNodeArtifact(app, nodeId)
            idx = find(strcmp({app.Data.nodes.id}, char(string(nodeId))), 1);
            if isempty(idx) || ~isfield(app.Data.nodes(idx), 'params') || ~isstruct(app.Data.nodes(idx).params)
                return;
            end
            removeKeys = {'pattern','patternImage','patternRect','patternList','activePatternIndex', ...
                'patternSourceFOV','patternSourceFrame','patternSourceChannel','crop','fovCrop'};
            for i = 1:numel(removeKeys)
                if isfield(app.Data.nodes(idx).params, removeKeys{i})
                    app.Data.nodes(idx).params = rmfield(app.Data.nodes(idx).params, removeKeys{i});
                end
            end
            refreshAfterModelChange(app);
        end

        function [lines, color] = roiGridStatus(app, node)
            params = getField(app, node, 'params', struct());
            profile = roiDefinitionProfileFromProject(app, node);
            if ~isstruct(params) || isempty(fieldnames(params))
                params = struct();
            end
            params = mergeStructDefaults(app, params, roiGrid.setparam(struct()));
            n = 1;
            mode = 'fullframe';
            try
                n = max(1, round(double(params.gridCount)));
                mode = char(string(params.mode));
            catch
            end
            lines = { ...
                sprintf('Grid artifact: %s, %d ROI(s) per FOV', mode, n), ...
                'This module has no image patch artifact; it stores a deterministic full-frame/grid recipe.'};
            if ~isempty(profile)
                lines{end+1} = 'A saved project profile is available and is used automatically unless this node overrides it.';
                color = [0.10 0.42 0.20];
            else
                color = [0.20 0.20 0.20];
            end
        end

        function [lines, color] = roiManualStatus(app, node)
            params = getField(app, node, 'params', struct());
            profile = roiDefinitionProfileFromProject(app, node);
            nRect = manualRectCount(app, params);
            nProfileRect = manualRectCount(app, profile);
            if nRect > 0
                dimLines = manualRectDimensionLines(app, params);
                lines = { ...
                    sprintf('Manual ROI artifact: %d rectangle(s) stored in this pipeline node.', nRect), ...
                    'Use the dedicated editor to draw or revise these ROIs with image context.'};
                if ~isempty(dimLines)
                    lines = [lines dimLines]; %#ok<AGROW>
                end
                color = [0.10 0.42 0.20];
            elseif nProfileRect > 0
                dimLines = manualRectDimensionLines(app, profile);
                lines = { ...
                    'Manual ROI source: project profile.', ...
                    sprintf('%d rectangle(s) are saved in the project ROI profile and will be used at run time.', nProfileRect), ...
                    'This pipeline node does not store its own manual ROI override.'};
                if ~isempty(dimLines)
                    lines = [lines dimLines]; %#ok<AGROW>
                end
                color = [0.62 0.32 0.08];
            elseif ~isempty(profile)
                lines = { ...
                    'Manual ROI profile found, but no compact rectangle metadata is available.', ...
                    'Open the dedicated editor to inspect or complete the manual ROI definition.'};
                color = [0.62 0.32 0.08];
            else
                lines = { ...
                    'Manual ROI artifact: not defined in this node.', ...
                    'Manual ROI drawing requires image context; open the dedicated editor before running this module.'};
                color = [0.70 0.10 0.10];
            end
        end

        function n = manualRectCount(app, params) %#ok<INUSD>
            n = 0;
            if ~isstruct(params) || isempty(params)
                return;
            end
            keys = {'manualRois','rectangles','roiRects','rois','positions','manualRects'};
            for i = 1:numel(keys)
                k = keys{i};
                if ~isfield(params, k) || isempty(params.(k))
                    continue;
                end
                v = params.(k);
                if isnumeric(v) && size(v, 2) >= 4
                    n = size(v, 1);
                    return;
                elseif isstruct(v)
                    n = numel(v);
                    return;
                elseif iscell(v)
                    n = numel(v);
                    return;
                end
            end
        end

        function lines = manualRectDimensionLines(app, params)
            rects = manualRectArray(app, params);
            lines = {};
            if isempty(rects)
                return;
            end
            nShow = min(size(rects, 1), 4);
            for i = 1:nShow
                r = rects(i, 1:4);
                lines{end+1} = sprintf('ROI %d: x=%g, y=%g, w=%g, h=%g px', i, r(1), r(2), r(3), r(4)); %#ok<AGROW>
            end
            if size(rects, 1) > nShow
                lines{end+1} = sprintf('... %d more ROI rectangle(s).', size(rects, 1) - nShow);
            end
        end

        function rects = manualRectArray(app, params) %#ok<INUSD>
            rects = zeros(0,4);
            if ~isstruct(params) || isempty(params)
                return;
            end
            keys = {'manualRois','rectangles','roiRects','rois','positions','manualRects'};
            for i = 1:numel(keys)
                k = keys{i};
                if ~isfield(params, k) || isempty(params.(k))
                    continue;
                end
                v = params.(k);
                if isnumeric(v) && size(v, 2) >= 4
                    rects = double(v(:,1:4));
                    return;
                elseif isstruct(v)
                    out = zeros(0,4);
                    for j = 1:numel(v)
                        r = [];
                        if isfield(v, 'rect') && ~isempty(v(j).rect)
                            r = v(j).rect;
                        elseif isfield(v, 'position') && ~isempty(v(j).position)
                            r = v(j).position;
                        elseif isfield(v, 'value') && ~isempty(v(j).value)
                            r = v(j).value;
                        end
                        if isnumeric(r) && numel(r) >= 4
                            out(end+1,:) = double(r(1:4)); %#ok<AGROW>
                        end
                    end
                    rects = out;
                    return;
                elseif iscell(v)
                    out = zeros(0,4);
                    for j = 1:numel(v)
                        r = v{j};
                        if isnumeric(r) && numel(r) >= 4
                            out(end+1,:) = double(r(1:4)); %#ok<AGROW>
                        end
                    end
                    rects = out;
                    return;
                end
            end
        end

        function [lines, color] = roiTrackedStatus(app, node)
            params = getField(app, node, 'params', struct());
            profile = roiDefinitionProfileFromProject(app, node);
            if ~isstruct(params) || isempty(fieldnames(params))
                params = struct();
            end
            params = mergeStructDefaults(app, params, roiTracked.setparam(struct()));

            source = choiceScalarText(app, getField(app, params, 'channel', ''));
            if isempty(strtrim(source))
                source = '<mask channel unresolved>';
            end
            extractState = 'extract ROI crops';
            try
                if ~logical(params.extract)
                    extractState = 'do not extract ROI crops';
                end
            catch
            end
            marginText = valueToDisplay(app, getField(app, params, 'margin', 0));
            lines = { ...
                ['Tracked ROI recipe: mask/source channel = ' source], ...
                ['Margin: ' marginText ' px | ' extractState], ...
                'Requires an upstream ROI list and a compatible mask/segmentation binding.'};
            if ~isempty(profile)
                lines{end+1} = 'A saved project profile is available and is used automatically unless this node overrides it.';
                color = [0.10 0.42 0.20];
            elseif strcmp(source, '<mask channel unresolved>')
                color = [0.70 0.10 0.10];
            else
                color = [0.20 0.20 0.20];
            end
        end

        function [lines, color] = roiPatternStatus(app, node)
            params = getField(app, node, 'params', struct());
            profile = roiDefinitionProfileFromProject(app, node);
            if hasUsableRoiPattern(app, params)
                lines = {'Pattern is already defined within module.'};
                if roiPatternHasSourceContext(app, params)
                    lines{end+1} = 'Pattern was generated from existing raw data and stores its source context.';
                end
                lines = [lines roiPatternDescription(app, params)];
                color = [0.10 0.42 0.20];
            else
                lines = { ...
                    'Please generate pattern first.', ...
                    'This module has no stored pattern artifact yet.', ...
                    'Use Generate pattern to create one from the current raw data context.'};
                if hasUsableRoiPattern(app, profile)
                    lines{end+1} = 'A legacy project ROI profile exists, but it is not stored in this module.';
                end
                color = [0.70 0.10 0.10];
            end
        end

        function tf = roiPatternHasSourceContext(app, params)
            tf = false;
            if ~isstruct(params) || isempty(params)
                return;
            end
            pat = struct();
            if isfield(params, 'pattern') && isstruct(params.pattern) && ~isempty(params.pattern)
                pat = params.pattern(1);
            elseif isfield(params, 'patternList') && isstruct(params.patternList) && ~isempty(params.patternList)
                pat = params.patternList(1);
            end
            fovValue = roiPatternFirstNonEmpty(app, params, pat, {'patternSourceFOV','sourceFOV','sourceFov','fovIndex'});
            frameValue = roiPatternFirstNonEmpty(app, params, pat, {'patternSourceFrame','sourceFrame','frame','referenceFrame'});
            channelValue = roiPatternFirstNonEmpty(app, params, pat, {'patternSourceChannel','sourceChannel','channel','channelIndex'});
            tf = ~isempty(fovValue) || ~isempty(frameValue) || ~isempty(channelValue);
        end

        function tf = hasUsableRoiPattern(app, params) %#ok<INUSD>
            tf = false;
            if ~isstruct(params) || isempty(params)
                return;
            end
            try
                if isfield(params, 'pattern') && isstruct(params.pattern) && ~isempty(params.pattern)
                    tf = true;
                    return;
                end
                if isfield(params, 'patternList') && isstruct(params.patternList) && ~isempty(params.patternList)
                    tf = true;
                    return;
                end
                if isfield(params, 'patternRect') && isnumeric(params.patternRect) && numel(params.patternRect) >= 4
                    tf = true;
                end
            catch
                tf = false;
            end
        end

        function lines = roiPatternDescription(app, params)
            lines = {};
            if ~isstruct(params) || isempty(params)
                return;
            end
            pat = struct();
            if isfield(params, 'pattern') && isstruct(params.pattern) && ~isempty(params.pattern)
                pat = params.pattern(1);
            elseif isfield(params, 'patternList') && isstruct(params.patternList) && ~isempty(params.patternList)
                pat = params.patternList(1);
            end
            rect = roiPatternFirstNonEmpty(app, params, pat, {'patternRect','rect','position','crop'});
            if isnumeric(rect) && numel(rect) >= 4
                lines{end+1} = ['Rect: ' mat2str(double(rect(1:4)), 4)]; %#ok<AGROW>
            end
            fovValue = roiPatternFirstNonEmpty(app, params, pat, {'patternSourceFOV','sourceFOV','sourceFov','fovIndex'});
            frameValue = roiPatternFirstNonEmpty(app, params, pat, {'patternSourceFrame','sourceFrame','frame','referenceFrame'});
            channelValue = roiPatternFirstNonEmpty(app, params, pat, {'patternSourceChannel','sourceChannel','channel','channelIndex'});
            sourceBits = {};
            if ~isempty(fovValue), sourceBits{end+1} = ['FOV ' valueToDisplay(app, fovValue)]; end %#ok<AGROW>
            if ~isempty(frameValue), sourceBits{end+1} = ['frame ' valueToDisplay(app, frameValue)]; end %#ok<AGROW>
            if ~isempty(channelValue), sourceBits{end+1} = ['channel ' valueToDisplay(app, channelValue)]; end %#ok<AGROW>
            if ~isempty(sourceBits)
                lines{end+1} = ['Source: ' strjoin(sourceBits, ', ')]; %#ok<AGROW>
            end
            if isempty(lines)
                lines = {'Pattern metadata found, but no compact source description is available.'};
            end
        end

        function value = roiPatternFirstNonEmpty(app, params, pat, keys) %#ok<INUSD>
            value = [];
            for i = 1:numel(keys)
                k = keys{i};
                if isstruct(params) && isfield(params, k) && ~isempty(params.(k))
                    value = params.(k);
                    return;
                end
                if isstruct(pat) && isfield(pat, k) && ~isempty(pat.(k))
                    value = pat.(k);
                    return;
                end
            end
        end

        function out = mergeStructOverride(app, base, override) %#ok<INUSD>
            if ~isstruct(base)
                base = struct();
            end
            out = base;
            if ~isstruct(override) || isempty(override)
                return;
            end
            fn = fieldnames(override);
            for i = 1:numel(fn)
                out.(fn{i}) = override.(fn{i});
            end
        end

        function buildRoiGridTab(app, parentTab, node)
            nodeId = char(string(getField(app, node, 'id', '')));
            runtimeData = paramsToTableData(app, node, 'runtime');
            grid = uigridlayout(parentTab, [4 1]);
            grid.RowHeight = {74, 32, 24, '1x'};
            grid.ColumnWidth = {'1x'};
            grid.Padding = [12 10 12 12];
            grid.RowSpacing = 8;

            [statusLines, statusColor] = roiGridStatus(app, node);
            status = uitextarea(grid, 'Editable', 'off', 'Value', statusLines);
            status.Layout.Row = 1;
            try
                status.FontColor = statusColor;
            catch
            end

            actions = uigridlayout(grid, [1 3]);
            actions.RowHeight = {28};
            actions.ColumnWidth = {150, 120, '1x'};
            actions.Padding = [0 0 0 0];
            actions.ColumnSpacing = 8;
            actions.Layout.Row = 2;

            editBtn = uibutton(actions, 'push', 'Text', 'Open ROI workflow...', ...
                'ButtonPushedFcn', @(~,~)openWorkflowRoiEditor(app, nodeId));
            editBtn.Layout.Row = 1;
            editBtn.Layout.Column = 1;

            resetBtn = uibutton(actions, 'push', 'Text', 'Reset defaults', ...
                'ButtonPushedFcn', @(~,~)resetRoiDefinitionParams(app, nodeId));
            resetBtn.Layout.Row = 1;
            resetBtn.Layout.Column = 2;

            hint = uilabel(actions, 'Text', 'Grid/full-frame geometry is edited in the dedicated dialog; pipeline2 only stores the resulting parameters.', ...
                'FontColor', [0.35 0.35 0.35], 'Interpreter', 'none');
            hint.Layout.Row = 1;
            hint.Layout.Column = 3;

            runtimeLabel = uilabel(grid, 'Text', 'Runtime parameters');
            runtimeLabel.FontWeight = 'bold';
            runtimeLabel.Layout.Row = 3;

            if isempty(runtimeData)
                msg = uilabel(grid, 'Text', 'No runtime parameter is declared for this ROI grid module.', ...
                    'FontAngle', 'italic', 'FontColor', [0.35 0.35 0.35]);
                msg.Layout.Row = 4;
            else
                section = buildParamSection(app, grid, runtimeData, node, app.Data.runMode, 'runtime');
                section.Layout.Row = 4;
            end
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
            runtimeData = paramsToTableData(app, node, 'runtime');
            grid = uigridlayout(parentTab, [4 1]);
            grid.RowHeight = {74, 32, 24, '1x'};
            grid.ColumnWidth = {'1x'};
            grid.Padding = [12 10 12 12];
            grid.RowSpacing = 8;

            [statusLines, statusColor] = roiManualStatus(app, node);
            status = uitextarea(grid, 'Editable', 'off', 'Value', statusLines);
            status.Layout.Row = 1;
            try
                status.FontColor = statusColor;
            catch
            end

            actions = uigridlayout(grid, [1 3]);
            actions.RowHeight = {28};
            actions.ColumnWidth = {160, 120, '1x'};
            actions.Padding = [0 0 0 0];
            actions.ColumnSpacing = 8;
            actions.Layout.Row = 2;

            editBtn = uibutton(actions, 'push', 'Text', 'Open drawing workflow...', ...
                'ButtonPushedFcn', @(~,~)openWorkflowRoiEditor(app, nodeId));
            editBtn.Layout.Row = 1;
            editBtn.Layout.Column = 1;

            resetBtn = uibutton(actions, 'push', 'Text', 'Reset defaults', ...
                'ButtonPushedFcn', @(~,~)resetRoiDefinitionParams(app, nodeId));
            resetBtn.Layout.Row = 1;
            resetBtn.Layout.Column = 2;

            hint = uilabel(actions, 'Text', 'Manual ROI drawing needs image context and is handled in workflow focused on ROI manual mode.', ...
                'FontColor', [0.35 0.35 0.35], 'Interpreter', 'none');
            hint.Layout.Row = 1;
            hint.Layout.Column = 3;

            runtimeLabel = uilabel(grid, 'Text', 'Runtime parameters');
            runtimeLabel.FontWeight = 'bold';
            runtimeLabel.Layout.Row = 3;

            if isempty(runtimeData)
                msg = uilabel(grid, 'Text', 'No runtime parameter is declared for this manual ROI module.', ...
                    'FontAngle', 'italic', 'FontColor', [0.35 0.35 0.35]);
                msg.Layout.Row = 4;
            else
                section = buildParamSection(app, grid, runtimeData, node, app.Data.runMode, 'runtime');
                section.Layout.Row = 4;
            end
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

        function clearRuntimeNodeParam(app, nodeId, param)
            key = runtimeNodeKey(app, nodeId);
            param = char(string(param));
            try
                if isfield(app.RuntimeNodeParams, key) && isstruct(app.RuntimeNodeParams.(key)) && ...
                        isfield(app.RuntimeNodeParams.(key), param)
                    app.RuntimeNodeParams.(key) = rmfield(app.RuntimeNodeParams.(key), param);
                end
            catch
            end
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

        function grid = buildRoiExtractBindingSection(app, parent, node)
            nodeId = char(string(getField(app, node, 'id', '')));
            channels = roiExtractAvailableChannels(app);
            useSymbolic = roiExtractUsesSymbolicSource(app, node);
            hasInventory = ~isempty(channels);
            if ~hasInventory
                channels = {'<no channel inventory>'};
                useSymbolic = true;
            end

            grid = uigridlayout(parent, [3 3]);
            grid.RowHeight = {28, 142, 22};
            grid.ColumnWidth = {96, 170, '1x'};
            grid.Padding = [0 0 0 0];
            grid.RowSpacing = 6;
            grid.ColumnSpacing = 8;

            dirLabel = uilabel(grid, 'Text', 'Input');
            dirLabel.Layout.Row = 1;
            dirLabel.Layout.Column = 1;

            resLabel = uilabel(grid, 'Text', 'channel/source');
            resLabel.Layout.Row = 1;
            resLabel.Layout.Column = 2;

            mode = uidropdown(grid);
            mode.Items = {'<source output>', 'Select channels manually'};
            mode.ItemsData = {'symbolic', 'manual'};
            mode.Value = ternary(app, useSymbolic, 'symbolic', 'manual');
            mode.Tooltip = 'Symbolic mode uses all source channels provided by the upstream dataloader/source. Manual mode selects concrete channels below.';
            mode.ValueChangedFcn = @(src,~)roiExtractSourceModeChanged(app, nodeId, src.Value);
            mode.Layout.Row = 1;
            mode.Layout.Column = 3;

            table = uitable(grid);
            table.ColumnName = {'Use','Channel'};
            table.ColumnEditable = [true false];
            table.ColumnWidth = {52, 'auto'};
            table.RowName = {};
            table.Data = roiExtractChannelTableData(app, node, channels, useSymbolic);
            table.Enable = ternary(app, useSymbolic, 'off', 'on');
            table.Tooltip = 'Select one or more source channels to extract into ROI H5 files.';
            table.CellEditCallback = @(src,event)roiExtractChannelTableEdited(app, nodeId, src, event);
            table.Layout.Row = 2;
            table.Layout.Column = [2 3];

            hint = uilabel(grid, 'Text', ternary(app, useSymbolic, ...
                ternary(app, hasInventory, ...
                    'Symbolic mode: all upstream source channels will be extracted.', ...
                    'No concrete channel inventory is available yet; source channels will be resolved at run time.'), ...
                'Manual mode: checked channels are stored in extractChannels.'), ...
                'FontColor', [0.35 0.35 0.35], 'Interpreter', 'none');
            hint.Layout.Row = 3;
            hint.Layout.Column = [2 3];
        end

        function channels = roiExtractAvailableChannels(app)
            channels = runtimeConcreteChannels(app);
            channels = channels(~cellfun(@(s)startsWith(strtrim(char(string(s))), '<'), channels));
            channels = unique(channels(~cellfun(@isempty, channels)), 'stable');
        end

        function tf = roiExtractUsesSymbolicSource(app, node)
            nodeId = char(string(getField(app, node, 'id', '')));
            value = [];
            runtimeParams = getRuntimeNodeParams(app, nodeId);
            if isstruct(runtimeParams) && isfield(runtimeParams, 'extractChannels')
                value = runtimeParams.extractChannels;
            else
                p = getField(app, node, 'params', struct());
                if isstruct(p) && isfield(p, 'extractChannels')
                    value = p.extractChannels;
                elseif isstruct(p) && isfield(p, 'channels')
                    value = p.channels;
                end
            end
            txt = strtrim(choiceScalarText(app, value));
            tf = isempty(txt) || isSymbolicStoredBinding(app, txt) || startsWith(txt, '<') || strcmpi(txt, 'all') || strcmpi(txt, '<all>');
        end

        function data = roiExtractChannelTableData(app, node, channels, useSymbolic)
            selected = roiExtractSelectedChannels(app, node, channels, useSymbolic);
            data = cell(numel(channels), 2);
            for i = 1:numel(channels)
                ch = char(string(channels{i}));
                data{i,1} = useSymbolic || any(strcmp(selected, ch));
                data{i,2} = ch;
            end
        end

        function selected = roiExtractSelectedChannels(app, node, channels, useSymbolic)
            if useSymbolic
                selected = channels;
                return;
            end
            nodeId = char(string(getField(app, node, 'id', '')));
            value = [];
            runtimeParams = getRuntimeNodeParams(app, nodeId);
            if isstruct(runtimeParams) && isfield(runtimeParams, 'extractChannels')
                value = runtimeParams.extractChannels;
            else
                p = getField(app, node, 'params', struct());
                if isstruct(p) && isfield(p, 'extractChannels')
                    value = p.extractChannels;
                elseif isstruct(p) && isfield(p, 'channels')
                    value = p.channels;
                end
            end
            selected = normalizeChannelSelectionValue(app, value);
            if isempty(selected)
                selected = channels;
            end
        end

        function channels = normalizeChannelSelectionValue(app, value) %#ok<INUSD>
            channels = {};
            if isempty(value)
                return;
            end
            if iscell(value)
                channels = cellstr(string(value(:)'));
            elseif isstring(value)
                channels = cellstr(value(:)');
            elseif ischar(value)
                txt = strtrim(value);
                if any(strcmpi(txt, {'all','<all>','*',':'})) || startsWith(txt, '@') || startsWith(txt, '<')
                    channels = {};
                else
                    parts = regexp(txt, '[,;]', 'split');
                    channels = cellfun(@strtrim, parts, 'UniformOutput', false);
                end
            elseif isnumeric(value)
                channels = cellstr(string(value(:)'));
            end
            channels = unique(channels(~cellfun(@isempty, channels)), 'stable');
        end

        function ids = upstreamNodeIds(app, nodeId)
            ids = {};
            nodeId = char(string(nodeId));
            try
                edges = app.Data.edges;
                for i = 1:numel(edges)
                    toId = char(string(getField(app, edges(i), 'to', '')));
                    fromId = char(string(getField(app, edges(i), 'from', '')));
                    if strcmp(toId, nodeId) && ~isempty(fromId)
                        ids{end+1} = fromId; %#ok<AGROW>
                    end
                end
            catch
                ids = {};
            end
            ids = unique(ids, 'stable');
        end

        function symbolic = roiExtractSourceSymbolicBinding(app, node)
            symbolic = '@source';
            spec = struct('type', 'channel', 'role', 'source');
            try
                resources = upstreamCompatibleResources(app, node, spec);
            catch
                resources = struct([]);
            end
            if isempty(resources)
                return;
            end
            symbols = cell(1, numel(resources));
            for i = 1:numel(resources)
                symbols{i} = char(string(getField(app, resources(i), 'symbol', '')));
            end
            idx = find(~cellfun(@isempty, symbols), 1);
            if isempty(idx)
                return;
            end
            symbolic = ['@' symbols{idx}];
        end

        function roiExtractSourceModeChanged(app, nodeId, modeValue)
            idx = find(strcmp({app.Data.nodes.id}, char(string(nodeId))), 1);
            if isempty(idx)
                return;
            end
            if ~isfield(app.Data.nodes(idx), 'params') || ~isstruct(app.Data.nodes(idx).params)
                app.Data.nodes(idx).params = struct();
            end
            runtimeParams = getRuntimeNodeParams(app, nodeId);
            if strcmpi(char(string(modeValue)), 'symbolic')
                symbolic = roiExtractSourceSymbolicBinding(app, app.Data.nodes(idx));
                app.Data.nodes(idx).params.extractChannels = symbolic;
                runtimeParams.extractChannels = symbolic;
            else
                channels = roiExtractAvailableChannels(app);
                if isempty(channels)
                    app.Data.nodes(idx).params.extractChannels = '@source';
                    runtimeParams.extractChannels = '@source';
                    setRuntimeNodeParams(app, nodeId, runtimeParams);
                    refreshModuleTabs(app);
                    refreshValidationReport(app);
                    return;
                end
                app.Data.nodes(idx).params.extractChannels = channels;
                runtimeParams.extractChannels = channels;
            end
            setRuntimeNodeParams(app, nodeId, runtimeParams);
            refreshModuleTabs(app);
            refreshValidationReport(app);
        end

        function roiExtractChannelTableEdited(app, nodeId, table, event)
            if isempty(event.Indices) || event.Indices(2) ~= 1
                return;
            end
            data = table.Data;
            if isempty(data)
                return;
            end
            selected = {};
            for i = 1:size(data,1)
                try
                    if logical(data{i,1})
                        selected{end+1} = char(string(data{i,2})); %#ok<AGROW>
                    end
                catch
                end
            end
            idx = find(strcmp({app.Data.nodes.id}, char(string(nodeId))), 1);
            if isempty(idx)
                return;
            end
            if ~isfield(app.Data.nodes(idx), 'params') || ~isstruct(app.Data.nodes(idx).params)
                app.Data.nodes(idx).params = struct();
            end
            app.Data.nodes(idx).params.extractChannels = selected;
            runtimeParams = getRuntimeNodeParams(app, nodeId);
            runtimeParams.extractChannels = selected;
            setRuntimeNodeParams(app, nodeId, runtimeParams);
            refreshValidationReport(app);
        end

        function ctrl = createBindingControl(app, parent, node, param, value, choices, direction, editable)
            enableState = ternary(app, editable, 'on', 'off');
            isInput = strcmpi(char(string(direction)), 'Input');
            if isInput || ~isempty(choices)
                displayValue = choiceScalarText(app, value);
                placeholder = '<unconfigured>';
                if isempty(choices)
                    choices = {displayValue};
                end
                choices = flattenChoiceList(app, choices);
                choices = choices(~cellfun(@isempty, choices));
                if isInput && isempty(displayValue)
                    choices = [{placeholder} choices]; %#ok<AGROW>
                    displayValue = placeholder;
                end
                if isempty(choices)
                    choices = {'<unresolved>'};
                end
                if isempty(displayValue) || ~any(strcmp(choices, displayValue))
                    if isInput && any(strcmp(choices, placeholder))
                        displayValue = placeholder;
                    else
                        displayValue = choices{1};
                    end
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
            focus = captureTabFocus(app);
            d = openRuntimeProgress(app, 'Pipeline bindings', 'Applying binding change...');
            cleanupObj = onCleanup(@()finishStaticParameterRefresh(app, d, [], focus)); %#ok<NASGU>
            param = char(string(param));
            value = strtrim(char(string(value)));
            isInput = strcmpi(char(string(direction)), 'Input');

            if ~isfield(app.Data.nodes(idx), 'params') || ~isstruct(app.Data.nodes(idx).params)
                app.Data.nodes(idx).params = struct();
            end

            if isAllChannelBindingLabel(app, value)
                app.Data.nodes(idx).params.(param) = 'all';
                clearRuntimeNodeParam(app, nodeId, param);
            elseif isSymbolicBindingLabel(app, value)
                symbolicValue = symbolicBindingValueFromLabel(app, value);
                app.Data.nodes(idx).params.(param) = symbolicValue;
                clearRuntimeNodeParam(app, nodeId, param);
            elseif isempty(value) || any(strcmp(value, {'<unresolved>','<unconfigured>'}))
                if isfield(app.Data.nodes(idx).params, param)
                    app.Data.nodes(idx).params = rmfield(app.Data.nodes(idx).params, param);
                end
                clearRuntimeNodeParam(app, nodeId, param);
            else
                app.Data.nodes(idx).params.(param) = value;
                clearRuntimeNodeParam(app, nodeId, param);
            end

            if ~isInput
                updateRuntimeProgress(app, d, 'Refreshing dependent binding choices...');
                refreshModuleTabs(app);
            end
            updateRuntimeProgress(app, d, 'Checking pipeline bindings...');
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

            if isstruct(p) && isfield(p, param) && (~isInput || isConfiguredBindingValue(app, p.(param))) && ...
                    (~isInput || ~isSymbolicStoredBinding(app, p.(param)) || symbolicBindingIsActive(app, p.(param)))
                value = bindingValueToDisplay(app, choiceScalarText(app, p.(param)), node, spec);
                return;
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
            if isAllChannelBindingSpec(app, spec) && isAllChannelSelectorText(app, displayValue)
                displayValue = '<all>';
                return;
            end
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
                    if resourceSpecCompatibleForUi(app, wantedType, wantedRole, outType, outRole)
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
                if resourceChoiceIsAmbiguousForSpec(app, available(i), spec)
                    continue;
                end
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

            if isAllChannelBindingSpec(app, spec) && isempty(upstreamChoices)
                runtimeChoices = [{'<all>'} runtimeChoices]; %#ok<AGROW>
            end
            graphChoices = graphResourceChoiceLabels(app, node, spec);
            choices = [upstreamChoices runtimeChoices graphChoices]; %#ok<AGROW>

            if isempty(choices) && ~isempty(currentValue)
                choices{end+1} = currentValue; %#ok<AGROW>
            end

            if isempty(choices)
                role = char(string(getField(app, spec, 'role', 'resource')));
                choices = {['<' role ' output>']};
            end
            choices = unique(choices(~cellfun(@isempty, choices)), 'stable');
        end

        function tf = isAllChannelBindingSpec(app, spec) %#ok<INUSD>
            tf = strcmpi(char(string(getField(app, spec, 'type', ''))), 'channel') && ...
                strcmpi(char(string(getField(app, spec, 'role', ''))), 'source') && ...
                strcmpi(char(string(getField(app, spec, 'param', ''))), 'channels');
        end

        function tf = isSingularChannelBindingSpec(app, spec)
            tf = false;
            specType = lower(char(string(getField(app, spec, 'type', ''))));
            specParam = lower(char(string(getField(app, spec, 'param', ''))));
            if ~strcmp(specType, 'channel') || isAllChannelBindingSpec(app, spec)
                return;
            end

            required = logical(getField(app, spec, 'required', false));
            singularParams = {'channel','inputchannelname','instancechannelname'};
            tf = required || any(strcmp(specParam, singularParams)) || ...
                ~isempty(regexp(specParam, '^mask\d+_name$', 'once')) || ...
                ~isempty(regexp(specParam, '^channel\d+_name$', 'once'));
        end

        function tf = resourceChoiceIsAmbiguousForSpec(app, resource, spec)
            tf = false;
            if ~isSingularChannelBindingSpec(app, spec)
                return;
            end

            sourceKind = lower(char(string(getField(app, resource, 'sourceKind', ''))));
            if any(strcmp(sourceKind, {'context','ctx','runtime'}))
                return;
            end

            sourceNode = lower(char(string(getField(app, resource, 'sourceNode', ''))));
            sourcePort = lower(char(string(getField(app, resource, 'sourcePort', ''))));
            symbol = lower(char(string(getField(app, resource, 'symbol', ''))));
            concrete = lower(strtrim(char(string(getField(app, resource, 'concreteName', '')))));
            nodeIds = {};
            try
                if isfield(app.Data, 'nodes') && ~isempty(app.Data.nodes)
                    nodeIds = lower(cellstr(string({app.Data.nodes.id})));
                end
            catch
                nodeIds = {};
            end

            hasSingleConcrete = ~isempty(concrete) && ...
                ~startsWith(concrete, '@') && ...
                ~any(strcmp(concrete, {'channels','all','*',':',sourceNode})) && ...
                ~any(strcmp(concrete, nodeIds));
            if hasSingleConcrete
                return;
            end

            tf = any(strcmp(sourceKind, {'sourceinventory','imagestoroi'})) || ...
                strcmp(sourcePort, 'channels') || ...
                endsWith(symbol, '.channels');
        end

        function tf = isAllChannelBindingLabel(app, value) %#ok<INUSD>
            tf = strcmpi(strtrim(char(string(value))), '<all>');
        end

        function tf = isAllChannelSelectorText(app, value) %#ok<INUSD>
            value = lower(strtrim(char(string(value))));
            tf = any(strcmp(value, {'all','*',':','<all>'}));
        end

        function choices = runtimeBindingChoices(app, spec)
            choices = {};
            type = lower(char(string(getField(app, spec, 'type', ''))));
            role = lower(char(string(getField(app, spec, 'role', ''))));
            if strcmp(type, 'channel') && strcmp(role, 'roi_image')
                choices = runtimeConcreteChannels(app);
            elseif strcmp(type, 'channel') && strcmp(role, 'source')
                choices = runtimeConcreteChannels(app);
            elseif strcmp(type, 'mask')
                choices = runtimeMaskChoices(app);
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

        function masks = runtimeMaskChoices(app)
            masks = {};
            try
                channels = runtimeConcreteChannels(app);
                if isempty(channels)
                    return;
                end
                low = lower(string(channels));
                keep = contains(low, "mask") | contains(low, "seg") | contains(low, "cellpose") | ...
                    contains(low, "sam") | contains(low, "viterbi") | contains(low, "track") | contains(low, "result");
                masks = cellstr(string(channels(keep)));
                masks = unique(masks(~cellfun(@isempty, masks)), 'stable');
            catch
                masks = {};
            end
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
                elseif strcmpi(role, 'metrics')
                    keep = contains(lower(string(names)), "quant") | contains(lower(string(names)), "metric");
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
                cacheKey = runtimeDataSeriesCacheKey(app);
                if isfield(app.RuntimeDataSeriesCache, 'key') && strcmp(char(string(app.RuntimeDataSeriesCache.key)), cacheKey) && ...
                        isfield(app.RuntimeDataSeriesCache, 'names')
                    names = app.RuntimeDataSeriesCache.names;
                    return;
                end
                [roiList, nFovSampled] = runtimeSampledRoisForDataSeries(app);
                if isempty(roiList)
                    app.RuntimeDataSeriesCache = struct('key', cacheKey, 'names', {{}}, 'sampledRoiCount', 0, 'sampledFovCount', 0);
                    return;
                end
                maxRoi = min(numel(roiList), 12);
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
                        displayName = dataSeriesDisplayName(app, ds(i));
                        if ~isempty(displayName)
                            names{end+1} = displayName; %#ok<AGROW>
                        end
                    end
                    if numel(unique(names(~cellfun(@isempty, names)), 'stable')) >= 16
                        break;
                    end
                end
                names = unique(names(~cellfun(@isempty, names)), 'stable');
                app.RuntimeDataSeriesCache = struct('key', cacheKey, 'names', {names}, ...
                    'sampledRoiCount', min(maxRoi, numel(roiList)), ...
                    'sampledFovCount', nFovSampled);
            catch
                names = {};
            end
        end

        function names = runtimeCachedDataSeriesNames(app)
            names = {};
            try
                cacheKey = runtimeDataSeriesCacheKey(app);
                if isfield(app.RuntimeDataSeriesCache, 'key') && strcmp(char(string(app.RuntimeDataSeriesCache.key)), cacheKey) && ...
                        isfield(app.RuntimeDataSeriesCache, 'names')
                    names = app.RuntimeDataSeriesCache.names;
                end
            catch
                names = {};
            end
        end

        function clearRuntimeDataSeriesCache(app)
            app.RuntimeDataSeriesCache = struct('key', '', 'names', {{}}, 'sampledRoiCount', 0, 'sampledFovCount', 0);
        end

        function name = dataSeriesDisplayName(app, item) %#ok<INUSD>
            name = '';
            probes = {'groupid','name','id','concreteName','symbol'};
            for i = 1:numel(probes)
                key = probes{i};
                value = [];
                try
                    if isstruct(item) && isfield(item, key)
                        value = item.(key);
                    elseif isobject(item) && isprop(item, key)
                        value = item.(key);
                    end
                catch
                    value = [];
                end
                if isempty(value)
                    continue;
                end
                txt = strtrim(char(string(value)));
                if ~isempty(txt)
                    name = txt;
                    return;
                end
            end
        end

        function key = runtimeDataSeriesCacheKey(app)
            parts = {};
            try, parts{end+1} = char(string(app.CurrentProjectVarName)); catch, end %#ok<AGROW>
            try
                if ~isempty(app.CurrentProject) && isa(app.CurrentProject, 'shallow')
                    [pth, file] = app.CurrentProject.getPath;
                    parts{end+1} = fullfile(pth, [file '.mat']); %#ok<AGROW>
                    parts{end+1} = sprintf('nfov=%d', numel(app.CurrentProject.fov)); %#ok<AGROW>
                    if ~isempty(app.CurrentProject.fov)
                        parts{end+1} = sprintf('nroi1=%d', numel(app.CurrentProject.fov(1).roi)); %#ok<AGROW>
                    end
                end
            catch
            end
            try, parts{end+1} = ['fovs=' char(string(getRuntimeValue(app, 'fovs')))]; catch, end %#ok<AGROW>
            try, parts{end+1} = ['rois=' char(string(getRuntimeValue(app, 'rois')))]; catch, end %#ok<AGROW>
            key = strjoin(parts, '|');
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

        function [roiList, nFovSampled] = runtimeSampledRoisForDataSeries(app)
            roiList = [];
            nFovSampled = 0;
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

                maxFov = min(numel(fovIdx), 4);
                fovIdx = deterministicSample(app, fovIdx, maxFov, runtimeDataSeriesCacheKey(app));
                roiSel = parseLooseSelection(app, getRuntimeValue(app, 'rois'));

                for k = 1:numel(fovIdx)
                    f = app.CurrentProject.fov(fovIdx(k));
                    if isempty(f.roi)
                        continue;
                    end
                    if isempty(roiSel) || ~isnumeric(roiSel)
                        roiIdx = 1:numel(f.roi);
                    else
                        roiIdx = round(double(roiSel(:)'));
                        roiIdx = roiIdx(roiIdx >= 1 & roiIdx <= numel(f.roi));
                    end
                    if isempty(roiIdx)
                        continue;
                    end
                    roiIdx = deterministicSample(app, roiIdx, min(numel(roiIdx), 3), ...
                        [runtimeDataSeriesCacheKey(app) '|fov=' num2str(fovIdx(k))]);
                    roiList = [roiList f.roi(roiIdx)]; %#ok<AGROW>
                    nFovSampled = nFovSampled + 1;
                    if numel(roiList) >= 12
                        roiList = roiList(1:12);
                        return;
                    end
                end
            catch
                roiList = [];
                nFovSampled = 0;
            end
        end

        function sample = deterministicSample(app, values, n, salt) %#ok<INUSD>
            values = values(:)';
            if numel(values) <= n
                sample = values;
                return;
            end
            seed = sum(double(char(string(salt)))) + 7919 * numel(values) + 104729 * n;
            oldState = rng;
            cleanupObj = onCleanup(@()rng(oldState)); %#ok<NASGU>
            rng(mod(seed, 2^32), 'twister');
            order = randperm(numel(values), n);
            sample = values(sort(order));
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
                    if ~resourceSpecCompatibleForUi(app, wantedType, wantedRole, outType, outRole)
                        continue;
                    end
                    resource = makeUiResourceChoice(app, srcNode, outSpec);
                    if resourceChoiceIsAmbiguousForSpec(app, resource, spec)
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
                if resourceOutputNameIsConcrete(app, spec, name)
                    return;
                end
                name = '';
            end
            param = char(string(getField(app, spec, 'param', '')));
            if ~isempty(param) && isstruct(params) && isfield(params, param) && ~isempty(params.(param))
                name = choiceScalarText(app, params.(param));
                if resourceOutputNameIsConcrete(app, spec, name)
                    return;
                end
                name = '';
            end
            role = lower(char(string(getField(app, spec, 'role', ''))));
            if strcmp(role, 'roi_image')
                name = '';
            else
                name = char(string(getField(app, node, 'id', '')));
            end
        end

        function tf = resourceOutputNameIsConcrete(app, spec, name) %#ok<INUSD>
            role = lower(char(string(getField(app, spec, 'role', ''))));
            name = strtrim(char(string(name)));
            tf = true;
            if strcmp(role, 'roi_image') && (isempty(name) || startsWith(name, '@') || any(strcmpi(name, {'all','*',':','<all>'})))
                tf = false;
            end
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
                    if ~resourceSpecCompatibleForUi(app, wantedType, wantedRole, outType, outRole)
                        continue;
                    end
                    resources = appendStruct(app, resources, makeUiResourceChoice(app, srcNode, outSpec)); %#ok<AGROW>
                end
            end
        end

        function tf = resourceSpecCompatibleForUi(app, wantedType, wantedRole, availableType, availableRole) %#ok<INUSD>
            wantedType = lower(char(string(wantedType)));
            wantedRole = lower(char(string(wantedRole)));
            availableType = lower(char(string(availableType)));
            availableRole = lower(char(string(availableRole)));
            tf = strcmp(wantedType, availableType) && resourceRolesCompatibleForUi(app, wantedRole, availableRole);
            if tf
                return;
            end
            tf = strcmp(wantedType, 'channel') && strcmp(wantedRole, 'mask_roi_image') && ...
                strcmp(availableType, 'mask') && strcmp(availableRole, 'segmentation');
        end

        function tf = resourceRolesCompatibleForUi(app, wantedRole, availableRole) %#ok<INUSD>
            wantedRole = lower(char(string(wantedRole)));
            availableRole = lower(char(string(availableRole)));
            tf = isempty(wantedRole) || isempty(availableRole) || strcmp(wantedRole, availableRole);
            if tf
                return;
            end
            if strcmp(wantedRole, 'score_roi_image')
                tf = any(strcmp(availableRole, roiScorableChannelRolesForUi(app)));
                return;
            end
            if strcmp(wantedRole, 'mask_roi_image')
                tf = any(strcmp(availableRole, {'roi_image','mask_roi_image','derived_roi_image','tracking','lineage_mask'}));
                return;
            end
            if strcmp(wantedRole, 'roi_image')
                tf = any(strcmp(availableRole, roiScorableChannelRolesForUi(app)));
                return;
            end
            tf = false;
        end

        function roles = roiScorableChannelRolesForUi(app) %#ok<INUSD>
            roles = {'roi_image','score_roi_image','derived_roi_image','probability','tracking','lineage_mask'};
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
                if ~resourceOutputNameIsConcrete(app, outSpec, concreteName)
                    concreteName = '';
                end
            end
            if isempty(concreteName)
                param = char(string(getField(app, outSpec, 'param', '')));
                if ~isempty(param) && isstruct(params) && isfield(params, param) && ~isempty(params.(param))
                    concreteName = choiceScalarText(app, params.(param));
                    if ~resourceOutputNameIsConcrete(app, outSpec, concreteName)
                        concreteName = '';
                    end
                end
            end
            if isempty(concreteName)
                role = lower(char(string(getField(app, outSpec, 'role', ''))));
                if ~strcmp(role, 'roi_image')
                    concreteName = sourceNode;
                end
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
            symbol = char(string(getField(app, spec, 'symbol', '')));
            if strcmpi(type, 'channel') && strcmpi(role, 'probability')
                label = 'channel/probability';
                return;
            elseif strcmpi(type, 'mask') && strcmpi(role, 'segmentation') && strcmpi(symbol, 'segmentation')
                label = 'mask/segmentation';
                return;
            end
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
            if contains(value, '.')
                parts = strsplit(value, '.');
                sourceNode = strtrim(parts{1});
                return;
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
            if ~isfield(ctx, 'masks') || isempty(ctx.masks)
                runtimeMasks = runtimeMaskChoices(app);
                if ~isempty(runtimeMasks)
                    ctx.masks = runtimeMasks;
                end
            end
        end

        function txt = choiceScalarText(app, v) %#ok<INUSD>
            txt = '';
            if isempty(v)
                return;
            end
            if isMissingValue(app, v)
                return;
            end
            if iscell(v)
                flat = v(~cellfun(@isempty, v));
                flat = flat(~cellfun(@(x)isMissingValue(app, x), flat));
                if isempty(flat)
                    return;
                end
                txt = char(string(flat{end}));
            elseif ischar(v)
                txt = v;
            elseif isstring(v) || isnumeric(v) || islogical(v) || iscategorical(v)
                vals = string(v(:));
                try
                    vals = vals(~ismissing(vals));
                catch
                end
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

        function grid = buildParamSection(app, parent, data, node, editable, scope)
            if nargin < 6 || isempty(scope)
                scope = 'static';
            end
            n = max(1, size(data, 1));
            grid = uigridlayout(parent, [n 2]);
            grid.RowHeight = repmat({28}, 1, n);
            grid.ColumnWidth = {210, '1x'};
            grid.Padding = [0 0 0 0];
            grid.RowSpacing = 6;
            grid.ColumnSpacing = 8;

            for i = 1:size(data, 1)
                key = char(string(data{i,1}));
                label = uilabel(grid, 'Text', friendlyParamLabel(app, key));
                label.Layout.Row = i;
                label.Layout.Column = 1;
                label.Tooltip = key;

                value = resolveDisplayedParamValue(app, node, key, data{i,2}, scope);
                ctrl = createParamControl(app, grid, node, key, value, editable, scope);
                ctrl.Layout.Row = i;
                ctrl.Layout.Column = 2;
            end
        end

        function value = resolveDisplayedParamValue(app, node, key, defaultValue, scope)
            if nargin < 5 || isempty(scope)
                scope = 'static';
            end
            value = defaultValue;
            p = getField(app, node, 'params', struct());
            if strcmpi(scope, 'runtime')
                nodeId = char(string(getField(app, node, 'id', '')));
                rp = getRuntimeNodeParams(app, nodeId);
                if isstruct(rp) && isfield(rp, key)
                    value = rp.(key);
                elseif isstruct(p) && isfield(p, key) && ~isSymbolicStoredBinding(app, p.(key))
                    value = p.(key);
                end
            else
                if isstruct(p) && isfield(p, key)
                    value = p.(key);
                end
            end

            nodeType = char(string(getField(app, node, 'type', '')));
            pkg = lower(char(string(getField(app, node, 'pkg', ''))));
            if strcmpi(scope, 'static') && strcmpi(nodeType, 'processor') && ...
                    strcmp(pkg, 'combinemultiplechannels') && strcmpi(char(string(key)), 'requiredChannelCount')
                if isempty(value) || (ischar(value) && isempty(strtrim(value))) || (isstring(value) && strlength(strtrim(value)) == 0)
                    value = 0;
                end
            end
            if strcmpi(scope, 'static') && strcmpi(nodeType, 'classifier')
                switch lower(char(string(key)))
                    case 'outputmode'
                        if isempty(strtrim(char(string(value))))
                            value = 'lstm_only';
                        end
                    case 'outputtype'
                        if isempty(strtrim(char(string(value))))
                            value = 'segmentation';
                        end
                    case 'diameter'
                        if isempty(value) || (ischar(value) && isempty(strtrim(value))) || (isstring(value) && strlength(strtrim(value)) == 0)
                            value = NaN;
                        end
                    case 'min_size'
                        if isempty(value) || (ischar(value) && isempty(strtrim(value))) || (isstring(value) && strlength(strtrim(value)) == 0)
                            value = 10;
                        end
                    case 'flow_threshold'
                        if isempty(value) || (ischar(value) && isempty(strtrim(value))) || (isstring(value) && strlength(strtrim(value)) == 0)
                            value = 0.4;
                        end
                    case 'cell_prob_threshold'
                        if isempty(value) || (ischar(value) && isempty(strtrim(value))) || (isstring(value) && strlength(strtrim(value)) == 0)
                            value = 0;
                        end
                end
            end
            if strcmpi(scope, 'runtime') && strcmpi(nodeType, 'dataLoader') && strcmpi(char(string(key)), 'path')
                rawDataPath = getRuntimeValue(app, 'rawDataPath');
                if ~isempty(strtrim(rawDataPath))
                    value = rawDataPath;
                end
            end
        end

        function ctrl = createParamControl(app, parent, node, key, value, editable, scope)
            if nargin < 7 || isempty(scope)
                scope = 'static';
            end
            value = normalizeMissingParamValue(app, value);
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
                ctrl.ValueChangedFcn = @(src,~)paramControlChanged(app, node, key, src.Value, scope);
                return;
            end

            valueText = safeScalarText(app, value);
            if islogical(value) || any(strcmpi(valueText, {'true','false'}))
                ctrl = uicheckbox(parent, 'Text', '');
                if islogical(value)
                    ctrl.Value = logical(value);
                else
                    ctrl.Value = strcmpi(valueText, 'true');
                end
                ctrl.Enable = enableState;
                ctrl.ValueChangedFcn = @(src,~)paramControlChanged(app, node, key, src.Value, scope);
                return;
            end

            if isnumeric(value) && isscalar(value)
                ctrl = uieditfield(parent, 'numeric');
                ctrl.Value = double(value);
                if strcmpi(nodeType, 'processor') && strcmpi(char(string(getField(app, node, 'pkg', ''))), 'combinemultiplechannels') && ...
                        strcmp(keyLower, 'requiredchannelcount')
                    ctrl.Limits = [0 5];
                    try
                        ctrl.RoundFractionalValues = 'on';
                    catch
                    end
                    ctrl.Tooltip = 'Number of input channel bindings to expose. Use 0 for the legacy 5-slot mode.';
                end
                ctrl.Enable = enableState;
                ctrl.ValueChangedFcn = @(src,~)paramControlChanged(app, node, key, src.Value, scope);
                return;
            end

            ctrl = uieditfield(parent, 'text');
            ctrl.Value = paramValueToDisplay(app, node, key, value);
            ctrl.Enable = enableState;
            ctrl.ValueChangedFcn = @(src,~)paramControlChanged(app, node, key, src.Value, scope);
        end

        function choices = paramDropdownChoices(app, node, key) %#ok<INUSD>
            nodeType = lower(char(string(getField(app, node, 'type', ''))));
            keyLower = lower(char(string(key)));
            choices = {};
            switch nodeType
                case 'classifier'
                    switch keyLower
                        case 'outputmode'
                            choices = {'lstm_only','cnn_only','both'};
                        case 'outputtype'
                            choices = {'segmentation','probability','both'};
                    end
                case 'roiextract'
                    switch keyLower
                        case 'driftmethod'
                            choices = {'subpixel','circshift','register'};
                        case 'driftrefmode'
                            choices = {'previous','first'};
                        case 'driftchannel'
                            choices = runtimeChannelChoices(app, true);
                    end
                case 'processor'
                    pkg = lower(char(string(getField(app, node, 'pkg', ''))));
                    if strcmp(pkg, 'computerls') && strcmp(keyLower, 'statedecoder')
                        choices = {'off','viterbi','median'};
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

        function paramControlChanged(app, node, key, value, scope)
            if nargin < 6 || isempty(scope)
                scope = 'static';
            end
            nodeId = char(string(getField(app, node, 'id', '')));
            idx = find(strcmp({app.Data.nodes.id}, nodeId), 1);
            if isempty(idx)
                return;
            end
            focus = captureTabFocus(app);
            d = openRuntimeProgress(app, 'Pipeline parameters', 'Applying parameter change...');
            drawnow limitrate;
            cleanupObj = onCleanup(@()finishStaticParameterRefresh(app, d, [], focus)); %#ok<NASGU>
            if strcmpi(char(string(key)), 'driftChannel') && strcmpi(char(string(value)), 'auto')
                value = [];
            end
            nodeType = char(string(getField(app, app.Data.nodes(idx), 'type', '')));
            pkg = lower(char(string(getField(app, app.Data.nodes(idx), 'pkg', ''))));
            keyText = char(string(key));
            if strcmpi(scope, 'static') && strcmpi(nodeType, 'processor') && ...
                    strcmp(pkg, 'combinemultiplechannels') && strcmpi(keyText, 'requiredChannelCount')
                value = normalizeCombineChannelCount(app, value);
            elseif strcmpi(scope, 'static') && strcmpi(nodeType, 'processor') && ...
                    strcmp(pkg, 'computemetrics') && any(strcmpi(keyText, {'maskChannelCount','scoreChannelCount'}))
                if strcmpi(keyText, 'maskChannelCount')
                    value = normalizeCountValue(app, value, 1, 8);
                else
                    value = normalizeCountValue(app, value, 0, 12);
                end
            end

            if strcmpi(scope, 'runtime')
                runtimeParams = getRuntimeNodeParams(app, nodeId);
                runtimeParams.(keyText) = value;
                setRuntimeNodeParams(app, nodeId, runtimeParams);
                if strcmpi(nodeType, 'dataLoader') && strcmpi(keyText, 'path')
                    setRuntimeValue(app, 'rawDataPath', value);
                end
            else
                if ~isfield(app.Data.nodes(idx), 'params') || ~isstruct(app.Data.nodes(idx).params)
                    app.Data.nodes(idx).params = struct();
                end
                app.Data.nodes(idx).params.(keyText) = value;
            end
            needsBindingRefresh = ~strcmpi(scope, 'runtime') && ...
                (any(strcmpi(keyText, {'outputMode','outputType'})) || ...
                staticParamAffectsBindings(app, app.Data.nodes(idx), keyText));
            if needsBindingRefresh
                updateRuntimeProgress(app, d, 'Rebuilding pipeline module tabs...');
                refreshModuleTabs(app);
            end
            updateRuntimeProgress(app, d, 'Checking pipeline bindings...');
            refreshValidationReport(app);
        end

        function value = normalizeCombineChannelCount(app, value) %#ok<INUSD>
            value = normalizeCountValue(app, value, 0, 5);
        end

        function value = normalizeCountValue(app, value, minValue, maxValue) %#ok<INUSD>
            try
                value = double(value);
            catch
                value = 0;
            end
            if isempty(value) || ~isscalar(value) || ~isfinite(value)
                value = 0;
            end
            value = min(maxValue, max(minValue, round(value)));
        end

        function tf = staticParamAffectsBindings(app, node, key) %#ok<INUSD>
            nodeType = char(string(getField(app, node, 'type', '')));
            pkg = char(string(getField(app, node, 'pkg', '')));
            keyText = char(string(key));
            tf = (strcmpi(nodeType, 'processor') && ...
                strcmpi(pkg, 'combinemultiplechannels') && ...
                strcmpi(keyText, 'requiredChannelCount')) || ...
                (strcmpi(nodeType, 'processor') && ...
                strcmpi(pkg, 'computemetrics') && ...
                any(strcmpi(keyText, {'maskChannelCount','scoreChannelCount'}))) || ...
                (strcmpi(nodeType, 'classifier') && ...
                strcmpi(pkg, 'cellposesam') && ...
                strcmpi(keyText, 'outputType'));
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
                    case {'roipattern','roiidentify'}
                        keys = {'threshold'};
                    case 'roimanual'
                        keys = {};
                    case 'roiextract'
                        keys = {'correctDrift','driftChannel','driftMethod','driftRefMode','driftSubpixel','driftMaxShift','scale','cropDrift','forceChannelNames'};
                    case 'processor'
                        keys = processorStaticKeys(app, pkg, node);
                    case 'classifier'
                        keys = classifierStaticKeys(app, pkg);
                    otherwise
                        keys = contractParamKeys(app, node, scope);
                end
            else
                switch nodeType
                    case 'dataloader'
                        keys = {};
                    case {'roipattern','roiidentify'}
                        keys = {};
                    case 'roimanual'
                        keys = {};
                    case 'roigrid'
                        keys = {};
                    case 'roitracked'
                        keys = {};
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
                        keys = [cellstr(getParamList(app, params, 'static')), ...
                            cellstr(getParamList(app, params, 'fixed')), ...
                            cellstr(getParamList(app, params, 'design')), ...
                            cellstr(getParamList(app, params, 'template'))];
                    otherwise
                        keys = [cellstr(getParamList(app, params, 'run')), ...
                            cellstr(getParamList(app, params, 'data'))];
                end
            end
        end

        function keys = processorStaticKeys(app, pkg, node)
            if nargin < 3
                node = struct();
            end
            switch pkg
                case 'combinemultiplechannels'
                    slotCount = combineMultipleChannelsSlotCountForNode(app, node);
                    rgbKeys = arrayfun(@(i)sprintf('RGB_Channel%d', i), 1:slotCount, 'UniformOutput', false);
                    keys = [{'requiredChannelCount'}, rgbKeys, {'debug'}];
                case 'computemetrics'
                    keys = computeMetricsStaticKeysForNode(app, node);
                case 'computerls'
                    keys = moduleSetparamKeys(app, pkg);
                    keys = setdiff(keys, {'classification_data','outputName','pkg','paramTooltip','tip'}, 'stable');
                case 'computelineage'
                    keys = moduleSetparamKeys(app, pkg);
                    keys = setdiff(keys, {'classification_data','outputName','pkg','tip'}, 'stable');
                case 'computemaxprojection'
                    keys = {'method','zstacks'};
                case 'basicobjecttracking'
                    keys = {'inputMode','coefDist','coefSize','coefIoU','maxRelativeDistance','debug'};
                case 'trackmotherlineageviterbi'
                    keys = {'mode','debug', ...
                        'wM_center','wM_area','wM_bottom','wB_dist','wB_small', ...
                        'lambdaM_jump','lambdaM_area','lambdaM_appear','lambdaM_disapp', ...
                        'lambdaB_jump','lambdaB_area','lambdaB_appear','lambdaB_disapp', ...
                        'tempConf','bottomSign','ratioMin','bonusSwitch'};
                otherwise
                    keys = moduleSetparamKeys(app, pkg);
                    keys = setdiff(keys, {'outputName','outputChannelName','existingPolicy','pkg','paramTooltip','tip'}, 'stable');
            end
        end

        function n = combineMultipleChannelsSlotCountForNode(app, node) %#ok<INUSD>
            maxSlots = 5;
            n = maxSlots;
            p = getField(app, node, 'params', struct());
            if ~isstruct(p) || ~isfield(p, 'requiredChannelCount') || isempty(p.requiredChannelCount)
                return;
            end
            try
                requested = double(p.requiredChannelCount);
            catch
                requested = 0;
            end
            if ~isscalar(requested) || ~isfinite(requested) || requested <= 0
                return;
            end
            n = min(maxSlots, max(1, round(requested)));
        end

        function keys = computeMetricsStaticKeysForNode(app, node)
            maskCount = computeMetricsMaskSlotCountForNode(app, node);
            keys = {'maskChannelCount','scoreChannelCount'};
            for i = 1:maskCount
                keys = [keys, { ...
                    sprintf('mask%d_label', i), ...
                    sprintf('mask%d_stat', i)}]; %#ok<AGROW>
            end
            keys = [keys, {'BrightestPixels'}];
        end

        function n = computeMetricsMaskSlotCountForNode(app, node)
            n = computeMetricsCountForNode(app, node, {'maskChannelCount','maskCount'}, 2, 1, 8);
        end

        function n = computeMetricsScoreSlotCountForNode(app, node)
            n = computeMetricsCountForNode(app, node, {'scoreChannelCount','channelCount'}, 4, 0, 12);
        end

        function n = computeMetricsCountForNode(app, node, names, defaultValue, minValue, maxValue) %#ok<INUSD>
            n = defaultValue;
            p = getField(app, node, 'params', struct());
            if isstruct(p)
                for i = 1:numel(names)
                    key = char(string(names{i}));
                    if isfield(p, key) && ~isempty(p.(key))
                        try
                            requested = double(p.(key));
                        catch
                            requested = NaN;
                        end
                        if isscalar(requested) && isfinite(requested)
                            n = requested;
                            break;
                        end
                    end
                end
            end
            n = min(maxValue, max(minValue, round(n)));
        end

        function keys = classifierStaticKeys(app, pkg)
            switch pkg
                case 'cnn_lstm'
                    keys = {'outputMode'};
                case 'cellposesam'
                    keys = {'outputType','diameter','min_size','flow_threshold','cell_prob_threshold'};
                otherwise
                    keys = {};
            end
        end

        function keys = moduleSetparamKeys(app, pkg)
            keys = {};
            if isempty(pkg)
                return;
            end
            pkg = canonicalProcessorPackageName(app, pkg);
            try
                p = feval([char(string(pkg)) '.setparam'], moduleSetparamPreviewContext(app, pkg));
                if isstruct(p)
                    keys = fieldnames(p)';
                end
            catch
                keys = {};
            end
        end

        function ctx = moduleSetparamPreviewContext(app, pkg)
            % Avoid legacy setparam fallbacks that scan the MATLAB workspace
            % and load ROI dataseries while pipeline2 is only discovering UI keys.
            ctx = struct();
            ctx.useProvidedChannels = true;
            ctx.channels = {'N/A'};
            ctx.roiChannels = {'N/A'};
            ctx.masks = {'N/A'};
            ctx.dataSeries = {''};
            ctx.dataSeriesNames = {''};
            ctx.classification_data = {''};
            ctx.classificationData = {''};
            try
                channels = runtimeConcreteChannels(app);
                if ~isempty(channels)
                    ctx.channels = channels;
                    ctx.roiChannels = channels;
                end
            catch
            end
            try
                ds = runtimeCachedDataSeriesNames(app);
                if ~isempty(ds)
                    ctx.dataSeries = ds;
                    ctx.dataSeriesNames = ds;
                    ctx.classification_data = ds;
                    ctx.classificationData = ds;
                end
            catch
            end
            switch lower(char(string(pkg)))
                case {'computerls','computelineage'}
                    if isempty(ctx.classification_data)
                        ctx.classification_data = {''};
                        ctx.classificationData = {''};
                    end
            end
        end

        function pkg = canonicalProcessorPackageName(app, pkg) %#ok<INUSD>
            raw = char(string(pkg));
            switch lower(strtrim(raw))
                case 'combinemultiplechannels'
                    pkg = 'combineMultipleChannels';
                case 'computemetrics'
                    pkg = 'computeMetrics';
                case 'computerls'
                    pkg = 'computeRLS';
                case 'computelineage'
                    pkg = 'computeLineage';
                case 'computemaxprojection'
                    pkg = 'computeMaxProjection';
                case 'basicobjecttracking'
                    pkg = 'basicObjectTracking';
                case 'formatindataseries'
                    pkg = 'formatInDataSeries';
                case 'trackmotherlineageviterbi'
                    pkg = 'trackMotherLineageViterbi';
                otherwise
                    pkg = raw;
            end
        end

        function pkg = canonicalModulePackageName(app, nodeType, pkg)
            if strcmpi(char(string(nodeType)), 'processor')
                pkg = canonicalProcessorPackageName(app, pkg);
                return;
            end
            raw = char(string(pkg));
            key = lower(strtrim(raw));
            switch lower(char(string(nodeType)))
                case 'dataloader'
                    switch key
                        case 'dataloader'
                            pkg = 'dataLoader';
                        otherwise
                            pkg = raw;
                    end
                case {'roipattern','roiidentify'}
                    pkg = 'roiPattern';
                case 'roimanual'
                    pkg = 'roiManual';
                case 'roigrid'
                    pkg = 'roiGrid';
                case 'roitracked'
                    pkg = 'roiTracked';
                case 'roiextract'
                    pkg = 'roiExtract';
                case 'classifier'
                    switch key
                        case 'cellposesam'
                            pkg = 'cellposesam';
                        case 'cnn_lstm'
                            pkg = 'cnn_lstm';
                        case 'cnn'
                            pkg = 'cnn';
                        otherwise
                            pkg = raw;
                    end
                otherwise
                    pkg = raw;
            end
        end

        function keys = processorRuntimeKeys(app, pkg) %#ok<INUSD>
            switch pkg
                otherwise
                    keys = {};
            end
        end

        function keys = removeGlobalRuntimeKeys(app, keys) %#ok<INUSD>
            globalKeys = {'fovIndex','roiIndex','roiList','frames','channels','extractFrames','extractChannels','positionFilter','channelFilter','stackFilter'};
            keys = keys(~ismember(lower(keys), lower(globalKeys)));
        end

        function keys = filterParamsByAdvancedMode(app, node, keys)
            % Deprecated: keep all declared parameters visible in their
            % role-specific section.
        end

        function keys = easyParamKeys(app, node) %#ok<INUSD>
            nodeType = lower(char(string(getField(app, node, 'type', ''))));
            pkg = lower(char(string(getField(app, node, 'pkg', ''))));
            switch nodeType
                case 'dataloader'
                    keys = {'path','positionFilter','channelFilter','stackFilter','label'};
                case {'roipattern','roiidentify'}
                    keys = {'channel','channelIndex','referenceFrame','threshold','fovIndex'};
                case 'roimanual'
                    keys = {'fovIndex'};
                case 'roigrid'
                    keys = {'gridCount'};
                case 'roitracked'
                    keys = {'fovIndex','roiIndex','channel','extractChannels'};
                case 'roiextract'
                    keys = {'correctDrift','driftChannel','driftMethod','driftRefMode', ...
                        'driftSubpixel','driftMaxShift','scale','cropDrift','forceChannelNames'};
                case 'processor'
                    if strcmp(pkg, 'combinemultiplechannels')
                        slotCount = combineMultipleChannelsSlotCountForNode(app, node);
                        rgbKeys = arrayfun(@(i)sprintf('RGB_Channel%d', i), 1:slotCount, 'UniformOutput', false);
                        keys = [{'requiredChannelCount'}, rgbKeys];
                    elseif strcmp(pkg, 'computemetrics')
                        keys = computeMetricsStaticKeysForNode(app, node);
                    elseif strcmp(pkg, 'computerls')
                        keys = {'AverageFluoByDivision','StateDecoder','ExpectedDivisionPeriod','MinDivisionInterval','MinDivisionIntervalFactor','ArrestThreshold','DeathThreshold','ClogThreshold','EmptyThresholdNext','QCMinMeanMargin','QCMaxLowConfidenceFraction'};
                    elseif strcmp(pkg, 'computelineage')
                        keys = {'ArrestThreshold','DeathThreshold','ClogThreshold','EmptyThresholdNext'};
                    elseif strcmp(pkg, 'computemaxprojection')
                        keys = {'method','zstacks'};
                    elseif strcmp(pkg, 'basicobjecttracking')
                        keys = {'inputMode','coefDist','coefSize','coefIoU','maxRelativeDistance'};
                    elseif strcmp(pkg, 'trackmotherlineageviterbi')
                        keys = {'mode','tempConf','bottomSign','ratioMin','bonusSwitch'};
                    else
                        keys = {'channels','channel','frames'};
                    end
                case 'classifier'
                    keys = {'outputMode','outputType'};
                otherwise
                    keys = {};
            end
        end

        function out = valueToDisplay(app, v) %#ok<INUSD>
            if isMissingValue(app, v)
                out = '';
            elseif ischar(v)
                out = v;
            elseif isstring(v)
                try
                    v = v(~ismissing(v));
                catch
                end
                if isempty(v)
                    out = '';
                else
                    out = char(strjoin(v(:), ', '));
                end
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

        function tf = isMissingValue(app, v) %#ok<INUSD>
            tf = false;
            try
                tf = any(ismissing(v(:)));
            catch
                tf = false;
            end
        end

        function v = normalizeMissingParamValue(app, v)
            if isMissingValue(app, v)
                if iscell(v)
                    try
                        keep = ~cellfun(@(x)isMissingValue(app, x), v);
                        v = v(keep);
                    catch
                        v = {};
                    end
                    if isempty(v)
                        v = '';
                    end
                elseif isstring(v)
                    try
                        v = v(~ismissing(v));
                    catch
                        v = strings(0,1);
                    end
                    if isempty(v)
                        v = "";
                    end
                else
                    v = '';
                end
            end
        end

        function txt = safeScalarText(app, v) %#ok<INUSD>
            txt = '';
            if isempty(v)
                return;
            end
            try
                if isMissingValue(app, v)
                    return;
                end
                vals = string(v(:));
                vals = vals(~ismissing(vals));
                if ~isempty(vals)
                    txt = char(vals(end));
                end
            catch
                txt = '';
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
                app.LastValidationOk = false;
                app.LastValidationReport = struct();
                app.RuninformationhereLabel.Text = 'Template mode - no module yet.';
                app.PipelineandRuncheckreportLabel.Text = 'Click the grey block to add the first module.';
                redrawGraph(app);
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
            app.LastValidationOk = logical(ok);
            app.LastValidationReport = report;

            app.Data.nodes = annotateNodeStatus(app, app.Data.nodes, report);
            refreshSelectedModuleTable(app);

            if ok
                app.RuninformationhereLabel.Text = sprintf('Template mode - %d module(s), %d edge(s), valid.', numel(pipe.nodes), numel(pipe.edges));
            else
                app.RuninformationhereLabel.Text = sprintf('Template mode - %d module(s), %d edge(s), needs attention.', numel(pipe.nodes), numel(pipe.edges));
            end
            app.PipelineandRuncheckreportLabel.Text = [formatValidationReport(app, ok, report) newline newline formatRunPolicySummary(app)];
            redrawGraph(app);
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
                app.LastValidationOk = false;
                app.LastValidationReport = report;
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
            app.LastValidationOk = logical(ok);
            app.LastValidationReport = report;
            app.Data.nodes = annotateNodeStatus(app, app.Data.nodes, report);
            refreshSelectedModuleTable(app);
            app.RuninformationhereLabel.Text = ternary(app, ok, ...
                sprintf('Template mode - %d module(s), %d edge(s), valid.', numel(pipe.nodes), numel(pipe.edges)), ...
                sprintf('Template mode - %d module(s), %d edge(s), needs attention.', numel(pipe.nodes), numel(pipe.edges)));
            redrawGraph(app);
        end

        function issues = validateRuntimeInputs(app)
            issues = {};
            projectPath = strtrim(getRuntimeValue(app, 'projectPath'));
            rawDataPath = strtrim(getRuntimeValue(app, 'rawDataPath'));
            projectOk = ~isempty(projectPath) && (exist(projectPath, 'dir') == 7 || exist(projectPath, 'file') == 2);
            rawOk = ~isempty(rawDataPath) && exist(rawDataPath, 'dir') == 7;
            startsFromProject = runtimeStartsFromExistingProject(app);

            if ~isempty(projectPath) && ~projectOk
                issues{end+1} = ['Project path does not exist: ' projectPath]; %#ok<AGROW>
                markRuntimeField(app, 'projectPath', 'missing', 'Project must be an existing folder or project .mat file.');
            end

            if startsFromProject
                if ~projectOk
                    issues{end+1} = 'Existing project mode requires a loaded shallow project.'; %#ok<AGROW>
                    markRuntimeField(app, 'projectPath', 'missing', 'Project must be an existing folder or project .mat file.');
                end
            elseif pipelineHasNodeType(app, 'dataLoader')
                if isempty(rawDataPath)
                    issues{end+1} = 'Raw data folder is required when input source is Raw data via dataloader.'; %#ok<AGROW>
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
                hasPassword = hasUserKey && ~isempty(strtrim(hubPasswordFromUi(app)));
                if ~(hasToken || hasUserKey || hasPassword)
                    issues{end+1} = 'Hub user key, password login, or session token is required when run target is Hub.'; %#ok<AGROW>
                end
                pathReport = hubPathPreflight(app, hub);
                if ~pathReport.ok
                    for i = 1:numel(pathReport.errors)
                        issues{end+1} = pathReport.errors{i}; %#ok<AGROW>
                    end
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
            inputSourceLabel = 'existing project ROIs';
            if ~runtimeStartsFromExistingProject(app)
                inputSourceLabel = 'raw data via dataloader';
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
                '- Input source: ' inputSourceLabel newline ...
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
                symbolicEdges = validationReportResourceBindingEdges(app, report);
                if ~isempty(symbolicEdges)
                    lines{end+1} = ''; %#ok<AGROW>
                    lines{end+1} = 'Symbolic links:'; %#ok<AGROW>
                    for i = 1:min(numel(symbolicEdges), 8)
                        lines{end+1} = sprintf('- %s -> %s', ...
                            char(string(symbolicEdges(i).from)), ...
                            char(string(symbolicEdges(i).to))); %#ok<AGROW>
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

        function edges = validationReportResourceBindingEdges(app, report) %#ok<INUSD>
            edges = struct('from',{},'to',{},'fromPort',{},'toPort',{},'condition',{});
            if ~isstruct(report) || ~isfield(report, 'edges') || isempty(report.edges)
                return;
            end
            raw = report.edges;
            keep = false(size(raw));
            for i = 1:numel(raw)
                keep(i) = strcmpi(char(string(getField(app, raw(i), 'condition', ''))), 'resourceBinding');
            end
            edges = raw(keep);
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
            pipe.name = currentPipelineName(app);
            pipe.nodes = sanitizeNodeParamsForPipeline(app, app.Data.nodes);
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
                hasExtractChannels = isfield(nodes(i).params, 'extractChannels') && ~isempty(nodes(i).params.extractChannels);
                hasLegacyChannels = isfield(nodes(i).params, 'channels') && ~isempty(nodes(i).params.channels);
                if ~hasExtractChannels && hasLegacyChannels
                    nodes(i).params.extractChannels = nodes(i).params.channels;
                elseif ~hasExtractChannels
                    nodes(i).params.extractChannels = '@source';
                end
                if isfield(nodes(i).params, 'channels')
                    nodes(i).params = rmfield(nodes(i).params, 'channels');
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
            pipe.nodes = stripRuntimeParamsFromNodes(app, sanitizeNodeParamsForPipeline(app, app.Data.nodes));
            pipe.edges = app.Data.edges;
            pipe.branches = struct([]);
        end

        function nodes = sanitizeNodeParamsForPipeline(app, nodes)
            nodes = sanitizeClassifierNodeParams(app, nodes);
            nodes = sanitizeProcessorNodeParams(app, nodes);
            nodes = pipelineNormalizeNodes(nodes, 'persist');
        end

        function nodes = sanitizeProcessorNodeParams(app, nodes) %#ok<INUSD>
            for i = 1:numel(nodes)
                nodeType = lower(char(string(getField(app, nodes(i), 'type', ''))));
                pkg = lower(char(string(getField(app, nodes(i), 'pkg', ''))));
                if ~strcmp(nodeType, 'processor') || ~strcmp(pkg, 'computerls') || ...
                        ~isfield(nodes(i), 'params') || ~isstruct(nodes(i).params)
                    continue;
                end
                if isfield(nodes(i).params, 'StateDecoder')
                    nodes(i).params.StateDecoder = choiceScalarText(app, nodes(i).params.StateDecoder);
                    if isempty(nodes(i).params.StateDecoder)
                        nodes(i).params.StateDecoder = 'off';
                    end
                end
            end
        end

        function nodes = sanitizeClassifierNodeParams(app, nodes) %#ok<INUSD>
            for i = 1:numel(nodes)
                nodeType = lower(char(string(getField(app, nodes(i), 'type', ''))));
                if ~strcmp(nodeType, 'classifier') || ~isfield(nodes(i), 'params') || ~isstruct(nodes(i).params)
                    continue;
                end
                pkg = lower(char(string(getField(app, nodes(i), 'pkg', ''))));
                if isfield(nodes(i).params, 'trainingParam')
                    nodes(i).params = rmfield(nodes(i).params, 'trainingParam');
                end
                if strcmp(pkg, 'cnn_lstm')
                    keys = fieldnames(nodes(i).params);
                    drop = false(size(keys));
                    exact = {'train_CNN_classifier','compute_CNN_activations','train_LSTM_network', ...
                        'assemble_network','classifier_output','execution_environment','transfer_learning','tip'};
                    prefixes = {'CNN_','LSTM_','Format_'};
                    for kk = 1:numel(keys)
                        drop(kk) = any(strcmp(keys{kk}, exact)) || any(startsWith(keys{kk}, prefixes));
                    end
                    if any(drop)
                        nodes(i).params = rmfield(nodes(i).params, keys(drop));
                    end
                end
            end
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
            pipeObj.description = ['Created from ' guiAppName(app)];
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
            pipeObj.nodes = sanitizeNodeParamsForPipeline(app, pipeObj.nodes);
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
            name = defaultPipelineTemplateName(app);
            if ~isempty(app.CurrentPipeline) && isa(app.CurrentPipeline, 'pipeline') && ~isempty(app.CurrentPipeline.strid)
                name = char(string(app.CurrentPipeline.strid));
                if strcmp(name, guiAppName(app))
                    name = defaultPipelineTemplateName(app);
                end
            elseif ~isempty(app.CurrentPipelinePath)
                [~, name] = fileparts(app.CurrentPipelinePath);
                if isempty(name) || strcmp(name, guiAppName(app))
                    name = defaultPipelineTemplateName(app);
                end
            end
        end

        function name = guiAppName(app) %#ok<INUSD>
            name = 'pipelineGUI2';
        end

        function name = defaultPipelineTemplateName(app) %#ok<INUSD>
            name = 'pipelineTemplate';
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
                [runSaved, runJsonPath] = saveCurrentRunSnapshotIfProjectAvailable(app);
                addRecentPipelinePath(app, fullfile(pipeObj.path, 'pipeline.json'));
                ok = true;
                suffix = '';
                if ~isempty(app.CurrentPipelineWorkspaceVar)
                    suffix = [' | workspace: ' app.CurrentPipelineWorkspaceVar];
                end
                msg = ['Pipeline saved: ' fullfile(pipeObj.path, 'pipeline.json') suffix];
                if runSaved
                    msg = [msg ' | run saved: ' runJsonPath];
                end
                app.RuninformationhereLabel.Text = msg;
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
            if strcmp(varName, guiAppName(app))
                varName = defaultPipelineTemplateName(app);
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

        function loadPipelineFromObject(app, pipeObj, restoreLatestRun)
            if nargin < 3 || isempty(restoreLatestRun)
                restoreLatestRun = true;
            end
            if isempty(pipeObj) || ~isa(pipeObj, 'pipeline')
                return;
            end
            nodes = pipeObj.nodes;
            if isempty(nodes)
                nodes = struct([]);
            end
            nodes = normalizeLoadedNodeLayouts(app, nodes);
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
            refreshSelectedModuleTable(app);
            latestRunApplied = false;
            if logical(restoreLatestRun)
                latestRunApplied = applyLatestRunForCurrentPipeline(app, false);
            end
            refreshAfterModelChange(app);
            if latestRunApplied && ~isempty(app.CurrentRun) && isa(app.CurrentRun, 'pipelineRun')
                try
                    app.RuninformationhereLabel.Text = ['Pipeline loaded with latest run: ' char(string(app.CurrentRun.runId))];
                catch
                end
            end
        end

        function applied = applyLatestRunForCurrentPipeline(app, refreshUi)
            if nargin < 2 || isempty(refreshUi)
                refreshUi = true;
            end
            applied = false;
            if ~isempty(app.CurrentRun) || isempty(app.CurrentPipeline) || ~isa(app.CurrentPipeline, 'pipeline') || ...
                    isempty(app.CurrentProject) || ~isa(app.CurrentProject, 'shallow')
                return;
            end
            try
                runs = app.CurrentPipeline.findDependentRuns(app.CurrentProject);
            catch
                runs = pipelineRun.empty;
            end
            runObj = latestPipelineRun(app, runs);
            if isempty(runObj)
                return;
            end
            loadRunIntoUi(app, runObj, refreshUi);
            applied = true;
            if logical(refreshUi)
                try
                    app.RuninformationhereLabel.Text = ['Pipeline loaded with latest run: ' char(string(runObj.runId))];
                catch
                end
            end
        end

        function runObj = latestPipelineRun(app, runs)
            runObj = [];
            if isempty(runs)
                return;
            end
            bestScore = -inf;
            bestIdx = 0;
            for i = 1:numel(runs)
                score = pipelineRunTimestampScore(app, runs(i), i);
                if score >= bestScore
                    bestScore = score;
                    bestIdx = i;
                end
            end
            if bestIdx > 0
                runObj = runs(bestIdx);
            end
        end

        function score = pipelineRunTimestampScore(app, runObj, fallbackIndex) %#ok<INUSD>
            score = double(fallbackIndex);
            txt = '';
            try
                if isprop(runObj, 'updatedAt') && ~isempty(runObj.updatedAt)
                    txt = char(string(runObj.updatedAt));
                elseif isprop(runObj, 'createdAt') && ~isempty(runObj.createdAt)
                    txt = char(string(runObj.createdAt));
                end
            catch
                txt = '';
            end
            if isempty(txt)
                return;
            end
            try
                dt = datetime(txt);
                if ~isnat(dt)
                    score = datenum(dt);
                    return;
                end
            catch
            end
            try
                score = datenum(txt);
            catch
            end
        end

        function nodes = normalizeLoadedNodeLayouts(app, nodes) %#ok<INUSD>
            if isempty(nodes)
                return;
            end
            n = numel(nodes);
            cols = nan(1, n);
            rows = nan(1, n);
            for i = 1:n
                if isfield(nodes(i), 'layout') && numel(nodes(i).layout) >= 2 && all(isfinite(double(nodes(i).layout(1:2))))
                    cols(i) = round(double(nodes(i).layout(1)));
                    rows(i) = round(double(nodes(i).layout(2)));
                else
                    cols(i) = i;
                    rows(i) = 1;
                end
            end

            % Older detecdiv-created templates used pixel-like [x y w h]
            % values such as [10 10 20 10]. The graph renderer now expects
            % compact symbolic columns/rows.
            needsCompact = max(cols, [], 'omitnan') > n + 2 || max(rows, [], 'omitnan') > n + 2 || any(cols < 1) || any(rows < 1);
            if ~needsCompact
                return;
            end

            uniqueCols = unique(cols(isfinite(cols)), 'stable');
            uniqueRows = unique(rows(isfinite(rows)), 'stable');
            for i = 1:n
                col = find(uniqueCols == cols(i), 1, 'first');
                row = find(uniqueRows == rows(i), 1, 'first');
                if isempty(col), col = i; end
                if isempty(row), row = 1; end
                nodes(i).layout = [col row 1 1];
            end
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
            ctx.run.control = buildRunControlPolicy(app, ctx.run.executionTarget);
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
            runtimeMasks = runtimeMaskChoices(app);
            if ~isempty(runtimeMasks)
                ctx.masks = runtimeMasks;
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

            if strcmp(ctx.run.executionTarget, 'hub')
                pathReport = hubPathPreflight(app, ctx.hub);
                ctx.hub.pathPreflight = pathReport;
                ctx = applyHubPathPreflightToContext(app, ctx, pathReport);
            end

            ctx.pipelineRef = buildPipelineRef(app);
            ctx.targetRef = buildTargetRef(app);
        end

        function source = inferRuntimeInputSource(app)
            if ~runtimeStartsFromExistingProject(app)
                source = 'pipeline start (dataloader)';
                return;
            end
            source = 'existing project fovs';
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

        function control = buildRunControlPolicy(app, executionTarget) %#ok<INUSD>
            target = lower(char(string(executionTarget)));
            if isempty(target)
                target = 'local';
            end
            control = struct();
            control.backend = target;
            control.cancelPolicy = 'cooperative';
            control.resumePolicy = resumeModeToRunPolicy(app, app.ResumeoptionsDropDown.Value);
            control.progressGranularity = 'roi';
            control.safeStopPoint = 'between_rois';
            switch target
                case 'hub'
                    control.cancelMode = 'hub_job_cancel';
                    control.cancelEndpoint = '/pipeline-runs/{job_id}/cancel';
                    control.statusEndpoint = '/pipeline-runs/{job_id}';
                otherwise
                    control.cancelMode = 'file_token';
                    control.cancelTokenFile = '';
            end
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
                params = stripGlobalRoiPolicyParams(app, nodeId, params);
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

        function params = stripGlobalRoiPolicyParams(app, nodeId, params)
            if ~isstruct(params)
                return;
            end
            idx = find(strcmp({app.Data.nodes.id}, char(string(nodeId))), 1);
            if isempty(idx)
                return;
            end
            nodeType = lower(char(string(getField(app, app.Data.nodes(idx), 'type', ''))));
            if ~any(strcmp(nodeType, {'roipattern','roiidentify','roimanual','roigrid','roitracked','roiextract'}))
                return;
            end
            policyKeys = {'keepExisting','skipExisting','errorOnExisting','openFirstOnly','existingPolicy'};
            for i = 1:numel(policyKeys)
                if isfield(params, policyKeys{i})
                    params = rmfield(params, policyKeys{i});
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
            hub = addUiPathMappingToHub(app, hub);
        end

        function hub = addUiPathMappingToHub(app, hub)
            remoteRoot = strtrim(char(string(getStructText(app, hub, 'defaultRemoteProjectRoot', ''))));
            localRoot = strtrim(char(string(getStructText(app, hub, 'defaultLocalProjectRoot', ''))));
            if isempty(remoteRoot) || isempty(localRoot)
                return;
            end
            try
                hub = detecdiv_hub_upsert_path_mapping(hub, remoteRoot, localRoot);
            catch
                if ~isfield(hub, 'pathMappings') || isempty(hub.pathMappings)
                    hub.pathMappings = struct('remoteRoot', {}, 'localRoot', {});
                end
                hub.pathMappings(end+1).remoteRoot = regexprep(strrep(remoteRoot, '\', '/'), '[\/]+$', '');
                hub.pathMappings(end).localRoot = regexprep(strrep(localRoot, '/', filesep), '[\\\/]+$', '');
            end
        end

        function report = hubPathPreflight(app, hub)
            report = struct('ok', true, 'errors', {{}}, 'warnings', {{}}, ...
                'paths', struct('label', {}, 'localPath', {}, 'remotePath', {}, 'status', {}, 'message', {}));
            checks = collectHubPathChecks(app);
            seen = containers.Map('KeyType', 'char', 'ValueType', 'logical');
            for i = 1:numel(checks)
                localPath = strtrim(char(string(checks(i).path)));
                if isempty(localPath)
                    continue;
                end
                key = lower(strrep(localPath, '/', '\'));
                if isKey(seen, key)
                    continue;
                end
                seen(key) = true;
                [remotePath, ok, message, status] = translateHubPathForServer(app, localPath, hub);
                item = struct('label', checks(i).label, 'localPath', localPath, ...
                    'remotePath', remotePath, 'status', status, 'message', message);
                report.paths(end+1) = item; %#ok<AGROW>
                if ~ok
                    report.ok = false;
                    report.errors{end+1} = sprintf('%s is local-only for Hub: %s. %s', ...
                        checks(i).label, localPath, message); %#ok<AGROW>
                elseif ~isempty(message)
                    report.warnings{end+1} = sprintf('%s: %s', checks(i).label, message); %#ok<AGROW>
                end
            end
        end

        function checks = collectHubPathChecks(app)
            checks = struct('label', {}, 'path', {});
            checks = addHubPathCheck(app, checks, 'Project path', getRuntimeValue(app, 'projectPath'));
            checks = addHubPathCheck(app, checks, 'Raw data path', getRuntimeValue(app, 'rawDataPath'));
            if ~isempty(app.CurrentProject) && isa(app.CurrentProject, 'shallow')
                try
                    if isfield(app.CurrentProject.io, 'path') && isfield(app.CurrentProject.io, 'file') && ...
                            ~isempty(app.CurrentProject.io.path) && ~isempty(app.CurrentProject.io.file)
                        checks = addHubPathCheck(app, checks, 'Project data folder', ...
                            fullfile(char(string(app.CurrentProject.io.path)), char(string(app.CurrentProject.io.file))));
                    end
                catch
                end
                checks = collectProjectFovSourceChecks(app, checks, app.CurrentProject);
            end
        end

        function checks = collectProjectFovSourceChecks(app, checks, shallowObj)
            maxSources = 30;
            sourceCount = 0;
            try
                fovs = shallowObj.fov;
            catch
                return;
            end
            for i = 1:numel(fovs)
                sourceValues = {};
                sourceValues = appendCellTextValues(app, sourceValues, getObjectFieldSafe(app, fovs(i), 'srcpath'));
                sourceValues = appendCellTextValues(app, sourceValues, getObjectFieldSafe(app, fovs(i), 'tiffSource'));
                sourceValues = appendCellTextValues(app, sourceValues, getObjectFieldSafe(app, fovs(i), 'ndtiffPath'));
                sourceValues = appendCellTextValues(app, sourceValues, getObjectFieldSafe(app, fovs(i), 'omeZarrPath'));
                for j = 1:numel(sourceValues)
                    sourceCount = sourceCount + 1;
                    checks = addHubPathCheck(app, checks, sprintf('FOV source %d', i), sourceValues{j}); %#ok<AGROW>
                    if sourceCount >= maxSources
                        return;
                    end
                end
            end
        end

        function value = getObjectFieldSafe(app, obj, fieldName) %#ok<INUSD>
            value = [];
            try
                if isprop(obj, fieldName) || isfield(obj, fieldName)
                    value = obj.(fieldName);
                end
            catch
            end
        end

        function values = appendCellTextValues(app, values, inputValue) %#ok<INUSD>
            if isempty(inputValue)
                return;
            end
            if iscell(inputValue)
                for i = 1:numel(inputValue)
                    values = appendCellTextValues(app, values, inputValue{i}); %#ok<AGROW>
                end
                return;
            end
            if isstring(inputValue)
                for i = 1:numel(inputValue)
                    values{end+1} = char(inputValue(i)); %#ok<AGROW>
                end
                return;
            end
            if ischar(inputValue)
                values{end+1} = inputValue; %#ok<AGROW>
            end
        end

        function checks = addHubPathCheck(app, checks, label, pathValue) %#ok<INUSD>
            pathValue = strtrim(char(string(pathValue)));
            if isempty(pathValue) || strcmpi(pathValue, 'Project source path not resolved')
                return;
            end
            checks(end+1) = struct('label', char(string(label)), 'path', pathValue); %#ok<AGROW>
        end

        function ctx = applyHubPathPreflightToContext(app, ctx, report) %#ok<INUSD>
            if ~isfield(ctx, 'hub') || ~isstruct(ctx.hub)
                ctx.hub = struct();
            end
            for i = 1:numel(report.paths)
                item = report.paths(i);
                if ~strcmp(item.status, 'error') && ~isempty(item.remotePath)
                    label = lower(strrep(item.label, ' ', ''));
                    if strcmp(label, 'rawdatapath')
                        ctx.run.serverRawDataPath = item.remotePath;
                        ctx.io.serverRawDataPath = item.remotePath;
                        ctx.dataLoader.serverPath = item.remotePath;
                    elseif strcmp(label, 'projectpath')
                        ctx.run.serverProjectPath = item.remotePath;
                        ctx.io.serverProjectPath = item.remotePath;
                    elseif strcmp(label, 'projectdatafolder')
                        ctx.run.serverProjectDataFolder = item.remotePath;
                        ctx.io.serverProjectDataFolder = item.remotePath;
                    end
                end
            end
        end

        function [remotePath, ok, message, status] = translateHubPathForServer(app, localPath, hub)
            ok = true;
            message = '';
            status = 'server';
            remotePath = strrep(char(string(localPath)), '\', '/');
            if isempty(strtrim(localPath))
                status = 'empty';
                return;
            end
            if isHubServerPath(app, localPath, hub)
                status = 'server';
                return;
            end
            [mappedPath, mapped] = hubMappedServerPath(app, localPath, hub);
            if mapped
                remotePath = mappedPath;
                status = 'mapped';
                return;
            end
            if isWindowsLocalPath(app, localPath)
                ok = false;
                status = 'error';
                message = 'Set Local root and Remote root so the worker can map this Windows path to the server mount, for example Local root X:/ and Remote root /data.';
                return;
            end
            if ~isAbsoluteServerLikePath(app, localPath)
                ok = false;
                status = 'error';
                message = 'Hub runs need absolute paths visible from the worker, not relative paths.';
                return;
            end
        end

        function tf = isHubServerPath(app, pathValue, hub)
            tf = false;
            pathValue = strrep(char(string(pathValue)), '\', '/');
            if startsWith(pathValue, '/') && ~startsWith(pathValue, '//')
                tf = true;
                return;
            end
            mappings = getHubPathMappings(app, hub);
            for i = 1:numel(mappings)
                remoteRoot = regexprep(strrep(mappings(i).remoteRoot, '\', '/'), '[\/]+$', '');
                if ~isempty(remoteRoot) && hubPathStartsWithRoot(app, pathValue, remoteRoot, false)
                    tf = true;
                    return;
                end
            end
        end

        function tf = isAbsoluteServerLikePath(app, pathValue) %#ok<INUSD>
            pathValue = char(string(pathValue));
            tf = startsWith(pathValue, '/') && ~startsWith(pathValue, '//');
        end

        function tf = isWindowsLocalPath(app, pathValue) %#ok<INUSD>
            pathValue = char(string(pathValue));
            tf = ~isempty(regexp(pathValue, '^[A-Za-z]:[\\/]*', 'once')) || ...
                startsWith(pathValue, '\\') || startsWith(pathValue, '//');
        end

        function [remotePath, mapped] = hubMappedServerPath(app, localPath, hub)
            mapped = false;
            remotePath = strrep(char(string(localPath)), '\', '/');
            localComparable = strrep(char(string(localPath)), '/', '\');
            mappings = getHubPathMappings(app, hub);
            bestLen = -1;
            bestRemote = '';
            bestSuffix = '';
            for i = 1:numel(mappings)
                localRoot = regexprep(strrep(char(string(mappings(i).localRoot)), '/', '\'), '[\\\/]+$', '');
                remoteRoot = regexprep(strrep(char(string(mappings(i).remoteRoot)), '\', '/'), '[\/]+$', '');
                if isempty(localRoot) || isempty(remoteRoot)
                    continue;
                end
                if hubPathStartsWithRoot(app, localComparable, localRoot, true) && numel(localRoot) > bestLen
                    suffix = localComparable(numel(localRoot)+1:end);
                    suffix = strrep(suffix, '\', '/');
                    bestLen = numel(localRoot);
                    bestRemote = remoteRoot;
                    bestSuffix = suffix;
                end
            end
            if bestLen >= 0
                remotePath = [bestRemote bestSuffix];
                mapped = true;
            end
        end

        function tf = hubPathStartsWithRoot(app, pathValue, rootValue, ignoreCase) %#ok<INUSD>
            pathValue = char(string(pathValue));
            rootValue = char(string(rootValue));
            if ignoreCase
                pathCmp = lower(pathValue);
                rootCmp = lower(rootValue);
            else
                pathCmp = pathValue;
                rootCmp = rootValue;
            end
            tf = startsWith(pathCmp, rootCmp);
            if ~tf
                return;
            end
            if numel(pathCmp) == numel(rootCmp)
                return;
            end
            if endsWith(rootCmp, ':')
                return;
            end
            nextChar = pathCmp(numel(rootCmp)+1);
            tf = any(nextChar == ['\' '/']);
        end

        function mappings = getHubPathMappings(app, hub) %#ok<INUSD>
            mappings = struct('remoteRoot', {}, 'localRoot', {});
            try
                if isfield(hub, 'pathMappings') && ~isempty(hub.pathMappings)
                    mappings = hub.pathMappings;
                end
            catch
                mappings = struct('remoteRoot', {}, 'localRoot', {});
            end
        end

        function password = hubPasswordFromUi(app)
            password = '';
            flushHubPasswordControl(app);
            try
                if isstruct(app.HubFieldHandles) && isfield(app.HubFieldHandles, 'password') && ...
                        isvalid(app.HubFieldHandles.password)
                    if isprop(app.HubFieldHandles.password, 'Data')
                        password = char(string(app.HubFieldHandles.password.Data));
                    else
                        password = char(string(app.HubFieldHandles.password.Value));
                    end
                end
            catch
                password = '';
            end
            if isempty(password)
                try
                    if isfield(app.RuntimeValues, 'hubPassword')
                        password = char(string(app.RuntimeValues.hubPassword));
                    end
                catch
                end
            end
        end

        function flushHubPasswordControl(app)
            try
                if isstruct(app.HubFieldHandles) && isfield(app.HubFieldHandles, 'password') && ...
                        isvalid(app.HubFieldHandles.password) && isprop(app.HubFieldHandles.password, 'Data')
                    app.HubFieldHandles.password.Data = struct('command', 'flush', 'nonce', char(string(datetime('now'))));
                    drawnow;
                    pause(0.05);
                    drawnow;
                end
            catch
            end
        end

        function setHubPasswordValue(app, value)
            try
                if isstruct(app.HubFieldHandles) && isfield(app.HubFieldHandles, 'password') && ...
                        isvalid(app.HubFieldHandles.password)
                    if isprop(app.HubFieldHandles.password, 'Data')
                        app.HubFieldHandles.password.Data = char(string(value));
                    else
                        app.HubFieldHandles.password.Value = char(string(value));
                    end
                    app.RuntimeValues.hubPassword = char(string(value));
                end
            catch
            end
        end

        function persistHubSettingsFromUi(app)
            try
                if ~isstruct(app.HubFieldHandles) || isempty(fieldnames(app.HubFieldHandles))
                    return;
                end
                hub = hubSettingsFromUi(app);
                detecdiv_hub_settings_set(hub);
            catch
            end
        end

        function connectHubButtonPushed(app)
            d = openRuntimeProgress(app, 'DetecDiv Hub', 'Connecting to hub...');
            try
                hub = hubSettingsFromUi(app);
                if ~isfield(hub, 'baseUrl') || isempty(strtrim(char(string(hub.baseUrl))))
                    error('pipeline2:HubMissingUrl', 'Hub URL is required.');
                end
                hub = ensureHubSessionFromUi(app, hub);
                hub = requireHubSessionForStatus(app, hub);
                updateRuntimeProgress(app, d, 'Checking hub status...');
                [hubStatus, info] = queryHubStatus(app, hub);
                detecdiv_hub_settings_set(hub);
                applyHubSettingsToUi(app, hub);
                setHubPasswordValue(app, '');
                closeRuntimeProgress(app, d);
                summaryText = formatHubStatusSummary(app, hubStatus);
                app.RuninformationhereLabel.Text = ['Hub connected: ' summaryText];
                appendRunReport(app, 'Hub status: OK', struct('summary', hubStatus.summary));
                try
                    uialert(app.UIFigure, ['Connected to DetecDiv Hub.' newline summaryText newline char(string(info.url))], ...
                        'Hub connection', 'Icon', 'success');
                catch
                end
            catch ME
                closeRuntimeProgress(app, d);
                try
                    uialert(app.UIFigure, ME.message, 'Hub connection failed', 'Icon', 'error');
                catch
                end
            end
            refreshValidationReport(app);
        end

        function [status, info] = queryHubStatus(app, hub)
            [health, info] = detecdiv_hub_request('GET', '/health', [], hub);
            auth = struct();
            targets = struct([]);
            jobs = struct([]);
            targetError = '';
            jobError = '';
            try
                auth = detecdiv_hub_request('GET', '/auth/session', [], hub);
            catch ME
                targetError = ['Authentication unavailable: ' ME.message];
            end
            try
                if isempty(targetError)
                    targets = detecdiv_hub_request('GET', '/execution-targets', [], hub);
                end
            catch ME
                targetError = ME.message;
            end
            try
                jobs = detecdiv_hub_request('GET', '/jobs', [], hub);
            catch ME
                jobError = ME.message;
            end
            worker = summarizeHubWorkers(app, targets);
            queue = summarizeHubJobs(app, jobs);
            summary = struct( ...
                'database', char(string(getField(app, health, 'database_status', 'unknown'))), ...
                'hostname', char(string(getField(app, health, 'hostname', ''))), ...
                'auth_mode', char(string(getField(app, auth, 'auth_mode', 'unknown'))), ...
                'worker_available', worker.availableWorkers, ...
                'worker_active', worker.activeWorkers, ...
                'worker_busy', worker.busyWorkers, ...
                'worker_stale', worker.staleWorkers, ...
                'worker_error', worker.errorWorkers, ...
                'queued_jobs', queue.queued, ...
                'queued_pipeline_runs', queue.queuedPipelineRuns, ...
                'running_jobs', queue.running);
            if ~isempty(targetError)
                summary.execution_targets_error = targetError;
            end
            if ~isempty(jobError)
                summary.jobs_error = jobError;
            end
            status = struct('health', health, 'auth', auth, 'worker', worker, 'queue', queue, ...
                'summary', summary, 'executionTargetsError', targetError, 'jobsError', jobError);
        end

        function worker = summarizeHubWorkers(app, targets)
            worker = struct('targetCount', 0, 'activeWorkers', 0, 'registeredWorkers', 0, ...
                'availableWorkers', 0, 'busyWorkers', 0, 'onlineWorkers', 0, ...
                'staleWorkers', 0, 'errorWorkers', 0, 'capacity', 0, 'details', {{}});
            if isempty(targets)
                return;
            end
            useMatlabOnly = false;
            for i = 1:numel(targets)
                target = localListItem(app, targets, i);
                if isstruct(target) && isfield(target, 'supports_matlab') && logical(target.supports_matlab)
                    useMatlabOnly = true;
                    break;
                end
            end
            for i = 1:numel(targets)
                target = localListItem(app, targets, i);
                if ~isstruct(target)
                    continue;
                end
                if useMatlabOnly && isfield(target, 'supports_matlab') && ~logical(target.supports_matlab)
                    continue;
                end
                metadata = getField(app, target, 'metadata_json', struct());
                wh = getField(app, metadata, 'worker_health_summary', struct());
                if isempty(fieldnamesOrEmpty(app, wh))
                    wh = getField(app, metadata, 'worker_health', struct());
                end
                active = numericField(app, wh, 'worker_count', 0);
                registered = numericField(app, wh, 'registered_workers', active);
                busy = numericField(app, wh, 'busy_workers', 0);
                online = numericField(app, wh, 'online_workers', active);
                stale = numericField(app, wh, 'stale_workers', max(0, registered - active));
                errors = numericField(app, wh, 'error_workers', 0);
                capacity = numericField(app, wh, 'max_concurrent_jobs', 0);
                if capacity <= 0
                    capacity = numericField(app, metadata, 'max_concurrent_jobs', active);
                end
                if capacity <= 0
                    capacity = active;
                end
                available = max(0, capacity - busy);
                worker.targetCount = worker.targetCount + 1;
                worker.activeWorkers = worker.activeWorkers + active;
                worker.registeredWorkers = worker.registeredWorkers + registered;
                worker.availableWorkers = worker.availableWorkers + available;
                worker.busyWorkers = worker.busyWorkers + busy;
                worker.onlineWorkers = worker.onlineWorkers + online;
                worker.staleWorkers = worker.staleWorkers + stale;
                worker.errorWorkers = worker.errorWorkers + errors;
                worker.capacity = worker.capacity + capacity;
                worker.details{end+1} = sprintf('%s: %d/%d available, %d busy, %d stale', ...
                    char(string(getField(app, target, 'display_name', getField(app, target, 'target_key', 'target')))), ...
                    available, capacity, busy, stale); %#ok<AGROW>
            end
        end

        function queue = summarizeHubJobs(app, jobs)
            queue = struct('total', 0, 'queued', 0, 'running', 0, 'cancelling', 0, ...
                'queuedPipelineRuns', 0, 'runningPipelineRuns', 0);
            if isempty(jobs)
                return;
            end
            queue.total = numel(jobs);
            for i = 1:numel(jobs)
                job = localListItem(app, jobs, i);
                if ~isstruct(job)
                    continue;
                end
                st = lower(strtrim(char(string(getField(app, job, 'status', '')))));
                params = getField(app, job, 'params_json', struct());
                kind = lower(strtrim(char(string(getField(app, params, 'job_kind', '')))));
                switch st
                    case 'queued'
                        queue.queued = queue.queued + 1;
                        if strcmp(kind, 'pipeline_run')
                            queue.queuedPipelineRuns = queue.queuedPipelineRuns + 1;
                        end
                    case 'running'
                        queue.running = queue.running + 1;
                        if strcmp(kind, 'pipeline_run')
                            queue.runningPipelineRuns = queue.runningPipelineRuns + 1;
                        end
                    case 'cancelling'
                        queue.cancelling = queue.cancelling + 1;
                end
            end
        end

        function text = formatHubStatusSummary(app, status)
            worker = status.worker;
            queue = status.queue;
            db = char(string(getField(app, status.summary, 'database', 'unknown')));
            authMode = char(string(getField(app, status.summary, 'auth_mode', 'unknown')));
            if isempty(status.executionTargetsError)
                workerText = sprintf('workers %d/%d available (%d active, %d busy, %d stale, %d error)', ...
                    worker.availableWorkers, worker.capacity, worker.activeWorkers, worker.busyWorkers, ...
                    worker.staleWorkers, worker.errorWorkers);
            else
                workerText = ['workers unavailable: ' compactStatusMessage(app, status.executionTargetsError)];
            end
            text = sprintf('DB %s, auth %s, %s, queue %d queued (%d pipeline), %d running', ...
                db, authMode, workerText, queue.queued, queue.queuedPipelineRuns, queue.running);
            if ~isempty(status.jobsError)
                text = [text ', jobs unavailable: ' compactStatusMessage(app, status.jobsError)];
            end
        end

        function msg = compactStatusMessage(app, msg) %#ok<INUSD>
            msg = strtrim(char(string(msg)));
            msg = regexprep(msg, '\s+', ' ');
            maxLen = 160;
            if strlength(string(msg)) > maxLen
                msg = [char(extractBefore(string(msg), maxLen)) '...'];
            end
        end

        function value = localListItem(app, values, idx) %#ok<INUSD>
            if iscell(values)
                value = values{idx};
            else
                value = values(idx);
            end
        end

        function names = fieldnamesOrEmpty(app, value) %#ok<INUSD>
            if isstruct(value)
                names = fieldnames(value);
            else
                names = {};
            end
        end

        function value = numericField(app, S, key, defaultValue)
            value = defaultValue;
            try
                if isstruct(S) && isfield(S, key) && ~isempty(S.(key))
                    value = double(S.(key));
                end
            catch
                value = defaultValue;
            end
        end

        function hub = requireHubSessionForStatus(app, hub)
            if isfield(hub, 'sessionToken') && ~isempty(strtrim(char(string(hub.sessionToken))))
                try
                    detecdiv_hub_request('GET', '/auth/session', [], hub);
                    return;
                catch ME
                    error('pipeline2:HubSessionInvalid', ...
                        ['Hub session token is not valid for status endpoints: ' ME.message ...
                         newline 'Reconnect with your password or paste a valid session token.']);
                end
            end
            error('pipeline2:HubAuthenticationRequired', ...
                ['Hub is reachable, but worker status requires an authenticated session.' newline ...
                 'Enter your password and click Connect, or paste a valid session token.']);
        end

        function hub = ensureHubSessionFromUi(app, hub)
            password = hubPasswordFromUi(app);
            hasToken = isfield(hub, 'sessionToken') && ~isempty(strtrim(char(string(hub.sessionToken))));
            if isempty(strtrim(password)) && ~hasToken
                password = promptHubPassword(app, hub);
            end
            if isempty(strtrim(password))
                return;
            end
            userKey = '';
            if isfield(hub, 'userKey')
                userKey = strtrim(char(string(hub.userKey)));
            end
            if isempty(userKey)
                error('pipeline2:HubMissingUserKey', 'Hub user key is required for password login.');
            end
            [~, hub] = detecdiv_hub_login(userKey, password, hub);
            if isfield(app.HubFieldHandles, 'sessionToken') && isvalid(app.HubFieldHandles.sessionToken) && ...
                    isfield(hub, 'sessionToken')
                app.HubFieldHandles.sessionToken.Value = char(string(hub.sessionToken));
            end
            setHubPasswordValue(app, '');
        end

        function password = promptHubPassword(app, hub)
            password = '';
            userKey = '';
            try
                if isfield(hub, 'userKey')
                    userKey = strtrim(char(string(hub.userKey)));
                end
            catch
                userKey = '';
            end
            try
                import javax.swing.*
                panel = javaObjectEDT('javax.swing.JPanel');
                panel.setLayout(javaObjectEDT('java.awt.GridLayout', 0, 1));
                label = javaObjectEDT('javax.swing.JLabel', ['Password for Hub user ' userKey ':']);
                field = javaObjectEDT('javax.swing.JPasswordField', 24);
                panel.add(label);
                panel.add(field);
                option = JOptionPane.showConfirmDialog([], panel, 'DetecDiv Hub login', ...
                    JOptionPane.OK_CANCEL_OPTION, JOptionPane.PLAIN_MESSAGE);
                if option == JOptionPane.OK_OPTION
                    password = char(field.getPassword())';
                end
            catch
                try
                    answer = inputdlg({['Password for Hub user ' userKey ':']}, 'DetecDiv Hub login', 1, {''});
                    if ~isempty(answer)
                        password = char(string(answer{1}));
                    end
                catch
                    password = '';
                end
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
                    ids = {};
                    for ii = 1:numel(app.Data.nodes)
                        ids{end+1} = char(string(app.Data.nodes(ii).id)); %#ok<AGROW>
                    end
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
                    nodeId = char(string(data{i,2}));
                    ids{end+1} = nodeId; %#ok<AGROW>
                end
            end
        end

        function tf = runtimeRunSelectionAllowsNode(app, nodeId)
            tf = true;
        end

        function enableRawPrepNodesInRunTable(app)
            data = app.UISelectedModuleTable.Data;
            if isempty(data)
                return;
            end
            for i = 1:size(data, 1)
                nodeId = char(string(data{i,2}));
                idx = find(strcmp({app.Data.nodes.id}, nodeId), 1);
                if isempty(idx)
                    continue;
                end
                if isRawPrepNode(app, app.Data.nodes(idx))
                    data{i,1} = true;
                end
            end
            app.UISelectedModuleTable.Data = data;
        end

        function disableRawPrepNodesInRunTable(app)
            data = app.UISelectedModuleTable.Data;
            if isempty(data)
                return;
            end
            for i = 1:size(data, 1)
                nodeId = char(string(data{i,2}));
                idx = find(strcmp({app.Data.nodes.id}, nodeId), 1);
                if isempty(idx)
                    continue;
                end
                if isRawPrepNode(app, app.Data.nodes(idx))
                    data{i,1} = false;
                end
            end
            app.UISelectedModuleTable.Data = data;
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
                ref.id = currentPipelineName(app);
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

        function [ok, runJsonPath] = saveCurrentRunSnapshotIfProjectAvailable(app)
            ok = false;
            runJsonPath = '';
            if isempty(app.CurrentProject) || ~isa(app.CurrentProject, 'shallow') || isempty(app.CurrentPipelinePath)
                return;
            end
            try
                ctx = buildRunContext(app);
                runObj = createOrUpdateCurrentRun(app, ctx, 'preflight');
                logRunEvent(app, runObj, 'Run parameters saved with pipeline template.', 'pipeline2');
                pipelineRunSave(runObj);
                shallowSave(app.CurrentProject, 'shallowObj');
                runJsonPath = fullfile(runObj.path, 'run.json');
                ok = true;
            catch ME
                try
                    app.PipelineandRuncheckreportLabel.Text = [app.PipelineandRuncheckreportLabel.Text newline newline ...
                        'Run snapshot save failed:' newline ME.message];
                catch
                end
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

        function ctx = attachRunCancellationAndProgress(app, ctx, runObj, progressDlg) %#ok<INUSD>
            tokenFile = '';
            try
                [runPath, ~] = runObj.getPath;
                if ~isempty(runPath)
                    if exist(runPath, 'dir') ~= 7
                        mkdir(runPath);
                    end
                    tokenFile = fullfile(runPath, 'cancel.request');
                    if exist(tokenFile, 'file') == 2
                        delete(tokenFile);
                    end
                end
            catch
                tokenFile = '';
            end
            ctx.cancel = struct('tokenFile', tokenFile);
            try
                if isfield(ctx,'run') && isstruct(ctx.run) && isfield(ctx.run,'control') && isstruct(ctx.run.control)
                    ctx.run.control.backend = 'local';
                    ctx.run.control.cancelMode = 'file_token';
                    ctx.run.control.cancelTokenFile = tokenFile;
                end
            catch
            end
            ctx.progress = struct('startedAt', char(datetime('now')), 'value', 0, 'message', 'Run queued');
            if nargin >= 4 && ~isempty(progressDlg)
                ctx.progressDlg = progressDlg;
            end
        end

        function ctx = stripTransientRunContext(app, ctx) %#ok<INUSD>
            if ~isstruct(ctx)
                return;
            end
            if isfield(ctx, 'progressDlg')
                ctx = rmfield(ctx, 'progressDlg');
            end
            try
                if isfield(ctx,'progress') && isstruct(ctx.progress)
                    if isfield(ctx.progress,'startedTic')
                        ctx.progress = rmfield(ctx.progress, 'startedTic');
                    end
                    if isfield(ctx.progress,'nodeStartTic')
                        ctx.progress = rmfield(ctx.progress, 'nodeStartTic');
                    end
                end
            catch
            end
            try
                if isfield(ctx,'store') && isstruct(ctx.store) && isfield(ctx.store,'classifierRuntime')
                    ctx.store = rmfield(ctx.store, 'classifierRuntime');
                end
            catch
            end
        end

        function tf = isPipelineCancelException(app, ME) %#ok<INUSD>
            tf = false;
            try
                ids = string(ME.identifier);
                for iCause = 1:numel(ME.cause)
                    ids(end+1) = string(ME.cause{iCause}.identifier); %#ok<AGROW>
                end
                tf = any(strcmp(ids, "runPipeline:Cancelled")) || contains(string(ME.message), "cancelled by user", 'IgnoreCase', true);
            catch
                tf = strcmp(ME.identifier, 'runPipeline:Cancelled');
            end
        end

        function runObj = annotateHubRunControl(app, runObj, job) %#ok<INUSD>
            try
                if ~isstruct(runObj.ctx)
                    runObj.ctx = struct();
                end
                if ~isfield(runObj.ctx,'run') || ~isstruct(runObj.ctx.run)
                    runObj.ctx.run = struct();
                end
                if ~isfield(runObj.ctx.run,'control') || ~isstruct(runObj.ctx.run.control)
                    runObj.ctx.run.control = struct();
                end
                runObj.ctx.run.control.backend = 'hub';
                runObj.ctx.run.control.cancelPolicy = 'cooperative';
                runObj.ctx.run.control.cancelMode = 'hub_job_cancel';
                runObj.ctx.run.control.progressGranularity = 'roi';
                runObj.ctx.run.control.safeStopPoint = 'between_rois';
                runObj.ctx.run.control.cancelEndpoint = '/pipeline-runs/{job_id}/cancel';
                runObj.ctx.run.control.statusEndpoint = '/pipeline-runs/{job_id}';
                if isstruct(job) && isfield(job,'id') && ~isempty(job.id)
                    runObj.ctx.run.control.jobId = char(string(job.id));
                end
            catch
            end
        end

        function loadRunIntoUi(app, runObj, refreshUi)
            if nargin < 3 || isempty(refreshUi)
                refreshUi = true;
            end
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
                    if isfield(ctx.run, 'gpuPolicy') && ~isempty(ctx.run.gpuPolicy)
                        gpuPolicy = char(string(ctx.run.gpuPolicy));
                        if strcmpi(gpuPolicy, 'module_default')
                            gpuPolicy = 'auto';
                        end
                        if any(strcmp(app.ExecutionDropDown.ItemsData, gpuPolicy))
                            app.ExecutionDropDown.Value = gpuPolicy;
                        elseif any(strcmp(app.ExecutionDropDown.Items, gpuPolicy))
                            app.ExecutionDropDown.Value = gpuPolicy;
                        end
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
            if isempty(app.CurrentProject) && ~isempty(runObj.projectPath)
                bindProjectFromPath(app, [runObj.projectPath '.mat'], false);
            end
            if logical(refreshUi)
                refreshModuleTabs(app);
                refreshValidationReport(app);
            end
            try
                if strcmpi(char(string(runObj.status)), 'cancelled')
                    app.RunButton.Text = 'Resume run';
                else
                    app.RunButton.Text = 'Run !';
                end
            catch
                app.RunButton.Text = 'Run !';
            end
        end

        function params = uiRuntimeNodeParamsFromRun(app, runNodeParams)
            params = struct();
            if ~isstruct(runNodeParams)
                return;
            end
            if numel(runNodeParams) > 1 || (isfield(runNodeParams, 'id') && isfield(runNodeParams, 'params'))
                for i = 1:numel(runNodeParams)
                    if ~isfield(runNodeParams(i), 'id') || isempty(runNodeParams(i).id) || ...
                            ~isfield(runNodeParams(i), 'params') || ~isstruct(runNodeParams(i).params)
                        continue;
                    end
                    nodeId = char(string(runNodeParams(i).id));
                    params.(runtimeNodeKey(app, nodeId)) = runNodeParams(i).params;
                end
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
                nodeId = char(string(data{i,2}));
                data{i,1} = any(strcmp(selectedNodes, nodeId)) && runtimeRunSelectionAllowsNode(app, nodeId);
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

        function reportFile = writeSmokeTestReport(app, runObj, smokeInfo, dryReport, runReport, ME)
            reportFile = '';
            if nargin < 6
                ME = [];
            end
            if isempty(runObj) || ~isa(runObj, 'pipelineRun')
                return;
            end
            try
                [runPath, ~] = runObj.getPath;
                if isempty(runPath)
                    return;
                end
                if exist(runPath, 'dir') ~= 7
                    mkdir(runPath);
                end
                reportFile = fullfile(runPath, 'smoke_report.txt');

                lines = {};
                lines{end+1} = 'Pipeline smoke test report'; %#ok<AGROW>
                lines{end+1} = ['Generated: ' char(datetime('now'))]; %#ok<AGROW>
                lines{end+1} = ['Status: ' char(string(runObj.status))]; %#ok<AGROW>
                lines{end+1} = ['Run ID: ' char(string(runObj.runId))]; %#ok<AGROW>
                lines{end+1} = ['Run folder: ' runPath]; %#ok<AGROW>
                lines{end+1} = ['Run JSON: ' fullfile(runPath, 'run.json')]; %#ok<AGROW>
                lines{end+1} = '';

                lines{end+1} = 'Scope'; %#ok<AGROW>
                lines{end+1} = ['- Pipeline: ' smokeFieldText(app, runObj.pipelineRef, 'id', currentPipelineName(app))]; %#ok<AGROW>
                lines{end+1} = ['- Pipeline path: ' smokeFieldText(app, runObj.pipelineRef, 'path', app.CurrentPipelinePath)]; %#ok<AGROW>
                lines{end+1} = ['- Project: ' char(string(runObj.projectPath))]; %#ok<AGROW>
                if isstruct(smokeInfo) && isfield(smokeInfo, 'label') && ~isempty(smokeInfo.label)
                    lines{end+1} = ['- Test ROI: ' char(string(smokeInfo.label))]; %#ok<AGROW>
                end
                if isstruct(smokeInfo) && isfield(smokeInfo, 'fovIndex')
                    lines{end+1} = ['- FOV index: ' smokeValueText(app, smokeInfo.fovIndex)]; %#ok<AGROW>
                end
                if isstruct(smokeInfo) && isfield(smokeInfo, 'roiIndex')
                    lines{end+1} = ['- ROI index: ' smokeValueText(app, smokeInfo.roiIndex)]; %#ok<AGROW>
                end
                if isstruct(smokeInfo) && isfield(smokeInfo, 'roiId')
                    lines{end+1} = ['- ROI id: ' char(string(smokeInfo.roiId))]; %#ok<AGROW>
                end
                lines{end+1} = '- Output persistence: memory only, no ROI/H5/dataseries save'; %#ok<AGROW>
                lines{end+1} = '';

                ctx = struct();
                try
                    ctx = runObj.ctx;
                catch
                end
                if isstruct(ctx)
                    lines{end+1} = 'Runtime'; %#ok<AGROW>
                    if isfield(ctx, 'run') && isstruct(ctx.run)
                        lines{end+1} = ['- Selected nodes: ' smokeValueText(app, getField(app, ctx.run, 'selectedNodes', {}))]; %#ok<AGROW>
                        lines{end+1} = ['- Run policy: ' smokeValueText(app, getField(app, ctx.run, 'runPolicy', ''))]; %#ok<AGROW>
                        lines{end+1} = ['- Execution target: ' smokeValueText(app, getField(app, ctx.run, 'executionTarget', 'local'))]; %#ok<AGROW>
                    end
                    if isfield(ctx, 'io') && isstruct(ctx.io)
                        lines{end+1} = ['- Existing output policy: ' smokeValueText(app, getField(app, ctx.io, 'existingPolicy', ''))]; %#ok<AGROW>
                        lines{end+1} = ['- persistOutputs: ' smokeValueText(app, getField(app, ctx.io, 'persistOutputs', false))]; %#ok<AGROW>
                        lines{end+1} = ['- saveMode: ' smokeValueText(app, getField(app, ctx.io, 'saveMode', 'defer'))]; %#ok<AGROW>
                    end
                    lines{end+1} = '';
                end

                lines = [lines formatSmokeReportBlock(app, 'Dry-run', dryReport)]; %#ok<AGROW>
                lines{end+1} = ''; %#ok<AGROW>
                lines = [lines formatSmokeReportBlock(app, 'Execution', runReport)]; %#ok<AGROW>

                if ~isempty(ME)
                    lines{end+1} = ''; %#ok<AGROW>
                    lines{end+1} = 'Error'; %#ok<AGROW>
                    lines{end+1} = ['- Identifier: ' char(string(ME.identifier))]; %#ok<AGROW>
                    lines{end+1} = ['- Message: ' char(string(ME.message))]; %#ok<AGROW>
                    try
                        if ~isempty(ME.stack)
                            top = ME.stack(1);
                            lines{end+1} = sprintf('- Location: %s:%d', char(string(top.name)), top.line); %#ok<AGROW>
                        end
                    catch
                    end
                end

                fid = fopen(reportFile, 'w');
                if fid < 0
                    error('pipeline2:SmokeReportWrite', 'Cannot write %s.', reportFile);
                end
                cleaner = onCleanup(@()fclose(fid)); %#ok<NASGU>
                fwrite(fid, [strjoin(lines, newline) newline], 'char');
                logRunEvent(app, runObj, ['Smoke report written: ' reportFile], 'pipeline2');
            catch MEwrite
                try
                    warning('pipeline2:SmokeReportWrite', 'Unable to write smoke report: %s', MEwrite.message);
                catch
                end
            end
        end

        function lines = formatSmokeReportBlock(app, titleText, report)
            lines = {char(string(titleText))};
            if ~isstruct(report) || isempty(fieldnames(report))
                lines{end+1} = '- Not available'; %#ok<AGROW>
                return;
            end
            if isfield(report, 'summary') && isstruct(report.summary) && ~isempty(fieldnames(report.summary))
                lines{end+1} = ['- Summary: ' smokeValueText(app, report.summary)]; %#ok<AGROW>
            end
            if isfield(report, 'order') && ~isempty(report.order)
                lines{end+1} = ['- Order: ' strjoin(cellstr(string(report.order)), ' -> ')]; %#ok<AGROW>
            end
            if isfield(report, 'nodeRuns') && isstruct(report.nodeRuns) && ~isempty(report.nodeRuns)
                lines{end+1} = '- Nodes:'; %#ok<AGROW>
                for i = 1:numel(report.nodeRuns)
                    row = report.nodeRuns(i);
                    nodeId = smokeFieldText(app, row, 'nodeId', '');
                    nodeType = smokeFieldText(app, row, 'nodeType', '');
                    status = smokeFieldText(app, row, 'status', '');
                    duration = smokeValueText(app, getField(app, row, 'durationSec', 0));
                    msg = smokeFieldText(app, row, 'message', '');
                    line = sprintf('  - %s [%s] status=%s duration=%ss', nodeId, nodeType, status, duration);
                    if ~isempty(strtrim(msg))
                        line = [line ' message=' msg];
                    end
                    lines{end+1} = line; %#ok<AGROW>
                end
            end
            if isfield(report, 'errors') && ~isempty(report.errors)
                lines{end+1} = ['- Errors: ' strjoin(cellstr(string(report.errors)), ' | ')]; %#ok<AGROW>
            end
            if isfield(report, 'warnings') && ~isempty(report.warnings)
                lines{end+1} = ['- Warnings: ' strjoin(cellstr(string(report.warnings)), ' | ')]; %#ok<AGROW>
            end
        end

        function txt = smokeFieldText(app, S, fieldName, defaultValue)
            txt = smokeValueText(app, getField(app, S, fieldName, defaultValue));
        end

        function txt = smokeValueText(app, value) %#ok<INUSD>
            if isempty(value)
                txt = '';
                return;
            end
            try
                if ischar(value)
                    txt = value;
                elseif isstring(value)
                    txt = char(strjoin(value(:)', ', '));
                elseif isnumeric(value) || islogical(value)
                    txt = mat2str(value);
                elseif iscell(value)
                    txt = char(strjoin(string(value(:)'), ', '));
                elseif isstruct(value)
                    txt = jsonencode(value);
                else
                    txt = char(string(value));
                end
            catch
                txt = '<unprintable>';
            end
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

        function SmokeTestButtonPushed(app, event) %#ok<INUSD>
            oldText = app.SmokeTestButton.Text;
            app.SmokeTestButton.Text = 'Smoke running...';
            app.SmokeTestButton.Enable = 'off';
            cleanupObj = onCleanup(@()restoreSmokeTestButton(app, oldText)); %#ok<NASGU>
            drawnow;

            runObj = [];
            d = [];
            smokeInfo = struct();
            dryReport = struct();
            report = struct();
            try
                if ~ensurePipelineSavedForRun(app)
                    return;
                end
                if ~ensureCurrentProjectForRun(app)
                    return;
                end

                [okTemplate, reportTemplate] = refreshValidationReportWithOutput(app);
                runtimeIssues = validateRuntimeInputs(app);
                blockingRuntimeIssues = runtimeIssues(~contains(string(runtimeIssues), "unusual"));
                if ~okTemplate
                    app.PipelineandRuncheckreportLabel.Text = formatValidationReport(app, okTemplate, reportTemplate);
                    uialert(app.UIFigure, 'Pipeline template is not valid. Fix blocking issues before smoke test.', ...
                        'Smoke test', 'Icon', 'error');
                    return;
                end
                if ~isempty(blockingRuntimeIssues)
                    CheckpipelineButtonPushed(app, []);
                    uialert(app.UIFigure, strjoin(blockingRuntimeIssues, newline), 'Runtime inputs', 'Icon', 'error');
                    return;
                end

                ctx = buildRunContext(app);
                [ctxSmoke, smokeInfo] = buildSmokeRunContext(app, ctx);
                pipeObj = buildExecutablePipelineObject(app, app.CurrentPipelinePath, ctxSmoke);
                app.CurrentPipeline = pipeObj;
                assignCurrentPipelineToWorkspace(app, pipeObj);

                runObj = createSmokePipelineRun(app, ctxSmoke, smokeInfo, 'preflight');
                logRunEvent(app, runObj, ['Smoke test requested: ' smokeInfo.label], 'pipeline2');
                pipelineRunSave(runObj);
                shallowSave(app.CurrentProject, 'shallowObj');

                try
                    d = uiprogressdlg(app.UIFigure, 'Title', 'Pipeline smoke test', ...
                        'Message', ['Preparing single-ROI smoke test: ' smokeInfo.label], ...
                        'Indeterminate', 'on', 'Cancelable', 'on');
                    try
                        if isprop(d, 'CancelText')
                            d.CancelText = 'Stop smoke test';
                        end
                    catch
                    end
                catch
                    d = [];
                end

                if ~isempty(d), d.Message = 'Dry-run validation...'; end
                ctxDry = ctxSmoke;
                ctxDry.dryRun = true;
                [~, dryReport] = runPipeline(pipeObj, ctxDry);
                runObj.outputs.dryRunReport = dryReport;
                runObj.status = 'dry_run_ok';
                runObj.ctx = ctxDry;
                logRunEvent(app, runObj, 'Smoke dry-run validation completed.', 'pipeline2');
                pipelineRunSave(runObj);
                appendRunReport(app, ['Smoke dry-run OK: ' smokeInfo.label], dryReport);

                if ~isempty(d), d.Message = ['Running local smoke test: ' smokeInfo.label]; end
                ctxRun = ctxSmoke;
                ctxRun.dryRun = false;
                ctxRun = attachRunCancellationAndProgress(app, ctxRun, runObj, d);
                runObj.status = 'running';
                runObj.ctx = stripTransientRunContext(app, ctxRun);
                logRunEvent(app, runObj, 'Local smoke test started.', 'pipeline2');
                pipelineRunSave(runObj);

                [ctxOut, report] = runPipeline(pipeObj, ctxRun);
                runObj.ctx = stripTransientRunContext(app, ctxOut);
                runObj.outputs.report = report;
                runObj.outputs.smokeTest = smokeInfo;
                runObj.status = 'done';
                runObj.progress = getField(app, report, 'summary', struct());
                logRunEvent(app, runObj, 'Local smoke test completed.', 'pipeline2');
                smokeReportFile = writeSmokeTestReport(app, runObj, smokeInfo, dryReport, report, []);
                runObj.outputs.smokeReportFile = smokeReportFile;
                pipelineRunSave(runObj);
                clearRuntimeDataSeriesCache(app);
                updateRuntimeResourceInventory(app);
                appendRunReport(app, ['Smoke test OK: ' smokeInfo.label], report);
                app.RuninformationhereLabel.Text = ['Smoke test done: ' smokeReportFile];
            catch ME
                fullReport = printExceptionToConsole(app, 'Pipeline smoke test failed', ME);
                try
                    if exist('runObj', 'var') && ~isempty(runObj)
                        if isPipelineCancelException(app, ME)
                            runObj.status = 'cancelled';
                        else
                            runObj.status = 'failed';
                        end
                        runObj.outputs.error = struct('identifier', ME.identifier, ...
                            'message', ME.message, 'report', fullReport);
                        try
                            runObj.ctx = stripTransientRunContext(app, ctxRun);
                        catch
                            try
                                runObj.ctx = ctxSmoke;
                            catch
                            end
                        end
                        if isPipelineCancelException(app, ME)
                            logRunEvent(app, runObj, ['Smoke test cancelled: ' ME.message], 'pipeline2');
                        else
                            logRunEvent(app, runObj, ['Smoke test failed: ' ME.message], 'pipeline2');
                        end
                        smokeReportFile = writeSmokeTestReport(app, runObj, smokeInfo, dryReport, report, ME);
                        runObj.outputs.smokeReportFile = smokeReportFile;
                        pipelineRunSave(runObj);
                    end
                catch
                end
                app.PipelineandRuncheckreportLabel.Text = [app.PipelineandRuncheckreportLabel.Text newline newline ...
                    'Smoke test failed:' newline ME.identifier newline ME.message newline newline ...
                    getReport(ME, 'basic', 'hyperlinks', 'off')];
                if isPipelineCancelException(app, ME)
                    uialert(app.UIFigure, 'Smoke test stopped. Existing outputs and run log were kept.', ...
                        'Smoke test stopped', 'Icon', 'warning');
                else
                    uialert(app.UIFigure, ME.message, 'Smoke test failed', 'Icon', 'error');
                end
            end
            try, close(d); catch, end
        end

        function restoreSmokeTestButton(app, oldText)
            try
                if ~isempty(app.SmokeTestButton) && isvalid(app.SmokeTestButton)
                    app.SmokeTestButton.Text = oldText;
                    app.SmokeTestButton.Enable = 'on';
                end
            catch
            end
        end

        function [ctxSmoke, smokeInfo] = buildSmokeRunContext(app, ctx)
            [roiObj, smokeInfo] = resolveSmokeTestRoi(app);
            if isempty(roiObj)
                error('pipeline2:SmokeNoROI', ...
                    'Smoke test requires at least one existing ROI in the selected FOV/ROI runtime scope.');
            end

            ctxSmoke = ctx;
            ctxSmoke.allowGUI = false;
            ctxSmoke.interactive = false;
            ctxSmoke.dryRun = false;
            ctxSmoke.saveProgress = false;
            ctxSmoke.runId = uniqueSmokeRunId(app);
            ctxSmoke.resume = false;

            if ~isfield(ctxSmoke, 'run') || ~isstruct(ctxSmoke.run)
                ctxSmoke.run = struct();
            end
            ctxSmoke.run.runPolicy = 'restart';
            ctxSmoke.run.resume = false;
            ctxSmoke.run.executionTarget = 'local';
            ctxSmoke.run.control = buildRunControlPolicy(app, 'local');
            ctxSmoke.run.control.resumePolicy = 'restart';
            ctxSmoke.run.smokeTest = smokeInfo;
            ctxSmoke.run.rois = [];
            ctxSmoke.run.fovIndex = smokeInfo.fovIndex;
            if ~isfield(ctxSmoke.run, 'nodeParams') || ~isstruct(ctxSmoke.run.nodeParams)
                ctxSmoke.run.nodeParams = struct();
            end

            if isfield(ctxSmoke, 'hub')
                ctxSmoke = rmfield(ctxSmoke, 'hub');
            end
            if ~isfield(ctxSmoke, 'sel') || ~isstruct(ctxSmoke.sel)
                ctxSmoke.sel = struct();
            end
            ctxSmoke.sel.fovs = smokeInfo.fovIndex;
            ctxSmoke.sel.rois = [];
            ctxSmoke.fovIndex = smokeInfo.fovIndex;
            ctxSmoke.fovList = app.CurrentProject.fov(smokeInfo.fovIndex);
            ctxSmoke.roiList = roiObj;
            ctxSmoke.rois = roiObj;
            ctxSmoke.smokeTest = smokeInfo;

            if ~isfield(ctxSmoke, 'io') || ~isstruct(ctxSmoke.io)
                ctxSmoke.io = struct();
            end
            ctxSmoke.io.persistOutputs = false;
            ctxSmoke.io.saveMode = 'defer';
            ctxSmoke.io.deferredSave = true;
            ctxSmoke.io.cachePolicy = 'memory';
            if ~isfield(ctxSmoke, 'store') || ~isstruct(ctxSmoke.store)
                ctxSmoke.store = struct();
            end
            ctxSmoke.store.cacheMode = 'memory';
            ctxSmoke.run.nodeParams = addSmokeNodeParamOverrides(app, ctxSmoke.run.nodeParams, smokeInfo);
        end

        function [roiObj, info] = resolveSmokeTestRoi(app)
            roiObj = [];
            info = struct('enabled', true, 'scope', 'single_roi', ...
                'fovIndex', [], 'roiIndex', [], 'roiId', '', 'label', '', ...
                'createdAt', char(datetime('now')));
            if isempty(app.CurrentProject) || ~isa(app.CurrentProject, 'shallow')
                return;
            end
            try
                fovIdx = parseIndexSelection(app, getRuntimeValue(app, 'fovs'));
                if isempty(fovIdx)
                    fovIdx = 1:numel(app.CurrentProject.fov);
                end
                fovIdx = fovIdx(fovIdx >= 1 & fovIdx <= numel(app.CurrentProject.fov));
                roiSel = parseLooseSelection(app, getRuntimeValue(app, 'rois'));
                for i = 1:numel(fovIdx)
                    f = app.CurrentProject.fov(fovIdx(i));
                    if isempty(f.roi)
                        continue;
                    end
                    roiIdx = smokeCandidateRoiIndices(app, f.roi, roiSel);
                    if isempty(roiIdx)
                        continue;
                    end
                    roiObj = f.roi(roiIdx(1));
                    info.fovIndex = fovIdx(i);
                    info.roiIndex = roiIdx(1);
                    info.roiId = safeRoiLabel(app, roiObj, roiIdx(1));
                    info.label = sprintf('FOV %d, ROI %d (%s)', info.fovIndex, info.roiIndex, info.roiId);
                    return;
                end
            catch
                roiObj = [];
            end
        end

        function idx = smokeCandidateRoiIndices(app, rois, roiSel)
            idx = [];
            if isempty(rois)
                return;
            end
            if isempty(roiSel)
                idx = 1:numel(rois);
            elseif isnumeric(roiSel)
                idx = round(double(roiSel(:)'));
                idx = idx(isfinite(idx) & idx >= 1 & idx <= numel(rois));
            else
                wanted = cellstr(string(roiSel(:)));
                ids = cell(1, numel(rois));
                for i = 1:numel(rois)
                    ids{i} = safeRoiLabel(app, rois(i), i);
                end
                for i = 1:numel(wanted)
                    match = find(strcmp(ids, wanted{i}), 1);
                    if ~isempty(match)
                        idx(end+1) = match; %#ok<AGROW>
                    end
                end
            end
            idx = unique(idx, 'stable');
        end

        function label = safeRoiLabel(app, roiObj, fallbackIndex) %#ok<INUSD>
            label = '';
            try
                if isprop(roiObj, 'id') && ~isempty(roiObj.id)
                    label = char(string(roiObj.id));
                end
            catch
                label = '';
            end
            if isempty(strtrim(label))
                label = sprintf('#%d', fallbackIndex);
            end
        end

        function nodeParams = addSmokeNodeParamOverrides(app, nodeParams, smokeInfo)
            if ~isstruct(nodeParams) || isempty(nodeParams)
                nodeParams = struct();
            end
            activeIds = selectedRunNodeIds(app);
            for i = 1:numel(app.Data.nodes)
                node = app.Data.nodes(i);
                nodeId = char(string(getField(app, node, 'id', '')));
                if isempty(nodeId) || (~isempty(activeIds) && ~any(strcmp(activeIds, nodeId)))
                    continue;
                end
                nodeType = lower(char(string(getField(app, node, 'type', ''))));
                patch = struct();
                if any(strcmp(nodeType, {'roiidentify','roipattern','roimanual','roigrid','roitracked','roiextract'}))
                    patch.fovIndex = smokeInfo.fovIndex;
                end
                if any(strcmp(nodeType, {'roiextract','processor','classifier'}))
                    patch.roiList = smokeInfo.roiIndex;
                    if any(strcmp(nodeType, {'processor','classifier'}))
                        patch.roiList = 1;
                    end
                end
                if isempty(fieldnames(patch))
                    continue;
                end
                key = matlab.lang.makeValidName(nodeId);
                if ~isfield(nodeParams, key) || ~isstruct(nodeParams.(key))
                    nodeParams.(key) = struct();
                end
                nodeParams.(key) = mergeStructOverride(app, nodeParams.(key), patch);
            end
        end

        function runId = uniqueSmokeRunId(app)
            base = [matlab.lang.makeValidName(currentPipelineName(app)) '_smoke_' datestr(now, 'yyyymmdd_HHMMSS')];
            runId = base;
            try
                existing = app.CurrentProject.processing.pipelineRun;
                names = {};
                if ~isempty(existing)
                    names = arrayfun(@(p) char(string(p.runId)), existing, 'UniformOutput', false);
                end
                n = 1;
                while any(strcmp(names, runId))
                    n = n + 1;
                    runId = sprintf('%s_%d', base, n);
                end
            catch
            end
        end

        function runObj = createSmokePipelineRun(app, ctx, smokeInfo, status)
            ref = buildPipelineRef(app);
            target = buildTargetRef(app);
            target.fovIds = smokeInfo.fovIndex;
            target.roiIds = {smokeInfo.roiId};
            target.notes = ['Smoke test: ' smokeInfo.label];
            runObj = pipelineRunNew(app.CurrentProject, ref.id, ref.path, ...
                'runId', ctx.runId, 'ctx', ctx, 'status', status, ...
                'pipelineRef', ref, 'targetRef', target, ...
                'description', ['Single-ROI smoke test: ' smokeInfo.label]);
        end

        function RunButtonPushed(app, event) %#ok<INUSD>
            app.RunButton.Text = 'Run !';
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
                    'Message', 'Saving preflight run...', 'Indeterminate', 'on', ...
                    'Cancelable', 'on');
                try
                    if isprop(d, 'CancelText')
                        d.CancelText = 'Stop run';
                    end
                catch
                end
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
                    hub = ensureHubSessionFromUi(app, hub);
                    pathReport = hubPathPreflight(app, hub);
                    if ~pathReport.ok
                        runObj.status = 'failed';
                        runObj.outputs.hubPathPreflight = pathReport;
                        logRunEvent(app, runObj, ['Run blocked by Hub path preflight: ' strjoin(pathReport.errors, ' | ')], 'pipeline2');
                        pipelineRunSave(runObj);
                        error('pipeline2:HubPathPreflightFailed', '%s', strjoin(pathReport.errors, newline));
                    end
                    try
                        detecdiv_hub_settings_set(hub);
                    catch
                    end
                    runObj.ctx = ctx;
                    runObj.ctx.hub = hub;
                    runObj.ctx.hub.pathPreflight = pathReport;
                    runObj.ctx = applyHubPathPreflightToContext(app, runObj.ctx, pathReport);
                    logRunEvent(app, runObj, 'Submitting run to DetecDiv Hub.', 'pipeline2');
                    pipelineRunSave(runObj);
                    [job, runObj] = detecdiv_hub_submit_pipeline_run(runObj, app.CurrentProject, 'hub', hub);
                    runObj = annotateHubRunControl(app, runObj, job);
                    logRunEvent(app, runObj, 'Hub submission completed.', 'pipeline2');
                    pipelineRunSave(runObj);
                    shallowSave(app.CurrentProject, 'shallowObj');
                    clearRuntimeDataSeriesCache(app);
                    updateRuntimeResourceInventory(app);
                    appendRunReport(app, ['Hub submit: ' char(string(getField(app, job, 'status', 'submitted')))], job);
                    app.RuninformationhereLabel.Text = ['Hub run submitted: ' fullfile(runObj.path, 'run.json')];
                else
                    if ~isempty(d), d.Message = 'Running local MATLAB pipeline...'; end
                    ctxRun = ctx;
                    ctxRun.dryRun = false;
                    ctxRun = attachRunCancellationAndProgress(app, ctxRun, runObj, d);
                    runObj.status = 'running';
                    runObj.ctx = stripTransientRunContext(app, ctxRun);
                    logRunEvent(app, runObj, 'Local MATLAB run started.', 'pipeline2');
                    pipelineRunSave(runObj);
                    [ctxOut, report] = runPipeline(pipeObj, ctxRun);
                    runObj.ctx = stripTransientRunContext(app, ctxOut);
                    runObj.outputs.report = report;
                    runObj.status = 'done';
                    runObj.progress = getField(app, report, 'summary', struct());
                    logRunEvent(app, runObj, 'Local MATLAB run completed.', 'pipeline2');
                    pipelineRunSave(runObj);
                    shallowSave(app.CurrentProject, 'shallowObj');
                    clearRuntimeDataSeriesCache(app);
                    updateRuntimeResourceInventory(app);
                    appendRunReport(app, 'Local run: OK', report);
                    app.RuninformationhereLabel.Text = ['Run done: ' fullfile(runObj.path, 'run.json')];
                    app.RunButton.Text = 'Run !';
                end
            catch ME
                fullReport = printExceptionToConsole(app, 'Pipeline run failed', ME);
                try
                    if exist('runObj', 'var') && ~isempty(runObj)
                        if isPipelineCancelException(app, ME)
                            runObj.status = 'cancelled';
                        else
                            runObj.status = 'failed';
                        end
                        runObj.outputs.error = struct('identifier', ME.identifier, ...
                            'message', ME.message, 'report', fullReport);
                        try
                            runObj.ctx = stripTransientRunContext(app, ctxRun);
                        catch
                            runObj.ctx = buildRunContext(app);
                        end
                        if isPipelineCancelException(app, ME)
                            logRunEvent(app, runObj, ['Run cancelled: ' ME.message], 'pipeline2');
                        else
                            logRunEvent(app, runObj, ['Run failed: ' ME.message], 'pipeline2');
                        end
                        pipelineRunSave(runObj);
                    end
                catch
                end
                if isPipelineCancelException(app, ME)
                    app.RuninformationhereLabel.Text = ['Run stopped: ' fullfile(runObj.path, 'run.json')];
                    app.RunButton.Text = 'Resume run';
                    app.PipelineandRuncheckreportLabel.Text = [app.PipelineandRuncheckreportLabel.Text newline newline ...
                        'Run stopped by user.' newline ...
                        'Resume with "Resume previous progress" and an output policy that skips existing outputs.'];
                    uialert(app.UIFigure, 'Run stopped. Existing outputs and run log were kept; resume can continue from saved progress.', ...
                        'Run stopped', 'Icon', 'warning');
                else
                    app.PipelineandRuncheckreportLabel.Text = [app.PipelineandRuncheckreportLabel.Text newline newline ...
                        'Run failed:' newline ME.identifier newline ME.message newline newline ...
                        getReport(ME, 'basic', 'hyperlinks', 'off')];
                    uialert(app.UIFigure, ME.message, 'Run failed', 'Icon', 'error');
                end
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
                [arr, item] = alignStructFieldsForAppend(app, arr, item);
                out = arr;
                out(end+1) = item;
            end
        end

        function [arr, item] = alignStructFieldsForAppend(app, arr, item) %#ok<INUSD>
            arrFields = fieldnames(arr);
            itemFields = fieldnames(item);
            allFields = unique([arrFields; itemFields], 'stable');
            for i = 1:numel(allFields)
                f = allFields{i};
                if ~isfield(arr, f)
                    [arr.(f)] = deal([]);
                end
                if ~isfield(item, f)
                    item.(f) = [];
                end
            end
            arr = orderfields(arr, allFields);
            item = orderfields(item, allFields);
        end

        function updateCommonControlsEnableState(app)
            hasNode = ~isnan(app.SelectedNodeIndex) && app.SelectedNodeIndex >= 1 && app.SelectedNodeIndex <= numel(app.Data.nodes);
            state = ternary(app, hasNode, 'on', 'off');
            app.IdEditField.Enable = state;
            app.TypeDropDown.Enable = state;
            app.SubtypeDropDown.Enable = state;
            app.AdvancedmodeCheckBox.Enable = 'off';
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
            app.AdvancedmodeCheckBox.Value = false;
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
            app.RunButton.Position = [416 11 100 23];
            app.RunButton.Text = 'Run !';

            % Create SmokeTestButton
            app.SmokeTestButton = uibutton(app.ParametersPanel, 'push');
            app.SmokeTestButton.Position = [276 11 130 23];
            app.SmokeTestButton.Text = 'Smoke test (1 ROI)';

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
        function app = pipeline2(varargin)

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute startup logic after the designer-created layout exists
            runStartupFcn(app, @startupFcn)

            applyStartupArguments(app, varargin{:});

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
