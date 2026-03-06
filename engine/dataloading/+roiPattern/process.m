function ctx = process(ctx)
% roiPattern.process  Run pattern-based ROI identification.

    if nargin < 1 || isempty(ctx)
        ctx = struct();
    end

    if isfield(ctx, 'interactive') && ctx.interactive
        ctx = roiPattern.ui(ctx);
        if isfield(ctx, 'cancelled') && ctx.cancelled
            return;
        end
    end

    ctx = roiPattern.runCore(ctx);

    if isfield(ctx, 'roiPattern') && isstruct(ctx.roiPattern)
        ctx.params = ctx.roiPattern;
    end

    if isfield(ctx, 'shallow') && ~isempty(ctx.shallow)
        try
            if ~isfield(ctx.shallow.runProfiles, 'dataloading') || isempty(ctx.shallow.runProfiles.dataloading)
                ctx.shallow.runProfiles.dataloading = struct();
            end
            if isfield(ctx, 'roiPattern') && isstruct(ctx.roiPattern)
                ctx.shallow.runProfiles.dataloading.roiPattern = ctx.roiPattern;
            end
        catch
        end
    end
end
