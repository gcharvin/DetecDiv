function convention = relationTemporalConvention()
%ANNOTATIONMANAGER.RELATIONTEMPORALCONVENTION Parent-event timing contract.
% The stored event is the child's first visible frame, never the later frame
% at which a reviewer happened to assign the parent. Parent presence is
% required at child birth. Presence at birth-1 is eligibility metadata for
% the temporal head, not a condition for validity of static/censored GT.

convention = cellModel.relationTemporalConvention();
end
