function [baseValue, spanValue] = detecdiv_progress_bounds(ctx)
%detecdiv_progress_bounds Map module-local progress into pipeline progress.
%
% [baseValue, spanValue] = detecdiv_progress_bounds(ctx) returns the
% pipeline-wide interval occupied by the current unit of work. A module can
% therefore report a local value in [0,1] without knowing how many pipeline
% nodes or ROIs surround it.

    baseValue = 0;
    spanValue = 1;
    if nargin < 1 || ~isstruct(ctx)
        return;
    end

    progress = struct();
    if isfield(ctx, 'progress') && isstruct(ctx.progress)
        progress = ctx.progress;
    end

    nodeIndex = numericScalar(progress, 'currentNodeIndex', 1);
    totalNodes = max(1, numericScalar(progress, 'totalNodes', 1));
    nodeIndex = max(1, min(totalNodes, nodeIndex));

    roiIndex = numericScalar(progress, 'roiIndex', []);
    totalRois = numericScalar(progress, 'totalRois', []);
    if ~isempty(roiIndex) && ~isempty(totalRois) && totalRois > 0
        totalRois = max(1, totalRois);
        roiIndex = max(1, min(totalRois, roiIndex));
        baseValue = ((roiIndex - 1) * totalNodes + (nodeIndex - 1)) / ...
            (totalRois * totalNodes);
        spanValue = 1 / (totalRois * totalNodes);
    else
        baseValue = (nodeIndex - 1) / totalNodes;
        spanValue = 1 / totalNodes;
    end

    localBase = numericScalar(progress, 'localBase', 0);
    localSpan = numericScalar(progress, 'localSpan', 1);
    localBase = max(0, min(1, localBase));
    localSpan = max(0, min(1 - localBase, localSpan));
    baseValue = baseValue + spanValue * localBase;
    spanValue = spanValue * localSpan;

    baseValue = max(0, min(1, baseValue));
    spanValue = max(0, min(1 - baseValue, spanValue));
end

function value = numericScalar(source, fieldName, fallback)
    value = fallback;
    try
        if isstruct(source) && isfield(source, fieldName) && ...
                ~isempty(source.(fieldName))
            candidate = double(source.(fieldName));
            if isscalar(candidate) && isfinite(candidate)
                value = candidate;
            end
        end
    catch
        value = fallback;
    end
end
