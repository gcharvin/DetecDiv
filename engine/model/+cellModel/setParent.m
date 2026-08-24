function [model, report] = setParent(model, family, frame, childLabel, parentLabel, varargin)
%CELLMODEL.SETPARENT Set or remove one parent relation using mask references.
% 'Fast', true is for an already-normalized live model; persistence will
% normalize and validate the complete model when it is flushed.
% 'Toggle', true removes the relation when the clicked parent is already
% assigned to the child; a different parent still replaces the relation.

p = inputParser;
p.addParameter('Fast', false, @(x) islogical(x) && isscalar(x));
p.addParameter('Toggle', false, @(x) islogical(x) && isscalar(x));
p.parse(varargin{:});
fast = p.Results.Fast;
toggle = p.Results.Toggle;
if ~fast
    model = cellModel.normalize(model);
end
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
    [model, report] = cellModel.setParentTrack(model, familyId, frame, ...
        child.track_id, [], 'Fast', fast);
    return;
end

parent = cellModel.findInstance(model, familyId, frame, parentLabel);
if isempty(parent) || parent.track_id == 0
    error('cellModel:UntrackedParent', 'The parent mask has no assigned track.');
end
if parent.track_id == child.track_id
    error('cellModel:SelfParent', 'A track cannot be its own parent.');
end
if toggle && ~isempty(existing) && ...
        model.relations.parent_track_id(existing) == parent.track_id
    [model, report] = cellModel.setParentTrack(model, familyId, frame, ...
        child.track_id, [], 'Fast', fast);
    return;
end
[model, report] = cellModel.setParentTrack(model, familyId, frame, ...
    child.track_id, parent.track_id, 'Fast', fast);
end
