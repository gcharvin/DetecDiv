function [model, report] = removeTrack(model, family, trackId, varargin)
%CELLMODEL.REMOVETRACK Remove every instance and relation of one track.
% 'Fast', true accepts an already-normalized live model and defers the
% final normalization/validation to the caller's persistence boundary.

p = inputParser;
p.addParameter('Fast', false, @(x) islogical(x) && isscalar(x));
p.parse(varargin{:});
fast = p.Results.Fast;

if ~isscalar(trackId) || ~isfinite(trackId) || ...
        trackId < 1 || trackId ~= round(trackId)
    error('cellModel:BadTrackId', 'Track ID must be a positive integer.');
end
if ~fast
    model = cellModel.normalize(model);
end
[~, familyId] = cellModel.familyIndex(model, family);
if isempty(familyId)
    error('cellModel:UnknownFamily', 'Unknown family.');
end
trackId = uint64(trackId);

instanceRows = model.instances.family_id == familyId & ...
    model.instances.track_id == trackId;
frames = double(unique(model.instances.frame(instanceRows))).';
instanceFrames = double(model.instances.frame(instanceRows)).';
maskLabels = double(model.instances.mask_label(instanceRows)).';
objectIds = model.instances.object_id(instanceRows).';

relationRows = model.relations.family_id == familyId & ...
    (model.relations.parent_track_id == trackId | ...
     model.relations.child_track_id == trackId);
censorRows = model.censoring.family_id == familyId & ...
    model.censoring.track_id == trackId;

model.instances = keepRows(model.instances, ~instanceRows);
model.relations = keepRows(model.relations, ~relationRows);
model.censoring = keepRows(model.censoring, ~censorRows);

if ~fast
    model = cellModel.normalize(model);
    cellModel.validate(model, 'Throw', true);
end
if any(instanceRows)
    status = 'removed';
else
    status = 'missing';
end
report = struct('status', status, 'family_id', familyId, ...
    'track_id', trackId, 'frames', frames, ...
    'instance_frames', instanceFrames, 'mask_labels', maskLabels, ...
    'object_ids', objectIds, 'instances_removed', nnz(instanceRows), ...
    'relations_removed', nnz(relationRows), ...
    'censoring_removed', nnz(censorRows));
end

function out = keepRows(in, keep)
out = in;
names = fieldnames(in);
for i = 1:numel(names)
    out.(names{i}) = in.(names{i})(keep,:);
end
end
