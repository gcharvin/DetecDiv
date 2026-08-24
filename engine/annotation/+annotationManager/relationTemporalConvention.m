function convention = relationTemporalConvention()
%ANNOTATIONMANAGER.RELATIONTEMPORALCONVENTION Parent-event timing contract.
% A reviewed parent relation may be recorded either on the child's first
% visible frame (birth) or on the following frame (birth+1). This preserves
% the established Score workflow where a link can be confirmed after the
% new track has appeared. Consequently the child birth must be event_frame
% or event_frame-1, and both child and parent presence are accepted on
% event_frame or event_frame-1. Larger offsets are temporal GT errors.

convention = cellModel.relationTemporalConvention();
end
