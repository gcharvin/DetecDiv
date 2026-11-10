classdef MovieExportJob < handle
    % Frozen viewer adapter to Score's export layout, data panels and writer.
    properties (SetAccess=private)
        Entries = struct('session',{},'model',{},'proxy',{},'selected',{},'overlay',{},'regions',{},'frameCount',{},'viewport',{})
        Options
        Settings
        Output = ''
    end
    properties
        Cancel = []
        Progress = []
    end
    methods
        function obj=MovieExportJob(sources,settings,drafts,dataSelection)
            if nargin==0, return; end % Restored immutable export snapshot.
            if nargin<3, drafts={}; end
            if nargin<4, dataSelection=[]; end
            assert(~isempty(sources),'detecdivui:ExportSource','Select and load an image first.');
            for name={'fps','interval','scale','fontSize','imageDataRatio','trackWindow'}
                validateattributes(settings.(name{1}),{'numeric'},{'real','scalar','finite','positive'});
            end
            assert(any(settings.rotation==[0 90 180 270]),'detecdivui:ExportRotation','Choose a quarter-turn rotation.');
            if strcmpi(settings.mode,'movie')
                profiles=VideoWriter.getProfiles;
                assert(ismember(settings.profile,{profiles.Name}),'detecdivui:ExportProfile','This video profile is unavailable.');
            end
            obj.Settings=settings;
            for source=reshape(sources,1,[])
                live=source.session; position=live.Project.fov(source.position);
                project=shallow(); frozen=fov();
                fields=properties(position);
                for k=1:numel(fields)
                    name=fields{k};
                    if any(strcmp(name,{'roi','parent','channels','driftReferenceState'})), continue; end
                    frozen.(name)=position.(name);
                end
                if source.zone>0
                    original=position.roi(source.zone); proxy=obj.copyROI(original);
                    assert(~isfield(proxy.display,'write_abs_start')||isempty(proxy.display.write_abs_start)||proxy.display.write_abs_start==0, ...
                        'detecdivui:ExportWindow','Load the complete ROI sequence before exporting absolute frame numbers.');
                    if settings.includeDrafts
                        for k=1:numel(drafts)
                            d=drafts{k};
                            if ~isequal(d.Source,original)||~d.Dirty, continue; end
                            assert(~d.SaveFailed,'detecdivui:ExportPartialSave','Retry the incomplete annotation save before exporting this ROI.');
                            proxy.image(:,:,d.Pix,:)=d.Masks;
                        end
                    end
                    frozen.roi(source.zone)=proxy;
                else
                    proxy=roi(position.id,[]);
                end
                project.fov(source.position)=frozen;
                session=detecdivui.Session(project); session.selectPosition(source.position); session.selectZone(source.zone);
                [names,count]=session.dimensions();
                model=source.model.copyFor(session,settings.includeDrafts);
                assert(any([model.Layers.visible]),'detecdivui:ExportLayers','Select at least one visible layer in Display.');
                selected=find(strcmp(names,source.channel),1);
                if isempty(selected), selected=find([model.Layers.visible],1); end
                % Resolve automatic levels once at the frozen reference frame.
                visible=find([model.Layers.visible]);
                for k=visible, model.read(k,min(source.frame,count)); end
                if settings.includeData
                    assert(~isempty(dataSelection)&&source.zone>0,'detecdivui:ExportData','Select a temporal curve in Data before including a data panel.');
                    candidates=position.roi(source.zone).data;
                    at=find(arrayfun(@(d)strcmp(d.groupid,dataSelection.groupid),candidates),1);
                    if isequal(position.roi(source.zone),dataSelection.source)
                        ds=obj.copyData(dataSelection.data);
                    else
                        assert(~isempty(at),'detecdivui:ExportData','A selected ROI has no matching dataseries. Export it separately.');
                        ds=obj.copyData(candidates(at));
                    end
                    assert(strcmp(ds.type,'temporal')&&height(ds.data)==count,'detecdivui:ExportData','Export requires a temporal dataseries with one row per image frame.');
                    assert(all(ismember(dataSelection.variables,ds.data.Properties.VariableNames)), ...
                        'detecdivui:ExportData','A selected ROI has different dataseries variables.');
                    [~,columns]=ismember(dataSelection.variables,ds.data.Properties.VariableNames);
                    plotProperties=ds.plotProperties;
                    ds.data=ds.data(:,columns);
                    if iscell(plotProperties)&&size(plotProperties,1)>=max(columns)
                        ds.plotProperties=plotProperties(columns,:);
                    end
                    ds.ensurePlotProperties();
                    proxy.data=ds;
                else, proxy.data=dataseries.empty;
                end
                regions=struct([]); if source.zone==0 && source.outlines, regions=live.referenceRegions(); end
                viewport=[]; if isfield(source,'viewport'), viewport=source.viewport; end
                obj.Entries(end+1)=struct('session',session,'model',model,'proxy',proxy,'selected',selected, ...
                    'overlay',source.overlay,'regions',regions,'frameCount',count,'viewport',viewport);
            end
            counts=[obj.Entries.frameCount];
            if (ischar(settings.frames)||isstring(settings.frames))&&strcmpi(strtrim(settings.frames),'all')
                assert(all(counts==counts(1)),'detecdivui:ExportFrames', ...
                    'The selected images have different frame counts. Choose a common frame range or export separately.');
            end
            frames=obj.parseFrames(settings.frames,min(counts));
            mode=settings.mode; if strcmp(mode,'images'), mode='movie'; end
            opts=score_collectDisplayOptions('mode',mode,'frames',frames,'IPS',settings.fps, ...
                'framerate',settings.interval,'hideStamp',~settings.timestamp,'timeOffset',settings.zeroTime, ...
                'title',settings.title,'ROITitle',settings.roiTitle,'fontSize',settings.fontSize, ...
                'textColor',settings.textColor,'background',settings.background,'legend',settings.legend, ...
                'track',settings.track,'trackWindow',settings.trackWindow,'dataColormap',settings.dataColormap, ...
                'eventMarkers',settings.events,'Nbrick',settings.imageDataRatio);
            n=numel(obj.Entries); rows=settings.rows; cols=settings.columns;
            if rows==0 && cols==0
                cols=ceil(sqrt(n)); rows=ceil(n/cols);
            elseif rows==0
                rows=ceil(n/cols);
            elseif cols==0
                cols=ceil(n/rows);
            end
            assert(rows*cols>=n,'detecdivui:ExportGrid','The mosaic grid is too small for the selected images.');
            opts.Nrow=rows; opts.Ncol=cols; opts.Ndataseries=0;
            opts.plotidx={}; opts.dataidx={}; opts.plotidxgroup={}; opts.ngroup=0;
            if settings.includeData
                opts.Ndataseries=1; opts.ngroup=1; opts.dataidx={1};
                variables=obj.Entries(1).proxy.data.data.Properties.VariableNames;
                [~,indices]=ismember(dataSelection.variables,variables);
                opts.plotidx={indices}; opts.plotidxgroup={dataSelection.label};
            end
            obj.Options=opts;
            widths=[]; heights=[]; titles={};
            for k=1:n
                views=obj.frameViews(k,frames(1));
                names=cellfun(@(v)v.title,views,'UniformOutput',false);
                if k==1
                    titles=names;
                else
                    assert(isequal(names,titles),'detecdivui:ExportPanels', ...
                        'The selected images use different channel panels. Export them separately or align their Display layout.');
                end
                for j=1:numel(views)
                    widths(end+1)=size(views{j}.pixels,2); heights(end+1)=size(views{j}.pixels,1); %#ok<AGROW>
                end
            end
            opts.overlay=isscalar(titles); opts.Nchannel=numel(titles);
            opts.NintensityChannel=numel(titles); opts.channel=titles; opts.channelLabel=titles; opts.nonIndexedNames=titles;
            opts.levels=repmat({[0 255]},1,numel(titles)); opts.displayLevels=opts.levels;
            opts.RGB=repmat({[1 1 1]},1,numel(titles)); opts.scale=false(1,numel(titles));
            opts.tileW=max(widths)/opts.Nbrick; opts.tileH=max(heights)/opts.Nbrick;
            opts.movieProfile=settings.profile; opts.compositeProvider=@(r,f,p)obj.composite(r,f,p);
            obj.Options=opts;
        end
        function views=frameViews(obj,index,frame)
            entry=obj.Entries(index);
            if entry.overlay
                views={entry.model.compose(frame,entry.selected)};
            else
                views=entry.model.separate(frame,entry.selected);
            end
            for k=1:numel(views)
                view=views{k};
                if ~isfield(view,'title'), view.title=''; end
                if view.native
                    view.pixels=im2uint8(workflowui.stretchToUnit(view.pixels,view.limits,false));
                else
                    view.pixels=im2uint8(view.pixels);
                end
                if ismatrix(view.pixels), view.pixels=repmat(view.pixels,1,1,3); end
                for region=reshape(entry.regions,1,[])
                    p=region.position;
                    item=struct('x',p(1)+[0 p(3) p(3) 0], 'y',p(2)+[0 0 p(4) p(4)], ...
                        'FaceColor',[.25 .9 .85],'FaceAlpha',.025,'EdgeColor',[.25 .9 .85],'LineWidth',1.5);
                    view.vectors=[view.vectors item];
                end
                view=obj.transform(view,entry.viewport); views{k}=view;
            end
        end
        function [rgb,vectors,overlay,alpha]=composite(obj,source,frame,opts)
            obj.checkCancel();
            index=find(arrayfun(@(e)isequal(e.proxy,source),obj.Entries),1);
            assert(~isempty(index),'detecdivui:ExportSource','The export source is unavailable.');
            views=obj.frameViews(index,opts.frames(frame));
            pixels=cellfun(@(v)v.pixels,views,'UniformOutput',false); rgb=cat(4,pixels{:});
            vectors=views{1}.vectors; overlay=zeros(size(rgb,1),size(rgb,2),3); alpha=zeros(size(rgb,1),size(rgb,2));
            if strcmpi(opts.mode,'sequence') && ~isempty(obj.Progress)
                obj.Progress(((index-1)*numel(opts.frames)+frame)/(numel(obj.Entries)*numel(opts.frames)+1));
            end
        end
        function figureHandle=preview(obj)
            opts=obj.Options; opts.mode='movie'; opts.previewOnly=true;
            figureHandle=figure('Visible','off','Color',opts.background,'IntegerHandle','off','Name','Movie Preview','NumberTitle','off');
            try
                handles=score_createDisplayHandles(opts,figureHandle);
                score_renderFinalFrame(handles,[obj.Entries.proxy],opts);
                figureHandle.Visible='on';
            catch err
                delete(figureHandle); rethrow(err);
            end
        end
        function path=write(obj,path,overwrite)
            if nargin<3, overwrite=false; end
            if strcmp(obj.Settings.mode,'movie')
                profiles=VideoWriter.getProfiles;
                assert(ismember(obj.Settings.profile,{profiles.Name}),'detecdivui:ExportProfile', ...
                    'The selected video profile is unavailable on this worker. Choose a compatible target; no fallback is allowed.');
            end
            [folder,name,suffix]=fileparts(path); if isempty(folder), folder=pwd; end
            if strcmp(obj.Settings.mode,'images'), name=[name suffix]; end
            assert(isfolder(folder)&&~isempty(name),'detecdivui:ExportPath','Choose an existing output folder and a filename.');
            extension=obj.extension(obj.Settings.mode,obj.Settings.profile); path=fullfile(folder,[name extension]);
            images=strcmp(obj.Settings.mode,'images');
            assert(~isfolder(path),'detecdivui:ExportExists','Choose a new sequence folder; existing folders are never merged or removed.');
            assert(overwrite||~isfile(path),'detecdivui:ExportExists','The output already exists. Choose another filename or confirm replacement.');
            temp=[tempname(folder) extension];
            opts=obj.Options; opts.name=temp; opts.exportCancel=@()obj.cancelled(); opts.exportProgress=@(f)obj.report(f);
            if images
                mkdir(temp); opts.imageSequence=struct('path',temp,'format',obj.Settings.imageFormat);
            end
            fig=figure('Visible','off','Color',opts.background,'IntegerHandle','off','HandleVisibility','callback');
            if isfield(opts,'exportAxesFont'), set(fig,'DefaultAxesFontName',opts.exportAxesFont); end
            if isfield(opts,'exportTextFont'), set(fig,'DefaultTextFontName',opts.exportTextFont); end
            cleanup=onCleanup(@()obj.cleanup(fig,temp));
            handles=score_createDisplayHandles(opts,fig);
            score_renderFinalFrame(handles,[obj.Entries.proxy],opts);
            obj.checkCancel();
            assert(isfile(temp)||isfolder(temp),'detecdivui:ExportOutput','The renderer did not create the requested output.');
            assert(~isfolder(path),'detecdivui:ExportExists','The destination folder appeared during export.');
            assert(overwrite||~isfile(path),'detecdivui:ExportExists','The destination appeared during export. Choose another filename.');
            [ok,message]=movefile(temp,path,'f'); assert(ok,'detecdivui:ExportMove','%s',message);
            obj.Output=path; obj.report(1); clear cleanup;
        end
        function descriptor=saveSnapshot(obj,folder)
            descriptor=detecdivui.MovieExportSnapshot.write(obj,folder);
        end
    end
    methods (Access=private)
        function view=transform(obj,view,viewport)
            s=obj.Settings; h=size(view.pixels,1); w=size(view.pixels,2); origin=[1 1];
            crop=s.crop;
            if isempty(crop)&&isfield(s,'useViewport')&&s.useViewport&&numel(viewport)==4
                x=max(1,ceil(viewport(1))); y=max(1,ceil(viewport(3)));
                crop=[x y min(w,floor(viewport(2)))-x+1 min(h,floor(viewport(4)))-y+1];
                assert(all(crop(3:4)>0),'detecdivui:ExportViewport','The current view is outside the image. Fit Image before exporting.');
            end
            if ~isempty(crop)
                p=crop;
                validateattributes(p,{'numeric'},{'numel',4,'integer','positive','finite'});
                assert(p(1)+p(3)-1<=w && p(2)+p(4)-1<=h,'detecdivui:ExportCrop','Crop must fit every selected image.');
                view.pixels=view.pixels(p(2):p(2)+p(4)-1,p(1):p(1)+p(3)-1,:); origin=p(1:2);
            end
            oldH=size(view.pixels,1); oldW=size(view.pixels,2);
            if s.scale~=1, view.pixels=imresize(view.pixels,s.scale,'nearest'); end
            h=size(view.pixels,1); w=size(view.pixels,2); scale=[w/oldW h/oldH];
            if strcmp(s.flip,'Vertical'), view.pixels=flipud(view.pixels);
            elseif strcmp(s.flip,'Horizontal'), view.pixels=fliplr(view.pixels); end
            turns=round(s.rotation/90); view.pixels=rot90(view.pixels,turns);
            for k=1:numel(view.vectors)
                v=view.vectors(k); x=(v.x-origin(1)+.5)*scale(1)+.5; y=(v.y-origin(2)+.5)*scale(2)+.5;
                if strcmp(s.flip,'Vertical'), y=h+1-y; elseif strcmp(s.flip,'Horizontal'), x=w+1-x; end
                for turn=1:turns, nextX=y; y=w+1-x; x=nextX; swap=w; w=h; h=swap; end
                view.vectors(k).x=x; view.vectors(k).y=y;
                % Rotation dimensions are per-vector, not cumulative.
                h=size(view.pixels,1); w=size(view.pixels,2); if mod(turns,2), swap=w; w=h; h=swap; end
            end
        end
        function yes=cancelled(obj)
            yes=~isempty(obj.Cancel)&&obj.Cancel();
        end
        function checkCancel(obj)
            if obj.cancelled(), error('score:ExportCancelled','Export cancelled.'); end
        end
        function report(obj,fraction)
            if ~isempty(obj.Progress), obj.Progress(fraction); end
        end
    end
    methods (Static)
        function settings=defaults()
            settings=struct('mode','movie','profile','MPEG-4','imageFormat','png','fps',20,'interval',1,'frames','all', ...
                'timestamp',true,'zeroTime',true,'title','','roiTitle',true,'scale',1,'crop',[],'useViewport',true, ...
                'rotation',0,'flip','None','fontSize',10,'textColor',[1 1 1],'background',[0 0 0], ...
                'rows',0,'columns',0,'includeDrafts',true,'includeData',false,'legend',true, ...
                'track',false,'trackWindow',20,'dataColormap','lines','imageDataRatio',3,'events',{{}});
        end
        function frames=parseFrames(value,count)
            if isnumeric(value)
                frames=double(value(:)');
            else
                value=strtrim(char(string(value)));
                if isempty(value)||strcmpi(value,'all'), frames=1:count; return; end
                assert(~isempty(regexp(value,'^[\d\s,:;\[\]]+$','once')),'detecdivui:ExportFrames','Use frame numbers or ranges such as 1:2:100.');
                parts=regexp(strrep(strrep(value,'[',''),']',''),'[,;\s]+','split'); frames=[];
                for k=1:numel(parts)
                    if isempty(parts{k}), continue; end
                    assert(~isempty(regexp(parts{k},'^\d+(?::\d+){0,2}$','once')), ...
                        'detecdivui:ExportFrames','Use frame numbers or ranges such as 1:2:100.');
                    v=sscanf(strrep(parts{k},':',' '),'%f')';
                    assert(numel(v)<=3&&all(v>=1&v<=count),'detecdivui:ExportFrames','Frames must be within 1:%d.',count);
                    if isscalar(v)
                        next=v;
                    elseif numel(v)==2
                        next=v(1):v(2);
                    else
                        next=v(1):v(2):v(3);
                    end
                    frames=[frames next]; %#ok<AGROW>
                end
            end
            assert(~isempty(frames)&&all(isfinite(frames)&frames==floor(frames)&frames>=1&frames<=count), ...
                'detecdivui:ExportFrames','Choose existing positive frame numbers.');
            assert(all(diff(frames)>0),'detecdivui:ExportFrames','Frames must be in increasing order without duplicates.');
        end
        function extension=extension(mode,profile)
            if strcmpi(mode,'images')
                extension='';
            elseif strcmpi(mode,'sequence')
                extension='.pdf';
            elseif strcmp(profile,'MPEG-4')
                extension='.mp4';
            elseif any(strcmp(profile,{'Archival','Motion JPEG 2000'}))
                extension='.mj2';
            else
                extension='.avi';
            end
        end
        function obj=fromSnapshot(path,checksum)
            payload=detecdivui.MovieExportSnapshot.read(path,checksum);
            obj=detecdivui.MovieExportJob(); obj.Settings=payload.settings; obj.Options=payload.options;
            for k=1:numel(payload.entries)
                item=payload.entries(k); proxy=roi(item.id,item.value); proxy.display=item.display;
                if ~isempty(item.data)
                    ds=dataseries(); names=fieldnames(item.data);
                    for j=1:numel(names), ds.(names{j})=item.data.(names{j}); end
                    proxy.data=ds;
                else, proxy.data=dataseries.empty;
                end
                session=detecdivui.MovieSnapshotSession(item,proxy,fileparts(path));
                model=detecdivui.LayerModel(); model.restoreSnapshot(session,item.layers,item.styles);
                obj.Entries(end+1)=struct('session',session,'model',model,'proxy',proxy,'selected',item.selected, ...
                    'overlay',item.overlay,'regions',item.regions,'frameCount',item.frameCount,'viewport',item.viewport);
            end
            obj.Options.compositeProvider=@(r,f,p)obj.composite(r,f,p);
        end
    end
    methods (Static,Access=private)
        function copy=copyROI(source)
            copy=roi(source.id,source.value); copy.path=source.path; copy.image=source.image;
            copy.display=source.display; copy.channelid=source.channelid;
            copy.cellModel=source.cellModel; copy.cellModelInfo=source.cellModelInfo;
        end
        function copy=copyData(source)
            copy=dataseries(); fields=properties(source);
            for k=1:numel(fields), copy.(fields{k})=source.(fields{k}); end
        end
        function cleanup(fig,temp)
            if isgraphics(fig), delete(fig); end
            if isfile(temp), delete(temp); end
            if isfolder(temp)
                parent=char(java.io.File(fileparts(temp)).getCanonicalPath());
                actual=char(java.io.File(temp).getCanonicalPath());
                assert(strcmpi(fileparts(actual),parent),'detecdivui:ExportCleanup','Temporary output escaped its output directory.');
                rmdir(temp,'s');
            end
        end
    end
end
