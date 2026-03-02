function ctx = process(ctx)
% roiPattern.process  Run pattern-based ROI detection using the legacy backend.

    if nargin < 1 || isempty(ctx)
        ctx = struct();
    end

    if isfield(ctx, 'interactive') && ctx.interactive
        ctx = roiPattern.ui(ctx);
        if isfield(ctx, 'cancelled') && ctx.cancelled
            return;
        end
    end

    if isfield(ctx, 'roiPattern') && isstruct(ctx.roiPattern)
        ctx.roiIdentify = ctx.roiPattern;
        ctx.params = ctx.roiPattern;
    elseif isfield(ctx, 'params') && isstruct(ctx.params)
        ctx.roiIdentify = ctx.params;
    end

    ctx = roiIdentify.process(ctx);

    if isfield(ctx, 'roiIdentify') && isstruct(ctx.roiIdentify)
        ctx.roiPattern = ctx.roiIdentify;
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
