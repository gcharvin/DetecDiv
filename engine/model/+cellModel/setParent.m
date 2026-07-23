function [model, report] = setParent(model, family, frame, childLabel, parentLabel)
%CELLMODEL.SETPARENT Set or remove one parent relation using mask references.

model = cellModel.normalize(model);
[~, familyId] = cellModel.familyIndex(model, family);
if isempty(familyId), error('cellModel:UnknownFamily', 'Unknown family.'); end
child = cellModel.findInstance(model, familyId, frame, childLabel);
if isempty(child) || child.track_id == 0
    error('cellModel:UntrackedChild', 'The child mask has no assigned track.');
end
existing = find(model.relations.family_id == familyId & ...
    model.relations.child_track_id == child.track_id & ...
    model.relations.type_id == uint8(1), 1, 'first');

if isempty(parentLabel) || ~isfinite(parentLabel) || parentLabel <= 0
    if ~isempty(existing)
        model.relations = removeRow(model.relations, existing);
    end
    model = cellModel.normalize(model);
    report = struct('status','removed','child_track_id',child.track_id,'parent_track_id',uint64(0));
    return;
end

parent = cellModel.findInstance(model, familyId, frame, parentLabel);
if isempty(parent) || parent.track_id == 0
    error('cellModel:UntrackedParent', 'The parent mask has no assigned track.');
end
if parent.track_id == child.track_id
    error('cellModel:SelfParent', 'A track cannot be its own parent.');
end
if isempty(existing)
    row = numel(model.relations.relation_id) + 1;
    model.relations.relation_id(row,1) = ...
        max([model.relations.relation_id; uint64(0)]) + uint64(1);
    model.relations.family_id(row,1) = familyId;
    model.relations.child_track_id(row,1) = child.track_id;
    model.relations.type_id(row,1) = uint8(1);
    model.relations.confidence(row,1) = single(1);
else
    row = existing;
end
model.relations.parent_track_id(row,1) = parent.track_id;
model.relations.event_frame(row,1) = uint32(frame);
model = cellModel.normalize(model);
cellModel.validate(model, 'Throw', true);
report = struct('status','set','child_track_id',child.track_id, ...
    'parent_track_id',parent.track_id);
end

function columns = removeRow(columns, row)
keep = true(numel(columns.relation_id), 1);
keep(row) = false;
names = fieldnames(columns);
for i = 1:numel(names)
    columns.(names{i}) = columns.(names{i})(keep,:);
end
end
