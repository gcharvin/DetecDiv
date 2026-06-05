function [ok, report] = validatePipeline(pipe, ctx, opts)
% validatePipeline  Validate pipeline structure and dependencies.

    ok = true;
    report = struct('errors',{{}}, 'warnings',{{}}, 'order', [], 'nodes', [], 'edges', [], 'contracts', struct(), 'semantic', struct(), 'binding', struct(), 'solver', struct());

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
            artifactWarnings = classifierArtifactWarnings(node);
            if ~isempty(artifactWarnings)
                report.warnings = [report.warnings, artifactWarnings]; %#ok<AGROW>
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
                channels = mergeKnownChannels(channels, normalizeConfiguredSelectionValue(params.(key)));
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
            channels = normalizeChannelList(params.(key));
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
                report.warnings{end+1} = nodeReport.message; %#ok<AGROW>
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
        'resources', initialResourceInventory(ctx, sem));
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
            unknown = setdiff(lower(configuredChannels), lower(availableChannels));
            if ~isempty(availableChannels) && ~isempty(unknown)
                status = 'invalid';
                message = ['Node ' char(string(node.id)) ' references unknown channel(s): ' strjoin(configuredChannels(ismember(lower(configuredChannels), unknown)), ', ') '.'];
            else
                status = 'resolved';
                message = formatResolvedBindingMessage(node, requiredCount, configuredChannels);
            end
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
        br = evaluateResourceInput(node, r, state.resources);
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
end

function outputs = expandAllRoiExtractChannelOutputs(node, nodeReport, state, outputs)
    if ~strcmpi(char(string(getField(node, 'type', ''))), 'roiExtract') || isempty(outputs)
        return;
    end
    channels = getField(nodeReport, 'configuredChannels', {});
    if isempty(channels)
        channels = getField(state, 'imageChannels', {});
    end
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

function br = evaluateResourceInput(node, spec, availableResources)
    configured = resolveResourceConfiguredValue(node, spec);
    symbolic = resolveResourceSymbolicValue(node, spec);
    compatible = findCompatibleResources(availableResources, spec);
    graphCompatible = nonContextResources(compatible);
    status = 'resolved';
    autoChoice = resourceInventoryDef();

    if ~isempty(configured)
        status = 'resolved';
        msg = sprintf('Node %s binds %s resource "%s" to %s.', ...
            char(string(getField(node, 'id', ''))), char(string(spec.type)), configured, char(string(spec.param)));
    elseif ~isempty(symbolic)
        symbolicChoice = findSymbolicResourceChoice(compatible, symbolic);
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
        chosen = getField(nodeReport, 'configuredChannels', {});
        if isempty(chosen)
            chosen = state.imageChannels;
        end
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

function warnings = classifierArtifactWarnings(node)
    warnings = {};
    if ~strcmpi(char(string(getField(node, 'type', ''))), 'classifier')
        return;
    end
    p = getField(node, 'params', struct());
    hasLinkedPath = isstruct(p) && isfield(p, 'modulePath') && ~isempty(p.modulePath) && ...
        isfield(p, 'moduleId') && ~isempty(p.moduleId);
    hasLinkedVar = isstruct(p) && isfield(p, 'moduleVar') && ~isempty(p.moduleVar);
    if ~(hasLinkedPath || hasLinkedVar)
        warnings{end+1} = ['Classifier node ' char(string(getField(node, 'id', ''))) ...
            ' is not linked to an existing classi object; model weights/training artifacts may be unavailable at run time.']; %#ok<AGROW>
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
        channels = mergeKnownChannels(channels, normalizeConfiguredSelectionValue(params.(key)));
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
                tmp{end+1} = char(string(v{i})); %#ok<AGROW>
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
        port = lower(char(string(getField(spec, 'port', ''))));
        transfer = lower(char(string(getField(spec, 'transfer', ''))));
        if strcmp(type, 'channel') && strcmp(port, 'channels') && any(strcmp(transfer, {'sourceinventory','imagestoroi'}))
            name = '';
        else
            name = char(string(getField(node, 'id', '')));
        end
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
    tf = any(strcmp(s, {'@source','@sources','<source output>','<all source channels>'}));
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
    tf = strcmp(wantedType, 'channel') && strcmp(wantedRole, 'mask_roi_image') && ...
        strcmp(availableType, 'mask') && strcmp(availableRole, 'segmentation');
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
        tf = any(strcmp(availableRole, {'roi_image','mask_roi_image','derived_roi_image','tracking','lineage_mask'}));
        return;
    end
    if strcmp(wantedRole, 'roi_image')
        tf = any(strcmp(availableRole, roiScorableChannelRoles()));
        return;
    end
    tf = false;
end

function roles = roiScorableChannelRoles()
    roles = {'roi_image','score_roi_image','derived_roi_image','probability','tracking','lineage_mask'};
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
    resources = normalizeResourceInventory(resources);
    for i = 1:numel(resources)
        if strcmp(char(string(resources(i).sourceNode)), sourceNode)
            choice(end+1) = resources(i); %#ok<AGROW>
        end
    end
end

function sourceNode = symbolicResourceSourceNode(symbolicValue)
    sourceNode = '';
    symbolicValue = strtrim(char(string(symbolicValue)));
    if startsWith(symbolicValue, '@resource:')
        parts = strsplit(symbolicValue, ':');
        if numel(parts) >= 3
            sourceNode = strtrim(parts{3});
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
