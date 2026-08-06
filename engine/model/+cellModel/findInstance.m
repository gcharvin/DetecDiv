function instance = findInstance(model, family, frame, maskLabel)
%CELLMODEL.FINDINSTANCE Find one object reference by provider label.

% Models are normalized when loaded or mutated. This lookup is part of the
% display hot path, so normalizing/sorting the complete instance table here
% would make every frame navigation unnecessarily expensive.
[~,familyId]=cellModel.familyIndex(model,family);
instance=[];
if isempty(familyId) || ~isfield(model,'instances') || ...
        ~isstruct(model.instances) || ~isfield(model.instances,'family_id') || ...
        ~isfield(model.instances,'frame') || ~isfield(model.instances,'mask_label')
    return;
end
hit=find(model.instances.family_id==familyId & ...
    model.instances.frame==uint32(frame) & ...
    model.instances.mask_label==uint32(maskLabel),1,'first');
if isempty(hit), return; end
names=fieldnames(model.instances); instance=struct();
for i=1:numel(names), instance.(names{i})=model.instances.(names{i})(hit); end
end
