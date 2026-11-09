classdef MovieExportOptions < handle
    properties (SetAccess=private)
        Figure
        Controls=struct()
    end
    properties (Access=private)
        Settings
        OnApply
        Status
        Events
        EventRow=0
    end
    methods
        function obj=MovieExportOptions(settings,onApply)
            obj.Settings=settings; obj.OnApply=onApply;
            obj.Figure=uifigure('Name','Movie Options','Position',[260 120 620 720],'Visible','off', ...
                'Tag','movie-options-dialog','CloseRequestFcn',@(~,~)delete(obj));
            root=uigridlayout(obj.Figure,[4 1]); root.RowHeight={'1x',150,28,22};
            form=uigridlayout(root,[20 2]); form.Scrollable='on'; form.ColumnWidth={155,'1x'};
            form.RowHeight=repmat({28},1,20);
            obj.field(form,'Title','title','text');
            obj.field(form,'ROI titles','roiTitle','logical');
            obj.field(form,'Image scale','scale','numeric',[.01 20]);
            obj.field(form,'Crop [x y width height]','crop','vector');
            obj.field(form,'Use visible image area','useViewport','logical');
            obj.Controls.useViewport.Tooltip='Use Image pan/zoom when Crop is empty; an explicit Crop takes priority';
            obj.field(form,'Rotate counterclockwise','rotation','choice',{'0','90','180','270'});
            obj.field(form,'Flip','flip','choice',{'None','Vertical','Horizontal'});
            obj.field(form,'Mosaic rows (0 = auto)','rows','numeric',[0 100]);
            obj.field(form,'Mosaic columns (0 = auto)','columns','numeric',[0 100]);
            obj.field(form,'Font size','fontSize','numeric',[1 100]);
            obj.field(form,'Text color','textColor','color');
            obj.field(form,'Background','background','color');
            obj.field(form,'Include Data selection','includeData','logical');
            obj.Controls.includeData.Tooltip='Use the temporal variable or group selected in the Data widget';
            obj.field(form,'Data legend','legend','logical');
            obj.field(form,'Follow data window','track','logical');
            obj.field(form,'Data window (frames)','trackWindow','numeric',[1 1000000]);
            obj.field(form,'Image / data ratio','imageDataRatio','numeric',[1 20]);
            obj.field(form,'Data colormap','dataColormap','choice',{'lines','parula','turbo','hsv','jet','gray'});
            form.RowHeight=form.RowHeight(1:18);
            panel=uipanel(root,'Title','Events'); events=uigridlayout(panel,[2 1]); events.RowHeight={'1x',24};
            obj.Events=uitable(events,'Data',settings.events,'RowName',{}, ...
                'ColumnName',{'On','Start frame','End frame','Label','Width'}, ...
                'ColumnFormat',{'logical','numeric','numeric','char','numeric'}, ...
                'ColumnEditable',true(1,5),'Tag','movie-events', ...
                'CellSelectionCallback',@(~,e)obj.selectEvent(e));
            row=uigridlayout(events,[1 2]); row.Padding=[0 0 0 0];
            uibutton(row,'Text','Add Event','ButtonPushedFcn',@(~,~)obj.addEvent());
            uibutton(row,'Text','Remove Event','ButtonPushedFcn',@(~,~)obj.removeEvent());
            row=uigridlayout(root,[1 2]); row.Padding=[0 0 0 0];
            uibutton(row,'Text','Cancel','ButtonPushedFcn',@(~,~)delete(obj));
            uibutton(row,'Text','Apply','Tag','movie-options-apply','ButtonPushedFcn',@(~,~)obj.apply());
            obj.Status=uilabel(root,'Text','','Interpreter','none','Tag','movie-options-status');
            obj.Figure.WindowStyle='modal'; obj.Figure.Visible='on';
        end
        function applied=apply(obj)
            applied=false;
            try
                value=obj.Settings; names=fieldnames(obj.Controls);
                for k=1:numel(names)
                    name=names{k}; c=obj.Controls.(name); v=c.Value;
                    if strcmp(name,'crop')
                        text=strtrim(v); v=[];
                        if ~isempty(text)
                            assert(~isempty(regexp(text,'^[\d\s,]+$','once')),'detecdivui:ExportCrop','Use x y width height, or leave Crop empty.');
                            v=sscanf(strrep(text,',',' '),'%f')';
                            validateattributes(v,{'numeric'},{'numel',4,'integer','positive'});
                        end
                    elseif strcmp(name,'rotation'), v=str2double(v);
                    end
                    value.(name)=v;
                end
                for name={'rows','columns','imageDataRatio','trackWindow'}
                    assert(value.(name{1})==floor(value.(name{1})),'detecdivui:ExportInteger','%s must be an integer.',name{1});
                end
                value.events=obj.Events.Data;
                for k=1:size(value.events,1)
                    if ~value.events{k,1}, continue; end
                    validateattributes([value.events{k,2:3}],{'numeric'},{'integer','positive','finite'});
                    assert(value.events{k,3}>=value.events{k,2},'detecdivui:ExportEvents','Event end must follow its start.');
                    validateattributes(value.events{k,5},{'numeric'},{'scalar','real','finite','positive'});
                end
                obj.OnApply(value); applied=true; obj.Figure.Visible='off';
            catch err, obj.Status.Text=err.message; obj.Status.Tooltip=err.message;
            end
        end
        function delete(obj)
            if isgraphics(obj.Figure), delete(obj.Figure); end
        end
    end
    methods (Access=private)
        function field(obj,parent,label,name,type,varargin)
            uilabel(parent,'Text',label,'Interpreter','none'); value=obj.Settings.(name);
            switch type
                case 'logical', c=uicheckbox(parent,'Text','','Value',value);
                case 'numeric', c=uieditfield(parent,'numeric','Value',value,'Limits',varargin{1});
                case 'choice'
                    c=uidropdown(parent,'Items',varargin{1},'Value',char(string(value)));
                case 'color'
                    c=uicolorpicker(parent,'Value',value);
                case 'vector'
                    c=uieditfield(parent,'text','Value',num2str(value));
                otherwise, c=uieditfield(parent,'text','Value',value);
            end
            c.Tag=['movie-option-' name]; obj.Controls.(name)=c;
        end
        function selectEvent(obj,event)
            if ~isempty(event.Indices), obj.EventRow=event.Indices(1); end
        end
        function addEvent(obj)
            obj.Events.Data(end+1,:)={true,1,1,'Event',1.5};
        end
        function removeEvent(obj)
            if obj.EventRow>0&&obj.EventRow<=size(obj.Events.Data,1), obj.Events.Data(obj.EventRow,:)=[]; end
            obj.EventRow=0;
        end
    end
end
