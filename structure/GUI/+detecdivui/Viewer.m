classdef Viewer < handle
    % Experimental shell. UI widgets adapt legacy readers through Session.
    properties (SetAccess = private)
        Session
        Figure
    end
    properties (Access = private)
        Positions
        Zones
        Channels
        Frame
        TimeSlider
        FrameCount
        Previous
        Next
        Crumb
        Status
        Guidance
        Back
        Axes
        Main
        Browser
        Tools
        Overlays
        SelectedZone = 0
        RenderKey = ''
        MaxFrame = 1
    end
    methods
        function obj = Viewer(project, visibility)
            if nargin < 1, project = []; end
            if nargin < 2, visibility = 'on'; end
            obj.Session = detecdivui.Session();
            obj.Figure = uifigure('Name','DetecDiv — Explorer', ...
                'Position',[80 80 1380 840], 'Visible',visibility, ...
                'Color',[0.95 0.96 0.97]);
            obj.Figure.CloseRequestFcn = @(~,~)delete(obj);
            root = uigridlayout(obj.Figure,[4 1]);
            root.RowHeight = {48,36,'1x',28};
            root.Padding = [12 8 12 8];
            root.BackgroundColor = [0.95 0.96 0.97];
            header = uigridlayout(root,[1 5]);
            header.ColumnWidth = {120,200,'1x',100,100};
            header.Padding = [0 0 0 0];
            uilabel(header,'Text','DetecDiv','FontSize',23,'FontWeight','bold');
            uibutton(header,'Text','Ouvrir une expérience', ...
                'ButtonPushedFcn',@(~,~)obj.openProject());
            uilabel(header,'Text','Explorer les images','FontSize',16,'FontColor',[0.1 0.4 0.5]);
            uibutton(header,'state','Text','Données','Value',true, ...
                'ValueChangedFcn',@(src,~)obj.togglePanel('browser',src.Value));
            uibutton(header,'state','Text','Outils','Value',true, ...
                'ValueChangedFcn',@(src,~)obj.togglePanel('tools',src.Value));
            location = uigridlayout(root,[1 2]);
            location.ColumnWidth = {150,'1x'}; location.Padding = [0 0 0 0];
            obj.Back = uibutton(location,'Text','← Position','Enable','off', ...
                'ButtonPushedFcn',@(~,~)obj.returnToPosition());
            obj.Crumb = uilabel(location,'Text','Votre espace de travail', ...
                'Interpreter','none','FontSize',13);
            obj.Main = uigridlayout(root,[1 3]);
            obj.Main.ColumnWidth = {224,'1x',252}; obj.Main.Padding = [0 0 0 0];
            obj.Browser = uipanel(obj.Main,'Title','Données de l’expérience');
            nav = uigridlayout(obj.Browser,[5 1]);
            nav.RowHeight = {22,'1x',22,'1x',42};
            uilabel(nav,'Text','Positions','FontWeight','bold');
            obj.Positions = uilistbox(nav,'Items',{},'Enable','off','Tag','positions', ...
                'ValueChangedFcn',@(~,~)obj.changePosition());
            uilabel(nav,'Text','Zones d’analyse','FontWeight','bold');
            obj.Zones = uilistbox(nav,'Items',{},'Enable','off','Tag','zones', ...
                'ValueChangedFcn',@(~,~)obj.changeZone());
            uilabel(nav,'Text','Cliquez sur une zone dans la liste ou directement dans l’image.', ...
                'WordWrap','on','FontColor',[0.4 0.45 0.5]);
            canvas = uigridlayout(obj.Main,[2 1]);
            canvas.RowHeight = {'1x',66}; canvas.Padding = [0 0 0 0];
            obj.Axes = uiaxes(canvas,'Color',[0.07 0.09 0.11],'Tag','image-view');
            obj.Axes.XTick = []; obj.Axes.YTick = [];
            obj.Axes.Toolbar.Visible = 'on';
            title(obj.Axes,'Ouvrez une expérience pour explorer ses images');
            timeline = uigridlayout(canvas,[2 5]);
            timeline.RowHeight = {26,22};
            timeline.ColumnWidth = {32,32,80,'1x',90}; timeline.Padding = [0 0 0 0];
            obj.Previous = uibutton(timeline,'Text','‹','Enable','off', ...
                'Tooltip','Image précédente','ButtonPushedFcn',@(~,~)obj.stepFrame(-1));
            obj.Next = uibutton(timeline,'Text','›','Enable','off', ...
                'Tooltip','Image suivante','ButtonPushedFcn',@(~,~)obj.stepFrame(1));
            obj.Frame = uieditfield(timeline,'numeric','Value',1,'Limits',[1 Inf], ...
                'RoundFractionalValues','on','Enable','off','Tag','frame-number', ...
                'Tooltip','Image temporelle','ValueChangedFcn',@(~,~)obj.render());
            obj.FrameCount = uilabel(timeline,'Text','/ 1');
            obj.FrameCount.Layout.Column = 5;
            obj.TimeSlider = uislider(timeline,'Limits',[1 2],'Value',1, ...
                'MajorTicks',[],'MinorTicks',[],'Enable','off','Tag','time-slider', ...
                'ValueChangedFcn',@(src,~)obj.setFrame(round(src.Value)));
            obj.TimeSlider.Layout.Row = 2; obj.TimeSlider.Layout.Column = [1 5];
            obj.Tools = uipanel(obj.Main,'Title','Affichage et navigation');
            tools = uigridlayout(obj.Tools,[9 1]);
            tools.RowHeight = {22,30,30,32,22,120,30,'1x',50};
            uilabel(tools,'Text','Canal','FontWeight','bold');
            obj.Channels = uidropdown(tools,'Items',{'—'},'ItemsData',1, ...
                'Enable','off','Tag','channels', ...
                'ValueChangedFcn',@(~,~)obj.render());
            obj.Overlays = uicheckbox(tools,'Text','Zones de référence','Value',true, ...
                'Enable','off','Tag','reference-zones','ValueChangedFcn',@(~,~)obj.render());
            obj.Overlays.Tooltip = 'Contours de référence enregistrés, sans correction temporelle de dérive.';
            uibutton(tools,'Text','Ajuster l’image à la vue', ...
                'ButtonPushedFcn',@(~,~)obj.resetView());
            uilabel(tools,'Text','Pour continuer','FontWeight','bold');
            obj.Guidance = uilabel(tools,'Text', ...
                'Ouvrez une expérience existante, puis choisissez une position.', ...
                'WordWrap','on','VerticalAlignment','top');
            uilabel(tools,'Text','Explorer → Zones → Analyser','FontColor',[0.4 0.45 0.5]);
            note = uilabel(tools,'Text','Les réglages de cette vue ne modifient pas les données.', ...
                'WordWrap','on','FontColor',[0.4 0.45 0.5]);
            note.Layout.Row = 9;
            obj.Status = uilabel(root,'Text','Aucune expérience ouverte', ...
                'Interpreter','none','Tag','status');
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
            obj.SelectedZone = 0; obj.RenderKey = '';
            [labels, indices] = obj.Session.positionItems();
            obj.setList(obj.Positions,labels,indices,obj.Session.Position);
            obj.refreshZones(); obj.refreshView();
        end
        function changePosition(obj)
            obj.Session.selectPosition(obj.Positions.Value);
            obj.SelectedZone = 0;
            obj.refreshZones(); obj.refreshView();
        end
        function refreshZones(obj)
            [labels, indices] = obj.Session.zoneItems();
            if obj.Session.Position == 0
                obj.setList(obj.Zones,{},[],0);
            else
                obj.setList(obj.Zones,[{'Vue de la position'},labels],[0 indices],obj.Session.Zone);
            end
        end
        function changeZone(obj)
            obj.openZone(obj.Zones.Value);
        end
        function openZone(obj,index)
            obj.Session.selectZone(index);
            if index > 0, obj.SelectedZone = index; end
            obj.Zones.Value = index;
            obj.refreshView();
        end
        function returnToPosition(obj)
            if obj.Session.Position == 0, return; end
            obj.openZone(0);
        end
        function refreshView(obj)
            obj.Crumb.Text = obj.Session.breadcrumb();
            obj.Back.Enable = obj.onOff(obj.Session.Zone > 0);
            obj.Overlays.Enable = obj.onOff(obj.Session.Position > 0 && obj.Session.Zone == 0);
            if obj.Session.Position == 0
                obj.setControls({},1);
                cla(obj.Axes); obj.RenderKey = '';
                title(obj.Axes,'Aucune position à afficher');
                obj.Status.Text = 'Cette expérience ne contient pas encore de données à explorer.';
                obj.Guidance.Text = 'Ouvrez une expérience contenant des images ou des zones d’analyse.';
                return;
            end
            try
                [names, frames] = obj.Session.dimensions();
                obj.setControls(names,frames);
                if obj.Session.Zone == 0
                    [~, zones] = obj.Session.zoneItems();
                    obj.Guidance.Text = sprintf(['%d zone(s) dans cette position. ' ...
                        'Cliquez sur un contour ou choisissez une zone dans la liste pour l’examiner.'],numel(zones));
                else
                    obj.Guidance.Text = ['Vous examinez les pixels de cette zone. ' ...
                        'Parcourez le temps ou changez de canal. « Position » vous ramène au champ complet.'];
                end
                obj.render();
            catch err
                obj.setControls({},1);
                obj.Guidance.Text = 'Les pixels de cette zone sont indisponibles. Revenez à la position ou vérifiez son extraction.';
                obj.showError(err);
            end
        end
        function setControls(obj,names,frames)
            oldName = '';
            if ~isempty(obj.Channels.ItemsData) && obj.Channels.Value <= numel(obj.Channels.Items)
                oldName = obj.Channels.Items{obj.Channels.Value};
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
            obj.MaxFrame = frames;
            obj.Frame.Value = min(obj.Frame.Value,frames);
            obj.Frame.Enable = obj.onOff(available && frames > 1);
            obj.FrameCount.Text = sprintf('/ %d',frames);
            obj.TimeSlider.Limits = [1 max(2,frames)];
            obj.TimeSlider.Value = obj.Frame.Value;
            obj.TimeSlider.Enable = obj.onOff(available && frames > 1);
            obj.Previous.Enable = obj.onOff(available && obj.Frame.Value > 1);
            obj.Next.Enable = obj.onOff(available && obj.Frame.Value < frames);
        end
        function setFrame(obj,frame)
            obj.Frame.Value = min(max(1,frame),obj.MaxFrame);
            obj.render();
        end
        function stepFrame(obj,delta)
            obj.setFrame(obj.Frame.Value+delta);
        end
        function render(obj)
            if obj.Session.Position == 0, return; end
            try
                obj.Frame.Value = min(obj.Frame.Value,obj.MaxFrame);
                obj.TimeSlider.Value = obj.Frame.Value;
                obj.Previous.Enable = obj.onOff(obj.Frame.Value > 1);
                obj.Next.Enable = obj.onOff(obj.Frame.Value < obj.MaxFrame);
                plane = obj.Session.readPlane(obj.Frame.Value,obj.Channels.Value);
                assert(~isempty(plane),'detecdivui:EmptyImage', ...
                    'Image indisponible. Vérifiez les sources et le canal sélectionné.');
                key = sprintf('%d:%d',obj.Session.Position,obj.Session.Zone);
                keepView = strcmp(key,obj.RenderKey);
                xl = obj.Axes.XLim; yl = obj.Axes.YLim;
                cla(obj.Axes);
                if size(plane,3) == 3
                    image(obj.Axes,plane);
                else
                    imagesc(obj.Axes,plane); colormap(obj.Axes,gray(256));
                end
                axis(obj.Axes,'image'); obj.Axes.XTick = []; obj.Axes.YTick = [];
                title(obj.Axes,'');
                if obj.Session.Zone == 0 && obj.Overlays.Value, obj.drawRegions(); end
                % Reestablish limits explicitly: UIAxes can retain [0 1]
                % after an empty/error view or transitions through patches.
                obj.Axes.YDir = 'reverse';
                if keepView
                    obj.Axes.XLim = xl; obj.Axes.YLim = yl;
                else
                    obj.Axes.XLim = [0.5 size(plane,2)+0.5];
                    obj.Axes.YLim = [0.5 size(plane,1)+0.5];
                end
                if size(plane,3) ~= 3
                    finitePixels = plane(isfinite(plane));
                    limits = [0 1];
                    if ~isempty(finitePixels)
                        limits = double([min(finitePixels(:)) max(finitePixels(:))]);
                        if limits(2) <= limits(1), limits(2) = limits(1)+1; end
                    end
                    obj.Axes.CLim = limits;
                end
                obj.RenderKey = key;
                source = 'Champ brut';
                if obj.Session.Zone > 0, source = 'Zone · pixels chargés'; end
                obj.Status.Text = sprintf('%s · Image %d / %d · %s',source, ...
                    obj.Frame.Value,obj.MaxFrame,obj.Channels.Items{obj.Channels.Value});
                obj.Status.Tooltip = obj.Status.Text;
            catch err
                obj.showError(err);
            end
        end
        function drawRegions(obj)
            regions = obj.Session.referenceRegions();
            hold(obj.Axes,'on');
            for k = 1:numel(regions)
                r = regions(k); p = r.position;
                color = [0.25 0.9 0.85];
                if r.index == obj.SelectedZone, color = [1 0.8 0.25]; end
                h = patch(obj.Axes,p(1)+[0 p(3) p(3) 0],p(2)+[0 0 p(4) p(4)],color, ...
                    'FaceAlpha',0.025,'EdgeColor',color,'LineWidth',1.5, ...
                    'Tag','zone-overlay','UserData',r.index);
                h.ButtonDownFcn = @(~,~)obj.openZone(r.index);
                t = text(obj.Axes,p(1),p(2),sprintf(' %d',r.index),'Color',color, ...
                    'VerticalAlignment','bottom','FontWeight','bold','Interpreter','none');
                t.ButtonDownFcn = @(~,~)obj.openZone(r.index);
            end
            hold(obj.Axes,'off');
        end
        function resetView(obj)
            obj.RenderKey = ''; obj.render();
        end
        function togglePanel(obj,which,visible)
            if strcmp(which,'browser')
                obj.Browser.Visible = obj.onOff(visible);
                obj.Main.ColumnWidth{1} = 224*double(visible);
            else
                obj.Tools.Visible = obj.onOff(visible);
                obj.Main.ColumnWidth{3} = 252*double(visible);
            end
        end
        function showError(obj,err)
            cla(obj.Axes); obj.RenderKey = '';
            obj.Status.Text = err.message; obj.Status.Tooltip = err.message;
            title(obj.Axes,'Image indisponible');
        end
    end
    methods (Static, Access = private)
        function setList(list,labels,indices,selected)
            list.ItemsData = [];
            list.Items = labels;
            list.ItemsData = indices;
            list.Enable = detecdivui.Viewer.onOff(~isempty(indices));
            if ~isempty(indices), list.Value = selected; end
        end
        function value = onOff(condition)
            if condition, value = 'on'; else, value = 'off'; end
        end
    end
end
