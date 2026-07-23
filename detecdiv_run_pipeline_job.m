function result = detecdiv_run_pipeline_job(jobInput)
% detecdiv_run_pipeline_job  Non-interactive pipeline-run entrypoint for batch workers.
%
% Accepted inputs:
%   - path to a JSON file
%   - struct payload already loaded in MATLAB
%
% The payload is expected to follow the shared pipeline_run contract.

    repoRoot = fileparts(mfilename('fullpath'));
    currentRoot = pwd;
    if exist(fullfile(currentRoot, 'detecdiv_setup_path.m'), 'file') == 2 && ...
            exist(fullfile(currentRoot, 'structure', 'io', 'runPipelineStructured.m'), 'file') == 2
        repoRoot = currentRoot;
    end
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
        classifierScopedRun = localIsClassifierScopedPayload(payload);
        projectMatPath = '';
        shallowObj = [];
        if ~classifierScopedRun
            projectMatPath = localResolveProjectMatPath(payload);
            [shallowObj, msg] = shallowLoad(projectMatPath);
            if isempty(shallowObj)
                error('detecdiv_run_pipeline_job:ProjectLoadFailed', '%s', msg);
            end
            shallowObj = localRelinkRawPaths(shallowObj, payload);
        end

        pipelineInputPath = localResolvePipelineInputPath(payload);
        [pipeObj, msg] = pipelineLoad(pipelineInputPath);
        if isempty(pipeObj)
            error('detecdiv_run_pipeline_job:PipelineLoadFailed', '%s', msg);
        end
        ctx = localBuildExecutionContext(payload, shallowObj, pipeObj);
        if classifierScopedRun
            ctx = localAttachClassifierScopedRuntime(ctx, pipeObj, payload);
        end
        dependencyAudit = pipelineAuditDependencies(pipeObj, 'Mode', 'run', 'Context', ctx);
        runId = char(string(localGetText(payload, {'run_request','run_id'}, '')));
        if isempty(runId)
            if classifierScopedRun
                runId = localSuggestClassifierScopedRunId(pipeObj.strid);
            else
                runId = localSuggestRunId(shallowObj, pipeObj.strid);
            end
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
        [saveOk, saveMsg] = localMaybeSaveProject(shallowObj, payload);
        if ~saveOk
            runObj.status = 'failed';
            pipelineRunSave(runObj);
            error('detecdiv_run_pipeline_job:ProjectSaveFailed', ...
                'Pipeline execution completed, but final project save failed: %s', saveMsg);
        end

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
    candidates = localProjectMatPathCandidates(payload);
    projectMatPath = localFirstExistingPath(candidates);
    if ~isempty(projectMatPath)
        return;
    end
    firstCandidate = '';
    if ~isempty(candidates)
        firstCandidate = candidates{1};
    end
    if isempty(firstCandidate)
        error('detecdiv_run_pipeline_job:MissingProjectPath', ...
            'project_ref.project_mat_path is required for batch execution.');
    end
    error('detecdiv_run_pipeline_job:ProjectMissing', 'Project MAT not found: %s', firstCandidate);
end

function candidates = localProjectMatPathCandidates(payload)
    candidates = {};
    serverProjectPath = localGetText(payload, {'run_request','paths','server_project_path'}, '');
    candidates = localAppendPathCandidate(candidates, serverProjectPath, payload);
    candidates = localAppendPathCandidate(candidates, localGetText(payload, {'project_ref','project_mat_path'}, ''), payload);
    candidates = localAppendPathCandidate(candidates, localGetText(payload, {'run_request','paths','project_path'}, ''), payload);
    candidates = unique(candidates, 'stable');
end

function pathOut = localFirstExistingPath(candidates)
    pathOut = '';
    for i = 1:numel(candidates)
        candidate = char(string(candidates{i}));
        if exist(candidate, 'file') == 2
            pathOut = candidate;
            return;
        end
    end
end

function pipelineInputPath = localResolvePipelineInputPath(payload)
    keys = { ...
        {'pipeline_ref','export_manifest_uri'}; ...
        {'pipeline_ref','pipeline_bundle_uri'}; ...
        {'pipeline_ref','pipeline_json_path'} ...
    };
    candidates = {};
    for i = 1:numel(keys)
        candidates = localAppendPathCandidate(candidates, localGetText(payload, keys{i}, ''), payload);
    end
    if ~localIsClassifierScopedPayload(payload)
        candidates = localAppendPipelineSiblingCandidates(candidates, payload);
    end
    pipelineInputPath = localFirstExistingPath(unique(candidates, 'stable'));
    if isempty(pipelineInputPath)
        error('detecdiv_run_pipeline_job:MissingPipelinePath', ...
            'pipeline_ref.export_manifest_uri, pipeline_bundle_uri, or pipeline_json_path is required.');
    end
end

function candidates = localAppendPipelineSiblingCandidates(candidates, payload)
    projectMatPath = localResolveProjectMatPath(payload);
    projectDir = regexprep(projectMatPath, '\.mat$', '');
    keys = { ...
        {'pipeline_ref','export_manifest_uri'}; ...
        {'pipeline_ref','pipeline_bundle_uri'}; ...
        {'pipeline_ref','pipeline_json_path'} ...
    };
    for i = 1:numel(keys)
        sourcePath = localGetText(payload, keys{i}, '');
        if isempty(sourcePath)
            continue;
        end
        leaf = localPathLeaf(sourcePath);
        if isempty(leaf)
            continue;
        end
        candidates = localAppendPathCandidate(candidates, fullfile(fileparts(projectDir), leaf), payload);
        candidates = localAppendPathCandidate(candidates, fullfile(projectDir, leaf), payload);
    end
end

function candidates = localAppendPathCandidate(candidates, pathText, payload)
    if nargin < 1 || isempty(candidates)
        candidates = {};
    end
    pathText = char(string(pathText));
    if isempty(pathText)
        return;
    end
    candidates{end+1} = pathText; %#ok<AGROW>
    mapped = localApplyPathMappings(pathText, payload);
    if ~isempty(mapped) && ~strcmp(mapped, pathText)
        candidates{end+1} = mapped; %#ok<AGROW>
    end
end

function pathOut = localApplyPathMappings(pathIn, payload)
    pathOut = char(string(pathIn));
    mappings = localGetField(localGetField(localGetField(payload, 'run_request', struct()), 'paths', struct()), 'path_mappings', []);
    if isempty(mappings)
        return;
    end
    if isstruct(mappings)
        mappings = mappings(:)';
    elseif iscell(mappings)
        mappings = [mappings{:}];
    else
        return;
    end
    candidateNorm = strrep(pathOut, '/', '\');
    bestLen = -1;
    bestOut = pathOut;
    for i = 1:numel(mappings)
        localRoot = localGetText(mappings(i), {'localRoot'}, localGetText(mappings(i), {'local_root'}, ''));
        remoteRoot = localGetText(mappings(i), {'remoteRoot'}, localGetText(mappings(i), {'remote_root'}, ''));
        localNorm = regexprep(strrep(localRoot, '/', '\'), '[\\\/]+$', '');
        remoteNorm = regexprep(strrep(remoteRoot, '\', '/'), '[\\\/]+$', '');
        if isempty(localNorm) || isempty(remoteNorm)
            continue;
        end
        if localPathStartsWithRoot(candidateNorm, localNorm) && numel(localNorm) > bestLen
            suffix = candidateNorm(numel(localNorm)+1:end);
            suffix = strrep(suffix, '\', '/');
            bestLen = numel(localNorm);
            bestOut = [remoteNorm suffix];
        end
    end
    pathOut = bestOut;
end

function tf = localPathStartsWithRoot(pathValue, rootValue)
    pathCmp = lower(char(string(pathValue)));
    rootCmp = lower(char(string(rootValue)));
    tf = startsWith(pathCmp, rootCmp);
    if ~tf || numel(pathCmp) == numel(rootCmp) || endsWith(rootCmp, ':')
        return;
    end
    nextChar = pathCmp(numel(rootCmp)+1);
    tf = any(nextChar == ['\' '/']);
end

function leaf = localPathLeaf(pathText)
    parts = regexp(strrep(char(string(pathText)), '\', '/'), '/', 'split');
    if isempty(parts)
        leaf = '';
    else
        leaf = parts{end};
    end
end

function tf = localIsClassifierScopedPayload(payload)
    scope = lower(strtrim(localGetText(payload, {'project_ref','scope'}, ...
        localGetText(payload, {'project_ref','type'}, ''))));
    inputSource = lower(strtrim(localGetText(payload, {'run_request','input_source'}, '')));
    classiPath = localClassifierPathFromPayload(payload);
    tf = ~isempty(classiPath) && (any(strcmp(scope, {'classifier','classi'})) || contains(inputSource, 'classifier'));
end

function classiPath = localClassifierPathFromPayload(payload)
    candidates = { ...
        localGetText(payload, {'run_request','paths','server_classifier_path'}, ''), ...
        localGetText(payload, {'project_ref','classifier_path'}, ''), ...
        localGetText(payload, {'run_request','paths','classifier_path'}, ''), ...
        localGetText(payload, {'project_ref','local_classifier_path'}, '')};
    classiPath = '';
    for i = 1:numel(candidates)
        candidate = localTranslatePathForWorker(candidates{i}, payload);
        if ~isempty(candidate)
            classiPath = candidate;
            return;
        end
    end
end

function ctx = localAttachClassifierScopedRuntime(ctx, pipeObj, payload)
    if isfield(ctx, 'roiList') && ~isempty(ctx.roiList) && isa(ctx.roiList, 'roi')
        return;
    end
    [classiObj, snapPath] = localLoadClassifierForScopedRun(pipeObj, ctx, payload);
    if isempty(classiObj) || ~isa(classiObj, 'classi')
        error('detecdiv_run_pipeline_job:ClassifierScopedLoadFailed', ...
            'Classifier-scoped run could not load the classifier snapshot.');
    end
    rois = classiObj.roi;
    if isempty(rois)
        error('detecdiv_run_pipeline_job:ClassifierScopedNoRoi', ...
            'Classifier-scoped run loaded %s but it contains no ROI.', snapPath);
    end
    idx = [];
    try
        if isfield(ctx, 'sel') && isstruct(ctx.sel) && isfield(ctx.sel, 'rois') && ~isempty(ctx.sel.rois)
            idx = ctx.sel.rois;
        end
    catch
        idx = [];
    end
    if isempty(idx)
        idx = localDefaultClassifierRoiSelection(classiObj, ctx);
    end
    if ~isempty(idx)
        idx = idx(idx >= 1 & idx <= numel(rois));
        rois = rois(idx);
    end
    ctx.roiList = rois;
    ctx.rois = rois;
    if ~isfield(ctx, 'store') || ~isstruct(ctx.store)
        ctx.store = struct();
    end
    ctx.store.classifierScoped = struct( ...
        'snapshot', snapPath, ...
        'classifierPath', classiObj.path, ...
        'roiCount', numel(rois));
    if ~isfield(ctx, 'run') || ~isstruct(ctx.run)
        ctx.run = struct();
    end
    ctx.run.runtimeInventoryMode = 'classifier_snapshot';
end

function [classiObj, snapPath] = localLoadClassifierForScopedRun(pipeObj, ctx, payload)
    classiObj = [];
    snapPath = '';
    refs = localClassifierModuleRefs(pipeObj, ctx, payload);
    for i = 1:numel(refs)
        modulePath = localResolveScopedModulePath(refs(i).modulePath, ctx, payload);
        if isempty(modulePath) || exist(modulePath, 'dir') ~= 7
            continue;
        end
        snapPath = localClassifierSnapshotPath(modulePath, refs(i).moduleId);
        if isempty(snapPath) || exist(snapPath, 'file') ~= 2
            continue;
        end
        try
            [classiObj, ~] = classiLoad(snapPath);
        catch
            classiObj = [];
        end
        if ~isempty(classiObj) && isa(classiObj, 'classi')
            return;
        end
    end
    snapPath = '';
end

function refs = localClassifierModuleRefs(pipeObj, ctx, payload)
    refs = struct('modulePath', {}, 'moduleId', {});
    payloadPath = localClassifierPathFromPayload(payload);
    if ~isempty(payloadPath)
        refs(end+1) = struct('modulePath', payloadPath, 'moduleId', localPathLeaf(payloadPath)); %#ok<AGROW>
    end
    try
        params = localGetField(ctx.run, 'nodeParams', struct());
        refs = [refs localClassifierModuleRefsFromNodeParams(params)]; %#ok<AGROW>
    catch
    end
    try
        nodes = pipeObj.nodes;
        for i = 1:numel(nodes)
            nodeType = lower(strtrim(char(string(localGetField(nodes(i), 'type', '')))));
            if ~strcmp(nodeType, 'classifier')
                continue;
            end
            p = localGetField(nodes(i), 'params', struct());
            modulePath = localGetField(p, 'modulePath', '');
            moduleId = localGetField(p, 'moduleId', '');
            if isempty(modulePath)
                modulePath = localGetText(nodes(i), {'origin','path'}, '');
            end
            if isempty(moduleId)
                moduleId = localGetText(nodes(i), {'origin','id'}, '');
            end
            if ~isempty(modulePath)
                refs(end+1) = struct('modulePath', modulePath, 'moduleId', moduleId); %#ok<AGROW>
            end
        end
    catch
    end
end

function refs = localClassifierModuleRefsFromNodeParams(nodeParams)
    refs = struct('modulePath', {}, 'moduleId', {});
    if isempty(nodeParams)
        return;
    end
    if iscell(nodeParams)
        for i = 1:numel(nodeParams)
            refs = [refs localClassifierModuleRefsFromNodeParams(nodeParams{i})]; %#ok<AGROW>
        end
        return;
    end
    if ~isstruct(nodeParams)
        return;
    end
    if isfield(nodeParams, 'id') && isfield(nodeParams, 'params')
        for i = 1:numel(nodeParams)
            p = nodeParams(i).params;
            if ~isstruct(p) || ~isfield(p, 'modulePath') || isempty(p.modulePath)
                continue;
            end
            refs(end+1) = struct( ...
                'modulePath', p.modulePath, ...
                'moduleId', localGetField(p, 'moduleId', '')); %#ok<AGROW>
        end
        return;
    end
    names = fieldnames(nodeParams);
    for i = 1:numel(names)
        refs = [refs localClassifierModuleRefsFromNodeParams(nodeParams.(names{i}))]; %#ok<AGROW>
    end
end

function modulePath = localResolveScopedModulePath(pathText, ctx, payload)
    modulePath = localTranslatePathForWorker(pathText, payload);
    if isempty(modulePath)
        return;
    end
    if exist(modulePath, 'dir') == 7
        return;
    end
    if localIsAbsolutePath(modulePath)
        return;
    end
    bases = localPipelineBaseDirs(ctx, payload);
    for i = 1:numel(bases)
        candidate = fullfile(bases{i}, modulePath);
        if exist(candidate, 'dir') == 7
            modulePath = candidate;
            return;
        end
    end
end

function bases = localPipelineBaseDirs(ctx, payload)
    bases = {};
    candidates = { ...
        localGetText(payload, {'pipeline_ref','pipeline_json_path'}, ''), ...
        localGetText(payload, {'pipeline_ref','pipeline_bundle_uri'}, ''), ...
        localGetText(payload, {'pipeline_ref','export_manifest_uri'}, '')};
    try
        candidates{end+1} = ctx.pipelineRef.path; %#ok<AGROW>
    catch
    end
    for i = 1:numel(candidates)
        p = localTranslatePathForWorker(candidates{i}, payload);
        if isempty(p)
            continue;
        end
        if exist(p, 'file') == 2
            p = fileparts(p);
        end
        if exist(p, 'dir') == 7
            bases{end+1} = p; %#ok<AGROW>
            if strcmpi(localPathLeaf(p), 'pipeline')
                bases{end+1} = fileparts(p); %#ok<AGROW>
            end
        end
    end
    bases = unique(bases, 'stable');
end

function snapPath = localClassifierSnapshotPath(modulePath, moduleId)
    snapPath = '';
    modulePath = char(string(modulePath));
    moduleId = char(string(moduleId));
    if isempty(moduleId)
        moduleId = localPathLeaf(modulePath);
    end
    candidates = {};
    if ~isempty(moduleId)
        candidates{end+1} = fullfile(modulePath, [moduleId '_classification.mat']); %#ok<AGROW>
    end
    d = dir(fullfile(modulePath, '*_classification.mat'));
    for i = 1:numel(d)
        candidates{end+1} = fullfile(d(i).folder, d(i).name); %#ok<AGROW>
    end
    for i = 1:numel(candidates)
        if exist(candidates{i}, 'file') == 2
            snapPath = candidates{i};
            return;
        end
    end
end

function idx = localDefaultClassifierRoiSelection(classiObj, ctx)
    idx = [];
    intent = '';
    try
        intent = lower(strtrim(char(string(ctx.run.classifierIntent))));
    catch
    end
    try
        if isstruct(classiObj.dataset) && isfield(classiObj.dataset, 'split') && isstruct(classiObj.dataset.split)
            split = classiObj.dataset.split;
            if strcmp(intent, 'train') && isfield(split, 'train')
                idx = localNormalizeSelectionVector(split.train);
            elseif isfield(split, 'test')
                idx = localNormalizeSelectionVector(split.test);
            elseif isfield(split, 'val')
                idx = localNormalizeSelectionVector(split.val);
            end
        end
    catch
        idx = [];
    end
    if isempty(idx)
        idx = 1:numel(classiObj.roi);
    end
end

function tf = localIsAbsolutePath(pathText)
    pathText = char(string(pathText));
    tf = startsWith(pathText, '/') || startsWith(pathText, '\') || ...
        ~isempty(regexp(pathText, '^[A-Za-z]:[\\/]', 'once'));
end

function ctx = localBuildExecutionContext(payload, shallowObj, pipeObj)
    ctx = struct();
    if nargin >= 2 && ~isempty(shallowObj)
        ctx.shallow = shallowObj;
        ctx.shallowObj = shallowObj;
    end
    ctx.allowGUI = false;
    ctx.interactive = false;
    ctx.pipelineRef = struct('id', char(string(pipeObj.strid)), 'path', char(string(pipeObj.path)), 'version', char(string(pipeObj.version)));
    if nargin >= 2 && ~isempty(shallowObj)
        ctx.targetRef = struct( ...
            'type', 'shallow', ...
            'projectPath', fullfile(shallowObj.io.path, shallowObj.io.file), ...
            'projectName', shallowObj.io.file, ...
            'fovIds', [], ...
            'roiIds', {{}}, ...
            'classiPath', '', ...
            'notes', '');
    else
        classiPath = localClassifierPathFromPayload(payload);
        ctx.targetRef = struct( ...
            'type', 'classi', ...
            'projectPath', '', ...
            'projectName', '', ...
            'fovIds', [], ...
            'roiIds', {{}}, ...
            'classiPath', classiPath, ...
            'notes', 'Classifier-scoped Hub pipeline run.');
    end

    if isfield(payload, 'run_request') && isstruct(payload.run_request)
        rr = payload.run_request;
        ctx.run = struct();
        ctx.run.selectedNodes = localNormalizeSelectedNodes(localGetField(rr, 'selected_nodes', {}));
        ctx.run.nodeParams = localNormalizeNodeParams(localGetField(rr, 'node_params', struct('id', {}, 'params', {})), payload);
        intent = localNormalizeRunIntent(localGetText(rr, {'intent'}, localGetText(rr, {'classifier_intent'}, '')));
        if isempty(intent)
            intent = localInferRunIntentFromNodeParams(ctx.run.nodeParams);
        end
        if isempty(intent)
            intent = localInferRunIntentFromPipeline(pipeObj);
        end
        if ~isempty(intent)
            ctx.run.intent = intent;
            ctx.run.classifierIntent = intent;
        end
        ctx.run.runPolicy = localGetText(rr, {'run_policy'}, 'resume');
        inputSource = localGetText(rr, {'input_source'}, localGetText(rr, {'inputSource'}, ''));
        if isfield(rr, 'paths') && isstruct(rr.paths)
            ctx.run.paths = rr.paths;
        end

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
        localValidateInputSourceForSelectedNodes(inputSource, pipeObj, ctx.run.selectedNodes);
        if ~isempty(inputSource)
            ctx.run.inputSource = inputSource;
        end
        availableChannels = localNormalizeStringSelection(localGetField(rr, 'available_channels', {}));
        if ~isempty(availableChannels)
            ctx.channels = availableChannels;
            ctx.run.availableChannels = availableChannels;
        end
        roiChannels = localNormalizeStringSelection(localGetField(rr, 'roi_channels', {}));
        if ~isempty(roiChannels)
            ctx.roiChannels = roiChannels;
        elseif ~isempty(availableChannels)
            ctx.roiChannels = availableChannels;
        end
        masks = localNormalizeStringSelection(localGetField(rr, 'masks', {}));
        if ~isempty(masks)
            ctx.masks = masks;
        end
        dataSeries = localNormalizeStringSelection(localGetField(rr, 'data_series', {}));
        if ~isempty(dataSeries)
            ctx.dataSeries = dataSeries;
            ctx.dataSeriesNames = dataSeries;
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

function intent = localNormalizeRunIntent(value)
    intent = '';
    txt = lower(strtrim(char(string(value))));
    switch txt
        case {'train','training','fit'}
            intent = 'train';
        case {'validate','validation','val','test','evaluate','eval'}
            intent = 'validate';
        case {'infer','inference','classify','classification','predict','prediction'}
            intent = 'infer';
    end
end

function intent = localInferRunIntentFromNodeParams(nodeParams)
    intent = '';
    if isempty(nodeParams) || ~isstruct(nodeParams)
        return;
    end
    for i = 1:numel(nodeParams)
        params = localGetField(nodeParams(i), 'params', struct());
        cand = '';
        if isstruct(params)
            cand = localNormalizeRunIntent(localGetText(params, {'operation'}, localGetText(params, {'intent'}, '')));
        end
        if strcmp(cand, 'train')
            intent = cand;
            return;
        elseif isempty(intent) && ~isempty(cand)
            intent = cand;
        end
    end
end

function intent = localInferRunIntentFromPipeline(pipeObj)
    intent = '';
    try
        nodes = pipeObj.nodes;
    catch
        nodes = [];
    end
    if isempty(nodes)
        return;
    end
    for i = 1:numel(nodes)
        params = localGetField(nodes(i), 'params', struct());
        cand = '';
        if isstruct(params)
            cand = localNormalizeRunIntent(localGetText(params, {'operation'}, localGetText(params, {'intent'}, '')));
        end
        if strcmp(cand, 'train')
            intent = cand;
            return;
        elseif isempty(intent) && ~isempty(cand)
            intent = cand;
        end
    end
end

function localValidateInputSourceForSelectedNodes(inputSource, pipeObj, selectedNodes)
    if isempty(selectedNodes) || ~localIsRawInputSource(inputSource)
        return;
    end
    selectedTypes = localSelectedNodeTypes(pipeObj, selectedNodes);
    if isempty(selectedTypes)
        return;
    end
    if ~any(strcmp(selectedTypes, 'dataloader'))
        error('detecdiv_run_pipeline_job:RawModeWithoutDataloader', ...
            ['Input mode is raw-data/dataloader, but the selected pipeline run does not include a dataloader node. ' ...
             'Switch Input mode to "Read from existing project", or include a dataloader in the selected run.']);
    end
end

function tf = localIsRawInputSource(inputSource)
    txt = lower(strtrim(char(string(inputSource))));
    tf = contains(txt, 'dataloader') || contains(txt, 'raw') || contains(txt, 'pipeline start');
end

function nodeTypes = localSelectedNodeTypes(pipeObj, selectedNodes)
    nodeTypes = {};
    try
        nodes = pipeObj.nodes;
    catch
        nodes = struct([]);
    end
    if isempty(nodes)
        return;
    end
    for i = 1:numel(selectedNodes)
        nodeId = char(string(selectedNodes{i}));
        for j = 1:numel(nodes)
            if strcmp(char(string(localGetField(nodes(j), 'id', ''))), nodeId)
                nodeTypes{end+1} = lower(char(string(localGetField(nodes(j), 'type', '')))); %#ok<AGROW>
                break;
            end
        end
    end
    nodeTypes = unique(nodeTypes, 'stable');
end

function runObj = localEnsureRunObject(shallowObj, pipeObj, ctx, payload, runId)
    if isempty(shallowObj) || ~isa(shallowObj, 'shallow')
        runObj = localEnsureClassifierScopedRunObject(pipeObj, ctx, payload, runId);
        return;
    end
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

function runObj = localEnsureClassifierScopedRunObject(pipeObj, ctx, payload, runId)
    runRoot = localGetText(payload, {'run_request','paths','server_run_path'}, '');
    if isempty(runRoot)
        runRoot = localTranslatePathForWorker(localGetText(payload, {'run_request','paths','run_path'}, ''), payload);
    end
    if isempty(runRoot)
        classiPath = localClassifierPathFromPayload(payload);
        if isempty(classiPath)
            try
                classiPath = ctx.targetRef.classiPath;
            catch
                classiPath = '';
            end
        end
        if isempty(classiPath)
            error('detecdiv_run_pipeline_job:ClassifierRunNoPath', ...
                'Classifier-scoped run requires a classifier path or server_run_path.');
        end
        runRoot = fullfile(classiPath, 'pipeline_runs', runId);
    end
    if exist(runRoot, 'dir') ~= 7
        mkdir(runRoot);
    end
    runObj = pipelineRun('', runId, 1);
    runObj.path = runRoot;
    runObj.templateId = char(string(pipeObj.strid));
    runObj.templatePath = localCanonicalPipelineJsonPath(pipeObj, pipeObj.path);
    runObj.pipelineRef = ctx.pipelineRef;
    runObj.targetRef = ctx.targetRef;
    runObj.projectPath = '';
    runObj.projectName = '';
    runObj.description = localGetText(payload, {'run_request','description'}, 'Classifier-scoped pipeline run.');
    runObj.ctx = ctx;
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

function runId = localSuggestClassifierScopedRunId(templateId)
    runId = [char(string(templateId)) '_run_' char(datetime('now','Format','yyyyMMdd_HHmmss'))];
end

function [ok, msg] = localMaybeSaveProject(shallowObj, payload)
    ok = true;
    msg = '';
    if isempty(shallowObj) || ~isa(shallowObj, 'shallow')
        return;
    end
    saveProject = true;
    saveMode = 'shallowObj';
    try
        if isfield(payload, 'execution') && isstruct(payload.execution) && isfield(payload.execution, 'save_project')
            saveProject = logical(payload.execution.save_project);
        end
        if isfield(payload, 'execution') && isstruct(payload.execution)
            if isfield(payload.execution, 'save_project_mode') && ~isempty(payload.execution.save_project_mode)
                saveMode = char(string(payload.execution.save_project_mode));
            elseif isfield(payload.execution, 'saveProjectMode') && ~isempty(payload.execution.saveProjectMode)
                saveMode = char(string(payload.execution.saveProjectMode));
            end
        end
    catch
    end
    if saveProject
        try
            if any(strcmpi(saveMode, {'full','fullProject','projectAndRois'}))
                shallowSave(shallowObj);
            else
                shallowSave(shallowObj, 'shallowObj');
            end
        catch ME
            ok = false;
            msg = ME.message;
            warning('detecdiv_run_pipeline_job:ProjectSaveFailed', ...
                'Final project save failed after pipeline execution: %s', ME.message);
        end
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
    paths = localGetField(localGetField(payload, 'run_request', struct()), 'paths', struct());
    rawRoots = localAppendStringList(rawRoots, localGetField(paths, 'server_raw_data_path', {}));
    rawRoots = localAppendStringList(rawRoots, localGetField(paths, 'raw_data_path', {}));
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

function nodeParams = localNormalizeNodeParams(value, payload)
    nodeParams = struct('id', {}, 'params', {});
    if nargin < 2
        payload = struct();
    end
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
        nodeParams(end).params = localTranslateValuePathsForWorker(params, payload);
    end
end

function value = localTranslateValuePathsForWorker(value, payload)
    if isstruct(value)
        for i = 1:numel(value)
            names = fieldnames(value(i));
            for j = 1:numel(names)
                value(i).(names{j}) = localTranslateValuePathsForWorker(value(i).(names{j}), payload);
            end
        end
    elseif iscell(value)
        for i = 1:numel(value)
            value{i} = localTranslateValuePathsForWorker(value{i}, payload);
        end
    elseif isstring(value)
        for i = 1:numel(value)
            textValue = char(value(i));
            if localLooksLikePathText(textValue)
                value(i) = string(localTranslatePathForWorker(textValue, payload));
            end
        end
    elseif ischar(value)
        if localLooksLikePathText(value)
            value = localTranslatePathForWorker(value, payload);
        end
    end
end

function tf = localLooksLikePathText(value)
    value = char(string(value));
    tf = ~isempty(regexp(value, '^[A-Za-z]:[\\/]', 'once')) || ...
        startsWith(value, '\') || startsWith(value, '/') || ...
        contains(value, '\') || contains(value, '/');
end

function pathOut = localTranslatePathForWorker(pathIn, payload)
    pathOut = localApplyPathMappings(pathIn, payload);
    if ~strcmp(pathOut, char(string(pathIn)))
        return;
    end

    rawRoots = localRawRootCandidates(payload);
    leaf = localPathLeaf(pathIn);
    if isempty(leaf)
        return;
    end
    for i = 1:numel(rawRoots)
        candidate = char(string(rawRoots{i}));
        if isempty(candidate) || exist(candidate, 'dir') ~= 7
            continue;
        end
        if strcmpi(localPathLeaf(candidate), leaf)
            pathOut = candidate;
            return;
        end
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
    persistent doneRoot;
    repoRoot = char(string(repoRoot));
    if ~isempty(doneRoot) && strcmpi(doneRoot, repoRoot)
        return;
    end

    restoredefaultpath();
    rehash toolboxcache;
    addpath(repoRoot, '-begin');

    setupFun = fullfile(repoRoot, 'detecdiv_setup_path.m');
    if exist(setupFun, 'file') == 2
        detecdiv_setup_path(repoRoot, 'ResetPath', true, 'Verbose', true);
    else
        runtimeDirs = {repoRoot, fullfile(repoRoot, 'structure'), ...
            fullfile(repoRoot, 'helpers'), fullfile(repoRoot, 'engine')};
        keep = {};
        for i = 1:numel(runtimeDirs)
            if exist(runtimeDirs{i}, 'dir') ~= 7
                continue;
            end
            rawPaths = regexp(genpath(runtimeDirs{i}), pathsep, 'split');
            for j = 1:numel(rawPaths)
                p = rawPaths{j};
                if isempty(p) || exist(p, 'dir') ~= 7 || localIsForbiddenRuntimePath(p)
                    continue;
                end
                keep{end+1} = p; %#ok<AGROW>
            end
        end
        if ~isempty(keep)
            addpath(keep{:}, '-begin');
        end
    end

    rehash;
    localAssertFunctionFromRepo('runPipelineStructured', repoRoot, true);
    localAssertFunctionFromRepo('pipelineRunSave', repoRoot, true);
    if exist(fullfile(repoRoot, 'engine', 'classification', '+sam31', 'train.m'), 'file') == 2
        localAssertFunctionFromRepo('sam31.train', repoRoot, true);
    end
    fprintf('[detecdiv_run_pipeline_job] repoRoot: %s\n', repoRoot);
    fprintf('[detecdiv_run_pipeline_job] runPipelineStructured: %s\n', which('runPipelineStructured'));
    fprintf('[detecdiv_run_pipeline_job] sam31.train: %s\n', which('sam31.train'));
    doneRoot = repoRoot;
end

function tf = localIsForbiddenRuntimePath(pathStr)
    p = lower(strrep(char(string(pathStr)), '/', filesep));
    parts = regexp(p, ['\' filesep '+'], 'split');
    forbidden = {'.git', '.github', '.vs', '.idea', '.codex_transfer_tmp', ...
        '.codex_deploy_backup', 'backups', 'detecdiv_deploy_backups', ...
        'doc', 'catalog', '__pycache__'};
    tf = any(ismember(parts, forbidden));
end

function localAssertFunctionFromRepo(funName, repoRoot, required)
    resolved = which(funName);
    if isempty(resolved)
        if required
            error('detecdiv_run_pipeline_job:RuntimeFunctionMissing', ...
                'Required runtime function is not on the MATLAB path: %s', funName);
        end
        return;
    end
    resolvedNorm = localNormalizePathForRuntime(resolved);
    repoNorm = localNormalizePathForRuntime(repoRoot);
    if ~startsWith(resolvedNorm, [repoNorm '/']) && ~strcmp(resolvedNorm, repoNorm)
        error('detecdiv_run_pipeline_job:RuntimeFunctionOutsideRepo', ...
            'Runtime function %s resolves outside repo root.%sResolved: %s%sRepo: %s', ...
            funName, newline, resolved, newline, repoRoot);
    end
    if localIsForbiddenRuntimePath(resolved)
        error('detecdiv_run_pipeline_job:RuntimeFunctionFromForbiddenPath', ...
            'Runtime function %s resolves from a forbidden backup/cache path: %s', ...
            funName, resolved);
    end
end

function out = localNormalizePathForRuntime(pathStr)
    out = char(string(pathStr));
    out = strrep(out, '\', '/');
    out = regexprep(out, '/+', '/');
    if numel(out) > 1 && endsWith(out, '/')
        out = extractBefore(out, strlength(out));
    end
    out = lower(out);
end
