classdef workflow < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                       matlab.ui.Figure
        FileMenu                       matlab.ui.container.Menu
        EditMenu                       matlab.ui.container.Menu
        ViewMenu                       matlab.ui.container.Menu
        AboutMenu                      matlab.ui.container.Menu
        FOVsPositionsPanel             matlab.ui.container.Panel
        UIFOVTable                     matlab.ui.control.Table
        ChannelsPanel                  matlab.ui.container.Panel
        selectedFOVEditField           matlab.ui.control.EditField
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
        ROIsLabel                      matlab.ui.control.Label
        GenerateROIsButton             matlab.ui.control.Button
        TestROIdetectionButton         matlab.ui.control.Button
        UIExistingROIsTable            matlab.ui.control.Table
        SavepatternButton              matlab.ui.control.Button
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

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 1298 975];
            app.UIFigure.Name = 'MATLAB App';

            % Create FileMenu
            app.FileMenu = uimenu(app.UIFigure);
            app.FileMenu.Text = 'File';

            % Create EditMenu
            app.EditMenu = uimenu(app.UIFigure);
            app.EditMenu.Text = 'Edit';

            % Create ViewMenu
            app.ViewMenu = uimenu(app.UIFigure);
            app.ViewMenu.Text = 'View';

            % Create AboutMenu
            app.AboutMenu = uimenu(app.UIFigure);
            app.AboutMenu.Text = 'About';

            % Create UIAxes
            app.UIAxes = uiaxes(app.UIFigure);
            title(app.UIAxes, 'Title')
            xlabel(app.UIAxes, 'X')
            ylabel(app.UIAxes, 'Y')
            zlabel(app.UIAxes, 'Z')
            app.UIAxes.Position = [533 312 755 656];

            % Create TabGroup
            app.TabGroup = uitabgroup(app.UIFigure);
            app.TabGroup.Position = [11 321 513 645];

            % Create DataloaderTab
            app.DataloaderTab = uitab(app.TabGroup);
            app.DataloaderTab.Title = 'Dataloader';

            % Create UIDataLoaderTable
            app.UIDataLoaderTable = uitable(app.DataloaderTab);
            app.UIDataLoaderTable.ColumnName = {'Column 1'; 'Column 2'; 'Column 3'; 'Column 4'};
            app.UIDataLoaderTable.RowName = {};
            app.UIDataLoaderTable.Position = [9 247 494 364];

            % Create AdddataButton
            app.AdddataButton = uibutton(app.DataloaderTab, 'push');
            app.AdddataButton.Position = [14 12 489 226];
            app.AdddataButton.Text = 'Add data....';

            % Create ROIsIDTab
            app.ROIsIDTab = uitab(app.TabGroup);
            app.ROIsIDTab.Title = 'ROIs ID';

            % Create ROIgenerationmodeButtonGroup
            app.ROIgenerationmodeButtonGroup = uibuttongroup(app.ROIsIDTab);
            app.ROIgenerationmodeButtonGroup.Title = 'ROI generation mode';
            app.ROIgenerationmodeButtonGroup.Position = [9 495 494 116];

            % Create ManualselectionmanualButton
            app.ManualselectionmanualButton = uiradiobutton(app.ROIgenerationmodeButtonGroup);
            app.ManualselectionmanualButton.Text = 'Manual selection (manual)';
            app.ManualselectionmanualButton.Position = [11 70 163 22];
            app.ManualselectionmanualButton.Value = true;

            % Create PatterndetectionpatternButton
            app.PatterndetectionpatternButton = uiradiobutton(app.ROIgenerationmodeButtonGroup);
            app.PatterndetectionpatternButton.Text = 'Pattern detection (pattern)';
            app.PatterndetectionpatternButton.Position = [11 48 161 22];

            % Create GridselectiongridButton
            app.GridselectiongridButton = uiradiobutton(app.ROIgenerationmodeButtonGroup);
            app.GridselectiongridButton.Text = 'Grid selection (grid)';
            app.GridselectiongridButton.Position = [11 26 127 22];

            % Create UIROIParametersTable
            app.UIROIParametersTable = uitable(app.ROIsIDTab);
            app.UIROIParametersTable.ColumnName = {'Column 1'; 'Column 2'; 'Column 3'; 'Column 4'};
            app.UIROIParametersTable.RowName = {};
            app.UIROIParametersTable.Position = [15 247 488 235];

            % Create SavepatternButton
            app.SavepatternButton = uibutton(app.ROIsIDTab, 'push');
            app.SavepatternButton.Position = [400 131 106 44];
            app.SavepatternButton.Text = 'Save pattern';

            % Create UIExistingROIsTable
            app.UIExistingROIsTable = uitable(app.ROIsIDTab);
            app.UIExistingROIsTable.ColumnName = {'Display'; 'Size'};
            app.UIExistingROIsTable.RowName = {};
            app.UIExistingROIsTable.Position = [12 12 380 196];

            % Create TestROIdetectionButton
            app.TestROIdetectionButton = uibutton(app.ROIsIDTab, 'push');
            app.TestROIdetectionButton.Position = [400 79 103 42];
            app.TestROIdetectionButton.Text = 'Test ROI detection';

            % Create GenerateROIsButton
            app.GenerateROIsButton = uibutton(app.ROIsIDTab, 'push');
            app.GenerateROIsButton.FontWeight = 'bold';
            app.GenerateROIsButton.Position = [403 10 100 59];
            app.GenerateROIsButton.Text = 'Generate ROIs';

            % Create ROIsLabel
            app.ROIsLabel = uilabel(app.ROIsIDTab);
            app.ROIsLabel.Position = [15 216 36 22];
            app.ROIsLabel.Text = 'ROIs:';

            % Create selectallButton
            app.selectallButton = uibutton(app.ROIsIDTab, 'push');
            app.selectallButton.Position = [57 215 100 23];
            app.selectallButton.Text = 'select all';

            % Create deselectallButton
            app.deselectallButton = uibutton(app.ROIsIDTab, 'push');
            app.deselectallButton.Position = [167 215 100 23];
            app.deselectallButton.Text = 'deselect all';

            % Create removeselectedButton
            app.removeselectedButton = uibutton(app.ROIsIDTab, 'push');
            app.removeselectedButton.Position = [278 215 103 23];
            app.removeselectedButton.Text = 'remove selected';

            % Create ROIsExtractionTab
            app.ROIsExtractionTab = uitab(app.TabGroup);
            app.ROIsExtractionTab.Title = 'ROIs Extraction';

            % Create UIROIsExtractionTable
            app.UIROIsExtractionTable = uitable(app.ROIsExtractionTab);
            app.UIROIsExtractionTable.ColumnName = {'Column 1'; 'Column 2'; 'Column 3'; 'Column 4'};
            app.UIROIsExtractionTable.RowName = {};
            app.UIROIsExtractionTable.Position = [10 108 493 503];

            % Create ExtractROIsButton
            app.ExtractROIsButton = uibutton(app.ROIsExtractionTab, 'push');
            app.ExtractROIsButton.Position = [10 12 493 84];
            app.ExtractROIsButton.Text = 'Extract ROIs';

            % Create ChannelsPanel
            app.ChannelsPanel = uipanel(app.UIFigure);
            app.ChannelsPanel.Title = 'Channels';
            app.ChannelsPanel.Position = [459 15 832 298];

            % Create LevelsSliderLabel
            app.LevelsSliderLabel = uilabel(app.ChannelsPanel);
            app.LevelsSliderLabel.HorizontalAlignment = 'right';
            app.LevelsSliderLabel.Position = [505 247 40 22];
            app.LevelsSliderLabel.Text = 'Levels';

            % Create LevelsSlider
            app.LevelsSlider = uislider(app.ChannelsPanel, 'range');
            app.LevelsSlider.Position = [559 256 150 3];

            % Create FrameSliderLabel
            app.FrameSliderLabel = uilabel(app.ChannelsPanel);
            app.FrameSliderLabel.HorizontalAlignment = 'right';
            app.FrameSliderLabel.Position = [500 208 40 22];
            app.FrameSliderLabel.Text = 'Frame';

            % Create FrameSlider
            app.FrameSlider = uislider(app.ChannelsPanel);
            app.FrameSlider.Position = [560 217 150 3];

            % Create ZoomSliderLabel
            app.ZoomSliderLabel = uilabel(app.ChannelsPanel);
            app.ZoomSliderLabel.HorizontalAlignment = 'right';
            app.ZoomSliderLabel.Position = [505 163 36 22];
            app.ZoomSliderLabel.Text = 'Zoom';

            % Create ZoomSlider
            app.ZoomSlider = uislider(app.ChannelsPanel);
            app.ZoomSlider.Position = [563 176 150 3];

            % Create colorColorPickerLabel
            app.colorColorPickerLabel = uilabel(app.ChannelsPanel);
            app.colorColorPickerLabel.HorizontalAlignment = 'right';
            app.colorColorPickerLabel.Position = [726 244 34 22];
            app.colorColorPickerLabel.Text = 'color:';

            % Create colorColorPicker
            app.colorColorPicker = uicolorpicker(app.ChannelsPanel);
            app.colorColorPicker.Position = [768 244 38 22];

            % Create FrameEditField
            app.FrameEditField = uieditfield(app.ChannelsPanel, 'numeric');
            app.FrameEditField.Position = [736 210 53 22];

            % Create PanButton
            app.PanButton = uibutton(app.ChannelsPanel, 'push');
            app.PanButton.Position = [739 147 76 23];
            app.PanButton.Text = 'Pan';

            % Create ResetzoomButton
            app.ResetzoomButton = uibutton(app.ChannelsPanel, 'push');
            app.ResetzoomButton.Position = [737 177 78 23];
            app.ResetzoomButton.Text = 'Reset zoom';

            % Create UIDisplayChannelTable
            app.UIDisplayChannelTable = uitable(app.ChannelsPanel);
            app.UIDisplayChannelTable.ColumnName = {'Display'; 'Name'; 'Levels'; 'RGB'; 'Weights'; 'auto'};
            app.UIDisplayChannelTable.RowName = {};
            app.UIDisplayChannelTable.Position = [9 147 494 122];

            % Create selectedFOVEditField
            app.selectedFOVEditField = uieditfield(app.ChannelsPanel, 'text');
            app.selectedFOVEditField.Tooltip = {'Display : path, size of image'};
            app.selectedFOVEditField.Position = [12 9 811 127];

            % Create FOVsPositionsPanel
            app.FOVsPositionsPanel = uipanel(app.UIFigure);
            app.FOVsPositionsPanel.Title = 'FOVs (Positions)';
            app.FOVsPositionsPanel.Position = [9 16 443 295];

            % Create UIFOVTable
            app.UIFOVTable = uitable(app.FOVsPositionsPanel);
            app.UIFOVTable.ColumnName = {'Select'; 'Name'};
            app.UIFOVTable.RowName = {};
            app.UIFOVTable.Position = [9 9 424 257];

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = workflow

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

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