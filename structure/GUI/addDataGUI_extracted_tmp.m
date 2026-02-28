classdef addDataGUI < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                    matlab.ui.Figure
        DataselectioncommandsPanel  matlab.ui.container.Panel
        CloseButton                 matlab.ui.control.Button
        DatalabelEditField          matlab.ui.control.EditField
        DatalabelEditFieldLabel     matlab.ui.control.Label
        ParsingrulesLabel           matlab.ui.control.Label
        ParsefilelistButton         matlab.ui.control.Button
        AddselectedpositionstoprojectButton  matlab.ui.control.Button
        ParserinputLabel            matlab.ui.control.Label
        ParseroutputLabel           matlab.ui.control.Label
        UITableFilter               matlab.ui.control.Table
        Label_2                     matlab.ui.control.Label
        ParsingcommentsLabel        matlab.ui.control.Label
        filenameLabel               matlab.ui.control.Label
        SamplefilenameLabel         matlab.ui.control.Label
        UITable                     matlab.ui.control.Table
        SelectdatadirectoryPanel    matlab.ui.container.Panel
        Label                       matlab.ui.control.Label
        ChoosedirectoryButton       matlab.ui.control.Button
    end

    
    properties (Access = private)
        project % Description
        output=[]; % Description
        com % Description
        mainapp % Description
        path=[]; % Description
    end
    
    methods (Access = private)
        
        function s = getSampleFilename(app, pos)
    % Retourne une string safe pour afficher un "sample filename"
    s = '';

    % Cas multi-TIFF récent (avec tiffSource/pageMap)
    if isfield(pos,'isMultiTiff') && pos.isMultiTiff
        if isfield(pos,'tiffSource') && ~isempty(pos.tiffSource)
            try
                if iscell(pos.tiffSource) && ~isempty(pos.tiffSource{1})
                    s = pos.tiffSource{1};
                    return;
                elseif ischar(pos.tiffSource) || isstring(pos.tiffSource)
                    s = char(pos.tiffSource);
                    return;
                end
            catch
                % continue fallback
            end
        end
        % fallback: nom de la position (souvent le fichier)
        if isfield(pos,'name') && ~isempty(pos.name)
            s = char(string(pos.name));
            return;
        end
    end

    % Cas générique : filelist peut être cell, struct array, ou cell-of-struct-array
    if isfield(pos,'filelist') && ~isempty(pos.filelist)
        try
            fl = pos.filelist;

            % filelist = cell
            if iscell(fl)
                x = fl{1};
                if isstruct(x) && ~isempty(x) && isfield(x,'name')
                    s = x(1).name;
                    return;
                end
                if isstruct(fl{1}) && isfield(fl{1},'name')
                    s = fl{1}.name;
                    return;
                end
            end

            % filelist = struct array
            if isstruct(fl) && ~isempty(fl) && isfield(fl,'name')
                s = fl(1).name;
                return;
            end
        catch
            % continue fallback
        end
    end

    % Dernier fallback
    if isfield(pos,'name') && ~isempty(pos.name)
        s = char(string(pos.name));
    end
end


        function params = buildFilterParams(app, useTableFilters)
            params = struct();
            params.path = app.path;
            params.interactive = false;
            params.write = false;

            if ~useTableFilters || isempty(app.UITableFilter.Data)
                return;
            end

            data = app.UITableFilter.Data;

            posfilter = data(:,1);
            tmp = {};
            for i = 1:numel(posfilter)
                if ~isempty(posfilter{i})
                    tmp{end+1} = posfilter{i}; %#ok<AGROW>
                end
            end
            if ~isempty(tmp)
                params.positionFilter = tmp;
            end

            chafilter = data(:,2);
            tmp = {};
            for i = 1:numel(chafilter)
                if ~isempty(chafilter{i})
                    tmp{end+1} = chafilter{i}; %#ok<AGROW>
                end
            end
            if ~isempty(tmp)
                params.channelFilter = tmp;
            end

            stackfilter = data(:,3);
            tmp = {};
            for i = 1:numel(stackfilter)
                if ~isempty(stackfilter{i})
                    tmp{end+1} = stackfilter{i}; %#ok<AGROW>
                end
            end
            if ~isempty(tmp)
                params.stackFilter = tmp;
            end
        end

        function displayresults(app,option)
            useFilters = (nargin > 1);

            d = uiprogressdlg(app.UIFigure,'Title','Please Wait', ...
                'Message','Parsing files in the selected directory...');
            d.Value = 0.33;

            app.Label.Text = app.path;

            try
                params = buildFilterParams(app, useFilters);
                params.progress = d;

                ctx = struct();
                ctx.shallow = app.project;
                ctx.dataLoader = params;
                ctx = dataLoader.process(ctx);

                app.output = ctx.dataOutput;
            catch ME
                close(d);
                uialert(app.UIFigure, ME.message, 'Error', 'Icon','error');
                return;
            end

            d.Message = 'Displaying results...';
            pause(0.2);

            if isfield(app.output,'datatype') && ~strcmp(app.output.datatype,'phylocell') && ~strcmp(app.output.datatype,'multitif')
                app.UITableFilter.Enable = 'on';
                app.ParsefilelistButton.Enable = 'on';
                app.UITableFilter.ColumnEditable = [true true true];

                data = {'' '' ''; '' '' ''; '' '' ''; '' '' ''};

                if isfield(app.output,'pos') && ~isempty(app.output.pos)
                    if isfield(app.output.pos(1),'positionfilter2') && ~isempty(app.output.pos(1).positionfilter2)
                        pf = app.output.pos(1).positionfilter2;
                        for i = 1:min(numel(pf),size(data,1))
                            data{i,1} = pf{i};
                        end
                    end

                    if isfield(app.output.pos(1),'channelfilter2') && ~isempty(app.output.pos(1).channelfilter2)
                        cf = app.output.pos(1).channelfilter2;
                        for i = 1:min(numel(cf),size(data,1))
                            data{i,2} = cf{i};
                        end
                    end

                    if isfield(app.output.pos(1),'stackfilter2') && ~isempty(app.output.pos(1).stackfilter2)
                        sf = app.output.pos(1).stackfilter2;
                        for i = 1:min(numel(sf),size(data,1))
                            data{i,3} = sf{i};
                        end
                    end
                end

                app.UITableFilter.Data = data;
            end

            if isfield(app.output,'pos') && ~isempty(app.output.pos)
                [~,tmp,~] = fileparts(app.path);
                app.DatalabelEditField.Value = tmp;
            end

            plotresults(app);
            close(d);
        end

        function plotresults(app)
            if isempty(app.output) || ~isfield(app.output,'pos') || isempty(app.output.pos)
                app.UITable.Data = {};
                app.Label_2.Text = 'No position found in selected folder.';
                return;
            end

            app.Label_2.Text = app.output.comments;
            app.UITable.Enable = 'on';

            tmp = cell(numel(app.output.pos),4);
            nAlready = 0;
            for i = 1:numel(app.output.pos)
                alreadyLoaded = isPositionAlreadyInProject(app, app.output.pos(i));
                if alreadyLoaded
                    nAlready = nAlready + 1;
                end

                tmp{i,1} = ~alreadyLoaded;
                tmp{i,2} = app.output.pos(i).name;
                tmp{i,3} = app.output.pos(i).channels;
                tmp{i,4} = num2str(app.output.pos(i).frames);
            end

            app.UITable.Data = tmp;
            ncols = size(app.UITable.Data,2);
            app.UITable.ColumnEditable = true(1,ncols);
            app.UITable.ColumnEditable(2:4) = false;

            app.filenameLabel.Text = getSampleFilename(app, app.output.pos(1));

            if nAlready > 0
                app.Label_2.Text = sprintf('%s\n%d position(s) are already in project and are unchecked by default.', app.Label_2.Text, nAlready);
            end
        end

        function tf = isPositionAlreadyInProject(app, pos)
            tf = false;
            try
                key = buildIncomingPosKey(app, pos);
                if isempty(key)
                    return;
                end
                mapObj = buildExistingKeyMap(app, app.project);
                tf = isKey(mapObj, key);
            catch
                tf = false;
            end
        end

        function mapObj = buildExistingKeyMap(app, proj)
            mapObj = containers.Map('KeyType','char','ValueType','logical');
            if isempty(proj) || isempty(proj.fov)
                return;
            end
            for i = 1:numel(proj.fov)
                try
                    key = buildFovKey(app, proj.fov(i));
                    if ~isempty(key)
                        mapObj(key) = true;
                    end
                catch
                end
            end
        end

        function key = buildFovKey(app, f)
            key = '';
            name = '';
            if isprop(f,'id') && ~isempty(f.id)
                name = char(string(f.id));
                name = regexprep(name, '_\d+$', '');
            end

            chanSig = signatureList(app, f.channel);

            if isprop(f,'isNDTiff') && f.isNDTiff
                src = normPath(app, getMaybe(app, f,'ndtiffPath',''));
                pos = num2str(getMaybe(app, f,'ndtiffPosition',-1));
                zst = num2str(getMaybe(app, f,'ndtiffZ',0));
                key = lower(sprintf('ndtiff|%s|%s|%s|%s|%s', src, pos, zst, chanSig, name));
                return;
            end

            if isprop(f,'isMultiTiff') && f.isMultiTiff
                src = firstNonEmptyCell(app, f.tiffSource);
                if isempty(src)
                    src = firstNonEmptyCell(app, f.srcpath);
                end
                src = normPath(app, src);
                key = lower(sprintf('multitiff|%s|%s|%s', src, chanSig, name));
                return;
            end

            src = firstNonEmptyCell(app, f.srcpath);
            sample = firstFileFromFov(app, f);
            key = lower(sprintf('files|%s|%s|%s|%s', normPath(app, src), normPath(app, sample), chanSig, name));
        end

        function key = buildIncomingPosKey(app, pos)
            key = '';
            name = char(string(getField(app, pos,'name','')));
            chanSig = signatureList(app, getField(app, pos,'channelname',{}));

            if isfield(pos,'isNDTiff') && pos.isNDTiff
                src = normPath(app, getField(app, pos,'ndtiffPath',''));
                p = num2str(getField(app, pos,'ndtiffPosition',-1));
                z = num2str(getField(app, pos,'ndtiffZ',0));
                key = lower(sprintf('ndtiff|%s|%s|%s|%s|%s', src, p, z, chanSig, name));
                return;
            end

            if isfield(pos,'isMultiTiff') && pos.isMultiTiff
                src = firstNonEmptyCell(app, getField(app, pos,'tiffSource',{}));
                if isempty(src)
                    src = firstNonEmptyCell(app, getField(app, pos,'pathlist',{}));
                end
                key = lower(sprintf('multitiff|%s|%s|%s', normPath(app, src), chanSig, name));
                return;
            end

            src = firstNonEmptyCell(app, getField(app, pos,'pathlist',{}));
            sample = firstFileFromParsedPos(app, pos);
            key = lower(sprintf('files|%s|%s|%s|%s', normPath(app, src), normPath(app, sample), chanSig, name));
        end

        function v = getMaybe(app, obj, name, defaultVal)
            v = defaultVal;
            try
                if isprop(obj,name)
                    val = obj.(name);
                    if ~isempty(val)
                        v = val;
                    end
                end
            catch
            end
        end

        function v = getField(app, S, name, defaultVal)
            v = defaultVal;
            if isstruct(S) && isfield(S,name)
                val = S.(name);
                if ~isempty(val)
                    v = val;
                end
            end
        end

        function s = firstNonEmptyCell(app, c)
            s = '';
            if ischar(c) || isstring(c)
                s = char(string(c));
                return;
            end
            if ~iscell(c) || isempty(c)
                return;
            end
            for i = 1:numel(c)
                if ischar(c{i}) || isstring(c{i})
                    t = char(string(c{i}));
                    if ~isempty(t)
                        s = t;
                        return;
                    end
                end
            end
        end

        function s = firstFileFromFov(app, f)
            s = '';
            try
                if ~isempty(f.srclist) && iscell(f.srclist) && ~isempty(f.srclist{1})
                    e = f.srclist{1};
                    if isstruct(e) && ~isempty(e) && isfield(e,'name')
                        s = e(1).name;
                        return;
                    end
                end
            catch
            end
        end

        function s = firstFileFromParsedPos(app, pos)
            s = '';
            if ~isfield(pos,'filelist') || isempty(pos.filelist)
                return;
            end
            fl = pos.filelist;
            try
                if iscell(fl)
                    x = fl{1};
                    if isstruct(x) && ~isempty(x) && isfield(x,'name')
                        s = x(1).name;
                        return;
                    end
                elseif isstruct(fl) && ~isempty(fl) && isfield(fl,'name')
                    s = fl(1).name;
                    return;
                end
            catch
            end
        end

        function s = signatureList(app, v)
            if ischar(v) || isstring(v)
                s = lower(char(string(v)));
                return;
            end
            if isempty(v)
                s = '';
                return;
            end
            if iscell(v)
                tmp = cell(1,numel(v));
                for i=1:numel(v)
                    try
                        tmp{i} = lower(char(string(v{i})));
                    catch
                        tmp{i} = '';
                    end
                end
                s = strjoin(tmp, ',');
            else
                try
                    s = lower(char(string(v)));
                catch
                    s = '';
                end
            end
        end

        function p = normPath(app, in)
            p = '';
            if isempty(in)
                return;
            end
            try
                p = char(string(in));
            catch
                return;
            end
            p = strrep(p,'\','/');
            p = regexprep(p,'/+$','');
        end

        function tf = hasMainApp(app)
            tf = false;
            try
                tf = ~isempty(app.mainapp) && isvalid(app.mainapp) && isprop(app.mainapp,'DetecDivUIFigure') && isvalid(app.mainapp.DetecDivUIFigure);
            catch
                tf = false;
            end
        end
    end

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app, shallowObj, mainapp)
            app.project=shallowObj;
            
           
                data={'' '' ''; '' '' ''; '' '' ''; '' '' ''};
                app.UITableFilter.Data=data;
               
                
            if nargin==3
            app.mainapp=mainapp;
            end
        end

        % Callback function
        function ChoosedirectoryButtonPushed(app, event)
           
            pathe = uigetdir(pwd,'Select directory with data:');
    
            if pathe==0
                disp('Quit!');
            return;
            end

          app.path=pathe;
          displayresults(app);
  
        end

        % Cell edit callback: UITable
        function UITableCellEdit(app, event)
            indices = event.Indices;
            newData = event.NewData;
            
        end

        % Cell selection callback: UITable
        function UITableCellSelection(app, event)
            indices = event.Indices;

           if ~isempty(indices)
    app.filenameLabel.Text = getSampleFilename(app, app.output.pos(indices(1)));
end

           app.com=indices(1);
           
           %app.ChannelfilterstringEditField.Value=app.output.pos(app.com).channelfilter;
           %app.StacksfilterstringEditField.Value=app.output.pos(app.com).stackfilter;
        end

        % Callback function
        function ChannelfilterstringEditFieldValueChanged(app, event)
        
        end

        % Callback function
        function StacksfilterstringEditFieldValueChanged(app, event)
  
        end

        % Callback function
        function ChannelfilterstringEditFieldValueChanging(app, event)
     
        end

        % Callback function
        function StacksfilterstringEditFieldValueChanging(app, event)

        end

        % Callback function
        function UIFigureButtonDown(app, event)
          
        end

        % Window button down function: UIFigure
        function UIFigureWindowButtonDown(app, event)
            %plotresults(app);
        end

        % Button pushed function: AddselectedpositionstoprojectButton


        function AddselectedpositionstoprojectButtonPushed(app, event)
            if isempty(app.output) || ~isfield(app.output,'pos') || isempty(app.output.pos)
                uialert(app.UIFigure,'There are no data to be added !','Error');
                return;
            end

            selected = find(cellfun(@(x) x==1, app.UITable.Data(:,1)));
            if isempty(selected)
                uialert(app.UIFigure,'You must select at least one item !','Warning');
                return;
            end

            selectedOutput = app.output;
            selectedOutput.pos = selectedOutput.pos(selected);

            lab = app.DatalabelEditField.Value;
            params = struct();
            params.write = true;
            params.interactive = false;
            params.label = lab;
            if ~isempty(app.path)
                params.path = app.path;
            end

            nBefore = numel(app.project.fov);

            try
                ctx = struct();
                ctx.shallow = app.project;
                ctx.dataLoader = params;
                ctx.dataOutput = selectedOutput;
                ctx = dataLoader.process(ctx);
                app.project = ctx.shallow;
            catch ME
                uialert(app.UIFigure, ME.message, 'Error', 'Icon','error');
                return;
            end

            nAfter = numel(app.project.fov);
            nDelta = max(0, nAfter - nBefore);
            if nDelta > 0
                msg = sprintf('Data successfully added (%d new FOVs). Press Close to return.', nDelta);
            else
                msg = 'No new FOV was added (already loaded data were skipped). Press Close to return.';
            end

            uialert(app.UIFigure, msg, 'Import result', 'Icon','success');
        end

        % Close request function: UIFigure

        function UIFigureCloseRequest(app, event)
            if hasMainApp(app)
                uiresume(app.mainapp.DetecDivUIFigure);
            end
            delete(app);
        end

        % Button pushed function: ChoosedirectoryButton
        function ChoosedirectoryButtonPushed2(app, event)
            pathe=uigetdir(pwd);
            
            if pathe~=0
                app.path=pathe; 
                displayresults(app)
            end
        end

        % Button pushed function: ParsefilelistButton
        function ParsefilelistButtonPushed(app, event)
            displayresults(app,'ok')
        end

        % Button pushed function: CloseButton

        function CloseButtonPushed(app, event)
            if hasMainApp(app)
                uiresume(app.mainapp.DetecDivUIFigure);
            end
            delete(app);
        end

        % Selection changed function: UITable
        function UITableSelectionChanged(app, event)
            selection = app.UITable.Selection;
            
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [92 92 652 797];
            app.UIFigure.Name = 'MATLAB App';
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @UIFigureCloseRequest, true);
            app.UIFigure.WindowButtonDownFcn = createCallbackFcn(app, @UIFigureWindowButtonDown, true);

            % Create SelectdatadirectoryPanel
            app.SelectdatadirectoryPanel = uipanel(app.UIFigure);
            app.SelectdatadirectoryPanel.Title = 'Select data directory';
            app.SelectdatadirectoryPanel.Position = [4 715 640 79];

            % Create ChoosedirectoryButton
            app.ChoosedirectoryButton = uibutton(app.SelectdatadirectoryPanel, 'push');
            app.ChoosedirectoryButton.ButtonPushedFcn = createCallbackFcn(app, @ChoosedirectoryButtonPushed2, true);
            app.ChoosedirectoryButton.Position = [7 26 119 22];
            app.ChoosedirectoryButton.Text = 'Choose directory....';

            % Create Label
            app.Label = uilabel(app.SelectdatadirectoryPanel);
            app.Label.WordWrap = 'on';
            app.Label.Position = [151 8 445 47];
            app.Label.Text = '';

            % Create DataselectioncommandsPanel
            app.DataselectioncommandsPanel = uipanel(app.UIFigure);
            app.DataselectioncommandsPanel.Title = 'Data selection commands';
            app.DataselectioncommandsPanel.Position = [5 9 640 701];

            % Create UITable
            app.UITable = uitable(app.DataselectioncommandsPanel);
            app.UITable.ColumnName = {'Select'; 'Position'; '# Channels'; '#Frames'};
            app.UITable.RowName = {};
            app.UITable.CellEditCallback = createCallbackFcn(app, @UITableCellEdit, true);
            app.UITable.CellSelectionCallback = createCallbackFcn(app, @UITableCellSelection, true);
            app.UITable.SelectionChangedFcn = createCallbackFcn(app, @UITableSelectionChanged, true);
            app.UITable.Enable = 'off';
            app.UITable.Position = [15 95 607 267];

            % Create SamplefilenameLabel
            app.SamplefilenameLabel = uilabel(app.DataselectioncommandsPanel);
            app.SamplefilenameLabel.Position = [7 648 132 22];
            app.SamplefilenameLabel.Text = 'Sample file name: ';

            % Create filenameLabel
            app.filenameLabel = uilabel(app.DataselectioncommandsPanel);
            app.filenameLabel.WordWrap = 'on';
            app.filenameLabel.Position = [115 640 517 38];
            app.filenameLabel.Text = 'filename';

            % Create ParsingcommentsLabel
            app.ParsingcommentsLabel = uilabel(app.DataselectioncommandsPanel);
            app.ParsingcommentsLabel.Position = [7 616 109 22];
            app.ParsingcommentsLabel.Text = 'Parsing comments:';

            % Create Label_2
            app.Label_2 = uilabel(app.DataselectioncommandsPanel);
            app.Label_2.WordWrap = 'on';
            app.Label_2.Position = [138 588 493 49];
            app.Label_2.Text = '';

            % Create UITableFilter
            app.UITableFilter = uitable(app.DataselectioncommandsPanel);
            app.UITableFilter.ColumnName = {'Positions'; 'Channels'; 'Stacks'};
            app.UITableFilter.RowName = {};
            app.UITableFilter.Enable = 'off';
            app.UITableFilter.Position = [13 437 484 134];

            % Create ParseroutputLabel
            app.ParseroutputLabel = uilabel(app.DataselectioncommandsPanel);
            app.ParseroutputLabel.Position = [16 365 81 22];
            app.ParseroutputLabel.Text = 'Parser output:';

            % Create ParserinputLabel
            app.ParserinputLabel = uilabel(app.DataselectioncommandsPanel);
            app.ParserinputLabel.WordWrap = 'on';
            app.ParserinputLabel.Position = [15 401 562 28];
            app.ParserinputLabel.Text = 'For each category, please enter a string to extract positions/channels/stacks. Example : for channels, either write ''GFP'', ''mCherry'' or ''cha$'' to look for numerated channels in the form ''cha1'', ''cha2'' etc.';

            % Create AddselectedpositionstoprojectButton
            app.AddselectedpositionstoprojectButton = uibutton(app.DataselectioncommandsPanel, 'push');
            app.AddselectedpositionstoprojectButton.ButtonPushedFcn = createCallbackFcn(app, @AddselectedpositionstoprojectButtonPushed, true);
            app.AddselectedpositionstoprojectButton.Position = [19 9 288 33];
            app.AddselectedpositionstoprojectButton.Text = 'Add selected positions to project';

            % Create ParsefilelistButton
            app.ParsefilelistButton = uibutton(app.DataselectioncommandsPanel, 'push');
            app.ParsefilelistButton.ButtonPushedFcn = createCallbackFcn(app, @ParsefilelistButtonPushed, true);
            app.ParsefilelistButton.Enable = 'off';
            app.ParsefilelistButton.Position = [522 483 100 85];
            app.ParsefilelistButton.Text = 'Parse filelist !';

            % Create ParsingrulesLabel
            app.ParsingrulesLabel = uilabel(app.DataselectioncommandsPanel);
            app.ParsingrulesLabel.Position = [9 580 79 22];
            app.ParsingrulesLabel.Text = 'Parsing rules:';

            % Create DatalabelEditFieldLabel
            app.DatalabelEditFieldLabel = uilabel(app.DataselectioncommandsPanel);
            app.DatalabelEditFieldLabel.HorizontalAlignment = 'right';
            app.DatalabelEditFieldLabel.Position = [20 57 63 22];
            app.DatalabelEditFieldLabel.Text = 'Data label:';

            % Create DatalabelEditField
            app.DatalabelEditField = uieditfield(app.DataselectioncommandsPanel, 'text');
            app.DatalabelEditField.Position = [98 57 334 22];

            % Create CloseButton
            app.CloseButton = uibutton(app.DataselectioncommandsPanel, 'push');
            app.CloseButton.ButtonPushedFcn = createCallbackFcn(app, @CloseButtonPushed, true);
            app.CloseButton.Position = [322 9 296 33];
            app.CloseButton.Text = 'Close';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = addDataGUI(varargin)

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @(app)startupFcn(app, varargin{:}))

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