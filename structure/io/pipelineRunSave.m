function pipelineRunSave(runObj, opts)
% pipelineRunSave  Save pipeline run to JSON in its folder.

    if nargin < 1 || isempty(runObj)
        return;
    end
    if nargin < 2 || isempty(opts)
        opts = struct();
    end
    opts = normalizeSaveOptions(opts);
    verbose = opts.verbose;

    [path, ~] = runObj.getPath;
    if isempty(path)
        error('pipelineRunSave:NoPath','Pipeline run path is empty.');
    end
    if ~exist(path,'dir')
        mkdir(path);
    end

    jsonFile = fullfile(path, 'run.json');
    previousStatus = readPreviousRunStatus(jsonFile);
    runObj.ctx = attachRunPathsToContext(runObj.ctx, path, runObj.runId);

    runObj.updatedAt = char(datetime('now'));
    S = pipelineRunToStruct(runObj);

    try
        txt = jsonencode(S, 'PrettyPrint', true);
    catch
        txt = jsonencode(S);
    end

    fid = fopen(jsonFile, 'w');
    if fid < 0
        error('pipelineRunSave:IO','Unable to write %s', jsonFile);
    end
    fwrite(fid, txt, 'char');
    fclose(fid);

    if shouldWriteSidecars(opts, previousStatus, S, path)
        writeRunSummaryFile(runObj, S, path);
        writeRunParamsFile(S, path);
        writeRunLogFile(runObj, S, path, opts);
        if opts.review
            writeRunReviewFile(runObj, path);
        end
    end

    if verbose
        fprintf('Pipeline run saved: %s\n', jsonFile);
    end
end

function opts = normalizeSaveOptions(opts)
    if nargin < 1 || isempty(opts)
        opts = struct();
    end
    if ~isstruct(opts)
        opts = struct();
    end
    if ~isfield(opts, 'verbose') || isempty(opts.verbose)
        opts.verbose = true;
    else
        opts.verbose = logical(opts.verbose);
    end
    if ~isfield(opts, 'sidecars') || isempty(opts.sidecars)
        opts.sidecars = 'auto';
    end
    if islogical(opts.sidecars) || isnumeric(opts.sidecars)
        opts.sidecars = logical(opts.sidecars);
    else
        opts.sidecars = lower(strtrim(char(string(opts.sidecars))));
    end
    if ~isfield(opts, 'review') || isempty(opts.review)
        opts.review = false;
    else
        opts.review = logical(opts.review);
    end
    if ~isfield(opts, 'includeRuntimeLogs') || isempty(opts.includeRuntimeLogs)
        opts.includeRuntimeLogs = false;
    else
        opts.includeRuntimeLogs = logical(opts.includeRuntimeLogs);
    end
end

function status = readPreviousRunStatus(jsonFile)
    status = '';
    if exist(jsonFile, 'file') ~= 2
        return;
    end
    try
        S = jsondecode(fileread(jsonFile));
        if isstruct(S) && isfield(S, 'status') && ~isempty(S.status)
            status = char(string(S.status));
        end
    catch
        status = '';
    end
end

function tf = shouldWriteSidecars(opts, previousStatus, S, runPath)
    if islogical(opts.sidecars)
        tf = opts.sidecars;
        return;
    end
    switch lower(char(string(opts.sidecars)))
        case {'true', 'on', 'yes', 'always'}
            tf = true;
        case {'false', 'off', 'no', 'never'}
            tf = false;
        otherwise
            currentStatus = char(string(getFieldOrDefault(S, 'status', '')));
            firstSave = exist(fullfile(runPath, 'run_summary.txt'), 'file') ~= 2;
            statusChanged = ~strcmp(char(string(previousStatus)), currentStatus);
            tf = firstSave || statusChanged;
    end
end

function ctx = attachRunPathsToContext(ctx, runPath, runId)
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
    if isempty(runPath)
        return;
    end
    eventLogPath = fullfile(runPath, 'run_events.jsonl');
    if nargin >= 3 && ~isempty(runId)
        ctx.runId = char(string(runId));
        ctx.run.runId = char(string(runId));
    end
    ctx.run.path = runPath;
    ctx.run.runPath = runPath;
    ctx.run.eventLogPath = eventLogPath;
    ctx.io.eventLogPath = eventLogPath;
    ctx.store.runPath = runPath;
    ctx.store.eventLogPath = eventLogPath;
end

function S = pipelineRunToStruct(runObj)
    S = struct();
    S.runId = runObj.runId;
    S.id = runObj.id;

    S.pipelineRef = getOrDefaultStruct(runObj, 'pipelineRef', struct('id','','path','','version',''));
    S.targetRef = getOrDefaultStruct(runObj, 'targetRef', struct('type','shallow','projectPath','','projectName','', ...
        'fovIds',[],'roiIds',{{}},'classiPath','','notes',''));

    % compatibility keys
    S.templateId = runObj.templateId;
    S.templatePath = runObj.templatePath;
    S.projectPath = runObj.projectPath;
    S.projectName = runObj.projectName;

    S.description = runObj.description;
    S.status = runObj.status;
    S.ctx = sanitizeForJson(stripRuntimeOnlyContext(runObj.ctx));
    S.outputs = sanitizeForJson(runObj.outputs);
    S.progress = sanitizeForJson(runObj.progress);
    S.createdAt = runObj.createdAt;
    S.updatedAt = char(datetime('now'));
end

function ctx = stripRuntimeOnlyContext(ctx)
    if ~isstruct(ctx)
        return;
    end
    try
        if isfield(ctx,'store') && isstruct(ctx.store) && isfield(ctx.store,'classifierRuntime')
            ctx.store = rmfield(ctx.store, 'classifierRuntime');
        end
    catch
    end
    try
        if isfield(ctx,'cancel')
            ctx = rmfield(ctx, 'cancel');
        end
    catch
    end
    try
        if isfield(ctx,'progressDlg')
            ctx = rmfield(ctx, 'progressDlg');
        end
    catch
    end
end

function S = getOrDefaultStruct(obj, fieldName, defaultValue)
    if isprop(obj, fieldName)
        S = obj.(fieldName);
        if isempty(S) || ~isstruct(S)
            S = defaultValue;
        end
    else
        S = defaultValue;
    end
end

function writeRunSummaryFile(runObj, S, runPath)
    txtFile = fullfile(runPath, 'run_summary.txt');
    txt = buildRunSummaryText(runObj, S);
    fid = fopen(txtFile, 'w');
    if fid < 0
        warning('pipelineRunSave:SummaryIO', 'Unable to write %s', txtFile);
        return;
    end
    fwrite(fid, txt, 'char');
    fclose(fid);
end

function writeRunParamsFile(S, runPath)
    jsonFile = fullfile(runPath, 'run_params.json');
    P = struct();
    P.runId = getFieldOrDefault(S, 'runId', '');
    P.status = getFieldOrDefault(S, 'status', '');
    P.pipelineRef = getFieldOrDefault(S, 'pipelineRef', struct());
    P.targetRef = getFieldOrDefault(S, 'targetRef', struct());
    P.createdAt = getFieldOrDefault(S, 'createdAt', '');
    P.updatedAt = getFieldOrDefault(S, 'updatedAt', '');
    ctx = getFieldOrDefault(S, 'ctx', struct());
    if isstruct(ctx)
        P.run = getFieldOrDefault(ctx, 'run', struct());
        P.io = getFieldOrDefault(ctx, 'io', struct());
        P.sel = getFieldOrDefault(ctx, 'sel', struct());
        P.store = getFieldOrDefault(ctx, 'store', struct());
        P.hub = getFieldOrDefault(ctx, 'hub', struct());
        P.names = getFieldOrDefault(ctx, 'names', struct());
    end
    try
        txt = jsonencode(P, 'PrettyPrint', true);
    catch
        txt = jsonencode(P);
    end
    fid = fopen(jsonFile, 'w');
    if fid < 0
        warning('pipelineRunSave:ParamsIO', 'Unable to write %s', jsonFile);
        return;
    end
    fwrite(fid, txt, 'char');
    fclose(fid);
end

function writeRunLogFile(runObj, S, runPath, opts)
    txtFile = fullfile(runPath, 'run_log.txt');
    lines = {};
    lines{end+1} = sprintf('Run ID: %s', char(string(getFieldOrDefault(S, 'runId', '')))); %#ok<AGROW>
    lines{end+1} = sprintf('Status: %s', char(string(getFieldOrDefault(S, 'status', '')))); %#ok<AGROW>
    lines{end+1} = sprintf('Pipeline: %s', char(string(getNestedOrDefault(S, {'pipelineRef','path'}, '')))); %#ok<AGROW>
    lines{end+1} = sprintf('Project: %s', char(string(getFieldOrDefault(S, 'projectPath', '')))); %#ok<AGROW>
    lines{end+1} = sprintf('Updated: %s', char(string(getFieldOrDefault(S, 'updatedAt', '')))); %#ok<AGROW>
    lines{end+1} = '';

    outputs = getFieldOrDefault(S, 'outputs', struct());
    if isstruct(outputs) && isfield(outputs, 'error') && isstruct(outputs.error)
        lines{end+1} = 'Last error:'; %#ok<AGROW>
        lines{end+1} = sprintf('  Identifier: %s', valueToChar(getFieldOrDefault(outputs.error, 'identifier', ''))); %#ok<AGROW>
        lines{end+1} = sprintf('  Message: %s', valueToChar(getFieldOrDefault(outputs.error, 'message', ''))); %#ok<AGROW>
        detail = valueToChar(getFieldOrDefault(outputs.error, 'report', ''));
        if ~isempty(strtrim(detail))
            lines{end+1} = '  Report:'; %#ok<AGROW>
            lines{end+1} = detail; %#ok<AGROW>
        end
        lines{end+1} = '';
    end

    lines{end+1} = 'History:'; %#ok<AGROW>
    if isprop(runObj, 'history') && ~isempty(runObj.history)
        for i = 1:height(runObj.history)
            line = formatHistoryLine(runObj.history, i);
            if ~isempty(line)
                lines{end+1} = line; %#ok<AGROW>
            end
        end
    end
    if nargin >= 4 && isstruct(opts) && isfield(opts, 'includeRuntimeLogs') && opts.includeRuntimeLogs
        lines = appendRuntimeSidecarLogs(lines, runPath);
    end
    txt = [strjoin(lines, newline) newline];
    fid = fopen(txtFile, 'w');
    if fid < 0
        warning('pipelineRunSave:LogIO', 'Unable to write %s', txtFile);
        return;
    end
    fwrite(fid, txt, 'char');
    fclose(fid);
end

function lines = appendRuntimeSidecarLogs(lines, runPath)
    classifierRoot = classifierRootFromRunPath(runPath);
    lines = appendFileSection(lines, 'Runtime progress', fullfile(runPath, 'progress.json'), 120);
    if isempty(classifierRoot)
        return;
    end

    runnerLog = fullfile(classifierRoot, 'sam31_train', 'train_sam31_runner.log');
    lines = appendFileSection(lines, 'SAM31 runner log', runnerLog, 240);

    [internalLog, internalStats] = findLatestSam31TrainingLogs(classifierRoot);
    lines = appendFileSection(lines, 'SAM31 internal training log', internalLog, 300);
    lines = appendFileSection(lines, 'SAM31 train stats', internalStats, 120);
end

function classifierRoot = classifierRootFromRunPath(runPath)
    classifierRoot = '';
    if isempty(runPath)
        return;
    end
    try
        [pipelineRunsDir, ~] = fileparts(runPath);
        [rootCandidate, leaf] = fileparts(pipelineRunsDir);
        if strcmpi(leaf, 'pipeline_runs') && ~isempty(rootCandidate)
            classifierRoot = rootCandidate;
        end
    catch
        classifierRoot = '';
    end
end

function [logPath, statsPath] = findLatestSam31TrainingLogs(classifierRoot)
    logPath = '';
    statsPath = '';
    if isempty(classifierRoot)
        return;
    end
    artifactsRoot = fullfile(classifierRoot, 'sam31_artifacts');
    if exist(artifactsRoot, 'dir') ~= 7
        return;
    end
    logPath = newestFile(fullfile(artifactsRoot, '**', 'logs', '*', 'log.txt'));
    statsPath = newestFile(fullfile(artifactsRoot, '**', 'logs', '*', 'train_stats.json'));
end

function path = newestFile(pattern)
    path = '';
    try
        files = dir(pattern);
        files = files(~[files.isdir]);
        if isempty(files)
            return;
        end
        [~, idx] = max([files.datenum]);
        path = fullfile(files(idx).folder, files(idx).name);
    catch
        path = '';
    end
end

function lines = appendFileSection(lines, title, path, maxLines)
    if isempty(path) || exist(path, 'file') ~= 2
        return;
    end
    body = tailTextFile(path, maxLines);
    if isempty(strtrim(body))
        return;
    end
    lines{end+1} = ''; %#ok<AGROW>
    lines{end+1} = sprintf('%s: %s', title, path); %#ok<AGROW>
    lines{end+1} = body; %#ok<AGROW>
end

function txt = tailTextFile(path, maxLines)
    txt = '';
    try
        raw = fileread(path);
    catch
        return;
    end
    parts = regexp(raw, '\r\n|\n|\r', 'split');
    if ~isempty(parts) && isempty(parts{end})
        parts(end) = [];
    end
    if numel(parts) > maxLines
        parts = parts(end - maxLines + 1:end);
        parts = [{sprintf('[showing last %d lines]', maxLines)} parts];
    end
    txt = strjoin(parts, newline);
end

function writeRunReviewFile(runObj, runPath)
    eventFile = fullfile(runPath, 'run_events.jsonl');
    if exist(eventFile, 'file') ~= 2
        return;
    end
    try
        pipelineRunReview(runObj, 'Write', true);
    catch ME
        warning('pipelineRunSave:ReviewIO', 'Unable to write run review: %s', ME.message);
    end
end

function txt = buildRunSummaryText(runObj, S)
    try
        eventFile = fullfile(runObj.path, 'run_events.jsonl');
        if isfile(eventFile)
            review = pipelineRunReview(runObj, 'Write', false);
            txt = buildRunSummaryTextFromReview(review);
            return;
        end
    catch
    end

    lines = {};
    lines{end+1} = sprintf('Run ID: %s', char(string(runObj.runId))); %#ok<AGROW>
    lines{end+1} = sprintf('Status: %s', char(string(runObj.status))); %#ok<AGROW>
    lines{end+1} = sprintf('Project: %s', char(string(getFieldOrDefault(S, 'projectPath', '')))); %#ok<AGROW>
    lines{end+1} = sprintf('Pipeline: %s', char(string(getNestedOrDefault(S, {'pipelineRef','id'}, '')))); %#ok<AGROW>
    lines{end+1} = sprintf('Created: %s', char(string(getFieldOrDefault(S, 'createdAt', '')))); %#ok<AGROW>
    lines{end+1} = sprintf('Updated: %s', char(string(getFieldOrDefault(S, 'updatedAt', '')))); %#ok<AGROW>
    eventLogPath = getNestedOrDefault(S, {'ctx','run','eventLogPath'}, '');
    if ~isempty(eventLogPath)
        lines{end+1} = sprintf('Event log: %s', char(string(eventLogPath))); %#ok<AGROW>
    end

    report = struct();
    outputs = getFieldOrDefault(S, 'outputs', struct());
    if isstruct(outputs) && isfield(outputs, 'report') && isstruct(outputs.report)
        report = outputs.report;
    end

    if ~isempty(fieldnames(report))
        lines{end+1} = '';
        lines{end+1} = 'Summary'; %#ok<AGROW>
        summary = getFieldOrDefault(report, 'summary', struct());
        if isstruct(summary) && ~isempty(fieldnames(summary))
            keys = {'totalNodes','doneNodes','skippedNodes','failedNodes'};
            for i = 1:numel(keys)
                if isfield(summary, keys{i})
                    lines{end+1} = sprintf('  %s: %s', keys{i}, valueToChar(summary.(keys{i}))); %#ok<AGROW>
                end
            end
        end
        if isfield(report, 'startedAt')
            lines{end+1} = sprintf('  startedAt: %s', valueToChar(report.startedAt)); %#ok<AGROW>
        end
        if isfield(report, 'endedAt')
            lines{end+1} = sprintf('  endedAt: %s', valueToChar(report.endedAt)); %#ok<AGROW>
        end

        nodeRuns = getFieldOrDefault(report, 'nodeRuns', struct([]));
        if isstruct(nodeRuns) && ~isempty(nodeRuns)
            lines{end+1} = '';
            lines{end+1} = 'Nodes'; %#ok<AGROW>
            for i = 1:numel(nodeRuns)
                row = nodeRuns(i);
                base = sprintf('- %s [%s] status=%s', ...
                    valueToChar(getFieldOrDefault(row,'nodeId','')), ...
                    valueToChar(getFieldOrDefault(row,'nodeType','')), ...
                    valueToChar(getFieldOrDefault(row,'status','')));
                pol = sprintf(' runPolicy=%s existingPolicy=%s', ...
                    valueToChar(getFieldOrDefault(row,'runPolicy','')), ...
                    valueToChar(getFieldOrDefault(row,'existingPolicy','')));
                dur = sprintf(' duration=%.3fs', double(getFieldOrDefault(row,'durationSec',0)));
                delta = '';
                before = getFieldOrDefault(row,'before', struct());
                after = getFieldOrDefault(row,'after', struct());
                if isstruct(before) && isstruct(after) && isfield(before,'fovCount') && isfield(after,'fovCount') ...
                        && isfield(before,'roiCount') && isfield(after,'roiCount')
                    delta = sprintf(' fov=%d->%d roi=%d->%d', ...
                        double(before.fovCount), double(after.fovCount), ...
                        double(before.roiCount), double(after.roiCount));
                end
                lines{end+1} = [base pol dur delta]; %#ok<AGROW>
                msg = valueToChar(getFieldOrDefault(row,'message',''));
                if ~isempty(strtrim(msg))
                    lines{end+1} = ['  message: ' msg]; %#ok<AGROW>
                end
            end
        end
    end

    if isprop(runObj, 'history') && ~isempty(runObj.history)
        histLines = {};
        startIdx = max(1, height(runObj.history) - 20 + 1);
        for i = startIdx:height(runObj.history)
            line = formatHistoryLine(runObj.history, i);
            if ~isempty(line)
                histLines{end+1} = line; %#ok<AGROW>
            end
        end
        if ~isempty(histLines)
            lines{end+1} = '';
            lines{end+1} = 'History'; %#ok<AGROW>
            lines = [lines histLines]; %#ok<AGROW>
        end
    end

    txt = strjoin(lines, newline);
    txt = [txt newline];
end

function txt = buildRunSummaryTextFromReview(review)
    lines = {};
    lines{end+1} = sprintf('Run ID: %s', valueToChar(getFieldOrDefault(review, 'runId', ''))); %#ok<AGROW>
    lines{end+1} = sprintf('Status: %s', valueToChar(getFieldOrDefault(review, 'status', ''))); %#ok<AGROW>
    lines{end+1} = sprintf('Run folder: %s', valueToChar(getFieldOrDefault(review, 'runPath', ''))); %#ok<AGROW>
    lines{end+1} = sprintf('Event log: %s', valueToChar(getFieldOrDefault(review, 'eventLogPath', ''))); %#ok<AGROW>
    if isfield(review, 'eventCount') && isfield(review, 'totalEventCount') && review.eventCount ~= review.totalEventCount
        lines{end+1} = sprintf('Events: %d latest attempt / %d total', review.eventCount, review.totalEventCount); %#ok<AGROW>
    end

    summary = getFieldOrDefault(review, 'summary', struct());
    nodes = getFieldOrDefault(review, 'nodes', struct([]));
    lines{end+1} = ''; %#ok<AGROW>
    lines{end+1} = 'Summary'; %#ok<AGROW>
    lines{end+1} = sprintf('  totalNodes: %d', numel(nodes)); %#ok<AGROW>
    lines{end+1} = sprintf('  doneNodes: %s', valueToChar(getFieldOrDefault(summary, 'doneNodes', 0))); %#ok<AGROW>
    lines{end+1} = sprintf('  skippedNodes: %s', valueToChar(getFieldOrDefault(summary, 'skippedNodes', 0))); %#ok<AGROW>
    lines{end+1} = sprintf('  failedNodes: %s', valueToChar(getFieldOrDefault(summary, 'failedNodes', 0))); %#ok<AGROW>
    lines{end+1} = sprintf('  cancelledNodes: %s', valueToChar(getFieldOrDefault(summary, 'cancelledNodes', 0))); %#ok<AGROW>
    lines{end+1} = sprintf('  startedAt: %s', valueToChar(getFieldOrDefault(summary, 'startedAt', ''))); %#ok<AGROW>
    lines{end+1} = sprintf('  endedAt: %s', valueToChar(getFieldOrDefault(summary, 'endedAt', ''))); %#ok<AGROW>

    lines{end+1} = ''; %#ok<AGROW>
    lines{end+1} = 'Nodes'; %#ok<AGROW>
    if isempty(nodes)
        lines{end+1} = '- No node execution data found.'; %#ok<AGROW>
    else
        for i = 1:numel(nodes)
            row = nodes(i);
            lines{end+1} = sprintf('- %s [%s] status=%s duration=%s', ...
                valueToChar(getFieldOrDefault(row, 'nodeId', '')), ...
                valueToChar(getFieldOrDefault(row, 'nodeType', '')), ...
                valueToChar(getFieldOrDefault(row, 'status', '')), ...
                valueToChar(getFieldOrDefault(row, 'durationSec', ''))); %#ok<AGROW>
            msg = valueToChar(getFieldOrDefault(row, 'message', ''));
            if ~isempty(strtrim(msg))
                lines{end+1} = ['  message: ' msg]; %#ok<AGROW>
            end
        end
    end
    txt = [strjoin(lines, newline) newline];
end

function v = getFieldOrDefault(S, name, defaultVal)
    v = defaultVal;
    if isstruct(S) && isfield(S, name) && ~isempty(S.(name))
        v = S.(name);
    end
end

function v = getNestedOrDefault(S, pathParts, defaultVal)
    v = defaultVal;
    cur = S;
    for i = 1:numel(pathParts)
        if ~isstruct(cur) || ~isfield(cur, pathParts{i})
            return;
        end
        cur = cur.(pathParts{i});
    end
    if ~isempty(cur)
        v = cur;
    end
end

function txt = valueToChar(v)
    if isstring(v)
        txt = char(string(v));
    elseif ischar(v)
        txt = v;
    elseif isnumeric(v) || islogical(v)
        txt = num2str(v);
    else
        try
            txt = char(string(v));
        catch
            txt = '';
        end
    end
end

function line = formatHistoryLine(historyTable, idx)
    line = '';
    try
        category = string(historyTable.Category(idx));
        message = string(historyTable.Message(idx));
        if (ismissing(category) || strlength(category) == 0) && ...
                (ismissing(message) || strlength(message) == 0)
            return;
        end
        dateValue = historyTable.Date(idx);
        line = sprintf('- %s [%s] %s', ...
            char(string(dateValue)), char(category), char(message));
    catch
    end
end

function out = sanitizeForJson(in)
    if isempty(in)
        out = in;
        return;
    end

    if isstruct(in)
        out = in;
        fn = fieldnames(in);
        for k = 1:numel(in)
            for i = 1:numel(fn)
                out(k).(fn{i}) = sanitizeForJson(in(k).(fn{i}));
            end
        end
        return;
    end

    if iscell(in)
        out = cell(size(in));
        for i = 1:numel(in)
            out{i} = sanitizeForJson(in{i});
        end
        return;
    end

    if isnumeric(in) || islogical(in) || ischar(in)
        out = in;
        return;
    end

    if isstring(in)
        out = cellstr(in);
        return;
    end

    if isdatetime(in)
        out = char(in);
        return;
    end

    if isa(in,'handle')
        out = struct('className', class(in), 'note', 'handle omitted for JSON');
        return;
    end

    try
        jsonencode(in);
        out = in;
    catch
        out = struct('className', class(in), 'note', 'value omitted for JSON');
    end
end
