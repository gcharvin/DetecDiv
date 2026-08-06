function model = readH5(filename, varargin)
%CELLMODEL.READH5 Read a DetecDiv cellular object model sidecar.

p=inputParser;
p.addParameter('AllowMissing',false,@(x)islogical(x)&&isscalar(x));
p.addParameter('ROIId','',@(x)ischar(x)||isstring(x));
p.parse(varargin{:});
filename=char(string(filename));
if ~isfile(filename)
    if p.Results.AllowMissing
        model=cellModel.create(p.Results.ROIId); return;
    end
    error('cellModel:FileNotFound','Cell model file not found: %s',filename);
end

metadata=cellModel.readMetadata(filename);

model=cellModel.create(metadata.roi_id);
model.format=char(string(metadata.format));
model.schema_version=uint16(metadata.schema_version);
model.index_base=uint8(metadata.index_base);
model.roi_id=char(string(metadata.roi_id));
model.families=readFamilies(metadata);
model.states=readStates(metadata);
if isfield(metadata,'relation_types') && ~isempty(metadata.relation_types)
    model.relation_types=metadata.relation_types;
end
if isfield(metadata,'provenance') && isstruct(metadata.provenance)
    model.provenance=metadata.provenance;
end

model.instances=readColumns(filename,'/instances',model.instances);
model.relations=readColumns(filename,'/relations',model.relations);
model=cellModel.normalize(model);
cellModel.validate(model,'Throw',true);
end

function families=readFamilies(metadata)
empty=cellModel.create(''); families=empty.families;
if ~isfield(metadata,'families') || isempty(metadata.families), return; end
rows=metadata.families; n=numel(rows);
families.family_id=zeros(n,1,'uint32'); families.name=cell(n,1);
families.mask_provider=cell(n,1); families.lineage_source=cell(n,1);
families.color_rgb=zeros(n,3,'uint8');
for i=1:n
    families.family_id(i)=uint32(rows(i).family_id);
    families.name{i}=char(string(rows(i).name));
    families.mask_provider{i}=char(string(rows(i).mask_provider));
    families.lineage_source{i}=char(string(rows(i).lineage_source));
    families.color_rgb(i,:)=uint8(rows(i).color_rgb(:).');
end
end

function states=readStates(metadata)
empty=cellModel.create(''); states=empty.states;
if ~isfield(metadata,'states') || isempty(metadata.states), return; end
rows=metadata.states; n=numel(rows);
states.state_id=zeros(n,1,'uint16'); states.name=cell(n,1);
states.color_rgb=zeros(n,3,'uint8');
for i=1:n
    states.state_id(i)=uint16(rows(i).state_id);
    states.name{i}=char(string(rows(i).name));
    states.color_rgb(i,:)=uint8(rows(i).color_rgb(:).');
end
end

function columns=readColumns(filename,group,columns)
names=fieldnames(columns);
for i=1:numel(names)
    path=[group '/' names{i}];
    try
        value=h5read(filename,path);
        columns.(names{i})=cast(value(:),class(columns.(names{i})));
    catch ME
        if ~contains(ME.identifier,'libraryError') && ~contains(ME.message,'does not exist')
            rethrow(ME);
        end
    end
end
end
