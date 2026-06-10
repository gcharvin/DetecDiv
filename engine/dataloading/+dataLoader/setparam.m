function param = setparam(ctx)
% dataLoader.setparam  Default params for dataloading.

    param = struct();
    param.path = '';
    param.positionFilter = {};
    param.channelFilter  = {};
    param.stackFilter    = {};
    param.label          = '';
    param.write          = true;
    param.interactive    = false;
    param.useExistingProjectSources = false;

    if nargin < 1 || isempty(ctx)
        return;
    end

    % allow ctx overrides
    if isfield(ctx,'path') && ~isempty(ctx.path)
        param.path = ctx.path;
    end
end
