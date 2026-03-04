classdef workflow < matlab.apps.AppBase

    properties (Access = public)
        UIFigure                       matlab.ui.Figure
        FileMenu                       matlab.ui.container.Menu
        EditMenu                       matlab.ui.container.Menu
        ViewMenu                       matlab.ui.container.Menu
        AboutMenu                      matlab.ui.container.Menu
        TabGroup                       matlab.ui.container.TabGroup
        DataloaderTab                  matlab.ui.container.Tab
        AdddataButton                  matlab.ui.control.Button
        UIDataLoaderTable              matlab.ui.control.Table
        DisplayTab                     matlab.ui.container.Tab
        PanButton                      matlab.ui.control.Button
        ResetzoomButton                matlab.ui.control.Button
        DisplaycolorColorPicker        matlab.ui.control.ColorPicker
        DisplaycolorColorPickerLabel   matlab.ui.control.Label
        ZoomSlider                     matlab.ui.control.Slider
        ZoomSliderLabel                matlab.ui.control.Label
        FrameEditField                 matlab.ui.control.NumericEditField
        FrameEditFieldLabel            matlab.ui.control.Label
        FrameSlider                    matlab.ui.control.Slider
        FrameSliderLabel               matlab.ui.control.Label
        LevelsSlider                   matlab.ui.control.RangeSlider
        LevelsSliderLabel              matlab.ui.control.Label
        UIDisplayChannelTable          matlab.ui.control.Table
        selectedFOVEditField           matlab.ui.control.TextArea
        selectedFOVEditFieldLabel      matlab.ui.control.Label
        UIFOVTable                     matlab.ui.control.Table
        ROIsIDTab                      matlab.ui.container.Tab
        RemoveselectedButton           matlab.ui.control.Button
        DeselectallButton              matlab.ui.control.Button
        SelectallButton                matlab.ui.control.Button
        GenerateROIsButton             matlab.ui.control.Button
        TestROIdetectionButton         matlab.ui.control.Button
        UIExistingROIsTable            matlab.ui.control.Table
        DrawpatternButton              matlab.ui.control.Button
        UIROIParametersTable           matlab.ui.control.Table
        ROIgenerationmodeButtonGroup   matlab.ui.container.ButtonGroup
        GridselectiongridButton        matlab.ui.control.RadioButton
        PatterndetectionpatternButton  matlab.ui.control.RadioButton
        ManualselectionmanualButton    matlab.ui.control.RadioButton
        ROIsExtractionTab              matlab.ui.container.Tab
        ExtractROIsButton              matlab.ui.control.Button
        UIROIsExtractionTable          matlab.ui.control.Table
        UIAxes                         matlab.ui.control.UIAxes
    end

    properties (Access = private)
        Project
        Pipeline
        SelectedFov = []
        SelectedFrame = 1
        ChannelCfg struct = struct([])
        SelectedChannelRow = 1
        RoiDisplayMask logical = false(0,1)
        Cache
        Dirty logical = false
        Suppress logical = false
        PatternHandle = []
        SelectedRoi = []
        RoiEditHandle = []
        RoiEditListener = []
        PreviewRoiPositions double = zeros(0,4)
        PendingManualRect double = zeros(0,4)
    end

    methods (Access = private)
        function startupFcn(app, shallowObj)
            app.configureUi();
            app.Cache = containers.Map('KeyType','char','ValueType','any');
            if nargin < 2 || isempty(shallowObj) || ~isa(shallowObj,'shallow')
                uialert(app.UIFigure,'workflow expects a shallow project object.','Missing project','Icon','warning');
                app.refreshAll();
                return;
            end
            app.Project = shallowObj;
            app.ensureWorkflowRunProfiles();
            app.Pipeline = app.loadOrCreateDefaultPipeline();
            if app.getFovCount() > 0
                app.SelectedFov = 1;
            end
            app.refreshAll();
            app.markDirty(false);
        end

        function configureUi(app)
            app.UIFigure.Name = 'Workflow';
            app.UIFigure.WindowKeyPressFcn = createCallbackFcn(app,@UIFigureWindowKeyPress,true);
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app,@UIFigureCloseRequest,true);

            app.UIAxes.Toolbar.Visible = 'off';
            app.UIAxes.XTick = [];
            app.UIAxes.YTick = [];
            title(app.UIAxes,'Display','Interpreter','none');

            app.selectedFOVEditField.Editable = 'off';

            if isempty(app.FileMenu.Children)
                m = uimenu(app.FileMenu);
                m.Text = 'Save project';
                m.MenuSelectedFcn = createCallbackFcn(app,@SaveprojectMenuSelected,true);
            end

            app.UIDataLoaderTable.ColumnName = {'Parameter';'Value'};
            app.UIDataLoaderTable.RowName = {};
            app.UIDataLoaderTable.ColumnEditable = [false true];
            app.UIDataLoaderTable.ColumnWidth = {150,250};
            app.UIDataLoaderTable.CellEditCallback = createCallbackFcn(app,@UIDataLoaderTableCellEdit,true);

            app.UIFOVTable.RowName = {};
            app.UIFOVTable.ColumnName = {'Select FOV';'Name'};
            app.UIFOVTable.ColumnEditable = [true false];
            app.UIFOVTable.ColumnWidth = {75,330};
            app.UIFOVTable.CellEditCallback = createCallbackFcn(app,@UIFOVTableCellEdit,true);
            app.UIFOVTable.SelectionChangedFcn = createCallbackFcn(app,@UIFOVTableSelectionChanged,true);

            app.UIDisplayChannelTable.RowName = {};
            app.UIDisplayChannelTable.ColumnEditable = [true false true false true true];
            app.UIDisplayChannelTable.ColumnWidth = {55,95,80,70,60,45};
            app.UIDisplayChannelTable.CellEditCallback = createCallbackFcn(app,@UIDisplayChannelTableCellEdit,true);
            app.UIDisplayChannelTable.SelectionChangedFcn = createCallbackFcn(app,@UIDisplayChannelTableSelectionChanged,true);

            app.LevelsSlider.Limits = [0 100];
            app.LevelsSlider.Value = app.levelsToSliderValue([0 4095]);
            app.LevelsSlider.ValueChangedFcn = createCallbackFcn(app,@LevelsSliderValueChanged,true);

            app.FrameSlider.Limits = [1 2];
            app.FrameSlider.Value = 1;
            app.FrameSlider.ValueChangedFcn = createCallbackFcn(app,@FrameSliderValueChanged,true);
            app.FrameEditField.Limits = [1 Inf];
            app.FrameEditField.Value = 1;
            app.FrameEditField.ValueChangedFcn = createCallbackFcn(app,@FrameEditFieldValueChanged,true);

            app.ZoomSlider.Limits = [0 20];
            app.ZoomSlider.Value = 0;
            app.ZoomSlider.ValueChangedFcn = createCallbackFcn(app,@ZoomSliderValueChanged,true);
            app.DisplaycolorColorPicker.ValueChangedFcn = createCallbackFcn(app,@DisplaycolorColorPickerValueChanged,true);
            app.ResetzoomButton.ButtonPushedFcn = createCallbackFcn(app,@ResetzoomButtonPushed,true);
            app.PanButton.ButtonPushedFcn = createCallbackFcn(app,@PanButtonPushed,true);
            app.AdddataButton.ButtonPushedFcn = createCallbackFcn(app,@AdddataButtonPushed,true);

            app.ROIgenerationmodeButtonGroup.SelectionChangedFcn = createCallbackFcn(app,@ROIgenerationmodeButtonGroupSelectionChanged,true);
            app.UIROIParametersTable.ColumnName = {'Parameter';'Value'};
            app.UIROIParametersTable.RowName = {};
            app.UIROIParametersTable.ColumnEditable = [false true];
            app.UIROIParametersTable.ColumnWidth = {150,250};
            app.UIROIParametersTable.CellEditCallback = createCallbackFcn(app,@UIROIParametersTableCellEdit,true);
            app.DrawpatternButton.ButtonPushedFcn = createCallbackFcn(app,@DrawpatternButtonPushed,true);
            app.TestROIdetectionButton.ButtonPushedFcn = createCallbackFcn(app,@TestROIdetectionButtonPushed,true);
            app.GenerateROIsButton.ButtonPushedFcn = createCallbackFcn(app,@GenerateROIsButtonPushed,true);

            app.UIExistingROIsTable.ColumnName = {'Display';'ROI';'Value'};
            app.UIExistingROIsTable.RowName = {};
            app.UIExistingROIsTable.ColumnEditable = [true false true];
            app.UIExistingROIsTable.ColumnWidth = {60,180,160};
            app.UIExistingROIsTable.CellEditCallback = createCallbackFcn(app,@UIExistingROIsTableCellEdit,true);
            app.UIExistingROIsTable.SelectionChangedFcn = createCallbackFcn(app,@UIExistingROIsTableSelectionChanged,true);
            app.SelectallButton.ButtonPushedFcn = createCallbackFcn(app,@SelectallButtonPushed,true);
            app.DeselectallButton.ButtonPushedFcn = createCallbackFcn(app,@DeselectallButtonPushed,true);
            app.RemoveselectedButton.ButtonPushedFcn = createCallbackFcn(app,@RemoveselectedButtonPushed,true);

            app.UIROIsExtractionTable.ColumnName = {'Parameter';'Value'};
            app.UIROIsExtractionTable.RowName = {};
            app.UIROIsExtractionTable.ColumnEditable = [false true];
            app.UIROIsExtractionTable.ColumnWidth = {150,250};
            app.UIROIsExtractionTable.CellEditCallback = createCallbackFcn(app,@UIROIsExtractionTableCellEdit,true);
            app.ExtractROIsButton.ButtonPushedFcn = createCallbackFcn(app,@ExtractROIsButtonPushed,true);
        end

        function pipe = loadOrCreateDefaultPipeline(app)
            pipe = [];
            if isempty(app.Project)
                return;
            end
            jsonPath = '';
            try
                if isfield(app.Project.runProfiles,'pipeline') && isfield(app.Project.runProfiles.pipeline,'defaultTemplatePath')
                    jsonPath = char(string(app.Project.runProfiles.pipeline.defaultTemplatePath));
                end
            catch
            end
            if ~isempty(jsonPath) && exist(jsonPath,'file')
                [pipe,msg] = pipelineLoad(jsonPath);
                if isempty(pipe)
                    warning('workflow:Pipeline','%s',msg);
                else
                    return;
                end
            end
            projPath = app.Project.io.path;
            projName = char(string(app.Project.io.file));
            defaultJson = fullfile(projPath, projName, [projName '_pipeline'], 'pipeline.json');
            if exist(defaultJson,'file')
                [pipe,msg] = pipelineLoad(defaultJson);
                if isempty(pipe)
                    warning('workflow:Pipeline','%s',msg);
                else
                    app.storePipelineLink(pipe);
                    return;
                end
            end
            pipe = pipelineNew('path', fullfile(projPath, projName), 'name', [projName '_pipeline'], 'workspace', false);
            app.storePipelineLink(pipe);
        end

        function storePipelineLink(app, pipe)
            if isempty(pipe)
                return;
            end
            if ~isfield(app.Project.runProfiles,'pipeline') || ~isstruct(app.Project.runProfiles.pipeline)
                app.Project.runProfiles.pipeline = struct();
            end
            app.Project.runProfiles.pipeline.defaultTemplatePath = fullfile(pipe.path,'pipeline.json');
            app.Project.runProfiles.pipeline.defaultTemplateId = pipe.strid;
        end

        function refreshAll(app)
            app.refreshDataloaderTable();
            app.refreshFovTable();
            app.refreshSelectedFovInfo();
            app.refreshDisplayChannels();
            app.refreshRoiMode();
            app.refreshRoiTables();
            app.refreshExtractionTable();
            app.renderCurrentFrame();
            app.refreshTitle();
        end

        function refreshDataloaderTable(app)
            params = struct();
            idx = app.findNodeIndex('dataLoader');
            if ~isempty(idx)
                params = app.Pipeline.nodes(idx).params;
            elseif ~isempty(app.Project) && isfield(app.Project.runProfiles,'dataloading') && isfield(app.Project.runProfiles.dataloading,'dataLoader')
                params = app.Project.runProfiles.dataloading.dataLoader;
            end
            app.UIDataLoaderTable.Data = app.structToTable(params);
        end

        function refreshFovTable(app)
            nFov = app.getFovCount();
            data = cell(nFov,2);
            for i = 1:nFov
                data{i,1} = (~isempty(app.SelectedFov) && app.SelectedFov == i);
                data{i,2} = app.getFovLabel(i);
            end
            app.Suppress = true;
            app.UIFOVTable.Data = data;
            app.Suppress = false;
        end

        function refreshSelectedFovInfo(app)
            fovObj = app.getSelectedFov();
            if isempty(fovObj)
                app.selectedFOVEditField.Value = {''};
            else
                raw = workflowui.describeFov(fovObj);
                app.selectedFOVEditField.Value = regexp(raw, '\s*\|\s*', 'split');
            end
        end
        function refreshDisplayChannels(app)
            fovObj = app.getSelectedFov();
            if isempty(fovObj)
                app.ChannelCfg = struct([]);
                app.UIDisplayChannelTable.Data = cell(0,6);
                app.setFrameControls(1);
                return;
            end
            names = cellstr(string(fovObj.channel(:)));
            needReset = isempty(app.ChannelCfg) || numel(app.ChannelCfg) ~= numel(names);
            if ~needReset
                needReset = ~isequal(string({app.ChannelCfg.name})', string(names(:)));
            end
            if needReset
                app.ChannelCfg = repmat(struct('enabled',true,'name','','levels',[0 4095],'color',[1 1 1],'weight',1,'auto',true), numel(names), 1);
                for i = 1:numel(names)
                    app.ChannelCfg(i).name = names{i};
                    app.ChannelCfg(i).enabled = true;
                    app.ChannelCfg(i).color = [1 1 1];
                end
                app.restoreDisplaySettings(names);
                app.SelectedChannelRow = min(max(1, app.SelectedChannelRow), max(1, numel(names)));
            end
            data = cell(numel(names),6);
            for i = 1:numel(names)
                cfg = app.ChannelCfg(i);
                data{i,1} = cfg.enabled;
                data{i,2} = cfg.name;
                data{i,3} = sprintf('%g-%g',cfg.levels(1),cfg.levels(2));
                data{i,4} = sprintf('[%0.2f %0.2f %0.2f]',cfg.color(1),cfg.color(2),cfg.color(3));
                data{i,5} = cfg.weight;
                data{i,6} = cfg.auto;
            end
            app.Suppress = true;
            app.UIDisplayChannelTable.Data = data;
            app.Suppress = false;
            app.setFrameControls(app.getMaxFrame());
            app.refreshDisplayControls();
        end

        function refreshDisplayControls(app)
            if isempty(app.ChannelCfg)
                return;
            end
            row = min(max(1,app.SelectedChannelRow), numel(app.ChannelCfg));
            app.SelectedChannelRow = row;
            app.LevelsSlider.Value = app.levelsToSliderValue(double(app.ChannelCfg(row).levels));
            app.DisplaycolorColorPicker.Value = app.ChannelCfg(row).color;
        end

        function refreshRoiMode(app)
            mode = app.getCurrentRoiMode();
            app.Suppress = true;
            switch lower(mode)
                case 'roipattern'
                    app.ROIgenerationmodeButtonGroup.SelectedObject = app.PatterndetectionpatternButton;
                case 'roigrid'
                    app.ROIgenerationmodeButtonGroup.SelectedObject = app.GridselectiongridButton;
                otherwise
                    app.ROIgenerationmodeButtonGroup.SelectedObject = app.ManualselectionmanualButton;
            end
            app.Suppress = false;
            switch lower(app.getSelectedRoiMode())
                case 'roipattern'
                    app.DrawpatternButton.Enable = 'on';
                    app.DrawpatternButton.Text = 'Draw pattern';
                    app.TestROIdetectionButton.Enable = 'on';
                case 'roimanual'
                    app.DrawpatternButton.Enable = 'on';
                    app.DrawpatternButton.Text = 'Draw ROI';
                    app.TestROIdetectionButton.Enable = 'off';
                otherwise
                    app.DrawpatternButton.Enable = 'off';
                    app.DrawpatternButton.Text = 'Draw pattern';
                    app.TestROIdetectionButton.Enable = 'off';
            end
        end

        function refreshRoiTables(app)
            mode = app.getSelectedRoiMode();
            idx = app.findNodeIndex(mode);
            defaults = app.getDefaultParams(mode);
            if isempty(idx)
                params = defaults;
            else
                params = app.Pipeline.nodes(idx).params;
                changed = false;
                fn = fieldnames(defaults);
                for ii = 1:numel(fn)
                    if ~isfield(params, fn{ii})
                        params.(fn{ii}) = defaults.(fn{ii});
                        changed = true;
                    end
                end
                if changed
                    app.Pipeline.nodes(idx).params = params;
                    pipelineSave(app.Pipeline);
                    app.storePipelineLink(app.Pipeline);
                    app.publishPipelineToWorkspace();
                end
            end
            data = app.structToTable(params);
            effFov = [];
            if isfield(params,'fovIndex') && ~isempty(params.fovIndex)
                effFov = reshape(double(params.fovIndex), 1, []);
            elseif ~isempty(app.SelectedFov)
                effFov = app.SelectedFov;
            end
            effFov = unique(effFov(isfinite(effFov) & effFov >= 1 & effFov <= app.getFovCount()));
            if isempty(effFov)
                scopeText = '<none>';
            else
                labels = arrayfun(@(k) app.getFovLabel(k), effFov, 'UniformOutput', false);
                scopeText = strjoin(labels, ', ');
            end
            data(end+1,:) = {'selectedFOVs', scopeText}; %#ok<AGROW>
            if strcmpi(mode,'roiPattern')
                crop = app.getPatternCrop();
                if isempty(crop)
                    cropTxt = '<draw pattern>';
                else
                    cropTxt = mat2str(round(crop));
                end
                data(end+1,:) = {'patternRect', cropTxt}; %#ok<AGROW>
            end
            app.UIROIParametersTable.Data = data;
            app.refreshExistingRoisTable();
        end

        function refreshExistingRoisTable(app)
            fovObj = app.getSelectedFov();
            if isempty(fovObj) || isempty(fovObj.roi)
                app.RoiDisplayMask = false(0,1);
                app.SelectedRoi = [];
                app.UIExistingROIsTable.Data = cell(0,3);
                return;
            end
            if numel(fovObj.roi) == 1
                try
                    if isempty(fovObj.roi(1).id)
                        app.RoiDisplayMask = false(0,1);
                        app.SelectedRoi = [];
                        app.UIExistingROIsTable.Data = cell(0,3);
                        return;
                    end
                catch
                end
            end
            nRoi = numel(fovObj.roi);
            if numel(app.RoiDisplayMask) ~= nRoi
                app.RoiDisplayMask = true(nRoi,1);
            end
            if isempty(app.SelectedRoi) || app.SelectedRoi < 1 || app.SelectedRoi > nRoi
                app.SelectedRoi = [];
            end
            data = cell(nRoi,3);
            for i = 1:nRoi
                data{i,1} = app.RoiDisplayMask(i);
                data{i,2} = app.describeRoi(fovObj.roi(i), i);
                pos = app.getRoiPosition(fovObj.roi(i));
                if isempty(pos)
                    data{i,3} = '';
                else
                    data{i,3} = mat2str(round(pos));
                end
            end
            app.Suppress = true;
            app.UIExistingROIsTable.Data = data;
            app.Suppress = false;
        end

        function refreshExtractionTable(app)
            idx = app.findNodeIndex('roiExtract');
            defaults = app.getDefaultParams('roiExtract');
            if isempty(idx)
                params = defaults;
            else
                params = app.Pipeline.nodes(idx).params;
                changed = false;
                fn = fieldnames(defaults);
                for ii = 1:numel(fn)
                    if ~isfield(params, fn{ii})
                        params.(fn{ii}) = defaults.(fn{ii});
                        changed = true;
                    end
                end
                if changed
                    app.Pipeline.nodes(idx).params = params;
                    pipelineSave(app.Pipeline);
                    app.storePipelineLink(app.Pipeline);
                    app.publishPipelineToWorkspace();
                end
            end
            data = app.structToTable(params);
            effFov = [];
            if isfield(params,'fovIndex') && ~isempty(params.fovIndex)
                effFov = reshape(double(params.fovIndex), 1, []);
            elseif ~isempty(app.SelectedFov)
                effFov = app.SelectedFov;
            end
            effFov = unique(effFov(isfinite(effFov) & effFov >= 1 & effFov <= app.getFovCount()));
            if isempty(effFov)
                scopeText = '<none>';
            else
                labels = arrayfun(@(k) app.getFovLabel(k), effFov, 'UniformOutput', false);
                scopeText = strjoin(labels, ', ');
            end
            data(end+1,:) = {'selectedFOVs', scopeText}; %#ok<AGROW>
            app.UIROIsExtractionTable.Data = data;
        end

        function renderCurrentFrame(app)
            cla(app.UIAxes);
            fovObj = app.getSelectedFov();
            if isempty(fovObj) || isempty(app.ChannelCfg)
                title(app.UIAxes,'Display','Interpreter','none');
                app.clearPatternEditor();
                app.clearRoiEditor();
                return;
            end
            imgs = cell(1,numel(app.ChannelCfg));
            active = find([app.ChannelCfg.enabled]);
            if isempty(active)
                title(app.UIAxes,'No channel selected','Interpreter','none');
                app.clearPatternEditor();
                app.clearRoiEditor();
                return;
            end
            for i = active(:)'
                imgs{i} = app.getImage(i);
            end
            rgb = workflowui.composeBlendImage(imgs, app.ChannelCfg);
            if isempty(rgb)
                title(app.UIAxes,'Unable to load image','Interpreter','none');
                app.clearPatternEditor();
                app.clearRoiEditor();
                return;
            end
            image(app.UIAxes, rgb);
            axis(app.UIAxes,'image');
            app.UIAxes.XTick = [];
            app.UIAxes.YTick = [];
            hold(app.UIAxes,'on');
            for i = 1:numel(app.RoiDisplayMask)
                if ~app.RoiDisplayMask(i)
                    continue;
                end
                pos = app.getRoiPosition(fovObj.roi(i));
                if ~isempty(pos)
                    edge = [0 1 1];
                    lw = 1;
                    if isequal(app.SelectedRoi, i)
                        edge = [1 1 0];
                        lw = 2.0;
                    end
                    hRect = rectangle(app.UIAxes,'Position',pos,'EdgeColor',edge,'LineWidth',lw);
                    hRect.ButtonDownFcn = @(src,evt)app.selectRoi(i);
                    text(app.UIAxes, pos(1), max(1,pos(2)-2), sprintf('%d', i), 'Color', edge, 'FontSize', 14, 'FontWeight', 'bold', 'Interpreter', 'none', 'ButtonDownFcn', @(src,evt)app.selectRoi(i));
                end
            end
            for i = 1:size(app.PreviewRoiPositions,1)
                pos = app.PreviewRoiPositions(i,:);
                rectangle(app.UIAxes,'Position',pos,'EdgeColor',[1 0 1],'LineWidth',1.2,'LineStyle','--');
                text(app.UIAxes, pos(1), max(1,pos(2)-2), sprintf('T%d', i), 'Color', [1 0 1], 'FontSize', 13, 'FontWeight', 'bold', 'Interpreter', 'none');
            end
            app.drawGridPreview(size(rgb,2), size(rgb,1));
            crop = app.getPatternCrop();
            if ~isempty(crop)
                rectangle(app.UIAxes,'Position',crop,'EdgeColor',[1 1 0],'LineStyle','--','LineWidth',1.0);
            end
            if strcmpi(app.getSelectedRoiMode(),'roiManual') && isempty(app.SelectedRoi) && ~isempty(app.PendingManualRect)
                rectangle(app.UIAxes,'Position',app.PendingManualRect(1,1:4),'EdgeColor',[0 1 0],'LineStyle','--','LineWidth',1.2);
            end
            hold(app.UIAxes,'off');
            title(app.UIAxes, sprintf('%s | frame %d', app.getFovLabel(app.SelectedFov), app.SelectedFrame), 'Interpreter', 'none');
            app.rebuildEditors();
            app.applyZoom();
        end

        function drawGridPreview(app, widthPx, heightPx)
            if ~strcmpi(app.getSelectedRoiMode(), 'roiGrid')
                return;
            end
            idx = app.findNodeIndex('roiGrid');
            if isempty(idx)
                return;
            end
            params = app.Pipeline.nodes(idx).params;
            modeName = lower(char(string(app.getParamField(params, 'mode', 'fullframe'))));
            if strcmp(modeName, 'fullframe')
                rectangle(app.UIAxes, 'Position', [1 1 widthPx heightPx], 'EdgeColor', [1 0.6 0], 'LineWidth', 1.2, 'LineStyle', ':');
                return;
            end
            gridCount = app.getParamField(params, 'gridCount', 4);
            if isempty(gridCount) || ~isnumeric(gridCount)
                return;
            end
            gridCount = max(1, round(double(gridCount(1))));
            nSide = round(sqrt(gridCount));
            if nSide < 1
                nSide = 1;
            end
            if nSide * nSide ~= gridCount
                nSide = ceil(sqrt(gridCount));
            end
            tileW = widthPx / nSide;
            tileH = heightPx / nSide;
            for rr = 1:nSide
                for cc = 1:nSide
                    x = (cc - 1) * tileW + 1;
                    y = (rr - 1) * tileH + 1;
                    w = min(tileW, widthPx - x + 1);
                    h = min(tileH, heightPx - y + 1);
                    rectangle(app.UIAxes, 'Position', [x y w h], 'EdgeColor', [1 0.6 0], 'LineWidth', 1.0, 'LineStyle', ':');
                end
            end
        end

        function im = getImage(app, channelIdx)
            im = [];
            if isempty(app.SelectedFov)
                return;
            end
            key = sprintf('%d|%d|%d', app.SelectedFov, app.SelectedFrame, channelIdx);
            if isKey(app.Cache,key)
                im = app.Cache(key);
                return;
            end
            try
                im = readImage(app.Project.fov(app.SelectedFov), app.SelectedFrame, channelIdx);
                app.Cache(key) = im;
            catch ME
                warning('workflow:readImage','%s',ME.message);
            end
        end

        function applyZoom(app)
            if isempty(app.UIAxes.Children)
                return;
            end
            h = app.UIAxes.Children(end);
            if ~isprop(h,'CData')
                return;
            end
            cdata = h.CData;
            if isempty(cdata)
                return;
            end
            hgt = size(cdata,1);
            wid = size(cdata,2);
            frac = max(0.05, 1 / (1 + 0.25 * double(app.ZoomSlider.Value)));
            cx = (wid + 1) / 2;
            cy = (hgt + 1) / 2;
            halfW = max(1, wid * frac / 2);
            halfH = max(1, hgt * frac / 2);
            app.UIAxes.XLim = [max(0.5, cx-halfW), min(wid+0.5, cx+halfW)];
            app.UIAxes.YLim = [max(0.5, cy-halfH), min(hgt+0.5, cy+halfH)];
        end

        function fovObj = getSelectedFov(app)
            fovObj = [];
            if isempty(app.Project) || isempty(app.SelectedFov) || app.SelectedFov < 1 || app.SelectedFov > app.getFovCount()
                return;
            end
            fovObj = app.Project.fov(app.SelectedFov);
        end

        function pos = getDefaultPatternPosition(app)
            pos = [10 10 40 40];
            fovObj = app.getSelectedFov();
            if isempty(fovObj)
                return;
            end
            chanIdx = find([app.ChannelCfg.enabled], 1, 'first');
            if isempty(chanIdx)
                chanIdx = 1;
            end
            try
                im = readImage(fovObj, app.SelectedFrame, chanIdx);
                if ~isempty(im)
                    h = size(im,1);
                    w = size(im,2);
                    ww = max(16, round(w * 0.2));
                    hh = max(16, round(h * 0.2));
                    pos = [max(1, round((w - ww) / 2)), max(1, round((h - hh) / 2)), ww, hh];
                end
            catch
            end
        end

        function syncPatternFromHandle(app)
            if isempty(app.PatternHandle)
                return;
            end
            try
                if ~isvalid(app.PatternHandle)
                    return;
                end
            catch
                return;
            end
            idx = app.findNodeIndex('roiPattern');
            if isempty(idx)
                return;
            end
            params = app.Pipeline.nodes(idx).params;
            pat = struct();
            pat.crop = double(app.PatternHandle.Position);
            pat.rect = double(app.PatternHandle.Position);
            pat.fovIndex = app.SelectedFov;
            try
                pat.fovId = char(string(app.Project.fov(app.SelectedFov).id));
            catch
                pat.fovId = app.getFovLabel(app.SelectedFov);
            end
            pat.referenceFrame = app.SelectedFrame;
            chanIdx = find([app.ChannelCfg.enabled], 1, 'first');
            if isempty(chanIdx)
                chanIdx = 1;
            end
            pat.channelIndex = chanIdx;
            try
                pat.channel = char(string(app.Project.fov(app.SelectedFov).channel{chanIdx}));
            catch
                pat.channel = '';
            end
            params.patternList = pat;
            if isfield(params, 'activePatternIndex')
                params.activePatternIndex = 1;
            end
            if isfield(params, 'referenceFrame')
                params.referenceFrame = app.SelectedFrame;
            end
            if isfield(params, 'channelIndex')
                params.channelIndex = chanIdx;
            end
            if isfield(params, 'channel')
                params.channel = pat.channel;
            end
            if isfield(params, 'crop')
                params.crop = pat.crop;
            end
            if isfield(params, 'fovIndex')
                params.fovIndex = app.SelectedFov;
            end
            app.Pipeline.nodes(idx).params = params;
            pipelineSave(app.Pipeline);
            app.storePipelineLink(app.Pipeline);
            app.publishPipelineToWorkspace();
            app.markDirty(true);
            app.refreshRoiTables();
        end

        function deletePattern(app)
            if ~isempty(app.PatternHandle)
                try
                    if isvalid(app.PatternHandle)
                        delete(app.PatternHandle);
                    end
                catch
                end
            end
            app.PatternHandle = [];
            idx = app.findNodeIndex('roiPattern');
            if isempty(idx)
                return;
            end
            params = app.Pipeline.nodes(idx).params;
            if isfield(params, 'patternList')
                params.patternList = struct([]);
            end
            if isfield(params, 'activePatternIndex')
                params.activePatternIndex = 1;
            end
            app.Pipeline.nodes(idx).params = params;
            pipelineSave(app.Pipeline);
            app.storePipelineLink(app.Pipeline);
            app.publishPipelineToWorkspace();
            app.markDirty(true);
            app.refreshAll();
        end

        function maxFrame = getMaxFrame(app)
            maxFrame = 1;
            fovObj = app.getSelectedFov();
            if isempty(fovObj)
                return;
            end
            try
                if ~isempty(fovObj.frames)
                    maxFrame = max(double(fovObj.frames(:)));
                elseif ~isempty(fovObj.srclist) && ~isempty(fovObj.srclist{1})
                    maxFrame = numel(fovObj.srclist{1});
                end
            catch
            end
            if isempty(maxFrame) || ~isfinite(maxFrame) || maxFrame < 1
                maxFrame = 1;
            end
            maxFrame = round(maxFrame);
        end

        function setFrameControls(app, maxFrame)
            maxFrame = max(1, round(maxFrame));
            app.SelectedFrame = min(max(1, app.SelectedFrame), maxFrame);
            if maxFrame <= 1
                app.FrameSlider.Limits = [1 2];
            else
                app.FrameSlider.Limits = [1 maxFrame];
            end
            app.FrameSlider.Value = app.SelectedFrame;
            app.FrameEditField.Value = app.SelectedFrame;
        end

        function count = getFovCount(app)
            count = 0;
            if isempty(app.Project)
                return;
            end
            try
                count = numel(app.Project.fov);
                if count == 1
                    try
                        if isempty(app.Project.fov(1).srcpath{1})
                            count = 0;
                        end
                    catch
                    end
                end
            catch
                count = 0;
            end
        end

        function label = getFovLabel(app, idx)
            label = sprintf('FOV %d', idx);
            if isempty(idx) || idx < 1 || idx > app.getFovCount()
                return;
            end
            try
                label = sprintf('%d - %s', idx, char(string(app.Project.fov(idx).id)));
            catch
            end
        end

        function txt = describeRoi(app, roiObj, idx)
            txt = sprintf('ROI %d', idx);
            try
                if ~isempty(roiObj.id)
                    txt = char(string(roiObj.id));
                end
            catch
            end
            pos = app.getRoiPosition(roiObj);
            if ~isempty(pos)
                txt = sprintf('%s [%dx%d]', txt, round(pos(3)), round(pos(4)));
            end
        end
        function pos = getRoiPosition(app, roiObj)
            pos = [];
            try
                if numel(roiObj.value) >= 4
                    pos = double(reshape(roiObj.value(1:4),1,[]));
                end
            catch
            end
        end

        function crop = getPatternCrop(app)
            crop = [];
            idx = app.findNodeIndex('roiPattern');
            if isempty(idx)
                return;
            end
            params = app.Pipeline.nodes(idx).params;
            if ~isfield(params,'patternList') || isempty(params.patternList)
                return;
            end
            pat = params.patternList(1);
            if isstruct(pat) && isfield(pat,'rect') && numel(pat.rect) >= 4
                crop = double(reshape(pat.rect(1:4),1,[]));
            elseif isstruct(pat) && isfield(pat,'crop') && numel(pat.crop) >= 4
                crop = double(reshape(pat.crop(1:4),1,[]));
            end
        end

        function idx = findNodeIndex(app, typeName)
            idx = [];
            if isempty(app.Pipeline) || isempty(app.Pipeline.nodes)
                return;
            end
            for i = 1:numel(app.Pipeline.nodes)
                if strcmpi(char(string(app.Pipeline.nodes(i).type)), typeName)
                    idx = i;
                    return;
                end
            end
        end

        function mode = getCurrentRoiMode(app)
            mode = 'roiManual';
            if ~isempty(app.findNodeIndex('roiPattern')) || ~isempty(app.findNodeIndex('roiIdentify'))
                mode = 'roiPattern';
            elseif ~isempty(app.findNodeIndex('roiGrid'))
                mode = 'roiGrid';
            elseif ~isempty(app.findNodeIndex('roiManual'))
                mode = 'roiManual';
            end
        end

        function mode = getSelectedRoiMode(app)
            if isequal(app.ROIgenerationmodeButtonGroup.SelectedObject, app.PatterndetectionpatternButton)
                mode = 'roiPattern';
            elseif isequal(app.ROIgenerationmodeButtonGroup.SelectedObject, app.GridselectiongridButton)
                mode = 'roiGrid';
            else
                mode = 'roiManual';
            end
        end

        function params = getDefaultParams(app, typeName)
            switch lower(char(string(typeName)))
                case 'dataloader'
                    params = dataLoader.setparam(struct());
                case 'roipattern'
                    params = roiPattern.setparam(struct());
                case 'roimanual'
                    params = roiManual.setparam(struct());
                case 'roigrid'
                    params = roiGrid.setparam(struct());
                case 'roiextract'
                    params = roiExtract.setparam(struct());
                otherwise
                    params = struct();
            end
        end

        function ensureRoiNode(app, typeName)
            current = app.getCurrentRoiMode();
            if strcmpi(current,typeName) && ~isempty(app.findNodeIndex(typeName))
                return;
            end
            keep = true(1, numel(app.Pipeline.nodes));
            for i = 1:numel(app.Pipeline.nodes)
                if any(strcmpi(char(string(app.Pipeline.nodes(i).type)), {'roiPattern','roiIdentify','roiManual','roiGrid'}))
                    keep(i) = false;
                end
            end
            nodes = app.Pipeline.nodes(keep);
            newNode = app.buildBuiltinNode(typeName);
            insertPos = numel(nodes) + 1;
            for i = 1:numel(nodes)
                if strcmpi(char(string(nodes(i).type)),'dataLoader')
                    insertPos = i + 1;
                end
            end
            nodes = [nodes(1:insertPos-1), newNode, nodes(insertPos:end)];
            app.Pipeline.nodes = nodes;
            app.rebuildCoreEdges();
            pipelineSave(app.Pipeline);
            app.storePipelineLink(app.Pipeline);
            app.publishPipelineToWorkspace();
            app.markDirty(true);
        end

        function ensureExtractNode(app)
            if ~isempty(app.findNodeIndex('roiExtract'))
                return;
            end
            nodes = app.Pipeline.nodes;
            newNode = app.buildBuiltinNode('roiExtract');
            insertPos = numel(nodes) + 1;
            for i = 1:numel(nodes)
                if any(strcmpi(char(string(nodes(i).type)), {'roiPattern','roiManual','roiGrid','roiIdentify'}))
                    insertPos = i + 1;
                end
            end
            nodes = [nodes(1:insertPos-1), newNode, nodes(insertPos:end)];
            app.Pipeline.nodes = nodes;
            app.rebuildCoreEdges();
            pipelineSave(app.Pipeline);
            app.storePipelineLink(app.Pipeline);
            app.publishPipelineToWorkspace();
            app.markDirty(true);
        end

        function rebuildCoreEdges(app)
            keep = true(1, numel(app.Pipeline.edges));
            coreTypes = {'dataLoader','roiPattern','roiIdentify','roiManual','roiGrid','roiExtract'};
            for i = 1:numel(app.Pipeline.edges)
                fromType = app.nodeTypeFromId(app.Pipeline.edges(i).from);
                toType = app.nodeTypeFromId(app.Pipeline.edges(i).to);
                if any(strcmpi(fromType, coreTypes)) || any(strcmpi(toType, coreTypes))
                    keep(i) = false;
                end
            end
            edges = app.Pipeline.edges(keep);
            dlId = app.nodeIdByType('dataLoader');
            roiId = app.nodeIdByType(app.getCurrentRoiMode());
            exId = app.nodeIdByType('roiExtract');
            if ~isempty(dlId) && ~isempty(roiId)
                edges(end+1) = struct('from',dlId,'to',roiId,'fromPort','images','toPort','images','condition','');
            end
            if ~isempty(roiId) && ~isempty(exId)
                edges(end+1) = struct('from',roiId,'to',exId,'fromPort','roiList','toPort','roiList','condition','');
            end
            app.Pipeline.edges = edges;
        end

        function node = buildBuiltinNode(app, typeName)
            node = struct('id','','name','','type','','func','','gui','','guiMode','replace','paramRequired',{{}},'pkg','','params',struct(),'inputs',{{}},'outputs',{{}},'enabled',true,'status','','layout',[10 10 20 10]);
            switch lower(char(string(typeName)))
                case 'roipattern'
                    node.id = 'roipattern_1'; node.name = 'roipattern_1'; node.type = 'roiPattern'; node.func = 'roiPattern.process'; node.gui = 'roiPattern.ui'; node.params = app.getDefaultParams('roiPattern'); node.inputs = {'images'}; node.outputs = {'roiList'}; node.layout = [35 10 20 10];
                case 'roimanual'
                    node.id = 'roimanual_1'; node.name = 'roimanual_1'; node.type = 'roiManual'; node.func = 'roiManual.process'; node.gui = 'roiManual.ui'; node.params = app.getDefaultParams('roiManual'); node.inputs = {'images'}; node.outputs = {'roiList'}; node.layout = [35 10 20 10];
                case 'roigrid'
                    node.id = 'roigrid_1'; node.name = 'roigrid_1'; node.type = 'roiGrid'; node.func = 'roiGrid.process'; node.gui = 'roiGrid.ui'; node.params = app.getDefaultParams('roiGrid'); node.inputs = {'images'}; node.outputs = {'roiList'}; node.layout = [35 10 20 10];
                case 'roiextract'
                    node.id = 'roiextract_1'; node.name = 'roiextract_1'; node.type = 'roiExtract'; node.func = 'roiExtract.process'; node.gui = 'roiExtract.ui'; node.params = app.getDefaultParams('roiExtract'); node.inputs = {'roiList'}; node.outputs = {'channels'}; node.layout = [60 10 20 10];
                otherwise
                    error('Unsupported builtin node type: %s', typeName);
            end
        end

        function t = structToTable(app, s)
            if isempty(s) || ~isstruct(s)
                t = cell(0,2);
                return;
            end
            fn = fieldnames(s);
            t = cell(numel(fn),2);
            for i = 1:numel(fn)
                t{i,1} = fn{i};
                t{i,2} = app.tableValue(s.(fn{i}));
            end
        end

        function v = tableValue(app, x)
            if ischar(x)
                v = x;
            elseif isstring(x)
                v = char(join(x(:)',', '));
            elseif islogical(x) && isscalar(x)
                v = x;
            elseif isnumeric(x) && isscalar(x)
                v = x;
            elseif isnumeric(x)
                v = mat2str(x);
            elseif iscell(x)
                v = strjoin(cellstr(string(x(:)')),', ');
            elseif isstruct(x)
                v = sprintf('<struct %dx%d>',size(x,1),size(x,2));
            else
                v = char(string(x));
            end
        end

        function parsed = parseEditedValue(app, newData, template)
            if islogical(template)
                if islogical(newData)
                    parsed = logical(newData);
                else
                    parsed = any(strcmpi(strtrim(char(string(newData))), {'1','true','yes','on'}));
                end
                return;
            end

            if isnumeric(template)
                if isnumeric(newData)
                    parsed = newData;
                    return;
                end
                txt = strtrim(char(string(newData)));
                if isempty(txt)
                    parsed = [];
                    return;
                end
                try
                    parsed = eval(['[' txt ']']);
                catch
                    parsed = template;
                end
                return;
            end

            if iscell(template)
                txt = strtrim(char(string(newData)));
                if isempty(txt)
                    parsed = {};
                else
                    parts = regexp(txt, '\s*,\s*', 'split');
                    parsed = parts(~cellfun('isempty', parts));
                end
                return;
            end

            if isstring(template)
                parsed = string(newData);
                return;
            end

            if ischar(template)
                parsed = char(string(newData));
                return;
            end

            if isempty(template)
                txt = char(string(newData));
                if islogical(newData) || isnumeric(newData)
                    parsed = newData;
                else
                    try
                        val = eval(['[' txt ']']);
                        if isnumeric(val)
                            parsed = val;
                        else
                            parsed = txt;
                        end
                    catch
                        parsed = txt;
                    end
                end
                return;
            end

            parsed = newData;
        end

        function tf = isEditableParamValue(app, template) %#ok<INUSD>
            tf = ischar(template) || isstring(template) || islogical(template) || isnumeric(template) || iscell(template) || isempty(template);
        end

        function updateNodeParamFromTable(app, nodeType, tableData, rowIdx, newValue)
            if rowIdx < 1 || rowIdx > size(tableData, 1)
                return;
            end
            switch lower(char(string(nodeType)))
                case 'roiextract'
                    app.ensureExtractNode();
                case {'roipattern','roimanual','roigrid'}
                    app.ensureRoiNode(nodeType);
            end
            idx = app.findNodeIndex(nodeType);
            if isempty(idx)
                return;
            end
            params = app.Pipeline.nodes(idx).params;
            key = char(string(tableData{rowIdx,1}));
            if strcmpi(key, 'selectedFOVs')
                return;
            end
            if strcmpi(key, 'patternRect')
                newPos = app.parseRoiValue(newValue, app.getPatternCrop());
                if ~isempty(newPos)
                    app.upsertPattern(newPos);
                    app.renderCurrentFrame();
                end
                return;
            end
            if ~isfield(params, key)
                return;
            end
            template = params.(key);
            if ~app.isEditableParamValue(template)
                uialert(app.UIFigure, ['Parameter ' key ' must be edited via the dedicated ROI tool.'], 'Read-only parameter', 'Icon', 'warning');
                return;
            end
            params.(key) = app.parseEditedValue(newValue, template);
            if strcmpi(char(string(nodeType)), 'roiGrid') && strcmpi(key, 'gridCount')
                try
                    if double(params.(key)) > 1
                        params.mode = 'grid';
                    else
                        params.mode = 'fullframe';
                    end
                catch
                end
            end
            app.Pipeline.nodes(idx).params = params;
            pipelineSave(app.Pipeline);
            app.storePipelineLink(app.Pipeline);
            app.publishPipelineToWorkspace();
            app.markDirty(true);
        end

        function value = getParamField(app, params, fieldName, defaultValue) %#ok<INUSD>
            if isstruct(params) && isfield(params, fieldName)
                value = params.(fieldName);
            else
                value = defaultValue;
            end
        end

        function publishPipelineToWorkspace(app)
            if isempty(app.Pipeline)
                return;
            end
            varName = '';
            try
                names = evalin('base', 'who');
            catch
                names = {};
            end
            for i = 1:numel(names)
                try
                    candidate = evalin('base', names{i});
                    if isa(candidate, 'pipeline') && isprop(candidate, 'path') && strcmp(char(string(candidate.path)), char(string(app.Pipeline.path)))
                        varName = names{i};
                        break;
                    end
                catch
                end
            end
            if isempty(varName)
                varName = matlab.lang.makeValidName(char(string(app.Pipeline.strid)));
            end
            try
                assignin('base', varName, app.Pipeline);
            catch
            end
        end

        function id = nodeIdByType(app, typeName)
            id = '';
            idx = app.findNodeIndex(typeName);
            if ~isempty(idx)
                id = char(string(app.Pipeline.nodes(idx).id));
            end
        end

        function typeName = nodeTypeFromId(app, nodeId)
            typeName = '';
            for i = 1:numel(app.Pipeline.nodes)
                if strcmp(char(string(app.Pipeline.nodes(i).id)), char(string(nodeId)))
                    typeName = char(string(app.Pipeline.nodes(i).type));
                    return;
                end
            end
        end

        function crop = onOff(app, tf)
            if tf, crop = 'on'; else, crop = 'off'; end
        end

        function markDirty(app, tf)
            app.Dirty = logical(tf);
            app.refreshTitle();
        end

        function refreshTitle(app)
            if isempty(app.Project)
                base = 'Workflow';
            else
                base = ['Workflow - ' char(string(app.Project.io.file))];
            end
            if app.Dirty
                app.UIFigure.Name = [base ' *'];
            else
                app.UIFigure.Name = base;
            end
        end

        function SaveprojectMenuSelected(app, event) %#ok<INUSD>
            try
                if ~isempty(app.Pipeline)
                    pipelineSave(app.Pipeline);
                    app.publishPipelineToWorkspace();
                end
                if ~isempty(app.Project)
                    shallowSave(app.Project,'shallowObj');
                end
                app.markDirty(false);
            catch ME
                uialert(app.UIFigure, ME.message, 'Save error', 'Icon', 'error');
            end
        end

        function ensureWorkflowRunProfiles(app)
            if isempty(app.Project)
                return;
            end
            if ~isfield(app.Project.runProfiles,'workflow') || ~isstruct(app.Project.runProfiles.workflow)
                app.Project.runProfiles.workflow = struct();
            end
        end

        function persistDisplaySettings(app)
            if isempty(app.Project)
                return;
            end
            app.ensureWorkflowRunProfiles();
            S = struct();
            S.channelCfg = app.ChannelCfg;
            S.selectedChannelRow = app.SelectedChannelRow;
            S.zoomValue = app.ZoomSlider.Value;
            app.Project.runProfiles.workflow.display = S;
        end

        function restoreDisplaySettings(app, names)
            if isempty(app.Project) || ~isfield(app.Project.runProfiles,'workflow') || ~isfield(app.Project.runProfiles.workflow,'display')
                return;
            end
            S = app.Project.runProfiles.workflow.display;
            if isfield(S,'channelCfg') && numel(S.channelCfg) == numel(names)
                try
                    if isequal(string({S.channelCfg.name})', string(names(:)))
                        app.ChannelCfg = S.channelCfg;
                    end
                catch
                end
            end
            if isfield(S,'selectedChannelRow')
                app.SelectedChannelRow = max(1, round(double(S.selectedChannelRow)));
            end
            if isfield(S,'zoomValue') && isnumeric(S.zoomValue)
                app.ZoomSlider.Value = min(app.ZoomSlider.Limits(2), max(app.ZoomSlider.Limits(1), double(S.zoomValue)));
            end
        end

        function values = levelsToSliderValue(app, levels) %#ok<INUSD>
            levels = double(levels(:))';
            levels = max(0, min(65535, levels));
            values = 100 * log10(1 + levels) / log10(65536);
        end

        function levels = sliderToLevels(app, sliderVals) %#ok<INUSD>
            sliderVals = sort(double(sliderVals(:))');
            sliderVals = max(0, min(100, sliderVals));
            levels = round(10.^(sliderVals * log10(65536) / 100) - 1);
            levels = max(0, min(65535, levels));
        end

        function levels = parseLevelsString(app, raw, fallback) %#ok<INUSD>
            if isnumeric(raw)
                levels = sort(double(raw(:))');
            else
                txt = char(string(raw));
                nums = sscanf(strrep(strrep(txt,'[',' '),']',' '), '%f-%f');
                if numel(nums) < 2
                    nums = sscanf(strrep(strrep(txt,'[',' '),']',' '), '%f %f');
                end
                if numel(nums) < 2
                    levels = fallback;
                    return;
                end
                levels = sort(double(nums(1:2)'));
            end
            levels = max(0, min(65535, levels));
        end

        function pos = parseRoiValue(app, raw, fallback) %#ok<INUSD>
            if isnumeric(raw)
                vals = double(raw(:))';
            else
                txt = strtrim(char(string(raw)));
                if isempty(txt)
                    pos = fallback;
                    return;
                end
                try
                    vals = eval(['[' txt ']']); %#ok<EVLDIR>
                catch
                    pos = fallback;
                    return;
                end
            end
            if numel(vals) < 4 || ~isnumeric(vals)
                pos = fallback;
            else
                pos = double(vals(1:4));
            end
        end

        function [fovIndex, scopeLabel, ok] = confirmFovScope(app, actionLabel)
            ok = false;
            scopeLabel = '';
            if isempty(app.SelectedFov)
                fovIndex = [];
                return;
            end
            if contains(lower(char(string(actionLabel))), 'extract')
                idx = app.findNodeIndex('roiExtract');
            else
                idx = app.findNodeIndex(app.getSelectedRoiMode());
            end
            fovIndex = [];
            if ~isempty(idx)
                params = app.Pipeline.nodes(idx).params;
                if isfield(params, 'fovIndex') && ~isempty(params.fovIndex)
                    fovIndex = reshape(double(params.fovIndex), 1, []);
                end
            end
            if isempty(fovIndex)
                fovIndex = app.SelectedFov;
            end
            fovIndex = unique(fovIndex(isfinite(fovIndex) & fovIndex >= 1 & fovIndex <= app.getFovCount()));
            if isempty(fovIndex)
                fovIndex = app.SelectedFov;
            end
            labels = arrayfun(@(i) app.getFovLabel(i), fovIndex, 'UniformOutput', false);
            scopeLabel = strjoin(labels, ', ');
            ok = true;
        end

        function pos = getSelectedRoiPositionOrDefault(app)
            pos = [];
            if ~isempty(app.RoiEditHandle)
                try
                    if isvalid(app.RoiEditHandle)
                        pos = double(app.RoiEditHandle.Position);
                    end
                catch
                end
            end
            if isempty(pos) && ~isempty(app.PendingManualRect)
                pos = double(app.PendingManualRect(1,1:4));
            end
            fovObj = app.getSelectedFov();
            if isempty(pos) && ~isempty(fovObj) && ~isempty(app.SelectedRoi) && app.SelectedRoi >= 1 && app.SelectedRoi <= numel(fovObj.roi)
                pos = app.getRoiPosition(fovObj.roi(app.SelectedRoi));
            end
            if isempty(pos)
                pos = app.getDefaultPatternPosition();
            end
        end

        function selectRoi(app, idx)
            fovObj = app.getSelectedFov();
            if isempty(fovObj) || idx < 1 || idx > numel(fovObj.roi)
                return;
            end
            if idx <= numel(app.RoiDisplayMask) && ~app.RoiDisplayMask(idx)
                return;
            end
            app.PendingManualRect = zeros(0,4);
            app.SelectedRoi = idx;
            app.refreshExistingRoisTable();
            app.renderCurrentFrame();
        end

        function rebuildEditors(app)
            if strcmpi(app.getSelectedRoiMode(),'roiPattern')
                crop = app.getPatternCrop();
                if isempty(crop)
                    crop = app.getDefaultPatternPosition();
                end
                app.createPatternEditor(crop);
            else
                app.clearPatternEditor();
            end
            if strcmpi(app.getSelectedRoiMode(),'roiManual') && isempty(app.SelectedRoi) && ~isempty(app.PendingManualRect)
                app.createRoiEditor(app.PendingManualRect(1,1:4), 'pending');
                return;
            end
            fovObj = app.getSelectedFov();
            if isempty(fovObj) || isempty(app.SelectedRoi) || app.SelectedRoi < 1 || app.SelectedRoi > numel(fovObj.roi)
                app.clearRoiEditor();
                return;
            end
            if app.SelectedRoi <= numel(app.RoiDisplayMask) && ~app.RoiDisplayMask(app.SelectedRoi)
                app.clearRoiEditor();
                return;
            end
            pos = app.getRoiPosition(fovObj.roi(app.SelectedRoi));
            if isempty(pos)
                app.clearRoiEditor();
                return;
            end
            app.createRoiEditor(pos, 'selected');
        end

        function createPatternEditor(app, pos)
            app.clearPatternEditor();
            app.PatternHandle = drawrectangle(app.UIAxes, 'Position', pos, 'Color', [1 1 0], 'LineWidth', 1.6, 'LineStyle', '--');
            cm = uicontextmenu(app.UIFigure);
            uimenu(cm, 'Text', 'Delete pattern', 'MenuSelectedFcn', @(src,evt)app.deletePattern());
            app.PatternHandle.ContextMenu = cm;
            try
                addlistener(app.PatternHandle, 'ROIMoved', @(src,evt)app.syncPatternFromHandle());
            catch
            end
        end

        function clearPatternEditor(app)
            if ~isempty(app.PatternHandle)
                try
                    if isvalid(app.PatternHandle)
                        delete(app.PatternHandle);
                    end
                catch
                end
            end
            app.PatternHandle = [];
        end

        function createRoiEditor(app, pos, modeName)
            app.clearRoiEditor();
            if strcmpi(modeName, 'pending')
                color = [0 1 0];
            else
                color = [1 1 0];
            end
            app.RoiEditHandle = drawrectangle(app.UIAxes, 'Position', pos, 'Color', color, 'LineWidth', 1.6);
            try
                app.RoiEditListener = addlistener(app.RoiEditHandle, 'ROIMoved', @(src,evt)app.commitSelectedRoiPosition(src.Position));
            catch
                app.RoiEditListener = [];
            end
        end

        function clearRoiEditor(app)
            if ~isempty(app.RoiEditListener)
                try, delete(app.RoiEditListener); catch, end
            end
            app.RoiEditListener = [];
            if ~isempty(app.RoiEditHandle)
                try
                    if isvalid(app.RoiEditHandle)
                        delete(app.RoiEditHandle);
                    end
                catch
                end
            end
            app.RoiEditHandle = [];
        end

        function commitSelectedRoiPosition(app, pos)
            pos = double(pos(1:4));
            if strcmpi(app.getSelectedRoiMode(),'roimanual') && isempty(app.SelectedRoi)
                app.PendingManualRect = pos;
                app.markDirty(true);
                return;
            end
            fovObj = app.getSelectedFov();
            if isempty(fovObj) || isempty(app.SelectedRoi) || app.SelectedRoi < 1 || app.SelectedRoi > numel(fovObj.roi)
                return;
            end
            fovObj.roi(app.SelectedRoi).value(1:4) = uint16(round(pos));
            app.markDirty(true);
            app.refreshExistingRoisTable();
        end

        function upsertPattern(app, pos)
            idx = app.findNodeIndex('roiPattern');
            if isempty(idx)
                return;
            end
            params = app.Pipeline.nodes(idx).params;
            pat = struct();
            pat.crop = double(pos);
            pat.rect = double(pos);
            pat.fovIndex = app.SelectedFov;
            try
                pat.fovId = char(string(app.Project.fov(app.SelectedFov).id));
            catch
                pat.fovId = app.getFovLabel(app.SelectedFov);
            end
            pat.referenceFrame = app.SelectedFrame;
            chanIdx = find([app.ChannelCfg.enabled], 1, 'first');
            if isempty(chanIdx)
                chanIdx = 1;
            end
            pat.channelIndex = chanIdx;
            try
                pat.channel = char(string(app.Project.fov(app.SelectedFov).channel{chanIdx}));
            catch
                pat.channel = '';
            end
            params.patternList = pat;
            if isfield(params,'activePatternIndex'), params.activePatternIndex = 1; end
            if isfield(params,'referenceFrame'), params.referenceFrame = app.SelectedFrame; end
            if isfield(params,'channelIndex'), params.channelIndex = chanIdx; end
            if isfield(params,'channel'), params.channel = pat.channel; end
            if isfield(params,'crop'), params.crop = pat.crop; end
            if isfield(params,'fovIndex'), params.fovIndex = app.SelectedFov; end
            app.Pipeline.nodes(idx).params = params;
            pipelineSave(app.Pipeline);
            app.storePipelineLink(app.Pipeline);
            app.publishPipelineToWorkspace();
            app.markDirty(true);
            app.refreshRoiTables();
        end

        function posList = collectRoiPositions(app, roiArray) %#ok<INUSD>
            posList = zeros(0,4);
            try
                n = numel(roiArray);
            catch
                return;
            end
            tmp = zeros(0,4);
            for ii = 1:n
                try
                    if numel(roiArray(ii).value) >= 4
                        tmp(end+1,:) = double(reshape(roiArray(ii).value(1:4),1,[])); %#ok<AGROW>
                    end
                catch
                end
            end
            posList = tmp;
        end

        function AdddataButtonPushed(app, event) %#ok<INUSD>
            if isempty(app.Project)
                return;
            end
            nBefore = app.getFovCount();
            dlg = addDataGUI(app.Project, []);
            if ~isempty(dlg) && isvalid(dlg)
                waitfor(dlg.UIFigure);
            end
            app.Cache = containers.Map('KeyType','char','ValueType','any');
            if isempty(app.SelectedFov) && app.getFovCount() > 0
                app.SelectedFov = 1;
            end
            if app.getFovCount() ~= nBefore
                app.markDirty(true);
            end
            app.refreshAll();
        end

        function UIDataLoaderTableCellEdit(app, event)
            if isempty(event.Indices) || event.Indices(2) ~= 2
                app.refreshDataloaderTable();
                return;
            end
            app.updateNodeParamFromTable('dataLoader', app.UIDataLoaderTable.Data, event.Indices(1), event.NewData);
            app.refreshDataloaderTable();
        end

        function UIFOVTableSelectionChanged(app, event)
            if app.Suppress || isempty(event.Selection)
                return;
            end
            app.SelectedFov = event.Selection(1);
            app.SelectedFrame = 1;
            app.Cache = containers.Map('KeyType','char','ValueType','any');
            app.refreshAll();
        end

        function UIFOVTableCellEdit(app, event)
            if app.Suppress || isempty(event.Indices) || event.Indices(2) ~= 1
                return;
            end
            if logical(event.NewData)
                app.SelectedFov = event.Indices(1);
                app.SelectedFrame = 1;
                app.Cache = containers.Map('KeyType','char','ValueType','any');
            end
            app.refreshAll();
        end

        function UIDisplayChannelTableSelectionChanged(app, event)
            if app.Suppress || isempty(event.Selection)
                return;
            end
            app.SelectedChannelRow = event.Selection(1);
            app.refreshDisplayControls();
        end

        function UIDisplayChannelTableCellEdit(app, event)
            if app.Suppress || isempty(event.Indices)
                return;
            end
            row = event.Indices(1); col = event.Indices(2);
            if row < 1 || row > numel(app.ChannelCfg)
                return;
            end
            switch col
                case 1
                    app.ChannelCfg(row).enabled = logical(event.NewData);
                case 3
                    app.ChannelCfg(row).levels = app.parseLevelsString(event.NewData, app.ChannelCfg(row).levels);
                    app.ChannelCfg(row).auto = false;
                case 5
                    if isnumeric(event.NewData)
                        app.ChannelCfg(row).weight = double(event.NewData);
                    else
                        tmp = str2double(char(string(event.NewData)));
                        if isfinite(tmp)
                            app.ChannelCfg(row).weight = tmp;
                        end
                    end
                case 6
                    app.ChannelCfg(row).auto = logical(event.NewData);
            end
            app.persistDisplaySettings();
            app.markDirty(true);
            app.refreshDisplayChannels();
            app.renderCurrentFrame();
        end
        function LevelsSliderValueChanged(app, event) %#ok<INUSD>
            if isempty(app.ChannelCfg)
                return;
            end
            row = min(max(1,app.SelectedChannelRow), numel(app.ChannelCfg));
            app.ChannelCfg(row).levels = app.sliderToLevels(double(app.LevelsSlider.Value));
            app.ChannelCfg(row).auto = false;
            app.persistDisplaySettings();
            app.markDirty(true);
            app.refreshDisplayChannels();
            app.renderCurrentFrame();
        end

        function FrameSliderValueChanged(app, event) %#ok<INUSD>
            app.SelectedFrame = max(1, round(app.FrameSlider.Value));
            app.FrameEditField.Value = app.SelectedFrame;
            app.renderCurrentFrame();
        end

        function FrameEditFieldValueChanged(app, event) %#ok<INUSD>
            app.SelectedFrame = min(app.getMaxFrame(), max(1, round(app.FrameEditField.Value)));
            app.FrameSlider.Value = app.SelectedFrame;
            app.FrameEditField.Value = app.SelectedFrame;
            app.renderCurrentFrame();
        end

        function ZoomSliderValueChanged(app, event) %#ok<INUSD>
            app.persistDisplaySettings();
            app.markDirty(true);
            app.applyZoom();
        end

        function DisplaycolorColorPickerValueChanged(app, event) %#ok<INUSD>
            if isempty(app.ChannelCfg)
                return;
            end
            row = min(max(1,app.SelectedChannelRow), numel(app.ChannelCfg));
            app.ChannelCfg(row).color = app.DisplaycolorColorPicker.Value;
            app.persistDisplaySettings();
            app.markDirty(true);
            app.refreshDisplayChannels();
            app.renderCurrentFrame();
        end

        function ResetzoomButtonPushed(app, event) %#ok<INUSD>
            app.ZoomSlider.Value = 0;
            app.persistDisplaySettings();
            app.markDirty(true);
            app.applyZoom();
        end

        function PanButtonPushed(app, event) %#ok<INUSD>
            try
                p = pan(app.UIFigure);
                if strcmpi(p.Enable,'on')
                    p.Enable = 'off';
                    app.PanButton.Text = 'Pan';
                else
                    p.Enable = 'on';
                    app.PanButton.Text = 'Pan on';
                end
            catch
            end
        end

        function UIFigureWindowKeyPress(app, event)
            switch lower(event.Key)
                case 'rightarrow'
                    app.SelectedFrame = min(app.getMaxFrame(), app.SelectedFrame + 1);
                case 'leftarrow'
                    app.SelectedFrame = max(1, app.SelectedFrame - 1);
                otherwise
                    return;
            end
            app.FrameSlider.Value = app.SelectedFrame;
            app.FrameEditField.Value = app.SelectedFrame;
            app.renderCurrentFrame();
        end

        function ROIgenerationmodeButtonGroupSelectionChanged(app, event) %#ok<INUSD>
            if app.Suppress
                return;
            end
            app.ensureRoiNode(app.getSelectedRoiMode());
            app.PreviewRoiPositions = zeros(0,4);
            app.refreshAll();
        end

        function UIROIParametersTableCellEdit(app, event)
            if isempty(event.Indices) || event.Indices(2) ~= 2
                app.refreshRoiTables();
                return;
            end
            app.updateNodeParamFromTable(app.getSelectedRoiMode(), app.UIROIParametersTable.Data, event.Indices(1), event.NewData);
            app.refreshRoiTables();
            app.renderCurrentFrame();
        end

        function DrawpatternButtonPushed(app, event) %#ok<INUSD>
            if isempty(app.Project) || isempty(app.getSelectedFov())
                return;
            end
            mode = lower(app.getSelectedRoiMode());
            switch mode
                case 'roimanual'
                    pos = app.getSelectedRoiPositionOrDefault();
                    app.SelectedRoi = [];
                    app.PendingManualRect = double(pos);
                    app.renderCurrentFrame();
                otherwise
                    app.ensureRoiNode('roiPattern');
                    pos = app.getPatternCrop();
                    if isempty(pos)
                        pos = app.getDefaultPatternPosition();
                    end
                    app.upsertPattern(pos);
                    app.renderCurrentFrame();
            end
        end

        function TestROIdetectionButtonPushed(app, event) %#ok<INUSD>
            idx = app.findNodeIndex('roiPattern');
            if isempty(idx) || isempty(app.SelectedFov)
                return;
            end
            app.syncPatternFromHandle();
            fovObj = app.getSelectedFov();
            origRoi = fovObj.roi;
            d = uiprogressdlg(app.UIFigure,'Title','ROI pattern','Message','Testing pattern detection on current FOV...');
            try, d.Indeterminate = 'on'; catch, end
            try
                ctx = struct('shallow', app.Project, 'roiPattern', app.Pipeline.nodes(idx).params, 'fovIndex', app.SelectedFov, 'interactive', false, 'saveProgress', false);
                roiPattern.process(ctx);
                app.PreviewRoiPositions = app.collectRoiPositions(fovObj.roi);
                fovObj.roi = origRoi;
            catch ME
                try, fovObj.roi = origRoi; catch, end
                close(d);
                uialert(app.UIFigure, ME.message, 'ROI pattern error', 'Icon', 'error');
                return;
            end
            close(d);
            app.renderCurrentFrame();
        end

        function GenerateROIsButtonPushed(app, event) %#ok<INUSD>
            mode = app.getSelectedRoiMode();
            app.ensureRoiNode(mode);
            [fovIndex, scopeLabel, ok] = app.confirmFovScope('Generate ROIs');
            if ~ok
                return;
            end
            try
                switch lower(mode)
                    case 'roimanual'
                        srcPos = app.getSelectedRoiPositionOrDefault();
                        if isempty(srcPos)
                            uialert(app.UIFigure,'Draw or select one ROI first.','Manual ROI','Icon','warning');
                            return;
                        end
                        createdCurrent = false;
                        for ff = reshape(fovIndex,1,[])
                            if ff == app.SelectedFov
                                if isempty(app.PendingManualRect)
                                    continue;
                                end
                                app.Project.fov(ff).addROI(uint16(round(srcPos)), app.Project.fov(ff).id);
                                createdCurrent = true;
                            else
                                app.Project.fov(ff).addROI(uint16(round(srcPos)), app.Project.fov(ff).id);
                            end
                        end
                        if createdCurrent
                            app.SelectedRoi = numel(app.Project.fov(app.SelectedFov).roi);
                        end
                        app.PendingManualRect = zeros(0,4);
                        app.markDirty(true);
                    case 'roipattern'
                        app.syncPatternFromHandle();
                        d = uiprogressdlg(app.UIFigure,'Title','ROI pattern','Message',['Applying ROI pattern to ' scopeLabel '...']);
                        try, d.Indeterminate = 'on'; catch, end
                        ctx = struct('shallow', app.Project, 'roiPattern', app.Pipeline.nodes(app.findNodeIndex('roiPattern')).params, 'interactive', false, 'fovIndex', fovIndex);
                        roiPattern.process(ctx);
                        close(d);
                        app.PreviewRoiPositions = zeros(0,4);
                        app.markDirty(true);
                    case 'roigrid'
                        idxGrid = app.findNodeIndex('roiGrid');
                        params = app.Pipeline.nodes(idxGrid).params;
                        if isfield(params,'gridCount')
                            try
                                if double(params.gridCount) > 1
                                    params.mode = 'grid';
                                else
                                    params.mode = 'fullframe';
                                end
                            catch
                            end
                            app.Pipeline.nodes(idxGrid).params = params;
                            pipelineSave(app.Pipeline);
                            app.storePipelineLink(app.Pipeline);
                            app.publishPipelineToWorkspace();
                        end
                        d = uiprogressdlg(app.UIFigure,'Title','ROI grid','Message',['Generating ROI grid on ' scopeLabel '...']);
                        try, d.Indeterminate = 'on'; catch, end
                        ctx = struct('shallow', app.Project, 'roiGrid', app.Pipeline.nodes(idxGrid).params, 'interactive', false, 'fovIndex', fovIndex);
                        roiGrid.process(ctx);
                        close(d);
                        app.PreviewRoiPositions = zeros(0,4);
                        app.markDirty(true);
                end
            catch ME
                if exist('d','var') && isvalid(d)
                    close(d);
                end
                uialert(app.UIFigure, ME.message, 'ROI generation error', 'Icon', 'error');
                return;
            end
            app.refreshAll();
        end

        function UIExistingROIsTableCellEdit(app, event)
            if app.Suppress || isempty(event.Indices)
                return;
            end
            row = event.Indices(1);
            col = event.Indices(2);
            if row < 1
                return;
            end
            fovObj = app.getSelectedFov();
            if isempty(fovObj) || row > numel(fovObj.roi)
                return;
            end
            switch col
                case 1
                    if row <= numel(app.RoiDisplayMask)
                        app.RoiDisplayMask(row) = logical(event.NewData);
                        if ~app.RoiDisplayMask(row) && isequal(app.SelectedRoi, row)
                            app.SelectedRoi = [];
                        end
                    end
                case 3
                    newPos = app.parseRoiValue(event.NewData, app.getRoiPosition(fovObj.roi(row)));
                    if ~isempty(newPos)
                        fovObj.roi(row).value(1:4) = uint16(round(newPos));
                        app.SelectedRoi = row;
                        app.PendingManualRect = zeros(0,4);
                        app.markDirty(true);
                    end
            end
            app.refreshExistingRoisTable();
            app.renderCurrentFrame();
        end

        function UIExistingROIsTableSelectionChanged(app, event)
            if app.Suppress || isempty(event.Selection)
                return;
            end
            app.selectRoi(event.Selection(1));
        end

        function SelectallButtonPushed(app, event) %#ok<INUSD>
            if isempty(app.RoiDisplayMask), return; end
            app.RoiDisplayMask(:) = true;
            app.refreshExistingRoisTable();
            app.renderCurrentFrame();
        end

        function DeselectallButtonPushed(app, event) %#ok<INUSD>
            if isempty(app.RoiDisplayMask), return; end
            app.RoiDisplayMask(:) = false;
            app.SelectedRoi = [];
            app.refreshExistingRoisTable();
            app.renderCurrentFrame();
        end

        function RemoveselectedButtonPushed(app, event) %#ok<INUSD>
            fovObj = app.getSelectedFov();
            if isempty(fovObj) || isempty(app.RoiDisplayMask)
                return;
            end
            removeIdx = find(app.RoiDisplayMask);
            if isempty(removeIdx)
                return;
            end
            msg = sprintf('Delete ROIs %s for %s?', mat2str(removeIdx), app.getFovLabel(app.SelectedFov));
            choice = uiconfirm(app.UIFigure, msg, 'Delete ROIs', 'Options', {'Delete','Cancel'}, 'DefaultOption', 'Cancel', 'CancelOption', 'Cancel');
            if ~strcmp(choice,'Delete')
                return;
            end
            keepIdx = setdiff(1:numel(fovObj.roi), removeIdx);
            if isempty(keepIdx)
                fovObj.roi = roi;
            else
                fovObj.roi = fovObj.roi(keepIdx);
            end
            app.RoiDisplayMask = false(0,1);
            app.SelectedRoi = [];
            app.PreviewRoiPositions = zeros(0,4);
            app.markDirty(true);
            app.refreshAll();
        end

        function UIROIsExtractionTableCellEdit(app, event)
            if isempty(event.Indices) || event.Indices(2) ~= 2
                app.refreshExtractionTable();
                return;
            end
            app.updateNodeParamFromTable('roiExtract', app.UIROIsExtractionTable.Data, event.Indices(1), event.NewData);
            app.refreshExtractionTable();
        end

        function ExtractROIsButtonPushed(app, event) %#ok<INUSD>
            app.ensureExtractNode();
            [fovIndex, scopeLabel, ok] = app.confirmFovScope('Extract ROI crops');
            if ~ok
                return;
            end
            d = uiprogressdlg(app.UIFigure,'Title','ROI extraction','Message',['Extracting ROI crops on ' scopeLabel '...']);
            try
                ctx = struct('shallow', app.Project, 'roiExtract', app.Pipeline.nodes(app.findNodeIndex('roiExtract')).params, 'interactive', false, 'fovIndex', fovIndex);
                roiExtract.process(ctx);
                app.markDirty(true);
            catch ME
                close(d);
                uialert(app.UIFigure, ME.message, 'ROI extraction error', 'Icon', 'error');
                return;
            end
            close(d);
            app.refreshAll();
        end

        function UIFigureCloseRequest(app, event) %#ok<INUSD>
            if app.Dirty
                choice = uiconfirm(app.UIFigure,'Unsaved changes. Save project before closing?','Close workflow', ...
                    'Options',{'Save','Discard','Cancel'},'DefaultOption','Save','CancelOption','Cancel');
                if strcmp(choice,'Cancel')
                    return;
                end
                if strcmp(choice,'Save')
                    try
                        if ~isempty(app.Pipeline)
                            pipelineSave(app.Pipeline);
                            app.publishPipelineToWorkspace();
                        end
                        if ~isempty(app.Project)
                            shallowSave(app.Project,'shallowObj');
                        end
                        app.markDirty(false);
                    catch ME
                        uialert(app.UIFigure,ME.message,'Save error','Icon','error');
                        return;
                    end
                end
            end
            delete(app);
        end
    end

    methods (Access = private)
        function createComponents(app)
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 1063 671];
            app.UIFigure.Name = 'MATLAB App';

            app.FileMenu = uimenu(app.UIFigure); app.FileMenu.Text = 'File';
            app.EditMenu = uimenu(app.UIFigure); app.EditMenu.Text = 'Edit';
            app.ViewMenu = uimenu(app.UIFigure); app.ViewMenu.Text = 'View';
            app.AboutMenu = uimenu(app.UIFigure); app.AboutMenu.Text = 'About';

            app.UIAxes = uiaxes(app.UIFigure); title(app.UIAxes,'Display','Interpreter','none'); xlabel(app.UIAxes,'X'); ylabel(app.UIAxes,'Y'); zlabel(app.UIAxes,'Z'); app.UIAxes.Position = [461 82 590 580];
            app.TabGroup = uitabgroup(app.UIFigure); app.TabGroup.Position = [11 12 450 650];

            app.DataloaderTab = uitab(app.TabGroup); app.DataloaderTab.Title = 'Dataloader';
            app.UIDataLoaderTable = uitable(app.DataloaderTab); app.UIDataLoaderTable.Position = [10 366 421 234];
            app.AdddataButton = uibutton(app.DataloaderTab,'push'); app.AdddataButton.Position = [11 302 111 54]; app.AdddataButton.Text = 'Add data....';

            app.DisplayTab = uitab(app.TabGroup); app.DisplayTab.Title = 'Display';
            app.UIFOVTable = uitable(app.DisplayTab); app.UIFOVTable.ColumnName = {'Select FOV'; 'Name'}; app.UIFOVTable.Position = [10 435 431 185];
            app.selectedFOVEditFieldLabel = uilabel(app.DisplayTab); app.selectedFOVEditFieldLabel.HorizontalAlignment = 'right'; app.selectedFOVEditFieldLabel.Position = [18 403 81 22]; app.selectedFOVEditFieldLabel.Text = 'selected FOV:';
            app.selectedFOVEditField = uitextarea(app.DisplayTab); app.selectedFOVEditField.Editable = 'off'; app.selectedFOVEditField.Tooltip = {'Display : path, size of image'}; app.selectedFOVEditField.Position = [114 361 320 64];
            app.UIDisplayChannelTable = uitable(app.DisplayTab); app.UIDisplayChannelTable.ColumnName = {'Display'; 'Name'; 'Levels'; 'RGB'; 'Weights'; 'auto'}; app.UIDisplayChannelTable.Position = [11 161 421 185];
            app.LevelsSliderLabel = uilabel(app.DisplayTab); app.LevelsSliderLabel.HorizontalAlignment = 'right'; app.LevelsSliderLabel.Position = [6 125 40 22]; app.LevelsSliderLabel.Text = 'Levels';
            app.LevelsSlider = uislider(app.DisplayTab,'range'); app.LevelsSlider.Position = [68 134 150 3];
            app.FrameSliderLabel = uilabel(app.DisplayTab); app.FrameSliderLabel.HorizontalAlignment = 'right'; app.FrameSliderLabel.Position = [8 78 40 22]; app.FrameSliderLabel.Text = 'Frame';
            app.FrameSlider = uislider(app.DisplayTab); app.FrameSlider.Position = [70 87 150 3];
            app.FrameEditFieldLabel = uilabel(app.DisplayTab); app.FrameEditFieldLabel.HorizontalAlignment = 'right'; app.FrameEditFieldLabel.Position = [241 74 40 22]; app.FrameEditFieldLabel.Text = 'Frame';
            app.FrameEditField = uieditfield(app.DisplayTab,'numeric'); app.FrameEditField.Position = [291 74 100 22];
            app.ZoomSliderLabel = uilabel(app.DisplayTab); app.ZoomSliderLabel.HorizontalAlignment = 'right'; app.ZoomSliderLabel.Position = [10 28 36 22]; app.ZoomSliderLabel.Text = 'Zoom';
            app.ZoomSlider = uislider(app.DisplayTab); app.ZoomSlider.Position = [68 37 150 3];
            app.DisplaycolorColorPickerLabel = uilabel(app.DisplayTab); app.DisplaycolorColorPickerLabel.HorizontalAlignment = 'right'; app.DisplaycolorColorPickerLabel.Position = [255 116 77 22]; app.DisplaycolorColorPickerLabel.Text = 'Display color:';
            app.DisplaycolorColorPicker = uicolorpicker(app.DisplayTab); app.DisplaycolorColorPicker.Position = [347 116 38 22];
            app.ResetzoomButton = uibutton(app.DisplayTab,'push'); app.ResetzoomButton.Position = [240 23 100 23]; app.ResetzoomButton.Text = 'Reset zoom';
            app.PanButton = uibutton(app.DisplayTab,'push'); app.PanButton.Position = [347 23 100 23]; app.PanButton.Text = 'Pan';

            app.ROIsIDTab = uitab(app.TabGroup); app.ROIsIDTab.Title = 'ROIs ID';
            app.ROIgenerationmodeButtonGroup = uibuttongroup(app.ROIsIDTab); app.ROIgenerationmodeButtonGroup.Title = 'ROI generation mode'; app.ROIgenerationmodeButtonGroup.Position = [8 526 190 93];
            app.ManualselectionmanualButton = uiradiobutton(app.ROIgenerationmodeButtonGroup); app.ManualselectionmanualButton.Text = 'Manual selection (manual)'; app.ManualselectionmanualButton.Position = [11 47 163 22]; app.ManualselectionmanualButton.Value = true;
            app.PatterndetectionpatternButton = uiradiobutton(app.ROIgenerationmodeButtonGroup); app.PatterndetectionpatternButton.Text = 'Pattern detection (pattern)'; app.PatterndetectionpatternButton.Position = [11 25 161 22];
            app.GridselectiongridButton = uiradiobutton(app.ROIgenerationmodeButtonGroup); app.GridselectiongridButton.Text = 'Grid selection (grid)'; app.GridselectiongridButton.Position = [11 3 127 22];
            app.UIROIParametersTable = uitable(app.ROIsIDTab); app.UIROIParametersTable.Position = [11 342 420 174];
            app.DrawpatternButton = uibutton(app.ROIsIDTab,'push'); app.DrawpatternButton.Position = [13 290 170 44]; app.DrawpatternButton.Text = 'Draw pattern';
            app.UIExistingROIsTable = uitable(app.ROIsIDTab); app.UIExistingROIsTable.Position = [11 71 420 185];
            app.TestROIdetectionButton = uibutton(app.ROIsIDTab,'push'); app.TestROIdetectionButton.Position = [191 293 114 38]; app.TestROIdetectionButton.Text = 'Test ROI detection';
            app.GenerateROIsButton = uibutton(app.ROIsIDTab,'push'); app.GenerateROIsButton.Position = [320 296 100 31]; app.GenerateROIsButton.Text = 'Generate ROIs';
            app.SelectallButton = uibutton(app.ROIsIDTab,'push'); app.SelectallButton.Position = [10 27 100 23]; app.SelectallButton.Text = 'Select all';
            app.DeselectallButton = uibutton(app.ROIsIDTab,'push'); app.DeselectallButton.Position = [119 27 100 23]; app.DeselectallButton.Text = 'Deselect all';
            app.RemoveselectedButton = uibutton(app.ROIsIDTab,'push'); app.RemoveselectedButton.Position = [228 26 108 23]; app.RemoveselectedButton.Text = 'Remove selected';

            app.ROIsExtractionTab = uitab(app.TabGroup); app.ROIsExtractionTab.Title = 'ROIs Extraction';
            app.UIROIsExtractionTable = uitable(app.ROIsExtractionTab); app.UIROIsExtractionTable.Position = [10 326 431 294];
            app.ExtractROIsButton = uibutton(app.ROIsExtractionTab,'push'); app.ExtractROIsButton.Position = [11 252 131 64]; app.ExtractROIsButton.Text = 'Extract ROIs';

            app.UIFigure.Visible = 'on';
        end
    end

    methods (Access = public)
        function app = workflow(varargin)
            createComponents(app)
            registerApp(app, app.UIFigure)
            runStartupFcn(app, @(app)startupFcn(app, varargin{:}))
            if nargout == 0
                clear app
            end
        end

        function delete(app)
            if isvalid(app.UIFigure)
                delete(app.UIFigure)
            end
        end
    end
end



