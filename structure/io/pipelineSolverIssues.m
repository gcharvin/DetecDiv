function solver = pipelineSolverIssues(report, nodes)
% pipelineSolverIssues  Convert validation/binding output into actionable UX items.
%
% The validator keeps the machine-facing result in errors/warnings/binding.
% This helper builds a small, stable action list for pipelineGUI and run
% preflight screens.

    if nargin < 1 || isempty(report) || ~isstruct(report)
        report = struct();
    end
    if nargin < 2 || isempty(nodes)
        nodes = struct([]);
    end

    issues = emptyIssue();

    issues = appendMissingParamIssues(issues, report, nodes, 'missingParams', ...
        'error', 'missing_template_param', 'design', 'open_node_params');
    issues = appendMissingParamIssues(issues, report, nodes, 'deferredParams', ...
        'warning', 'needs_run_param', 'run_preflight', 'open_run_params');
    issues = appendBindingIssues(issues, report, nodes);
    issues = appendGenericMessages(issues, report, 'errors', 'error', nodes);
    issues = appendGenericMessages(issues, report, 'warnings', 'warning', nodes);

    issues = dedupeIssues(issues);
    table = issueTable(issues);

    solver = struct( ...
        'issues', issues, ...
        'table', {table}, ...
        'summary', summarizeIssues(issues), ...
        'hasBlocking', any(strcmp({issues.severity}, 'error')));
end

function issues = appendMissingParamIssues(issues, report, nodes, fieldName, severity, status, resolveAt, action)
    if ~isfield(report, fieldName) || isempty(report.(fieldName))
        return;
    end
    entries = report.(fieldName);
    for i = 1:numel(entries)
        entry = entries{i};
        if ~isstruct(entry) || ~isfield(entry, 'node')
            continue;
        end
        nodeId = char(string(entry.node));
        params = {};
        if isfield(entry, 'missing') && ~isempty(entry.missing)
            params = cellstr(string(entry.missing(:)));
        end
        node = findNode(nodes, nodeId);
        for k = 1:numel(params)
            paramName = char(string(params{k}));
            msg = sprintf('Parameter "%s" must be set for node %s.', paramName, nodeId);
            if strcmp(resolveAt, 'run_preflight')
                msg = sprintf('Parameter "%s" must be resolved before the run is submitted.', paramName);
            end
            issues(end+1) = makeIssue(node, severity, status, nodeId, paramName, msg, resolveAt, action); %#ok<AGROW>
        end
    end
end

function issues = appendBindingIssues(issues, report, nodes)
    if ~isfield(report, 'binding') || ~isstruct(report.binding) || ...
            ~isfield(report.binding, 'nodes') || ~isstruct(report.binding.nodes)
        return;
    end

    keys = fieldnames(report.binding.nodes);
    for i = 1:numel(keys)
        br = report.binding.nodes.(keys{i});
        if ~isstruct(br)
            continue;
        end
        nodeId = char(string(getField(br, 'nodeId', keys{i})));
        node = findNode(nodes, nodeId);
        status = lower(char(string(getField(br, 'status', ''))));
        if isempty(status) || strcmp(status, 'resolved')
            continue;
        end

        severity = 'warning';
        issueStatus = status;
        action = 'open_node_params';
        resolveAt = lower(char(string(getField(br, 'resolveAt', 'run'))));
        if strcmp(resolveAt, 'run')
            resolveAt = 'run_preflight';
            action = 'open_run_params';
        end

        switch status
            case 'invalid'
                severity = 'error';
                issueStatus = 'invalid_binding';
                resolveAt = 'design';
                action = 'open_node_params';
            case 'needs_user_binding'
                issueStatus = 'needs_design_binding';
                resolveAt = 'design';
                action = 'open_node_params';
            case 'needs_run_binding'
                issueStatus = 'needs_run_binding';
                resolveAt = 'run_preflight';
                action = 'open_run_params';
            case 'auto_resolvable'
                severity = 'info';
                issueStatus = 'auto_resolvable_binding';
                action = 'apply_auto_binding';
        end

        msg = char(string(getField(br, 'message', 'Channel binding needs attention.')));
        paramName = bindingParamName(node, br);
        issues(end+1) = makeIssue(node, severity, issueStatus, nodeId, paramName, msg, resolveAt, action); %#ok<AGROW>
    end
end

function issues = appendGenericMessages(issues, report, fieldName, severity, nodes)
    if ~isfield(report, fieldName) || isempty(report.(fieldName))
        return;
    end
    msgs = report.(fieldName);
    for i = 1:numel(msgs)
        msg = char(string(msgs{i}));
        if isempty(strtrim(msg)) || messageAlreadyCovered(issues, msg)
            continue;
        end
        nodeId = inferNodeIdFromMessage(msg, nodes);
        node = findNode(nodes, nodeId);
        issues(end+1) = makeIssue(node, severity, ['validation_' fieldName], nodeId, '', msg, 'design', 'select_node'); %#ok<AGROW>
    end
end

function issue = makeIssue(node, severity, status, nodeId, paramName, message, resolveAt, action)
    if nargin < 1 || ~isstruct(node)
        node = struct();
    end
    nodeName = nodeId;
    moduleType = '';
    pkg = '';
    if isfield(node, 'name') && ~isempty(node.name)
        nodeName = char(string(node.name));
    end
    if isfield(node, 'type') && ~isempty(node.type)
        moduleType = char(string(node.type));
    end
    if isfield(node, 'pkg') && ~isempty(node.pkg)
        pkg = char(string(node.pkg));
    end

    issue = struct( ...
        'id', makeIssueId(status, nodeId, paramName, message), ...
        'severity', char(string(severity)), ...
        'status', char(string(status)), ...
        'scope', 'node', ...
        'nodeId', char(string(nodeId)), ...
        'nodeName', char(string(nodeName)), ...
        'moduleType', moduleType, ...
        'package', pkg, ...
        'param', char(string(paramName)), ...
        'message', char(string(message)), ...
        'stage', issueStage(resolveAt), ...
        'resolveAt', char(string(resolveAt)), ...
        'action', char(string(action)), ...
        'actionLabel', actionLabel(action, resolveAt));
end

function issue = emptyIssue()
    issue = struct( ...
        'id', {}, 'severity', {}, 'status', {}, 'scope', {}, ...
        'nodeId', {}, 'nodeName', {}, 'moduleType', {}, 'package', {}, ...
        'param', {}, 'message', {}, 'stage', {}, 'resolveAt', {}, 'action', {}, 'actionLabel', {});
end

function out = issueTable(issues)
    out = cell(numel(issues), 8);
    for i = 1:numel(issues)
        out{i,1} = issues(i).severity;
        out{i,2} = issues(i).stage;
        out{i,3} = issues(i).nodeName;
        out{i,4} = issues(i).moduleType;
        out{i,5} = issues(i).param;
        out{i,6} = issues(i).resolveAt;
        out{i,7} = issues(i).message;
        out{i,8} = issues(i).actionLabel;
    end
end

function stage = issueStage(resolveAt)
    resolveAt = lower(char(string(resolveAt)));
    switch resolveAt
        case 'design'
            stage = 'Config';
        case 'run_preflight'
            stage = 'Run';
        otherwise
            stage = 'Run';
    end
end

function summary = summarizeIssues(issues)
    summary = struct('errors', 0, 'warnings', 0, 'info', 0, 'total', numel(issues));
    for i = 1:numel(issues)
        switch lower(issues(i).severity)
            case 'error'
                summary.errors = summary.errors + 1;
            case 'warning'
                summary.warnings = summary.warnings + 1;
            otherwise
                summary.info = summary.info + 1;
        end
    end
end

function node = findNode(nodes, nodeId)
    node = struct();
    if isempty(nodes) || isempty(nodeId)
        return;
    end
    for i = 1:numel(nodes)
        if isfield(nodes(i), 'id') && strcmp(char(string(nodes(i).id)), nodeId)
            node = nodes(i);
            return;
        end
    end
end

function name = bindingParamName(node, br)
    name = '';
    contract = struct();
    if isstruct(node) && isfield(node, 'contract') && isstruct(node.contract)
        contract = node.contract;
    end
    if isfield(contract, 'binding') && isstruct(contract.binding)
        keys = getField(contract.binding, 'selectorKeys', {});
        if ~isempty(keys)
            keys = cellstr(string(keys(:)));
            name = strjoin(keys, ', ');
            return;
        end
    end
    if isfield(br, 'mode') && ~isempty(br.mode)
        name = char(string(br.mode));
    end
end

function id = makeIssueId(status, nodeId, paramName, message)
    raw = strjoin({char(string(status)), char(string(nodeId)), char(string(paramName)), char(string(message))}, '|');
    id = matlab.lang.makeValidName(raw);
end

function label = actionLabel(action, resolveAt)
    switch char(string(action))
        case 'open_node_params'
            label = 'Configure node';
        case 'open_run_params'
            label = 'Resolve at run setup';
        case 'apply_auto_binding'
            label = 'Auto-resolve';
        case 'select_node'
            label = 'Select node';
        otherwise
            if strcmp(resolveAt, 'run_preflight')
                label = 'Resolve before run';
            else
                label = 'Review';
            end
    end
end

function tf = messageAlreadyCovered(issues, msg)
    tf = false;
    msg = char(string(msg));
    for i = 1:numel(issues)
        if contains(msg, issues(i).message) || contains(issues(i).message, msg)
            tf = true;
            return;
        end
    end
end

function nodeId = inferNodeIdFromMessage(msg, nodes)
    nodeId = '';
    if isempty(nodes)
        return;
    end
    for i = 1:numel(nodes)
        if ~isfield(nodes(i), 'id')
            continue;
        end
        candidate = char(string(nodes(i).id));
        if contains(msg, candidate)
            nodeId = candidate;
            return;
        end
    end
end

function issues = dedupeIssues(issues)
    if isempty(issues)
        return;
    end
    keep = true(1, numel(issues));
    seen = containers.Map('KeyType','char','ValueType','logical');
    for i = 1:numel(issues)
        key = char(string(issues(i).id));
        if isKey(seen, key)
            keep(i) = false;
        else
            seen(key) = true;
        end
    end
    issues = issues(keep);
end

function v = getField(s, name, defaultValue)
    if nargin < 3
        defaultValue = [];
    end
    v = defaultValue;
    if isstruct(s) && isfield(s, name)
        v = s.(name);
    end
end
