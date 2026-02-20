function ctx = process(ctx)
% roiIdentify.process  Identify ROIs using stored pattern or ctx params.

    if nargin < 1 || isempty(ctx)
        ctx = struct();
    end

    % interactive path
    if isfield(ctx,'interactive') && ctx.interactive
        ctx = roiIdentify.ui(ctx);
        return;
    end

    % ---- resolve shallow & fov list ----
    shallowObj = [];
    if isfield(ctx,'shallow') && ~isempty(ctx.shallow)
        shallowObj = ctx.shallow;
        fovList = shallowObj.fov;
    elseif isfield(ctx,'fovList') && ~isempty(ctx.fovList)
        fovList = ctx.fovList;
    else
        error('roiIdentify.process:NoFOV','No shallow or fovList provided.');
    end

    if ~exist('fovList','var') || isempty(fovList)
        return;
    end

    % ---- params ----
    p = struct();
    if isfield(ctx,'roiIdentify') && ~isempty(ctx.roiIdentify)
        p = ctx.roiIdentify;
    elseif isfield(ctx,'params') && ~isempty(ctx.params)
        p = ctx.params;
    else
        p = roiIdentify.setparam(ctx);
    end

    % override with stored params if missing
    if ~isempty(shallowObj) && isprop(shallowObj,'runProfiles')
        rp = shallowObj.runProfiles;
        if isfield(rp,'dataloading') && isfield(rp.dataloading,'roiIdentify')
            s = rp.dataloading.roiIdentify;
            p = mergeStructDefaults(p, s);
        end
    end

    if ~isfield(p,'fallbackFullFrame'), p.fallbackFullFrame = true; end
    if ~isfield(p,'keepExisting'), p.keepExisting = false; end

    % ---- fov selection ----
    if isfield(ctx,'fovIndex') && ~isempty(ctx.fovIndex)
        fovIdx = ctx.fovIndex(:)';
    else
        fovIdx = 1:numel(fovList);
    end

    % ---- progress ----
    resume = true;
    if isfield(ctx,'resume'), resume = logical(ctx.resume); end
    saveProgress = true;
    if isfield(ctx,'saveProgress'), saveProgress = logical(ctx.saveProgress); end

    prog = progressLoad(shallowObj, ctx, 'roiIdentify');
    if isempty(prog) || ~resume
        prog = progressInit(shallowObj, ctx, 'roiIdentify', fovIdx, p);
    end

    % ---- pattern ----
    pattern = struct();
    if isfield(ctx,'pattern') && ~isempty(ctx.pattern)
        pattern = ctx.pattern;
    elseif ~isempty(shallowObj)
        pattern = loadPattern(shallowObj);
    end

    if (isempty(pattern) || ~isfield(pattern,'rect') || isempty(pattern.rect)) && ...
            isprop(fovList(1),'pattern') && ~isempty(fovList(1).pattern)
        pattern.rect = fovList(1).pattern;
        pattern.fovIndex = 1;
        if isprop(fovList(1),'id')
            pattern.fovId = fovList(1).id;
        end
        if isprop(fovList(1),'crop') && ~isempty(fovList(1).crop)
            pattern.crop = fovList(1).crop;
        end
    end

    % full-frame fallback
    if isempty(pattern) || ~isstruct(pattern) || ~isfield(pattern,'rect') || isempty(pattern.rect)
        if p.fallbackFullFrame
            for i = fovIdx
                f = fovList(i);
                try
                    if isempty(f.roi) || (numel(f.roi)==1 && isempty(f.roi(1).id))
                        % use first channel, first frame
                        im = readImage(f, p.referenceFrame, resolveChannelIndex(f, p));
                        if isempty(im)
                            continue;
                        end
                        [H,W] = size(im);
                        f.addROI([1 1 W H], f.id);
                    end
                    progressMark(shallowObj, ctx, 'roiIdentify', i, 1:numel(f.roi));
                catch
                end
            end
            if saveProgress && ~isempty(shallowObj)
                try, shallowSave(shallowObj); catch, end
            end
            ctx.fovList = fovList;
            ctx.roiList = collectROIs(fovList);
            return;
        else
            error('roiIdentify.process:NoPattern','No pattern available and fallback disabled.');
        end
    end

    % ---- build pattern patch ----
    [pattimg, chanIdx, refFrame, crop] = buildPatternPatch(fovList, pattern, p);

    % ---- select fovs to process based on progress ----
    fovsToProcess = [];
    fovIdxToProcess = [];
    for i = fovIdx
        if resume && isDoneFov(prog, i)
            continue;
        end
        fovsToProcess = [fovsToProcess fovList(i)]; %#ok<AGROW>
        fovIdxToProcess(end+1) = i; %#ok<AGROW>
    end

    if isempty(fovsToProcess)
        ctx.fovList = fovList;
        ctx.roiList = collectROIs(fovList);
        return;
    end

    % ---- call identifyROIs ----
    identifyROIs('FOV', fovsToProcess, ...
        'Frames', refFrame, ...
        'Threshold', p.threshold, ...
        'Pattern', pattimg, ...
        'Crop', crop, ...
        'Channel', chanIdx, ...
        'Keep', p.keepExisting);

    % ---- update progress ----
    for k = 1:numel(fovIdxToProcess)
        i = fovIdxToProcess(k);
        try
            n = numel(fovList(i).roi);
            if n==1 && isempty(fovList(i).roi(1).id)
                n = 0;
            end
            if n > 0
                progressMark(shallowObj, ctx, 'roiIdentify', i, 1:n);
            end
        catch
        end
    end

    if saveProgress && ~isempty(shallowObj)
        try, shallowSave(shallowObj); catch, end
    end

    ctx.fovList = fovList;
    ctx.roiList = collectROIs(fovList);
    if ~isempty(ctx.fovList)
        try
            ctx.channels = ctx.fovList(1).channel;
        catch
        end
    end

    % store params/pattern back
    if ~isempty(shallowObj) && isprop(shallowObj,'runProfiles')
        rp = shallowObj.runProfiles;
        if ~isfield(rp,'dataloading') || isempty(rp.dataloading)
            rp.dataloading = struct();
        end
        rp.dataloading.roiIdentify = p;
        shallowObj.runProfiles = rp;
        storePattern(shallowObj, pattern);
    end
end

% ---------------- helpers ----------------

function ok = isDoneFov(prog, fovIdx)
    ok = false;
    if isempty(prog) || ~isfield(prog,'fovIds') || ~isfield(prog,'done')
        return;
    end
    pos = find(prog.fovIds == fovIdx, 1);
    if isempty(pos), return; end
    if numel(prog.done) >= pos && ~isempty(prog.done{pos})
        ok = true;
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

function [pattimg, chanIdx, refFrame, crop] = buildPatternPatch(fovList, pattern, p)
    refFrame = p.referenceFrame;
    crop = p.crop;

    if isfield(pattern,'frame') && ~isempty(pattern.frame)
        refFrame = pattern.frame;
    end

    % resolve reference fov
    refFov = fovList(1);
    if isfield(pattern,'fovIndex') && ~isempty(pattern.fovIndex)
        if pattern.fovIndex <= numel(fovList)
            refFov = fovList(pattern.fovIndex);
        end
    elseif isfield(pattern,'fovId') && ~isempty(pattern.fovId)
        for i = 1:numel(fovList)
            if isprop(fovList(i),'id') && strcmp(fovList(i).id, pattern.fovId)
                refFov = fovList(i);
                break;
            end
        end
    end

    chanIdx = resolveChannelIndex(refFov, p);
    if isfield(pattern,'channelIndex') && ~isempty(pattern.channelIndex)
        chanIdx = pattern.channelIndex;
    elseif isfield(pattern,'channel') && ~isempty(pattern.channel)
        chanIdx = resolveChannelIndex(refFov, pattern);
    end

    tmp = readImage(refFov, refFrame, chanIdx);
    rect = pattern.rect;

    % rect = [x y w h]
    x1 = rect(1); y1 = rect(2);
    x2 = rect(1) + rect(3);
    y2 = rect(2) + rect(4);

    pattimg = tmp(y1:y2, x1:x2);

    if isempty(crop) && isfield(pattern,'crop')
        crop = pattern.crop;
    end
end

function idx = resolveChannelIndex(fov, p)
    idx = 1;
    if isfield(p,'channelIndex') && ~isempty(p.channelIndex)
        idx = p.channelIndex;
        return;
    end
    if isfield(p,'channel') && ~isempty(p.channel)
        q = char(string(p.channel));
        try
            pix = find(matches(fov.channel, q), 1);
            if ~isempty(pix)
                idx = pix;
            end
        catch
        end
    end
end

function out = mergeStructDefaults(base, override)
    out = base;
    if isempty(override), return; end
    fn = fieldnames(override);
    for i = 1:numel(fn)
        k = fn{i};
        if ~isfield(out,k) || isempty(out.(k))
            out.(k) = override.(k);
        end
    end
end
