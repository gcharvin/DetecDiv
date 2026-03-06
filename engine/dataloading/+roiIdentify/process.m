function ctx = process(ctx)
% roiIdentify.process  Legacy compatibility wrapper around roiPattern core.

    if nargin < 1 || isempty(ctx)
        ctx = struct();
    end

    if isfield(ctx,'interactive') && ctx.interactive
        ctx = roiIdentify.ui(ctx);
        return;
    end

    % Bridge legacy field names to the new ROI pattern core.
    if isfield(ctx,'roiIdentify') && isstruct(ctx.roiIdentify) && ~isempty(ctx.roiIdentify)
        ctx.roiPattern = ctx.roiIdentify;
    elseif isfield(ctx,'params') && isstruct(ctx.params) && ~isempty(ctx.params)
        ctx.roiPattern = ctx.params;
    else
        if isfield(ctx,'shallow') && ~isempty(ctx.shallow)
            try
                rp = ctx.shallow.runProfiles;
                if isfield(rp,'dataloading') && isfield(rp.dataloading,'roiIdentify') && isstruct(rp.dataloading.roiIdentify)
                    ctx.roiPattern = rp.dataloading.roiIdentify;
                end
            catch
            end
        end
    end

    ctx = roiPattern.runCore(ctx);

    if isfield(ctx,'roiPattern') && isstruct(ctx.roiPattern)
        ctx.roiIdentify = ctx.roiPattern;
        ctx.params = ctx.roiIdentify;
    end

    if isfield(ctx,'shallow') && ~isempty(ctx.shallow)
        try
            if ~isfield(ctx.shallow.runProfiles, 'dataloading') || isempty(ctx.shallow.runProfiles.dataloading)
                ctx.shallow.runProfiles.dataloading = struct();
            end
            if isfield(ctx, 'roiIdentify') && isstruct(ctx.roiIdentify)
                ctx.shallow.runProfiles.dataloading.roiIdentify = ctx.roiIdentify;
            end
        catch
        end
    end
end
