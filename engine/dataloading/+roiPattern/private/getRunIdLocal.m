function runId = getRunIdLocal(ctx)
% getRunIdLocal  Return a stable run id for ROI pattern checkpoints.

    runId = 'default';
    if nargin < 1 || isempty(ctx)
        return;
    end
    if isstruct(ctx) && isfield(ctx,'runId') && ~isempty(ctx.runId)
        runId = char(string(ctx.runId));
        runId = matlab.lang.makeValidName(runId);
        if isempty(runId)
            runId = 'default';
        end
    end
end
