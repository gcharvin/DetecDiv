classdef ROIextracterGUI < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        ROIidentifierUIFigure          matlab.ui.Figure
        PositionlistPanel              matlab.ui.container.Panel
        GenerateROIsButton             matlab.ui.control.Button
        DeselectallButton              matlab.ui.control.Button
        SelectallButton                matlab.ui.control.Button
        TestonselectedpositionsButton  matlab.ui.control.Button
        UITable                        matlab.ui.control.Table
        ROIDetectionparametersPanel    matlab.ui.container.Panel
        channelnameEditField           matlab.ui.control.EditField
        channelnameEditFieldLabel      matlab.ui.control.Label
        PatternLabel                   matlab.ui.control.Label
        SetreferencepatternButton      matlab.ui.control.Button
        test                           matlab.ui.control.Button
        ThresholdEditField             matlab.ui.control.NumericEditField
        ThresholdEditFieldLabel        matlab.ui.control.Label
        ReferenceframeEditField        matlab.ui.control.NumericEditField
        ReferenceframeEditFieldLabel   matlab.ui.control.Label
        CloseButton                    matlab.ui.control.Button
    end


    properties (Access = private)
        Data % Description
    end

    methods (Access = private)

       
function updateTable(app)
    shallowObj = app.Data.shallowObj;
    t = app.UITable;

    t.ColumnEditable = [true false false false false false false];
    t.ColumnWidth    = {50 50 'Auto' 90 90 80 80};
    t.ColumnName     = {'Select','Index','Position Name','current ROIs','new ROIs','Crop','Pattern'};
    t.ColumnFormat   = {'logical','numeric','char','numeric','numeric','logical','logical'};

    nFov = numel(shallowObj.fov);

    % keep selection
    if ~isempty(t.Data) && size(t.Data,1) == nFov
        selected = cellfun(@(x) isequal(x,true) || isequal(x,1), t.Data(:,1));
    else
        selected = true(nFov,1);
    end

    % ensure detectedrois length
    if ~isfield(app.Data,'detectedrois') || isempty(app.Data.detectedrois)
        app.Data.detectedrois = zeros(1,nFov);
    elseif numel(app.Data.detectedrois) < nFov
        app.Data.detectedrois(end+1:nFov) = 0;
    end

    Data = cell(nFov, 7);

    for k = 1:nFov
        f = shallowObj.fov(k);

        % -------- Position Name (id) --------
        posName = '';
        try
            posName = f.id;  % works if object has property id
        catch
            try
                posName = f.("id"); % struct case
            catch
                posName = '';
            end
        end

        % -------- current ROIs --------
        roi = [];
        try
            roi = f.roi;        % object property
        catch
            try
                roi = f.("roi"); % struct field
            catch
                roi = [];
            end
        end

        n = 0;
        if ~isempty(roi)
            % If roi has property "id" and it's a single placeholder with empty id -> count as 0
            isPlaceholder = false;
            try
                if numel(roi) == 1 && isprop(roi,'id') && isempty(roi(1).id)
                    isPlaceholder = true;
                end
            catch
                % ignore
            end

            if ~isPlaceholder
                n = numel(roi);
            end
        end

        % -------- crop flag --------
        m = false;
        try
            m = ~isempty(f.crop);
        catch
            try
                m = ~isempty(f.("crop"));
            catch
                m = false;
            end
        end

        % -------- pattern flag --------
        p = false;
        try
            p = ~isempty(f.pattern);
        catch
            try
                p = ~isempty(f.("pattern"));
            catch
                p = false;
            end
        end

        % -------- new ROIs --------
        z = app.Data.detectedrois(k);

        Data(k,:) = {logical(selected(k)), double(k), char(string(posName)), double(n), double(z), logical(m), logical(p)};
    end

    t.Data = Data;
end




    end


    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app, fovobj, refresh)
            % app.callingApp=callingApp;
            % app.Data.shallowObj=shallowObj;
            %  findPattern(app);

            if nargin==1
                refresh=[];

                warndlg('Please provide a FOV object as an argument !');
                delete(app);
                return;
            end

            app.Data.fovobj=fovobj;


            patt=0;
            if numel(fovobj)
                if numel(fovobj.pattern)==0
                    % pattenr does not exist
                    patt=0;
                    app.PatternLabel.Text=['No pattern found in FOV ' fovobj.id '!'];
                else
                    patt=1;
                    app.PatternLabel.Text=['Pattern found in FOV ' fovobj.id '; Size : ' num2str(fovobj.pattern(3)) 'x' num2str(fovobj.pattern(4))];
                end
            else
                % look for pattern in other fov in the same project ?
                %do it later
                app.PatternLabel.Text=['No pattern found; First set pattern in image!'];
            end


            pix=find(fovobj.display.selectedchannel,1,'first');
            app.channelnameEditField.Value=fovobj.channel{pix};


            if numel(fovobj)
                app.Data.shallowObj= fovobj.flaggedROIs;

                for i=1:numel(app.Data.shallowObj.fov)

                    if numel(app.Data.shallowObj.fov(i).roi)==1 && numel(app.Data.shallowObj.fov(i).roi.id)==0
                        z=0;
                    else
                        z=numel(app.Data.shallowObj.fov(i).roi);
                    end
                    app.Data.detectedrois(i)=z;
                end

                updateTable(app)
            end



        end

        % Button pushed function: CloseButton
        function CloseButtonPushed(app, event)
            %  uiresume(app.callingApp.DetecDivUIFigure)
            delete(app)
        end

        % Close request function: ROIidentifierUIFigure
        function ROIidentifierUIFigureCloseRequest(app, event)
            %uiresume(app.callingApp.DetecDivUIFigure)
            delete(app)

        end

        % Value changed function: ReferenceframeEditField
        function ReferenceframeEditFieldValueChanged(app, event)
            %   value = app.ReferenceframeEditField.Value;
            %  shallowObj=app.Data.shallowObj;

            %  [cc,i,k]=computePattern(app,shallowObj,value);
            %  displayPattern(app,shallowObj);
        end

        % Button pushed function: TestonselectedpositionsButton
        function TestonselectedpositionsButtonPushed(app, event)

            % --- Pattern must exist ---
            if isempty(app.Data.fovobj) || isempty(app.Data.fovobj.pattern)
                uialert(app.ROIidentifierUIFigure, 'Pattern is not defined!', 'Warning', 'Icon','warning');
                return;
            end

            shallowObj = app.Data.shallowObj;

            if isempty(app.UITable.Data)
                uialert(app.ROIidentifierUIFigure, 'There is no ROI in the table!', 'Warning', 'Icon','warning');
                return;
            end

            % --- Selected positions ---
            selectedIdx = find(cellfun(@(x) isequal(x, true) || isequal(x, 1), app.UITable.Data(:,1)));
            if isempty(selectedIdx)
                uialert(app.ROIidentifierUIFigure, 'No position selected!', 'Warning', 'Icon','warning');
                return;
            end

            frameid = app.ReferenceframeEditField.Value;
            thr     = app.ThresholdEditField.Value;

            str = app.channelnameEditField.Value;
            pix = find(matches(app.Data.fovobj.channel, str), 1, 'first');
            if isempty(pix)
                uialert(app.ROIidentifierUIFigure, sprintf('Channel "%s" not found.', str), 'Error', 'Icon','error');
                return;
            end

            % --- Build FOV list safely (handle class friendly) ---
            fovs = shallowObj.fov(selectedIdx);

            % --- Build pattern image ---
            tmp     = readImage(app.Data.fovobj, frameid, pix);
            pattern = app.Data.fovobj.pattern; % [x y w h]
            x = pattern(1); y = pattern(2); w = pattern(3); h = pattern(4);

            % clamp within image bounds
            x1 = max(1, x);
            y1 = max(1, y);
            x2 = min(size(tmp,2), x + w - 1);
            y2 = min(size(tmp,1), y + h - 1);

            pattimg = tmp(y1:y2, x1:x2);

            % --- Run ROI detection in "Test" mode ---
            out = identifyROIs( ...
                'FOV',      fovs, ...
                'Frames',   frameid, ...
                'Test', ...
                'Threshold', thr, ...
                'Pattern',   pattimg, ...
                'Crop',      app.Data.fovobj.crop, ...
                'Channel',   pix);

            % --- Write results back using fovid (robust mapping) ---
            % On suppose que out(i).fovid correspond à l'index des fov dans shallowObj.fov
            for i = 1:numel(out)
                if isfield(out(i),'fovid') && ~isempty(out(i).fovid)
                    j = out(i).fovid;
                    if j >= 1 && j <= numel(app.Data.detectedrois)
                        app.Data.detectedrois(j) = size(out(i).scaled, 1);
                    end
                end
            end

            updateTable(app);

        end

        % Button pushed function: test
        function testButtonPushed(app, event)

            if isempty(app.Data.fovobj) || isempty(app.Data.fovobj.pattern)
                uialert(app.ROIidentifierUIFigure, 'Pattern is not defined!', 'Warning', 'Icon','warning');
                return;
            end

            frameid = app.ReferenceframeEditField.Value;
            thr     = app.ThresholdEditField.Value;

            str = app.channelnameEditField.Value;
            pix = find(matches(app.Data.fovobj.channel, str), 1, 'first');
            if isempty(pix)
                uialert(app.ROIidentifierUIFigure, sprintf('Channel "%s" not found.', str), 'Error', 'Icon','error');
                return;
            end

            tmp     = readImage(app.Data.fovobj, frameid, pix);
            pattern = app.Data.fovobj.pattern; % [x y w h]
            x = pattern(1); y = pattern(2); w = pattern(3); h = pattern(4);

            x1 = max(1, x);
            y1 = max(1, y);
            x2 = min(size(tmp,2), x + w - 1);
            y2 = min(size(tmp,1), y + h - 1);

            pattimg = tmp(y1:y2, x1:x2);

            out = identifyROIs( ...
                'FOV',       app.Data.fovobj, ...
                'Frames',    frameid, ...
                'Test', ...
                'Threshold', thr, ...
                'Pattern',   pattimg, ...
                'Crop',      app.Data.fovobj.crop, ...
                'Channel',   pix);

            if isempty(out) || ~isfield(out(1),'scaled') || isempty(out(1).scaled)
                uialert(app.ROIidentifierUIFigure, 'No ROI detected.', 'Info', 'Icon','info');
                return;
            end

            scaled2 = out(1).scaled;

            % Open / get axes
            hFig = app.Data.fovobj.view(frameid);
            figure(hFig);

            % Remove previous overlays
            old = findobj(hFig, 'Tag', 'roitesttag');
            if ~isempty(old)
                delete(old);
            end

            ax = findobj(hFig, 'type', 'Axes');
            if isempty(ax)
                uialert(app.ROIidentifierUIFigure, 'No axes found in figure.', 'Error', 'Icon','error');
                return;
            end
            ax = ax(1);

            % Draw rectangles
            for kk = 1:size(scaled2,1)
                roitmp = scaled2(kk,:); % [x y w h] assumed
                x1 = roitmp(1);
                y1 = roitmp(2);
                x2 = roitmp(1) + roitmp(3);
                y2 = roitmp(2) + roitmp(4);

                patch(ax, ...
                    'XData', [x1 x2 x2 x1 x1], ...
                    'YData', [y1 y1 y2 y2 y1], ...
                    'FaceAlpha', 0, ...
                    'FaceColor', [0 0 0], ...
                    'EdgeColor', [1 0 1], ...
                    'Tag', 'roitesttag', ...
                    'UserData', kk);
            end

        end

        % Button pushed function: SetreferencepatternButton
        function SetreferencepatternButtonPushed(app, event)
            if numel(app.Data.fovobj)
                h=app.Data.fovobj.view;
                figure(h);
            end

        end

        % Button pushed function: GenerateROIsButton
        function GenerateROIsButtonPushed(app, event)
            
    if isempty(app.Data.fovobj) || isempty(app.Data.fovobj.pattern)
        uialert(app.ROIidentifierUIFigure, 'Pattern is not defined!', 'Error', 'Icon','error');
        return;
    end

    shallowObj = app.Data.shallowObj;

    if isempty(app.UITable.Data)
        uialert(app.ROIidentifierUIFigure, 'There is no ROI in the table!', 'Warning', 'Icon','warning');
        return;
    end

    selectedIdx = find(cellfun(@(x) isequal(x, true) || isequal(x, 1), app.UITable.Data(:,1)));
    if isempty(selectedIdx)
        uialert(app.ROIidentifierUIFigure, 'No position selected!', 'Warning', 'Icon','warning');
        return;
    end

    frameid = app.ReferenceframeEditField.Value;
    thr     = app.ThresholdEditField.Value;

    str = app.channelnameEditField.Value;
    pix = find(matches(app.Data.fovobj.channel, str), 1, 'first');
    if isempty(pix)
        uialert(app.ROIidentifierUIFigure, sprintf('Channel "%s" not found.', str), 'Error', 'Icon','error');
        return;
    end

    % --- build fovs safely (handle friendly) ---
    fovs = shallowObj.fov(selectedIdx);

    % --- check existing ROIs (don’t break building fovs) ---
    hasExisting = false;
    for j = selectedIdx(:)'
        roi = [];
        if isfield(shallowObj.fov(j),'roi')
            roi = shallowObj.fov(j).roi;
        end
        if ~(isempty(roi) || (numel(roi)==1 && isfield(roi,'id') && isempty(roi(1).id)))
            hasExisting = true;
            break;
        end
    end

    if hasExisting
        sel = uiconfirm(app.ROIidentifierUIFigure, ...
            'Some ROIs exist already, overwrite?', ...
            'Confirm ROI Creation', ...
            'Options', {'OK','Cancel'}, ...
            'DefaultOption', 2, ...
            'CancelOption', 2);
        if strcmp(sel,'Cancel')
            return;
        end
    end

    % --- build pattern image ---
    tmp     = readImage(app.Data.fovobj, frameid, pix);
    pattern = app.Data.fovobj.pattern; % [x y w h]
    x = pattern(1); y = pattern(2); w = pattern(3); h = pattern(4);

    x1 = max(1, x);
    y1 = max(1, y);
    x2 = min(size(tmp,2), x + w - 1);
    y2 = min(size(tmp,1), y + h - 1);

    pattimg = tmp(y1:y2, x1:x2);

    % --- run detection/generation ---
    out = identifyROIs( ...
        'FOV',       fovs, ...
        'Frames',    frameid, ...
        'Threshold', thr, ...
        'Pattern',   pattimg, ...
        'Crop',      app.Data.fovobj.crop, ...
        'Channel',   pix);

    % --- update detected rois using fovid ---
    for i = 1:numel(out)
        if isfield(out(i),'fovid') && ~isempty(out(i).fovid)
            j = out(i).fovid;
            if j >= 1 && j <= numel(app.Data.detectedrois)
                app.Data.detectedrois(j) = size(out(i).scaled, 1);
            end
        end
    end

    updateTable(app);

    % show frame
    hFig = app.Data.fovobj.view(frameid);
    figure(hFig);



        end

        % Button pushed function: DeselectallButton
        function DeselectallButtonPushed(app, event)
            n=size(app.UITable.Data,1);
            t=cell(1,n);
            t(:)={false};

            app.UITable.Data(:,1)=t';
        end

        % Button pushed function: SelectallButton
        function SelectallButtonPushed(app, event)
            n=size(app.UITable.Data,1);
            t=cell(1,n);
            t(:)={true};

            app.UITable.Data(:,1)=t';
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create ROIidentifierUIFigure and hide until all components are created
            app.ROIidentifierUIFigure = uifigure('Visible', 'off');
            app.ROIidentifierUIFigure.IntegerHandle = 'on';
            app.ROIidentifierUIFigure.Position = [100 100 638 619];
            app.ROIidentifierUIFigure.Name = 'ROI identifier';
            app.ROIidentifierUIFigure.CloseRequestFcn = createCallbackFcn(app, @ROIidentifierUIFigureCloseRequest, true);
            app.ROIidentifierUIFigure.Tag = 'ROIExtracter';

            % Create CloseButton
            app.CloseButton = uibutton(app.ROIidentifierUIFigure, 'push');
            app.CloseButton.ButtonPushedFcn = createCallbackFcn(app, @CloseButtonPushed, true);
            app.CloseButton.Position = [204 10 235 37];
            app.CloseButton.Text = 'Close';

            % Create ROIDetectionparametersPanel
            app.ROIDetectionparametersPanel = uipanel(app.ROIidentifierUIFigure);
            app.ROIDetectionparametersPanel.Title = 'ROI Detection parameters';
            app.ROIDetectionparametersPanel.Position = [13 427 619 179];

            % Create ReferenceframeEditFieldLabel
            app.ReferenceframeEditFieldLabel = uilabel(app.ROIDetectionparametersPanel);
            app.ReferenceframeEditFieldLabel.HorizontalAlignment = 'right';
            app.ReferenceframeEditFieldLabel.Position = [12 81 95 22];
            app.ReferenceframeEditFieldLabel.Text = 'Reference frame';

            % Create ReferenceframeEditField
            app.ReferenceframeEditField = uieditfield(app.ROIDetectionparametersPanel, 'numeric');
            app.ReferenceframeEditField.ValueChangedFcn = createCallbackFcn(app, @ReferenceframeEditFieldValueChanged, true);
            app.ReferenceframeEditField.Position = [117 82 100 22];
            app.ReferenceframeEditField.Value = 1;

            % Create ThresholdEditFieldLabel
            app.ThresholdEditFieldLabel = uilabel(app.ROIDetectionparametersPanel);
            app.ThresholdEditFieldLabel.HorizontalAlignment = 'right';
            app.ThresholdEditFieldLabel.Position = [41 48 59 22];
            app.ThresholdEditFieldLabel.Text = 'Threshold';

            % Create ThresholdEditField
            app.ThresholdEditField = uieditfield(app.ROIDetectionparametersPanel, 'numeric');
            app.ThresholdEditField.Position = [117 48 100 22];
            app.ThresholdEditField.Value = 0.5;

            % Create test
            app.test = uibutton(app.ROIDetectionparametersPanel, 'push');
            app.test.ButtonPushedFcn = createCallbackFcn(app, @testButtonPushed, true);
            app.test.Position = [23 10 586 27];
            app.test.Text = 'Test ROI detection';

            % Create SetreferencepatternButton
            app.SetreferencepatternButton = uibutton(app.ROIDetectionparametersPanel, 'push');
            app.SetreferencepatternButton.ButtonPushedFcn = createCallbackFcn(app, @SetreferencepatternButtonPushed, true);
            app.SetreferencepatternButton.WordWrap = 'on';
            app.SetreferencepatternButton.Position = [467 114 142 39];
            app.SetreferencepatternButton.Text = 'Set reference pattern...';

            % Create PatternLabel
            app.PatternLabel = uilabel(app.ROIDetectionparametersPanel);
            app.PatternLabel.WordWrap = 'on';
            app.PatternLabel.Position = [20 110 222 46];
            app.PatternLabel.Text = 'Pattern';

            % Create channelnameEditFieldLabel
            app.channelnameEditFieldLabel = uilabel(app.ROIDetectionparametersPanel);
            app.channelnameEditFieldLabel.HorizontalAlignment = 'right';
            app.channelnameEditFieldLabel.Position = [234 83 84 22];
            app.channelnameEditFieldLabel.Text = 'channel name:';

            % Create channelnameEditField
            app.channelnameEditField = uieditfield(app.ROIDetectionparametersPanel, 'text');
            app.channelnameEditField.Editable = 'off';
            app.channelnameEditField.Position = [333 83 200 22];

            % Create PositionlistPanel
            app.PositionlistPanel = uipanel(app.ROIidentifierUIFigure);
            app.PositionlistPanel.Title = 'Position list ';
            app.PositionlistPanel.Position = [15 61 617 355];

            % Create UITable
            app.UITable = uitable(app.PositionlistPanel);
            app.UITable.ColumnName = {'Column 1'; 'Column 2'; 'Column 3'; 'Column 4'};
            app.UITable.RowName = {};
            app.UITable.Tooltip = {'If one single cropping area exists, it will be used for all position; if none exists, no cropping will be done; '};
            app.UITable.Position = [9 19 598 260];

            % Create TestonselectedpositionsButton
            app.TestonselectedpositionsButton = uibutton(app.PositionlistPanel, 'push');
            app.TestonselectedpositionsButton.ButtonPushedFcn = createCallbackFcn(app, @TestonselectedpositionsButtonPushed, true);
            app.TestonselectedpositionsButton.Position = [249 290 153 37];
            app.TestonselectedpositionsButton.Text = 'Test on selected positions';

            % Create SelectallButton
            app.SelectallButton = uibutton(app.PositionlistPanel, 'push');
            app.SelectallButton.ButtonPushedFcn = createCallbackFcn(app, @SelectallButtonPushed, true);
            app.SelectallButton.Position = [10 297 100 23];
            app.SelectallButton.Text = 'Select all';

            % Create DeselectallButton
            app.DeselectallButton = uibutton(app.PositionlistPanel, 'push');
            app.DeselectallButton.ButtonPushedFcn = createCallbackFcn(app, @DeselectallButtonPushed, true);
            app.DeselectallButton.Position = [116 297 100 23];
            app.DeselectallButton.Text = 'Deselect all';

            % Create GenerateROIsButton
            app.GenerateROIsButton = uibutton(app.PositionlistPanel, 'push');
            app.GenerateROIsButton.ButtonPushedFcn = createCallbackFcn(app, @GenerateROIsButtonPushed, true);
            app.GenerateROIsButton.FontWeight = 'bold';
            app.GenerateROIsButton.Position = [455 290 146 37];
            app.GenerateROIsButton.Text = 'Generate ROIs';

            % Show the figure after all components are created
            app.ROIidentifierUIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = ROIextracterGUI(varargin)

            runningApp = getRunningApp(app);

            % Check for running singleton app
            if isempty(runningApp)

                % Create UIFigure and components
                createComponents(app)

                % Register the app with App Designer
                registerApp(app, app.ROIidentifierUIFigure)

                % Execute the startup function
                runStartupFcn(app, @(app)startupFcn(app, varargin{:}))
            else

                % Focus the running singleton app
                figure(runningApp.ROIidentifierUIFigure)

                app = runningApp;
            end

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.ROIidentifierUIFigure)
        end
    end
end