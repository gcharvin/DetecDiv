function ctx = process(ctx)
% roiExtract.process  Extract ROI crops with per-ROI progress tracking.

    if nargin < 1 || isempty(ctx)
        ctx = struct();
    end

    ctx.errors = {};

    % interactive path
    if isfield(ctx,'interactive') && ctx.interactive
        ctx = roiExtract.ui(ctx);
        if isfield(ctx,'cancelled') && ctx.cancelled
            return;
        end
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
    p = roiExtract.setparam(ctx);
    if ~isempty(shallowObj)
        try
            if isfield(shallowObj.runProfiles,'dataloading') && isfield(shallowObj.runProfiles.dataloading,'roiExtract')
                stored = shallowObj.runProfiles.dataloading.roiExtract;
                if isstruct(stored)
                    p = mergeStructOverride(p, stored);
                end
            end
        catch
        end
    end
    if isfield(ctx,'roiExtract') && isstruct(ctx.roiExtract) && ~isempty(ctx.roiExtract)
        p = mergeStructOverride(p, ctx.roiExtract);
    elseif isfield(ctx,'extract') && isstruct(ctx.extract) && ~isempty(ctx.extract)
        p = mergeStructOverride(p, ctx.extract);
    elseif isfield(ctx,'params') && isstruct(ctx.params) && ~isempty(ctx.params)
        p = mergeStructOverride(p, ctx.params);
    end

    % fov selection
    if isfield(ctx,'fovIndex') && ~isempty(ctx.fovIndex)
        fovIdx = ctx.fovIndex(:)';
    elseif isfield(p,'fovIndex') && ~isempty(p.fovIndex)
        fovIdx = p.fovIndex(:)';
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

    progressDlg = [];
    if isfield(ctx,'progressDlg') && ~isempty(ctx.progressDlg)
        progressDlg = ctx.progressDlg;
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

        if ~isempty(progressDlg)
            try
                if isprop(progressDlg,'CancelRequested') && progressDlg.CancelRequested
                    ctx.canceled = true;
                    break;
                end
            catch
            end
        end

        args = buildExtractArgs(p, progressDlg);
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
            ctx.errors{end+1} = ME.message; %#ok<AGROW>
            if ~isempty(shallowObj)
                rp = shallowObj.runProfiles;
                rp.dataloading.runs.(getRunId(ctx)) = prog;
                shallowObj.runProfiles = rp;
            end
        end
    end

    ctx.fovList = fovList;
    ctx.roiList = collectROIs(fovList);
    ctx = maybeWarmRoiCache(ctx, p);
    ctx.dataSeries = collectDataSeries(ctx.roiList);
    if ~isfield(ctx,'channels') || isempty(ctx.channels)
        if isfield(p,'channels') && ~isempty(p.channels)
            ctx.channels = p.channels;
        elseif ~isempty(fovList)
            try
                ctx.channels = fovList(1).channel;
            catch
            end
        end
    end

    if ~isempty(shallowObj)
        try
            if ~isfield(shallowObj.runProfiles,'dataloading') || isempty(shallowObj.runProfiles.dataloading)
                shallowObj.runProfiles.dataloading = struct();
            end
            shallowObj.runProfiles.dataloading.roiExtract = p;
        catch
        end
    end
end

function ctx = maybeWarmRoiCache(ctx, p)
    cachePolicy = resolveCachePolicy(ctx);
    if strcmp(cachePolicy, 'disk')
        return;
    end

    rois = [];
    if isfield(ctx,'roiList') && ~isempty(ctx.roiList)
        rois = ctx.roiList;
    end
    if isempty(rois)
        return;
    end

    if strcmp(cachePolicy, 'auto') && ~shouldAutoWarmCache(rois)
        return;
    end

    for i = 1:numel(rois)
        try
            if isempty(rois(i).image)
                rois(i).load('Silent');
            elseif isempty(rois(i).data)
                rois(i).load('Data', true, 'Silent');
            end
        catch
        end
    end

    ctx.roiList = rois;
end

function tf = shouldAutoWarmCache(rois)
    tf = false;
    if isempty(rois)
        return;
    end
    if numel(rois) > 64
        return;
    end

    totalBytes = 0;
    for i = 1:numel(rois)
        try
            h5File = fullfile(rois(i).path, ['im_' rois(i).id '.h5']);
            d = dir(h5File);
            if ~isempty(d)
                totalBytes = totalBytes + d(1).bytes;
            end
        catch
        end
        if totalBytes > 512 * 1024 * 1024
            return;
        end
    end
    tf = totalBytes > 0 && totalBytes <= 512 * 1024 * 1024;
end

function policy = resolveCachePolicy(ctx)
    policy = 'auto';
    try
        if isfield(ctx,'io') && isstruct(ctx.io) && isfield(ctx.io,'cachePolicy') && ~isempty(ctx.io.cachePolicy)
            policy = lower(char(string(ctx.io.cachePolicy)));
        elseif isfield(ctx,'store') && isstruct(ctx.store) && isfield(ctx.store,'cacheMode') && ~isempty(ctx.store.cacheMode)
            policy = lower(char(string(ctx.store.cacheMode)));
        elseif isfield(ctx,'cachePolicy') && ~isempty(ctx.cachePolicy)
            policy = lower(char(string(ctx.cachePolicy)));
        end
    catch
        policy = 'auto';
    end
    switch policy
        case {'memory','disk','auto'}
        otherwise
            policy = 'auto';
    end
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

function ds = collectDataSeries(roiList)
    ds = {};
    if isempty(roiList)
        return;
    end
    for i = 1:numel(roiList)
        try
            r = roiList(i);
            if isprop(r,'data') && ~isempty(r.data)
                for k = 1:numel(r.data)
                    if isprop(r.data(k),'groupid') && ~isempty(r.data(k).groupid)
                        ds{end+1} = char(r.data(k).groupid); %#ok<AGROW>
                    end
                end
            end
        catch
        end
    end
    if ~isempty(ds)
        ds = unique(ds,'stable');
    end
end

function args = buildExtractArgs(p, progressDlg)
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
    if isfield(p,'driftRefMode') && ~isempty(p.driftRefMode)
        args = [args {'DriftRefMode'} {p.driftRefMode}];
    end
    if isfield(p,'driftSubpixel')
        args = [args {'DriftSubpixel'} {p.driftSubpixel}];
    end
    if isfield(p,'driftMaxShift') && ~isempty(p.driftMaxShift)
        args = [args {'DriftMaxShift'} {p.driftMaxShift}];
    end
    if isfield(p,'scale') && ~isempty(p.scale)
        args = [args {'Scale'} {p.scale}];
    end
    if isfield(p,'cropDrift') && ~isempty(p.cropDrift)
        args = [args {'CropDrift'} {p.cropDrift}];
    end
    if nargin >= 2 && ~isempty(progressDlg)
        args = [args {'hprogressbar'} {progressDlg}];
    end
end

function out = mergeStructOverride(base, override)
    out = base;
    if isempty(override)
        return;
    end
    fn = fieldnames(override);
    for i = 1:numel(fn)
        out.(fn{i}) = override.(fn{i});
    end
end
