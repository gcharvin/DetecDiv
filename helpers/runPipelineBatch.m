function report = runPipelineBatch(batchSpec, varargin)
% runPipelineBatch  Execute a validated batch locally, item by item.

    ip = inputParser;
    ip.addParameter('BatchRoot', '', @(x)ischar(x) || isstring(x));
    ip.addParameter('ProgressCallback', [], @(x)isempty(x) || isa(x, 'function_handle'));
    ip.addParameter('StopOnError', false, @(x)islogical(x) || isnumeric(x));
    ip.addParameter('SaveProjects', true, @(x)islogical(x) || isnumeric(x));
    ip.addParameter('HubSettings', struct(), @isstruct);
    ip.parse(varargin{:});
    opts = ip.Results;

    report = struct();
    report.batchId = localStringField(batchSpec, 'id');
    report.batchName = localStringField(batchSpec, 'name');
    report.batchRoot = char(string(opts.BatchRoot));
    report.startedAt = char(datetime('now'));
    report.finishedAt = '';
    report.items = struct([]);
    report.summary = struct('totalItems', 0, 'doneItems', 0, 'failedItems', 0, 'skippedItems', 0);
    report.validation = struct();

    if isempty(opts.BatchRoot)
        opts.BatchRoot = fullfile(tempdir, 'detecdiv_batch_runs', report.batchId);
    end
    report.batchRoot = char(string(opts.BatchRoot));
    ensureFolder(report.batchRoot);
    ensureFolder(fullfile(report.batchRoot, 'items'));
    executionTarget = localExecutionTarget(batchSpec);

    [isValid, validation] = validatePipelineBatch(batchSpec, 'BatchRoot', report.batchRoot);
    report.validation = validation;
    report.summary.totalItems = numel(batchSpec.items);
    writeJson(fullfile(report.batchRoot, 'batch.json'), sanitizeForJson(batchSpec));
    writeJson(fullfile(report.batchRoot, 'validation.json'), sanitizeForJson(validation));

    if ~isValid
        report.finishedAt = char(datetime('now'));
        writeJson(fullfile(report.batchRoot, 'status.json'), sanitizeForJson(report));
        return;
    end

    [pipe, msg] = resolveBatchPipeline(batchSpec);
    if isempty(pipe)
        report.validation.pipeline.status = 'error';
        report.validation.pipeline.errors{end+1} = msg;
        report.finishedAt = char(datetime('now'));
        writeJson(fullfile(report.batchRoot, 'status.json'), sanitizeForJson(report));
        return;
    end

    total = numel(batchSpec.items);
    report.items = repmat(localEmptyItemReport(), total, 1);
    for i = 1:total
        item = batchSpec.items(i);
        itemReport = localNormalizeRunItemReport(report.validation.items(i));
        if startsWith(lower(char(string(localStringField(item, 'kind')))), 'dataset')
            itemReport.status = 'skipped';
            itemReport.message = 'Dataset item is not supported yet.';
            report.items(i) = itemReport;
            report.summary.skippedItems = report.summary.skippedItems + 1;
            callProgress(opts.ProgressCallback, i, total, 'skipped', itemReport);
            writeJson(fullfile(report.batchRoot, 'status.json'), sanitizeForJson(report));
            continue;
        end

        if ~strcmpi(itemReport.status, 'ok')
            itemReport.status = 'skipped';
            itemReport.message = 'Validation failed.';
            report.items(i) = itemReport;
            report.summary.skippedItems = report.summary.skippedItems + 1;
            callProgress(opts.ProgressCallback, i, total, 'skipped', itemReport);
            writeJson(fullfile(report.batchRoot, 'status.json'), sanitizeForJson(report));
            if logical(opts.StopOnError)
                break;
            end
            continue;
        end

        itemDir = fullfile(report.batchRoot, 'items', localItemFolderName(item, i));
        ensureFolder(itemDir);
        requestFile = fullfile(itemDir, 'request.json');
        writeJson(requestFile, sanitizeForJson(struct('batchId', report.batchId, 'itemIndex', i, 'item', item)));
        callProgress(opts.ProgressCallback, i, total, 'running', itemReport);

        try
            [ctx, itemInfo] = buildPipelineBatchItemCtx(batchSpec, i, 'BatchRoot', report.batchRoot);
            if ~isempty(ctx) && isfield(ctx, 'run') && isstruct(ctx.run)
                ctx.run.batchItemFolder = itemDir;
            end
            t0 = tic;
            if strcmp(executionTarget, 'hub')
                [job, runObj] = submitBatchItemToHub(batchSpec, ctx, opts.HubSettings);
                itemReport.status = 'submitted';
                itemReport.message = 'Submitted to Hub.';
                itemReport.durationSec = toc(t0);
                itemReport.itemInfo = itemInfo;
                itemReport.job = job;
                itemReport.jobId = localStructText(job, 'id');
                if isempty(itemReport.jobId)
                    itemReport.jobId = localStructText(job, 'job_id');
                end
                try
                    itemReport.runPath = fullfile(runObj.path, 'run.json');
                catch
                    itemReport.runPath = '';
                end
            else
                [ctx, runReport] = runPipeline(pipe, ctx);
                itemReport.status = 'done';
                itemReport.message = '';
                itemReport.durationSec = toc(t0);
                itemReport.runReport = runReport;
                itemReport.itemInfo = itemInfo;
                if logical(opts.SaveProjects) && isfield(ctx, 'shallow') && isa(ctx.shallow, 'shallow')
                    try
                        shallowSave(ctx.shallow, 'shallowObj');
                    catch ME
                        itemReport.warnings{end+1} = ['Project save failed: ' ME.message]; %#ok<AGROW>
                    end
                end
            end
            report.summary.doneItems = report.summary.doneItems + 1;
        catch ME
            itemReport.status = 'failed';
            itemReport.message = ME.message;
            itemReport.errorId = ME.identifier;
            report.summary.failedItems = report.summary.failedItems + 1;
            if logical(opts.StopOnError)
                report.items(i) = itemReport;
                callProgress(opts.ProgressCallback, i, total, 'failed', itemReport);
                writeJson(fullfile(report.batchRoot, 'status.json'), sanitizeForJson(report));
                break;
            end
        end

        report.items(i) = itemReport;
        writeJson(fullfile(itemDir, 'status.json'), sanitizeForJson(itemReport));
        writeJson(fullfile(report.batchRoot, 'status.json'), sanitizeForJson(report));
        callProgress(opts.ProgressCallback, i, total, itemReport.status, itemReport);
    end

    report.finishedAt = char(datetime('now'));
    writeJson(fullfile(report.batchRoot, 'status.json'), sanitizeForJson(report));
end

function [job, runObj] = submitBatchItemToHub(batchSpec, ctx, hubSettings)
    if ~isfield(ctx, 'shallow') || isempty(ctx.shallow) || ~isa(ctx.shallow, 'shallow')
        error('runPipelineBatch:MissingHubProject', 'Hub submission requires a loaded shallow project.');
    end
    ref = localPipelineRef(batchSpec, ctx);
    targetRef = localTargetRef(ctx);
    runId = localBatchRunId(batchSpec, ctx);
    runObj = pipelineRunNew(ctx.shallow, ref.id, ref.path, ...
        'RunId', runId, ...
        'Description', 'Batch pipeline run', ...
        'Ctx', ctx, ...
        'Status', 'preflight', ...
        'PipelineRef', ref, ...
        'TargetRef', targetRef);
    pipelineRunSave(runObj);

    hub = hubSettings;
    if isfield(ctx, 'hub') && isstruct(ctx.hub) && ~isempty(fieldnames(ctx.hub))
        hub = ctx.hub;
    elseif isempty(hub) || ~isstruct(hub) || isempty(fieldnames(hub))
        hub = detecdiv_hub_settings_get();
    end

    executionTargetId = '';
    try
        if isfield(ctx.run, 'execution_target_id') && ~isempty(ctx.run.execution_target_id)
            executionTargetId = char(string(ctx.run.execution_target_id));
        elseif isfield(ctx.run, 'executionTargetId') && ~isempty(ctx.run.executionTargetId)
            executionTargetId = char(string(ctx.run.executionTargetId));
        elseif isfield(ctx, 'hub') && isstruct(ctx.hub) && isfield(ctx.hub, 'executionTargetId')
            executionTargetId = char(string(ctx.hub.executionTargetId));
        end
    catch
        executionTargetId = '';
    end

    if isempty(executionTargetId)
        [job, runObj] = detecdiv_hub_submit_pipeline_run(runObj, ctx.shallow, 'hub', hub);
    else
        [job, runObj] = detecdiv_hub_submit_pipeline_run(runObj, ctx.shallow, ...
            'hub', hub, 'ExecutionTargetId', executionTargetId);
    end
end

function target = localExecutionTarget(batchSpec)
    target = 'local';
    try
        if isfield(batchSpec, 'prototypeRuntimeConfig') && isstruct(batchSpec.prototypeRuntimeConfig) && ...
                isfield(batchSpec.prototypeRuntimeConfig, 'run') && isstruct(batchSpec.prototypeRuntimeConfig.run) && ...
                isfield(batchSpec.prototypeRuntimeConfig.run, 'executionTarget') && ...
                ~isempty(batchSpec.prototypeRuntimeConfig.run.executionTarget)
            target = lower(char(string(batchSpec.prototypeRuntimeConfig.run.executionTarget)));
        elseif isfield(batchSpec, 'execution') && isstruct(batchSpec.execution) && ...
                isfield(batchSpec.execution, 'target') && ~isempty(batchSpec.execution.target)
            target = lower(char(string(batchSpec.execution.target)));
        end
    catch
        target = 'local';
    end
    if ~ismember(target, {'local', 'hub'})
        target = 'local';
    end
end

function ref = localPipelineRef(batchSpec, ctx)
    ref = struct('id', 'pipeline', 'path', '', 'version', '');
    if isfield(batchSpec, 'pipelineRef') && isstruct(batchSpec.pipelineRef)
        ref = mergeStructDefaults(ref, batchSpec.pipelineRef);
    end
    if isfield(ctx, 'pipelineRef') && isstruct(ctx.pipelineRef)
        ref = mergeStructDefaults(ref, ctx.pipelineRef);
    end
end

function targetRef = localTargetRef(ctx)
    targetRef = struct('type', 'shallow', 'projectPath', '', 'projectName', '', ...
        'fovIds', [], 'roiIds', {{}}, 'classiPath', '', 'notes', 'batch run');
    if isfield(ctx, 'targetRef') && isstruct(ctx.targetRef)
        targetRef = mergeStructDefaults(targetRef, ctx.targetRef);
    end
end

function runId = localBatchRunId(batchSpec, ctx)
    base = localStringField(batchSpec, 'id');
    itemId = '';
    try
        itemId = char(string(ctx.run.batchItemId));
    catch
    end
    if isempty(base)
        base = 'batch';
    end
    if isempty(itemId)
        itemId = char(string(ctx.run.batchItemIndex));
    end
    runId = matlab.lang.makeValidName(['batch_' base '_' itemId]);
end

function S = mergeStructDefaults(defaults, value)
    S = defaults;
    if isempty(value) || ~isstruct(value)
        return;
    end
    fn = fieldnames(value);
    for i = 1:numel(fn)
        if ~isempty(value.(fn{i}))
            S.(fn{i}) = value.(fn{i});
        end
    end
end

function [pipe, msg] = resolveBatchPipeline(batchSpec)
    msg = '';
    pipe = [];
    if isfield(batchSpec, 'pipelineTemplate') && ~isempty(batchSpec.pipelineTemplate) && ...
            (isstruct(batchSpec.pipelineTemplate) || isobject(batchSpec.pipelineTemplate))
        pipe = batchSpec.pipelineTemplate;
        return;
    end
    if ~isfield(batchSpec, 'pipelineRef') || ~isstruct(batchSpec.pipelineRef) || ...
            ~isfield(batchSpec.pipelineRef, 'path') || isempty(batchSpec.pipelineRef.path)
        msg = 'batchSpec.pipelineRef.path is empty.';
        return;
    end
    [pipe, msg] = pipelineLoad(char(string(batchSpec.pipelineRef.path)));
end

function callProgress(cb, idx, total, state, itemReport)
    if isempty(cb)
        return;
    end
    payload = struct();
    payload.index = idx;
    payload.total = total;
    payload.progress = idx / max(1, total);
    payload.state = char(string(state));
    payload.item = itemReport;
    try
        cb(payload);
    catch
    end
end

function item = localEmptyItemReport()
    item = struct( ...
        'index', 0, ...
        'id', '', ...
        'kind', '', ...
        'name', '', ...
        'sourceMode', '', ...
        'catalogId', '', ...
        'projectMatPath', '', ...
        'datasetId', '', ...
        'status', 'pending', ...
        'message', '', ...
        'pipelineOk', false, ...
        'pipelineErrors', {{}}, ...
        'pipelineWarnings', {{}}, ...
        'warnings', {{}}, ...
        'errors', {{}}, ...
        'durationSec', 0, ...
        'runReport', struct(), ...
        'itemInfo', struct(), ...
        'errorId', '', ...
        'job', struct(), ...
        'jobId', '', ...
        'runPath', '');
end

function item = localNormalizeRunItemReport(in)
    item = localEmptyItemReport();
    if isempty(in) || ~isstruct(in)
        return;
    end
    fn = fieldnames(in);
    for i = 1:numel(fn)
        item.(fn{i}) = in.(fn{i});
    end
end

function name = localItemFolderName(item, idx)
    name = sprintf('%03d_%s', idx, regexprep(lower(char(string(localStringField(item, 'displayName')))), '[^a-z0-9_\\-]+', '_'));
    name = regexprep(name, '_+', '_');
    name = strtrim(name);
    if isempty(name) || strcmp(name, sprintf('%03d_', idx))
        name = sprintf('%03d_item', idx);
    end
end

function txt = localStringField(S, fieldName)
    txt = '';
    if isstruct(S) && isfield(S, fieldName) && ~isempty(S.(fieldName))
        txt = char(string(S.(fieldName)));
    end
end

function txt = localStructText(S, fieldName)
    txt = '';
    try
        if isstruct(S) && isfield(S, fieldName) && ~isempty(S.(fieldName))
            txt = char(string(S.(fieldName)));
        end
    catch
        txt = '';
    end
end

function ensureFolder(pathText)
    if isempty(pathText)
        return;
    end
    if exist(pathText, 'dir') ~= 7
        mkdir(pathText);
    end
end

function writeJson(filePath, data)
    try
        txt = jsonencode(data, 'PrettyPrint', true);
    catch
        txt = jsonencode(data);
    end
    fid = fopen(filePath, 'w');
    if fid < 0
        warning('runPipelineBatch:WriteFailed', 'Unable to write %s', filePath);
        return;
    end
    fwrite(fid, txt, 'char');
    fclose(fid);
end

function out = sanitizeForJson(in)
    if isempty(in)
        out = in;
        return;
    end
    if isstruct(in)
        out = in;
        for k = 1:numel(in)
            fn = fieldnames(in(k));
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
    if isdatetime(in)
        out = char(in);
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
    try
        jsonencode(in);
        out = in;
    catch
        out = struct('className', class(in), 'note', 'value omitted for JSON');
    end
end
