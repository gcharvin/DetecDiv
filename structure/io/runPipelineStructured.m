function [ctx, report] = runPipelineStructured(pipe, ctx)
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

    % Use a per-invocation run id by default so progress checkpoints from
    % previous runs do not silently skip nodes.
    ctx = normalizeRunId(ctx);
    ctx = normalizeExecutionContext(ctx);
    ctx = seedContextFromProject(ctx);
    checkPipelineCancellation(ctx, 'initialize', '');

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
    report = initRunReport(report, ctx);

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
        checkPipelineCancellation(ctx, 'before_node', nodeId);

        % run-level parameter override (optional)
        node = applyRunNodeOverride(node, ctx, nodeId);
        [node, policy] = applyNodeExecutionPolicy(node, ctx);

        % run-level subset selection (optional)
        if shouldSkipByRunSelection(ctx, nodeId)
            report = appendNodeRun(report, node, policy, 'skipped_selection', ...
                captureContextStats(ctx), captureContextStats(ctx), 0, '');
            executed(nodeId) = true;
            continue;
        end

        % disabled nodes are always skipped
        if isfield(node,'enabled') && ~isempty(node.enabled) && ~logical(node.enabled)
            report = appendNodeRun(report, node, policy, 'skipped_disabled', ...
                captureContextStats(ctx), captureContextStats(ctx), 0, '');
            executed(nodeId) = true;
            continue;
        end

        if shouldSkipNode(node, ctx, edges, executed)
            report = appendNodeRun(report, node, policy, 'skipped_condition', ...
                captureContextStats(ctx), captureContextStats(ctx), 0, '');
            executed(nodeId) = true;
            continue;
        end

        % ensure required params are present; launch GUI if allowed
        [missing, ~] = missingParamsForNode(node, ctx, 'run');
        if ~isempty(missing)
            if allowGui && hasNodeGui(node)
                [ctx, guiCompleted] = runNodeGui(node, ctx);
                ctx = syncCtxFromShallow(ctx);

                if guiCompleted && isGuiReplace(node)
                    ctx = ensureOutputs(node, ctx);
                    executed(nodeId) = true;
                    continue;
                end

                [missing, ~] = missingParamsForNode(node, ctx, 'run');
            end

            if ~isempty(missing)
                error('runPipeline:MissingParams', ...
                    'Node %s missing params: %s', nodeId, strjoin(missing, ', '));
            end
        end

        ctx.pipeline = struct('currentNode', nodeId, 'nodeType', node.type);
        ctx = applyNodeParams(ctx, node);
        checkPipelineCancellation(ctx, 'prepared_node', nodeId);

        if isa(pipe,'pipeline')
            pipe.runState.currentNode = nodeId;
            pipe.runState.progress = (i-1) / max(1,total);
        end

        beforeStats = captureContextStats(ctx);
        tNode = tic;
        try
            ctx = applyPolicyToContext(ctx, node, policy);
            checkPipelineCancellation(ctx, 'before_execute', nodeId);
            ctx = executeNode(node, ctx);
            checkPipelineCancellation(ctx, 'after_execute', nodeId);
            afterStats = captureContextStats(ctx);
            report = appendNodeRun(report, node, policy, 'done', ...
                beforeStats, afterStats, toc(tNode), '');
        catch ME
            wasCancelled = strcmp(ME.identifier, 'runPipeline:Cancelled');
            afterStats = captureContextStats(ctx);
            nodeStatus = 'failed';
            if wasCancelled
                nodeStatus = 'cancelled';
            end
            report = appendNodeRun(report, node, policy, nodeStatus, ...
                beforeStats, afterStats, toc(tNode), formatNodeError(ME));
            report.endedAt = char(datetime('now'));
            report.summary = buildRunSummary(report);
            stashRunReport(report);
            if isa(pipe,'pipeline')
                if wasCancelled
                    pipe.runState.status = 'cancelled';
                else
                    pipe.runState.status = 'failed';
                end
                pipe.runState.currentNode = nodeId;
                pipe.runState.errors = [pipe.runState.errors {formatNodeError(ME)}];
            end
            rethrow(ME);
        end

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
    ctx = stripEphemeralExecutionFields(ctx);
    report.endedAt = char(datetime('now'));
    report.summary = buildRunSummary(report);
    stashRunReport(report);
end

function checkPipelineCancellation(ctx, stage, nodeId)
    if nargin < 2 || isempty(stage)
        stage = 'run';
    end
    if nargin < 3
        nodeId = '';
    end

    drawnow;

    tokenFile = '';
    try
        if isstruct(ctx) && isfield(ctx,'cancel') && isstruct(ctx.cancel) ...
                && isfield(ctx.cancel,'tokenFile') && ~isempty(ctx.cancel.tokenFile)
            tokenFile = char(string(ctx.cancel.tokenFile));
        end
    catch
        tokenFile = '';
    end

    if isempty(tokenFile) || exist(tokenFile, 'file') ~= 2
        return;
    end

    try
        pe = pyenv;
        if pe.Status == "Loaded"
            terminate(pyenv);
        end
    catch
    end

    msg = 'Pipeline run cancelled by user.';
    if ~isempty(nodeId)
        msg = sprintf('Pipeline run cancelled by user during %s (%s).', char(string(nodeId)), char(string(stage)));
    end
    error('runPipeline:Cancelled', '%s', msg);
end

function ctx = stripEphemeralExecutionFields(ctx)
    if ~isstruct(ctx)
        return;
    end
    try
        if isfield(ctx,'cancel')
            ctx = rmfield(ctx,'cancel');
        end
    catch
    end
end

function ctx = normalizeRunId(ctx)
    if ~isstruct(ctx)
        return;
    end

    if isfield(ctx,'runId') && ~isempty(ctx.runId)
        runId = char(string(ctx.runId));
    elseif isfield(ctx,'run') && isstruct(ctx.run) && isfield(ctx.run,'runId') && ~isempty(ctx.run.runId)
        runId = char(string(ctx.run.runId));
    else
        stamp = char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
        runId = ['pipelineRun_' stamp];
    end

    runId = matlab.lang.makeValidName(runId);
    if isempty(runId)
        runId = 'pipelineRun_default';
    end
    ctx.runId = runId;
end

function ctx = normalizeExecutionContext(ctx)
    if ~isstruct(ctx)
        ctx = struct();
    end

    if ~isfield(ctx,'run') || ~isstruct(ctx.run) || isempty(ctx.run)
        ctx.run = struct();
    end
    if ~isfield(ctx,'io') || ~isstruct(ctx.io) || isempty(ctx.io)
        ctx.io = struct();
    end
    if ~isfield(ctx,'store') || ~isstruct(ctx.store) || isempty(ctx.store)
        ctx.store = struct();
    end
    if ~isfield(ctx,'names') || ~isstruct(ctx.names) || isempty(ctx.names)
        ctx.names = struct();
    end
    if ~isfield(ctx,'sel') || ~isstruct(ctx.sel) || isempty(ctx.sel)
        ctx.sel = struct();
    end

    if ~isfield(ctx.run,'runPolicy') || isempty(ctx.run.runPolicy)
        if isfield(ctx.run,'resume') && ~isempty(ctx.run.resume) && ~logical(ctx.run.resume)
            ctx.run.runPolicy = 'restart';
        else
            ctx.run.runPolicy = 'resume';
        end
    end
    ctx.run.runPolicy = normalizeRunPolicy(ctx.run.runPolicy);
    ctx.run.resume = strcmpi(ctx.run.runPolicy, 'resume');

    if ~isfield(ctx.io,'existingPolicy') || isempty(ctx.io.existingPolicy)
        if isfield(ctx.io,'overwrite') && ~isempty(ctx.io.overwrite) && logical(ctx.io.overwrite)
            ctx.io.existingPolicy = 'replace';
        elseif isfield(ctx.io,'writePolicy') && ~isempty(ctx.io.writePolicy)
            ctx.io.existingPolicy = char(string(ctx.io.writePolicy));
        else
            ctx.io.existingPolicy = '';
        end
    else
        ctx.io.existingPolicy = normalizeExistingPolicy(ctx.io.existingPolicy, 'replace');
    end
    if ~isfield(ctx.io,'globalExistingPolicy') || isempty(ctx.io.globalExistingPolicy)
        ctx.io.globalExistingPolicy = ctx.io.existingPolicy;
    else
        ctx.io.globalExistingPolicy = normalizeExistingPolicy(ctx.io.globalExistingPolicy, 'replace');
    end

    if ~isfield(ctx.io,'cachePolicy') || isempty(ctx.io.cachePolicy)
        if isfield(ctx.store,'cacheMode') && ~isempty(ctx.store.cacheMode)
            ctx.io.cachePolicy = char(string(ctx.store.cacheMode));
        else
            ctx.io.cachePolicy = 'auto';
        end
    end
    ctx.io.cachePolicy = normalizeCachePolicy(ctx.io.cachePolicy);
    ctx.store.cacheMode = ctx.io.cachePolicy;

    if ~isfield(ctx,'resume') || isempty(ctx.resume)
        ctx.resume = ctx.run.resume;
    end
    if ~isfield(ctx,'saveProgress') || isempty(ctx.saveProgress)
        ctx.saveProgress = true;
    end

    if ~isfield(ctx.sel,'fovs') || isempty(ctx.sel.fovs)
        if isfield(ctx.run,'fovIndex') && ~isempty(ctx.run.fovIndex)
            ctx.sel.fovs = normalizeIndexVectorLocal(ctx.run.fovIndex);
        else
            ctx.sel.fovs = [];
        end
    else
        ctx.sel.fovs = normalizeIndexVectorLocal(ctx.sel.fovs);
    end
end

function report = initRunReport(report, ctx)
    report.runId = getfielddefault(ctx, 'runId', '');
    report.startedAt = char(datetime('now'));
    report.endedAt = '';
    report.nodeRuns = struct( ...
        'nodeId', {}, 'nodeType', {}, 'status', {}, ...
        'runPolicy', {}, 'existingPolicy', {}, 'outputName', {}, ...
        'durationSec', {}, 'before', {}, 'after', {}, 'message', {});
    report.summary = struct();
end

function [node, policy] = applyNodeExecutionPolicy(node, ctx)
    policy = resolveNodeExecutionPolicy(node, ctx);

    if ~isfield(node,'params') || isempty(node.params) || ~isstruct(node.params)
        node.params = struct();
    end
    node.params.runPolicy = policy.runPolicy;
    node.params.existingPolicy = policy.existingPolicy;

    switch lower(char(string(getfielddefault(node,'type',''))))
        case {'roiidentify','roipattern','roimanual','roigrid'}
            switch policy.existingPolicy
                case 'append'
                    node.params.keepExisting = true;
                case 'replace'
                    node.params.keepExisting = false;
                case 'skip'
                    node.params.keepExisting = true;
                    node.params.skipExisting = true;
                case 'error'
                    node.params.keepExisting = true;
                    node.params.errorOnExisting = true;
            end
        case {'processor','classifier'}
            if ~isempty(policy.outputName)
                node.params.outputName = policy.outputName;
                if strcmpi(char(string(getfielddefault(node,'type',''))), 'classifier')
                    node.params.out_dataSeries_name = policy.outputName;
                end
            end
    end
end

function policy = resolveNodeExecutionPolicy(node, ctx)
    nodeType = lower(char(string(getfielddefault(node,'type',''))));
    p = getfielddefault(node, 'params', struct());

    policy = struct();
    policy.runPolicy = normalizeRunPolicy(getFirstNonEmpty( ...
        getfielddefault(p,'runPolicy',''), ...
        getfielddefault(getfielddefault(ctx,'run',struct()),'runPolicy',''), ...
        ternary(getfielddefault(ctx,'resume',true), 'resume', 'restart')));
    policy.resume = strcmpi(policy.runPolicy, 'resume');

    policy.existingPolicy = normalizeExistingPolicy(getFirstNonEmpty( ...
        getfielddefault(p,'existingPolicy',''), ...
        getfielddefault(getfielddefault(ctx,'io',struct()),'globalExistingPolicy', ...
            getfielddefault(getfielddefault(ctx,'io',struct()),'existingPolicy','')), ...
        defaultExistingPolicyForNode(nodeType)), defaultExistingPolicyForNode(nodeType));

    explicitOutputName = getFirstNonEmpty( ...
        getfielddefault(p,'outputName',''), ...
        getfielddefault(p,'out_dataSeries_name',''), ...
        getfielddefault(getfielddefault(ctx,'names',struct()),'outputName',''));

    if isempty(explicitOutputName) && any(strcmp(nodeType, {'processor','classifier'}))
        if strcmpi(policy.existingPolicy, 'append')
            explicitOutputName = [char(string(node.id)) '_' char(string(getfielddefault(ctx,'runId','run')))];
        else
            explicitOutputName = char(string(node.id));
        end
    end
    if isempty(explicitOutputName) && strcmp(nodeType, 'roitracked') && strcmpi(policy.existingPolicy, 'append')
        explicitOutputName = [char(string(node.id)) '_' char(string(getfielddefault(ctx,'runId','run')))];
    end

    policy.outputName = char(string(explicitOutputName));
end

function ctx = applyPolicyToContext(ctx, node, policy)
    if ~isstruct(ctx)
        ctx = struct();
    end
    ctx.resume = policy.resume;
    if ~isfield(ctx,'saveProgress') || isempty(ctx.saveProgress)
        ctx.saveProgress = true;
    end
    ctx.executionPolicy = policy;

    if ~isfield(ctx,'run') || ~isstruct(ctx.run) || isempty(ctx.run)
        ctx.run = struct();
    end
    ctx.run.runPolicy = policy.runPolicy;
    ctx.run.resume = policy.resume;

    if ~isfield(ctx,'io') || ~isstruct(ctx.io) || isempty(ctx.io)
        ctx.io = struct();
    end
    if ~isfield(ctx.io,'effectiveExistingPolicy') || ~strcmp(ctx.io.effectiveExistingPolicy, policy.existingPolicy)
        ctx.io.effectiveExistingPolicy = policy.existingPolicy;
    end
    if ~isfield(ctx.io,'globalExistingPolicy')
        ctx.io.globalExistingPolicy = getfielddefault(ctx.io,'existingPolicy','');
    end
    ctx.io.existingPolicy = ctx.io.globalExistingPolicy;
    if ~isfield(ctx.io,'cachePolicy') || isempty(ctx.io.cachePolicy)
        ctx.io.cachePolicy = 'auto';
    end
    ctx.io.cachePolicy = normalizeCachePolicy(ctx.io.cachePolicy);

    if ~isfield(ctx,'store') || ~isstruct(ctx.store) || isempty(ctx.store)
        ctx.store = struct();
    end
    ctx.store.cacheMode = ctx.io.cachePolicy;

    if any(strcmpi(char(string(getfielddefault(node,'type',''))), {'processor','classifier'}))
        if ~isfield(ctx,'names') || ~isstruct(ctx.names) || isempty(ctx.names)
            ctx.names = struct();
        end
        if ~isempty(policy.outputName)
            ctx.names.outputName = policy.outputName;
        end
    end
end

function report = appendNodeRun(report, node, policy, status, beforeStats, afterStats, durationSec, message)
    row = struct( ...
        'nodeId', char(string(getfielddefault(node,'id',''))), ...
        'nodeType', char(string(getfielddefault(node,'type',''))), ...
        'status', char(string(status)), ...
        'runPolicy', char(string(getfielddefault(policy,'runPolicy',''))), ...
        'existingPolicy', char(string(getfielddefault(policy,'existingPolicy',''))), ...
        'outputName', char(string(getfielddefault(policy,'outputName',''))), ...
        'durationSec', double(durationSec), ...
        'before', beforeStats, ...
        'after', afterStats, ...
        'message', char(string(message)));
    report.nodeRuns(end+1) = row; %#ok<AGROW>
end

function stats = captureContextStats(ctx)
    stats = struct('fovCount', 0, 'roiCount', 0, 'dataSeriesCount', 0, 'maskCount', 0);

    fovList = [];
    if isfield(ctx,'fovList') && ~isempty(ctx.fovList)
        fovList = ctx.fovList;
    else
        shallowObj = getShallowObject(ctx);
        if ~isempty(shallowObj)
            try
                fovList = shallowObj.fov;
            catch
            end
        end
    end
    try
        stats.fovCount = numel(fovList);
    catch
    end

    rois = [];
    if isfield(ctx,'roiList') && ~isempty(ctx.roiList)
        rois = ctx.roiList;
    elseif ~isempty(fovList)
        try
            rois = collectRoisFromProject(getShallowObject(ctx));
        catch
        end
    end
    try
        stats.roiCount = countValidRois(rois);
    catch
    end

    if isfield(ctx,'dataSeries') && ~isempty(ctx.dataSeries)
        try
            stats.dataSeriesCount = numel(ctx.dataSeries);
        catch
        end
    elseif ~isempty(rois)
        try
            stats.dataSeriesCount = numel(collectDataSeriesFromRois(rois));
        catch
        end
    end

    if isfield(ctx,'masks') && ~isempty(ctx.masks)
        try
            stats.maskCount = numel(ctx.masks);
        catch
        end
    end
end

function n = countValidRois(rois)
    n = 0;
    if isempty(rois)
        return;
    end
    n = numel(rois);
    try
        if n == 1 && isempty(rois(1).id)
            n = 0;
        end
    catch
    end
end

function summary = buildRunSummary(report)
    summary = struct('totalNodes', 0, 'doneNodes', 0, 'skippedNodes', 0, 'failedNodes', 0);
    if ~isfield(report,'nodeRuns') || isempty(report.nodeRuns)
        return;
    end
    statusList = {report.nodeRuns.status};
    summary.totalNodes = numel(statusList);
    summary.doneNodes = sum(strcmp(statusList, 'done'));
    summary.skippedNodes = sum(startsWith(string(statusList), "skipped"));
    summary.failedNodes = sum(strcmp(statusList, 'failed'));
end

function stashRunReport(report)
    try
        setappdata(0, 'DetecDivLastPipelineReport', report);
    catch
    end
end

function out = getFirstNonEmpty(varargin)
    out = '';
    for i = 1:numel(varargin)
        v = varargin{i};
        if isstring(v)
            v = char(string(v));
        end
        if ischar(v)
            if ~isempty(strtrim(v))
                out = v;
                return;
            end
        elseif ~isempty(v)
            out = v;
            return;
        end
    end
end

function out = ternary(cond, a, b)
    if cond
        out = a;
    else
        out = b;
    end
end

function policy = normalizeRunPolicy(policy)
    policy = lower(strtrim(char(string(policy))));
    switch policy
        case {'', 'resume', 'continue'}
            policy = 'resume';
        case {'restart', 'rerun', 'fresh'}
            policy = 'restart';
        otherwise
            policy = 'resume';
    end
end

function policy = normalizeExistingPolicy(policy, fallback)
    if nargin < 2 || isempty(fallback)
        fallback = 'replace';
    end
    policy = lower(strtrim(char(string(policy))));
    switch policy
        case {'', 'default'}
            policy = fallback;
        case {'replace', 'overwrite', 'reset'}
            policy = 'replace';
        case {'append', 'add'}
            policy = 'append';
        case {'skip', 'resume'}
            policy = 'skip';
        case {'error', 'fail'}
            policy = 'error';
        case {'upsert', 'merge'}
            policy = 'upsert';
        otherwise
            policy = fallback;
    end
end

function policy = normalizeCachePolicy(policy)
    policy = lower(strtrim(char(string(policy))));
    switch policy
        case {'', 'auto'}
            policy = 'auto';
        case {'memory', 'ram', 'keep'}
            policy = 'memory';
        case {'disk', 'reload', 'none'}
            policy = 'disk';
        otherwise
            policy = 'auto';
    end
end

function policy = defaultExistingPolicyForNode(nodeType)
    switch lower(char(string(nodeType)))
        case 'dataloader'
            policy = 'skip';
        case {'roiidentify','roipattern','roimanual','roigrid'}
            policy = 'replace';
        case 'roitracked'
            policy = 'upsert';
        case 'roiextract'
            policy = 'replace';
        case {'processor','classifier'}
            policy = 'replace';
        otherwise
            policy = 'replace';
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

    node = injectGlobalSelectionIntoNode(node, ctx);

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

function node = injectGlobalSelectionIntoNode(node, ctx)
    if ~isfield(node,'params') || ~isstruct(node.params)
        node.params = struct();
    end
    fovs = [];
    if isfield(ctx,'sel') && isstruct(ctx.sel) && isfield(ctx.sel,'fovs') && ~isempty(ctx.sel.fovs)
        fovs = normalizeIndexVectorLocal(ctx.sel.fovs);
    end
    if isempty(fovs)
        return;
    end

    nodeType = lower(char(string(getfielddefault(node,'type',''))));
    if any(strcmp(nodeType, {'roiidentify','roipattern','roimanual','roigrid','roiextract','roitracked'}))
        if ~isfield(node.params,'fovIndex') || isempty(node.params.fovIndex)
            node.params.fovIndex = fovs;
        end
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

function [missing, deferred] = missingParamsForNode(node, ctx, mode)
    missing = {};
    deferred = {};
    if nargin < 3 || isempty(mode)
        mode = 'run';
    end
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
        scope = paramScopeForNode(node, k);
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
        if strcmpi(mode, 'template') && strcmp(scope, 'run')
            deferred{end+1} = k; %#ok<AGROW>
        else
            missing{end+1} = k; %#ok<AGROW>
        end
    end
end

function scope = paramScopeForNode(node, paramName)
    scope = 'template';
    nodeType = lower(char(string(getfielddefault(node,'type',''))));
    paramName = lower(char(string(paramName)));

    switch nodeType
        case 'dataloader'
            if any(strcmp(paramName, {'path','positionfilter','channelfilter','stackfilter','label'}))
                scope = 'run';
            end
        case {'roipattern','roiidentify','roimanual','roigrid','roiextract','roitracked'}
            if any(strcmp(paramName, {'fovindex','roiindex','frames','channels','extractframes','extractchannels'}))
                scope = 'run';
            end
        case {'processor','classifier'}
            if any(strcmp(paramName, {'frames','channels','channel','outputname','out_dataseries_name'}))
                scope = 'run';
            end
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

function ctx = seedContextFromProject(ctx)
    ctx = syncCtxFromShallow(ctx);
    shallowObj = getShallowObject(ctx);
    if isempty(shallowObj)
        return;
    end

    selectedFovs = [];
    if isfield(ctx,'sel') && isstruct(ctx.sel) && isfield(ctx.sel,'fovs') && ~isempty(ctx.sel.fovs)
        selectedFovs = normalizeIndexVectorLocal(ctx.sel.fovs);
    end

    if isempty(selectedFovs)
        try
            ctx.fovList = shallowObj.fov;
        catch
        end
    else
        try
            idx = selectedFovs(selectedFovs >= 1 & selectedFovs <= numel(shallowObj.fov));
            ctx.fovList = shallowObj.fov(idx);
        catch
        end
    end

    if isfield(ctx,'fovList') && ~isempty(ctx.fovList)
        try
            ctx.channels = ctx.fovList(1).channel;
        catch
        end
    end

    srcLevel = getProjectInputSourceLevel(ctx);
    if srcLevel >= 2
        ctx.roiList = collectRoisFromFovList(getfielddefault(ctx,'fovList',[]));
    elseif (~isfield(ctx,'roiList') || isempty(ctx.roiList)) && shouldSeedFromProjectInputSource(ctx)
        ctx.roiList = collectRoisFromFovList(getfielddefault(ctx,'fovList',[]));
    end

    if srcLevel >= 3 && (~isfield(ctx,'masks') || isempty(ctx.masks))
        ctx.masks = inferMaskChannelsFromRois(getfielddefault(ctx,'roiList',[]));
    end

    if srcLevel >= 4 && (~isfield(ctx,'dataSeries') || isempty(ctx.dataSeries))
        ctx.dataSeries = collectDataSeriesFromRois(getfielddefault(ctx,'roiList',[]));
    end
end

function tf = shouldSeedFromProjectInputSource(ctx)
tf = false;
if ~isfield(ctx,'run') || ~isstruct(ctx.run) || ~isfield(ctx.run,'inputSource') || isempty(ctx.run.inputSource)
    return;
end
src = lower(char(string(ctx.run.inputSource)));
tf = contains(src, 'existing project');
end

function level = getProjectInputSourceLevel(ctx)
level = 0;
if ~isfield(ctx,'run') || ~isstruct(ctx.run) || ~isfield(ctx.run,'inputSource') || isempty(ctx.run.inputSource)
    return;
end
src = lower(char(string(ctx.run.inputSource)));
switch src
    case 'pipeline start (dataloader)'
        level = 0;
    case 'existing project fovs'
        level = 1;
    case 'existing rois'
        level = 2;
    case 'existing masks'
        level = 3;
    case 'existing dataseries'
        level = 4;
    otherwise
        if contains(src, 'existing project')
            level = 1;
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
    p = getfielddefault(node, 'params', struct());
    refProc = resolveProcessorReference(p);
    procObj = process(tempdir, 'pipeline_processor', randi(1e9));
    if ~isempty(refProc)
        procObj = applyProcessorReference(procObj, refProc);
    end
    if isfield(p,'modulePath') && ~isempty(p.modulePath)
        procObj.path = char(string(p.modulePath));
    end
    if isfield(p,'moduleId') && ~isempty(p.moduleId)
        procObj.strid = char(string(p.moduleId));
    end

    procFun = '';
    if ~isempty(pkgName)
        procFun = [pkgName '.process'];
    elseif isprop(procObj, 'processFun') && ~isempty(procObj.processFun)
        procFun = char(string(procObj.processFun));
    elseif isfield(node,'func') && ~isempty(node.func)
        procFun = char(string(node.func));
    end
    if isempty(procFun)
        error('runPipeline:ProcessorNoPackage', ...
            'Processor node %s is missing package/function information.', char(string(node.id)));
    end

    procObj.processFun = procFun;
    baseArg = struct();
    try
        if isprop(procObj, 'processArg') && isstruct(procObj.processArg)
            baseArg = procObj.processArg;
        end
    catch
    end
    procObj.processArg = mergeStruct(baseArg, p);
    procObj.strid = char(string(node.id));
    try
        procObj.runProfiles.process = struct( ...
            'io', getfielddefault(ctx, 'io', struct()), ...
            'store', getfielddefault(ctx, 'store', struct()), ...
            'run', getfielddefault(ctx, 'run', struct()));
    catch
    end

    procCtx = struct();
    p = procObj.processArg;
    procCtx.params = p;
    procCtx.run = getfielddefault(ctx, 'run', struct());
    procCtx.pipeline = getfielddefault(ctx, 'pipeline', struct());
    procCtx.io = getfielddefault(ctx, 'io', struct());
    procCtx.store = getfielddefault(ctx, 'store', struct());
    procCtx.executionPolicy = getfielddefault(ctx, 'executionPolicy', struct());
    if isfield(ctx,'names') && isstruct(ctx.names) && isfield(ctx.names,'outputName') && ~isempty(ctx.names.outputName)
        procCtx.outputName = ctx.names.outputName;
    elseif isfield(p,'outputName') && ~isempty(p.outputName)
        procCtx.outputName = p.outputName;
    end

    existingPolicy = normalizeExistingPolicy(getfielddefault(p,'existingPolicy','replace'), 'replace');
    if isfield(procCtx,'outputName') && ~isempty(procCtx.outputName)
        if any(strcmp(existingPolicy, {'skip','error'})) && roiOutputsExist(rois, char(string(procCtx.outputName)))
            if strcmp(existingPolicy, 'error')
                error('runPipeline:ProcessorOutputExists', ...
                    'Processor node %s output %s already exists.', ...
                    char(string(node.id)), char(string(procCtx.outputName)));
            end
            warning('runPipeline:ProcessorSkippedExisting', ...
                'Processor node %s skipped because output %s already exists.', ...
                char(string(node.id)), char(string(procCtx.outputName)));
            ctx.roiList = rois;
            ctx.dataSeries = collectDataSeriesFromRois(rois);
            ctx.channels = inferChannelsFromRois(rois, ctx);
            return;
        end
        if strcmp(existingPolicy, 'append') && roiOutputsExist(rois, char(string(procCtx.outputName)))
            error('runPipeline:ProcessorAppendOutputExists', ...
                ['Processor node %s uses append policy but output %s already exists. ' ...
                 'Choose another outputName to append side-by-side results.'], ...
                char(string(node.id)), char(string(procCtx.outputName)));
        end
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
    elseif strcmpi(char(string(pkgName)), 'cellposesam')
        args = [args {'GPU'}]; %#ok<AGROW>
    end

    try
        processData(procObj, rois, args{:});
    catch ME
        if strcmp(ME.identifier, 'runPipeline:Cancelled') || contains(lower(ME.message), 'cancelled by user')
            rethrow(ME);
        end
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
    p = getfielddefault(node, 'params', struct());
    refClassi = resolveClassifierReference(p);
    clsObj = classi(tempdir, 'pipeline_classifier', randi(1e9), 'InitTraining', false);
    clsObj.strid = char(string(node.id));

    if ~isempty(refClassi)
        clsObj = applyClassifierReference(clsObj, refClassi);
    end
    if isfield(p,'modulePath') && ~isempty(p.modulePath)
        clsObj.path = char(string(p.modulePath));
    end
    if isfield(p,'moduleId') && ~isempty(p.moduleId)
        clsObj.strid = char(string(p.moduleId));
    end

    if ~isempty(pkgName)
        clsObj.classifierPkg = pkgName;
        if isempty(clsObj.classifyFun)
            clsObj.classifyFun = [pkgName '.classify'];
        end
    elseif isfield(node,'func') && ~isempty(node.func)
        clsObj.classifyFun = char(string(node.func));
    elseif isempty(refClassi)
        error('runPipeline:ClassifierNoPackage', ...
            'Classifier node %s is missing package/function information.', char(string(node.id)));
    end

    if isfield(p,'classes') && ~isempty(p.classes)
        clsObj.classes = p.classes;
    end
    if isfield(p,'category') && ~isempty(p.category)
        clsObj.category = classiNormalizeCategory(p.category);
    end
    if isfield(p,'outputType') && ~isempty(p.outputType)
        clsObj.outputType = p.outputType;
    end
    try
        clsObj.runProfiles.classify = struct( ...
            'io', getfielddefault(ctx, 'io', struct()), ...
            'store', getfielddefault(ctx, 'store', struct()), ...
            'cancel', getfielddefault(ctx, 'cancel', struct()));
    catch
    end

    outputName = char(string(node.id));
    if isfield(ctx,'names') && isstruct(ctx.names) && isfield(ctx.names,'outputName') && ~isempty(ctx.names.outputName)
        outputName = char(string(ctx.names.outputName));
    elseif isfield(p,'outputName') && ~isempty(p.outputName)
        outputName = char(string(p.outputName));
    elseif isfield(p,'out_dataSeries_name') && ~isempty(p.out_dataSeries_name)
        outputName = char(string(p.out_dataSeries_name));
    end

    existingPolicy = normalizeExistingPolicy(getfielddefault(p,'existingPolicy','replace'), 'replace');
    if any(strcmp(existingPolicy, {'skip','error'})) && roiOutputsExist(rois, outputName)
        if strcmp(existingPolicy, 'error')
            error('runPipeline:ClassifierOutputExists', ...
                'Classifier node %s output %s already exists.', ...
                char(string(node.id)), outputName);
        end
        warning('runPipeline:ClassifierSkippedExisting', ...
            'Classifier node %s skipped because output %s already exists.', ...
            char(string(node.id)), outputName);
        ctx.roiList = rois;
        ctx.dataSeries = collectDataSeriesFromRois(rois);
        ctx.channels = inferChannelsFromRois(rois, ctx);
        ctx.masks = inferMaskChannelsFromRois(rois);
        return;
    end
    if strcmp(existingPolicy, 'append') && roiOutputsExist(rois, outputName)
        error('runPipeline:ClassifierAppendOutputExists', ...
            ['Classifier node %s uses append policy but output %s already exists. ' ...
             'Choose another outputName to append side-by-side results.'], ...
            char(string(node.id)), outputName);
    end

    args = {'OutputName', outputName};
    if isfield(p,'frames') && ~isempty(p.frames)
        args = [args {'Frames', p.frames}]; %#ok<AGROW>
    end
    selectedChannels = [];
    if isfield(p,'channel') && ~isempty(p.channel)
        selectedChannels = p.channel;
    elseif isfield(p,'channels') && ~isempty(p.channels)
        selectedChannels = p.channels;
    end
    if ~isempty(selectedChannels)
        ch = normalizeClassifierChannels(selectedChannels);
        args = [args {'Channel', ch}]; %#ok<AGROW>
    end
    if isfield(p,'parallel') && ~isempty(p.parallel) && logical(p.parallel)
        args = [args {'Parallel'}]; %#ok<AGROW>
    end
    classifierPkgForRun = '';
    try
        if isprop(clsObj, 'classifierPkg') && ~isempty(clsObj.classifierPkg)
            classifierPkgForRun = char(string(clsObj.classifierPkg));
        elseif ~isempty(pkgName)
            classifierPkgForRun = char(string(pkgName));
        end
    catch
    end
    if isfield(p,'gpu') && ~isempty(p.gpu) && logical(p.gpu)
        args = [args {'GPU'}]; %#ok<AGROW>
    elseif strcmpi(classifierPkgForRun, 'cellposesam')
        args = [args {'GPU'}]; %#ok<AGROW>
    end

    try
        classifyData(clsObj, rois, args{:});
    catch ME
        if strcmp(ME.identifier, 'runPipeline:Cancelled') || contains(lower(ME.message), 'cancelled by user')
            rethrow(ME);
        end
        error('runPipeline:NodeFailed','Node %s failed: %s', node.id, ME.message);
    end

    ctx.roiList = rois;
    ctx.dataSeries = collectDataSeriesFromRois(rois);
    ctx.channels = inferChannelsFromRois(rois, ctx);
    ctx.masks = inferMaskChannelsFromRois(rois);
end

function refClassi = resolveClassifierReference(p)
refClassi = [];
if ~isstruct(p) || isempty(fieldnames(p))
    return;
end

if isfield(p,'moduleVar') && ~isempty(p.moduleVar)
    varName = char(string(p.moduleVar));
    try
        cand = evalin('base', varName);
        if isa(cand, 'classi')
            if numel(cand) >= 1
                refClassi = cand(1);
                return;
            end
        end
    catch
    end
end

if isfield(p,'modulePath') && ~isempty(p.modulePath)
    refClassi = loadClassifierReferenceFromPath(p);
end
end

function clsObj = applyClassifierReference(clsObj, refClassi)
props = {'path','strid','description','category','channel','channelName','channelName2', ...
    'classes','classifyFun','trainingFun','classifierPkg','outputType','outputFun','outputArg','trainingParam','runProfiles'};
for i = 1:numel(props)
    name = props{i};
    try
        if isprop(refClassi, name)
            val = refClassi.(name);
            if ~isempty(val)
                clsObj.(name) = val;
            end
        end
    catch
    end
end
end

function refProc = resolveProcessorReference(p)
refProc = [];
if ~isstruct(p) || isempty(fieldnames(p))
    return;
end

if isfield(p,'moduleVar') && ~isempty(p.moduleVar)
    varName = char(string(p.moduleVar));
    try
        cand = evalin('base', varName);
        if isa(cand, 'process') && numel(cand) >= 1
            refProc = cand(1);
            return;
        end
    catch
    end
end

if isfield(p,'modulePath') && ~isempty(p.modulePath)
    refProc = loadProcessorReferenceFromPath(p);
end
end

function procObj = applyProcessorReference(procObj, refProc)
props = {'path','strid','description','category','processFun','processArg','runProfiles'};
for i = 1:numel(props)
    name = props{i};
    try
        if isprop(refProc, name)
            val = refProc.(name);
            if ~isempty(val)
                procObj.(name) = val;
            end
        end
    catch
    end
end
end

function refClassi = loadClassifierReferenceFromPath(p)
refClassi = [];
snap = resolveModuleSnapshotPath(p, 'classifier');
if isempty(snap) || exist(snap, 'file') ~= 2
    return;
end
try
    [refClassi, ~] = classiLoad(snap);
catch
    refClassi = [];
end
end

function refProc = loadProcessorReferenceFromPath(p)
refProc = [];
snap = resolveModuleSnapshotPath(p, 'processor');
if isempty(snap) || exist(snap, 'file') ~= 2
    return;
end
try
    [refProc, ~] = processLoad(snap);
catch
    refProc = [];
end
end

function snap = resolveModuleSnapshotPath(p, kind)
snap = '';
if ~isstruct(p) || ~isfield(p,'modulePath') || isempty(p.modulePath)
    return;
end
base = char(string(p.modulePath));
sid = '';
if isfield(p,'moduleId') && ~isempty(p.moduleId)
    sid = char(string(p.moduleId));
end
if isempty(sid)
    [~, sid] = fileparts(base);
end
switch lower(char(string(kind)))
    case 'classifier'
        snap = fullfile(base, [sid '_classification.mat']);
    case 'processor'
        snap = fullfile(base, [sid '_processor.mat']);
end
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
        if isfield(ctx,'fovList') && ~isempty(ctx.fovList)
            rois = collectRoisFromFovList(ctx.fovList);
        else
            shallowObj = getShallowObject(ctx);
            if ~isempty(shallowObj)
                rois = collectRoisFromProject(shallowObj);
            end
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

function rois = collectRoisFromFovList(fovList)
    rois = [];
    if isempty(fovList)
        return;
    end
    for i = 1:numel(fovList)
        try
            r = fovList(i).roi;
            if ~isempty(r)
                rois = [rois r(:)']; %#ok<AGROW>
            end
        catch
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

function vals = normalizeIndexVectorLocal(vals)
vals = double(vals(:)');
vals = vals(isfinite(vals));
vals = unique(round(vals), 'stable');
vals = vals(vals >= 1);
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

function tf = roiOutputsExist(rois, outputName)
    tf = false;
    if isempty(rois) || isempty(outputName)
        return;
    end
    outputName = char(string(outputName));
    probeNames = { ...
        outputName, ...
        ['results_' outputName], ...
        ['prob_' outputName], ...
        ['results_' outputName '_cell'], ...
        ['prob_' outputName '_cell']};

    for i = 1:numel(rois)
        try
            r = rois(i);
            if isempty(r.data)
                r.load('data');
            end
            if ~isempty(r.data)
                groupIds = arrayfun(@(x) char(string(x.groupid)), r.data, 'UniformOutput', false);
                if any(strcmp(groupIds, outputName))
                    tf = true;
                    return;
                end
            end
        catch
        end
        try
            names = {};
            if isfield(r.display,'channel') && ~isempty(r.display.channel)
                names = cellfun(@char, cellstr(string(r.display.channel)), 'UniformOutput', false);
            end
            if ~isempty(names)
                if any(cellfun(@(nm) any(strcmp(nm, probeNames)) || contains(nm, [outputName '_']), names))
                    tf = true;
                    return;
                end
            end
        catch
        end
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
