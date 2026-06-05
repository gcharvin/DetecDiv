function ctx = process(ctx)
% dataLoader.process  Parse input data and attach to project.

    if nargin < 1 || isempty(ctx)
        ctx = struct();
    end

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
        out = parseInputData(p.path, args{:});
    end

    if isfield(p,'positionIdx') && ~isempty(p.positionIdx) && isfield(out,'pos') && ~isempty(out.pos)
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

    if ~isfield(ctx,'shallow') || isempty(ctx.shallow)
        ctx.shallow = shallow();
    end

    if p.write
        ctx.shallow.addData(out);
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
            ctx.channels = ctx.fovList(1).channel;
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
