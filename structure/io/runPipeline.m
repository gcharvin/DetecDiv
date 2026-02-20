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
    fun = resolveNodeFunc(node);

    % prefer ctx-aware calling
    try
        ctx = feval(fun, ctx);
    catch ME
        error('runPipeline:NodeFailed','Node %s failed: %s', node.id, ME.message);
    end

    % optional output coherence check
    ctx = ensureOutputs(node, ctx);
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
        case 'roiextract'
            ctx.roiExtract = node.params;
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
