function [tracked,frames,refs] = inferStack(roiobj,classif,p,ctx)
%INFERSTACK Run the existing EDGE/APPEAR/END backend without GUI ownership.
if nargin<4||isempty(ctx),ctx=struct();end
detecdiv_check_cancel(ctx,'cellLatentTracker start');
if isempty(roiobj.image),roiobj.load;end
frames=resolveFrames(ctx,size(roiobj.image,4));
if any(diff(frames)~=1)
    error('cellLatentTracker:NonContiguousFrames', ...
        'Latent tracking requires one contiguous frame interval.');
end
instanceName=textValue(p.instanceChannelName);
imageName=textValue(p.imageChannelName);
selected=selectedChannels(ctx);
if isempty(instanceName)
    if numel(selected)>=2,instanceName=selected{2};elseif numel(selected)==1,instanceName=selected{1};end
end
if isempty(imageName)&&numel(selected)>=2,imageName=selected{1};end
if isempty(instanceName)
    error('cellLatentTracker:MissingInstanceChannel', ...
        'Select the frame-local instance-mask channel.');
end
instances=readStack(roiobj,instanceName,frames,true);
brightfield=[];
if ~isempty(imageName),brightfield=readStack(roiobj,imageName,frames,false);end
checkpointDir=resolveArtifact(classif,p.checkpointDir);
if ~isfile(fullfile(checkpointDir,'manifest.json'))
    error('cellLatentTracker:MissingCheckpoint', ...
        'The latent-tracker checkpoint was not found: %s',checkpointDir);
end
workDir=resolveWorkDir(ctx,classif,roiobj);
inputPath=fullfile(workDir,'input_frame_local_instances.h5');
resultPath=fullfile(workDir,'pred_stable_tracks.mat');
auditPath=fullfile(workDir,'pred_stable_tracks_audit.json');
configPath=fullfile(workDir,'latent_tracker_config.json');
writeStack(inputPath,'/input_frame_local_instances',instances,'uint32');
if ~isempty(brightfield),writeStack(inputPath,'/input_brightfield',brightfield,'single');end
cfg=struct('schema_version',1, ...
    'input_path',normalizedPath(inputPath), ...
    'instances_dataset','/input_frame_local_instances', ...
    'brightfield_dataset','', ...
    'checkpoint_dir',normalizedPath(checkpointDir), ...
    'output_mat_path',normalizedPath(resultPath), ...
    'output_json_path',normalizedPath(auditPath), ...
    'roi_id',char(string(roiobj.id)), ...
    'top_k',positiveInteger(p.topK,'topK'), ...
    'frame_interval_minutes',positiveScalar( ...
        p.frameIntervalMinutes,'frameIntervalMinutes'), ...
    'device',textValue(p.device), ...
    'solver_parameters',struct('milp_time_limit_seconds', ...
        positiveScalar(p.solverTimeLimitSeconds,'solverTimeLimitSeconds')));
if ~isempty(brightfield),cfg.brightfield_dataset='/input_brightfield';end
writeJson(configPath,cfg);
runtime=cellLatentModel.utils.runPythonModule( ...
    'infer-detecdiv-tracking',configPath,ctx,fullfile(workDir,'stdout.txt'));
detecdiv_check_cancel(ctx,'cellLatentTracker after inference');
if ~isfile(resultPath)||~isfile(auditPath)
    error('cellLatentTracker:MissingResult', ...
        'Latent tracker produced no result/audit artifact.');
end
loaded=load(resultPath,'pred_stable_tracks');
tracked=uint32(loaded.pred_stable_tracks);
if ismatrix(tracked),tracked=reshape(tracked,size(tracked,1),size(tracked,2),1);end
if ~isequal(size(tracked),[size(roiobj.image,1),size(roiobj.image,2),numel(frames)])
    error('cellLatentTracker:ResultShapeMismatch', ...
        'Tracked-mask result has unexpected shape %s.',mat2str(size(tracked)));
end
if max(tracked(:))>intmax('uint16')
    error('cellLatentTracker:TooManyTracks','Track ID exceeds uint16 ROI storage.');
end
refs=struct('workDir',workDir,'audit',auditPath, ...
    'stdout',fullfile(workDir,'stdout.txt'),'runtime',runtime, ...
    'instanceChannel',instanceName,'brightfieldChannel',imageName, ...
    'checkpointDir',checkpointDir);
end

function frames=resolveFrames(ctx,n),frames=[];try frames=ctx.sel.frames;catch,end;if isempty(frames)||isequal(frames,-1),frames=1:n;else,frames=unique(round(double(frames(:)')),'stable');frames=frames(isfinite(frames)&frames>=1&frames<=n);end,if isempty(frames),error('cellLatentTracker:EmptyFrames','No valid frame selected.');end,end
function names=selectedChannels(ctx),names={};try raw=ctx.sel.channels;if ischar(raw)||isstring(raw),names=cellstr(string(raw));elseif iscell(raw),names=cellfun(@(x)char(string(x)),raw,'UniformOutput',false);end,catch,end,names=names(~cellfun(@isempty,names));end
function stack=readStack(roiobj,name,frames,isLabels),try idx=roiobj.findChannelID(name,'exact');catch,idx=roiobj.findChannelID(name);end,if isempty(idx),error('cellLatentTracker:ChannelNotFound','Channel "%s" was not found.',name);end,stack=squeeze(roiobj.image(:,:,idx(1),frames));if numel(frames)==1,stack=reshape(stack,size(stack,1),size(stack,2),1);end,if isLabels,values=double(stack(:));if any(~isfinite(values))||any(values<0)||any(mod(values,1)~=0),error('cellLatentTracker:InvalidLabels','Channel "%s" must contain integer labels.',name);end,stack=uint32(stack);else,stack=single(stack);end,end
function writeStack(filename,dataset,stack,datatype),stored=permute(stack,[2 1 3]);sz=[size(stack,2),size(stack,1),size(stack,3)];h5create(filename,dataset,sz,'Datatype',datatype,'ChunkSize',[min(sz(1),256),min(sz(2),256),1],'Deflate',1);h5write(filename,dataset,stored);h5writeatt(filename,dataset,'axis_order','time,y,x');end
function folder=resolveWorkDir(ctx,classif,roiobj),folder='';try folder=ctx.workDir;catch,end,if isempty(folder),try folder=fullfile(classif.path,'work','cellLatentTracker');catch,folder=fullfile(tempdir,'detecdiv_cell_latent_tracker');end,end,safe=regexprep(char(string(roiobj.id)),'[^A-Za-z0-9_.-]','_');stamp=char(datetime('now','Format','yyyyMMdd''T''HHmmssSSS'));folder=fullfile(folder,[safe '_' stamp]);if exist(folder,'dir')~=7,mkdir(folder);end,end
function value=resolveArtifact(classif,value),value=textValue(value);if isempty(value),return;end,if ~isfolder(value),try candidate=fullfile(classif.path,value);if isfolder(candidate),value=candidate;end,catch,end,end,end
function writeJson(filename,value),fid=fopen(filename,'w');if fid<0,error('cellLatentTracker:ConfigWriteFailed','Cannot write %s.',filename);end,cleanup=onCleanup(@()fclose(fid));fwrite(fid,jsonencode(value,'PrettyPrint',true),'char');end %#ok<NASGU>
function value=normalizedPath(value),value=strrep(char(string(value)),'\','/');end
function value=textValue(value),while iscell(value),if isempty(value),value='';return;else,value=value{end};end,end,value=strtrim(char(string(value)));end
function value=positiveScalar(value,name),value=double(value);if ~isscalar(value)||~isfinite(value)||value<=0,error('cellLatentTracker:InvalidParameter','%s must be positive.',name);end,end
function value=positiveInteger(value,name),value=round(positiveScalar(value,name));end
