function [model, report] = setParentTrack(model, family, frame, childTrackId, parentTrackId, varargin)
%CELLMODEL.SETPARENTTRACK Set or remove a parent relation using track IDs.
% 'Fast', true is for an already-normalized live model; persistence will
% normalize and validate the complete model when it is flushed.

p = inputParser;
p.addParameter('Fast', false, @(x) islogical(x) && isscalar(x));
p.parse(varargin{:});
fast = p.Results.Fast;
if ~fast
    model = cellModel.normalize(model);
end
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
    if ~fast
        model = cellModel.normalize(model);
    end
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
[eventFrame, childBirthFrame] = canonicalEventFrame( ...
    model, familyId, childTrackId, parentTrackId);
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
% The UI action may occur long after appearance, but the stored biological
% event is always canonicalized to the child's first visible frame. This
% applies only to newly set/replaced links; existing GT is never migrated.
model.relations.event_frame(row,1) = eventFrame;
if ~fast
    model = cellModel.normalize(model);
    cellModel.validate(model, 'Throw', true);
end
report = struct('status', 'set', 'child_track_id', childTrackId, ...
    'parent_track_id', parentTrackId, 'event_frame', eventFrame, ...
    'requested_frame', uint32(frame), ...
    'child_birth_frame', childBirthFrame);
end

function [eventFrame, childBirthFrame] = canonicalEventFrame( ...
        model, familyId, childTrackId, parentTrackId)
childRows = model.instances.family_id == familyId & ...
    model.instances.track_id == childTrackId;
childFrames = unique(double(model.instances.frame(childRows)));
childBirth = min(childFrames);
childBirthFrame = uint32(childBirth);
eventFrame = childBirthFrame;

convention = cellModel.relationTemporalConvention();
acceptedParentFrames = childBirth + double( ...
    convention.accepted_presence_frames_relative_to_event);
acceptedParentFrames = acceptedParentFrames(acceptedParentFrames >= 1);
parentRows = model.instances.family_id == familyId & ...
    model.instances.track_id == parentTrackId;
parentFrames = unique(double(model.instances.frame(parentRows)));
if any(ismember(parentFrames, acceptedParentFrames)), return; end

if childBirth > 1
    expected = sprintf('frame %u or the preceding frame %u', ...
        uint32(childBirth), uint32(childBirth-1));
else
    expected = 'frame 1';
end
error('cellModel:ParentAbsentAtChildBirth', ...
    ['Cannot link Parent Track %u to Child Track %u: the child is born ' ...
     'at frame %u, but the parent is absent at %s under convention %s. ' ...
     'Open frame %u and inspect both tracks; correct their identities or ' ...
     'choose a parent present at the child birth.'], ...
    parentTrackId, childTrackId, childBirthFrame, expected, ...
    convention.name, childBirthFrame);
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
