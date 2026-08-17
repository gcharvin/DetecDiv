function out = classify(roiobj,classif,ctx)
%CELLLATENTTRACKER.CLASSIFY Assign stable IDs from frame-local instances.
if nargin<3||isempty(ctx),ctx=struct();end
out=cellLatentModel.utils.outInitSafe('cellLatentTracker.classify');
cellLatentTracker.ensureClassMetadata(classif);
p=cellLatentTracker.utils.defaultExecutionParam();
try p=cellLatentModel.utils.applyOverrides(p,classif.executionParam);catch,end
if isfield(ctx,'params')&&isstruct(ctx.params)
    runtime=ctx.params;
    if isfield(runtime,'checkpointDir'),runtime=rmfield(runtime,'checkpointDir');end
    p=cellLatentModel.utils.applyOverrides(p,runtime);
end
[tracked,frames,inference]=cellLatentTracker.inferStack( ...
    roiobj,classif,p,ctx);
workDir=inference.workDir;
auditPath=inference.audit;
runtime=inference.runtime;
outputName=physicalOutputName(textValue(p.outputName));
outImage=roiobj.image; idx=roiobj.findChannelID(outputName);
if isempty(idx)
    empty=zeros(size(outImage,1),size(outImage,2),1,size(outImage,4),'uint16');
    roiobj.addChannel(empty,outputName,[1 1 1],[0 0 0]);
    outImage=roiobj.image; idx=roiobj.findChannelID(outputName);
end
idx=idx(1);
outImage(:,:,idx,frames)=reshape(uint16(tracked),size(tracked,1), ...
    size(tracked,2),1,size(tracked,3));
audit=jsondecode(fileread(auditPath));
out.status="OK"; out.data=roiobj.data; out.image=outImage; out.patch=[];
out.artifacts.workDir=workDir; out.artifacts.audit=auditPath;
out.artifacts.stdout=fullfile(workDir,'stdout.txt');
out.metrics=audit.summary;
out.refs.outputChannel=outputName; out.refs.runtime=runtime;
if logical(p.debug)
    fprintf('[cellLatentTracker] ROI=%s detections=%d tracks=%d output=%s\n', ...
        char(string(roiobj.id)),double(audit.summary.detections), ...
        double(audit.summary.tracks),outputName);
end
end

function frames=resolveFrames(ctx,n),frames=[];try frames=ctx.sel.frames;catch,end;if isempty(frames)||isequal(frames,-1),frames=1:n;else,frames=unique(round(double(frames(:)')),'stable');frames=frames(isfinite(frames)&frames>=1&frames<=n);end,if isempty(frames),error('cellLatentTracker:EmptyFrames','No valid frame selected.');end,end
function names=selectedChannels(ctx),names={};try raw=ctx.sel.channels;if ischar(raw)||isstring(raw),names=cellstr(string(raw));elseif iscell(raw),names=cellfun(@(x)char(string(x)),raw,'UniformOutput',false);end,catch,end,names=names(~cellfun(@isempty,names));end
function stack=readStack(roiobj,name,frames,isLabels),try idx=roiobj.findChannelID(name,'exact');catch,idx=roiobj.findChannelID(name);end,if isempty(idx),error('cellLatentTracker:ChannelNotFound','Channel "%s" was not found.',name);end,stack=squeeze(roiobj.image(:,:,idx(1),frames));if numel(frames)==1,stack=reshape(stack,size(stack,1),size(stack,2),1);end,if isLabels,values=double(stack(:));if any(~isfinite(values))||any(values<0)||any(mod(values,1)~=0),error('cellLatentTracker:InvalidLabels','Channel "%s" must contain integer labels.',name);end,stack=uint32(stack);else,stack=single(stack);end,end
function writeStack(filename,dataset,stack,datatype),stored=permute(stack,[2 1 3]);sz=[size(stack,2),size(stack,1),size(stack,3)];h5create(filename,dataset,sz,'Datatype',datatype,'ChunkSize',[min(sz(1),256),min(sz(2),256),1],'Deflate',1);h5write(filename,dataset,stored);h5writeatt(filename,dataset,'axis_order','time,y,x');end
function folder=resolveWorkDir(ctx,classif,roiobj),folder='';try folder=ctx.workDir;catch,end,if isempty(folder),try folder=fullfile(classif.path,'work','cellLatentTracker');catch,folder=fullfile(tempdir,'detecdiv_cell_latent_tracker');end,end,safe=regexprep(char(string(roiobj.id)),'[^A-Za-z0-9_.-]','_');stamp=char(datetime('now','Format','yyyyMMdd''T''HHmmssSSS'));folder=fullfile(folder,[safe '_' stamp]);if exist(folder,'dir')~=7,mkdir(folder);end,end
function value=resolveArtifact(classif,value),value=textValue(value);if isempty(value),return;end,if ~isfolder(value),try candidate=fullfile(classif.path,value);if isfolder(candidate),value=candidate;end,catch,end,end,end
function name=physicalOutputName(name),if isempty(name),name='pred_latent_tracker_tracks';end,if ~startsWith(name,'results_','IgnoreCase',true),name=['results_' name];end,end
function writeJson(filename,value),fid=fopen(filename,'w');if fid<0,error('cellLatentTracker:ConfigWriteFailed','Cannot write %s.',filename);end,cleanup=onCleanup(@()fclose(fid));fwrite(fid,jsonencode(value,'PrettyPrint',true),'char');end %#ok<NASGU>
function value=normalizedPath(value),value=strrep(char(string(value)),'\','/');end
function value=textValue(value),while iscell(value),if isempty(value),value='';return;else,value=value{end};end,end,value=strtrim(char(string(value)));end
function value=positiveScalar(value,name),value=double(value);if ~isscalar(value)||~isfinite(value)||value<=0,error('cellLatentTracker:InvalidParameter','%s must be positive.',name);end,end
function value=positiveInteger(value,name),value=round(positiveScalar(value,name));end
