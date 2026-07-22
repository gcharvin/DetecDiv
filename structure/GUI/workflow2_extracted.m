classdef workflow2 < matlab.apps.AppBase
    properties (Access = public)
        UIFigure                       matlab.ui.Figure
        FileMenu                       matlab.ui.container.Menu
        EditMenu                       matlab.ui.container.Menu
        ViewMenu                       matlab.ui.container.Menu
        AboutMenu                      matlab.ui.container.Menu
        FOVsPositionsPanel             matlab.ui.container.Panel
        SelectcurrentFOVtodisplayPanel matlab.ui.container.Panel
        UIFOVTable                     matlab.ui.control.Table
        ChannelsPanel                  matlab.ui.container.Panel
        selectedFOVEditField           matlab.ui.control.TextArea
        UIDisplayChannelTable          matlab.ui.control.Table
        ResetzoomButton                matlab.ui.control.Button
        PanButton                      matlab.ui.control.Button
        FrameEditField                 matlab.ui.control.NumericEditField
        colorColorPicker               matlab.ui.control.ColorPicker
        colorColorPickerLabel          matlab.ui.control.Label
        ZoomSlider                     matlab.ui.control.Slider
        ZoomSliderLabel                matlab.ui.control.Label
        FrameSlider                    matlab.ui.control.Slider
        FrameSliderLabel               matlab.ui.control.Label
        LevelsSlider                   matlab.ui.control.RangeSlider
        LevelsSliderLabel              matlab.ui.control.Label
        TabGroup                       matlab.ui.container.TabGroup
        DataloaderTab                  matlab.ui.container.Tab
        AdddataButton                  matlab.ui.control.Button
        UIDataLoaderTable              matlab.ui.control.Table
        ROIsIDTab                      matlab.ui.container.Tab
        removeselectedButton           matlab.ui.control.Button
        deselectallButton              matlab.ui.control.Button
        selectallButton                matlab.ui.control.Button
        SelectallButton                matlab.ui.control.Button
        DeselectallButton              matlab.ui.control.Button
        DeleteselectedButton           matlab.ui.control.Button
        ROIsLabel                      matlab.ui.control.Label
        GenerateROIsButton             matlab.ui.control.Button
        TestROIdetectionButton         matlab.ui.control.Button
        UIExistingROIsTable            matlab.ui.control.Table
        UIROICandidateTable            matlab.ui.control.Table
        SavepatternButton              matlab.ui.control.Button
        UIROIParametersTable           matlab.ui.control.Table
        ROIgenerationmodeButtonGroup   matlab.ui.container.ButtonGroup
        GridselectiongridButton        matlab.ui.control.RadioButton
        PatterndetectionpatternButton  matlab.ui.control.RadioButton
        ManualselectionmanualButton    matlab.ui.control.RadioButton
        ROIsExtractionTab              matlab.ui.container.Tab
        ExtractROIsButton              matlab.ui.control.Button
        UIROIsExtractionTable          matlab.ui.control.Table
        ROIdefinitionPanel             matlab.ui.container.Panel
        ProceedButton                  matlab.ui.control.Button
        CancelButton                   matlab.ui.control.Button
        RoiLegendTextArea              matlab.ui.control.TextArea
        RoiThresholdLabel              matlab.ui.control.Label
        RoiThresholdEditField          matlab.ui.control.NumericEditField
        RoiManualRectLabel             matlab.ui.control.Label
        RoiManualRectEditField         matlab.ui.control.EditField
        CurrentROIsizeEditField        matlab.ui.control.EditField
        CurrentROIsizeEditFieldLabel   matlab.ui.control.Label
        Panel                          matlab.ui.container.Panel
        UIAxes                         matlab.ui.control.UIAxes
    end

    properties (Access = public)
        Result struct = struct()
        Cancelled logical = true
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

        CacheBytes

        CacheOrder cell = {}

        CacheSizeBytes double = 0

        CacheMaxBytes double = 536870912

        Dirty logical = false

        Suppress logical = false

        PatternHandle = []

        SelectedRoi = []

        SelectedRoiRows double = zeros(1,0)

        RoiEditHandle = []

        RoiEditListener = []

        PreviewRoiPositions double = zeros(0,4)

        PendingManualRect double = zeros(0,4)

        ManualRoiRecords struct = repmat(struct('fovIndex', [], 'rect', []), 0, 1)

        RoiCandidateRects double = zeros(0,4)

        RoiCandidateSelected logical = false(0,1)

        RoiCandidateSource cell = {}

        SelectedCandidateRow double = NaN

        DynamicStaticParamControls cell = {}

        FovCropHandle = []

        FovCropListener = []

        FocusModule char = ''

        ModuleMode char = 'roimanual'

        StartupParams struct = struct()

        LastTableRoiRow double = NaN

        LastTableRoiClickTime double = 0

        LastGraphicRoiRow double = NaN

        LastGraphicRoiClickTime double = 0

    end



    methods (Access = private)

        function startupFcn(app, shallowObj, varargin)

            opts = app.parseStartupOptions(varargin{:});

            app.configureUi();

            app.configureWorkflow2Shell();

            app.resetImageCache();

            if nargin >= 2 && ~isempty(shallowObj) && ~isa(shallowObj, 'shallow') && ...
                    (ischar(shallowObj) || isstring(shallowObj)) && ...
                    (exist(char(string(shallowObj)), 'dir') == 7 || exist(char(string(shallowObj)), 'file') == 2)

                try

                    shallowObj = app.createTemporaryProjectFromRawPath(char(string(shallowObj)));

                catch ME

                    uialert(app.UIFigure, ME.message, 'Raw data loading', 'Icon', 'warning');

                end

            end

            if nargin < 2 || isempty(shallowObj) || ~isa(shallowObj,'shallow')

                uialert(app.UIFigure,'workflow expects a shallow project object.','Missing project','Icon','warning');

                app.refreshAll();

                return;

            end

            app.Project = shallowObj;

            app.ensureWorkflowRunProfiles();

            if ~isempty(opts.FocusModule)

                targetForPipe = app.normalizeFocusModuleName(opts.FocusModule);

                if any(strcmpi(targetForPipe, {'roimanual','roipattern','roigrid','roitracked'}))

                    app.ModuleMode = targetForPipe;

                end

            end

            app.Pipeline = app.loadOrCreateDefaultPipeline();

            if app.getFovCount() > 0

                app.SelectedFov = 1;

            end

            if ~isempty(opts.Params) && isstruct(opts.Params)

                app.StartupParams = opts.Params;

            end

            if ~isempty(opts.FocusModule)

                target = app.normalizeFocusModuleName(opts.FocusModule);

                if any(strcmpi(target, {'roimanual','roipattern','roigrid','roitracked'}))

                    app.ensureRoiNode(target);

                    app.FocusModule = target;

                    app.ModuleMode = target;

                    app.applyStartupParamsToNode(target);

                    if app.isValidUi(app.TabGroup) && app.isValidUi(app.ROIsIDTab)
                        app.TabGroup.SelectedTab = app.ROIsIDTab;
                    end

                elseif strcmpi(target, 'roiextract')

                    app.ensureExtractNode();

                    if app.isValidUi(app.TabGroup) && app.isValidUi(app.ROIsExtractionTab)
                        app.TabGroup.SelectedTab = app.ROIsExtractionTab;
                    end

                elseif any(strcmpi(target, {'display','dataloader'}))

                    if app.isValidUi(app.TabGroup) && app.isValidUi(app.DataloaderTab)
                        app.TabGroup.SelectedTab = app.DataloaderTab;
                    end

                end

            end

            app.configureWorkflow2Module();

            if strcmpi(app.getSelectedRoiMode(), 'roiManual')
                idxManual = app.findNodeIndex('roiManual');
                if ~isempty(idxManual)
                    app.initializeManualRoiRecordsFromParams(app.Pipeline.nodes(idxManual).params);
                    app.loadManualRoisForSelectedFov();
                end
            end

            app.refreshAll();

            app.restoreWorkflow2RoiArtifact();

            app.markDirty(false);

        end

        function shallowObj = createTemporaryProjectFromRawPath(app, rawDataPath) %#ok<INUSD>

            rawDataPath = char(string(rawDataPath));

            if ~(exist(rawDataPath, 'dir') == 7 || exist(rawDataPath, 'file') == 2)

                error('workflow2:RawPathMissing', 'Raw data path does not exist: %s', rawDataPath);

            end

            shallowObj = shallow();
            [basePath, baseName, baseExt] = fileparts(rawDataPath);

            if isempty(basePath)

                basePath = pwd;

            end

            shallowObj.io.path = basePath;
            shallowObj.io.file = ['workflow2_raw_' matlab.lang.makeValidName([baseName baseExt])];
            shallowObj.addData(rawDataPath);

            if isempty(shallowObj.fov) || isempty(shallowObj.fov(1).srcpath)

                error('workflow2:RawPathNoFov', 'Raw data were parsed, but no displayable FOV was created.');

            end

        end



        function opts = parseStartupOptions(app, varargin) %#ok<INUSD>

            opts = struct('FocusModule', '', 'Params', struct());

            if isempty(varargin)

                return;

            end

            if numel(varargin) == 1 && (ischar(varargin{1}) || isstring(varargin{1}))

                opts.FocusModule = char(string(varargin{1}));

                return;

            end

            i = 1;

            while i <= numel(varargin)

                key = varargin{i};

                if ~(ischar(key) || isstring(key))

                    i = i + 1;

                    continue;

                end

                if i == numel(varargin)

                    break;

                end

                val = varargin{i+1};

                switch lower(char(string(key)))

                    case {'focus', 'focusmodule', 'module', 'moduletype'}

                        opts.FocusModule = char(string(val));

                    case {'params', 'param', 'nodeparams'}

                        if isstruct(val)

                            opts.Params = val;

                        end

                end

                i = i + 2;

            end

        end

        function configureWorkflow2Shell(app)

            app.UIFigure.Name = 'Workflow2 - ROI definition';

            try

                app.UIFigure.WindowStyle = 'modal';

            catch

            end

            try

                app.FileMenu.Visible = 'off';
                app.EditMenu.Visible = 'off';
                app.ViewMenu.Visible = 'off';
                app.AboutMenu.Visible = 'off';

            catch

            end

            try

                app.TabGroup.SelectedTab = app.ROIsIDTab;
                app.ROIsIDTab.Title = 'ROI definition';
                delete(app.DataloaderTab);
                delete(app.ROIsExtractionTab);

            catch

            end

            try

                app.GenerateROIsButton.Visible = 'off';
                app.GenerateROIsButton.Enable = 'off';
                app.ExtractROIsButton.Visible = 'off';
                app.ExtractROIsButton.Enable = 'off';
                app.AdddataButton.Visible = 'off';
                app.AdddataButton.Enable = 'off';

            catch

            end

            try

                app.RoiLegendTextArea.Value = app.roiLegendLines();

            catch

            end

            app.configureWorkflow2Layout();

        end

        function configureWorkflow2Layout(app)

            try

                app.UIFigure.Position(3:4) = [1320 880];

            catch

            end

            % App Designer owns workflow2 layout. Keep this function minimal
            % so manual layout edits are not overwritten at startup.
            try, app.ROIsIDTab.Title = 'ROI'; catch, end
            try, app.ROIgenerationmodeButtonGroup.Visible = 'off'; catch, end
            try, app.UIROIParametersTable.Visible = 'off'; catch, end
            try, app.UIExistingROIsTable.Visible = 'off'; catch, end
            try, app.ROIsLabel.Visible = 'off'; catch, end
            try, app.selectallButton.Visible = 'off'; catch, end
            try, app.deselectallButton.Visible = 'off'; catch, end
            try, app.removeselectedButton.Visible = 'off'; catch, end
            try, app.RoiLegendTextArea.Visible = 'off'; catch, end
            try, app.GenerateROIsButton.Visible = 'off'; catch, end

            try

                app.ProceedButton.FontSize = 14;
                app.ProceedButton.FontWeight = 'bold';
                app.CancelButton.FontSize = 14;

            catch

            end
            app.refreshManualRectEditField();
            app.refreshRoiCandidateTable();

        end

        function configureWorkflow2Module(app)

            mode = app.getCurrentRoiMode();

            app.ModuleMode = mode;

            if app.isValidUi(app.ROIgenerationmodeButtonGroup)
                app.ROIgenerationmodeButtonGroup.Title = 'ROI definition mode';
            end

            switch lower(mode)

                case 'roipattern'

                    if app.isValidUi(app.ROIgenerationmodeButtonGroup) && app.isValidUi(app.PatterndetectionpatternButton)
                        app.ROIgenerationmodeButtonGroup.SelectedObject = app.PatterndetectionpatternButton;
                    end
                    if app.isValidUi(app.SavepatternButton)
                        app.SavepatternButton.Text = 'Draw pattern';
                        app.SavepatternButton.Enable = 'on';
                    end
                    if app.isValidUi(app.TestROIdetectionButton)
                        app.TestROIdetectionButton.Text = 'Preview detection';
                        app.TestROIdetectionButton.Enable = 'on';
                    end
                    if app.isValidUi(app.RoiThresholdLabel), app.RoiThresholdLabel.Visible = 'on'; end
                    if app.isValidUi(app.RoiThresholdEditField), app.RoiThresholdEditField.Visible = 'on'; end
                    if app.isValidUi(app.CurrentROIsizeEditFieldLabel), app.CurrentROIsizeEditFieldLabel.Visible = 'on'; end
                    if app.isValidUi(app.CurrentROIsizeEditField), app.CurrentROIsizeEditField.Visible = 'on'; end
                    app.refreshRoiThresholdField();
                    app.refreshManualRectEditField();

                case 'roigrid'

                    if app.isValidUi(app.ROIgenerationmodeButtonGroup) && app.isValidUi(app.GridselectiongridButton)
                        app.ROIgenerationmodeButtonGroup.SelectedObject = app.GridselectiongridButton;
                    end
                    if app.isValidUi(app.SavepatternButton)
                        app.SavepatternButton.Text = 'Grid settings';
                        app.SavepatternButton.Enable = 'off';
                    end
                    if app.isValidUi(app.TestROIdetectionButton)
                        app.TestROIdetectionButton.Text = 'Preview grid';
                        app.TestROIdetectionButton.Enable = 'on';
                    end
                    if app.isValidUi(app.RoiThresholdLabel), app.RoiThresholdLabel.Visible = 'off'; end
                    if app.isValidUi(app.RoiThresholdEditField), app.RoiThresholdEditField.Visible = 'off'; end
                    if app.isValidUi(app.CurrentROIsizeEditFieldLabel), app.CurrentROIsizeEditFieldLabel.Visible = 'off'; end
                    if app.isValidUi(app.CurrentROIsizeEditField), app.CurrentROIsizeEditField.Visible = 'off'; end

                case 'roimanual'

                    if app.isValidUi(app.ROIgenerationmodeButtonGroup) && app.isValidUi(app.ManualselectionmanualButton)
                        app.ROIgenerationmodeButtonGroup.SelectedObject = app.ManualselectionmanualButton;
                    end
                    if app.isValidUi(app.SavepatternButton)
                        app.SavepatternButton.Text = 'Draw ROI';
                        app.SavepatternButton.Enable = 'on';
                    end
                    if app.isValidUi(app.TestROIdetectionButton)
                        app.TestROIdetectionButton.Text = 'Preview';
                        app.TestROIdetectionButton.Enable = 'off';
                    end
                    if app.isValidUi(app.RoiThresholdLabel), app.RoiThresholdLabel.Visible = 'off'; end
                    if app.isValidUi(app.RoiThresholdEditField), app.RoiThresholdEditField.Visible = 'off'; end
                    if app.isValidUi(app.CurrentROIsizeEditFieldLabel), app.CurrentROIsizeEditFieldLabel.Visible = 'on'; end
                    if app.isValidUi(app.CurrentROIsizeEditField), app.CurrentROIsizeEditField.Visible = 'on'; end
                    app.refreshManualRectEditField();

                otherwise

                    if app.isValidUi(app.SavepatternButton), app.SavepatternButton.Enable = 'off'; end
                    if app.isValidUi(app.TestROIdetectionButton), app.TestROIdetectionButton.Enable = 'off'; end
                    if app.isValidUi(app.RoiThresholdLabel), app.RoiThresholdLabel.Visible = 'off'; end
                    if app.isValidUi(app.RoiThresholdEditField), app.RoiThresholdEditField.Visible = 'off'; end
                    if app.isValidUi(app.CurrentROIsizeEditFieldLabel), app.CurrentROIsizeEditFieldLabel.Visible = 'off'; end
                    if app.isValidUi(app.CurrentROIsizeEditField), app.CurrentROIsizeEditField.Visible = 'off'; end

            end

            if app.isValidUi(app.PatterndetectionpatternButton), app.PatterndetectionpatternButton.Enable = app.modeRadioEnable('roipattern'); end
            if app.isValidUi(app.GridselectiongridButton), app.GridselectiongridButton.Enable = app.modeRadioEnable('roigrid'); end
            if app.isValidUi(app.ManualselectionmanualButton), app.ManualselectionmanualButton.Enable = app.modeRadioEnable('roimanual'); end

            if app.isValidUi(app.RoiLegendTextArea)
                app.RoiLegendTextArea.Value = app.roiLegendLines();
            end
            app.refreshStaticParameterPanel();

        end

        function state = modeRadioEnable(app, mode)

            if strcmpi(app.ModuleMode, mode)

                state = 'on';

            else

                state = 'off';

            end

        end

        function refreshStaticParameterPanel(app)

            if ~app.isValidUi(app.Panel)
                return;
            end
            app.clearDynamicStaticParamControls();

            mode = app.getCurrentRoiMode();
            idx = app.findNodeIndex(mode);
            defaults = app.getDefaultParams(mode);
            if isempty(idx)
                params = defaults;
            else
                params = app.Pipeline.nodes(idx).params;
            end
            keys = fieldnames(params);
            hide = {'crop','fovCrop','pattern','patternList','activePatternIndex','patternImage', ...
                'referenceFrame','channel','channelIndex','fovIndex','manualRois','manualRects', ...
                'rectangles','roiRects','rois','positions'};
            if strcmpi(mode, 'roiPattern')
                keys = intersect({'threshold'}, keys, 'stable');
            elseif strcmpi(mode, 'roiGrid')
                keys = intersect({'gridCount'}, keys, 'stable');
            end
            keep = {};
            for i = 1:numel(keys)
                if any(strcmpi(keys{i}, hide))
                    continue;
                end
                val = params.(keys{i});
                if isstruct(val) || isa(val, 'function_handle')
                    continue;
                end
                keep{end+1} = keys{i}; %#ok<AGROW>
            end

            if isempty(keep)
                lbl = uilabel(app.Panel, 'Text', 'No static parameters for this ROI mode.', ...
                    'Position', [12 max(10, app.Panel.Position(4)-55) max(120, app.Panel.Position(3)-24) 22]);
                app.DynamicStaticParamControls = {lbl};
                return;
            end

            panelW = max(180, app.Panel.Position(3));
            y = max(20, app.Panel.Position(4) - 45);
            app.DynamicStaticParamControls = {};
            for i = 1:numel(keep)
                key = keep{i};
                val = params.(key);
                labelW = min(115, max(80, panelW * 0.42));
                ctrlW = max(70, panelW - labelW - 34);
                lbl = uilabel(app.Panel, 'Text', key, 'Interpreter', 'none', ...
                    'Position', [12 y labelW 22]);
                if islogical(val)
                    ctrl = uicheckbox(app.Panel, 'Text', '', 'Value', logical(val), ...
                        'Position', [18+labelW y 24 22], ...
                        'ValueChangedFcn', @(src,evt)app.staticParamControlChanged(key, src.Value));
                else
                    ctrl = uieditfield(app.Panel, 'text', 'Value', app.paramValueToText(val), ...
                        'Position', [18+labelW y ctrlW 22], ...
                        'ValueChangedFcn', @(src,evt)app.staticParamControlChanged(key, src.Value));
                end
                app.DynamicStaticParamControls(end+1:end+2) = {lbl, ctrl}; %#ok<AGROW>
                y = y - 28;
                if y < 10
                    break;
                end
            end

        end

        function clearDynamicStaticParamControls(app)

            for i = 1:numel(app.DynamicStaticParamControls)
                h = app.DynamicStaticParamControls{i};
                try
                    if ~isempty(h) && isvalid(h)
                        delete(h);
                    end
                catch
                end
            end
            app.DynamicStaticParamControls = {};

        end

        function txt = paramValueToText(app, val) %#ok<INUSD>

            if isnumeric(val)
                if isscalar(val)
                    txt = num2str(val);
                else
                    txt = mat2str(val);
                end
            elseif ischar(val) || isstring(val)
                txt = char(string(val));
            elseif iscell(val)
                txt = strjoin(cellstr(string(val(:)')), ', ');
            else
                try
                    txt = jsonencode(val);
                catch
                    txt = char(string(val));
                end
            end

        end

        function staticParamControlChanged(app, key, value)

            mode = app.getCurrentRoiMode();
            idx = app.findNodeIndex(mode);
            if isempty(idx)
                app.ensureRoiNode(mode);
                idx = app.findNodeIndex(mode);
            end
            if isempty(idx)
                return;
            end
            params = app.Pipeline.nodes(idx).params;
            if isfield(params, key)
                oldValue = params.(key);
            else
                oldValue = [];
            end
            params.(key) = app.parseStaticParamValue(value, oldValue);
            if strcmpi(mode, 'roiGrid') && strcmpi(key, 'gridCount')
                try
                    params.gridCount = max(1, round(double(params.gridCount(1))));
                    if params.gridCount > 1
                        params.mode = 'grid';
                    else
                        params.mode = 'fullframe';
                    end
                    app.PreviewRoiPositions = zeros(0,4);
                    app.RoiCandidateRects = zeros(0,4);
                    app.RoiCandidateSelected = false(0,1);
                    app.RoiCandidateSource = {};
                catch
                end
            end
            app.Pipeline.nodes(idx).params = params;
            app.savePipelineIfPersistent();
            app.storePipelineLink(app.Pipeline);
            app.publishPipelineToWorkspace();
            app.markDirty(true);
            app.refreshStaticParameterPanel();
            if strcmpi(mode, 'roiGrid')
                app.refreshRoiCandidateTable();
                app.renderCurrentFrame();
            end

        end

        function val = parseStaticParamValue(app, value, oldValue) %#ok<INUSD>

            if islogical(oldValue)
                val = logical(value);
                return;
            end
            txt = char(string(value));
            if isnumeric(oldValue)
                parsed = str2num(txt); %#ok<ST2NM>
                if isempty(parsed)
                    val = oldValue;
                else
                    val = parsed;
                end
            elseif isstring(oldValue)
                val = string(txt);
            else
                val = txt;
            end

        end

        function refreshRoiThresholdField(app)

            if ~app.isValidUi(app.RoiThresholdEditField)
                return;
            end

            val = 0.5;
            idx = app.findNodeIndex('roiPattern');

            try

                if ~isempty(idx)

                    params = app.Pipeline.nodes(idx).params;

                    if isfield(params, 'threshold') && ~isempty(params.threshold)

                        val = double(params.threshold(1));

                    end

                end

            catch

            end

            try

                app.RoiThresholdEditField.Value = val;

            catch

            end

        end

        function RoiThresholdEditFieldValueChanged(app, event) %#ok<INUSD>

            if ~app.isValidUi(app.RoiThresholdEditField)
                return;
            end

            idx = app.findNodeIndex('roiPattern');

            if isempty(idx)

                return;

            end

            params = app.Pipeline.nodes(idx).params;
            params.threshold = app.RoiThresholdEditField.Value;
            app.Pipeline.nodes(idx).params = params;
            app.markDirty(true);

        end

        function refreshManualRectEditField(app)

            if ~app.isValidUi(app.CurrentROIsizeEditField)

                return;

            end

            rect = app.getCurrentEditableRect();

            if isempty(rect)

                app.CurrentROIsizeEditField.Value = '';

            else

                app.CurrentROIsizeEditField.Value = app.formatManualRect(rect);

            end

        end

        function rect = getCurrentEditableRect(app)

            rect = [];
            mode = lower(char(string(app.getSelectedRoiMode())));

            if strcmp(mode, 'roipattern')
                try
                    if ~isempty(app.PatternHandle) && isvalid(app.PatternHandle)
                        rect = double(app.PatternHandle.Position);
                        return;
                    end
                catch
                end
                rect = app.getPatternCrop();
                return;
            end

            try

                if ~isempty(app.RoiEditHandle) && isvalid(app.RoiEditHandle)

                    rect = double(app.RoiEditHandle.Position);

                end

            catch

            end

            if isempty(rect) && ~isempty(app.PendingManualRect)

                rect = double(app.PendingManualRect(1,1:4));

            end

        end

        function txt = formatManualRect(app, rect) %#ok<INUSD>

            rect = round(double(rect(1,1:4)));
            txt = sprintf('%d, %d, %d, %d', rect(1), rect(2), rect(3), rect(4));

        end

        function rect = parseManualRectText(app, txt) %#ok<INUSD>

            rect = [];

            try

                txt = char(string(txt));
                txt = regexprep(txt, '[,;]', ' ');
                vals = str2num(txt); %#ok<ST2NM>

                if isnumeric(vals) && numel(vals) >= 4

                    vals = round(double(vals(1:4)));

                    if all(isfinite(vals)) && vals(3) > 0 && vals(4) > 0

                        rect = vals;

                    end

                end

            catch

                rect = [];

            end

        end

        function RoiManualRectEditFieldValueChanged(app, event) %#ok<INUSD>

            if ~app.isValidUi(app.CurrentROIsizeEditField)
                return;
            end

            rect = app.parseManualRectText(app.CurrentROIsizeEditField.Value);

            if isempty(rect)

                app.refreshManualRectEditField();
                return;

            end

            rect = round(double(rect(1,1:4)));
            mode = lower(char(string(app.getSelectedRoiMode())));

            if strcmp(mode, 'roipattern')
                if ~isempty(app.PatternHandle)
                    try
                        if isvalid(app.PatternHandle)
                            app.PatternHandle.Position = rect;
                        end
                    catch
                    end
                end
                app.upsertPattern(rect);
            else
                row = app.SelectedCandidateRow;
                if isempty(app.PendingManualRect)
                    app.PendingManualRect = rect;
                    row = 1;
                elseif ~isnan(row) && row >= 1 && row <= size(app.PendingManualRect,1)
                    app.PendingManualRect(row,:) = rect;
                else
                    app.PendingManualRect(1,:) = rect;
                    row = 1;
                end
                app.SelectedCandidateRow = row;
                app.SelectedRoi = [];
                app.SelectedRoiRows = zeros(1,0);
                app.storeManualRoisForSelectedFov();

                if ~isempty(app.RoiEditHandle)

                    try

                        if isvalid(app.RoiEditHandle)

                            app.RoiEditHandle.Position = app.PendingManualRect(row,:);

                        end

                    catch

                    end

                end
            end

            app.markDirty(true);
            app.refreshManualRectEditField();
            app.refreshRoiCandidateTable();
            app.renderCurrentFrame();

        end

        function applyStartupParamsToNode(app, mode)

            if isempty(app.StartupParams) || ~isstruct(app.StartupParams)

                return;

            end

            idx = app.findNodeIndex(mode);

            if isempty(idx)

                return;

            end

            app.Pipeline.nodes(idx).params = app.mergeStructOverride(app.Pipeline.nodes(idx).params, app.StartupParams);

        end

        function out = mergeStructOverride(app, base, override) %#ok<INUSD>

            if ~isstruct(base)

                base = struct();

            end

            out = base;

            if ~isstruct(override)

                return;

            end

            fn = fieldnames(override);

            for i = 1:numel(fn)

                out.(fn{i}) = override.(fn{i});

            end

        end

        function lines = roiLegendLines(app)

            switch lower(app.getCurrentRoiMode())

                case 'roipattern'

                    lines = {'Legend: cyan = existing ROI; red = extracted ROI; orange = stale ROI or editable pattern; yellow = selected ROI; magenta dashed = preview detection.'};

                case 'roigrid'

                    lines = {'Legend: cyan = existing ROI; red = extracted ROI; orange dotted = grid/full-frame recipe preview; yellow = selected ROI. ROIs are generated only when the pipeline runs.'};

                case 'roimanual'

                    lines = {'Legend: cyan = existing ROI; red = extracted ROI; green = manual ROI candidate; bright green = selected candidate; yellow = selected existing ROI.'};

                otherwise

                    lines = {'Legend: blue = existing ROI; green/orange overlays are module-specific previews.'};

            end

        end



        function mode = normalizeFocusModuleName(app, mode) %#ok<INUSD>

            mode = lower(strtrim(char(string(mode))));

            switch mode

                case {'roitracked', 'tracked', 'trackedroi', 'roitracking'}

                    mode = 'roitracked';

                case {'roipattern', 'pattern', 'roiidentify', 'identify'}

                    mode = 'roipattern';

                case {'roigrid', 'grid'}

                    mode = 'roigrid';

                case {'roimanual', 'manual'}

                    mode = 'roimanual';

                case {'roiextract', 'extract'}

                    mode = 'roiextract';

                case {'display'}

                    mode = 'display';

                case {'dataloader','loader','rawpath','relink'}

                    mode = 'dataloader';

                otherwise

                    mode = '';

            end

        end



        function configureUi(app)

            app.UIFigure.Name = 'Workflow';
            app.UIFigure.AutoResizeChildren = 'off';

            app.UIFigure.WindowKeyPressFcn = createCallbackFcn(app,@UIFigureWindowKeyPress,true);

            app.UIFigure.CloseRequestFcn = createCallbackFcn(app,@UIFigureCloseRequest,true);
            app.UIFigure.SizeChangedFcn = createCallbackFcn(app,@UIFigureSizeChanged,true);



            app.UIAxes.Toolbar.Visible = 'off';

            app.UIAxes.XTick = [];

            app.UIAxes.YTick = [];

            title(app.UIAxes,'Display','Interpreter','none');

            cmAxes = uicontextmenu(app.UIFigure);

            uimenu(cmAxes, 'Text', 'Open selected ROI in score...', 'MenuSelectedFcn', @(src,evt)app.OpenSelectedRoiInScoreMenuSelected());

            uimenu(cmAxes, 'Text', 'Draw inclusion crop (current FOV)', 'MenuSelectedFcn', @(src,evt)app.DrawFovCropMenuSelected());

            uimenu(cmAxes, 'Text', 'Clear inclusion crop (current FOV)', 'MenuSelectedFcn', @(src,evt)app.ClearFovCropMenuSelected());

            app.UIAxes.ContextMenu = cmAxes;



            if app.isValidUi(app.selectedFOVEditField)
                app.selectedFOVEditField.Editable = 'off';
            end



            if app.isValidUi(app.FileMenu) && isempty(app.FileMenu.Children)

                m = uimenu(app.FileMenu);

                m.Text = 'Save project';

                m.MenuSelectedFcn = createCallbackFcn(app,@SaveprojectMenuSelected,true);

            end



            if app.isValidUi(app.UIDataLoaderTable)
                app.UIDataLoaderTable.ColumnName = {'Parameter';'Value'};
                app.UIDataLoaderTable.RowName = {};
                app.UIDataLoaderTable.ColumnEditable = [false true];
                app.UIDataLoaderTable.ColumnWidth = {150,250};
                app.UIDataLoaderTable.CellEditCallback = createCallbackFcn(app,@UIDataLoaderTableCellEdit,true);
            end



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

            app.colorColorPicker.ValueChangedFcn = createCallbackFcn(app,@colorColorPickerValueChanged,true);

            app.ResetzoomButton.ButtonPushedFcn = createCallbackFcn(app,@ResetzoomButtonPushed,true);

            app.PanButton.ButtonPushedFcn = createCallbackFcn(app,@PanButtonPushed,true);

            if app.isValidUi(app.AdddataButton)
                app.AdddataButton.ButtonPushedFcn = createCallbackFcn(app,@AdddataButtonPushed,true);
            end

            if app.isValidUi(app.ROIgenerationmodeButtonGroup)
                app.ROIgenerationmodeButtonGroup.SelectionChangedFcn = createCallbackFcn(app,@ROIgenerationmodeButtonGroupSelectionChanged,true);
            end

            if app.isValidUi(app.UIROIParametersTable)
                app.UIROIParametersTable.ColumnName = {'Parameter';'Value'};
                app.UIROIParametersTable.RowName = {};
                app.UIROIParametersTable.ColumnEditable = [false true];
                app.UIROIParametersTable.ColumnWidth = {150,250};
                app.UIROIParametersTable.CellEditCallback = createCallbackFcn(app,@UIROIParametersTableCellEdit,true);
            end

            if app.isValidUi(app.SavepatternButton)
                app.SavepatternButton.ButtonPushedFcn = createCallbackFcn(app,@SavepatternButtonPushed,true);
            end
            if app.isValidUi(app.TestROIdetectionButton)
                app.TestROIdetectionButton.ButtonPushedFcn = createCallbackFcn(app,@TestROIdetectionButtonPushed,true);
            end
            if app.isValidUi(app.GenerateROIsButton)
                app.GenerateROIsButton.ButtonPushedFcn = createCallbackFcn(app,@GenerateROIsButtonPushed,true);
            end

            if app.isValidUi(app.UIExistingROIsTable)
                app.UIExistingROIsTable.ColumnName = {'Display';'Index';'ROI';'Value'};
                app.UIExistingROIsTable.RowName = {};
                app.UIExistingROIsTable.ColumnEditable = [true false false true];
                app.UIExistingROIsTable.ColumnWidth = {55,50,140,155};
                app.UIExistingROIsTable.CellEditCallback = createCallbackFcn(app,@UIExistingROIsTableCellEdit,true);
                app.UIExistingROIsTable.SelectionChangedFcn = createCallbackFcn(app,@UIExistingROIsTableSelectionChanged,true);
            end
            if app.isValidUi(app.selectallButton), app.selectallButton.ButtonPushedFcn = createCallbackFcn(app,@selectallButtonPushed,true); end
            if app.isValidUi(app.deselectallButton), app.deselectallButton.ButtonPushedFcn = createCallbackFcn(app,@deselectallButtonPushed,true); end
            if app.isValidUi(app.removeselectedButton), app.removeselectedButton.ButtonPushedFcn = createCallbackFcn(app,@removeselectedButtonPushed,true); end
            if app.isValidUi(app.SelectallButton), app.SelectallButton.ButtonPushedFcn = createCallbackFcn(app,@selectallButtonPushed,true); end
            if app.isValidUi(app.DeselectallButton), app.DeselectallButton.ButtonPushedFcn = createCallbackFcn(app,@deselectallButtonPushed,true); end
            if app.isValidUi(app.DeleteselectedButton), app.DeleteselectedButton.ButtonPushedFcn = createCallbackFcn(app,@removeselectedButtonPushed,true); end

            if app.isValidUi(app.UIROIsExtractionTable)
                app.UIROIsExtractionTable.ColumnName = {'Parameter';'Value'};
                app.UIROIsExtractionTable.RowName = {};
                app.UIROIsExtractionTable.ColumnEditable = [false true];
                app.UIROIsExtractionTable.ColumnWidth = {150,250};
                app.UIROIsExtractionTable.CellEditCallback = createCallbackFcn(app,@UIROIsExtractionTableCellEdit,true);
            end
            if app.isValidUi(app.ExtractROIsButton)
                app.ExtractROIsButton.ButtonPushedFcn = createCallbackFcn(app,@ExtractROIsButtonPushed,true);
            end
            if app.isValidUi(app.ProceedButton)
                app.ProceedButton.ButtonPushedFcn = createCallbackFcn(app,@ProceedButtonPushed,true);
            end
            if app.isValidUi(app.CancelButton)
                app.CancelButton.ButtonPushedFcn = createCallbackFcn(app,@CancelButtonPushed,true);
            end
            if app.isValidUi(app.RoiThresholdEditField)
                app.RoiThresholdEditField.ValueChangedFcn = createCallbackFcn(app,@RoiThresholdEditFieldValueChanged,true);
            end
            if app.isValidUi(app.CurrentROIsizeEditField)
                app.CurrentROIsizeEditField.ValueChangedFcn = createCallbackFcn(app,@RoiManualRectEditFieldValueChanged,true);
            end
            if app.isValidUi(app.UIROICandidateTable)
                app.UIROICandidateTable.ColumnName = {'Use';'Type';'x';'y';'w';'h'};
                app.UIROICandidateTable.RowName = {};
                app.UIROICandidateTable.ColumnEditable = [true false true true true true];
                app.UIROICandidateTable.ColumnWidth = {45,75,58,58,58,58};
                app.UIROICandidateTable.CellEditCallback = createCallbackFcn(app,@UIROICandidateTableCellEdit,true);
                app.UIROICandidateTable.SelectionChangedFcn = createCallbackFcn(app,@UIROICandidateTableSelectionChanged,true);
            end

            app.reflowTables();

        end


        function reflowTables(app)

            if app.isValidUi(app.UIDataLoaderTable)
                app.localSetTwoColWidth(app.UIDataLoaderTable, 150);
            end
            if app.isValidUi(app.UIROIParametersTable)
                app.localSetTwoColWidth(app.UIROIParametersTable, 150);
            end
            if app.isValidUi(app.UIROIsExtractionTable)
                app.localSetTwoColWidth(app.UIROIsExtractionTable, 150);
            end
            if app.isValidUi(app.UIROICandidateTable)
                tw = max(220, app.UIROICandidateTable.Position(3) - 18);
                w = [45 75 58 58 58 58];
                if sum(w) > tw
                    w = max(40, floor(w * (tw / sum(w))));
                end
                app.UIROICandidateTable.ColumnWidth = num2cell(w);
            end

            if ~isempty(app.UIFOVTable) && isvalid(app.UIFOVTable)
                tw = max(180, app.UIFOVTable.Position(3) - 18);
                w1 = 90;
                w2 = max(120, tw - w1);
                app.UIFOVTable.ColumnWidth = {w1, w2};
            end

            if ~isempty(app.UIDisplayChannelTable) && isvalid(app.UIDisplayChannelTable)
                tw = max(300, app.UIDisplayChannelTable.Position(3) - 18);
                w = [55, 120, 95, 80, 70, 45];
                w(2) = max(120, tw - sum(w([1 3 4 5 6])));
                if sum(w) > tw
                    scale = tw / sum(w);
                    w = max(40, floor(w .* scale));
                end
                app.UIDisplayChannelTable.ColumnWidth = num2cell(w);
            end

            if ~isempty(app.UIExistingROIsTable) && isvalid(app.UIExistingROIsTable)
                tw = max(240, app.UIExistingROIsTable.Position(3) - 18);
                w = [60, 55, 140, max(110, tw - (60 + 55 + 140))];
                if sum(w) > tw
                    scale = tw / sum(w);
                    w = max(35, floor(w .* scale));
                end
                app.UIExistingROIsTable.ColumnWidth = num2cell(w);
            end

        end



        function localSetTwoColWidth(app, tbl, w1)

            if isempty(tbl) || ~isvalid(tbl)
                return;
            end
            tw = max(220, tbl.Position(3) - 18);
            w1 = min(max(90, w1), max(90, tw - 120));
            w2 = max(120, tw - w1);
            tbl.ColumnWidth = {w1, w2};

        end



        function UIFigureSizeChanged(app, event) %#ok<INUSD>

            app.reflowTables();

        end



        function pipe = loadOrCreateDefaultPipeline(app)

            pipe = [];

            if isempty(app.Project)

                return;

            end

            pipe = pipeline('', 'workflow2_roi_definition');

            try

                pipe.nodes = app.buildBuiltinNode(app.ModuleMode);
                pipe.edges = struct([]);
                pipe.branches = struct([]);

            catch

                pipe.nodes = app.buildBuiltinNode('roiManual');
                pipe.edges = struct([]);
                pipe.branches = struct([]);

            end

            return;

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

            return;

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

            if app.isValidUi(app.UIDataLoaderTable)

                app.refreshDataloaderTable();

            end

            app.refreshFovTable();

            app.refreshSelectedFovInfo();

            app.refreshDisplayChannels();

            app.refreshRoiMode();

            app.refreshRoiTables();
            app.refreshStaticParameterPanel();

            if app.isValidUi(app.UIROIsExtractionTable)

                app.refreshExtractionTable();

            end

            app.renderCurrentFrame();

            app.refreshTitle();

        end



        function refreshDataloaderTable(app)

            if ~app.isValidUi(app.UIDataLoaderTable)

                return;

            end

            params = struct();

            idx = app.findNodeIndex('dataLoader');

            if ~isempty(idx)

                params = app.Pipeline.nodes(idx).params;

            elseif ~isempty(app.Project) && isfield(app.Project.runProfiles,'dataloading') && isfield(app.Project.runProfiles.dataloading,'dataLoader')

                params = app.Project.runProfiles.dataloading.dataLoader;

            end

            app.UIDataLoaderTable.Data = app.structToTable(params);

        end

        function tf = isValidUi(app, h) %#ok<INUSD>

            tf = false;

            try

                tf = ~isempty(h) && isvalid(h);

            catch

                tf = false;

            end

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

                app.selectedFOVEditField.Value = '';

            else

                raw = workflowui.describeFov(fovObj);
                lines = regexp(raw, '\s*\|\s*', 'split');
                if isa(app.selectedFOVEditField, 'matlab.ui.control.TextArea')
                    app.selectedFOVEditField.Value = lines(:);
                else
                    app.selectedFOVEditField.Value = strjoin(lines, ' | ');
                end

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

                % Start with a single visible source. Enabling every entry is
                % especially expensive for stack-series datasets, where Z
                % planes are exposed as display channels (often 100+).
                app.ChannelCfg = repmat(struct('enabled',false,'name','','levels',[0 4095],'color',[1 1 1],'weight',1,'auto',true), numel(names), 1);

                for i = 1:numel(names)

                    app.ChannelCfg(i).name = names{i};

                    app.ChannelCfg(i).enabled = (i == 1);

                    app.ChannelCfg(i).color = [1 1 1];

                end

                app.restoreDisplaySettings(names);

                % A focused pattern editor must render its recorded source
                % channel on the very first refresh. This also overrides an
                % old display profile that may have all Z planes enabled.
                if strcmpi(app.normalizeFocusModuleName(app.FocusModule), 'roipattern') && ...
                        ~isempty(app.StartupParams) && isstruct(app.StartupParams)
                    try
                        [~, ~, ~, startupChanIdx] = app.extractPatternState(app.StartupParams);
                        startupChanIdx = round(double(startupChanIdx(1)));
                        if isfinite(startupChanIdx) && startupChanIdx >= 1 && startupChanIdx <= numel(app.ChannelCfg)
                            for cc = 1:numel(app.ChannelCfg)
                                app.ChannelCfg(cc).enabled = (cc == startupChanIdx);
                            end
                            app.SelectedChannelRow = startupChanIdx;
                        end
                    catch
                    end
                end

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

            app.colorColorPicker.Value = app.ChannelCfg(row).color;

        end



        function refreshRoiMode(app)

            mode = app.getCurrentRoiMode();

            app.Suppress = true;

            switch lower(mode)

                case 'roipattern'

                    if app.isValidUi(app.ROIgenerationmodeButtonGroup) && app.isValidUi(app.PatterndetectionpatternButton)
                        app.ROIgenerationmodeButtonGroup.SelectedObject = app.PatterndetectionpatternButton;
                    end

                case 'roigrid'

                    if app.isValidUi(app.ROIgenerationmodeButtonGroup) && app.isValidUi(app.GridselectiongridButton)
                        app.ROIgenerationmodeButtonGroup.SelectedObject = app.GridselectiongridButton;
                    end

                case 'roitracked'

                    if app.isValidUi(app.ROIgenerationmodeButtonGroup) && app.isValidUi(app.PatterndetectionpatternButton)
                        app.ROIgenerationmodeButtonGroup.SelectedObject = app.PatterndetectionpatternButton;
                    end

                otherwise

                    if app.isValidUi(app.ROIgenerationmodeButtonGroup) && app.isValidUi(app.ManualselectionmanualButton)
                        app.ROIgenerationmodeButtonGroup.SelectedObject = app.ManualselectionmanualButton;
                    end

            end

            app.Suppress = false;

            switch lower(app.getSelectedRoiMode())

                case 'roipattern'

                    if app.isValidUi(app.SavepatternButton), app.SavepatternButton.Enable = 'on'; end

                    if app.isValidUi(app.SavepatternButton), app.SavepatternButton.Text = 'Draw pattern'; end

                    if app.isValidUi(app.TestROIdetectionButton), app.TestROIdetectionButton.Enable = 'on'; end

                case 'roimanual'

                    if app.isValidUi(app.SavepatternButton), app.SavepatternButton.Enable = 'on'; end

                    if app.isValidUi(app.SavepatternButton), app.SavepatternButton.Text = 'Draw ROI'; end

                    if app.isValidUi(app.TestROIdetectionButton), app.TestROIdetectionButton.Enable = 'off'; end

                case 'roigrid'

                    if app.isValidUi(app.SavepatternButton), app.SavepatternButton.Enable = 'off'; end

                    if app.isValidUi(app.SavepatternButton), app.SavepatternButton.Text = 'Grid settings'; end

                    if app.isValidUi(app.TestROIdetectionButton), app.TestROIdetectionButton.Enable = 'on'; end

                    if app.isValidUi(app.TestROIdetectionButton), app.TestROIdetectionButton.Text = 'Preview grid'; end

                otherwise

                    if app.isValidUi(app.SavepatternButton), app.SavepatternButton.Enable = 'off'; end

                    if app.isValidUi(app.SavepatternButton), app.SavepatternButton.Text = 'Draw pattern'; end

                    if app.isValidUi(app.TestROIdetectionButton), app.TestROIdetectionButton.Enable = 'off'; end

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

                    app.savePipelineIfPersistent();

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

            if app.isValidUi(app.UIROIParametersTable)
                app.UIROIParametersTable.Data = data;
            end

            app.refreshExistingRoisTable();
            app.refreshRoiCandidateTable();

        end



        function refreshExistingRoisTable(app)

            fovObj = app.getSelectedFov();

            if isempty(fovObj) || isempty(fovObj.roi)

                app.RoiDisplayMask = false(0,1);

                app.SelectedRoi = [];

                if app.isValidUi(app.UIExistingROIsTable)
                    app.UIExistingROIsTable.Data = cell(0,4);
                end

                return;

            end

            if numel(fovObj.roi) == 1

                try

                    if isempty(fovObj.roi(1).id)

                        app.RoiDisplayMask = false(0,1);

                        app.SelectedRoi = [];

                        if app.isValidUi(app.UIExistingROIsTable)
                            app.UIExistingROIsTable.Data = cell(0,4);
                        end

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

            if app.isValidUi(app.UIExistingROIsTable)
                app.UIExistingROIsTable.Data = data;
            end

            app.Suppress = false;

        end

        function refreshRoiCandidateTable(app)

            if ~app.isValidUi(app.UIROICandidateTable)
                return;
            end

            app.syncCandidateStateFromCurrentMode();
            pos = round(double(app.RoiCandidateRects));
            if isempty(pos)
                app.UIROICandidateTable.Data = cell(0,6);
                return;
            end

            data = cell(size(pos,1),6);
            for i = 1:size(pos,1)
                data{i,1} = app.RoiCandidateSelected(i);
                data{i,2} = app.RoiCandidateSource{i};
                data{i,3} = pos(i,1);
                data{i,4} = pos(i,2);
                data{i,5} = pos(i,3);
                data{i,6} = pos(i,4);
            end
            app.UIROICandidateTable.Data = data;

        end

        function syncCandidateStateFromCurrentMode(app)

            mode = lower(char(string(app.getSelectedRoiMode())));
            switch mode
                case 'roipattern'
                    rects = round(double(app.PreviewRoiPositions));
                    src = repmat({'pattern'}, size(rects,1), 1);
                case 'roimanual'
                    rects = round(double(app.manualCandidateRects()));
                    src = repmat({'manual'}, size(rects,1), 1);
                case 'roigrid'
                    if isempty(app.PreviewRoiPositions)
                        rects = round(double(app.gridCandidateRectsFromCurrentImage()));
                    else
                        rects = round(double(app.PreviewRoiPositions));
                    end
                    src = repmat({'grid'}, size(rects,1), 1);
                otherwise
                    rects = zeros(0,4);
                    src = {};
            end

            if isempty(rects)
                app.RoiCandidateRects = zeros(0,4);
                app.RoiCandidateSelected = false(0,1);
                app.RoiCandidateSource = {};
                app.SelectedCandidateRow = NaN;
                return;
            end

            oldRects = round(double(app.RoiCandidateRects));
            oldSel = app.RoiCandidateSelected;
            sel = true(size(rects,1),1);
            for i = 1:size(rects,1)
                if ~isempty(oldRects)
                    match = find(all(oldRects == rects(i,:), 2), 1, 'first');
                    if ~isempty(match) && match <= numel(oldSel)
                        sel(i) = logical(oldSel(match));
                    end
                end
            end
            app.RoiCandidateRects = rects;
            app.RoiCandidateSelected = sel;
            app.RoiCandidateSource = src;
            if isnan(app.SelectedCandidateRow) || app.SelectedCandidateRow < 1 || app.SelectedCandidateRow > size(rects,1)
                app.SelectedCandidateRow = 1;
            end

        end

        function rects = manualCandidateRects(app)

            rects = zeros(0,4);
            if ~isempty(app.PendingManualRect)
                rects = round(double(app.PendingManualRect(:,1:4)));
                return;
            end
            try
                if ~isempty(app.RoiEditHandle) && isvalid(app.RoiEditHandle)
                    rects = round(double(app.RoiEditHandle.Position));
                    return;
                end
            catch
            end

        end

        function storeManualRoisForFov(app, fovIdx)

            if nargin < 2 || isempty(fovIdx) || ~isfinite(double(fovIdx))
                return;
            end
            fovIdx = round(double(fovIdx(1)));
            if fovIdx < 1
                return;
            end

            rects = app.PendingManualRect;
            rects = app.validManualRectRows(rects);
            keep = true(1, numel(app.ManualRoiRecords));
            for ii = 1:numel(app.ManualRoiRecords)
                try
                    keep(ii) = round(double(app.ManualRoiRecords(ii).fovIndex)) ~= fovIdx;
                catch
                    keep(ii) = true;
                end
            end
            app.ManualRoiRecords = app.ManualRoiRecords(keep);

            for ii = 1:size(rects,1)
                app.ManualRoiRecords(end+1,1) = struct('fovIndex', fovIdx, 'rect', round(double(rects(ii,1:4)))); %#ok<AGROW>
            end

        end

        function storeManualRoisForSelectedFov(app)

            if strcmpi(app.getSelectedRoiMode(), 'roiManual') && ~isempty(app.SelectedFov)
                app.storeManualRoisForFov(app.SelectedFov);
            end

        end

        function loadManualRoisForSelectedFov(app, fallbackRects)

            if ~strcmpi(app.getSelectedRoiMode(), 'roiManual') || isempty(app.SelectedFov)
                return;
            end
            if nargin < 2
                fallbackRects = zeros(0,4);
            end
            fallbackRects = app.validManualRectRows(fallbackRects);
            app.clearRoiEditor();
            fovIdx = round(double(app.SelectedFov(1)));
            rects = zeros(0,4);
            for ii = 1:numel(app.ManualRoiRecords)
                try
                    if round(double(app.ManualRoiRecords(ii).fovIndex)) == fovIdx
                        rects(end+1,1:4) = round(double(app.ManualRoiRecords(ii).rect(1:4))); %#ok<AGROW>
                    end
                catch
                end
            end
            inheritedFromPreviousFov = isempty(rects) && ~isempty(fallbackRects);
            if inheritedFromPreviousFov
                rects = fallbackRects;
            end
            app.PendingManualRect = app.validManualRectRows(rects);
            if isempty(app.PendingManualRect)
                app.SelectedCandidateRow = NaN;
            else
                app.SelectedCandidateRow = 1;
            end
            app.RoiCandidateRects = zeros(0,4);
            app.RoiCandidateSelected = false(0,1);
            app.RoiCandidateSource = {};
            app.SelectedRoi = [];
            app.SelectedRoiRows = zeros(1,0);
            if inheritedFromPreviousFov
                app.storeManualRoisForFov(fovIdx);
            end

        end

        function rects = validManualRectRows(app, rects) %#ok<INUSD>

            if isempty(rects)
                rects = zeros(0,4);
                return;
            end
            rects = double(rects);
            if isvector(rects) && numel(rects) >= 4
                rects = reshape(rects(1:4), 1, 4);
            elseif size(rects,2) < 4 && size(rects,1) >= 4
                rects = rects';
            end
            if size(rects,2) < 4
                rects = zeros(0,4);
                return;
            end
            rects = round(double(rects(:,1:4)));
            keep = all(isfinite(rects), 2) & rects(:,3) > 0 & rects(:,4) > 0;
            rects = rects(keep,:);

        end

        function records = currentManualRoiRecords(app)

            app.storeManualRoisForSelectedFov();
            records = app.ManualRoiRecords;
            if isempty(records)
                rects = app.validManualRectRows(app.manualCandidateRects());
                if ~isempty(rects)
                    fovIdx = app.SelectedFov;
                    if isempty(fovIdx) || ~isfinite(double(fovIdx))
                        fovIdx = 1;
                    end
                    for ii = 1:size(rects,1)
                        records(end+1,1) = struct('fovIndex', round(double(fovIdx(1))), 'rect', rects(ii,1:4)); %#ok<AGROW>
                    end
                end
            end

        end

        function initializeManualRoiRecordsFromParams(app, params)

            app.ManualRoiRecords = repmat(struct('fovIndex', [], 'rect', []), 0, 1);
            if ~isstruct(params) || isempty(params)
                return;
            end
            if isfield(params, 'manualRois') && isstruct(params.manualRois) && ~isempty(params.manualRois)
                for ii = 1:numel(params.manualRois)
                    rec = params.manualRois(ii);
                    rect = [];
                    if isfield(rec, 'rect') && ~isempty(rec.rect)
                        rect = rec.rect;
                    elseif isfield(rec, 'position') && ~isempty(rec.position)
                        rect = rec.position;
                    elseif isfield(rec, 'value') && ~isempty(rec.value)
                        rect = rec.value;
                    end
                    if numel(rect) < 4
                        continue;
                    end
                    fovIdx = app.SelectedFov;
                    if isfield(rec, 'fovIndex') && ~isempty(rec.fovIndex)
                        fovIdx = round(double(rec.fovIndex(1)));
                    end
                    if isempty(fovIdx) || ~isfinite(double(fovIdx)) || fovIdx < 1
                        fovIdx = 1;
                    end
                    rect = app.validManualRectRows(double(rect(1:4)));
                    if ~isempty(rect)
                        app.ManualRoiRecords(end+1,1) = struct('fovIndex', fovIdx, 'rect', rect(1,1:4)); %#ok<AGROW>
                    end
                end
                return;
            end

            rects = app.extractManualRects(params);
            rects = app.validManualRectRows(rects);
            if isempty(rects)
                return;
            end
            fovIdx = app.SelectedFov;
            if isfield(params, 'fovIndex') && ~isempty(params.fovIndex)
                fovIdx = round(double(params.fovIndex(1)));
            end
            if isempty(fovIdx) || ~isfinite(double(fovIdx)) || fovIdx < 1
                fovIdx = 1;
            end
            for ii = 1:size(rects,1)
                app.ManualRoiRecords(end+1,1) = struct('fovIndex', fovIdx, 'rect', rects(ii,1:4)); %#ok<AGROW>
            end

        end

        function drawManualCandidateOverlays(app)

            if ~strcmpi(app.getSelectedRoiMode(), 'roiManual') || isempty(app.PendingManualRect)
                return;
            end
            rects = round(double(app.PendingManualRect(:,1:4)));
            selectedRow = app.SelectedCandidateRow;
            for ii = 1:size(rects,1)
                if ~isnan(selectedRow) && ii == selectedRow
                    continue;
                end
                pos = rects(ii,:);
                if any(~isfinite(pos)) || pos(3) <= 0 || pos(4) <= 0
                    continue;
                end
                edge = [0 0.85 0.15];
                lw = 1.4;
                if ~isnan(selectedRow) && ii == selectedRow
                    edge = [0 1 0];
                    lw = 2.2;
                end
                x = [pos(1) pos(1)+pos(3) pos(1)+pos(3) pos(1)];
                y = [pos(2) pos(2) pos(2)+pos(4) pos(2)+pos(4)];
                patch(app.UIAxes, x, y, edge, 'FaceAlpha', 0.04, 'EdgeColor', 'none');
                rectangle(app.UIAxes, 'Position', pos, 'EdgeColor', edge, 'LineWidth', lw);
                text(app.UIAxes, pos(1), max(1,pos(2)-2), sprintf('M%d', ii), ...
                    'Color', edge, 'FontSize', 13, 'FontWeight', 'bold', 'Interpreter', 'none');
            end

        end

        function rects = gridCandidateRectsFromCurrentImage(app)

            rects = zeros(0,4);
            idx = app.findNodeIndex('roiGrid');
            if isempty(idx)
                return;
            end
            chanIdx = 1;
            try
                chanIdx = min(max(1, app.SelectedChannelRow), max(1, numel(app.ChannelCfg)));
            catch
            end
            img = app.getImage(chanIdx);
            if isempty(img)
                return;
            end
            params = app.Pipeline.nodes(idx).params;
            gridCount = app.getParamField(params, 'gridCount', 1);
            if isempty(gridCount) || ~isnumeric(gridCount)
                gridCount = 1;
            end
            gridCount = max(1, round(double(gridCount(1))));
            rects = app.gridRectsForImageSize(size(img,2), size(img,1), gridCount);

        end

        function rects = gridRectsForImageSize(app, widthPx, heightPx, gridCount) %#ok<INUSD>

            widthPx = max(1, round(double(widthPx)));
            heightPx = max(1, round(double(heightPx)));
            gridCount = max(1, round(double(gridCount)));
            if gridCount <= 1
                rects = [1 1 widthPx heightPx];
                return;
            end
            cols = ceil(sqrt(gridCount));
            rows = ceil(gridCount / cols);
            tileW = widthPx / cols;
            tileH = heightPx / rows;
            rects = zeros(gridCount, 4);
            for ii = 1:gridCount
                rr = ceil(ii / cols);
                cc = mod(ii - 1, cols) + 1;
                x = round((cc - 1) * tileW + 1);
                y = round((rr - 1) * tileH + 1);
                x2 = round(min(widthPx, cc * tileW));
                y2 = round(min(heightPx, rr * tileH));
                rects(ii,:) = [x y max(1, x2 - x + 1) max(1, y2 - y + 1)];
            end

        end

        function UIROICandidateTableCellEdit(app, event)

            if app.Suppress || isempty(event.Indices)
                return;
            end
            row = event.Indices(1);
            col = event.Indices(2);
            if row < 1 || row > size(app.RoiCandidateRects,1)
                return;
            end
            if col == 1
                app.RoiCandidateSelected(row) = logical(event.NewData);
            elseif col >= 3 && col <= 6
                vals = app.parseCandidateRowValues(row);
                if ~isempty(vals)
                    app.RoiCandidateRects(row,:) = vals;
                    app.SelectedCandidateRow = row;
                    app.applyCandidateStateToMode();
                end
            end
            app.refreshRoiCandidateTable();
            app.renderCurrentFrame();

        end

        function vals = parseCandidateRowValues(app, row)

            vals = [];
            try
                raw = app.UIROICandidateTable.Data(row,3:6);
                vals = round(double(cellfun(@(x)double(x), raw)));
                if numel(vals) ~= 4 || any(~isfinite(vals)) || vals(3) <= 0 || vals(4) <= 0
                    vals = [];
                end
            catch
                vals = [];
            end

        end

        function UIROICandidateTableSelectionChanged(app, event)

            if app.Suppress || isempty(event.Selection)
                return;
            end
            row = event.Selection(1,1);
            if row < 1 || row > size(app.RoiCandidateRects,1)
                return;
            end
            app.SelectedCandidateRow = row;
            app.applyCurrentCandidateToEditor(row);
            app.refreshManualRectEditField();
            app.renderCurrentFrame();

        end

        function applyCurrentCandidateToEditor(app, row)

            if nargin < 2 || isempty(row)
                row = app.SelectedCandidateRow;
            end
            if isnan(row) || row < 1 || row > size(app.RoiCandidateRects,1)
                return;
            end
            rect = round(double(app.RoiCandidateRects(row,1:4)));
            mode = lower(char(string(app.getSelectedRoiMode())));
            if strcmp(mode, 'roipattern')
                app.PreviewRoiPositions(row,:) = rect;
            elseif strcmp(mode, 'roigrid')
                if size(app.PreviewRoiPositions,1) < row
                    app.PreviewRoiPositions = app.RoiCandidateRects;
                end
                app.PreviewRoiPositions(row,:) = rect;
            else
                if isempty(app.PendingManualRect)
                    app.PendingManualRect = rect;
                elseif row >= 1 && row <= size(app.PendingManualRect,1)
                    app.PendingManualRect(row,:) = rect;
                else
                    app.PendingManualRect(end+1,1:4) = rect;
                    app.SelectedCandidateRow = size(app.PendingManualRect,1);
                end
                app.SelectedRoi = [];
                app.SelectedRoiRows = zeros(1,0);
                app.storeManualRoisForSelectedFov();
            end

        end

        function applyCandidateStateToMode(app)

            mode = lower(char(string(app.getSelectedRoiMode())));
            rects = round(double(app.RoiCandidateRects));
            switch mode
                case 'roipattern'
                    app.PreviewRoiPositions = rects;
                case 'roigrid'
                    app.PreviewRoiPositions = rects;
                case 'roimanual'
                    app.PendingManualRect = rects;
                    if isempty(rects)
                        app.SelectedCandidateRow = NaN;
                        app.clearRoiEditor();
                    elseif isnan(app.SelectedCandidateRow) || app.SelectedCandidateRow < 1 || app.SelectedCandidateRow > size(rects,1)
                        app.SelectedCandidateRow = 1;
                    end
                    app.storeManualRoisForSelectedFov();
            end

        end



        function refreshExtractionTable(app)

            if ~app.isValidUi(app.UIROIsExtractionTable)

                return;

            end

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

                    app.savePipelineIfPersistent();

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

            activeList = reshape(active,1,[]);

            nActive = numel(activeList);

            dLoad = [];

            uncached = false;
            for k = 1:nActive
                i = activeList(k);
                key = app.getImageCacheKey(app.SelectedFov, app.SelectedFrame, i);
                if ~app.isImageCachedKey(key)
                    uncached = true;
                    break;
                end
            end

            if uncached
                try
                    dLoad = uiprogressdlg(app.UIFigure, ...
                        'Title','Loading raw frame', ...
                        'Message',sprintf('Preparing channel 1/%d (frame %d)...', nActive, app.SelectedFrame), ...
                        'Value',0, ...
                        'Cancelable','off');
                    drawnow;
                catch
                    dLoad = [];
                end
            end

            for k = 1:nActive

                i = activeList(k);

                if ~isempty(dLoad)
                    dLoad.Value = max(0, (k-1) / nActive);
                    dLoad.Message = sprintf('Reading channel %d/%d: %s (frame %d)...', ...
                        k, nActive, char(string(app.ChannelCfg(i).name)), app.SelectedFrame);
                    drawnow limitrate;
                end

                key = app.getImageCacheKey(app.SelectedFov, app.SelectedFrame, i);

                imgs{i} = app.getImage(i);

                if ~isempty(dLoad)

                    dLoad.Value = min(1, k / nActive);

                    drawnow limitrate;

                end

            end

            if ~isempty(dLoad)

                try, close(dLoad); catch, end

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

                roiObj = fovObj.roi(i);

                pos = app.getRoiPosition(roiObj);

                if ~isempty(pos)

                    edge = app.getRoiEdgeColor(roiObj);

                    lw = 1.6;

                    if isequal(app.SelectedRoi, i)

                        edge = [1 1 0];

                        lw = 2.4;

                    end

                    x = [pos(1) pos(1)+pos(3) pos(1)+pos(3) pos(1)];

                    y = [pos(2) pos(2) pos(2)+pos(4) pos(2)+pos(4)];

                    p = patch(app.UIAxes, x, y, edge, 'FaceAlpha', 0.02, 'EdgeColor', 'none');

                    cmRoi = app.createRoiContextMenu(i);

                    try, p.ContextMenu = cmRoi; catch, end

                    p.UserData = i;

                    p.ButtonDownFcn = createCallbackFcn(app,@onRoiGraphicObjectClicked,true);

                    hRect = rectangle(app.UIAxes,'Position',pos,'EdgeColor',edge,'LineWidth',lw);

                    try, hRect.ContextMenu = cmRoi; catch, end

                    hRect.UserData = i;

                    hRect.ButtonDownFcn = createCallbackFcn(app,@onRoiGraphicObjectClicked,true);

                    ht=text(app.UIAxes, pos(1), max(1,pos(2)-2), sprintf('%d', i), 'Color', edge, 'FontSize', 14, 'FontWeight', 'bold', 'Interpreter', 'none');

                    ht.UserData = i;

                    ht.ButtonDownFcn = createCallbackFcn(app,@onRoiGraphicObjectClicked,true);

                    try, ht.ContextMenu = cmRoi; catch, end

                end

            end

            app.drawManualCandidateOverlays();

            previewMode = lower(char(string(app.getSelectedRoiMode())));

            for i = 1:size(app.PreviewRoiPositions,1)

                pos = app.PreviewRoiPositions(i,:);

                if strcmp(previewMode, 'roigrid')
                    edge = [1 0.6 0];
                    lineStyle = ':';
                    prefix = 'G';
                else
                    edge = [1 0 1];
                    lineStyle = '--';
                    prefix = 'T';
                end

                hPrev=rectangle(app.UIAxes,'Position',pos,'EdgeColor',edge,'LineWidth',1.2,'LineStyle',lineStyle);

                try, hPrev.ContextMenu = app.UIAxes.ContextMenu; catch, end

                text(app.UIAxes, pos(1), max(1,pos(2)-2), sprintf('%s%d', prefix, i), 'Color', edge, 'FontSize', 13, 'FontWeight', 'bold', 'Interpreter', 'none');

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

            app.drawWorkflow2OverlayLegend();

            hold(app.UIAxes,'off');

            title(app.UIAxes, sprintf('%s | frame %d', app.getFovLabel(app.SelectedFov), app.SelectedFrame), 'Interpreter', 'none');

            app.rebuildEditors();

            app.applyZoom();

            drawnow limitrate nocallbacks;

        end

        function drawWorkflow2OverlayLegend(app)

            try

                xl = xlim(app.UIAxes);
                yl = ylim(app.UIAxes);

                if numel(xl) < 2 || numel(yl) < 2

                    return;

                end

                x0 = xl(1) + 0.018 * abs(diff(xl));
                y0 = yl(1) + 0.035 * abs(diff(yl));
                dy = 0.032 * abs(diff(yl));

                mode = lower(char(string(app.getSelectedRoiMode())));
                items = app.roiLegendItems(mode);

                for i = 1:size(items, 1)

                    text(app.UIAxes, x0, y0 + (i-1)*dy, char(items{i,2}), ...
                        'Color', items{i,1}, ...
                        'BackgroundColor', [0 0 0], ...
                        'Margin', 2, ...
                        'FontSize', 11, ...
                        'FontWeight', 'bold', ...
                        'Interpreter', 'none', ...
                        'Tag', 'workflow2Legend');

                end

            catch

            end

        end

        function items = roiLegendItems(app, mode) %#ok<INUSD>

            switch lower(char(string(mode)))

                case 'roipattern'

                    items = { ...
                        [0 1 1], 'cyan existing ROI'; ...
                        [1 0 0], 'red extracted ROI'; ...
                        [1 0.5 0], 'orange pattern/edit'; ...
                        [1 1 0], 'yellow selected'; ...
                        [1 0 1], 'magenta preview'};

                case 'roigrid'

                    items = { ...
                        [0 1 1], 'cyan existing ROI'; ...
                        [1 0.5 0], 'orange grid preview'; ...
                        [1 1 0], 'yellow selected'};

                otherwise

                    items = { ...
                        [0 1 1], 'cyan existing ROI'; ...
                        [1 0 0], 'red extracted ROI'; ...
                        [1 0.5 0], 'orange drawn/edited ROI'; ...
                        [1 1 0], 'yellow selected'};

            end

        end



        function drawGridPreview(app, widthPx, heightPx)

            if ~strcmpi(app.getSelectedRoiMode(), 'roiGrid')

                return;

            end

            if ~isempty(app.PreviewRoiPositions)

                return;

            end

            idx = app.findNodeIndex('roiGrid');

            if isempty(idx)

                return;

            end

            params = app.Pipeline.nodes(idx).params;

            gridCount = app.getParamField(params, 'gridCount', 1);

            if isempty(gridCount) || ~isnumeric(gridCount)

                gridCount = 1;

            end

            gridCount = max(1, round(double(gridCount(1))));

            rects = app.gridRectsForImageSize(widthPx, heightPx, gridCount);
            for ii = 1:size(rects,1)
                rectangle(app.UIAxes, 'Position', rects(ii,:), 'EdgeColor', [1 0.6 0], 'LineWidth', 1.0, 'LineStyle', ':');
            end

        end



        function resetImageCache(app)

            app.Cache = containers.Map('KeyType','char','ValueType','any');

            app.CacheBytes = containers.Map('KeyType','char','ValueType','double');

            app.CacheOrder = {};

            app.CacheSizeBytes = 0;

        end



        function key = getImageCacheKey(app, fovIdx, frameIdx, channelIdx) %#ok<INUSL>

            key = sprintf('%d|%d|%d', double(fovIdx), double(frameIdx), double(channelIdx));

        end



        function tf = isImageCachedKey(app, key)

            tf = ~isempty(app.Cache) && isKey(app.Cache, key);

        end



        function touchImageCacheKey(app, key)

            if isempty(app.CacheOrder)

                app.CacheOrder = {key};

                return;

            end

            app.CacheOrder(strcmp(app.CacheOrder, key)) = [];

            app.CacheOrder{end+1} = key;

        end



        function storeImageCacheKey(app, key, im)

            if isempty(im)

                return;

            end

            if isempty(app.Cache) || isempty(app.CacheBytes)

                app.resetImageCache();

            end

            bytes = app.estimateImageBytes(im);

            if isKey(app.Cache, key)

                app.CacheSizeBytes = app.CacheSizeBytes - app.CacheBytes(key);

            end

            app.Cache(key) = im;

            app.CacheBytes(key) = bytes;

            app.CacheSizeBytes = app.CacheSizeBytes + bytes;

            app.touchImageCacheKey(key);

            app.trimImageCache();

        end



        function trimImageCache(app)

            while app.CacheSizeBytes > app.CacheMaxBytes && ~isempty(app.CacheOrder)

                key = app.CacheOrder{1};

                app.CacheOrder(1) = [];

                if isempty(app.Cache) || ~isKey(app.Cache, key)

                    continue;

                end

                if ~isempty(app.CacheBytes) && isKey(app.CacheBytes, key)

                    app.CacheSizeBytes = max(0, app.CacheSizeBytes - app.CacheBytes(key));

                    remove(app.CacheBytes, key);

                end

                remove(app.Cache, key);

            end

        end



        function bytes = estimateImageBytes(app, im) %#ok<INUSL>

            info = whos('im');

            bytes = double(info.bytes);

        end



        function im = getImage(app, channelIdx, fovIdx, frameIdx)

            im = [];

            if nargin < 3 || isempty(fovIdx)

                fovIdx = app.SelectedFov;

            end

            if nargin < 4 || isempty(frameIdx)

                frameIdx = app.SelectedFrame;

            end

            if isempty(fovIdx) || isempty(app.Project) || fovIdx < 1 || fovIdx > app.getFovCount()

                return;

            end

            key = app.getImageCacheKey(fovIdx, frameIdx, channelIdx);

            if app.isImageCachedKey(key)

                im = app.Cache(key);

                app.touchImageCacheKey(key);

                return;

            end

            try

                im = readImage(app.Project.fov(fovIdx), frameIdx, channelIdx);

                app.storeImageCacheKey(key, im);

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

                im = app.getImage(chanIdx);

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

        function pos = defaultManualRoiPosition(app)

            pos = app.getDefaultPatternPosition();

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
            app.refreshManualRectEditField();
            app.refreshRoiCandidateTable();

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

            app.savePipelineIfPersistent();

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



        function edge = getRoiEdgeColor(app, roiObj)

            st = app.getRoiExtractionState(roiObj);

            switch st

                case 'extracted'

                    edge = [1 0.2 0.2];

                case 'stale'

                    edge = [1 0.6 0.1];

                otherwise

                    edge = [0 1 1];

            end

        end



        function st = getRoiExtractionState(app, roiObj)

            st = 'unknown';

            try

                if ismethod(roiObj, 'getExtractionStatus')

                    st = char(string(roiObj.getExtractionStatus()));

                elseif isprop(roiObj,'extraction') && isstruct(roiObj.extraction) && isfield(roiObj.extraction,'status') && ~isempty(roiObj.extraction.status)

                    st = char(string(roiObj.extraction.status));

                end

            catch

            end

            st = lower(strtrim(st));

            if any(strcmp(st, {'not_extracted','extracted','stale'}))

                return;

            end

            st = 'unknown';

            try

                roiPath = char(string(roiObj.path));

                roiId = char(string(roiObj.id));

                if ~isempty(roiPath) && ~isempty(roiId)

                    h5File = fullfile(roiPath, ['im_' roiId '.h5']);

                    if isfile(h5File)

                        st = 'extracted';

                    else

                        st = 'not_extracted';

                    end

                end

            catch

            end

        end



        function setRoiExtractionStatus(app, roiObj, status)

            if isempty(roiObj)

                return;

            end

            try

                if ismethod(roiObj,'setExtractionStatus')

                    roiObj.setExtractionStatus(status);

                elseif isprop(roiObj,'extraction')

                    ex = struct('status',char(string(status)),'updatedAt','','runId','');

                    try

                        ex.updatedAt = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));

                    catch

                    end

                    roiObj.extraction = ex;

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

            if ~isempty(app.FocusModule) && ~isempty(app.findNodeIndex(app.FocusModule))

                mode = app.FocusModule;

                return;

            end

            mode = 'roiManual';

            if ~isempty(app.findNodeIndex('roiPattern')) || ~isempty(app.findNodeIndex('roiIdentify'))

                mode = 'roiPattern';

            elseif ~isempty(app.findNodeIndex('roiGrid'))

                mode = 'roiGrid';

            elseif ~isempty(app.findNodeIndex('roiManual'))

                mode = 'roiManual';

            elseif ~isempty(app.findNodeIndex('roiTracked'))

                mode = 'roiTracked';

            end

        end



        function mode = getSelectedRoiMode(app)

            if ~app.isValidUi(app.ROIgenerationmodeButtonGroup)
                mode = app.getCurrentRoiMode();
                return;
            end

            if isequal(app.ROIgenerationmodeButtonGroup.SelectedObject, app.PatterndetectionpatternButton)

                mode = 'roiPattern';

            elseif isequal(app.ROIgenerationmodeButtonGroup.SelectedObject, app.GridselectiongridButton)

                mode = 'roiGrid';

            elseif strcmpi(app.getCurrentRoiMode(),'roiTracked')

                mode = 'roiTracked';

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

                case 'roitracked'

                    params = roiTracked.setparam(struct());

                case 'roiextract'

                    params = roiExtract.setparam(struct());

                otherwise

                    params = struct();

            end

        end



        function ensureRoiNode(app, typeName)

            typeName = char(string(typeName));

            if ~isempty(app.findNodeIndex(typeName))

                app.FocusModule = typeName;

                return;

            end

            nodes = app.Pipeline.nodes;

            if any(strcmpi(typeName, {'roiPattern','roiIdentify','roiManual','roiGrid'}))

                keep = true(1, numel(nodes));

                for i = 1:numel(nodes)

                    if any(strcmpi(char(string(nodes(i).type)), {'roiPattern','roiIdentify','roiManual','roiGrid'}))

                        keep(i) = false;

                    end

                end

                nodes = nodes(keep);

            end

            newNode = app.buildBuiltinNode(typeName);

            insertPos = numel(nodes) + 1;

            for i = 1:numel(nodes)

                t = char(string(nodes(i).type));

                if strcmpi(t,'dataLoader')

                    insertPos = i + 1;

                end

                if strcmpi(typeName,'roiTracked') && any(strcmpi(t, {'roiPattern','roiIdentify','roiManual','roiGrid'}))

                    insertPos = i + 1;

                end

            end

            nodes = [nodes(1:insertPos-1), newNode, nodes(insertPos:end)];

            if strcmpi(typeName,'roiTracked')
                [nodes, ~] = app.ensureTrackedMaskSupportNodes(nodes);
            end

            app.Pipeline.nodes = nodes;

            app.rebuildCoreEdges();

            app.savePipelineIfPersistent();

            app.storePipelineLink(app.Pipeline);

            app.publishPipelineToWorkspace();

            app.FocusModule = typeName;

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

                if any(strcmpi(char(string(nodes(i).type)), {'roiPattern','roiManual','roiGrid','roiIdentify','roiTracked'}))

                    insertPos = i + 1;

                end

            end

            nodes = [nodes(1:insertPos-1), newNode, nodes(insertPos:end)];

            app.Pipeline.nodes = nodes;

            app.rebuildCoreEdges();

            app.savePipelineIfPersistent();

            app.storePipelineLink(app.Pipeline);

            app.publishPipelineToWorkspace();

            app.markDirty(true);

        end



        function rebuildCoreEdges(app)

            keep = true(1, numel(app.Pipeline.edges));

            coreTypes = {'dataLoader','roiPattern','roiIdentify','roiManual','roiGrid','roiTracked','roiExtract'};

            for i = 1:numel(app.Pipeline.edges)

                fromType = app.nodeTypeFromId(app.Pipeline.edges(i).from);

                toType = app.nodeTypeFromId(app.Pipeline.edges(i).to);

                if any(strcmpi(fromType, coreTypes)) || any(strcmpi(toType, coreTypes))

                    keep(i) = false;

                end

            end

            edges = app.Pipeline.edges(keep);
            if isempty(edges) || ~isstruct(edges)
                edges = struct( ...
                    'from', {}, ...
                    'to', {}, ...
                    'fromPort', {}, ...
                    'toPort', {}, ...
                    'condition', {});
            end

            dlId = app.nodeIdByType('dataLoader');

            sourceId = '';

            if ~isempty(app.nodeIdByType('roiPattern'))

                sourceId = app.nodeIdByType('roiPattern');

            elseif ~isempty(app.nodeIdByType('roiGrid'))

                sourceId = app.nodeIdByType('roiGrid');

            elseif ~isempty(app.nodeIdByType('roiManual'))

                sourceId = app.nodeIdByType('roiManual');

            elseif ~isempty(app.nodeIdByType('roiIdentify'))

                sourceId = app.nodeIdByType('roiIdentify');

            end

            trackedId = app.nodeIdByType('roiTracked');

            exId = app.nodeIdByType('roiExtract');
            maskSourceId = '';
            for iNode = 1:numel(app.Pipeline.nodes)
                n = app.Pipeline.nodes(iNode);
                t = '';
                if isfield(n,'type') && ~isempty(n.type)
                    t = lower(char(string(n.type)));
                end
                if ~strcmp(t,'classifier')
                    continue;
                end
                outs = {};
                if isfield(n,'outputs') && ~isempty(n.outputs)
                    outs = lower(cellstr(n.outputs(:)));
                end
                if isempty(outs)
                    try
                        ctr = pipelineNodeContract(n);
                        if isfield(ctr,'out') && ~isempty(ctr.out)
                            outs = lower({ctr.out.name});
                        end
                    catch
                    end
                end
                if any(strcmp(outs,'masks'))
                    maskSourceId = char(string(n.id));
                    break;
                end
            end

            if ~isempty(trackedId) && ~isempty(maskSourceId) && ~isempty(exId)

                if ~isempty(dlId) && ~isempty(sourceId)

                    edges(end+1) = struct('from',dlId,'to',sourceId,'fromPort','images','toPort','images','condition','');

                end

                if ~isempty(sourceId)

                    edges(end+1) = struct('from',sourceId,'to',exId,'fromPort','roiList','toPort','roiList','condition','');
                    edges(end+1) = struct('from',sourceId,'to',trackedId,'fromPort','roiList','toPort','roiList','condition','');

                end

                edges(end+1) = struct('from',exId,'to',maskSourceId,'fromPort','roiList','toPort','roiList','condition','');
                edges(end+1) = struct('from',maskSourceId,'to',trackedId,'fromPort','masks','toPort','masks','condition','');

                app.Pipeline.edges = edges;

                return;

            end

            if ~isempty(dlId) && ~isempty(sourceId)

                edges(end+1) = struct('from',dlId,'to',sourceId,'fromPort','images','toPort','images','condition','');

            end

            if ~isempty(sourceId) && ~isempty(trackedId)

                edges(end+1) = struct('from',sourceId,'to',trackedId,'fromPort','roiList','toPort','roiList','condition','');

            end
            if ~isempty(maskSourceId) && ~isempty(trackedId)
                edges(end+1) = struct('from',maskSourceId,'to',trackedId,'fromPort','masks','toPort','masks','condition','');
            end

            if ~isempty(trackedId) && ~isempty(exId)

                edges(end+1) = struct('from',trackedId,'to',exId,'fromPort','roiList','toPort','roiList','condition','');

            elseif ~isempty(sourceId) && ~isempty(exId)

                edges(end+1) = struct('from',sourceId,'to',exId,'fromPort','roiList','toPort','roiList','condition','');

            end

            app.Pipeline.edges = edges;

        end

        function [nodes, changed] = ensureTrackedMaskSupportNodes(app, nodes)

            changed = false;

            if nargin < 2 || isempty(nodes)

                nodes = app.Pipeline.nodes;

            end

            srcIdx = [];
            for i = 1:numel(nodes)
                if isfield(nodes(i),'type') && any(strcmpi(char(string(nodes(i).type)), {'roiPattern','roiIdentify','roiManual','roiGrid'}))
                    srcIdx = i;
                    break;
                end
            end
            if isempty(srcIdx)
                srcNode = app.buildBuiltinNode('roiPattern');
                if isempty(nodes)
                    nodes = srcNode;
                else
                    nodes = [srcNode nodes]; %#ok<AGROW>
                end
                changed = true;
            end

            exIdx = app.findNodeIndexInList(nodes, 'roiExtract');

            if isempty(exIdx)

                exNode = app.buildBuiltinNode('roiExtract');
                insertPos = numel(nodes) + 1;

                for i = 1:numel(nodes)

                    t = char(string(nodes(i).type));

                    if any(strcmpi(t, {'roiPattern','roiIdentify','roiManual','roiGrid','roiTracked'}))

                        insertPos = i + 1;

                    end

                end

                nodes = [nodes(1:insertPos-1), exNode, nodes(insertPos:end)]; %#ok<AGROW>
                changed = true;
                exIdx = app.findNodeIndexInList(nodes, 'roiExtract');

            end

            maskIdx = app.findMaskClassifierNodeIndexInList(nodes);

            if isempty(maskIdx)

                maskNode = app.buildDefaultMaskClassifierNode();

                if isempty(exIdx)

                    insertPos = numel(nodes) + 1;

                else

                    insertPos = exIdx + 1;

                end

                nodes = [nodes(1:insertPos-1), maskNode, nodes(insertPos:end)]; %#ok<AGROW>
                changed = true;

            end

        end

        function idx = findNodeIndexInList(app, nodes, typeName) %#ok<INUSD>

            idx = [];

            for i = 1:numel(nodes)

                if isfield(nodes(i),'type') && strcmpi(char(string(nodes(i).type)), char(string(typeName)))

                    idx = i;
                    return;

                end

            end

        end

        function idx = findMaskClassifierNodeIndexInList(app, nodes)

            idx = [];

            for i = 1:numel(nodes)

                if ~isfield(nodes(i),'type') || ~strcmpi(char(string(nodes(i).type)), 'classifier')

                    continue;

                end

                if app.nodeProducesMasks(nodes(i))

                    idx = i;
                    return;

                end

            end

        end

        function tf = nodeProducesMasks(app, node) %#ok<INUSD>

            tf = false;
            outs = {};

            if isfield(node,'outputs') && ~isempty(node.outputs)

                outs = lower(cellstr(node.outputs(:)));

            end

            if isempty(outs)

                try

                    ctr = pipelineNodeContract(node);
                    if isfield(ctr,'out') && ~isempty(ctr.out)
                        outs = lower({ctr.out.name});
                    end

                catch

                    outs = {};

                end

            end

            tf = any(strcmp(outs,'masks'));

        end

        function node = buildDefaultMaskClassifierNode(app) %#ok<INUSD>

            params = struct('pkg','cellposesam','outputName','tracked_masks');
            node = struct('id','classifier_mask_1','name','classifier_mask_1','type','classifier','func','cellposesam.classify','gui','classifierGUI','guiMode','replace','paramRequired',{{'pkg'}},'pkg','cellposesam','params',params,'inputs',{{'roiList'}},'outputs',{{'roiList','masks'}},'enabled',true,'status','','layout',[72 10 24 10]);

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

                case 'roitracked'

                    node.id = 'roitracked_1'; node.name = 'roitracked_1'; node.type = 'roiTracked'; node.func = 'roiTracked.process'; node.gui = 'roiTracked.ui'; node.params = app.getDefaultParams('roiTracked'); node.inputs = {'roiList','masks'}; node.outputs = {'roiList'}; node.layout = [48 10 20 10];

                case 'roiextract'

                    node.id = 'roiextract_1'; node.name = 'roiextract_1'; node.type = 'roiExtract'; node.func = 'roiExtract.process'; node.gui = 'roiExtract.ui'; node.params = app.getDefaultParams('roiExtract'); node.inputs = {'roiList'}; node.outputs = {'roiList','channels'}; node.layout = [60 10 20 10];

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

        function parsed = parseChannelValue(app, newData) %#ok<INUSD>

            if isnumeric(newData)

                parsed = double(newData(:)');

                return;

            end

            if islogical(newData)

                parsed = find(newData);

                return;

            end

            txt = strtrim(char(string(newData)));

            if isempty(txt) || strcmp(txt, '[]')

                parsed = {};

                return;

            end

            if ~isempty(regexp(txt, '^[0-9eE\\+\\-\\.\\,\\:\\;\\[\\]\\(\\)\\s]+$', 'once'))

                vals = str2num(txt); %#ok<ST2NM>

                if ~isempty(vals) || strcmp(txt, '[]')

                    parsed = double(vals(:)');

                    return;

                end

            end

            parts = regexp(txt, '\s*,\s*', 'split');
            parsed = parts(~cellfun('isempty', parts));

            if isempty(parsed)

                parsed = {txt};

            end

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

                case {'roipattern','roimanual','roigrid','roitracked'}

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

            elseif strcmpi(key, 'channels')

                params.(key) = app.parseChannelValue(newValue);

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

            app.savePipelineIfPersistent();

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

        function didSave = savePipelineIfPersistent(app)

            didSave = false;
            if isempty(app.Pipeline)
                return;
            end

            try
                [pipePath, ~] = app.Pipeline.getPath;
            catch
                pipePath = '';
            end

            if isempty(pipePath)
                return;
            end

            pipelineSave(app.Pipeline);
            didSave = true;

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

                app.saveWorkflowStateWithProgress();

            catch ME

                uialert(app.UIFigure, ME.message, 'Save error', 'Icon', 'error');

            end

        end

        function saveWorkflowStateWithProgress(app)

            d = uiprogressdlg(app.UIFigure, ...
                'Title','Save project', ...
                'Message','Preparing save...', ...
                'Cancelable','off');

            cleanupDlg = onCleanup(@() deleteProgressDialogLocal(d)); %#ok<NASGU>

            try, d.Indeterminate = 'on'; catch, end

            if ~isempty(app.Pipeline)

                try, d.Message = 'Saving pipeline template...'; catch, end

                app.savePipelineIfPersistent();

                app.publishPipelineToWorkspace();

            end

            if ~isempty(app.Project)

                try, d.Message = 'Saving project data...'; catch, end

                shallowSave(app.Project,'shallowObj');

            end

            app.markDirty(false);

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

                row = app.SelectedCandidateRow;
                if isnan(row) || row < 1 || row > size(app.PendingManualRect,1)
                    row = 1;
                end
                pos = double(app.PendingManualRect(row,1:4));

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



        function cm = createRoiContextMenu(app, idx)

            cm = uicontextmenu(app.UIFigure);

            uimenu(cm, 'Text', sprintf('Open ROI %d in score...', idx), 'MenuSelectedFcn', @(src,evt)app.openRoiInScoreByIndex(idx));

            uimenu(cm, 'Text', sprintf('Select ROI %d', idx), 'MenuSelectedFcn', @(src,evt)app.selectRoi(idx));

        end



        function OpenSelectedRoiInScoreMenuSelected(app)

            if isempty(app.SelectedRoi)

                uialert(app.UIFigure, 'Select one ROI first.', 'Open ROI', 'Icon', 'warning');

                return;

            end

            app.openRoiInScoreByIndex(app.SelectedRoi);

        end



        function onRoiGraphicClicked(app, idx)

            isDouble = app.isDoubleClickOnRow(idx, 'graphic');

            app.selectRoi(idx);

            if isDouble

                app.openRoiInScoreByIndex(idx);

            end

        end

        function onRoiGraphicObjectClicked(app, src, event) %#ok<INUSD>

            idx = [];

            try

                idx = double(src.UserData);

            catch

            end

            if isempty(idx) || ~isscalar(idx) || ~isfinite(idx)

                return;

            end

            app.onRoiGraphicClicked(round(idx));

        end



        function tf = isDoubleClickOnRow(app, row, source)

            t = posixtime(datetime('now'));

            if strcmpi(source, 'graphic')

                tf = isequal(app.LastGraphicRoiRow, row) && ((t - app.LastGraphicRoiClickTime) <= 0.45);

                app.LastGraphicRoiRow = row;

                app.LastGraphicRoiClickTime = t;

            else

                tf = isequal(app.LastTableRoiRow, row) && ((t - app.LastTableRoiClickTime) <= 0.45);

                app.LastTableRoiRow = row;

                app.LastTableRoiClickTime = t;

            end

        end



        function openRoiInScoreByIndex(app, idx)

            fovObj = app.getSelectedFov();

            if isempty(fovObj) || idx < 1 || idx > numel(fovObj.roi)

                return;

            end

            roiObj = fovObj.roi(idx);

            if ~app.isRoiExtractedForOpen(roiObj)

                uialert(app.UIFigure, sprintf('ROI %d is not extracted yet. Run ROI extraction first.', idx), 'ROI not extracted', 'Icon', 'warning');

                return;

            end

            try

                roiObj.parent = fovObj;

            catch

            end

            try

                if isempty(roiObj.image)

                    roiObj.load;

                end

            catch ME

                uialert(app.UIFigure, ME.message, 'ROI loading error', 'Icon', 'error');

                return;

            end

            if isempty(roiObj.image)

                uialert(app.UIFigure, sprintf('ROI %d has no extracted image on disk.', idx), 'ROI loading error', 'Icon', 'warning');

                return;

            end

            try

                figures = findall(0,'Type','figure');

                scoreFig = findobj(figures,'Name','ScoreApp');

                if ~isempty(scoreFig) && isprop(scoreFig,'RunningAppInstance')

                    scoreApp = scoreFig(1).RunningAppInstance;

                    if ~isempty(scoreApp) && isvalid(scoreApp)

                        scoreApp.addROI(roiObj);

                        return;

                    end

                end

            catch

            end

            try

                clear score
                rehash
                score(roiObj);

            catch ME

                uialert(app.UIFigure, ME.message, 'Open ROI error', 'Icon', 'error');

            end

        end



        function tf = isRoiExtractedForOpen(app, roiObj)

            tf = false;

            st = app.getRoiExtractionState(roiObj);

            if strcmp(st, 'extracted')

                tf = true;

                return;

            end

            try

                if ismethod(roiObj, 'isExtracted')

                    tf = logical(roiObj.isExtracted());

                    return;

                end

            catch

            end

        end



        function rebuildEditors(app)

            if strcmpi(app.getSelectedRoiMode(),'roiPattern')

                crop = app.getPatternCrop();

                if isempty(crop)

                    app.clearPatternEditor();

                else

                    app.createPatternEditor(crop);

                end

            else

                app.clearPatternEditor();

            end

            if strcmpi(app.getSelectedRoiMode(),'roiManual') && isempty(app.SelectedRoi) && ~isempty(app.PendingManualRect)

                row = app.SelectedCandidateRow;
                if isnan(row) || row < 1 || row > size(app.PendingManualRect,1)
                    row = 1;
                    app.SelectedCandidateRow = row;
                end
                app.createRoiEditor(app.PendingManualRect(row,1:4), 'pending');

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
            app.refreshManualRectEditField();
            app.refreshRoiCandidateTable();

        end



        function createRoiEditor(app, pos, modeName)

            app.clearRoiEditor();

            if strcmpi(modeName, 'pending')

                color = [0 1 0];

            else

                color = [1 1 0];

            end

            app.RoiEditHandle = drawrectangle(app.UIAxes, 'Position', pos, 'Color', color, 'LineWidth', 1.6);

            if strcmpi(app.getSelectedRoiMode(), 'roiManual')

                row = app.SelectedCandidateRow;
                if isempty(app.PendingManualRect)
                    app.PendingManualRect = round(double(pos(1,1:4)));
                    row = 1;
                elseif ~isnan(row) && row >= 1 && row <= size(app.PendingManualRect,1)
                    app.PendingManualRect(row,:) = round(double(pos(1,1:4)));
                else
                    app.PendingManualRect(end+1,1:4) = round(double(pos(1,1:4)));
                    row = size(app.PendingManualRect,1);
                end
                app.SelectedCandidateRow = row;
                app.storeManualRoisForSelectedFov();
                app.refreshManualRectEditField();
                app.refreshRoiCandidateTable();

            end

            if strcmpi(modeName, 'selected')

                cm = uicontextmenu(app.UIFigure);

                uimenu(cm, 'Text', 'Open ROI in score...', 'MenuSelectedFcn', @(src,evt)app.openRoiInScoreByIndex(app.SelectedRoi));

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

            pos = round(double(pos(1:4)));

            if strcmpi(app.getSelectedRoiMode(),'roimanual') && isempty(app.SelectedRoi)

                row = app.SelectedCandidateRow;
                if isempty(app.PendingManualRect)
                    app.PendingManualRect = pos;
                    row = 1;
                elseif ~isnan(row) && row >= 1 && row <= size(app.PendingManualRect,1)
                    app.PendingManualRect(row,:) = pos;
                else
                    row = 1;
                    app.PendingManualRect(row,:) = pos;
                end
                app.SelectedCandidateRow = row;
                app.storeManualRoisForSelectedFov();

                app.markDirty(true);

                app.refreshManualRectEditField();
                app.refreshRoiCandidateTable();

                return;

            end

            fovObj = app.getSelectedFov();

            if isempty(fovObj) || isempty(app.SelectedRoi) || app.SelectedRoi < 1 || app.SelectedRoi > numel(fovObj.roi)

                return;

            end

            fovObj.roi(app.SelectedRoi).value(1:4) = uint16(round(pos));

            app.setRoiExtractionStatus(fovObj.roi(app.SelectedRoi), 'stale');

            app.markDirty(true);

            app.refreshManualRectEditField();
            app.refreshRoiCandidateTable();

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

            [chanIdx, chanName] = app.getSelectedReferenceChannel();

            pat.channelIndex = chanIdx;

            pat.channel = chanName;



            pattimg = [];

            try

                src = app.getImage(chanIdx);

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

            app.savePipelineIfPersistent();

            app.storePipelineLink(app.Pipeline);

            app.publishPipelineToWorkspace();

            app.markDirty(true);

            app.refreshRoiTables();
            app.refreshManualRectEditField();
            app.refreshRoiCandidateTable();

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

            app.resetImageCache();

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

            fallbackRects = app.validManualRectRows(app.PendingManualRect);

            app.storeManualRoisForSelectedFov();

            app.clearRoiEditor();

            app.SelectedFov = event.Selection(1);

            app.PreviewRoiPositions = zeros(0,4);

            app.loadManualRoisForSelectedFov(fallbackRects);

            app.refreshAll();

        end



        function UIFOVTableCellEdit(app, event)

            if app.Suppress || isempty(event.Indices) || event.Indices(2) ~= 1

                return;

            end

            if logical(event.NewData)

                fallbackRects = app.validManualRectRows(app.PendingManualRect);

                app.storeManualRoisForSelectedFov();

                app.clearRoiEditor();

                app.SelectedFov = event.Indices(1);

                app.PreviewRoiPositions = zeros(0,4);

                app.loadManualRoisForSelectedFov(fallbackRects);

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
                    if logical(event.NewData)
                        app.SelectedChannelRow = row;
                    end

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



        function colorColorPickerValueChanged(app, event) %#ok<INUSD>

            if isempty(app.ChannelCfg)

                return;

            end

            row = min(max(1,app.SelectedChannelRow), numel(app.ChannelCfg));

            app.ChannelCfg(row).color = app.colorColorPicker.Value;

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

            selectedMode = app.getSelectedRoiMode();

            app.ensureRoiNode(selectedMode);

            app.FocusModule = selectedMode;

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



        function SavepatternButtonPushed(app, event) %#ok<INUSD>

            if isempty(app.Project) || isempty(app.getSelectedFov())

                return;

            end

            mode = lower(app.getSelectedRoiMode());

            switch mode

                case 'roimanual'

                    row = app.SelectedCandidateRow;
                    if ~isnan(row) && row >= 1 && row <= size(app.PendingManualRect,1)
                        pos = app.PendingManualRect(row,1:4);
                    else
                        pos = app.getSelectedRoiPositionOrDefault();
                        if isempty(pos)
                            pos = app.defaultManualRoiPosition();
                        end
                        if isempty(app.PendingManualRect)
                            app.PendingManualRect = round(double(pos(1,1:4)));
                            row = 1;
                        else
                            app.PendingManualRect(end+1,1:4) = round(double(pos(1,1:4)));
                            row = size(app.PendingManualRect,1);
                        end
                    end

                    app.SelectedRoi = [];
                    app.SelectedRoiRows = zeros(1,0);
                    app.SelectedCandidateRow = row;
                    app.storeManualRoisForSelectedFov();
                    app.markDirty(true);
                    app.refreshManualRectEditField();
                    app.refreshRoiCandidateTable();

                    app.renderCurrentFrame();
                    app.createRoiEditor(round(double(pos(1,1:4))), 'pending');

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

            if strcmpi(app.getSelectedRoiMode(), 'roiGrid')

                app.PreviewRoiPositions = round(double(app.gridCandidateRectsFromCurrentImage()));
                app.RoiCandidateRects = zeros(0,4);
                app.RoiCandidateSelected = false(0,1);
                app.RoiCandidateSource = {};
                app.refreshRoiCandidateTable();
                app.renderCurrentFrame();
                return;

            end

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

            app.refreshRoiCandidateTable();
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

            if ~strcmpi(mode,'roitracked') && ~keepExisting

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

                        records = app.currentManualRoiRecords();

                        if isempty(records)

                            uialert(app.UIFigure,'Draw or select one ROI first.','Manual ROI','Icon','warning');

                            return;

                        end

                        if numel(records) == 1

                            srcPos = round(double(records(1).rect(1:4)));

                            for ff = reshape(fovIndex,1,[])

                                if ~keepExisting

                                    app.Project.fov(ff).roi = roi;

                                end

                                app.Project.fov(ff).addROI(uint16(srcPos), app.Project.fov(ff).id);

                            end

                        else

                            missingFovs = [];
                            for ff = reshape(fovIndex,1,[])
                                hasFovRecord = false;
                                for rr = 1:numel(records)
                                    if round(double(records(rr).fovIndex)) == ff
                                        hasFovRecord = true;
                                        break;
                                    end
                                end
                                if ~hasFovRecord
                                    missingFovs(end+1) = ff; %#ok<AGROW>
                                end
                            end
                            if ~isempty(missingFovs)
                                uialert(app.UIFigure, ...
                                    sprintf('Manual ROI definition is missing for FOV(s): %s.', mat2str(missingFovs)), ...
                                    'Manual ROI', 'Icon', 'warning');
                                return;
                            end

                            for ff = reshape(fovIndex,1,[])

                                if ~keepExisting

                                    app.Project.fov(ff).roi = roi;

                                end

                                for rr = 1:numel(records)
                                    if round(double(records(rr).fovIndex)) == ff
                                        app.Project.fov(ff).addROI(uint16(round(double(records(rr).rect(1:4)))), app.Project.fov(ff).id);
                                    end
                                end

                            end

                        end

                        if any(fovIndex == app.SelectedFov)

                            app.SelectedRoi = numel(app.Project.fov(app.SelectedFov).roi);

                        end

                        app.loadManualRoisForSelectedFov();

                        app.markDirty(true);

                    case 'roipattern'

                        d = uiprogressdlg(app.UIFigure,'Title','ROI pattern','Message',['Applying ROI pattern to ' scopeLabel '...']);

                        try, d.Indeterminate = 'on'; catch, end

                        out = app.runPatternDetection(fovIndex, false);

                        close(d);

                        app.PreviewRoiPositions = zeros(0,4);

                        disp(['[workflow][roiPattern] generated ROIs on ' num2str(numel(fovIndex)) ' FOV(s)']);

                        app.markDirty(true);

                    case 'roitracked'

                        idxTracked = app.findNodeIndex('roiTracked');

                        d = uiprogressdlg(app.UIFigure,'Title','Tracked ROI','Message',['Generating tracked ROIs on ' scopeLabel '...']);

                        try, d.Indeterminate = 'on'; catch, end

                        ctxTracked = struct('shallow', app.Project, 'roiTracked', app.Pipeline.nodes(idxTracked).params, 'interactive', false, 'fovIndex', fovIndex);

                        ctxTracked = roiTracked.process(ctxTracked);

                        close(d);

                        if isfield(ctxTracked,'roiTracked') && isstruct(ctxTracked.roiTracked)

                            app.Pipeline.nodes(idxTracked).params = ctxTracked.roiTracked;

                            app.savePipelineIfPersistent();

                            app.storePipelineLink(app.Pipeline);

                            app.publishPipelineToWorkspace();

                        end

                        app.PreviewRoiPositions = zeros(0,4);

                        app.markDirty(true);

                        out = [];

                        if isfield(ctxTracked,'createdTracked')

                            out = ctxTracked.createdTracked;

                        end

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

                            app.savePipelineIfPersistent();

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

            if strcmpi(mode,'roitracked') && exist('out','var') && ~isempty(out)

                for ff = reshape(fovIndex,1,[])

                    nCreated = 0;

                    try

                        nCreated = sum(double([out.fov]) == ff);

                    catch

                    end

                    summary{end+1,1} = sprintf('FOV %d: %d tracked ROI(s)', ff, nCreated); %#ok<AGROW>

                end

            else

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

                        app.setRoiExtractionStatus(fovObj.roi(row), 'stale');

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

            if isempty(rows)

                return;

            end

            row = rows(1);

            isDouble = app.isDoubleClickOnRow(row, 'table');

            app.SelectedRoi = row;

            app.selectRoi(row);

            if isDouble

                app.openRoiInScoreByIndex(row);

            end

        end



        function selectallButtonPushed(app, event) %#ok<INUSD>

            if ~isempty(app.RoiCandidateRects)
                app.RoiCandidateSelected(:) = true;
                app.refreshRoiCandidateTable();
                app.renderCurrentFrame();
                return;
            end

            if isempty(app.RoiDisplayMask), return; end

            app.RoiDisplayMask(:) = true;

            app.SelectedRoiRows = 1:numel(app.RoiDisplayMask);

            app.refreshExistingRoisTable();

            app.renderCurrentFrame();

        end



        function deselectallButtonPushed(app, event) %#ok<INUSD>

            if ~isempty(app.RoiCandidateRects)
                app.RoiCandidateSelected(:) = false;
                app.refreshRoiCandidateTable();
                app.renderCurrentFrame();
                return;
            end

            if isempty(app.RoiDisplayMask), return; end

            app.RoiDisplayMask(:) = false;

            app.SelectedRoi = [];

            app.SelectedRoiRows = zeros(1,0);

            app.refreshExistingRoisTable();

            app.renderCurrentFrame();

        end



        function removeselectedButtonPushed(app, event) %#ok<INUSD>

            if ~isempty(app.RoiCandidateRects)
                removeIdx = find(app.RoiCandidateSelected);
                if isempty(removeIdx)
                    return;
                end
                keepIdx = setdiff(1:size(app.RoiCandidateRects,1), removeIdx);
                app.RoiCandidateRects = app.RoiCandidateRects(keepIdx,:);
                app.RoiCandidateSelected = app.RoiCandidateSelected(keepIdx);
                app.RoiCandidateSource = app.RoiCandidateSource(keepIdx);
                if isempty(keepIdx)
                    app.SelectedCandidateRow = NaN;
                else
                    app.SelectedCandidateRow = min(max(1, app.SelectedCandidateRow), numel(keepIdx));
                end
                app.applyCandidateStateToMode();
                app.markDirty(true);
                app.refreshRoiCandidateTable();
                app.refreshManualRectEditField();
                app.renderCurrentFrame();
                return;
            end

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

            if nargin < 2 || isempty(fovIndex)

                fovIndex = app.SelectedFov;

            end

            if isempty(fovIndex)

                fovIndex = 1;

            end

            fovIndex = reshape(double(fovIndex), 1, []);

            ctx = struct('shallow', app.Project, ...
                'roiPattern', params, ...
                'interactive', false, ...
                'fovIndex', fovIndex, ...
                'resume', false, ...
                'saveProgress', false, ...
                'testOnly', logical(testOnly));

            disp(sprintf('[workflow][roiPattern] testOnly=%d fovIndex=%s', logical(testOnly), mat2str(fovIndex)));

            ctx = roiPattern.process(ctx);

            app.Project = ctx.shallow;

            if testOnly

                if isfield(ctx,'patternDetection') && ~isempty(ctx.patternDetection)

                    out = ctx.patternDetection;

                else

                    out = struct([]);

                end

                return;

            end

            if isfield(ctx,'roiPattern') && isstruct(ctx.roiPattern) && ~isempty(ctx.roiPattern)

                app.Pipeline.nodes(idx).params = ctx.roiPattern;

                app.savePipelineIfPersistent();

                app.storePipelineLink(app.Pipeline);

                app.publishPipelineToWorkspace();

            end

            out = struct([]);

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

                tmp = app.getImage(pix, srcIdx, frameid);

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

            app.cancelAndResume();

        end

        function proceedAndResume(app)

            try

                mode = app.getSelectedRoiMode();

                idx = app.findNodeIndex(mode);

                if ~isempty(idx)

                    params = app.collectWorkflow2RoiParams(mode, app.Pipeline.nodes(idx).params);
                    app.Pipeline.nodes(idx).params = params;
                    app.Result = params;

                else

                    app.Result = struct();

                end

            catch

                app.Result = struct();

            end

            app.Cancelled = false;

            try

                app.UIFigure.Visible = 'off';

            catch

            end

            try

                uiresume(app.UIFigure);

            catch

            end

        end

        function params = collectWorkflow2RoiParams(app, mode, params)

            if ~isstruct(params)

                params = struct();

            end

            [chanIdx, chanName] = app.getSelectedReferenceChannel();

            params.fovIndex = app.SelectedFov;
            params.referenceFrame = app.SelectedFrame;
            params.channelIndex = chanIdx;
            params.channel = chanName;

            switch lower(char(string(mode)))

                case 'roimanual'

                    app.syncCandidateStateFromCurrentMode();
                    records = app.currentManualRoiRecords();
                    if isempty(records)
                        posList = app.selectedCandidateRects();
                        if isempty(posList)
                            pos = app.getSelectedRoiPositionOrDefault();
                            if ~isempty(pos)
                                posList = round(double(pos(1,1:4)));
                            end
                        end
                        posList = app.validManualRectRows(posList);
                        if ~isempty(posList)
                            fovIdx = app.SelectedFov;
                            if isempty(fovIdx) || ~isfinite(double(fovIdx))
                                fovIdx = 1;
                            end
                            for rr = 1:size(posList,1)
                                records(end+1,1) = struct('fovIndex', round(double(fovIdx(1))), 'rect', posList(rr,1:4)); %#ok<AGROW>
                            end
                        end
                    end

                    if isempty(records)

                        params.manualRois = repmat(struct('fovIndex', [], 'frame', [], ...
                            'channelIndex', [], 'channel', '', 'rect', [], 'position', []), 0, 1);
                        params.manualRects = zeros(0,4);

                    else

                        rec = repmat(struct('fovIndex', [], 'frame', app.SelectedFrame, ...
                            'channelIndex', chanIdx, 'channel', chanName, 'rect', [], 'position', []), numel(records), 1);
                        currentRects = zeros(0,4);
                        selectedFov = app.SelectedFov;
                        if isempty(selectedFov) || ~isfinite(double(selectedFov))
                            selectedFov = [];
                        else
                            selectedFov = round(double(selectedFov(1)));
                        end
                        for rr = 1:numel(records)
                            rec(rr).fovIndex = round(double(records(rr).fovIndex));
                            rec(rr).rect = round(double(records(rr).rect(1:4)));
                            rec(rr).position = rec(rr).rect;
                            if ~isempty(selectedFov) && rec(rr).fovIndex == selectedFov
                                currentRects(end+1,1:4) = rec(rr).rect; %#ok<AGROW>
                            end
                        end
                        if isempty(currentRects) && numel(rec) == 1
                            currentRects = rec(1).rect;
                        end

                        params.manualRois = rec;
                        params.manualRects = round(double(currentRects(:,1:4)));
                        if ~isempty(params.manualRects)
                            app.PendingManualRect = params.manualRects(1,:);
                        end

                    end

                case 'roipattern'

                    if ~isempty(app.PatternHandle)

                        try

                            pos = double(app.PatternHandle.Position);
                            app.upsertPattern(pos);
                            idx = app.findNodeIndex('roiPattern');

                            if ~isempty(idx)

                                params = app.Pipeline.nodes(idx).params;

                            end

                        catch

                        end

                    end

                    app.syncCandidateStateFromCurrentMode();
                    selectedRects = app.selectedCandidateRects();
                    if ~isempty(selectedRects)
                        params.candidateRects = round(double(selectedRects(:,1:4)));
                        params.previewRects = params.candidateRects;
                    end

                case 'roigrid'

                    app.syncCandidateStateFromCurrentMode();
                    selectedRects = app.selectedCandidateRects();
                    if isempty(selectedRects)
                        selectedRects = app.gridCandidateRectsFromCurrentImage();
                    end
                    selectedRects = round(double(selectedRects(:,1:4)));
                    params.gridRects = selectedRects;
                    params.candidateRects = selectedRects;
                    params.previewRects = selectedRects;
                    params.gridCount = max(1, size(selectedRects, 1));
                    if params.gridCount > 1
                        params.mode = 'grid';
                    else
                        params.mode = 'fullframe';
                    end

            end

        end

        function rects = selectedCandidateRects(app)

            rects = zeros(0,4);
            if isempty(app.RoiCandidateRects)
                return;
            end
            sel = app.RoiCandidateSelected;
            if numel(sel) ~= size(app.RoiCandidateRects,1)
                sel = true(size(app.RoiCandidateRects,1),1);
            end
            rects = round(double(app.RoiCandidateRects(logical(sel),1:4)));

        end

        function [chanIdx, chanName] = getSelectedReferenceChannel(app)

            chanIdx = [];
            chanName = '';

            if ~isempty(app.ChannelCfg)

                enabledIdx = [];
                try
                    enabledIdx = find(arrayfun(@(c) isfield(c, 'enabled') && logical(c.enabled), app.ChannelCfg));
                catch
                    enabledIdx = [];
                end
                if numel(enabledIdx) == 1
                    chanIdx = enabledIdx(1);
                elseif ~isempty(enabledIdx) && ...
                        (isempty(app.SelectedChannelRow) || app.SelectedChannelRow < 1 || ...
                         app.SelectedChannelRow > numel(app.ChannelCfg) || ~ismember(app.SelectedChannelRow, enabledIdx))
                    chanIdx = enabledIdx(1);
                else
                    chanIdx = min(max(1, app.SelectedChannelRow), numel(app.ChannelCfg));
                end

                if chanIdx <= numel(app.ChannelCfg)

                    chanName = char(string(app.ChannelCfg(chanIdx).name));

                end

            end

            if isempty(chanIdx)

                chanIdx = 1;

            end

            if isempty(chanName)

                try

                    fovObj = app.getSelectedFov();
                    chanName = char(string(fovObj.channel{chanIdx}));

                catch

                    chanName = '';

                end

            end

        end

        function restoreWorkflow2RoiArtifact(app)

            mode = app.getSelectedRoiMode();
            idx = app.findNodeIndex(mode);

            if isempty(idx)

                return;

            end

            params = app.Pipeline.nodes(idx).params;

            switch lower(char(string(mode)))

                case 'roimanual'

                    app.initializeManualRoiRecordsFromParams(params);

                    if isfield(params, 'fovIndex') && ~isempty(params.fovIndex)

                        fovIdx = round(double(params.fovIndex(1)));

                        if isfinite(fovIdx) && fovIdx >= 1 && fovIdx <= app.getFovCount()

                            app.SelectedFov = fovIdx;

                        end

                    end

                    if isfield(params, 'referenceFrame') && ~isempty(params.referenceFrame)

                        frameIdx = round(double(params.referenceFrame(1)));

                        if isfinite(frameIdx)

                            app.SelectedFrame = max(1, frameIdx);

                        end

                    elseif isfield(params, 'frame') && ~isempty(params.frame)

                        frameIdx = round(double(params.frame(1)));

                        if isfinite(frameIdx)

                            app.SelectedFrame = max(1, frameIdx);

                        end

                    end

                    if isfield(params, 'channelIndex') && ~isempty(params.channelIndex)

                        chanIdx = round(double(params.channelIndex(1)));

                        if isfinite(chanIdx)

                            app.SelectedChannelRow = max(1, chanIdx);

                        end

                    end

                    app.loadManualRoisForSelectedFov();

                    app.refreshAll();

                case 'roipattern'

                    [rect, fovIdx, frameIdx, chanIdx] = app.extractPatternState(params);
                    app.SelectedRoi = [];
                    app.SelectedRoiRows = zeros(1,0);
                    if ~isempty(rect)
                        app.PreviewRoiPositions = zeros(0,4);
                        app.SelectedCandidateRow = NaN;
                        if ~isempty(fovIdx) && isfinite(fovIdx) && fovIdx >= 1 && fovIdx <= app.getFovCount()
                            app.SelectedFov = fovIdx;
                        end
                        if ~isempty(frameIdx) && isfinite(frameIdx)
                            app.SelectedFrame = max(1, frameIdx);
                        end
                        if ~isempty(chanIdx) && isfinite(chanIdx) && chanIdx >= 1
                            app.SelectedChannelRow = chanIdx;
                            try
                                for cc = 1:numel(app.ChannelCfg)
                                    app.ChannelCfg(cc).enabled = (cc == chanIdx);
                                end
                            catch
                            end
                        end
                    end
                    app.refreshAll();

            end

        end

        function [rect, fovIdx, frameIdx, chanIdx] = extractPatternState(app, params) %#ok<INUSD>
            rect = [];
            fovIdx = [];
            frameIdx = [];
            chanIdx = [];
            if ~isstruct(params) || isempty(params)
                return;
            end

            pat = struct([]);
            if isfield(params, 'pattern') && isstruct(params.pattern) && ~isempty(params.pattern)
                pat = params.pattern(1);
            elseif isfield(params, 'patternList') && isstruct(params.patternList) && ~isempty(params.patternList)
                pat = params.patternList(1);
            end

            rect = firstNumericVectorFieldLocal(params, pat, {'rect','crop','patternRect','position'}, 4);
            fovIdx = firstNumericScalarFieldLocal(params, pat, {'fovIndex','sourceFOV','sourceFov','patternSourceFOV'});
            frameIdx = firstNumericScalarFieldLocal(params, pat, {'referenceFrame','frame','sourceFrame','patternSourceFrame'});
            chanIdx = firstNumericScalarFieldLocal(params, pat, {'channelIndex','sourceChannelIndex','patternSourceChannelIndex'});
            if isempty(chanIdx)
                channelName = firstTextFieldLocal(params, pat, {'channel','sourceChannel','patternSourceChannel'});
                if ~isempty(channelName)
                    try
                        names = cellfun(@(x)char(string(x)), {app.ChannelCfg.name}, 'UniformOutput', false);
                        match = find(strcmp(names, channelName), 1);
                        if ~isempty(match)
                            chanIdx = match;
                        end
                    catch
                    end
                end
            end
        end

        function rect = extractManualRect(app, params) %#ok<INUSD>

            rects = app.extractManualRects(params);
            if isempty(rects)
                rect = [];
            else
                rect = rects(1,1:4);
            end

        end

        function rects = extractManualRects(app, params) %#ok<INUSD>

            rects = zeros(0,4);

            if ~isstruct(params) || isempty(params)

                return;

            end

            keys = {'manualRois','manualRects','rectangles','roiRects','rois','positions'};

            for i = 1:numel(keys)

                key = keys{i};

                if ~isfield(params, key) || isempty(params.(key))

                    continue;

                end

                value = params.(key);

                if isnumeric(value) && size(value, 2) >= 4

                    rects = double(value(:,1:4));
                    return;

                elseif isstruct(value)

                    out = zeros(0,4);
                    for jj = 1:numel(value)
                        vals = [];
                        if isfield(value, 'rect') && ~isempty(value(jj).rect)
                            vals = double(value(jj).rect);
                        elseif isfield(value, 'position') && ~isempty(value(jj).position)
                            vals = double(value(jj).position);
                        elseif isfield(value, 'value') && ~isempty(value(jj).value)
                            vals = double(value(jj).value);
                        end
                        if numel(vals) >= 4
                            out(end+1,:) = vals(1:4); %#ok<AGROW>
                        end
                    end
                    if ~isempty(out)
                        rects = out;
                        return;
                    end

                elseif iscell(value) && ~isempty(value)

                    out = zeros(0,4);
                    for jj = 1:numel(value)
                        vals = value{jj};
                        if isnumeric(vals) && numel(vals) >= 4
                            out(end+1,:) = double(vals(1:4)); %#ok<AGROW>
                        end
                    end
                    if ~isempty(out)
                        rects = out;
                        return;
                    end

                end

            end

        end

        function cancelAndResume(app)

            app.Cancelled = true;

            try

                app.UIFigure.Visible = 'off';

            catch

            end

            try

                uiresume(app.UIFigure);

            catch

            end

        end

        function ProceedButtonPushed(app, event) %#ok<INUSD>

            app.proceedAndResume();

        end

        function CancelButtonPushed(app, event) %#ok<INUSD>

            app.cancelAndResume();

        end

    end



    
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 1079 829];
            app.UIFigure.Name = 'MATLAB App';

            % Create UIAxes
            app.UIAxes = uiaxes(app.UIFigure);
            title(app.UIAxes, 'Title')
            xlabel(app.UIAxes, 'X')
            ylabel(app.UIAxes, 'Y')
            zlabel(app.UIAxes, 'Z')
            app.UIAxes.Position = [571 315 473 507];

            % Create ChannelsPanel
            app.ChannelsPanel = uipanel(app.UIFigure);
            app.ChannelsPanel.Title = 'Select channel and frame to display';
            app.ChannelsPanel.Position = [18 315 535 352];

            % Create LevelsSliderLabel
            app.LevelsSliderLabel = uilabel(app.ChannelsPanel);
            app.LevelsSliderLabel.HorizontalAlignment = 'right';
            app.LevelsSliderLabel.Position = [20 173 40 22];
            app.LevelsSliderLabel.Text = 'Levels';

            % Create LevelsSlider
            app.LevelsSlider = uislider(app.ChannelsPanel, 'range');
            app.LevelsSlider.Position = [74 182 150 3];

            % Create FrameSliderLabel
            app.FrameSliderLabel = uilabel(app.ChannelsPanel);
            app.FrameSliderLabel.HorizontalAlignment = 'right';
            app.FrameSliderLabel.Position = [279 171 40 22];
            app.FrameSliderLabel.Text = 'Frame';

            % Create FrameSlider
            app.FrameSlider = uislider(app.ChannelsPanel);
            app.FrameSlider.Position = [338 181 150 3];

            % Create ZoomSliderLabel
            app.ZoomSliderLabel = uilabel(app.ChannelsPanel);
            app.ZoomSliderLabel.HorizontalAlignment = 'right';
            app.ZoomSliderLabel.Position = [23 117 36 22];
            app.ZoomSliderLabel.Text = 'Zoom';

            % Create ZoomSlider
            app.ZoomSlider = uislider(app.ChannelsPanel);
            app.ZoomSlider.Position = [75 129 150 3];

            % Create colorColorPickerLabel
            app.colorColorPickerLabel = uilabel(app.ChannelsPanel);
            app.colorColorPickerLabel.HorizontalAlignment = 'right';
            app.colorColorPickerLabel.Position = [361 119 34 22];
            app.colorColorPickerLabel.Text = 'color:';

            % Create colorColorPicker
            app.colorColorPicker = uicolorpicker(app.ChannelsPanel);
            app.colorColorPicker.Position = [355 119 38 22];

            % Create FrameEditField
            app.FrameEditField = uieditfield(app.ChannelsPanel, 'numeric');
            app.FrameEditField.Position = [406 120 53 22];

            % Create PanButton
            app.PanButton = uibutton(app.ChannelsPanel, 'push');
            app.PanButton.Position = [407 91 76 23];
            app.PanButton.Text = 'Pan';

            % Create ResetzoomButton
            app.ResetzoomButton = uibutton(app.ChannelsPanel, 'push');
            app.ResetzoomButton.Position = [316 91 78 23];
            app.ResetzoomButton.Text = 'Reset zoom';

            % Create UIDisplayChannelTable
            app.UIDisplayChannelTable = uitable(app.ChannelsPanel);
            app.UIDisplayChannelTable.ColumnName = {'Display'; 'Name'; 'Levels'; 'RGB'; 'Weights'; 'auto'};
            app.UIDisplayChannelTable.RowName = {};
            app.UIDisplayChannelTable.Position = [9 201 513 122];

            % Create selectedFOVEditField
            app.selectedFOVEditField = uitextarea(app.ChannelsPanel);
            app.selectedFOVEditField.Editable = 'off';
            app.selectedFOVEditField.Tooltip = {'Display : path, size of image'};
            app.selectedFOVEditField.Position = [11 9 511 73];

            % Create SelectcurrentFOVtodisplayPanel
            app.SelectcurrentFOVtodisplayPanel = uipanel(app.UIFigure);
            app.SelectcurrentFOVtodisplayPanel.Title = 'Select current FOV to display';
            app.SelectcurrentFOVtodisplayPanel.Position = [4 676 547 146];

            % Create UIFOVTable
            app.UIFOVTable = uitable(app.SelectcurrentFOVtodisplayPanel);
            app.UIFOVTable.ColumnName = {'Select'; 'Name'};
            app.UIFOVTable.RowName = {};
            app.UIFOVTable.Position = [11 11 523 106];

            % Create ROIdefinitionPanel
            app.ROIdefinitionPanel = uipanel(app.UIFigure);
            app.ROIdefinitionPanel.Title = 'ROI definition';
            app.ROIdefinitionPanel.Position = [20 19 1024 286];

            % Create SavepatternButton
            app.SavepatternButton = uibutton(app.ROIdefinitionPanel, 'push');
            app.SavepatternButton.Position = [11 215 106 44];
            app.SavepatternButton.Text = 'Save pattern';

            % Create TestROIdetectionButton
            app.TestROIdetectionButton = uibutton(app.ROIdefinitionPanel, 'push');
            app.TestROIdetectionButton.Position = [419 216 103 42];
            app.TestROIdetectionButton.Text = 'Test ROI detection';

            % Create UIROICandidateTable
            app.UIROICandidateTable = uitable(app.ROIdefinitionPanel);
            app.UIROICandidateTable.ColumnName = {'Column 1'; 'Column 2'; 'Column 3'; 'Column 4'};
            app.UIROICandidateTable.RowName = {};
            app.UIROICandidateTable.Position = [13 15 510 150];

            % Create CurrentROIsizeEditFieldLabel
            app.CurrentROIsizeEditFieldLabel = uilabel(app.ROIdefinitionPanel);
            app.CurrentROIsizeEditFieldLabel.HorizontalAlignment = 'right';
            app.CurrentROIsizeEditFieldLabel.Position = [154 226 94 22];
            app.CurrentROIsizeEditFieldLabel.Text = 'Current ROI size';

            % Create CurrentROIsizeEditField
            app.CurrentROIsizeEditField = uieditfield(app.ROIdefinitionPanel, 'text');
            app.CurrentROIsizeEditField.Position = [279 226 100 22];

            % Create SelectallButton
            app.SelectallButton = uibutton(app.ROIdefinitionPanel, 'push');
            app.SelectallButton.Position = [15 181 100 23];
            app.SelectallButton.Text = 'Select all';

            % Create DeleteselectedButton
            app.DeleteselectedButton = uibutton(app.ROIdefinitionPanel, 'push');
            app.DeleteselectedButton.Position = [237 181 100 23];
            app.DeleteselectedButton.Text = 'Delete selected';

            % Create DeselectallButton
            app.DeselectallButton = uibutton(app.ROIdefinitionPanel, 'push');
            app.DeselectallButton.Position = [127 181 100 23];
            app.DeselectallButton.Text = 'Deselect all';

            % Create CancelButton
            app.CancelButton = uibutton(app.ROIdefinitionPanel, 'push');
            app.CancelButton.Position = [848 32 159 65];
            app.CancelButton.Text = 'Cancel';

            % Create ProceedButton
            app.ProceedButton = uibutton(app.ROIdefinitionPanel, 'push');
            app.ProceedButton.Position = [848 110 159 138];
            app.ProceedButton.Text = 'Proceed';

            % Create Panel
            app.Panel = uipanel(app.ROIdefinitionPanel);
            app.Panel.Title = 'ROI definition static parameters';
            app.Panel.Position = [535 23 298 232];

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion




    methods (Access = public)

        function app = workflow2(varargin)

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

function deleteProgressDialogLocal(d)
if isempty(d)
    return;
end
try
    if isvalid(d)
        close(d);
    end
catch
end
end

function value = firstNumericVectorFieldLocal(params, pat, keys, minCount)
value = [];
for i = 1:numel(keys)
    key = keys{i};
    candidate = [];
    if isstruct(params) && isfield(params, key) && ~isempty(params.(key))
        candidate = params.(key);
    elseif isstruct(pat) && isfield(pat, key) && ~isempty(pat.(key))
        candidate = pat.(key);
    end
    if isnumeric(candidate) && numel(candidate) >= minCount
        value = double(reshape(candidate(1:minCount), 1, []));
        return;
    end
end
end

function value = firstNumericScalarFieldLocal(params, pat, keys)
value = [];
for i = 1:numel(keys)
    key = keys{i};
    candidate = [];
    if isstruct(params) && isfield(params, key) && ~isempty(params.(key))
        candidate = params.(key);
    elseif isstruct(pat) && isfield(pat, key) && ~isempty(pat.(key))
        candidate = pat.(key);
    end
    if isnumeric(candidate) && ~isempty(candidate) && isfinite(double(candidate(1)))
        value = round(double(candidate(1)));
        return;
    end
end
end

function value = firstTextFieldLocal(params, pat, keys)
value = '';
for i = 1:numel(keys)
    key = keys{i};
    candidate = [];
    if isstruct(params) && isfield(params, key) && ~isempty(params.(key))
        candidate = params.(key);
    elseif isstruct(pat) && isfield(pat, key) && ~isempty(pat.(key))
        candidate = pat.(key);
    end
    if ~isempty(candidate)
        value = strtrim(char(string(candidate)));
        if ~isempty(value)
            return;
        end
    end
end
end
