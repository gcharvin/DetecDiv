function [model, report] = setParentTrack(model, family, frame, childTrackId, parentTrackId)
%CELLMODEL.SETPARENTTRACK Set or remove a parent relation using track IDs.

model = cellModel.normalize(model);
[~, familyId] = cellModel.familyIndex(model, family);
if isempty(familyId), error('cellModel:UnknownFamily', 'Unknown family.'); end
childTrackId = validTrackId(childTrackId, 'child');
known = model.instances.family_id == familyId;
if ~any(model.instances.track_id(known) == childTrackId)
    error('cellModel:UnknownChildTrack', ...
        'Child track %u does not exist in this family.', childTrackId);
end

existing = find(model.relations.family_id == familyId & ...
    model.relations.child_track_id == childTrackId & ...
    model.relations.type_id == uint8(1), 1, 'first');
if nargin < 5 || isempty(parentTrackId) || ...
        (isnumeric(parentTrackId) && isscalar(parentTrackId) && parentTrackId == 0)
    if ~isempty(existing), model.relations = removeRow(model.relations, existing); end
    model = cellModel.normalize(model);
    report = struct('status', 'removed', 'child_track_id', childTrackId, ...
        'parent_track_id', uint64(0), 'event_frame', uint32(frame));
    return;
end

parentTrackId = validTrackId(parentTrackId, 'parent');
if parentTrackId == childTrackId
    error('cellModel:SelfParent', 'A track cannot be its own parent.');
end
if ~any(model.instances.track_id(known) == parentTrackId)
    error('cellModel:UnknownParentTrack', ...
        'Parent track %u does not exist in this family.', parentTrackId);
end
if isempty(existing)
    row = numel(model.relations.relation_id) + 1;
    model.relations.relation_id(row,1) = ...
        max([model.relations.relation_id; uint64(0)]) + uint64(1);
    model.relations.family_id(row,1) = familyId;
    model.relations.child_track_id(row,1) = childTrackId;
    model.relations.type_id(row,1) = uint8(1);
    model.relations.confidence(row,1) = single(1);
else
    row = existing;
end
model.relations.parent_track_id(row,1) = parentTrackId;
model.relations.event_frame(row,1) = uint32(frame);
model = cellModel.normalize(model);
cellModel.validate(model, 'Throw', true);
report = struct('status', 'set', 'child_track_id', childTrackId, ...
    'parent_track_id', parentTrackId, 'event_frame', uint32(frame));
end

function value = validTrackId(value, role)
if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || ...
        value < 1 || value ~= round(value)
    roleLabel = [upper(role(1)) role(2:end)];
    error('cellModel:BadTrackId', '%s track ID must be a positive integer.', ...
        roleLabel);
end
value = uint64(value);
end

function columns = removeRow(columns, row)
keep = true(numel(columns.relation_id), 1);
keep(row) = false;
names = fieldnames(columns);
for i = 1:numel(names), columns.(names{i}) = columns.(names{i})(keep,:); end
end
