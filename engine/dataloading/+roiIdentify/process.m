function ctx = process(ctx)
% roiIdentify.process  Identify ROIs using stored or per-FOV patterns.

    if nargin < 1 || isempty(ctx)
        ctx = struct();
    end

    if isfield(ctx,'interactive') && ctx.interactive
        ctx = roiIdentify.ui(ctx);
        return;
    end

    shallowObj = [];
    if isfield(ctx,'shallow') && ~isempty(ctx.shallow)
        shallowObj = ctx.shallow;
        fovList = shallowObj.fov;
    elseif isfield(ctx,'fovList') && ~isempty(ctx.fovList)
        fovList = ctx.fovList;
    else
        error('roiIdentify.process:NoFOV','No shallow or fovList provided.');
    end

    if isempty(fovList)
        return;
    end

    p = roiIdentify.setparam(ctx);
    if ~isempty(shallowObj) && isprop(shallowObj,'runProfiles')
        rp = shallowObj.runProfiles;
        if isfield(rp,'dataloading') && isfield(rp.dataloading,'roiIdentify')
            s = rp.dataloading.roiIdentify;
            if isstruct(s)
                p = mergeStructOverride(p, s);
            end
        end
    end
    if isfield(ctx,'roiIdentify') && isstruct(ctx.roiIdentify) && ~isempty(ctx.roiIdentify)
        p = mergeStructOverride(p, ctx.roiIdentify);
    elseif isfield(ctx,'params') && isstruct(ctx.params) && ~isempty(ctx.params)
        p = mergeStructOverride(p, ctx.params);
    end

    if ~isfield(p,'fallbackFullFrame')
        p.fallbackFullFrame = true;
    end
    if ~isfield(p,'keepExisting')
        p.keepExisting = false;
    end

    if isfield(ctx,'fovIndex') && ~isempty(ctx.fovIndex)
        fovIdx = ctx.fovIndex(:)';
    else
        fovIdx = 1:numel(fovList);
    end

    resume = true;
    if isfield(ctx,'resume')
        resume = logical(ctx.resume);
    end
    saveProgress = true;
    if isfield(ctx,'saveProgress')
        saveProgress = logical(ctx.saveProgress);
    end

    prog = progressLoad(shallowObj, ctx, 'roiIdentify');
    if isempty(prog) || ~resume
        prog = progressInit(shallowObj, ctx, 'roiIdentify', fovIdx, p);
    end

    patternList = normalizePatternList(ctx, p, shallowObj, fovList);

    fovIdxToProcess = [];
    for i = fovIdx
        if resume && isDoneFov(prog, i)
            continue;
        end
        fovIdxToProcess(end+1) = i; %#ok<AGROW>
    end

    if isempty(fovIdxToProcess)
        ctx.fovList = fovList;
        ctx.roiList = collectROIs(fovList);
        ctx.patternList = patternList;
        return;
    end

    for k = 1:numel(fovIdxToProcess)
        i = fovIdxToProcess(k);
        currentFov = fovList(i);
        pattern = selectPatternForFov(currentFov, i, ctx, p, patternList);

        if hasValidPattern(pattern)
            [pattimg, chanIdx, refFrame, crop] = buildPatternPatch(fovList, pattern, p);
            identifyROIs('FOV', currentFov, ...
                'Frames', refFrame, ...
                'Threshold', p.threshold, ...
                'Pattern', pattimg, ...
                'Crop', crop, ...
                'Channel', chanIdx, ...
                'Keep', p.keepExisting);
        elseif p.fallbackFullFrame
            applyFullFrameFallback(currentFov, p);
        else
            error('roiIdentify.process:NoPattern', 'No pattern available for FOV %d.', i);
        end

        try
            n = numel(currentFov.roi);
            if n == 1 && isempty(currentFov.roi(1).id)
                n = 0;
            end
            if n > 0
                progressMark(shallowObj, ctx, 'roiIdentify', i, 1:n);
            end
        catch
        end
    end

    if saveProgress && ~isempty(shallowObj)
        try
            shallowSave(shallowObj);
        catch
        end
    end

    ctx.fovList = fovList;
    ctx.roiList = collectROIs(fovList);
    ctx.patternList = patternList;
    if ~isempty(patternList)
        defaultPattern = selectPatternForFov(fovList(1), 1, struct(), p, patternList);
        if hasValidPattern(defaultPattern)
            ctx.pattern = defaultPattern;
        end
    end
    if ~isempty(ctx.fovList)
        try
            ctx.channels = ctx.fovList(1).channel;
        catch
        end
    end

    if ~isempty(shallowObj) && isprop(shallowObj,'runProfiles')
        rp = shallowObj.runProfiles;
        if ~isfield(rp,'dataloading') || isempty(rp.dataloading)
            rp.dataloading = struct();
        end
        p.patternList = patternList;
        rp.dataloading.roiIdentify = p;
        shallowObj.runProfiles = rp;
        if ~isempty(patternList)
            patIdx = 1;
            if isfield(p, 'activePatternIndex') && ~isempty(p.activePatternIndex)
                try
                    if p.activePatternIndex >= 1 && p.activePatternIndex <= numel(patternList)
                        patIdx = p.activePatternIndex;
                    end
                catch
                end
            end
            storePattern(shallowObj, patternList(patIdx));
        end
    end
end

function patternList = normalizePatternList(ctx, p, shallowObj, fovList)
patternList = struct([]);

if isfield(ctx,'pattern') && isstruct(ctx.pattern) && hasValidPattern(ctx.pattern)
    patternList = ctx.pattern;
    return;
end

if isfield(p,'patternList') && isstruct(p.patternList) && ~isempty(p.patternList)
    patternList = p.patternList;
    return;
end

if ~isempty(shallowObj)
    try
        stored = loadPattern(shallowObj);
        if isstruct(stored) && ~isempty(stored)
            patternList = stored;
            return;
        end
    catch
    end
end

try
    if isprop(fovList(1), 'pattern') && ~isempty(fovList(1).pattern)
        pat.rect = fovList(1).pattern;
        pat.fovIndex = 1;
        try
            pat.fovId = fovList(1).id;
        catch
            pat.fovId = '';
        end
        try
            pat.crop = fovList(1).crop;
        catch
            pat.crop = [];
        end
        pat.frame = p.referenceFrame;
        if isfield(p, 'channel')
            pat.channel = p.channel;
        end
        if isfield(p, 'channelIndex')
            pat.channelIndex = p.channelIndex;
        end
        patternList = pat;
    end
catch
end
end

function pattern = selectPatternForFov(fovObj, fovIndex, ctx, p, patternList)
pattern = struct();

if isfield(ctx,'pattern') && isstruct(ctx.pattern) && hasValidPattern(ctx.pattern)
    pattern = ctx.pattern;
    return;
end

if isempty(patternList)
    return;
end

for i = 1:numel(patternList)
    try
        if isfield(patternList(i), 'fovId') && isprop(fovObj, 'id') && strcmp(char(string(patternList(i).fovId)), char(string(fovObj.id)))
            pattern = patternList(i);
            return;
        end
    catch
    end
end

for i = 1:numel(patternList)
    try
        if isfield(patternList(i), 'fovIndex') && ~isempty(patternList(i).fovIndex) && patternList(i).fovIndex == fovIndex
            pattern = patternList(i);
            return;
        end
    catch
    end
end

activeIdx = [];
if isfield(p, 'activePatternIndex') && ~isempty(p.activePatternIndex)
    activeIdx = p.activePatternIndex;
end
if ~isempty(activeIdx) && activeIdx >= 1 && activeIdx <= numel(patternList)
    pattern = patternList(activeIdx);
    return;
end

pattern = patternList(1);
end

function tf = hasValidPattern(pattern)
tf = isstruct(pattern) && ~isempty(pattern) && isfield(pattern,'rect') && ~isempty(pattern.rect);
end

function applyFullFrameFallback(fovObj, p)
    if isempty(fovObj.roi) || (numel(fovObj.roi) == 1 && isempty(fovObj.roi(1).id))
        im = readImage(fovObj, p.referenceFrame, resolveChannelIndex(fovObj, p));
        if isempty(im)
            return;
        end
        [h, w] = size(im);
        fovObj.addROI([1 1 w h], fovObj.id);
    end
end

function ok = isDoneFov(prog, fovIdx)
    ok = false;
    if isempty(prog) || ~isfield(prog,'fovIds') || ~isfield(prog,'done')
        return;
    end
    pos = find(prog.fovIds == fovIdx, 1);
    if isempty(pos)
        return;
    end
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

    x1 = rect(1);
    y1 = rect(2);
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
