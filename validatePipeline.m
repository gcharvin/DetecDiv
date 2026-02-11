function [ok, report] = validatePipeline(pipe, ctx)
% validatePipeline  Validate pipeline structure and dependencies.

    ok = true;
    report = struct('errors',{{}}, 'order', [], 'nodes', [], 'edges', []);

    if nargin < 2
        ctx = struct();
    end

    P = pipelineToStructLocal(pipe);
    nodes = P.nodes;
    edges = normalizeEdges(P);

    report.nodes = nodes;
    report.edges = edges;

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
        available = fieldnames(ctx);
        if isfield(P,'inputs')
            available = unique([available(:); cellstr(P.inputs(:))]);
        end

        for i = 1:numel(order)
            node = nodes(strcmp(ids, order{i}));
            if isfield(node,'inputs') && ~isempty(node.inputs)
                req = cellstr(node.inputs(:));
                missing = setdiff(req, available);
                if ~isempty(missing)
                    ok = false;
                    report.errors{end+1} = ['Missing inputs for node ' node.id ': ' strjoin(missing, ', ')];
                end
            end
            if isfield(node,'outputs') && ~isempty(node.outputs)
                out = cellstr(node.outputs(:));
                available = unique([available(:); out(:)]);
            end
        end
    catch
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

function edges = normalizeEdges(P)
    edges = struct('from',{},'to',{},'condition',{});
    if isfield(P,'edges') && ~isempty(P.edges)
        if isstruct(P.edges)
            edges = P.edges;
        elseif iscell(P.edges)
            for i = 1:size(P.edges,1)
                edges(end+1).from = char(string(P.edges{i,1})); %#ok<AGROW>
                edges(end).to = char(string(P.edges{i,2}));
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
