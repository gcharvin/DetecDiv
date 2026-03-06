function ctx = process(ctx)
% roiGrid.process  Interactive wrapper around roiGrid.runCore.

    if nargin < 1 || isempty(ctx)
        ctx = struct();
    end

    if isfield(ctx, 'interactive') && ctx.interactive
        ctx = roiGrid.ui(ctx);
        if isfield(ctx, 'cancelled') && ctx.cancelled
            return;
        end
    end

    ctx = roiGrid.runCore(ctx);
end
