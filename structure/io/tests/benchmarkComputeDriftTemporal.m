function records = benchmarkComputeDriftTemporal(projectFiles,outputDir,varargin)
% Test equivariance to known added motion on real evolving image sequences.
% This checks temporal behavior without claiming unknown natural drift is GT.
ip=inputParser;
ip.addParameter('SampleCount',33,@(x)isnumeric(x)&&isscalar(x)&&x>=3);
ip.parse(varargin{:}); sampleCount=ip.Results.SampleCount;
if ~iscell(projectFiles), projectFiles=cellstr(projectFiles); end
if ~isfolder(outputDir), mkdir(outputDir); end
records=struct([]);
fig=figure('Visible','off','Position',[0 0 1200 850]);
layout=tiledlayout(numel(projectFiles),3,'TileSpacing','compact','Padding','compact');
for p=1:numel(projectFiles)
    manifest=jsondecode(fileread(projectFiles{p}));
    [parent,name]=fileparts(projectFiles{p}); projectDir=fullfile(parent,name);
    fi=find(~cellfun(@isempty,{manifest.fovs.id}),1);
    meta=jsondecode(fileread(fullfile(projectDir,manifest.fovs(fi).metadataPath)));
    raw=detecdiv_paths_prefer_local(meta.srcpath{1});
    token=regexp(meta.channel{1},'channel(\d+)_z(\d+)','tokens','once');
    files=dir(fullfile(raw,sprintf('*channel%s*_z%s.tif',token{1},token{2})));
    ids=unique([1:3 round(linspace(1,numel(files),sampleCount)) numel(files)-2:numel(files)]);
    first=imread(fullfile(files(1).folder,files(1).name));
    images=zeros(size(first,1),size(first,2),1,numel(ids),'like',first);
    for k=1:numel(ids), images(:,:,1,k)=imread(fullfile(files(ids(k)).folder,files(ids(k)).name)); end
    addedRow=.2*sin((0:numel(ids)-1)*.3)+.05*(0:numel(ids)-1);
    addedCol=.3*(cos((0:numel(ids)-1)*.4)-1)-.04*(0:numel(ids)-1);
    injected=images;
    for k=1:numel(ids)
        im=images(:,:,1,k);
        injected(:,:,1,k)=imtranslate(im,[addedCol(k) addedRow(k)], ...
            'linear','FillValues',median(im(:)));
    end
    args={'framesid',ids,'refimage',first,'method','robust', ...
        'maxshift',20,'maxstep',10,'hipasssigma',3,'apodize',true};
    f=fov(); started=tic;
    [~,original]=f.computeDrift('images',images,args{:});
    f=fov();
    [~,translated]=f.computeDrift('images',injected,args{:});
    common=original.accepted(ids)&translated.accepted(ids);
    errors=hypot(translated.x(ids)-original.x(ids)+addedRow, ...
        translated.y(ids)-original.y(ids)+addedCol);
    r=struct('project',manifest.projectName,'fov',meta.id,'frames',ids, ...
        'maxEquivarianceError',max(errors(common)),'rmsEquivarianceError',sqrt(mean(errors(common).^2)), ...
        'commonAccepted',nnz(common),'sampleCount',numel(ids),'seconds',toc(started), ...
        'originalTemporalFallbackFrames',ids(startsWith(original.estimation(ids),'temporalFallback')), ...
        'injectedTemporalFallbackFrames',ids(startsWith(translated.estimation(ids),'temporalFallback')), ...
        'original',original,'translated',translated,'errors',errors);
    if isempty(records), records=r; else, records(end+1)=r; end %#ok<AGROW>
    fprintf('%s: accepted %d/%d max equivariance error=%.4fpx rms=%.4fpx\n', ...
        r.project,r.commonAccepted,r.sampleCount,r.maxEquivarianceError,r.rmsEquivarianceError);
    for k=[1 round(numel(ids)/2) numel(ids)]
        im=images(:,:,1,k);
        im=imtranslate(im,[original.y(ids(k)) original.x(ids(k))],'linear','FillValues',median(im(:)));
        nexttile; imshow(imcrop(im,meta.rois(1).value),[]);
        title(sprintf('%s frame %d',manifest.projectName,ids(k)),'Interpreter','none');
    end
    fid=fopen(fullfile(outputDir,'temporal.json'),'w'); fprintf(fid,'%s',jsonencode(records,PrettyPrint=true)); fclose(fid);
    clear images injected
end
exportgraphics(layout,fullfile(outputDir,'natural_sequence_rois.png'));
close(fig);
end
