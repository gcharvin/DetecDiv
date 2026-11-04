classdef Viewer < handle
    % Conventional desktop shell; legacy readers are accessed through Session.
    properties (SetAccess = private)
        Session
        Figure
        Host
        Sessions = {}
        ActiveProject = 0
        DisplayModel
    end
    properties (Access = private)
        Tree
        Channels
        LayerTable
        LayerKind
        ColorField
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
        Overlays
        BrowserMenu
        ToolsMenu
        OverlayMenu
        CloseMenu
        CopyMenu
        ParentMenu
        PreviousMenu
        NextMenu
        ViewStates = {}
        PreferredChannel = ''
        SelectedZone = 0
        RenderKey = ''
        MaxFrame = 1
        Closing = false
    end
    methods
        function obj = Viewer(project, visibility, layoutFile, autoSave)
            if nargin < 1, project = []; end
            if nargin < 2, visibility = 'on'; end
            obj.Session = detecdivui.Session();
            obj.Host = detecdivui.DockingHost(layoutFile,autoSave);
            obj.Host.OnClosed = @()delete(obj);
            obj.Figure = obj.Host.widgetFigure('Image');
            obj.createMenus();
            root = uigridlayout(obj.Figure,[3 1]);
            root.RowHeight = {32,'1x',24};
            root.Padding = [8 6 8 6];
            root.BackgroundColor = [0.95 0.96 0.97];
            location = uigridlayout(root,[1 2]);
            location.ColumnWidth = {100,'1x'}; location.Padding = [0 0 0 0];
            obj.Back = uibutton(location,'Text','← FOV','Enable','off', ...
                'Tag','parent-fov','Tooltip','Return to the parent FOV', ...
                'ButtonPushedFcn',@(~,~)obj.returnToPosition());
            obj.Crumb = uilabel(location,'Text','', ...
                'Interpreter','none','FontSize',12,'Tag','breadcrumb');
            nav = uigridlayout(obj.Host.widgetFigure('Projects'),[1 1]);
            nav.Padding = [4 4 4 4];
            obj.Tree = uitree(nav,'Tag','projects-tree', ...
                'SelectionChangedFcn',@(~,~)obj.browseSelection());
            obj.Tree.Tooltip = 'Browse open projects, FOVs and ROIs';
            canvas = uigridlayout(root,[2 1]);
            canvas.RowHeight = {'1x',60}; canvas.Padding = [0 0 0 0];
            obj.Axes = uiaxes(canvas,'Color',[0.07 0.09 0.11],'Tag','image-view');
            obj.Axes.XTick = []; obj.Axes.YTick = [];
            obj.Axes.Toolbar.Visible = 'on';
            timeline = uigridlayout(canvas,[2 5]);
            timeline.RowHeight = {26,20};
            timeline.ColumnWidth = {32,32,80,'1x',90}; timeline.Padding = [0 0 0 0];
            obj.Previous = uibutton(timeline,'Text','‹','Enable','off', ...
                'Tag','previous-frame','Tooltip','Previous frame', ...
                'ButtonPushedFcn',@(~,~)obj.stepFrame(-1));
            obj.Next = uibutton(timeline,'Text','›','Enable','off', ...
                'Tag','next-frame','Tooltip','Next frame', ...
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
            tools = uigridlayout(obj.Host.widgetFigure('Display'),[14 1]);
            tools.RowHeight = {22,'1x',22,28,28,22,28,28,28,22,38,28,28,32};
            uilabel(tools,'Text','Layers','FontWeight','bold');
            obj.LayerTable = uitable(tools,'Data',cell(0,2),'ColumnName',{'','Layer'}, ...
                'ColumnEditable',[true false],'ColumnWidth',{28,'auto'},'RowName',{}, ...
                'Tag','layers','Tooltip','Toggle visibility or select a layer', ...
                'CellEditCallback',@(~,event)obj.layerVisibilityChanged(event), ...
                'CellSelectionCallback',@(~,event)obj.layerSelected(event));
            uilabel(tools,'Text','Active layer','FontWeight','bold');
            active = uigridlayout(tools,[1 2]); active.Padding = [0 0 0 0];
            active.ColumnWidth = {'1x',45};
            obj.Channels = uidropdown(active,'Items',{'—'},'ItemsData',1, ...
                'Enable','off','Tag','channels','Tooltip','Select the layer to adjust', ...
                'ValueChangedFcn',@(~,~)obj.render());
            uibutton(active,'Text','Solo','Tag','solo-layer','Tooltip','Show only the active layer', ...
                'ButtonPushedFcn',@(~,~)obj.soloLayer());
            obj.LayerKind = uidropdown(tools,'Items',{'Intensity','Labels'},'Enable','off', ...
                'Tag','layer-kind','Tooltip','Labels requires an integer label map', ...
                'ValueChangedFcn',@(~,~)obj.editLayer('kind'));
            uilabel(tools,'Text','Contrast','FontWeight','bold');
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
            uilabel(tools,'Text','Opacity','FontWeight','bold');
            obj.OpacitySlider = uislider(tools,'Limits',[0 1],'Value',1,'Enable','off', ...
                'MajorTicks',[0 1],'Tag','layer-opacity','Tooltip','Active layer opacity / intensity weight', ...
                'ValueChangedFcn',@(~,~)obj.editLayer('opacity'));
            color = uigridlayout(tools,[1 2]); color.Padding = [0 0 0 0];
            color.ColumnWidth = {40,'1x'}; uilabel(color,'Text','Color');
            obj.ColorField = uieditfield(color,'text','Enable','off','Value','1 1 1', ...
                'Tag','layer-color','Tooltip','RGB triplet or score colormap; Labels for label colors', ...
                'ValueChangedFcn',@(~,~)obj.editLayer('color'));
            obj.Overlays = uicheckbox(tools,'Text','ROI outlines','Value',true, ...
                'Enable','off','Tag','reference-zones', ...
                'Tooltip','Show reference ROI rectangles; positions are not drift-corrected', ...
                'ValueChangedFcn',@(src,~)obj.setOutlines(src.Value));
            uibutton(tools,'Text','Fit image','Tooltip','Fit the complete image to the viewport', ...
                'Tag','fit-image','ButtonPushedFcn',@(~,~)obj.resetView());
            obj.Status = uilabel(root,'Text','Ready','Interpreter','none','Tag','status');
            if iscell(project)
                for k = 1:numel(project), obj.addProject(project{k}); end
            elseif ~isempty(project)
                for k = 1:numel(project), obj.addProject(project(k)); end
            end
            try
                obj.Host.start(visibility);
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
            index = obj.findProject(project);
            if index == 0
                obj.Sessions{end+1} = detecdivui.Session(project);
                obj.DisplayModels{end+1} = detecdivui.LayerModel();
                obj.ViewStates{end+1} = struct('frame',1,'channel','','selectedROI',0);
                index = numel(obj.Sessions);
                obj.rebuildTree();
            end
            obj.activate(index);
            obj.selectCurrentNode();
            obj.refreshView();
        end
        function closeProject(obj,index)
            % Closing removes the UI reference only; scientific data is unchanged.
            if nargin < 2, index = obj.ActiveProject; end
            if index == 0, return; end
            validateattributes(index,{'numeric'},{'scalar','integer','positive','<=',numel(obj.Sessions)});
            active = obj.Session;
            obj.storeView();
            obj.Sessions(index) = []; obj.ViewStates(index) = [];
            obj.DisplayModels(index) = [];
            remaining = find(cellfun(@(session)isequal(session,active),obj.Sessions),1);
            obj.ActiveProject = 0;
            obj.Session = detecdivui.Session();
            obj.DisplayModel = [];
            obj.rebuildTree();
            if ~isempty(obj.Sessions)
                if isempty(remaining), remaining = min(index,numel(obj.Sessions)); end
                obj.activate(remaining); obj.selectCurrentNode();
            end
            obj.refreshView();
        end
        function figure = widgetFigure(obj,name)
            figure = obj.Host.widgetFigure(name);
        end
        function delete(obj)
            if obj.Closing, return; end
            obj.Closing = true;
            if ~isempty(obj.Host) && isvalid(obj.Host), delete(obj.Host); end
        end
    end
    methods (Access = private)
        function createMenus(obj)
            file = obj.Host.menu([],'File');
            obj.Host.menu(file,'Open Project...','Accelerator','O', ...
                'MenuSelectedFcn',@(~,~)obj.openProject());
            obj.CloseMenu = obj.Host.menu(file,'Close Project','Accelerator','W', ...
                'Enable','off','MenuSelectedFcn',@(~,~)obj.closeProject());
            obj.Host.menu(file,'Exit','Separator','on', ...
                'MenuSelectedFcn',@(~,~)delete(obj));
            edit = obj.Host.menu([],'Edit');
            obj.CopyMenu = obj.Host.menu(edit,'Copy Image','Accelerator','C', ...
                'Enable','off','MenuSelectedFcn',@(~,~)obj.copyImage());
            view = obj.Host.menu([],'View');
            obj.BrowserMenu = obj.Host.widgetMenu(view,'Projects');
            obj.Host.widgetMenu(view,'Image');
            obj.ToolsMenu = obj.Host.widgetMenu(view,'Display');
            obj.OverlayMenu = obj.Host.menu(view,'ROI Outlines','Checked','on','Separator','on', ...
                'MenuSelectedFcn',@(~,~)obj.setOutlines(~obj.Overlays.Value));
            obj.Host.menu(view,'Fit Image','MenuSelectedFcn',@(~,~)obj.resetView());
            obj.Host.menu(view,'Reload Image','Accelerator','R', ...
                'MenuSelectedFcn',@(~,~)obj.reloadImage());
            obj.Host.menu(view,'Expand Projects','Separator','on', ...
                'MenuSelectedFcn',@(~,~)expand(obj.Tree,'all'));
            obj.Host.menu(view,'Collapse Projects', ...
                'MenuSelectedFcn',@(~,~)collapse(obj.Tree,'all'));
            obj.Host.addDockMenus(view);
            navigate = obj.Host.menu([],'Navigate');
            obj.ParentMenu = obj.Host.menu(navigate,'Parent FOV','Enable','off', ...
                'MenuSelectedFcn',@(~,~)obj.returnToPosition());
            obj.PreviousMenu = obj.Host.menu(navigate,'Previous Frame','Enable','off', ...
                'MenuSelectedFcn',@(~,~)obj.stepFrame(-1));
            obj.NextMenu = obj.Host.menu(navigate,'Next Frame','Enable','off', ...
                'MenuSelectedFcn',@(~,~)obj.stepFrame(1));
            helpMenu = obj.Host.menu([],'Help');
            obj.Host.menu(helpMenu,'About DetecDiv', ...
                'MenuSelectedFcn',@(~,~)uialert(obj.Figure, ...
                    'DetecDiv — microscopy image analysis','About DetecDiv','Icon','info'));
        end
        function openProject(obj)
            try
                [file,folder] = uigetfile( ...
                    {'*.json;*.mat','DetecDiv Projects (*.json, *.mat)'},'Open Project');
                if isequal(file,0), return; end
                project = shallowLoad(fullfile(folder,file));
                if ~isempty(project), obj.addProject(project); end
            catch err
                obj.showError(err);
            end
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
            delete(obj.Tree.Children);
            for k = 1:numel(obj.Sessions)
                session = obj.Sessions{k};
                projectNode = uitreenode(obj.Tree,'Text',obj.projectName(session.Project), ...
                    'NodeData',struct('project',k,'fov',0,'roi',0),'Tag','project-node');
                [labels, indices] = session.positionItems();
                for j = 1:numel(indices)
                    fovNode = uitreenode(projectNode,'Text',labels{j}, ...
                        'NodeData',struct('project',k,'fov',indices(j),'roi',0),'Tag','fov-node');
                    % Inspect the hierarchy without changing session selection.
                    rois = session.Project.fov(indices(j)).roi;
                    for r = 1:numel(rois)
                        if strlength(string(rois(r).id)) > 0 || ~isempty(rois(r).value) || ~isempty(rois(r).image)
                            label = sprintf('ROI %d',r);
                            if strlength(string(rois(r).id)) > 0
                                label = sprintf('%s · %s',label,string(rois(r).id));
                            end
                            uitreenode(fovNode,'Text',label, ...
                                'NodeData',struct('project',k,'fov',indices(j),'roi',r),'Tag','roi-node');
                        end
                    end
                end
                expand(projectNode);
            end
        end
        function browseSelection(obj)
            nodes = obj.Tree.SelectedNodes;
            if isempty(nodes), return; end
            target = nodes(1).NodeData;
            obj.activate(target.project);
            if target.fov > 0
                if obj.Session.Position ~= target.fov || target.roi == 0
                    obj.Session.selectPosition(target.fov);
                end
                obj.Session.selectZone(target.roi);
                if target.roi > 0, obj.SelectedZone = target.roi; end
            end
            obj.selectCurrentNode(); obj.refreshView();
        end
        function activate(obj,index)
            if obj.ActiveProject == index, return; end
            obj.storeView();
            obj.ActiveProject = index; obj.Session = obj.Sessions{index};
            obj.DisplayModel = obj.DisplayModels{index};
            state = obj.ViewStates{index};
            obj.Frame.Value = state.frame; obj.PreferredChannel = state.channel;
            obj.SelectedZone = state.selectedROI; obj.RenderKey = '';
        end
        function storeView(obj)
            if obj.ActiveProject == 0, return; end
            name = obj.Channels.Items{obj.Channels.Value};
            obj.ViewStates{obj.ActiveProject} = struct('frame',obj.Frame.Value, ...
                'channel',name,'selectedROI',obj.SelectedZone);
        end
        function selectCurrentNode(obj)
            nodes = findall(obj.Tree,'Type','uitreenode');
            for k = 1:numel(nodes)
                d = nodes(k).NodeData;
                if d.project == obj.ActiveProject && d.fov == obj.Session.Position && d.roi == obj.Session.Zone
                    obj.Tree.SelectedNodes = nodes(k);
                    if isa(nodes(k).Parent,'matlab.ui.container.TreeNode'), expand(nodes(k).Parent); end
                    return;
                end
            end
        end
        function openZone(obj,index)
            obj.Session.selectZone(index);
            if index > 0, obj.SelectedZone = index; end
            obj.selectCurrentNode(); obj.refreshView();
        end
        function returnToPosition(obj)
            if obj.Session.Position == 0, return; end
            obj.openZone(0);
        end
        function refreshView(obj)
            obj.Crumb.Text = obj.Session.breadcrumb();
            obj.CloseMenu.Enable = obj.onOff(obj.ActiveProject > 0);
            obj.Back.Enable = obj.onOff(obj.Session.Zone > 0);
            obj.ParentMenu.Enable = obj.Back.Enable;
            obj.Overlays.Enable = obj.onOff(obj.Session.Position > 0 && obj.Session.Zone == 0);
            obj.OverlayMenu.Enable = obj.Overlays.Enable;
            if obj.Session.Position == 0
                obj.setControls({},1);
                cla(obj.Axes); title(obj.Axes,''); obj.RenderKey = '';
                obj.CopyMenu.Enable = 'off';
                obj.Status.Text = 'Ready';
                if obj.ActiveProject > 0, obj.Status.Text = 'No FOVs'; end
                return;
            end
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
        end
        function setFrame(obj,frame)
            obj.Frame.Value = min(max(1,frame),obj.MaxFrame); obj.render();
        end
        function stepFrame(obj,delta)
            obj.setFrame(obj.Frame.Value+delta);
        end
        function render(obj)
            if obj.Session.Position == 0, return; end
            try
                obj.Frame.Value = min(obj.Frame.Value,obj.MaxFrame);
                obj.TimeSlider.Value = obj.Frame.Value;
                obj.updateFrameActions(true);
                obj.refreshLayerControls();
                view = obj.DisplayModel.compose(obj.Frame.Value,obj.Channels.Value);
                plane = view.pixels;
                key = sprintf('%d:%d:%d',obj.ActiveProject,obj.Session.Position,obj.Session.Zone);
                keepView = strcmp(key,obj.RenderKey);
                xl = obj.Axes.XLim; yl = obj.Axes.YLim;
                cla(obj.Axes);
                if view.native
                    imagesc(obj.Axes,plane); colormap(obj.Axes,gray(256));
                    obj.Axes.CLim = view.limits;
                else
                    image(obj.Axes,plane);
                end
                axis(obj.Axes,'image'); obj.Axes.XTick = []; obj.Axes.YTick = [];
                title(obj.Axes,'');
                if obj.Session.Zone == 0 && obj.Overlays.Value, obj.drawRegions(); end
                obj.Axes.YDir = 'reverse';
                if keepView
                    obj.Axes.XLim = xl; obj.Axes.YLim = yl;
                else
                    obj.Axes.XLim = [0.5 size(plane,2)+0.5];
                    obj.Axes.YLim = [0.5 size(plane,1)+0.5];
                end
                if view.native, obj.Axes.CLim = view.limits; end
                obj.RenderKey = key; obj.CopyMenu.Enable = 'on';
                source = 'Raw';
                if obj.Session.Zone > 0, source = 'ROI'; end
                obj.Status.Text = sprintf('%s | Frame %d / %d | %s',source, ...
                    obj.Frame.Value,obj.MaxFrame,strjoin(view.names,' + '));
                obj.Status.Tooltip = obj.Status.Text;
            catch err
                obj.showError(err);
            end
        end
        function drawRegions(obj)
            regions = obj.Session.referenceRegions();
            hold(obj.Axes,'on');
            for k = 1:numel(regions)
                r = regions(k); p = r.position; color = [0.25 0.9 0.85];
                if r.index == obj.SelectedZone, color = [1 0.8 0.25]; end
                h = patch(obj.Axes,p(1)+[0 p(3) p(3) 0],p(2)+[0 0 p(4) p(4)],color, ...
                    'FaceAlpha',0.025,'EdgeColor',color,'LineWidth',1.5, ...
                    'Tag','zone-overlay','UserData',r.index);
                h.ButtonDownFcn = @(~,~)obj.openZone(r.index);
                t = text(obj.Axes,p(1),p(2),sprintf(' ROI %d',r.index),'Color',color, ...
                    'VerticalAlignment','bottom','FontWeight','bold','Interpreter','none');
                t.ButtonDownFcn = @(~,~)obj.openZone(r.index);
            end
            hold(obj.Axes,'off');
        end
        function setOutlines(obj,visible)
            obj.Overlays.Value = visible; obj.OverlayMenu.Checked = obj.onOff(visible); obj.render();
        end
        function resetView(obj)
            obj.RenderKey = ''; obj.render();
        end
        function reloadImage(obj)
            if isempty(obj.DisplayModel), return; end
            obj.DisplayModel.invalidate(); obj.render();
        end
        function layerSelected(obj,event)
            if isempty(event.Indices), return; end
            obj.Channels.Value = event.Indices(1,1); obj.render();
        end
        function soloLayer(obj)
            if isempty(obj.DisplayModel) || isempty(obj.DisplayModel.Layers), return; end
            obj.DisplayModel.solo(obj.Channels.Value); obj.render();
        end
        function layerVisibilityChanged(obj,event)
            obj.DisplayModel.setVisible(event.Indices(1),event.NewData); obj.render();
        end
        function editLayer(obj,action)
            if isempty(obj.DisplayModel), return; end
            index = obj.Channels.Value;
            try
                switch action
                    case 'limits', obj.DisplayModel.setLimits(index,[obj.MinField.Value obj.MaxField.Value]);
                    case 'range', obj.DisplayModel.setLimits(index,obj.ContrastSlider.Value);
                    case 'auto', obj.DisplayModel.autoContrast(index,obj.Frame.Value);
                    case 'opacity', obj.DisplayModel.setOpacity(index,obj.OpacitySlider.Value);
                    case 'color', obj.DisplayModel.setColor(index,obj.ColorField.Value);
                    case 'kind', obj.DisplayModel.setKind(index,obj.LayerKind.Value);
                end
                obj.render();
            catch err
                obj.refreshLayerControls(); obj.Status.Text = err.message;
            end
        end
        function refreshLayerControls(obj)
            layers = obj.DisplayModel.Layers;
            if isempty(layers), obj.clearLayerControls(); return; end
            obj.LayerTable.Data = [num2cell([layers.visible]'),{layers.name}'];
            index = obj.Channels.Value;
            layer = obj.DisplayModel.Layers(index);
            isLabel = strcmp(layer.kind,'Labels'); isRGB = strcmp(layer.kind,'RGB');
            if ~isLabel
                plane = obj.DisplayModel.read(index,obj.Frame.Value);
                layer = obj.DisplayModel.Layers(index);
            end
            if isRGB, obj.LayerKind.Items = {'RGB'};
            else, obj.LayerKind.Items = {'Intensity','Labels'}; end
            obj.LayerKind.Value = layer.kind; obj.LayerKind.Enable = obj.onOff(~isRGB);
            obj.ColorField.Value = layer.color; obj.ColorField.Enable = obj.onOff(~isRGB);
            obj.OpacitySlider.Value = layer.opacity; obj.OpacitySlider.Enable = 'on';
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
        end
        function clearLayerControls(obj)
            obj.LayerTable.Data = cell(0,2);
            for control = {obj.LayerKind,obj.ColorField,obj.MinField,obj.MaxField, ...
                    obj.ContrastSlider,obj.AutoButton,obj.OpacitySlider}
                item = control{1}; item.Enable = 'off';
            end
        end
        function copyImage(obj)
            try
                copygraphics(obj.Axes);
            catch err
                obj.Status.Text = err.message;
            end
        end
        function showError(obj,err)
            cla(obj.Axes); obj.RenderKey = ''; obj.CopyMenu.Enable = 'off';
            obj.Status.Text = err.message; obj.Status.Tooltip = err.message;
            title(obj.Axes,'Image unavailable');
        end
    end
    methods (Static, Access = private)
        function name = projectName(project)
            name = char(string(project.io.file));
            if isempty(name), name = 'Untitled Project'; end
        end
        function value = onOff(condition)
            if condition, value = 'on'; else, value = 'off'; end
        end
    end
end
