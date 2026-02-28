classdef dataLoaderGUI < matlab.apps.AppBase

    properties (Access = public)
        UIFigure                    matlab.ui.Figure
        MainLayout                  matlab.ui.container.GridLayout
        PathLabel                   matlab.ui.control.Label
        PathEditField               matlab.ui.control.EditField
        BrowseButton                matlab.ui.control.Button
        LabelLabel                  matlab.ui.control.Label
        LabelEditField              matlab.ui.control.EditField
        PositionFilterLabel         matlab.ui.control.Label
        PositionFilterEditField     matlab.ui.control.EditField
        ChannelFilterLabel          matlab.ui.control.Label
        ChannelFilterEditField      matlab.ui.control.EditField
        StackFilterLabel            matlab.ui.control.Label
        StackFilterEditField        matlab.ui.control.EditField
        PositionIdxLabel            matlab.ui.control.Label
        PositionIdxEditField        matlab.ui.control.EditField
        ChannelIdxLabel             matlab.ui.control.Label
        ChannelIdxEditField         matlab.ui.control.EditField
        FrameRangeLabel             matlab.ui.control.Label
        FrameRangeEditField         matlab.ui.control.EditField
        WriteCheckBox               matlab.ui.control.CheckBox
        InteractiveCheckBox         matlab.ui.control.CheckBox
        NotesTextArea               matlab.ui.control.TextArea
        ButtonLayout                matlab.ui.container.GridLayout
        CancelButton                matlab.ui.control.Button
        SaveButton                  matlab.ui.control.Button
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
                params = dataLoader.setparam(struct());
            else
                params = mergeWithDefaults(app, params);
            end
            app.InitialParams = params;
            app.Result = params;
            populateFields(app, params);
        end

        function params = mergeWithDefaults(app, params) %#ok<INUSD>
            defaults = dataLoader.setparam(struct());
            extra = struct('positionIdx', [], 'channelIdx', [], 'frameRange', []);
            defaults = mergeStructLocal(app, defaults, extra);
            params = mergeStructLocal(app, defaults, params);
        end

        function out = mergeStructLocal(app, base, patch) %#ok<INUSD>
            out = base;
            if nargin < 3 || ~isstruct(patch) || isempty(patch)
                return;
            end
            fn = fieldnames(patch);
            for i = 1:numel(fn)
                out.(fn{i}) = patch.(fn{i});
            end
        end

        function populateFields(app, p)
            app.PathEditField.Value = char(string(getFieldValue(app, p, 'path', '')));
            app.LabelEditField.Value = char(string(getFieldValue(app, p, 'label', '')));
            app.PositionFilterEditField.Value = formatFilterField(app, getFieldValue(app, p, 'positionFilter', {}));
            app.ChannelFilterEditField.Value = formatFilterField(app, getFieldValue(app, p, 'channelFilter', {}));
            app.StackFilterEditField.Value = formatFilterField(app, getFieldValue(app, p, 'stackFilter', {}));
            app.PositionIdxEditField.Value = formatNumericField(app, getFieldValue(app, p, 'positionIdx', []));
            app.ChannelIdxEditField.Value = formatNumericField(app, getFieldValue(app, p, 'channelIdx', []));
            app.FrameRangeEditField.Value = formatNumericField(app, getFieldValue(app, p, 'frameRange', []));
            app.WriteCheckBox.Value = logical(getFieldValue(app, p, 'write', true));
            app.InteractiveCheckBox.Value = logical(getFieldValue(app, p, 'interactive', false));
        end

        function v = getFieldValue(app, s, key, fallback) %#ok<INUSD>
            v = fallback;
            if isstruct(s) && isfield(s, key)
                tmp = s.(key);
                if ~isempty(tmp)
                    v = tmp;
                end
            end
        end

        function s = formatFilterField(app, v) %#ok<INUSD>
            if isempty(v)
                s = '';
                return;
            end
            if ischar(v) || isstring(v)
                s = char(string(v));
                return;
            end
            if iscell(v)
                parts = cell(1, numel(v));
                for i = 1:numel(v)
                    parts{i} = char(string(v{i}));
                end
                s = strjoin(parts, ', ');
                return;
            end
            s = '';
        end

        function s = formatNumericField(app, v) %#ok<INUSD>
            if isempty(v)
                s = '';
                return;
            end
            if ischar(v) || isstring(v)
                s = char(string(v));
                return;
            end
            try
                s = mat2str(v);
            catch
                s = '';
            end
        end

        function out = parseNumericExpr(app, txt) %#ok<INUSD>
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

        function out = parseFilterField(app, txt) %#ok<INUSD>
            out = {};
            txt = strtrim(char(string(txt)));
            if isempty(txt)
                return;
            end
            parts = regexp(txt, '\s*,\s*', 'split');
            parts = parts(~cellfun('isempty', parts));
            out = parts;
        end

        function BrowseButtonPushed(app, event) %#ok<INUSD>
            startDir = char(string(app.PathEditField.Value));
            if isempty(startDir) || ~isfolder(startDir)
                startDir = pwd;
            end
            picked = uigetdir(startDir, 'Select raw data folder');
            if isequal(picked, 0)
                return;
            end
            app.PathEditField.Value = picked;
        end

        function SaveButtonPushed(app, event) %#ok<INUSD>
            p = app.InitialParams;
            p.path = char(string(app.PathEditField.Value));
            p.label = char(string(app.LabelEditField.Value));
            p.positionFilter = parseFilterField(app, app.PositionFilterEditField.Value);
            p.channelFilter = parseFilterField(app, app.ChannelFilterEditField.Value);
            p.stackFilter = parseFilterField(app, app.StackFilterEditField.Value);
            p.positionIdx = parseNumericExpr(app, app.PositionIdxEditField.Value);
            p.channelIdx = parseNumericExpr(app, app.ChannelIdxEditField.Value);
            p.frameRange = parseNumericExpr(app, app.FrameRangeEditField.Value);
            p.write = logical(app.WriteCheckBox.Value);
            p.interactive = logical(app.InteractiveCheckBox.Value);
            app.Result = p;
            app.Cancelled = false;
            closeFigure(app);
        end

        function CancelButtonPushed(app, event) %#ok<INUSD>
            app.Cancelled = true;
            closeFigure(app);
        end

        function UIFigureCloseRequest(app, event) %#ok<INUSD>
            app.Cancelled = true;
            closeFigure(app);
        end

        function closeFigure(app)
            try
                uiresume(app.UIFigure);
            catch
            end
            try
                delete(app.UIFigure);
            catch
            end
        end
    end

    methods (Access = private)

        function createComponents(app)
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 760 520];
            app.UIFigure.Name = 'Data loader parameters';
            app.UIFigure.WindowStyle = 'modal';
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @UIFigureCloseRequest, true);

            app.MainLayout = uigridlayout(app.UIFigure);
            app.MainLayout.ColumnWidth = {150, '1x', 100};
            app.MainLayout.RowHeight = {24, 24, 24, 24, 24, 24, 24, 24, 24, 70, 40};
            app.MainLayout.Padding = [12 12 12 12];
            app.MainLayout.RowSpacing = 8;
            app.MainLayout.ColumnSpacing = 12;

            app.PathLabel = uilabel(app.MainLayout);
            app.PathLabel.Text = 'Raw data path';
            app.PathLabel.Layout.Row = 1;
            app.PathLabel.Layout.Column = 1;

            app.PathEditField = uieditfield(app.MainLayout, 'text');
            app.PathEditField.Layout.Row = 1;
            app.PathEditField.Layout.Column = 2;

            app.BrowseButton = uibutton(app.MainLayout, 'push');
            app.BrowseButton.Text = 'Browse...';
            app.BrowseButton.ButtonPushedFcn = createCallbackFcn(app, @BrowseButtonPushed, true);
            app.BrowseButton.Layout.Row = 1;
            app.BrowseButton.Layout.Column = 3;

            app.LabelLabel = uilabel(app.MainLayout);
            app.LabelLabel.Text = 'Label prefix';
            app.LabelLabel.Layout.Row = 2;
            app.LabelLabel.Layout.Column = 1;

            app.LabelEditField = uieditfield(app.MainLayout, 'text');
            app.LabelEditField.Layout.Row = 2;
            app.LabelEditField.Layout.Column = [2 3];

            app.PositionFilterLabel = uilabel(app.MainLayout);
            app.PositionFilterLabel.Text = 'Position filter';
            app.PositionFilterLabel.Layout.Row = 3;
            app.PositionFilterLabel.Layout.Column = 1;

            app.PositionFilterEditField = uieditfield(app.MainLayout, 'text');
            app.PositionFilterEditField.Layout.Row = 3;
            app.PositionFilterEditField.Layout.Column = [2 3];

            app.ChannelFilterLabel = uilabel(app.MainLayout);
            app.ChannelFilterLabel.Text = 'Channel filter';
            app.ChannelFilterLabel.Layout.Row = 4;
            app.ChannelFilterLabel.Layout.Column = 1;

            app.ChannelFilterEditField = uieditfield(app.MainLayout, 'text');
            app.ChannelFilterEditField.Layout.Row = 4;
            app.ChannelFilterEditField.Layout.Column = [2 3];

            app.StackFilterLabel = uilabel(app.MainLayout);
            app.StackFilterLabel.Text = 'Stack filter';
            app.StackFilterLabel.Layout.Row = 5;
            app.StackFilterLabel.Layout.Column = 1;

            app.StackFilterEditField = uieditfield(app.MainLayout, 'text');
            app.StackFilterEditField.Layout.Row = 5;
            app.StackFilterEditField.Layout.Column = [2 3];

            app.PositionIdxLabel = uilabel(app.MainLayout);
            app.PositionIdxLabel.Text = 'Run position idx';
            app.PositionIdxLabel.Layout.Row = 6;
            app.PositionIdxLabel.Layout.Column = 1;

            app.PositionIdxEditField = uieditfield(app.MainLayout, 'text');
            app.PositionIdxEditField.Layout.Row = 6;
            app.PositionIdxEditField.Layout.Column = [2 3];

            app.ChannelIdxLabel = uilabel(app.MainLayout);
            app.ChannelIdxLabel.Text = 'Run channel idx';
            app.ChannelIdxLabel.Layout.Row = 7;
            app.ChannelIdxLabel.Layout.Column = 1;

            app.ChannelIdxEditField = uieditfield(app.MainLayout, 'text');
            app.ChannelIdxEditField.Layout.Row = 7;
            app.ChannelIdxEditField.Layout.Column = [2 3];

            app.FrameRangeLabel = uilabel(app.MainLayout);
            app.FrameRangeLabel.Text = 'Run frame range';
            app.FrameRangeLabel.Layout.Row = 8;
            app.FrameRangeLabel.Layout.Column = 1;

            app.FrameRangeEditField = uieditfield(app.MainLayout, 'text');
            app.FrameRangeEditField.Layout.Row = 8;
            app.FrameRangeEditField.Layout.Column = [2 3];

            app.WriteCheckBox = uicheckbox(app.MainLayout);
            app.WriteCheckBox.Text = 'Write data into project';
            app.WriteCheckBox.Layout.Row = 9;
            app.WriteCheckBox.Layout.Column = 2;

            app.InteractiveCheckBox = uicheckbox(app.MainLayout);
            app.InteractiveCheckBox.Text = 'Interactive process call';
            app.InteractiveCheckBox.Layout.Row = 9;
            app.InteractiveCheckBox.Layout.Column = 3;

            app.NotesTextArea = uitextarea(app.MainLayout);
            app.NotesTextArea.Editable = 'off';
            app.NotesTextArea.Value = { ...
                'Filters are comma-separated strings used by parseInputData.', ...
                'Run position/channel/frame fields are optional overrides used by pipeline runs.', ...
                'Leave run fields blank to inherit the template behavior.'};
            app.NotesTextArea.Layout.Row = 10;
            app.NotesTextArea.Layout.Column = [1 3];

            app.ButtonLayout = uigridlayout(app.MainLayout);
            app.ButtonLayout.ColumnWidth = {'1x', 100, 100};
            app.ButtonLayout.RowHeight = {30};
            app.ButtonLayout.Padding = [0 0 0 0];
            app.ButtonLayout.ColumnSpacing = 10;
            app.ButtonLayout.Layout.Row = 11;
            app.ButtonLayout.Layout.Column = [1 3];

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

        function app = dataLoaderGUI(varargin)
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
