function instance = findTrackInstance(model, family, frame, trackId)
%CELLMODEL.FINDTRACKINSTANCE Find one frame-local object by track identity.

[~, familyId] = cellModel.familyIndex(model, family);
instance = [];
if isempty(familyId) || ~isfield(model, 'instances') || ...
        ~isstruct(model.instances) || ~isfield(model.instances, 'family_id') || ...
        ~isfield(model.instances, 'frame') || ~isfield(model.instances, 'track_id')
    return;
end
hit = find(model.instances.family_id == familyId & ...
    model.instances.frame == uint32(frame) & ...
    model.instances.track_id == uint64(trackId), 1, 'first');
if isempty(hit), return; end
names = fieldnames(model.instances);
instance = struct();
for i = 1:numel(names)
    instance.(names{i}) = model.instances.(names{i})(hit);
end
end
