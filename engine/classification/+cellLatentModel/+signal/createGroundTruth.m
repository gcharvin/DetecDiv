function report = createGroundTruth(roiObj, definition, varargin)
%CELLLATENTMODEL.SIGNAL.CREATEGROUNDTRUTH Materialize editable signal GT.

p=inputParser;
p.addParameter('Model',struct(),@isstruct);
p.addParameter('Overwrite',false,@(x)islogical(x)&&isscalar(x));
p.addParameter('Save',true,@(x)islogical(x)&&isscalar(x));
p.parse(varargin{:});
def=definitionCheck(definition);
[model,familyId]=resolveModel(roiObj,def.family,p.Results.Model);
if strcmp(def.task,'segmentation')
    target=createMaskTarget(roiObj,def,p.Results.Overwrite);
    createSegmentationCoverage(roiObj,def,p.Results.Overwrite);
    if p.Results.Save
        roiObj.save(target,false);
        roiObj.save('data',false);
    end
    count=size(roiObj.image,4);
else
    [target,count]=createObjectTarget(roiObj,model,familyId,def,p.Results.Overwrite);
    if p.Results.Save, roiObj.save('data',false); end
end
report=struct('signal_name',def.name,'task',def.task,'target',target, ...
    'target_count',count,'family_id',familyId,'saved',logical(p.Results.Save));
end

function [target,count]=createObjectTarget(roiObj,model,familyId,def,overwrite)
rows=find(model.instances.family_id==familyId);
[~,order]=sortrows([double(model.instances.frame(rows)),double(model.instances.track_id(rows))]);
rows=rows(order); count=numel(rows);
tbl=table(model.instances.object_id(rows),model.instances.family_id(rows), ...
    model.instances.track_id(rows),model.instances.frame(rows), ...
    model.instances.mask_label(rows), ...
    'VariableNames',{'ObjectId','FamilyId','TrackId','Frame','MaskLabel'});
if strcmp(def.task,'classification')
    tbl.(def.value_field)=categorical(repmat({'undefined'},count,1), ...
        unique([{'undefined'} def.classes],'stable'));
else
    tbl.(def.value_field)=nan(count,1);
end
idx=seriesIndex(roiObj,def.ground_truth_group);
if ~isempty(idx)&&hasDefined(roiObj.data(idx).data,def.value_field)&&~overwrite
    error('cellLatentModel:SignalGroundTruthExists', ...
        'Signal GT dataseries "%s" already contains annotations.',def.ground_truth_group);
end
ds=dataseries(tbl,tbl.Properties.VariableNames, ...
    'groupid',def.ground_truth_group,'parentid',roiObj.id, ...
    'groups',repmat({'latent_signal_gt'},1,width(tbl)), ...
    'plot',repmat({false},1,width(tbl)));
ds.class=string(def.task);
ds.type="temporal";
ds.userData=struct('schema_version',uint16(1),'signal_definition',def, ...
    'join_key','ObjectId','semantic','latent_custom_signal_ground_truth');
if isempty(idx)
    if isempty(roiObj.data)||(numel(roiObj.data)==1&&isempty(roiObj.data(1).data))
        roiObj.data=ds;
    else
        roiObj.data(end+1)=ds;
    end
else
    roiObj.data(idx)=ds;
end
target=def.ground_truth_group;
end

function target=createMaskTarget(roiObj,def,overwrite)
if isempty(roiObj.image), roiObj.load('Silent'); end
target=def.ground_truth_channel;
idx=roiObj.findChannelID(target,'exact');
if ~isempty(idx)
    current=roiObj.image(:,:,idx(1),:);
    if any(current(:))&&~overwrite
        error('cellLatentModel:SignalGroundTruthExists','Signal GT channel "%s" is not empty.',target);
    end
    roiObj.image(:,:,idx(1),:)=zeros(size(current),'like',current);
else
    blank=zeros(size(roiObj.image,1),size(roiObj.image,2),1,size(roiObj.image,4),'uint16');
    roiObj.addChannel(blank,target,[1 1 1],[0 0 0]);
end
end

function createSegmentationCoverage(roiObj,def,overwrite)
n=size(roiObj.image,4);
tbl=table(uint32((1:n).'),false(n,1),'VariableNames',{'Frame','Reviewed'});
idx=seriesIndex(roiObj,def.ground_truth_group);
if ~isempty(idx)&&ismember('Reviewed',roiObj.data(idx).data.Properties.VariableNames) && ...
        any(roiObj.data(idx).data.Reviewed)&&~overwrite
    error('cellLatentModel:SignalGroundTruthExists', ...
        'Signal GT review coverage "%s" is not empty.',def.ground_truth_group);
end
ds=dataseries(tbl,tbl.Properties.VariableNames, ...
    'groupid',def.ground_truth_group,'parentid',roiObj.id, ...
    'groups',{'frame','review'},'plot',{false,false});
ds.class="classification"; ds.type="temporal";
ds.userData=struct('schema_version',uint16(1),'signal_definition',def, ...
    'semantic','latent_custom_signal_segmentation_review');
if isempty(idx)
    if isempty(roiObj.data)||(numel(roiObj.data)==1&&isempty(roiObj.data(1).data))
        roiObj.data=ds;
    else
        roiObj.data(end+1)=ds;
    end
else
    roiObj.data(idx)=ds;
end
end

function [model,familyId]=resolveModel(roiObj,family,provided)
if isempty(fieldnames(provided)), [model,~]=roiObj.loadCellModel('MigrateLegacy',true);
else, model=cellModel.normalize(provided,roiObj.id); end
[idx,familyId]=cellModel.familyIndex(model,family);
if isempty(idx), error('cellLatentModel:UnknownSignalFamily','Signal target family was not found.'); end
end

function idx=seriesIndex(roiObj,group)
idx=[];
try, idx=find(arrayfun(@(x)strcmp(char(string(x.groupid)),group),roiObj.data),1); catch, end
end
function tf=hasDefined(tbl,field)
tf=false;
if ~istable(tbl)||~ismember(field,tbl.Properties.VariableNames), return; end
v=tbl.(field);
if iscategorical(v), tf=any(~isundefined(v)&string(v)~="undefined");
elseif isnumeric(v), tf=any(isfinite(double(v))); end
end
function def=definitionCheck(def)
cellLatentModel.signal.annotationSpec(def); % validates and keeps one contract authority
end
