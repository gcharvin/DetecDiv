classdef Viewer < handle
    % Conventional desktop shell; legacy readers are accessed through Session.
    properties (SetAccess = private)
        Session
        Figure
        Host
        Sessions = {}
        ActiveProject = 0
        DisplayModel
        WorkspaceObjects = struct('object',{},'variables',{},'kind',{})
        Pipeline
        Progress
        ProjectProgress
        DisplayProgress
        ROIs
        Masks
        Tracks
        Data
        RecentProjects
    end
    properties (Access = private)
        Tree
        ProjectName
        DetailsPanel
        ProjectPath
        ProjectInfo
        CopyPath
        Channels
        LayerTable
        LayerKind
        ColorField
        ColorPicker
        MaskOptions
        MaskStyle
        MaskWidth
        Histogram
        MinField
        MaxField
        ContrastSlider
        AutoButton
        OpacitySlider
        DisplayModels = {}
        Frame
        TimeSlider
        FrameCount
        Previous
        Next
        Crumb
        Status
        Back
        Axes
        ImageGrid
        ImageAxes = gobjects(0)
        ImageLink = []
        ImageRevision = 0
        OverlayChannels
        Overlays
        BrowserMenu
        ToolsMenu
        OverlayMenu
        CloseMenu
        CopyMenu
        SavePipelineMenu
        RelinkMenu
        LoadImage
        RelinkImage
        ImageRequested = false
        MissingRaw = false
        ParentMenu
        PreviousMenu
        NextMenu
        ViewStates = {}
        PreferredChannel = ''
        SelectedZone = 0
        RenderKey = ''
        MaxFrame = 1
        Closing = false
        DisplayTabs
        ROIsTab
        MasksTab
        TracksTab
        EditTracksMenu
        AnnotationSelection = []
        EditContoursMenu
        SaveMasksMenu
        ImageMenu
        DefineROIMenu
        ImageROIMenu
        TreeROIMenu
        SaveProjectMenu
        DrawingROI = false
        KeyboardView
        KeyboardState = struct()
        KeyboardSelection = {}
        KeyboardGeneration = 0
        KeyboardFocusRequest = 0
        JumpKeys = {'l','m'}
        JumpBackMenu
        JumpForwardMenu
        ShortcutFigure = []
        LoadedObjects = struct('object',{},'variables',{},'kind',{})
        RecentMenu
        RecentCommands = {}
        ClearRecentCommand
        ProjectSources = {}
    end
    methods
        function obj = Viewer(project, visibility, layoutFile, autoSave,recentFile)
            if nargin < 1, project = []; end
            if nargin < 2, visibility = 'on'; end
            if nargin < 5, recentFile = fullfile(prefdir,'recentProjects.mat'); end
            obj.RecentProjects = detecdivui.RecentProjects(recentFile);
            obj.Session = detecdivui.Session();
            obj.Host = detecdivui.DockingHost(layoutFile,autoSave);
            obj.Host.OnClosed = detecdivui.Callback(obj,'delete');
            obj.Figure = obj.Host.widgetFigure('Image');
            [~,specialKeys] = detecdiv_prefs_get_shortcuts();
            if numel(specialKeys{3}) == 2 && numel(unique(lower(string(specialKeys{3})))) == 2 && ...
                    all(cellfun(@(key)~isempty(key),specialKeys{3}))
                obj.JumpKeys = cellfun(@lower,specialKeys{3},'UniformOutput',false);
            end
            obj.createMenus();
            root = uigridlayout(obj.Figure,[4 1]);
            root.RowHeight = {32,'1x',24,0};
            root.Padding = [8 6 8 6];
            root.BackgroundColor = [0.95 0.96 0.97];
            location = uigridlayout(root,[1 4]);
            location.ColumnWidth = {100,'1x',100,130}; location.Padding = [0 0 0 0];
            obj.Back = uibutton(location,'Text','← FOV','Enable','off', ...
                'Tag','parent-fov','Tooltip','Return to the parent FOV', ...
                'ButtonPushedFcn',@(~,~)obj.returnToPosition());
            obj.Crumb = uilabel(location,'Text','', ...
                'Interpreter','none','FontSize',12,'Tag','breadcrumb');
            obj.LoadImage = uibutton(location,'Text','Load Image','Enable','off', ...
                'Tag','load-image','Tooltip','Load the selected FOV or ROI on demand', ...
                'ButtonPushedFcn',@(~,~)obj.loadCurrentImage());
            obj.RelinkImage = uibutton(location,'Text','Relink Raw Data...','Visible','off', ...
                'Tag','relink-raw-data','Tooltip','Locate raw data using the existing project relink helper', ...
                'ButtonPushedFcn',@(~,~)obj.relinkRawData());
            nav = uigridlayout(obj.Host.widgetFigure('Projects'),[3 1]);
            nav.Padding = [4 4 4 4];
            nav.RowHeight = {'1x',230,22};
            obj.Tree = uitree(nav,'Tag','projects-tree', ...
                'SelectionChangedFcn',@(~,~)obj.browseSelection());
            obj.Tree.Tooltip = 'Browse open projects, FOVs and ROIs';
            treeMenu = uicontextmenu(obj.Host.widgetFigure('Projects'));
            obj.TreeROIMenu = uimenu(treeMenu,'Text','Define ROIs...','Enable','off', ...
                'MenuSelectedFcn',@(~,~)obj.openROITool());
            obj.Tree.ContextMenu = treeMenu;
            details = uipanel(nav,'Title','Project','Tag','project-details');
            obj.DetailsPanel = details;
            info = uigridlayout(details,[3 1]);
            info.Padding = [6 4 6 4]; info.RowHeight = {22,54,'1x'};
            obj.ProjectName = uilabel(info,'Text','—','FontWeight','bold', ...
                'Interpreter','none','Tag','project-name');
            pathRow = uigridlayout(info,[1 2]); pathRow.Padding = [0 0 0 0];
            pathRow.ColumnWidth = {'1x',48};
            obj.ProjectPath = uitextarea(pathRow,'Value',{'—'},'Editable','off', ...
                'Tag','project-path','Tooltip','Project folder');
            obj.CopyPath = uibutton(pathRow,'Text','Copy','Enable','off', ...
                'Tag','copy-project-path','Tooltip','Copy the project folder path', ...
                'ButtonPushedFcn',@(~,~)obj.copyProjectPath());
            obj.ProjectInfo = uitable(info,'Data',cell(0,2),'ColumnName',{}, ...
                'ColumnWidth',{105,'auto'},'RowName',{},'Tag','project-information', ...
                'ColumnEditable',[false false]);
            projectStatus = uilabel(nav,'Text','','Tag','projects-status');
            obj.ProjectProgress = detecdivui.Progress(nav,projectStatus,'projects-progress');
            canvas = uigridlayout(root,[2 1]);
            canvas.RowHeight = {'1x',60}; canvas.Padding = [0 0 0 0];
            obj.ImageGrid = uigridlayout(canvas,[1 1]); obj.ImageGrid.Padding = [0 0 0 0];
            obj.ImageGrid.ColumnSpacing = 8;
            obj.Axes = uiaxes(obj.ImageGrid,'Color',[0.07 0.09 0.11],'Tag','image-view');
            obj.ImageAxes = obj.Axes;
            obj.ImageMenu = uicontextmenu(obj.Figure);
            obj.ImageROIMenu = uimenu(obj.ImageMenu,'Text','Define ROIs...','Enable','off', ...
                'MenuSelectedFcn',@(~,~)obj.openROITool());
            uimenu(obj.ImageMenu,'Text','Edit Contours...','MenuSelectedFcn',@(~,~)obj.openContourTool());
            uimenu(obj.ImageMenu,'Text','Edit Tracks...','MenuSelectedFcn',@(~,~)obj.openTracksTool());
            obj.Axes.ContextMenu = obj.ImageMenu;
            obj.Axes.XTick = []; obj.Axes.YTick = [];
            obj.Axes.Toolbar.Visible = 'on';
            timeline = uigridlayout(canvas,[2 5]);
            timeline.RowHeight = {26,20};
            timeline.ColumnWidth = {32,32,80,'1x',90}; timeline.Padding = [0 0 0 0];
            obj.Previous = uibutton(timeline,'Text','‹','Enable','off', ...
                'Tag','previous-frame','Tooltip','Previous frame (Left Arrow)', ...
                'ButtonPushedFcn',@(~,~)obj.stepFrame(-1));
            obj.Next = uibutton(timeline,'Text','›','Enable','off', ...
                'Tag','next-frame','Tooltip','Next frame (Right Arrow)', ...
                'ButtonPushedFcn',@(~,~)obj.stepFrame(1));
            obj.Frame = uieditfield(timeline,'numeric','Value',1,'Limits',[1 Inf], ...
                'RoundFractionalValues','on','Enable','off','Tag','frame-number', ...
                'Tooltip','Frame number','ValueChangedFcn',@(~,~)obj.render());
            obj.FrameCount = uilabel(timeline,'Text','/ 1');
            obj.FrameCount.Layout.Column = 5;
            obj.TimeSlider = uislider(timeline,'Limits',[1 2],'Value',1, ...
                'MajorTicks',[],'MinorTicks',[],'Enable','off','Tag','time-slider', ...
                'Tooltip','Browse frames', ...
                'ValueChangedFcn',@(src,~)obj.setFrame(round(src.Value)));
            obj.TimeSlider.Layout.Row = 2; obj.TimeSlider.Layout.Column = [1 5];
            displayRoot = uigridlayout(obj.Host.widgetFigure('Display'),[1 1]);
            displayRoot.Padding = [0 0 0 0];
            obj.DisplayTabs = uitabgroup(displayRoot,'Tag','display-tabs');
            displayTab = uitab(obj.DisplayTabs,'Title','Display');
            tools = uigridlayout(displayTab,[13 1]);
            tools.RowSpacing = 6; tools.Scrollable = 'on';
            tools.RowHeight = {22,'1x',28,28,0,150,28,28,28,32,28,22,22};
            heading = uigridlayout(tools,[1 2]); heading.Padding = [0 0 0 0]; heading.ColumnWidth = {45,'1x'};
            uilabel(heading,'Text','Layers','FontWeight','bold');
            obj.OverlayChannels = uicheckbox(heading,'Text','Overlay channels','Value',true, ...
                'Enable','off','Tag','display-overlay','Tooltip','Combine channels when checked; show them side by side when unchecked. Masks appear on every panel.', ...
                'ValueChangedFcn',@(~,~)obj.editLayer('presentation'));
            obj.LayerTable = detecdivui.LayerTable(tools);
            obj.LayerTable.OnEdit = detecdivui.Callback(obj,'widgetEvent','layerEdit');
            active = uigridlayout(tools,[1 3]); active.Padding = [0 0 0 0]; active.ColumnSpacing = 4;
            active.ColumnWidth = {'1x',42,36};
            obj.Channels = uidropdown(active,'Items',{'—'},'ItemsData',1, ...
                'Enable','off','Tag','channels','Tooltip','Select the layer to adjust', ...
                'ValueChangedFcn',@(~,~)obj.render());
            uibutton(active,'Text','Solo','Tag','solo-layer','Tooltip','Show only the active layer', ...
                'ButtonPushedFcn',@(~,~)obj.soloLayer());
            uibutton(active,'Text','Fit','Tooltip','Fit the complete image to the viewport', ...
                'Tag','fit-image','ButtonPushedFcn',@(~,~)obj.resetView());
            obj.LayerKind = uidropdown(tools,'Items',{'Intensity','Labels'},'Enable','off', ...
                'Tag','layer-kind','Tooltip','Labels requires an integer label map', ...
                'ValueChangedFcn',@(~,~)obj.editLayer('kind'));
            obj.MaskOptions = uigridlayout(tools,[1 2]); obj.MaskOptions.Padding = [0 0 0 0];
            obj.MaskOptions.ColumnWidth = {'1x',54}; obj.MaskOptions.Visible = 'off';
            obj.MaskStyle = uidropdown(obj.MaskOptions,'Items',{'Fill','Contours','Fill + Contours'}, ...
                'Tag','mask-style','Tooltip','Label layer appearance', ...
                'ValueChangedFcn',@(~,~)obj.editLayer('mask-style'));
            obj.MaskWidth = uieditfield(obj.MaskOptions,'numeric','Value',1,'Limits',[0 Inf], ...
                'Tag','mask-width','Tooltip','Contour line width in points', ...
                'ValueChangedFcn',@(~,~)obj.editLayer('mask-style'));
            obj.Histogram = detecdivui.HistogramView(tools);
            obj.Histogram.OnEdit = detecdivui.Callback(obj,'widgetEvent','layerEdit');
            limits = uigridlayout(tools,[1 2]); limits.Padding = [0 0 0 0];
            limits.ColumnWidth = {'1x','1x'};
            obj.MinField = uieditfield(limits,'numeric','Value',0,'Enable','off', ...
                'Tag','contrast-min','Tooltip','Minimum intensity in source units', ...
                'ValueChangedFcn',@(~,~)obj.editLayer('limits'));
            obj.MaxField = uieditfield(limits,'numeric','Value',1,'Enable','off', ...
                'Tag','contrast-max','Tooltip','Maximum intensity in source units', ...
                'ValueChangedFcn',@(~,~)obj.editLayer('limits'));
            obj.ContrastSlider = uislider(tools,'range','Limits',[0 1],'Value',[0 1], ...
                'Enable','off','MajorTicks',[],'MinorTicks',[],'Tag','contrast-range', ...
                'Tooltip','Adjust contrast for the active layer', ...
                'ValueChangedFcn',@(~,~)obj.editLayer('range'));
            obj.AutoButton = uibutton(tools,'Text','Auto','Enable','off','Tag','auto-contrast', ...
                'Tooltip','Set contrast from this frame and keep it while browsing', ...
                'ButtonPushedFcn',@(~,~)obj.editLayer('auto'));
            opacity = uigridlayout(tools,[1 2]); opacity.Padding = [0 0 4 0]; opacity.ColumnWidth = {43,'1x'};
            uilabel(opacity,'Text','Weight');
            obj.OpacitySlider = uislider(opacity,'Limits',[0 1],'Value',1,'Enable','off', ...
                'MajorTicks',[0 1],'Tag','layer-opacity','Tooltip','Active layer opacity / intensity weight', ...
                'ValueChangedFcn',@(~,~)obj.editLayer('opacity'));
            color = uigridlayout(tools,[1 2]); color.Padding = [0 0 0 0];
            color.ColumnWidth = {34,'1x'};
            obj.ColorPicker = uicolorpicker(color,'Value',[1 1 1],'Enable','off','Tag','layer-color-picker', ...
                'Tooltip','Choose the active layer color', ...
                'ValueChangedFcn',@(~,~)obj.editLayer('picker'));
            obj.ColorField = uidropdown(color,'Items',{'1 1 1','1 0 0','0 1 0','0 0 1', ...
                'parula','turbo','gray','hot','jet','hsv'},'Editable','on','Enable','off','Value','1 1 1', ...
                'Tag','layer-color','Tooltip','RGB triplet or score colormap; Labels for label colors', ...
                'ValueChangedFcn',@(~,~)obj.editLayer('color'));
            obj.Overlays = uicheckbox(tools,'Text','ROI outlines','Value',true, ...
                'Enable','off','Tag','reference-zones', ...
                'Tooltip','Show reference ROI rectangles; positions are not drift-corrected', ...
                'ValueChangedFcn',@(src,~)obj.setOutlines(src.Value));
            displayStatus = uilabel(tools,'Text','','Tag','display-status');
            obj.DisplayProgress = detecdivui.Progress(tools,displayStatus,'display-progress');
            obj.Status = uilabel(root,'Text','Ready','Interpreter','none','Tag','status');
            obj.Progress = detecdivui.Progress(root,obj.Status,'image-progress');
            obj.KeyboardView = uihtml(root,'Tag','image-keyboard', ...
                'HTMLSource',fullfile(fileparts(mfilename('fullpath')),'imageKeyboard.html'), ...
                'DataChangedFcn',@(~,event)obj.imageKey(event.Data));
            obj.KeyboardView.Layout.Row = 4;
            root.RowHeight = {32,'1x',24,0};
            obj.Pipeline = detecdivui.PipelineWidget(obj.Host.widgetFigure('Pipeline'));
            obj.ensureDataWidget();
            obj.DisplayTabs.SelectionChangedFcn = @(~,~)obj.displayTabSelected();
            obj.rebindCallbacks();
            try
                obj.Host.start(visibility);
                if obj.Host.isWidgetVisible('Data'), obj.ensureDataWidget(); end
                if iscell(project)
                    for k = 1:numel(project), obj.addProject(project{k}); end
                elseif ~isempty(project)
                    for k = 1:numel(project), obj.addProject(project(k)); end
                end
            catch err
                delete(obj); rethrow(err);
            end
            obj.BrowserMenu.Checked = obj.onOff(obj.Host.isWidgetVisible('Projects'));
            obj.ToolsMenu.Checked = obj.onOff(obj.Host.isWidgetVisible('Display'));
            if ~isempty(obj.Host.LastLayoutError), obj.Status.Text = obj.Host.LastLayoutError; end
            obj.Host.syncMenus();
        end
        function addProject(obj,project)
            % Add or focus a project; existing projects stay in the tree.
            assert(isa(project,'shallow') && isscalar(project), ...
                'detecdivui:Project','A shallow project is required.');
            activity = obj.ProjectProgress.begin('Opening project...'); %#ok<NASGU>
            index = obj.findProject(project);
            if index == 0
                obj.Sessions{end+1} = detecdivui.Session(project);
                obj.DisplayModels{end+1} = detecdivui.LayerModel();
                obj.DisplayModels{end}.ReadOverride = detecdivui.Callback(obj,'maskPlane');
                obj.ViewStates{end+1} = struct('frame',1,'channel','','selectedROI',0);
                obj.ProjectSources{end+1} = '';
                index = numel(obj.Sessions);
                obj.rebuildTree();
            elseif ~isequal(obj.Sessions{index}.Project,project)
                session = obj.Sessions{index}; old = session.Project;
                position = session.Position; zone = session.Zone;
                obj.Pipeline.rebindProject(old,project);
                if obj.hasROIWidget(), obj.ROIs.forgetProject(old); end
                session.setProject(project);
                if position > 0 && position <= numel(project.fov)
                    session.selectPosition(position);
                    if zone > 0 && zone <= numel(project.fov(position).roi), session.selectZone(zone); end
                end
                obj.DisplayModels{index}.invalidate(); obj.rebuildTree();
            end
            obj.activate(index);
            obj.selectProjectNode();
            obj.refreshView(false);
        end
        function closeProject(obj,index)
            % Closing removes the UI reference only; scientific data is unchanged.
            if nargin < 2, index = obj.ActiveProject; end
            if index == 0, return; end
            validateattributes(index,{'numeric'},{'scalar','integer','positive','<=',numel(obj.Sessions)});
            if obj.hasMaskWidget() && ~obj.Masks.resolve(obj.Sessions{index}.Project, ...
                    detecdivui.Callback(obj,'closeProjectHandle',obj.Sessions{index}.Project)), return; end
            if obj.hasMaskWidget()
                if obj.ActiveProject == index, obj.closeContourTool(); obj.closeTracksTool(); end
                obj.Masks.forgetProject(obj.Sessions{index}.Project);
            end
            if obj.hasTracksWidget(), obj.Tracks.forgetProject(obj.Sessions{index}.Project); end
            if ~isempty(obj.AnnotationSelection) && isequal(obj.AnnotationSelection.project,obj.Sessions{index}.Project)
                obj.AnnotationSelection = [];
            end
            activity = obj.ProjectProgress.begin('Closing project...'); %#ok<NASGU>
            active = obj.Session;
            wasActive = index == obj.ActiveProject;
            obj.Pipeline.forgetProject(obj.Sessions{index}.Project);
            if obj.hasROIWidget(), obj.ROIs.forgetProject(obj.Sessions{index}.Project); end
            obj.storeView();
            obj.Sessions(index) = []; obj.ViewStates(index) = [];
            if numel(obj.ProjectSources) >= index, obj.ProjectSources(index) = []; end
            obj.DisplayModels(index) = [];
            remaining = find(cellfun(@(session)isequal(session,active),obj.Sessions),1);
            if ~wasActive
                obj.ActiveProject = remaining;
                obj.rebuildTree(); obj.selectCurrentNode(); obj.refreshProjectInfo();
                if ~isempty(obj.RenderKey)
                    obj.RenderKey = sprintf('%d:%d:%d',remaining,obj.Session.Position,obj.Session.Zone);
                end
                return;
            end
            obj.ActiveProject = 0;
            obj.Session = detecdivui.Session();
            obj.DisplayModel = [];
            obj.rebuildTree();
            if ~isempty(obj.Sessions)
                if isempty(remaining), remaining = min(index,numel(obj.Sessions)); end
                obj.activate(remaining); obj.selectProjectNode();
            end
            obj.refreshView(false);
        end
        function project = openProject(obj,path)
            project = [];
            try
                if nargin < 2
                    [file,folder] = uigetfile( ...
                        {'*.json;*.mat','DetecDiv Projects (*.json, *.mat)'},'Open Project');
                    if isequal(file,0), return; end
                    path = fullfile(folder,file);
                end
                activity = obj.ProjectProgress.begin('Loading project...'); %#ok<NASGU>
                path = detecdivui.RecentProjects.resolve(path);
                [project,message] = shallowLoad(path,'ProgressCallback',@(payload)obj.ProjectProgress.report(payload));
                assert(~isempty(project),'detecdivui:ProjectLoad','Could not open project. %s',char(string(message)));
                obj.addProject(project); obj.ProjectSources{obj.ActiveProject} = path; obj.rememberProject(path);
            catch err
                project = []; obj.Status.Text = err.message; obj.Status.Tooltip = err.message;
            end
        end
        function classifier = openClassifier(obj,path)
            classifier = [];
            try
                if nargin < 2
                    [file,folder] = uigetfile({'*classification*.mat;*.mat','DetecDiv Classifiers (*.mat)'},'Open Classifier');
                    if isequal(file,0), return; end
                    path = fullfile(folder,file);
                end
                activity = obj.ProjectProgress.begin('Loading classifier...'); %#ok<NASGU>
                [classifier,message] = classiLoad(path);
                assert(isa(classifier,'classi') && isscalar(classifier) && isvalid(classifier), ...
                    'detecdivui:ClassifierLoad','Could not open this classifier. %s',char(string(message)));
                obj.registerLoadedObject(classifier,'classi');
                obj.Status.Text = 'Classifier opened';
            catch err
                classifier = []; obj.Status.Text = err.message; obj.Status.Tooltip = err.message;
            end
        end
        function template = openPipeline(obj,path)
            if nargin < 2, template = obj.Pipeline.openTemplate();
            else, template = obj.Pipeline.openTemplate(path); end
            if ~isempty(template), obj.Host.focusWidget('Pipeline'); end
        end
        function ok = saveProject(obj)
            ok = false; if obj.ActiveProject == 0, return; end
            activity = obj.ProjectProgress.begin('Saving project metadata...'); %#ok<NASGU>
            try
                project = obj.Session.Project;
                assert(strlength(string(project.io.path)) > 0 && strlength(string(project.io.file)) > 0, ...
                    'detecdivui:ProjectPath','Set a project name and folder before saving.');
                shallowSave(project,'shallowObj');
                obj.Status.Text = 'Project saved'; ok = true;
                path = fullfile(project.io.path,[project.io.file '.json']);
                obj.ProjectSources{obj.ActiveProject} = path; obj.rememberProject(path);
            catch err
                obj.Status.Text = err.message;
            end
            obj.Status.Tooltip = obj.Status.Text;
        end
        function loadCurrentImage(obj)
            if obj.Session.Position == 0, return; end
            obj.selectCurrentNode();
            obj.DisplayModel.invalidate(); obj.refreshView(true);
        end
        function report = relinkRawData(obj,root)
            report = [];
            if obj.ActiveProject == 0, return; end
            try
                if nargin < 2
                    [root,picked] = detecdiv_paths_prompt_root(string(pwd),"","PROJECT");
                    if ~picked, obj.Status.Text = 'Relink cancelled'; return; end
                end
                retry = obj.ImageRequested && obj.MissingRaw;
                activity = obj.ProjectProgress.begin('Relinking raw data...'); %#ok<NASGU>
                report = detecdiv_paths_relink_project(obj.Session.Project,root);
                obj.DisplayModel.invalidate();
                if isempty(report)
                    obj.Status.Text = 'No raw paths updated';
                elseif ~any([report.ok])
                    obj.Status.Text = 'No matching raw paths found. Choose the dataset or a Pos folder.';
                elseif retry && any([report.ok])
                    obj.refreshView(true);
                else
                    obj.Status.Text = sprintf('Raw data: %d/%d paths linked',sum([report.ok]),numel(report));
                end
                obj.Status.Tooltip = obj.Status.Text;
            catch err
                obj.Status.Text = err.message; obj.Status.Tooltip = err.message;
            end
        end
        function figure = widgetFigure(obj,name)
            figure = obj.Host.widgetFigure(name);
        end
        function rebindCallbacks(obj)
            % Can repair an already-open viewer without changing project data.
            obj.Pipeline.OnStatus = detecdivui.Callback(obj,'widgetEvent','status');
            obj.Pipeline.OnChanged = detecdivui.Callback(obj,'widgetEvent','pipelineChanged');
            obj.Pipeline.OnDefineROIs = detecdivui.Callback(obj,'widgetEvent','defineROIs');
            obj.Pipeline.OnProjectUpdated = detecdivui.Callback(obj,'addProject');
            obj.Pipeline.OnTemplateOpened = detecdivui.Callback(obj,'widgetEvent','templateOpened');
            obj.Pipeline.rebindCallbacks();
            obj.ProjectProgress.Route = detecdivui.Callback(obj,'widgetEvent','progressOwner','Projects');
            obj.Pipeline.Progress.Route = detecdivui.Callback(obj,'widgetEvent','progressOwner','Pipeline');
            obj.Progress.Route = detecdivui.Callback(obj,'widgetEvent','progressOwner','Image');
            obj.DisplayProgress.Route = detecdivui.Callback(obj,'widgetEvent','progressOwner','Display');
            obj.Host.OnActivity = detecdivui.Callback(obj.Progress,'begin');
            obj.Host.OnClosed = detecdivui.Callback(obj,'delete');
            obj.Host.OnCanClose = detecdivui.Callback(obj,'canClose');
            if isa(obj.LayerTable,'detecdivui.LayerTable')
                obj.LayerTable.OnEdit = detecdivui.Callback(obj,'widgetEvent','layerEdit');
                obj.Histogram.OnEdit = detecdivui.Callback(obj,'widgetEvent','layerEdit');
            end
            if obj.hasROIWidget()
                obj.ROIs.Progress.Route = detecdivui.Callback(obj,'widgetEvent','progressOwner','Display');
                obj.ROIs.OnDismiss = detecdivui.Callback(obj,'closeROITool');
            end
        end
        function result = widgetEvent(obj,action,varargin)
            result = [];
            if obj.Closing, return; end
            switch action
                case 'status'
                    message = varargin{1}; obj.Status.Text = message; obj.Status.Tooltip = message;
                case 'pipelineChanged', obj.syncPipelineMenu();
                case 'defineROIs', obj.openROITool(varargin{:});
                case 'templateOpened', obj.registerLoadedObject(varargin{1},'pipeline');
                case 'progressOwner', result = obj.progressOwner(varargin{1});
                case 'layerEdit', obj.editLayerRow(varargin{:});
                case 'imageLayer', obj.selectImageLayer(varargin{:});
                case 'zone'
                    if varargin{3} == obj.ImageRevision && ~obj.DrawingROI
                        if varargin{2} > 0, obj.Channels.Value = varargin{2}; end
                        obj.openZone(varargin{1});
                    end
                otherwise, error('detecdivui:WidgetEvent','Unknown viewer widget event.');
            end
        end
        function openROITool(obj,project,node,callback)
            obj.closeTracksTool();
            obj.closeContourTool();
            if nargin >= 2 && ~isempty(project) && ~isequal(project,obj.Session.Project), obj.addProject(project); end
            if obj.Session.Position == 0 && nargin >= 3 && ~isempty(node) && ...
                    isfield(node.params,'fovIndex') && ~isempty(node.params.fovIndex)
                obj.Session.selectPosition(node.params.fovIndex(1)); obj.refreshView(false);
            end
            if obj.Session.Position == 0
                obj.widgetEvent('status','Select a FOV to define ROIs'); return;
            end
            obj.ensureROIWidget();
            if nargin >= 3 && ~isempty(node)
                obj.ROIs.bind(node,callback);
            else
                obj.ROIs.standalone();
            end
            obj.ROIsTab.Parent = obj.DisplayTabs;
            obj.DisplayTabs.SelectedTab = obj.ROIsTab;
            obj.ROIs.setActive(true);
            obj.refreshKeyboard();
            obj.Host.focusWidget('Display'); obj.Host.show();
        end
        function closeROITool(obj)
            if obj.hasROIWidget(), obj.ROIs.setActive(false); end
            if ~isempty(obj.ROIsTab) && isvalid(obj.ROIsTab)
                % Detach rather than delete: retain controls and the pending draft.
                obj.ROIsTab.Parent = [];
            end
            obj.refreshKeyboard();
        end
        function ax = roiAxes(obj)
            ax = obj.Axes;
        end
        function openContourTool(obj)
            try
                obj.closeTracksTool();
                scope = obj.DisplayProgress.begin('Opening contour editor...'); %#ok<NASGU>
                c = obj.contourContext();
                assert(~isempty(c.roi) && ~isempty(c.masks),'detecdivui:ContourContext', ...
                    'Select an extracted ROI and a label mask layer first.');
                obj.closeROITool();
                obj.ensureAnnotationDrafts();
                obj.MasksTab.Parent = obj.DisplayTabs; obj.DisplayTabs.SelectedTab = obj.MasksTab;
                obj.Masks.setActive(true); obj.refreshKeyboard();
                obj.Host.focusWidget('Display'); obj.Host.show();
            catch err, obj.closeContourTool(); obj.widgetEvent('status',err.message);
            end
        end
        function closeContourTool(obj)
            if obj.hasMaskWidget(), obj.Masks.setActive(false); end
            if ~isempty(obj.MasksTab) && isvalid(obj.MasksTab), obj.MasksTab.Parent = []; end
            obj.refreshKeyboard();
        end
        function openTracksTool(obj)
            try
                scope = obj.DisplayProgress.begin('Opening track editor...'); %#ok<NASGU>
                c = obj.contourContext();
                assert(~isempty(c.roi) && ~isempty(c.masks),'detecdivui:TrackContext', ...
                    'Select an extracted ROI with a loaded annotation mask.');
                obj.closeROITool(); obj.closeContourTool(); obj.ensureAnnotationDrafts();
                if ~obj.hasTracksWidget()
                    obj.TracksTab = uitab(obj.DisplayTabs,'Title','Tracks','Tag','tracks-tab');
                    obj.Tracks = detecdivui.TracksWidget(obj.TracksTab,obj);
                    obj.Tracks.Progress.Route = detecdivui.Callback(obj,'widgetEvent','progressOwner','Display');
                end
                obj.TracksTab.Parent = obj.DisplayTabs; obj.DisplayTabs.SelectedTab = obj.TracksTab;
                obj.Tracks.setActive(true); obj.refreshKeyboard();
                obj.Host.focusWidget('Display'); obj.Host.show();
            catch err, obj.closeTracksTool(); obj.widgetEvent('status',err.message);
            end
        end
        function closeTracksTool(obj)
            if obj.hasTracksWidget(), obj.Tracks.setActive(false); end
            if ~isempty(obj.TracksTab) && isvalid(obj.TracksTab), obj.TracksTab.Parent = []; end
            obj.refreshKeyboard();
        end
        function draft = annotationDraft(obj,channel)
            obj.ensureAnnotationDrafts(); c = obj.contourContext();
            assert(~isempty(c.roi),'detecdivui:AnnotationROI','Select an extracted ROI.');
            draft = obj.Masks.draftFor(c.roi,channel,c.project);
        end
        function rememberAnnotation(obj,source,channel,frame,label,tool)
            obj.AnnotationSelection = struct('roi',source,'project',obj.Session.Project, ...
                'channel',channel,'frame',frame,'label',label,'tool',tool);
        end
        function selection = selectedAnnotation(obj)
            selection = obj.AnnotationSelection; c = obj.contourContext();
            if isempty(selection) || ~isequal(selection.roi,c.roi) || selection.frame ~= c.frame, selection = []; end
        end
        function context = contourContext(obj)
            context = struct('roi',[],'frame',obj.Frame.Value,'project',obj.Session.Project,'masks',{{}});
            if obj.Session.Zone == 0 || ~obj.ImageRequested, return; end
            context.roi = obj.Session.Project.fov(obj.Session.Position).roi(obj.Session.Zone);
            if isempty(context.roi.image), context.roi = []; return; end
            layers = obj.DisplayModel.Layers;
            context.masks = {layers(strcmp({layers.kind},'Labels')).name};
            context.masks = context.masks(cellfun(@(name)detecdivui.MaskDraft.isLabel(context.roi,name),context.masks));
        end
        function openData(obj)
            obj.ensureDataWidget(); obj.Data.setContext(); obj.Host.openData();
        end
        function planWorkflow(obj,intent)
            if nargin<2, intent = ''; end
            obj.Host.focusWidget('Pipeline'); obj.Pipeline.openPlanner(intent);
        end
        function toggleData(obj)
            if obj.Host.isWidgetVisible('Data'), obj.Host.setWidgetVisible('Data',false);
            else, obj.openData(); end
        end
        function frame = annotationFrame(obj)
            frame = obj.Frame.Value;
        end
        function count = annotationFrameCount(obj)
            count = 0;
            if obj.Session.Zone > 0 && obj.ImageRequested
                source = obj.Session.Project.fov(obj.Session.Position).roi(obj.Session.Zone);
                if ~isempty(source.image), count = size(source.image,4); end
            end
        end
        function navigateDataFrame(obj,source,frame)
            if obj.DrawingROI || obj.annotationFrameCount() == 0, return; end
            current = obj.Session.Project.fov(obj.Session.Position).roi(obj.Session.Zone);
            if isequal(source,current) && isscalar(frame) && isfinite(frame), obj.setFrame(frame); end
        end
        function yes = contourGestureActive(obj)
            yes = obj.DrawingROI;
        end
        function contourChanged(obj)
            for k = 1:numel(obj.DisplayModels), obj.DisplayModels{k}.invalidate(); end
            obj.SaveMasksMenu.Enable = obj.onOff(obj.hasMaskWidget() && obj.Masks.dirty());
            obj.render(); obj.refreshKeyboard();
        end
        function contourOpacity(obj,delta,channel)
            c = obj.contourContext(); if isempty(c.masks), return; end
            index = find(strcmp({obj.DisplayModel.Layers.name},channel),1);
            if isempty(index), return; end
            value = obj.DisplayModel.Layers(index).opacity;
            obj.DisplayModel.setOpacity(index,min(1,max(0,value+delta))); obj.render();
        end
        function plane = maskPlane(obj,session,index,frame,plane)
            if obj.hasMaskWidget(), plane = obj.Masks.override(session,index,frame,plane); end
        end
        function yes = canClose(obj)
            yes = true;
            if obj.hasMaskWidget() && obj.Masks.dirty()
                yes = obj.Masks.resolve([],detecdivui.Callback(obj,'close'));
            end
        end
        function closeProjectHandle(obj,project)
            index = find(cellfun(@(session)isequal(session.Project,project),obj.Sessions),1);
            if ~isempty(index), obj.closeProject(index); end
        end
        function close(obj)
            if obj.canClose(), delete(obj); end
        end
        function scope = beginROIGesture(obj)
            obj.DrawingROI = true;
            obj.refreshKeyboard();
            scope = onCleanup(@()obj.finishROIGesture());
        end
        function ax = prepareROIView(obj)
            assert(obj.Session.Position > 0,'detecdivui:ROIFov','Select a FOV first.');
            if obj.Session.Zone > 0, obj.openZone(0);
            elseif ~obj.ImageRequested, obj.loadCurrentImage(); end
            assert(~isempty(findall(obj.Axes,'Type','image')),'detecdivui:RawImage','Load the raw image or relink its source first.');
            if obj.isSeparated() && isstruct(obj.Axes.UserData) && obj.Axes.UserData.layer > 0 && ...
                    obj.Channels.Value ~= obj.Axes.UserData.layer
                obj.Channels.Value = obj.Axes.UserData.layer; obj.render();
            end
            ax = obj.Axes;
        end
        function [plane,frame,channel] = roiSource(obj)
            obj.prepareROIView(); frame = obj.Frame.Value; channel = obj.Channels.Value;
            plane = obj.DisplayModel.read(channel,frame);
        end
        function roisChanged(obj)
            obj.rebuildTree(); obj.selectCurrentNode(); obj.refreshProjectInfo(); obj.render();
        end
        function showRoiPreview(obj,detections)
            delete(findall(obj.Axes,'Tag','roi-preview'));
            hold(obj.Axes,'on');
            for k = 1:numel(detections)
                if ~isfield(detections(k),'scaled'), continue; end
                rects = detections(k).scaled;
                for j = 1:size(rects,1)
                    rectangle(obj.Axes,'Position',rects(j,1:4),'EdgeColor',[.7 .3 1],'LineWidth',1.2,'Tag','roi-preview');
                end
            end
            hold(obj.Axes,'off');
        end
        function refreshWorkspace(obj)
            % Import live handles; never load files or alter workspace variables.
            activity = obj.ProjectProgress.begin('Scanning workspace...'); %#ok<NASGU>
            entries = detecdivui.workspaceObjects();
            active = obj.Session.Project;
            obj.WorkspaceObjects = obj.mergeLoadedObjects(entries(~strcmp({entries.kind},'shallow')));
            obj.Pipeline.importWorkspace(entries);
            projects = find(strcmp({entries.kind},'shallow')); count = 0;
            for k = projects
                count = count+1;
                obj.ProjectProgress.update(sprintf('Opening project %d / %d',count,numel(projects)),(count-1)/numel(projects));
                obj.addProject(entries(k).object);
            end
            if ~isempty(active)
                index = obj.findProject(active);
                if index > 0, obj.activate(index); end
            end
            obj.rebuildTree(); obj.selectProjectNode(); obj.refreshView(false);
            obj.Status.Text = 'Workspace refreshed';
        end
        function delete(obj)
            if obj.Closing, return; end
            if obj.hasMaskWidget() && obj.Masks.dirty(), obj.Masks.recover(); end
            obj.Closing = true;
            if ~isempty(obj.Data) && isvalid(obj.Data), delete(obj.Data); end
            if obj.hasTracksWidget(), delete(obj.Tracks); end
            if ~isempty(obj.TracksTab) && isvalid(obj.TracksTab), delete(obj.TracksTab); end
            if obj.hasMaskWidget(), delete(obj.Masks); end
            if ~isempty(obj.MasksTab) && isvalid(obj.MasksTab), delete(obj.MasksTab); end
            if obj.hasROIWidget(), delete(obj.ROIs); end
            if ~isempty(obj.ShortcutFigure) && isvalid(obj.ShortcutFigure), delete(obj.ShortcutFigure); end
            if ~isempty(obj.ROIsTab) && isvalid(obj.ROIsTab), delete(obj.ROIsTab); end
            if ~isempty(obj.Pipeline) && isvalid(obj.Pipeline), delete(obj.Pipeline); end
            if ~isempty(obj.Host) && isvalid(obj.Host), obj.Host.OnActivity = []; end
            if ~isempty(obj.Host) && isvalid(obj.Host), delete(obj.Host); end
        end
    end
    methods (Access = private)
        function ensureDataWidget(obj)
            if ~isempty(obj.Data) && isvalid(obj.Data), return; end
            obj.Data = detecdivui.DataWidget(obj.Host.widgetFigure('Data'),obj);
            obj.Data.Progress.Route = detecdivui.Callback(obj,'widgetEvent','progressOwner','Data');
        end
        function ensureAnnotationDrafts(obj)
            if obj.hasMaskWidget(), return; end
            obj.MasksTab = uitab(obj.DisplayTabs,'Title','Contours','Tag','mask-tab');
            obj.Masks = detecdivui.MaskWidget(obj.MasksTab,obj);
            obj.Masks.Progress.Route = detecdivui.Callback(obj,'widgetEvent','progressOwner','Display');
            obj.MasksTab.Parent = [];
        end
        function yes = hasTracksWidget(obj)
            yes = isa(obj.Tracks,'detecdivui.TracksWidget') && isscalar(obj.Tracks) && isvalid(obj.Tracks);
        end
        function yes = hasMaskWidget(obj)
            yes = isa(obj.Masks,'detecdivui.MaskWidget') && isscalar(obj.Masks) && isvalid(obj.Masks);
        end
        function registerLoadedObject(obj,item,kind)
            entry = struct('object',item,'variables',{{}},'kind',kind);
            keep = true(1,numel(obj.LoadedObjects));
            for k = 1:numel(obj.LoadedObjects)
                keep(k) = isvalid(obj.LoadedObjects(k).object) && ...
                    ~obj.sameTool(obj.LoadedObjects(k).object,item);
            end
            obj.LoadedObjects = [obj.LoadedObjects(keep) entry];
            obj.WorkspaceObjects = obj.mergeLoadedObjects(obj.WorkspaceObjects);
            obj.rebuildTree();
            index = find(arrayfun(@(e)isequal(e.object,item),obj.WorkspaceObjects),1);
            nodes = findall(obj.Tree,'Tag','workspace-object');
            for node = nodes'
                if node.UserData.object == index
                    obj.Tree.SelectedNodes = node; obj.showWorkspaceObject(index); break;
                end
            end
        end
        function entries = mergeLoadedObjects(obj,entries)
            obj.LoadedObjects = obj.LoadedObjects(arrayfun(@(e)isvalid(e.object),obj.LoadedObjects));
            entries = entries(arrayfun(@(e)isvalid(e.object),entries));
            for loaded = obj.LoadedObjects
                keep = ~arrayfun(@(e)obj.sameTool(e.object,loaded.object),entries);
                entries = [entries(keep) loaded];
            end
        end
        function same = sameTool(~,a,b)
            same = isequal(a,b);
            if same || ~strcmp(class(a),class(b)) || isempty(a.path) || isempty(b.path), return; end
            pathA = regexprep(strrep(char(a.path),'\','/'),'/+$','');
            pathB = regexprep(strrep(char(b.path),'\','/'),'/+$','');
            same = strcmpi(pathA,pathB);
            if ~isa(a,'pipeline'), same = same && strcmp(a.strid,b.strid); end
        end
        function rememberProject(obj,path)
            try
                if isempty(obj.RecentProjects), obj.RecentProjects = detecdivui.RecentProjects(); end
                obj.RecentProjects.remember(path); obj.refreshRecentMenu();
            catch err
                obj.Status.Text = ['Project opened/saved; recent history was not saved: ' err.message];
                obj.Status.Tooltip = obj.Status.Text;
            end
        end
        function openRecentProject(obj,path)
            % Focus an open project without reloading over unsaved data.
            for k = 1:numel(obj.Sessions)
                project = obj.Sessions{k}.Project; source = '';
                if numel(obj.ProjectSources) >= k, source = obj.ProjectSources{k}; end
                if isempty(source) && ~isempty(project.io.path) && ~isempty(project.io.file)
                    source = fullfile(project.io.path,[project.io.file '.json']);
                end
                if ~isempty(source) && detecdivui.RecentProjects.samePath(source,path)
                    if obj.ActiveProject ~= k, obj.activate(k); obj.refreshView(false); end
                    obj.selectCurrentNode(); obj.refreshProjectInfo(); obj.rememberProject(path); return;
                end
            end
            obj.openProject(path);
        end
        function clearRecentProjects(obj)
            try
                obj.RecentProjects.clear(); obj.refreshRecentMenu();
                obj.Status.Text = 'Recent projects cleared';
            catch err
                obj.Status.Text = err.message; obj.Status.Tooltip = err.message;
            end
        end
        function refreshRecentMenu(obj)
            if isempty(obj.RecentMenu), return; end
            paths = obj.RecentProjects.Paths;
            for k = 1:numel(obj.RecentCommands)
                command = obj.RecentCommands{k}; command.Enable = 'off'; command.MenuSelectedFcn = [];
                if k <= numel(paths)
                    path = char(paths(k)); [folder,name,extension] = fileparts(path);
                    command.Text = sprintf('%d %s%s — %s',k,name,extension,folder);
                    command.Enable = 'on'; command.MenuSelectedFcn = @(~,~)obj.openRecentProject(path);
                end
            end
            obj.RecentMenu.Children = [obj.RecentCommands(1:numel(paths)) {obj.ClearRecentCommand}];
            obj.RecentMenu.Enable = obj.onOff(~isempty(paths)); obj.Host.syncMenus();
        end
        function yes = hasROIWidget(obj)
            yes = isa(obj.ROIs,'detecdivui.ROIWidget') && isscalar(obj.ROIs) && isvalid(obj.ROIs);
        end
        function ensureROIWidget(obj)
            if obj.hasROIWidget(), return; end
            if isempty(obj.ROIsTab) || ~isvalid(obj.ROIsTab)
                obj.ROIsTab = uitab(obj.DisplayTabs,'Title','Define ROIs','Tag','roi-tab');
            end
            % A deleted assistant may have left its controls in the tab.
            delete(obj.ROIsTab.Children);
            obj.ROIs = detecdivui.ROIWidget(obj.ROIsTab,obj);
            obj.ROIs.Progress.Route = detecdivui.Callback(obj,'widgetEvent','progressOwner','Display');
            obj.ROIs.OnDismiss = detecdivui.Callback(obj,'closeROITool');
            obj.ROIs.setContext(obj.Session); obj.ROIs.onRender();
        end
        function displayTabSelected(obj)
            if obj.Closing, return; end
            if isequal(obj.DisplayTabs.SelectedTab,obj.ROIsTab)
                obj.ensureROIWidget();
            end
            if obj.hasROIWidget()
                obj.ROIs.setActive(isequal(obj.DisplayTabs.SelectedTab,obj.ROIsTab));
            end
            maskActive = obj.hasMaskWidget() && isequal(obj.DisplayTabs.SelectedTab,obj.MasksTab);
            tracksActive = obj.hasTracksWidget() && isequal(obj.DisplayTabs.SelectedTab,obj.TracksTab);
            if obj.hasMaskWidget() && ~maskActive, obj.Masks.setActive(false); end
            if obj.hasTracksWidget() && ~tracksActive, obj.Tracks.setActive(false); end
            if maskActive, obj.Masks.setActive(true); end
            if tracksActive, obj.Tracks.setActive(true); end
            obj.refreshKeyboard();
        end
        function finishROIGesture(obj)
            if isvalid(obj), obj.DrawingROI = false; obj.refreshKeyboard(); end
        end
        function progress = progressOwner(obj,widget)
            progress = obj.Progress;
            if obj.Closing, return; end
            owners = struct('Image',obj.Progress,'Projects',obj.ProjectProgress, ...
                'Pipeline',obj.Pipeline.Progress,'Display',obj.DisplayProgress);
            owners.Data = obj.Progress;
            if ~isempty(obj.Data) && isvalid(obj.Data), owners.Data = obj.Data.Progress; end
            if obj.hasROIWidget() && isequal(obj.DisplayTabs.SelectedTab,obj.ROIsTab)
                owners.Display = obj.ROIs.Progress;
            end
            if obj.hasMaskWidget() && obj.Masks.Active, owners.Display = obj.Masks.Progress; end
            if obj.hasTracksWidget() && obj.Tracks.Active, owners.Display = obj.Tracks.Progress; end
            visible = obj.Host.isWidgetVisible(widget);
            % A document can be visible but covered by another tab. Use the
            % main view unless Pipeline/Display actually owns the focus.
            if ismember(widget,{'Pipeline','Display','Data'})
                selected = obj.Host.App.SelectedChild;
                visible = visible && isstruct(selected) && isscalar(selected) && ...
                    isfield(selected,'tag') && strcmpi(selected.tag,widget);
            end
            if visible
                progress = owners.(widget); return;
            end
            if obj.Host.isWidgetVisible('Image'), return; end
            selected = obj.Host.App.SelectedChild;
            if isstruct(selected) && isscalar(selected) && isfield(selected,'tag')
                names = fieldnames(owners); index = find(strcmpi(names,selected.tag),1);
                if ~isempty(index) && obj.Host.isWidgetVisible(names{index})
                    progress = owners.(names{index}); return;
                end
            end
            for name = {'Image','Projects','Pipeline','Display','Data'}
                if obj.Host.isWidgetVisible(name{1})
                    progress = owners.(name{1}); return;
                end
            end
        end
        function createMenus(obj)
            file = obj.Host.menu([],'File');
            obj.Host.menu(file,'Open Project...','Accelerator','O', ...
                'MenuSelectedFcn',@(~,~)obj.openProject());
            obj.RecentMenu = obj.Host.menu(file,'Recent Projects','Enable','off');
            for k = 1:10
                obj.RecentCommands{k} = obj.Host.menu(obj.RecentMenu,'','Enable','off');
            end
            obj.ClearRecentCommand = obj.Host.menu(obj.RecentMenu,'Clear Recent Projects', ...
                'Separator','on','MenuSelectedFcn',@(~,~)obj.clearRecentProjects());
            obj.refreshRecentMenu();
            obj.Host.menu(file,'Open Classifier...','MenuSelectedFcn',@(~,~)obj.openClassifier());
            obj.SaveProjectMenu = obj.Host.menu(file,'Save Project','Accelerator','S','Enable','off', ...
                'MenuSelectedFcn',@(~,~)obj.saveProject());
            obj.SaveMasksMenu = obj.Host.menu(file,'Save Masks','Enable','off', ...
                'MenuSelectedFcn',@(~,~)obj.Masks.saveAll());
            obj.Host.menu(file,'Open Pipeline...','MenuSelectedFcn',@(~,~)obj.openPipeline());
            obj.SavePipelineMenu = obj.Host.menu(file,'Save Pipeline','Enable','off', ...
                'MenuSelectedFcn',@(~,~)obj.Pipeline.saveTemplate());
            obj.CloseMenu = obj.Host.menu(file,'Close Project','Accelerator','W', ...
                'Enable','off','MenuSelectedFcn',@(~,~)obj.closeProject());
            obj.RelinkMenu = obj.Host.menu(file,'Relink Raw Data...','Enable','off', ...
                'MenuSelectedFcn',@(~,~)obj.relinkRawData());
            obj.Host.menu(file,'Exit','Separator','on', ...
                'MenuSelectedFcn',@(~,~)obj.close());
            edit = obj.Host.menu([],'Edit');
            obj.CopyMenu = obj.Host.menu(edit,'Copy Image','Accelerator','C', ...
                'Enable','off','MenuSelectedFcn',@(~,~)obj.copyImage());
            obj.DefineROIMenu = obj.Host.menu(edit,'Define ROIs...','Enable','off', ...
                'MenuSelectedFcn',@(~,~)obj.openROITool());
            obj.EditContoursMenu = obj.Host.menu(edit,'Edit Contours...','Enable','off', ...
                'MenuSelectedFcn',@(~,~)obj.openContourTool());
            obj.EditTracksMenu = obj.Host.menu(edit,'Edit Tracks...','Enable','off', ...
                'MenuSelectedFcn',@(~,~)obj.openTracksTool());
            obj.Host.menu(edit,'Plan Workflow...','Separator','on', ...
                'MenuSelectedFcn',@(~,~)obj.planWorkflow());
            view = obj.Host.menu([],'View');
            obj.BrowserMenu = obj.Host.widgetMenu(view,'Projects');
            obj.Host.widgetMenu(view,'Image');
            obj.ToolsMenu = obj.Host.widgetMenu(view,'Display');
            obj.Host.widgetMenu(view,'Pipeline');
            dataMenu = obj.Host.widgetMenu(view,'Data');
            dataMenu.MenuSelectedFcn = @(~,~)obj.toggleData();
            obj.OverlayMenu = obj.Host.menu(view,'ROI Outlines','Checked','on','Separator','on', ...
                'MenuSelectedFcn',@(~,~)obj.setOutlines(~obj.Overlays.Value));
            obj.Host.menu(view,'Fit Image','MenuSelectedFcn',@(~,~)obj.resetView());
            obj.Host.menu(view,'Reload Image','Accelerator','R', ...
                'MenuSelectedFcn',@(~,~)obj.reloadImage());
            obj.Host.menu(view,'Refresh Workspace', ...
                'MenuSelectedFcn',@(~,~)obj.refreshWorkspace());
            obj.Host.menu(view,'Expand Projects','Separator','on', ...
                'MenuSelectedFcn',@(~,~)expand(obj.Tree,'all'));
            obj.Host.menu(view,'Collapse Projects', ...
                'MenuSelectedFcn',@(~,~)collapse(obj.Tree,'all'));
            obj.Host.addDockMenus(view);
            navigate = obj.Host.menu([],'Navigate');
            obj.ParentMenu = obj.Host.menu(navigate,'Parent FOV','Enable','off', ...
                'MenuSelectedFcn',@(~,~)obj.returnToPosition());
            obj.PreviousMenu = obj.Host.menu(navigate,'Previous Frame','Enable','off', ...
                'Shortcut','Left Arrow', ...
                'MenuSelectedFcn',@(~,~)obj.stepFrame(-1));
            obj.NextMenu = obj.Host.menu(navigate,'Next Frame','Enable','off', ...
                'Shortcut','Right Arrow', ...
                'MenuSelectedFcn',@(~,~)obj.stepFrame(1));
            obj.JumpBackMenu = obj.Host.menu(navigate,'Back 10 Frames','Enable','off', ...
                'Shortcut',upper(obj.JumpKeys{1}),'MenuSelectedFcn',@(~,~)obj.stepFrame(-10));
            obj.JumpForwardMenu = obj.Host.menu(navigate,'Forward 10 Frames','Enable','off', ...
                'Shortcut',upper(obj.JumpKeys{2}),'MenuSelectedFcn',@(~,~)obj.stepFrame(10));
            helpMenu = obj.Host.menu([],'Help');
            obj.Host.menu(helpMenu,'Keyboard Shortcuts...', ...
                'MenuSelectedFcn',@(~,~)obj.showShortcuts());
            obj.Host.menu(helpMenu,'About DetecDiv', ...
                'MenuSelectedFcn',@(~,~)uialert(obj.Figure, ...
                    'DetecDiv — microscopy image analysis','About DetecDiv','Icon','info'));
        end
        function syncPipelineMenu(obj)
            template = obj.Pipeline.Template;
            obj.SavePipelineMenu.Enable = obj.onOff(~isempty(template) && isvalid(template) && ~isempty(template.path));
            obj.Host.syncMenus();
        end
        function index = findProject(obj,project)
            index = 0;
            for k = 1:numel(obj.Sessions)
                other = obj.Sessions{k}.Project;
                sameId = strlength(string(project.projectId)) > 0 && strcmp(project.projectId,other.projectId);
                samePath = strlength(string(project.io.path)) > 0 && strlength(string(project.io.file)) > 0 && ...
                    strcmpi(fullfile(project.io.path,project.io.file),fullfile(other.io.path,other.io.file));
                if isequal(project,other) || sameId || samePath, index = k; return; end
            end
        end
        function rebuildTree(obj)
            % Flush queued expand/select commands before removing their nodes.
            % R2026a's native TreeNodeManager can otherwise retain stale indices.
            obj.Tree.SelectedNodes = [];
            drawnow;
            % Build away from the live peer. R2026a can fail inside HG set
            % when native tree updates interleave with a large node batch.
            parent = obj.Tree.Parent;
            restoreParent = onCleanup(@()obj.restoreBrowserParent(parent));
            obj.Tree.Parent = [];
            drawnow;
            delete(obj.Tree.Children);
            for k = 1:numel(obj.Sessions)
                session = obj.Sessions{k};
                projectNode = obj.browserNode(obj.Tree,obj.projectName(session.Project), ...
                    struct('project',k,'fov',0,'roi',0),'project-node');
                [labels, indices] = session.positionItems();
                for j = 1:numel(indices)
                    fovNode = obj.browserNode(projectNode,labels{j}, ...
                        struct('project',k,'fov',indices(j),'roi',0),'fov-node');
                    % Inspect the hierarchy without changing session selection.
                    rois = session.Project.fov(indices(j)).roi;
                    for r = 1:numel(rois)
                        if strlength(string(rois(r).id)) > 0 || ~isempty(rois(r).value) || ~isempty(rois(r).image)
                            label = sprintf('ROI %d',r);
                            if strlength(string(rois(r).id)) > 0
                                label = sprintf('%s · %s',label,string(rois(r).id));
                            end
                            obj.browserNode(fovNode,label, ...
                                struct('project',k,'fov',indices(j),'roi',r),'roi-node');
                        end
                    end
                end
            end
            kinds = {'classi','process','pipeline'};
            labels = {'Classifiers','Processors','Pipelines'};
            for k = 1:numel(kinds)
                indices = find(strcmp({obj.WorkspaceObjects.kind},kinds{k}));
                if isempty(indices), continue; end
                group = obj.browserNode(obj.Tree,labels{k}, ...
                    struct('project',0,'fov',0,'roi',0,'object',0),'workspace-collection');
                for j = indices
                    entry = obj.WorkspaceObjects(j);
                    name = char(string(entry.object.strid));
                    if isempty(name)
                        if isempty(entry.variables), name = ['Untitled ' class(entry.object)];
                        else, name = entry.variables{1}; end
                    end
                    obj.browserNode(group,name, ...
                        struct('project',0,'fov',0,'roi',0,'object',j),'workspace-object');
                end
            end
            clear restoreParent; % Publish the completed hierarchy in one step.
            drawnow;
            roots = obj.Tree.Children;
            for k = 1:numel(roots), expand(roots(k)); end
        end
        function restoreBrowserParent(obj,parent)
            if isvalid(obj) && isgraphics(obj.Tree) && isgraphics(parent)
                obj.Tree.Parent = parent;
                obj.Tree.Layout.Row = 1; obj.Tree.Layout.Column = 1;
            end
        end
        function browseSelection(obj)
            nodes = obj.Tree.SelectedNodes;
            if isempty(nodes), return; end
            target = nodes(1).UserData;
            if target.project == 0
                if target.object > 0
                    obj.showWorkspaceObject(target.object);
                else
                    obj.DetailsPanel.Title = nodes(1).Text;
                    obj.ProjectName.Text = nodes(1).Text;
                    obj.ProjectName.Tooltip = nodes(1).Text;
                    obj.ProjectPath.Value = {'—'}; obj.ProjectPath.Tooltip = '';
                    obj.CopyPath.UserData = ''; obj.CopyPath.Enable = 'off';
                    obj.ProjectInfo.Data = {'Objects',numel(nodes(1).Children)};
                end
                return;
            end
            obj.activate(target.project);
            if target.fov > 0
                if obj.Session.Position ~= target.fov || target.roi == 0
                    obj.Session.selectPosition(target.fov);
                end
                obj.Session.selectZone(target.roi);
                if target.roi > 0, obj.SelectedZone = target.roi; end
            end
            if target.fov > 0, obj.selectCurrentNode(); end
            obj.refreshView(target.fov > 0);
        end
        function refreshProjectInfo(obj)
            obj.DetailsPanel.Title = 'Project';
            obj.CopyPath.Tooltip = 'Copy the project folder path';
            obj.ProjectName.Text = '—'; obj.ProjectPath.Value = {'—'};
            obj.ProjectPath.Tooltip = 'Project folder'; obj.CopyPath.UserData = '';
            obj.CopyPath.Enable = 'off'; obj.ProjectInfo.Data = cell(0,2);
            if obj.ActiveProject == 0, return; end
            project = obj.Session.Project;
            obj.ProjectName.Text = obj.projectName(project);
            obj.ProjectName.Tooltip = obj.ProjectName.Text;
            folder = char(string(project.io.path)); name = char(string(project.io.file));
            if ~isempty(folder) && ~isempty(name)
                file = fullfile(folder,name);
                obj.ProjectPath.Value = {file}; obj.ProjectPath.Tooltip = file;
                obj.CopyPath.UserData = file; obj.CopyPath.Enable = 'on';
            end
            [~,indices] = obj.Session.positionItems();
            roiCount = 0;
            for k = indices
                rois = project.fov(k).roi;
                for r = 1:numel(rois)
                    roiCount = roiCount + (strlength(string(rois(r).id)) > 0 || ...
                        ~isempty(rois(r).value) || ~isempty(rois(r).image));
                end
            end
            data = {'FOVs',numel(indices); 'ROIs',roiCount};
            fields = {'classification','processor','pipelineRun'};
            labels = {'Classifiers','Processors','Pipeline runs'};
            for k = 1:numel(fields)
                count = 0;
                if isfield(project.processing,fields{k}), count = numel(project.processing.(fields{k})); end
                data(end+1,:) = {labels{k},count}; %#ok<AGROW>
            end
            [pipelinePath,pipelineId] = detecdiv_project_cached_pipeline_ref(project);
            if ~isempty(pipelineId) || ~isempty(pipelinePath)
                if isempty(pipelineId), pipelineId = pipelinePath; end
                data(end+1,:) = {'Default pipeline',pipelineId};
            end
            obj.ProjectInfo.Data = data;
        end
        function showWorkspaceObject(obj,index)
            entry = obj.WorkspaceObjects(index); item = entry.object;
            if ~isvalid(item), obj.refreshWorkspace(); return; end
            labels = struct('classi','Classifier','process','Processor','pipeline','Pipeline');
            obj.DetailsPanel.Title = labels.(entry.kind);
            obj.CopyPath.Tooltip = 'Copy the object folder path';
            name = char(string(item.strid));
            if isempty(name)
                if isempty(entry.variables), name = ['Untitled ' labels.(entry.kind)];
                else, name = entry.variables{1}; end
            end
            obj.ProjectName.Text = name; obj.ProjectName.Tooltip = name;
            obj.ProjectPath.Value = {'—'}; obj.ProjectPath.Tooltip = 'Object folder';
            obj.CopyPath.UserData = ''; obj.CopyPath.Enable = 'off';
            folder = char(string(item.path));
            if ~isempty(folder)
                obj.ProjectPath.Value = {folder}; obj.ProjectPath.Tooltip = folder;
                obj.CopyPath.UserData = folder; obj.CopyPath.Enable = 'on';
            end
            source = 'Workspace'; origin = strjoin(entry.variables,', ');
            if isempty(entry.variables), source = 'Source'; origin = 'File'; end
            obj.ProjectInfo.Data = {'Type',labels.(entry.kind); ...
                source,origin; 'Description',char(string(item.description))};
            obj.Status.Text = sprintf('%s selected',labels.(entry.kind));
            if strcmp(entry.kind,'pipeline')
                obj.Pipeline.addTemplate(item); obj.Host.focusWidget('Pipeline');
            end
        end
        function copyProjectPath(obj)
            if isempty(obj.CopyPath.UserData), return; end
            try
                clipboard('copy',obj.CopyPath.UserData);
                obj.Status.Text = 'Path copied';
            catch err
                obj.Status.Text = err.message;
            end
        end
        function activate(obj,index)
            if obj.ActiveProject == index, return; end
            obj.storeView();
            obj.ImageRequested = false;
            obj.ActiveProject = index; obj.Session = obj.Sessions{index};
            obj.DisplayModel = obj.DisplayModels{index};
            state = obj.ViewStates{index};
            obj.Frame.Value = state.frame; obj.PreferredChannel = state.channel;
            obj.SelectedZone = state.selectedROI; obj.RenderKey = '';
        end
        function storeView(obj)
            if obj.ActiveProject == 0 || ~obj.ImageRequested, return; end
            name = obj.Channels.Items{obj.Channels.Value};
            obj.ViewStates{obj.ActiveProject} = struct('frame',obj.Frame.Value, ...
                'channel',name,'selectedROI',obj.SelectedZone);
        end
        function selectCurrentNode(obj)
            nodes = findall(obj.Tree,'Type','uitreenode');
            for k = 1:numel(nodes)
                d = nodes(k).UserData;
                if d.project == 0, continue; end
                if d.project == obj.ActiveProject && d.fov == obj.Session.Position && d.roi == obj.Session.Zone
                    obj.Tree.SelectedNodes = nodes(k);
                    if isa(nodes(k).Parent,'matlab.ui.container.TreeNode'), expand(nodes(k).Parent); end
                    return;
                end
            end
        end
        function selectProjectNode(obj)
            nodes = findall(obj.Tree,'Tag','project-node');
            for k = 1:numel(nodes)
                if nodes(k).UserData.project == obj.ActiveProject
                    obj.Tree.SelectedNodes = nodes(k); return;
                end
            end
        end
        function openZone(obj,index)
            if obj.DrawingROI, return; end
            obj.Session.selectZone(index);
            if index > 0, obj.SelectedZone = index; end
            obj.selectCurrentNode(); obj.refreshView();
        end
        function returnToPosition(obj)
            if obj.Session.Position == 0, return; end
            obj.openZone(0);
        end
        function refreshView(obj,loadImage)
            if nargin < 2, loadImage = true; end
            if ~isa(obj.Pipeline.OnStatus,'detecdivui.Callback'), obj.rebindCallbacks(); end
            obj.refreshProjectInfo();
            if ~isempty(obj.Data) && isvalid(obj.Data), obj.Data.setContext(); end
            if obj.hasROIWidget(), obj.ROIs.setContext(obj.Session); end
            if obj.Session.Position == 0 || obj.Session.Zone > 0, obj.closeROITool(); end
            if obj.Session.Zone == 0, obj.closeContourTool(); obj.closeTracksTool(); end
            obj.EditContoursMenu.Enable = obj.onOff(obj.Session.Zone > 0);
            obj.EditTracksMenu.Enable = obj.EditContoursMenu.Enable;
            roiEnabled = obj.onOff(obj.Session.Position > 0);
            obj.DefineROIMenu.Enable = roiEnabled;
            obj.ImageROIMenu.Enable = roiEnabled; obj.TreeROIMenu.Enable = roiEnabled;
            obj.Pipeline.setContext(obj.Session);
            obj.Crumb.Text = obj.Session.breadcrumb();
            obj.Crumb.Tooltip = obj.Crumb.Text;
            obj.CloseMenu.Enable = obj.onOff(obj.ActiveProject > 0);
            obj.SaveProjectMenu.Enable = obj.onOff(obj.ActiveProject > 0 && ...
                strlength(string(obj.Session.Project.io.path)) > 0 && strlength(string(obj.Session.Project.io.file)) > 0);
            obj.RelinkMenu.Enable = obj.onOff(obj.Session.Position > 0);
            obj.LoadImage.Enable = obj.onOff(obj.Session.Position > 0);
            obj.RelinkImage.Visible = 'off'; obj.MissingRaw = false;
            obj.Back.Enable = obj.onOff(obj.Session.Zone > 0);
            obj.ParentMenu.Enable = obj.Back.Enable;
            obj.Overlays.Enable = obj.onOff(obj.Session.Position > 0 && obj.Session.Zone == 0);
            obj.OverlayMenu.Enable = obj.Overlays.Enable;
            if obj.Session.Position == 0
                obj.setControls({},1);
                obj.clearImagePanels(); obj.RenderKey = '';
                obj.CopyMenu.Enable = 'off';
                obj.ImageRequested = false;
                if ~isempty(obj.Data) && isvalid(obj.Data), obj.Data.onFrame(); end
                obj.LoadImage.Text = 'Load Image';
                obj.Status.Text = 'Ready';
                if obj.ActiveProject > 0, obj.Status.Text = 'No FOVs'; end
                return;
            end
            if ~loadImage
                obj.storeView(); obj.ImageRequested = false;
                if ~isempty(obj.Data) && isvalid(obj.Data), obj.Data.onFrame(); end
                preferred = obj.ViewStates{obj.ActiveProject}.channel;
                obj.setControls({},max(1,obj.Frame.Value));
                obj.PreferredChannel = preferred;
                obj.FrameCount.Text = '';
                obj.clearImagePanels(); obj.RenderKey = '';
                obj.CopyMenu.Enable = 'off'; obj.LoadImage.Text = 'Load Image';
                obj.Status.Text = 'Select a FOV or ROI, or load the current image';
                obj.Status.Tooltip = obj.Status.Text;
                return;
            end
            obj.ImageRequested = true; obj.LoadImage.Text = 'Reload Image';
            activity = obj.Progress.begin('Loading image...'); %#ok<NASGU>
            try
                [names, frames] = obj.Session.dimensions();
                obj.setControls(names,frames);
                obj.DisplayModel.configure(obj.Session,obj.Channels.Value);
                obj.render();
            catch err
                obj.setControls({},1); obj.showError(err);
            end
        end
        function setControls(obj,names,frames)
            oldName = obj.Channels.Items{obj.Channels.Value};
            if ~isempty(obj.PreferredChannel)
                oldName = obj.PreferredChannel; obj.PreferredChannel = '';
            end
            available = ~isempty(names);
            if ~available, names = {'—'}; end
            names = matlab.lang.makeUniqueStrings(names);
            obj.Channels.ItemsData = [];
            obj.Channels.Items = names;
            obj.Channels.ItemsData = 1:numel(names);
            chosen = find(strcmp(names,oldName),1);
            if isempty(chosen), chosen = 1; end
            obj.Channels.Value = chosen;
            obj.Channels.Enable = obj.onOff(available);
            if ~available, obj.clearLayerControls(); end
            obj.MaxFrame = frames;
            obj.Frame.Value = min(obj.Frame.Value,frames);
            obj.Frame.Enable = obj.onOff(available && frames > 1);
            obj.FrameCount.Text = sprintf('/ %d',frames);
            obj.TimeSlider.Value = 1;
            obj.TimeSlider.Limits = [1 max(2,frames)];
            obj.TimeSlider.Value = obj.Frame.Value;
            obj.TimeSlider.Enable = obj.onOff(available && frames > 1);
            obj.updateFrameActions(available);
        end
        function updateFrameActions(obj,available)
            obj.Previous.Enable = obj.onOff(available && obj.Frame.Value > 1);
            obj.Next.Enable = obj.onOff(available && obj.Frame.Value < obj.MaxFrame);
            obj.PreviousMenu.Enable = obj.Previous.Enable;
            obj.NextMenu.Enable = obj.Next.Enable;
            obj.JumpBackMenu.Enable = obj.Previous.Enable;
            obj.JumpForwardMenu.Enable = obj.Next.Enable;
            obj.refreshKeyboard();
        end
        function refreshKeyboard(obj)
            if isempty(obj.KeyboardView) || ~isvalid(obj.KeyboardView) || obj.Closing, return; end
            toolActive = obj.hasROIWidget() && isequal(obj.DisplayTabs.SelectedTab,obj.ROIsTab);
            editing = obj.hasMaskWidget() && obj.Masks.Active;
            tracking = obj.hasTracksWidget() && obj.Tracks.Active;
            enabled = obj.ImageRequested && obj.Session.Position > 0 && ...
                (strcmp(obj.Frame.Enable,'on') || editing || tracking) && ~obj.DrawingROI && ~toolActive;
            selection = {obj.Session.Project,obj.Session.Position,obj.Session.Zone,enabled,editing,tracking};
            if ~isequal(selection,obj.KeyboardSelection)
                obj.KeyboardSelection = selection; obj.KeyboardGeneration = obj.KeyboardGeneration+1;
            end
            state = struct('context',sprintf('%d',obj.KeyboardGeneration),'enabled',enabled, ...
                'keys',{{'leftarrow','rightarrow',obj.JumpKeys{1},obj.JumpKeys{2}}},'ctrlKeys',{{}}, ...
                'focusRequest',obj.KeyboardFocusRequest);
            if editing, state.keys = [state.keys obj.Masks.shortcuts()]; state.ctrlKeys = {'z','y'}; end
            if tracking, state.keys = [state.keys {'escape','delete'}]; state.ctrlKeys = {'z','y'}; end
            if isequal(state,obj.KeyboardState), return; end
            obj.KeyboardState = state; obj.KeyboardView.Data = state;
        end
        function imageKey(obj,event)
            if obj.Closing || ~isstruct(event) || ~all(isfield(event,{'action','context','key'})) || ...
                    ~strcmp(event.action,'key'), return; end
            obj.refreshKeyboard();
            state = obj.KeyboardState;
            if ~state.enabled || ~strcmp(event.context,state.context), return; end
            ctrl = isfield(event,'ctrl') && event.ctrl;
            if obj.hasTracksWidget() && obj.Tracks.Active && (ctrl || ~any(strcmpi(event.key,state.keys(1:4))))
                obj.Tracks.key(char(event.key),ctrl); return;
            end
            if obj.hasMaskWidget() && obj.Masks.Active && (ctrl || ~any(strcmpi(event.key,state.keys(1:4))))
                obj.Masks.key(char(event.key),ctrl); return;
            end
            index = find(strcmpi(char(event.key),state.keys),1);
            if isempty(index), return; end
            offsets = [-1 1 -10 10];
            frame = min(obj.MaxFrame,max(1,obj.Frame.Value+offsets(index)));
            if frame ~= obj.Frame.Value, obj.setFrame(frame); end
        end
        function showShortcuts(obj)
            if ~isempty(obj.ShortcutFigure) && isvalid(obj.ShortcutFigure)
                figure(obj.ShortcutFigure); delete(obj.ShortcutFigure.Children);
            else
                obj.ShortcutFigure = uifigure('Name','Keyboard Shortcuts','Tag','keyboard-shortcuts', ...
                    'Position',[200 200 580 360]);
            end
            grid = uigridlayout(obj.ShortcutFigure,[2 1]); grid.RowHeight = {'1x',28};
            rows = {'Left Arrow','Previous frame','Image browsing'; ...
                'Right Arrow','Next frame','Image browsing'; ...
                upper(obj.JumpKeys{1}),'Back 10 frames','Image browsing'; ...
                upper(obj.JumpKeys{2}),'Forward 10 frames','Image browsing'; ...
                'Ctrl+O','Open project','Main window'; 'Ctrl+S','Save project','Main window'; ...
                'Ctrl+W','Close project','Main window'; 'Ctrl+C','Copy image','Main window'; ...
                'Ctrl+R','Reload image','Main window'};
            if obj.hasMaskWidget()
                keys = obj.Masks.shortcuts();
                rows = [rows; {'Delete','Delete selected label on this frame','Contours'; ...
                    upper(keys{5}),'Fill selected label holes','Contours'; ...
                    [upper(keys{6}) ' / ' upper(keys{7})],'Decrease / increase mask opacity','Contours'; ...
                    'Up / Down Arrow','Increase / decrease mask opacity','Contours'; ...
                    'Ctrl+Z / Ctrl+Y','Undo / redo annotation edit','Contours'; ...
                    'Escape','Cancel stroke / return to Select','Contours'; ...
                    'Shift + drag','Erase with the brush','Contours'}];
            end
            if obj.hasTracksWidget()
                rows = [rows; {'Delete','Delete selected contour on this frame','Tracks'; ...
                    'Ctrl+Z / Ctrl+Y','Undo / redo shared annotation edit','Tracks'; ...
                    'Escape','Cancel pending link selection','Tracks'}];
            end
            uitable(grid,'Data',rows,'ColumnName',{'Shortcut','Action','Context'}, ...
                'ColumnWidth',{110,'auto',140},'RowName',{},'ColumnEditable',false, ...
                'Tag','keyboard-shortcuts-table');
            uibutton(grid,'Text','Close','ButtonPushedFcn',@(~,~)delete(obj.ShortcutFigure));
        end
        function setFrame(obj,frame)
            obj.Frame.Value = min(max(1,frame),obj.MaxFrame); obj.render();
        end
        function stepFrame(obj,delta)
            obj.setFrame(obj.Frame.Value+delta);
            obj.focusImage();
        end
        function focusImage(obj)
            % Selecting a document does not move focus off its native buttons.
            obj.Host.focusWidget('Image');
            obj.KeyboardFocusRequest = obj.KeyboardFocusRequest+1;
            obj.refreshKeyboard();
        end
        function render(obj)
            if obj.Session.Position == 0 || ~obj.ImageRequested, return; end
            activity = obj.Progress.begin('Reading image and rendering layers...'); %#ok<NASGU>
            try
                obj.Frame.Value = min(obj.Frame.Value,obj.MaxFrame);
                obj.TimeSlider.Value = obj.Frame.Value;
                obj.updateFrameActions(true);
                separated = obj.isSeparated();
                if separated
                    views = obj.DisplayModel.separate(obj.Frame.Value,obj.Channels.Value);
                else
                    view = obj.DisplayModel.compose(obj.Frame.Value,obj.Channels.Value);
                    view.layer = obj.Channels.Value; view.title = ''; views = {view};
                end
                obj.refreshLayerControls();
                key = sprintf('%d:%d:%d',obj.ActiveProject,obj.Session.Position,obj.Session.Zone);
                keepView = strcmp(key,obj.RenderKey);
                xl = obj.Axes.XLim; yl = obj.Axes.YLim;
                obj.renderImagePanels(views,separated,keepView,xl,yl);
                if obj.hasROIWidget(), obj.ROIs.onRender(); end
                if obj.hasMaskWidget(), obj.Masks.onRender(); end
                if obj.hasTracksWidget(), obj.Tracks.onRender(); end
                if ~isempty(obj.Data) && isvalid(obj.Data), obj.Data.onFrame(); end
                obj.RenderKey = key; obj.CopyMenu.Enable = 'on';
                source = 'Raw';
                if obj.Session.Zone > 0, source = 'ROI'; end
                names = {obj.DisplayModel.Layers([obj.DisplayModel.Layers.visible]).name};
                separator = ' + '; if separated, separator = ' | '; end
                obj.Status.Text = sprintf('%s | Frame %d / %d | %s',source, ...
                    obj.Frame.Value,obj.MaxFrame,strjoin(names,separator));
                if obj.Session.Zone > 0 && obj.hasMaskWidget() && ...
                        obj.Masks.dirty(obj.Session.Project.fov(obj.Session.Position).roi(obj.Session.Zone))
                    obj.Status.Text = [obj.Status.Text ' | Unsaved annotations'];
                end
                obj.Status.Tooltip = obj.Status.Text;
            catch err
                obj.showError(err);
            end
        end
        function yes = isSeparated(obj)
            yes = ~isempty(obj.OverlayChannels) && isvalid(obj.OverlayChannels) && ~obj.OverlayChannels.Value;
        end
        function ensureImagePanels(obj,count)
            if ~isempty(obj.ImageLink), delete(obj.ImageLink); obj.ImageLink = []; end
            if isempty(obj.ImageAxes), obj.ImageAxes = obj.Axes; end
            if numel(obj.ImageAxes) > count
                delete(obj.ImageAxes(count+1:end)); obj.ImageAxes = obj.ImageAxes(1:count);
            end
            for k = numel(obj.ImageAxes)+1:count
                obj.ImageAxes(k) = uiaxes(obj.ImageGrid,'Color',[.07 .09 .11]);
                obj.ImageAxes(k).Toolbar.Visible = 'on';
            end
            if ~isempty(obj.ImageGrid)
                obj.ImageGrid.ColumnWidth = repmat({'1x'},1,count);
                for k = 1:count, obj.ImageAxes(k).Layout.Row = 1; obj.ImageAxes(k).Layout.Column = k; end
                obj.ImageGrid.RowHeight = {'1x'};
            end
        end
        function clearImagePanels(obj)
            obj.ensureImagePanels(1); obj.Axes = obj.ImageAxes(1);
            cla(obj.Axes); title(obj.Axes,''); obj.Axes.Tag = 'image-view';
            obj.ImageRevision = obj.ImageRevision+1;
        end
        function renderImagePanels(obj,views,separated,keepView,xl,yl)
            obj.ensureImagePanels(numel(views)); obj.ImageRevision = obj.ImageRevision+1;
            selected = find(cellfun(@(v)v.layer == obj.Channels.Value,views),1);
            matched = ~isempty(selected);
            if isempty(selected), selected = 1; end
            obj.Axes = obj.ImageAxes(selected);
            for k = 1:numel(views)
                ax = obj.ImageAxes(k); view = views{k}; plane = view.pixels; cla(ax);
                ax.Tag = 'channel-view'; if k == selected, ax.Tag = 'image-view'; end
                if view.native
                    imagesc(ax,plane); colormap(ax,gray(256)); ax.CLim = view.limits;
                else
                    image(ax,plane);
                end
                axis(ax,'image'); ax.XTick = []; ax.YTick = []; ax.YDir = 'reverse';
                ax.ContextMenu = obj.ImageMenu; ax.UserData = struct('layer',view.layer);
                callback = detecdivui.Callback(obj,'widgetEvent','imageLayer',view.layer,obj.ImageRevision);
                ax.ButtonDownFcn = {@detecdivui.Callback.event,callback};
                imageHandle = findall(ax,'Type','image');
                set(imageHandle,'ContextMenu',obj.ImageMenu,'ButtonDownFcn',{@detecdivui.Callback.event,callback});
                label = ''; if separated, label = view.title; end
                color = [.25 .3 .35]; if matched && k == selected, color = [0 .4 .65]; end
                title(ax,label,'Interpreter','none','FontSize',11,'Color',color);
                if obj.Session.Zone == 0 && obj.Overlays.Value, obj.drawRegions(ax,view.layer); end
                if keepView, ax.XLim = xl; ax.YLim = yl;
                else, ax.XLim = [.5 size(plane,2)+.5]; ax.YLim = [.5 size(plane,1)+.5]; end
                if isfield(view,'vectors') && ~isempty(view.vectors)
                    options = score_collectDisplayOptions('mode','display','frames',1,'hideStamp',true);
                    [~,contours] = score_displayVectorGraphics(ax,1,1,view.vectors,options);
                    set(contours,'Tag','mask-contour','HitTest','off','PickableParts','none');
                end
            end
            if numel(obj.ImageAxes) > 1, obj.ImageLink = linkprop(obj.ImageAxes,{'XLim','YLim'}); end
        end
        function selectImageLayer(obj,index,revision)
            if revision ~= obj.ImageRevision || obj.DrawingROI || index < 1 || ...
                    index > numel(obj.DisplayModel.Layers) || ~obj.DisplayModel.Layers(index).visible, return; end
            if obj.Channels.Value ~= index
                obj.Channels.Value = index;
                for ax = obj.ImageAxes
                    ax.Tag = 'channel-view'; ax.Title.Color = [.25 .3 .35];
                    if ax.UserData.layer == index
                        obj.Axes = ax; ax.Tag = 'image-view'; ax.Title.Color = [0 .4 .65];
                    end
                end
                obj.refreshLayerControls();
                if obj.hasROIWidget(), obj.ROIs.onRender(); end
                if obj.hasTracksWidget(), obj.Tracks.onRender(); end
            end
        end
        function drawRegions(obj,ax,layer)
            regions = obj.Session.referenceRegions();
            hold(ax,'on');
            for k = 1:numel(regions)
                r = regions(k); p = r.position; color = [0.25 0.9 0.85];
                if r.index == obj.SelectedZone, color = [1 0.8 0.25]; end
                h = patch(ax,p(1)+[0 p(3) p(3) 0],p(2)+[0 0 p(4) p(4)],color, ...
                    'FaceAlpha',0.025,'EdgeColor',color,'LineWidth',1.5, ...
                    'Tag','zone-overlay','UserData',r.index);
                callback = detecdivui.Callback(obj,'widgetEvent','zone',r.index,layer,obj.ImageRevision);
                h.ButtonDownFcn = {@detecdivui.Callback.event,callback};
                t = text(ax,p(1),p(2),sprintf(' ROI %d',r.index),'Color',color, ...
                    'VerticalAlignment','bottom','FontWeight','bold','Interpreter','none');
                t.ButtonDownFcn = {@detecdivui.Callback.event,callback};
            end
            hold(ax,'off');
        end
        function setOutlines(obj,visible)
            obj.Overlays.Value = visible; obj.OverlayMenu.Checked = obj.onOff(visible); obj.render();
        end
        function resetView(obj)
            obj.RenderKey = ''; obj.render();
        end
        function reloadImage(obj)
            obj.loadCurrentImage();
        end
        function soloLayer(obj)
            if ~obj.ImageRequested || isempty(obj.DisplayModel) || isempty(obj.DisplayModel.Layers), return; end
            obj.DisplayModel.solo(obj.Channels.Value); obj.render();
        end
        function editLayer(obj,action)
            if ~obj.ImageRequested || isempty(obj.DisplayModel), return; end
            activity = obj.DisplayProgress.begin('Updating display...'); %#ok<NASGU>
            index = obj.Channels.Value;
            try
                switch action
                    case 'limits', obj.DisplayModel.setLimits(index,[obj.MinField.Value obj.MaxField.Value]);
                    case 'range', obj.DisplayModel.setLimits(index,obj.ContrastSlider.Value);
                    case 'auto', obj.DisplayModel.autoContrast(index,obj.Frame.Value);
                    case 'opacity', obj.DisplayModel.setOpacity(index,obj.OpacitySlider.Value);
                    case 'color', obj.DisplayModel.setColor(index,obj.ColorField.Value);
                    case 'picker', obj.DisplayModel.setColor(index,sprintf('%.8g %.8g %.8g',obj.ColorPicker.Value));
                    case 'kind', obj.DisplayModel.setKind(index,obj.LayerKind.Value);
                    case 'mask-style', obj.DisplayModel.setLabelStyle(index,obj.MaskStyle.Value,obj.MaskWidth.Value);
                    case 'presentation'
                end
                obj.render();
                if strcmp(action,'presentation'), obj.focusImage(); end
            catch err
                obj.refreshLayerControls(); obj.Status.Text = err.message;
            end
        end
        function refreshLayerControls(obj)
            layers = obj.DisplayModel.Layers;
            if isempty(layers), obj.clearLayerControls(); return; end
            index = obj.Channels.Value;
            obj.LayerTable.update(layers,index,~obj.isSeparated());
            if ~isempty(obj.OverlayChannels), obj.OverlayChannels.Enable = 'on'; end
            layer = obj.DisplayModel.Layers(index);
            isLabel = strcmp(layer.kind,'Labels'); isRGB = strcmp(layer.kind,'RGB');
            if ~isempty(obj.MaskOptions) && isvalid(obj.MaskOptions)
                rows = obj.MaskOptions.Parent.RowHeight; rows{5} = 0; rows{6} = 150;
                rows(7:9) = {28,28,28};
                obj.MaskOptions.Visible = obj.onOff(isLabel);
                obj.Histogram.View.Visible = obj.onOff(~isLabel);
                obj.MinField.Parent.Visible = obj.onOff(~isLabel);
                obj.ContrastSlider.Visible = obj.onOff(~isLabel); obj.AutoButton.Visible = obj.onOff(~isLabel);
                if isLabel
                    rows{5} = 28; rows{6} = 0;
                    rows(7:9) = {0,0,0};
                    style = obj.DisplayModel.labelStyle(index);
                    obj.MaskStyle.Value = style.mode; obj.MaskWidth.Value = style.width;
                    obj.MaskWidth.Enable = obj.onOff(~strcmp(style.mode,'Fill'));
                end
                obj.MaskOptions.Parent.RowHeight = rows;
            end
            if ~isLabel
                plane = obj.DisplayModel.read(index,obj.Frame.Value);
                layer = obj.DisplayModel.Layers(index);
            end
            if isRGB, obj.LayerKind.Items = {'RGB'};
            else, obj.LayerKind.Items = {'Intensity','Labels'}; end
            obj.LayerKind.Value = layer.kind; obj.LayerKind.Enable = obj.onOff(~isRGB);
            if ~any(strcmp(obj.ColorField.Items,layer.color)), obj.ColorField.Items{end+1} = layer.color; end
            obj.ColorField.Value = layer.color; obj.ColorField.Enable = obj.onOff(~isRGB);
            rgb = sscanf(strrep(layer.color,',',' '),'%f');
            if numel(rgb) ~= 3 || any(~isfinite(rgb) | rgb < 0 | rgb > 1), rgb = [1 1 1]; end
            obj.ColorPicker.Value = reshape(rgb,1,3); obj.ColorPicker.Enable = obj.onOff(~isRGB);
            obj.OpacitySlider.Value = layer.opacity; obj.OpacitySlider.Enable = obj.onOff(isLabel || ~obj.isSeparated());
            for control = {obj.MinField,obj.MaxField,obj.ContrastSlider,obj.AutoButton}
                item = control{1}; item.Enable = obj.onOff(~isLabel);
            end
            if ~isLabel
                obj.MinField.Value = layer.limits(1); obj.MaxField.Value = layer.limits(2);
                values = double(plane(isfinite(plane)));
                bounds = layer.limits;
                if ~isempty(values), bounds = [min(min(values(:)),bounds(1)),max(max(values(:)),bounds(2))]; end
                obj.ContrastSlider.Limits = [min(bounds(1),obj.ContrastSlider.Limits(1)), ...
                    max(bounds(2),obj.ContrastSlider.Limits(2))];
                obj.ContrastSlider.Value = layer.limits;
                obj.ContrastSlider.Limits = bounds;
            end
            obj.Histogram.update(obj.DisplayModel,obj.Frame.Value,index);
        end
        function clearLayerControls(obj)
            if ~isempty(obj.OverlayChannels), obj.OverlayChannels.Enable = 'off'; end
            obj.LayerTable.update(struct([]),0); obj.Histogram.clear();
            if ~isempty(obj.MaskOptions) && isvalid(obj.MaskOptions)
                obj.MaskOptions.Visible = 'off'; obj.Histogram.View.Visible = 'on';
                obj.MinField.Parent.Visible = 'on'; obj.ContrastSlider.Visible = 'on'; obj.AutoButton.Visible = 'on';
                rows = obj.MaskOptions.Parent.RowHeight; rows{5} = 0; rows{6} = 150;
                rows(7:9) = {28,28,28};
                obj.MaskOptions.Parent.RowHeight = rows;
            end
            for control = {obj.LayerKind,obj.ColorField,obj.ColorPicker,obj.MinField,obj.MaxField, ...
                    obj.ContrastSlider,obj.AutoButton,obj.OpacitySlider}
                item = control{1}; item.Enable = 'off';
            end
        end
        function editLayerRow(obj,action,index,value)
            if ~obj.ImageRequested || isempty(obj.DisplayModel), return; end
            activity = obj.DisplayProgress.begin('Updating display...'); %#ok<NASGU>
            try
                validateattributes(index,{'numeric'},{'scalar','integer','positive','<=',numel(obj.DisplayModel.Layers)});
                switch action
                    case 'select', obj.Channels.Value = index;
                    case 'visible'
                        validateattributes(value,{'logical'},{'scalar'});
                        obj.DisplayModel.setVisible(index,value);
                    case 'limits', obj.DisplayModel.setLimits(index,value); obj.Channels.Value = index;
                    case 'opacity', obj.DisplayModel.setOpacity(index,value);
                    case 'color'
                        validateattributes(value,{'numeric'},{'vector','numel',3,'finite','>=',0,'<=',1});
                        obj.DisplayModel.setColor(index,sprintf('%.8g %.8g %.8g',value));
                    case 'histogram'
                    otherwise, return;
                end
                obj.render();
            catch err
                obj.refreshLayerControls(); obj.Status.Text = err.message;
            end
        end
        function copyImage(obj)
            activity = obj.Progress.begin('Copying image...'); %#ok<NASGU>
            try
                copygraphics(obj.Axes);
            catch err
                obj.Status.Text = err.message;
            end
        end
        function showError(obj,err)
            obj.clearImagePanels(); obj.RenderKey = ''; obj.CopyMenu.Enable = 'off';
            obj.clearLayerControls();
            obj.MissingRaw = strcmp(err.identifier,'detecdivui:RawSourceMissing');
            obj.RelinkImage.Visible = obj.onOff(obj.MissingRaw);
            obj.Status.Text = err.message; obj.Status.Tooltip = err.message;
            title(obj.Axes,'Image unavailable');
        end
    end
    methods (Static, Access = private)
        function node = browserNode(parent,text,data,tag)
            % Navigation records stay on the MATLAB side.
            node = uitreenode(parent,'Text',text,'Tag',tag,'NodeData',[]);
            node.UserData = data;
        end
        function name = projectName(project)
            name = char(string(project.io.file));
            if isempty(name), name = 'Untitled Project'; end
        end
        function value = onOff(condition)
            if condition, value = 'on'; else, value = 'off'; end
        end
    end
end
