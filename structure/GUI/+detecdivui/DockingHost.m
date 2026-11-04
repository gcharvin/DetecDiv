classdef DockingHost < handle
    % R2026a-only boundary around MATLAB's undocumented web docking system.
    properties (SetAccess = private)
        App
        Widgets
        Menus = {}
        Commands = {}
        LayoutFile
        LastLayoutError = ''
    end
    properties
        OnClosed = []
    end
    properties (Access = private)
        Window
        Pump
        StateListener
        DefaultLayout
        AutoSave = true
        Closing = false
        LastMenuJSON = ''
        DockCommands = {}
        MenusInstalled = false
        WebBusy = false
        VisibilityCommands = {}
        InvalidLayout = false
    end
    methods
        function obj = DockingHost(layoutFile,autoSave)
            assert(ispc && strcmp(version('-release'),'2026a'), ...
                'detecdivui:DockingRelease','The docking host currently requires Windows MATLAB R2026a.');
            obj.LayoutFile = char(layoutFile); obj.AutoSave = autoSave;
            obj.App = matlab.ui.container.internal.AppContainer( ...
                'Tag',['DetecDivUI_' char(matlab.lang.internal.uuid)],'Title','DetecDiv', ...
                'PersistLayout',false,'PersistDocuments',false,'CleanStart',true, ...
                'ToolstripEnabled',false,'WindowBounds',[80 80 1380 840]);
            group = matlab.ui.internal.FigureDocumentGroup( ...
                'Tag','workspace','Title','Workspace','EnableDockControls',true);
            obj.App.add(group);
            for name = {'Projects','Image','Display'}
                id = lower(name{1});
                doc = matlab.ui.internal.FigureDocument('Tag',id,'Title',name{1}, ...
                    'DocumentGroupTag','workspace','EnableDockControls',true,'Closable',false);
                obj.App.add(doc); obj.Widgets.(id) = doc;
            end
            obj.App.CanCloseFcn = @(~)obj.allowClose();
            obj.StateListener = addlistener(obj.App,'StateChanged',@(~,~)obj.appStateChanged());
        end
        function figure = widgetFigure(obj,name)
            figure = obj.widget(name).Figure;
        end
        function item = menu(obj,parent,text,varargin)
            item = detecdivui.MenuCommand(sprintf('command%d',numel(obj.Commands)+1),text,varargin{:});
            obj.Commands{end+1} = item;
            if isempty(parent), obj.Menus{end+1} = item;
            else, parent.Children{end+1} = item; end
        end
        function addDockMenus(obj,parent)
            docking = obj.menu(parent,'Docking','Separator','on');
            names = {'Projects','Image','Display'};
            for k = 1:numel(names)
                name = names{k};
                obj.DockCommands{k} = obj.menu(docking,['Undock ' name], ...
                    'MenuSelectedFcn',@(~,~)obj.setDocked(name,~obj.widget(name).Docked));
            end
            obj.menu(docking,'Dock All','Separator','on', ...
                'MenuSelectedFcn',@(~,~)obj.dockAll());
            obj.menu(parent,'Save Layout','Separator','on', ...
                'MenuSelectedFcn',@(~,~)obj.saveLayout());
            obj.menu(parent,'Restore Layout','MenuSelectedFcn',@(~,~)obj.restoreLayout());
            obj.menu(parent,'Reset Layout','MenuSelectedFcn',@(~,~)obj.resetLayout());
        end
        function item = widgetMenu(obj,parent,name)
            item = obj.menu(parent,name,'Checked','on', ...
                'MenuSelectedFcn',@(~,~)obj.setWidgetVisible(name,~obj.isWidgetVisible(name)));
            obj.VisibilityCommands{end+1} = struct('name',name,'command',item);
        end
        function start(obj,visibility)
            obj.App.Visible = true;
            started = tic;
            while obj.App.State ~= matlab.ui.container.internal.appcontainer.AppState.RUNNING
                assert(toc(started) < 30,'detecdivui:DockingStart','Docking window initialization timed out.');
                pause(0.03); drawnow;
            end
            windows = matlab.internal.webwindowmanager.instance.windowList;
            match = arrayfun(@(window)contains(char(window.URL),['&id=' char(obj.App.Tag) '&']),windows);
            assert(nnz(match) == 1,'detecdivui:DockingWindow','Cannot identify the docking window.');
            obj.Window = windows(match);
            obj.resetLayout();
            obj.waitForLayout(); obj.DefaultLayout = obj.App.Layout;
            if ~isempty(obj.LayoutFile) && isfile(obj.LayoutFile), obj.restoreLayout(); end
            script = fileread(fullfile(fileparts(mfilename('fullpath')),'desktopMenu.js'));
            obj.Window.executeJS(script,5);
            obj.MenusInstalled = true;
            obj.syncMenus();
            obj.Pump = timer('ExecutionMode','fixedSpacing','StartDelay',0.5,'Period',0.2,'BusyMode','drop', ...
                'Tag','DetecDivDockMenu','TimerFcn',@(~,~)obj.pumpMenu());
            start(obj.Pump);
            if strcmp(visibility,'off'), obj.Window.hide(); end
        end
        function setDocked(obj,name,docked)
            doc = obj.widget(name);
            doc.Visible = true; doc.Docked = logical(docked);
            obj.settle(); obj.syncMenus();
        end
        function value = isDocked(obj,name)
            value = obj.widget(name).Docked;
        end
        function setWidgetVisible(obj,name,visible)
            doc = obj.widget(name); doc.Visible = logical(visible);
            obj.settle(); obj.syncMenus();
        end
        function value = isWidgetVisible(obj,name)
            value = obj.widget(name).Visible;
        end
        function dockAll(obj)
            names = fieldnames(obj.Widgets);
            for k = 1:numel(names)
                doc = obj.widget(names{k}); doc.Docked = true;
            end
            obj.settle(); obj.syncMenus();
        end
        function resetLayout(obj)
            obj.dockAll();
            names = {'projects','image','display'};
            for k = 1:numel(names)
                doc = obj.widget(names{k}); doc.Visible = true;
            end
            if ~isempty(obj.DefaultLayout)
                obj.App.Layout = obj.DefaultLayout;
            else
                layout = struct('gridDimensions',struct('w',3,'h',1),'tileCount',3, ...
                    'columnWeights',[0.20 0.64 0.16],'rowWeights',1,'tileCoverage',[1 2 3]);
                occupancy = repmat(struct('children',struct('id','')),1,3);
                for k = 1:3, occupancy(k).children.id = ['workspace_' names{k}]; end
                layout.tileOccupancy = occupancy;
                obj.App.DocumentLayout = layout;
            end
            obj.settle(); obj.syncMenus();
        end
        function record = snapshot(obj)
            obj.waitForLayout();
            record = struct('schema','detecdiv.ui.layout.v1','release',version('-release'), ...
                'layout',obj.App.Layout,'windowBounds',obj.App.WindowBounds,'widgets',struct());
            names = fieldnames(obj.Widgets);
            for k = 1:numel(names)
                doc = obj.widget(names{k});
                record.widgets.(names{k}) = struct('docked',doc.Docked, ...
                    'visible',doc.Visible,'windowBounds',doc.WindowBounds);
            end
        end
        function saveLayout(obj,file)
            if nargin < 2, file = obj.LayoutFile; end
            if isempty(file), return; end
            record = obj.snapshot();
            folder = fileparts(char(file));
            if ~isempty(folder) && ~isfolder(folder), mkdir(folder); end
            if isempty(folder), folder = pwd; end
            temporary = [tempname(folder) '.json'];
            fid = fopen(temporary,'w','n','UTF-8');
            assert(fid >= 0,'detecdivui:LayoutWrite','Cannot write the workspace layout.');
            cleanup = onCleanup(@()fclose(fid));
            fprintf(fid,'%s',jsonencode(record));
            clear cleanup;
            [ok,msg] = movefile(temporary,file,'f');
            assert(ok,'detecdivui:LayoutWrite','Cannot save the workspace layout: %s',msg);
            obj.LastLayoutError = '';
            obj.InvalidLayout = false;
        end
        function ok = restoreLayout(obj,file)
            if nargin < 2, file = obj.LayoutFile; end
            ok = false;
            if isempty(file) || ~isfile(file), return; end
            try
                record = jsondecode(fileread(file));
                obj.validateRecord(record);
                obj.App.WindowBounds = reshape(record.windowBounds,1,4);
                names = fieldnames(obj.Widgets);
                for k = 1:numel(names)
                    state = record.widgets.(names{k}); doc = obj.widget(names{k});
                    doc.WindowBounds = reshape(state.windowBounds,1,4);
                    doc.Docked = state.docked; doc.Visible = state.visible;
                end
                obj.waitForLayout();
                obj.App.Layout = record.layout;
                obj.waitForLayout();
                % A newly opened floating CEF window can publish its default
                % bounds after the initial state set. Apply saved bounds last.
                for k = 1:numel(names)
                    state = record.widgets.(names{k});
                    if ~state.docked
                        doc = obj.widget(names{k});
                        doc.WindowBounds = reshape(state.windowBounds,1,4);
                    end
                end
                obj.waitForLayout(); obj.syncMenus();
                obj.LastLayoutError = ''; ok = true;
                obj.InvalidLayout = false;
            catch err
                obj.LastLayoutError = ['Layout not restored: ' err.message];
                % Keep an invalid user file intact until an explicit save.
                obj.InvalidLayout = true;
                obj.resetLayout();
            end
        end
        function item = findCommand(obj,text)
            matches = cellfun(@(command)strcmp(command.Text,text),obj.Commands);
            assert(nnz(matches) == 1,'detecdivui:MenuCommand','Menu command is missing or ambiguous: %s',text);
            item = obj.Commands{find(matches,1)};
        end
        function syncMenus(obj)
            if ~obj.MenusInstalled || obj.WebBusy || isempty(obj.Window) || ~isvalid(obj.Window) || obj.Closing, return; end
            for k = 1:numel(obj.DockCommands)
                names = {'Projects','Image','Display'}; name = names{k};
                verb = 'Undock';
                if ~obj.isDocked(name), verb = 'Dock'; end
                obj.DockCommands{k}.Text = [verb ' ' name];
            end
            for k = 1:numel(obj.VisibilityCommands)
                binding = obj.VisibilityCommands{k};
                if obj.isWidgetVisible(binding.name), binding.command.Checked = 'on';
                else, binding.command.Checked = 'off'; end
            end
            json = jsonencode(cellfun(@(item)item.serialize(),obj.Menus,'UniformOutput',false));
            if strcmp(json,obj.LastMenuJSON), return; end
            obj.executeJS(['window.detecdivMenu.setMenus(' json ');']);
            obj.LastMenuJSON = json;
        end
        function result = menuScript(obj,script)
            % Access only this host's menu adapter (also used by integration tests).
            result = obj.executeJS(script);
        end
        function capture(obj,file)
            obj.settle(); obj.WebBusy = true;
            release = onCleanup(@()obj.releaseWeb());
            imwrite(obj.Window.getScreenshot(),file);
        end
        function show(obj)
            obj.Window.show();
        end
        function delete(obj)
            if obj.Closing, return; end
            obj.stopPump();
            obj.saveOnClose(); obj.Closing = true;
            if ~isempty(obj.StateListener), delete(obj.StateListener); end
            if ~isempty(obj.App) && isvalid(obj.App), delete(obj.App); end
        end
    end
    methods (Access = private)
        function result = executeJS(obj,script)
            obj.WebBusy = true;
            release = onCleanup(@()obj.releaseWeb());
            result = obj.Window.executeJS(script,2);
        end
        function releaseWeb(obj)
            if isvalid(obj), obj.WebBusy = false; end
        end
        function doc = widget(obj,name)
            id = lower(char(name));
            assert(isfield(obj.Widgets,id),'detecdivui:Widget','Unknown widget: %s',id);
            doc = obj.Widgets.(id);
        end
        function settle(obj)
            drawnow;
            if ~isempty(obj.App) && isvalid(obj.App)
                obj.App.waitForPendingAsyncOperations();
            end
            drawnow;
        end
        function waitForLayout(obj)
            % Native document moves update peer properties asynchronously.
            % Require a quiet layout rather than saving a transient old grid.
            previous = ''; stable = tic; started = tic;
            while toc(started) < 10
                obj.settle();
                layout = obj.App.Layout;
                current = jsonencode(obj.stableLayoutFields(layout));
                if ~strcmp(previous,current)
                    previous = current; stable = tic;
                elseif toc(stable) >= 0.35 && isfield(layout,'documentLayout')
                    return;
                end
                pause(0.05);
            end
            error('detecdivui:LayoutBusy','Workspace layout has not settled.');
        end
        function value = stableLayoutFields(obj,value)
            % Selection counters and pixel caches can change even when the
            % docking geometry is stationary. They are not a layout barrier.
            if isstruct(value)
                ignored = {'selectionOrder','showOrder','lastSelectedDocumentId', ...
                    'referenceWidth','referenceHeight','columnLeft','rowTop','windowBounds'};
                value = rmfield(value,intersect(fieldnames(value),ignored));
                value = orderfields(value);
                names = fieldnames(value);
                for k = 1:numel(value)
                    for j = 1:numel(names)
                        value(k).(names{j}) = obj.stableLayoutFields(value(k).(names{j}));
                    end
                end
            elseif iscell(value)
                value = cellfun(@(item)obj.stableLayoutFields(item),value,'UniformOutput',false);
            elseif isnumeric(value)
                value = round(value,4);
            end
        end
        function pumpMenu(obj)
            if obj.Closing || obj.WebBusy, return; end
            try
                events = jsondecode(obj.executeJS('JSON.stringify(window.detecdivMenu.drain())'));
                if ischar(events) || isstring(events), events = jsondecode(events); end
                for k = 1:numel(events)
                    id = events{k};
                    index = find(cellfun(@(command)strcmp(command.Id,id),obj.Commands),1);
                    if ~isempty(index), obj.Commands{index}.invoke(); end
                    if ~isvalid(obj) || obj.Closing, return; end
                end
                obj.syncMenus();
            catch err
                if isvalid(obj) && ~obj.Closing
                    warning('detecdivui:DesktopMenu','Desktop menu: %s',err.message);
                end
            end
        end
        function saveOnClose(obj)
            if ~obj.AutoSave || obj.InvalidLayout || isempty(obj.App) || ~isvalid(obj.App) || ...
                    obj.App.State ~= matlab.ui.container.internal.appcontainer.AppState.RUNNING, return; end
            try
                obj.saveLayout();
            catch err
                warning('detecdivui:LayoutSave','Layout not saved: %s',err.message);
            end
        end
        function ok = allowClose(obj)
            obj.stopPump(); obj.saveOnClose(); ok = true;
        end
        function appStateChanged(obj)
            if obj.Closing, return; end
            if obj.App.State == matlab.ui.container.internal.appcontainer.AppState.TERMINATED
                obj.stopPump();
                if ~isempty(obj.OnClosed), obj.OnClosed(); end
            end
        end
        function stopPump(obj)
            if ~isempty(obj.Pump) && isvalid(obj.Pump)
                stop(obj.Pump); delete(obj.Pump);
            end
            obj.Pump = [];
        end
        function validateRecord(obj,record)
            assert(isstruct(record) && isscalar(record) && ...
                all(isfield(record,{'schema','release','layout','widgets','windowBounds'})), ...
                'detecdivui:LayoutSchema','Invalid workspace layout.');
            assert(strcmp(record.schema,'detecdiv.ui.layout.v1') && strcmp(record.release,version('-release')), ...
                'detecdivui:LayoutVersion','Workspace layout belongs to a different format or MATLAB release.');
            validateattributes(record.windowBounds,{'numeric'},{'vector','numel',4,'finite'});
            assert(isstruct(record.layout) && ~isempty(fieldnames(record.layout)), ...
                'detecdivui:LayoutSchema','Workspace layout is empty.');
            names = fieldnames(obj.Widgets);
            for k = 1:numel(names)
                state = record.widgets.(names{k});
                validateattributes(state.docked,{'logical'},{'scalar'});
                validateattributes(state.visible,{'logical'},{'scalar'});
                validateattributes(state.windowBounds,{'numeric'},{'vector','numel',4,'finite'});
            end
        end
    end
end
