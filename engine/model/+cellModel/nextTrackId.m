function nextId = nextTrackId(model, family)
%CELLMODEL.NEXTTRACKID Return the first positive unused track ID in a family.

model = cellModel.normalize(model);
[~, familyId] = cellModel.familyIndex(model, family);
if isempty(familyId)
    error('cellModel:UnknownFamily', 'Unknown family.');
end

used = unique(model.instances.track_id( ...
    model.instances.family_id == familyId & model.instances.track_id > 0));
nextId = uint64(1);
while any(used == nextId)
    nextId = nextId + 1;
end
end
