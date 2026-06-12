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

    % Use a per-invocation run id by default so progress checkpoints from
    % previous runs do not silently skip nodes.
    ctx = normalizeRunId(ctx);
    ctx = normalizeExecutionContext(ctx);
    ctx = normalizeRunEventLedger(ctx);
    pipelineRunEvent(ctx, 'run_start', 'Runner', 'runPipeline', ...
        'RunPolicy', getfielddefault(ctx.run, 'runPolicy', ''), ...
        'ExistingPolicy', getfielddefault(ctx.io, 'globalExistingPolicy', ''));
    ctx = preparePythonEnvironmentIfNeeded(pipe, ctx);
    ctx = seedContextFromProject(ctx);
    ctx = normalizeCancellationContext(ctx);
    checkPipelineCancelled(ctx, 'before pipeline validation');

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

    [pipe, bindingResolution] = pipelineResolveBindings(pipe, ctx, struct('allowGui', allowGui));

    [ok, report] = validatePipeline(pipe, ctx, struct('allowGui', allowGui));
    if ~ok
        error('runPipeline:Invalid','Pipeline validation failed: %s', strjoin(report.errors, ' | '));
    end
    report.bindingResolution = bindingResolution;
    report = initRunReport(report, ctx);
    ctx = initializePipelineProgress(ctx, report);
    checkPipelineCancelled(ctx, 'before pipeline run');

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

    if shouldUseRoiMajorExecution(report, nodeMap, ctx)
        [ctx, report] = executeRoiMajorPipeline(pipe, ctx, report, nodeMap, edges, allowGui);
        return;
    end

    executed = containers.Map();
    total = numel(report.order);
    for i = 1:numel(report.order)
        nodeId = report.order{i};
        node = nodeMap(nodeId);
        ctx = updatePipelineProgress(ctx, nodeId, i, total, 0, 1, ...
            sprintf('Node %d/%d: %s', i, total, nodeId));
        checkPipelineCancelled(ctx, ['before node ' nodeId]);

        % run-level parameter override (optional)
        node = applyRunNodeOverride(node, ctx, nodeId);
        [node, policy] = applyNodeExecutionPolicy(node, ctx);

        % run-level subset selection (optional)
        if shouldSkipByRunSelection(ctx, nodeId)
            report = appendNodeRun(report, node, policy, 'skipped_selection', ...
                captureContextStats(ctx), captureContextStats(ctx), 0, '');
            pipelineRunEvent(ctx, 'node_skipped', 'NodeId', nodeId, ...
                'NodeType', getfielddefault(node,'type',''), 'Status', 'skipped_selection');
            executed(nodeId) = true;
            continue;
        end

        % disabled nodes are always skipped
        if isfield(node,'enabled') && ~isempty(node.enabled) && ~logical(node.enabled)
            report = appendNodeRun(report, node, policy, 'skipped_disabled', ...
                captureContextStats(ctx), captureContextStats(ctx), 0, '');
            pipelineRunEvent(ctx, 'node_skipped', 'NodeId', nodeId, ...
                'NodeType', getfielddefault(node,'type',''), 'Status', 'skipped_disabled');
            executed(nodeId) = true;
            continue;
        end

        if shouldSkipNode(node, ctx, edges, executed)
            report = appendNodeRun(report, node, policy, 'skipped_condition', ...
                captureContextStats(ctx), captureContextStats(ctx), 0, '');
            pipelineRunEvent(ctx, 'node_skipped', 'NodeId', nodeId, ...
                'NodeType', getfielddefault(node,'type',''), 'Status', 'skipped_condition');
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
        ctx.progress.currentNodeId = nodeId;
        ctx.progress.currentNodeIndex = i;
        ctx.progress.totalNodes = total;
        ctx.progress.nodeStartTic = tic;

        if isa(pipe,'pipeline')
            pipe.runState.currentNode = nodeId;
            pipe.runState.progress = (i-1) / max(1,total);
        end

        beforeStats = captureContextStats(ctx);
        tNode = tic;
        try
            ctx = applyPolicyToContext(ctx, node, policy);
            checkPipelineCancelled(ctx, ['before executing node ' nodeId]);
            pipelineRunEvent(ctx, 'node_start', 'NodeId', nodeId, ...
                'NodeType', getfielddefault(node,'type',''), 'NodeIndex', i, ...
                'TotalNodes', total, 'RunPolicy', policy.runPolicy, ...
                'ExistingPolicy', policy.existingPolicy, 'OutputName', policy.outputName);
            ctx = executeNode(node, ctx);
            afterStats = captureContextStats(ctx);
            [nodeStatus, nodeMessage, ctx] = consumeNodeStatusOverride(ctx);
            report = appendNodeRun(report, node, policy, nodeStatus, ...
                beforeStats, afterStats, toc(tNode), nodeMessage);
            pipelineRunEvent(ctx, 'node_done', 'NodeId', nodeId, ...
                'NodeType', getfielddefault(node,'type',''), 'NodeIndex', i, ...
                'TotalNodes', total, 'Status', nodeStatus, ...
                'DurationSec', toc(tNode), 'Message', nodeMessage, ...
                'Before', beforeStats, 'After', afterStats);
        catch ME
            afterStats = captureContextStats(ctx);
            failedStatus = 'failed';
            if isPipelineCancelledException(ME)
                failedStatus = 'cancelled';
            end
            report = appendNodeRun(report, node, policy, failedStatus, ...
                beforeStats, afterStats, toc(tNode), formatNodeError(ME));
            pipelineRunEvent(ctx, ['node_' failedStatus], 'NodeId', nodeId, ...
                'NodeType', getfielddefault(node,'type',''), 'NodeIndex', i, ...
                'TotalNodes', total, 'Status', failedStatus, ...
                'DurationSec', toc(tNode), 'Message', formatNodeError(ME));
            report.endedAt = char(datetime('now'));
            report.summary = buildRunSummary(report);
            stashRunReport(report);
            if strcmp(failedStatus, 'cancelled')
                pipelineRunEvent(ctx, 'run_cancelled', 'Summary', report.summary, ...
                    'StartedAt', report.startedAt, 'EndedAt', report.endedAt, ...
                    'Message', formatNodeError(ME));
            else
                pipelineRunEvent(ctx, 'run_failed', 'Summary', report.summary, ...
                    'StartedAt', report.startedAt, 'EndedAt', report.endedAt, ...
                    'Message', formatNodeError(ME));
            end
            if isa(pipe,'pipeline')
                pipe.runState.status = failedStatus;
                pipe.runState.currentNode = nodeId;
                pipe.runState.errors = [pipe.runState.errors {formatNodeError(ME)}];
            end
            rethrow(ME);
        end

        executed(nodeId) = true;
        ctx = updatePipelineProgress(ctx, nodeId, i, total, 1, 1, ...
            sprintf('Completed node %d/%d: %s', i, total, nodeId));
        if isa(pipe,'pipeline')
            pipe.runState.progress = i / max(1,total);
        end
    end

    if isa(pipe,'pipeline')
        pipe.runState.status = 'done';
        pipe.runState.currentNode = '';
        pipe.log('Pipeline completed','Run');
    end
    report.endedAt = char(datetime('now'));
    report.summary = buildRunSummary(report);
    stashRunReport(report);
    ctx = updatePipelineProgress(ctx, '', total, total, 1, 1, 'Pipeline completed.');
    pipelineRunEvent(ctx, 'run_done', 'Summary', report.summary, ...
        'StartedAt', report.startedAt, 'EndedAt', report.endedAt);
end

function ctx = preparePythonEnvironmentIfNeeded(pipe, ctx)
if ~pipelineUsesPythonBackend(pipe, ctx)
    return;
end
cfg = resolvePythonPreflightConfig(ctx);
args = {'debug', true, 'mode', cfg.mode};
if strcmpi(cfg.mode, 'custom')
    args = [args {'envName', cfg.envName}]; %#ok<AGROW>
    if ~isempty(cfg.envPath)
        args = [args {'envPath', cfg.envPath}]; %#ok<AGROW>
    end
end
try
    info = select_and_load_conda_env(args{:});
catch ME
    if contains(ME.message, 'Unknown option "mode"')
        info = select_and_load_conda_env('debug', true);
    else
        rethrow(ME);
    end
end
if ~isfield(ctx,'exec') || ~isstruct(ctx.exec) || isempty(ctx.exec)
    ctx.exec = struct();
end
if ~isfield(ctx.exec,'python') || ~isstruct(ctx.exec.python) || isempty(ctx.exec.python)
    ctx.exec.python = struct();
end
ctx.exec.python = mergeStruct(ctx.exec.python, struct( ...
    'mode', cfg.mode, ...
    'envName', cfg.envName, ...
    'envPath', cfg.envPath, ...
    'preflight', true, ...
    'preflightDone', true, ...
    'info', info));
end

function cfg = resolvePythonPreflightConfig(ctx)
cfg = struct('mode', 'default', 'envName', '', 'envPath', '');
try
    if isfield(ctx,'exec') && isstruct(ctx.exec) && isfield(ctx.exec,'python') && isstruct(ctx.exec.python)
        py = ctx.exec.python;
        if isfield(py,'mode') && ~isempty(py.mode)
            cfg.mode = lower(char(string(py.mode)));
        end
        if isfield(py,'envName') && ~isempty(py.envName)
            cfg.envName = char(string(py.envName));
        end
        if isfield(py,'envPath') && ~isempty(py.envPath)
            cfg.envPath = char(string(py.envPath));
        end
    end
catch
end
if ~any(strcmp(cfg.mode, {'default','custom'}))
    cfg.mode = 'default';
end
end

function tf = pipelineUsesPythonBackend(pipe, ctx)
tf = false;
P = pipelineToStructLocal(pipe);
nodes = getfielddefault(P, 'nodes', struct([]));
if isempty(nodes)
    return;
end
selectedIds = {};
try
    if isfield(ctx,'run') && isstruct(ctx.run) && isfield(ctx.run,'selectedNodes') && ~isempty(ctx.run.selectedNodes)
        selectedIds = cellstr(ctx.run.selectedNodes(:));
    end
catch
end
for i = 1:numel(nodes)
    node = nodes(i);
    try
        if ~isempty(selectedIds) && ~any(strcmp(selectedIds, char(string(node.id))))
            continue;
        end
    catch
    end
    if isPythonBackedNode(node)
        tf = true;
        return;
    end
end
end

function tf = isPythonBackedNode(node)
tf = false;
pkg = lower(strtrim(char(string(resolveNodePackage(node)))));
func = '';
try
    func = lower(strtrim(char(string(getfielddefault(node, 'func', '')))));
catch
end
if any(strcmp(pkg, {'cellposesam','yoloseg','celltracktr'}))
    tf = true;
    return;
end
if contains(func, 'cellpose') || contains(func, 'yolo') || contains(func, 'tracktr') || contains(func, 'python')
    tf = true;
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
    if ~isfield(ctx.run,'gpuPolicy') || isempty(ctx.run.gpuPolicy)
        if isfield(ctx,'exec') && isstruct(ctx.exec) && isfield(ctx.exec,'gpuPolicy') && ~isempty(ctx.exec.gpuPolicy)
            ctx.run.gpuPolicy = ctx.exec.gpuPolicy;
        else
            ctx.run.gpuPolicy = 'module_default';
        end
    end
    ctx.run.gpuPolicy = normalizeGpuPolicy(ctx.run.gpuPolicy);

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
    if ~isfield(ctx.io,'persistOutputs') || isempty(ctx.io.persistOutputs)
        ctx.io.persistOutputs = true;
    else
        ctx.io.persistOutputs = logical(ctx.io.persistOutputs);
    end
    if ~isfield(ctx.io,'saveMode') || isempty(ctx.io.saveMode)
        ctx.io.saveMode = 'immediate';
    end
    ctx.io.saveMode = normalizeSaveMode(ctx.io.saveMode);
    if ~isfield(ctx.io,'deferredSave') || isempty(ctx.io.deferredSave)
        ctx.io.deferredSave = strcmp(ctx.io.saveMode, 'defer');
    else
        ctx.io.deferredSave = logical(ctx.io.deferredSave);
        if ctx.io.deferredSave
            ctx.io.saveMode = 'defer';
        end
    end

    if ~isfield(ctx,'resume') || isempty(ctx.resume)
        ctx.resume = ctx.run.resume;
    end
    if ~isfield(ctx,'saveProgress') || isempty(ctx.saveProgress)
        ctx.saveProgress = true;
    end
    if ~isfield(ctx,'exec') || ~isstruct(ctx.exec) || isempty(ctx.exec)
        ctx.exec = struct();
    end
    ctx.exec.gpuPolicy = ctx.run.gpuPolicy;

    if ~isfield(ctx.sel,'fovs') || isempty(ctx.sel.fovs)
        if isfield(ctx.run,'fovIndex') && ~isempty(ctx.run.fovIndex)
            ctx.sel.fovs = normalizeIndexVectorLocal(ctx.run.fovIndex);
        else
            ctx.sel.fovs = [];
        end
    else
        ctx.sel.fovs = normalizeIndexVectorLocal(ctx.sel.fovs);
    end

    if ~isfield(ctx.sel,'frames') || isempty(ctx.sel.frames)
        if isfield(ctx.run,'frames') && ~isempty(ctx.run.frames)
            ctx.sel.frames = normalizeIndexVectorLocal(ctx.run.frames);
        else
            ctx.sel.frames = [];
        end
    else
        ctx.sel.frames = normalizeIndexVectorLocal(ctx.sel.frames);
    end

    if ~isfield(ctx.sel,'rois') || isempty(ctx.sel.rois)
        if isfield(ctx.run,'rois') && ~isempty(ctx.run.rois)
            ctx.sel.rois = normalizeIndexVectorLocal(ctx.run.rois);
        else
            ctx.sel.rois = [];
        end
    else
        ctx.sel.rois = normalizeIndexVectorLocal(ctx.sel.rois);
    end
end

function ctx = normalizeRunEventLedger(ctx)
    if ~isstruct(ctx)
        ctx = struct();
    end
    if ~isfield(ctx,'run') || ~isstruct(ctx.run)
        ctx.run = struct();
    end
    if ~isfield(ctx,'io') || ~isstruct(ctx.io)
        ctx.io = struct();
    end
    if ~isfield(ctx,'store') || ~isstruct(ctx.store)
        ctx.store = struct();
    end
    eventLogPath = getFirstNonEmpty( ...
        getfielddefault(ctx.run,'eventLogPath',''), ...
        getfielddefault(ctx.io,'eventLogPath',''), ...
        getfielddefault(ctx.store,'eventLogPath',''));
    if isempty(eventLogPath)
        runPath = getFirstNonEmpty( ...
            getfielddefault(ctx.run,'path',''), ...
            getfielddefault(ctx.run,'runPath',''), ...
            getfielddefault(ctx.store,'runPath',''));
        if ~isempty(runPath)
            eventLogPath = fullfile(char(string(runPath)), 'run_events.jsonl');
        end
    end
    if ~isempty(eventLogPath)
        ctx.run.eventLogPath = char(string(eventLogPath));
        ctx.io.eventLogPath = char(string(eventLogPath));
        ctx.store.eventLogPath = char(string(eventLogPath));
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

function [status, message, ctx] = consumeNodeStatusOverride(ctx)
    status = 'done';
    message = '';
    try
        if isfield(ctx, 'pipeline') && isstruct(ctx.pipeline)
            if isfield(ctx.pipeline, 'nodeStatusOverride') && ~isempty(ctx.pipeline.nodeStatusOverride)
                status = char(string(ctx.pipeline.nodeStatusOverride));
                ctx.pipeline = rmfield(ctx.pipeline, 'nodeStatusOverride');
            end
            if isfield(ctx.pipeline, 'nodeMessage') && ~isempty(ctx.pipeline.nodeMessage)
                message = char(string(ctx.pipeline.nodeMessage));
                ctx.pipeline = rmfield(ctx.pipeline, 'nodeMessage');
            end
        end
    catch
        status = 'done';
        message = '';
    end
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
    summary.cancelledNodes = sum(strcmp(statusList, 'cancelled'));
end

function stashRunReport(report)
    try
        setappdata(0, 'DetecDivLastPipelineReport', report);
    catch
    end
end

function tf = isPipelineCancelledException(ME)
    tf = false;
    try
        ids = string(ME.identifier);
        for iCause = 1:numel(ME.cause)
            ids(end+1) = string(ME.cause{iCause}.identifier); %#ok<AGROW>
        end
        tf = any(strcmp(ids, "runPipeline:Cancelled")) || contains(string(ME.message), "cancelled by user", 'IgnoreCase', true);
    catch
        tf = strcmp(ME.identifier, 'runPipeline:Cancelled');
    end
end

function ctx = normalizeCancellationContext(ctx)
    if ~isfield(ctx,'cancel') || ~isstruct(ctx.cancel) || isempty(ctx.cancel)
        ctx.cancel = struct();
    end
    if ~isfield(ctx.cancel,'tokenFile')
        ctx.cancel.tokenFile = '';
    end
end

function ctx = initializePipelineProgress(ctx, report)
    if ~isfield(ctx,'progress') || ~isstruct(ctx.progress) || isempty(ctx.progress)
        ctx.progress = struct();
    end
    ctx.progress.startedTic = tic;
    ctx.progress.totalNodes = numel(report.order);
    ctx.progress.currentNodeIndex = 0;
    ctx.progress.currentNodeId = '';
end

function checkPipelineCancelled(ctx, where)
    if nargin < 2
        where = 'pipeline run';
    end
    requested = false;
    tokenFile = '';
    try
        if isfield(ctx,'cancel') && isstruct(ctx.cancel) && isfield(ctx.cancel,'tokenFile') && ~isempty(ctx.cancel.tokenFile)
            tokenFile = char(string(ctx.cancel.tokenFile));
            requested = exist(tokenFile, 'file') == 2;
        end
    catch
        requested = false;
    end
    try
        if isfield(ctx,'progressDlg') && ~isempty(ctx.progressDlg) && isvalid(ctx.progressDlg) ...
                && isprop(ctx.progressDlg, 'CancelRequested') && ctx.progressDlg.CancelRequested
            requested = true;
            if ~isempty(tokenFile) && exist(tokenFile, 'file') ~= 2
                fid = fopen(tokenFile, 'w');
                if fid > 0
                    fprintf(fid, 'cancel requested at %s\n', char(datetime('now')));
                    fclose(fid);
                end
            end
        end
    catch
    end
    if requested
        error('runPipeline:Cancelled', 'Pipeline run cancelled by user at %s.', char(string(where)));
    end
end

function ctx = updatePipelineProgress(ctx, nodeId, nodeIndex, totalNodes, subIndex, subTotal, message)
    if nargin < 7 || isempty(message)
        message = 'Pipeline running...';
    end
    if nargin < 6 || isempty(subTotal) || subTotal <= 0
        subTotal = 1;
    end
    if nargin < 5 || isempty(subIndex)
        subIndex = 0;
    end
    totalNodes = max(1, totalNodes);
    frac = max(0, min(1, (max(0, nodeIndex - 1) + max(0, min(1, subIndex ./ subTotal))) ./ totalNodes));
    etaText = '';
    try
        if isfield(ctx,'progress') && isstruct(ctx.progress) && isfield(ctx.progress,'startedTic')
            elapsed = toc(ctx.progress.startedTic);
            if frac > 0.02
                eta = elapsed * (1 - frac) / frac;
                etaText = sprintf(' | ETA %s', formatDurationShort(eta));
            end
        end
    catch
    end
    try
        if isfield(ctx,'progressDlg') && ~isempty(ctx.progressDlg) && isvalid(ctx.progressDlg)
            ctx.progressDlg.Indeterminate = 'off';
            ctx.progressDlg.Value = frac;
            ctx.progressDlg.Message = sprintf('%s%s', char(string(message)), etaText);
            drawnow limitrate;
        end
    catch
    end
    try
        ctx.progress.currentNodeId = char(string(nodeId));
        ctx.progress.currentNodeIndex = nodeIndex;
        ctx.progress.totalNodes = totalNodes;
        ctx.progress.value = frac;
        ctx.progress.message = char(string(message));
    catch
    end
end

function txt = formatDurationShort(secondsValue)
    secondsValue = max(0, double(secondsValue));
    if secondsValue < 60
        txt = sprintf('%ds', round(secondsValue));
    elseif secondsValue < 3600
        txt = sprintf('%dm%02ds', floor(secondsValue/60), round(mod(secondsValue,60)));
    else
        txt = sprintf('%dh%02dm', floor(secondsValue/3600), floor(mod(secondsValue,3600)/60));
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

function mode = normalizeSaveMode(mode)
    mode = lower(strtrim(char(string(mode))));
    switch mode
        case {'defer','deferred','roi','roi_final','roi_finalized','final','finalized','memory'}
            mode = 'defer';
        otherwise
            mode = 'immediate';
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
                throwNodeFailed(node, ME);
            end
        case 'roiidentify'
            try
                ctx = roiIdentify.process(ctx);
            catch ME
                throwNodeFailed(node, ME);
            end
        case 'roipattern'
            try
                ctx = roiPattern.process(ctx);
            catch ME
                throwNodeFailed(node, ME);
            end
        case 'roimanual'
            try
                ctx = roiManual.process(ctx);
            catch ME
                throwNodeFailed(node, ME);
            end
        case 'roigrid'
            try
                ctx = roiGrid.process(ctx);
            catch ME
                throwNodeFailed(node, ME);
            end
        case 'roitracked'
            try
                ctx = roiTracked.process(ctx);
            catch ME
                throwNodeFailed(node, ME);
            end
        case 'roiextract'
            try
                ctx = roiExtract.process(ctx);
            catch ME
                throwNodeFailed(node, ME);
            end
        case 'processor'
            ctx = executeProcessorNode(node, ctx);
        case 'classifier'
            ctx = executeClassifierNode(node, ctx);
        otherwise
            try
                fun = resolveNodeFunc(node);
                ctx = feval(fun, ctx);
            catch ME
                throwNodeFailed(node, ME);
            end
    end

    % optional output coherence check
    ctx = ensureOutputs(node, ctx);
end

function tf = shouldUseRoiMajorExecution(report, nodeMap, ctx)
    tf = false;
    try
        if isfield(ctx,'run') && isstruct(ctx.run) && isfield(ctx.run,'executionMode') && ~isempty(ctx.run.executionMode)
            mode = lower(strtrim(char(string(ctx.run.executionMode))));
            if any(strcmp(mode, {'node','node_major','node-major','legacy'}))
                return;
            end
            if any(strcmp(mode, {'roi','roi_major','roi-major','roi_finalized','roi-finalized'}))
                tf = true;
            end
        end
        ids = report.order;
        if isempty(ids)
            tf = false;
            return;
        end
        activeTypes = {};
        for i = 1:numel(ids)
            node = nodeMap(ids{i});
            if shouldSkipByRunSelection(ctx, ids{i})
                continue;
            end
            if isfield(node,'enabled') && ~isempty(node.enabled) && ~logical(node.enabled)
                continue;
            end
            activeTypes{end+1} = lower(char(string(getfielddefault(node,'type','')))); %#ok<AGROW>
        end
        if isempty(activeTypes)
            tf = false;
            return;
        end
        tf = all(ismember(activeTypes, {'classifier','processor'}));
    catch
        tf = false;
    end
end

function [ctx, report] = executeRoiMajorPipeline(pipe, ctx, report, nodeMap, edges, allowGui)
    ids = report.order;
    ids = ids(:)';
    totalNodes = numel(ids);

    firstNode = [];
    for i = 1:totalNodes
        if isKey(nodeMap, ids{i})
            candidate = nodeMap(ids{i});
            if shouldSkipByRunSelection(ctx, ids{i})
                continue;
            end
            if isfield(candidate,'enabled') && ~isempty(candidate.enabled) && ~logical(candidate.enabled)
                continue;
            end
            firstNode = candidate;
            break;
        end
    end
    if isempty(firstNode)
        error('runPipeline:RoiMajorNoActiveNode', 'ROI-major execution has no active classifier/processor node.');
    end

    rois = selectRoisForNode(ctx, firstNode);
    if isempty(rois)
        error('runPipeline:RoiMajorNoROI', 'ROI-major execution requires at least one selected ROI.');
    end

    nRoi = numel(rois);
    nodeStats = repmat(struct( ...
        'node', [], 'policy', [], 'durationSec', 0, ...
        'done', 0, 'skipped', 0, 'message', '', ...
        'before', [], 'after', []), 1, totalNodes);

    for i = 1:totalNodes
        node = nodeMap(ids{i});
        node = applyRunNodeOverride(node, ctx, ids{i});
        [node, policy] = applyNodeExecutionPolicy(node, ctx);
        nodeStats(i).node = node;
        nodeStats(i).policy = policy;
        nodeStats(i).before = captureContextStats(ctx);
    end

    disp(sprintf('[runPipeline] ROI-major execution enabled: %d node(s), %d ROI(s).', totalNodes, nRoi));
    pipelineRunEvent(ctx, 'run_mode', 'ExecutionMode', 'roi_major', ...
        'TotalNodes', totalNodes, 'TotalRois', nRoi);
    for r = 1:nRoi
        checkPipelineCancelled(ctx, sprintf('before ROI %d/%d', r, nRoi));
        roiCtx = ctx;
        roiCtx.roiList = rois(r);
        roiCtx.io.saveMode = 'defer';
        roiCtx.io.deferredSave = true;
        roiCtx.io.cachePolicy = 'memory';
        roiCtx.store.cacheMode = 'memory';
        roiCtx.run.executionMode = 'roi_major';

        executed = containers.Map();
        for i = 1:totalNodes
            nodeId = ids{i};
            node = nodeStats(i).node;
            policy = nodeStats(i).policy;
            roiCtx = updatePipelineProgress(roiCtx, nodeId, i, totalNodes, r-1, nRoi, ...
                sprintf('ROI %d/%d, node %d/%d: %s', r, nRoi, i, totalNodes, nodeId));
            checkPipelineCancelled(roiCtx, sprintf('before ROI %d node %s', r, nodeId));

            if shouldSkipByRunSelection(roiCtx, nodeId)
                nodeStats(i).skipped = nodeStats(i).skipped + 1;
                executed(nodeId) = true;
                continue;
            end
            if isfield(node,'enabled') && ~isempty(node.enabled) && ~logical(node.enabled)
                nodeStats(i).skipped = nodeStats(i).skipped + 1;
                executed(nodeId) = true;
                continue;
            end
            if shouldSkipNode(node, roiCtx, edges, executed)
                nodeStats(i).skipped = nodeStats(i).skipped + 1;
                executed(nodeId) = true;
                continue;
            end

            [missing, ~] = missingParamsForNode(node, roiCtx, 'run');
            if ~isempty(missing)
                if allowGui && hasNodeGui(node)
                    error('runPipeline:RoiMajorGuiRequired', ...
                        'Node %s still requires GUI parameters during ROI-major execution: %s', ...
                        nodeId, strjoin(missing, ', '));
                end
                error('runPipeline:MissingParams', ...
                    'Node %s missing params: %s', nodeId, strjoin(missing, ', '));
            end

            roiCtx.pipeline = struct('currentNode', nodeId, 'nodeType', node.type);
            roiCtx = applyNodeParams(roiCtx, node);
            roiCtx.progress.currentNodeId = nodeId;
            roiCtx.progress.currentNodeIndex = i;
            roiCtx.progress.totalNodes = totalNodes;
            roiCtx.progress.roiIndex = r;
            roiCtx.progress.totalRois = nRoi;
            roiCtx.progress.nodeStartTic = tic;

            if isa(pipe,'pipeline')
                pipe.runState.currentNode = sprintf('%s ROI %d/%d', nodeId, r, nRoi);
                pipe.runState.progress = ((r-1) + (i-1)/max(1,totalNodes)) / max(1,nRoi);
            end

            tNode = tic;
            try
                roiCtx = applyPolicyToContext(roiCtx, node, policy);
                roiCtx.io.saveMode = 'defer';
                roiCtx.io.deferredSave = true;
                roiCtx.io.cachePolicy = 'memory';
                roiCtx.store.cacheMode = 'memory';
                if r == 1
                    pipelineRunEvent(roiCtx, 'node_start', 'NodeId', nodeId, ...
                        'NodeType', getfielddefault(node,'type',''), 'NodeIndex', i, ...
                        'TotalNodes', totalNodes, 'RunPolicy', policy.runPolicy, ...
                        'ExistingPolicy', policy.existingPolicy, 'OutputName', policy.outputName, ...
                        'ExecutionMode', 'roi_major', 'TotalRois', nRoi);
                end
                roiCtx = executeNode(node, roiCtx);
                [nodeStatus, nodeMessage, roiCtx] = consumeNodeStatusOverride(roiCtx);
                nodeStats(i).durationSec = nodeStats(i).durationSec + toc(tNode);
                if startsWith(string(nodeStatus), "skipped")
                    nodeStats(i).skipped = nodeStats(i).skipped + 1;
                else
                    nodeStats(i).done = nodeStats(i).done + 1;
                end
                if ~isempty(nodeMessage)
                    nodeStats(i).message = nodeMessage;
                end
            catch ME
                nodeStats(i).durationSec = nodeStats(i).durationSec + toc(tNode);
                nodeStats(i).after = captureContextStats(roiCtx);
                status = 'failed';
                if isPipelineCancelledException(ME)
                    status = 'cancelled';
                end
                report = appendNodeRun(report, node, policy, status, ...
                    nodeStats(i).before, nodeStats(i).after, nodeStats(i).durationSec, formatNodeError(ME));
                pipelineRunEvent(roiCtx, ['node_' status], 'NodeId', nodeId, ...
                    'NodeType', getfielddefault(node,'type',''), 'NodeIndex', i, ...
                    'TotalNodes', totalNodes, 'Status', status, ...
                    'ExecutionMode', 'roi_major', 'RoiIndex', r, 'TotalRois', nRoi, ...
                    'DurationSec', nodeStats(i).durationSec, 'Message', formatNodeError(ME));
                report.endedAt = char(datetime('now'));
                report.summary = buildRunSummary(report);
                stashRunReport(report);
                if strcmp(status, 'cancelled')
                    pipelineRunEvent(roiCtx, 'run_cancelled', 'Summary', report.summary, ...
                        'StartedAt', report.startedAt, 'EndedAt', report.endedAt, ...
                        'Message', formatNodeError(ME));
                else
                    pipelineRunEvent(roiCtx, 'run_failed', 'Summary', report.summary, ...
                        'StartedAt', report.startedAt, 'EndedAt', report.endedAt, ...
                        'Message', formatNodeError(ME));
                end
                if isa(pipe,'pipeline')
                    pipe.runState.status = status;
                    pipe.runState.currentNode = nodeId;
                    pipe.runState.errors = [pipe.runState.errors {formatNodeError(ME)}];
                end
                rethrow(ME);
            end

            executed(nodeId) = true;
        end

        saveFinalizedRoiLocal(rois(r), roiCtx);
        try
            ctx.store = roiCtx.store;
        catch
        end
        ctx = updatePipelineProgress(ctx, '', totalNodes, totalNodes, r, nRoi, ...
            sprintf('Finalized ROI %d/%d', r, nRoi));
    end

    ctx.roiList = rois;
    ctx.dataSeries = collectDataSeriesFromRois(rois);
    ctx.channels = inferChannelsFromRois(rois, ctx);
    ctx.masks = inferMaskChannelsFromRois(rois);
    for i = 1:totalNodes
        nodeStats(i).after = captureContextStats(ctx);
        status = 'done';
        if nodeStats(i).done == 0 && nodeStats(i).skipped > 0
            status = 'skipped_existing';
        end
        msg = sprintf('ROI-major: %d ROI(s) finalized; %d executed, %d skipped. Save is deferred until each ROI is complete.', ...
            nRoi, nodeStats(i).done, nodeStats(i).skipped);
        if ~isempty(nodeStats(i).message)
            msg = sprintf('%s Last node message: %s', msg, nodeStats(i).message);
        end
        report = appendNodeRun(report, nodeStats(i).node, nodeStats(i).policy, status, ...
            nodeStats(i).before, nodeStats(i).after, nodeStats(i).durationSec, msg);
        pipelineRunEvent(ctx, 'node_done', 'NodeId', getfielddefault(nodeStats(i).node,'id',''), ...
            'NodeType', getfielddefault(nodeStats(i).node,'type',''), 'NodeIndex', i, ...
            'TotalNodes', totalNodes, 'Status', status, 'ExecutionMode', 'roi_major', ...
            'TotalRois', nRoi, 'DurationSec', nodeStats(i).durationSec, ...
            'Message', msg, 'Before', nodeStats(i).before, 'After', nodeStats(i).after);
    end

    if isa(pipe,'pipeline')
        pipe.runState.status = 'done';
        pipe.runState.currentNode = '';
        pipe.runState.progress = 1;
        pipe.log('Pipeline completed in ROI-major mode','Run');
    end
    report.endedAt = char(datetime('now'));
    report.summary = buildRunSummary(report);
    stashRunReport(report);
    ctx = updatePipelineProgress(ctx, '', totalNodes, totalNodes, 1, 1, 'Pipeline completed.');
    pipelineRunEvent(ctx, 'run_done', 'Summary', report.summary, ...
        'StartedAt', report.startedAt, 'EndedAt', report.endedAt, ...
        'ExecutionMode', 'roi_major');
end

function saveFinalizedRoiLocal(roiobj, ctx)
    dirty = struct('data', false, 'image', false);
    try
        if isstruct(roiobj.results) && isfield(roiobj.results, 'pipelineDeferredDirty') && isstruct(roiobj.results.pipelineDeferredDirty)
            dirty = roiobj.results.pipelineDeferredDirty;
            if isfield(roiobj.results, 'pipelineDeferredDirty')
                roiobj.results = rmfield(roiobj.results, 'pipelineDeferredDirty');
            end
        end
    catch
    end

    if ~isfield(dirty,'data'), dirty.data = false; end
    if ~isfield(dirty,'image'), dirty.image = false; end
    if ~dirty.data && roiHasSavableDataseriesLocal(roiobj)
        dirty.data = true;
    end

    if isMemoryOnlyOutputRunLocal(ctx)
        disp(sprintf('[runPipeline] Final ROI save skipped for ROI %s: memory-only output mode.', safeRoiIdForRunLocal(roiobj)));
        return;
    end

    if dirty.image
        try
            roiobj.save;
            disp(sprintf('[runPipeline] Final ROI save: image+data for ROI %s.', safeRoiIdForRunLocal(roiobj)));
        catch ME
            error('runPipeline:RoiFinalSaveFailed', ...
                'Final save failed for ROI %s: %s', safeRoiIdForRunLocal(roiobj), ME.message);
        end
    elseif dirty.data
        try
            didSave = roiobj.save('data');
            if ~didSave
                error('runPipeline:NoDataSaved', 'No savable dataseries was found.');
            end
            disp(sprintf('[runPipeline] Final ROI save: data for ROI %s.', safeRoiIdForRunLocal(roiobj)));
        catch ME
            error('runPipeline:RoiFinalSaveFailed', ...
                'Final data save failed for ROI %s: %s', safeRoiIdForRunLocal(roiobj), ME.message);
        end
    else
        disp(sprintf('[runPipeline] Final ROI save skipped: no deferred output for ROI %s.', safeRoiIdForRunLocal(roiobj)));
    end

    try
        if isfield(ctx,'io') && isstruct(ctx.io) && isfield(ctx.io,'cachePolicy') && strcmp(ctx.io.cachePolicy, 'disk')
            roiobj.clear;
        end
    catch
    end
end

function tf = isMemoryOnlyOutputRunLocal(ctx)
    tf = false;
    try
        if isfield(ctx,'io') && isstruct(ctx.io) && isfield(ctx.io,'persistOutputs') && ...
                ~isempty(ctx.io.persistOutputs) && ~logical(ctx.io.persistOutputs)
            tf = true;
            return;
        end
    catch
    end
    try
        if isfield(ctx,'run') && isstruct(ctx.run) && isfield(ctx.run,'smokeTest') && ~isempty(ctx.run.smokeTest)
            tf = true;
        end
    catch
    end
end

function tf = roiHasSavableDataseriesLocal(roiobj)
    tf = false;
    try
        d = roiobj.data;
        if isempty(d)
            return;
        end
        if isa(d,'dataseries')
            for k = 1:numel(d)
                try
                    if ~isempty(d(k).groupid)
                        tf = true;
                        return;
                    end
                catch
                end
            end
        else
            tf = true;
        end
    catch
        tf = false;
    end
end

function roiId = safeRoiIdForRunLocal(roiobj)
    roiId = '<unknown>';
    try
        roiId = char(string(roiobj.id));
    catch
    end
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

function throwNodeFailed(node, ME)
    nodeId = char(string(getfielddefault(node, 'id', '<unknown>')));
    wrapped = MException('runPipeline:NodeFailed', ...
        'Node %s failed: %s', nodeId, formatNodeError(ME));
    wrapped = addCause(wrapped, ME);
    throw(wrapped);
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
    ctx = updateGlobalSelectionFromNodeParams(ctx, node);

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

function ctx = updateGlobalSelectionFromNodeParams(ctx, node)
    if ~isfield(ctx,'sel') || ~isstruct(ctx.sel) || isempty(ctx.sel)
        ctx.sel = struct();
    end
    if ~isfield(node,'params') || ~isstruct(node.params) || isempty(node.params)
        return;
    end

    nodeType = lower(char(string(getfielddefault(node,'type',''))));
    if supportsInheritedFrames(nodeType)
        if isfield(node.params,'frames') && ~isempty(node.params.frames) ...
                && isnumeric(node.params.frames) && ~isequal(node.params.frames, -1)
            ctx.sel.frames = normalizeIndexVectorLocal(node.params.frames);
        end
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
    else
        nodeType = lower(char(string(getfielddefault(node,'type',''))));
        if strcmp(nodeType, 'dataloader')
            node.params.positionIdx = fovs;
        elseif any(strcmp(nodeType, {'roiidentify','roipattern','roimanual','roigrid','roiextract','roitracked'}))
            node.params.fovIndex = fovs;
        end
    end

    frames = [];
    if isfield(ctx,'sel') && isstruct(ctx.sel) && isfield(ctx.sel,'frames') && ~isempty(ctx.sel.frames)
        frames = normalizeIndexVectorLocal(ctx.sel.frames);
    end
    if ~isempty(frames)
        nodeType = lower(char(string(getfielddefault(node,'type',''))));
        if supportsInheritedFrames(nodeType)
            node.params.frames = frames;
        end
    end
end

function tf = supportsInheritedFrames(nodeType)
tf = any(strcmp(nodeType, {'dataloader','roiidentify','roipattern','roimanual','roigrid','roitracked','roiextract','processor','classifier'}));
end

function policy = normalizeGpuPolicy(policy)
policy = lower(strtrim(char(string(policy))));
switch policy
    case {'', '<module default>', 'module default', 'default', 'module_default'}
        policy = 'module_default';
    case {'force gpu', 'gpu', 'true', '1', 'on', 'force_gpu'}
        policy = 'force_gpu';
    case {'force cpu', 'cpu', 'false', '0', 'off', 'force_cpu'}
        policy = 'force_cpu';
    otherwise
        policy = 'module_default';
end
end

function [gpuDecision, hasGpuDecision] = resolveEffectiveGpuDecision(p, ctx, pkgName)
gpuDecision = false;
hasGpuDecision = false;

runPolicy = 'module_default';
try
    if isfield(ctx,'run') && isstruct(ctx.run) && isfield(ctx.run,'gpuPolicy') && ~isempty(ctx.run.gpuPolicy)
        runPolicy = normalizeGpuPolicy(ctx.run.gpuPolicy);
    end
catch
end

switch runPolicy
    case 'force_gpu'
        gpuDecision = true;
        hasGpuDecision = true;
        return;
    case 'force_cpu'
        gpuDecision = false;
        hasGpuDecision = true;
        return;
end

if isstruct(p) && isfield(p,'gpu') && ~isempty(p.gpu)
    [gpuDecision, hasGpuDecision] = gpuDecisionFromExecutionValue(p.gpu);
    if hasGpuDecision
        return;
    end
end

if isstruct(p) && isfield(p,'executionEnvironment') && ~isempty(p.executionEnvironment)
    [gpuDecision, hasGpuDecision] = gpuDecisionFromExecutionValue(p.executionEnvironment);
    if hasGpuDecision
        return;
    end
end

if isstruct(p) && isfield(p,'execution_environment') && ~isempty(p.execution_environment)
    [gpuDecision, hasGpuDecision] = gpuDecisionFromExecutionValue(p.execution_environment);
    if hasGpuDecision
        return;
    end
end

pkgName = lower(strtrim(char(string(pkgName))));
if strcmp(pkgName, 'cellposesam')
    gpuDecision = true;
    hasGpuDecision = true;
end
end

function [gpuDecision, hasGpuDecision] = gpuDecisionFromExecutionValue(v)
hasGpuDecision = false;
gpuDecision = false;
if islogical(v)
    gpuDecision = logical(v);
    hasGpuDecision = true;
    return;
end
if isnumeric(v)
    if isempty(v) || ~isscalar(v) || ~isfinite(double(v))
        return;
    end
    gpuDecision = logical(v ~= 0);
    hasGpuDecision = true;
    return;
end
s = lower(strtrim(char(string(v))));
s = strrep(s, '-', '_');
s = strrep(s, ' ', '_');
switch s
    case {'gpu','force_gpu','multi_gpu'}
        gpuDecision = true;
        hasGpuDecision = true;
    case {'cpu','force_cpu'}
        gpuDecision = false;
        hasGpuDecision = true;
    otherwise
        hasGpuDecision = false;
end
end

function tf = logicalizeGpuValue(v)
if islogical(v)
    tf = logical(v);
    return;
end
if isnumeric(v)
    tf = logical(v ~= 0);
    return;
end
s = lower(strtrim(char(string(v))));
tf = any(strcmp(s, {'1','true','yes','on','gpu','force gpu'}));
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
    condEdges = condEdges(arrayfun(@(e)isExecutionEdgeCondition(e.condition), condEdges));
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

function tf = isExecutionEdgeCondition(condition)
tf = false;
try
    condition = lower(strtrim(char(string(condition))));
catch
    return;
end
if isempty(condition)
    return;
end
tf = ~any(strcmp(condition, {'resourcebinding','binding','symbolicbinding'}));
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
    scope = pipelineParamScope(node, paramName);
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
        ctx.roiList = collectRoisForContextSelection(ctx, getfielddefault(ctx,'fovList',[]));
    elseif (~isfield(ctx,'roiList') || isempty(ctx.roiList)) && shouldSeedFromProjectInputSource(ctx)
        ctx.roiList = collectRoisForContextSelection(ctx, getfielddefault(ctx,'fovList',[]));
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
    case {'existing rois', 'existing project rois'}
        level = 2;
    case {'existing masks', 'existing project masks'}
        level = 3;
    case {'existing dataseries', 'existing project dataseries'}
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
    ensureProcessorPackagePath(node, p, ctx);
    refProc = resolveProcessorReference(node, p, ctx);
    procObj = process('', 'pipeline_processor', randi(1e9));
    if ~isempty(refProc)
        procObj = applyProcessorReference(procObj, refProc);
    end
    if isfield(p,'modulePath') && ~isempty(p.modulePath)
        refInfoForPath = resolveNodeModuleReference(node, p, 'processor', ctx);
        if isstruct(refInfoForPath) && isfield(refInfoForPath,'modulePath') && ~isempty(refInfoForPath.modulePath)
            procObj.path = char(string(refInfoForPath.modulePath));
        else
            procObj.path = char(string(p.modulePath));
        end
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
    p = injectPipelineRuntimeParams(p, ctx);
    p = mapNodeRuntimePathParams(node, p, ctx);
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
    procCtx.cancel = getfielddefault(ctx, 'cancel', struct());
    procCtx.progress = getfielddefault(ctx, 'progress', struct());
    if isfield(ctx,'progressDlg') && ~isempty(ctx.progressDlg)
        procCtx.progressDlg = ctx.progressDlg;
    end
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
            ctx.roiList = rois;
            ctx.dataSeries = collectDataSeriesFromRois(rois);
            ctx.channels = inferChannelsFromRois(rois, ctx);
            ctx.pipeline.nodeStatusOverride = 'skipped_existing';
            ctx.pipeline.nodeMessage = sprintf('Output %s already exists.', char(string(procCtx.outputName)));
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
    if isfield(ctx,'progressDlg') && ~isempty(ctx.progressDlg)
        args = [args {'Progress', ctx.progressDlg}]; %#ok<AGROW>
    end
    if isfield(p,'frames') && ~isempty(p.frames)
        args = [args {'Frames', p.frames}]; %#ok<AGROW>
    end
    if isfield(p,'parallel') && ~isempty(p.parallel) && logical(p.parallel)
        args = [args {'Parallel'}]; %#ok<AGROW>
    end
    [gpuDecision, hasGpuDecision] = resolveEffectiveGpuDecision(p, ctx, pkgName);
    if hasGpuDecision && gpuDecision
        args = [args {'GPU'}]; %#ok<AGROW>
    end

    try
        checkPipelineCancelled(ctx, ['before processor ' char(string(node.id))]);
        processData(procObj, rois, args{:});
    catch ME
        throwNodeFailed(node, ME);
    end

    ctx.roiList = rois;
    ctx.dataSeries = collectDataSeriesFromRois(rois);
    ctx.channels = inferChannelsFromRois(rois, ctx);
end

function ensureProcessorPackagePath(node, p, ctx)
    roots = {};
    customPackageRoot = getNodeCustomPackageField(node, p, 'customPackageRoot');
    customPackageDir = getNodeCustomPackageField(node, p, 'customPackageDir');
    if ~isempty(customPackageRoot)
        roots{end+1} = resolveNodeRelativeRuntimePath(customPackageRoot, ctx); %#ok<AGROW>
    end
    if ~isempty(customPackageDir)
        packageDir = resolveNodeRelativeRuntimePath(customPackageDir, ctx);
        if exist(packageDir, 'dir') == 7
            roots{end+1} = fileparts(packageDir); %#ok<AGROW>
        else
            [mappedPackageDir, mapped] = mapModulePathToServerPath(packageDir, ctx);
            if mapped || exist(mappedPackageDir, 'dir') == 7
                roots{end+1} = fileparts(mappedPackageDir); %#ok<AGROW>
            end
        end
    end
    roots = unique(roots, 'stable');
    for i = 1:numel(roots)
        root = roots{i};
        if isempty(root)
            continue;
        end
        [mappedRoot, mapped] = mapModulePathToServerPath(root, ctx);
        if mapped || exist(mappedRoot, 'dir') == 7
            root = mappedRoot;
        end
        if exist(root, 'dir') ~= 7
            continue;
        end
        try
            if ~contains(path, root)
                addpath(root);
                rehash;
            end
        catch ME
            warning('runPipeline:ProcessorPackagePath', ...
                'Could not add custom package root for processor node %s: %s', ...
                char(string(getfielddefault(node, 'id', ''))), ME.message);
        end
    end
end

function value = getNodeCustomPackageField(node, p, fieldName)
value = '';
if isstruct(node) && isfield(node, fieldName) && ~isempty(node.(fieldName))
    value = char(string(node.(fieldName)));
elseif isstruct(p) && isfield(p, fieldName) && ~isempty(p.(fieldName))
    value = char(string(p.(fieldName)));
end
end

function p = mapNodeRuntimePathParams(node, p, ctx)
    if ~isstruct(p)
        return;
    end
    fields = fieldnames(p);
    explicitKeys = explicitPathParamKeys(node);
    for i = 1:numel(fields)
        name = fields{i};
        if ~any(strcmp(explicitKeys, name)) && ~isPathLikeParamName(name)
            continue;
        end
        value = p.(name);
        if ~(ischar(value) || (isstring(value) && isscalar(value)))
            continue;
        end
        text = char(string(value));
        if isempty(strtrim(text))
            continue;
        end
        text = resolveNodeRelativeRuntimePath(text, ctx);
        [mappedText, mapped] = mapModulePathToServerPath(text, ctx);
        if mapped
            p.(name) = mappedText;
        else
            p.(name) = text;
        end
    end
end

function pathOut = resolveNodeRelativeRuntimePath(pathIn, ctx)
pathOut = char(string(pathIn));
if isempty(pathOut) || isAbsolutePathLocal(pathOut)
    return;
end
if ~contains(pathOut, '/') && ~contains(pathOut, '\')
    return;
end
bases = {};
try
    if isfield(ctx,'pipelineRef') && isstruct(ctx.pipelineRef) && isfield(ctx.pipelineRef,'path') && ~isempty(ctx.pipelineRef.path)
        bases{end+1} = char(string(ctx.pipelineRef.path)); %#ok<AGROW>
    end
catch
end
try
    if isfield(ctx,'templatePath') && ~isempty(ctx.templatePath)
        bases{end+1} = char(string(ctx.templatePath)); %#ok<AGROW>
    end
catch
end
try
    if isfield(ctx,'run') && isstruct(ctx.run)
        runPath = getfielddefault(ctx.run, 'runPath', getfielddefault(ctx.run, 'path', ''));
        if ~isempty(runPath)
            bases{end+1} = char(string(runPath)); %#ok<AGROW>
        end
    end
catch
end
for i = 1:numel(bases)
    base = bases{i};
    if exist(base, 'file') == 2
        base = fileparts(base);
    end
    if exist(base, 'dir') ~= 7
        continue;
    end
    candidate = fullfile(base, pathOut);
    if exist(candidate, 'dir') == 7 || exist(candidate, 'file') == 2 || canCreateParentPath(candidate)
        pathOut = candidate;
        return;
    end
end
end

function tf = canCreateParentPath(pathIn)
tf = false;
try
    parent = fileparts(char(string(pathIn)));
    tf = ~isempty(parent) && (exist(parent, 'dir') == 7 || mkdir(parent));
catch
    tf = false;
end
end

function keys = explicitPathParamKeys(node)
keys = {};
try
    contract = pipelineNodeContract(node);
catch
    contract = struct();
end
if isstruct(contract) && isfield(contract, 'parameters') && isstruct(contract.parameters) ...
        && isfield(contract.parameters, 'paths') && ~isempty(contract.parameters.paths)
    keys = cellstr(string(contract.parameters.paths(:)));
end
keys = unique(keys, 'stable');
end

function tf = isPathLikeParamName(name)
    key = lower(char(string(name)));
    tf = contains(key, 'path') || contains(key, 'folder') || ...
        strcmp(key, 'outputdir') || strcmp(key, 'custompackagedir') || ...
        strcmp(key, 'custompackageroot') || endsWith(key, 'dir') || endsWith(key, 'root');
end

function p = injectPipelineRuntimeParams(p, ctx)
    if ~isstruct(p)
        return;
    end
    runId = getfielddefault(ctx, 'runId', '');
    if isempty(runId) && isfield(ctx, 'run') && isstruct(ctx.run)
        runId = getfielddefault(ctx.run, 'runId', '');
    end
    if ~isempty(runId) && (~isfield(p, 'runId') || isempty(p.runId))
        p.runId = char(string(runId));
    end

    runPath = '';
    if isfield(ctx, 'store') && isstruct(ctx.store)
        runPath = getfielddefault(ctx.store, 'runPath', '');
    end
    if isempty(runPath) && isfield(ctx, 'run') && isstruct(ctx.run)
        runPath = getfielddefault(ctx.run, 'runPath', '');
        if isempty(runPath), runPath = getfielddefault(ctx.run, 'path', ''); end
    end
    if ~isempty(runPath) && (~isfield(p, 'runPath') || isempty(p.runPath))
        p.runPath = char(string(runPath));
    end

    projectPath = getfielddefault(ctx, 'projectPath', '');
    if isempty(projectPath) && isfield(ctx, 'run') && isstruct(ctx.run)
        projectPath = getfielddefault(ctx.run, 'projectPath', '');
    end
    if isempty(projectPath) && isfield(ctx, 'io') && isstruct(ctx.io)
        projectPath = getfielddefault(ctx.io, 'projectPath', '');
    end
    if ~isempty(projectPath) && (~isfield(p, 'projectPath') || isempty(p.projectPath))
        p.projectPath = char(string(projectPath));
    end

    projectFolder = projectFolderFromRuntimeContext(ctx);
    if isempty(projectFolder)
        return;
    end
    if isfield(p, 'outputDir') && isEmptyPathValue(p.outputDir)
        p.outputDir = projectFolder;
    end
    if isfield(p, 'outputFolder') && isEmptyPathValue(p.outputFolder)
        p.outputFolder = projectFolder;
    end
end

function tf = isEmptyPathValue(value)
tf = false;
if ischar(value) || (isstring(value) && isscalar(value))
    tf = isempty(strtrim(char(string(value))));
end
end

function folder = projectFolderFromRuntimeContext(ctx)
folder = '';
projectPath = getfielddefault(ctx, 'projectPath', '');
if isempty(projectPath) && isfield(ctx, 'run') && isstruct(ctx.run)
    projectPath = getfielddefault(ctx.run, 'projectPath', '');
end
if isempty(projectPath) && isfield(ctx, 'io') && isstruct(ctx.io)
    projectPath = getfielddefault(ctx.io, 'projectPath', '');
end
if isempty(projectPath) && isfield(ctx, 'targetRef') && isstruct(ctx.targetRef)
    projectPath = getfielddefault(ctx.targetRef, 'projectPath', '');
end
folder = projectFolderFromProjectPath(projectPath);
end

function folder = projectFolderFromProjectPath(projectPath)
folder = '';
if isempty(projectPath)
    return;
end
projectPath = char(string(projectPath));
if exist(projectPath, 'dir') == 7
    folder = projectPath;
    return;
end
[pth, name, ext] = fileparts(projectPath);
if strcmpi(ext, '.mat')
    candidate = fullfile(pth, name);
    if exist(candidate, 'dir') == 7
        folder = candidate;
    elseif exist(pth, 'dir') == 7
        folder = pth;
    end
elseif exist(pth, 'dir') == 7
    folder = pth;
end
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
    refClassi = resolveClassifierReference(node, p, ctx);
    clsObj = classi('', 'pipeline_classifier', randi(1e9), 'InitTraining', false);
    clsObj.strid = char(string(node.id));

    if ~isempty(refClassi)
        clsObj = applyClassifierReference(clsObj, refClassi);
    end
    if isfield(p,'modulePath') && ~isempty(p.modulePath)
        refInfoForPath = resolveNodeModuleReference(node, p, 'classifier', ctx);
        if isstruct(refInfoForPath) && isfield(refInfoForPath,'modulePath') && ~isempty(refInfoForPath.modulePath)
            clsObj.path = char(string(refInfoForPath.modulePath));
        else
            clsObj.path = char(string(p.modulePath));
        end
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
    if isfield(p,'description') && ~isempty(p.description)
        desc = p.description;
        if ischar(desc) || isstring(desc)
            desc = {char(desc)};
        end
        clsObj.description = desc;
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
            'cancel', getfielddefault(ctx, 'cancel', struct()), ...
            'progress', getfielddefault(ctx, 'progress', struct()));
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
        ctx.roiList = rois;
        ctx.dataSeries = collectDataSeriesFromRois(rois);
        ctx.channels = inferChannelsFromRois(rois, ctx);
        ctx.masks = inferMaskChannelsFromRois(rois);
        ctx.pipeline.nodeStatusOverride = 'skipped_existing';
        ctx.pipeline.nodeMessage = sprintf('Output %s already exists.', outputName);
        return;
    end
    if strcmp(existingPolicy, 'append') && roiOutputsExist(rois, outputName)
        error('runPipeline:ClassifierAppendOutputExists', ...
            ['Classifier node %s uses append policy but output %s already exists. ' ...
             'Choose another outputName to append side-by-side results.'], ...
            char(string(node.id)), outputName);
    end

    [ctx, classifierForRun, classifierCNNForRun] = resolveRuntimeClassifierCache(ctx, clsObj, node);

    args = {'OutputName', outputName, 'Ctx', ctx};
    if ~isempty(classifierForRun)
        args = [args {'Classifier', classifierForRun}]; %#ok<AGROW>
    end
    if ~isempty(classifierCNNForRun)
        args = [args {'ClassifierCNN', classifierCNNForRun}]; %#ok<AGROW>
    end
    if isfield(ctx,'progressDlg') && ~isempty(ctx.progressDlg)
        args = [args {'Progress', ctx.progressDlg}]; %#ok<AGROW>
    end
    if isfield(p,'frames') && ~isempty(p.frames)
        args = [args {'Frames', p.frames}]; %#ok<AGROW>
    end
    selectedChannels = [];
    if isfield(p,'channel') && ~isempty(p.channel)
        selectedChannels = p.channel;
    elseif isfield(p,'channels') && ~isempty(p.channels)
        selectedChannels = p.channels;
    elseif isfield(p,'channelName') && ~isempty(p.channelName)
        selectedChannels = p.channelName;
    elseif isprop(clsObj, 'channelName') && ~isempty(clsObj.channelName)
        selectedChannels = clsObj.channelName;
    end
    if ~isempty(selectedChannels)
        ch = normalizeClassifierChannels(selectedChannels);
        args = [args {'Channel', ch}]; %#ok<AGROW>
    end
    if isfield(p,'parallel') && ~isempty(p.parallel) && logical(p.parallel)
        args = [args {'Parallel'}]; %#ok<AGROW>
    end
    classifierPkgForRun = pkgName;
    try
        if isprop(clsObj, 'classifierPkg') && ~isempty(clsObj.classifierPkg)
            classifierPkgForRun = char(string(clsObj.classifierPkg));
        end
    catch
    end
    [gpuDecision, hasGpuDecision] = resolveEffectiveGpuDecision(p, ctx, classifierPkgForRun);
    if hasGpuDecision && gpuDecision
        args = [args {'GPU'}]; %#ok<AGROW>
    end

    try
        checkPipelineCancelled(ctx, ['before classifier ' char(string(node.id))]);
        classifyData(clsObj, rois, args{:});
    catch ME
        throwNodeFailed(node, ME);
    end

    ctx.roiList = rois;
    ctx.dataSeries = collectDataSeriesFromRois(rois);
    ctx.channels = inferChannelsFromRois(rois, ctx);
    ctx.masks = inferMaskChannelsFromRois(rois);
end

function refClassi = resolveClassifierReference(node, p, ctx)
refClassi = [];
if ~isstruct(p) || isempty(fieldnames(p))
    p = struct();
end
if nargin < 3 || ~isstruct(ctx)
    ctx = struct();
end

refInfo = resolveNodeModuleReference(node, p, 'classifier', ctx);
if ~isempty(refInfo)
    refClassi = loadClassifierReferenceFromPath(refInfo);
    if ~isempty(refClassi)
        return;
    end
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

function [ctx, classifierForRun, classifierCNNForRun] = resolveRuntimeClassifierCache(ctx, clsObj, node)
classifierForRun = [];
classifierCNNForRun = [];
try
    nodeId = char(string(getfielddefault(node,'id',clsObj.strid)));
    key = matlab.lang.makeValidName(nodeId);
    auxKey = matlab.lang.makeValidName([nodeId '_classifierCNN']);
    if ~isfield(ctx,'store') || ~isstruct(ctx.store) || isempty(ctx.store)
        ctx.store = struct();
    end
    if ~isfield(ctx.store,'classifierRuntime') || ~isstruct(ctx.store.classifierRuntime)
        ctx.store.classifierRuntime = struct();
    end
    if isfield(ctx.store.classifierRuntime, key) && ~isempty(ctx.store.classifierRuntime.(key))
        classifierForRun = ctx.store.classifierRuntime.(key);
    else
        if isprop(clsObj,'classifier') && ~isempty(clsObj.classifier)
            classifierForRun = clsObj.classifier;
        else
            try
                classifierForRun = clsObj.loadClassifier('force');
            catch
                classifierForRun = [];
            end
        end
        if ~isempty(classifierForRun)
            ctx.store.classifierRuntime.(key) = classifierForRun;
        end
    end
    if isfield(ctx.store.classifierRuntime, auxKey) && ~isempty(ctx.store.classifierRuntime.(auxKey))
        classifierCNNForRun = ctx.store.classifierRuntime.(auxKey);
    elseif shouldCacheAuxiliaryClassifierCNN(clsObj, node)
        classifierCNNForRun = loadAuxiliaryClassifierCNN(clsObj);
        if ~isempty(classifierCNNForRun)
            ctx.store.classifierRuntime.(auxKey) = classifierCNNForRun;
        end
    end
catch
    classifierForRun = [];
    classifierCNNForRun = [];
end
end

function tf = shouldCacheAuxiliaryClassifierCNN(clsObj, node)
tf = false;
try
    if isfield(node, 'params') && isstruct(node.params) && isfield(node.params, 'outputMode') && ~isempty(node.params.outputMode)
        outputMode = lower(strrep(strtrim(char(string(node.params.outputMode))), '-', '_'));
        outputMode = strrep(outputMode, ' ', '_');
        if any(strcmp(outputMode, {'lstm','lstm_only','primary'}))
            return;
        end
    end
    pkg = lower(strtrim(char(string(resolveNodePackage(node)))));
    fun = '';
    if isprop(clsObj,'classifyFun') && ~isempty(clsObj.classifyFun)
        fun = lower(strtrim(char(string(clsObj.classifyFun))));
    elseif isfield(node,'func') && ~isempty(node.func)
        fun = lower(strtrim(char(string(node.func))));
    end
    tf = strcmp(pkg, 'cnn_lstm') || contains(fun, 'cnn_lstm') || contains(fun, 'lstm');
catch
    tf = false;
end
end

function classifierCNN = loadAuxiliaryClassifierCNN(clsObj)
classifierCNN = [];
try
    if ~isprop(clsObj,'path') || isempty(clsObj.path) || ~isprop(clsObj,'strid') || isempty(clsObj.strid)
        return;
    end
    filePath = fullfile(char(string(clsObj.path)), ['netCNN_' char(string(clsObj.strid)) '.mat']);
    if exist(filePath, 'file') ~= 2
        return;
    end
    S = load(filePath);
    fields = {'classifier','netCNN','net'};
    for i = 1:numel(fields)
        if isfield(S, fields{i}) && ~isempty(S.(fields{i}))
            classifierCNN = S.(fields{i});
            return;
        end
    end
    names = fieldnames(S);
    if ~isempty(names)
        classifierCNN = S.(names{1});
    end
catch
    classifierCNN = [];
end
end

function refProc = resolveProcessorReference(node, p, ctx)
refProc = [];
if ~isstruct(p) || isempty(fieldnames(p))
    p = struct();
end
if nargin < 3 || ~isstruct(ctx)
    ctx = struct();
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

refInfo = resolveNodeModuleReference(node, p, 'processor', ctx);
if ~isempty(refInfo)
    refProc = loadProcessorReferenceFromPath(refInfo);
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
    refClassi = loadClassifierSnapshotStrictLocal(snap);
catch
    refClassi = [];
end
end

function classiObj = loadClassifierSnapshotStrictLocal(filePath)
classiObj = [];
if isempty(filePath) || exist(filePath, 'file') ~= 2
    return;
end
S = load(filePath);
if isfield(S, 'classiObj') && isa(S.classiObj, 'classi')
    classiObj = S.classiObj;
else
    names = fieldnames(S);
    for ii = 1:numel(names)
        cand = S.(names{ii});
        if isa(cand, 'classi')
            classiObj = cand;
            break;
        end
    end
end
if isempty(classiObj) || ~isa(classiObj, 'classi')
    classiObj = [];
    return;
end
if numel(classiObj) > 1
    [~, expectedId] = fileparts(filePath);
    expectedId = regexprep(expectedId, '_classification$', '');
    ids = arrayfun(@(x) char(string(x.strid)), classiObj, 'UniformOutput', false);
    match = find(strcmp(ids, expectedId), 1, 'first');
    if isempty(match)
        match = 1;
    end
    classiObj = classiObj(match);
end
try
    [pth, file] = fileparts(filePath);
    file = regexprep(file, '_classification$', '');
    if ispc
        pth = [pth '\'];
    else
        pth = [pth '/'];
    end
    classiObj.setPath(pth, file);
catch
end
try
    classiObj.category = classiNormalizeCategory(classiObj.category);
catch
end
try
    if isprop(classiObj, 'run') && isstruct(classiObj.run) && isfield(classiObj.run, 'active')
        classiObj.run.active = false;
    end
    classiObj.runNormalizePaths();
catch
end
try
    classiObj.syncDatasetFromLegacy();
    classiObj.syncLegacyFromDataset();
catch
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

function refInfo = resolveNodeModuleReference(node, p, kind, ctx)
refInfo = struct();
if nargin < 2 || ~isstruct(p) || isempty(p)
    p = struct();
end
if nargin < 4 || ~isstruct(ctx)
    ctx = struct();
end
if isfield(p,'modulePath') && ~isempty(p.modulePath)
    refInfo = p;
    refInfo = absolutizeModuleReferencePath(refInfo, ctx);
    return;
end
if ~isstruct(node) || ~isfield(node,'origin') || ~isstruct(node.origin)
    refInfo = [];
    return;
end
origin = node.origin;
originKind = char(string(getfielddefault(origin, 'kind', '')));
if ~strcmpi(originKind, kind)
    refInfo = [];
    return;
end
originPath = char(string(getfielddefault(origin, 'path', '')));
originId = char(string(getfielddefault(origin, 'id', '')));
if isempty(originPath)
    refInfo = [];
    return;
end
refInfo = p;
refInfo.modulePath = originPath;
if ~isempty(originId)
    refInfo.moduleId = originId;
end
refInfo.moduleKind = kind;
refInfo = absolutizeModuleReferencePath(refInfo, ctx);
end

function refInfo = absolutizeModuleReferencePath(refInfo, ctx)
if ~isstruct(refInfo) || ~isfield(refInfo,'modulePath') || isempty(refInfo.modulePath)
    return;
end
modulePath = char(string(refInfo.modulePath));
if ~ispc && looksLikeWindowsAbsPath(modulePath)
    [mappedPath, mapped] = mapModulePathToServerPath(modulePath, ctx);
    if mapped && (exist(mappedPath, 'dir') == 7 || exist(mappedPath, 'file') == 2)
        refInfo.modulePath = mappedPath;
        return;
    end
    moduleId = '';
    moduleKind = '';
    try
        if isfield(refInfo,'moduleId') && ~isempty(refInfo.moduleId)
            moduleId = char(string(refInfo.moduleId));
        end
    catch
    end
    try
        if isfield(refInfo,'moduleKind') && ~isempty(refInfo.moduleKind)
            moduleKind = char(string(refInfo.moduleKind));
        end
    catch
    end
    recovered = recoverServerModulePath(modulePath, moduleId, moduleKind, ctx);
    if ~isempty(recovered)
        refInfo.modulePath = recovered;
        return;
    end
end
if isAbsolutePathLocal(modulePath)
    if exist(modulePath, 'dir') == 7 || exist(modulePath, 'file') == 2
        refInfo.modulePath = modulePath;
        return;
    end
    refInfo.modulePath = modulePath;
    return;
end

bases = {};
try
    if isfield(ctx,'pipelineRef') && isstruct(ctx.pipelineRef) && isfield(ctx.pipelineRef,'path') && ~isempty(ctx.pipelineRef.path)
        bases{end+1} = char(string(ctx.pipelineRef.path)); %#ok<AGROW>
    end
catch
end
try
    if isfield(ctx,'templatePath') && ~isempty(ctx.templatePath)
        bases{end+1} = char(string(ctx.templatePath)); %#ok<AGROW>
    end
catch
end

for i = 1:numel(bases)
    base = bases{i};
    if isempty(base)
        continue;
    end
    if exist(base, 'file') == 2
        base = fileparts(base);
    end
    if exist(base, 'dir') ~= 7
        continue;
    end
    candidate = fullfile(base, modulePath);
    if exist(candidate, 'dir') == 7 || exist(candidate, 'file') == 2
        refInfo.modulePath = candidate;
        return;
    end
end
end

function tf = looksLikeWindowsAbsPath(p)
tf = false;
if isempty(p)
    return;
end
p = char(string(p));
tf = ~isempty(regexp(p, '^[A-Za-z]:[\\/]', 'once')) || startsWith(p, '\\');
end

function [mappedPath, mapped] = mapModulePathToServerPath(pathIn, ctx)
    [mappedPath, mapped] = detecdiv_paths_map_module_path(pathIn, ctx, 'server');
end

function mappings = modulePathMappings(ctx)
    mappings = detecdiv_paths_module_mappings(ctx);
end

function mappings = uniqueModulePathMappings(mappings)
if isempty(mappings)
    return;
end
keep = true(1, numel(mappings));
seen = {};
for i = 1:numel(mappings)
    if ~isfield(mappings(i), 'localRoot') || ~isfield(mappings(i), 'remoteRoot')
        keep(i) = false;
        continue;
    end
    localRoot = lower(regexprep(strrep(char(string(mappings(i).localRoot)), '/', '\'), '[\\\/]+$', ''));
    remoteRoot = lower(regexprep(strrep(char(string(mappings(i).remoteRoot)), '\', '/'), '[\/]+$', ''));
    key = [localRoot '|' remoteRoot];
    if isempty(localRoot) || isempty(remoteRoot) || any(strcmp(seen, key))
        keep(i) = false;
    else
        seen{end+1} = key; %#ok<AGROW>
    end
end
mappings = mappings(keep);
end

function recovered = recoverServerModulePath(modulePath, moduleId, moduleKind, ctx)
recovered = '';
if nargin < 2 || isempty(moduleId)
    [~, moduleId] = fileparts(char(string(modulePath)));
end
moduleId = char(string(moduleId));
moduleKind = lower(char(string(moduleKind)));

roots = {};
try
    if isfield(ctx,'targetRef') && isstruct(ctx.targetRef) && isfield(ctx.targetRef,'projectPath') && ~isempty(ctx.targetRef.projectPath)
        projectPath = char(string(ctx.targetRef.projectPath));
        roots{end+1} = projectPath; %#ok<AGROW>
        roots{end+1} = fileparts(projectPath); %#ok<AGROW>
        roots{end+1} = fullfile(fileparts(projectPath), 'tmpProject'); %#ok<AGROW>
    end
catch
end
try
    if isfield(ctx,'pipelineRef') && isstruct(ctx.pipelineRef) && isfield(ctx.pipelineRef,'path') && ~isempty(ctx.pipelineRef.path)
        roots{end+1} = char(string(ctx.pipelineRef.path)); %#ok<AGROW>
    end
catch
end
try
    [mappedPath, mapped] = mapModulePathToServerPath(modulePath, ctx);
    if mapped && ~isempty(mappedPath)
        roots{end+1} = mappedPath; %#ok<AGROW>
        roots{end+1} = fileparts(mappedPath); %#ok<AGROW>
        roots{end+1} = fileparts(fileparts(mappedPath)); %#ok<AGROW>
    end
catch
end
roots = unique(roots(~cellfun(@isempty, roots)), 'stable');

candidateDirs = {};
for i = 1:numel(roots)
    root = roots{i};
    if exist(root, 'dir') ~= 7
        continue;
    end
    if strcmp(moduleKind, 'classifier')
        candidateDirs{end+1} = fullfile(root, moduleId); %#ok<AGROW>
        candidateDirs{end+1} = fullfile(root, 'classifiers', moduleId); %#ok<AGROW>
        candidateDirs{end+1} = fullfile(root, 'classification', moduleId); %#ok<AGROW>
        candidateDirs{end+1} = fullfile(root, 'ClassiRepository', moduleId); %#ok<AGROW>
        candidateDirs{end+1} = fullfile(root, 'assets', 'classification', moduleId); %#ok<AGROW>
        candidateDirs{end+1} = fullfile(root, 'tmpProject', 'classification', moduleId); %#ok<AGROW>
    else
        candidateDirs{end+1} = fullfile(root, moduleId); %#ok<AGROW>
        candidateDirs{end+1} = fullfile(root, 'processors', moduleId); %#ok<AGROW>
    end
end

for i = 1:numel(candidateDirs)
    cand = candidateDirs{i};
    if exist(cand, 'dir') == 7 || exist(cand, 'file') == 2
        recovered = cand;
        return;
    end
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
    fromCtxRoiList = false;
    if isfield(ctx,'roiList') && ~isempty(ctx.roiList)
        rois = ctx.roiList;
        fromCtxRoiList = true;
    end

    if isempty(rois)
        fromCtxRoiList = false;
        if isfield(ctx,'fovList') && ~isempty(ctx.fovList)
            rois = collectRoisForContextSelection(ctx, ctx.fovList);
        else
            shallowObj = getShallowObject(ctx);
            if ~isempty(shallowObj)
                rois = collectRoisForContextSelection(ctx, shallowObj.fov);
            end
        end
    end
    if ~fromCtxRoiList && ~isempty(rois) && isfield(ctx,'sel') && isstruct(ctx.sel) && ...
            isfield(ctx.sel,'rois') && ~isempty(ctx.sel.rois)
        rois = filterRoisBySelectionVector(rois, ctx.sel.rois);
    end

    p = getfielddefault(node, 'params', struct());
    if isstruct(p) && isfield(p,'roiList') && ~isempty(p.roiList) && ~isempty(rois)
        idx = resolveIndexSelectionLocal(p.roiList, numel(rois));
        idx = idx(idx >= 1 & idx <= numel(rois));
        if ~isempty(idx)
            rois = rois(idx);
        else
            rois = rois([]);
        end
    end
end

function rois = collectRoisForContextSelection(ctx, fovList)
    rois = [];
    if isempty(fovList)
        return;
    end
    roiSel = [];
    if isfield(ctx,'sel') && isstruct(ctx.sel) && isfield(ctx.sel,'rois') && ~isempty(ctx.sel.rois)
        roiSel = ctx.sel.rois;
    end
    for i = 1:numel(fovList)
        try
            r = fovList(i).roi;
            if isempty(r)
                continue;
            end
            if ~isempty(roiSel)
                idx = resolveIndexSelectionLocal(roiSel, numel(r));
                idx = idx(idx >= 1 & idx <= numel(r));
                r = r(idx);
            end
            if ~isempty(r)
                rois = [rois r(:)']; %#ok<AGROW>
            end
        catch
        end
    end
    rois = filterValidRoiHandles(rois);
end

function rois = filterRoisBySelectionVector(rois, roiSel)
    if isempty(rois) || isempty(roiSel)
        return;
    end
    idx = resolveIndexSelectionLocal(roiSel, numel(rois));
    idx = idx(idx >= 1 & idx <= numel(rois));
    if isempty(idx)
        rois = rois([]);
    else
        rois = rois(idx);
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
    rois = filterValidRoiHandles(rois);
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
    rois = filterValidRoiHandles(rois);
end

function rois = filterValidRoiHandles(rois)
    if isempty(rois)
        return;
    end
    keep = true(1, numel(rois));
    for i = 1:numel(rois)
        try
            r = rois(i);
            rid = '';
            rpath = '';
            if isprop(r, 'id') && ~isempty(r.id)
                rid = char(string(r.id));
            end
            if isprop(r, 'path') && ~isempty(r.path)
                rpath = char(string(r.path));
            end
            keep(i) = ~(isempty(strtrim(rid)) && isempty(strtrim(rpath)));
        catch
            keep(i) = false;
        end
    end
    rois = rois(keep);
end

function pkgName = resolveNodePackage(node)
    pkgName = '';
    nodeType = '';
    if isfield(node,'type') && ~isempty(node.type)
        nodeType = char(string(node.type));
    end
    if isfield(node,'pkg') && ~isempty(node.pkg)
        pkgName = char(string(node.pkg));
        pkgName = canonicalPackageNameForNode(nodeType, pkgName);
        return;
    end
    if isfield(node,'params') && isstruct(node.params) && isfield(node.params,'pkg') && ~isempty(node.params.pkg)
        pkgName = char(string(node.params.pkg));
        pkgName = canonicalPackageNameForNode(nodeType, pkgName);
        return;
    end
    if isfield(node,'func') && ~isempty(node.func)
        f = char(string(node.func));
        dot = strfind(f, '.');
        if ~isempty(dot)
            pkgName = f(1:dot(1)-1);
            pkgName = canonicalPackageNameForNode(nodeType, pkgName);
        end
    end
end

function pkgName = canonicalPackageNameForNode(nodeType, pkgName)
    if isempty(pkgName)
        return;
    end
    raw = char(string(pkgName));
    switch lower(strtrim(raw))
        case 'dataloader'
            pkgName = 'dataLoader';
        case {'roipattern','roiidentify'}
            pkgName = 'roiPattern';
        case 'roimanual'
            pkgName = 'roiManual';
        case 'roigrid'
            pkgName = 'roiGrid';
        case 'roitracked'
            pkgName = 'roiTracked';
        case 'roiextract'
            pkgName = 'roiExtract';
        case 'combinemultiplechannels'
            pkgName = 'combineMultipleChannels';
        case 'computemetrics'
            pkgName = 'computeMetrics';
        case 'computerls'
            pkgName = 'computeRLS';
        case 'computelineage'
            pkgName = 'computeLineage';
        case 'computemaxprojection'
            pkgName = 'computeMaxProjection';
        case 'basicobjecttracking'
            pkgName = 'basicObjectTracking';
        case 'formatindataseries'
            pkgName = 'formatInDataSeries';
        case 'trackmotherlineageviterbi'
            pkgName = 'trackMotherLineageViterbi';
        otherwise
            if strcmpi(char(string(nodeType)), 'classifier')
                switch lower(strtrim(raw))
                    case 'cellposesam'
                        pkgName = 'cellposesam';
                    case 'cnn_lstm'
                        pkgName = 'cnn_lstm';
                    case 'cnn'
                        pkgName = 'cnn';
                    case {'deeplab_pixel_classification','deeplab pixel classification','deeplab-pixel-classification'}
                        pkgName = 'deeplab_pixel_classification';
                    otherwise
                        pkgName = raw;
                end
            else
                pkgName = raw;
            end
    end
end

function vals = normalizeIndexVectorLocal(vals)
if isempty(vals)
    vals = [];
    return;
end
if containsEndSelectorLocal(vals)
    return;
end
if iscell(vals)
    parts = {};
    for i = 1:numel(vals)
        cur = vals{i};
        if isempty(cur)
            continue;
        elseif isnumeric(cur) || islogical(cur)
            parts{end+1} = double(cur(:)'); %#ok<AGROW>
        else
            parsed = parseIndexTextLocal(cur);
            if isempty(parsed) && any(strcmpi(strtrim(char(string(cur))), {'all','*'}))
                vals = [];
                return;
            end
            parts{end+1} = parsed; %#ok<AGROW>
        end
    end
    if isempty(parts)
        vals = [];
        return;
    end
    vals = [parts{:}];
elseif ischar(vals) || isstring(vals)
    txt = strtrim(char(string(vals)));
    if isempty(txt) || any(strcmpi(txt, {'all','*'}))
        vals = [];
        return;
    end
    vals = parseIndexTextLocal(txt);
else
    vals = double(vals(:)');
end
vals = vals(isfinite(vals));
vals = unique(round(vals), 'stable');
vals = vals(vals >= 1);
end

function idx = resolveIndexSelectionLocal(sel, maxIndex)
if nargin < 2 || isempty(maxIndex) || ~isfinite(double(maxIndex))
    maxIndex = Inf;
end
if isempty(sel)
    idx = [];
    return;
end
if containsEndSelectorLocal(sel)
    idx = parseIndexSelectionWithEndLocal(sel, maxIndex);
else
    idx = normalizeIndexVectorLocal(sel);
end
idx = idx(isfinite(idx));
idx = unique(round(idx), 'stable');
idx = idx(idx >= 1);
if isfinite(double(maxIndex))
    idx = idx(idx <= maxIndex);
end
end

function tf = containsEndSelectorLocal(value)
tf = false;
try
    if iscell(value)
        for i = 1:numel(value)
            if containsEndSelectorLocal(value{i})
                tf = true;
                return;
            end
        end
    elseif ischar(value) || isstring(value)
        tf = contains(lower(char(string(value))), 'end');
    end
catch
    tf = false;
end
end

function vals = parseIndexSelectionWithEndLocal(sel, maxIndex)
vals = [];
if iscell(sel)
    parts = {};
    for i = 1:numel(sel)
        parts{end+1} = parseIndexSelectionWithEndLocal(sel{i}, maxIndex); %#ok<AGROW>
    end
    if ~isempty(parts)
        vals = [parts{:}];
    end
    return;
end
if isnumeric(sel) || islogical(sel)
    vals = double(sel(:)');
    return;
end
txt = strtrim(char(string(sel)));
if isempty(txt) || any(strcmpi(txt, {'all','*'}))
    vals = [];
    return;
end
txt = strrep(txt, ';', ',');
txt = strrep(txt, ' ', ',');
tokens = regexp(txt, '[,]+', 'split');
out = {};
for i = 1:numel(tokens)
    tok = strtrim(tokens{i});
    if isempty(tok)
        continue;
    end
    if contains(tok, ':')
        bits = regexp(tok, ':', 'split');
        nums = nan(1, numel(bits));
        for j = 1:numel(bits)
            nums(j) = parseIndexTermLocal(bits{j}, maxIndex);
        end
        if numel(nums) == 2 && all(isfinite(nums))
            out{end+1} = nums(1):nums(2); %#ok<AGROW>
        elseif numel(nums) >= 3 && all(isfinite(nums(1:3))) && nums(2) ~= 0
            out{end+1} = nums(1):nums(2):nums(3); %#ok<AGROW>
        end
    else
        n = parseIndexTermLocal(tok, maxIndex);
        if isfinite(n)
            out{end+1} = n; %#ok<AGROW>
        end
    end
end
if ~isempty(out)
    vals = [out{:}];
end
end

function n = parseIndexTermLocal(tok, maxIndex)
tok = strtrim(lower(char(string(tok))));
if strcmp(tok, 'end')
    n = double(maxIndex);
    return;
end
m = regexp(tok, '^end([+-]\d+)$', 'tokens', 'once');
if ~isempty(m)
    n = double(maxIndex) + str2double(m{1});
    return;
end
n = str2double(tok);
end

function vals = parseIndexTextLocal(txt)
vals = [];
try
    txt = strtrim(char(string(txt)));
    if isempty(txt)
        return;
    end
    txt = strrep(txt, ';', ',');
    txt = strrep(txt, ' ', ',');
    tokens = regexp(txt, '[,]+', 'split');
    out = {};
    for i = 1:numel(tokens)
        tok = strtrim(tokens{i});
        if isempty(tok)
            continue;
        end
        if contains(tok, ':')
            nums = sscanf(tok, '%f:%f:%f');
            if numel(nums) == 2
                out{end+1} = nums(1):nums(2); %#ok<AGROW>
            elseif numel(nums) >= 3
                out{end+1} = nums(1):nums(2):nums(3); %#ok<AGROW>
            end
        else
            n = str2double(tok);
            if isfinite(n)
                out{end+1} = n; %#ok<AGROW>
            end
        end
    end
    if ~isempty(out)
        vals = [out{:}];
    end
catch
    vals = [];
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
                keep(i) = contains(nm, 'mask') || contains(nm, 'seg') || ...
                    contains(nm, 'result') || contains(nm, 'cellpose') || ...
                    contains(nm, 'sam') || contains(nm, 'track');
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
