function runId = getRunId(ctx)
% getRunId  Return a stable run id for dataloading checkpoints.

    runId = 'default';
    if nargin < 1 || isempty(ctx)
        return;
    end
    if isfield(ctx,'runId') && ~isempty(ctx.runId)
        runId = char(string(ctx.runId));
    end
end
