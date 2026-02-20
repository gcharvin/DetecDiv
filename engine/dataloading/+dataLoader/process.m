function ctx = process(ctx)
% dataLoader.process  Parse input data and attach to project.

    if nargin < 1 || isempty(ctx)
        ctx = struct();
    end

    % --- params ---
    p = struct();
    if isfield(ctx,'dataLoader') && ~isempty(ctx.dataLoader)
        p = ctx.dataLoader;
    elseif isfield(ctx,'params') && ~isempty(ctx.params)
        p = ctx.params;
    end

    % allow ctx.path override
    if isfield(ctx,'path') && ~isempty(ctx.path)
        p.path = ctx.path;
    end

    if ~isfield(p,'write'), p.write = true; end
    if ~isfield(p,'interactive'), p.interactive = false; end

    % --- interactive GUI ---
    if isfield(ctx,'interactive') && ctx.interactive
        p.interactive = true;
    end

    if p.interactive
        ctx = dataLoader.ui(ctx);
        if isfield(ctx,'cancelled') && ctx.cancelled
            return;
        end
    end

    % --- get or build output ---
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
        out = parseInputData(p.path, args{:});
    end

    % add label prefix if requested
    if isfield(p,'label') && ~isempty(p.label) && isfield(out,'pos')
        lab = char(string(p.label));
        for i = 1:numel(out.pos)
            if isfield(out.pos(i),'name') && ~isempty(out.pos(i).name)
                out.pos(i).name = [lab '_' out.pos(i).name];
            end
        end
    end

    ctx.dataOutput = out;

    % --- attach to project ---
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
    if ~isempty(ctx.fovList)
        try
            ctx.channels = ctx.fovList(1).channel;
        catch
        end
    end

    % store last params in project
    if isprop(ctx.shallow,'runProfiles')
        rp = ctx.shallow.runProfiles;
        if ~isfield(rp,'dataloading') || isempty(rp.dataloading)
            rp.dataloading = struct();
        end
        rp.dataloading.dataLoader = p;
        ctx.shallow.runProfiles = rp;
    end
end
