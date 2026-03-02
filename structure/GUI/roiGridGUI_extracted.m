classdef roiGridGUI < matlab.apps.AppBase

    properties (Access = public)
        UIFigure                    matlab.ui.Figure
        MainLayout                  matlab.ui.container.GridLayout
        PositionsEditFieldLabel     matlab.ui.control.Label
        PositionsEditField          matlab.ui.control.EditField
        ModeDropDownLabel           matlab.ui.control.Label
        ModeDropDown                matlab.ui.control.DropDown
        GridCountDropDownLabel      matlab.ui.control.Label
        GridCountDropDown           matlab.ui.control.DropDown
        KeepExistingCheckBox        matlab.ui.control.CheckBox
        DescriptionTextArea         matlab.ui.control.TextArea
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
        FovCount double = 0
    end

    methods (Access = private)

        function startupFcn(app, params, fovCount)
            if nargin < 2 || isempty(params) || ~isstruct(params)
                params = roiGrid.setparam(struct());
            else
                params = mergeWithDefaults(app, params);
            end
            if nargin < 3 || isempty(fovCount) || ~isscalar(fovCount) || ~isfinite(fovCount)
                fovCount = 0;
            end

            app.InitialParams = params;
            app.Result = params;
            app.FovCount = max(0, floor(double(fovCount)));
            populateFields(app, params);
        end

        function params = mergeWithDefaults(app, params) %#ok<INUSD>
            defaults = roiGrid.setparam(struct());
            fn = fieldnames(defaults);
            for i = 1:numel(fn)
                k = fn{i};
                if ~isfield(params, k) || isempty(params.(k))
                    params.(k) = defaults.(k);
                end
            end
            params = roiGrid.setparam(params);
        end

        function populateFields(app, params)
            app.PositionsEditField.Value = formatPositions(app, params.fovIndex);
            app.ModeDropDown.Value = validateMode(app, params.mode);
            app.GridCountDropDown.Value = validateGridCount(app, params.gridCount);
            app.KeepExistingCheckBox.Value = logical(defaultLogical(app, params.keepExisting, false));
        end

        function value = defaultLogical(app, value, fallback) %#ok<INUSD>
            if isempty(value)
                value = fallback;
            end
        end

        function txt = formatPositions(app, idx)
            if isempty(idx)
                if app.FovCount > 0
                    txt = sprintf('1:%d', app.FovCount);
                else
                    txt = '';
                end
                return;
            end
            if isnumeric(idx) && isvector(idx)
                idx = idx(:)';
                if numel(idx) >= 2
                    dv = diff(idx);
                    if all(abs(dv - dv(1)) < eps(max(1, abs(dv(1)))))
                        if abs(dv(1) - 1) < eps(max(1, abs(dv(1))))
                            txt = sprintf('%g:%g', idx(1), idx(end));
                        else
                            txt = sprintf('%g:%g:%g', idx(1), dv(1), idx(end));
                        end
                        return;
                    end
                end
                txt = mat2str(idx);
                return;
            end
            txt = char(string(idx));
        end

        function value = validateMode(app, mode) %#ok<INUSD>
            mode = lower(strrep(char(string(mode)), ' ', ''));
            if any(strcmp(mode, {'fullframe', 'full', 'single'}))
                value = 'fullframe';
            else
                value = 'grid';
            end
        end

        function value = validateGridCount(app, gridCount) %#ok<INUSD>
            items = app.GridCountDropDown.Items;
            value = '1';
            if isempty(gridCount) || ~isscalar(gridCount) || ~isfinite(gridCount)
                return;
            end
            candidate = num2str(round(gridCount));
            if any(strcmp(items, candidate))
                value = candidate;
            end
        end

        function idx = parsePositions(app, txt) %#ok<INUSD>
            idx = [];
            txt = strtrim(char(string(txt)));
            if isempty(txt)
                return;
            end
            try
                idx = eval(['[' txt ']']); %#ok<EVLDIR>
                if ~isnumeric(idx)
                    idx = [];
                else
                    idx = unique(reshape(double(idx), 1, []));
                end
            catch
                idx = [];
            end
        end

        function saveAndClose(app)
            params = app.InitialParams;
            params.fovIndex = parsePositions(app, app.PositionsEditField.Value);
            params.mode = char(string(app.ModeDropDown.Value));
            params.gridCount = str2double(app.GridCountDropDown.Value);
            params.keepExisting = logical(app.KeepExistingCheckBox.Value);
            params = roiGrid.setparam(params);
            if strcmpi(params.mode, 'fullframe')
                params.gridCount = 1;
            end

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
            app.UIFigure.Position = [100 100 520 300];
            app.UIFigure.Name = 'ROI grid parameters';
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @UIFigureCloseRequest, true);
            app.UIFigure.WindowStyle = 'modal';

            app.MainLayout = uigridlayout(app.UIFigure);
            app.MainLayout.ColumnWidth = {150, '1x'};
            app.MainLayout.RowHeight = {24, 24, 24, 24, '1x', 44};
            app.MainLayout.Padding = [12 12 12 12];
            app.MainLayout.RowSpacing = 8;
            app.MainLayout.ColumnSpacing = 12;

            app.PositionsEditFieldLabel = uilabel(app.MainLayout);
            app.PositionsEditFieldLabel.Text = 'Positions';
            app.PositionsEditFieldLabel.Layout.Row = 1;
            app.PositionsEditFieldLabel.Layout.Column = 1;

            app.PositionsEditField = uieditfield(app.MainLayout, 'text');
            app.PositionsEditField.Layout.Row = 1;
            app.PositionsEditField.Layout.Column = 2;

            app.ModeDropDownLabel = uilabel(app.MainLayout);
            app.ModeDropDownLabel.Text = 'Mode';
            app.ModeDropDownLabel.Layout.Row = 2;
            app.ModeDropDownLabel.Layout.Column = 1;

            app.ModeDropDown = uidropdown(app.MainLayout);
            app.ModeDropDown.Items = {'fullframe','grid'};
            app.ModeDropDown.Layout.Row = 2;
            app.ModeDropDown.Layout.Column = 2;

            app.GridCountDropDownLabel = uilabel(app.MainLayout);
            app.GridCountDropDownLabel.Text = 'Grid count';
            app.GridCountDropDownLabel.Layout.Row = 3;
            app.GridCountDropDownLabel.Layout.Column = 1;

            app.GridCountDropDown = uidropdown(app.MainLayout);
            app.GridCountDropDown.Items = {'1','4','9','16','25'};
            app.GridCountDropDown.Layout.Row = 3;
            app.GridCountDropDown.Layout.Column = 2;

            app.KeepExistingCheckBox = uicheckbox(app.MainLayout);
            app.KeepExistingCheckBox.Text = 'Keep existing ROIs';
            app.KeepExistingCheckBox.Layout.Row = 4;
            app.KeepExistingCheckBox.Layout.Column = [1 2];

            app.DescriptionTextArea = uitextarea(app.MainLayout);
            app.DescriptionTextArea.Layout.Row = 5;
            app.DescriptionTextArea.Layout.Column = [1 2];
            app.DescriptionTextArea.Editable = 'off';
            app.DescriptionTextArea.Value = { ...
                'Positions: numeric expression, blank = all positions.', ...
                'Mode fullframe creates one ROI covering the image.', ...
                'Mode grid splits the image into N equal tiles (N must be 1, 4, 9, 16, 25).'};

            app.ButtonLayout = uigridlayout(app.MainLayout);
            app.ButtonLayout.Layout.Row = 6;
            app.ButtonLayout.Layout.Column = [1 2];
            app.ButtonLayout.ColumnWidth = {'1x', 100, 100};
            app.ButtonLayout.RowHeight = {36};

            app.CancelButton = uibutton(app.ButtonLayout, 'push');
            app.CancelButton.Text = 'Cancel';
            app.CancelButton.Layout.Column = 2;
            app.CancelButton.ButtonPushedFcn = createCallbackFcn(app, @CancelButtonPushed, true);

            app.SaveButton = uibutton(app.ButtonLayout, 'push');
            app.SaveButton.Text = 'OK';
            app.SaveButton.Layout.Column = 3;
            app.SaveButton.ButtonPushedFcn = createCallbackFcn(app, @SaveButtonPushed, true);

            app.UIFigure.Visible = 'on';
        end
    end

    methods (Access = public)

        function app = roiGridGUI(varargin)
            createComponents(app)
            registerApp(app, app.UIFigure)

            params = [];
            fovCount = [];
            if nargin >= 1
                params = varargin{1};
            end
            if nargin >= 2
                fovCount = varargin{2};
            end
            startupFcn(app, params, fovCount)

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
