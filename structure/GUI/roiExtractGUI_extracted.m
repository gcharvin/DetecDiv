classdef roiExtractGUI < matlab.apps.AppBase

    properties (Access = public)
        UIFigure                        matlab.ui.Figure
        MainLayout                      matlab.ui.container.GridLayout
        FramesEditFieldLabel            matlab.ui.control.Label
        FramesEditField                 matlab.ui.control.EditField
        ChannelsEditFieldLabel          matlab.ui.control.Label
        ChannelsEditField               matlab.ui.control.EditField
        CorrectDriftCheckBox            matlab.ui.control.CheckBox
        DriftChannelEditFieldLabel      matlab.ui.control.Label
        DriftChannelEditField           matlab.ui.control.EditField
        DriftMethodDropDownLabel        matlab.ui.control.Label
        DriftMethodDropDown             matlab.ui.control.DropDown
        DriftRefModeDropDownLabel       matlab.ui.control.Label
        DriftRefModeDropDown            matlab.ui.control.DropDown
        DriftSubpixelCheckBox           matlab.ui.control.CheckBox
        DriftMaxShiftEditFieldLabel     matlab.ui.control.Label
        DriftMaxShiftEditField          matlab.ui.control.NumericEditField
        ScaleEditFieldLabel             matlab.ui.control.Label
        ScaleEditField                  matlab.ui.control.NumericEditField
        CropDriftEditFieldLabel         matlab.ui.control.Label
        CropDriftEditField              matlab.ui.control.NumericEditField
        ExtendCheckBox                  matlab.ui.control.CheckBox
        ForceChannelNamesCheckBox       matlab.ui.control.CheckBox
        DescriptionTextArea             matlab.ui.control.TextArea
        ButtonLayout                    matlab.ui.container.GridLayout
        CancelButton                    matlab.ui.control.Button
        SaveButton                      matlab.ui.control.Button
    end

    properties (Access = public)
        Result struct = struct()
        Cancelled logical = true
    end

    properties (Access = private)
        InitialParams struct = struct()
    end

    methods (Access = private)

        function startupFcn(app, params)
            if nargin < 2 || isempty(params) || ~isstruct(params)
                params = roiExtract.setparam(struct());
            else
                params = mergeWithDefaults(app, params);
            end

            app.InitialParams = params;
            app.Result = params;
            populateFields(app, params);
        end

        function params = mergeWithDefaults(app, params) %#ok<INUSD>
            defaults = roiExtract.setparam(struct());
            fn = fieldnames(defaults);
            for i = 1:numel(fn)
                k = fn{i};
                if ~isfield(params, k) || isempty(params.(k))
                    params.(k) = defaults.(k);
                end
            end
        end

        function populateFields(app, params)
            app.FramesEditField.Value = formatNumericField(app, params.frames);
            app.ChannelsEditField.Value = formatChannelsField(app, params.channels);
            app.CorrectDriftCheckBox.Value = logical(defaultLogical(app, params.correctDrift, true));
            app.DriftChannelEditField.Value = formatNumericField(app, params.driftChannel);
            app.DriftMethodDropDown.Value = validateChoice(app, char(string(params.driftMethod)), app.DriftMethodDropDown.Items, 'subpixel');
            app.DriftRefModeDropDown.Value = validateChoice(app, char(string(params.driftRefMode)), app.DriftRefModeDropDown.Items, 'previous');
            app.DriftSubpixelCheckBox.Value = logical(defaultLogical(app, params.driftSubpixel, true));
            app.DriftMaxShiftEditField.Value = defaultNumeric(app, params.driftMaxShift, 20);
            app.ScaleEditField.Value = defaultNumeric(app, params.scale, 1);
            app.CropDriftEditField.Value = defaultNumeric(app, params.cropDrift, 1);
            app.ExtendCheckBox.Value = logical(defaultLogical(app, params.extend, false));
            app.ForceChannelNamesCheckBox.Value = logical(defaultLogical(app, params.forceChannelNames, true));
        end

        function value = defaultLogical(app, value, fallback) %#ok<INUSD>
            if isempty(value)
                value = fallback;
            end
        end

        function value = defaultNumeric(app, value, fallback) %#ok<INUSD>
            if isempty(value) || ~isscalar(value) || ~isfinite(value)
                value = fallback;
            end
        end

        function out = validateChoice(app, value, choices, fallback) %#ok<INUSD>
            if isempty(value)
                out = fallback;
                return;
            end
            if any(strcmp(choices, value))
                out = value;
            else
                out = fallback;
            end
        end

        function s = formatNumericField(app, v) %#ok<INUSD>
            if isempty(v)
                s = '';
                return;
            end
            if ischar(v)
                s = v;
                return;
            end
            try
                s = mat2str(v);
            catch
                s = '';
            end
        end

        function s = formatChannelsField(app, v) %#ok<INUSD>
            if isempty(v)
                s = '';
                return;
            end
            if ischar(v) || isstring(v)
                s = char(string(v));
                return;
            end
            if isnumeric(v)
                s = mat2str(v);
                return;
            end
            if iscell(v)
                tmp = cell(size(v));
                for i = 1:numel(v)
                    tmp{i} = char(string(v{i}));
                end
                s = strjoin(tmp, ', ');
                return;
            end
            s = '';
        end

        function out = parseNumericAnswer(app, txt) %#ok<INUSD>
            out = [];
            txt = strtrim(char(string(txt)));
            if isempty(txt)
                return;
            end
            try
                out = eval(['[' txt ']']); %#ok<EVLDIR>
                if ~isnumeric(out)
                    out = [];
                end
            catch
                out = [];
            end
        end

        function out = parseChannelsAnswer(app, txt)
            out = {};
            txt = strtrim(char(string(txt)));
            if isempty(txt)
                return;
            end
            numVal = parseNumericAnswer(app, txt);
            if ~isempty(numVal)
                out = numVal;
                return;
            end
            parts = regexp(txt, '\s*,\s*', 'split');
            parts = parts(~cellfun('isempty', parts));
            out = parts;
        end

        function saveAndClose(app)
            params = app.InitialParams;
            params.frames = parseNumericAnswer(app, app.FramesEditField.Value);
            params.channels = parseChannelsAnswer(app, app.ChannelsEditField.Value);
            params.correctDrift = logical(app.CorrectDriftCheckBox.Value);
            params.driftChannel = parseNumericAnswer(app, app.DriftChannelEditField.Value);
            params.driftMethod = char(string(app.DriftMethodDropDown.Value));
            params.driftRefMode = char(string(app.DriftRefModeDropDown.Value));
            params.driftSubpixel = logical(app.DriftSubpixelCheckBox.Value);
            params.driftMaxShift = app.DriftMaxShiftEditField.Value;
            params.scale = app.ScaleEditField.Value;
            params.cropDrift = app.CropDriftEditField.Value;
            params.extend = logical(app.ExtendCheckBox.Value);
            params.forceChannelNames = logical(app.ForceChannelNamesCheckBox.Value);

            app.Result = params;
            app.Cancelled = false;
            resumeAndClose(app);
        end

        function cancelAndClose(app)
            app.Cancelled = true;
            resumeAndClose(app);
        end

        function resumeAndClose(app)
            try
                uiresume(app.UIFigure);
            catch
            end
        end

        function SaveButtonPushed(app, event) %#ok<INUSD>
            saveAndClose(app);
        end

        function CancelButtonPushed(app, event) %#ok<INUSD>
            cancelAndClose(app);
        end

        function UIFigureCloseRequest(app, event) %#ok<INUSD>
            cancelAndClose(app);
        end
    end

    methods (Access = private)

        function createComponents(app)

            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 640 520];
            app.UIFigure.Name = 'ROI extraction parameters';
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @UIFigureCloseRequest, true);
            app.UIFigure.WindowStyle = 'modal';

            app.MainLayout = uigridlayout(app.UIFigure);
            app.MainLayout.ColumnWidth = {170, '1x'};
            app.MainLayout.RowHeight = {24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 24, 70, 44};
            app.MainLayout.Padding = [12 12 12 12];
            app.MainLayout.RowSpacing = 8;
            app.MainLayout.ColumnSpacing = 12;

            app.FramesEditFieldLabel = uilabel(app.MainLayout);
            app.FramesEditFieldLabel.Text = 'Frames';
            app.FramesEditFieldLabel.Layout.Row = 1;
            app.FramesEditFieldLabel.Layout.Column = 1;

            app.FramesEditField = uieditfield(app.MainLayout, 'text');
            app.FramesEditField.Layout.Row = 1;
            app.FramesEditField.Layout.Column = 2;

            app.ChannelsEditFieldLabel = uilabel(app.MainLayout);
            app.ChannelsEditFieldLabel.Text = 'Channels';
            app.ChannelsEditFieldLabel.Layout.Row = 2;
            app.ChannelsEditFieldLabel.Layout.Column = 1;

            app.ChannelsEditField = uieditfield(app.MainLayout, 'text');
            app.ChannelsEditField.Layout.Row = 2;
            app.ChannelsEditField.Layout.Column = 2;

            app.CorrectDriftCheckBox = uicheckbox(app.MainLayout);
            app.CorrectDriftCheckBox.Text = 'Correct XY drift';
            app.CorrectDriftCheckBox.Layout.Row = 3;
            app.CorrectDriftCheckBox.Layout.Column = [1 2];

            app.DriftChannelEditFieldLabel = uilabel(app.MainLayout);
            app.DriftChannelEditFieldLabel.Text = 'Drift channel';
            app.DriftChannelEditFieldLabel.Layout.Row = 4;
            app.DriftChannelEditFieldLabel.Layout.Column = 1;

            app.DriftChannelEditField = uieditfield(app.MainLayout, 'text');
            app.DriftChannelEditField.Layout.Row = 4;
            app.DriftChannelEditField.Layout.Column = 2;

            app.DriftMethodDropDownLabel = uilabel(app.MainLayout);
            app.DriftMethodDropDownLabel.Text = 'Drift method';
            app.DriftMethodDropDownLabel.Layout.Row = 5;
            app.DriftMethodDropDownLabel.Layout.Column = 1;

            app.DriftMethodDropDown = uidropdown(app.MainLayout);
            app.DriftMethodDropDown.Items = {'subpixel', 'integer'};
            app.DriftMethodDropDown.Layout.Row = 5;
            app.DriftMethodDropDown.Layout.Column = 2;

            app.DriftRefModeDropDownLabel = uilabel(app.MainLayout);
            app.DriftRefModeDropDownLabel.Text = 'Drift ref mode';
            app.DriftRefModeDropDownLabel.Layout.Row = 6;
            app.DriftRefModeDropDownLabel.Layout.Column = 1;

            app.DriftRefModeDropDown = uidropdown(app.MainLayout);
            app.DriftRefModeDropDown.Items = {'previous', 'first'};
            app.DriftRefModeDropDown.Layout.Row = 6;
            app.DriftRefModeDropDown.Layout.Column = 2;

            app.DriftSubpixelCheckBox = uicheckbox(app.MainLayout);
            app.DriftSubpixelCheckBox.Text = 'Use subpixel refinement';
            app.DriftSubpixelCheckBox.Layout.Row = 7;
            app.DriftSubpixelCheckBox.Layout.Column = [1 2];

            app.DriftMaxShiftEditFieldLabel = uilabel(app.MainLayout);
            app.DriftMaxShiftEditFieldLabel.Text = 'Max drift shift';
            app.DriftMaxShiftEditFieldLabel.Layout.Row = 8;
            app.DriftMaxShiftEditFieldLabel.Layout.Column = 1;

            app.DriftMaxShiftEditField = uieditfield(app.MainLayout, 'numeric');
            app.DriftMaxShiftEditField.Limits = [0 Inf];
            app.DriftMaxShiftEditField.Layout.Row = 8;
            app.DriftMaxShiftEditField.Layout.Column = 2;

            app.ScaleEditFieldLabel = uilabel(app.MainLayout);
            app.ScaleEditFieldLabel.Text = 'Scale';
            app.ScaleEditFieldLabel.Layout.Row = 9;
            app.ScaleEditFieldLabel.Layout.Column = 1;

            app.ScaleEditField = uieditfield(app.MainLayout, 'numeric');
            app.ScaleEditField.Limits = [0 Inf];
            app.ScaleEditField.Layout.Row = 9;
            app.ScaleEditField.Layout.Column = 2;

            app.CropDriftEditFieldLabel = uilabel(app.MainLayout);
            app.CropDriftEditFieldLabel.Text = 'Crop drift factor';
            app.CropDriftEditFieldLabel.Layout.Row = 10;
            app.CropDriftEditFieldLabel.Layout.Column = 1;

            app.CropDriftEditField = uieditfield(app.MainLayout, 'numeric');
            app.CropDriftEditField.Limits = [0 Inf];
            app.CropDriftEditField.Layout.Row = 10;
            app.CropDriftEditField.Layout.Column = 2;

            app.ExtendCheckBox = uicheckbox(app.MainLayout);
            app.ExtendCheckBox.Text = 'Extend existing ROI data';
            app.ExtendCheckBox.Layout.Row = 11;
            app.ExtendCheckBox.Layout.Column = 1;

            app.ForceChannelNamesCheckBox = uicheckbox(app.MainLayout);
            app.ForceChannelNamesCheckBox.Text = 'Force channel names';
            app.ForceChannelNamesCheckBox.Layout.Row = 11;
            app.ForceChannelNamesCheckBox.Layout.Column = 2;

            app.DescriptionTextArea = uitextarea(app.MainLayout);
            app.DescriptionTextArea.Editable = 'off';
            app.DescriptionTextArea.Value = { ...
                'Frames: numeric expression, blank = all.', ...
                'Channels: comma-separated names or numeric expression.', ...
                'Drift channel: leave blank to use package default.'};
            app.DescriptionTextArea.Layout.Row = 12;
            app.DescriptionTextArea.Layout.Column = [1 2];

            app.ButtonLayout = uigridlayout(app.MainLayout);
            app.ButtonLayout.ColumnWidth = {'1x', 100, 100};
            app.ButtonLayout.RowHeight = {30};
            app.ButtonLayout.Padding = [0 0 0 0];
            app.ButtonLayout.ColumnSpacing = 10;
            app.ButtonLayout.Layout.Row = 13;
            app.ButtonLayout.Layout.Column = [1 2];

            app.CancelButton = uibutton(app.ButtonLayout, 'push');
            app.CancelButton.Text = 'Cancel';
            app.CancelButton.ButtonPushedFcn = createCallbackFcn(app, @CancelButtonPushed, true);
            app.CancelButton.Layout.Row = 1;
            app.CancelButton.Layout.Column = 2;

            app.SaveButton = uibutton(app.ButtonLayout, 'push');
            app.SaveButton.Text = 'OK';
            app.SaveButton.ButtonPushedFcn = createCallbackFcn(app, @SaveButtonPushed, true);
            app.SaveButton.Layout.Row = 1;
            app.SaveButton.Layout.Column = 3;

            app.UIFigure.Visible = 'on';
        end
    end

    methods (Access = public)

        function app = roiExtractGUI(varargin)
            createComponents(app)
            registerApp(app, app.UIFigure)
            runStartupFcn(app, @(app)startupFcn(app, varargin{:}))

            if nargout == 0
                clear app
            end
        end

        function delete(app)
            try
                delete(app.UIFigure)
            catch
            end
        end
    end
end
