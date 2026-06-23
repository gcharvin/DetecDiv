function ctx = process(ctx)
% dataLoader.process  Parse input data and attach to project.

    if nargin < 1 || isempty(ctx)
        ctx = struct();
    end
    detecdiv_check_cancel(ctx, 'dataLoader start');

    p = dataLoader.setparam(struct());
    if isfield(ctx,'dataLoader') && isstruct(ctx.dataLoader) && ~isempty(ctx.dataLoader)
        p = mergeStructOverride(p, ctx.dataLoader);
    elseif isfield(ctx,'params') && isstruct(ctx.params) && ~isempty(ctx.params)
        p = mergeStructOverride(p, ctx.params);
    end

    if isfield(ctx,'path') && ~isempty(ctx.path)
        p.path = ctx.path;
    end
    if ~isfield(p,'write'), p.write = true; end
    if ~isfield(p,'interactive'), p.interactive = false; end
    try
        if isfield(ctx,'io') && isstruct(ctx.io) && isfield(ctx.io,'persistOutputs') && ...
                ~isempty(ctx.io.persistOutputs) && ~logical(ctx.io.persistOutputs)
            p.write = false;
        end
    catch
    end
    if isfield(ctx,'interactive') && ctx.interactive
        p.interactive = true;
    end

    if p.interactive
        ctx = dataLoader.ui(ctx);
        if isfield(ctx,'cancelled') && ctx.cancelled
            return;
        end
        if isfield(ctx,'dataLoader') && isstruct(ctx.dataLoader)
            p = mergeStructOverride(p, ctx.dataLoader);
        end
    end

    if isfield(p, 'useExistingProjectSources') && ~isempty(p.useExistingProjectSources) && logical(p.useExistingProjectSources)
        detecdiv_check_cancel(ctx, 'dataLoader use existing project sources');
        if ~isfield(ctx, 'shallow') || isempty(ctx.shallow) || ~isa(ctx.shallow, 'shallow')
            error('dataLoader.process:NoProject', ...
                'useExistingProjectSources requires ctx.shallow to be a loaded shallow project.');
        end
        ctx.fovList = ctx.shallow.fov;
        ctx.images = ctx.fovList;
        if ~isempty(ctx.fovList)
            try
                fovChannels = ctx.fovList(1).channel;
                if ~isempty(fovChannels)
                    ctx.channels = fovChannels;
                elseif ~isfield(ctx,'channels') || isempty(ctx.channels)
                    ctx.channels = {};
                end
            catch
            end
        end
        if isprop(ctx.shallow,'runProfiles')
            rp = ctx.shallow.runProfiles;
            if ~isfield(rp,'dataloading') || isempty(rp.dataloading)
                rp.dataloading = struct();
            end
            rp.dataloading.dataLoader = p;
            ctx.shallow.runProfiles = rp;
        end
        return;
    end

    out = [];
    if isfield(ctx,'dataOutput') && ~isempty(ctx.dataOutput)
        out = ctx.dataOutput;
    end

    if isempty(out)
        if ~isfield(p,'path') || isempty(p.path)
            error('dataLoader.process:NoPath','No input path provided.');
        end

        args = {};
        if isfield(p,'positionFilter') && ~isempty(p.positionFilter)
            args = [args {'positionfilter'} {p.positionFilter}];
        end
        if isfield(p,'channelFilter') && ~isempty(p.channelFilter)
            args = [args {'channelfilter'} {p.channelFilter}];
        end
        if isfield(p,'stackFilter') && ~isempty(p.stackFilter)
            args = [args {'stackfilter'} {p.stackFilter}];
        end
        if isfield(p,'progress') && ~isempty(p.progress)
            args = [args {'progress'} {p.progress}];
        end
        tokenFile = cancelTokenFileFromCtx(ctx);
        if ~isempty(tokenFile)
            args = [args {'canceltokenfile'} {tokenFile}];
        end
        detecdiv_check_cancel(ctx, 'dataLoader before parseInputData');
        out = parseInputData(p.path, args{:});
        detecdiv_check_cancel(ctx, 'dataLoader after parseInputData');
    end

    if isfield(p,'positionIdx') && ~isempty(p.positionIdx) && isfield(out,'pos') && ~isempty(out.pos)
        detecdiv_check_cancel(ctx, 'dataLoader before position selection');
        idx = p.positionIdx(:)';
        idx = idx(idx >= 1 & idx <= numel(out.pos));
        if ~isempty(idx)
            out.pos = out.pos(idx);
        else
            out.pos = out.pos([]);
        end
    end

    if isfield(p,'label') && ~isempty(p.label) && isfield(out,'pos')
        lab = char(string(p.label));
        for i = 1:numel(out.pos)
            if isfield(out.pos(i),'name') && ~isempty(out.pos(i).name)
                out.pos(i).name = [lab '_' out.pos(i).name];
            end
        end
    end

    ctx.dataOutput = out;
    detecdiv_check_cancel(ctx, 'dataLoader before addData');

    if ~isfield(ctx,'shallow') || isempty(ctx.shallow)
        ctx.shallow = shallow();
    end

    ctx.shallow.addData(out);
    detecdiv_check_cancel(ctx, 'dataLoader after addData');
    if p.write
        try
            shallowSave(ctx.shallow);
        catch
        end
    end

    ctx.fovList = ctx.shallow.fov;
    % Keep a contract-level alias used by pipeline contracts.
    ctx.images = ctx.fovList;
    if ~isempty(ctx.fovList)
        try
            fovChannels = ctx.fovList(1).channel;
            if ~isempty(fovChannels)
                ctx.channels = fovChannels;
            elseif ~isfield(ctx,'channels') || isempty(ctx.channels)
                ctx.channels = {};
            end
        catch
        end
    end
    if isfield(p,'positionIdx') && ~isempty(p.positionIdx)
        ctx.positionIdx = p.positionIdx;
    end
    if isfield(p,'channelIdx') && ~isempty(p.channelIdx)
        ctx.channelIdx = p.channelIdx;
    end
    if isfield(p,'frameRange') && ~isempty(p.frameRange)
        ctx.frameRange = p.frameRange;
    end

    if isprop(ctx.shallow,'runProfiles')
        rp = ctx.shallow.runProfiles;
        if ~isfield(rp,'dataloading') || isempty(rp.dataloading)
            rp.dataloading = struct();
        end
        rp.dataloading.dataLoader = p;
        ctx.shallow.runProfiles = rp;
    end
end

function tokenFile = cancelTokenFileFromCtx(ctx)
    tokenFile = '';
    try
        if isfield(ctx,'cancel') && isstruct(ctx.cancel) ...
                && isfield(ctx.cancel,'tokenFile') && ~isempty(ctx.cancel.tokenFile)
            tokenFile = char(string(ctx.cancel.tokenFile));
        end
    catch
        tokenFile = '';
    end
end

function out = mergeStructOverride(base, patch)
    out = base;
    if nargin < 2 || ~isstruct(patch) || isempty(patch)
        return;
    end
    fn = fieldnames(patch);
    for i = 1:numel(fn)
        out.(fn{i}) = patch.(fn{i});
    end
end
