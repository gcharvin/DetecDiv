classdef MovieExportSnapshot
    % Portable data-only snapshots: selected planes/frames, never model folders.
    methods (Static)
        function descriptor=write(job,folder)
            assert(~isfolder(folder)&&~isfile(folder),'detecdivui:SnapshotExists','Choose a new export snapshot directory.');
            mkdir(folder);
            options=job.Options; options=rmfield(options,'compositeProvider');
            options.exportDPI=round(get(groot,'ScreenPixelsPerInch'));
            options.exportAxesFont=get(groot,'DefaultAxesFontName'); options.exportTextFont=get(groot,'DefaultTextFontName');
            payload=struct('schema','detecdiv.viewer_movie_snapshot.v1','settings',job.Settings, ...
                'options',options,'renderSignature',detecdivui.MovieExportSnapshot.renderSignature(),'entries',struct([]));
            total=numel(job.Entries)*numel(options.frames); done=0;
            for k=1:numel(job.Entries)
                e=job.Entries(k); keep=unique([find([e.model.Layers.visible]) e.selected],'stable');
                layers=e.model.Layers(keep); styles=cell(1,numel(keep)); planes=zeros(1,numel(keep));
                lineages=cell(numel(keep),numel(options.frames));
                parentLinks=arrayfun(@(index)e.model.parentLinks(index),keep);
                asset=sprintf('pixels_%03d.h5',k); file=fullfile(folder,asset);
                for j=1:numel(keep)
                    first=e.model.read(keep(j),options.frames(1)); planes(j)=size(first,3);
                    h5create(file,sprintf('/layer_%03d',j),[size(first,1) size(first,2) planes(j) numel(options.frames)], ...
                        'Datatype',class(first),'ChunkSize',[min(128,size(first,1)) min(128,size(first,2)) planes(j) 1],'Deflate',4);
                    styles{j}=e.model.labelStyle(keep(j));
                end
                for frame=reshape(options.frames,1,[])
                    detecdivui.MovieExportSnapshot.checkCancel(job);
                    local=find(options.frames==frame,1);
                    for j=1:numel(keep)
                        pixels=e.model.read(keep(j),frame);
                        h5write(file,sprintf('/layer_%03d',j),pixels,[1 1 1 local],[size(pixels,1) size(pixels,2) planes(j) 1]);
                        lineages{j,local}=e.model.lineageVectors(keep(j),frame);
                    end
                    done=done+1;
                    if ~isempty(job.Progress), job.Progress(done/(total+1)); end
                    drawnow;
                end
                data=[];
                if ~isempty(e.proxy.data)
                    d=e.proxy.data(1); data=struct();
                    for name={'id','groupid','type','data','plotProperties','groupProperties','plotGroup','description','show'}
                        data.(name{1})=d.(name{1});
                    end
                end
                metadata=struct('channel',{{layers.name}},'indexed',strcmp({layers.kind},'Labels'));
                item=struct('id',e.proxy.id,'value',e.proxy.value,'display',metadata,'layers',layers, ...
                    'styles',{styles},'planes',planes,'width',size(first,2),'height',size(first,1), ...
                    'asset',asset,'sha256',detecdivui.MovieExportSnapshot.hashFile(file), ...
                    'frames',options.frames,'frameCount',e.frameCount,'selected',find(keep==e.selected,1), ...
                    'overlay',e.overlay,'regions',e.regions,'viewport',e.viewport,'data',data, ...
                    'lineages',{lineages},'parentLinks',parentLinks);
                if isempty(payload.entries), payload.entries=item; else, payload.entries(k)=item; end
            end
            % Resolve export geometry once on the client; a worker must match
            % it exactly, rather than silently changing text/layout presets.
            payload.options.expectedCanvas=detecdivui.MovieExportSnapshot.canvas(job,options);
            detecdivui.MovieExportSnapshot.assertDataOnly(payload);
            path=fullfile(folder,'snapshot.mat'); save(path,'payload','-v7.3');
            descriptor=struct('path',path,'sha256',detecdivui.MovieExportSnapshot.hashFile(path), ...
                'schema',payload.schema,'canvasSize',payload.options.expectedCanvas);
        end
        function payload=read(path,checksum)
            assert(strcmpi(detecdivui.MovieExportSnapshot.hashFile(path),checksum),'detecdivui:SnapshotChecksum', ...
                'The export snapshot changed after submission.');
            stored=load(path,'payload'); payload=stored.payload;
            assert(strcmp(payload.schema,'detecdiv.viewer_movie_snapshot.v1'),'detecdivui:SnapshotVersion','Unsupported export snapshot version.');
            assert(strcmp(payload.renderSignature,detecdivui.MovieExportSnapshot.renderSignature()), ...
                'detecdivui:SnapshotRenderer','The worker renderer differs from this viewer. Publish/use the matching DetecDiv release.');
            for item=reshape(payload.entries,1,[])
                assert(~isempty(regexp(item.asset,'^pixels_\d+\.h5$','once')), ...
                    'detecdivui:SnapshotAsset','Invalid snapshot asset path.');
                file=fullfile(fileparts(path),item.asset);
                assert(strcmpi(detecdivui.MovieExportSnapshot.hashFile(file),item.sha256), ...
                    'detecdivui:SnapshotChecksum','A snapshot pixel file changed after submission.');
            end
        end
        function checksum=hashFile(path)
            digest=java.security.MessageDigest.getInstance('SHA-256');
            stream=java.security.DigestInputStream(java.io.FileInputStream(java.io.File(path)),digest);
            cleanup=onCleanup(@()stream.close()); buffer=zeros(1,1024*1024,'int8');
            while stream.read(buffer,0,numel(buffer))>=0, end
            raw=typecast(digest.digest(),'uint8'); checksum=lower(reshape(dec2hex(raw,2).',1,[]));
        end
        function signature=renderSignature()
            names={'detecdivui.MovieExportJob','detecdivui.MovieSnapshotSession','detecdivui.MovieExportSnapshot', ...
                'detecdivui.LayerModel','score_makeComposite','score_renderFinalFrame','score_updateRender', ...
                'score_layoutExport','score_captureMovieFrame','score_exportSequence','score_displayVectorGraphics', ...
                'score_displayDataPanel','score_drawMovieEventText','score_drawMovieEventLines'};
            digest=java.security.MessageDigest.getInstance('SHA-256');
            for k=1:numel(names)
                text=strrep(fileread(which(names{k})),sprintf('\r\n'),newline);
                digest.update(typecast(unicode2native([names{k} newline text],'UTF-8'),'int8'));
            end
            raw=typecast(digest.digest(),'uint8'); signature=lower(reshape(dec2hex(raw,2).',1,[]));
        end
        function commit=publishedCode()
            root=fileparts(which('detecdiv_ui'));
            [status,commit]=system(sprintf('git -C "%s" rev-parse HEAD',root)); commit=strtrim(commit);
            assert(status==0&&~isempty(regexp(commit,'^[a-f0-9]{40}$','once')), ...
                'detecdivui:ExportRelease','Run this viewer from a versioned DetecDiv checkout.');
            paths='structure/GUI/+detecdivui engine/export/+movieExport structure/GUI/score helpers/detecdiv_movie_export_submit.m helpers/detecdiv_hub_submit_pipeline_run.m';
            [status,dirty]=system(sprintf('git -C "%s" status --porcelain -- %s',root,paths));
            assert(status==0&&isempty(strtrim(dirty)),'detecdivui:ExportRelease', ...
                'Commit and publish the current exporter changes before Hub export; the worker must use this exact renderer release.');
        end
    end
    methods (Static,Access=private)
        function assertDataOnly(value)
            if isstruct(value)
                names=fieldnames(value);
                for k=1:numel(value)
                    for j=1:numel(names), detecdivui.MovieExportSnapshot.assertDataOnly(value(k).(names{j})); end
                end
            elseif iscell(value)
                for k=1:numel(value), detecdivui.MovieExportSnapshot.assertDataOnly(value{k}); end
            elseif istable(value)
                names=value.Properties.VariableNames;
                for k=1:numel(names), detecdivui.MovieExportSnapshot.assertDataOnly(value.(names{k})); end
            else
                assert(isnumeric(value)||islogical(value)||ischar(value)||isstring(value)|| ...
                    iscategorical(value)||isdatetime(value)||isduration(value), ...
                    'detecdivui:SnapshotData','Export snapshots accept data values, not application/model handles.');
            end
        end
        function checkCancel(job)
            if ~isempty(job.Cancel)&&job.Cancel(), error('score:ExportCancelled','Export cancelled.'); end
        end
        function size=canvas(job,options)
            options.previewOnly=true; options.compositeProvider=@(r,f,p)job.composite(r,f,p);
            fig=figure('Visible','off','IntegerHandle','off','HandleVisibility','callback');
            cleanup=onCleanup(@()delete(fig));
            set(fig,'DefaultAxesFontName',options.exportAxesFont,'DefaultTextFontName',options.exportTextFont);
            handles=score_createDisplayHandles(options,fig); graphics=score_renderFinalFrame(handles,[job.Entries.proxy],options);
            if isfield(graphics,'movieLayout'), size=graphics.movieLayout.canvasSize;
            else, size=graphics.sequenceLayout.canvasSize; end
        end
    end
end
