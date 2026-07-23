function [index, familyId] = familyIndex(model, identifier)
%CELLMODEL.FAMILYINDEX Resolve a family by numeric ID, name, or provider.

model=cellModel.normalize(model);
index=[]; familyId=[];
if isempty(identifier), return; end
if isnumeric(identifier)
    index=find(model.families.family_id==uint32(identifier),1,'first');
else
    value=string(identifier);
    index=find(strcmp(string(model.families.name),value),1,'first');
    if isempty(index)
        index=find(strcmp(string(model.families.mask_provider),value),1,'first');
    end
end
if ~isempty(index), familyId=model.families.family_id(index); end
end
