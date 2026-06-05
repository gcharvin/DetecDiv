function result = detecdiv_run_pipeline_job(jobInput)
% detecdiv_run_pipeline_job  Non-interactive pipeline-run entrypoint for batch workers.
%
% Accepted inputs:
%   - path to a JSON file
%   - struct payload already loaded in MATLAB
%
% The payload is expected to follow the shared pipeline_run contract.

    repoRoot = fileparts(mfilename('fullpath'));
    localAddRepoPaths(repoRoot);

    payload = localLoadPayload(jobInput);
    payload = localNormalizePayload(payload);

    result = struct( ...
        'status', 'failed', ...
        'job_id', localGetText(payload, {'job_id'}, ''), ...
        'run_id', '', ...
        'project_mat_path', '', ...
        'pipeline_json_path', '', ...
        'run_json_path', '', ...
        'artifacts', struct('kind', {}, 'path', {}), ...
        'summary', struct(), ...
        'error', '');

    resultPath = localGetText(payload, {'execution','result_json_path'}, '');

    try
        projectMatPath = localResolveProjectMatPath(payload);
        [shallowObj, msg] = shallowLoad(projectMatPath);
        if isempty(shallowObj)
            error('detecdiv_run_pipeline_job:ProjectLoadFailed', '%s', msg);
        end
        shallowObj = localRelinkRawPaths(shallowObj, payload);

        pipelineInputPath = localResolvePipelineInputPath(payload);
        [pipeObj, msg] = pipelineLoad(pipelineInputPath);
        if isempty(pipeObj)
            error('detecdiv_run_pipeline_job:PipelineLoadFailed', '%s', msg);
        end
        dependencyAudit = pipelineAuditDependencies(pipeObj, 'Mode', 'run');

        ctx = localBuildExecutionContext(payload, shallowObj, pipeObj);
        runId = char(string(localGetText(payload, {'run_request','run_id'}, '')));
        if isempty(runId)
            runId = localSuggestRunId(shallowObj, pipeObj.strid);
        end
        ctx.runId = runId;
        if ~isfield(ctx, 'run') || ~isstruct(ctx.run)
            ctx.run = struct();
        end
        ctx.run.runId = runId;

        runObj = localEnsureRunObject(shallowObj, pipeObj, ctx, payload, runId);
        runObj.status = 'running';
        runObj.ctx = ctx;
        pipelineRunSave(runObj);
        ctx = runObj.ctx;

        [ctxOut, report] = runPipelineDetecDiv(pipeObj, ctx);
        runObj.ctx = ctxOut;
        runObj.outputs = struct('report', report);
        runObj.progress = struct();
        runObj.status = 'done';
        pipelineRunSave(runObj);
        localMaybeSaveProject(shallowObj, payload);

        result.status = 'done';
        result.run_id = runObj.runId;
        result.project_mat_path = projectMatPath;
        result.pipeline_json_path = localCanonicalPipelineJsonPath(pipeObj, pipelineInputPath);
        result.run_json_path = fullfile(runObj.path, 'run.json');
        result.artifacts = localBuildArtifacts(result.run_json_path);
        result.summary = localBuildResultSummary(pipeObj, report, ctxOut);
        result.dependency_audit = dependencyAudit;
    catch ME
        try
            report = getappdata(0, 'DetecDivLastPipelineReport');
        catch
            report = struct();
        end

        isCancelled = strcmp(ME.identifier, 'runPipeline:Cancelled') ...
            || contains(lower(ME.message), 'cancelled by user') ...
            || contains(lower(ME.message), 'canceled by user');

        try
            if exist('runObj', 'var') && ~isempty(runObj)
                if isCancelled
                    runObj.status = 'cancelled';
                else
                    runObj.status = 'failed';
                end
                if exist('ctxOut', 'var') && ~isempty(ctxOut)
                    runObj.ctx = ctxOut;
                elseif exist('ctx', 'var') && ~isempty(ctx)
                    runObj.ctx = ctx;
                end
                if isstruct(report) && ~isempty(fieldnames(report))
                    runObj.outputs = struct('report', report);
                end
                pipelineRunSave(runObj);
                if exist('shallowObj', 'var') && ~isempty(shallowObj)
                    localMaybeSaveProject(shallowObj, payload);
                end
                result.run_id = char(string(runObj.runId));
                result.run_json_path = fullfile(runObj.path, 'run.json');
                result.artifacts = localBuildArtifacts(result.run_json_path);
            end
        catch
        end

        try
            if exist('projectMatPath', 'var') && ~isempty(projectMatPath)
                result.project_mat_path = projectMatPath;
            end
        catch
        end
        try
            if exist('pipeObj', 'var') && ~isempty(pipeObj)
                result.pipeline_json_path = localCanonicalPipelineJsonPath(pipeObj, pipelineInputPath);
            elseif exist('pipelineInputPath', 'var') && ~isempty(pipelineInputPath)
                result.pipeline_json_path = char(string(pipelineInputPath));
            end
        catch
        end

        if isCancelled
            result.status = 'cancelled';
        else
            result.status = 'failed';
        end
        if exist('dependencyAudit', 'var') && ~isempty(dependencyAudit)
            result.dependency_audit = dependencyAudit;
        end
        result.error = getReport(ME, 'extended', 'hyperlinks', 'off');
        result.summary = localBuildFailureSummary(report);
        localWriteResultIfRequested(resultPath, result);
        fprintf(2, '%s\n', result.error);
        error('detecdiv_run_pipeline_job:ExecutionFailed', '%s', ME.message);
    end

    localWriteResultIfRequested(resultPath, result);
    fprintf('PIPELINE_RUN_RESULT_JSON %s\n', char(string(resultPath)));
end

function payload = localLoadPayload(jobInput)
    if nargin < 1 || isempty(jobInput)
        error('detecdiv_run_pipeline_job:MissingInput', 'A payload struct or JSON path is required.');
    end

    if isstruct(jobInput)
        payload = jobInput;
        return;
    end

    jobPath = char(string(jobInput));
    if exist(jobPath, 'file') ~= 2
        error('detecdiv_run_pipeline_job:MissingJson', 'Payload JSON not found: %s', jobPath);
    end
    payload = jsondecode(fileread(jobPath));
end

function payload = localNormalizePayload(payload)
    if isstruct(payload) && isfield(payload, 'params_json') && isstruct(payload.params_json)
        merged = payload.params_json;
        if ~isfield(merged, 'job_id') && isfield(payload, 'id')
            merged.job_id = char(string(payload.id));
        end
        if ~isfield(merged, 'project_ref') && isfield(payload, 'project_id') && ~isempty(payload.project_id)
            merged.project_ref = struct('project_id', char(string(payload.project_id)));
        end
        if ~isfield(merged, 'pipeline_ref') && isfield(payload, 'pipeline_id') && ~isempty(payload.pipeline_id)
            merged.pipeline_ref = struct('pipeline_id', char(string(payload.pipeline_id)));
        end
        if ~isfield(merged, 'execution')
            merged.execution = struct();
        end
        if ~isfield(merged.execution, 'requested_mode') && isfield(payload, 'requested_mode')
            merged.execution.requested_mode = char(string(payload.requested_mode));
        end
        if ~isfield(merged.execution, 'execution_target_id') && isfield(payload, 'execution_target_id') && ~isempty(payload.execution_target_id)
            merged.execution.execution_target_id = char(string(payload.execution_target_id));
        end
        payload = merged;
    end

    if ~isfield(payload, 'job_kind') || isempty(payload.job_kind)
        payload.job_kind = 'pipeline_run';
    end
    if ~strcmpi(char(string(payload.job_kind)), 'pipeline_run')
        error('detecdiv_run_pipeline_job:InvalidJobKind', 'Expected job_kind=pipeline_run.');
    end
end

function projectMatPath = localResolveProjectMatPath(payload)
    projectMatPath = localGetText(payload, {'project_ref','project_mat_path'}, '');
    if isempty(projectMatPath)
        error('detecdiv_run_pipeline_job:MissingProjectPath', ...
            'project_ref.project_mat_path is required for batch execution.');
    end
    if exist(projectMatPath, 'file') ~= 2
        error('detecdiv_run_pipeline_job:ProjectMissing', 'Project MAT not found: %s', projectMatPath);
    end
end

function pipelineInputPath = localResolvePipelineInputPath(payload)
    keys = { ...
        {'pipeline_ref','export_manifest_uri'}; ...
        {'pipeline_ref','pipeline_bundle_uri'}; ...
        {'pipeline_ref','pipeline_json_path'} ...
    };
    pipelineInputPath = '';
    for i = 1:numel(keys)
        pipelineInputPath = localGetText(payload, keys{i}, '');
        if ~isempty(pipelineInputPath)
            break;
        end
    end
    if isempty(pipelineInputPath)
        error('detecdiv_run_pipeline_job:MissingPipelinePath', ...
            'pipeline_ref.export_manifest_uri, pipeline_bundle_uri, or pipeline_json_path is required.');
    end
end

function ctx = localBuildExecutionContext(payload, shallowObj, pipeObj)
    ctx = struct();
    ctx.shallow = shallowObj;
    ctx.shallowObj = shallowObj;
    ctx.allowGUI = false;
    ctx.interactive = false;
    ctx.pipelineRef = struct('id', char(string(pipeObj.strid)), 'path', char(string(pipeObj.path)), 'version', char(string(pipeObj.version)));
    ctx.targetRef = struct( ...
        'type', 'shallow', ...
        'projectPath', fullfile(shallowObj.io.path, shallowObj.io.file), ...
        'projectName', shallowObj.io.file, ...
        'fovIds', [], ...
        'roiIds', {{}}, ...
        'classiPath', '', ...
        'notes', '');

    if isfield(payload, 'run_request') && isstruct(payload.run_request)
        rr = payload.run_request;
        ctx.run = struct();
        ctx.run.selectedNodes = localNormalizeSelectedNodes(localGetField(rr, 'selected_nodes', {}));
        ctx.run.nodeParams = localNormalizeNodeParams(localGetField(rr, 'node_params', struct('id', {}, 'params', {})));
        ctx.run.runPolicy = localGetText(rr, {'run_policy'}, 'resume');

        ctx.io = struct();
        ctx.io.globalExistingPolicy = localGetText(rr, {'existing_data_policy'}, '');
        ctx.io.existingPolicy = ctx.io.globalExistingPolicy;
        ctx.io.cachePolicy = localGetText(rr, {'roi_cache_policy'}, 'auto');

        if isfield(rr, 'selection') && isstruct(rr.selection)
            ctx.sel = struct();
            ctx.sel.fovs = localNormalizeSelectionVector(localGetField(rr.selection, 'fovs', []));
            ctx.sel.frames = localNormalizeSelectionVector(localGetField(rr.selection, 'frames', []));
            ctx.sel.rois = localNormalizeSelectionVector(localGetField(rr.selection, 'rois', []));
            ctx.sel.channels = localNormalizeStringSelection(localGetField(rr.selection, 'channels', {}));
        end
        if isfield(rr, 'control') && isstruct(rr.control)
            ctx.run.control = rr.control;
        end

        if isfield(rr, 'python') && isstruct(rr.python)
            ctx.exec.python = rr.python;
        end
        if isfield(rr, 'gpu') && isstruct(rr.gpu)
            gpuMode = localGetText(rr, {'gpu','mode'}, '');
            if ~isempty(gpuMode)
                ctx.run.gpuPolicy = gpuMode;
            end
        end

        descr = localGetText(rr, {'description'}, '');
        if ~isempty(descr)
            ctx.run.description = descr;
        end
    end

    if isfield(payload, 'execution') && isstruct(payload.execution)
        if isfield(payload.execution, 'allow_gui')
            ctx.allowGUI = logical(payload.execution.allow_gui);
        end
        if isfield(payload.execution, 'interactive')
            ctx.interactive = logical(payload.execution.interactive);
        end
        if isfield(payload.execution, 'dry_run') && logical(payload.execution.dry_run)
            ctx.dryRun = true;
        end
        cancelTokenFile = localGetText(payload, {'execution','cancel_token_file'}, '');
        if ~isempty(cancelTokenFile)
            ctx.cancel = struct('tokenFile', cancelTokenFile);
        end
    end
end

function runObj = localEnsureRunObject(shallowObj, pipeObj, ctx, payload, runId)
    existingIdx = [];
    try
        if isfield(shallowObj.processing, 'pipelineRun') && ~isempty(shallowObj.processing.pipelineRun)
            names = arrayfun(@(r) char(string(r.runId)), shallowObj.processing.pipelineRun, 'UniformOutput', false);
            existingIdx = find(strcmp(names, char(string(runId))), 1, 'first');
        end
    catch
        existingIdx = [];
    end

    descr = localGetText(payload, {'run_request','description'}, '');
    if isempty(existingIdx)
        runObj = pipelineRunNew(shallowObj, pipeObj.strid, localCanonicalPipelineJsonPath(pipeObj, pipeObj.path), ...
            'runId', runId, ...
            'description', descr, ...
            'ctx', ctx, ...
            'status', 'new');
    else
        runObj = shallowObj.processing.pipelineRun(existingIdx);
        runObj.templateId = char(string(pipeObj.strid));
        runObj.templatePath = localCanonicalPipelineJsonPath(pipeObj, pipeObj.path);
        runObj.pipelineRef = ctx.pipelineRef;
        runObj.targetRef = ctx.targetRef;
        runObj.description = descr;
        runObj.ctx = ctx;
    end
end

function runId = localSuggestRunId(shallowObj, templateId)
    runId = [char(string(templateId)) '_run_1'];
    try
        if ~isfield(shallowObj.processing, 'pipelineRun') || isempty(shallowObj.processing.pipelineRun)
            return;
        end
        names = arrayfun(@(r) char(string(r.runId)), shallowObj.processing.pipelineRun, 'UniformOutput', false);
        n = 1;
        while any(strcmp(names, [char(string(templateId)) '_run_' num2str(n)]))
            n = n + 1;
        end
        runId = [char(string(templateId)) '_run_' num2str(n)];
    catch
    end
end

function localMaybeSaveProject(shallowObj, payload)
    saveProject = true;
    try
        if isfield(payload, 'execution') && isstruct(payload.execution) && isfield(payload.execution, 'save_project')
            saveProject = logical(payload.execution.save_project);
        end
    catch
    end
    if saveProject
        shallowSave(shallowObj);
    end
end

function shallowObj = localRelinkRawPaths(shallowObj, payload)
    rawRoots = localRawRootCandidates(payload);
    if isempty(rawRoots)
        return;
    end

    for i = 1:numel(rawRoots)
        rawRoot = char(string(rawRoots{i}));
        if isempty(rawRoot) || exist(rawRoot, 'dir') ~= 7
            continue;
        end

        try
            [shallowObj, report] = detecdiv_paths_relink_project(shallowObj, rawRoot, 'Debug', false);
            okCount = localReportOkCount(report);
            fprintf('[pipeline-job] Raw path relink candidate %s: %d/%d entries ready.\n', ...
                rawRoot, okCount, numel(report));
            if okCount == numel(report) && ~isempty(report)
                return;
            end
        catch ME
            fprintf('[pipeline-job] Raw path relink skipped for %s: %s\n', rawRoot, ME.message);
        end
    end
end

function rawRoots = localRawRootCandidates(payload)
    rawRoots = {};
    rawRoots = localAppendStringList(rawRoots, localGetField(localGetField(payload, 'project_ref', struct()), 'raw_root_candidates', {}));
    rawRoots = localAppendStringList(rawRoots, localGetField(localGetField(payload, 'project_ref', struct()), 'raw_root', {}));
    rawRoots = localAppendStringList(rawRoots, localGetField(localGetField(payload, 'execution', struct()), 'raw_root_candidates', {}));
    rawRoots = localAppendStringList(rawRoots, localGetField(localGetField(payload, 'execution', struct()), 'raw_root', {}));
    projectMatPath = localGetText(payload, {'project_ref','project_mat_path'}, '');
    if ~isempty(projectMatPath) && exist('detecdiv_paths_infer_raw_roots', 'file') == 2
        try
            rawRoots = localAppendStringList(rawRoots, detecdiv_paths_infer_raw_roots(projectMatPath));
        catch ME
            fprintf('[pipeline-job] Raw root inference skipped for %s: %s\n', projectMatPath, ME.message);
        end
    end
    rawRoots = unique(rawRoots, 'stable');
end

function out = localAppendStringList(out, value)
    if nargin < 1 || isempty(out)
        out = {};
    end
    if isempty(value)
        return;
    end
    if iscell(value)
        for i = 1:numel(value)
            out = localAppendStringList(out, value{i});
        end
        return;
    end
    if isstring(value)
        for i = 1:numel(value)
            txt = char(value(i));
            if ~isempty(txt)
                out{end+1} = txt; %#ok<AGROW>
            end
        end
        return;
    end
    if ischar(value)
        out{end+1} = value; %#ok<AGROW>
    end
end

function okCount = localReportOkCount(report)
    okCount = 0;
    try
        if isstruct(report) && isfield(report, 'ok')
            okCount = sum([report.ok]);
        end
    catch
        okCount = 0;
    end
end

function summary = localBuildResultSummary(pipeObj, report, ctxOut)
    summary = struct();
    try
        summary.node_count = numel(pipeObj.nodes);
    catch
        summary.node_count = 0;
    end
    try
        summary.selected_node_count = numel(localGetField(ctxOut.run, 'selectedNodes', {}));
    catch
        summary.selected_node_count = 0;
    end
    try
        summary.report_summary = localGetField(report, 'summary', struct());
    catch
        summary.report_summary = struct();
    end
end

function summary = localBuildFailureSummary(report)
    summary = struct();
    if isstruct(report) && ~isempty(fieldnames(report))
        summary.report_summary = localGetField(report, 'summary', struct());
    end
end

function artifacts = localBuildArtifacts(runJsonPath)
    artifacts = struct('kind', {}, 'path', {});
    if nargin < 1 || isempty(runJsonPath)
        return;
    end
    if exist(runJsonPath, 'file') == 2
        artifacts(1).kind = 'run_json';
        artifacts(1).path = char(string(runJsonPath));
        runDir = fileparts(runJsonPath);
        summaryPath = fullfile(runDir, 'run_summary.txt');
        if exist(summaryPath, 'file') == 2
            artifacts(2).kind = 'run_summary';
            artifacts(2).path = summaryPath;
        end
        logPath = fullfile(runDir, 'run_log.txt');
        if exist(logPath, 'file') == 2
            artifacts(end+1).kind = 'run_log';
            artifacts(end).path = logPath;
        end
        eventPath = fullfile(runDir, 'run_events.jsonl');
        if exist(eventPath, 'file') == 2
            artifacts(end+1).kind = 'run_events';
            artifacts(end).path = eventPath;
        end
    end
end

function jsonPath = localCanonicalPipelineJsonPath(pipeObj, pipelineInputPath)
    jsonPath = '';
    try
        if isa(pipeObj, 'pipeline') && ~isempty(pipeObj.path)
            candidate = fullfile(pipeObj.path, 'pipeline.json');
            if exist(candidate, 'file') == 2
                jsonPath = candidate;
                return;
            end
        end
    catch
    end
    jsonPath = char(string(pipelineInputPath));
end

function selectedNodes = localNormalizeSelectedNodes(value)
    if isempty(value)
        selectedNodes = {};
        return;
    end
    if ischar(value) || isstring(value)
        selectedNodes = {char(string(value))};
        return;
    end
    if iscell(value)
        selectedNodes = cellfun(@(v) char(string(v)), value(:), 'UniformOutput', false);
        return;
    end
    selectedNodes = {};
end

function nodeParams = localNormalizeNodeParams(value)
    nodeParams = struct('id', {}, 'params', {});
    if isempty(value)
        return;
    end
    if ~isstruct(value)
        return;
    end
    for i = 1:numel(value)
        nodeParams(end+1).id = char(string(localGetField(value(i), 'id', ''))); %#ok<AGROW>
        params = localGetField(value(i), 'params', struct());
        if isempty(params) || ~isstruct(params)
            params = struct();
        end
        nodeParams(end).params = params;
    end
end

function v = localNormalizeSelectionVector(v)
    if isempty(v)
        v = [];
        return;
    end
    if ischar(v) || isstring(v)
        try
            vv = str2num(char(string(v))); %#ok<ST2NM>
            if isnumeric(vv)
                v = vv;
            else
                v = [];
            end
        catch
            v = [];
        end
        return;
    end
    if ~isnumeric(v)
        v = [];
    end
end

function v = localNormalizeStringSelection(v)
    if isempty(v)
        v = {};
        return;
    end
    if ischar(v) || isstring(v)
        v = {char(string(v))};
        return;
    end
    if iscell(v)
        v = cellfun(@(x) char(string(x)), v(:), 'UniformOutput', false);
        return;
    end
    v = {};
end

function txt = localGetText(S, pathParts, defaultVal)
    if nargin < 3
        defaultVal = '';
    end
    txt = defaultVal;
    try
        cur = S;
        for i = 1:numel(pathParts)
            if ~isstruct(cur) || ~isfield(cur, pathParts{i})
                return;
            end
            cur = cur.(pathParts{i});
        end
        if isempty(cur)
            return;
        end
        txt = char(string(cur));
    catch
        txt = defaultVal;
    end
end

function v = localGetField(S, fieldName, defaultVal)
    v = defaultVal;
    try
        if isstruct(S) && isfield(S, fieldName)
            v = S.(fieldName);
        end
    catch
    end
end

function localWriteResultIfRequested(resultPath, result)
    if nargin < 1 || isempty(resultPath)
        return;
    end
    try
        [resultDir, ~, ~] = fileparts(resultPath);
        if ~isempty(resultDir) && exist(resultDir, 'dir') ~= 7
            mkdir(resultDir);
        end
        txt = jsonencode(result, 'PrettyPrint', true);
    catch
        txt = jsonencode(result);
    end
    fid = fopen(resultPath, 'w');
    if fid < 0
        return;
    end
    fwrite(fid, txt, 'char');
    fclose(fid);
end

function localAddRepoPaths(repoRoot)
    persistent done;
    if ~isempty(done) && done
        return;
    end
    rawPaths = regexp(genpath(repoRoot), pathsep, 'split');
    keep = {};
    for i = 1:numel(rawPaths)
        p = rawPaths{i};
        if isempty(p)
            continue;
        end
        normp = lower(strrep(p, '/', '\'));
        if contains(normp, [filesep '.git']) || contains(normp, [filesep 'backups']) || contains(normp, [filesep 'doc'])
            continue;
        end
        keep{end+1} = p; %#ok<AGROW>
    end
    if ~isempty(keep)
        addpath(keep{:});
    end
    done = true;
end
