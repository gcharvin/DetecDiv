function [gh, opts] = score_layoutMovie(gh, dh, rois, opts)
% Shared export geometry keeps movie and sequence text sizing consistent.
[gh, opts] = score_layoutExport(gh, dh, rois, opts);
end
