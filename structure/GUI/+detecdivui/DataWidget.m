classdef DataWidget < handle
    % Read-only dataseries browsing using Score's extraction/rendering helpers.
    properties (SetAccess = private)
        Progress
        Series = {}
        Axes
    end
    properties (Access = private)
        Viewer
        Source = []
        Target
        Dataset
        Variable
        Group
        Units
        Interval
        Load
        Status
        Proxy
        PlotLines = gobjects(0)
        Marker = []
        SelectedData = []
        Temporal = false
        Sync = false
        Step = 1
        Token = 0
    end
    methods
        function obj = DataWidget(parent,viewer)
            obj.Viewer = viewer; obj.Proxy = roi('data-view',[]);
            grid = uigridlayout(parent,[4 1]); grid.Padding = [6 6 6 6]; grid.RowHeight = {24,28,'1x',24};
            header = uigridlayout(grid,[1 2]); header.Padding = [0 0 0 0]; header.ColumnWidth = {'1x',100};
            obj.Target = uilabel(header,'Text','—','Interpreter','none','Tag','data-target');
            obj.Load = uibutton(header,'Text','Load Data','Enable','off','Tag','data-load', ...
                'Tooltip','Load ROI dataseries; preserve data already cached in the project', ...
                'ButtonPushedFcn',@(~,~)obj.loadData());
            controls = uigridlayout(grid,[1 5]); controls.Padding = [0 0 0 0];
            controls.ColumnWidth = {'1x','1x','1x',85,75};
            obj.Dataset = uidropdown(controls,'Items',{'—'},'Tag','data-series', ...
                'Tooltip','ROI dataseries','ValueChangedFcn',@(~,~)obj.selectSeries());
            obj.Variable = uidropdown(controls,'Items',{'—'},'Tag','data-variable', ...
                'Tooltip','Variable; vector cells expand into separate curves', ...
                'ValueChangedFcn',@(~,~)obj.selectVariable());
            obj.Group = uidropdown(controls,'Items',{'Variable'},'Tag','data-group', ...
                'Tooltip','Saved Score plot group','ValueChangedFcn',@(~,~)obj.plot());
            obj.Units = uidropdown(controls,'Items',{'Frames','Minutes'},'Tag','data-time-units', ...
                'ValueChangedFcn',@(~,~)obj.plot());
            obj.Interval = uieditfield(controls,'numeric','Value',1,'Limits',[eps Inf], ...
                'Tag','data-interval','Tooltip','Acquisition interval in minutes per frame; display only', ...
                'ValueChangedFcn',@(~,~)obj.plot());
            obj.Axes = uiaxes(grid,'Tag','data-axes');
            obj.Status = uilabel(grid,'Text','Ready','Interpreter','none','Tag','data-status');
            obj.Progress = detecdivui.Progress(grid,obj.Status,'data-progress');
            obj.setContext();
        end
        function setContext(obj)
            % Metadata selection can precede image loading; obtain the ROI
            % handle without asking for image dimensions or raw sources.
            session = obj.Viewer.Session;
            source = [];
            if session.Zone > 0, source = session.Project.fov(session.Position).roi(session.Zone); end
            if obj.Token > 0 && isequal(source,obj.Source), obj.onFrame(); return; end
            obj.Source = source; obj.Token = obj.Token+1; obj.Series = {};
            obj.SelectedData = []; obj.clearPlot();
            obj.resetControls();
            obj.Load.Enable = obj.onOff(~isempty(source)); obj.Target.Text = '—';
            if isempty(source), obj.status('Select a ROI'); return; end
            obj.Target.Text = source.id; obj.Target.Tooltip = source.path;
            interval = session.Project.fov(session.Position).interval;
            if isnumeric(interval) && isscalar(interval) && isfinite(interval) && interval > 0, obj.Interval.Value = interval; end
            obj.status('Ready');
        end
        function loadData(obj)
            if isempty(obj.Source), return; end
            scope = obj.Progress.begin('Loading ROI dataseries...'); %#ok<NASGU>
            try
                source = obj.Source; data = source.data;
                meaningful = obj.meaningful(data);
                if isempty(meaningful)
                    scratch = roi(source.id,source.value); scratch.path = source.path;
                    scratch.load('data','Silent'); data = scratch.data; meaningful = obj.meaningful(data);
                end
                series = cell(1,numel(meaningful)); names = series;
                for k = 1:numel(meaningful)
                    original = data(meaningful(k)); ds = dataseries();
                    fields = properties(original);
                    for j = 1:numel(fields), ds.(fields{j}) = original.(fields{j}); end
                    series{k} = ds; name = char(string(ds.groupid));
                    if isempty(name), name = char(string(ds.id)); end
                    names{k} = name;
                end
                obj.Series = series; obj.Token = obj.Token+1;
                if isempty(series), obj.resetSeries(); obj.status('No dataseries'); return; end
                obj.Dataset.ItemsData = []; obj.Dataset.Items = matlab.lang.makeUniqueStrings(names);
                obj.Dataset.ItemsData = 1:numel(series); obj.Dataset.Value = 1; obj.Dataset.Enable = 'on';
                obj.selectSeries();
            catch err, obj.resetSeries(); obj.status(err.message);
            end
        end
        function onFrame(obj)
            if ~isempty(obj.SelectedData) && obj.Temporal && ...
                    obj.Sync ~= (height(obj.SelectedData.data) == obj.Viewer.annotationFrameCount())
                obj.plot(); return;
            end
            if isempty(obj.SelectedData) || ~obj.Sync || ~isgraphics(obj.Marker), return; end
            frame = obj.Viewer.annotationFrame(); x = frame*obj.Step; obj.Marker.Value = x;
            for handle = reshape(obj.PlotLines,1,[])
                if ~isgraphics(handle) || ~isstruct(handle.UserData) || ~isfield(handle.UserData,'LinkedLine'), continue; end
                curve = handle.UserData.LinkedLine;
                if isgraphics(curve) && frame >= 1 && frame <= numel(curve.YData)
                    handle.XData = x; handle.YData = curve.YData(frame); handle.Visible = 'on';
                else
                    handle.Visible = 'off';
                end
            end
        end
        function click(obj,token)
            if token ~= obj.Token || ~obj.Sync || isempty(obj.Source), return; end
            x = obj.Axes.CurrentPoint(1,1); obj.navigate(x);
        end
        function navigate(obj,x)
            if ~obj.Sync, return; end
            obj.Viewer.navigateDataFrame(obj.Source,round(x/obj.Step));
        end
        function delete(obj)
            obj.Series = {};
        end
    end
    methods (Access = private)
        function selectSeries(obj)
            ds = obj.Series{obj.Dataset.Value}; variables = ds.data.Properties.VariableNames;
            obj.SelectedData = ds; obj.Variable.Items = variables; obj.Variable.Value = variables{1}; obj.Variable.Enable = 'on';
            groups = {};
            if iscell(ds.plotProperties) && size(ds.plotProperties,1) >= width(ds.data) && size(ds.plotProperties,2) >= 6
                groups = cellstr(unique(string(ds.plotProperties(:,6)),'stable'));
                groups = groups(~cellfun(@isempty,groups));
            end
            groups = groups(~strcmp(groups,'Variable'));
            obj.Group.Items = [{'Variable'} reshape(groups,1,[])]; obj.Group.Value = 'Variable'; obj.Group.Enable = 'on';
            obj.plot();
        end
        function selectVariable(obj)
            obj.Group.Value = 'Variable'; obj.plot();
        end
        function plot(obj)
            if isempty(obj.SelectedData), return; end
            scope = obj.Progress.begin('Plotting dataseries...'); %#ok<NASGU>
            try
                obj.Token = obj.Token+1;
                ds = obj.SelectedData; names = ds.data.Properties.VariableNames;
                index = find(strcmp(names,obj.Variable.Value)); groupName = obj.Variable.Value;
                if ~strcmp(obj.Group.Value,'Variable')
                    index = find(strcmp(string(ds.plotProperties(:,6)),obj.Group.Value)); groupName = obj.Group.Value;
                end
                obj.clearPlot(); obj.Temporal = strcmp(ds.type,'temporal');
                obj.Step = 1;
                if obj.Temporal && strcmp(obj.Units.Value,'Minutes'), obj.Step = obj.Interval.Value; end
                obj.Proxy.data = ds;
                options = score_collectDisplayOptions('mode','display','frames',obj.Viewer.annotationFrame(), ...
                    'framerate',obj.Step,'timeOffset',false,'legend',true,'dataColormap','lines', ...
                    'background',[1 1 1],'textColor',[.15 .15 .15]);
                options.plotidx = {index}; options.dataidx = {1}; options.plotidxgroup = {groupName}; options.ngroup = 1;
                obj.PlotLines = score_displayDataPanel(obj.Axes,1,options,obj.Proxy);
                legends = findall(ancestor(obj.Axes,'figure'),'Type','legend');
                set(legends,'AutoUpdate','off');
                label = 'Row'; if obj.Temporal, label = obj.Units.Value; end
                xlabel(obj.Axes,label,'Interpreter','none');
                obj.Sync = obj.Temporal && height(ds.data) == obj.Viewer.annotationFrameCount();
                token = obj.Token; callback = @(~,~)obj.click(token);
                obj.Axes.ButtonDownFcn = callback;
                handles = findall(obj.Axes,'Type','line'); set(handles,'ButtonDownFcn',callback);
                set(findall(obj.Axes,'Type','image'),'ButtonDownFcn',callback);
                if obj.Sync
                    obj.Marker = xline(obj.Axes,obj.Viewer.annotationFrame()*obj.Step,'--', ...
                        'Color',[.2 .4 .8],'HitTest','off','Tag','data-frame-marker');
                else
                    for handle = reshape(obj.PlotLines,1,[])
                        if isstruct(handle.UserData) && isfield(handle.UserData,'LinkedLine'), handle.Visible = 'off'; end
                    end
                end
                obj.onFrame(); obj.status(sprintf('%s · %s · %d rows',ds.groupid,ds.type,height(ds.data)));
            catch err, obj.clearPlot(); obj.status(err.message);
            end
        end
        function clearPlot(obj)
            if isvalid(obj.Axes)
                cla(obj.Axes); colorbar(obj.Axes,'off'); legend(obj.Axes,'off');
                set(obj.Axes,'XLimMode','auto','YLimMode','auto','YDir','normal','NextPlot','replace');
            end
            obj.Marker = []; obj.PlotLines = gobjects(0); obj.Sync = false;
        end
        function resetSeries(obj)
            obj.Series = {}; obj.SelectedData = []; obj.Token = obj.Token+1; obj.clearPlot();
            obj.resetControls();
        end
        function resetControls(obj)
            controls = {obj.Dataset,obj.Variable,obj.Group};
            for k = 1:numel(controls)
                control = controls{k};
                control.ItemsData = []; control.Items = {'—'}; control.Enable = 'off';
            end
        end
        function status(obj,text)
            obj.Status.Text = text; obj.Status.Tooltip = text;
        end
    end
    methods (Static,Access=private)
        function indices = meaningful(data)
            indices = [];
            for k = 1:numel(data)
                if istable(data(k).data) && width(data(k).data) > 0 && height(data(k).data) > 0
                    indices(end+1) = k; %#ok<AGROW>
                end
            end
        end
        function value = onOff(yes)
            value = 'off'; if yes, value = 'on'; end
        end
    end
end
