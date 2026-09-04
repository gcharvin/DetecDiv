function [paramout,dataout,imageout] = core(param,roiobj,ctx)
%SELECTCAVITYTRAJECTORY.CORE Select and materialize one cavity-role path.

if nargin < 3 || isempty(ctx), ctx=struct(); end
paramout=selectCavityTrajectory.normalizeParam(param,ctx);
[model,loadReport]=roiobj.loadCellModel('MigrateLegacy',true);
[familyIndex,familyId]=resolveFamily(model,paramout.inputFamily);
if isempty(familyIndex)
    error('selectCavityTrajectory:FamilyNotFound', ...
        'No usable cell-model family matches "%s".',paramout.inputFamily);
end
familyName=char(string(model.families.name{familyIndex}));
provider=char(string(model.families.mask_provider{familyIndex}));
if isempty(provider)
    error('selectCavityTrajectory:MissingMaskProvider', ...
        'Cell-model family "%s" has no mask provider.',familyName);
end

ensureFullFrameSelection(ctx,model,familyId);
if isempty(roiobj.image), roiobj.load; end
pix=roiobj.findChannelID(provider);
if isempty(pix)
    try roiobj.load('Channel',provider,'Data',false,'Silent'); catch, end
    pix=roiobj.findChannelID(provider);
end
if isempty(pix)
    error('selectCavityTrajectory:ChannelNotFound', ...
        'Mask-provider channel "%s" was not found.',provider);
end
pix=pix(1);
stack=squeeze(roiobj.image(:,:,pix,:));
if ismatrix(stack), stack=reshape(stack,size(stack,1),size(stack,2),1); end
[imageHeight,imageWidth,nFrames]=size(stack);

observations=instanceGeometry(model,familyId,stack);
result=selectCavityTrajectory.decode( ...
    model,familyId,observations,paramout,[imageHeight imageWidth],nFrames);
result.roi_id=safeRoiId(roiobj);
result.family_name=familyName;
result.mask_provider=provider;
result.created_at=char(datetime('now','Format','yyyy-MM-dd''T''HH:mm:ssXXX'));

[cellMask,budMask,objectMask]=materializeMasks( ...
    result.assignments,model,familyId,stack);
cellName=[paramout.outputChannelBase '_cell'];
budName=[paramout.outputChannelBase '_bud'];
objectName=[paramout.outputChannelBase '_object'];
replaceChannel(roiobj,cellName,cellMask,[1 0.2 0.2]);
replaceChannel(roiobj,budName,budMask,[0.2 1 0.2]);
replaceChannel(roiobj,objectName,objectMask,[1 0.8 0.1]);

ds=trajectoryDataseries(result,paramout.outputName,safeRoiId(roiobj));
roiobj.data=replaceDataseries(roiobj.data,paramout.outputName,ds);

artifactFile='';
if paramout.writeArtifact
    artifactFile=artifactPath(roiobj,paramout,ctx);
    writeResultJson(artifactFile,result,paramout,loadReport);
end
paramout.inputFamily=familyName;
paramout.inputFamilyId=double(familyId);
paramout.maskProvider=provider;
paramout.outputChannels={cellName,budName,objectName};
paramout.saveChannels=paramout.outputChannels;
paramout.artifactFile=artifactFile;
paramout.artifacts={};
if ~isempty(artifactFile), paramout.artifacts={artifactFile}; end
paramout.trajectory=result;
paramout.summary=result.diagnostics;
dataout=roiobj.data;
imageout=roiobj.image;
if paramout.debug
    fprintf(['[selectCavityTrajectory] ROI=%s family=%s mode=%s; ' ...
        '%d episodes, %d events, %d abstained frames.\n'], ...
        safeRoiId(roiobj),familyName,paramout.mode, ...
        result.diagnostics.occupancy_episodes,result.diagnostics.events, ...
        result.diagnostics.abstained_frames);
end
end

function [index,familyId]=resolveFamily(model,identifier)
index=[]; familyId=[];
if ~strcmp(char(string(identifier)),'<auto>')
    [index,familyId]=cellModel.familyIndex(model,identifier);
    return;
end
count=numel(model.families.family_id);
if count==0, return; end
source=lower(string(model.families.lineage_source(:)));
names=lower(string(model.families.name(:)));
candidates=find(contains(source,'celllatentmodel') | contains(names,'latent'));
if isempty(candidates)
    hasRelations=false(count,1);
    for i=1:count
        hasRelations(i)=any(model.relations.family_id==model.families.family_id(i));
    end
    candidates=find(hasRelations);
end
if isempty(candidates), candidates=(1:count)'; end
index=candidates(end); familyId=model.families.family_id(index);
end

function ensureFullFrameSelection(ctx,model,familyId)
frames=[];
if isfield(ctx,'frames'), frames=ctx.frames;
elseif isfield(ctx,'sel')&&isstruct(ctx.sel)&&isfield(ctx.sel,'frames'), frames=ctx.sel.frames;
end
if isempty(frames)||(isnumeric(frames)&&isscalar(frames)&&frames==-1), return; end
familyRows=model.instances.family_id==uint32(familyId);
if ~any(familyRows), return; end
nFrames=double(max(model.instances.frame(familyRows)));
selected=unique(round(double(frames(:)')));
if ~isequal(selected,1:nFrames)
    error('selectCavityTrajectory:FullROIRequired', ...
        'Global cavity-trajectory decoding requires the complete ROI frame range.');
end
end

function observations=instanceGeometry(model,familyId,stack)
rows=find(model.instances.family_id==uint32(familyId) & ...
    model.instances.track_id>0 & model.instances.frame>0);
n=numel(rows);
observations=struct('frame',zeros(n,1,'uint32'), ...
    'track_id',zeros(n,1,'uint64'),'mask_label',zeros(n,1,'uint32'), ...
    'centroid_x',nan(n,1),'centroid_y',nan(n,1),'area',zeros(n,1));
for i=1:n
    row=rows(i); t=double(model.instances.frame(row));
    label=model.instances.mask_label(row);
    if t>size(stack,3), continue; end
    [yy,xx]=find(stack(:,:,t)==label);
    observations.frame(i)=uint32(t);
    observations.track_id(i)=model.instances.track_id(row);
    observations.mask_label(i)=label;
    observations.area(i)=numel(xx);
    if ~isempty(xx)
        observations.centroid_x(i)=mean(xx);
        observations.centroid_y(i)=mean(yy);
    end
end
valid=observations.area>0;
names=fieldnames(observations);
for i=1:numel(names), observations.(names{i})=observations.(names{i})(valid,:); end
end

function [cellMask,budMask,objectMask]=materializeMasks(assign,model,familyId,stack)
[imageHeight,imageWidth,nFrames]=size(stack);
cellMask=zeros(imageHeight,imageWidth,1,nFrames,'uint8');
budMask=zeros(imageHeight,imageWidth,1,nFrames,'uint8');
for t=1:min(nFrames,height(assign))
    label=assign.MaskLabel(t);
    if label>0 && ~assign.Abstained(t)
        cellMask(:,:,1,t)=uint8(stack(:,:,t)==label);
    end
    bud=assign.CompanionBudTrackID(t);
    if bud==0, continue; end
    row=find(model.instances.family_id==uint32(familyId) & ...
        model.instances.frame==uint32(t) & model.instances.track_id==bud,1,'first');
    if ~isempty(row)
        budMask(:,:,1,t)=uint8(stack(:,:,t)==model.instances.mask_label(row));
    end
end
objectMask=uint8(cellMask>0 | budMask>0);
end

function replaceChannel(roiobj,name,value,color)
try
    if ~isempty(roiobj.findChannelID(name)), roiobj.removeChannel(name); end
catch
end
roiobj.addChannel(value,name,color,[0 0 0]);
end

function ds=trajectoryDataseries(result,outputName,roiId)
tbl=result.assignments;
groups=repmat({'cavity_trajectory'},1,width(tbl));
plots=repmat({false},1,width(tbl));
ds=dataseries(tbl,tbl.Properties.VariableNames,'groupid',outputName, ...
    'parentid',roiId,'plot',plots,'groups',groups, ...
    'class','processing','type','temporal');
ds.description=['Selected biological subject occupying a microfluidic ' ...
    'cavity role. TrackIDs remain those of the input cell model.'];
ds.userData=struct('format',result.format,'schema_version',1, ...
    'family_id',result.family_id,'family_name',result.family_name, ...
    'mask_provider',result.mask_provider,'mode',result.mode, ...
    'events',result.events,'lifespans',result.lifespans, ...
    'confidence_semantics',result.confidence_semantics);
end

function data=replaceDataseries(data,groupid,ds)
if isempty(data)||(isa(data,'dataseries')&&numel(data)==1&&isempty(data(1).groupid))
    data=ds; return;
end
try
    keep=~arrayfun(@(x)strcmp(char(string(x.groupid)),groupid),data);
    data=data(keep);
catch
end
data(end+1)=ds;
end

function filename=artifactPath(roiobj,param,ctx)
root='';
try
    if isfield(ctx,'store')&&isstruct(ctx.store)&&isfield(ctx.store,'workDir')
        root=char(string(ctx.store.workDir));
    end
catch
end
if isempty(root)
    modelFile=cellModel.pathForROI(roiobj);
    root=fullfile(fileparts(modelFile),'artifacts','selectCavityTrajectory');
end
if ~isfolder(root), mkdir(root); end
safeRoi=regexprep(safeRoiId(roiobj),'[^A-Za-z0-9_.-]+','_');
safeOutput=regexprep(param.outputName,'[^A-Za-z0-9_.-]+','_');
filename=fullfile(root,sprintf('%s_%s.json',safeOutput,safeRoi));
end

function writeResultJson(filename,result,param,loadReport)
payload=rmfield(result,{'assignments','events','lifespans'});
payload.assignments=table2struct(result.assignments);
payload.events=table2struct(result.events);
payload.lifespans=table2struct(result.lifespans);
payload.parameters=serializableParam(param);
payload.cell_model_source=struct('filename',char(string(loadReport.filename)), ...
    'source',char(string(loadReport.source)));
temporary=[filename '.tmp.' char(java.util.UUID.randomUUID)];
cleanup=onCleanup(@()deleteIfPresent(temporary));
fid=fopen(temporary,'w');
if fid<0, error('selectCavityTrajectory:ArtifactWrite','Cannot create %s.',temporary); end
closeFile=onCleanup(@()fclose(fid));
fwrite(fid,jsonencode(payload,'PrettyPrint',true),'char');
clear closeFile;
[ok,message]=movefile(temporary,filename,'f');
if ~ok, error('selectCavityTrajectory:ArtifactWrite','Cannot finalize %s: %s',filename,message); end
clear cleanup;
end

function out=serializableParam(param)
out=param;
for name={'tip','trajectory','artifacts'}
    if isfield(out,name{1}), out=rmfield(out,name{1}); end
end
end

function deleteIfPresent(filename)
try if isfile(filename), delete(filename); end, catch, end
end

function value=safeRoiId(roiobj)
value='<unknown>';
try value=char(string(roiobj.id)); catch, end
end
