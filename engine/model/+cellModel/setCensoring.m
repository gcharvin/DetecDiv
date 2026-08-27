function [model, report] = setCensoring(model, family, trackId, frameStart, frameEnd, varargin)
%CELLMODEL.SETCENSORING Add an explicit, task-scoped censor interval.

p = inputParser;
p.addParameter('Scope', 'all');
p.addParameter('Reason', 'other', @(x) ischar(x) || isstring(x) || isnumeric(x));
p.addParameter('Source', 'human_review', @(x) ischar(x) || isstring(x) || isnumeric(x));
p.addParameter('Fast', false, @(x) islogical(x) && isscalar(x));
p.parse(varargin{:});

if ~p.Results.Fast, model = cellModel.normalize(model); end
[~, familyId] = cellModel.familyIndex(model, family);
if isempty(familyId), error('cellModel:UnknownFamily', 'Unknown family.'); end
trackId = positiveInteger(trackId, 'Track ID', 'uint64');
frameStart = positiveInteger(frameStart, 'Censor start frame', 'uint32');
frameEnd = positiveInteger(frameEnd, 'Censor end frame', 'uint32');
if frameEnd < frameStart
    error('cellModel:BadCensorInterval', ...
        'Censor end frame must be greater than or equal to its start.');
end
trackRows = model.instances.family_id == familyId & ...
    model.instances.track_id == trackId;
if ~any(trackRows)
    error('cellModel:UnknownTrack', ...
        'Track %u does not exist in this family.', trackId);
end
trackFrames = double(model.instances.frame(trackRows));
if ~any(trackFrames >= double(frameStart) & trackFrames <= double(frameEnd))
    error('cellModel:CensorOutsideTrack', ...
        'The censor interval does not overlap Track %u.', trackId);
end

scopeFlags = resolveScope(p.Results.Scope);
reasonId = resolveNamedId(model.censor_reasons, 'reason_id', 'name', ...
    p.Results.Reason, 'cellModel:UnknownCensorReason');
sourceId = resolveNamedId(model.censor_sources, 'source_id', 'name', ...
    p.Results.Source, 'cellModel:UnknownCensorSource');

% Repeating the exact action is idempotent.  Adjacent/overlapping records
% with the same semantics are merged into one deterministic interval.
same = model.censoring.family_id == familyId & ...
    model.censoring.track_id == trackId & ...
    model.censoring.scope_flags == scopeFlags & ...
    model.censoring.reason_id == reasonId & ...
    model.censoring.source_id == sourceId;
touching = same & double(model.censoring.frame_end) + 1 >= double(frameStart) & ...
    double(model.censoring.frame_start) <= double(frameEnd) + 1;
if any(touching)
    mergedStart = min([double(frameStart); double(model.censoring.frame_start(touching))]);
    mergedEnd = max([double(frameEnd); double(model.censoring.frame_end(touching))]);
    keep = ~touching;
    retainedId = min(model.censoring.censor_id(touching));
    model.censoring = keepRows(model.censoring, keep);
else
    mergedStart = double(frameStart);
    mergedEnd = double(frameEnd);
    retainedId = max([model.censoring.censor_id; uint64(0)]) + uint64(1);
end

censoring = model.censoring;
row = numel(censoring.censor_id) + 1;
censoring.censor_id(row,1) = retainedId;
censoring.family_id(row,1) = familyId;
censoring.track_id(row,1) = trackId;
censoring.frame_start(row,1) = uint32(mergedStart);
censoring.frame_end(row,1) = uint32(mergedEnd);
censoring.scope_flags(row,1) = scopeFlags;
censoring.reason_id(row,1) = reasonId;
censoring.source_id(row,1) = sourceId;
model.censoring = censoring;

if ~p.Results.Fast
    model = cellModel.normalize(model);
    cellModel.validate(model, 'Throw', true);
end
report = struct('status', 'set', 'censor_id', retainedId, ...
    'family_id', familyId, 'track_id', trackId, ...
    'frame_start', uint32(mergedStart), 'frame_end', uint32(mergedEnd), ...
    'scope_flags', scopeFlags, 'reason_id', reasonId, 'source_id', sourceId);
end

function value = positiveInteger(value, label, cls)
if ~isscalar(value) || ~isfinite(value) || value < 1 || value ~= round(value)
    error('cellModel:BadCensorValue', '%s must be a positive integer.', label);
end
value = cast(value, cls);
end

function flag = resolveScope(scope)
if iscell(scope), scope = string(scope); end
if ischar(scope) || (isstring(scope) && isscalar(scope))
    flag = cellModel.censorScope(scope);
elseif isstring(scope)
    flag = uint16(0);
    for name = scope(:).', flag = bitor(flag, cellModel.censorScope(name)); end
else
    flag = uint16(scope);
end
if ~isscalar(flag) || flag < 1 || bitand(flag, bitcmp(uint16(63))) ~= 0
    error('cellModel:BadCensorScope', 'Invalid censoring scope flags.');
end
end

function id = resolveNamedId(rows, idField, nameField, value, identifier)
ids = cast([rows.(idField)], class(rows(1).(idField)));
if isnumeric(value)
    id = cast(value, class(ids));
    hit = find(ids == id, 1);
else
    names = string({rows.(nameField)});
    hit = find(strcmpi(names, string(value)), 1);
    if isempty(hit), id = cast(0, class(ids)); else, id = ids(hit); end
end
if isempty(hit) || ~isscalar(id) || id < 1
    error(identifier, 'Unknown value "%s".', char(string(value)));
end
end

function out = keepRows(in, keep)
out = in;
names = fieldnames(in);
for i = 1:numel(names), out.(names{i}) = in.(names{i})(keep,:); end
end
