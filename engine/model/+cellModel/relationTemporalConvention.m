function convention = relationTemporalConvention()
%CELLMODEL.RELATIONTEMPORALCONVENTION Canonical parent-event timing.
% New or replaced parent links are stored at the child's first visible
% frame. Validation also accepts legacy/UI links recorded at birth+1. At
% either accepted event frame, parent and child presence may be observed on
% event_frame or event_frame-1. Existing relations are never migrated by
% merely loading or validating a model.

convention = struct( ...
    'name', 'child_birth_or_birth_plus_one_v1', ...
    'canonical_event', 'child_birth', ...
    'accepted_event_minus_birth', [0 1], ...
    'accepted_presence_frames_relative_to_event', [0 -1]);
end
