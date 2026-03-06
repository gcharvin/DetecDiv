function [ctx, report] = runPipeline(pipe, ctx)
% runPipeline  Execute a pipeline against ctx.

    if nargin < 2 || isempty(ctx)
        ctx = struct();
    end

    if isfield(ctx,'dryRun') && ~isempty(ctx.dryRun) && logical(ctx.dryRun)
        [~, report] = runPipelineDry(pipe, ctx);
        return;
    end

    % normalize project handle
    if isfield(ctx,'shallowObj') && ~isfield(ctx,'shallow')
        ctx.shallow = ctx.shallowObj;
    elseif isfield(ctx,'shallow') && ~isfield(ctx,'shallowObj')
        ctx.shallowObj = ctx.shallow;
    end
    if (~isfield(ctx,'masks') || isempty(ctx.masks))
        try
            roisForMask = [];
            if isfield(ctx,'roiList') && ~isempty(ctx.roiList)
                roisForMask = ctx.roiList;
            elseif isfield(ctx,'shallow') && ~isempty(ctx.shallow) && isa(ctx.shallow,'shallow')
                roisForMask = collectRoisFromProject(ctx.shallow);
            end
            if ~isempty(roisForMask)
                ctx.masks = inferMaskChannelsFromRois(roisForMask);
            end
        catch
        end
    end

    allowGui = false;
    if isfield(ctx,'allowGUI') && ~isempty(ctx.allowGUI)
        allowGui = logical(ctx.allowGUI);
    elseif isfield(ctx,'interactive') && ~isempty(ctx.interactive)
        allowGui = logical(ctx.interactive);
    end

    [ok, report] = validatePipeline(pipe, ctx, struct('allowGui', allowGui));
    if ~ok
        error('runPipeline:Invalid','Pipeline validation failed: %s', strjoin(report.errors, ' | '));
    end

    P = pipelineToStructLocal(pipe);
    nodes = report.nodes;
    edges = report.edges;

    % map id -> node
    nodeMap = containers.Map();
    for i = 1:numel(nodes)
        nodeMap(char(string(nodes(i).id))) = nodes(i);
    end

    % initialize run state
    if isa(pipe,'pipeline')
        pipe.runState = struct('status','running','currentNode','', ...
            'progress',0,'errors',{{}});
    end

    executed = containers.Map();
    total = numel(report.order);
    for i = 1:numel(report.order)
        nodeId = report.order{i};
        node = nodeMap(nodeId);

        % run-level subset selection (optional)
        if shouldSkipByRunSelection(ctx, nodeId)
            executed(nodeId) = true;
            continue;
        end

        % disabled nodes are always skipped
        if isfield(node,'enabled') && ~isempty(node.enabled) && ~logical(node.enabled)
            executed(nodeId) = true;
            continue;
        end

        % run-level parameter override (optional)
        node = applyRunNodeOverride(node, ctx, nodeId);

        if shouldSkipNode(node, ctx, edges, executed)
            executed(nodeId) = true;
            continue;
        end

        % ensure required params are present; launch GUI if allowed
        missing = missingParamsForNode(node, ctx);
        if ~isempty(missing)
            if allowGui && hasNodeGui(node)
                [ctx, guiCompleted] = runNodeGui(node, ctx);
                ctx = syncCtxFromShallow(ctx);

                if guiCompleted && isGuiReplace(node)
                    ctx = ensureOutputs(node, ctx);
                    executed(nodeId) = true;
                    continue;
                end

                missing = missingParamsForNode(node, ctx);
            end

            if ~isempty(missing)
                error('runPipeline:MissingParams', ...
                    'Node %s missing params: %s', nodeId, strjoin(missing, ', '));
            end
        end

        ctx.pipeline = struct('currentNode', nodeId, 'nodeType', node.type);
        ctx = applyNodeParams(ctx, node);

        if isa(pipe,'pipeline')
            pipe.runState.currentNode = nodeId;
            pipe.runState.progress = (i-1) / max(1,total);
        end

        ctx = executeNode(node, ctx);

        executed(nodeId) = true;
        if isa(pipe,'pipeline')
            pipe.runState.progress = i / max(1,total);
        end
    end

    if isa(pipe,'pipeline')
        pipe.runState.status = 'done';
        pipe.runState.currentNode = '';
        pipe.log('Pipeline completed','Run');
    end
end

function tf = shouldSkipByRunSelection(ctx, nodeId)
    tf = false;
    if ~isfield(ctx,'run') || isempty(ctx.run)
        return;
    end
    runCfg = ctx.run;
    if ~isstruct(runCfg) || ~isfield(runCfg,'selectedNodes') || isempty(runCfg.selectedNodes)
        return;
    end
    ids = cellstr(runCfg.selectedNodes(:));
    tf = ~any(strcmp(ids, nodeId));
end

function node = applyRunNodeOverride(node, ctx, nodeId)
    if ~isfield(ctx,'run') || isempty(ctx.run)
        return;
    end
    runCfg = ctx.run;
    if ~isstruct(runCfg) || ~isfield(runCfg,'nodeParams') || isempty(runCfg.nodeParams)
        return;
    end

    np = runCfg.nodeParams;
    if ~isstruct(np)
        return;
    end

    if isfield(np,'id')
        for i = 1:numel(np)
            if strcmp(char(string(np(i).id)), nodeId)
                if isfield(np(i),'params') && isstruct(np(i).params)
                    node.params = mergeStruct(node.params, np(i).params);
                end
                return;
            end
        end
    else
        % map-style fallback: ctx.run.nodeParams.<nodeId> = struct(...)
        f = matlab.lang.makeValidName(nodeId);
        if isfield(np, f) && isstruct(np.(f))
            node.params = mergeStruct(node.params, np.(f));
        end
    end
end

function out = mergeStruct(base, patch)
    if nargin < 1 || ~isstruct(base) || isempty(base)
        base = struct();
    end
    out = base;
    if nargin < 2 || ~isstruct(patch) || isempty(patch)
        return;
    end
    fn = fieldnames(patch);
    for i = 1:numel(fn)
        out.(fn{i}) = patch.(fn{i});
    end
end

function ctx = executeNode(node, ctx)
    nodeType = lower(char(string(getfielddefault(node,'type',''))));

    switch nodeType
        case 'dataloader'
            try
                ctx = dataLoader.process(ctx);
            catch ME
                error('runPipeline:NodeFailed','Node %s failed: %s', node.id, formatNodeError(ME));
            end
        case 'roiidentify'
            try
                ctx = roiIdentify.process(ctx);
            catch ME
                error('runPipeline:NodeFailed','Node %s failed: %s', node.id, formatNodeError(ME));
            end
        case 'roipattern'
            try
                ctx = roiPattern.process(ctx);
            catch ME
                error('runPipeline:NodeFailed','Node %s failed: %s', node.id, formatNodeError(ME));
            end
        case 'roimanual'
            try
                ctx = roiManual.process(ctx);
            catch ME
                error('runPipeline:NodeFailed','Node %s failed: %s', node.id, formatNodeError(ME));
            end
        case 'roigrid'
            try
                ctx = roiGrid.process(ctx);
            catch ME
                error('runPipeline:NodeFailed','Node %s failed: %s', node.id, formatNodeError(ME));
            end
        case 'roitracked'
            try
                ctx = roiTracked.process(ctx);
            catch ME
                error('runPipeline:NodeFailed','Node %s failed: %s', node.id, formatNodeError(ME));
            end
        case 'roiextract'
            try
                ctx = roiExtract.process(ctx);
            catch ME
                error('runPipeline:NodeFailed','Node %s failed: %s', node.id, formatNodeError(ME));
            end
        case 'processor'
            ctx = executeProcessorNode(node, ctx);
        case 'classifier'
            ctx = executeClassifierNode(node, ctx);
        otherwise
            fun = resolveNodeFunc(node);
            try
                ctx = feval(fun, ctx);
            catch ME
                error('runPipeline:NodeFailed','Node %s failed: %s', node.id, formatNodeError(ME));
            end
    end

    % optional output coherence check
    ctx = ensureOutputs(node, ctx);
end

function msg = formatNodeError(ME)
    msg = char(string(ME.message));
    try
        if ~isempty(ME.identifier)
            msg = sprintf('%s [%s]', msg, char(string(ME.identifier)));
        end
        if ~isempty(ME.stack)
            top = ME.stack(1);
            msg = sprintf('%s @ %s:%d', msg, char(string(top.name)), top.line);
        end
    catch
    end
end

function fun = resolveNodeFunc(node)
    if isfield(node,'func') && ~isempty(node.func)
        typeStr = node.func;
    else
        typeStr = node.type;
    end

    if isa(typeStr,'function_handle')
        fun = typeStr;
        return;
    end
    t = char(string(typeStr));
    if contains(t,'.process') || contains(t,'.classify')
        fun = t;
        return;
    end
    if ~isempty(which([t '.process']))
        fun = [t '.process'];
        return;
    end
    if ~isempty(which(t))
        fun = t;
        return;
    end
    error('runPipeline:UnknownNode','Cannot resolve node function: %s', t);
end

function ctx = applyNodeParams(ctx, node)
    if ~isfield(node,'params') || isempty(node.params)
        return;
    end

    % attach node params to ctx
    ctx.params = node.params;

    % map known dataloading nodes to ctx fields
    switch lower(char(string(node.type)))
        case 'dataloader'
            ctx.dataLoader = node.params;
        case 'roiidentify'
            ctx.roiIdentify = node.params;
        case 'roipattern'
            ctx.roiPattern = node.params;
        case 'roimanual'
            ctx.roiManual = node.params;
        case 'roigrid'
            ctx.roiGrid = node.params;
        case 'roitracked'
            ctx.roiTracked = node.params;
        case 'roiextract'
            ctx.roiExtract = node.params;
        case 'processor'
            ctx.processor = node.params;
        case 'classifier'
            ctx.classifier = node.params;
    end
end

function tf = shouldSkipNode(node, ctx, edges, executed)
    tf = false;
    % node-level condition
    if isfield(node,'condition') && ~isempty(node.condition)
        tf = ~evalCondition(node.condition, ctx);
        return;
    elseif isfield(node,'when') && ~isempty(node.when)
        tf = ~evalCondition(node.when, ctx);
        return;
    end

    % edge-level conditions (branching)
    if nargin < 3 || isempty(edges)
        return;
    end
    incoming = edges(strcmp({edges.to}, node.id));
    condEdges = incoming(~cellfun(@isempty, {incoming.condition}));
    if isempty(condEdges)
        return;
    end

    runOK = false;
    for k = 1:numel(condEdges)
        if isKey(executed, condEdges(k).from)
            if evalCondition(condEdges(k).condition, ctx)
                runOK = true;
                break;
            end
        end
    end
    tf = ~runOK;
end

function ok = evalCondition(expr, ctx)
    ok = false;
    try
        ok = eval(expr); %#ok<EVL>
    catch
    end
end

function P = pipelineToStructLocal(pipe)
    if isa(pipe, 'pipeline')
        P = struct();
        P.nodes = pipe.nodes;
        P.edges = pipe.edges;
        P.branches = pipe.branches;
    else
        P = pipe;
    end
end

function missing = missingParamsForNode(node, ctx)
    missing = {};
    req = {};
    if isfield(node,'paramRequired') && ~isempty(node.paramRequired)
        req = cellstr(node.paramRequired(:));
    elseif isfield(node,'requiredParams') && ~isempty(node.requiredParams)
        req = cellstr(node.requiredParams(:));
    end
    if isempty(req)
        return;
    end

    p = struct();
    if isfield(node,'params') && ~isempty(node.params)
        p = node.params;
    end

    for i = 1:numel(req)
        k = char(string(req{i}));
        if isfield(p,k) && ~isempty(p.(k))
            continue;
        end
        if isfield(ctx,k) && ~isempty(ctx.(k))
            continue;
        end
        if isfield(ctx,'params') && isfield(ctx.params,k) && ~isempty(ctx.params.(k))
            continue;
        end
        if isfield(ctx,'dataLoader') && isfield(ctx.dataLoader,k) && ~isempty(ctx.dataLoader.(k))
            continue;
        end
        if isfield(ctx,'roiIdentify') && isfield(ctx.roiIdentify,k) && ~isempty(ctx.roiIdentify.(k))
            continue;
        end
        if isfield(ctx,'roiExtract') && isfield(ctx.roiExtract,k) && ~isempty(ctx.roiExtract.(k))
            continue;
        end
        if isfield(ctx,'roiTracked') && isfield(ctx.roiTracked,k) && ~isempty(ctx.roiTracked.(k))
            continue;
        end
        if isfield(ctx,'processor') && isfield(ctx.processor,k) && ~isempty(ctx.processor.(k))
            continue;
        end
        if isfield(ctx,'classifier') && isfield(ctx.classifier,k) && ~isempty(ctx.classifier.(k))
            continue;
        end
        missing{end+1} = k; %#ok<AGROW>
    end
end

function tf = hasNodeGui(node)
    tf = isfield(node,'gui') && ~isempty(node.gui);
end

function tf = isGuiReplace(node)
    tf = true;
    if isfield(node,'guiMode') && ~isempty(node.guiMode)
        tf = strcmpi(char(string(node.guiMode)),'replace');
    end
end

function [ctx, completed] = runNodeGui(node, ctx)
    completed = false;
    if ~isfield(node,'gui') || isempty(node.gui)
        return;
    end
    guiFun = node.gui;
    try
        ctxOut = feval(guiFun, ctx);
        if ~isempty(ctxOut)
            ctx = ctxOut;
        end
        completed = true;
    catch
        % ignore GUI errors here; validation will catch missing params
    end
end

function ctx = syncCtxFromShallow(ctx)
    if isfield(ctx,'shallow') && ~isempty(ctx.shallow)
        try
            ctx.fovList = ctx.shallow.fov;
        catch
        end
        if isfield(ctx,'fovList') && ~isempty(ctx.fovList)
            try
                if ~isfield(ctx,'channels') || isempty(ctx.channels)
                    ctx.channels = ctx.fovList(1).channel;
                end
            catch
            end
        end
    end
end

function ctx = ensureOutputs(node, ctx)
    if isfield(node,'outputs') && ~isempty(node.outputs)
        outs = cellstr(node.outputs(:));
        for k = 1:numel(outs)
            if ~isfield(ctx, outs{k})
                ctx.(outs{k}) = [];
            end
        end
    end
end

function ctx = executeProcessorNode(node, ctx)
    shallowObj = getShallowObject(ctx);
    if isempty(shallowObj)
        error('runPipeline:ProcessorNoProject', ...
            'Processor node %s requires a shallow project context.', char(string(node.id)));
    end

    rois = selectRoisForNode(ctx, node);
    if isempty(rois)
        warning('runPipeline:ProcessorNoROI', ...
            'Processor node %s has no ROI to process; skipping.', char(string(node.id)));
        return;
    end

    pkgName = resolveNodePackage(node);
    procFun = '';
    if ~isempty(pkgName)
        procFun = [pkgName '.process'];
    elseif isfield(node,'func') && ~isempty(node.func)
        procFun = char(string(node.func));
    end
    if isempty(procFun)
        error('runPipeline:ProcessorNoPackage', ...
            'Processor node %s is missing package/function information.', char(string(node.id)));
    end

    procObj = process(tempdir, 'pipeline_processor', randi(1e9));
    procObj.processFun = procFun;
    procObj.processArg = getfielddefault(node, 'params', struct());
    procObj.strid = char(string(node.id));

    p = procObj.processArg;
    procCtx = struct();
    procCtx.params = p;
    procCtx.run = getfielddefault(ctx, 'run', struct());
    procCtx.pipeline = getfielddefault(ctx, 'pipeline', struct());
    if isfield(ctx,'names') && isstruct(ctx.names) && isfield(ctx.names,'outputName') && ~isempty(ctx.names.outputName)
        procCtx.outputName = ctx.names.outputName;
    elseif isfield(p,'outputName') && ~isempty(p.outputName)
        procCtx.outputName = p.outputName;
    end

    args = {'Ctx', procCtx};
    if isfield(p,'frames') && ~isempty(p.frames)
        args = [args {'Frames', p.frames}]; %#ok<AGROW>
    end
    if isfield(p,'parallel') && ~isempty(p.parallel) && logical(p.parallel)
        args = [args {'Parallel'}]; %#ok<AGROW>
    end
    if isfield(p,'gpu') && ~isempty(p.gpu) && logical(p.gpu)
        args = [args {'GPU'}]; %#ok<AGROW>
    end

    try
        processData(procObj, rois, args{:});
    catch ME
        error('runPipeline:NodeFailed','Node %s failed: %s', node.id, ME.message);
    end

    ctx.roiList = rois;
    ctx.dataSeries = collectDataSeriesFromRois(rois);
    ctx.channels = inferChannelsFromRois(rois, ctx);
end

function ctx = executeClassifierNode(node, ctx)
    shallowObj = getShallowObject(ctx);
    if isempty(shallowObj)
        error('runPipeline:ClassifierNoProject', ...
            'Classifier node %s requires a shallow project context.', char(string(node.id)));
    end

    rois = selectRoisForNode(ctx, node);
    if isempty(rois)
        warning('runPipeline:ClassifierNoROI', ...
            'Classifier node %s has no ROI to classify; skipping.', char(string(node.id)));
        return;
    end

    pkgName = resolveNodePackage(node);
    clsObj = classi(tempdir, 'pipeline_classifier', randi(1e9), 'InitTraining', false);
    clsObj.strid = char(string(node.id));
    if ~isempty(pkgName)
        clsObj.classifierPkg = pkgName;
        clsObj.classifyFun = [pkgName '.classify'];
    elseif isfield(node,'func') && ~isempty(node.func)
        clsObj.classifyFun = char(string(node.func));
    else
        error('runPipeline:ClassifierNoPackage', ...
            'Classifier node %s is missing package/function information.', char(string(node.id)));
    end

    p = getfielddefault(node, 'params', struct());
    if isfield(p,'classes') && ~isempty(p.classes)
        clsObj.classes = p.classes;
    end
    if isfield(p,'category') && ~isempty(p.category)
        clsObj.category = classiNormalizeCategory(p.category);
    end
    if isfield(p,'outputType') && ~isempty(p.outputType)
        clsObj.outputType = p.outputType;
    end

    outputName = char(string(node.id));
    if isfield(ctx,'names') && isstruct(ctx.names) && isfield(ctx.names,'outputName') && ~isempty(ctx.names.outputName)
        outputName = char(string(ctx.names.outputName));
    elseif isfield(p,'outputName') && ~isempty(p.outputName)
        outputName = char(string(p.outputName));
    elseif isfield(p,'out_dataSeries_name') && ~isempty(p.out_dataSeries_name)
        outputName = char(string(p.out_dataSeries_name));
    end

    args = {'OutputName', outputName};
    if isfield(p,'frames') && ~isempty(p.frames)
        args = [args {'Frames', p.frames}]; %#ok<AGROW>
    end
    if isfield(p,'channels') && ~isempty(p.channels)
        ch = normalizeClassifierChannels(p.channels);
        args = [args {'Channel', ch}]; %#ok<AGROW>
    end
    if isfield(p,'parallel') && ~isempty(p.parallel) && logical(p.parallel)
        args = [args {'Parallel'}]; %#ok<AGROW>
    end
    if isfield(p,'gpu') && ~isempty(p.gpu) && logical(p.gpu)
        args = [args {'GPU'}]; %#ok<AGROW>
    end

    try
        classifyData(clsObj, rois, args{:});
    catch ME
        error('runPipeline:NodeFailed','Node %s failed: %s', node.id, ME.message);
    end

    ctx.roiList = rois;
    ctx.dataSeries = collectDataSeriesFromRois(rois);
    ctx.channels = inferChannelsFromRois(rois, ctx);
    ctx.masks = inferMaskChannelsFromRois(rois);
end

function v = getfielddefault(S, key, defaultVal)
    v = defaultVal;
    if isstruct(S) && isfield(S,key) && ~isempty(S.(key))
        v = S.(key);
    end
end

function shallowObj = getShallowObject(ctx)
    shallowObj = [];
    if isfield(ctx,'shallow') && ~isempty(ctx.shallow)
        shallowObj = ctx.shallow;
    elseif isfield(ctx,'shallowObj') && ~isempty(ctx.shallowObj)
        shallowObj = ctx.shallowObj;
    end
    if ~isempty(shallowObj) && ~isa(shallowObj, 'shallow')
        shallowObj = [];
    end
end

function rois = selectRoisForNode(ctx, node)
    rois = [];
    if isfield(ctx,'roiList') && ~isempty(ctx.roiList)
        rois = ctx.roiList;
    end

    if isempty(rois)
        shallowObj = getShallowObject(ctx);
        if ~isempty(shallowObj)
            rois = collectRoisFromProject(shallowObj);
        end
    end

    p = getfielddefault(node, 'params', struct());
    if isstruct(p) && isfield(p,'roiList') && ~isempty(p.roiList) && ~isempty(rois)
        idx = double(p.roiList(:)');
        idx = idx(isfinite(idx));
        idx = round(idx);
        idx = idx(idx >= 1 & idx <= numel(rois));
        if ~isempty(idx)
            rois = rois(idx);
        else
            rois = rois([]);
        end
    end
end

function rois = collectRoisFromProject(shallowObj)
    rois = [];
    if isempty(shallowObj) || ~isa(shallowObj, 'shallow') || isempty(shallowObj.fov)
        return;
    end
    for i = 1:numel(shallowObj.fov)
        try
            r = shallowObj.fov(i).roi;
            if ~isempty(r)
                rois = [rois r(:)']; %#ok<AGROW>
            end
        catch
        end
    end
end

function pkgName = resolveNodePackage(node)
    pkgName = '';
    if isfield(node,'pkg') && ~isempty(node.pkg)
        pkgName = char(string(node.pkg));
        return;
    end
    if isfield(node,'params') && isstruct(node.params) && isfield(node.params,'pkg') && ~isempty(node.params.pkg)
        pkgName = char(string(node.params.pkg));
        return;
    end
    if isfield(node,'func') && ~isempty(node.func)
        f = char(string(node.func));
        dot = strfind(f, '.');
        if ~isempty(dot)
            pkgName = f(1:dot(1)-1);
        end
    end
end

function ds = collectDataSeriesFromRois(rois)
    ds = {};
    if isempty(rois)
        return;
    end
    for i = 1:numel(rois)
        try
            r = rois(i);
            if isempty(r.data)
                r.load('data');
            end
            for k = 1:numel(r.data)
                if isprop(r.data(k), 'groupid') && ~isempty(r.data(k).groupid)
                    ds{end+1} = char(string(r.data(k).groupid)); %#ok<AGROW>
                end
            end
        catch
        end
    end
    if ~isempty(ds)
        ds = unique(ds, 'stable');
    end
end

function ch = inferChannelsFromRois(rois, ctx)
    ch = {};
    if isfield(ctx,'channels') && ~isempty(ctx.channels)
        ch = ctx.channels;
        return;
    end
    if isempty(rois)
        return;
    end
    try
        r0 = rois(1);
        if isfield(r0.display,'channel') && ~isempty(r0.display.channel)
            ch = r0.display.channel;
        end
    catch
    end
end

function masks = inferMaskChannelsFromRois(rois)
    masks = {};
    if isempty(rois)
        return;
    end
    try
        r0 = rois(1);
        if ~isempty(r0.display) && isfield(r0.display,'channel') && ~isempty(r0.display.channel)
            names = r0.display.channel;
            keep = false(1, numel(names));
            for i = 1:numel(names)
                nm = lower(char(string(names{i})));
                keep(i) = contains(nm, 'mask') || contains(nm, 'result') || contains(nm, 'track');
            end
            masks = names(keep);
        end
    catch
    end
end

function ch = normalizeClassifierChannels(inCh)
    if isstring(inCh)
        inCh = cellstr(inCh);
    elseif ischar(inCh)
        inCh = {inCh};
    end
    if isnumeric(inCh)
        inCh = {inCh};
    end
    if ~iscell(inCh)
        inCh = {inCh};
    end
    ch = inCh;
end
