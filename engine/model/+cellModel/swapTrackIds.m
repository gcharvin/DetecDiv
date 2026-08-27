function [model, report] = swapTrackIds(model, family, trackA, trackB)
%CELLMODEL.SWAPTRACKIDS Atomically exchange two complete track identities.

model = cellModel.normalize(model);
[~, familyId] = cellModel.familyIndex(model, family);
if isempty(familyId)
    error('cellModel:UnknownFamily', 'Unknown family.');
end
trackA = localTrackId(trackA);
trackB = localTrackId(trackB);
if trackA == trackB
    report = struct('status', 'unchanged', 'family_id', familyId, ...
        'track_a', trackA, 'track_b', trackB, 'frames', []);
    return;
end

familyRows = model.instances.family_id == familyId;
rowsA = familyRows & model.instances.track_id == trackA;
rowsB = familyRows & model.instances.track_id == trackB;
if ~any(rowsA)
    error('cellModel:UnknownTrack', 'Track %u does not exist in this family.', trackA);
end
if ~any(rowsB)
    error('cellModel:UnknownTrack', 'Track %u does not exist in this family.', trackB);
end

frames = double(unique(model.instances.frame(rowsA | rowsB))).';
model.instances.track_id(rowsA) = trackB;
model.instances.track_id(rowsB) = trackA;

relationRows = model.relations.family_id == familyId;
parentA = relationRows & model.relations.parent_track_id == trackA;
parentB = relationRows & model.relations.parent_track_id == trackB;
childA = relationRows & model.relations.child_track_id == trackA;
childB = relationRows & model.relations.child_track_id == trackB;
model.relations.parent_track_id(parentA) = trackB;
model.relations.parent_track_id(parentB) = trackA;
model.relations.child_track_id(childA) = trackB;
model.relations.child_track_id(childB) = trackA;

censorRows = model.censoring.family_id == familyId;
censorA = censorRows & model.censoring.track_id == trackA;
censorB = censorRows & model.censoring.track_id == trackB;
model.censoring.track_id(censorA) = trackB;
model.censoring.track_id(censorB) = trackA;

model = cellModel.normalize(model);
cellModel.validate(model, 'Throw', true);
report = struct('status', 'swapped', 'family_id', familyId, ...
    'track_a', trackA, 'track_b', trackB, 'frames', frames);
end

function id = localTrackId(value)
if ~isscalar(value) || ~isfinite(value) || value < 1 || value ~= round(value)
    error('cellModel:BadTrackId', 'Track ID must be a positive integer.');
end
id = uint64(value);
end
