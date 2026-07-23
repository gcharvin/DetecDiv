function instance = findInstance(model, family, frame, maskLabel)
%CELLMODEL.FINDINSTANCE Find one object reference by provider label.

model=cellModel.normalize(model);
[~,familyId]=cellModel.familyIndex(model,family);
instance=[];
if isempty(familyId), return; end
hit=find(model.instances.family_id==familyId & ...
    model.instances.frame==uint32(frame) & ...
    model.instances.mask_label==uint32(maskLabel),1,'first');
if isempty(hit), return; end
names=fieldnames(model.instances); instance=struct();
for i=1:numel(names), instance.(names{i})=model.instances.(names{i})(hit); end
end
