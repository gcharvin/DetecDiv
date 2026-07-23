function report = writeH5(filename, model, varargin)
%CELLMODEL.WRITEH5 Atomically write a compact, Python-readable schema-v1 file.

p=inputParser;
p.addParameter('KeepBackup',true,@(x)islogical(x)&&isscalar(x));
p.parse(varargin{:});
filename=char(string(filename));
if isempty(filename), error('cellModel:MissingFilename','A target filename is required.'); end
targetDir=fileparts(filename);
if isempty(targetDir), targetDir=pwd; filename=fullfile(targetDir,filename); end
if ~isfolder(targetDir), mkdir(targetDir); end

model=cellModel.normalize(model);
cellModel.validate(model,'Throw',true);
model.provenance.updated_at=char(datetime('now','Format','yyyy-MM-dd''T''HH:mm:ssXXX'));

localFile=[tempname '.h5'];
cleanupLocal=onCleanup(@()deleteIfPresent(localFile));
metadata=buildMetadata(model);
bytes=unicode2native(jsonencode(metadata),'UTF-8');
writeVector(localFile,'/metadata_json',uint8(bytes(:)),'uint8');
h5writeatt(localFile,'/','format',model.format);
h5writeatt(localFile,'/','schema_version',model.schema_version);
h5writeatt(localFile,'/','index_base',model.index_base);
h5writeatt(localFile,'/','roi_id',model.roi_id);
h5writeatt(localFile,'/','storage_layout','columnar_1d');

writeColumns(localFile,'/instances',model.instances);
writeColumns(localFile,'/relations',model.relations);

roundTrip=cellModel.readH5(localFile);
cellModel.validate(roundTrip,'Throw',true);
if ~isequal(model.instances.object_id,roundTrip.instances.object_id) || ...
        ~isequal(model.relations.relation_id,roundTrip.relations.relation_id)
    error('cellModel:RoundTripMismatch','Temporary HDF5 verification failed.');
end

uuid=char(java.util.UUID.randomUUID);
stage=[filename '.tmp.' uuid];
cleanupStage=onCleanup(@()deleteIfPresent(stage));
copyfile(localFile,stage,'f');
assertSameSize(localFile,stage);

backup='';
if isfile(filename) && p.Results.KeepBackup
    backup=[filename '.bak'];
    copyfile(filename,backup,'f');
end

[ok,msg]=movefile(stage,filename,'f');
if ~ok
    copyfile(stage,filename,'f');
    deleteIfPresent(stage);
    if ~isfile(filename), error('cellModel:InstallFailed','%s',msg); end
end
assertSameSize(localFile,filename);
clear cleanupStage cleanupLocal;
deleteIfPresent(localFile);

info=dir(filename);
report=struct('filename',string(filename),'backup',string(backup), ...
    'bytes',info.bytes,'counts',cellModel.validate(model).counts,'status','ok');
end

function metadata=buildMetadata(model)
metadata=struct('format',model.format,'schema_version',double(model.schema_version), ...
    'index_base',double(model.index_base),'roi_id',model.roi_id, ...
    'families',[],'states',[],'relation_types',model.relation_types, ...
    'provenance',model.provenance);

n=numel(model.families.family_id);
families=repmat(struct('family_id',0,'name','','mask_provider','', ...
    'lineage_source','','color_rgb',[255 255 255]),n,1);
for i=1:n
    families(i).family_id=double(model.families.family_id(i));
    families(i).name=model.families.name{i};
    families(i).mask_provider=model.families.mask_provider{i};
    families(i).lineage_source=model.families.lineage_source{i};
    families(i).color_rgb=double(model.families.color_rgb(i,:));
end
metadata.families=families;

n=numel(model.states.state_id);
states=repmat(struct('state_id',0,'name','','color_rgb',[255 255 255]),n,1);
for i=1:n
    states(i).state_id=double(model.states.state_id(i));
    states(i).name=model.states.name{i};
    states(i).color_rgb=double(model.states.color_rgb(i,:));
end
metadata.states=states;
end

function writeColumns(filename,group,columns)
names=fieldnames(columns);
for i=1:numel(names)
    values=columns.(names{i});
    if isempty(values), continue; end
    writeVector(filename,[group '/' names{i}],values,class(values));
end
end

function writeVector(filename,path,values,datatype)
values=values(:);
n=numel(values);
args={'Datatype',datatype};
if n>=128
    args=[args,{'ChunkSize',min(n,4096),'Deflate',4}]; %#ok<AGROW>
end
h5create(filename,path,n,args{:});
h5write(filename,path,values);
end

function assertSameSize(source,target)
a=dir(source); b=dir(target);
if isempty(a)||isempty(b)||a.bytes~=b.bytes||b.bytes<=0
    error('cellModel:FileVerification','File copy verification failed for %s.',target);
end
end

function deleteIfPresent(filename)
try
    if isfile(filename), delete(filename); end
catch
end
end
