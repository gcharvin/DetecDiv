function [evidence, model] = parentageEvidence(model, family, varargin)
%CELLMODEL.PARENTAGEEVIDENCE Classify relation evidence by usable head.
% Annotation validity and training eligibility are deliberately distinct.
% A parent/child relation is a coherent static annotation when both tracks
% are visible at the child's first frame. It is eligible for temporal-birth
% supervision only when the parent is also materialized on the preceding
% frame. The stored event is always canonical child birth, never UI click
% time.

p = inputParser;
p.addParameter('Frames', [], @isnumeric);
p.parse(varargin{:});
selectedFrames = unique(round(double(p.Results.Frames(:))));
selectedFrames = selectedFrames(isfinite(selectedFrames) & selectedFrames >= 1);

model = cellModel.normalize(model);
[familyIndex, familyId] = cellModel.familyIndex(model, family);
evidence = repmat(emptyEvidence(), 0, 1);
if isempty(familyIndex), return; end
[model, ~] = cellModel.canonicalizeParentageEvents( ...
    model, 'FamilyIds', familyId);

rows = find(model.relations.family_id == familyId & ...
    model.relations.type_id == uint8(1));
if ~isempty(selectedFrames)
    rows = rows(ismember(double(model.relations.event_frame(rows)), ...
        selectedFrames));
end

for row = rows(:).'
    parentId = model.relations.parent_track_id(row);
    childId = model.relations.child_track_id(row);
    eventFrame = double(model.relations.event_frame(row));
    parentFrames = trackFrames(model, familyId, parentId);
    childFrames = trackFrames(model, familyId, childId);

    item = emptyEvidence();
    item.relation_id = model.relations.relation_id(row);
    item.family_id = familyId;
    item.parent_track_id = parentId;
    item.child_track_id = childId;
    item.event_frame = uint32(eventFrame);
    if ~isempty(parentFrames)
        item.parent_first_frame = uint32(min(parentFrames));
        item.parent_last_frame = uint32(max(parentFrames));
    end
    if ~isempty(childFrames)
        item.child_first_frame = uint32(min(childFrames));
    end
    item.parent_present_at_event = ismember(eventFrame, parentFrames);
    item.child_present_at_event = ismember(eventFrame, childFrames);
    item.previous_frame_materialized = eventFrame > 1 && ...
        (isempty(selectedFrames) || ismember(eventFrame - 1, selectedFrames));
    item.parent_present_before_event = item.previous_frame_materialized && ...
        ismember(eventFrame - 1, parentFrames);
    item.static_parentage_eligible = item.parent_present_at_event && ...
        item.child_present_at_event;
    item.temporal_parentage_eligible = item.static_parentage_eligible && ...
        item.parent_present_before_event;

    if ~item.child_present_at_event
        item.evidence_mode = 'invalid_child_absent_at_birth';
        item.exclusion_reason = 'child_absent_at_canonical_event';
    elseif ~item.parent_present_at_event
        item.evidence_mode = 'invalid_parent_absent_at_birth';
        item.exclusion_reason = 'parent_absent_at_child_birth';
    elseif item.temporal_parentage_eligible
        item.evidence_mode = 'observed_birth';
    elseif item.parent_first_frame == item.event_frame && ...
            item.child_first_frame == item.event_frame
        item.evidence_mode = 'left_censored_joint_entry';
        item.exclusion_reason = 'no_parent_history_before_joint_entry';
    elseif ~item.previous_frame_materialized
        item.evidence_mode = 'left_censored_range_start';
        item.exclusion_reason = 'preceding_frame_not_materialized';
    else
        item.evidence_mode = 'static_only_temporal_gap';
        item.exclusion_reason = 'parent_missing_on_preceding_frame';
    end
    evidence(end+1,1) = item; %#ok<AGROW>
end
end

function value = emptyEvidence()
value = struct( ...
    'relation_id', uint64(0), ...
    'family_id', uint32(0), ...
    'parent_track_id', uint64(0), ...
    'child_track_id', uint64(0), ...
    'event_frame', uint32(0), ...
    'parent_first_frame', uint32(0), ...
    'parent_last_frame', uint32(0), ...
    'child_first_frame', uint32(0), ...
    'parent_present_at_event', false, ...
    'child_present_at_event', false, ...
    'previous_frame_materialized', false, ...
    'parent_present_before_event', false, ...
    'static_parentage_eligible', false, ...
    'temporal_parentage_eligible', false, ...
    'evidence_mode', '', ...
    'exclusion_reason', '');
end

function frames = trackFrames(model, familyId, trackId)
rows = model.instances.family_id == familyId & ...
    model.instances.track_id == uint64(trackId);
frames = unique(double(model.instances.frame(rows)));
end
