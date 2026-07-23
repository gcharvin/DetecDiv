function [model, report] = relabelFrame(model, family, frame, oldLabel, newLabel, action)
%CELLMODEL.RELABELFRAME Keep object references aligned with a mask relabel.

if nargin < 6 || isempty(action), action = 'merge'; end
action = lower(char(string(action)));
if ~any(strcmp(action, {'merge','swap'}))
    error('cellModel:BadRelabelAction', 'Unknown relabel action: %s', action);
end
model = cellModel.normalize(model);
[~, familyId] = cellModel.familyIndex(model, family);
if isempty(familyId), error('cellModel:UnknownFamily', 'Unknown family.'); end
frame = uint32(frame);
oldLabel = uint32(oldLabel);
newLabel = uint32(newLabel);
if oldLabel == 0 || newLabel == 0
    error('cellModel:BadMaskLabel', 'Mask labels must be positive.');
end

oldRow = find(model.instances.family_id == familyId & ...
    model.instances.frame == frame & model.instances.mask_label == oldLabel, 1, 'first');
newRow = find(model.instances.family_id == familyId & ...
    model.instances.frame == frame & model.instances.mask_label == newLabel, 1, 'first');
if isempty(oldRow)
    report = struct('status','old_label_unmapped','old_label',oldLabel,'new_label',newLabel);
    return;
end

if strcmp(action, 'swap') && ~isempty(newRow)
    model.instances.mask_label([oldRow newRow]) = [newLabel; oldLabel];
elseif isempty(newRow)
    model.instances.mask_label(oldRow) = newLabel;
else
    keep = true(numel(model.instances.object_id), 1);
    keep(oldRow) = false;
    names = fieldnames(model.instances);
    for i = 1:numel(names)
        model.instances.(names{i}) = model.instances.(names{i})(keep,:);
    end
end
model = cellModel.normalize(model);
cellModel.validate(model, 'Throw', true);
report = struct('status','ok','old_label',oldLabel,'new_label',newLabel,'action',action);
end
