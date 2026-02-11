function ctx = process(ctx)
% roiExtract.process  Extract ROI crops with per-ROI progress tracking.

    if nargin < 1 || isempty(ctx)
        ctx = struct();
    end

    % resolve shallow
    shallowObj = [];
    if isfield(ctx,'shallow') && ~isempty(ctx.shallow)
        shallowObj = ctx.shallow;
        fovList = shallowObj.fov;
    elseif isfield(ctx,'fovList') && ~isempty(ctx.fovList)
        fovList = ctx.fovList;
    else
        error('roiExtract.process:NoFOV','No shallow or fovList provided.');
    end

    if isempty(fovList)
        return;
    end

    % params
    p = struct();
    if isfield(ctx,'roiExtract') && ~isempty(ctx.roiExtract)
        p = ctx.roiExtract;
    elseif isfield(ctx,'extract') && ~isempty(ctx.extract)
        p = ctx.extract;
    elseif isfield(ctx,'params') && ~isempty(ctx.params)
        p = ctx.params;
    else
        p = roiExtract.setparam(ctx);
    end

    % fov selection
    if isfield(ctx,'fovIndex') && ~isempty(ctx.fovIndex)
        fovIdx = ctx.fovIndex(:)';
    else
        fovIdx = 1:numel(fovList);
    end

    % runtime overrides
    if isfield(ctx,'frames') && ~isempty(ctx.frames)
        p.frames = ctx.frames;
    end
    if isfield(ctx,'channels') && ~isempty(ctx.channels)
        p.channels = ctx.channels;
    end

    resume = true;
    if isfield(ctx,'resume'), resume = logical(ctx.resume); end
    saveProgress = true;
    if isfield(ctx,'saveProgress'), saveProgress = logical(ctx.saveProgress); end

    prog = progressLoad(shallowObj, ctx, 'roiExtract');
    if isempty(prog) || ~resume
        prog = progressInit(shallowObj, ctx, 'roiExtract', fovIdx, p);
    end

    % loop per fov for ROI-granularity
    for i = fovIdx
        if i > numel(fovList)
            continue;
        end
        f = fovList(i);
        if isempty(f.roi)
            continue;
        end

        n = numel(f.roi);
        if n==1 && isempty(f.roi(1).id)
            continue;
        end

        done = getDoneForFov(prog, i);
        if resume
            todo = setdiff(1:n, done);
        else
            todo = 1:n;
        end

        if isempty(todo)
            continue;
        end

        args = buildExtractArgs(p);
        args = [args {'FOVIndex'} {i} {'ROISelect'} {todo}];

        try
            if ~isempty(shallowObj)
                extractAllROICrops(shallowObj, args{:});
            else
                % fallback: call on a temporary shallow
                tmp = shallow();
                tmp.fov = f;
                extractAllROICrops(tmp, args{:});
            end
            prog = progressMark(shallowObj, ctx, 'roiExtract', i, todo);
            if saveProgress && ~isempty(shallowObj)
                try, shallowSave(shallowObj); catch, end
            end
        catch ME
            prog.errors{end+1} = ME.message; %#ok<AGROW>
            if ~isempty(shallowObj)
                rp = shallowObj.runProfiles;
                rp.dataloading.runs.(getRunId(ctx)) = prog;
                shallowObj.runProfiles = rp;
            end
        end
    end

    ctx.fovList = fovList;
    ctx.roiList = collectROIs(fovList);
end

% ---------------- helpers ----------------

function done = getDoneForFov(prog, fovIdx)
    done = [];
    if isempty(prog) || ~isfield(prog,'fovIds') || ~isfield(prog,'done')
        return;
    end
    pos = find(prog.fovIds == fovIdx, 1);
    if isempty(pos), return; end
    if numel(prog.done) >= pos
        done = prog.done{pos};
    end
end

function roiList = collectROIs(fovList)
    roiList = [];
    for i = 1:numel(fovList)
        r = fovList(i).roi;
        if ~isempty(r)
            roiList = [roiList r(:)']; %#ok<AGROW>
        end
    end
end

function args = buildExtractArgs(p)
    args = {};
    if isfield(p,'frames') && ~isempty(p.frames)
        args = [args {'Frames'} {p.frames}];
    end
    if isfield(p,'channels') && ~isempty(p.channels)
        args = [args {'Channels'} {p.channels}];
    end
    if isfield(p,'forceChannelNames')
        args = [args {'ForceChannelNames'} {p.forceChannelNames}];
    end
    if isfield(p,'extend')
        args = [args {'Extend'} {p.extend}];
    end
    if isfield(p,'correctDrift')
        args = [args {'CorrectDrift'} {p.correctDrift}];
    end
    if isfield(p,'driftChannel') && ~isempty(p.driftChannel)
        args = [args {'DriftChannel'} {p.driftChannel}];
    end
    if isfield(p,'driftMethod') && ~isempty(p.driftMethod)
        args = [args {'DriftMethod'} {p.driftMethod}];
    end
    if isfield(p,'scale') && ~isempty(p.scale)
        args = [args {'Scale'} {p.scale}];
    end
    if isfield(p,'cropDrift') && ~isempty(p.cropDrift)
        args = [args {'CropDrift'} {p.cropDrift}];
    end
end
