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
        [edgeOk, edgeErrors, edgeWarnings] = validateEdgePorts(edges(i), nodes, ids);
        if ~edgeOk
            ok = false;
            report.errors = [report.errors, edgeErrors]; %#ok<AGROW>
        end
        if ~isempty(edgeWarnings)
            report.warnings = [report.warnings, edgeWarnings]; %#ok<AGROW>
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
        report.warnings{end+1} = ['Semantic validation skipped: ' ME.message];
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

function nodes = normalizeNodesWithContracts(nodes)
    if isempty(nodes)
        return;
    end
    for i = 1:numel(nodes)
        nodes(i).contract = pipelineNodeContract(nodes(i));
        [inNames, outNames] = contractIoNames(nodes(i).contract);
        if ~isfield(nodes(i), 'inputs') || isempty(nodes(i).inputs)
            nodes(i).inputs = inNames;
        end
        if ~isfield(nodes(i), 'outputs') || isempty(nodes(i).outputs)
            nodes(i).outputs = outNames;
        end
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
                          (isfield(ctx,'dataseries') && ~isempty(ctx.dataseries));

    state.imageChannels = unique([ ...
        normalizeChannelList(getField(ctx, 'channels', [])), ...
        inferFovChannels(getField(ctx, 'fovList', []))], 'stable');

    roiList = [];
    if isfield(ctx,'roiList') && ~isempty(ctx.roiList)
        roiList = ctx.roiList;
    elseif isfield(ctx,'rois') && ~isempty(ctx.rois)
        roiList = ctx.rois;
    end
    state.roiChannels = inferRoiChannels(roiList);
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
        if isfield(params, key) && ~isempty(params.(key))
            channels = normalizeChannelList(params.(key));
            if ~isempty(channels)
                return;
            end
        end
    end

    if isstruct(selectors) && isfield(selectors, 'defaultChannels') && ~isempty(selectors.defaultChannels)
        channels = normalizeChannelList(selectors.defaultChannels);
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
                report.warnings{end+1} = nodeReport.message; %#ok<AGROW>
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
        'roiChannels', {sem.roiChannels});
end

function nodeReport = evaluateNodeBinding(node, state)
    contract = getField(node, 'contract', struct());
    binding = getField(contract, 'binding', struct());
    selectors = getField(contract, 'selectors', struct());
    requirements = getField(contract, 'requirements', struct());

    scope = lower(char(string(getBindingScope(binding, requirements))));
    requiredCount = resolveBindingRequiredCount(node, binding, requirements, selectors);
    configuredChannels = resolveBindingConfiguredChannels(node, binding, selectors);
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

    status = 'resolved';
    message = 'No explicit channel binding requirement.';
    autoChoice = {};
    exactCount = getBindingExactCount(node, binding);
    if isempty(exactCount) || exactCount <= 0
        exactCount = [];
    end

    if requiredCount <= 0 && isempty(configuredChannels)
        nodeReport = makeBindingNodeReport(node, binding, scope, status, message, requiredCount, exactCount, configuredChannels, availableChannels, autoChoice);
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
            message = ['Node ' char(string(node.id)) ' depends on channel binding, but the upstream channel inventory is not known statically.'];
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
        'downstreamDemand', []);
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

    if strcmp(nodeType, 'dataloader')
        state.imageChannels = mergeKnownChannels(state.imageChannels, getField(nodeReport, 'configuredChannels', {}));
        return;
    end

    producedName = getField(nodeReport, 'producedChannelName', {});
    if strcmp(nodeType, 'roiextract')
        chosen = getField(nodeReport, 'configuredChannels', {});
        if isempty(chosen)
            chosen = state.imageChannels;
        end
        if isempty(chosen)
            chosen = getField(nodeReport, 'availableChannels', {});
        end
        state.roiChannels = mergeKnownChannels(state.roiChannels, mergeKnownChannels(chosen, producedName));
        return;
    end

    if logical(getField(capabilities, 'roiChannels', false)) || strcmp(getField(binding, 'outputScope', ''), 'roi')
        produced = mergeKnownChannels(getField(nodeReport, 'configuredChannels', {}), producedName);
        state.roiChannels = mergeKnownChannels(state.roiChannels, produced);
    elseif logical(getField(capabilities, 'outputsChannels', false))
        produced = mergeKnownChannels(getField(nodeReport, 'configuredChannels', {}), producedName);
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
    exactCount = getField(binding, 'exactCount', []);
    paramName = char(string(getField(binding, 'exactCountParam', '')));
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
    keep = ~strcmp(low, 'none') & ~strcmp(low, 'n/a');
    channels = channels(keep);
end

function status = classifyUnresolvedBinding(binding, availableChannels)
    resolveAt = lower(char(string(getField(binding, 'resolveAt', 'run'))));
    if isempty(availableChannels)
        if strcmp(resolveAt, 'design')
            status = 'needs_run_binding';
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
    out = unique([normalizeChannelList(a), normalizeChannelList(b)], 'stable');
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
