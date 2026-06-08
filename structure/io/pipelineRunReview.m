function [review, text] = pipelineRunReview(runOrPath, varargin)
% pipelineRunReview  Build a readable review from a pipeline run and event log.
%
% Usage:
%   [review, text] = pipelineRunReview(runObj)
%   pipelineRunReview(runObj, 'Write', true)

    opts = struct('Write', false, 'OutputPath', '');
    opts = parseOptions(opts, varargin{:});

    [runObj, runPath] = resolveRunAndPath(runOrPath);
    if ~isempty(runObj)
        events = pipelineRunEventsRead(runObj);
    else
        events = pipelineRunEventsRead(runPath);
    end
    totalEventCount = numel(events);
    events = latestRunAttemptEvents(events);

    review = struct();
    review.generatedAt = char(datetime('now'));
    review.runPath = runPath;
    review.runId = readRunId(runObj, events);
    review.status = readRunStatus(runObj, events);
    review.eventCount = numel(events);
    review.totalEventCount = totalEventCount;
    review.eventLogPath = fullfile(runPath, 'run_events.jsonl');
    review.summary = summarizeEvents(events);
    review.nodes = summarizeNodes(events, runObj);
    review.issues = summarizeIssues(events, runObj);
    review.artifacts = listRunArtifacts(runPath);

    text = formatReviewText(review);

    if logical(opts.Write)
        outPath = char(string(opts.OutputPath));
        if isempty(outPath)
            outPath = fullfile(runPath, 'run_review.txt');
        end
        writeTextFile(outPath, text);
        review.reviewPath = outPath;
    end
end

function opts = parseOptions(opts, varargin)
    i = 1;
    while i <= numel(varargin)
        key = lower(char(string(varargin{i})));
        value = [];
        if i < numel(varargin)
            value = varargin{i+1};
        end
        i = i + 2;
        switch key
            case 'write'
                opts.Write = logical(value);
            case {'outputpath','path'}
                opts.OutputPath = char(string(value));
        end
    end
end

function [runObj, runPath] = resolveRunAndPath(runOrPath)
    runObj = [];
    runPath = '';
    if nargin < 1 || isempty(runOrPath)
        error('pipelineRunReview:MissingRun', 'A pipeline run object or run path is required.');
    end
    if isa(runOrPath, 'pipelineRun')
        runObj = runOrPath;
        try
            [runPath, ~] = runObj.getPath;
        catch
            runPath = char(string(getPropOr(runObj, 'path', '')));
        end
        return;
    end
    p = char(string(runOrPath));
    if isfile(p)
        [folder, file, ext] = fileparts(p);
        if strcmpi([file ext], 'run.json')
            runPath = folder;
            try
                runObj = pipelineRunLoad(p);
            catch
            end
        else
            runPath = folder;
        end
    elseif isfolder(p)
        runPath = p;
        runJson = fullfile(runPath, 'run.json');
        if isfile(runJson)
            try
                runObj = pipelineRunLoad(runJson);
            catch
            end
        end
    end
end

function runId = readRunId(runObj, events)
    runId = '';
    try
        if ~isempty(runObj)
            runId = char(string(runObj.runId));
        end
    catch
    end
    if isempty(runId) && ~isempty(events) && isfield(events, 'runId')
        runId = firstText({events.runId});
    end
end

function status = readRunStatus(runObj, events)
    status = readEventRunStatus(events);
    if ~isempty(status)
        return;
    end
    status = readHubRunStatus(runObj);
    if ~isempty(status)
        return;
    end
    try
        if ~isempty(runObj)
            status = char(string(runObj.status));
        end
    catch
    end
end

function events = latestRunAttemptEvents(events)
    if isempty(events) || ~isfield(events, 'type')
        return;
    end
    types = string({events.type});
    starts = find(types == "run_start");
    if isempty(starts)
        return;
    end
    events = events(starts(end):end);
end

function status = readHubRunStatus(runObj)
    status = '';
    jobId = readHubJobId(runObj);
    if isempty(jobId) || exist('detecdiv_hub_get_pipeline_run', 'file') ~= 2
        return;
    end
    try
        hub = readRunHubSettings(runObj);
        if isempty(hub)
            job = detecdiv_hub_get_pipeline_run(jobId);
        else
            job = detecdiv_hub_get_pipeline_run(jobId, hub);
        end
        if isstruct(job) && isfield(job, 'status') && ~isempty(job.status)
            status = ['hub_' char(string(job.status))];
        end
    catch
        status = '';
    end
end

function status = readEventRunStatus(events)
    status = '';
    if isempty(events) || ~isfield(events, 'type')
        return;
    end
    types = string({events.type});
    if any(types == "run_done")
        status = 'done';
    elseif any(types == "run_cancelled")
        status = 'cancelled';
    elseif any(types == "run_failed")
        status = 'failed';
    elseif any(types == "node_start")
        status = 'running_or_interrupted';
    end
end

function jobId = readHubJobId(runObj)
    jobId = '';
    candidates = { ...
        {'ctx','hub','job_id'}, ...
        {'ctx','hub','hub_job_id'}, ...
        {'ctx','run','control','jobId'}};
    for i = 1:numel(candidates)
        jobId = valueText(getNestedRunValue(runObj, candidates{i}, ''));
        if ~isempty(strtrim(jobId))
            return;
        end
    end
end

function hub = readRunHubSettings(runObj)
    hub = [];
    try
        hub = getNestedRunValue(runObj, {'ctx','hub'}, []);
        if ~isstruct(hub)
            hub = [];
        end
    catch
        hub = [];
    end
end

function summary = summarizeEvents(events)
    summary = struct('startedAt', '', 'endedAt', '', 'durationSec', NaN, ...
        'lastEventType', '', 'lastEventAt', '', 'doneNodes', 0, ...
        'failedNodes', 0, 'cancelledNodes', 0, 'skippedNodes', 0);
    if isempty(events)
        return;
    end
    if isfield(events, 'ts')
        summary.startedAt = firstText({events.ts});
        summary.lastEventAt = lastText({events.ts});
        summary.endedAt = summary.lastEventAt;
        summary.durationSec = secondsBetween(summary.startedAt, summary.endedAt);
    end
    if isfield(events, 'type')
        types = string({events.type});
        summary.lastEventType = char(types(end));
        summary.doneNodes = sum(types == "node_done");
        summary.failedNodes = sum(types == "node_failed");
        summary.cancelledNodes = sum(types == "node_cancelled");
        summary.skippedNodes = sum(types == "node_skipped");
    end
end

function nodes = summarizeNodes(events, runObj)
    nodes = struct('nodeId', {}, 'nodeType', {}, 'status', {}, ...
        'startedAt', {}, 'endedAt', {}, 'durationSec', {}, 'message', {});
    if ~isempty(events) && isfield(events, 'NodeId')
        eventNodeIds = eventFieldValues(events, 'NodeId');
        ids = unique(nonEmptyTexts(eventNodeIds), 'stable');
        for i = 1:numel(ids)
            nodeEvents = events(strcmp(eventNodeIds, ids{i}));
            nodes(end+1) = summarizeNodeEvents(ids{i}, nodeEvents); %#ok<AGROW>
        end
    end
    if ~isempty(nodes)
        return;
    end
    report = struct();
    try
        report = runObj.outputs.report;
    catch
    end
    if isstruct(report) && isfield(report, 'nodeRuns') && ~isempty(report.nodeRuns)
        for i = 1:numel(report.nodeRuns)
            nr = report.nodeRuns(i);
            nodes(end+1) = struct( ... %#ok<AGROW>
                'nodeId', valueText(getFieldOr(nr, 'nodeId', '')), ...
                'nodeType', valueText(getFieldOr(nr, 'nodeType', '')), ...
                'status', valueText(getFieldOr(nr, 'status', '')), ...
                'startedAt', '', 'endedAt', '', ...
                'durationSec', double(getFieldOr(nr, 'durationSec', NaN)), ...
                'message', valueText(getFieldOr(nr, 'message', '')));
        end
    end
end

function node = summarizeNodeEvents(nodeId, events)
    node = struct('nodeId', nodeId, 'nodeType', '', 'status', '', ...
        'startedAt', '', 'endedAt', '', 'durationSec', NaN, 'message', '');
    if isempty(events)
        return;
    end
    if isfield(events, 'NodeType')
        node.nodeType = firstText({events.NodeType});
    end
    if isfield(events, 'ts')
        node.startedAt = firstText({events.ts});
        node.endedAt = lastText({events.ts});
        node.durationSec = secondsBetween(node.startedAt, node.endedAt);
    end
    if isfield(events, 'Status')
        node.status = lastText({events.Status});
    end
    if isempty(node.status) && isfield(events, 'type')
        node.status = eventTypeToStatus(lastText({events.type}));
    end
    if isfield(events, 'Message')
        node.message = lastText({events.Message});
    end
end

function issues = summarizeIssues(events, runObj)
    issues = {};
    if ~isempty(events) && isfield(events, 'type')
        types = string({events.type});
        bad = find(types == "node_failed" | types == "node_cancelled" | ...
            types == "run_failed" | types == "run_cancelled");
        for i = 1:numel(bad)
            idx = bad(i);
            issues{end+1} = sprintf('%s %s %s', eventText(events(idx), 'ts'), ...
                eventText(events(idx), 'type'), eventText(events(idx), 'Message')); %#ok<AGROW>
        end
    end
    try
        if isstruct(runObj.outputs) && isfield(runObj.outputs, 'error')
            err = runObj.outputs.error;
            issues{end+1} = ['error: ' valueText(getFieldOr(err, 'message', ''))]; %#ok<AGROW>
        elseif isstruct(runObj.outputs) && isfield(runObj.outputs, 'cancellation')
            c = runObj.outputs.cancellation;
            issues{end+1} = ['cancelled: ' valueText(getFieldOr(c, 'message', ''))]; %#ok<AGROW>
        end
    catch
    end
end

function artifacts = listRunArtifacts(runPath)
    artifacts = {};
    if isempty(runPath) || exist(runPath, 'dir') ~= 7
        return;
    end
    names = {'run.json','run_params.json','run_summary.txt','run_log.txt', ...
        'run_events.jsonl','run_review.txt','smoke_report.txt'};
    for i = 1:numel(names)
        p = fullfile(runPath, names{i});
        if isfile(p)
            artifacts{end+1} = p; %#ok<AGROW>
        end
    end
end

function text = formatReviewText(review)
    lines = {};
    lines{end+1} = 'Pipeline run review'; %#ok<AGROW>
    lines{end+1} = ['Generated: ' review.generatedAt]; %#ok<AGROW>
    lines{end+1} = ['Run ID: ' review.runId]; %#ok<AGROW>
    lines{end+1} = ['Status: ' review.status]; %#ok<AGROW>
    lines{end+1} = ['Run folder: ' review.runPath]; %#ok<AGROW>
    if isfield(review, 'totalEventCount') && review.totalEventCount ~= review.eventCount
        lines{end+1} = sprintf('Event count: %d latest attempt / %d total', review.eventCount, review.totalEventCount); %#ok<AGROW>
    else
        lines{end+1} = ['Event count: ' num2str(review.eventCount)]; %#ok<AGROW>
    end
    lines{end+1} = ''; %#ok<AGROW>
    lines{end+1} = 'Timeline'; %#ok<AGROW>
    lines{end+1} = ['- Started: ' review.summary.startedAt]; %#ok<AGROW>
    lines{end+1} = ['- Last event: ' review.summary.lastEventAt ' (' review.summary.lastEventType ')']; %#ok<AGROW>
    if isfinite(review.summary.durationSec)
        lines{end+1} = sprintf('- Duration: %.1f s', review.summary.durationSec); %#ok<AGROW>
    end
    lines{end+1} = sprintf('- Nodes: done=%d skipped=%d failed=%d cancelled=%d', ...
        review.summary.doneNodes, review.summary.skippedNodes, ...
        review.summary.failedNodes, review.summary.cancelledNodes); %#ok<AGROW>
    lines{end+1} = ''; %#ok<AGROW>
    lines{end+1} = 'Nodes'; %#ok<AGROW>
    if isempty(review.nodes)
        lines{end+1} = '- No node execution data found.'; %#ok<AGROW>
    else
        for i = 1:numel(review.nodes)
            n = review.nodes(i);
            dur = '';
            if isfinite(n.durationSec)
                dur = sprintf(' %.1fs', n.durationSec);
            end
            lines{end+1} = sprintf('- %s [%s] %s%s', ...
                n.nodeId, n.nodeType, n.status, dur); %#ok<AGROW>
            if ~isempty(strtrim(n.message))
                lines{end+1} = ['  message: ' n.message]; %#ok<AGROW>
            end
        end
    end
    lines{end+1} = ''; %#ok<AGROW>
    lines{end+1} = 'Issues'; %#ok<AGROW>
    if isempty(review.issues)
        lines{end+1} = '- None recorded.'; %#ok<AGROW>
    else
        for i = 1:numel(review.issues)
            lines{end+1} = ['- ' review.issues{i}]; %#ok<AGROW>
        end
    end
    lines{end+1} = ''; %#ok<AGROW>
    lines{end+1} = 'Artifacts'; %#ok<AGROW>
    if isempty(review.artifacts)
        lines{end+1} = '- None found.'; %#ok<AGROW>
    else
        for i = 1:numel(review.artifacts)
            lines{end+1} = ['- ' review.artifacts{i}]; %#ok<AGROW>
        end
    end
    text = [strjoin(lines, newline) newline];
end

function writeTextFile(path, text)
    folder = fileparts(path);
    if ~isempty(folder) && exist(folder, 'dir') ~= 7
        mkdir(folder);
    end
    fid = fopen(path, 'w');
    if fid < 0
        error('pipelineRunReview:IO', 'Unable to write %s.', path);
    end
    cleaner = onCleanup(@()fclose(fid)); %#ok<NASGU>
    fwrite(fid, text, 'char');
end

function out = nonEmptyTexts(values)
    out = {};
    for i = 1:numel(values)
        txt = valueText(values{i});
        if ~isempty(strtrim(txt))
            out{end+1} = txt; %#ok<AGROW>
        end
    end
end

function values = eventFieldValues(events, fieldName)
    values = cell(1, numel(events));
    for i = 1:numel(events)
        values{i} = eventText(events(i), fieldName);
    end
end

function txt = firstText(values)
    txt = '';
    for i = 1:numel(values)
        txt = valueText(values{i});
        if ~isempty(strtrim(txt))
            return;
        end
    end
end

function txt = lastText(values)
    txt = '';
    for i = numel(values):-1:1
        txt = valueText(values{i});
        if ~isempty(strtrim(txt))
            return;
        end
    end
end

function sec = secondsBetween(a, b)
    sec = NaN;
    try
        ta = datetime(a, 'InputFormat', 'yyyy-MM-dd HH:mm:ss.SSS');
        tb = datetime(b, 'InputFormat', 'yyyy-MM-dd HH:mm:ss.SSS');
        sec = seconds(tb - ta);
    catch
    end
end

function status = eventTypeToStatus(typeText)
    switch char(string(typeText))
        case 'node_done'
            status = 'done';
        case 'node_failed'
            status = 'failed';
        case 'node_cancelled'
            status = 'cancelled';
        case 'node_skipped'
            status = 'skipped';
        otherwise
            status = char(string(typeText));
    end
end

function txt = eventText(evt, name)
    txt = '';
    if isstruct(evt) && isfield(evt, name)
        txt = valueText(evt.(name));
    end
end

function v = getFieldOr(S, fieldName, defaultValue)
    v = defaultValue;
    if isstruct(S) && isfield(S, fieldName) && ~isempty(S.(fieldName))
        v = S.(fieldName);
    end
end

function v = getPropOr(obj, fieldName, defaultValue)
    v = defaultValue;
    try
        if isprop(obj, fieldName) && ~isempty(obj.(fieldName))
            v = obj.(fieldName);
        end
    catch
    end
end

function value = getNestedRunValue(runObj, pathParts, defaultValue)
    value = defaultValue;
    try
        cur = runObj;
        for i = 1:numel(pathParts)
            key = pathParts{i};
            if isstruct(cur)
                if ~isfield(cur, key)
                    value = defaultValue;
                    return;
                end
                cur = cur.(key);
            else
                if ~isprop(cur, key)
                    value = defaultValue;
                    return;
                end
                cur = cur.(key);
            end
        end
        if ~isempty(cur)
            value = cur;
        end
    catch
        value = defaultValue;
    end
end

function txt = valueText(v)
    if isempty(v)
        txt = '';
        return;
    end
    if ischar(v)
        txt = v;
    elseif isstring(v)
        txt = char(strjoin(v(:), ", "));
    elseif isnumeric(v) || islogical(v)
        txt = mat2str(v);
    elseif iscell(v)
        try
            txt = char(strjoin(string(v(:)), ", "));
        catch
            txt = '{cell}';
        end
    else
        try
            txt = char(string(v));
        catch
            txt = '';
        end
    end
end
