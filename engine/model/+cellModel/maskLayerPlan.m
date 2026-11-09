function plan=maskLayerPlan(model,provider,layerNames,varargin)
%MASKLAYERPLAN Give each editable tracking result its own mask provider.
% Pure metadata plan: callers copy the referenced masks and own persistence.
p=inputParser;
p.addParameter('KeepFamily',uint32(0),@(x)isnumeric(x)&&isscalar(x));
p.addParameter('NewResult','',@(x)ischar(x)||isstring(x));
p.parse(varargin{:});
model=cellModel.normalize(model); provider=char(string(provider));
names=reshape(cellstr(string(layerNames)),1,[]);
rows=find(strcmp(model.families.mask_provider,provider));
changes=struct('familyId',{},'result',{},'source',{},'layer',{},'initialize',{});
newResult=strtrim(char(string(p.Results.NewResult)));
if ~isempty(newResult)
    assert(~any(strcmpi(model.families.name,newResult)),'cellModel:ResultExists','A tracking result with this name already exists.');
    family=max([model.families.family_id;uint32(0)])+uint32(1);
    row=numel(model.families.family_id)+1;
    model.families.family_id(row,1)=family; model.families.name{row,1}=newResult;
    model.families.lineage_source{row,1}='manual'; model.families.color_rgb(row,:)=uint8([99 214 255]);
    layer=uniqueName(provider,newResult,family,names);
    model.families.mask_provider{row,1}=layer;
    changes(1)=struct('familyId',family,'result',newResult,'source',provider,'layer',layer,'initialize',true);
else
    assert(numel(rows)>1,'cellModel:DedicatedMasks','This mask layer already has at most one tracking result.');
    keep=p.Results.KeepFamily;
    if keep==0, keep=model.families.family_id(rows(1)); end
    assert(any(model.families.family_id(rows)==keep),'cellModel:MaskFamily','The retained result uses another mask layer.');
    for row=reshape(rows,1,[])
        family=model.families.family_id(row); if family==keep, continue; end
        result=model.families.name{row}; layer=uniqueName(provider,result,family,names); names{end+1}=layer; %#ok<AGROW>
        model.families.mask_provider{row}=layer;
        changes(end+1)=struct('familyId',family,'result',result,'source',provider,'layer',layer,'initialize',false); %#ok<AGROW>
    end
end
cellModel.validate(model,'Throw',true);
plan=struct('model',model,'changes',changes,'source',provider);
end
function name=uniqueName(provider,result,family,names)
stem=matlab.lang.makeValidName([provider '__' result]);
stem=stem(1:min(numel(stem),55)); name=stem; count=0;
while any(strcmpi(names,name))
    count=count+1; name=sprintf('%s_f%u_%d',stem,family,count);
end
end
