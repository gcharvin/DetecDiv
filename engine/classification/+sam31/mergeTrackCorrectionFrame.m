function [labels, action] = mergeTrackCorrectionFrame(labels, candidate, trackLabel, opts)
% sam31.mergeTrackCorrectionFrame  Merge one propagated mask into editable GT.

if nargin < 4 || ~isstruct(opts)
    opts = struct();
end
collisionThreshold = numericOption(opts, 'collisionThreshold', 0.35);
reassignmentIouThreshold = numericOption(opts, 'reassignmentIouThreshold', 0.50);
allowIdentityReassignment = logicalOption(opts, 'allowIdentityReassignment', false);

candidate = logical(candidate);
trackLabel = double(trackLabel);
action = struct('applied', false, 'clipped', false, 'skipped', false, ...
    'empty', false, 'reassignedLabel', 0, 'reassignmentIou', 0, ...
    'collisionFraction', 0);
if ~any(candidate(:))
    action.empty = true;
    return;
end

% A broken track normally means that the desired provider mask already
% exists in GT under another ID. Treat a strong one-object match as an
% intentional identity transfer instead of rejecting it as a collision.
overlapLabels = unique(double(labels(candidate)));
overlapLabels(overlapLabels == 0 | overlapLabels == trackLabel) = [];
if allowIdentityReassignment && isscalar(overlapLabels)
    otherLabel = overlapLabels(1);
    otherObject = labels == otherLabel;
    overlapCount = nnz(candidate & otherObject);
    unionCount = nnz(candidate | otherObject);
    matchIou = overlapCount / max(1, unionCount);
    if matchIou >= reassignmentIouThreshold
        labels(otherObject) = 0;
        action.reassignedLabel = otherLabel;
        action.reassignmentIou = matchIou;
    end
end

selfMask = labels == trackLabel;
otherMask = labels > 0 & labels ~= trackLabel;
overlap = candidate & otherMask;
action.collisionFraction = nnz(overlap) / max(1, nnz(candidate));
if action.collisionFraction > collisionThreshold
    action.skipped = true;
    return;
end
if any(overlap(:))
    candidate(overlap) = false;
    action.clipped = true;
end
labels(selfMask) = 0;
labels(candidate) = cast(trackLabel, 'like', labels);
action.applied = true;
end

function value = numericOption(opts, name, fallback)
value = fallback;
try
    if isfield(opts, name) && ~isempty(opts.(name))
        candidate = double(opts.(name));
        if isscalar(candidate) && isfinite(candidate)
            value = candidate;
        end
    end
catch
end
end

function value = logicalOption(opts, name, fallback)
value = fallback;
try
    if isfield(opts, name) && ~isempty(opts.(name))
        candidate = logical(opts.(name));
        if isscalar(candidate)
            value = candidate;
        end
    end
catch
end
end
