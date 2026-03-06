classdef workflow < matlab.apps.AppBase



    properties (Access = public)

        UIFigure                       matlab.ui.Figure

        FileMenu                       matlab.ui.container.Menu

        EditMenu                       matlab.ui.container.Menu

        ViewMenu                       matlab.ui.container.Menu

        AboutMenu                      matlab.ui.container.Menu

        TabGroup                       matlab.ui.container.TabGroup

        FOVsPositionsPanel             matlab.ui.container.Panel

        UIDisplayPanel                 matlab.ui.container.Panel

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

        SelectedRoiRows double = zeros(1,0)

        RoiEditHandle = []

        RoiEditListener = []

        PreviewRoiPositions double = zeros(0,4)

        PendingManualRect double = zeros(0,4)

        FovCropHandle = []

        FovCropListener = []

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

            cmAxes = uicontextmenu(app.UIFigure);

            uimenu(cmAxes, 'Text', 'Draw inclusion crop (current FOV)', 'MenuSelectedFcn', @(src,evt)app.DrawFovCropMenuSelected());

            uimenu(cmAxes, 'Text', 'Clear inclusion crop (current FOV)', 'MenuSelectedFcn', @(src,evt)app.ClearFovCropMenuSelected());

            app.UIAxes.ContextMenu = cmAxes;



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



            app.UIExistingROIsTable.ColumnName = {'Display';'Index';'ROI';'Value'};

            app.UIExistingROIsTable.RowName = {};

            app.UIExistingROIsTable.ColumnEditable = [true false false true];

            app.UIExistingROIsTable.ColumnWidth = {55,50,140,155};

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

            if strcmpi(mode,'roiPattern') && ~isempty(data)

                keys = string(data(:,1));

                keep = ~(keys == "crop" | keys == "fallbackFullFrame" | keys == "patternList" | keys == "activePatternIndex" | keys == "pattern" | keys == "patternImage");

                data = data(keep,:);

            end

            cropPoly = app.getSelectedFovCropPolygon();

            if isempty(cropPoly)

                cropTxt = '<none>';

            else

                cropTxt = mat2str(round(double(cropPoly)));

            end

            data(end+1,:) = {'fovCrop', cropTxt}; %#ok<AGROW>

            if strcmpi(mode,'roiPattern')

                crop = app.getPatternCrop();

                if isempty(crop)

                    cropTxt = '<draw pattern>';

                else

                    cropTxt = mat2str(round(crop));

                end

                data(end+1,:) = {'patternRect', cropTxt}; %#ok<AGROW>

                srcFov = '<none>';

                srcFrame = '<none>';

                srcChannel = '<none>';

                try

                    if isfield(params,'pattern') && isstruct(params.pattern) && ~isempty(params.pattern)

                        pat = params.pattern;

                        if isfield(pat,'fovIndex') && ~isempty(pat.fovIndex)

                            srcFov = sprintf('%d', round(double(pat.fovIndex(1))));

                        end

                        if isfield(pat,'referenceFrame') && ~isempty(pat.referenceFrame)

                            srcFrame = sprintf('%d', round(double(pat.referenceFrame(1))));

                        end

                        if isfield(pat,'channel') && ~isempty(pat.channel)

                            srcChannel = char(string(pat.channel));

                        elseif isfield(pat,'channelIndex') && ~isempty(pat.channelIndex)

                            srcChannel = sprintf('%d', round(double(pat.channelIndex(1))));

                        end

                    end

                catch

                end

                data(end+1,:) = {'patternSourceFOV', srcFov}; %#ok<AGROW>

                data(end+1,:) = {'patternSourceFrame', srcFrame}; %#ok<AGROW>

                data(end+1,:) = {'patternSourceChannel', srcChannel}; %#ok<AGROW>

            end

            app.UIROIParametersTable.Data = data;

            app.refreshExistingRoisTable();

        end



        function refreshExistingRoisTable(app)

            fovObj = app.getSelectedFov();

            if isempty(fovObj) || isempty(fovObj.roi)

                app.RoiDisplayMask = false(0,1);

                app.SelectedRoi = [];

                app.UIExistingROIsTable.Data = cell(0,4);

                return;

            end

            if numel(fovObj.roi) == 1

                try

                    if isempty(fovObj.roi(1).id)

                        app.RoiDisplayMask = false(0,1);

                        app.SelectedRoi = [];

                        app.UIExistingROIsTable.Data = cell(0,4);

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

            data = cell(nRoi,4);

            for i = 1:nRoi

                data{i,1} = app.RoiDisplayMask(i);

                data{i,2} = i;

                data{i,3} = app.describeRoi(fovObj.roi(i), i);

                pos = app.getRoiPosition(fovObj.roi(i));

                if isempty(pos)

                    data{i,4} = '';

                else

                    data{i,4} = mat2str(round(pos));

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

            app.UIROIsExtractionTable.Data = data;

        end



        function renderCurrentFrame(app)

            app.clearFovCropEditor();

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

            autoChanged = false;

            for i = active(:)'

                if i <= numel(app.ChannelCfg) && app.ChannelCfg(i).auto && ~isempty(imgs{i})

                    imd = double(imgs{i});

                    lo = min(imd(:));

                    hi = max(imd(:));

                    if ~isfinite(lo), lo = 0; end

                    if ~isfinite(hi) || hi <= lo, hi = lo + 1; end

                    newLv = [lo hi];

                    if any(abs(double(app.ChannelCfg(i).levels) - newLv) > eps(max(newLv)))

                        app.ChannelCfg(i).levels = newLv;

                        autoChanged = true;

                    end

                end

            end

            rgb = workflowui.composeBlendImage(imgs, app.ChannelCfg);

            if autoChanged

                app.refreshDisplayChannels();

            end

            if isempty(rgb)

                title(app.UIAxes,'Unable to load image','Interpreter','none');

                app.clearPatternEditor();

                app.clearRoiEditor();

                return;

            end

            hIm = image(app.UIAxes, rgb);

            try

                if ~isempty(app.UIAxes.ContextMenu)

                    hIm.ContextMenu = app.UIAxes.ContextMenu;

                end

            catch

            end

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

                    lw = 1.6;

                    if isequal(app.SelectedRoi, i)

                        edge = [1 1 0];

                        lw = 2.4;

                    end

                    x = [pos(1) pos(1)+pos(3) pos(1)+pos(3) pos(1)];

                    y = [pos(2) pos(2) pos(2)+pos(4) pos(2)+pos(4)];

                    p = patch(app.UIAxes, x, y, edge, 'FaceAlpha', 0.02, 'EdgeColor', 'none');

                    try, p.ContextMenu = app.UIAxes.ContextMenu; catch, end

                    p.ButtonDownFcn = @(src,evt)app.selectRoi(i);

                    hRect = rectangle(app.UIAxes,'Position',pos,'EdgeColor',edge,'LineWidth',lw);

                    try, hRect.ContextMenu = app.UIAxes.ContextMenu; catch, end

                    hRect.ButtonDownFcn = @(src,evt)app.selectRoi(i);

                    ht=text(app.UIAxes, pos(1), max(1,pos(2)-2), sprintf('%d', i), 'Color', edge, 'FontSize', 14, 'FontWeight', 'bold', 'Interpreter', 'none', 'ButtonDownFcn', @(src,evt)app.selectRoi(i));

                    try, ht.ContextMenu = app.UIAxes.ContextMenu; catch, end

                end

            end

            for i = 1:size(app.PreviewRoiPositions,1)

                pos = app.PreviewRoiPositions(i,:);

                hPrev=rectangle(app.UIAxes,'Position',pos,'EdgeColor',[1 0 1],'LineWidth',1.2,'LineStyle','--');

                try, hPrev.ContextMenu = app.UIAxes.ContextMenu; catch, end

                text(app.UIAxes, pos(1), max(1,pos(2)-2), sprintf('T%d', i), 'Color', [1 0 1], 'FontSize', 13, 'FontWeight', 'bold', 'Interpreter', 'none');

            end

            app.drawGridPreview(size(rgb,2), size(rgb,1));

            cropPoly = app.getSelectedFovCropPolygon();

            if ~isempty(cropPoly) && size(cropPoly,2) == 2

                xp = cropPoly(:,1); yp = cropPoly(:,2);

                if ~isequal(cropPoly(1,:), cropPoly(end,:))

                    xp(end+1) = cropPoly(1,1); %#ok<AGROW>

                    yp(end+1) = cropPoly(1,2); %#ok<AGROW>

                end

                plot(app.UIAxes, xp, yp, 'Color', [0 1 0], 'LineWidth', 1.8, 'LineStyle', '--');

                text(app.UIAxes, xp(1), max(1, yp(1)-4), 'crop', 'Color', [0 1 0], 'FontSize', 12, 'FontWeight', 'bold', 'Interpreter', 'none');

            end

            hold(app.UIAxes,'off');

            title(app.UIAxes, sprintf('%s | frame %d', app.getFovLabel(app.SelectedFov), app.SelectedFrame), 'Interpreter', 'none');

            app.rebuildEditors();

            app.applyZoom();

            drawnow limitrate nocallbacks;

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

            app.upsertPattern(double(app.PatternHandle.Position));

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

            if isfield(params, 'pattern')

                params.pattern = struct([]);

            end

            if isfield(params, 'patternList')

                params.patternList = struct([]); % legacy cleanup

            end

            if isfield(params, 'activePatternIndex')

                params.activePatternIndex = 1; % legacy cleanup

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



        function txt = formatFovIndexList(app, fovIndex) %#ok<INUSD>

            fovIndex = unique(round(double(fovIndex(:)')), 'stable');

            if isempty(fovIndex)

                txt = '<none>';

                return;

            end

            txt = strjoin(arrayfun(@(k) sprintf('%d', k), fovIndex, 'UniformOutput', false), ', ');

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

            pat = struct([]);

            if isfield(params,'pattern') && ~isempty(params.pattern)

                pat = params.pattern;

            end

            if isempty(pat)

                return;

            end

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

                if strcmpi(fn{i}, 'fovIndex')

                    vv = double(s.(fn{i}));

                    vv = vv(isfinite(vv));

                    vv = unique(round(vv(:)'), 'stable');

                    if ~isempty(vv) && isequal(vv, 1:app.getFovCount())

                        t{i,2} = 'all';

                    else

                        t{i,2} = app.compactNumericString(vv);

                    end

                else

                    t{i,2} = app.tableValue(s.(fn{i}));

                end

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

                v = app.compactNumericString(x);

            elseif iscell(x)

                v = strjoin(cellstr(string(x(:)')),', ');

            elseif isstruct(x)

                v = sprintf('<struct %dx%d>',size(x,1),size(x,2));

            else

                v = char(string(x));

            end

        end



        function txt = compactNumericString(app, arr) %#ok<INUSD>

            arr = double(arr(:)');

            if isempty(arr)

                txt = '[]';

                return;

            end

            if numel(arr) == 1

                txt = sprintf('%g', arr);

                return;

            end

            if all(abs(arr - round(arr)) < eps)

                arr = round(arr);

                d = diff(arr);

                if ~isempty(d) && all(d == d(1)) && d(1) ~= 0

                    if d(1) == 1

                        txt = sprintf('%d:%d', arr(1), arr(end));

                    else

                        txt = sprintf('%d:%d:%d', arr(1), d(1), arr(end));

                    end

                    return;

                end

            end

            txt = mat2str(arr);

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

            if strcmpi(key, 'fovCrop') || strcmpi(key,'patternSourceFOV') || strcmpi(key,'patternSourceFrame') || strcmpi(key,'patternSourceChannel')

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

            if strcmpi(key, 'fovIndex')

                parsed = app.parseFovIndexValue(newValue, []);

                if isempty(parsed)

                    parsed = app.parseFovIndexValue(template, []);

                end

                if isempty(parsed)

                    parsed = app.SelectedFov;

                end

                parsed = unique(parsed(:)');

                addedCurrent = false;

                if ~isempty(app.SelectedFov) && ~ismember(app.SelectedFov, parsed)

                    parsed(end+1) = app.SelectedFov;

                    parsed = unique(parsed, 'stable');

                    addedCurrent = true;

                end

                params.(key) = parsed;

                if addedCurrent

                    warning('workflow:fovIndexAdjusted', 'Current displayed FOV (%s) was added to fovIndex.', app.getFovLabel(app.SelectedFov));

                end

            else

                params.(key) = app.parseEditedValue(newValue, template);

            end

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



        function vals = parseFovIndexValue(app, raw, fallback) %#ok<INUSD>

            if nargin < 3

                fallback = [];

            end

            vals = [];

            nFov = app.getFovCount();

            if iscell(raw) && isscalar(raw)

                raw = raw{1};

            end

            if isnumeric(raw)

                vals = double(raw(:)');

            else

                txt = strtrim(char(string(raw)));

                if isempty(txt)

                    vals = [];

                else

                    t = lower(strtrim(txt));

                    t = strrep(t, '"', '');

                    t = strrep(t, '''', '');

                    t = strtrim(t);

                    if any(strcmp(t, {'all','*',':','1:end'}))

                        vals = 1:nFov;

                    else

                        txt2 = regexprep(txt, '[\[\]\(\)]', ' ');

                        txt2 = strrep(txt2, ',', ' ');

                        txt2 = strrep(txt2, ';', ' ');

                        txt2 = strtrim(txt2);

                        % Accept forms like "5 7 8", "3:5", "1:2:9".

                        try

                            vals = str2num(txt2); %#ok<ST2NM>

                        catch

                            vals = [];

                        end

                        if isempty(vals)

                            vals = fallback;

                        end

                    end

                end

            end

            if isempty(vals)

                vals = [];

                return;

            end

            vals = double(vals(:)');

            vals = vals(isfinite(vals));

            vals = vals(abs(vals - round(vals)) < 1e-9);

            vals = round(vals);

            vals = vals(vals >= 1 & vals <= nFov);

            vals = unique(vals, 'stable');

        end



        function [params, changed] = normalizeRoiPatternParams(app, params)

            changed = false;

            if ~isstruct(params)

                params = roiPattern.setparam(struct());

                changed = true;

                return;

            end

            defaults = roiPattern.setparam(struct());

            fn = fieldnames(defaults);

            for i = 1:numel(fn)

                k = fn{i};

                if ~isfield(params, k)

                    params.(k) = defaults.(k);

                    changed = true;

                end

            end

            if isempty(params.pattern)

                legacy = struct([]);

                if isfield(params,'patternList') && isstruct(params.patternList) && ~isempty(params.patternList)

                    legacy = params.patternList(1);

                end

                if ~isempty(legacy)

                    params.pattern = legacy;

                    changed = true;

                end

            end

            if isfield(params,'pattern') && isstruct(params.pattern) && ~isempty(params.pattern)

                pat = params.pattern;

                if ~isfield(pat,'rect') && isfield(pat,'crop')

                    pat.rect = pat.crop;

                    changed = true;

                end

                if ~isfield(pat,'crop') && isfield(pat,'rect')

                    pat.crop = pat.rect;

                    changed = true;

                end

                params.pattern = pat;

            end

            if isfield(params,'fovIndex')

                old = params.fovIndex;

                params.fovIndex = app.parseFovIndexValue(params.fovIndex, []);

                try

                    changed = changed || ~isequal(old, params.fovIndex);

                catch

                end

            else

                params.fovIndex = [];

                changed = true;

            end

            legacyFields = {'patternList','activePatternIndex','fallbackFullFrame','crop','patternImage'};

            for i = 1:numel(legacyFields)

                if isfield(params, legacyFields{i})

                    params = rmfield(params, legacyFields{i});

                    changed = true;

                end

            end

        end



        function cropPoly = getSelectedFovCropPolygon(app)

            cropPoly = [];

            fovObj = app.getSelectedFov();

            if isempty(fovObj)

                return;

            end

            try

                c = fovObj.crop;

                if isempty(c)

                    return;

                end

                c = double(c);

                if isvector(c) && numel(c) >= 4

                    c = reshape(c(1:4),1,[]);

                    x = c(1); y = c(2); w = c(3); h = c(4);

                    cropPoly = [x y; x+w y; x+w y+h; x y+h];

                elseif size(c,2) >= 2

                    cropPoly = c(:,1:2);

                end

            catch

            end

        end



        function DrawFovCropMenuSelected(app)

            fovObj = app.getSelectedFov();

            if isempty(fovObj)

                return;

            end

            app.clearFovCropEditor();

            poly = app.getSelectedFovCropPolygon();

            if isempty(poly)

                pos = app.getDefaultPatternPosition();

            else

                x = poly(:,1); y = poly(:,2);

                pos = [min(x), min(y), max(x)-min(x), max(y)-min(y)];

            end

            app.FovCropHandle = drawrectangle(app.UIAxes, 'Position', pos, 'Color', [0 1 0], 'LineWidth', 1.6);

            cm = uicontextmenu(app.UIFigure);

            uimenu(cm, 'Text', 'Clear inclusion crop', 'MenuSelectedFcn', @(src,evt)app.ClearFovCropMenuSelected());

            app.FovCropHandle.ContextMenu = cm;

            try

                app.FovCropListener = addlistener(app.FovCropHandle, 'ROIMoved', @(src,evt)app.commitFovCropFromRect(src.Position));

            catch

                app.FovCropListener = [];

            end

            app.commitFovCropFromRect(pos);

        end



        function ClearFovCropMenuSelected(app)

            fovObj = app.getSelectedFov();

            if isempty(fovObj)

                return;

            end

            try

                fovObj.crop = [];

            catch

            end

            app.clearFovCropEditor();

            app.markDirty(true);

            app.renderCurrentFrame();

        end



        function clearFovCropEditor(app)

            if ~isempty(app.FovCropListener)

                try, delete(app.FovCropListener); catch, end

            end

            app.FovCropListener = [];

            if ~isempty(app.FovCropHandle)

                try

                    if isvalid(app.FovCropHandle)

                        delete(app.FovCropHandle);

                    end

                catch

                end

            end

            app.FovCropHandle = [];

        end



        function commitFovCropFromRect(app, pos)

            fovObj = app.getSelectedFov();

            if isempty(fovObj)

                return;

            end

            pos = double(pos(1:4));

            x = pos(1); y = pos(2); w = pos(3); h = pos(4);

            cropPoly = [x y; x+w y; x+w y+h; x y+h];

            try

                fovObj.crop = cropPoly;

                app.markDirty(true);

            catch

            end

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

            scopeLabel = app.formatFovIndexList(fovIndex);

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

            app.SelectedRoiRows = idx;

            app.refreshExistingRoisTable();

            try

                app.Suppress = true;

                app.UIExistingROIsTable.Selection = [idx 1];

                app.Suppress = false;

            catch

                app.Suppress = false;

            end

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

            app.PatternHandle = drawrectangle(app.UIAxes, 'Position', pos, 'Color', [1 0.5 0], 'LineWidth', 1.6);

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

            if strcmpi(modeName, 'selected')

                cm = uicontextmenu(app.UIFigure);

                uimenu(cm, 'Text', 'Delete ROI', 'MenuSelectedFcn', @(src,evt)app.deleteSelectedRoi());

                app.RoiEditHandle.ContextMenu = cm;

            end

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



        function deleteSelectedRoi(app)

            fovObj = app.getSelectedFov();

            if isempty(fovObj) || isempty(app.SelectedRoi) || app.SelectedRoi < 1 || app.SelectedRoi > numel(fovObj.roi)

                return;

            end

            msg = sprintf('Delete ROI %d for %s?', app.SelectedRoi, app.getFovLabel(app.SelectedFov));

            choice = uiconfirm(app.UIFigure, msg, 'Delete ROI', 'Options', {'Delete','Cancel'}, 'DefaultOption', 'Cancel', 'CancelOption', 'Cancel');

            if ~strcmp(choice, 'Delete')

                return;

            end

            keepIdx = setdiff(1:numel(fovObj.roi), app.SelectedRoi);

            if isempty(keepIdx)

                fovObj.roi = roi;

            else

                fovObj.roi = fovObj.roi(keepIdx);

            end

            app.SelectedRoi = [];

            app.SelectedRoiRows = zeros(1,0);

            app.PendingManualRect = zeros(0,4);

            app.markDirty(true);

            app.refreshAll();

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



            pattimg = [];

            try

                src = readImage(app.Project.fov(app.SelectedFov), app.SelectedFrame, chanIdx);

                if ~isempty(src)

                    r = round(double(pos));

                    x1 = max(1, r(1));

                    y1 = max(1, r(2));

                    x2 = min(size(src,2), r(1) + r(3) - 1);

                    y2 = min(size(src,1), r(2) + r(4) - 1);

                    if x2 >= x1 && y2 >= y1

                        pattimg = src(y1:y2, x1:x2);

                    end

                end

            catch

            end

            pat.image = pattimg;



            params.pattern = pat;

            if isfield(params,'patternList')

                params.patternList = struct([]); % legacy cleanup

            end

            if isfield(params,'activePatternIndex')

                params.activePatternIndex = 1; % legacy cleanup

            end

            if isfield(params,'referenceFrame'), params.referenceFrame = app.SelectedFrame; end

            if isfield(params,'channelIndex'), params.channelIndex = chanIdx; end

            if isfield(params,'channel'), params.channel = pat.channel; end

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

            app.PreviewRoiPositions = zeros(0,4);

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

                app.PreviewRoiPositions = zeros(0,4);

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

            [fovIndex, scopeLabel, ok] = app.confirmFovScope('Test ROI detection');

            if ~ok

                return;

            end

            d = uiprogressdlg(app.UIFigure,'Title','ROI pattern','Message',['Testing ROI detection on FOV(s): ' scopeLabel '...']);

            try, d.Indeterminate = 'on'; catch, end

            try

                out = app.runPatternDetection(fovIndex, true);

                counts = zeros(1, numel(fovIndex));

                for ii = 1:numel(out)

                    try

                        if isfield(out(ii), 'fovid') && ~isempty(out(ii).fovid)

                            jj = double(out(ii).fovid(1));

                            if jj >= 1 && jj <= numel(fovIndex) && isfield(out(ii),'scaled') && ~isempty(out(ii).scaled)

                                counts(jj) = size(out(ii).scaled, 1);

                            end

                        end

                    catch

                    end

                end

                currentIdx = find(fovIndex == app.SelectedFov, 1, 'first');

                detIdx = find(counts > 0, 1, 'first');

                app.PreviewRoiPositions = zeros(0,4);

                if isempty(currentIdx) || (currentIdx <= numel(counts) && counts(currentIdx) == 0)

                    if ~isempty(detIdx)

                        app.SelectedFov = fovIndex(detIdx);

                        app.Cache = containers.Map('KeyType','char','ValueType','any');

                        currentIdx = detIdx;

                    end

                end

                if ~isempty(currentIdx)

                    for ii = 1:numel(out)

                        try

                            if isfield(out(ii), 'fovid') && ~isempty(out(ii).fovid) && double(out(ii).fovid(1)) == currentIdx

                                if isfield(out(ii), 'scaled') && ~isempty(out(ii).scaled)

                                    app.PreviewRoiPositions = double(out(ii).scaled);

                                end

                                break;

                            end

                        catch

                        end

                    end

                end

                lines = arrayfun(@(k,c) sprintf('FOV %d: %d ROI(s)', k, c), fovIndex, counts, 'UniformOutput', false);

                uialert(app.UIFigure, strjoin(lines, newline), 'ROI pattern test results', 'Icon', 'info');

            catch ME

                close(d);

                uialert(app.UIFigure, ['ROI pattern test failed: ' ME.message], 'ROI pattern error', 'Icon', 'error');

                disp(['[workflow][roiPattern][error] ' ME.message]);

                try, disp(getReport(ME, 'extended', 'hyperlinks', 'off')); catch, end

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

            idxNode = app.findNodeIndex(mode);

            params = app.Pipeline.nodes(idxNode).params;

            keepExisting = isfield(params,'keepExisting') && logical(params.keepExisting);

            overwriteFovs = [];

            if ~keepExisting

                for ff = reshape(fovIndex,1,[])

                    try

                        if ~isempty(app.Project.fov(ff).roi)

                            if ~(numel(app.Project.fov(ff).roi) == 1 && isempty(app.Project.fov(ff).roi(1).id))

                                overwriteFovs(end+1) = ff; %#ok<AGROW>

                            end

                        end

                    catch

                    end

                end

            end

            msg = sprintf('Generate ROIs on FOV(s): %s', scopeLabel);

            if ~isempty(overwriteFovs)

                msg = sprintf('%s%sExisting ROIs will be replaced on: %s', msg, newline, app.formatFovIndexList(overwriteFovs));

            end

            choice = uiconfirm(app.UIFigure, msg, 'Generate ROIs', 'Options', {'Run','Cancel'}, 'DefaultOption', 'Run', 'CancelOption', 'Cancel');

            if ~strcmp(choice,'Run')

                return;

            end

            beforeCounts = zeros(1, app.getFovCount());

            for ff = reshape(fovIndex,1,[])

                try

                    beforeCounts(ff) = numel(app.Project.fov(ff).roi);

                    if beforeCounts(ff) == 1 && isempty(app.Project.fov(ff).roi(1).id)

                        beforeCounts(ff) = 0;

                    end

                catch

                end

            end

            try

                switch lower(mode)

                    case 'roimanual'

                        srcPos = app.getSelectedRoiPositionOrDefault();

                        if isempty(srcPos)

                            uialert(app.UIFigure,'Draw or select one ROI first.','Manual ROI','Icon','warning');

                            return;

                        end

                        for ff = reshape(fovIndex,1,[])

                            if ~keepExisting

                                app.Project.fov(ff).roi = roi;

                            end

                            app.Project.fov(ff).addROI(uint16(round(srcPos)), app.Project.fov(ff).id);

                        end

                        if any(fovIndex == app.SelectedFov)

                            app.SelectedRoi = numel(app.Project.fov(app.SelectedFov).roi);

                        end

                        app.PendingManualRect = zeros(0,4);

                        app.markDirty(true);

                    case 'roipattern'

                        d = uiprogressdlg(app.UIFigure,'Title','ROI pattern','Message',['Applying ROI pattern to ' scopeLabel '...']);

                        try, d.Indeterminate = 'on'; catch, end

                        out = app.runPatternDetection(fovIndex, false);

                        close(d);

                        app.PreviewRoiPositions = zeros(0,4);

                        disp(['[workflow][roiPattern] generated ROIs on ' num2str(numel(fovIndex)) ' FOV(s)']);

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

                        ctx = struct('shallow', app.Project, 'roiGrid', app.Pipeline.nodes(idxGrid).params, 'interactive', false, 'fovIndex', fovIndex, 'resume', false, 'saveProgress', false);

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

                try, disp(getReport(ME, 'extended', 'hyperlinks', 'off')); catch, end

                return;

            end

            summary = cell(0,1);

            for ff = reshape(fovIndex,1,[])

                afterCount = 0;

                try

                    afterCount = numel(app.Project.fov(ff).roi);

                    if afterCount == 1 && isempty(app.Project.fov(ff).roi(1).id)

                        afterCount = 0;

                    end

                catch

                end

                if keepExisting

                    created = max(0, afterCount - beforeCounts(ff));

                else

                    created = afterCount;

                end

                summary{end+1,1} = sprintf('FOV %d: %d ROI(s)', ff, created); %#ok<AGROW>

            end

            app.refreshAll();

            uialert(app.UIFigure, strjoin(summary, newline), 'ROI generation complete', 'Icon', 'success');

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

                case 4

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

            rows = unique(event.Selection(:,1))';

            app.SelectedRoiRows = rows;

            if ~isempty(rows)

                app.SelectedRoi = rows(1);

                app.selectRoi(rows(1));

            end

        end



        function SelectallButtonPushed(app, event) %#ok<INUSD>

            if isempty(app.RoiDisplayMask), return; end

            app.RoiDisplayMask(:) = true;

            app.SelectedRoiRows = 1:numel(app.RoiDisplayMask);

            app.refreshExistingRoisTable();

            app.renderCurrentFrame();

        end



        function DeselectallButtonPushed(app, event) %#ok<INUSD>

            if isempty(app.RoiDisplayMask), return; end

            app.RoiDisplayMask(:) = false;

            app.SelectedRoi = [];

            app.SelectedRoiRows = zeros(1,0);

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

            msg = sprintf('Delete ROI(s) %s for %s?', mat2str(removeIdx), app.getFovLabel(app.SelectedFov));

            choice = uiconfirm(app.UIFigure, msg, 'Delete ROI', 'Options', {'Delete','Cancel'}, 'DefaultOption', 'Cancel', 'CancelOption', 'Cancel');

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

            app.SelectedRoiRows = zeros(1,0);

            app.PendingManualRect = zeros(0,4);

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

            msg = sprintf('Extract ROI crops on FOV(s): %s', scopeLabel);

            choice = uiconfirm(app.UIFigure, msg, 'Extract ROIs', 'Options', {'Run','Cancel'}, 'DefaultOption', 'Run', 'CancelOption', 'Cancel');

            if ~strcmp(choice,'Run')

                return;

            end

            d = uiprogressdlg(app.UIFigure,'Title','ROI extraction','Message',['Extracting ROI crops on ' scopeLabel '...'], 'Cancelable', 'on');

            try, d.Indeterminate = 'on'; catch, end

            try

                ctx = struct('shallow', app.Project, 'roiExtract', app.Pipeline.nodes(app.findNodeIndex('roiExtract')).params, 'interactive', false, 'fovIndex', fovIndex, 'resume', false, 'saveProgress', false, 'progressDlg', d);

                ctx = roiExtract.process(ctx);

                app.markDirty(true);

            catch ME

                close(d);

                uialert(app.UIFigure, ME.message, 'ROI extraction error', 'Icon', 'error');

                return;

            end

            canceled = false;

            try

                canceled = isfield(ctx,'canceled') && logical(ctx.canceled);

            catch

            end

            close(d);

            if canceled

                uialert(app.UIFigure, 'ROI extraction canceled between FOVs.', 'ROI extraction', 'Icon', 'warning');

            elseif isfield(ctx,'errors') && ~isempty(ctx.errors)

                uialert(app.UIFigure, strjoin(ctx.errors, newline), 'ROI extraction issues', 'Icon', 'warning');

            else

                lines = arrayfun(@(k) sprintf('FOV %d', k), fovIndex, 'UniformOutput', false);

                uialert(app.UIFigure, strjoin(lines, newline), 'ROI extraction launched', 'Icon', 'success');

            end

            app.refreshAll();

        end



        function out = runPatternDetection(app, fovIndex, testOnly)

            if nargin < 3

                testOnly = false;

            end

            [fovs, frameid, thr, pattimg, cropVal, pix] = app.resolvePatternDetectionInputs(fovIndex);

            pattRect = app.getPatternCrop();

            pattSize = size(pattimg);

            disp(sprintf('[workflow][roiPattern] frame=%d threshold=%g channel=%d fovCount=%d', frameid, thr, pix, numel(fovs)));

            disp(sprintf('[workflow][roiPattern] fovIndex=%s', mat2str(fovIndex)));

            disp(sprintf('[workflow][roiPattern] patternRect=%s', mat2str(round(double(pattRect)))));

            disp(sprintf('[workflow][roiPattern] patternSize=[%d %d]', pattSize(1), pattSize(2)));

            args = {'FOV', fovs, 'Frames', frameid, 'Threshold', thr, 'Pattern', pattimg, 'Channel', pix};

            if testOnly

                args = [args {'Test'}];

            else

                idx = app.findNodeIndex('roiPattern');

                if ~isempty(idx)

                    params = app.Pipeline.nodes(idx).params;

                    if isfield(params,'keepExisting') && logical(params.keepExisting)

                        args = [args {'Keep'} {true}];

                    end

                end

            end

            if ~isempty(cropVal)

                args = [args {'Crop'} {cropVal}];

            end

            out = identifyROIs(args{:});

            try

                totalCount = 0;

                for ii = 1:numel(out)

                    if isfield(out(ii),'scaled') && ~isempty(out(ii).scaled)

                        totalCount = totalCount + size(out(ii).scaled, 1);

                    end

                end

                disp(sprintf('[workflow][roiPattern] identifyROIs returned %d ROI(s)', totalCount));

            catch

            end

        end



        function [fovs, frameid, thr, pattimg, cropVal, pix] = resolvePatternDetectionInputs(app, fovIndex)

            idx = app.findNodeIndex('roiPattern');

            if isempty(idx)

                error('roiPattern node is missing.');

            end

            params = app.Pipeline.nodes(idx).params;



            pat = struct([]);

            if isfield(params,'pattern') && ~isempty(params.pattern)

                pat = params.pattern;

            end

            if isempty(pat)

                error('Pattern is not defined. Use Draw pattern first.');

            end



            frameid = app.SelectedFrame;

            if isfield(params,'referenceFrame') && ~isempty(params.referenceFrame)

                frameid = round(double(params.referenceFrame(1)));

            elseif isfield(pat,'referenceFrame') && ~isempty(pat.referenceFrame)

                frameid = round(double(pat.referenceFrame(1)));

            end



            thr = 0.5;

            if isfield(params,'threshold') && ~isempty(params.threshold)

                thr = double(params.threshold(1));

            end



            pix = [];

            if isfield(params,'channelIndex') && ~isempty(params.channelIndex)

                pix = round(double(params.channelIndex(1)));

            elseif isfield(pat,'channelIndex') && ~isempty(pat.channelIndex)

                pix = round(double(pat.channelIndex(1)));

            end

            if isempty(pix) || pix < 1

                pix = find([app.ChannelCfg.enabled], 1, 'first');

            end

            if isempty(pix)

                pix = 1;

            end



            fovIndex = unique(round(double(fovIndex(:)')));

            fovIndex = fovIndex(fovIndex >= 1 & fovIndex <= app.getFovCount());

            if isempty(fovIndex)

                error('No valid FOV selected for pattern detection.');

            end

            fovs = app.Project.fov(fovIndex);



            pattimg = [];

            if isfield(pat,'image') && ~isempty(pat.image)

                pattimg = pat.image;

            end



            if isempty(pattimg)

                if ~isfield(pat,'fovIndex') || isempty(pat.fovIndex)

                    error('Pattern image is missing and source FOV is unknown. Redraw pattern.');

                end

                srcIdx = round(double(pat.fovIndex(1)));

                if srcIdx < 1 || srcIdx > app.getFovCount()

                    error('Pattern source FOV index is invalid. Redraw pattern.');

                end

                srcFov = app.Project.fov(srcIdx);

                tmp = readImage(srcFov, frameid, pix);

                if isempty(tmp)

                    error('Could not load source image to build pattern image.');

                end

                rect = [];

                if isfield(pat,'rect') && numel(pat.rect) >= 4

                    rect = double(pat.rect(1:4));

                elseif isfield(pat,'crop') && numel(pat.crop) >= 4

                    rect = double(pat.crop(1:4));

                end

                if isempty(rect)

                    error('Pattern rectangle is missing. Redraw pattern.');

                end

                rect = round(rect);

                x1 = max(1, rect(1));

                y1 = max(1, rect(2));

                x2 = min(size(tmp,2), rect(1) + rect(3) - 1);

                y2 = min(size(tmp,1), rect(2) + rect(4) - 1);

                if x2 < x1 || y2 < y1

                    error('Pattern rectangle is invalid.');

                end

                pattimg = tmp(y1:y2, x1:x2);

            end



            cropVal = [];

        end



        function posList = collectPatternOutputPositions(app, out) %#ok<INUSD>

            posList = zeros(0,4);

            if isempty(out)

                return;

            end

            for ii = 1:numel(out)

                try

                    if isfield(out(ii),'scaled') && ~isempty(out(ii).scaled)

                        posList = [posList; double(out(ii).scaled)]; %#ok<AGROW>

                    end

                catch

                end

            end

        end



        function UIFigureCloseRequest(app, event) %#ok<INUSD>

            if app.Dirty

                choice = uiconfirm(app.UIFigure,'Unsaved changes. Save project before closing?','Close workflow','Options',{'Save','Discard','Cancel'},'DefaultOption','Save','CancelOption','Cancel');

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

            app.UIFigure.Position = [100 100 1298 975];

            app.UIFigure.Name = 'MATLAB App';



            app.FileMenu = uimenu(app.UIFigure); app.FileMenu.Text = 'File';

            app.EditMenu = uimenu(app.UIFigure); app.EditMenu.Text = 'Edit';

            app.ViewMenu = uimenu(app.UIFigure); app.ViewMenu.Text = 'View';

            app.AboutMenu = uimenu(app.UIFigure); app.AboutMenu.Text = 'About';

            app.UIAxes = uiaxes(app.UIFigure); title(app.UIAxes,'Display','Interpreter','none'); xlabel(app.UIAxes,'X'); ylabel(app.UIAxes,'Y'); zlabel(app.UIAxes,'Z'); app.UIAxes.Position = [387 260 901 708];
            app.TabGroup = uitabgroup(app.UIFigure); app.TabGroup.Position = [11 268 367 698];
            app.FOVsPositionsPanel = uipanel(app.UIFigure); app.FOVsPositionsPanel.Title = 'FOVs (Positions)'; app.FOVsPositionsPanel.Position = [19 15 395 237];
            app.UIDisplayPanel = uipanel(app.UIFigure); app.UIDisplayPanel.Title = 'Display'; app.UIDisplayPanel.Position = [428 15 860 237];

            app.DataloaderTab = uitab(app.TabGroup); app.DataloaderTab.Title = 'Dataloader';
            app.UIDataLoaderTable = uitable(app.DataloaderTab); app.UIDataLoaderTable.Position = [13 264 340 389];
            app.AdddataButton = uibutton(app.DataloaderTab,'push'); app.AdddataButton.Position = [18 14 332 226]; app.AdddataButton.Text = 'Add data....';

            app.UIFOVTable = uitable(app.FOVsPositionsPanel); app.UIFOVTable.ColumnName = {'Select FOV'; 'Name'}; app.UIFOVTable.Position = [9 13 374 195];
            app.selectedFOVEditFieldLabel = uilabel(app.UIDisplayPanel); app.selectedFOVEditFieldLabel.HorizontalAlignment = 'right'; app.selectedFOVEditFieldLabel.Position = [9 41 81 22]; app.selectedFOVEditFieldLabel.Text = 'selected FOV:';
            app.selectedFOVEditField = uitextarea(app.UIDisplayPanel); app.selectedFOVEditField.Editable = 'off'; app.selectedFOVEditField.Tooltip = {'Display : path, size of image'}; app.selectedFOVEditField.Position = [105 13 744 50];
            app.UIDisplayChannelTable = uitable(app.UIDisplayPanel); app.UIDisplayChannelTable.ColumnName = {'Display'; 'Name'; 'Levels'; 'RGB'; 'Weights'; 'auto'}; app.UIDisplayChannelTable.Position = [9 72 494 136];
            app.LevelsSliderLabel = uilabel(app.UIDisplayPanel); app.LevelsSliderLabel.HorizontalAlignment = 'right'; app.LevelsSliderLabel.Position = [522 186 40 22]; app.LevelsSliderLabel.Text = 'Levels';
            app.LevelsSlider = uislider(app.UIDisplayPanel,'range'); app.LevelsSlider.Position = [584 195 150 3];
            app.FrameSliderLabel = uilabel(app.UIDisplayPanel); app.FrameSliderLabel.HorizontalAlignment = 'right'; app.FrameSliderLabel.Position = [523 143 40 22]; app.FrameSliderLabel.Text = 'Frame';
            app.FrameSlider = uislider(app.UIDisplayPanel); app.FrameSlider.Position = [585 152 150 3];
            app.FrameEditFieldLabel = uilabel(app.UIDisplayPanel); app.FrameEditFieldLabel.HorizontalAlignment = 'right'; app.FrameEditFieldLabel.Position = [723 142 40 22]; app.FrameEditFieldLabel.Text = 'Frame';
            app.FrameEditField = uieditfield(app.UIDisplayPanel,'numeric'); app.FrameEditField.Position = [761 142 53 22];
            app.ZoomSliderLabel = uilabel(app.UIDisplayPanel); app.ZoomSliderLabel.HorizontalAlignment = 'right'; app.ZoomSliderLabel.Position = [528 91 36 22]; app.ZoomSliderLabel.Text = 'Zoom';
            app.ZoomSlider = uislider(app.UIDisplayPanel); app.ZoomSlider.Position = [588 104 150 3];
            app.DisplaycolorColorPickerLabel = uilabel(app.UIDisplayPanel); app.DisplaycolorColorPickerLabel.HorizontalAlignment = 'right'; app.DisplaycolorColorPickerLabel.Position = [762 183 34 22]; app.DisplaycolorColorPickerLabel.Text = 'color:';
            app.DisplaycolorColorPicker = uicolorpicker(app.UIDisplayPanel); app.DisplaycolorColorPicker.Position = [811 183 38 22];
            app.ResetzoomButton = uibutton(app.UIDisplayPanel,'push'); app.ResetzoomButton.Position = [762 110 78 23]; app.ResetzoomButton.Text = 'Reset zoom';
            app.PanButton = uibutton(app.UIDisplayPanel,'push'); app.PanButton.Position = [764 80 76 23]; app.PanButton.Text = 'Pan';



            app.ROIsIDTab = uitab(app.TabGroup); app.ROIsIDTab.Title = 'ROIs ID';

            app.ROIgenerationmodeButtonGroup = uibuttongroup(app.ROIsIDTab); app.ROIgenerationmodeButtonGroup.Title = 'ROI generation mode'; app.ROIgenerationmodeButtonGroup.Position = [9 571 341 93];

            app.ManualselectionmanualButton = uiradiobutton(app.ROIgenerationmodeButtonGroup); app.ManualselectionmanualButton.Text = 'Manual selection (manual)'; app.ManualselectionmanualButton.Position = [11 47 163 22]; app.ManualselectionmanualButton.Value = true;

            app.PatterndetectionpatternButton = uiradiobutton(app.ROIgenerationmodeButtonGroup); app.PatterndetectionpatternButton.Text = 'Pattern detection (pattern)'; app.PatterndetectionpatternButton.Position = [11 25 161 22];

            app.GridselectiongridButton = uiradiobutton(app.ROIgenerationmodeButtonGroup); app.GridselectiongridButton.Text = 'Grid selection (grid)'; app.GridselectiongridButton.Position = [11 3 127 22];

            app.UIROIParametersTable = uitable(app.ROIsIDTab); app.UIROIParametersTable.Position = [11 300 339 262];

            app.DrawpatternButton = uibutton(app.ROIsIDTab,'push'); app.DrawpatternButton.Position = [13 247 106 44]; app.DrawpatternButton.Text = 'Draw pattern';

            app.UIExistingROIsTable = uitable(app.ROIsIDTab); app.UIExistingROIsTable.Position = [11 44 339 196];

            app.TestROIdetectionButton = uibutton(app.ROIsIDTab,'push'); app.TestROIdetectionButton.Position = [124 248 114 42]; app.TestROIdetectionButton.Text = 'Test ROI detection';

            app.GenerateROIsButton = uibutton(app.ROIsIDTab,'push'); app.GenerateROIsButton.Position = [244 250 100 39]; app.GenerateROIsButton.Text = 'Generate ROIs';

            app.SelectallButton = uibutton(app.ROIsIDTab,'push'); app.SelectallButton.Position = [10 10 100 23]; app.SelectallButton.Text = 'Select all';

            app.DeselectallButton = uibutton(app.ROIsIDTab,'push'); app.DeselectallButton.Position = [118 10 100 23]; app.DeselectallButton.Text = 'Deselect all';

            app.RemoveselectedButton = uibutton(app.ROIsIDTab,'push'); app.RemoveselectedButton.Position = [228 10 108 23]; app.RemoveselectedButton.Text = 'Remove selected';



            app.ROIsExtractionTab = uitab(app.TabGroup); app.ROIsExtractionTab.Title = 'ROIs Extraction';

            app.UIROIsExtractionTable = uitable(app.ROIsExtractionTab); app.UIROIsExtractionTable.Position = [10 161 340 503];

            app.ExtractROIsButton = uibutton(app.ROIsExtractionTab,'push'); app.ExtractROIsButton.Position = [8 10 342 136]; app.ExtractROIsButton.Text = 'Extract ROIs';



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









