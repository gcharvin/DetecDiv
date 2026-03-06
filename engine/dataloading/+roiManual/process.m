function ctx = process(ctx)
% roiManual.process  Interactive wrapper around roiManual.runCore.

    if nargin < 1 || isempty(ctx)
        ctx = struct();
    end

    if isfield(ctx, 'interactive') && ctx.interactive
        ctx = roiManual.ui(ctx);
        if isfield(ctx, 'cancelled') && ctx.cancelled
            return;
        end
    end

    ctx = roiManual.runCore(ctx);
end
