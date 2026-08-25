function [model, report] = canonicalizeParentageEvents(model, varargin)
%CELLMODEL.CANONICALIZEPARENTAGEEVENTS Derive parent events from child birth.
% event_frame is biological metadata, not the frame at which a reviewer
% created the link. Parent/child identities are never changed here.
%
% The input is expected to use the normalized columnar schema. Relations
% whose child track is missing are left untouched so validation can report
% the missing identity explicitly.

p = inputParser;
p.addParameter('FamilyIds', [], @isnumeric);
p.parse(varargin{:});
familyIds = uint32(p.Results.FamilyIds(:));

report = struct( ...
    'changed', false, ...
    'count', 0, ...
    'relation_id', zeros(0,1,'uint64'), ...
    'family_id', zeros(0,1,'uint32'), ...
    'child_track_id', zeros(0,1,'uint64'), ...
    'previous_event_frame', zeros(0,1,'uint32'), ...
    'event_frame', zeros(0,1,'uint32'));

requiredRelationFields = {'relation_id','family_id','child_track_id', ...
    'event_frame','type_id'};
requiredInstanceFields = {'family_id','track_id','frame'};
if ~isstruct(model) || ~isfield(model, 'relations') || ...
        ~isfield(model, 'instances') || ...
        ~all(isfield(model.relations, requiredRelationFields)) || ...
        ~all(isfield(model.instances, requiredInstanceFields))
    return;
end

rows = find(model.relations.type_id == uint8(1) & ...
    model.relations.family_id > 0 & ...
    model.relations.child_track_id > 0);
if ~isempty(familyIds)
    rows = rows(ismember(model.relations.family_id(rows), familyIds));
end
for row = rows(:).'
    familyId = model.relations.family_id(row);
    childTrackId = model.relations.child_track_id(row);
    childRows = model.instances.family_id == familyId & ...
        model.instances.track_id == childTrackId & ...
        model.instances.frame > 0;
    if ~any(childRows)
        continue;
    end

    eventFrame = uint32(min(model.instances.frame(childRows)));
    previousFrame = model.relations.event_frame(row);
    if previousFrame == eventFrame
        continue;
    end

    model.relations.event_frame(row) = eventFrame;
    report.relation_id(end+1,1) = ...
        model.relations.relation_id(row);
    report.family_id(end+1,1) = familyId;
    report.child_track_id(end+1,1) = childTrackId;
    report.previous_event_frame(end+1,1) = previousFrame;
    report.event_frame(end+1,1) = eventFrame;
end

report.count = numel(report.relation_id);
report.changed = report.count > 0;
end
