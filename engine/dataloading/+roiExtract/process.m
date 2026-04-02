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

    existingPolicy = resolveExistingPolicy(ctx, p);
    switch existingPolicy
        case {'append','upsert'}
            p.extend = true;
        case 'replace'
            p.extend = false;
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

        [todo, existingTodo] = filterTodoByExistingPolicy(f.roi, todo, existingPolicy);
        if strcmp(existingPolicy, 'error') && ~isempty(existingTodo)
            error('roiExtract.process:ExistingOutputs', ...
                'ROI extraction outputs already exist for FOV %d, ROI(s) %s.', ...
                i, mat2str(existingTodo));
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
            tf = isfile(fullfile(r.path, ['im_' char(string(r.id)) '.h5']));
            if tf
                return;
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
        tf = any(strcmp(token, {'all', '*', ':'}));
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
