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
if oldTrackId > 0 && oldTrackId ~= newTrackId
    model = transferCensoring(model, familyId, oldTrackId, newTrackId, ...
        double(affectedFrames(:)).');
end
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

function model = transferCensoring(model, familyId, oldTrackId, newTrackId, affectedFrames)
% Censoring follows the biological identity segment that was reassigned.
recordRows = find(model.censoring.family_id == familyId & ...
    model.censoring.track_id == oldTrackId);
if isempty(recordRows), return; end
affectedFrames = unique(round(double(affectedFrames(:).')));
for row = flip(recordRows(:).')
    first = double(model.censoring.frame_start(row));
    last = double(model.censoring.frame_end(row));
    moved = affectedFrames(affectedFrames >= first & affectedFrames <= last);
    if isempty(moved), continue; end
    original = rowStruct(model.censoring, row);
    model.censoring = deleteRow(model.censoring, row);
    oldFrames = setdiff(first:last, moved, 'stable');
    oldRuns = contiguousRuns(oldFrames);
    newRuns = contiguousRuns(moved);
    blocks = [tagRuns(oldRuns, oldTrackId); tagRuns(newRuns, newTrackId)];
    nextId = max([model.censoring.censor_id; original.censor_id; uint64(0)]) + uint64(1);
    for i = 1:size(blocks,1)
        item = original;
        if i > 1, item.censor_id = nextId; nextId = nextId + uint64(1); end
        item.track_id = uint64(blocks(i,1));
        item.frame_start = uint32(blocks(i,2));
        item.frame_end = uint32(blocks(i,3));
        model.censoring = appendRow(model.censoring, item);
    end
end
end

function runs = contiguousRuns(frames)
runs = zeros(0,2);
if isempty(frames), return; end
frames = unique(sort(frames));
cuts = [1 find(diff(frames)>1)+1 numel(frames)+1];
for i = 1:numel(cuts)-1
    block = frames(cuts(i):cuts(i+1)-1);
    runs(end+1,:) = [block(1) block(end)]; %#ok<AGROW>
end
end

function tagged = tagRuns(runs, trackId)
if isempty(runs), tagged = zeros(0,3); return; end
tagged = [repmat(double(trackId),size(runs,1),1) runs];
end

function item = rowStruct(columns, row)
item = struct(); names = fieldnames(columns);
for i = 1:numel(names), item.(names{i}) = columns.(names{i})(row); end
end

function columns = deleteRow(columns, row)
names = fieldnames(columns);
for i = 1:numel(names), columns.(names{i})(row,:) = []; end
end

function columns = appendRow(columns, item)
names = fieldnames(columns);
for i = 1:numel(names), columns.(names{i})(end+1,1) = item.(names{i}); end
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
