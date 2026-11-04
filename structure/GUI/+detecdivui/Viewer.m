classdef Viewer < handle
    % Experimental MATLAB shell. Layout is code-owned until UX validation.
    properties (SetAccess = private)
        Session
        Figure
    end
    properties (Access = private)
        Positions
        Zones
        Channels
        Frame
        Crumb
        Status
        Axes
    end
    methods
        function obj = Viewer(project, visibility)
            if nargin < 1, project = []; end
            if nargin < 2, visibility = 'on'; end
            obj.Session = detecdivui.Session();
            obj.Figure = uifigure('Name','DetecDiv — espace de travail expérimental', ...
                'Position',[100 100 1200 760], 'Visible',visibility);
            obj.Figure.CloseRequestFcn = @(~,~)delete(obj);
            grid = uigridlayout(obj.Figure,[4 3]);
            grid.RowHeight = {36,32,'1x',36};
            grid.ColumnWidth = {220,'1x',220};
            uibutton(grid,'Text','Ouvrir une expérience', ...
                'ButtonPushedFcn',@(~,~)obj.openProject());
            obj.Crumb = uilabel(grid,'Text','Ouvrir une expérience pour commencer');
            obj.Crumb.Layout.Column = [2 3];
            steps = uilabel(grid,'Text', ...
                'Explorer  →  Choisir les zones  →  Segmenter et suivre  →  Réviser  →  Mesurer');
            steps.Layout.Row = 2; steps.Layout.Column = [1 3];
            nav = uigridlayout(grid,[4 1]);
            nav.Layout.Row = 3; nav.Layout.Column = 1;
            nav.RowHeight = {22,'1x',22,'1x'};
            uilabel(nav,'Text','Positions');
            obj.Positions = uilistbox(nav,'Items',{}, ...
                'ValueChangedFcn',@(~,~)obj.changePosition());
            uilabel(nav,'Text','Zones d''analyse');
            obj.Zones = uilistbox(nav,'Items',{}, ...
                'ValueChangedFcn',@(~,~)obj.changeZone());
            obj.Axes = uiaxes(grid);
            obj.Axes.Layout.Row = 3; obj.Axes.Layout.Column = 2;
            obj.Axes.XTick = []; obj.Axes.YTick = [];
            tools = uigridlayout(grid,[5 1]);
            tools.Layout.Row = 3; tools.Layout.Column = 3;
            tools.RowHeight = {30,22,30,70,'1x'};
            uibutton(tools,'Text','Revenir à la position', ...
                'ButtonPushedFcn',@(~,~)obj.returnToPosition());
            uilabel(tools,'Text','Canal / plan');
            obj.Channels = uidropdown(tools,'Items',{'—'}, ...
                'ValueChangedFcn',@(~,~)obj.render());
            uilabel(tools,'Text', ...
                'Prototype de navigation. Les outils d''analyse seront intégrés progressivement.', ...
                'WordWrap','on');
            obj.Frame = uieditfield(grid,'numeric','Value',1,'Limits',[1 Inf], ...
                'RoundFractionalValues','on','ValueChangedFcn',@(~,~)obj.render());
            obj.Frame.Layout.Row = 4; obj.Frame.Layout.Column = 1;
            obj.Frame.Tooltip = 'Image temporelle';
            obj.Status = uilabel(grid,'Text','Aucune expérience ouverte');
            obj.Status.Layout.Row = 4; obj.Status.Layout.Column = [2 3];
            if ~isempty(project), obj.attachProject(project); end
        end
        function delete(obj)
            if ~isempty(obj.Figure) && isvalid(obj.Figure), delete(obj.Figure); end
        end
    end
    methods (Access = private)
        function openProject(obj)
            try
                project = shallowLoad();
                if ~isempty(project), obj.attachProject(project); end
            catch err
                obj.showError(err);
            end
        end
        function attachProject(obj, project)
            obj.Session.setProject(project);
            n = numel(project.fov);
            obj.Positions.Items = cellstr(compose('Position %d',1:n));
            obj.Positions.ItemsData = 1:n;
            obj.Positions.Value = 1;
            obj.refreshZones();
            obj.refreshView();
        end
        function changePosition(obj)
            obj.Session.selectPosition(obj.Positions.Value);
            obj.refreshZones(); obj.refreshView();
        end
        function refreshZones(obj)
            n = numel(obj.Session.Project.fov(obj.Session.Position).roi);
            obj.Zones.Items = [{'Vue de la position'}, cellstr(compose('Zone %d',1:n))];
            obj.Zones.ItemsData = 0:n;
            obj.Zones.Value = 0;
        end
        function changeZone(obj)
            obj.Session.selectZone(obj.Zones.Value);
            obj.refreshView();
        end
        function returnToPosition(obj)
            if isempty(obj.Session.Project), return; end
            obj.Session.selectZone(0); obj.Zones.Value = 0; obj.refreshView();
        end
        function refreshView(obj)
            obj.Crumb.Text = obj.Session.breadcrumb();
            try
                oldChannel = obj.Channels.Value;
                [names, frames] = obj.Session.dimensions();
                if isempty(names), names = {'—'}; end
                obj.Channels.Items = names;
                if any(strcmp(names,oldChannel)), obj.Channels.Value = oldChannel; end
                obj.Frame.Value = min(obj.Frame.Value, frames);
                obj.render();
            catch err
                obj.showError(err);
            end
        end
        function render(obj)
            if isempty(obj.Session.Project), return; end
            try
                channel = find(strcmp(obj.Channels.Items,obj.Channels.Value),1);
                plane = obj.Session.readPlane(obj.Frame.Value,channel);
                assert(~isempty(plane),'detecdivui:EmptyImage', ...
                    'Image indisponible. Vérifiez les sources et le canal sélectionné.');
                imagesc(obj.Axes,plane); colormap(obj.Axes,gray(256));
                axis(obj.Axes,'image'); obj.Axes.XTick = []; obj.Axes.YTick = [];
                obj.Status.Text = sprintf('Image %d — %s',obj.Frame.Value,obj.Channels.Value);
            catch err
                obj.showError(err);
            end
        end
        function showError(obj,err)
            cla(obj.Axes);
            obj.Status.Text = err.message;
            title(obj.Axes,'Image indisponible');
        end
    end
end
