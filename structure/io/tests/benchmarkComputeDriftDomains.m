function records = benchmarkComputeDriftDomains(projectFiles,outputDir,varargin)
% Read-only, domain-independent registration benchmark on real source images.
% Known translations are injected into early/late images from several FOVs.
% No project object, ROI, raw file, classifier or project result is modified.
ip=inputParser;
ip.addParameter('MaxFOVs',3);
ip.addParameter('BaselineFcn',[]);
ip.addParameter('BaselineLabel','baseline');
ip.parse(varargin{:}); o=ip.Results;
if ~iscell(projectFiles), projectFiles=cellstr(projectFiles); end
if ~isfolder(outputDir), mkdir(outputDir); end
cases(1)=struct('name','fractional','rows',[0 .25 .4 -.35 .2 -.1], ...
    'cols',[0 -.3 .25 .4 -.35 -.25]);
cases(2)=struct('name','long','rows',0:4:40,'cols',0:-2:-20);
cases(3)=struct('name','photometric','rows',[0 1.3 2.6 3.7 4.2], ...
    'cols',[0 -.8 -1.6 -2.4 -3.2]);
records=struct([]);
for p=1:numel(projectFiles)
    manifest=jsondecode(fileread(projectFiles{p}));
    [parent,name]=fileparts(projectFiles{p}); projectDir=fullfile(parent,name);
    valid=find(~cellfun(@isempty,{manifest.fovs.id}));
    valid=valid(1:min(numel(valid),o.MaxFOVs));
    for fi=valid
        meta=jsondecode(fileread(fullfile(projectDir,manifest.fovs(fi).metadataPath)));
        raw=detecdiv_paths_prefer_local(meta.srcpath{1});
        token=regexp(meta.channel{1},'channel(\d+)_z(\d+)','tokens','once');
        assert(~isempty(token),'Benchmark source needs a declared channel/z TIFF mapping.');
        files=dir(fullfile(raw,sprintf('*channel%s*_z%s.tif',token{1},token{2})));
        assert(~isempty(files),'No benchmark source images in %s.',raw);
        for snapshot=unique([1 numel(files)])
            source=fullfile(files(snapshot).folder,files(snapshot).name);
            ref=imread(source);
            for ci=1:numel(cases)
                c=cases(ci);
                images=zeros(size(ref,1),size(ref,2),1,numel(c.rows),'like',ref);
                for k=1:numel(c.rows)
                    images(:,:,1,k)=imtranslate(ref,[c.cols(k) c.rows(k)], ...
                        'linear','FillValues',median(ref(:)));
                    if strcmp(c.name,'photometric') && k>1
                        images(:,:,1,k)=cast(double(images(:,:,1,k))*(.65+.07*k)+250*k,'like',ref);
                    end
                end
                for solver=1:(1+~isempty(o.BaselineFcn))
                    f=fov(); args={'images',images,'refimage',ref,'method','robust', ...
                        'maxshift',20,'maxstep',10,'hipasssigma',3,'apodize',true};
                    started=tic;
                    if solver==1
                        [~,d]=f.computeDrift(args{:}); label='improved';
                    else
                        [~,d]=o.BaselineFcn(f,args{:}); label=o.BaselineLabel;
                    end
                    r=struct('project',manifest.projectName,'fov',meta.id, ...
                        'source',source,'sourceFrame',snapshot,'imageSize',size(ref), ...
                        'case',c.name,'solver',label,'seconds',toc(started), ...
                        'rowError',d.x+c.rows,'colError',d.y+c.cols);
                    r.maxError=max(hypot(r.rowError,r.colError));
                    r.rmsError=sqrt(mean(r.rowError.^2+r.colError.^2));
                    r.rejectedFrames=[];
                    if isfield(d,'accepted'), r.rejectedFrames=find(~d.accepted); end
                    if isempty(records), records=r;
                    else, records(end+1)=r; end %#ok<AGROW>
                    fprintf('%s %s frame=%d %s %s max=%.4fpx rms=%.4fpx time=%.2fs\n', ...
                        r.project,r.fov,snapshot,c.name,label,r.maxError,r.rmsError,r.seconds);
                    fid=fopen(fullfile(outputDir,'benchmark.json'),'w');
                    fprintf(fid,'%s',jsonencode(records,PrettyPrint=true)); fclose(fid);
                end
                clear images
            end
        end
    end
end
end
