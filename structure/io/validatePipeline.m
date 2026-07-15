function [ok, report] = validatePipeline(pipe, ctx, opts)
% validatePipeline  Validate pipeline structure and dependencies.

    ok = true;
    report = struct('errors',{{}}, 'warnings',{{}}, 'order', [], 'nodes', [], 'edges', [], 'contracts', struct(), 'semantic', struct(), 'binding', struct(), 'classifierArtifacts', [], 'pluginPackages', [], 'pathChecks', [], 'solver', struct());

    if nargin < 2 || isempty(ctx)
        ctx = struct();
    end
    if nargin < 3 || isempty(opts)
        opts = struct();
    end

    allowGui = false;
    if isfield(opts,'allowGui') && ~isempty(opts.allowGui)
        allowGui = logical(opts.allowGui);
    end

    P = pipelineToStructLocal(pipe);
    nodes = normalizeNodesWithContracts(P.nodes);
    nodes = applyValidationRunNodeOverrides(nodes, ctx);
    edges = normalizeEdges(P, nodes);
    [nodes, edges] = filterGraphForRunSelection(nodes, edges, ctx);
    nodes = injectContextResolvedNodeBindings(nodes, ctx);
    edges = addResourceBindingDependencyEdges(nodes, edges);

    report.nodes = nodes;
    report.edges = edges;
    report.contracts = buildContractReport(nodes);
    report.missingParams = {};
    report.deferredParams = {};
    report.needsGui = {};

    if isempty(nodes)
        ok = false;
        report.errors{end+1} = 'Pipeline has no nodes.';
        return;
    end

    ids = getNodeIds(nodes);
    if numel(unique(ids)) ~= numel(ids)
        ok = false;
        report.errors{end+1} = 'Duplicate node ids.';
    end

    % validate edges
    for i = 1:numel(edges)
        if ~ismember(edges(i).from, ids)
            ok = false;
            report.errors{end+1} = ['Edge from unknown node: ' edges(i).from];
        end
        if ~ismember(edges(i).to, ids)
            ok = false;
            report.errors{end+1} = ['Edge to unknown node: ' edges(i).to];
        end
        if ~strcmpi(char(string(getField(edges(i), 'condition', ''))), 'resourceBinding')
            [edgeOk, edgeErrors, edgeWarnings] = validateEdgePorts(edges(i), nodes, ids);
            if ~edgeOk
                ok = false;
                report.errors = [report.errors, edgeErrors]; %#ok<AGROW>
            end
            if ~isempty(edgeWarnings)
                report.warnings = [report.warnings, edgeWarnings]; %#ok<AGROW>
            end
        end
    end

    % topo sort
    [order, cycle] = topoSort(ids, edges);
    if cycle
        ok = false;
        report.errors{end+1} = 'Pipeline has cycles.';
    else
        report.order = order;
    end

    % input/output coherence (best-effort)
    try
        available = initialAvailablePorts(ctx);
        semanticState = initialSemanticState(ctx);
        if isfield(P,'inputs')
            available = unique([available(:); cellstr(P.inputs(:))]);
        end

        for i = 1:numel(order)
            node = nodes(strcmp(ids, order{i}));
            req = requiredInputNames(node);
            if ~isempty(req)
                missing = setdiff(req, available);
                if ~isempty(missing)
                    ok = false;
                    report.errors{end+1} = ['Missing inputs for node ' node.id ': ' strjoin(missing, ', ')];
                end
            end
            % required params check
            [missParams, deferredParams] = missingParamsForNode(node, ctx, 'template');
            if ~isempty(deferredParams)
                report.deferredParams{end+1} = struct( ...
                    'node', char(string(node.id)), ...
                    'missing', {deferredParams});
                report.warnings{end+1} = ['Deferred params for node ' node.id ' (set at run): ' strjoin(deferredParams, ', ')];
            end
            if ~isempty(missParams)
                report.missingParams{end+1} = struct( ...
                    'node', char(string(node.id)), ...
                    'missing', {missParams});
                if hasNodeGui(node) && allowGui
                    report.needsGui{end+1} = char(string(node.id));
                else
                    ok = false;
                    report.errors{end+1} = ['Missing params for node ' node.id ': ' strjoin(missParams, ', ')];
                end
            end
            [artifactErrors, artifactWarnings, artifactReport] = classifierArtifactIssues(node, ctx);
            if ~isempty(artifactReport)
                report.classifierArtifacts = appendStructArray(report.classifierArtifacts, artifactReport);
            end
            if ~isempty(artifactErrors)
                ok = false;
                report.errors = [report.errors, artifactErrors]; %#ok<AGROW>
            end
            if ~isempty(artifactWarnings)
                report.warnings = [report.warnings, artifactWarnings]; %#ok<AGROW>
            end
            [pluginErrors, pluginWarnings, pluginReport] = pluginPackageIssues(node, ctx);
            if ~isempty(pluginReport)
                report.pluginPackages = appendStructArray(report.pluginPackages, pluginReport);
            end
            if ~isempty(pluginErrors)
                ok = false;
                report.errors = [report.errors, pluginErrors]; %#ok<AGROW>
            end
            if ~isempty(pluginWarnings)
                report.warnings = [report.warnings, pluginWarnings]; %#ok<AGROW>
            end
            [pathErrors, pathWarnings, pathReports] = nodePathIssues(node, ctx);
            if ~isempty(pathReports)
                report.pathChecks = appendStructArray(report.pathChecks, pathReports);
            end
            if ~isempty(pathErrors)
                ok = false;
                report.errors = [report.errors, pathErrors]; %#ok<AGROW>
            end
            if ~isempty(pathWarnings)
                report.warnings = [report.warnings, pathWarnings]; %#ok<AGROW>
            end
            designErrors = requiredDesignAssetErrors(node, ctx);
            if ~isempty(designErrors)
                if hasNodeGui(node) && allowGui
                    report.needsGui{end+1} = char(string(node.id)); %#ok<AGROW>
                    report.warnings = [report.warnings, designErrors]; %#ok<AGROW>
                else
                    ok = false;
                    report.errors = [report.errors, designErrors]; %#ok<AGROW>
                end
            end
            [semOk, semErrors, semWarnings, semReport] = validateNodeSemanticRequirements(node, semanticState);
            report.semantic.(matlab.lang.makeValidName(char(string(node.id)))) = semReport;
            if ~semOk
                ok = false;
                report.errors = [report.errors, semErrors]; %#ok<AGROW>
            end
            if ~isempty(semWarnings)
                report.warnings = [report.warnings, semWarnings]; %#ok<AGROW>
            end
            semanticState = applyNodeSemanticCapabilities(node, semanticState);
            out = outputNames(node);
            if ~isempty(out)
                available = unique([available(:); out(:)]);
            end
        end

        bindingReport = solvePipelineBindings(nodes, edges, ctx, order);
        report.binding = bindingReport;
        if isfield(bindingReport, 'errors') && ~isempty(bindingReport.errors)
            ok = false;
            report.errors = [report.errors, bindingReport.errors]; %#ok<AGROW>
        end
        if isfield(bindingReport, 'warnings') && ~isempty(bindingReport.warnings)
            report.warnings = [report.warnings, bindingReport.warnings]; %#ok<AGROW>
        end
    catch ME
        where = '';
        if ~isempty(ME.stack)
            where = sprintf(' (%s:%d)', ME.stack(1).name, ME.stack(1).line);
        end
        report.warnings{end+1} = ['Semantic validation skipped: ' ME.message where];
    end

    try
        report.solver = pipelineSolverIssues(report, nodes);
    catch ME
        report.warnings{end+1} = ['Solver issue report skipped: ' ME.message];
        report.solver = struct('issues', [], 'table', {{}}, 'summary', struct(), 'hasBlocking', false);
    end
end

function P = pipelineToStructLocal(pipe)
    if isa(pipe, 'pipeline')
        P = struct();
        P.nodes = pipe.nodes;
        P.edges = pipe.edges;
        P.branches = pipe.branches;
        if isprop(pipe,'inputs'), P.inputs = pipe.inputs; end
    else
        P = pipe;
    end
end

function nodes = applyValidationRunNodeOverrides(nodes, ctx)
    if isempty(nodes) || ~isstruct(ctx) || ~isfield(ctx, 'run') || ~isstruct(ctx.run) || ...
            ~isfield(ctx.run, 'nodeParams') || isempty(ctx.run.nodeParams)
        return;
    end
    np = ctx.run.nodeParams;
    for i = 1:numel(nodes)
        nodeId = char(string(getField(nodes(i), 'id', '')));
        patch = findRunNodeParamPatch(np, nodeId);
        if isempty(patch)
            continue;
        end
        if ~isfield(nodes(i), 'params') || ~isstruct(nodes(i).params)
            nodes(i).params = struct();
        end
        if isstruct(patch) && isfield(patch, 'params') && isstruct(patch.params)
            nodes(i).params = mergeStructLocal(nodes(i).params, sanitizeRunNodeParamPatch(nodes(i).params, patch.params));
        elseif isstruct(patch)
            patchParams = rmfieldIfPresentLocal(patch, {'id','nodeId'});
            nodes(i).params = mergeStructLocal(nodes(i).params, sanitizeRunNodeParamPatch(nodes(i).params, patchParams));
        end
    end
end

function patch = sanitizeRunNodeParamPatch(baseParams, patch)
    if ~isstruct(patch)
        return;
    end
    if ~isstruct(baseParams)
        baseParams = struct();
    end
    names = fieldnames(patch);
    for i = 1:numel(names)
        key = names{i};
        if ~isfield(baseParams, key) || isempty(baseParams.(key))
            continue;
        end
        if isGenericSourceSymbolicBinding(patch.(key)) && ~isSymbolicResourceBinding(baseParams.(key))
            patch = rmfield(patch, key);
        end
    end
end

function patch = findRunNodeParamPatch(nodeParams, nodeId)
    patch = [];
    if isempty(nodeParams) || isempty(nodeId)
        return;
    end
    try
        if iscell(nodeParams)
            for i = 1:numel(nodeParams)
                item = nodeParams{i};
                if isstruct(item) && nodeParamIdMatches(item, nodeId)
                    patch = item;
                    return;
                end
            end
        elseif isstruct(nodeParams) && numel(nodeParams) > 1
            for i = 1:numel(nodeParams)
                if nodeParamIdMatches(nodeParams(i), nodeId)
                    patch = nodeParams(i);
                    return;
                end
            end
        elseif isstruct(nodeParams)
            if nodeParamIdMatches(nodeParams, nodeId)
                patch = nodeParams;
                return;
            end
            f = matlab.lang.makeValidName(nodeId);
            if isfield(nodeParams, f)
                patch = nodeParams.(f);
            elseif isfield(nodeParams, nodeId)
                patch = nodeParams.(nodeId);
            end
        end
    catch
        patch = [];
    end
end

function tf = nodeParamIdMatches(item, nodeId)
    tf = false;
    try
        if isfield(item, 'id') && strcmp(char(string(item.id)), nodeId)
            tf = true;
        elseif isfield(item, 'nodeId') && strcmp(char(string(item.nodeId)), nodeId)
            tf = true;
        end
    catch
        tf = false;
    end
end

function S = rmfieldIfPresentLocal(S, names)
    if ~isstruct(S)
        return;
    end
    for i = 1:numel(names)
        if isfield(S, names{i})
            S = rmfield(S, names{i});
        end
    end
end

function arr = appendStructArray(arr, item)
    if isempty(item)
        return;
    end
    if isempty(arr)
        arr = item;
    else
        arr(end+1) = item; %#ok<AGROW>
    end
end

function [nodes, edges] = filterGraphForRunSelection(nodes, edges, ctx)
    selectedIds = selectedNodeIdsFromContext(ctx);
    if isempty(selectedIds) || isempty(nodes)
        return;
    end
    nodeIds = getNodeIds(nodes);
    keep = ismember(nodeIds, selectedIds);
    if ~any(keep)
        return;
    end
    nodes = nodes(keep);
    if isempty(edges)
        return;
    end
    edgeKeep = false(size(edges));
    for i = 1:numel(edges)
        edgeKeep(i) = any(strcmp(selectedIds, char(string(getField(edges(i), 'from', ''))))) && ...
            any(strcmp(selectedIds, char(string(getField(edges(i), 'to', '')))));
    end
    edges = edges(edgeKeep);
end

function ids = selectedNodeIdsFromContext(ctx)
    ids = {};
    try
        if isstruct(ctx) && isfield(ctx, 'run') && isstruct(ctx.run) && ...
                isfield(ctx.run, 'selectedNodes') && ~isempty(ctx.run.selectedNodes)
            ids = cellstr(string(ctx.run.selectedNodes(:)))';
            ids = unique(ids(~cellfun(@isempty, ids)), 'stable');
        end
    catch
        ids = {};
    end
end

function nodes = normalizeNodesWithContracts(nodes)
    if isempty(nodes)
        return;
    end
    nodes = pipelineNormalizeNodes(nodes, 'runtime');
    for i = 1:numel(nodes)
        nodes(i).contract = pipelineNodeContract(nodes(i));
        [nodes(i).inputs, nodes(i).outputs] = pipelineContractPortNames(nodes(i).contract);
    end
end

function edges = normalizeEdges(P, nodes)
    edges = struct('from',{},'to',{},'fromPort',{},'toPort',{},'condition',{});
    if isfield(P,'edges') && ~isempty(P.edges)
        if isstruct(P.edges)
            edges = P.edges;
        elseif iscell(P.edges)
            for i = 1:size(P.edges,1)
                edges(end+1).from = char(string(P.edges{i,1})); %#ok<AGROW>
                edges(end).to = char(string(P.edges{i,2}));
                edges(end).fromPort = '';
                edges(end).toPort = '';
                edges(end).condition = '';
            end
        end
    end
    if isfield(P,'branches') && ~isempty(P.branches)
        b = P.branches;
        if isstruct(b)
            for i = 1:numel(b)
                edges(end+1).from = char(string(b(i).from)); %#ok<AGROW>
                edges(end).to = char(string(b(i).to));
                edges(end).fromPort = '';
                edges(end).toPort = '';
                if isfield(b,'if')
                    edges(end).condition = char(string(b(i).if));
                elseif isfield(b,'condition')
                    edges(end).condition = char(string(b(i).condition));
                else
                    edges(end).condition = '';
                end
            end
        end
    end

    for i = 1:numel(edges)
        if ~isfield(edges(i), 'fromPort') || isempty(edges(i).fromPort)
            edges(i).fromPort = inferEdgePort(nodes, getField(edges(i), 'from', ''), 'out');
        else
            edges(i).fromPort = char(string(edges(i).fromPort));
        end
        if ~isfield(edges(i), 'toPort') || isempty(edges(i).toPort)
            edges(i).toPort = inferEdgePort(nodes, getField(edges(i), 'to', ''), 'in');
        else
            edges(i).toPort = char(string(edges(i).toPort));
        end
        if ~isfield(edges(i), 'condition') || isempty(edges(i).condition)
            edges(i).condition = '';
        else
            edges(i).condition = char(string(edges(i).condition));
        end
    end
end

function edges = addResourceBindingDependencyEdges(nodes, edges)
    if isempty(nodes)
        return;
    end
    ids = getNodeIds(nodes);
    declaredOutputs = collectDeclaredResourceOutputs(nodes);
    for i = 1:numel(nodes)
        targetId = char(string(getField(nodes(i), 'id', '')));
        contract = getField(nodes(i), 'contract', struct());
        resources = getField(contract, 'resources', struct());
        inputs = getField(resources, 'in', resourceSpecDef());
        if isempty(inputs)
            continue;
        end
        for j = 1:numel(inputs)
            spec = inputs(j);
            if isempty(getField(spec, 'type', ''))
                continue;
            end
            producers = resourceBindingProducerIds(nodes(i), spec, declaredOutputs, ids);
            for k = 1:numel(producers)
                producerId = char(string(producers{k}));
                if isempty(producerId) || strcmp(producerId, targetId)
                    continue;
                end
                edges = appendImplicitResourceEdge(edges, producerId, targetId, spec);
            end
        end
    end
end

function resources = collectDeclaredResourceOutputs(nodes)
    resources = resourceInventoryDef();
    for i = 1:numel(nodes)
        contract = getField(nodes(i), 'contract', struct());
        r = getField(contract, 'resources', struct());
        outputs = getField(r, 'out', resourceSpecDef());
        if isempty(outputs)
            continue;
        end
        for j = 1:numel(outputs)
            spec = outputs(j);
            if isempty(getField(spec, 'type', ''))
                continue;
            end
            resources = mergeResourceInventory(resources, makeResourceOutput(nodes(i), spec));
        end
    end
end

function producers = resourceBindingProducerIds(node, spec, declaredOutputs, ids)
    producers = {};
    [hasRaw, raw] = resolveResourceRawValue(node, spec);
    if ~hasRaw
        return;
    end

    if isGenericSourceSymbolicBinding(raw)
        return;
    end
    rawText = choiceToString(raw);
    if isempty(rawText)
        return;
    end

    if isSymbolicResourceBinding(rawText)
        sourceNode = symbolicResourceSourceNode(rawText);
        if ~isempty(sourceNode) && any(strcmp(ids, sourceNode))
            producers = {sourceNode};
        end
        return;
    end

    value = resolveResourceConfiguredValue(node, spec);
    if isempty(value)
        return;
    end
    matches = producerIdsForConcreteResource(value, spec, declaredOutputs);
    if numel(matches) == 1
        producers = matches;
    end
end

function producers = producerIdsForConcreteResource(value, spec, resources)
    producers = {};
    resources = normalizeResourceInventory(resources);
    value = strtrim(char(string(value)));
    if isempty(value)
        return;
    end
    if strcmpi(char(string(getField(spec, 'type', ''))), 'dataSeriesVariable')
        value = dataSeriesNameFromVariableBinding(value);
        if isempty(value)
            return;
        end
    end
    wantedType = lower(char(string(getField(spec, 'type', ''))));
    wantedRole = lower(char(string(getField(spec, 'role', ''))));
    for i = 1:numel(resources)
        if ~resourceSpecCompatible(wantedType, wantedRole, resources(i).type, resources(i).role)
            continue;
        end
        names = {char(string(resources(i).concreteName)), char(string(resources(i).symbol))};
        if any(strcmpi(value, names(~cellfun(@isempty, names))))
            producers{end+1} = char(string(resources(i).sourceNode)); %#ok<AGROW>
        end
    end
    producers = unique(producers(~cellfun(@isempty, producers)), 'stable');
end

function edges = appendImplicitResourceEdge(edges, fromId, toId, spec)
    for i = 1:numel(edges)
        if strcmp(char(string(getField(edges(i), 'from', ''))), fromId) && ...
                strcmp(char(string(getField(edges(i), 'to', ''))), toId) && ...
                strcmpi(char(string(getField(edges(i), 'condition', ''))), 'resourceBinding')
            return;
        end
    end
    if isempty(edges)
        edges = struct('from',{},'to',{},'fromPort',{},'toPort',{},'condition',{});
    end
    edges(end+1).from = fromId; %#ok<AGROW>
    edges(end).to = toId;
    edges(end).fromPort = char(string(getField(spec, 'port', 'resource')));
    edges(end).toPort = char(string(getField(spec, 'param', 'resource')));
    edges(end).condition = 'resourceBinding';
end

function ids = getNodeIds(nodes)
    ids = cell(1,numel(nodes));
    for i = 1:numel(nodes)
        ids{i} = char(string(nodes(i).id));
    end
end

function [order, cycle] = topoSort(ids, edges)
    cycle = false;
    order = {};

    indeg = containers.Map(ids, num2cell(zeros(size(ids))));
    adj = containers.Map(ids, cell(size(ids)));
    for i = 1:numel(ids)
        adj(ids{i}) = {};
    end

    for i = 1:numel(edges)
        u = edges(i).from; v = edges(i).to;
        if isKey(adj,u)
            adj(u) = [adj(u) {v}];
        end
        if isKey(indeg,v)
            indeg(v) = indeg(v) + 1;
        end
    end

    q = {};
    for i = 1:numel(ids)
        if indeg(ids{i}) == 0
            q{end+1} = ids{i}; %#ok<AGROW>
        end
    end

    while ~isempty(q)
        u = q{1};
        q(1) = [];
        order{end+1} = u; %#ok<AGROW>
        vs = adj(u);
        for k = 1:numel(vs)
            v = vs{k};
            indeg(v) = indeg(v) - 1;
            if indeg(v) == 0
                q{end+1} = v; %#ok<AGROW>
            end
        end
    end

    if numel(order) ~= numel(ids)
        cycle = true;
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
        if strcmpi(k, 'path') && strcmpi(char(string(getField(node, 'type', ''))), 'classifier')
            % Classifier nodes consume ROI/image data from the execution
            % context. A stale dataloader "path" requirement can remain when
            % a classifier is inserted in a raw-start slot.
            continue;
        end
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

function out = buildContractReport(nodes)
    out = struct();
    if isempty(nodes)
        return;
    end
    for i = 1:numel(nodes)
        key = matlab.lang.makeValidName(char(string(nodes(i).id)));
        out.(key) = getField(nodes(i), 'contract', struct('in',struct([]),'out',struct([])));
    end
end

function [ok, errors, warnings, nodeReport] = validateNodeSemanticRequirements(node, state)
    ok = true;
    errors = {};
    warnings = {};

    nodeId = char(string(getField(node, 'id', '')));
    contract = getField(node, 'contract', struct());
    req = getField(contract, 'requirements', struct());
    selectors = getField(contract, 'selectors', struct());

    nodeReport = struct( ...
        'summary', getField(contract, 'summary', ''), ...
        'requiredChannels', 0, ...
        'configuredChannels', {{}}, ...
        'availableChannels', {{}}, ...
        'channelCheck', '', ...
        'masksRequired', false, ...
        'dataSeriesRequired', false);

    configuredChannels = resolveNodeConfiguredChannels(node, selectors);
    availableImageChannels = state.imageChannels;
    availableRoiChannels = state.roiChannels;

    if isfield(req, 'images') && isstruct(req.images) && logical(getField(req.images, 'required', false))
        imageMin = double(getField(req.images, 'channelsMin', 0));
        [chOk, chErrors, chWarnings, chReport] = validateChannelRequirement( ...
            nodeId, 'source images', imageMin, configuredChannels, availableImageChannels, state.hasImages);
        nodeReport.requiredChannels = max(nodeReport.requiredChannels, imageMin);
        nodeReport.configuredChannels = chReport.configuredChannels;
        nodeReport.availableChannels = chReport.availableChannels;
        nodeReport.channelCheck = chReport.message;
        if ~chOk
            ok = false;
            errors = [errors, chErrors]; %#ok<AGROW>
        end
        warnings = [warnings, chWarnings]; %#ok<AGROW>
    end

    if isfield(req, 'roi') && isstruct(req.roi) && logical(getField(req.roi, 'required', false))
        roiMin = double(getField(req.roi, 'channelsMin', 0));
        [chOk, chErrors, chWarnings, chReport] = validateChannelRequirement( ...
            nodeId, 'ROI content', roiMin, configuredChannels, availableRoiChannels, state.hasRoiList);
        nodeReport.requiredChannels = max(nodeReport.requiredChannels, roiMin);
        nodeReport.configuredChannels = chReport.configuredChannels;
        nodeReport.availableChannels = chReport.availableChannels;
        nodeReport.channelCheck = chReport.message;
        if ~chOk
            ok = false;
            errors = [errors, chErrors]; %#ok<AGROW>
        end
        warnings = [warnings, chWarnings]; %#ok<AGROW>

        if logical(getField(req.roi, 'masks', false))
            nodeReport.masksRequired = true;
            if ~(state.hasMasks || state.roiHasMasks)
                ok = false;
                errors{end+1} = ['Node ' nodeId ' requires ROI masks, but no mask-producing upstream path is available.']; %#ok<AGROW>
            end
        end

        if logical(getField(req.roi, 'dataSeries', false))
            nodeReport.dataSeriesRequired = true;
            if ~(state.hasDataSeries || state.roiHasDataSeries)
                ok = false;
                errors{end+1} = ['Node ' nodeId ' requires ROI data series, but no upstream dataSeries output is available.']; %#ok<AGROW>
            end
        end
    end
end

function [ok, errors, warnings, report] = validateChannelRequirement(nodeId, scopeLabel, minCount, configuredChannels, availableChannels, supportAvailable)
    ok = true;
    errors = {};
    warnings = {};
    report = struct('configuredChannels', {configuredChannels}, 'availableChannels', {availableChannels}, 'message', '');

    if minCount <= 0
        if isempty(configuredChannels)
            report.message = 'No explicit channel requirement.';
        else
            report.message = ['Configured channels: ' strjoin(configuredChannels, ', ')];
        end
        return;
    end

    if ~supportAvailable
        ok = false;
        errors{end+1} = ['Node ' nodeId ' requires ' scopeLabel ', but that support is not available in the current graph state.']; %#ok<AGROW>
        report.message = 'Required support missing.';
        return;
    end

    if ~isempty(configuredChannels)
        if numel(configuredChannels) < minCount
            ok = false;
            errors{end+1} = ['Node ' nodeId ' expects at least ' num2str(minCount) ' channel(s) for ' scopeLabel ...
                ', but only ' num2str(numel(configuredChannels)) ' channel selector(s) are configured.']; %#ok<AGROW>
            report.message = 'Configured channel selectors are insufficient.';
            return;
        end
        report.message = ['Configured channels: ' strjoin(configuredChannels, ', ')];
        return;
    end

    if ~isempty(availableChannels)
        if numel(availableChannels) < minCount
            ok = false;
            errors{end+1} = ['Node ' nodeId ' expects at least ' num2str(minCount) ' channel(s) for ' scopeLabel ...
                ', but only ' num2str(numel(availableChannels)) ' channel(s) are visible from upstream/context.']; %#ok<AGROW>
            report.message = 'Upstream channel count is insufficient.';
            return;
        end
        report.message = ['Upstream channels available: ' strjoin(availableChannels, ', ')];
        return;
    end

    warnings{end+1} = ['Node ' nodeId ' expects at least ' num2str(minCount) ' channel(s) for ' scopeLabel ...
        ', but the exact channel inventory is not known statically.']; %#ok<AGROW>
    report.message = 'Channel count could not be validated statically.';
end

function state = initialSemanticState(ctx)
    state = struct( ...
        'hasImages', false, ...
        'hasFovList', false, ...
        'hasRoiList', false, ...
        'hasMasks', false, ...
        'hasDataSeries', false, ...
        'roiHasMasks', false, ...
        'roiHasDataSeries', false, ...
        'imageChannels', {{}}, ...
        'roiChannels', {{}});

    state.hasImages = (isfield(ctx,'images') && ~isempty(ctx.images)) || ...
                      (isfield(ctx,'fovList') && ~isempty(ctx.fovList)) || ...
                      (isfield(ctx,'shallow') && ~isempty(ctx.shallow)) || ...
                      (isfield(ctx,'shallowObj') && ~isempty(ctx.shallowObj));
    state.hasFovList = (isfield(ctx,'fovList') && ~isempty(ctx.fovList));
    state.hasRoiList = (isfield(ctx,'roiList') && ~isempty(ctx.roiList)) || ...
                       (isfield(ctx,'rois') && ~isempty(ctx.rois));
    if ~state.hasRoiList && validationStartsFromExistingProject(ctx)
        state.hasRoiList = true;
    end
    state.hasMasks = isfield(ctx,'masks') && ~isempty(ctx.masks);
    state.hasDataSeries = (isfield(ctx,'dataSeries') && ~isempty(ctx.dataSeries)) || ...
                          (isfield(ctx,'dataseries') && ~isempty(ctx.dataseries)) || ...
                          (isfield(ctx,'dataSeriesNames') && ~isempty(ctx.dataSeriesNames));

    state.imageChannels = unique([ ...
        normalizeChannelList(getField(ctx, 'channels', [])), ...
        inferFovChannels(getField(ctx, 'fovList', []))], 'stable');

    roiList = [];
    if isfield(ctx,'roiList') && ~isempty(ctx.roiList)
        roiList = ctx.roiList;
    elseif isfield(ctx,'rois') && ~isempty(ctx.rois)
        roiList = ctx.rois;
    end
    state.roiChannels = mergeKnownChannels( ...
        inferRoiChannels(roiList), ...
        normalizeChannelList(getField(ctx, 'roiChannels', [])));
    state.roiHasMasks = state.hasMasks || roiListHasMaskLikeChannels(roiList);
    state.roiHasDataSeries = state.hasDataSeries || roiListHasDataSeries(roiList);
end

function state = applyNodeSemanticCapabilities(node, state)
    contract = getField(node, 'contract', struct());
    capabilities = getField(contract, 'capabilities', struct());
    selectors = getField(contract, 'selectors', struct());
    binding = getField(contract, 'binding', struct());

    outNames = outputNames(node);
    if any(strcmp(outNames, 'images'))
        state.hasImages = true;
    end
    if any(strcmp(outNames, 'fovList'))
        state.hasFovList = true;
        state.hasImages = true;
    end
    if any(strcmp(outNames, 'roiList'))
        state.hasRoiList = true;
    end
    if any(strcmp(outNames, 'masks'))
        state.hasMasks = true;
        state.roiHasMasks = true;
    end
    if any(strcmp(outNames, 'dataSeries'))
        state.hasDataSeries = true;
        state.roiHasDataSeries = true;
    end
    if logical(getField(capabilities, 'outputsImages', false))
        state.hasImages = true;
    end
    if logical(getField(capabilities, 'outputsFovList', false))
        state.hasImages = true;
        state.hasFovList = true;
    end
    if logical(getField(capabilities, 'roiChannels', false))
        state.hasRoiList = true;
        nodeChannels = resolveNodeConfiguredChannels(node, selectors);
        if isempty(nodeChannels) && strcmpi(char(string(getField(node, 'type', ''))), 'roiextract')
            nodeChannels = state.imageChannels;
        end
        outName = resolveNodeProducedChannelName(node, binding);
        if ~isempty(outName)
            nodeChannels = mergeKnownChannels(nodeChannels, outName);
        end
        state.roiChannels = mergeKnownChannels(state.roiChannels, nodeChannels);
    end
    if logical(getField(capabilities, 'roiMasks', false))
        state.hasRoiList = true;
        state.roiHasMasks = true;
    end
    if logical(getField(capabilities, 'roiDataSeries', false))
        state.hasRoiList = true;
        state.roiHasDataSeries = true;
    end
    if logical(getField(capabilities, 'outputsChannels', false))
        nodeChannels = resolveNodeConfiguredChannels(node, selectors);
        if isempty(nodeChannels) && strcmpi(char(string(getField(node, 'type', ''))), 'roiextract')
            nodeChannels = state.imageChannels;
        end
        outName = resolveNodeProducedChannelName(node, binding);
        if ~isempty(outName)
            nodeChannels = mergeKnownChannels(nodeChannels, outName);
        end
        if any(strcmp(outNames, 'roiList')) || logical(getField(capabilities, 'roiChannels', false))
            state.roiChannels = mergeKnownChannels(state.roiChannels, nodeChannels);
        else
            state.imageChannels = mergeKnownChannels(state.imageChannels, nodeChannels);
        end
    end
end

function channels = resolveNodeConfiguredChannels(node, selectors)
    channels = {};
    params = getField(node, 'params', struct());
    if ~isstruct(params)
        return;
    end

    contract = getField(node, 'contract', struct());
    binding = getField(contract, 'binding', struct());
    selectorKeys = getField(binding, 'selectorKeys', {});
    if ~isempty(selectorKeys)
        selectorKeys = cellstr(string(selectorKeys(:)));
        for i = 1:numel(selectorKeys)
            key = char(string(selectorKeys{i}));
            if ~legacyChannelSelectorKeyApplies(node, key)
                continue;
            end
            if isfield(params, key) && ~isempty(params.(key))
                channels = mergeKnownChannels(channels, normalizeConfiguredOrSymbolicSelectionValue(params.(key)));
            end
        end
        if ~isempty(channels)
            return;
        end
    end

    candidates = { ...
        getField(selectors, 'channelsParam', ''), ...
        getField(selectors, 'channelParam', ''), ...
        'channelName', ...
        'channelFilter'};

    for i = 1:numel(candidates)
        key = char(string(candidates{i}));
        if isempty(key)
            continue;
        end
        if ~legacyChannelSelectorKeyApplies(node, key)
            continue;
        end
        if isfield(params, key) && ~isempty(params.(key))
            channels = normalizeConfiguredOrSymbolicSelectionValue(params.(key));
            if ~isempty(channels)
                return;
            end
        end
    end

    if strcmpi(char(string(getField(node, 'type', ''))), 'classifier')
        channels = resolveLinkedClassifierChannels(node);
        if ~isempty(channels)
            return;
        end
    end

    if isstruct(selectors) && isfield(selectors, 'defaultChannels') && ~isempty(selectors.defaultChannels)
        channels = normalizeChannelList(selectors.defaultChannels);
    end
end

function channels = resolveLinkedClassifierChannels(node)
    channels = {};
    p = getField(node, 'params', struct());
    if ~isstruct(p)
        return;
    end
    snap = '';
    try
        base = '';
        if isfield(p, 'modulePath') && ~isempty(p.modulePath)
            base = char(string(p.modulePath));
        end
        moduleId = '';
        if isfield(p, 'moduleId') && ~isempty(p.moduleId)
            moduleId = char(string(p.moduleId));
        elseif isfield(p, 'outputName') && ~isempty(p.outputName)
            moduleId = char(string(p.outputName));
        end
        if isempty(base) || exist(base, 'dir') ~= 7
            return;
        end
        candidates = {};
        if ~isempty(moduleId)
            candidates = { ...
                fullfile(base, [moduleId '_classification.mat']), ...
                fullfile(base, [moduleId '.mat'])};
        end
        files = dir(fullfile(base, '*_classification.mat'));
        for i = 1:numel(files)
            candidates{end+1} = fullfile(files(i).folder, files(i).name); %#ok<AGROW>
        end
        for i = 1:numel(candidates)
            if exist(candidates{i}, 'file') == 2
                snap = candidates{i};
                break;
            end
        end
        if isempty(snap)
            return;
        end
        S = load(snap);
        clsObj = [];
        if isfield(S, 'classiObj') && isa(S.classiObj, 'classi')
            clsObj = S.classiObj;
        else
            fn = fieldnames(S);
            for i = 1:numel(fn)
                if isa(S.(fn{i}), 'classi')
                    clsObj = S.(fn{i});
                    break;
                end
            end
        end
        if isempty(clsObj)
            return;
        end
        if numel(clsObj) > 1
            clsObj = clsObj(1);
        end
        if isprop(clsObj, 'channelName') && ~isempty(clsObj.channelName)
            channels = normalizeChannelList(clsObj.channelName);
        end
    catch
        channels = {};
    end
end

function name = resolveNodeProducedChannelName(node, binding)
    name = {};
    params = getField(node, 'params', struct());
    if ~isstruct(params) || ~isstruct(binding)
        return;
    end

    key = char(string(getField(binding, 'outputChannelNameParam', '')));
    if isempty(key)
        return;
    end
    if ~isfield(params, key) || isempty(params.(key))
        return;
    end
    raw = char(string(params.(key)));
    raw = strtrim(raw);
    if isempty(raw)
        return;
    end
    name = {raw};
end

function report = solvePipelineBindings(nodes, edges, ctx, order)
    report = struct('errors', {{}}, 'warnings', {{}}, 'nodes', struct(), ...
        'needsUserBinding', {{}}, 'needsRunBinding', {{}}, 'autoResolvable', {{}});
    if isempty(nodes)
        return;
    end
    if nargin < 4 || isempty(order)
        order = getNodeIds(nodes);
    end

    state = initialConstraintState(ctx);
    ids = getNodeIds(nodes);
    nodeReports = cell(1, numel(order));

    for i = 1:numel(order)
        idx = find(strcmp(ids, order{i}), 1, 'first');
        if isempty(idx)
            continue;
        end
        node = nodes(idx);
        nodeReport = evaluateNodeBinding(node, state);
        nodeReports{i} = nodeReport;
        key = matlab.lang.makeValidName(char(string(node.id)));
        report.nodes.(key) = nodeReport;
        switch nodeReport.status
            case 'invalid'
                report.errors{end+1} = nodeReport.message; %#ok<AGROW>
            case 'needs_user_binding'
                if strcmpi(char(string(getField(nodeReport, 'resolveAt', 'run'))), 'design')
                    report.errors{end+1} = nodeReport.message; %#ok<AGROW>
                else
                    report.warnings{end+1} = nodeReport.message; %#ok<AGROW>
                end
                report.needsUserBinding{end+1} = char(string(node.id)); %#ok<AGROW>
            case 'needs_run_binding'
                report.warnings{end+1} = nodeReport.message; %#ok<AGROW>
                report.needsRunBinding{end+1} = char(string(node.id)); %#ok<AGROW>
            case 'auto_resolvable'
                report.autoResolvable{end+1} = char(string(node.id)); %#ok<AGROW>
        end
        state = applyConstraintOutputs(node, state, nodeReport);
    end

    report.nodes = annotateDownstreamBindingDemand(nodes, edges, order, report.nodes);
end

function state = initialConstraintState(ctx)
    sem = initialSemanticState(ctx);
    state = struct( ...
        'hasImages', sem.hasImages, ...
        'hasRoiList', sem.hasRoiList, ...
        'hasMasks', sem.hasMasks || sem.roiHasMasks, ...
        'hasDataSeries', sem.hasDataSeries || sem.roiHasDataSeries, ...
        'imageChannels', {sem.imageChannels}, ...
        'roiChannels', {sem.roiChannels}, ...
        'resources', initialResourceInventory(ctx, sem), ...
        'ctx', ctx);
end

function nodeReport = evaluateNodeBinding(node, state)
    contract = getField(node, 'contract', struct());
    binding = getField(contract, 'binding', struct());
    selectors = getField(contract, 'selectors', struct());
    requirements = getField(contract, 'requirements', struct());

    scope = lower(char(string(getBindingScope(binding, requirements))));
    requiredCount = resolveBindingRequiredCount(node, binding, requirements, selectors);
    configuredChannels = resolveBindingConfiguredChannels(node, binding, selectors);
    configuredChannels = removeResourceOnlyConfiguredChannelValues(node, configuredChannels);
    availableChannels = {};
    supportAvailable = true;

    switch scope
        case 'images'
            availableChannels = state.imageChannels;
            supportAvailable = state.hasImages;
        case 'roi'
            availableChannels = state.roiChannels;
            supportAvailable = state.hasRoiList;
    end
    availableChannels = mergeKnownChannels(availableChannels, compatibleResourceConcreteNamesForBinding(node, state.resources));

    symbolicChannelCollectionSelected = hasSymbolicChannelCollectionSelection(node, binding, selectors);
    symbolicResourceSelected = hasSymbolicResourceSelection(node, binding, selectors);
    configuredChannels = configuredChannels(~isSymbolicChannelSelectionCell(configuredChannels));
    configuredChannels = expandChannelPatternSelections(configuredChannels, availableChannels);
    allChannelsSelected = isAllChannelSelection(configuredChannels) || symbolicChannelCollectionSelected;
    if allChannelsSelected
        if ~isempty(availableChannels)
            configuredChannels = availableChannels;
        else
            configuredChannels = {};
        end
    end

    status = 'resolved';
    message = 'No explicit channel binding requirement.';
    autoChoice = {};
    exactCount = getBindingExactCount(node, binding);
    if isempty(exactCount) || exactCount <= 0
        exactCount = [];
    end

    if ~legacyChannelBindingApplies(binding)
        nodeReport = makeBindingNodeReport(node, binding, scope, status, message, 0, [], {}, availableChannels, autoChoice);
        nodeReport = attachResourceBindingReport(nodeReport, node, state);
        return;
    end

    if requiredCount <= 0 && isempty(configuredChannels)
        nodeReport = makeBindingNodeReport(node, binding, scope, status, message, requiredCount, exactCount, configuredChannels, availableChannels, autoChoice);
        nodeReport = attachResourceBindingReport(nodeReport, node, state);
        return;
    end

    if symbolicResourceSelected && isempty(configuredChannels)
        message = ['Node ' char(string(node.id)) ' uses a symbolic resource binding for its channel selection.'];
        nodeReport = makeBindingNodeReport(node, binding, scope, status, message, requiredCount, exactCount, configuredChannels, availableChannels, autoChoice);
        nodeReport = attachResourceBindingReport(nodeReport, node, state);
        return;
    end

    if ~supportAvailable
        status = 'invalid';
        if strcmp(scope, 'images')
            message = ['Node ' char(string(node.id)) ' requires source image channels, but no image-producing upstream path is available.'];
        else
            message = ['Node ' char(string(node.id)) ' requires ROI channels, but no ROI-producing upstream path is available.'];
        end
        nodeReport = makeBindingNodeReport(node, binding, scope, status, message, requiredCount, exactCount, configuredChannels, availableChannels, autoChoice);
        nodeReport = attachResourceBindingReport(nodeReport, node, state);
        return;
    end

    if ~isempty(configuredChannels)
        missingChoices = 0;
        if ~isempty(exactCount)
            missingChoices = exactCount - numel(configuredChannels);
            if numel(configuredChannels) > exactCount
                status = 'invalid';
                message = ['Node ' char(string(node.id)) ' selects ' num2str(numel(configuredChannels)) ...
                    ' channel(s), but the contract expects exactly ' num2str(exactCount) '.'];
            elseif missingChoices > 0
                if ~isempty(availableChannels) && numel(availableChannels) < exactCount
                    status = 'invalid';
                    message = ['Node ' char(string(node.id)) ' expects exactly ' num2str(exactCount) ...
                        ' channel(s), but only ' num2str(numel(availableChannels)) ' are visible upstream.'];
                else
                    status = classifyUnresolvedBinding(binding, availableChannels);
                    message = ['Node ' char(string(node.id)) ' still needs ' num2str(missingChoices) ...
                        ' more channel selection(s) to satisfy its exact binding.'];
                end
            else
                [status, message] = validateConfiguredChannelSelection(node, scope, requiredCount, configuredChannels, availableChannels, state);
            end
        elseif numel(configuredChannels) < requiredCount
            if ~isempty(availableChannels) && numel(availableChannels) < requiredCount
                status = 'invalid';
                message = ['Node ' char(string(node.id)) ' requires at least ' num2str(requiredCount) ...
                    ' channel(s), but only ' num2str(numel(availableChannels)) ' are visible upstream.'];
            else
                status = classifyUnresolvedBinding(binding, availableChannels);
                message = ['Node ' char(string(node.id)) ' needs at least ' num2str(requiredCount) ...
                    ' selected channel(s), but only ' num2str(numel(configuredChannels)) ' are configured.'];
            end
        else
            [status, message] = validateConfiguredChannelSelection(node, scope, requiredCount, configuredChannels, availableChannels, state);
        end
    else
        if isempty(availableChannels)
            status = classifyUnresolvedBinding(binding, availableChannels);
            if allChannelsSelected
                message = ['Node ' char(string(node.id)) ' requests all available channels, but the upstream channel inventory is not known statically.'];
            else
                message = ['Node ' char(string(node.id)) ' depends on channel binding, but the upstream channel inventory is not known statically.'];
            end
        elseif numel(availableChannels) < requiredCount
            status = 'invalid';
            message = ['Node ' char(string(node.id)) ' requires ' num2str(requiredCount) ...
                ' channel(s), but only ' num2str(numel(availableChannels)) ' are available upstream.'];
        elseif ~isempty(exactCount) && numel(availableChannels) == exactCount
            status = 'auto_resolvable';
            autoChoice = availableChannels(:)';
            message = ['Node ' char(string(node.id)) ' can be resolved automatically from upstream: ' strjoin(autoChoice, ', ') '.'];
        elseif requiredCount == 1 && numel(availableChannels) == 1
            status = 'auto_resolvable';
            autoChoice = availableChannels(1);
            message = ['Node ' char(string(node.id)) ' has a single compatible upstream channel: ' char(string(autoChoice{1})) '.'];
        else
            status = 'needs_user_binding';
            if ~isempty(exactCount)
                message = ['Node ' char(string(node.id)) ' expects exactly ' num2str(exactCount) ...
                    ' channel(s) and has multiple compatible upstream choices.'];
            else
                message = ['Node ' char(string(node.id)) ' needs channel selection from upstream choices.'];
            end
        end
    end

    nodeReport = makeBindingNodeReport(node, binding, scope, status, message, requiredCount, exactCount, configuredChannels, availableChannels, autoChoice);
    nodeReport = attachResourceBindingReport(nodeReport, node, state);
end

function [status, message] = validateConfiguredChannelSelection(node, scope, requiredCount, configuredChannels, availableChannels, state)
    if nargin < 6 || ~isstruct(state)
        state = struct();
    end
    if isempty(configuredChannels)
        status = 'resolved';
        message = formatResolvedBindingMessage(node, requiredCount, configuredChannels);
        return;
    end

    configuredLower = normalizedLowerNameList(configuredChannels);
    availableLower = normalizedLowerNameList(availableChannels);
    unknown = {};
    if ~isempty(availableChannels)
        unknown = setdiff(configuredLower, availableLower, 'stable');
    end
    if isempty(unknown)
        status = 'resolved';
        message = formatResolvedBindingMessage(node, requiredCount, configuredChannels);
        return;
    end

    unknownDisplay = configuredChannels(ismember(configuredLower, unknown));
    unknownDisplay = unique(unknownDisplay, 'stable');
    status = 'invalid';

    sourceHints = {};
    if strcmp(scope, 'roi')
        sourceLower = normalizedLowerNameList(getField(state, 'imageChannels', {}));
        if ~isempty(sourceLower)
            sourceHints = configuredChannels(ismember(configuredLower, sourceLower));
            sourceHints = unique(sourceHints, 'stable');
        end
    end

    if strcmp(scope, 'roi') && ~isempty(sourceHints)
        message = ['Node ' char(string(node.id)) ' references ROI channel(s) that are not available in the current project: ' ...
            strjoin(unknownDisplay, ', ') '. These values look like source/raw channel names.'];
        if ~isempty(availableChannels)
            message = [message ' Visible ROI channels: ' strjoin(availableChannels, ', ') '.'];
        end
    else
        message = ['Node ' char(string(node.id)) ' references unknown channel(s): ' strjoin(unknownDisplay, ', ') '.'];
        if ~isempty(availableChannels)
            message = [message ' Visible channels: ' strjoin(availableChannels, ', ') '.'];
        end
    end
end

function nodeReport = makeBindingNodeReport(node, binding, scope, status, message, requiredCount, exactCount, configuredChannels, availableChannels, autoChoice)
    nodeReport = struct( ...
        'nodeId', char(string(getField(node, 'id', ''))), ...
        'scope', char(string(scope)), ...
        'mode', char(string(getField(binding, 'mode', ''))), ...
        'resolveAt', char(string(getField(binding, 'resolveAt', 'run'))), ...
        'status', char(string(status)), ...
        'message', char(string(message)), ...
        'requiredCount', double(requiredCount), ...
        'exactCount', exactCount, ...
        'configuredChannels', {configuredChannels}, ...
        'availableChannels', {availableChannels}, ...
        'autoChoice', {autoChoice}, ...
        'producedChannelName', {resolveNodeProducedChannelName(node, binding)}, ...
        'resources', struct('inputs', {resourceBindingDef()}, 'outputs', {resourceBindingDef()}), ...
        'downstreamDemand', []);
end

function tf = legacyChannelBindingApplies(binding)
    mode = lower(char(string(getField(binding, 'mode', ''))));
    tf = ~any(strcmp(mode, {'inventory','dataseries','data_series','mask','masks','resource','resources','symbolic'}));
end

function nodeReport = attachResourceBindingReport(nodeReport, node, state)
    contract = getField(node, 'contract', struct());
    resources = getField(contract, 'resources', struct());
    inputs = getField(resources, 'in', resourceSpecDef());
    outputs = getField(resources, 'out', resourceSpecDef());

    inputReports = resourceBindingDef();
    worstStatus = nodeReport.status;
    worstMessage = nodeReport.message;
    for i = 1:numel(inputs)
        r = inputs(i);
        if isempty(getField(r, 'type', ''))
            continue;
        end
        br = evaluateResourceInput(node, r, state.resources, getField(state, 'ctx', struct()));
        inputReports(end+1) = br; %#ok<AGROW>
        if resourceStatusRank(br.status) > resourceStatusRank(worstStatus)
            worstStatus = br.status;
            worstMessage = br.message;
        end
    end

    outputReports = resourceBindingDef();
    for i = 1:numel(outputs)
        r = outputs(i);
        if isempty(getField(r, 'type', ''))
            continue;
        end
        outputReports(end+1) = makeResourceOutput(node, r); %#ok<AGROW>
    end
    outputReports = expandAllRoiExtractChannelOutputs(node, nodeReport, state, outputReports);

    nodeReport.resources = struct('inputs', {inputReports}, 'outputs', {outputReports});
    if ~strcmp(worstStatus, nodeReport.status)
        nodeReport.status = worstStatus;
        nodeReport.message = worstMessage;
    elseif ~isempty(inputReports) && strcmp(nodeReport.status, 'resolved')
        unresolved = inputReports(~strcmp({inputReports.status}, 'resolved'));
        if ~isempty(unresolved)
            nodeReport.status = unresolved(1).status;
            nodeReport.message = unresolved(1).message;
        end
    end
    nodeReport = reconcileLegacyChannelReportWithResources(nodeReport, inputReports);
end

function nodeReport = reconcileLegacyChannelReportWithResources(nodeReport, inputReports)
    if ~strcmpi(char(string(getField(nodeReport, 'status', ''))), 'invalid') || isempty(inputReports)
        return;
    end

    configured = normalizeChannelList(getField(nodeReport, 'configuredChannels', {}));
    available = normalizeChannelList(getField(nodeReport, 'availableChannels', {}));
    if isempty(configured)
        return;
    end

    configuredLower = normalizedLowerNameList(configured);
    availableLower = normalizedLowerNameList(available);
    missingLower = setdiff(configuredLower, availableLower, 'stable');
    if isempty(missingLower)
        return;
    end

    covered = {};
    for i = 1:numel(inputReports)
        status = lower(char(string(getField(inputReports(i), 'status', ''))));
        if ~any(strcmp(status, {'resolved', 'auto_resolvable'}))
            continue;
        end
        covered = mergeKnownChannels(covered, normalizeChannelList(getField(inputReports(i), 'configured', ''))); %#ok<AGROW>
        covered = mergeKnownChannels(covered, normalizeChannelList(getField(inputReports(i), 'concreteName', ''))); %#ok<AGROW>
        covered = mergeKnownChannels(covered, normalizeChannelList(getField(inputReports(i), 'symbol', ''))); %#ok<AGROW>
    end
    coveredLower = normalizedLowerNameList(covered);
    if isempty(setdiff(missingLower, coveredLower, 'stable'))
        nodeReport.status = 'resolved';
        nodeReport.message = ['Node ' char(string(getField(nodeReport, 'nodeId', ''))) ...
            ' binds configured channel input(s) through upstream resources.'];
        nodeReport.availableChannels = mergeKnownChannels(available, covered);
    end
end

function outputs = expandAllRoiExtractChannelOutputs(node, nodeReport, state, outputs)
    if ~strcmpi(char(string(getField(node, 'type', ''))), 'roiExtract') || isempty(outputs)
        return;
    end
    channels = projectedRoiExtractChannels(node, nodeReport, state);
    channels = normalizeChannelList(channels);
    channels = channels(~isAllChannelSelectionCell(channels));
    if isempty(channels)
        return;
    end
    keep = true(size(outputs));
    for i = 1:numel(outputs)
        if strcmpi(outputs(i).type, 'channel') && strcmpi(outputs(i).role, 'roi_image') && ...
                isAllChannelSelection({outputs(i).concreteName})
            keep(i) = false;
        end
    end
    outputs = outputs(keep);
    for i = 1:numel(channels)
        item = resourceBindingDef('channel', 'roi_image', channels{i}, channels{i}, ...
            char(string(getField(node, 'id', ''))), 'channels', 'imagesToRoi');
        item.param = 'channels';
        item.message = sprintf('Node %s provides channel/roi_image resource "%s".', ...
            char(string(getField(node, 'id', ''))), channels{i});
        outputs(end+1) = item; %#ok<AGROW>
    end
end

function tf = isSingleChannelResourceSpec(spec)
    tf = false;
    if ~strcmpi(char(string(getField(spec, 'type', ''))), 'channel')
        return;
    end
    param = lower(char(string(getField(spec, 'param', ''))));
    required = logical(getField(spec, 'required', false));
    singularParams = {'channel','inputchannelname','instancechannelname'};
    tf = required || any(strcmp(param, singularParams)) || ...
        ~isempty(regexp(param, '^mask\d+_name$', 'once')) || ...
        ~isempty(regexp(param, '^channel\d+_name$', 'once'));
end

function tf = isAmbiguousCollectionResource(resource, spec)
    tf = false;
    if ~isSingleChannelResourceSpec(spec)
        return;
    end
    sourceKind = lower(char(string(getField(resource, 'sourceKind', ''))));
    if any(strcmp(sourceKind, {'context','ctx','runtime'}))
        return;
    end
    sourceNode = lower(char(string(getField(resource, 'sourceNode', ''))));
    sourcePort = lower(char(string(getField(resource, 'sourcePort', ''))));
    symbol = lower(char(string(getField(resource, 'symbol', ''))));
    concrete = lower(strtrim(char(string(getField(resource, 'concreteName', '')))));

    hasConcreteSingle = ~isempty(concrete) && ...
        ~startsWith(concrete, '@') && ...
        ~any(strcmp(concrete, {'channels','all','*',':',sourceNode}));
    if hasConcreteSingle
        return;
    end

    tf = any(strcmp(sourceKind, {'sourceinventory','imagestoroi'})) || ...
        strcmp(sourcePort, 'channels') || ...
        endsWith(symbol, '.channels');
end

function br = evaluateResourceInput(node, spec, availableResources, ctx)
    if nargin < 4 || isempty(ctx)
        ctx = struct();
    end
    [hasConfiguredRaw, configuredRaw] = resolveResourceRawValue(node, spec);
    configured = resolveResourceConfiguredValue(node, spec);
    symbolic = resolveResourceSymbolicValue(node, spec);
    compatible = findCompatibleResources(availableResources, spec);
    graphCompatible = nonContextResources(compatible);
    configuredPatternMatches = resourcePatternMatchesConfiguredValue(configured, compatible, spec);
    [configuredChannelSet, configuredChannelSetMatches, configuredChannelSetMissing] = ...
        resourceConfiguredChannelSetMatches(hasConfiguredRaw, configuredRaw, compatible, spec);
    status = 'resolved';
    autoChoice = resourceInventoryDef();

    if ~isempty(configuredChannelSet)
        autoChoice = configuredChannelSetMatches;
        if isempty(configuredChannelSetMissing)
            msg = sprintf('Node %s binds %d channel resource(s) to %s.', ...
                char(string(getField(node, 'id', ''))), numel(configuredChannelSet), char(string(spec.param)));
        else
            status = 'invalid';
            msg = sprintf('Node %s binds channel resources to %s, but these value(s) are not available upstream: %s.', ...
                char(string(getField(node, 'id', ''))), char(string(spec.param)), strjoin(configuredChannelSetMissing, ', '));
        end
    elseif ~isempty(configured)
        if isChannelPatternSelector(configured)
            if isempty(configuredPatternMatches)
                status = 'invalid';
                msg = sprintf('Node %s binds %s resource pattern "%s" to %s, but it matches no compatible upstream resource.', ...
                    char(string(getField(node, 'id', ''))), char(string(spec.type)), configured, char(string(spec.param)));
            else
                autoChoice = configuredPatternMatches;
                msg = sprintf('Node %s binds %s resource pattern "%s" to %s (%d match(es)).', ...
                    char(string(getField(node, 'id', ''))), char(string(spec.type)), configured, char(string(spec.param)), numel(configuredPatternMatches));
            end
        else
            msg = sprintf('Node %s binds %s resource "%s" to %s.', ...
                char(string(getField(node, 'id', ''))), char(string(spec.type)), configured, char(string(spec.param)));
        end
    elseif ~isempty(symbolic)
        symbolicChoice = findSymbolicResourceChoice(compatible, symbolic);
        if isempty(symbolicChoice)
            symbolicChoice = findExistingConcreteChoiceForSymbolicBinding(symbolic, spec, compatible, ctx);
        end
        if numel(symbolicChoice) == 1
            status = 'auto_resolvable';
            autoChoice = symbolicChoice;
            msg = sprintf('Node %s keeps symbolic %s/%s binding to %s.', ...
                char(string(getField(node, 'id', ''))), char(string(spec.type)), char(string(spec.role)), ...
                resourceSourceLabel(symbolicChoice));
        elseif numel(symbolicChoice) > 1
            status = 'needs_user_binding';
            msg = sprintf('Node %s symbolic %s/%s binding is ambiguous for %s.', ...
                char(string(getField(node, 'id', ''))), char(string(spec.type)), char(string(spec.role)), symbolic);
        else
            if isOptionalSourceChannelSpec(spec)
                msg = sprintf('Node %s keeps source channel binding symbolic; source channels will be resolved at run time.', ...
                    char(string(getField(node, 'id', ''))));
            else
                status = 'invalid';
                msg = sprintf('Node %s symbolic %s/%s binding points to %s, but no matching resource is available upstream.', ...
                    char(string(getField(node, 'id', ''))), char(string(spec.type)), char(string(spec.role)), symbolic);
            end
        end
    elseif ~logical(getField(spec, 'required', false))
        msg = sprintf('Node %s has optional %s/%s resource binding.', ...
            char(string(getField(node, 'id', ''))), char(string(spec.type)), char(string(spec.role)));
    elseif numel(graphCompatible) == 1
        status = 'auto_resolvable';
        autoChoice = graphCompatible;
        msg = sprintf('Node %s can bind %s/%s automatically from upstream %s.', ...
            char(string(getField(node, 'id', ''))), char(string(spec.type)), char(string(spec.role)), ...
            resourceSourceLabel(graphCompatible));
    elseif numel(graphCompatible) > 1
        status = 'needs_user_binding';
        msg = sprintf('Node %s needs a %s/%s resource selection; multiple compatible upstream module resources exist.', ...
            char(string(getField(node, 'id', ''))), char(string(spec.type)), char(string(spec.role)));
    elseif numel(compatible) == 1
        status = 'auto_resolvable';
        autoChoice = compatible;
        msg = sprintf('Node %s can bind %s/%s automatically from %s.', ...
            char(string(getField(node, 'id', ''))), char(string(spec.type)), char(string(spec.role)), ...
            resourceSourceLabel(compatible));
    elseif numel(compatible) > 1
        status = 'needs_user_binding';
        msg = sprintf('Node %s needs a %s/%s resource selection; multiple compatible upstream resources exist.', ...
            char(string(getField(node, 'id', ''))), char(string(spec.type)), char(string(spec.role)));
    elseif logical(getField(spec, 'required', false))
        status = 'needs_run_binding';
        msg = sprintf('Node %s requires %s/%s resource for parameter %s, but none is available upstream yet.', ...
            char(string(getField(node, 'id', ''))), char(string(spec.type)), char(string(spec.role)), char(string(spec.param)));
    else
        msg = sprintf('Node %s has optional %s/%s resource binding.', ...
            char(string(getField(node, 'id', ''))), char(string(spec.type)), char(string(spec.role)));
    end

    br = resourceBindingDef('', '', '', '', '', '', '');
    br.type = char(string(spec.type));
    br.role = char(string(spec.role));
    br.symbol = char(string(spec.symbol));
    br.param = char(string(spec.param));
    br.status = status;
    br.message = msg;
    br.configured = configured;
    br.available = compatible;
    br.autoChoice = autoChoice;
end

function [names, matches, missing] = resourceConfiguredChannelSetMatches(hasRaw, raw, compatibleResources, spec)
    names = {};
    matches = resourceInventoryDef();
    missing = {};
    if ~hasRaw || ~strcmpi(char(string(getField(spec, 'type', ''))), 'channel')
        return;
    end
    if isSymbolicResourceBinding(raw)
        return;
    end
    names = normalizeChannelList(raw);
    names = names(~isAllChannelSelectionCell(names));
    if numel(names) <= 1
        names = {};
        return;
    end

    compatibleResources = normalizeResourceInventory(compatibleResources);
    for i = 1:numel(names)
        name = strtrim(char(string(names{i})));
        if isempty(name)
            continue;
        end
        one = findCompatibleResourceByConfiguredChannelName(name, compatibleResources);
        if isempty(one)
            missing{end+1} = name; %#ok<AGROW>
        else
            matches = mergeResourceInventory(matches, one); %#ok<AGROW>
        end
    end
    missing = unique(missing, 'stable');
end

function match = findCompatibleResourceByConfiguredChannelName(name, compatibleResources)
    match = resourceInventoryDef();
    if isempty(name)
        return;
    end
    if isChannelPatternSelector(name)
        rx = channelPatternToRegexp(name);
        for i = 1:numel(compatibleResources)
            concreteName = strtrim(char(string(getField(compatibleResources(i), 'concreteName', ''))));
            symbol = strtrim(char(string(getField(compatibleResources(i), 'symbol', ''))));
            if (~isempty(concreteName) && ~isempty(regexp(concreteName, rx, 'once'))) || ...
                    (~isempty(symbol) && ~isempty(regexp(symbol, rx, 'once')))
                match(end+1) = compatibleResources(i); %#ok<AGROW>
            end
        end
        return;
    end
    for i = 1:numel(compatibleResources)
        concreteName = strtrim(char(string(getField(compatibleResources(i), 'concreteName', ''))));
        symbol = strtrim(char(string(getField(compatibleResources(i), 'symbol', ''))));
        if strcmpi(concreteName, name) || strcmpi(symbol, name)
            match(end+1) = compatibleResources(i); %#ok<AGROW>
        end
    end
end

function matches = resourcePatternMatchesConfiguredValue(configured, compatibleResources, spec)
    matches = resourceInventoryDef();
    if isempty(configured) || ~strcmpi(char(string(getField(spec, 'type', ''))), 'channel')
        return;
    end
    configured = strtrim(char(string(configured)));
    if ~isChannelPatternSelector(configured)
        return;
    end
    rx = channelPatternToRegexp(configured);
    compatibleResources = normalizeResourceInventory(compatibleResources);
    for i = 1:numel(compatibleResources)
        concreteName = strtrim(char(string(getField(compatibleResources(i), 'concreteName', ''))));
        symbol = strtrim(char(string(getField(compatibleResources(i), 'symbol', ''))));
        if (~isempty(concreteName) && ~isempty(regexp(concreteName, rx, 'once'))) || ...
                (~isempty(symbol) && ~isempty(regexp(symbol, rx, 'once')))
            matches(end+1) = compatibleResources(i); %#ok<AGROW>
        end
    end
end

function rank = resourceStatusRank(status)
    switch char(string(status))
        case 'invalid'
            rank = 4;
        case 'needs_user_binding'
            rank = 3;
        case 'needs_run_binding'
            rank = 2;
        case 'auto_resolvable'
            rank = 1;
        otherwise
            rank = 0;
    end
end

function state = applyConstraintOutputs(node, state, nodeReport)
    contract = getField(node, 'contract', struct());
    capabilities = getField(contract, 'capabilities', struct());
    binding = getField(contract, 'binding', struct());
    nodeType = lower(char(string(getField(node, 'type', ''))));

    if logical(getField(capabilities, 'outputsImages', false))
        state.hasImages = true;
    end
    if logical(getField(capabilities, 'outputsFovList', false))
        state.hasImages = true;
    end
    if any(strcmp(outputNames(node), 'roiList')) || logical(getField(capabilities, 'preservesRoiList', false)) || logical(getField(capabilities, 'createsRoiList', false))
        state.hasRoiList = true;
    end
    if logical(getField(capabilities, 'outputsMasks', false)) || logical(getField(capabilities, 'roiMasks', false))
        state.hasMasks = true;
    end
    if logical(getField(capabilities, 'outputsDataSeries', false)) || logical(getField(capabilities, 'roiDataSeries', false))
        state.hasDataSeries = true;
    end

    if isfield(nodeReport, 'resources') && isstruct(nodeReport.resources) && ...
            isfield(nodeReport.resources, 'outputs') && ~isempty(nodeReport.resources.outputs)
        state.resources = mergeResourceInventory(state.resources, nodeReport.resources.outputs);
    end

    if strcmp(nodeType, 'dataloader')
        state.imageChannels = mergeKnownChannels(state.imageChannels, getField(nodeReport, 'configuredChannels', {}));
        state.imageChannels = mergeKnownChannels(state.imageChannels, resourceConcreteNames(state.resources, 'channel', 'source'));
        return;
    end

    producedName = getField(nodeReport, 'producedChannelName', {});
    producedResourceChannels = {};
    try
        if isfield(nodeReport, 'resources') && isstruct(nodeReport.resources) && ...
                isfield(nodeReport.resources, 'outputs') && ~isempty(nodeReport.resources.outputs)
            producedResourceChannels = resourceConcreteNames(nodeReport.resources.outputs, 'channel', '');
        end
    catch
        producedResourceChannels = {};
    end
    if strcmp(nodeType, 'roiextract')
        chosen = projectedRoiExtractChannels(node, nodeReport, state);
        if isempty(chosen)
            chosen = getField(nodeReport, 'availableChannels', {});
        end
        state.roiChannels = mergeKnownChannels(state.roiChannels, mergeKnownChannels(chosen, mergeKnownChannels(producedName, producedResourceChannels)));
        state.roiChannels = mergeKnownChannels(state.roiChannels, resourceConcreteNames(state.resources, 'channel', 'roi_image'));
        return;
    end

    if logical(getField(capabilities, 'roiChannels', false)) || strcmp(getField(binding, 'outputScope', ''), 'roi')
        produced = mergeKnownChannels(getField(nodeReport, 'configuredChannels', {}), mergeKnownChannels(producedName, producedResourceChannels));
        state.roiChannels = mergeKnownChannels(state.roiChannels, produced);
    elseif logical(getField(capabilities, 'outputsChannels', false))
        produced = mergeKnownChannels(getField(nodeReport, 'configuredChannels', {}), mergeKnownChannels(producedName, producedResourceChannels));
        state.imageChannels = mergeKnownChannels(state.imageChannels, produced);
    end

end

function channels = projectedRoiExtractChannels(node, nodeReport, state)
    channels = {};
    if validationStartsFromExistingProject(getField(state, 'ctx', struct())) && ...
            roiExtractUsesProjectRoiChannelInventory(node)
        channels = normalizeChannelList(getField(state, 'roiChannels', {}));
        channels = channels(~isAllChannelSelectionCell(channels));
        if ~isempty(channels)
            return;
        end
    end

    channels = getField(nodeReport, 'configuredChannels', {});
    channels = normalizeChannelList(channels);
    channels = channels(~isAllChannelSelectionCell(channels));
    if ~isempty(channels)
        return;
    end

    channels = normalizeChannelList(getField(state, 'imageChannels', {}));
    channels = channels(~isAllChannelSelectionCell(channels));
end

function tf = validationStartsFromExistingProject(ctx)
    tf = false;
    try
        inputSource = lower(strtrim(char(string(getField(getField(ctx, 'run', struct()), 'inputSource', '')))));
        inputMode = lower(strtrim(char(string(getField(getField(ctx, 'run', struct()), 'inputSourceMode', '')))));
        tf = contains(inputSource, 'existing') || strcmp(inputMode, 'existing_rois');
    catch
        tf = false;
    end
end

function tf = roiExtractUsesProjectRoiChannelInventory(node)
    tf = false;
    try
        params = getField(node, 'params', struct());
        extractChannels = getField(params, 'extractChannels', []);
        configured = normalizeConfiguredSelectionValue(extractChannels);
        if isempty(configured)
            tf = true;
            return;
        end
        txt = lower(strtrim(choiceToString(extractChannels)));
        tf = startsWith(txt, '@') || isAllChannelSelection(configured);
    catch
        tf = false;
    end
end

function outStruct = annotateDownstreamBindingDemand(nodes, edges, order, reports)
    outStruct = reports;
    if isempty(nodes) || isempty(order)
        return;
    end
    ids = getNodeIds(nodes);
    demandMap = containers.Map('KeyType', 'char', 'ValueType', 'any');

    for i = numel(order):-1:1
        nodeId = char(string(order{i}));
        idx = find(strcmp(ids, nodeId), 1, 'first');
        if isempty(idx)
            continue;
        end
        node = nodes(idx);
        nodeKey = matlab.lang.makeValidName(nodeId);
        nodeReport = getField(outStruct, nodeKey, struct());
        localDemand = max([0 double(getField(nodeReport, 'requiredCount', 0)) double(getDownstreamDemandValue(demandMap, nodeId))]);
        propagated = propagateNodeDemand(node, localDemand);
        if propagated > 0
            preds = incomingNodeIds(edges, nodeId);
            for j = 1:numel(preds)
                prev = getDownstreamDemandValue(demandMap, preds{j});
                demandMap(preds{j}) = max(prev, propagated);
            end
        end
        if ~isempty(fieldnames(nodeReport))
            nodeReport.downstreamDemand = localDemand;
            if localDemand > 0 && any(strcmpi(char(string(getField(node, 'type', ''))), {'roiextract','dataloader'}))
                if strcmpi(char(string(getField(node, 'type', ''))), 'roiextract')
                    nodeReport.message = [char(string(nodeReport.message)) ' Downstream requires at least ' num2str(localDemand) ' ROI channel(s) from this extraction path.'];
                elseif strcmpi(char(string(getField(node, 'type', ''))), 'dataloader')
                    nodeReport.message = [char(string(nodeReport.message)) ' Downstream requires at least ' num2str(localDemand) ' source image channel(s) from the dataloader path.'];
                end
            end
            outStruct.(nodeKey) = nodeReport;
        end
    end
end

function ids = incomingNodeIds(edges, nodeId)
    ids = {};
    if isempty(edges)
        return;
    end
    for i = 1:numel(edges)
        if strcmp(char(string(getField(edges(i), 'to', ''))), nodeId)
            ids{end+1} = char(string(getField(edges(i), 'from', ''))); %#ok<AGROW>
        end
    end
    ids = unique(ids, 'stable');
end

function val = getDownstreamDemandValue(demandMap, nodeId)
    val = 0;
    if isKey(demandMap, nodeId)
        val = double(demandMap(nodeId));
    end
end

function outDemand = propagateNodeDemand(node, demand)
    outDemand = 0;
    if demand <= 0
        return;
    end
    nodeType = lower(char(string(getField(node, 'type', ''))));
    contract = getField(node, 'contract', struct());
    binding = getField(contract, 'binding', struct());
    scope = lower(char(string(getField(binding, 'scope', ''))));
    switch nodeType
        case 'roiextract'
            outDemand = demand;
        case 'dataloader'
            outDemand = demand;
        case {'roipattern','roiidentify','roimanual','roigrid','roitracked','processor','classifier'}
            if any(strcmp(scope, {'images','roi'}))
                outDemand = demand;
            end
        otherwise
            outDemand = 0;
    end
end

function [errors, warnings, artifactReport] = classifierArtifactIssues(node, ctx)
    errors = {};
    warnings = {};
    artifactReport = struct([]);
    if ~strcmpi(char(string(getField(node, 'type', ''))), 'classifier')
        return;
    end

    nodeId = char(string(getField(node, 'id', '')));
    pkgName = lower(char(string(getField(node, 'pkg', ''))));
    p = getField(node, 'params', struct());
    if isstruct(p) && isfield(p, 'pkg') && ~isempty(p.pkg)
        pkgName = lower(char(string(p.pkg)));
    end

    hasLinkedPath = isstruct(p) && isfield(p, 'modulePath') && ~isempty(p.modulePath);
    hasLinkedVar = isstruct(p) && isfield(p, 'moduleVar') && ~isempty(p.moduleVar);
    requiresLocalArtifacts = classifierRequiresLocalArtifacts(pkgName);
    if ~(hasLinkedPath || hasLinkedVar)
        warnings{end+1} = ['Classifier node ' nodeId ...
            ' is not linked to an existing classi object; model weights/training artifacts may be unavailable at run time.']; %#ok<AGROW>
        artifactReport = classifierArtifactReport(node, '', '', '', 'unlinked', '', '', false);
        return;
    end
    if ~hasLinkedPath
        warnings{end+1} = ['Classifier node ' nodeId ...
            ' is linked only by workspace variable; smoke/preflight cannot prove that model artifacts will be available in a batch or Hub run.']; %#ok<AGROW>
        artifactReport = classifierArtifactReport(node, '', '', '', 'workspace_only', '', '', false);
        return;
    end

    configuredPath = char(string(p.modulePath));
    moduleId = classifierModuleIdFromParams(p, configuredPath, nodeId);
    [modulePath, pathStatus, targetLabel] = resolveClassifierModulePathForValidation(configuredPath, moduleId, ctx);

    artifactReport = classifierArtifactReport(node, configuredPath, modulePath, moduleId, pathStatus, '', targetLabel, false);
    if isempty(modulePath) || exist(modulePath, 'dir') ~= 7
        msg = classifierRelinkMessage(nodeId, configuredPath, targetLabel, ...
            ['Linked classifier folder is not accessible for ' targetLabel '.']);
        if requiresLocalArtifacts
            errors{end+1} = msg;
        else
            warnings{end+1} = msg;
        end
        artifactReport.status = 'missing_module_path';
        return;
    end

    snapPath = classifierSnapshotPath(modulePath, moduleId);
    artifactReport.snapshotPath = snapPath;
    if isempty(snapPath) || exist(snapPath, 'file') ~= 2
        msg = classifierRelinkMessage(nodeId, configuredPath, targetLabel, ...
            sprintf('Linked classifier snapshot is missing under "%s" (expected %s_classification.mat).', modulePath, moduleId));
        if requiresLocalArtifacts
            errors{end+1} = msg;
        else
            warnings{end+1} = msg;
        end
        artifactReport.status = 'missing_snapshot';
        return;
    end

    switch pkgName
        case 'cnn_lstm'
            [modelOk, modelMessage, modelPath] = validateCnnLstmArtifacts(modulePath, moduleId, p);
            artifactReport.modelPath = modelPath;
            if ~modelOk
                errors{end+1} = classifierRelinkMessage(nodeId, configuredPath, targetLabel, modelMessage); %#ok<AGROW>
                artifactReport.status = 'missing_model';
                return;
            end
        case {'cellposesam','sam31'}
            % Python-backed classifiers may intentionally use package-managed
            % default weights or explicit checkpoint paths from their runtime
            % config. The linked classi snapshot is sufficient for pipeline
            % wiring; do not require a MATLAB <classifierId>.mat model file.
        otherwise
            modelPath = fullfile(modulePath, [moduleId '.mat']);
            artifactReport.modelPath = modelPath;
            if exist(modelPath, 'file') ~= 2
                warnings{end+1} = sprintf(['Classifier node %s is linked, but no default model file was found at %s. ' ...
                    'This may be valid for package "%s" if it uses external/default weights.'], nodeId, modelPath, pkgName); %#ok<AGROW>
            end
    end

    artifactReport.status = 'ok';
    artifactReport.accessible = true;
end

function [errors, warnings, reports] = nodePathIssues(node, ctx)
errors = {};
warnings = {};
reports = struct([]);

nodeType = lower(char(string(getField(node, 'type', ''))));
if ~strcmp(nodeType, 'processor')
    return;
end

p = getField(node, 'params', struct());
if ~isstruct(p)
    return;
end

outputKeys = {'outputDir','outputPath','outputFolder'};
for i = 1:numel(outputKeys)
    key = outputKeys{i};
    if ~isfield(p, key) || isempty(p.(key))
        continue;
    end
    [pathErrors, pathWarnings, rep] = validateProcessorOutputPath(node, key, p.(key), ctx);
    if ~isempty(rep)
        reports = appendStructArray(reports, rep);
    end
    if ~isempty(pathErrors)
        errors = [errors, pathErrors]; %#ok<AGROW>
    end
    if ~isempty(pathWarnings)
        warnings = [warnings, pathWarnings]; %#ok<AGROW>
    end
end
end

function [errors, warnings, report] = pluginPackageIssues(node, ctx)
errors = {};
warnings = {};
report = struct([]);

nodeType = lower(char(string(getField(node, 'type', ''))));
if ~any(strcmp(nodeType, {'processor','classifier'}))
    return;
end

pkgName = char(string(getField(node, 'pkg', '')));
p = getField(node, 'params', struct());
if isempty(pkgName) && isstruct(p) && isfield(p, 'pkg') && ~isempty(p.pkg)
    pkgName = char(string(p.pkg));
end
if isempty(pkgName)
    return;
end

[customRoot, customDir] = customPackagePathsForValidation(node, p, pkgName);
hasCustomLink = ~isempty(customRoot) || ~isempty(customDir);
registeredDir = registeredPluginPackageDirForValidation(pkgName, nodeType);
nodeId = char(string(getField(node, 'id', '')));

if isempty(customDir) && ~isempty(customRoot)
    customDir = fullfile(customRoot, ['+' pkgName]);
end

if hasCustomLink
    configuredPath = customDir;
    if isempty(configuredPath)
        configuredPath = customRoot;
    end
    [checkPath, status, targetLabel, serverPath] = resolveNodePathForValidation(configuredPath, ctx);
    accessible = ~isempty(checkPath) && exist(checkPath, 'dir') == 7;
    report = pluginPackageReport(node, customRoot, customDir, checkPath, serverPath, status, targetLabel, registeredDir, accessible);

    if accessible && ~packageFolderNameMatches(checkPath, pkgName)
        errors{end+1} = sprintf('Plugin package for node %s points to "%s", but expected a folder named +%s.', ...
            nodeId, checkPath, pkgName); %#ok<AGROW>
        return;
    end
    if accessible
        return;
    end

    msg = sprintf(['Plugin package for node %s is not accessible for %s. ' ...
        'Configured package path: %s.'], nodeId, targetLabel, configuredPath);
    if ~isempty(registeredDir)
        msg = sprintf('%s A registered copy exists at %s; relink the plugin in pipeline2 so runs and exports use the portable path.', ...
            msg, registeredDir);
    else
        msg = sprintf('%s Relink the plugin in pipeline2 or register/install the external plugin package.', msg);
    end
    errors{end+1} = msg; %#ok<AGROW>
    return;
end

if ~isempty(registeredDir)
    report = pluginPackageReport(node, customRoot, customDir, registeredDir, '', 'registered_unlinked', validationExecutionTargetLabel(ctx), registeredDir, true);
    warnings{end+1} = sprintf(['Plugin package "%s" for node %s is available in the plugin registry (%s), ' ...
        'but this pipeline node does not store a customPackageDir/customPackageRoot link. Relink it in pipeline2 before exporting a portable bundle.'], ...
        pkgName, nodeId, registeredDir); %#ok<AGROW>
end
end

function [customRoot, customDir] = customPackagePathsForValidation(node, params, pkgName)
customRoot = '';
customDir = '';
if isfield(node, 'customPackageRoot') && ~isempty(node.customPackageRoot)
    customRoot = char(string(node.customPackageRoot));
end
if isfield(node, 'customPackageDir') && ~isempty(node.customPackageDir)
    customDir = char(string(node.customPackageDir));
end
if isstruct(params)
    if isempty(customRoot) && isfield(params, 'customPackageRoot') && ~isempty(params.customPackageRoot)
        customRoot = char(string(params.customPackageRoot));
    end
    if isempty(customDir) && isfield(params, 'customPackageDir') && ~isempty(params.customPackageDir)
        customDir = char(string(params.customPackageDir));
    end
end
if isempty(customDir) && ~isempty(customRoot) && ~isempty(pkgName)
    customDir = fullfile(customRoot, ['+' pkgName]);
end
end

function report = pluginPackageReport(node, configuredRoot, configuredDir, resolvedDir, serverPath, status, targetLabel, registeredDir, accessible)
report = struct( ...
    'nodeId', char(string(getField(node, 'id', ''))), ...
    'type', char(string(getField(node, 'type', ''))), ...
    'package', char(string(getField(node, 'pkg', ''))), ...
    'configuredRoot', char(string(configuredRoot)), ...
    'configuredDir', char(string(configuredDir)), ...
    'resolvedDir', char(string(resolvedDir)), ...
    'serverPath', char(string(serverPath)), ...
    'registeredDir', char(string(registeredDir)), ...
    'target', char(string(targetLabel)), ...
    'status', char(string(status)), ...
    'accessible', logical(accessible));
end

function tf = packageFolderNameMatches(folderPath, pkgName)
tf = true;
try
    [~, leaf] = fileparts(char(string(folderPath)));
    expected = ['+' char(string(pkgName))];
    tf = strcmp(leaf, expected);
catch
    tf = true;
end
end

function packageDir = registeredPluginPackageDirForValidation(pkgName, nodeType)
packageDir = '';
try
    if exist('detecdiv_plugins_addpath', 'file') == 2
        detecdiv_plugins_addpath();
    end
    if exist('detecdiv_plugins_list', 'file') ~= 2
        return;
    end
    plugins = detecdiv_plugins_list();
    for i = 1:numel(plugins)
        if strcmp(char(string(plugins(i).name)), char(string(pkgName))) && ...
                strcmpi(char(string(plugins(i).type)), char(string(nodeType)))
            candidate = char(string(plugins(i).path));
            if exist(candidate, 'dir') == 7
                packageDir = candidate;
                return;
            end
        end
    end
catch
    packageDir = '';
end
end

function [errors, warnings, rep] = validateProcessorOutputPath(node, key, value, ctx)
errors = {};
warnings = {};
rep = struct([]);

if ~(ischar(value) || (isstring(value) && isscalar(value)))
    return;
end
configuredPath = char(string(value));
if isempty(strtrim(configuredPath))
    return;
end

[checkPath, status, targetLabel, serverPath] = resolveNodePathForValidation(configuredPath, ctx);
rep = struct( ...
    'nodeId', char(string(getField(node, 'id', ''))), ...
    'key', char(string(key)), ...
    'configuredPath', configuredPath, ...
    'resolvedPath', char(string(checkPath)), ...
    'serverPath', char(string(serverPath)), ...
    'target', char(string(targetLabel)), ...
    'status', char(string(status)));

nodeId = char(string(getField(node, 'id', '')));
if strcmp(status, 'unmapped_windows_path')
    errors{end+1} = sprintf(['Processor node %s output path %s is not runnable for %s. ' ...
        'Configured path %s cannot be mapped to a server-visible path.'], ...
        nodeId, key, targetLabel, configuredPath); %#ok<AGROW>
    return;
end

if strcmp(status, 'unmapped_server_path')
    warnings{end+1} = sprintf(['Processor node %s output path %s is configured as a server path (%s), ' ...
        'but this workstation cannot map it back to a local mirror for preflight verification.'], ...
        nodeId, key, configuredPath); %#ok<AGROW>
    return;
end

if isempty(checkPath)
    warnings{end+1} = sprintf('Processor node %s output path %s could not be resolved during validation.', nodeId, key); %#ok<AGROW>
    return;
end

if exist(checkPath, 'dir') == 7
    return;
end

parentDir = fileparts(checkPath);
if ~isempty(parentDir) && exist(parentDir, 'dir') == 7
    warnings{end+1} = sprintf(['Processor node %s output path %s does not exist yet (%s). ' ...
        'Its parent folder exists, so runtime may create it if the processor supports that.'], ...
        nodeId, key, checkPath); %#ok<AGROW>
else
    errors{end+1} = sprintf(['Processor node %s output path %s is not accessible for %s. ' ...
        'Configured path: %s. Checked path: %s.'], ...
        nodeId, key, targetLabel, configuredPath, checkPath); %#ok<AGROW>
end
end

function tf = classifierRequiresLocalArtifacts(pkgName)
    pkgName = lower(char(string(pkgName)));
    tf = ~any(strcmp(pkgName, {'cellposesam','sam31'}));
end

function msg = classifierRelinkMessage(nodeId, configuredPath, targetLabel, reason)
    msg = sprintf(['Classifier node %s linked classifier is not runnable. %s ' ...
        'Configured modulePath: %s. For %s, relink the classifier to an accessible folder, ' ...
        'export/copy the classifier module with its *_classification.mat and model .mat files, ' ...
        'or set a run override modulePath to the server-visible classifier folder.'], ...
        nodeId, reason, configuredPath, targetLabel);
end

function rep = classifierArtifactReport(node, configuredPath, resolvedPath, moduleId, status, snapshotPath, targetLabel, accessible)
    rep = struct( ...
        'nodeId', char(string(getField(node, 'id', ''))), ...
        'package', char(string(getField(node, 'pkg', ''))), ...
        'configuredPath', char(string(configuredPath)), ...
        'resolvedPath', char(string(resolvedPath)), ...
        'moduleId', char(string(moduleId)), ...
        'target', char(string(targetLabel)), ...
        'status', char(string(status)), ...
        'accessible', logical(accessible), ...
        'snapshotPath', char(string(snapshotPath)), ...
        'modelPath', '');
end

function moduleId = classifierModuleIdFromParams(p, configuredPath, nodeId)
    moduleId = '';
    try
        if isstruct(p) && isfield(p, 'moduleId') && ~isempty(p.moduleId)
            moduleId = char(string(p.moduleId));
        elseif isstruct(p) && isfield(p, 'outputName') && ~isempty(p.outputName)
            moduleId = char(string(p.outputName));
        end
    catch
        moduleId = '';
    end
    if isempty(moduleId)
        [~, moduleId] = fileparts(configuredPath);
    end
    if isempty(moduleId)
        moduleId = nodeId;
    end
end

function [modulePath, status, targetLabel] = resolveClassifierModulePathForValidation(configuredPath, moduleId, ctx)
    targetLabel = validationExecutionTargetLabel(ctx);
    status = 'configured';
    modulePath = '';

    if isempty(configuredPath)
        status = 'missing';
        return;
    end

    if ~ispc && looksLikeWindowsAbsPathLocal(configuredPath)
        [mappedPath, mapped] = mapLocalPathToHubServerPath(configuredPath, ctx);
        if mapped
            modulePath = mappedPath;
            status = 'mapped';
        end
    end

    if isHubValidationTarget(ctx)
        if ispc
            [checkPath, mapped] = mapHubClassifierPathToLocalCheckPath(configuredPath, ctx);
            if mapped
                modulePath = checkPath;
                status = 'hub_local_mirror';
            elseif looksLikeWindowsAbsPathLocal(configuredPath)
                status = 'unmapped_windows_path';
                return;
            elseif startsWith(strrep(configuredPath, '\', '/'), '/')
                status = 'unmapped_server_path';
                return;
            else
                modulePath = configuredPath;
            end
        else
            [mappedPath, mapped] = mapLocalPathToHubServerPath(configuredPath, ctx);
            if mapped
                modulePath = mappedPath;
                status = 'mapped';
            elseif startsWith(strrep(configuredPath, '\', '/'), '/')
                modulePath = configuredPath;
                status = 'server';
            elseif looksLikeWindowsAbsPathLocal(configuredPath)
                status = 'unmapped_windows_path';
                return;
            else
                modulePath = configuredPath;
            end
        end
    elseif isempty(modulePath)
        pathText = char(string(configuredPath));
        if ispc && startsWith(strrep(pathText, '\', '/'), '/')
            [localPath, mapped] = mapHubServerPathToLocalPath(pathText, ctx);
            if mapped
                modulePath = localPath;
                status = 'local_mirror';
            else
                modulePath = pathText;
            end
        else
            modulePath = configuredPath;
        end
    end

    if exist(modulePath, 'dir') ~= 7
        recovered = recoverClassifierModulePathForValidation(configuredPath, moduleId, ctx);
        if ~isempty(recovered)
            modulePath = recovered;
            status = 'recovered';
        end
    end
end

function [checkPath, status, targetLabel, serverPath] = resolveNodePathForValidation(configuredPath, ctx)
targetLabel = validationExecutionTargetLabel(ctx);
status = 'configured';
serverPath = '';
checkPath = '';

if isempty(configuredPath)
    status = 'missing';
    return;
end

pathText = char(string(configuredPath));
if isHubValidationTarget(ctx)
    if ispc
        if looksLikeWindowsAbsPathLocal(pathText)
            [serverPath, mapped] = mapLocalPathToHubServerPath(pathText, ctx);
            if ~mapped
                status = 'unmapped_windows_path';
                return;
            end
            checkPath = pathText;
            status = 'hub_local_mirror';
            return;
        end
        [localPath, mapped] = mapHubServerPathToLocalPath(pathText, ctx);
        if mapped
            checkPath = localPath;
            serverPath = pathText;
            status = 'hub_server_mirror';
            return;
        end
        if startsWith(strrep(pathText, '\', '/'), '/')
            status = 'unmapped_server_path';
            serverPath = pathText;
            return;
        end
    else
        if looksLikeWindowsAbsPathLocal(pathText)
            [serverPath, mapped] = mapLocalPathToHubServerPath(pathText, ctx);
            if ~mapped
                status = 'unmapped_windows_path';
                return;
            end
            checkPath = serverPath;
            status = 'mapped';
            return;
        end
        if startsWith(strrep(pathText, '\', '/'), '/')
            checkPath = pathText;
            serverPath = pathText;
            status = 'server';
            return;
        end
    end
end

checkPath = pathText;
end

function [checkPath, mapped] = mapHubClassifierPathToLocalCheckPath(pathIn, ctx)
    checkPath = char(string(pathIn));
    mapped = false;
    pathText = char(string(pathIn));
    if looksLikeWindowsAbsPathLocal(pathText)
        [~, mapped] = mapLocalPathToHubServerPath(pathText, ctx);
        if mapped
            checkPath = pathText;
        end
        return;
    end

    [localPath, reverseMapped] = mapHubServerPathToLocalPath(pathText, ctx);
    if reverseMapped
        checkPath = localPath;
        mapped = true;
    end
end

function tf = isHubValidationTarget(ctx)
    tf = false;
    try
        vals = { ...
            nestedFieldTextLocal(ctx, {'run','executionTarget'}, ''), ...
            nestedFieldTextLocal(ctx, {'execution','requested_mode'}, ''), ...
            nestedFieldTextLocal(ctx, {'run','control','backend'}, '')};
        txt = lower(strjoin(vals, ' '));
        tf = contains(txt, 'hub') || contains(txt, 'server');
    catch
        tf = false;
    end
end

function label = validationExecutionTargetLabel(ctx)
    if isHubValidationTarget(ctx)
        label = 'Hub/server execution';
    else
        label = 'local MATLAB execution';
    end
end

function [mappedPath, mapped] = mapHubServerPathToLocalPath(pathIn, ctx)
    [mappedPath, mapped] = detecdiv_paths_map_module_path(pathIn, ctx, 'local');
end

function [mappedPath, mapped] = mapLocalPathToHubServerPath(pathIn, ctx)
    [mappedPath, mapped] = detecdiv_paths_map_module_path(pathIn, ctx, 'server');
end

function mappings = validationPathMappings(ctx)
    mappings = detecdiv_paths_module_mappings(ctx);
end

function recovered = recoverClassifierModulePathForValidation(configuredPath, moduleId, ctx)
    recovered = '';
    roots = {};
    try
        roots{end+1} = nestedFieldTextLocal(ctx, {'run','serverProjectDataFolder'}, ''); %#ok<AGROW>
        roots{end+1} = nestedFieldTextLocal(ctx, {'io','serverProjectDataFolder'}, ''); %#ok<AGROW>
        roots{end+1} = nestedFieldTextLocal(ctx, {'run','projectPath'}, ''); %#ok<AGROW>
        roots{end+1} = nestedFieldTextLocal(ctx, {'io','projectPath'}, ''); %#ok<AGROW>
        roots{end+1} = nestedFieldTextLocal(ctx, {'targetRef','projectPath'}, ''); %#ok<AGROW>
        roots{end+1} = nestedFieldTextLocal(ctx, {'pipelineRef','path'}, ''); %#ok<AGROW>
    catch
    end
    roots = roots(~cellfun(@isempty, roots));
    mappedRoots = classifierMappedPathRootsForValidation(configuredPath, ctx);
    roots = [roots mappedRoots]; %#ok<AGROW>
    leaf = moduleId;
    if isempty(leaf)
        [~, leaf] = fileparts(configuredPath);
    end
    candidates = {};
    for i = 1:numel(roots)
        root = roots{i};
        if exist(root, 'file') == 2
            root = fileparts(root);
        end
        candidates{end+1} = fullfile(root, 'classifiers', leaf); %#ok<AGROW>
        candidates{end+1} = fullfile(root, 'classifier', leaf); %#ok<AGROW>
        candidates{end+1} = fullfile(root, 'ClassiRepository', leaf); %#ok<AGROW>
        candidates{end+1} = fullfile(root, leaf); %#ok<AGROW>
    end
    for i = 1:numel(candidates)
        if exist(candidates{i}, 'dir') == 7
            recovered = candidates{i};
            return;
        end
    end
end

function roots = classifierMappedPathRootsForValidation(configuredPath, ctx)
    roots = {};
    try
        [mappedPath, mapped] = mapLocalPathToHubServerPath(configuredPath, ctx);
        if mapped && ~isempty(mappedPath)
            roots{end+1} = mappedPath; %#ok<AGROW>
            roots{end+1} = fileparts(mappedPath); %#ok<AGROW>
            roots{end+1} = fileparts(fileparts(mappedPath)); %#ok<AGROW>
        end
    catch
    end
end

function mappings = uniquePathMappingsLocal(mappings)
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

function snapPath = classifierSnapshotPath(modulePath, moduleId)
    snapPath = '';
    candidates = {};
    if ~isempty(moduleId)
        candidates{end+1} = fullfile(modulePath, [moduleId '_classification.mat']); %#ok<AGROW>
    end
    files = dir(fullfile(modulePath, '*_classification.mat'));
    for i = 1:numel(files)
        candidates{end+1} = fullfile(files(i).folder, files(i).name); %#ok<AGROW>
    end
    for i = 1:numel(candidates)
        if exist(candidates{i}, 'file') == 2
            snapPath = candidates{i};
            return;
        end
    end
end

function [ok, msg, modelPath] = validateCnnLstmArtifacts(modulePath, moduleId, p)
    ok = true;
    msg = '';
    modelPath = '';
    outputMode = 'lstm_only';
    try
        if isstruct(p) && isfield(p, 'outputMode') && ~isempty(p.outputMode)
            outputMode = lower(strrep(strtrim(char(string(p.outputMode))), ' ', '_'));
        end
    catch
    end
    mainModel = fullfile(modulePath, [moduleId '.mat']);
    cnnModel = fullfile(modulePath, ['netCNN_' moduleId '.mat']);
    modelPath = mainModel;
    switch outputMode
        case 'cnn_only'
            modelPath = cnnModel;
            if exist(cnnModel, 'file') ~= 2
                ok = false;
                msg = sprintf('outputMode=cnn_only requires %s.', cnnModel);
            end
        case 'both'
            modelPath = mainModel;
            missing = {};
            if exist(mainModel, 'file') ~= 2
                missing{end+1} = mainModel; %#ok<AGROW>
            end
            if exist(cnnModel, 'file') ~= 2
                missing{end+1} = cnnModel; %#ok<AGROW>
            end
            if ~isempty(missing)
                ok = false;
                msg = sprintf('outputMode=both requires assembled LSTM model and CNN model: %s.', strjoin(missing, ', '));
            end
        otherwise
            if exist(mainModel, 'file') ~= 2
                ok = false;
                msg = sprintf(['CNN/LSTM inference requires assembled model file %s. ' ...
                    'netLSTM_%s.mat is a training/assembly artifact, not a standalone inference model.'], mainModel, moduleId);
            end
    end
end

function tf = looksLikeWindowsAbsPathLocal(pathText)
    s = char(string(pathText));
    tf = ~isempty(regexp(s, '^[A-Za-z]:[\\/]', 'once')) || startsWith(s, '\\');
end

function value = nestedFieldLocal(S, pathParts, defaultValue)
    value = defaultValue;
    try
        value = S;
        for i = 1:numel(pathParts)
            if ~isstruct(value) || ~isfield(value, pathParts{i})
                value = defaultValue;
                return;
            end
            value = value.(pathParts{i});
        end
    catch
        value = defaultValue;
    end
end

function text = nestedFieldTextLocal(S, pathParts, defaultValue)
    text = defaultValue;
    try
        value = nestedFieldLocal(S, pathParts, defaultValue);
        if ~isempty(value)
            text = char(string(value));
        end
    catch
        text = defaultValue;
    end
end

function nodes = injectContextResolvedNodeBindings(nodes, ctx)
    for i = 1:numel(nodes)
        nodeType = lower(char(string(getField(nodes(i), 'type', ''))));
        if ~isfield(nodes(i), 'params') || ~isstruct(nodes(i).params)
            nodes(i).params = struct();
        end
        switch nodeType
            case 'roipattern'
                if ~hasAnyFieldValue(nodes(i).params, {'channel','channels','channelName'})
                    ch = projectRoiPatternProfileChannel(ctx);
                    if ~isempty(ch)
                        nodes(i).params.channel = ch;
                    end
                end
            case 'classifier'
                if ~hasAnyFieldValue(nodes(i).params, {'channel','channels','channelName'})
                    ch = resolveLinkedClassifierChannels(nodes(i));
                    if ~isempty(ch)
                        nodes(i).params.channelName = ch;
                    end
                end
        end
    end
end

function tf = hasAnyFieldValue(S, names)
    tf = false;
    if ~isstruct(S)
        return;
    end
    for i = 1:numel(names)
        if isfield(S, names{i}) && ~isempty(S.(names{i}))
            tf = true;
            return;
        end
    end
end

function ch = projectRoiPatternProfileChannel(ctx)
    ch = {};
    shallowObj = [];
    if isstruct(ctx)
        if isfield(ctx, 'shallow') && isa(ctx.shallow, 'shallow')
            shallowObj = ctx.shallow;
        elseif isfield(ctx, 'shallowObj') && isa(ctx.shallowObj, 'shallow')
            shallowObj = ctx.shallowObj;
        end
    end
    if isempty(shallowObj) || ~isprop(shallowObj, 'runProfiles')
        return;
    end
    try
        rp = shallowObj.runProfiles;
        if isstruct(rp) && isfield(rp, 'dataloading') && isstruct(rp.dataloading) && ...
                isfield(rp.dataloading, 'roiPattern') && isstruct(rp.dataloading.roiPattern) && ...
                isfield(rp.dataloading.roiPattern, 'channel') && ~isempty(rp.dataloading.roiPattern.channel)
            ch = normalizeChannelList(rp.dataloading.roiPattern.channel);
        end
    catch
        ch = {};
    end
end

function errors = requiredDesignAssetErrors(node, ctx)
    errors = {};
    if nargin < 2 || isempty(ctx)
        ctx = struct();
    end
    nodeType = lower(char(string(getField(node, 'type', ''))));
    if ~any(strcmp(nodeType, {'roipattern','roiidentify'}))
        return;
    end
    params = getField(node, 'params', struct());
    if ~isstruct(params)
        params = struct();
    end

    hasPattern = false;
    patternKeys = {'pattern','patternImage','patternList'};
    for i = 1:numel(patternKeys)
        key = patternKeys{i};
        if isfield(params, key) && ~isempty(params.(key))
            hasPattern = true;
            break;
        end
    end
    if ~hasPattern
        errors{end+1} = ['Node ' char(string(getField(node, 'id', ''))) ...
            ' requires a saved ROI pattern definition in the node before it can run. Please generate pattern first.']; %#ok<AGROW>
    end
end

function tf = hasProjectRoiPatternProfile(ctx)
    tf = false;
    shallowObj = [];
    if isstruct(ctx)
        if isfield(ctx, 'shallow') && isa(ctx.shallow, 'shallow')
            shallowObj = ctx.shallow;
        elseif isfield(ctx, 'shallowObj') && isa(ctx.shallowObj, 'shallow')
            shallowObj = ctx.shallowObj;
        end
    end
    if isempty(shallowObj) || ~isprop(shallowObj, 'runProfiles')
        return;
    end
    try
        rp = shallowObj.runProfiles;
        if ~isstruct(rp) || ~isfield(rp, 'dataloading') || ~isstruct(rp.dataloading)
            return;
        end
        dl = rp.dataloading;
        keys = {'roiPattern','roiIdentify'};
        for i = 1:numel(keys)
            if isfield(dl, keys{i}) && hasRoiPatternAsset(dl.(keys{i}))
                tf = true;
                return;
            end
        end
    catch
        tf = false;
    end
end

function tf = hasRoiPatternAsset(params)
    tf = false;
    if ~isstruct(params) || isempty(params)
        return;
    end
    keys = {'pattern','patternImage','patternList'};
    for i = 1:numel(keys)
        if isfield(params, keys{i}) && ~isempty(params.(keys{i}))
            tf = true;
            return;
        end
    end
end

function scope = getBindingScope(binding, requirements)
    scope = char(string(getField(binding, 'scope', '')));
    if ~isempty(scope)
        return;
    end
    if isstruct(requirements) && isfield(requirements, 'images') && logical(getField(requirements.images, 'required', false))
        scope = 'images';
    elseif isstruct(requirements) && isfield(requirements, 'roi') && logical(getField(requirements.roi, 'required', false))
        scope = 'roi';
    else
        scope = '';
    end
end

function exactCount = getBindingExactCount(node, binding)
    exactCount = [];
    if ~isstruct(binding)
        return;
    end
    contract = getField(node, 'contract', struct());
    resources = getField(contract, 'resources', struct());
    inResources = getField(resources, 'in', []);
    mode = lower(char(string(getField(binding, 'mode', ''))));
    paramName = char(string(getField(binding, 'exactCountParam', '')));
    if strcmp(mode, 'channelslots') && ~isempty(paramName) && isstruct(inResources) && ~isempty(inResources)
        exactCount = numel(inResources);
        return;
    end
    exactCount = getField(binding, 'exactCount', []);
    params = getField(node, 'params', struct());
    if ~isempty(paramName) && isstruct(params) && isfield(params, paramName) && ~isempty(params.(paramName))
        try
            exactCount = double(params.(paramName));
            if ~isfinite(exactCount) || exactCount <= 0
                exactCount = [];
            else
                exactCount = round(exactCount);
            end
        catch
            exactCount = [];
        end
    end
end

function requiredCount = resolveBindingRequiredCount(node, binding, requirements, selectors)
    requiredCount = 0;
    exactCount = getBindingExactCount(node, binding);
    if ~isempty(exactCount)
        requiredCount = exactCount;
        return;
    end

    minCount = double(getField(binding, 'minCount', 0));
    if ~isempty(minCount) && isfinite(minCount)
        requiredCount = max(requiredCount, minCount);
    end
    defaultCount = double(getField(binding, 'defaultCount', 0));
    if ~isempty(defaultCount) && isfinite(defaultCount)
        requiredCount = max(requiredCount, defaultCount);
    elseif isstruct(selectors)
        selectorDefaultCount = double(getField(selectors, 'defaultChannelCount', 0));
        if ~isempty(selectorDefaultCount) && isfinite(selectorDefaultCount)
            requiredCount = max(requiredCount, selectorDefaultCount);
        end
    end
    if isstruct(requirements)
        if isfield(requirements, 'images') && isstruct(requirements.images)
            requiredCount = max(requiredCount, double(getField(requirements.images, 'channelsMin', 0)));
        end
        if isfield(requirements, 'roi') && isstruct(requirements.roi)
            requiredCount = max(requiredCount, double(getField(requirements.roi, 'channelsMin', 0)));
        end
    end

    configured = resolveBindingConfiguredChannels(node, binding, selectors);
    configured = removeResourceOnlyConfiguredChannelValues(node, configured);
    if requiredCount <= 0 && ~isempty(configured)
        requiredCount = numel(configured);
    end
end

function channels = resolveBindingConfiguredChannels(node, binding, selectors)
    channels = {};
    params = getField(node, 'params', struct());
    if ~isstruct(params)
        return;
    end

    selectorKeys = {};
    if isstruct(binding) && isfield(binding, 'selectorKeys') && ~isempty(binding.selectorKeys)
        selectorKeys = cellstr(string(binding.selectorKeys(:)));
    end
    for i = 1:numel(selectorKeys)
        key = char(string(selectorKeys{i}));
        if ~legacyChannelSelectorKeyApplies(node, key)
            continue;
        end
        if ~isfield(params, key) || isempty(params.(key))
            continue;
        end
        channels = mergeKnownChannels(channels, normalizeConfiguredOrSymbolicSelectionValue(params.(key)));
    end
    if ~isempty(channels)
        return;
    end
    channels = resolveNodeConfiguredChannels(node, selectors);
end

function tf = legacyChannelSelectorKeyApplies(node, key)
    tf = true;
    key = char(string(key));
    if isempty(key)
        return;
    end
    if strcmpi(char(string(getField(node, 'type', ''))), 'roiTracked') && strcmpi(key, 'channel')
        tf = false;
        return;
    end
    contract = getField(node, 'contract', struct());
    resources = getField(contract, 'resources', struct());
    inputs = getField(resources, 'in', resourceSpecDef());
    matched = false;
    hasChannelSpec = false;
    for i = 1:numel(inputs)
        if isempty(getField(inputs(i), 'type', ''))
            continue;
        end
        param = char(string(getField(inputs(i), 'param', '')));
        nameParam = char(string(getField(inputs(i), 'nameParam', '')));
        if ~strcmp(param, key) && ~strcmp(nameParam, key)
            continue;
        end
        matched = true;
        if strcmpi(char(string(getField(inputs(i), 'type', ''))), 'channel')
            hasChannelSpec = true;
        end
    end
    if matched && ~hasChannelSpec
        tf = false;
    end
end

function channels = removeResourceOnlyConfiguredChannelValues(node, channels)
    if isempty(channels)
        return;
    end
    params = getField(node, 'params', struct());
    if ~isstruct(params)
        return;
    end
    contract = getField(node, 'contract', struct());
    resources = getField(contract, 'resources', struct());
    inputs = getField(resources, 'in', resourceSpecDef());
    removeValues = {};
    for i = 1:numel(inputs)
        if isempty(getField(inputs(i), 'type', '')) || strcmpi(char(string(getField(inputs(i), 'type', ''))), 'channel')
            continue;
        end
        keys = unique({ ...
            char(string(getField(inputs(i), 'param', ''))), ...
            char(string(getField(inputs(i), 'nameParam', '')))}, 'stable');
        for j = 1:numel(keys)
            key = char(string(keys{j}));
            if isempty(key) || ~isfield(params, key) || isempty(params.(key))
                continue;
            end
            removeValues = mergeKnownChannels(removeValues, normalizeConfiguredSelectionValue(params.(key)));
        end
    end
    if isempty(removeValues)
        return;
    end
    keep = true(size(channels));
    for i = 1:numel(channels)
        keep(i) = ~any(strcmpi(char(string(channels{i})), removeValues));
    end
    channels = channels(keep);
end

function names = compatibleResourceConcreteNamesForBinding(node, resources)
    names = {};
    contract = getField(node, 'contract', struct());
    res = getField(contract, 'resources', struct());
    inputs = getField(res, 'in', struct([]));
    if isempty(inputs)
        return;
    end
    for i = 1:numel(inputs)
        spec = inputs(i);
        if ~strcmpi(char(string(getField(spec, 'type', ''))), 'channel')
            continue;
        end
        compatible = findCompatibleResources(resources, spec);
        names = mergeKnownChannels(names, allResourceConcreteNames(compatible));
        names = mergeKnownChannels(names, configuredCompatibleResourceNames(node, spec, compatible));
    end
end

function names = configuredCompatibleResourceNames(node, spec, compatible)
    names = {};
    [hasRaw, raw] = resolveResourceRawValue(node, spec);
    if ~hasRaw || isempty(raw) || isSymbolicResourceBinding(raw)
        return;
    end

    rawNames = normalizeChannelList(raw);
    rawNames = rawNames(~isAllChannelSelectionCell(rawNames));
    for i = 1:numel(rawNames)
        name = strtrim(char(string(rawNames{i})));
        if isempty(name)
            continue;
        end
        match = findCompatibleResourceByConfiguredChannelName(name, compatible);
        if ~isempty(match)
            names = mergeKnownChannels(names, {name}); %#ok<AGROW>
        end
    end
end

function tf = hasSymbolicResourceSelection(node, binding, selectors)
    tf = false;
    params = getField(node, 'params', struct());
    if ~isstruct(params)
        return;
    end
    keys = {};
    if isstruct(binding) && isfield(binding, 'selectorKeys') && ~isempty(binding.selectorKeys)
        keys = cellstr(string(binding.selectorKeys(:)));
    end
    keys = [keys(:)', { ...
        char(string(getField(selectors, 'channelsParam', ''))), ...
        char(string(getField(selectors, 'channelParam', '')))}];
    keys = unique(keys(~cellfun(@isempty, keys)), 'stable');
    for i = 1:numel(keys)
        key = char(string(keys{i}));
        if isfield(params, key) && isSymbolicResourceBinding(params.(key)) && ...
                ~isGenericSourceSymbolicBinding(params.(key))
            tf = true;
            return;
        end
    end
end

function names = allResourceConcreteNames(resources)
    names = {};
    resources = normalizeResourceInventory(resources);
    for i = 1:numel(resources)
        nm = char(string(resources(i).concreteName));
        if isempty(nm)
            nm = char(string(resources(i).symbol));
        end
        if ~isempty(nm)
            names{end+1} = nm; %#ok<AGROW>
        end
    end
    names = unique(names, 'stable');
end

function tf = hasSymbolicChannelCollectionSelection(node, binding, selectors)
    tf = false;
    if ~isstruct(binding) || ~strcmpi(char(string(getField(binding, 'mode', ''))), 'channelSet')
        return;
    end
    params = getField(node, 'params', struct());
    if ~isstruct(params)
        return;
    end
    keys = {};
    if isfield(binding, 'selectorKeys') && ~isempty(binding.selectorKeys)
        keys = cellstr(string(binding.selectorKeys(:)));
    end
    keys = [keys(:)', { ...
        char(string(getField(selectors, 'channelsParam', ''))), ...
        char(string(getField(selectors, 'channelParam', '')))}];
    keys = unique(keys(~cellfun(@isempty, keys)), 'stable');
    for i = 1:numel(keys)
        key = char(string(keys{i}));
        if isfield(params, key) && isSymbolicChannelCollectionValue(params.(key))
            tf = true;
            return;
        end
    end
end

function tf = isSymbolicChannelCollectionValue(value)
    txt = lower(strtrim(choiceToString(value)));
    tf = startsWith(txt, '@') && ( ...
        endsWith(txt, '.channels') || ...
        any(strcmp(txt, {'@source','@sources','@all_channels'})) || ...
        startsWith(txt, '@resource:source:'));
end

function channels = normalizeConfiguredSelectionValue(value)
    channels = {};
    if isempty(value)
        return;
    end
    if iscell(value) && numel(value) >= 2
        try
            entries = cellfun(@(x) char(string(x)), value, 'UniformOutput', false);
            selected = strtrim(entries{end});
            choices = entries(1:end-1);
            if ~isempty(selected) && (any(strcmpi(choices, selected)) || any(strcmpi(selected, {'none','n/a'})))
                if ~any(strcmpi(selected, {'none','n/a'}))
                    channels = {selected};
                end
                return;
            end
        catch
        end
    end
    channels = normalizeChannelList(value);
    low = lower(channels);
    keep = ~strcmp(low, 'none') & ~strcmp(low, 'n/a') & ~isSymbolicChannelSelectionCell(channels);
    channels = channels(keep);
end

function channels = normalizeConfiguredOrSymbolicSelectionValue(value)
    channels = normalizeConfiguredSelectionValue(value);
    if ~isempty(channels)
        return;
    end
    if isSymbolicResourceBinding(value) && ~isGenericSourceSymbolicBinding(value)
        channels = {choiceToString(value)};
    end
end

function tf = isAllChannelSelection(channels)
    tf = false;
    if isempty(channels)
        return;
    end
    vals = lower(strtrim(cellstr(string(channels(:)))));
    tf = any(strcmp(vals, 'all') | strcmp(vals, '*') | strcmp(vals, ':') | strcmp(vals, '<all>'));
end

function tf = isAllChannelSelectionCell(channels)
    if isempty(channels)
        tf = false(size(channels));
        return;
    end
    vals = lower(strtrim(cellstr(string(channels(:)))));
    tf = strcmp(vals, 'all') | strcmp(vals, '*') | strcmp(vals, ':') | strcmp(vals, '<all>');
    tf = reshape(tf, size(channels));
end

function out = normalizedLowerNameList(values)
    if isempty(values)
        out = {};
        return;
    end
    out = cellstr(string(values(:)));
    out = lower(strtrim(out));
end

function tf = isSymbolicChannelSelectionCell(channels)
    if isempty(channels)
        tf = false(size(channels));
        return;
    end
    vals = strtrim(cellstr(string(channels(:))));
    tf = startsWith(vals, '@') | startsWith(vals, '<');
    tf = reshape(tf, size(channels));
end

function status = classifyUnresolvedBinding(binding, availableChannels)
    resolveAt = lower(char(string(getField(binding, 'resolveAt', 'run'))));
    if isempty(availableChannels)
        if strcmp(resolveAt, 'design')
            status = 'needs_user_binding';
        else
            status = 'needs_run_binding';
        end
    else
        if strcmp(resolveAt, 'design')
            status = 'needs_user_binding';
        else
            status = 'needs_run_binding';
        end
    end
end

function msg = formatResolvedBindingMessage(node, requiredCount, configuredChannels)
    if isempty(configuredChannels)
        msg = ['Node ' char(string(node.id)) ' has no explicit channel binding requirement.'];
        return;
    end
    if requiredCount > 0
        msg = ['Node ' char(string(node.id)) ' binds ' num2str(numel(configuredChannels)) ...
            ' channel(s): ' strjoin(configuredChannels, ', ') '.'];
    else
        msg = ['Node ' char(string(node.id)) ' is configured on channels: ' strjoin(configuredChannels, ', ') '.'];
    end
end

function names = inferFovChannels(fovList)
    names = {};
    try
        if isempty(fovList)
            return;
        end
        f0 = fovList(1);
        if isprop(f0, 'channel') && ~isempty(f0.channel)
            names = normalizeChannelList(f0.channel);
        elseif isfield(f0, 'channel') && ~isempty(f0.channel)
            names = normalizeChannelList(f0.channel);
        end
    catch
        names = {};
    end
end

function names = inferRoiChannels(roiList)
    names = {};
    try
        if isempty(roiList)
            return;
        end
        r0 = roiList(1);
        if isprop(r0,'display') && ~isempty(r0.display) && isfield(r0.display,'channel') && ~isempty(r0.display.channel)
            names = normalizeChannelList(r0.display.channel);
            return;
        end
        if isfield(r0,'display') && ~isempty(r0.display) && isfield(r0.display,'channel') && ~isempty(r0.display.channel)
            names = normalizeChannelList(r0.display.channel);
        end
    catch
        names = {};
    end
end

function tf = roiListHasMaskLikeChannels(roiList)
    tf = false;
    names = inferRoiChannels(roiList);
    if isempty(names)
        return;
    end
    low = lower(names);
    tf = any(contains(low, 'mask') | contains(low, 'result') | contains(low, 'track'));
end

function tf = roiListHasDataSeries(roiList)
    tf = false;
    try
        if isempty(roiList)
            return;
        end
        r0 = roiList(1);
        if isprop(r0,'data') && ~isempty(r0.data)
            tf = true;
            return;
        end
        if isfield(r0,'data') && ~isempty(r0.data)
            tf = true;
        end
    catch
        tf = false;
    end
end

function out = mergeKnownChannels(a, b)
    aa = normalizeChannelList(a);
    bb = normalizeChannelList(b);
    out = unique([aa(:); bb(:)]', 'stable');
end

function names = normalizeChannelList(v)
    names = {};
    if isempty(v)
        return;
    end
    if ischar(v) || (isstring(v) && isscalar(v))
        s = char(string(v));
        if ~isempty(strtrim(s))
            names = splitDelimitedNameList(s);
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
                tmp = [tmp splitDelimitedNameList(char(string(v{i})))]; %#ok<AGROW>
            catch
            end
        end
        names = tmp(~cellfun(@(x) isempty(strtrim(x)), tmp));
        return;
    end
    if isnumeric(v)
        vals = double(v(:)');
        vals = vals(isfinite(vals));
        for i = 1:numel(vals)
            names{end+1} = num2str(vals(i)); %#ok<AGROW>
        end
    end
end

function names = splitDelimitedNameList(s)
    s = strtrim(char(string(s)));
    if isempty(s)
        names = {};
        return;
    end
    parts = regexp(s, '[,;]+', 'split');
    names = strtrim(parts);
    names = names(~cellfun(@isempty, names));
end

function names = expandChannelPatternSelections(names, availableChannels)
    names = normalizeChannelList(names);
    availableChannels = normalizeChannelList(availableChannels);
    if isempty(names) || isempty(availableChannels)
        return;
    end

    expanded = {};
    for i = 1:numel(names)
        item = strtrim(char(string(names{i})));
        if isChannelPatternSelector(item)
            rx = channelPatternToRegexp(item);
            matches = {};
            for j = 1:numel(availableChannels)
                candidate = char(string(availableChannels{j}));
                if ~isempty(regexp(candidate, rx, 'once'))
                    matches{end+1} = candidate; %#ok<AGROW>
                end
            end
            if ~isempty(matches)
                expanded = [expanded matches]; %#ok<AGROW>
            else
                expanded{end+1} = item; %#ok<AGROW>
            end
        else
            expanded{end+1} = item; %#ok<AGROW>
        end
    end
    names = unique(expanded, 'stable');
end

function tf = isChannelPatternSelector(value)
    value = strtrim(char(string(value)));
    if isempty(value) || any(strcmpi(value, {'all','*',':','<all>','@source','@roi','@all_channels'}))
        tf = false;
        return;
    end
    tf = contains(value, '$') || contains(value, '#') || contains(value, '*');
end

function rx = channelPatternToRegexp(pat)
    pat = char(string(pat));
    rx = '^';
    i = 1;
    while i <= numel(pat)
        ch = pat(i);
        if ch == '$' || ch == '#'
            j = i;
            while j <= numel(pat) && (pat(j) == '$' || pat(j) == '#')
                j = j + 1;
            end
            rx = [rx '\d{' num2str(j - i) '}']; %#ok<AGROW>
            i = j;
        elseif ch == '*'
            rx = [rx '.*']; %#ok<AGROW>
            i = i + 1;
        else
            rx = [rx regexptranslate('escape', ch)]; %#ok<AGROW>
            i = i + 1;
        end
    end
    rx = [rx '$'];
end

function resources = initialResourceInventory(ctx, sem)
    resources = resourceInventoryDef();
    imageChannels = getField(sem, 'imageChannels', {});
    roiChannels = getField(sem, 'roiChannels', {});
    for i = 1:numel(imageChannels)
        resources(end+1) = resourceInventoryDef('channel', 'source', imageChannels{i}, imageChannels{i}, 'ctx', 'images', 'context'); %#ok<AGROW>
    end
    for i = 1:numel(roiChannels)
        resources(end+1) = resourceInventoryDef('channel', 'roi_image', roiChannels{i}, roiChannels{i}, 'ctx', 'channels', 'context'); %#ok<AGROW>
    end

    dataSeries = {};
    if isfield(ctx, 'dataSeries') && ~isempty(ctx.dataSeries)
        dataSeries = normalizeResourceNameList(ctx.dataSeries);
    elseif isfield(ctx, 'dataSeriesNames') && ~isempty(ctx.dataSeriesNames)
        dataSeries = normalizeResourceNameList(ctx.dataSeriesNames);
    elseif isfield(ctx, 'roiList') && ~isempty(ctx.roiList)
        dataSeries = inferRoiDataSeriesNames(ctx.roiList);
    end
    for i = 1:numel(dataSeries)
        resources(end+1) = resourceInventoryDef('dataSeries', inferDataSeriesRole(dataSeries{i}), dataSeries{i}, dataSeries{i}, 'ctx', 'dataSeries', 'context'); %#ok<AGROW>
    end

    masks = {};
    if isfield(ctx, 'masks') && ~isempty(ctx.masks)
        masks = normalizeResourceNameList(ctx.masks);
    end
    for i = 1:numel(masks)
        resources(end+1) = resourceInventoryDef('mask', 'segmentation', masks{i}, masks{i}, 'ctx', 'masks', 'context'); %#ok<AGROW>
    end

    resources = mergeResourceInventory(resourceInventoryDef(), resources);
end

function out = resourceSpecDef()
    out = struct('type',{},'role',{},'symbol',{},'param',{},'port',{},'nameParam',{},'required',{},'transfer',{});
end

function out = resourceBindingDef(type, role, symbol, concreteName, sourceNode, sourcePort, sourceKind)
    if nargin == 0
        out = struct('type',{},'role',{},'symbol',{},'concreteName',{},'sourceNode',{},'sourcePort',{},'sourceKind',{}, ...
            'param',{},'status',{},'message',{},'configured',{},'available',{},'autoChoice',{});
        return;
    end
    out = resourceInventoryDef(type, role, symbol, concreteName, sourceNode, sourcePort, sourceKind);
    out.param = '';
    out.status = 'resolved';
    out.message = '';
    out.configured = '';
    out.available = resourceInventoryDef();
    out.autoChoice = resourceInventoryDef();
end

function out = resourceInventoryDef(type, role, symbol, concreteName, sourceNode, sourcePort, sourceKind)
    if nargin == 0
        out = struct('type',{},'role',{},'symbol',{},'concreteName',{},'sourceNode',{},'sourcePort',{},'sourceKind',{});
        return;
    end
    if nargin < 7, sourceKind = ''; end
    if nargin < 6, sourcePort = ''; end
    if nargin < 5, sourceNode = ''; end
    if nargin < 4, concreteName = ''; end
    if nargin < 3, symbol = ''; end
    if nargin < 2, role = ''; end
    out = struct( ...
        'type', char(string(type)), ...
        'role', char(string(role)), ...
        'symbol', char(string(symbol)), ...
        'concreteName', char(string(concreteName)), ...
        'sourceNode', char(string(sourceNode)), ...
        'sourcePort', char(string(sourcePort)), ...
        'sourceKind', char(string(sourceKind)));
end

function out = mergeResourceInventory(a, b)
    raw = [normalizeResourceInventory(a), normalizeResourceInventory(b)];
    out = resourceInventoryDef();
    seen = containers.Map('KeyType', 'char', 'ValueType', 'logical');
    for i = 1:numel(raw)
        key = lower(strjoin({raw(i).type, raw(i).role, raw(i).symbol, raw(i).concreteName, raw(i).sourceNode, raw(i).sourcePort}, '|'));
        if isKey(seen, key)
            continue;
        end
        seen(key) = true;
        out(end+1) = raw(i); %#ok<AGROW>
    end
end

function out = normalizeResourceInventory(v)
    out = resourceInventoryDef();
    if isempty(v) || ~isstruct(v)
        return;
    end
    defaults = resourceInventoryDef('', '', '', '', '', '', '');
    for i = 1:numel(v)
        itemRaw = mergeStructLocal(defaults, v(i));
        item = resourceInventoryDef( ...
            char(string(getField(itemRaw, 'type', ''))), ...
            char(string(getField(itemRaw, 'role', ''))), ...
            char(string(getField(itemRaw, 'symbol', ''))), ...
            char(string(getField(itemRaw, 'concreteName', ''))), ...
            char(string(getField(itemRaw, 'sourceNode', ''))), ...
            char(string(getField(itemRaw, 'sourcePort', ''))), ...
            char(string(getField(itemRaw, 'sourceKind', ''))));
        if isempty(item.type)
            continue;
        end
        out(end+1) = item; %#ok<AGROW>
    end
end

function out = makeResourceOutput(node, spec)
    nodeId = char(string(getField(node, 'id', '')));
    concreteName = resolveResourceOutputName(node, spec);
    symbol = char(string(getField(spec, 'symbol', '')));
    if isempty(symbol)
        symbol = [nodeId '.' char(string(getField(spec, 'port', 'resource')))];
    elseif ~contains(symbol, '.')
        symbol = [nodeId '.' symbol];
    end
    out = resourceBindingDef(char(string(spec.type)), char(string(spec.role)), symbol, concreteName, nodeId, char(string(spec.port)), char(string(spec.transfer)));
    out.param = char(string(getField(spec, 'param', '')));
    out.message = sprintf('Node %s provides %s/%s resource "%s".', nodeId, out.type, out.role, out.concreteName);
end

function name = resolveResourceOutputName(node, spec)
    name = '';
    params = getField(node, 'params', struct());
    key = char(string(getField(spec, 'nameParam', '')));
    if ~isempty(key) && isstruct(params) && isfield(params, key) && ~isempty(params.(key))
        name = choiceToString(params.(key));
    end
    if isempty(name)
        key = char(string(getField(spec, 'param', '')));
        if ~isempty(key) && isstruct(params) && isfield(params, key) && ~isempty(params.(key))
            name = choiceToString(params.(key));
        end
    end
    if isempty(name)
        type = lower(char(string(getField(spec, 'type', ''))));
        symbol = char(string(getField(spec, 'symbol', '')));
        if strcmp(type, 'dataseries') && ~isempty(symbol) && ~strcmpi(symbol, 'dataSeries') && ~contains(symbol, '.')
            name = symbol;
        end
    end
    if isempty(name)
        type = lower(char(string(getField(spec, 'type', ''))));
        port = lower(char(string(getField(spec, 'port', ''))));
        transfer = lower(char(string(getField(spec, 'transfer', ''))));
        if strcmp(type, 'channel') && strcmp(port, 'channels') && any(strcmp(transfer, {'sourceinventory','imagestoroi'}))
            name = '';
        else
            name = char(string(getField(node, 'id', '')));
        end
    end
    name = normalizePhysicalResourceOutputName(node, spec, name);
end

function name = normalizePhysicalResourceOutputName(node, spec, name)
    if isempty(name)
        return;
    end
    name = strtrim(char(string(name)));
    nodeType = lower(char(string(getField(node, 'type', ''))));
    pkgName = lower(char(string(getField(node, 'pkg', ''))));
    if isempty(pkgName)
        params = getField(node, 'params', struct());
        if isstruct(params) && isfield(params, 'pkg') && ~isempty(params.pkg)
            pkgName = lower(char(string(params.pkg)));
        end
    end
    resourceType = lower(char(string(getField(spec, 'type', ''))));
    role = lower(char(string(getField(spec, 'role', ''))));
    if strcmp(nodeType, 'processor') && strcmp(pkgName, 'computemetrics') && ...
            strcmp(resourceType, 'dataseries') && strcmp(role, 'metrics') && ...
            ~isempty(regexp(name, '^processor_computemetrics(_\d+)?$', 'once'))
        name = 'channel_quantification';
    elseif strcmp(nodeType, 'classifier') && strcmp(pkgName, 'cellposesam') && ...
            strcmp(resourceType, 'mask') && strcmp(role, 'segmentation')
        name = cellposeSegmentationChannelNameLocal(node, name);
    elseif strcmp(nodeType, 'classifier') && strcmp(pkgName, 'deeplab_pixel_classification') && ...
            strcmp(resourceType, 'mask') && strcmp(role, 'segmentation')
        name = prefixedResultsChannelNameLocal(name);
    elseif strcmp(nodeType, 'processor') && strcmp(pkgName, 'trackmotherlineageviterbi') && ...
            strcmp(resourceType, 'channel') && any(strcmp(role, {'lineage_mask','lineage_cell_mask','lineage_confidence','lineage_mother_mask','lineage_bud_mask'}))
        name = trackMotherLineageChannelNameLocal(name, role);
    end
end

function name = prefixedResultsChannelNameLocal(outputName)
    outputName = char(string(outputName));
    if startsWith(outputName, 'results_', 'IgnoreCase', true)
        name = outputName;
    else
        name = ['results_' outputName];
    end
end

function name = cellposeSegmentationChannelNameLocal(node, outputName)
    outputName = char(string(outputName));
    if startsWith(outputName, 'results_', 'IgnoreCase', true)
        name = outputName;
        return;
    end
    className = 'cell';
    params = getField(node, 'params', struct());
    if isstruct(params)
        keys = {'classes','classNames','className','labels'};
        for i = 1:numel(keys)
            key = keys{i};
            if isfield(params, key) && ~isempty(params.(key))
                className = firstTextValueLocal(params.(key), 'cell');
                break;
            end
        end
    end
    name = ['results_' outputName '_' className];
end

function name = trackMotherLineageChannelNameLocal(outputName, role)
    outputName = char(string(outputName));
    if endsWith(outputName, '_cell', 'IgnoreCase', true) || endsWith(outputName, '_bud', 'IgnoreCase', true) || endsWith(outputName, '_conf', 'IgnoreCase', true)
        name = outputName;
        return;
    end
    if any(strcmpi(char(string(role)), {'lineage_confidence','lineage_bud_mask'}))
        name = [outputName '_bud'];
    else
        name = [outputName '_cell'];
    end
end

function txt = firstTextValueLocal(value, fallback)
    txt = fallback;
    try
        if iscell(value)
            value = value{find(~cellfun(@isempty, value), 1, 'first')};
        elseif isstring(value) && ~isscalar(value)
            value = value(find(strlength(value) > 0, 1, 'first'));
        end
        candidate = strtrim(char(string(value)));
        if ~isempty(candidate)
            txt = candidate;
        end
    catch
        txt = fallback;
    end
end

function value = resolveResourceConfiguredValue(node, spec)
    value = '';
    [hasRaw, raw, key] = resolveResourceRawValue(node, spec);
    if ~hasRaw
        if strcmpi(char(string(getField(node, 'type', ''))), 'classifier') && ...
                any(strcmpi(key, {'channel','channels','channelName'}))
            linkedChannels = resolveLinkedClassifierChannels(node);
            if numel(linkedChannels) == 1
                value = linkedChannels{1};
            end
        end
        return;
    end
    if isSymbolicResourceBinding(raw)
        return;
    end
    if strcmpi(char(string(getField(spec, 'type', ''))), 'channel') && isChannelPatternSelector(choiceToString(raw))
        value = choiceToString(raw);
        return;
    end
    if ~isConfiguredResourceValue(raw)
        return;
    end
    value = choiceToString(raw);
    if any(strcmpi(value, {'none','n/a','N/A'}))
        value = '';
    end
end

function value = resolveResourceSymbolicValue(node, spec)
    value = '';
    [hasRaw, raw] = resolveResourceRawValue(node, spec);
    if ~hasRaw
        return;
    end
    if isGenericSourceSymbolicBinding(raw)
        return;
    end
    if ~isSymbolicResourceBinding(raw)
        return;
    end
    value = choiceToString(raw);
end

function [hasRaw, raw, key] = resolveResourceRawValue(node, spec)
    hasRaw = false;
    raw = [];
    key = '';
    params = getField(node, 'params', struct());
    if ~isstruct(params)
        return;
    end
    keys = resourceSpecParamKeys(node, spec);
    for i = 1:numel(keys)
        candidate = char(string(keys{i}));
        if isempty(candidate) || ~isfield(params, candidate) || isempty(params.(candidate))
            continue;
        end
        key = candidate;
        raw = params.(candidate);
        hasRaw = true;
        return;
    end
    if ~isempty(keys)
        key = char(string(keys{1}));
    end
end

function keys = resourceSpecParamKeys(node, spec)
    keys = { ...
        char(string(getField(spec, 'param', ''))), ...
        char(string(getField(spec, 'nameParam', '')))};
    contract = getField(node, 'contract', struct());
    binding = getField(contract, 'binding', struct());
    if isstruct(binding) && isfield(binding, 'selectorKeys') && ~isempty(binding.selectorKeys)
        keys = [keys, cellstr(string(binding.selectorKeys(:)))']; %#ok<AGROW>
    end
    keys = unique(keys(~cellfun(@isempty, keys)), 'stable');
end

function tf = isSymbolicResourceBinding(v)
    s = choiceToString(v);
    tf = startsWith(strtrim(s), '@');
end

function tf = isOptionalSourceChannelSpec(spec)
    tf = strcmpi(char(string(getField(spec, 'type', ''))), 'channel') && ...
        strcmpi(char(string(getField(spec, 'role', ''))), 'source') && ...
        ~logical(getField(spec, 'required', false));
end

function tf = isGenericSourceSymbolicBinding(v)
    s = lower(strtrim(choiceToString(v)));
    tf = any(strcmp(s, {'@source','@sources','@z_stack','@z-stack', ...
        '@z_stack output','@z-stack output', ...
        '<source output>','<all source channels>','<z_stack output>','<z-stack output>'}));
end

function tf = isConfiguredResourceValue(v)
    tf = false;
    if isempty(v)
        return;
    end
    if iscell(v)
        flat = v(~cellfun(@isempty, v));
        if isempty(flat)
            return;
        end
        if numel(flat) > 1
            return;
        end
    end
    tf = true;
end

function out = choiceToString(v)
    out = '';
    if isempty(v)
        return;
    end
    if iscell(v)
        out = char(string(v{end}));
    elseif ischar(v)
        out = v;
    elseif isstring(v) || isnumeric(v) || islogical(v) || iscategorical(v)
        vals = string(v(:));
        if ~isempty(vals)
            out = char(vals(end));
        end
    else
        try
            out = char(string(v));
        catch
            out = '';
        end
    end
    out = strtrim(out);
end

function compatible = findCompatibleResources(resources, spec)
    resources = normalizeResourceInventory(resources);
    compatible = resourceInventoryDef();
    wantedType = lower(char(string(getField(spec, 'type', ''))));
    wantedRole = lower(char(string(getField(spec, 'role', ''))));
    for i = 1:numel(resources)
        if ~resourceSpecCompatible(wantedType, wantedRole, resources(i).type, resources(i).role)
            continue;
        end
        if isAmbiguousCollectionResource(resources(i), spec)
            continue;
        end
        compatible(end+1) = resources(i); %#ok<AGROW>
    end
end

function tf = resourceSpecCompatible(wantedType, wantedRole, availableType, availableRole)
    wantedType = lower(char(string(wantedType)));
    wantedRole = lower(char(string(wantedRole)));
    availableType = lower(char(string(availableType)));
    availableRole = lower(char(string(availableRole)));
    tf = strcmp(wantedType, availableType) && resourceRolesCompatible(wantedRole, availableRole);
    if tf
        return;
    end
    tf = strcmp(wantedType, 'dataseriesvariable') && strcmp(availableType, 'dataseries') && ...
        dataSeriesVariableRoleCompatible(wantedRole, availableRole);
    if tf
        return;
    end
    tf = strcmp(wantedType, 'channel') && strcmp(wantedRole, 'mask_roi_image') && ...
        strcmp(availableType, 'mask') && strcmp(availableRole, 'segmentation');
end

function tf = dataSeriesVariableRoleCompatible(wantedRole, availableRole)
    wantedRole = lower(char(string(wantedRole)));
    availableRole = lower(char(string(availableRole)));
    tf = false;
    if isempty(wantedRole) || isempty(availableRole)
        tf = true;
        return;
    end
    switch wantedRole
        case {'metric_variable','metrics_variable'}
            tf = strcmp(availableRole, 'metrics');
        case {'classification_label','classification_variable'}
            tf = strcmp(availableRole, 'classification');
        otherwise
            tf = strcmp(wantedRole, availableRole);
    end
end

function tf = resourceRolesCompatible(wantedRole, availableRole)
    wantedRole = lower(char(string(wantedRole)));
    availableRole = lower(char(string(availableRole)));
    tf = isempty(wantedRole) || isempty(availableRole) || strcmp(wantedRole, availableRole);
    if tf
        return;
    end
    if strcmp(wantedRole, 'score_roi_image')
        tf = any(strcmp(availableRole, roiScorableChannelRoles()));
        return;
    end
    if strcmp(wantedRole, 'mask_roi_image')
        tf = any(strcmp(availableRole, {'roi_image','mask_roi_image','derived_roi_image','tracking','lineage_mask','lineage_cell_mask','lineage_mother_mask','lineage_bud_mask'}));
        return;
    end
    if strcmp(wantedRole, 'roi_image')
        tf = any(strcmp(availableRole, roiScorableChannelRoles()));
        return;
    end
    if strcmp(wantedRole, 'z_stack')
        tf = any(strcmp(availableRole, roiScorableChannelRoles()));
        return;
    end
    tf = false;
end

function roles = roiScorableChannelRoles()
    roles = {'roi_image','score_roi_image','derived_roi_image','probability','tracking','lineage_mask','lineage_cell_mask','lineage_confidence','lineage_mother_mask','lineage_bud_mask'};
end

function out = nonContextResources(resources)
    out = resourceInventoryDef();
    resources = normalizeResourceInventory(resources);
    for i = 1:numel(resources)
        sourceKind = lower(char(string(resources(i).sourceKind)));
        if any(strcmp(sourceKind, {'context','ctx','runtime'}))
            continue;
        end
        out(end+1) = resources(i); %#ok<AGROW>
    end
end

function choice = findSymbolicResourceChoice(resources, symbolicValue)
    choice = resourceInventoryDef();
    sourceNode = symbolicResourceSourceNode(symbolicValue);
    if isempty(sourceNode)
        return;
    end
    requestedRole = symbolicResourceRole(symbolicValue);
    resources = normalizeResourceInventory(resources);
    for i = 1:numel(resources)
        resourceRole = char(string(resources(i).role));
        resourceSymbol = char(string(resources(i).symbol));
        if strcmp(char(string(resources(i).sourceNode)), sourceNode) && ...
                (isempty(requestedRole) || strcmpi(resourceRole, requestedRole) || strcmpi(resourceSymbol, requestedRole) || endsWith(resourceSymbol, ['.' requestedRole], 'IgnoreCase', true))
            choice(end+1) = resources(i); %#ok<AGROW>
        end
    end
end

function choice = findExistingConcreteChoiceForSymbolicBinding(symbolicValue, spec, compatibleResources, ctx)
    choice = resourceInventoryDef();
    sourceNodeId = symbolicResourceSourceNode(symbolicValue);
    if isempty(sourceNodeId) || ~symbolicFallbackAllowedFromContext(ctx, sourceNodeId)
        return;
    end

    sourceNode = findPipelineNodeInContext(ctx, sourceNodeId);
    if isempty(sourceNode)
        return;
    end

    expectedOutputs = compatibleDeclaredOutputsForSourceNode(sourceNode, spec);
    if isempty(expectedOutputs)
        return;
    end

    matches = resourceInventoryDef();
    for i = 1:numel(expectedOutputs)
        out = expectedOutputs(i);
        if isempty(strtrim(char(string(getField(out, 'concreteName', '')))))
            continue;
        end
        matches = mergeResourceInventory(matches, findExistingResourcesMatchingConcreteName(compatibleResources, out)); %#ok<AGROW>
    end

    choice = pickUniqueConcreteResourceChoice(matches, expectedOutputs);
end

function tf = symbolicFallbackAllowedFromContext(ctx, sourceNodeId)
    tf = false;
    if ~isstruct(ctx) || ~isfield(ctx, 'run') || ~isstruct(ctx.run) || ...
            ~isfield(ctx.run, 'selectedNodes') || isempty(ctx.run.selectedNodes)
        return;
    end
    selected = cellstr(string(ctx.run.selectedNodes(:)))';
    tf = ~any(strcmp(selected, char(string(sourceNodeId))));
end

function node = findPipelineNodeInContext(ctx, nodeId)
    node = struct([]);
    if ~isstruct(ctx) || isempty(nodeId)
        return;
    end

    node = findNodeByIdLocal(getField(getField(ctx, 'pipelineSpec', struct()), 'nodes', struct([])), nodeId);
    if ~isempty(node)
        return;
    end

    pipelinePath = '';
    try
        pipelineRef = getField(ctx, 'pipelineRef', struct());
        pipelinePath = char(string(getField(pipelineRef, 'path', '')));
    catch
        pipelinePath = '';
    end
    if isempty(strtrim(pipelinePath))
        return;
    end

    try
        [pipeObj, msg] = pipelineLoad(pipelinePath); %#ok<ASGLU>
        if isempty(pipeObj)
            return;
        end
        node = findNodeByIdLocal(pipeObj.nodes, nodeId);
    catch
        node = struct([]);
    end
end

function node = findNodeByIdLocal(nodes, nodeId)
    node = struct([]);
    if isempty(nodes)
        return;
    end
    for i = 1:numel(nodes)
        if strcmp(char(string(getField(nodes(i), 'id', ''))), char(string(nodeId)))
            node = nodes(i);
            return;
        end
    end
end

function outputs = compatibleDeclaredOutputsForSourceNode(node, inputSpec)
    outputs = resourceBindingDef();
    if isempty(node)
        return;
    end

    contract = getField(node, 'contract', struct());
    if isempty(fieldnames(contract))
        try
            contract = pipelineNodeContract(node);
        catch
            contract = struct();
        end
    end
    outSpecs = getField(getField(contract, 'resources', struct()), 'out', resourceSpecDef());
    if isempty(outSpecs)
        return;
    end

    wantedType = char(string(getField(inputSpec, 'type', '')));
    wantedRole = char(string(getField(inputSpec, 'role', '')));
    for i = 1:numel(outSpecs)
        spec = outSpecs(i);
        if isempty(getField(spec, 'type', ''))
            continue;
        end
        if ~resourceSpecCompatible(wantedType, wantedRole, spec.type, spec.role)
            continue;
        end
        outputs(end+1) = makeResourceOutput(node, spec); %#ok<AGROW>
    end
end

function matches = findExistingResourcesMatchingConcreteName(resources, expectedOutput)
    matches = resourceInventoryDef();
    resources = normalizeResourceInventory(resources);
    expectedName = strtrim(char(string(getField(expectedOutput, 'concreteName', ''))));
    if isempty(expectedName)
        return;
    end
    for i = 1:numel(resources)
        concreteName = strtrim(char(string(getField(resources(i), 'concreteName', ''))));
        if strcmpi(concreteName, expectedName)
            matches(end+1) = resources(i); %#ok<AGROW>
        end
    end
end

function choice = pickUniqueConcreteResourceChoice(matches, expectedOutputs)
    choice = resourceInventoryDef();
    matches = normalizeResourceInventory(matches);
    if isempty(matches)
        return;
    end

    concreteNames = {matches.concreteName};
    concreteNames = concreteNames(~cellfun(@isempty, concreteNames));
    if isempty(concreteNames)
        return;
    end
    uniqueConcrete = unique(cellfun(@(x) lower(char(string(x))), concreteNames, 'UniformOutput', false), 'stable');
    if numel(uniqueConcrete) ~= 1
        return;
    end

    for i = 1:numel(expectedOutputs)
        exact = matches(strcmpi({matches.type}, char(string(expectedOutputs(i).type))) & ...
                        strcmpi({matches.role}, char(string(expectedOutputs(i).role))));
        if numel(exact) == 1
            choice = exact;
            return;
        end
    end

    choice = matches(1);
end

function sourceNode = symbolicResourceSourceNode(symbolicValue)
    sourceNode = '';
    symbolicValue = strtrim(char(string(symbolicValue)));
    if startsWith(symbolicValue, '@resource:')
        parts = strsplit(symbolicValue, ':');
        if numel(parts) >= 3
            sourceNode = strtrim(parts{3});
            sourceNode = dataSeriesNameFromVariableBinding(sourceNode);
        end
        return;
    end
    if startsWith(symbolicValue, '@')
        symbolicValue = symbolicValue(2:end);
    end
    if contains(symbolicValue, '.')
        parts = strsplit(symbolicValue, '.');
        sourceNode = strtrim(parts{1});
        return;
    end
    tokens = regexp(symbolicValue, 'output\s+from\s+([^/\s>]+)', 'tokens', 'once');
    if ~isempty(tokens)
        sourceNode = strtrim(tokens{1});
    end
end

function seriesName = dataSeriesNameFromVariableBinding(value)
    seriesName = strtrim(char(string(value)));
    if contains(seriesName, '/')
        parts = regexp(seriesName, '\s*/\s*', 'split');
        if ~isempty(parts)
            seriesName = strtrim(parts{1});
        end
    end
end

function role = symbolicResourceRole(symbolicValue)
    role = '';
    symbolicValue = strtrim(char(string(symbolicValue)));
    if startsWith(symbolicValue, '@resource:')
        parts = strsplit(symbolicValue, ':');
        if numel(parts) >= 2
            role = strtrim(parts{2});
        end
    end
    role = canonicalSymbolicResourceRole(role);
end

function role = canonicalSymbolicResourceRole(role)
    role = char(string(role));
    switch lower(strtrim(role))
        case {'lineage_cell','lineage_cell_mask','lineage_mask'}
            role = 'lineage_mother';
        case {'lineage_conf','lineage_confidence'}
            role = 'lineage_bud';
    end
end

function label = resourceSourceLabel(resource)
    if isempty(resource)
        label = '';
        return;
    end
    r = resource(1);
    label = char(string(r.symbol));
    if isempty(label)
        label = char(string(r.concreteName));
    end
    if ~isempty(r.sourceNode)
        label = [label ' (' char(string(r.sourceNode)) ')'];
    end
end

function names = resourceConcreteNames(resources, type, role)
    names = {};
    resources = normalizeResourceInventory(resources);
    for i = 1:numel(resources)
        if ~strcmpi(resources(i).type, type)
            continue;
        end
        if nargin >= 3 && ~isempty(role) && ~strcmpi(resources(i).role, role)
            continue;
        end
        nm = char(string(resources(i).concreteName));
        if isempty(nm)
            if strcmpi(resources(i).type, 'channel') && strcmpi(resources(i).sourcePort, 'channels') && ...
                    any(strcmpi(resources(i).sourceKind, {'sourceInventory','imagesToRoi'}))
                continue;
            end
            nm = char(string(resources(i).symbol));
        end
        if ~isempty(nm)
            names{end+1} = nm; %#ok<AGROW>
        end
    end
    names = unique(names, 'stable');
end

function names = normalizeResourceNameList(v)
    names = normalizeChannelList(v);
    if isstruct(v) || isobject(v)
        names = {};
        probes = {'groupid','name','id','concreteName','symbol'};
        for i = 1:numel(v)
            for j = 1:numel(probes)
                value = [];
                if isstruct(v) && isfield(v(i), probes{j})
                    value = v(i).(probes{j});
                elseif isobject(v) && isprop(v(i), probes{j})
                    value = v(i).(probes{j});
                end
                if ~isempty(value)
                    names{end+1} = char(string(value)); %#ok<AGROW>
                    break
                end
            end
        end
        names = unique(names(~cellfun(@isempty, names)), 'stable');
    end
end

function names = inferRoiDataSeriesNames(roiList)
    names = {};
    try
        if isempty(roiList)
            return;
        end
        r0 = roiList(1);
        ds = [];
        if isprop(r0, 'data')
            ds = r0.data;
        elseif isfield(r0, 'data')
            ds = r0.data;
        end
        names = normalizeResourceNameList(ds);
    catch
        names = {};
    end
end

function role = inferDataSeriesRole(name)
    low = lower(char(string(name)));
    if contains(low, 'rls')
        role = 'rls';
    elseif contains(low, 'div') || contains(low, 'class') || contains(low, 'cnn') || contains(low, 'lstm')
        role = 'classification';
    elseif contains(low, 'metric') || contains(low, 'quant')
        role = 'metrics';
    else
        role = 'dataSeries';
    end
end

function out = mergeStructLocal(base, override)
    out = base;
    if ~isstruct(override)
        return;
    end
    fn = fieldnames(override);
    for i = 1:numel(fn)
        out.(fn{i}) = override.(fn{i});
    end
end

function [ok, errors, warnings] = validateEdgePorts(edge, nodes, ids)
    ok = true;
    errors = {};
    warnings = {};

    if ~ismember(edge.from, ids) || ~ismember(edge.to, ids)
        return;
    end

    src = nodes(strcmp(ids, edge.from));
    dst = nodes(strcmp(ids, edge.to));

    srcPorts = getPortNames(getField(getField(src, 'contract', struct()), 'out', struct([])));
    dstPorts = getPortNames(getField(getField(dst, 'contract', struct()), 'in', struct([])));

    if isempty(edge.fromPort)
        warnings{end+1} = ['Edge ' edge.from ' -> ' edge.to ' has no fromPort; using legacy inference.']; %#ok<AGROW>
    elseif ~any(strcmp(srcPorts, edge.fromPort))
        ok = false;
        errors{end+1} = ['Invalid fromPort "' edge.fromPort '" on edge ' edge.from ' -> ' edge.to '.']; %#ok<AGROW>
    end

    if isempty(edge.toPort)
        warnings{end+1} = ['Edge ' edge.from ' -> ' edge.to ' has no toPort; using legacy inference.']; %#ok<AGROW>
    elseif ~any(strcmp(dstPorts, edge.toPort))
        ok = false;
        errors{end+1} = ['Invalid toPort "' edge.toPort '" on edge ' edge.from ' -> ' edge.to '.']; %#ok<AGROW>
    end

    if ok && ~isempty(edge.fromPort) && ~isempty(edge.toPort)
        srcType = getPortType(getField(getField(src, 'contract', struct()), 'out', struct([])), edge.fromPort);
        dstType = getPortType(getField(getField(dst, 'contract', struct()), 'in', struct([])), edge.toPort);
        if ~isempty(srcType) && ~isempty(dstType) && ~strcmp(srcType, 'generic') && ~strcmp(dstType, 'generic') && ~strcmp(srcType, dstType)
            ok = false;
            errors{end+1} = ['Type mismatch on edge ' edge.from '.' edge.fromPort ' -> ' edge.to '.' edge.toPort ...
                ' (' srcType ' -> ' dstType ').']; %#ok<AGROW>
        end
    end
end

function port = inferEdgePort(nodes, nodeId, direction)
    port = '';
    if isempty(nodeId) || isempty(nodes)
        return;
    end
    idx = find(strcmp(arrayfun(@(n) char(string(n.id)), nodes, 'UniformOutput', false), nodeId), 1);
    if isempty(idx)
        return;
    end
    contract = getField(nodes(idx), 'contract', struct());
    if strcmp(direction, 'out')
        ports = getField(contract, 'out', struct([]));
    else
        ports = getField(contract, 'in', struct([]));
    end
    if numel(ports) == 1
        port = char(string(ports(1).name));
    end
end

function available = initialAvailablePorts(ctx)
    available = fieldnames(ctx);
    if any(strcmp(available, 'shallowObj')) && ~any(strcmp(available, 'shallow'))
        available{end+1} = 'shallow'; %#ok<AGROW>
    elseif any(strcmp(available, 'shallow')) && ~any(strcmp(available, 'shallowObj'))
        available{end+1} = 'shallowObj'; %#ok<AGROW>
    end
    if any(strcmp(available, 'dataSeriesNames')) && ~any(strcmp(available, 'dataSeries'))
        available{end+1} = 'dataSeries'; %#ok<AGROW>
    end
    if any(strcmp(available, 'roiChannels')) && ~any(strcmp(available, 'channels'))
        available{end+1} = 'channels'; %#ok<AGROW>
    end
    if ((any(strcmp(available, 'fovList')) || any(strcmp(available, 'shallow')) || any(strcmp(available, 'shallowObj'))) && ...
            ~any(strcmp(available, 'images')))
        available{end+1} = 'images'; %#ok<AGROW>
    end
    if validationStartsFromExistingProject(ctx) && ~any(strcmp(available, 'roiList'))
        available{end+1} = 'roiList'; %#ok<AGROW>
    end
    available = unique(available(:));
end

function req = requiredInputNames(node)
    req = {};
    contract = getField(node, 'contract', struct());
    if isstruct(contract) && isfield(contract, 'in') && ~isempty(contract.in)
        req = {contract.in([contract.in.required]).name};
    elseif isfield(node, 'inputs') && ~isempty(node.inputs)
        req = cellstr(node.inputs(:));
    end
end

function out = outputNames(node)
    out = {};
    contract = getField(node, 'contract', struct());
    if isstruct(contract) && isfield(contract, 'out') && ~isempty(contract.out)
        out = {contract.out.name};
    elseif isfield(node, 'outputs') && ~isempty(node.outputs)
        out = cellstr(node.outputs(:));
    end
end

function [inputs, outputs] = contractIoNames(contract)
    inputs = {};
    outputs = {};
    if isstruct(contract) && isfield(contract, 'in') && ~isempty(contract.in)
        inputs = {contract.in.name};
    end
    if isstruct(contract) && isfield(contract, 'out') && ~isempty(contract.out)
        outputs = {contract.out.name};
    end
end

function names = getPortNames(ports)
    names = {};
    if isstruct(ports) && ~isempty(ports)
        names = {ports.name};
    end
end

function type = getPortType(ports, portName)
    type = '';
    if ~isstruct(ports) || isempty(ports)
        return;
    end
    idx = find(strcmp({ports.name}, portName), 1);
    if ~isempty(idx)
        type = char(string(ports(idx).type));
    end
end

function v = getField(S, fieldName, defaultValue)
    v = defaultValue;
    if isstruct(S) && isfield(S, fieldName)
        tmp = S.(fieldName);
        if ~isempty(tmp)
            v = tmp;
        end
    end
end

function tf = hasNodeGui(node)
    tf = isfield(node,'gui') && ~isempty(node.gui);
end
