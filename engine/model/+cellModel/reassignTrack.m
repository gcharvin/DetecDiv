function [model, report] = reassignTrack(model, family, frame, maskLabel, newTrackId, scope, varargin)
%CELLMODEL.REASSIGNTRACK Move selected instances to another track.
% 'Fast', true is for an already-normalized live model. Persistence will
% normalize and validate the complete model when it is flushed.

p = inputParser;
p.addParameter('Fast', false, @(x) islogical(x) && isscalar(x));
p.parse(varargin{:});
fast = p.Results.Fast;

if nargin < 6 || isempty(scope), scope = 'frame'; end
scope = lower(char(string(scope)));
if ~any(strcmp(scope, {'frame','to-last','all'}))
    error('cellModel:BadTrackScope', 'Unknown track reassignment scope: %s', scope);
end
if ~isscalar(newTrackId) || ~isfinite(newTrackId) || ...
        newTrackId < 1 || newTrackId ~= round(newTrackId)
    error('cellModel:BadTrackId', 'Track ID must be a positive integer.');
end

if ~fast
    model = cellModel.normalize(model);
end
[~, familyId] = cellModel.familyIndex(model, family);
if isempty(familyId), error('cellModel:UnknownFamily', 'Unknown family.'); end
frame = uint32(frame);
maskLabel = uint32(maskLabel);
newTrackId = uint64(newTrackId);

selected = find(model.instances.family_id == familyId & ...
    model.instances.frame == frame & ...
    model.instances.mask_label == maskLabel, 1, 'first');
if isempty(selected)
    error('cellModel:UnknownInstance', ...
        'No object with mask label %u exists at frame %u.', maskLabel, frame);
end
oldTrackId = model.instances.track_id(selected);

switch scope
    case 'frame'
        rows = selected;
    case 'to-last'
        rows = scopedRows(model, familyId, frame, maskLabel, oldTrackId, true);
    otherwise
        rows = scopedRows(model, familyId, frame, maskLabel, oldTrackId, false);
end

affectedFrames = model.instances.frame(rows);
destinationRows = find(model.instances.family_id == familyId & ...
    model.instances.track_id == newTrackId);
conflictRows = destinationRows(ismember( ...
    model.instances.frame(destinationRows), affectedFrames));
conflictRows = setdiff(conflictRows, rows, 'stable');
if ~isempty(conflictRows)
    frames = unique(model.instances.frame(conflictRows));
    error('cellModel:TrackFrameConflict', ...
        'Track %u already contains another object at frame(s): %s.', ...
        newTrackId, strjoin(cellstr(string(frames(:).')), ', '));
end

model.instances.track_id(rows) = newTrackId;
relationsUpdated = false;
if strcmp(scope, 'all') && oldTrackId > 0 && oldTrackId ~= newTrackId && ...
        ~any(model.instances.family_id == familyId & ...
            model.instances.track_id == oldTrackId)
    model = replaceRelationTrack(model, familyId, oldTrackId, newTrackId);
    relationsUpdated = true;
end

if ~fast
    model = cellModel.normalize(model);
    cellModel.validate(model, 'Throw', true);
end
report = struct('status', 'ok', 'scope', scope, ...
    'family_id', familyId, 'old_track_id', oldTrackId, ...
    'new_track_id', newTrackId, 'rows_changed', numel(rows), ...
    'frames', double(unique(affectedFrames(:)).'), ...
    'relations_updated', relationsUpdated);
end

function rows = scopedRows(model, familyId, frame, maskLabel, oldTrackId, fromFrame)
familyRows = model.instances.family_id == familyId;
if oldTrackId > 0
    identityRows = model.instances.track_id == oldTrackId;
else
    % Track zero is shared by every unassigned object and cannot identify a
    % trajectory. Fall back to the selected mask label in that case.
    identityRows = model.instances.mask_label == maskLabel & ...
        model.instances.track_id == 0;
end
rows = find(familyRows & identityRows);
if fromFrame
    rows = rows(model.instances.frame(rows) >= frame);
end
end

function model = replaceRelationTrack(model, familyId, oldTrackId, newTrackId)
rel = model.relations;
oldChild = any(rel.family_id == familyId & ...
    rel.child_track_id == oldTrackId & rel.type_id == uint8(1));
newChild = any(rel.family_id == familyId & ...
    rel.child_track_id == newTrackId & rel.type_id == uint8(1));
if oldChild && newChild
    error('cellModel:TrackRelationConflict', ...
        ['Both source and destination tracks already have a parent. ' ...
         'Correct parentage before merging the complete tracks.']);
end
rel.parent_track_id(rel.family_id == familyId & ...
    rel.parent_track_id == oldTrackId) = newTrackId;
rel.child_track_id(rel.family_id == familyId & ...
    rel.child_track_id == oldTrackId) = newTrackId;
self = rel.family_id == familyId & ...
    rel.parent_track_id == rel.child_track_id;
if any(self)
    names = fieldnames(rel);
    for i = 1:numel(names), rel.(names{i})(self,:) = []; end
end
model.relations = rel;
end
