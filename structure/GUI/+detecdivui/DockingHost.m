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
        OnActivity = []
        OnCanClose = []
        OnWidgetVisibility = []
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
        HiddenLayouts
        ArrangedWidgets = struct('data',false,'objects',false)
        AppCloseApproved = false
        PendingCloses
        HiddenFloating
    end
    methods
        function obj = DockingHost(layoutFile,autoSave)
            assert(ispc && strcmp(version('-release'),'2026a'), ...
                'detecdivui:DockingRelease','The docking host currently requires Windows MATLAB R2026a.');
            obj.LayoutFile = char(layoutFile); obj.AutoSave = autoSave;
            obj.HiddenLayouts = containers.Map('KeyType','char','ValueType','any');
            obj.PendingCloses = containers.Map('KeyType','char','ValueType','any');
            obj.HiddenFloating = containers.Map('KeyType','char','ValueType','any');
            obj.App = matlab.ui.container.internal.AppContainer( ...
                'Tag',['DetecDivUI_' char(matlab.lang.internal.uuid)],'Title','DetecDiv', ...
                'PersistLayout',false,'PersistDocuments',false,'CleanStart',true, ...
                'ToolstripEnabled',false,'WindowBounds',[80 80 1380 840]);
            group = matlab.ui.internal.FigureDocumentGroup( ...
                'Tag','workspace','Title','Workspace','EnableDockControls',true);
            obj.App.add(group);
            for name = {'Projects','Image','Display','Pipeline','Objects','Data','Classifier'}
                id = lower(name{1});
                doc = matlab.ui.internal.FigureDocument('Tag',id,'Title',name{1}, ...
                    'DocumentGroupTag','workspace','EnableDockControls',true,'Closable',true);
                if strcmp(id,'objects'), doc.Title='Annotations'; end
                obj.App.add(doc); obj.Widgets.(id) = doc;
                doc.CanCloseFcn = @(document)obj.requestWidgetClose(id,document);
                doc.Figure.CloseRequestFcn = @(~,~)obj.deferWidgetClose(id);
                if ismember(id,{'data','objects','classifier'}), doc.Visible = false; end
            end
            obj.App.CanCloseFcn = @(~)obj.allowClose();
            obj.StateListener = addlistener(obj.App,'StateChanged',@(~,~)obj.appStateChanged());
        end
        function name = widgetId(~,name)
            name=lower(char(name)); if strcmp(name,'annotations'), name='objects'; end
        end
        function name = widgetLabel(~,name)
            name=char(name); if strcmpi(name,'Objects'), name='Annotations'; end
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
            names = {'Projects','Image','Display','Pipeline','Objects','Data','Classifier'};
            for k = 1:numel(names)
                name = names{k};
                obj.DockCommands{k} = obj.menu(docking,['Undock ' obj.widgetLabel(name)], ...
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
            item = obj.menu(parent,obj.widgetLabel(name),'Checked','on', ...
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
            id = obj.widgetId(name); previous = [];
            if isKey(obj.HiddenFloating,id), previous = obj.HiddenFloating(id); remove(obj.HiddenFloating,id); end
            doc.Visible = true; doc.Docked = logical(docked);
            obj.waitForLayout(); obj.syncMenus();
            if ~docked && ~isempty(previous), doc.WindowBounds = previous.windowBounds; end
            obj.notifyVisibility(name,true);
        end
        function value = isDocked(obj,name)
            doc = obj.widget(name); value = doc.Docked;
            if ~doc.Visible && isKey(obj.HiddenFloating,lower(char(name))), value = false; end
        end
        function focusWidget(obj,name)
            obj.setWidgetVisible(name,true);
            if strcmpi(name,'Classifier'), obj.ensureClassifierPlacement(); end
            obj.App.SelectedChild = struct('tag',obj.widgetId(name),'documentGroupTag','workspace');
            obj.settle();
        end
        function openData(obj)
            obj.openInspector('Data','Image',.70);
        end
        function openObjects(obj)
            obj.openInspector('Objects','Display',.55);
        end
        function arrangeAnalysis(obj)
            activity = obj.activity('Arranging analysis workspace...'); %#ok<NASGU>
            for name = {'Objects','Data'}
                obj.setWidgetVisible(name{1},false);
                obj.Widgets.(lower(name{1})).Docked = true;
                obj.ArrangedWidgets.(lower(name{1})) = false;
                if isKey(obj.HiddenLayouts,lower(name{1})), remove(obj.HiddenLayouts,lower(name{1})); end
            end
            obj.openObjects(); obj.openData();
        end
        function closeWidget(obj,name)
            % Native tab/floating-window Close hides the document only.
            % Scientific drafts and component handles remain owned by Viewer.
            if obj.Closing || obj.AppCloseApproved, return; end
            obj.setWidgetVisible(name,false);
        end
        function setWidgetVisible(obj,name,visible)
            id = obj.widgetId(name); doc = obj.widget(id);
            if doc.Visible == logical(visible)
                if visible && strcmpi(name,'Classifier'), obj.ensureClassifierPlacement(); end
                obj.syncMenus(); return;
            end
            remembered = []; floating = [];
            if ~visible && ~doc.Docked
                % Hiding a floating peer directly can discard its document
                % node. Park it in the main host before hiding, retaining
                % its floating intent/bounds for the next open operation.
                floating = struct('windowBounds',doc.WindowBounds);
                obj.HiddenFloating(id) = floating;
                doc.Docked = true; obj.waitForLayout();
            elseif visible && isKey(obj.HiddenFloating,id)
                floating = obj.HiddenFloating(id);
            end
            if ~visible && doc.Docked && isempty(floating)
                obj.waitForLayout();
                remembered = obj.App.DocumentLayout;
            elseif visible && doc.Docked && isKey(obj.HiddenLayouts,id)
                obj.waitForLayout();
                saved = obj.HiddenLayouts(id);
                current = obj.stableLayoutFields(obj.App.DocumentLayout);
                % JSON does not retain row/column orientation of vector
                % arrays; compare canonical encodings across saved sessions.
                if strcmp(jsonencode(current),jsonencode(obj.stableLayoutFields(saved.hidden)))
                    remembered = saved.visible;
                end
                remove(obj.HiddenLayouts,id);
            end
            doc.Visible = logical(visible);
            obj.waitForLayout();
            if visible && ~isempty(floating)
                doc.Docked = false; obj.waitForLayout();
                doc.WindowBounds = floating.windowBounds; obj.waitForLayout();
                remove(obj.HiddenFloating,id);
            end
            if ~isempty(remembered)
                if visible
                    obj.App.DocumentLayout = detecdivui.WorkspaceLayout.geometry(remembered); obj.waitForLayout();
                else
                    obj.HiddenLayouts(id) = struct('visible',remembered, ...
                        'hidden',obj.stableLayoutFields(obj.App.DocumentLayout));
                end
            end
            obj.settle(); obj.syncMenus();
            if visible && strcmpi(name,'Classifier'), obj.ensureClassifierPlacement(); end
            obj.notifyVisibility(id,logical(visible));
        end
        function value = isWidgetVisible(obj,name)
            value = obj.widget(name).Visible;
        end
        function dockAll(obj)
            names = fieldnames(obj.Widgets);
            for k = 1:numel(names)
                doc = obj.widget(names{k}); doc.Docked = true;
            end
            obj.HiddenFloating = containers.Map('KeyType','char','ValueType','any');
            obj.settle(); obj.syncMenus();
        end
        function resetLayout(obj)
            activity = obj.activity('Arranging workspace...'); %#ok<NASGU>
            obj.dockAll();
            obj.Widgets.data.Visible = false; obj.Widgets.objects.Visible = false;
            obj.Widgets.classifier.Visible = false;
            obj.ArrangedWidgets = struct('data',false,'objects',false);
            obj.HiddenLayouts = containers.Map('KeyType','char','ValueType','any');
            names = {'projects','image','display','pipeline'};
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
                occupancy(3).children(2).id = 'workspace_pipeline';
                occupancy(1).children(2).id = 'workspace_classifier';
                layout.tileOccupancy = occupancy;
                obj.App.DocumentLayout = layout;
            end
            obj.settle(); obj.syncMenus();
            names = fieldnames(obj.Widgets);
            for k = 1:numel(names), obj.notifyVisibility(names{k},obj.widget(names{k}).Visible); end
        end
        function record = snapshot(obj)
            obj.waitForLayout();
            record = struct('schema','detecdiv.ui.layout.v1','release',version('-release'), ...
                'layout',obj.App.Layout,'windowBounds',obj.App.WindowBounds,'widgets',struct());
            names = fieldnames(obj.Widgets);
            for k = 1:numel(names)
                doc = obj.widget(names{k});
                bounds = doc.WindowBounds;
                if ~doc.Visible && isKey(obj.HiddenFloating,names{k}), bounds = obj.HiddenFloating(names{k}).windowBounds; end
                record.widgets.(names{k}) = struct('docked',obj.isDocked(names{k}), ...
                    'visible',doc.Visible,'windowBounds',bounds);
                if isfield(obj.ArrangedWidgets,names{k})
                    record.widgets.(names{k}).placed = obj.ArrangedWidgets.(names{k}) || doc.Visible || ~doc.Docked;
                end
            end
            record.hiddenLayouts = struct();
            for id = reshape(obj.HiddenLayouts.keys,1,[])
                record.hiddenLayouts.(id{1}) = obj.HiddenLayouts(id{1});
            end
        end
        function saveLayout(obj,file)
            if nargin < 2, file = obj.LayoutFile; end
            if isempty(file), return; end
            activity = obj.activity('Saving layout...'); %#ok<NASGU>
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
            activity = obj.activity('Restoring layout...'); %#ok<NASGU>
            if nargin < 2, file = obj.LayoutFile; end
            ok = false;
            if isempty(file) || ~isfile(file), return; end
            try
                record = jsondecode(fileread(file));
                % Earlier workspaces predate Pipeline. Keep their geometry;
                % expose the new widget through View without resetting tiles.
                if isfield(record,'widgets') && ~isfield(record.widgets,'pipeline')
                    record.widgets.pipeline = struct('docked',true,'visible',false, ...
                        'windowBounds',obj.Widgets.pipeline.WindowBounds);
                end
                if isfield(record,'widgets') && ~isfield(record.widgets,'data')
                    record.widgets.data = struct('docked',true,'visible',false, ...
                        'windowBounds',obj.Widgets.data.WindowBounds);
                end
                if isfield(record,'widgets') && ~isfield(record.widgets,'objects')
                    record.widgets.objects = struct('docked',true,'visible',false, ...
                        'windowBounds',obj.Widgets.objects.WindowBounds);
                end
                if isfield(record,'widgets') && ~isfield(record.widgets,'classifier')
                    record.widgets.classifier = struct('docked',true,'visible',false, ...
                        'windowBounds',obj.Widgets.classifier.WindowBounds);
                end
                obj.validateRecord(record);
                obj.App.WindowBounds = reshape(record.windowBounds,1,4);
                obj.HiddenFloating = containers.Map('KeyType','char','ValueType','any');
                names = fieldnames(obj.Widgets);
                for k = 1:numel(names)
                    state = record.widgets.(names{k}); doc = obj.widget(names{k});
                    doc.Docked = state.docked || ~state.visible; doc.Visible = state.visible;
                    if ~state.docked && ~state.visible
                        obj.HiddenFloating(names{k}) = struct('windowBounds',reshape(state.windowBounds,1,4));
                    end
                    if isfield(obj.ArrangedWidgets,names{k})
                        placed = state.visible || ~state.docked;
                        if isfield(state,'placed'), placed = state.placed; end
                        obj.ArrangedWidgets.(names{k}) = placed;
                    end
                end
                obj.waitForLayout();
                obj.App.Layout = record.layout;
                obj.waitForLayout();
                % Reparent before applying bounds: docked defaults can use
                % negative sentinels, invalid for a still-floating viewport.
                % Floating CEF windows can also publish their defaults late.
                for k = 1:numel(names)
                    state = record.widgets.(names{k});
                    doc = obj.widget(names{k});
                    if doc.Docked || all(state.windowBounds(3:4)>=0)
                        doc.WindowBounds = reshape(state.windowBounds,1,4);
                    end
                end
                obj.waitForLayout(); obj.syncMenus();
                obj.HiddenLayouts = containers.Map('KeyType','char','ValueType','any');
                if isfield(record,'hiddenLayouts')
                    for id = reshape(fieldnames(record.hiddenLayouts),1,[])
                        if isfield(obj.Widgets,id{1})
                            saved = record.hiddenLayouts.(id{1});
                            assert(isstruct(saved) && all(isfield(saved,{'visible','hidden'})), ...
                                'detecdivui:LayoutSchema','Invalid hidden widget placement.');
                            obj.HiddenLayouts(id{1}) = saved;
                        end
                    end
                end
                for k = 1:numel(names), obj.notifyVisibility(names{k},obj.widget(names{k}).Visible); end
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
            text = strrep(text,'Objects','Annotations');
            if strcmp(text,'Edit Contours...'), text='Edit Masks...'; end
            if strcmp(text,'Save Masks'), text='Save Annotations'; end
            matches = cellfun(@(command)strcmp(command.Text,text),obj.Commands);
            assert(nnz(matches) == 1,'detecdivui:MenuCommand','Menu command is missing or ambiguous: %s',text);
            item = obj.Commands{find(matches,1)};
        end
        function syncMenus(obj)
            if ~obj.MenusInstalled || obj.WebBusy || isempty(obj.Window) || ~isvalid(obj.Window) || obj.Closing, return; end
            for k = 1:numel(obj.DockCommands)
                names = {'Projects','Image','Display','Pipeline','Objects','Data','Classifier'}; name = names{k};
                verb = 'Undock';
                if ~obj.isDocked(name), verb = 'Dock'; end
                obj.DockCommands{k}.Text = [verb ' ' obj.widgetLabel(name)];
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
        function abortStartup(obj)
            % A partial/new failed host must not overwrite a saved layout.
            obj.AutoSave = false;
            obj.stopPump();
            obj.stopPendingCloses();
        end
        function delete(obj)
            if obj.Closing, return; end
            teardown = detecdivui.startupGuard('begin'); %#ok<NASGU>
            obj.stopPump();
            obj.stopPendingCloses();
            obj.saveOnClose(); obj.Closing = true;
            if ~isempty(obj.StateListener), delete(obj.StateListener); end
            if ~isempty(obj.App) && isvalid(obj.App), delete(obj.App); end
        end
    end
    methods (Access = private)
        function ensureClassifierPlacement(obj)
            if ~obj.Widgets.classifier.Docked || ~obj.Widgets.classifier.Visible, return; end
            % Older layouts have no node for this new document. Its controls
            % may become visible without a native tab unless it is inserted.
            current = obj.App.DocumentLayout;
            if ~isempty(detecdivui.WorkspaceLayout.tile(current,'workspace_classifier')), return; end
            tile = detecdivui.WorkspaceLayout.tile(current,'workspace_projects');
            if isempty(tile), tile = detecdivui.WorkspaceLayout.tile(current,'workspace_image'); end
            if isempty(tile), return; end
            current = detecdivui.WorkspaceLayout.geometry(current);
            current.tileOccupancy(tile).children(end+1).id = 'workspace_classifier';
            current.tileOccupancy(tile).showingChildId = 'workspace_classifier';
            obj.App.DocumentLayout = current; obj.waitForLayout();
        end
        function openInspector(obj,name,anchor,fraction)
            id = lower(name); doc = obj.widget(id);
            floatingBounds = [];
            if ~doc.Visible && isKey(obj.HiddenFloating,id), floatingBounds = obj.HiddenFloating(id).windowBounds; end
            obj.show();
            obj.waitForLayout(); current = obj.App.DocumentLayout;
            arrange = ~doc.Visible && doc.Docked && ~obj.ArrangedWidgets.(id) && ...
                obj.widget(anchor).Docked && obj.widget(anchor).Visible;
            obj.setWidgetVisible(name,true);
            if arrange
                [layout,changed] = detecdivui.WorkspaceLayout.below(current, ...
                    ['workspace_' lower(anchor)],['workspace_' id],fraction);
                if changed
                    obj.App.DocumentLayout = layout; obj.waitForLayout();
                    obj.App.SelectedChild = struct('tag',lower(anchor),'documentGroupTag','workspace');
                end
            end
            obj.ArrangedWidgets.(id) = true;
            obj.focusWidget(name);
            if ~isempty(floatingBounds)
                % The newly focused floating peer can publish default
                % bounds after visibility/docking updates have settled.
                doc.WindowBounds = floatingBounds; obj.waitForLayout();
                doc.WindowBounds = floatingBounds; obj.settle();
            end
        end
        function ok = requestWidgetClose(obj,id,~)
            % AppContainer also queries document callbacks while closing the
            % whole application; only that approved path may destroy them.
            ok = obj.Closing || obj.AppCloseApproved;
            if ok, return; end
            % Floating peers can restore Visible during their native close
            % transaction. Veto destruction, then hide on the next event turn.
            obj.deferWidgetClose(id);
        end
        function deferWidgetClose(obj,id)
            if obj.Closing || obj.AppCloseApproved, return; end
            if isKey(obj.PendingCloses,id) && isvalid(obj.PendingCloses(id)), return; end
            pending = timer('ExecutionMode','singleShot','StartDelay',.03, ...
                'Tag','DetecDivWidgetClose','TimerFcn',@(~,~)obj.closeWidget(id), ...
                'StopFcn',@(source,~)obj.closeTimerStopped(id,source));
            obj.PendingCloses(id) = pending; start(pending);
        end
        function closeTimerStopped(obj,id,pending)
            if isKey(obj.PendingCloses,id) && isequal(obj.PendingCloses(id),pending), remove(obj.PendingCloses,id); end
            if isvalid(pending), delete(pending); end
        end
        function stopPendingCloses(obj)
            if isempty(obj.PendingCloses), return; end
            ids = obj.PendingCloses.keys;
            for k = 1:numel(ids)
                pending = obj.PendingCloses(ids{k});
                if isvalid(pending), stop(pending); end
                if isKey(obj.PendingCloses,ids{k}), remove(obj.PendingCloses,ids{k}); end
                if isvalid(pending), delete(pending); end
            end
        end
        function notifyVisibility(obj,name,visible)
            detecdivui.Callback.call(obj.OnWidgetVisibility,obj.widgetId(name),logical(visible));
        end
        function scope = activity(obj,message)
            scope = [];
            if ~isempty(obj.OnActivity), scope = detecdivui.Callback.call(obj.OnActivity,message); end
        end
        function result = executeJS(obj,script)
            obj.WebBusy = true;
            release = onCleanup(@()obj.releaseWeb());
            result = obj.Window.executeJS(script,2);
        end
        function releaseWeb(obj)
            if isvalid(obj), obj.WebBusy = false; end
        end
        function doc = widget(obj,name)
            id = obj.widgetId(name);
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
            if obj.Closing || obj.WebBusy || detecdivui.startupGuard('active'), return; end
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
            ok = true;
            if ~isempty(obj.OnCanClose), ok = detecdivui.Callback.call(obj.OnCanClose); end
            if ~ok, return; end
            obj.AppCloseApproved = true;
            obj.stopPendingCloses();
            obj.stopPump(); obj.saveOnClose(); ok = true;
        end
        function appStateChanged(obj)
            if obj.Closing, return; end
            if obj.App.State == matlab.ui.container.internal.appcontainer.AppState.TERMINATED
                obj.stopPump();
                if ~isempty(obj.OnClosed), detecdivui.Callback.call(obj.OnClosed); end
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
                if isfield(state,'placed'), validateattributes(state.placed,{'logical'},{'scalar'}); end
            end
        end
    end
end
