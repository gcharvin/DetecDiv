classdef roiIdentifyGUI < matlab.apps.AppBase

    properties (Access = public)
        UIFigure                    matlab.ui.Figure
        MainLayout                  matlab.ui.container.GridLayout
        ReferencePositionLabel      matlab.ui.control.Label
        ReferencePositionDropDown   matlab.ui.control.DropDown
        ReferenceFrameLabel         matlab.ui.control.Label
        ReferenceFrameEditField     matlab.ui.control.NumericEditField
        ChannelLabel                matlab.ui.control.Label
        ChannelDropDown             matlab.ui.control.DropDown
        ThresholdLabel              matlab.ui.control.Label
        ThresholdEditField          matlab.ui.control.NumericEditField
        PatternTable                matlab.ui.control.Table
        PatternInfoTextArea         matlab.ui.control.TextArea
        ButtonLayout                matlab.ui.container.GridLayout
        CalibrateButton             matlab.ui.control.Button
        TestCurrentButton           matlab.ui.control.Button
        ApplySelectedButton         matlab.ui.control.Button
        RemovePatternButton         matlab.ui.control.Button
        CancelButton                matlab.ui.control.Button
        SaveButton                  matlab.ui.control.Button
    end

    properties (Access = public)
        Result struct = struct()
        Cancelled logical = true
    end

    properties (Access = private)
        Data struct = struct('shallowObj', [], 'patternList', struct([]), 'selectedPattern', [])
        InitialParams struct = struct()
    end

    methods (Access = private)

        function startupFcn(app, shallowObj, params)
            if nargin < 2 || isempty(shallowObj) || ~isa(shallowObj, 'shallow')
                error('roiIdentifyGUI:NoProject', 'A shallow project is required.');
            end
            if nargin < 3 || isempty(params) || ~isstruct(params)
                params = roiIdentify.setparam(struct());
            else
                params = mergeWithDefaults(app, params);
            end

            app.Data.shallowObj = shallowObj;
            app.InitialParams = params;
            app.Result = params;

            if isfield(params, 'patternList') && isstruct(params.patternList) && ~isempty(params.patternList)
                app.Data.patternList = params.patternList;
            else
                app.Data.patternList = struct([]);
            end

            if isfield(params, 'activePatternIndex') && ~isempty(params.activePatternIndex)
                app.Data.selectedPattern = params.activePatternIndex;
            end

            initReferenceFovList(app);
            populateParams(app, params);
            refreshPatternTable(app);
        end

        function params = mergeWithDefaults(app, params) %#ok<INUSD>
            defaults = roiIdentify.setparam(struct());
            fn = fieldnames(defaults);
            for i = 1:numel(fn)
                k = fn{i};
                if ~isfield(params, k) || isempty(params.(k))
                    params.(k) = defaults.(k);
                end
            end
        end

        function initReferenceFovList(app)
            shallowObj = app.Data.shallowObj;
            names = cell(1, numel(shallowObj.fov));
            for i = 1:numel(shallowObj.fov)
                label = sprintf('%d', i);
                try
                    if isprop(shallowObj.fov(i), 'id') && ~isempty(shallowObj.fov(i).id)
                        label = sprintf('%d - %s', i, char(string(shallowObj.fov(i).id)));
                    end
                catch
                end
                names{i} = label;
            end
            if isempty(names)
                names = {'1'};
            end
            app.ReferencePositionDropDown.Items = names;
            app.ReferencePositionDropDown.ItemsData = num2cell(1:numel(names));
            app.ReferencePositionDropDown.Value = app.ReferencePositionDropDown.ItemsData{1};
            updateChannelsForSelectedFov(app);
        end

        function populateParams(app, params)
            refIdx = resolveReferenceFovIndex(app, params);
            itemData = app.ReferencePositionDropDown.ItemsData;
            if refIdx >= 1 && refIdx <= numel(itemData)
                app.ReferencePositionDropDown.Value = itemData{refIdx};
            end

            if isempty(params.referenceFrame)
                app.ReferenceFrameEditField.Value = 1;
            else
                app.ReferenceFrameEditField.Value = params.referenceFrame;
            end

            if isempty(params.threshold)
                app.ThresholdEditField.Value = 0.5;
            else
                app.ThresholdEditField.Value = params.threshold;
            end

            updateChannelsForSelectedFov(app);

            wantedChannel = '';
            if isfield(params, 'channel') && ~isempty(params.channel)
                wantedChannel = char(string(params.channel));
            else
                pat = getSelectedPattern(app);
                if ~isempty(pat)
                    try
                        wantedChannel = char(string(pat.channel));
                    catch
                    end
                end
            end
            if ~isempty(wantedChannel) && any(strcmp(app.ChannelDropDown.Items, wantedChannel))
                app.ChannelDropDown.Value = wantedChannel;
            elseif ~isempty(app.ChannelDropDown.Items)
                app.ChannelDropDown.Value = app.ChannelDropDown.Items{1};
            end
        end

        function idx = resolveReferenceFovIndex(app, params)
            idx = 1;
            pat = getSelectedPattern(app);
            if ~isempty(pat)
                try
                    if isfield(pat, 'fovIndex') && ~isempty(pat.fovIndex)
                        idx = pat.fovIndex;
                        return;
                    end
                catch
                end
            end
            if isfield(params, 'fovIndex') && ~isempty(params.fovIndex)
                idx = params.fovIndex(1);
            end
        end

        function updateChannelsForSelectedFov(app)
            fovObj = getSelectedFov(app);
            channels = {};
            try
                channels = cellstr(string(fovObj.channel));
            catch
            end
            if isempty(channels)
                channels = {''};
            end
            app.ChannelDropDown.Items = channels;
            if any(strcmp(channels, app.ChannelDropDown.Value))
                return;
            end
            app.ChannelDropDown.Value = channels{1};
        end

        function fovObj = getSelectedFov(app)
            idx = app.ReferencePositionDropDown.Value;
            shallowObj = app.Data.shallowObj;
            if isempty(idx) || idx < 1 || idx > numel(shallowObj.fov)
                idx = 1;
            end
            fovObj = shallowObj.fov(idx);
        end

        function pat = getSelectedPattern(app)
            pat = [];
            idx = app.Data.selectedPattern;
            if isempty(idx) || idx < 1 || idx > numel(app.Data.patternList)
                return;
            end
            pat = app.Data.patternList(idx);
        end

        function refreshPatternTable(app)
            pats = app.Data.patternList;
            n = numel(pats);
            data = cell(n,4);
            for i = 1:n
                data{i,1} = sprintf('pattern_%d', i);
                data{i,2} = getPatternField(app, pats(i), 'fovId', '');
                data{i,3} = getPatternField(app, pats(i), 'frame', '');
                data{i,4} = getPatternField(app, pats(i), 'channel', '');
            end
            app.PatternTable.Data = data;

            if n == 0
                app.Data.selectedPattern = [];
                app.PatternInfoTextArea.Value = {'No stored pattern.'};
            else
                if isempty(app.Data.selectedPattern) || app.Data.selectedPattern < 1 || app.Data.selectedPattern > n
                    app.Data.selectedPattern = 1;
                end
                app.PatternTable.Selection = [app.Data.selectedPattern 1];
                updatePatternInfo(app);
            end
        end

        function out = getPatternField(app, pat, name, fallback) %#ok<INUSD>
            out = fallback;
            try
                if isfield(pat, name) && ~isempty(pat.(name))
                    val = pat.(name);
                    if isnumeric(val)
                        out = num2str(val);
                    else
                        out = char(string(val));
                    end
                end
            catch
            end
        end

        function updatePatternInfo(app)
            idx = app.Data.selectedPattern;
            if isempty(idx) || idx < 1 || idx > numel(app.Data.patternList)
                app.PatternInfoTextArea.Value = {'No stored pattern.'};
                return;
            end
            pat = app.Data.patternList(idx);
            lines = { ...
                ['FOV: ' getPatternField(app, pat, 'fovId', '')], ...
                ['Frame: ' getPatternField(app, pat, 'frame', '')], ...
                ['Channel: ' getPatternField(app, pat, 'channel', '')]};
            try
                if isfield(pat, 'rect') && ~isempty(pat.rect)
                    lines{end+1} = ['Rect: ' mat2str(pat.rect)]; %#ok<AGROW>
                end
            catch
            end
            app.PatternInfoTextArea.Value = lines;
        end

        function ReferencePositionDropDownValueChanged(app, event) %#ok<INUSD>
            updateChannelsForSelectedFov(app);
        end

        function PatternTableSelectionChanged(app, event)
            if isempty(event.Selection)
                return;
            end
            row = event.Selection(1);
            app.Data.selectedPattern = row;
            updatePatternInfo(app);
        end

        function CalibrateButtonPushed(app, event) %#ok<INUSD>
            fovObj = getSelectedFov(app);
            oldStyle = 'modal';
            try
                oldStyle = app.UIFigure.WindowStyle;
                app.UIFigure.WindowStyle = 'normal';
            catch
            end

            try
                if isprop(fovObj, 'display') && isstruct(fovObj.display)
                    appFrame = max(1, round(app.ReferenceFrameEditField.Value));
                    fovObj.display.frame = appFrame;
                    chanName = char(string(app.ChannelDropDown.Value));
                    if isprop(fovObj, 'channel') && ~isempty(fovObj.channel)
                        sel = zeros(1, numel(fovObj.channel));
                        idx = find(strcmp(fovObj.channel, chanName), 1, 'first');
                        if isempty(idx)
                            idx = 1;
                        end
                        sel(idx) = 1;
                        fovObj.display.selectedchannel = sel;
                    end
                end
            catch
            end

            h = [];
            try
                h = fovObj.view(fovObj.display.frame, [], []);
            catch
                try
                    h = fovObj.view(fovObj.display.frame, []);
                catch
                    h = fovObj.view(fovObj.display.frame);
                end
            end

            try
                if ~isempty(h) && isgraphics(h)
                    waitfor(h);
                end
            catch
            end

            try
                if isvalid(app.UIFigure)
                    app.UIFigure.WindowStyle = oldStyle;
                    figure(app.UIFigure);
                end
            catch
            end

            pat = buildPatternFromFov(app, fovObj);
            if isempty(pat)
                return;
            end

            app.Data.patternList = upsertPattern(app, app.Data.patternList, pat);
            app.Data.selectedPattern = findPatternIndex(app, app.Data.patternList, pat);
            refreshPatternTable(app);
        end

        function pat = buildPatternFromFov(app, fovObj)
            pat = struct();
            rect = [];
            try
                rect = fovObj.pattern;
            catch
            end
            if isempty(rect)
                return;
            end
            pat.rect = rect;
            try
                pat.crop = fovObj.crop;
            catch
                pat.crop = [];
            end
            try
                pat.fovId = fovObj.id;
            catch
                pat.fovId = sprintf('fov_%d', app.ReferencePositionDropDown.Value);
            end
            pat.fovIndex = app.ReferencePositionDropDown.Value;
            pat.frame = app.ReferenceFrameEditField.Value;
            pat.channel = char(string(app.ChannelDropDown.Value));
            try
                if isprop(fovObj, 'channel')
                    pix = find(matches(fovObj.channel, pat.channel), 1);
                    if ~isempty(pix)
                        pat.channelIndex = pix;
                    end
                end
            catch
            end
            pat.updatedAt = datetime('now');
        end

        function pats = upsertPattern(app, pats, pat) %#ok<INUSD>
            if isempty(pats)
                pats = pat;
                return;
            end
            for i = 1:numel(pats)
                sameFov = false;
                try
                    sameFov = isfield(pats(i), 'fovId') && strcmp(char(string(pats(i).fovId)), char(string(pat.fovId)));
                catch
                end
                if sameFov
                    pats(i) = pat;
                    return;
                end
            end
            pats(end+1) = pat;
        end

        function idx = findPatternIndex(app, pats, pat) %#ok<INUSD>
            idx = [];
            for i = 1:numel(pats)
                try
                    if isfield(pats(i), 'fovId') && strcmp(char(string(pats(i).fovId)), char(string(pat.fovId)))
                        idx = i;
                        return;
                    end
                catch
                end
            end
        end

        function RemovePatternButtonPushed(app, event) %#ok<INUSD>
            idx = app.Data.selectedPattern;
            if isempty(idx) || idx < 1 || idx > numel(app.Data.patternList)
                return;
            end
            keep = true(1, numel(app.Data.patternList));
            keep(idx) = false;
            app.Data.patternList = app.Data.patternList(keep);
            if isempty(app.Data.patternList)
                app.Data.selectedPattern = [];
            else
                app.Data.selectedPattern = min(idx, numel(app.Data.patternList));
            end
            refreshPatternTable(app);
        end

        function params = collectParamsFromUi(app)
            params = app.InitialParams;
            params.referenceFrame = app.ReferenceFrameEditField.Value;
            params.threshold = app.ThresholdEditField.Value;
            params.channel = char(string(app.ChannelDropDown.Value));
            params.patternList = app.Data.patternList;
            params.activePatternIndex = app.Data.selectedPattern;

            fovObj = getSelectedFov(app);
            try
                pix = find(matches(fovObj.channel, params.channel), 1);
                if ~isempty(pix)
                    params.channelIndex = pix;
                end
            catch
            end

            pat = getSelectedPattern(app);
            if ~isempty(pat)
                try
                    if isfield(pat, 'crop')
                        params.crop = pat.crop;
                    end
                catch
                end
            end
        end

        function idx = promptTargetPositions(app)
            idx = [];
            shallowObj = app.Data.shallowObj;
            if isempty(shallowObj) || ~isa(shallowObj, 'shallow')
                return;
            end
            defaultExpr = sprintf('1:%d', numel(shallowObj.fov));
            answer = inputdlg({'Positions to process:'}, 'ROI pattern detection', 1, {defaultExpr});
            if isempty(answer)
                return;
            end
            try
                tmp = eval(['[' char(string(answer{1})) ']']); %#ok<EVLDIR>
                if isnumeric(tmp)
                    tmp = reshape(double(tmp), 1, []);
                    idx = unique(tmp(isfinite(tmp) & tmp >= 1 & tmp <= numel(shallowObj.fov)));
                end
            catch
                idx = [];
            end
        end

        function runPatternDetection(app, fovIdx, openViewerAfter)
            if nargin < 3
                openViewerAfter = false;
            end
            params = collectParamsFromUi(app);
            app.Result = params;
            shallowObj = app.Data.shallowObj;
            runCtx = struct('shallow', shallowObj, 'roiPattern', params, 'params', params, 'fovIndex', fovIdx);
            try
                roiPattern.process(runCtx);
                if openViewerAfter && ~isempty(fovIdx)
                    k = fovIdx(1);
                    try
                        shallowObj.fov(k).view(shallowObj.fov(k).display.frame, [], shallowObj);
                    catch
                    end
                end
            catch ME
                uialert(app.UIFigure, ME.message, 'ROI detection failed', 'Icon', 'warning');
            end
        end

        function TestCurrentButtonPushed(app, event) %#ok<INUSD>
            idx = app.ReferencePositionDropDown.Value;
            runPatternDetection(app, idx, true);
        end

        function ApplySelectedButtonPushed(app, event) %#ok<INUSD>
            idx = promptTargetPositions(app);
            if isempty(idx)
                return;
            end
            runPatternDetection(app, idx, true);
        end

        function SaveButtonPushed(app, event) %#ok<INUSD>
            app.Result = collectParamsFromUi(app);
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
            app.UIFigure.Position = [100 100 720 560];
            app.UIFigure.Name = 'ROI identification parameters';
            app.UIFigure.WindowStyle = 'modal';
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @UIFigureCloseRequest, true);

            app.MainLayout = uigridlayout(app.UIFigure);
            app.MainLayout.ColumnWidth = {160, '1x'};
            app.MainLayout.RowHeight = {24, 24, 24, 24, 180, 80, 40};
            app.MainLayout.Padding = [12 12 12 12];
            app.MainLayout.RowSpacing = 8;
            app.MainLayout.ColumnSpacing = 12;

            app.ReferencePositionLabel = uilabel(app.MainLayout);
            app.ReferencePositionLabel.Text = 'Reference position';
            app.ReferencePositionLabel.Layout.Row = 1;
            app.ReferencePositionLabel.Layout.Column = 1;

            app.ReferencePositionDropDown = uidropdown(app.MainLayout);
            app.ReferencePositionDropDown.ValueChangedFcn = createCallbackFcn(app, @ReferencePositionDropDownValueChanged, true);
            app.ReferencePositionDropDown.Layout.Row = 1;
            app.ReferencePositionDropDown.Layout.Column = 2;

            app.ReferenceFrameLabel = uilabel(app.MainLayout);
            app.ReferenceFrameLabel.Text = 'Reference frame';
            app.ReferenceFrameLabel.Layout.Row = 2;
            app.ReferenceFrameLabel.Layout.Column = 1;

            app.ReferenceFrameEditField = uieditfield(app.MainLayout, 'numeric');
            app.ReferenceFrameEditField.Limits = [1 Inf];
            app.ReferenceFrameEditField.RoundFractionalValues = 'on';
            app.ReferenceFrameEditField.Layout.Row = 2;
            app.ReferenceFrameEditField.Layout.Column = 2;

            app.ChannelLabel = uilabel(app.MainLayout);
            app.ChannelLabel.Text = 'Reference channel';
            app.ChannelLabel.Layout.Row = 3;
            app.ChannelLabel.Layout.Column = 1;

            app.ChannelDropDown = uidropdown(app.MainLayout);
            app.ChannelDropDown.Layout.Row = 3;
            app.ChannelDropDown.Layout.Column = 2;

            app.ThresholdLabel = uilabel(app.MainLayout);
            app.ThresholdLabel.Text = 'Threshold';
            app.ThresholdLabel.Layout.Row = 4;
            app.ThresholdLabel.Layout.Column = 1;

            app.ThresholdEditField = uieditfield(app.MainLayout, 'numeric');
            app.ThresholdEditField.Limits = [0 Inf];
            app.ThresholdEditField.Layout.Row = 4;
            app.ThresholdEditField.Layout.Column = 2;

            app.PatternTable = uitable(app.MainLayout);
            app.PatternTable.ColumnName = {'Name', 'FOV', 'Frame', 'Channel'};
            app.PatternTable.RowName = {};
            app.PatternTable.ColumnEditable = [false false false false];
            app.PatternTable.SelectionChangedFcn = createCallbackFcn(app, @PatternTableSelectionChanged, true);
            app.PatternTable.Layout.Row = 5;
            app.PatternTable.Layout.Column = [1 2];

            app.PatternInfoTextArea = uitextarea(app.MainLayout);
            app.PatternInfoTextArea.Editable = 'off';
            app.PatternInfoTextArea.Layout.Row = 6;
            app.PatternInfoTextArea.Layout.Column = [1 2];

            app.ButtonLayout = uigridlayout(app.MainLayout);
            app.ButtonLayout.ColumnWidth = {150, 110, 130, 120, '1x', 100, 100};
            app.ButtonLayout.RowHeight = {30};
            app.ButtonLayout.Padding = [0 0 0 0];
            app.ButtonLayout.ColumnSpacing = 8;
            app.ButtonLayout.Layout.Row = 7;
            app.ButtonLayout.Layout.Column = [1 2];

            app.CalibrateButton = uibutton(app.ButtonLayout, 'push');
            app.CalibrateButton.Text = 'Calibrate pattern...';
            app.CalibrateButton.ButtonPushedFcn = createCallbackFcn(app, @CalibrateButtonPushed, true);
            app.CalibrateButton.Layout.Row = 1;
            app.CalibrateButton.Layout.Column = 1;

            app.TestCurrentButton = uibutton(app.ButtonLayout, 'push');
            app.TestCurrentButton.Text = 'Test current';
            app.TestCurrentButton.ButtonPushedFcn = createCallbackFcn(app, @TestCurrentButtonPushed, true);
            app.TestCurrentButton.Layout.Row = 1;
            app.TestCurrentButton.Layout.Column = 2;

            app.ApplySelectedButton = uibutton(app.ButtonLayout, 'push');
            app.ApplySelectedButton.Text = 'Apply to positions';
            app.ApplySelectedButton.ButtonPushedFcn = createCallbackFcn(app, @ApplySelectedButtonPushed, true);
            app.ApplySelectedButton.Layout.Row = 1;
            app.ApplySelectedButton.Layout.Column = 3;

            app.RemovePatternButton = uibutton(app.ButtonLayout, 'push');
            app.RemovePatternButton.Text = 'Remove pattern';
            app.RemovePatternButton.ButtonPushedFcn = createCallbackFcn(app, @RemovePatternButtonPushed, true);
            app.RemovePatternButton.Layout.Row = 1;
            app.RemovePatternButton.Layout.Column = 4;

            app.CancelButton = uibutton(app.ButtonLayout, 'push');
            app.CancelButton.Text = 'Cancel';
            app.CancelButton.ButtonPushedFcn = createCallbackFcn(app, @CancelButtonPushed, true);
            app.CancelButton.Layout.Row = 1;
            app.CancelButton.Layout.Column = 6;

            app.SaveButton = uibutton(app.ButtonLayout, 'push');
            app.SaveButton.Text = 'Save';
            app.SaveButton.ButtonPushedFcn = createCallbackFcn(app, @SaveButtonPushed, true);
            app.SaveButton.Layout.Row = 1;
            app.SaveButton.Layout.Column = 7;

            app.UIFigure.Visible = 'on';
        end
    end

    methods (Access = public)

        function app = roiIdentifyGUI(varargin)
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
