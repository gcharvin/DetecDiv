classdef PipelineGraph < handle
    % Compact, scrollable presentation of real pipeline edges and node states.
    properties
        OnSelect = []
        OnToggle = []
    end
    properties (SetAccess = private)
        Axes
        Model = struct()
    end
    properties (Access = private)
        Grid
    end
    methods
        function obj = PipelineGraph(parent,tag)
            obj.Grid = uigridlayout(parent,[1 1]);
            obj.Grid.Padding = [0 0 0 0]; obj.Grid.Scrollable = 'on';
            canvas = uipanel(obj.Grid,'BorderType','none');
            obj.Axes = uiaxes(canvas,'Tag',tag,'Visible','off','Units','normalized');
            obj.Axes.Toolbar.Visible = 'off'; disableDefaultInteractivity(obj.Axes);
            obj.Axes.PositionConstraint = 'innerposition'; obj.Axes.InnerPosition = [0 0 1 1];
        end
        function show(obj,nodes,edges,selected,included,statuses)
            if nargin < 5, included = true(1,numel(nodes)); end
            if nargin < 6, statuses = repmat({''},1,numel(nodes)); end
            obj.Model = struct('nodes',nodes,'edges',edges,'selected',selected, ...
                'included',included,'statuses',{statuses});
            ax = obj.Axes; cla(ax); hold(ax,'on'); n = numel(nodes);
            obj.Grid.RowHeight = {max(100,n*68+12)};
            ax.XLim = [0 1]; ax.YLim = [0 max(1,n)];
            if n == 0, hold(ax,'off'); return; end
            ids = cellstr(string({nodes.id}));
            % Node order stays stable; side routes also show branches/back edges.
            for k = 1:numel(edges)
                a = find(strcmp(ids,char(string(edges(k).from))),1);
                b = find(strcmp(ids,char(string(edges(k).to))),1);
                if isempty(a) || isempty(b), continue; end
                y1 = n-a+.5; y2 = n-b+.5; lane = .07+.025*mod(k-1,3);
                plot(ax,[.20 lane lane .18],[y1 y1 y2 y2],'Color',[.60 .65 .70], ...
                    'HitTest','off','PickableParts','none');
                patch(ax,[.20 .17 .17],[y2 y2+.065 y2-.065],[.60 .65 .70], ...
                    'EdgeColor','none','HitTest','off','PickableParts','none');
            end
            for k = 1:n
                node = nodes(k); y = n-k+.13;
                [face,edge] = obj.colors(obj.field(node,'type',''));
                if ~included(k), face = [.94 .94 .94]; edge = [.70 .70 .70]; end
                width = 1; if selected == k, width = 2.5; end
                rectangle(ax,'Position',[.20 y .77 .74],'Curvature',.10, ...
                    'FaceColor',face,'EdgeColor',edge,'LineWidth',width, ...
                    'Tag','pipeline-graph-node','UserData',k, ...
                    'ButtonDownFcn',@(~,~)obj.select(k));
                name = char(string(obj.field(node,'name',node.id)));
                if strlength(string(name)) > 22, name = [name(1:20) '…']; end
                text(ax,.27,y+.49,name,'Interpreter','none','FontSize',11,'FontWeight','bold', ...
                    'Color',[.14 .18 .22],'ButtonDownFcn',@(~,~)obj.select(k));
                state = obj.field(node,'type','');
                if ~isempty(statuses{k}), state = [char(string(state)) ' · ' statuses{k}]; end
                state = char(string(state));
                if numel(state) > 24, state = [state(1:22) '…']; end
                text(ax,.27,y+.20,state,'Interpreter','none','FontSize',10, ...
                    'Color',[.35 .39 .43],'ButtonDownFcn',@(~,~)obj.select(k));
                if ~isempty(obj.OnToggle)
                    mark = '□'; if included(k), mark = '☑'; end
                    text(ax,.01,y+.38,mark,'FontSize',18,'Color',edge, ...
                        'Tag','pipeline-graph-toggle','UserData',k, ...
                        'ButtonDownFcn',@(~,~)obj.toggle(k));
                end
            end
            hold(ax,'off');
        end
    end
    methods (Access = private)
        function select(obj,index)
            if ~isempty(obj.OnSelect), obj.OnSelect(index); end
        end
        function toggle(obj,index)
            if ~isempty(obj.OnToggle), obj.OnToggle(index); end
        end
    end
    methods (Static, Access = private)
        function value = field(s,key,default)
            value = default; if isfield(s,key) && ~isempty(s.(key)), value = s.(key); end
        end
        function [face,edge] = colors(type)
            switch lower(char(string(type)))
                case 'dataloader', edge = [.26 .45 .68];
                case {'roipattern','roiidentify','roigrid','roimanual','roitracked'}, edge = [.22 .55 .42];
                case 'roiextract', edge = [.49 .42 .72];
                case 'classifier', edge = [.78 .46 .20];
                case 'processor', edge = [.10 .58 .62];
                otherwise, edge = [.34 .42 .52];
            end
            face = edge+(1-edge)*.86;
        end
    end
end
