function [ctx, report] = runPipeline(pipe, ctx)
% runPipeline  Execute a pipeline against ctx.

    if nargin < 2 || isempty(ctx)
        ctx = struct();
    end

    [ok, report] = validatePipeline(pipe, ctx);
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

        if shouldSkipNode(node, ctx, edges, executed)
            executed(nodeId) = true;
            continue;
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

function ctx = executeNode(node, ctx)
    fun = resolveNodeFunc(node.type);

    % prefer ctx-aware calling
    try
        ctx = feval(fun, ctx);
    catch ME
        error('runPipeline:NodeFailed','Node %s failed: %s', node.id, ME.message);
    end

    % optional output coherence check
    if isfield(node,'outputs') && ~isempty(node.outputs)
        outs = cellstr(node.outputs(:));
        for k = 1:numel(outs)
            if ~isfield(ctx, outs{k})
                ctx.(outs{k}) = [];
            end
        end
    end
end

function fun = resolveNodeFunc(typeStr)
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
