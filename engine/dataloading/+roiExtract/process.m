function ctx = process(ctx)
% roiExtract.process  Extract ROI crops with per-ROI progress tracking.

    if nargin < 1 || isempty(ctx)
        ctx = struct();
    end

    ctx.errors = {};
    checkRoiExtractCancellation(ctx, 'start');

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
        error('roiExtract:NoFOV','No shallow or fovList provided.');
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

    hasRuntimeFovSelection = isfield(ctx,'sel') && isstruct(ctx.sel) && isfield(ctx.sel,'fovs');
    runtimeFovSelection = [];
    if hasRuntimeFovSelection && ~isempty(ctx.sel.fovs)
        runtimeFovSelection = ctx.sel.fovs;
    end
    hasRuntimeRoiSelection = isfield(ctx,'sel') && isstruct(ctx.sel) && isfield(ctx.sel,'rois');
    runtimeRoiSelection = [];
    if hasRuntimeRoiSelection && ~isempty(ctx.sel.rois)
        runtimeRoiSelection = ctx.sel.rois;
    end

    % fov selection. Runtime run selections must win over saved dataloading
    % profiles so a stale template cannot silently narrow a submitted run.
    if hasRuntimeFovSelection
        if isempty(runtimeFovSelection)
            fovIdx = 1:numel(fovList);
        else
            fovIdx = normalizeRoiSelectionParam(runtimeFovSelection);
        end
    elseif isfield(ctx,'fovIndex') && ~isempty(ctx.fovIndex)
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
    if isfield(p,'extractChannels') && ~isempty(p.extractChannels)
        p.channels = normalizeExtractChannelsParam(p.extractChannels);
    end
    if hasRuntimeRoiSelection
        p.roiList = runtimeRoiSelection;
    end
    if isfield(p,'roiList') && ~isempty(p.roiList)
        p.roiList = normalizeRoiSelectionParam(p.roiList);
    end
    p = normalizeScaleBinningParams(p);
    validateManualRoiContextForExtraction(shallowObj, fovIdx, ctx, p);

    existingPolicy = resolveExistingPolicy(ctx, p);
    switch existingPolicy
        case {'append','upsert'}
            p.extend = true;
        case 'replace'
            p.extend = false;
    end

    resume = true;
    if isfield(ctx,'resume'), resume = logical(ctx.resume); end
    if strcmp(existingPolicy, 'replace')
        resume = false;
    end
    saveProgress = true;
    if isfield(ctx,'saveProgress'), saveProgress = logical(ctx.saveProgress); end
    persistOutputs = true;
    try
        if isfield(ctx,'io') && isstruct(ctx.io) && isfield(ctx.io,'persistOutputs') && ~isempty(ctx.io.persistOutputs)
            persistOutputs = logical(ctx.io.persistOutputs);
        end
    catch
        persistOutputs = true;
    end

    prog = progressLoad(shallowObj, ctx, 'roiExtract');
    if isempty(prog) || ~resume
        prog = progressInit(shallowObj, ctx, 'roiExtract', fovIdx, p);
    end

    progressDlg = [];
    if isfield(ctx,'progressDlg') && ~isempty(ctx.progressDlg)
        progressDlg = ctx.progressDlg;
    end

    % loop per fov for ROI-granularity
    for fovPos = 1:numel(fovIdx)
        i = fovIdx(fovPos);
        checkRoiExtractCancellation(ctx, sprintf('before FOV %d', i));
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

        if isfield(p,'roiList') && ~isempty(p.roiList)
            todo = intersect(todo, p.roiList, 'stable');
        end

        [todo, existingTodo] = filterTodoByExistingPolicy(f.roi, todo, existingPolicy);
        if strcmp(existingPolicy, 'error') && ~isempty(existingTodo)
            error('roiExtract:ExistingOutputs', ...
                'ROI extraction outputs already exist for FOV %d, ROI(s) %s.', ...
                i, mat2str(existingTodo));
        end

        if isempty(todo)
            continue;
        end

        preflightRoiExtractionForFov(shallowObj, fovList, i, todo, p, persistOutputs);

        if ~isempty(progressDlg)
            try
                if isprop(progressDlg,'CancelRequested') && progressDlg.CancelRequested
                    ctx.canceled = true;
                    break;
                end
            catch
            end
        end

        args = buildExtractArgs(p, progressDlg, ctx);
        args = [args {'FOVIndex'} {i} {'ROISelect'} {todo}];
        args = [args {'ProgressFOVIndex'} {fovPos} {'ProgressFOVTotal'} {numel(fovIdx)}];
        if ~persistOutputs
            args = [args {'MemoryOnly'} {true}]; %#ok<AGROW>
        end

        try
            if ~isempty(shallowObj)
                extractAllROICrops(shallowObj, args{:});
                checkRoiExtractCancellation(ctx, sprintf('after FOV %d extraction', i));
                try
                    fovList = shallowObj.fov;
                catch
                end
            else
                % fallback: call on a temporary shallow
                tmp = shallow();
                tmp.fov = f;
                extractAllROICrops(tmp, args{:});
                checkRoiExtractCancellation(ctx, sprintf('after FOV %d extraction', i));
                try
                    fovList(i) = tmp.fov(1);
                catch
                end
            end
            validateExtractedRoisForFov(fovList, i, todo, persistOutputs, p, shallowObj);
            prog = progressMark(shallowObj, ctx, 'roiExtract', i, todo);
            if persistOutputs && saveProgress && ~isempty(shallowObj)
                try, shallowSave(shallowObj); catch, end
            end
        catch ME
            errText = formatExceptionForProgress(ME);
            prog = ensureProgressErrorsField(prog);
            prog.errors{end+1} = errText; %#ok<AGROW>
            ctx.errors{end+1} = errText; %#ok<AGROW>
            if ~isempty(shallowObj)
                try
                    rp = shallowObj.runProfiles;
                    if ~isfield(rp, 'dataloading') || ~isstruct(rp.dataloading)
                        rp.dataloading = struct();
                    end
                    if ~isfield(rp.dataloading, 'runs') || ~isstruct(rp.dataloading.runs)
                        rp.dataloading.runs = struct();
                    end
                    rp.dataloading.runs.(getRunId(ctx)) = prog;
                    shallowObj.runProfiles = rp;
                catch
                end
            end
            rethrow(ME);
        end
    end

    if ~isempty(shallowObj)
        try
            fovList = shallowObj.fov;
        catch
        end
    end
    ctx.fovList = fovList;
    ctx.roiList = collectROIs(fovList, fovIdx, getfieldlocal(p, 'roiList', []), persistOutputs);
    ctx = maybeWarmRoiCache(ctx, p);
    ctx.dataSeries = collectDataSeries(ctx.roiList);
    if ~isfield(ctx,'channels') || isempty(ctx.channels) || isAllChannelSelector(getfieldlocal(p, 'channels', []))
        if ~isempty(fovList)
            ctx.channels = inferFovChannels(fovList);
        elseif isfield(p,'channels') && ~isempty(p.channels) && ~isAllChannelSelector(p.channels)
            ctx.channels = p.channels;
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

function checkRoiExtractCancellation(ctx, where)
    tokenFile = '';
    try
        if isfield(ctx,'cancel') && isstruct(ctx.cancel) ...
                && isfield(ctx.cancel,'tokenFile') && ~isempty(ctx.cancel.tokenFile)
            tokenFile = char(string(ctx.cancel.tokenFile));
        end
    catch
        tokenFile = '';
    end

    if ~isempty(tokenFile) && exist(tokenFile, 'file') == 2
        error('runPipeline:Cancelled', 'ROI extraction cancelled by user at %s.', char(string(where)));
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

function policy = resolveExistingPolicy(ctx, p)
    policy = '';
    try
        if nargin >= 2 && isstruct(p) && isfield(p,'existingPolicy') && ~isempty(p.existingPolicy)
            policy = char(string(p.existingPolicy));
        elseif isfield(ctx,'executionPolicy') && isstruct(ctx.executionPolicy) && ...
                isfield(ctx.executionPolicy,'existingPolicy') && ~isempty(ctx.executionPolicy.existingPolicy)
            policy = char(string(ctx.executionPolicy.existingPolicy));
        elseif isfield(ctx,'io') && isstruct(ctx.io) && isfield(ctx.io,'effectiveExistingPolicy') && ...
                ~isempty(ctx.io.effectiveExistingPolicy)
            policy = char(string(ctx.io.effectiveExistingPolicy));
        elseif isfield(ctx,'io') && isstruct(ctx.io) && isfield(ctx.io,'existingPolicy') && ...
                ~isempty(ctx.io.existingPolicy)
            policy = char(string(ctx.io.existingPolicy));
        end
    catch
        policy = '';
    end

    policy = lower(strtrim(policy));
    switch policy
        case {'replace','append','skip','error','upsert'}
        otherwise
            policy = 'replace';
    end
end

function validateManualRoiContextForExtraction(shallowObj, fovIdx, ctx, p)
    if isempty(shallowObj) || ~isstruct(ctx)
        return;
    end

    records = manualRoiRecordsFromContext(ctx);
    if isempty(records)
        return;
    end

    for fovNumber = fovIdx(:)'
        expected = records([records.fovIndex] == double(fovNumber));
        if isempty(expected) || fovNumber < 1 || fovNumber > numel(shallowObj.fov)
            continue;
        end

        rois = shallowObj.fov(fovNumber).roi;
        if isempty(rois)
            error('roiExtract:ManualRoiMismatch', ...
                'Manual ROI specification expects %d ROI(s) for FOV %d, but the project currently has none.', ...
                numel(expected), fovNumber);
        end

        selectedRois = 1:numel(rois);
        if isstruct(p) && isfield(p, 'roiList') && ~isempty(p.roiList)
            selectedRois = intersect(selectedRois, p.roiList, 'stable');
        end
        if isempty(selectedRois)
            continue;
        end

        expectedRects = reshape([expected.rect], 4, []).';
        for k = selectedRois(:)'
            actualRect = roiRectForValidation(rois(k));
            if isempty(actualRect) || ~anyRectMatches(expectedRects, actualRect)
                error('roiExtract:ManualRoiMismatch', ...
                    ['Selected ROI %d in FOV %d has rectangle %s, which does not match the manual ROI specification %s. ' ...
                     'Run the manual ROI node with output policy replace before extraction.'], ...
                    k, fovNumber, formatRectForValidation(actualRect), formatRectsForValidation(expectedRects));
            end
        end

        if ~isstruct(p) || ~isfield(p, 'roiList') || isempty(p.roiList)
            for k = 1:size(expectedRects, 1)
                if ~anySelectedRoiMatches(rois, selectedRois, expectedRects(k, :))
                    error('roiExtract:ManualRoiMismatch', ...
                        ['Manual ROI specification for FOV %d includes rectangle %s, ' ...
                         'but selected project ROIs are %s. Run the manual ROI node with output policy replace before extraction.'], ...
                        fovNumber, mat2str(expectedRects(k, :)), summarizeSelectedRoiRects(rois, selectedRois));
                end
            end
        end
    end
end

function records = manualRoiRecordsFromContext(ctx)
    records = struct('fovIndex', {}, 'rect', {});
    if isfield(ctx, 'roiManual') && isstruct(ctx.roiManual) && ...
            isfield(ctx.roiManual, 'manualRois') && ~isempty(ctx.roiManual.manualRois)
        records = appendManualRoiRecords(records, ctx.roiManual.manualRois);
    end
    try
        if isfield(ctx, 'run') && isstruct(ctx.run) && isfield(ctx.run, 'nodeParams') && isstruct(ctx.run.nodeParams)
            keys = fieldnames(ctx.run.nodeParams);
            for i = 1:numel(keys)
                params = ctx.run.nodeParams.(keys{i});
                if isstruct(params) && isfield(params, 'manualRois') && ~isempty(params.manualRois)
                    records = appendManualRoiRecords(records, params.manualRois);
                end
            end
        end
    catch
    end
end

function records = appendManualRoiRecords(records, manualRois)
    for i = 1:numel(manualRois)
        rec = manualRois(i);
        if ~isstruct(rec) || ~isfield(rec, 'fovIndex') || isempty(rec.fovIndex)
            continue;
        end
        rect = [];
        if isfield(rec, 'rect') && ~isempty(rec.rect)
            rect = rec.rect;
        elseif isfield(rec, 'position') && ~isempty(rec.position)
            rect = rec.position;
        end
        if ~isnumeric(rect) || numel(rect) < 4
            continue;
        end
        records(end+1).fovIndex = double(rec.fovIndex); %#ok<AGROW>
        records(end).rect = double(rect(1:4));
    end
end

function rect = roiRectForValidation(r)
    rect = [];
    try
        if isprop(r, 'value') && ~isempty(r.value) && isnumeric(r.value) && numel(r.value) >= 4
            rect = double(r.value(1:4));
        end
    catch
        rect = [];
    end
end

function tf = anyRectMatches(expectedRects, actualRect)
    tf = false;
    if isempty(expectedRects) || isempty(actualRect)
        return;
    end
    actualRect = double(actualRect(1:4));
    for i = 1:size(expectedRects, 1)
        if all(abs(double(expectedRects(i, 1:4)) - actualRect) <= 1)
            tf = true;
            return;
        end
    end
end

function tf = anySelectedRoiMatches(rois, selectedRois, expectedRect)
    tf = false;
    for i = selectedRois(:)'
        if anyRectMatches(expectedRect, roiRectForValidation(rois(i)))
            tf = true;
            return;
        end
    end
end

function txt = summarizeSelectedRoiRects(rois, selectedRois)
    parts = cell(1, numel(selectedRois));
    for i = 1:numel(selectedRois)
        parts{i} = sprintf('ROI %d: %s', selectedRois(i), formatRectForValidation(roiRectForValidation(rois(selectedRois(i)))));
    end
    txt = strjoin(parts, '; ');
    if strlength(string(txt)) > 300
        txt = [char(extractBefore(string(txt), 298)) '...'];
    end
end

function txt = formatRectsForValidation(rects)
    parts = cell(1, size(rects, 1));
    for i = 1:size(rects, 1)
        parts{i} = mat2str(rects(i, :));
    end
    txt = strjoin(parts, '; ');
end

function txt = formatRectForValidation(rect)
    if isempty(rect)
        txt = '[]';
    else
        txt = mat2str(double(rect(1:4)));
    end
end

function [todo, existingTodo] = filterTodoByExistingPolicy(roiList, todo, existingPolicy)
    existingTodo = [];
    if isempty(todo) || ~any(strcmp(existingPolicy, {'skip','error'}))
        return;
    end

    keepMask = true(size(todo));
    for k = 1:numel(todo)
        idx = todo(k);
        if idx < 1 || idx > numel(roiList)
            continue;
        end
        if roiExtractOutputExists(roiList(idx))
            existingTodo(end+1) = idx; %#ok<AGROW>
            keepMask(k) = false;
        end
    end

    if strcmp(existingPolicy, 'skip')
        todo = todo(keepMask);
    end
end

function tf = roiExtractOutputExists(r)
    tf = false;
    try
        [~, tf] = r.getH5Filename();
        if tf
            return;
        end
    catch
    end

    try
        if isprop(r,'path') && ~isempty(r.path) && isprop(r,'id') && ~isempty(r.id)
            candidates = roiExtractOutputPathCandidates(char(string(r.path)), char(string(r.id)));
            for i = 1:numel(candidates)
                tf = isfile(candidates{i});
                if tf
                    return;
                end
            end
        end
    catch
    end

    try
        if isprop(r,'extraction') && isstruct(r.extraction) && isfield(r.extraction,'status') && ...
                strcmpi(char(string(r.extraction.status)), 'done')
            tf = true;
        end
    catch
    end
end

function candidates = roiExtractOutputPathCandidates(roiPath, roiId)
    candidates = {};
    if isempty(roiPath) || isempty(roiId)
        return;
    end
    fileName = ['im_' roiId '.h5'];
    candidates{end+1} = fullfile(roiPath, fileName); %#ok<AGROW>
    localPath = translateHubRemotePathToLocal(roiPath);
    if ~isempty(localPath) && ~strcmp(localPath, roiPath)
        candidates{end+1} = fullfile(localPath, fileName); %#ok<AGROW>
    end
    candidates = unique(candidates, 'stable');
end

function localPath = translateHubRemotePathToLocal(remotePath)
    localPath = '';
    remotePath = char(string(remotePath));
    if isempty(strtrim(remotePath))
        return;
    end
    try
        hub = detecdiv_hub_settings_get();
    catch
        hub = struct();
    end
    mappings = struct('remoteRoot', {}, 'localRoot', {});
    try
        if isfield(hub, 'pathMappings') && ~isempty(hub.pathMappings)
            mappings = hub.pathMappings;
        end
    catch
    end
    try
        if isfield(hub, 'defaultRemoteProjectRoot') && isfield(hub, 'defaultLocalProjectRoot') && ...
                ~isempty(hub.defaultRemoteProjectRoot) && ~isempty(hub.defaultLocalProjectRoot)
            mappings(end+1).remoteRoot = char(string(hub.defaultRemoteProjectRoot)); %#ok<AGROW>
            mappings(end).localRoot = char(string(hub.defaultLocalProjectRoot));
        end
    catch
    end
    remoteComparable = regexprep(strrep(remotePath, '\', '/'), '[\/]+$', '');
    bestLen = 0;
    bestLocalRoot = '';
    bestSuffix = '';
    for i = 1:numel(mappings)
        try
            remoteRoot = regexprep(strrep(char(string(mappings(i).remoteRoot)), '\', '/'), '[\/]+$', '');
            localRoot = regexprep(strrep(char(string(mappings(i).localRoot)), '/', filesep), '[\\\/]+$', '');
            if isempty(remoteRoot) || isempty(localRoot)
                continue;
            end
            if startsWith(remoteComparable, remoteRoot) && ...
                    (numel(remoteComparable) == numel(remoteRoot) || any(remoteComparable(numel(remoteRoot)+1) == ['/' '\']))
                if numel(remoteRoot) > bestLen
                    bestLen = numel(remoteRoot);
                    bestLocalRoot = localRoot;
                    bestSuffix = remoteComparable(numel(remoteRoot)+1:end);
                end
            end
        catch
        end
    end
    if bestLen == 0
        return;
    end
    bestSuffix = regexprep(bestSuffix, '^[\/\\]+', '');
    if isempty(bestSuffix)
        localPath = bestLocalRoot;
    else
        localPath = fullfile(bestLocalRoot, strrep(bestSuffix, '/', filesep));
    end
end

% ---------------- helpers ----------------

function preflightRoiExtractionForFov(shallowObj, fovList, fovIdx, roiSel, p, requirePersistedOutput)
    if isempty(fovList) || fovIdx < 1 || fovIdx > numel(fovList) || isempty(roiSel)
        return;
    end

    issues = {};
    f = fovList(fovIdx);
    fovLabel = fovLabelLocal(f, fovIdx);
    rois = [];
    try
        rois = f.roi;
    catch
        rois = [];
    end

    if isempty(rois)
        issues{end+1} = sprintf('%s has no ROI to extract.', fovLabel); %#ok<AGROW>
    end

    [channelIdx, channelIssues] = resolvePreflightChannels(f, p);
    issues = [issues channelIssues]; %#ok<AGROW>

    sampleFrame = resolvePreflightFrame(f, p);
    sampleSize = [];
    if isempty(channelIdx)
        sampleChannel = 1;
    else
        sampleChannel = channelIdx(1);
    end
    try
        im = f.readImage(sampleFrame, sampleChannel);
        if isempty(im)
            issues{end+1} = sprintf('%s source image is empty for frame %d channel %d.', ...
                fovLabel, sampleFrame, sampleChannel); %#ok<AGROW>
        else
            sampleSize = size(im);
            if numel(sampleSize) >= 2
                sampleSize = sampleSize(1:2);
            else
                sampleSize = [];
            end
        end
    catch ME
        issues{end+1} = sprintf('%s cannot read source image before extraction (frame %d, channel %d): %s', ...
            fovLabel, sampleFrame, sampleChannel, messageOrIdentifier(ME)); %#ok<AGROW>
    end

    for k = 1:numel(roiSel)
        idx = roiSel(k);
        if idx < 1 || idx > numel(rois)
            issues{end+1} = sprintf('%s ROI index %d is outside available ROI range 1:%d.', ...
                fovLabel, idx, numel(rois)); %#ok<AGROW>
            continue;
        end
        r = rois(idx);
        rect = roiRectLocal(r);
        roiLabel = roiLabelLocal(r, idx);
        if isempty(rect)
            issues{end+1} = sprintf('%s %s has no valid rectangle [x y w h].', ...
                fovLabel, roiLabel); %#ok<AGROW>
            continue;
        end
        if rect(3) <= 0 || rect(4) <= 0
            issues{end+1} = sprintf('%s %s has non-positive size: %s.', ...
                fovLabel, roiLabel, mat2str(rect)); %#ok<AGROW>
        end
        if ~isempty(sampleSize) && rectHasNoImageOverlap(rect, sampleSize)
            issues{end+1} = sprintf('%s %s rectangle %s does not overlap source image size [%d %d].', ...
                fovLabel, roiLabel, mat2str(rect), sampleSize(1), sampleSize(2)); %#ok<AGROW>
        end
    end

    if requirePersistedOutput
        outDir = expectedFovOutputDirLocal(shallowObj, f, fovIdx);
        [ok, msg] = ensureWritableDirectoryLocal(outDir);
        if ~ok
            issues{end+1} = sprintf('%s output directory is not writable: %s (%s).', ...
                fovLabel, outDir, msg); %#ok<AGROW>
        end
    end

    if ~isempty(issues)
        error('roiExtract:InvalidExtractionInputs', ...
            'ROI extraction preflight failed for %s before launching extraction:%s- %s', ...
            fovLabel, newline, strjoin(issues, [newline '- ']));
    end
end

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

function validateExtractedRoisForFov(fovList, fovIdx, roiSel, requirePersistedOutput, p, shallowObj)
    if nargin < 4 || isempty(requirePersistedOutput)
        requirePersistedOutput = true;
    end
    if nargin < 5
        p = struct();
    end
    if nargin < 6
        shallowObj = [];
    end
    if isempty(fovList) || fovIdx < 1 || fovIdx > numel(fovList) || isempty(roiSel)
        return;
    end
    missing = [];
    rois = fovList(fovIdx).roi;
    for k = 1:numel(roiSel)
        idx = roiSel(k);
        if idx < 1 || idx > numel(rois) || ~roiExtractionMaterialized(rois(idx), requirePersistedOutput)
            missing(end+1) = idx; %#ok<AGROW>
        end
    end
    if ~isempty(missing)
        details = missingExtractionDetails(fovList, fovIdx, rois, missing, requirePersistedOutput, p, shallowObj);
        if requirePersistedOutput
            error('roiExtract:MissingExtractedOutputs', ...
                'ROI extraction finished but did not materialize expected H5 outputs for FOV %d ROI(s) %s.%s%s', ...
                fovIdx, mat2str(missing), newline, details);
        else
            error('roiExtract:MissingExtractedOutputs', ...
                'ROI extraction finished but did not materialize in-memory outputs for FOV %d ROI(s) %s.%s%s', ...
                fovIdx, mat2str(missing), newline, details);
        end
    end
end

function tf = roiExtractionMaterialized(r, requirePersistedOutput)
    if requirePersistedOutput
        tf = roiExtractOutputExists(r);
        return;
    end

    tf = false;
    try
        tf = isprop(r, 'image') && ~isempty(r.image);
        if tf
            return;
        end
    catch
    end

    try
        tf = isprop(r,'extraction') && isstruct(r.extraction) && isfield(r.extraction,'status') && ...
            any(strcmpi(char(string(r.extraction.status)), {'extracted','memory'}));
    catch
        tf = false;
    end
end

function details = missingExtractionDetails(fovList, fovIdx, rois, missing, requirePersistedOutput, p, shallowObj)
    if nargin < 6
        p = struct();
    end
    if nargin < 7
        shallowObj = [];
    end

    lines = {};
    f = fovList(fovIdx);
    fovLabel = fovLabelLocal(f, fovIdx);
    outDir = expectedFovOutputDirLocal(shallowObj, f, fovIdx);
    [channelIdx, channelIssues] = resolvePreflightChannels(f, p);
    if isempty(channelIdx)
        channelText = '<none resolved>';
    else
        channelText = mat2str(channelIdx);
    end
    lines{end+1} = sprintf('FOV: %s', fovLabel); %#ok<AGROW>
    lines{end+1} = sprintf('Expected output directory: %s', outDir); %#ok<AGROW>
    lines{end+1} = sprintf('Resolved channel indices: %s', channelText); %#ok<AGROW>
    for i = 1:numel(channelIssues)
        lines{end+1} = sprintf('Channel issue: %s', channelIssues{i}); %#ok<AGROW>
    end

    for k = 1:numel(missing)
        idx = missing(k);
        if idx < 1 || idx > numel(rois)
            lines{end+1} = sprintf('ROI index %d is outside current ROI list.', idx); %#ok<AGROW>
            continue;
        end
        r = rois(idx);
        roiLabel = roiLabelLocal(r, idx);
        rect = roiRectLocal(r);
        roiPath = roiPathLocal(r);
        roiId = roiIdLocal(r, idx);
        if isempty(roiPath)
            roiPath = outDir;
        end
        candidates = roiExtractOutputPathCandidates(roiPath, roiId);
        if isempty(candidates)
            candidates = {fullfile(outDir, ['im_' roiId '.h5'])};
        end
        status = roiExtractionStatusLocal(r);
        if isempty(status)
            status = '<none>';
        end
        existsText = cell(1, numel(candidates));
        for c = 1:numel(candidates)
            existsText{c} = sprintf('%s exists=%d', candidates{c}, isfile(candidates{c}));
        end
        if requirePersistedOutput
            lines{end+1} = sprintf('%s missing persisted H5. rect=%s status=%s path=%s expected={%s}', ...
                roiLabel, mat2str(rect), status, roiPath, strjoin(existsText, '; ')); %#ok<AGROW>
        else
            hasImage = false;
            try
                hasImage = isprop(r, 'image') && ~isempty(r.image);
            catch
            end
            lines{end+1} = sprintf('%s missing in-memory image. rect=%s status=%s hasImage=%d', ...
                roiLabel, mat2str(rect), status, hasImage); %#ok<AGROW>
        end
    end

    details = strjoin(lines, newline);
end

function msg = formatExceptionForProgress(ME)
    msg = messageOrIdentifier(ME);
    try
        if ~isempty(ME.stack)
            top = ME.stack(1);
            msg = sprintf('%s @ %s:%d', msg, top.name, top.line);
        end
    catch
    end
end

function msg = messageOrIdentifier(ME)
    msg = '';
    try
        msg = char(string(ME.message));
    catch
        msg = '';
    end
    try
        id = char(string(ME.identifier));
    catch
        id = '';
    end
    if isempty(strtrim(msg))
        msg = id;
    elseif ~isempty(id) && ~contains(msg, id)
        msg = sprintf('%s [%s]', msg, id);
    end
    if isempty(strtrim(msg))
        msg = '<unknown error>';
    end
end

function [idx, issues] = resolvePreflightChannels(f, p)
    issues = {};
    names = inferFovChannels(f);
    nChannels = numel(names);
    if nChannels == 0
        nChannels = 1;
        names = {'channel_001'};
        issues{end+1} = 'FOV has no channel inventory; assuming channel index 1 for the source read check.'; %#ok<AGROW>
    end

    spec = [];
    if isstruct(p) && isfield(p, 'channels') && ~isempty(p.channels)
        spec = p.channels;
    end
    if isempty(spec) || isAllChannelSelector(spec)
        idx = 1:nChannels;
        return;
    end

    if isnumeric(spec) || islogical(spec)
        if islogical(spec)
            idx = find(spec);
        else
            idx = double(spec(:)');
        end
        bad = idx(~isfinite(idx) | idx < 1 | idx > nChannels);
        idx = idx(isfinite(idx) & idx >= 1 & idx <= nChannels);
        if ~isempty(bad)
            issues{end+1} = sprintf('Requested channel index outside 1:%d: %s.', nChannels, mat2str(bad)); %#ok<AGROW>
        end
        idx = unique(round(idx), 'stable');
        return;
    end

    requested = normalizeChannelListLocal(spec);
    if isempty(requested)
        idx = 1:nChannels;
        return;
    end
    [hit, loc] = ismember(requested, names);
    if any(~hit)
        issues{end+1} = sprintf('Requested channel(s) not found: %s. Available: %s.', ...
            strjoin(requested(~hit), ', '), strjoin(names, ', ')); %#ok<AGROW>
    end
    idx = loc(hit);
    idx = unique(idx(:)', 'stable');
end

function frame = resolvePreflightFrame(f, p)
    frame = 1;
    spec = [];
    if isstruct(p) && isfield(p, 'frames') && ~isempty(p.frames)
        spec = p.frames;
    end
    if isempty(spec)
        return;
    end
    if ischar(spec) || (isstring(spec) && isscalar(spec))
        txt = strtrim(char(string(spec)));
        if isempty(txt) || any(strcmpi(txt, {'all', '*', ':'}))
            return;
        end
        try
            spec = str2num(txt); %#ok<ST2NM>
        catch
            spec = [];
        end
    end
    if iscell(spec)
        try
            spec = [spec{:}];
        catch
            spec = [];
        end
    end
    if islogical(spec)
        spec = find(spec);
    end
    try
        vals = double(spec(:)');
        vals = vals(isfinite(vals) & vals >= 1);
        if ~isempty(vals)
            frame = round(vals(1));
        end
    catch
        frame = 1;
    end
    try
        if isprop(f, 'frames') && ~isempty(f.frames)
            maxFrame = max(double(f.frames(:)));
            frame = min(max(1, frame), maxFrame);
        end
    catch
    end
end

function label = fovLabelLocal(f, idx)
    id = '';
    try
        if isprop(f, 'id') && ~isempty(f.id)
            id = char(string(f.id));
        end
    catch
        id = '';
    end
    if isempty(id)
        label = sprintf('FOV %d', idx);
    else
        label = sprintf('FOV %d (%s)', idx, id);
    end
end

function label = roiLabelLocal(r, idx)
    id = roiIdLocal(r, idx);
    label = sprintf('ROI %d (%s)', idx, id);
end

function id = roiIdLocal(r, idx)
    id = '';
    try
        if isprop(r, 'id') && ~isempty(r.id)
            id = char(string(r.id));
        end
    catch
        id = '';
    end
    if isempty(id)
        id = sprintf('ROI_%d', idx);
    end
end

function rect = roiRectLocal(r)
    rect = [];
    try
        if isprop(r, 'value') && ~isempty(r.value)
            v = double(r.value);
            if isvector(v) && numel(v) >= 4
                rect = reshape(v(1:4), 1, 4);
            elseif size(v, 2) >= 4
                rect = v(1, 1:4);
            elseif size(v, 1) >= 4 && size(v, 2) == 1
                rect = reshape(v(1:4), 1, 4);
            end
        end
    catch
        rect = [];
    end
    if ~isempty(rect)
        rect = round(rect);
        if numel(rect) ~= 4 || any(~isfinite(rect))
            rect = [];
        end
    end
end

function tf = rectHasNoImageOverlap(rect, imageSize)
    tf = false;
    if isempty(rect) || numel(imageSize) < 2
        return;
    end
    h = imageSize(1);
    w = imageSize(2);
    x1 = rect(1);
    y1 = rect(2);
    x2 = rect(1) + rect(3) - 1;
    y2 = rect(2) + rect(4) - 1;
    tf = x2 < 1 || y2 < 1 || x1 > w || y1 > h;
end

function path = roiPathLocal(r)
    path = '';
    try
        if isprop(r, 'path') && ~isempty(r.path)
            path = char(string(r.path));
        end
    catch
        path = '';
    end
end

function status = roiExtractionStatusLocal(r)
    status = '';
    try
        if isprop(r, 'extraction') && isstruct(r.extraction) && ...
                isfield(r.extraction, 'status') && ~isempty(r.extraction.status)
            status = char(string(r.extraction.status));
        end
    catch
        status = '';
    end
end

function outDir = expectedFovOutputDirLocal(shallowObj, f, fovIdx)
    root = '';
    try
        if ~isempty(shallowObj) && isprop(shallowObj, 'io') && isstruct(shallowObj.io)
            if isfield(shallowObj.io, 'path') && ~isempty(shallowObj.io.path) && ...
                    isfield(shallowObj.io, 'file') && ~isempty(shallowObj.io.file)
                root = fullfile(char(string(shallowObj.io.path)), char(string(shallowObj.io.file)));
            end
        end
    catch
        root = '';
    end
    if isempty(root)
        try
            if ~isempty(shallowObj) && ismethod(shallowObj, 'getPath')
                [pth, name] = shallowObj.getPath;
                if ~isempty(pth) && ~isempty(name)
                    root = fullfile(pth, name);
                elseif ~isempty(pth)
                    root = pth;
                end
            end
        catch
            root = '';
        end
    end
    if isempty(root)
        try
            r = f.roi;
            if ~isempty(r) && isprop(r(1), 'path') && ~isempty(r(1).path)
                root = fileparts(char(string(r(1).path)));
            end
        catch
            root = '';
        end
    end
    if isempty(root)
        root = pwd;
    end

    fovId = sprintf('FOV_%d', fovIdx);
    try
        if isprop(f, 'id') && ~isempty(f.id)
            fovId = char(string(f.id));
        end
    catch
    end
    outDir = fullfile(root, fovId);
end

function [ok, msg] = ensureWritableDirectoryLocal(outDir)
    ok = false;
    msg = '';
    try
        if isempty(outDir)
            msg = 'empty path';
            return;
        end
        if ~exist(outDir, 'dir')
            mkdir(outDir);
        end
        token = fullfile(outDir, ['.detecdiv_write_test_' char(java.util.UUID.randomUUID)]);
        fid = fopen(token, 'w');
        if fid < 0
            msg = 'fopen returned an invalid file id';
            return;
        end
        fprintf(fid, 'ok');
        fclose(fid);
        delete(token);
        ok = true;
    catch ME
        msg = messageOrIdentifier(ME);
        try
            if exist('fid', 'var') && fid > 0
                fclose(fid);
            end
        catch
        end
    end
end

function roiList = collectROIs(fovList, fovIdx, roiSel, requireExtracted)
    if nargin < 2 || isempty(fovIdx)
        fovIdx = 1:numel(fovList);
    end
    if nargin < 3
        roiSel = [];
    end
    if nargin < 4
        requireExtracted = false;
    end
    roiSel = normalizeRoiSelectionParam(roiSel);

    roiList = [];
    for i = fovIdx
        if i < 1 || i > numel(fovList)
            continue;
        end
        r = fovList(i).roi;
        if ~isempty(r)
            if ~isempty(roiSel)
                idx = roiSel(roiSel >= 1 & roiSel <= numel(r));
                r = r(idx);
            end
            if requireExtracted && ~isempty(r)
                keep = false(1, numel(r));
                for k = 1:numel(r)
                    keep(k) = roiExtractOutputExists(r(k));
                end
                r = r(keep);
            end
            roiList = [roiList r(:)']; %#ok<AGROW>
        end
    end
end

function idx = normalizeRoiSelectionParam(v)
    idx = [];
    if nargin < 1 || isempty(v)
        return;
    end
    if ischar(v) || (isstring(v) && isscalar(v))
        s = strtrim(char(string(v)));
        if isempty(s) || strcmpi(s, 'all') || strcmp(s, ':')
            return;
        end
        try
            v = str2num(s); %#ok<ST2NM>
        catch
            v = [];
        end
    end
    if iscell(v)
        try
            v = [v{:}];
        catch
            v = [];
        end
    end
    try
        idx = round(double(v(:)'));
        idx = idx(isfinite(idx) & idx >= 1);
        idx = unique(idx, 'stable');
    catch
        idx = [];
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

function p = normalizeScaleBinningParams(p)
    if ~isfield(p, 'binning') || isempty(p.binning)
        return;
    end
    try
        b = double(p.binning(1));
    catch
        b = [];
    end
    if isempty(b) || ~isfinite(b) || b <= 0
        currentScale = 1;
        if isfield(p, 'scale') && ~isempty(p.scale)
            currentScale = p.scale;
        end
        warning('roiExtract:InvalidBinning', ...
            'Invalid binning=%s -> keeping scale=%s', mat2str(p.binning), mat2str(currentScale));
        return;
    end
    p.scale = 1 ./ b;
end

function args = buildExtractArgs(p, progressDlg, ctx)
    args = {};
    if isfield(p,'frames') && ~isempty(p.frames)
        args = [args {'Frames'} {p.frames}];
    end
    if isfield(p,'channels') && ~isempty(p.channels) && ~isAllChannelSelector(p.channels)
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
    tokenFile = '';
    try
        if nargin >= 3 && isfield(ctx,'cancel') && isstruct(ctx.cancel) ...
                && isfield(ctx.cancel,'tokenFile') && ~isempty(ctx.cancel.tokenFile)
            tokenFile = char(string(ctx.cancel.tokenFile));
        end
    catch
        tokenFile = '';
    end
    if ~isempty(tokenFile)
        args = [args {'CancelTokenFile'} {tokenFile}];
    end
end

function prog = ensureProgressErrorsField(prog)
    if isempty(prog) || ~isstruct(prog)
        prog = struct();
    end
    if ~isfield(prog, 'errors') || isempty(prog.errors)
        prog.errors = {};
    elseif ~iscell(prog.errors)
        prog.errors = {prog.errors};
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

function tf = isAllChannelSelector(spec)
    tf = false;
    if isempty(spec)
        return;
    end

    if ischar(spec) || (isstring(spec) && isscalar(spec))
        token = lower(strtrim(char(string(spec))));
        tf = any(strcmp(token, {'all', '*', ':', '<all>', '<source output>'})) || ...
            startsWith(token, '@') || startsWith(token, '<source output');
        return;
    end

    if isstring(spec)
        vals = cellstr(spec(:));
        vals = vals(~cellfun(@(x) isempty(strtrim(x)), vals));
        if numel(vals) == 1
            tf = isAllChannelSelector(vals{1});
        end
        return;
    end

    if iscell(spec)
        vals = spec(~cellfun(@isempty, spec));
        if numel(vals) == 1
            tf = isAllChannelSelector(vals{1});
        end
    end
end

function channels = normalizeExtractChannelsParam(spec)
    channels = spec;
    if isempty(spec)
        return;
    end

    if ischar(spec) || (isstring(spec) && isscalar(spec))
        token = strtrim(char(string(spec)));
        if isempty(token)
            channels = {};
        elseif isAllChannelSelector(token)
            channels = 'all';
        else
            channels = token;
        end
        return;
    end

    if isstring(spec)
        vals = cellstr(spec(:))';
    elseif iscell(spec)
        vals = {};
        for i = 1:numel(spec)
            if isempty(spec{i})
                continue;
            end
            vals{end+1} = strtrim(char(string(spec{i}))); %#ok<AGROW>
        end
    else
        return;
    end

    vals = vals(~cellfun(@isempty, vals));
    vals = vals(~strcmp(vals, '<no channel inventory>'));
    if isempty(vals)
        channels = 'all';
        return;
    end
    if numel(vals) == 1 && isAllChannelSelector(vals{1})
        channels = 'all';
        return;
    end
    channels = unique(vals, 'stable');
end

function ch = inferFovChannels(fovList)
    ch = {};
    if isempty(fovList)
        return;
    end

    try
        f0 = fovList(1);
        if isprop(f0,'channel') && ~isempty(f0.channel)
            ch = normalizeChannelListLocal(f0.channel);
            return;
        end
        if isfield(f0,'channel') && ~isempty(f0.channel)
            ch = normalizeChannelListLocal(f0.channel);
        end
    catch
        ch = {};
    end
end

function names = normalizeChannelListLocal(v)
    names = {};
    if isempty(v)
        return;
    end
    if ischar(v) || (isstring(v) && isscalar(v))
        s = strtrim(char(string(v)));
        if ~isempty(s)
            names = {s};
        end
        return;
    end
    if isstring(v)
        names = cellstr(v(:))';
        names = names(~cellfun(@(x) isempty(strtrim(x)), names));
        return;
    end
    if iscell(v)
        tmp = {};
        for i = 1:numel(v)
            if isempty(v{i})
                continue;
            end
            try
                s = strtrim(char(string(v{i})));
                if ~isempty(s)
                    tmp{end+1} = s; %#ok<AGROW>
                end
            catch
            end
        end
        names = tmp;
    end
end

function v = getfieldlocal(S, name, defaultVal)
    v = defaultVal;
    if isstruct(S) && isfield(S, name) && ~isempty(S.(name))
        v = S.(name);
    end
end
