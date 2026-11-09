classdef MovieExportWidget < handle
    % Contextual export assistant. Scientific pixels and Display stay untouched.
    properties (SetAccess=private)
        Progress
        Busy=false
        Settings
        LastOutput=''
        LastError=''
        HubJob=struct()
        HubRun=[]
    end
    properties (Access=private)
        Viewer
        Target
        Scope
        Format
        Path
        Frames
        FPS
        Interval
        Timestamp
        ZeroTime
        Drafts
        Status
        CancelButton
        Buttons=gobjects(0)
        CancelRequested=false
        Preview=[]
        OptionsDialog=[]
        Context=[]
        Activity=[]
        ProgressOwner=[]
        Execution
        HubTarget
        Form
        ExportButton
        Monitor=[]
        HubOutput=''
    end
    methods
        function obj=MovieExportWidget(parent,viewer)
            obj.Viewer=viewer; obj.Settings=detecdivui.MovieExportJob.defaults();
            root=uigridlayout(parent,[5 1]); root.Padding=[6 6 6 6]; root.RowSpacing=6;
            root.RowHeight={24,'1x',28,28,24};
            row=uigridlayout(root,[1 2]); row.Padding=[0 0 0 0]; row.ColumnWidth={'1x',95};
            obj.Target=uilabel(row,'Text','—','Interpreter','none','Tag','movie-target');
            uibutton(row,'Text','← Display','Tag','movie-done','ButtonPushedFcn',@(~,~)viewer.closeMovieExport());
            form=uigridlayout(root,[10 1]); form.Padding=[0 0 0 0]; form.Scrollable='on'; obj.Form=form;
            form.RowHeight={28,28,0,28,28,28,28,28,24,24};
            obj.Scope=uidropdown(form,'Items',{'Current Image','Open ROI Tabs','Current FOV ROIs'}, ...
                'ItemsData',{'current','open','fov'},'Tag','movie-scope','Tooltip','Images included in the export');
            row=uigridlayout(form,[1 2]); row.Padding=[0 0 0 0]; row.ColumnWidth={'1x',75};
            obj.Execution=uidropdown(row,'Items',{'Local MATLAB','DetecDiv Hub'},'ItemsData',{'local','hub'}, ...
                'Tag','movie-execution','ValueChangedFcn',@(~,~)obj.executionChanged());
            obj.Buttons(end+1)=uibutton(row,'Text','Hub...','Tag','movie-connect','ButtonPushedFcn',@(~,~)viewer.connectHub());
            obj.HubTarget=uidropdown(form,'Items',{'Automatic'},'ItemsData',{''},'Visible','off','Tag','movie-hub-target');
            profiles=VideoWriter.getProfiles; names={profiles.Name};
            names=names(ismember(names,{'MPEG-4','Motion JPEG AVI','Uncompressed AVI','Motion JPEG 2000','Archival'}));
            obj.Format=uidropdown(form,'Items',[names {'PDF Sequence','PNG Sequence','TIFF Sequence'}],'Tag','movie-format', ...
                'ValueChangedFcn',@(~,~)obj.formatChanged());
            row=uigridlayout(form,[1 2]); row.Padding=[0 0 0 0]; row.ColumnWidth={'1x',65};
            obj.Path=uieditfield(row,'text','Tag','movie-path','Tooltip','Output file or new image-sequence folder');
            obj.Buttons(end+1)=uibutton(row,'Text','File...','ButtonPushedFcn',@(~,~)obj.chooseFile());
            row=obj.row(form,'Frames');
            obj.Frames=uieditfield(row,'text','Value','all','Tag','movie-frames','Tooltip','all, 1:100, 1:2:100, or an increasing list');
            row=obj.row(form,'FPS');
            obj.FPS=uieditfield(row,'numeric','Value',20,'Limits',[.01 1000],'Tag','movie-fps','Tooltip','Playback frames per second');
            row=obj.row(form,'min/frame');
            obj.Interval=uieditfield(row,'numeric','Value',1,'Limits',[eps Inf],'Tag','movie-interval','Tooltip','Acquisition interval, independent of playback FPS');
            row=uigridlayout(form,[1 2]); row.Padding=[0 0 0 0];
            obj.Timestamp=uicheckbox(row,'Text','Timestamp','Value',true,'Tag','movie-timestamp');
            obj.ZeroTime=uicheckbox(row,'Text','Start at zero','Value',true,'Tag','movie-zero-time');
            obj.Drafts=uicheckbox(form,'Text','Include annotation drafts','Value',true,'Tag','movie-drafts', ...
                'Tooltip','Export the visible unsaved masks without saving or modifying scientific data');
            row=uigridlayout(root,[1 3]); row.Padding=[0 0 0 0]; row.ColumnWidth={75,'1x','1x'};
            obj.Buttons(end+1)=uibutton(row,'Text','Options...','Tag','movie-options','ButtonPushedFcn',@(~,~)obj.editOptions());
            obj.Buttons(end+1)=uibutton(row,'Text','Preview','Tag','movie-preview','ButtonPushedFcn',@(~,~)obj.preview());
            obj.ExportButton=uibutton(row,'Text','Export','Tag','movie-export','ButtonPushedFcn',@(~,~)obj.exportNow());
            obj.Buttons(end+1)=obj.ExportButton;
            row=uigridlayout(root,[1 3]); row.Padding=[0 0 0 0];
            obj.CancelButton=uibutton(row,'Text','Cancel','Enable','off','Tag','movie-cancel','ButtonPushedFcn',@(~,~)obj.cancel());
            uibutton(row,'Text','Open File','Tag','movie-open','ButtonPushedFcn',@(~,~)obj.openOutput(false));
            uibutton(row,'Text','Folder','Tag','movie-folder','ButtonPushedFcn',@(~,~)obj.openOutput(true));
            obj.Status=uilabel(root,'Text','Ready','Interpreter','none','Tag','movie-status');
            obj.Progress=detecdivui.Progress(root,obj.Status,'movie-progress');
            obj.formatChanged(); obj.setContext(); obj.refreshHub();
        end
        function setContext(obj)
            if obj.Busy, return; end
            sources=obj.Viewer.movieSources('current');
            if isempty(sources), obj.Target.Text='—'; obj.Context=[]; return; end
            source=sources(1); session=source.session;
            scopeLabel='Current FOV ROIs';
            if ~isempty(session.Classifier), scopeLabel='Classifier ROIs'; end
            obj.Scope.Items={'Current Image','Open ROI Tabs',scopeLabel};
            key={session.Project,source.position,source.zone};
            if ~isequal(key,obj.Context)
                obj.Context=key; obj.Frames.Value='all';
                interval=session.Project.fov(source.position).interval;
                if isnumeric(interval)&&~isempty(interval)&&isfinite(interval(1))&&interval(1)>0, obj.Interval.Value=interval(1); end
            end
            obj.Target.Text=session.breadcrumb(); obj.Target.Tooltip=obj.Target.Text;
            if isempty(obj.Path.Value)
                folder=pwd; name=session.Project.fov(source.position).id;
                if source.zone>0
                    r=session.Project.fov(source.position).roi(source.zone); folder=r.path; name=r.id;
                end
                if isempty(folder)||~isfolder(folder), folder=pwd; end
                obj.Path.Value=fullfile(folder,[matlab.lang.makeValidName(name) '_movie' obj.extension()]);
            end
        end
        function settings=readSettings(obj)
            settings=obj.Settings; settings.frames=obj.Frames.Value; settings.fps=obj.FPS.Value;
            settings.interval=obj.Interval.Value; settings.timestamp=obj.Timestamp.Value;
            settings.zeroTime=obj.ZeroTime.Value; settings.includeDrafts=obj.Drafts.Value;
        end
        function dialog=editOptions(obj)
            dialog=[]; if obj.Busy, return; end
            if ~isempty(obj.OptionsDialog)&&isvalid(obj.OptionsDialog), delete(obj.OptionsDialog); end
            dialog=detecdivui.MovieExportOptions(obj.readSettings(),@(settings)obj.applyOptions(settings)); obj.OptionsDialog=dialog;
        end
        function applyOptions(obj,settings)
            obj.Settings=settings; obj.status('Export options updated');
        end
        function job=makeJob(obj)
            sources=obj.Viewer.movieSources(obj.Scope.Value); drafts={};
            if ~isempty(obj.Viewer.Masks)&&isvalid(obj.Viewer.Masks), drafts=obj.Viewer.Masks.Drafts; end
            data=[];
            if ~isempty(obj.Viewer.Data)&&isvalid(obj.Viewer.Data), data=obj.Viewer.Data.exportSelection(); end
            job=detecdivui.MovieExportJob(sources,obj.readSettings(),drafts,data);
            if obj.Busy
                job.Cancel=@()~isvalid(obj)||obj.CancelRequested;
                job.Progress=@(fraction)obj.report(fraction);
            end
        end
        function figureHandle=preview(obj)
            figureHandle=[]; if obj.Busy, return; end
            obj.start(); cleanup=onCleanup(@()obj.finish());
            obj.beginProgress('Preparing movie preview...');
            try
                job=obj.makeJob();
                if isgraphics(obj.Preview), delete(obj.Preview); end
                figureHandle=job.preview(); obj.Preview=figureHandle; obj.status('Preview ready');
            catch err
                obj.failed(err);
            end
        end
        function output=exportNow(obj,path,overwrite)
            output=''; if obj.Busy, return; end
            if nargin<2, path=obj.Path.Value; end
            if nargin<3, overwrite=false; end
            if isempty(path), obj.chooseFile(); path=obj.Path.Value; if isempty(path), return; end; end
            if ~strcmp(obj.Settings.mode,'images')
                [folder,name]=fileparts(path); path=fullfile(folder,[name obj.extension()]);
            end
            if isfile(path)&&~overwrite
                answer=uiconfirm(obj.Viewer.Figure,sprintf('Replace this file?\n%s',path),'Export Movie', ...
                    'Options',{'Replace','Cancel'},'DefaultOption',2,'CancelOption',2);
                if ~strcmp(answer,'Replace'), return; end
                overwrite=true;
            end
            obj.start(); cleanup=onCleanup(@()obj.finish());
            obj.beginProgress('Freezing Display and loading export sources...');
            try
                if strcmp(obj.Execution.Value,'hub')
                    assert(~obj.remoteActive(),'detecdivui:ExportRunning','A Hub export is already queued or running.');
                    code=detecdivui.MovieExportSnapshot.publishedCode();
                    if ~obj.Viewer.Hub.Connected, obj.Viewer.Hub.refresh(); end
                    assert(obj.Viewer.Hub.Connected,'detecdivui:HubConnection','Connect through Hub > Connection before submitting.');
                    job=obj.makeJob(); [parent,~]=fileparts(path); if isempty(parent), parent=pwd; end
                    snapshotFolder=fullfile(parent,['.detecdiv_export_' char(matlab.lang.internal.uuid)]);
                    descriptor=job.saveSnapshot(snapshotFolder);
                    params=movieExport.setparam(struct()); params.sourceType='viewer_snapshot';
                    params.outputMode=job.Settings.mode; params.outputPath=path; params.snapshotPath=descriptor.path;
                    params.snapshotChecksum=descriptor.sha256; params.overwrite=overwrite;
                    target=obj.Viewer.Session.Project;
                    if ~isempty(obj.Viewer.Session.Classifier), target=obj.Viewer.Session.Classifier; end
                    [obj.HubRun,result]=detecdiv_movie_export_submit(target,params,'Target','hub', ...
                        'Hub',obj.Viewer.Hub.settings(),'ExecutionTargetId',obj.HubTarget.Value,'CodeCommit',code);
                    obj.HubJob=result.job; obj.HubOutput=path; obj.startMonitor();
                    obj.status(['Submitted to Hub: ' char(string(obj.HubJob.id))]);
                else
                    assert(~obj.remoteActive()||~strcmpi(path,obj.HubOutput),'detecdivui:ExportRunning','This output is reserved by a running Hub export.');
                    job=obj.makeJob(); output=job.write(path,overwrite);
                    obj.LastOutput=output; obj.Path.Value=output; obj.status(['Exported: ' output]);
                end
            catch err
                obj.failed(err);
            end
        end
        function cancel(obj)
            if ~obj.Busy && obj.remoteActive()
                try
                    obj.HubJob=detecdiv_hub_cancel_pipeline_run(obj.HubJob.id,obj.Viewer.Hub.settings());
                    obj.status('Hub cancellation requested');
                catch err
                    obj.failed(err);
                end
                return;
            end
            obj.CancelRequested=true; obj.status('Cancelling export...');
        end
        function refreshHub(obj)
            [names,ids]=obj.Viewer.Hub.targetItems(); previous=obj.HubTarget.Value;
            obj.HubTarget.ItemsData=[]; obj.HubTarget.Items=names; obj.HubTarget.ItemsData=ids;
            if ismember(previous,ids), obj.HubTarget.Value=previous; else, obj.HubTarget.Value=''; end
            if ~obj.Busy, obj.executionChanged(); end
        end
        function pollHub(obj)
            if obj.Busy||~isfield(obj.HubJob,'id'), return; end
            try
                hub=obj.Viewer.Hub.settings(); hub.timeout=3;
                obj.HubJob=detecdiv_hub_get_pipeline_run(obj.HubJob.id,hub);
                state=char(string(obj.HubJob.status)); obj.status(['Hub: ' state]);
                obj.CancelButton.Enable=matlab.lang.OnOffSwitchState(obj.remoteActive());
                if ~obj.remoteActive()
                    obj.stopMonitor();
                    if any(strcmpi(state,{'done','completed','succeeded'}))
                        if isfile(obj.HubOutput)||isfolder(obj.HubOutput), obj.LastOutput=obj.HubOutput; end
                    end
                end
            catch err
                obj.status(['Hub monitor: ' err.message]);
            end
        end
        function delete(obj)
            obj.CancelRequested=true;
            obj.stopMonitor();
            obj.Activity=[];
            if isgraphics(obj.Preview), delete(obj.Preview); end
            if ~isempty(obj.OptionsDialog)&&isvalid(obj.OptionsDialog), delete(obj.OptionsDialog); end
        end
    end
    methods (Access=private)
        function formatChanged(obj)
            value=obj.Format.Value; previous=obj.Settings.mode;
            if strcmp(value,'PDF Sequence')
                obj.Settings.mode='sequence';
            elseif any(strcmp(value,{'PNG Sequence','TIFF Sequence'}))
                obj.Settings.mode='images'; obj.Settings.imageFormat='png';
                if strcmp(value,'TIFF Sequence'), obj.Settings.imageFormat='tif'; end
            else
                obj.Settings.mode='movie'; obj.Settings.profile=value;
            end
            obj.FPS.Enable=matlab.lang.OnOffSwitchState(strcmp(obj.Settings.mode,'movie'));
            if ~isempty(obj.Path.Value) && ~(strcmp(previous,'images')&&strcmp(obj.Settings.mode,'images'))
                [folder,name,ext]=fileparts(obj.Path.Value);
                if strcmp(previous,'images'), name=[name ext]; end
                obj.Path.Value=fullfile(folder,[name obj.extension()]);
            end
        end
        function extension=extension(obj)
            extension=detecdivui.MovieExportJob.extension(obj.Settings.mode,obj.Settings.profile);
        end
        function chooseFile(obj)
            extension=obj.extension(); label=['Export (*' extension ')'];
            if strcmp(obj.Settings.mode,'images'), label='New image-sequence folder'; end
            [name,folder]=uiputfile({['*' extension],label},'Export Movie',obj.Path.Value);
            if ~isequal(name,0), obj.Path.Value=fullfile(folder,name); end
        end
        function start(obj)
            obj.Busy=true; obj.CancelRequested=false; obj.LastError='';
            obj.CancelButton.Enable='on'; set(obj.Buttons,'Enable','off');
            controls={obj.Scope,obj.Format,obj.Path,obj.Frames,obj.FPS,obj.Interval,obj.Timestamp,obj.ZeroTime,obj.Drafts,obj.Execution,obj.HubTarget};
            for k=1:numel(controls), controls{k}.Enable='off'; end
        end
        function finish(obj)
            if ~isvalid(obj), return; end
            obj.Activity=[]; obj.ProgressOwner=[];
            obj.Busy=false; obj.CancelButton.Enable=matlab.lang.OnOffSwitchState(obj.remoteActive()); set(obj.Buttons,'Enable','on');
            controls={obj.Scope,obj.Format,obj.Path,obj.Frames,obj.FPS,obj.Interval,obj.Timestamp,obj.ZeroTime,obj.Drafts,obj.Execution,obj.HubTarget};
            for k=1:numel(controls), controls{k}.Enable='on'; end
            obj.formatChanged();
            obj.executionChanged();
        end
        function failed(obj,err)
            obj.LastError=err.message; obj.status(err.message);
        end
        function report(obj,fraction)
            if ~isvalid(obj), return; end
            message=sprintf('Rendering export · %d%%',round(fraction*100));
            owner=obj.Viewer.movieProgress();
            if isempty(obj.ProgressOwner)||~isvalid(obj.ProgressOwner)||owner~=obj.ProgressOwner
                obj.Activity=[]; obj.ProgressOwner=owner; obj.Activity=owner.begin(message);
            end
            owner.update(message,fraction);
        end
        function beginProgress(obj,message)
            obj.ProgressOwner=obj.Viewer.movieProgress(); obj.Activity=obj.ProgressOwner.begin(message);
        end
        function status(obj,message)
            obj.Status.Text=message; obj.Status.Tooltip=message;
        end
        function openOutput(obj,folderOnly)
            if isempty(obj.LastOutput)||(~isfile(obj.LastOutput)&&~isfolder(obj.LastOutput)), obj.status('No exported file available'); return; end
            if isfolder(obj.LastOutput), winopen(obj.LastOutput);
            elseif folderOnly
                winopen(fileparts(obj.LastOutput));
            else
                winopen(obj.LastOutput);
            end
        end
        function executionChanged(obj)
            remote=strcmp(obj.Execution.Value,'hub'); rows=obj.Form.RowHeight; rows{3}=0;
            obj.HubTarget.Visible=matlab.lang.OnOffSwitchState(remote);
            if remote, rows{3}=28; obj.ExportButton.Text='Submit'; else, obj.ExportButton.Text='Export'; end
            obj.Form.RowHeight=rows;
        end
        function yes=remoteActive(obj)
            yes=isfield(obj.HubJob,'id')&&isfield(obj.HubJob,'status')&& ...
                ~any(strcmpi(char(string(obj.HubJob.status)),{'done','completed','succeeded','failed','cancelled','canceled','rejected'}));
        end
        function startMonitor(obj)
            obj.stopMonitor(); obj.Monitor=timer('ExecutionMode','fixedSpacing','Period',5,'BusyMode','drop', ...
                'Tag','DetecDivMovieHub','TimerFcn',@(~,~)obj.pollHub()); start(obj.Monitor);
        end
        function stopMonitor(obj)
            if ~isempty(obj.Monitor)&&isvalid(obj.Monitor), stop(obj.Monitor); delete(obj.Monitor); end
            obj.Monitor=[];
        end
    end
    methods (Static,Access=private)
        function row=row(parent,label)
            row=uigridlayout(parent,[1 2]); row.Padding=[0 0 0 0]; row.ColumnWidth={70,'1x'};
            uilabel(row,'Text',label);
        end
    end
end
