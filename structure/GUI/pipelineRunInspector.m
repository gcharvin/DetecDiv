function fig = pipelineRunInspector(runObj, shallowObj)
% pipelineRunInspector  Lightweight viewer for pipeline run metadata/results.

    if nargin < 1 || isempty(runObj)
        error('pipelineRunInspector:MissingRun', 'A pipeline run object is required.');
    end
    if nargin < 2
        shallowObj = [];
    end

    fig = uifigure('Name', ['Pipeline Run - ' char(string(runObj.runId))], ...
        'Position', [100 100 980 720]);

    grid = uigridlayout(fig, [3 1]);
    grid.RowHeight = {110, '1x', 36};
    grid.ColumnWidth = {'1x'};
    grid.Padding = [10 10 10 10];

    headerArea = uitextarea(grid, 'Editable', 'off');
    headerArea.FontName = 'Consolas';
    headerArea.Value = splitLinesLocal(buildHeaderText(runObj, shallowObj));

    tabs = uitabgroup(grid);
    summaryTab = uitab(tabs, 'Title', 'Summary');
    reviewTab = uitab(tabs, 'Title', 'Review');
    eventsTab = uitab(tabs, 'Title', 'Events');
    paramsTab = uitab(tabs, 'Title', 'Parameters');
    nodesTab = uitab(tabs, 'Title', 'Nodes');

    summaryArea = uitextarea(summaryTab, 'Editable', 'off', ...
        'Position', [10 10 930 510]);
    summaryArea.FontName = 'Consolas';
    summaryArea.Value = splitLinesLocal(readSummaryText(runObj));

    reviewArea = uitextarea(reviewTab, 'Editable', 'off', ...
        'Position', [10 10 930 510]);
    reviewArea.FontName = 'Consolas';
    reviewArea.Value = splitLinesLocal(readReviewText(runObj, false));

    eventTable = uitable(eventsTab, ...
        'ColumnName', {'Time', 'Type', 'Node', 'Status', 'Message'}, ...
        'RowName', {}, ...
        'Position', [10 10 930 510]);
    eventTable.Data = buildEventRows(runObj);

    paramTable = uitable(paramsTab, ...
        'ColumnName', {'Scope', 'Parameter', 'Value'}, ...
        'RowName', {}, ...
        'Position', [10 10 930 510]);
    paramTable.Data = buildParamRows(runObj);

    nodeTable = uitable(nodesTab, ...
        'ColumnName', {'Node', 'Type', 'Status', 'Run policy', 'Existing', 'Duration (s)', 'Message'}, ...
        'RowName', {}, ...
        'Position', [10 10 930 510]);
    nodeTable.Data = buildNodeRows(runObj);

    btnGrid = uigridlayout(grid, [1 8]);
    btnGrid.ColumnWidth = {110, 100, 110, 120, 120, 130, 130, '1x'};
    btnGrid.Padding = [0 0 0 0];

    refreshTimer = timer('ExecutionMode', 'fixedSpacing', 'Period', 2, ...
        'TimerFcn', @(~,~)safeRefreshInspector(runObj, shallowObj, ...
        headerArea, summaryArea, reviewArea, eventTable, paramTable, nodeTable));
    fig.CloseRequestFcn = @(~,~)closeInspector(fig, refreshTimer);

    autoRefreshBtn = uibutton(btnGrid, 'state', 'Text', 'Auto refresh');
    autoRefreshBtn.Layout.Row = 1;
    autoRefreshBtn.Layout.Column = 1;
    autoRefreshBtn.ValueChangedFcn = @(src,~)toggleAutoRefresh(src, refreshTimer, runObj, shallowObj, ...
        headerArea, summaryArea, reviewArea, eventTable, paramTable, nodeTable);

    refreshBtn = uibutton(btnGrid, 'push', 'Text', 'Refresh');
    refreshBtn.Layout.Row = 1;
    refreshBtn.Layout.Column = 2;
    refreshBtn.ButtonPushedFcn = @(~,~)refreshInspector(runObj, shallowObj, ...
        headerArea, summaryArea, reviewArea, eventTable, paramTable, nodeTable);

    writeReviewBtn = uibutton(btnGrid, 'push', 'Text', 'Write review');
    writeReviewBtn.Layout.Row = 1;
    writeReviewBtn.Layout.Column = 3;
    writeReviewBtn.ButtonPushedFcn = @(~,~)writeReviewAndRefresh(runObj, shallowObj, ...
        headerArea, summaryArea, reviewArea, eventTable, paramTable, nodeTable);

    openReviewBtn = uibutton(btnGrid, 'push', 'Text', 'Open review');
    openReviewBtn.Layout.Row = 1;
    openReviewBtn.Layout.Column = 4;
    openReviewBtn.ButtonPushedFcn = @(~,~)openReviewFile(runObj);

    openJsonBtn = uibutton(btnGrid, 'push', 'Text', 'Open run.json');
    openJsonBtn.Layout.Row = 1;
    openJsonBtn.Layout.Column = 5;
    openJsonBtn.ButtonPushedFcn = @(~,~)openRunJson(runObj);

    openSummaryBtn = uibutton(btnGrid, 'push', 'Text', 'Open summary');
    openSummaryBtn.Layout.Row = 1;
    openSummaryBtn.Layout.Column = 6;
    openSummaryBtn.ButtonPushedFcn = @(~,~)openSummaryFile(runObj);

    openFolderBtn = uibutton(btnGrid, 'push', 'Text', 'Open folder');
    openFolderBtn.Layout.Row = 1;
    openFolderBtn.Layout.Column = 7;
    openFolderBtn.ButtonPushedFcn = @(~,~)openRunFolder(runObj);

    closeBtn = uibutton(btnGrid, 'push', 'Text', 'Close');
    closeBtn.Layout.Row = 1;
    closeBtn.Layout.Column = 8;
    closeBtn.ButtonPushedFcn = @(~,~)closeInspector(fig, refreshTimer);
end

function txt = buildHeaderText(runObj, shallowObj)
    lines = {};
    lines{end+1} = ['Run ID: ' char(string(getPropOr(runObj, 'runId', '')))];
    lines{end+1} = ['Status: ' effectiveRunStatus(runObj)];
    lines{end+1} = ['Pipeline ID: ' char(string(getNestedOr(runObj, {'pipelineRef','id'}, '')))];
    [pipePath, pipePathSource] = resolvePipelinePath(runObj, shallowObj);
    lines{end+1} = ['Pipeline path: ' pipePath];
    if ~isempty(pipePathSource)
        lines{end+1} = ['Pipeline path source: ' pipePathSource];
    end
    lines{end+1} = ['Project path: ' char(string(getPropOr(runObj, 'projectPath', '')))];
    lines{end+1} = ['Run folder: ' char(string(getPropOr(runObj, 'path', '')))];
    lines{end+1} = ['Created: ' char(string(getPropOr(runObj, 'createdAt', '')))];
    lines{end+1} = ['Updated: ' char(string(getPropOr(runObj, 'updatedAt', '')))];
    txt = strjoin(lines, newline);
end

function txt = readSummaryText(runObj)
    try
        review = pipelineRunReview(runObj, 'Write', false);
        txt = buildSummaryFromReview(review);
        return;
    catch
    end
    txt = buildFallbackSummary(runObj);
end

function txt = readReviewText(runObj, writeFile)
    if nargin < 2
        writeFile = false;
    end
    try
        [~, txt] = pipelineRunReview(runObj, 'Write', writeFile);
        return;
    catch ME
        txt = ['No structured run review available yet.' newline ME.message];
    end
end

function txt = buildFallbackSummary(runObj)
    lines = {};
    lines{end+1} = ['Run ID: ' char(string(getPropOr(runObj, 'runId', '')))];
    lines{end+1} = ['Status: ' effectiveRunStatus(runObj)];
    try
        report = runObj.outputs.report;
    catch
        report = struct();
    end
    if isstruct(report) && isfield(report, 'nodeRuns') && ~isempty(report.nodeRuns)
        lines{end+1} = '';
        lines{end+1} = 'Nodes';
        for i = 1:numel(report.nodeRuns)
            nr = report.nodeRuns(i);
            lines{end+1} = sprintf('- %s [%s] %s', ...
                char(string(getFieldOr(nr, 'nodeId', ''))), ...
                char(string(getFieldOr(nr, 'nodeType', ''))), ...
                char(string(getFieldOr(nr, 'status', ''))));
        end
    end
    txt = strjoin(lines, newline);
end

function status = effectiveRunStatus(runObj)
    status = char(string(getPropOr(runObj, 'status', '')));
    try
        review = pipelineRunReview(runObj, 'Write', false);
        if isstruct(review) && isfield(review, 'status') && ~isempty(review.status)
            status = char(string(review.status));
        end
    catch
    end
end

function rows = buildParamRows(runObj)
    rows = cell(0, 3);
    try
        ctx = runObj.ctx;
    catch
        ctx = struct();
    end
    if ~isstruct(ctx)
        return;
    end

    if isfield(ctx, 'run') && isstruct(ctx.run)
        rows = appendStructRows(rows, 'Run', ctx.run, {'nodeParams'});
        if isfield(ctx.run, 'selectedNodes')
            rows(end+1,:) = {'Run', 'selectedNodes', valueToDisplay(ctx.run.selectedNodes)}; %#ok<AGROW>
        end
    end
    if isfield(ctx, 'io') && isstruct(ctx.io)
        rows = appendStructRows(rows, 'IO', ctx.io, {});
    end
    if isfield(ctx, 'pipelineRef') && isstruct(ctx.pipelineRef)
        rows = appendStructRows(rows, 'PipelineRef', ctx.pipelineRef, {});
    end
    if isfield(ctx, 'run') && isstruct(ctx.run) && isfield(ctx.run, 'nodeParams') && ~isempty(ctx.run.nodeParams)
        np = ctx.run.nodeParams;
        for i = 1:numel(np)
            nodeId = char(string(getFieldOr(np(i), 'id', ['node_' num2str(i)])));
            params = getFieldOr(np(i), 'params', struct());
            if ~isstruct(params) || isempty(fieldnames(params))
                rows(end+1,:) = {['Node ' nodeId], '(overrides)', '<none>'}; %#ok<AGROW>
                continue;
            end
            fn = fieldnames(params);
            for k = 1:numel(fn)
                rows(end+1,:) = {['Node ' nodeId], fn{k}, valueToDisplay(params.(fn{k}))}; %#ok<AGROW>
            end
        end
    end
end

function rows = buildNodeRows(runObj)
    rows = cell(0, 7);
    try
        review = pipelineRunReview(runObj, 'Write', false);
        if isstruct(review) && isfield(review, 'nodes') && ~isempty(review.nodes)
            for i = 1:numel(review.nodes)
                nr = review.nodes(i);
                rows(end+1,:) = { ... %#ok<AGROW>
                    char(string(getFieldOr(nr, 'nodeId', ''))), ...
                    char(string(getFieldOr(nr, 'nodeType', ''))), ...
                    char(string(getFieldOr(nr, 'status', ''))), ...
                    '', ...
                    '', ...
                    valueToDisplay(getFieldOr(nr, 'durationSec', '')), ...
                    char(string(getFieldOr(nr, 'message', ''))) ...
                    };
            end
            return;
        end
    catch
    end
    report = struct();
    try
        report = runObj.outputs.report;
    catch
    end
    if ~isstruct(report) || ~isfield(report, 'nodeRuns') || isempty(report.nodeRuns)
        return;
    end
    for i = 1:numel(report.nodeRuns)
        nr = report.nodeRuns(i);
        rows(end+1,:) = { ... %#ok<AGROW>
            char(string(getFieldOr(nr, 'nodeId', ''))), ...
            char(string(getFieldOr(nr, 'nodeType', ''))), ...
            char(string(getFieldOr(nr, 'status', ''))), ...
            char(string(getFieldOr(nr, 'runPolicy', ''))), ...
            char(string(getFieldOr(nr, 'existingPolicy', ''))), ...
            valueToDisplay(getFieldOr(nr, 'durationSec', '')), ...
            char(string(getFieldOr(nr, 'message', ''))) ...
            };
    end
end

function rows = buildEventRows(runObj)
    rows = cell(0, 5);
    try
        events = pipelineRunEventsRead(runObj);
        events = latestRunAttemptEventsLocal(events);
    catch
        events = struct([]);
    end
    for i = 1:numel(events)
        rows(end+1,:) = { ... %#ok<AGROW>
            eventField(events(i), 'ts'), ...
            eventField(events(i), 'type'), ...
            eventField(events(i), 'NodeId'), ...
            eventField(events(i), 'Status'), ...
            eventField(events(i), 'Message')};
    end
end

function txt = buildSummaryFromReview(review)
    lines = {};
    lines{end+1} = ['Run ID: ' char(string(getFieldOr(review, 'runId', '')))]; %#ok<AGROW>
    lines{end+1} = ['Status: ' char(string(getFieldOr(review, 'status', '')))]; %#ok<AGROW>
    lines{end+1} = ['Run folder: ' char(string(getFieldOr(review, 'runPath', '')))]; %#ok<AGROW>
    lines{end+1} = ['Event log: ' char(string(getFieldOr(review, 'eventLogPath', '')))]; %#ok<AGROW>
    if isfield(review, 'eventCount') && isfield(review, 'totalEventCount') && review.eventCount ~= review.totalEventCount
        lines{end+1} = sprintf('Events: %d latest attempt / %d total', review.eventCount, review.totalEventCount); %#ok<AGROW>
    end
    lines{end+1} = ''; %#ok<AGROW>
    lines{end+1} = 'Summary'; %#ok<AGROW>
    summary = getFieldOr(review, 'summary', struct());
    totalNodes = 0;
    try
        totalNodes = numel(review.nodes);
    catch
    end
    lines{end+1} = sprintf('  totalNodes: %d', totalNodes); %#ok<AGROW>
    lines{end+1} = sprintf('  doneNodes: %s', valueToDisplay(getFieldOr(summary, 'doneNodes', 0))); %#ok<AGROW>
    lines{end+1} = sprintf('  skippedNodes: %s', valueToDisplay(getFieldOr(summary, 'skippedNodes', 0))); %#ok<AGROW>
    lines{end+1} = sprintf('  failedNodes: %s', valueToDisplay(getFieldOr(summary, 'failedNodes', 0))); %#ok<AGROW>
    lines{end+1} = sprintf('  cancelledNodes: %s', valueToDisplay(getFieldOr(summary, 'cancelledNodes', 0))); %#ok<AGROW>
    lines{end+1} = sprintf('  startedAt: %s', char(string(getFieldOr(summary, 'startedAt', '')))); %#ok<AGROW>
    lines{end+1} = sprintf('  endedAt: %s', char(string(getFieldOr(summary, 'endedAt', '')))); %#ok<AGROW>
    lines{end+1} = ''; %#ok<AGROW>
    lines{end+1} = 'Nodes'; %#ok<AGROW>
    nodes = getFieldOr(review, 'nodes', struct([]));
    if isempty(nodes)
        lines{end+1} = '- No node execution data found.'; %#ok<AGROW>
    else
        for i = 1:numel(nodes)
            nr = nodes(i);
            lines{end+1} = sprintf('- %s [%s] status=%s duration=%s', ...
                char(string(getFieldOr(nr, 'nodeId', ''))), ...
                char(string(getFieldOr(nr, 'nodeType', ''))), ...
                char(string(getFieldOr(nr, 'status', ''))), ...
                valueToDisplay(getFieldOr(nr, 'durationSec', ''))); %#ok<AGROW>
            msg = char(string(getFieldOr(nr, 'message', '')));
            if ~isempty(strtrim(msg))
                lines{end+1} = ['  message: ' msg]; %#ok<AGROW>
            end
        end
    end
    txt = strjoin(lines, newline);
end

function events = latestRunAttemptEventsLocal(events)
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

function refreshInspector(runObj, shallowObj, headerArea, summaryArea, reviewArea, eventTable, paramTable, nodeTable)
    runObj = reloadRunObject(runObj);
    headerArea.Value = splitLinesLocal(buildHeaderText(runObj, shallowObj));
    summaryArea.Value = splitLinesLocal(readSummaryText(runObj));
    reviewArea.Value = splitLinesLocal(readReviewText(runObj, false));
    eventTable.Data = buildEventRows(runObj);
    paramTable.Data = buildParamRows(runObj);
    nodeTable.Data = buildNodeRows(runObj);
end

function safeRefreshInspector(runObj, shallowObj, headerArea, summaryArea, reviewArea, eventTable, paramTable, nodeTable)
    try
        if isempty(headerArea) || ~isvalid(headerArea)
            return;
        end
        refreshInspector(runObj, shallowObj, headerArea, summaryArea, reviewArea, eventTable, paramTable, nodeTable);
    catch
    end
end

function toggleAutoRefresh(src, refreshTimer, runObj, shallowObj, headerArea, summaryArea, reviewArea, eventTable, paramTable, nodeTable)
    try
        if logical(src.Value)
            safeRefreshInspector(runObj, shallowObj, headerArea, summaryArea, reviewArea, eventTable, paramTable, nodeTable);
            start(refreshTimer);
        else
            stop(refreshTimer);
        end
    catch
    end
end

function closeInspector(fig, refreshTimer)
    try
        stop(refreshTimer);
    catch
    end
    try
        delete(refreshTimer);
    catch
    end
    try
        delete(fig);
    catch
    end
end

function writeReviewAndRefresh(runObj, shallowObj, headerArea, summaryArea, reviewArea, eventTable, paramTable, nodeTable)
    runObj = reloadRunObject(runObj);
    reviewArea.Value = splitLinesLocal(readReviewText(runObj, true));
    refreshInspector(runObj, shallowObj, headerArea, summaryArea, reviewArea, eventTable, paramTable, nodeTable);
end

function runObj = reloadRunObject(runObj)
    try
        runPath = char(string(getPropOr(runObj, 'path', '')));
        runJson = fullfile(runPath, 'run.json');
        if isfile(runJson)
            [loaded, ~] = pipelineRunLoad(runJson);
            if ~isempty(loaded) && isa(loaded, 'pipelineRun')
                runObj = loaded;
            end
        end
    catch
    end
end

function rows = appendStructRows(rows, scope, S, skipFields)
    if nargin < 4
        skipFields = {};
    end
    if ~isstruct(S)
        return;
    end
    fn = fieldnames(S);
    for i = 1:numel(fn)
        if any(strcmp(fn{i}, skipFields))
            continue;
        end
        rows(end+1,:) = {scope, fn{i}, valueToDisplay(S.(fn{i}))}; %#ok<AGROW>
    end
end

function out = valueToDisplay(v)
    if ischar(v)
        out = v;
        return;
    end
    if isstring(v)
        out = char(strjoin(v(:), ", "));
        return;
    end
    if islogical(v)
        out = mat2str(v);
        return;
    end
    if isnumeric(v)
        try
            out = mat2str(v);
        catch
            out = num2str(v);
        end
        return;
    end
    if iscell(v)
        try
            out = jsonencode(v);
        catch
            out = sprintf('{cell %dx%d}', size(v,1), size(v,2));
        end
    elseif isstruct(v)
        try
            out = jsonencode(v);
        catch
            out = '{struct}';
        end
    else
        try
            out = char(string(v));
        catch
            out = '<unprintable>';
        end
    end
    if numel(out) > 220
        out = [out(1:217) '...'];
    end
end

function [pipePath, source] = resolvePipelinePath(runObj, shallowObj)
    pipePath = '';
    source = '';
    try
        pipePath = char(string(getNestedOr(runObj, {'pipelineRef','path'}, '')));
        if ~isempty(pipePath)
            source = 'run.pipelineRef.path';
            return;
        end
    catch
    end
    try
        pipePath = char(string(getPropOr(runObj, 'templatePath', '')));
        if ~isempty(pipePath)
            source = 'run.templatePath';
            return;
        end
    catch
    end
    try
        if ~isempty(shallowObj) && isa(shallowObj, 'shallow') && isprop(shallowObj, 'runProfiles') && ...
                isstruct(shallowObj.runProfiles) && isfield(shallowObj.runProfiles, 'pipeline') && ...
                isstruct(shallowObj.runProfiles.pipeline) && isfield(shallowObj.runProfiles.pipeline, 'defaultTemplatePath')
            candidate = char(string(shallowObj.runProfiles.pipeline.defaultTemplatePath));
            if ~isempty(candidate)
                pipePath = fileparts(candidate);
                source = 'project.defaultTemplatePath';
                return;
            end
        end
    catch
    end
end

function openRunJson(runObj)
    runPath = char(string(getPropOr(runObj, 'path', '')));
    runJson = fullfile(runPath, 'run.json');
    if isfile(runJson)
        edit(runJson);
    end
end

function openSummaryFile(runObj)
    runPath = char(string(getPropOr(runObj, 'path', '')));
    summaryFile = fullfile(runPath, 'run_summary.txt');
    if isfile(summaryFile)
        edit(summaryFile);
    end
end

function openReviewFile(runObj)
    runPath = char(string(getPropOr(runObj, 'path', '')));
    reviewFile = fullfile(runPath, 'run_review.txt');
    if ~isfile(reviewFile)
        try
            pipelineRunReview(runObj, 'Write', true);
        catch
        end
    end
    if isfile(reviewFile)
        edit(reviewFile);
    end
end

function openRunFolder(runObj)
    runPath = char(string(getPropOr(runObj, 'path', '')));
    if isempty(runPath) || ~isfolder(runPath)
        return;
    end
    try
        winopen(runPath);
    catch
        try
            cd(runPath);
        catch
        end
    end
end

function v = getPropOr(obj, fieldName, defaultValue)
    v = defaultValue;
    try
        if isprop(obj, fieldName)
            tmp = obj.(fieldName);
            if ~isempty(tmp)
                v = tmp;
            end
        end
    catch
    end
end

function v = getNestedOr(obj, pathParts, defaultValue)
    v = defaultValue;
    try
        tmp = obj;
        for i = 1:numel(pathParts)
            key = pathParts{i};
            if isobject(tmp) && isprop(tmp, key)
                tmp = tmp.(key);
            elseif isstruct(tmp) && isfield(tmp, key)
                tmp = tmp.(key);
            else
                return;
            end
        end
        if ~isempty(tmp)
            v = tmp;
        end
    catch
    end
end

function v = getFieldOr(S, fieldName, defaultValue)
    v = defaultValue;
    if isstruct(S) && isfield(S, fieldName) && ~isempty(S.(fieldName))
        v = S.(fieldName);
    end
end

function txt = eventField(evt, fieldName)
    txt = '';
    try
        if isstruct(evt) && isfield(evt, fieldName) && ~isempty(evt.(fieldName))
            txt = valueToDisplay(evt.(fieldName));
        end
    catch
        txt = '';
    end
end

function out = splitLinesLocal(txt)
    if isempty(txt)
        out = {''};
        return;
    end
    out = regexp(txt, '\r\n|\n|\r', 'split');
    if isempty(out)
        out = {txt};
    end
end
