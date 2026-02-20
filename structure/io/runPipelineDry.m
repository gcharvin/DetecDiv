function [ok, report] = runPipelineDry(pipe, ctx, opts)
% runPipelineDry  Validate prerequisites without executing nodes.

    if nargin < 2 || isempty(ctx)
        ctx = struct();
    end
    if nargin < 3 || isempty(opts)
        opts = struct();
    end

    allowGui = true;
    if isfield(opts,'allowGui') && ~isempty(opts.allowGui)
        allowGui = logical(opts.allowGui);
    end

    [okV, report] = validatePipeline(pipe, ctx, struct('allowGui', allowGui));

    % strict ok if any missing params (even if GUI could fill them)
    ok = okV;
    if isfield(report,'missingParams') && ~isempty(report.missingParams)
        ok = false;
    end

    report.dryRun = true;
    report.okStrict = ok;
    report.ok = okV;
end
