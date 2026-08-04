function [index, familyId] = familyIndex(model, identifier)
%CELLMODEL.FAMILYINDEX Resolve a family by numeric ID, name, or provider.

index=[]; familyId=[];
if isempty(identifier) || ~isstruct(model) || ~isfield(model,'families') || ...
        ~isstruct(model.families) || ~isfield(model.families,'family_id')
    return;
end

% Models are normalized when they are loaded or mutated. Do not call
% cellModel.normalize here: resolving one family is a display hot path, and
% normalize sorts every instance and relation in the complete model.
families = model.families;
ids = uint32(families.family_id(:));
if isempty(ids), return; end

if isnumeric(identifier)
    index=find(ids==uint32(identifier(1)),1,'first');
else
    value=string(identifier);
    if isempty(value), return; end
    value=value(1);
    if isfield(families,'name')
        index=find(strcmp(string(families.name(:)),value),1,'first');
    end
    if isempty(index) && isfield(families,'mask_provider')
        index=find(strcmp(string(families.mask_provider(:)),value),1,'first');
    end
end
if ~isempty(index) && index<=numel(ids), familyId=ids(index); else, index=[]; end
end
