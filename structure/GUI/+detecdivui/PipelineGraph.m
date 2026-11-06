classdef PipelineGraph < handle
    % Compact, scrollable presentation of real pipeline edges and node states.
    properties
        OnSelect = []
        OnToggle = []
        OnStatus = []
        OnEdit = []
        OnChangeType = []
    end
    properties (SetAccess = private)
        Axes
        Model = struct()
    end
    properties (Access = private)
        Grid
        Revision = 0
        SelectedEdge = ''
        NodeMenus = gobjects(0)
    end
    methods
        function obj = PipelineGraph(parent,tag)
            obj.Grid = uigridlayout(parent,[1 1]);
            obj.Grid.Padding = [0 0 0 0]; obj.Grid.Scrollable = 'on';
            canvas = uipanel(obj.Grid,'BorderType','none');
            canvas.AutoResizeChildren = 'off';
            obj.Axes = uiaxes(canvas,'Tag',tag,'Visible','off','Units','pixels', ...
                'Toolbar',[],'Interactions',[]);
            obj.Axes.PositionConstraint = 'innerposition';
            canvas.SizeChangedFcn = @(~,~)obj.resizeCanvas();
            obj.resizeCanvas();
        end
        function show(obj,nodes,edges,selected,included,statuses)
            if nargin < 5, included = true(1,numel(nodes)); end
            if nargin < 6, statuses = repmat({''},1,numel(nodes)); end
            edges = detecdivui.PipelineBindings.edges(nodes,edges);
            obj.Model = struct('nodes',nodes,'edges',edges,'selected',selected, ...
                'included',included,'statuses',{statuses});
            layout = detecdivui.PipelineGraphLayout.build(nodes,edges);
            obj.Model.routes = layout.routes; obj.Model.issues = layout.issues;
            obj.Revision = obj.Revision+1; revision = obj.Revision;
            delete(obj.NodeMenus(isgraphics(obj.NodeMenus))); obj.NodeMenus = gobjects(0);
            active = find(strcmp({layout.routes.key},obj.SelectedEdge),1);
            if isempty(active), obj.SelectedEdge = ''; end
            ax = obj.Axes; cla(ax); hold(ax,'on'); n = numel(nodes);
            obj.Grid.RowHeight = {max(100,n*68+12)};
            ax.XLim = layout.xlim; ax.YLim = layout.ylim;
            if n == 0, hold(ax,'off'); return; end
            edgeColors = zeros(numel(layout.routes),3);
            edgeData = cell(1,numel(layout.routes));
            for k = 1:numel(layout.routes)
                r = layout.routes(k); [~,color] = obj.colors(obj.field(nodes(r.fromIndex),'type',''));
                if ~included(r.fromIndex) || ~included(r.toIndex), color = [.70 .72 .74]; end
                width = 1.4;
                if ~isempty(active)
                    if k == active, width = 2.8; else, color = color+(1-color)*.70; end
                end
                style = '-'; if r.resource, style = '--'; end
                data = struct('edgeIndex',r.edgeIndex,'from',edges(r.edgeIndex).from,'to',edges(r.edgeIndex).to, ...
                    'fromPort',obj.field(edges(r.edgeIndex),'fromPort',''),'toPort',obj.field(edges(r.edgeIndex),'toPort',''));
                edgeColors(k,:) = color; edgeData{k} = data;
                callback = @(~,~)obj.selectEdge(k,revision);
                plot(ax,r.x,r.y,'Color',color,'LineWidth',width,'LineStyle',style, ...
                    'Tag','pipeline-graph-edge','UserData',data,'ButtonDownFcn',callback);
                patch(ax,r.headX,r.headY,color,'EdgeColor','none', ...
                    'Tag','pipeline-graph-arrow','UserData',data,'ButtonDownFcn',callback);
            end
            for k = 1:n
                node = nodes(k); bounds = layout.bounds(k,:); y = bounds(2);
                menu = [];
                if ~isempty(obj.OnEdit) || ~isempty(obj.OnChangeType)
                    menu = uicontextmenu(ancestor(ax,'figure'),'Tag','pipeline-module-menu','UserData',node.id);
                    obj.NodeMenus(end+1) = menu;
                    if ~isempty(obj.OnEdit)
                        uimenu(menu,'Text','Edit Module...','Tag','pipeline-module-edit', ...
                            'MenuSelectedFcn',@(~,~)obj.edit(k,revision,false));
                    end
                    if ~isempty(obj.OnChangeType)
                        uimenu(menu,'Text','Change Type...','Tag','pipeline-module-change-type', ...
                            'MenuSelectedFcn',@(~,~)obj.edit(k,revision,true));
                    end
                end
                [face,edge] = obj.colors(obj.field(node,'type',''));
                if strcmp(statuses{k},'Added'), edge = [.15 .55 .30]; face = [.89 .97 .91];
                elseif strcmp(statuses{k},'Reused step'), edge = [.20 .45 .75]; face = [.89 .94 .99];
                elseif any(contains(statuses{k},{'unverified','partial','stale','Choose method'}))
                    edge = [.70 .46 .12]; face = [1 .96 .86];
                end
                if ~included(k), face = [.94 .94 .94]; edge = [.70 .70 .70]; end
                width = 1; if selected == k, width = 2.5; end
                if ~isempty(active) && any(k == [layout.routes(active).fromIndex layout.routes(active).toIndex]), width = max(width,2); end
                rectangle(ax,'Position',bounds,'Curvature',.10, ...
                    'FaceColor',face,'EdgeColor',edge,'LineWidth',width, ...
                    'Tag','pipeline-graph-node','UserData',k,'ContextMenu',menu, ...
                    'ButtonDownFcn',@(~,~)obj.select(k,revision));
                name = char(string(obj.field(node,'name',node.id)));
                text(ax,bounds(1)+.06,y+.49,name,'Interpreter','none','FontSize',11,'FontWeight','bold', ...
                    'Tag','pipeline-graph-name','UserData',name,'ContextMenu',menu, ...
                    'Color',[.14 .18 .22],'ButtonDownFcn',@(~,~)obj.select(k,revision));
                state = obj.field(node,'type','');
                if ~isempty(statuses{k})
                    if any(strcmp(state,{'resource','question'})), state = statuses{k};
                    else, state = [char(string(state)) ' · ' statuses{k}]; end
                end
                state = char(string(state));
                text(ax,bounds(1)+.06,y+.20,state,'Interpreter','none','FontSize',10, ...
                    'Tag','pipeline-graph-state','UserData',state,'ContextMenu',menu, ...
                    'Color',[.35 .39 .43],'ButtonDownFcn',@(~,~)obj.select(k,revision));
                if ~isempty(obj.OnToggle)
                    mark = '□'; if included(k), mark = '☑'; end
                    text(ax,.01,y+.38,mark,'FontSize',18,'Color',edge, ...
                        'Tag','pipeline-graph-toggle','UserData',k, ...
                        'ButtonDownFcn',@(~,~)obj.toggle(k,revision));
                end
            end
            for k = 1:numel(layout.routes)
                r = layout.routes(k); color = edgeColors(k,:);
                plot(ax,r.source(1),r.source(2),'o','MarkerSize',4,'MarkerEdgeColor',color, ...
                    'MarkerFaceColor',color,'Tag','pipeline-graph-source', ...
                    'UserData',edgeData{k}, ...
                    'ButtonDownFcn',@(~,~)obj.selectEdge(k,revision));
            end
            hold(ax,'off');
            obj.resizeCanvas();
            if ~isempty(layout.issues), detecdivui.Callback.call(obj.OnStatus,strjoin(layout.issues,'; ')); end
        end
    end
    methods (Access = private)
        function resizeCanvas(obj)
            if isempty(obj.Axes) || ~isgraphics(obj.Axes), return; end
            canvas = obj.Axes.Parent; size = canvas.InnerPosition(3:4);
            obj.Axes.InnerPosition = [1 1 max(1,size(1)) max(1,size(2))];
            textWidth = max(0,.74-16*diff(obj.Axes.XLim)/max(1,size(1)));
            tags = {'pipeline-graph-name','pipeline-graph-state'};
            for k = 1:numel(tags)
                labels = findall(obj.Axes,'Tag',tags{k});
                for label = reshape(labels,1,[])
                    value = label.UserData; label.String = value;
                    extent = label.Extent;
                    if extent(3) <= textWidth, continue; end
                    % Measure the rendered font rather than limiting wide
                    % cards to a fixed number of characters.
                    low = 0; high = max(0,numel(value)-1);
                    while low < high
                        middle = ceil((low+high)/2);
                        label.String = [value(1:middle) '…']; extent = label.Extent;
                        if extent(3) <= textWidth, low = middle; else, high = middle-1; end
                    end
                    label.String = [value(1:low) '…']; extent = label.Extent;
                    if extent(3) > textWidth, label.String = ''; end
                end
            end
        end
        function select(obj,index,revision)
            if revision ~= obj.Revision, return; end
            obj.SelectedEdge = '';
            detecdivui.Callback.call(obj.OnSelect,index);
        end
        function toggle(obj,index,revision)
            if revision ~= obj.Revision, return; end
            detecdivui.Callback.call(obj.OnToggle,index);
        end
        function edit(obj,index,revision,changeType)
            if revision ~= obj.Revision, return; end
            if changeType, callback = obj.OnChangeType; else, callback = obj.OnEdit; end
            detecdivui.Callback.call(callback,index);
        end
        function selectEdge(obj,index,revision)
            if revision ~= obj.Revision, return; end
            r = obj.Model.routes(index); obj.SelectedEdge = r.key;
            edge = obj.Model.edges(r.edgeIndex); source = char(string(edge.from)); target = char(string(edge.to));
            fromPort = obj.field(edge,'fromPort',''); toPort = obj.field(edge,'toPort','');
            if ~isempty(fromPort), source = [source '.' char(string(fromPort))]; end
            if ~isempty(toPort), target = [target '.' char(string(toPort))]; end
            model = obj.Model;
            obj.show(model.nodes,model.edges,model.selected,model.included,model.statuses);
            prefix = ''; if r.resource, prefix = 'Binding: '; end
            detecdivui.Callback.call(obj.OnStatus,[prefix source ' → ' target]);
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
