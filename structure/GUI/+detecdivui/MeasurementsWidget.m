classdef MeasurementsWidget < handle
    % Transient image measurements; no masks, project ROI or dataseries writes.
    properties (SetAccess=private)
        Active=false
        Shape=[]
        Results=struct('layer',{},'index',{},'sample',{})
        Progress
        Axes
        Revision=0
    end
    properties (Access=private)
        Viewer
        Target
        Mode
        DrawButton
        ExportButton
        Stats
        Status
        Context=[]
        Records=struct('project',{},'position',{},'zone',{},'source',{},'mode',{},'geometry',{})
        Listeners={}
        Guard=[]
        PreviewClock=[]
        ExportData=table()
        Busy=false
        Curves=gobjects(0)
        Content
        Wide=[]
        Container
        Controls
        ClearButton
        CompactControls=[]
    end
    methods
        function obj=MeasurementsWidget(parent,viewer)
            obj.Viewer=viewer;
            root=uigridlayout(parent,[1 1]); root.Padding=[0 0 0 0];
            obj.Container=uipanel(root,'BorderType','none');
            grid=uigridlayout(obj.Container,[4 1]); grid.Padding=[6 6 6 6]; grid.RowHeight={24,28,'1x',22};
            row=uigridlayout(grid,[1 2]); row.Padding=[0 0 0 0]; row.ColumnWidth={'1x',65};
            obj.Target=uilabel(row,'Text','—','Interpreter','none','Tag','measurements-target');
            uibutton(row,'Text','Done','Tag','measurements-done','Tooltip','Hide Measurements and retain view geometry', ...
                'ButtonPushedFcn',@(~,~)viewer.Host.setWidgetVisible('Measurements',false));
            row=uigridlayout(grid,[1 4]); row.Padding=[0 0 0 0]; row.RowSpacing=4; row.ColumnWidth={'1x',100,65,110};
            obj.Controls=row;
            obj.Mode=uidropdown(row,'Items',{'Line','Ellipse'},'Tag','measurement-mode', ...
                'ValueChangedFcn',@(~,~)obj.onRender());
            obj.DrawButton=uibutton(row,'Text','Draw','Tag','measurement-draw','Enable','off', ...
                'Tooltip','Draw a temporary measurement on the main Image', ...
                'ButtonPushedFcn',@(~,~)obj.draw());
            obj.ClearButton=uibutton(row,'Text','Clear','Tag','measurement-clear','Tooltip','Clear this view measurement; scientific data is unchanged', ...
                'ButtonPushedFcn',@(~,~)obj.clear());
            obj.ExportButton=uibutton(row,'Text','Export CSV...','Tag','measurement-export','Enable','off', ...
                'ButtonPushedFcn',@(~,~)obj.exportCSV());
            obj.Content=uigridlayout(grid,[1 2]); obj.Content.Padding=[0 0 0 0]; obj.Content.ColumnWidth={'3x','2x'};
            obj.Axes=uiaxes(obj.Content,'Tag','measurement-axes','Toolbar',[]);
            obj.Axes=detecdivui.ImageAxes.initialize(obj.Axes);
            obj.Stats=uitable(obj.Content,'RowName',{},'ColumnName',{'Channel','N','Mean','Median','Std','Unit'}, ...
                'ColumnWidth',{'auto',35,60,60,60,50},'ColumnEditable',false(1,6),'Data',cell(0,6), ...
                'Tag','measurement-stats');
            obj.Status=uilabel(grid,'Text','Load an image','Interpreter','none','Tag','measurement-status');
            obj.Progress=detecdivui.Progress(grid,obj.Status,'measurement-progress');
            obj.Container.SizeChangedFcn=@(~,~)obj.layout(); obj.layout();
        end
        function setActive(obj,active)
            obj.Active=logical(active);
            if obj.Active, obj.onRender();
            else, obj.clearShape(); obj.status('Inactive'); end
        end
        function onRender(obj)
            if ~obj.Active||obj.Busy, return; end
            obj.clearShape(); obj.Context=obj.Viewer.measurementContext();
            c=obj.Context; obj.DrawButton.Enable=obj.onOff(c.ready);
            if ~c.ready, obj.resetPlot(); obj.Target.Text='—'; obj.status('Load an image'); return; end
            obj.Target.Text=sprintf('%s · Frame %d',c.shortName,c.frame); obj.Target.Tooltip=c.name;
            obj.layout();
            at=obj.record(c,obj.Mode.Value);
            if isempty(at), obj.resetPlot(); obj.status(['Draw a ' lower(obj.Mode.Value)]); return; end
            try
                obj.makeShape(obj.Records(at).geometry); obj.refreshProfile(true);
            catch err, obj.resetPlot(); obj.status(err.message);
            end
        end
        function setGeometry(obj,mode,geometry)
            assert(ismember(mode,{'Line','Ellipse'}),'detecdivui:MeasurementMode','Choose Line or Ellipse.');
            if ~obj.Active
                assert(~obj.Viewer.contourGestureActive(),'detecdivui:MeasurementGesture','Finish the current drawing first.');
                obj.Viewer.openMeasurements();
            end
            c=obj.Viewer.measurementContext(); assert(c.ready,'detecdivui:MeasurementImage','Load an image first.');
            if strcmp(mode,'Line')
                validateattributes(geometry,{'numeric'},{'real','finite','size',[2 2]});
                assert(norm(diff(geometry))>0,'detecdivui:MeasurementLine','Draw distinct line endpoints.');
            else
                validateattributes(geometry,{'numeric'},{'real','finite','vector','numel',5});
                assert(all(geometry(3:4)>0),'detecdivui:MeasurementEllipse','Ellipse radii must be positive.');
                geometry=reshape(geometry,1,5);
            end
            obj.Mode.Value=mode; obj.Context=c; obj.store(geometry); obj.onRender();
        end
        function draw(obj)
            if obj.Viewer.contourGestureActive(), obj.status('Finish the current drawing first'); return; end
            obj.Viewer.openMeasurements(); c=obj.Viewer.measurementContext();
            if ~c.ready, return; end
            obj.clearShape(); obj.Context=c; obj.Busy=true;
            obj.Mode.Enable='off'; obj.DrawButton.Enable='off';
            cleanup=onCleanup(@()obj.finishDraw());
            guard=obj.Viewer.beginROIGesture(); %#ok<NASGU>
            try
                if strcmp(obj.Mode.Value,'Line'), obj.Shape=images.roi.Line(obj.Viewer.roiAxes(),'Color',[1 .65 0]);
                else, obj.Shape=images.roi.Ellipse(obj.Viewer.roiAxes(),'Color',[1 .65 0]); end
                shape=obj.Shape; draw(shape);
                if isempty(shape)||~isvalid(shape), return; end
                after=obj.Viewer.measurementContext();
                assert(obj.sameView(c,after)&&c.frame==after.frame, ...
                    'detecdivui:MeasurementContext','The image changed while drawing. Draw again.');
                obj.setGeometry(obj.Mode.Value,obj.geometry()); obj.attach(); obj.refreshProfile(true);
            catch err, obj.clearShape(); obj.status(err.message);
            end
        end
        function geometryChanged(obj,revision,moving)
            if ~obj.Active||obj.Busy||revision~=obj.Revision||isempty(obj.Shape)||~isvalid(obj.Shape), return; end
            c=obj.Viewer.measurementContext();
            if ~obj.sameView(c,obj.Context), return; end
            if moving&&isempty(obj.Guard), obj.Guard=obj.Viewer.beginROIGesture(); end
            obj.store(obj.geometry());
            if moving&&~isempty(obj.PreviewClock)&&toc(obj.PreviewClock)<.06, return; end
            obj.PreviewClock=tic; obj.refreshProfile(~moving);
            if ~moving, obj.Guard=[]; end
        end
        function updateNavigation(obj)
            if isempty(obj.Shape)||~isvalid(obj.Shape), return; end
            allowed='all'; if obj.Viewer.imageNavigationActive(), allowed='none'; end
            obj.Shape.InteractionsAllowed=allowed;
        end
        function geometryDeleted(obj,revision)
            if revision~=obj.Revision, return; end
            obj.Revision=obj.Revision+1; obj.Shape=[]; obj.Listeners={}; obj.Guard=[];
            if ~isempty(obj.Context)
                at=obj.record(obj.Context,obj.Mode.Value); if ~isempty(at), obj.Records(at)=[]; end
            end
            obj.resetPlot(); obj.status(['Draw a ' lower(obj.Mode.Value)]);
        end
        function clear(obj)
            if ~isempty(obj.Context)
                at=obj.record(obj.Context,obj.Mode.Value); if ~isempty(at), obj.Records(at)=[]; end
            end
            obj.onRender();
        end
        function forgetProject(obj,project)
            keep=arrayfun(@(r)~isequal(r.project,project),obj.Records); obj.Records=obj.Records(keep);
        end
        function output=exportCSV(obj,path)
            output=''; if isempty(obj.ExportData), return; end
            data=obj.ExportData;
            if nargin<2
                [file,folder]=uiputfile('*.csv','Export Measurements','intensity-profile.csv');
                if isequal(file,0), return; end
                path=fullfile(folder,file);
            end
            scope=obj.Progress.begin('Exporting measurements...'); %#ok<NASGU>
            try
                writetable(data,path,'Delimiter',',','Encoding','UTF-8'); output=path; obj.status('Measurements exported');
            catch err, obj.status(err.message);
            end
        end
        function delete(obj)
            obj.Active=false; obj.clearShape(); obj.Records=obj.Records([]);
        end
    end
    methods (Access=private)
        function layout(obj)
            compact=obj.Container.InnerPosition(3)<420;
            if ~isequal(compact,obj.CompactControls)
                obj.CompactControls=compact;
                if compact
                    obj.Controls.RowHeight={28,28}; obj.Controls.ColumnWidth={'1x','1x',0,0};
                    obj.Mode.Layout.Row=1; obj.Mode.Layout.Column=1;
                    obj.DrawButton.Layout.Row=1; obj.DrawButton.Layout.Column=2;
                    obj.ClearButton.Layout.Row=2; obj.ClearButton.Layout.Column=1;
                    obj.ExportButton.Layout.Row=2; obj.ExportButton.Layout.Column=2;
                    obj.Controls.ColumnWidth={'1x','1x'}; obj.Controls.Parent.RowHeight={24,62,'1x',22};
                else
                    obj.Controls.ColumnWidth={'1x',100,65,110};
                    buttons={obj.Mode,obj.DrawButton,obj.ClearButton,obj.ExportButton};
                    for k=1:numel(buttons), buttons{k}.Layout.Row=1; buttons{k}.Layout.Column=k; end
                    obj.Controls.RowHeight={28}; obj.Controls.Parent.RowHeight={24,28,'1x',22};
                end
            end
            wide=obj.Container.InnerPosition(3)>=700;
            if isequal(wide,obj.Wide), return; end
            obj.Wide=wide;
            if wide
                obj.Content.ColumnWidth={'3x','2x'}; obj.Content.RowHeight={'1x',0};
                obj.Axes.Layout.Row=1; obj.Axes.Layout.Column=1; obj.Stats.Layout.Row=1; obj.Stats.Layout.Column=2;
                obj.Content.RowHeight={'1x'};
            else
                obj.Content.RowHeight={'1x',84}; obj.Content.ColumnWidth={'1x',0};
                obj.Axes.Layout.Row=1; obj.Axes.Layout.Column=1; obj.Stats.Layout.Row=2; obj.Stats.Layout.Column=1;
                obj.Content.ColumnWidth={'1x'};
            end
        end
        function finishDraw(obj)
            if ~isvalid(obj), return; end
            obj.Busy=false; obj.Mode.Enable='on'; obj.onRender();
        end
        function makeShape(obj,geometry)
            ax=obj.Viewer.roiAxes();
            if strcmp(obj.Mode.Value,'Line')
                obj.Shape=drawline(ax,'Position',geometry,'Color',[1 .65 0]);
            else
                obj.Shape=drawellipse(ax,'Center',geometry(1:2),'SemiAxes',geometry(3:4), ...
                    'RotationAngle',geometry(5),'Color',[1 .65 0]);
            end
            obj.attach(); obj.updateNavigation();
        end
        function attach(obj)
            obj.Shape.Tag='measurement-shape'; obj.Shape.Selected=false;
            revision=obj.Revision;
            obj.Listeners={addlistener(obj.Shape,'MovingROI',@(~,~)obj.geometryChanged(revision,true)), ...
                addlistener(obj.Shape,'ROIMoved',@(~,~)obj.geometryChanged(revision,false)), ...
                addlistener(obj.Shape,'DeletingROI',@(~,~)obj.geometryDeleted(revision))};
        end
        function value=geometry(obj)
            if strcmp(obj.Mode.Value,'Line'), value=obj.Shape.Position;
            else, value=[obj.Shape.Center obj.Shape.SemiAxes obj.Shape.RotationAngle]; end
        end
        function clearShape(obj)
            obj.Revision=obj.Revision+1;
            for k=1:numel(obj.Listeners), if isvalid(obj.Listeners{k}), delete(obj.Listeners{k}); end; end
            obj.Listeners={};
            if ~isempty(obj.Shape)&&isvalid(obj.Shape), delete(obj.Shape); end
            obj.Shape=[]; obj.Guard=[];
        end
        function index=record(obj,c,mode)
            index=find(arrayfun(@(r)obj.sameView(r,c)&&strcmp(r.mode,mode),obj.Records),1);
        end
        function store(obj,geometry)
            c=obj.Context; at=obj.record(c,obj.Mode.Value);
            item=struct('project',c.project,'position',c.position,'zone',c.zone,'source',c.source, ...
                'mode',obj.Mode.Value,'geometry',geometry);
            if isempty(at), obj.Records(end+1)=item; else, obj.Records(at)=item; end
        end
        function refreshProfile(obj,showProgress)
            if isempty(obj.Shape)||~isvalid(obj.Shape), return; end
            if showProgress, scope=obj.Progress.begin('Measuring visible intensity channels...'); end %#ok<NASGU>
            c=obj.Context; layers=obj.Viewer.DisplayModel.Layers;
            indices=find([layers.visible]&~strcmp({layers.kind},'Labels'));
            obj.resetPlot(); hold(obj.Axes,'on'); rows=cell(0,6); names={};
            try
                mode='Line';
                if strcmp(obj.Mode.Value,'Line'), geometry=obj.Shape.Position;
                else
                    mode='Region'; base=obj.Viewer.DisplayModel.read(1,c.frame);
                    geometry=createMask(obj.Shape,base(:,:,1));
                end
                for index=indices
                    plane=obj.Viewer.DisplayModel.read(index,c.frame);
                    sample=score_measureIntensity(plane,mode,geometry,c.source,c.channels(index).logicalId);
                    obj.Results(end+1)=struct('layer',layers(index).name,'index',index,'sample',sample);
                    color=obj.curveColor(layers(index).color); name=layers(index).name;
                    if strcmp(mode,'Line')
                        obj.Curves(end+1)=plot(obj.Axes,sample.x,sample.values,'Color',color,'LineWidth',1.5);
                        part=table(repmat(string(c.name),numel(sample.x),1),repmat(string(name),numel(sample.x),1), ...
                            repmat(c.frame,numel(sample.x),1),sample.x,sample.values,repmat(string(sample.unit),numel(sample.x),1), ...
                            'VariableNames',{'Source','Layer','Frame','Distance_px','Intensity','Unit'});
                    else
                        obj.Curves(end+1)=stairs(obj.Axes,sample.centers,sample.counts,'Color',color,'LineWidth',1.5);
                        n=numel(sample.centers);
                        part=table(repmat(string(c.name),n,1),repmat(string(name),n,1),repmat(c.frame,n,1), ...
                            sample.centers(:),sample.counts(:),repmat(string(sample.unit),n,1), ...
                            'VariableNames',{'Source','Layer','Frame','Intensity','Count','Unit'});
                    end
                    obj.ExportData=[obj.ExportData;part];
                    rows(end+1,:)={name,sample.count,sample.mean,sample.median,sample.std,sample.unit}; %#ok<AGROW>
                    names{end+1}=[name ' (' sample.unit ')']; %#ok<AGROW>
                end
                obj.Stats.Data=rows;
                if strcmp(mode,'Line'), xlabel(obj.Axes,'Distance (px)'); ylabel(obj.Axes,'Intensity');
                else, xlabel(obj.Axes,'Intensity'); ylabel(obj.Axes,'Pixel count'); end
                if ~isempty(names), legend(obj.Axes,obj.Curves,names,'Interpreter','none','Location','best','AutoUpdate','off'); end
                obj.ExportButton.Enable=obj.onOff(~isempty(obj.ExportData));
                if isempty(indices), obj.status('No visible intensity channels');
                else, obj.status(sprintf('Frame %d · %d channels',c.frame,numel(indices))); end
            catch err, obj.resetPlot(); obj.status(err.message);
            end
            hold(obj.Axes,'off');
        end
        function resetPlot(obj)
            legend(obj.Axes,'off'); cla(obj.Axes); obj.Curves=gobjects(0);
            obj.Results=obj.Results([]); obj.ExportData=table(); obj.Stats.Data=cell(0,6); obj.ExportButton.Enable='off';
        end
        function status(obj,message)
            obj.Status.Text=message; obj.Status.Tooltip=message;
        end
    end
    methods (Static,Access=private)
        function yes=sameView(a,b)
            yes=~isempty(a)&&~isempty(b)&&isequal(a.project,b.project)&&a.position==b.position&&a.zone==b.zone;
            if yes&&a.zone>0, yes=isequal(a.source,b.source); end
        end
        function color=curveColor(spec)
            color=sscanf(strrep(spec,',',' '),'%f')';
            if numel(color)~=3
                color=[0 0 0];
                if ~strcmp(spec,'RGB'), map=score_colormapFromName(spec,64); color=map(end,:); end
            end
            if all(color>=.99), color=[0 0 0]; end
        end
        function value=onOff(yes)
            value='off'; if yes, value='on'; end
        end
    end
end
