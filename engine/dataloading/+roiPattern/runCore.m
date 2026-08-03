function ctx = runCore(ctx)
% roiPattern.runCore  Core pattern-based ROI identification logic.

    if nargin < 1 || isempty(ctx)
        ctx = struct();
    end
    detecdiv_check_cancel(ctx, 'roiPattern runCore start');


    shallowObj = [];
    if isfield(ctx,'shallow') && ~isempty(ctx.shallow)
        shallowObj = ctx.shallow;
        fovList = shallowObj.fov;
    elseif isfield(ctx,'fovList') && ~isempty(ctx.fovList)
        fovList = ctx.fovList;
    else
        error('roiPattern.runCore:NoFOV','No shallow or fovList provided.');
    end

    if isempty(fovList)
        return;
    end

    p = roiPattern.setparam(struct());
    if ~isempty(shallowObj) && isprop(shallowObj,'runProfiles')
        rp = shallowObj.runProfiles;
        if isfield(rp,'dataloading') && isfield(rp.dataloading,'roiPattern')
            s = rp.dataloading.roiPattern;
            if isstruct(s)
                p = mergeStructOverride(p, s);
            end
        end
    end
    if isfield(ctx,'roiPattern') && isstruct(ctx.roiPattern) && ~isempty(ctx.roiPattern)
        p = mergeStructOverride(p, ctx.roiPattern);
    elseif isfield(ctx,'params') && isstruct(ctx.params) && ~isempty(ctx.params)
        p = mergeStructOverride(p, ctx.params);
    end

    p = sanitizeParamsForStorage(p);

    if ~isfield(p,'fallbackFullFrame')
        p.fallbackFullFrame = true;
    end
    if ~isfield(p,'keepExisting')
        p.keepExisting = false;
    end
    if ~isfield(p,'skipExisting')
        p.skipExisting = false;
    end
    if ~isfield(p,'errorOnExisting')
        p.errorOnExisting = false;
    end
    p = applyExistingPolicyToPatternParams(p, ctx);

    hasRuntimeFovSelection = isfield(ctx,'sel') && isstruct(ctx.sel) && isfield(ctx.sel,'fovs');
    if hasRuntimeFovSelection
        if isempty(ctx.sel.fovs)
            fovIdx = 1:numel(fovList);
        else
            fovIdx = normalizeFovSelection(ctx.sel.fovs, numel(fovList));
        end
    elseif isfield(ctx,'fovIndex') && ~isempty(ctx.fovIndex)
        fovIdx = ctx.fovIndex(:)';
    else
        fovIdx = 1:numel(fovList);
    end
    fovIdx = normalizeFovSelection(fovIdx, numel(fovList));
    if isempty(fovIdx)
        return;
    end

    resume = true;
    if isfield(ctx,'resume')
        resume = logical(ctx.resume);
    end
    saveProgress = true;
    if isfield(ctx,'saveProgress')
        saveProgress = logical(ctx.saveProgress);
    end

    testOnly = false;
    if isfield(ctx,'testOnly')
        testOnly = logical(ctx.testOnly);
    end

    patternList = normalizePatternList(ctx, p, shallowObj, fovList);

    if testOnly
        detecdiv_check_cancel(ctx, 'roiPattern before test');
        detections = runPatternTest(fovList, fovIdx, ctx, p, patternList);
        ctx.fovList = fovList;
        ctx.roiList = collectROIs(fovList);
        ctx.patternList = patternList;
        ctx.patternDetection = detections;
        ctx.roiPattern = p;
        ctx.params = p;
        return;
    end

    prog = progressLoadLocal(shallowObj, ctx, 'roiPattern');
    if isempty(prog) || ~resume
        prog = progressInitLocal(shallowObj, ctx, 'roiPattern', fovIdx, p);
    end

    fovIdxToProcess = [];
    for i = fovIdx
        detecdiv_check_cancel(ctx, sprintf('roiPattern plan FOV %d', i));
        if shouldSkipExistingFov(fovList(i), p)
            continue;
        end
        if shouldErrorExistingFov(fovList(i), p)
            error('roiPattern.runCore:ExistingROI', ...
                'FOV %d already contains ROIs and existingPolicy=error.', i);
        end
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
        detecdiv_check_cancel(ctx, sprintf('roiPattern before FOV %d/%d', k, numel(fovIdxToProcess)));
        currentFov = fovList(i);
        pattern = selectPatternForFov(currentFov, i, ctx, p, patternList);

        if hasValidPattern(pattern)
            detecdiv_check_cancel(ctx, sprintf('roiPattern before patch FOV %d', i));
            [pattimg, chanIdx, refFrame, crop] = buildPatternPatch(fovList, currentFov, pattern, p, ctx);
            detecdiv_check_cancel(ctx, sprintf('roiPattern before identify FOV %d', i));
            identifyROIsLocal('FOV', currentFov, ...
                'Frames', refFrame, ...
                'Threshold', p.threshold, ...
                'Pattern', pattimg, ...
                'Crop', crop, ...
                'Channel', chanIdx, ...
                'Keep', p.keepExisting);
            detecdiv_check_cancel(ctx, sprintf('roiPattern after identify FOV %d', i));
        elseif p.fallbackFullFrame
            detecdiv_check_cancel(ctx, sprintf('roiPattern fallback FOV %d', i));
            applyFullFrameFallback(currentFov, p);
        else
            error('roiPattern.runCore:NoPattern', 'No pattern available for FOV %d.', i);
        end

        try
            n = numel(currentFov.roi);
            if n == 1 && isempty(currentFov.roi(1).id)
                n = 0;
            end
            if n > 0
                progressMarkLocal(shallowObj, ctx, 'roiPattern', i, 1:n);
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
    ctx.roiPattern = p;
    ctx.params = p;
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
        rp.dataloading.roiPattern = p;
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
            storePatternLocal(shallowObj, patternList(patIdx));
        end
    end
end

function p = applyExistingPolicyToPatternParams(p, ctx)
policy = resolveExistingPolicy(ctx, p, 'replace');
switch lower(policy)
    case 'skip'
        p.keepExisting = true;
        p.skipExisting = true;
        p.errorOnExisting = false;
    case {'upsert','append'}
        p.keepExisting = true;
        p.skipExisting = false;
        p.errorOnExisting = false;
    case 'error'
        p.keepExisting = true;
        p.skipExisting = false;
        p.errorOnExisting = true;
    otherwise
        p.keepExisting = false;
        p.skipExisting = false;
        p.errorOnExisting = false;
end
end

function policy = resolveExistingPolicy(ctx, p, fallback)
policy = '';
try
    if isfield(ctx,'executionPolicy') && isstruct(ctx.executionPolicy) && ...
            isfield(ctx.executionPolicy,'existingPolicy') && ~isempty(ctx.executionPolicy.existingPolicy)
        policy = char(string(ctx.executionPolicy.existingPolicy));
    elseif isfield(ctx,'io') && isstruct(ctx.io) && isfield(ctx.io,'effectiveExistingPolicy') && ~isempty(ctx.io.effectiveExistingPolicy)
        policy = char(string(ctx.io.effectiveExistingPolicy));
    elseif isfield(ctx,'io') && isstruct(ctx.io) && isfield(ctx.io,'existingPolicy') && ~isempty(ctx.io.existingPolicy)
        policy = char(string(ctx.io.existingPolicy));
    elseif isstruct(p) && isfield(p,'existingPolicy') && ~isempty(p.existingPolicy)
        policy = char(string(p.existingPolicy));
    end
catch
    policy = '';
end
if isempty(policy)
    policy = fallback;
end
policy = lower(strtrim(policy));
if strcmp(policy, 'update')
    policy = 'upsert';
elseif strcmp(policy, 'replace_existing')
    policy = 'replace';
end
if ~any(strcmp(policy, {'replace','skip','upsert','append','error'}))
    policy = fallback;
end
end

function tf = shouldSkipExistingFov(fovObj, p)
tf = false;
if ~isfield(p,'skipExisting') || ~logical(p.skipExisting)
    return;
end
tf = fovHasValidRois(fovObj);
end

function tf = shouldErrorExistingFov(fovObj, p)
tf = false;
if ~isfield(p,'errorOnExisting') || ~logical(p.errorOnExisting)
    return;
end
tf = fovHasValidRois(fovObj);
end

function tf = fovHasValidRois(fovObj)
tf = false;
try
    r = fovObj.roi;
    if isempty(r)
        return;
    end
    tf = ~(numel(r) == 1 && isempty(r(1).id));
catch
    tf = false;
end
end

function patternList = normalizePatternList(ctx, p, shallowObj, fovList)
patternList = struct([]);

if isfield(ctx,'pattern') && isstruct(ctx.pattern) && hasValidPattern(ctx.pattern)
    patternList = ctx.pattern;
    return;
end

if isfield(p,'pattern') && isstruct(p.pattern) && hasValidPattern(p.pattern)
    patternList = p.pattern;
    return;
end

if isfield(p,'patternList') && isstruct(p.patternList) && ~isempty(p.patternList)
    patternList = p.patternList;
    return;
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

function fovIdx = normalizeFovSelection(selection, nFov)
    if isempty(selection)
        fovIdx = [];
        return;
    end
    if isnumeric(selection) || islogical(selection)
        fovIdx = reshape(double(selection), 1, []);
    elseif iscell(selection)
        fovIdx = [];
        for i = 1:numel(selection)
            fovIdx = [fovIdx normalizeFovSelection(selection{i}, nFov)]; %#ok<AGROW>
        end
    elseif ischar(selection) || (isstring(selection) && isscalar(selection))
        nums = regexp(char(selection), '\d+', 'match');
        fovIdx = str2double(nums);
    else
        fovIdx = [];
    end
    fovIdx = unique(round(fovIdx(isfinite(fovIdx) & fovIdx >= 1 & fovIdx <= nFov)), 'stable');
end

function [pattimg, chanIdx, refFrame, crop] = buildPatternPatch(fovList, targetFov, pattern, p, ctx)
    refFrame = 1;
    if isfield(p,'referenceFrame') && ~isempty(p.referenceFrame)
        refFrame = round(double(p.referenceFrame(1)));
    end
    crop = [];
    if nargin < 5
        ctx = struct();
    end

    if isfield(pattern,'frame') && ~isempty(pattern.frame)
        refFrame = round(double(pattern.frame(1)));
    end

    refFov = fovList(1);
    if isfield(pattern,'fovIndex') && ~isempty(pattern.fovIndex)
        candIdx = round(double(pattern.fovIndex(1)));
        if candIdx >= 1 && candIdx <= numel(fovList)
            refFov = fovList(candIdx);
        end
    elseif isfield(pattern,'fovId') && ~isempty(pattern.fovId)
        for i = 1:numel(fovList)
            if isprop(fovList(i),'id') && strcmp(char(string(fovList(i).id)), char(string(pattern.fovId)))
                refFov = fovList(i);
                break;
            end
        end
    end

    % The detection channel belongs to the target/run context. The channel
    % recorded in pattern is source metadata and is only a fallback when the
    % run has no explicit channel binding.
    if (isfield(p,'channel') && ~isempty(p.channel)) || ...
            (isfield(p,'channelIndex') && ~isempty(p.channelIndex))
        chanIdx = resolveChannelIndex(targetFov, p);
    else
        chanIdx = resolveChannelIndex(targetFov, pattern);
    end
    chanIdx = max(1, round(double(chanIdx)));

    % If the embedded patch is unavailable, rebuild it from its original
    % source channel, independently from the target detection channel.
    sourceChanIdx = resolveChannelIndex(refFov, pattern);
    if isempty(sourceChanIdx) || ~isfinite(sourceChanIdx) || sourceChanIdx < 1
        sourceChanIdx = resolveChannelIndex(refFov, p);
    end
    sourceChanIdx = max(1, round(double(sourceChanIdx)));

    [pattimg, ok] = tryLoadEmbeddedPatternPatch(pattern);
    if ~ok
        [pattimg, ok] = tryLoadExportedPatternPatch(pattern, ctx);
    end
    if ~ok
        tmp = readImage(refFov, refFrame, sourceChanIdx);
        if isempty(tmp)
            error('roiPattern.runCore:PatternImageReadFailed', 'Cannot read pattern reference image.');
        end

        rect = double(pattern.rect(:)');
        if numel(rect) < 4
            error('roiPattern.runCore:InvalidPatternRect', 'Pattern rect must contain [x y w h].');
        end
        x = round(rect(1));
        y = round(rect(2));
        w = max(1, round(rect(3)));
        h = max(1, round(rect(4)));

        x1 = max(1, x);
        y1 = max(1, y);
        x2 = min(size(tmp,2), x1 + w - 1);
        y2 = min(size(tmp,1), y1 + h - 1);
        if x2 < x1
            x2 = x1;
        end
        if y2 < y1
            y2 = y1;
        end

        pattimg = tmp(y1:y2, x1:x2);
    end

    if isempty(crop)
        try
            if isprop(targetFov,'crop') && ~isempty(targetFov.crop)
                crop = normalizeCropForIdentify(targetFov.crop);
            end
        catch
        end
    end

end

function [pattimg, ok] = tryLoadEmbeddedPatternPatch(pattern)
pattimg = [];
ok = false;

keys = {'image', 'patternImage', 'pattimg', 'patch'};
for k = 1:numel(keys)
    key = keys{k};
    if isfield(pattern, key) && ~isempty(pattern.(key))
        pattimg = pattern.(key);
        ok = true;
        return;
    end
end
end

function [pattimg, ok] = tryLoadExportedPatternPatch(pattern, ctx)
pattimg = [];
ok = false;

if ~isfield(pattern, 'patchFile') || isempty(pattern.patchFile)
    return;
end

patchPath = resolvePatternPatchPath(pattern.patchFile, ctx);
if exist(patchPath, 'file') ~= 2
    return;
end

try
    [~, ~, ext] = fileparts(patchPath);
    switch lower(ext)
        case '.mat'
            S = load(patchPath);
            if isfield(S, 'patternImage')
                pattimg = S.patternImage;
            elseif isfield(S, 'pattimg')
                pattimg = S.pattimg;
            elseif isfield(S, 'patch')
                pattimg = S.patch;
            end
        otherwise
            pattimg = imread(patchPath);
    end
    ok = ~isempty(pattimg);
catch
    pattimg = [];
    ok = false;
end
end

function patchPath = resolvePatternPatchPath(patchPath, ctx)
patchPath = char(string(patchPath));
if isempty(patchPath) || isAbsolutePathLocal(patchPath)
    return;
end

base = '';
try
    if isfield(ctx,'pipelineRef') && isstruct(ctx.pipelineRef) && isfield(ctx.pipelineRef,'path') && ~isempty(ctx.pipelineRef.path)
        base = char(string(ctx.pipelineRef.path));
    elseif isfield(ctx,'templatePath') && ~isempty(ctx.templatePath)
        base = char(string(ctx.templatePath));
    end
catch
    base = '';
end

if isempty(base)
    return;
end
if exist(base, 'file') == 2
    base = fileparts(base);
end
if exist(base, 'dir') == 7
    patchPath = fullfile(base, patchPath);
end
end

function tf = isAbsolutePathLocal(p)
tf = false;
if isempty(p)
    return;
end
p = char(string(p));
if ispc
    tf = startsWith(p, '/') || ~isempty(regexp(p, '^[A-Za-z]:[\\/]', 'once')) || startsWith(p, '\\');
else
    tf = startsWith(p, '/');
end
end

function idx = resolveChannelIndex(fov, p)
    idx = 1;
    if isfield(p,'channel') && ~isempty(p.channel)
        q = char(string(p.channel));
        try
            pix = find(matches(fov.channel, q), 1);
            if isempty(pix)
                pix = find(strcmpi(cellstr(string(fov.channel)), q), 1);
            end
            if ~isempty(pix)
                idx = pix;
                return;
            end
        catch
        end
    end
    if isfield(p,'channelIndex') && ~isempty(p.channelIndex)
        try
            if ischar(p.channelIndex) || isstring(p.channelIndex)
                v = str2double(char(string(p.channelIndex)));
            else
                v = double(p.channelIndex(1));
            end
            if isfinite(v) && v >= 1
                idx = round(v);
                return;
            end
        catch
        end
    end
end

function cropOut = normalizeCropForIdentify(cropIn)
cropOut = [];
if nargin < 1 || isempty(cropIn)
    return;
end

arr = [];
try
    if ischar(cropIn) || isstring(cropIn)
        s = strtrim(char(string(cropIn)));
        if isempty(s) || strcmp(s, '[]')
            return;
        end
        arr = str2num(s); %#ok<ST2NM>
    else
        arr = double(cropIn);
    end
catch
    return;
end

if isempty(arr) || ~isnumeric(arr)
    return;
end

if isvector(arr) && numel(arr) >= 4
    x = double(arr(1));
    y = double(arr(2));
    w = double(arr(3));
    h = double(arr(4));
    if ~(isfinite(x) && isfinite(y) && isfinite(w) && isfinite(h) && w > 0 && h > 0)
        return;
    end
    x1 = x;
    y1 = y;
    x2 = x + w;
    y2 = y + h;
    cropOut = [x1 y1; x2 y1; x2 y2; x1 y2];
    return;
end

if size(arr,2) == 2 && size(arr,1) >= 3
    cropOut = arr;
end
end

function out = runPatternTest(fovList, fovIdx, ctx, p, patternList)
out = struct([]);
for kk = 1:numel(fovIdx)
    detecdiv_check_cancel(ctx, sprintf('roiPattern test FOV %d/%d', kk, numel(fovIdx)));
    i = fovIdx(kk);
    currentFov = fovList(i);
    pattern = selectPatternForFov(currentFov, i, ctx, p, patternList);
    if ~hasValidPattern(pattern)
        continue;
    end

    [pattimg, chanIdx, refFrame, crop] = buildPatternPatch(fovList, currentFov, pattern, p, ctx);
    disp(sprintf('[roiPattern][test] targetFOV=%d refFrame=%d channel=%d patternSize=[%d %d]', i, refFrame, chanIdx, size(pattimg,1), size(pattimg,2)));

    args = {'FOV', currentFov, ...
        'Frames', refFrame, ...
        'Threshold', p.threshold, ...
        'Pattern', pattimg, ...
        'Channel', chanIdx, ...
        'Test'};
    if ~isempty(crop)
        disp(sprintf('[roiPattern][test] applying crop for FOV %d', i));
        args = [args {'Crop'} {crop}];
    else
        disp(sprintf('[roiPattern][test] no crop for FOV %d', i));
    end

    detecdiv_check_cancel(ctx, sprintf('roiPattern before test identify FOV %d', i));
    thisOut = identifyROIsLocal(args{:});
    detecdiv_check_cancel(ctx, sprintf('roiPattern after test identify FOV %d', i));
    if isempty(thisOut)
        continue;
    end

    for jj = 1:numel(thisOut)
        try
            thisOut(jj).fovid = kk;
        catch
        end
    end

    out = [out thisOut(:)']; %#ok<AGROW>
end
end

function p = sanitizeParamsForStorage(p)
if ~isstruct(p)
    p = struct();
    return;
end

legacyFields = {'shallow','fovList','roiList','project','Project','ctx'};
for k = 1:numel(legacyFields)
    if isfield(p, legacyFields{k})
        p = rmfield(p, legacyFields{k});
    end
end

fn = fieldnames(p);
for i = 1:numel(fn)
    key = fn{i};
    try
        val = p.(key);
        if isobject(val)
            p = rmfield(p, key);
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
        if isempty(override.(fn{i}))
            continue;
        end
        out.(fn{i}) = override.(fn{i});
    end
end

