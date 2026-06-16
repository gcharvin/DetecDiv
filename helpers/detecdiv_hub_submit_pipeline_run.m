function [job, runObj] = detecdiv_hub_submit_pipeline_run(runObj, shallowObj, varargin)
% detecdiv_hub_submit_pipeline_run  Submit an existing pipelineRun to detecdiv-hub.

    if nargin < 1 || isempty(runObj) || ~localIsClass(runObj, 'pipelineRun')
        error('detecdiv_hub_submit_pipeline_run:MissingRun', 'A pipelineRun object is required.');
    end
    if nargin < 2
        shallowObj = [];
    end
    projectArgClass = localClassName(shallowObj);
    shallowObj = localResolveShallowProject(runObj, shallowObj);
    if isempty(shallowObj)
        error('detecdiv_hub_submit_pipeline_run:MissingProject', ...
            'A shallow project is required. Received project argument class: %s.', projectArgClass);
    end

    opts = localRunStage('parse options', @() localParse(varargin{:}));
    ref = localRunStage('resolve hub project reference', @() detecdiv_hub_project_ref(shallowObj, opts.hub));
    if isempty(ref.project_id)
        [shallowObj, ref, ensureStatus] = localRunStage('ensure hub project registration', ...
            @() detecdiv_hub_ensure_project(shallowObj, 'Hub', opts.hub, ...
                'ErrorIfQueued', false, ...
                'InitialWaitSec', opts.projectResolveInitialWaitSec, ...
                'ResolveAttempts', opts.projectResolveAttempts, ...
                'ResolveIntervalSec', opts.projectResolveIntervalSec));
        if ~isempty(ref.project_id)
            if opts.saveProject
                localRunStageNoOutput('save project after hub registration check', @() localSaveProject(shallowObj, opts.hub));
            end
        end
        if isempty(ref.project_id)
            msg = ['This project is not registered in the Hub project catalogue, ' ...
                'and direct project registration failed.' newline ...
                char(string(ensureStatus.message)) newline ...
                'No broad project-root indexing job was queued.'];
            error('detecdiv_hub_submit_pipeline_run:ProjectRegistrationFailed', '%s', msg);
        end
    else
        [shallowObj, ref] = localRunStage('store resolved hub project reference', ...
            @() detecdiv_hub_ensure_project(shallowObj, 'Hub', opts.hub, 'ResolveAttempts', 1));
        if opts.saveProject
            localRunStageNoOutput('save project after hub project resolution', @() localSaveProject(shallowObj, opts.hub));
        end
    end

    payload = struct();
    payload.project_id = ref.project_id;
    payload.requested_mode = opts.requestedMode;
    payload.priority = opts.priority;
    payload.requested_by = opts.requestedBy;
    payload.requested_from_host = localRunStage('resolve local host name', @() localHostName());
    payload.project_ref = localRunStage('build project reference payload', @() localBuildProjectRef(ref, opts.hub));
    payload.pipeline_ref = localRunStage('build pipeline reference payload', @() localBuildPipelineRef(runObj, ref, opts.hub, shallowObj));
    payload.run_request = localRunStage('build run request payload', @() localBuildRunRequest(runObj, opts.hub, ref));
    payload.execution = localRunStage('build execution payload', @() localBuildExecution(opts));

    localRunStageNoOutput('release local hub edit lease', @() detecdiv_hub_release_project_open(shallowObj, opts.hub));
    job = localRunStage('POST /pipeline-runs', @() detecdiv_hub_request('POST', '/pipeline-runs', payload, opts.hub));
    runObj = localRunStage('attach hub job to pipelineRun', @() localAttachHubJob(runObj, job, ref));
    localRunStageNoOutput('save pipelineRun after hub submit', @() localSavePipelineRun(runObj));
end

function tf = localIsClass(value, className)
    tf = false;
    try
        tf = isa(value, className);
    catch
        tf = false;
    end
end

function shallowObj = localResolveShallowProject(runObj, candidate)
    shallowObj = [];
    if localIsClass(candidate, 'shallow')
        shallowObj = candidate;
        return;
    end

    shallowObj = localFindProjectInBaseWorkspace(runObj);
end

function shallowObj = localFindProjectInBaseWorkspace(runObj)
    shallowObj = [];
    try
        names = evalin('base', 'who');
    catch
        names = {};
    end
    for i = 1:numel(names)
        try
            candidate = evalin('base', names{i});
            if ~localIsClass(candidate, 'shallow')
                continue;
            end
            if localProjectContainsRun(candidate, runObj)
                shallowObj = candidate;
                return;
            end
        catch
        end
    end
end

function tf = localProjectContainsRun(shallowObj, runObj)
    tf = false;
    try
        if ~isfield(shallowObj.processing, 'pipelineRun') || isempty(shallowObj.processing.pipelineRun)
            return;
        end
        runs = shallowObj.processing.pipelineRun;
        for i = 1:numel(runs)
            try
                if runs(i) == runObj
                    tf = true;
                    return;
                end
            catch
            end
            try
                if strcmp(char(string(runs(i).runId)), char(string(runObj.runId)))
                    tf = true;
                    return;
                end
            catch
            end
        end
    catch
    end
end

function name = localClassName(value)
    name = '<empty>';
    try
        if ~isempty(value)
            name = class(value);
        end
    catch
        name = '<unknown>';
    end
end

function varargout = localRunStage(stageName, fn)
    try
        [varargout{1:nargout}] = fn();
    catch ME
        throwAsCaller(localWrapStageError(stageName, ME));
    end
end

function localRunStageNoOutput(stageName, fn)
    try
        fn();
    catch ME
        throwAsCaller(localWrapStageError(stageName, ME));
    end
end

function localSavePipelineRun(runObj)
    pipelineRunSave(runObj);
end

function localSaveProject(shallowObj, hub)
    localEnsureProjectSavePathIsLocal(shallowObj, hub);
    try
        shallowSave(shallowObj, 'shallowObj');
    catch
    end
end

function localEnsureProjectSavePathIsLocal(shallowObj, hub)
    try
        if isempty(shallowObj) || ~isprop(shallowObj, 'io') || ~isstruct(shallowObj.io) || ...
                ~isfield(shallowObj.io, 'path') || isempty(shallowObj.io.path)
            return;
        end
        ctx = struct();
        ctx.hub = hub;
        [localPath, mapped] = detecdiv_paths_map_module_path(shallowObj.io.path, ctx, 'local');
        if mapped && ~isempty(localPath)
            shallowObj.io.path = localPath;
        end
    catch
    end
end

function wrapped = localWrapStageError(stageName, ME)
    locked = localProjectLockedStageError(stageName, ME);
    if ~isempty(locked)
        wrapped = locked;
        return;
    end

    msg = sprintf('Hub submit failed during "%s": %s', char(string(stageName)), ME.message);
    if ~isempty(ME.identifier)
        msg = sprintf('%s\nIdentifier: %s', msg, ME.identifier);
    end
    if ~isempty(ME.stack)
        lines = cell(1, min(numel(ME.stack), 6));
        for i = 1:numel(lines)
            lines{i} = sprintf('%s:%d', ME.stack(i).name, ME.stack(i).line);
        end
        msg = sprintf('%s\nStack:\n%s', msg, strjoin(lines, newline));
    end
    wrapped = MException('detecdiv_hub_submit_pipeline_run:StageFailed', '%s', msg);
    wrapped = addCause(wrapped, ME);
end

function wrapped = localProjectLockedStageError(stageName, ME)
    wrapped = [];
    if ~strcmp(ME.identifier, 'detecdiv_hub_request:HTTP409')
        return;
    end

    lockInfo = localDecodeHubLockMessage(ME.message);
    if isempty(lockInfo)
        return;
    end

    lines = {
        'This project is locked on DetecDiv Hub.'
        localLockHumanSummary(lockInfo)
        ''
        'A new Hub run cannot be submitted until the active job finishes, is cancelled, or the lock is released.'
        'Use the Run Monitor to follow or cancel the active run, then retry submission.'
        };
    msg = strjoin(lines, newline);
    if ~isempty(stageName)
        msg = sprintf('%s\n\nHub stage: %s', msg, char(string(stageName)));
    end

    wrapped = MException('detecdiv_hub_submit_pipeline_run:ProjectLocked', '%s', msg);
    wrapped = addCause(wrapped, ME);
end

function lockInfo = localDecodeHubLockMessage(messageText)
    lockInfo = [];
    raw = char(string(messageText));
    try
        payload = jsondecode(raw);
    catch
        return;
    end
    if ~isstruct(payload) || ~isfield(payload, 'locks')
        return;
    end
    msg = localTextField(payload, 'message', '');
    if ~contains(lower(msg), 'locked')
        return;
    end

    locks = payload.locks;
    if isempty(locks)
        return;
    end
    if numel(locks) > 1
        locks = locks(1);
    end

    lockInfo = struct();
    lockInfo.message = msg;
    lockInfo.lockKind = localTextField(locks, 'lock_kind', '');
    lockInfo.jobId = localTextField(locks, 'job_id', '');
    lockInfo.holderKey = localTextField(locks, 'holder_key', '');
    lockInfo.holderHost = localTextField(locks, 'holder_host', '');
    lockInfo.reason = localTextField(locks, 'reason', '');
    lockInfo.expiresAt = localTextField(locks, 'expires_at', '');
end

function value = localTextField(s, fieldName, fallback)
    value = fallback;
    try
        if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
            value = char(string(s.(fieldName)));
        end
    catch
        value = fallback;
    end
end

function msg = localLockHumanSummary(lockInfo)
    if strcmpi(lockInfo.lockKind, 'server_job')
        msg = 'Another Hub pipeline run is currently using this project.';
    elseif strcmpi(lockInfo.lockKind, 'client_edit_lease')
        msg = 'This project is currently open for editing in a DetecDiv client.';
    else
        msg = 'Hub has an active project lock.';
    end

    details = {};
    if ~isempty(lockInfo.jobId)
        details{end+1} = ['Job id: ' lockInfo.jobId]; %#ok<AGROW>
    end
    if ~isempty(lockInfo.reason)
        details{end+1} = ['Reason: ' lockInfo.reason]; %#ok<AGROW>
    end
    if ~isempty(lockInfo.holderHost)
        details{end+1} = ['Host: ' lockInfo.holderHost]; %#ok<AGROW>
    end
    if ~isempty(lockInfo.expiresAt)
        details{end+1} = ['Expires: ' lockInfo.expiresAt]; %#ok<AGROW>
    end

    if ~isempty(details)
        msg = [msg newline strjoin(details, newline)];
    end
end

function opts = localParse(varargin)
    opts = struct();
    opts.hub = detecdiv_hub_settings_get();
    opts.requestedMode = 'server';
    opts.priority = 100;
    opts.requestedBy = '';
    opts.executionTargetId = '';
    opts.saveProject = true;
    opts.writeScope = 'project_update';
    opts.projectResolveInitialWaitSec = 1;
    opts.projectResolveAttempts = 60;
    opts.projectResolveIntervalSec = 3;
    i = 1;
    while i <= numel(varargin)
        key = lower(char(string(varargin{i})));
        if i == numel(varargin)
            break;
        end
        value = varargin{i+1};
        switch key
            case 'hub'
                opts.hub = value;
            case 'requestedmode'
                opts.requestedMode = char(string(value));
            case 'priority'
                opts.priority = double(value);
            case 'requestedby'
                opts.requestedBy = char(string(value));
            case 'executiontargetid'
                opts.executionTargetId = char(string(value));
            case 'saveproject'
                opts.saveProject = logical(value);
            case 'writescope'
                opts.writeScope = char(string(value));
            case {'projectresolveinitialwaitsec','initialwaitsec'}
                opts.projectResolveInitialWaitSec = double(value);
            case {'projectresolveattempts','resolveattempts'}
                opts.projectResolveAttempts = double(value);
            case {'projectresolveintervalsec','resolveintervalsec'}
                opts.projectResolveIntervalSec = double(value);
        end
        i = i + 2;
    end
    if isempty(opts.requestedBy) && localCanUseHubUserKey(opts.hub)
        opts.requestedBy = char(string(opts.hub.userKey));
    end
end

function tf = localCanUseHubUserKey(hub)
    tf = false;
    try
        if isfield(hub, 'sessionToken') && ~isempty(hub.sessionToken)
            return;
        end
        tf = isfield(hub, 'userKey') && ~isempty(hub.userKey);
    catch
        tf = false;
    end
end

function projectRef = localBuildProjectRef(ref, hub)
    projectRef = struct();
    projectRef.project_id = ref.project_id;
    projectRef.project_key = ref.project_key;
    projectRef.project_name = ref.project_name;
    if isfield(ref, 'local_project_mat_path') && ~isempty(ref.local_project_mat_path)
        projectRef.local_project_mat_path = ref.local_project_mat_path;
    else
        projectRef.local_project_mat_path = ref.project_mat_path;
    end
    projectRef.project_mat_path = localTranslatePathForServer(ref.project_mat_path, ref, hub);
end

function pipelineRef = localBuildPipelineRef(runObj, ref, hub, shallowObj)
    pipelineRef = struct();
    pipelineRef.pipeline_key = '';
    pipelineRef.pipeline_bundle_uri = '';
    pipelineRef.export_manifest_uri = '';
    pipelineRef.pipeline_json_path = '';
    try
        pipelineRef.pipeline_key = char(string(runObj.templateId));
    catch
    end
    try
        if isstruct(runObj.pipelineRef) && isfield(runObj.pipelineRef, 'id') && ~isempty(runObj.pipelineRef.id)
            pipelineRef.pipeline_key = char(string(runObj.pipelineRef.id));
        end
        if isstruct(runObj.pipelineRef) && isfield(runObj.pipelineRef, 'path') && ~isempty(runObj.pipelineRef.path)
            pipelineRef.pipeline_json_path = localPipelineJsonPath(runObj.pipelineRef.path, ref, hub);
        end
    catch
    end
    if isempty(pipelineRef.pipeline_json_path)
        try
            pipelineRef.pipeline_json_path = localPipelineJsonPath(runObj.templatePath, ref, hub);
        catch
        end
    end
    try
        bundleRef = localExportRunPipelineBundle(runObj, ref, hub, shallowObj);
        if ~isempty(bundleRef.pipeline_json_path)
            pipelineRef.pipeline_bundle_uri = bundleRef.pipeline_bundle_uri;
            pipelineRef.export_manifest_uri = bundleRef.export_manifest_uri;
            pipelineRef.pipeline_json_path = bundleRef.pipeline_json_path;
        end
    catch ME
        error('detecdiv_hub_submit_pipeline_run:PipelineBundleExportFailed', ...
            ['Unable to export a server-visible Hub pipeline bundle. ' ...
             'Hub submission was stopped before sending a local pipeline path to the worker: %s'], ME.message);
    end
    localAssertServerVisiblePipelineRef(pipelineRef);
end

function localAssertServerVisiblePipelineRef(pipelineRef)
    pipelinePath = localText(localGetField(pipelineRef, 'pipeline_json_path', ''));
    bundlePath = localText(localGetField(pipelineRef, 'pipeline_bundle_uri', ''));
    manifestPath = localText(localGetField(pipelineRef, 'export_manifest_uri', ''));

    if isempty(pipelinePath)
        error('detecdiv_hub_submit_pipeline_run:MissingServerPipelineRef', ...
            ['Hub submission requires a server-visible pipeline JSON path. ' ...
             'Export a Hub pipeline bundle before submitting the run.']);
    end
    if localLooksLikeLocalClientPath(pipelinePath)
        error('detecdiv_hub_submit_pipeline_run:LocalPipelinePathForHub', ...
            ['Hub submission would send a local client pipeline path to the worker: %s\n' ...
             'The pipeline must be exported to the run hub_pipeline_bundle first.'], pipelinePath);
    end
    if ~localLooksLikeServerPath(pipelinePath)
        error('detecdiv_hub_submit_pipeline_run:NonServerPipelinePathForHub', ...
            'Hub pipeline path is not server-visible: %s', pipelinePath);
    end
    if (~isempty(bundlePath) && ~localLooksLikeServerPath(bundlePath)) || ...
            (~isempty(manifestPath) && ~localLooksLikeServerPath(manifestPath))
        error('detecdiv_hub_submit_pipeline_run:NonServerPipelineBundleForHub', ...
            'Hub pipeline bundle paths must be server-visible.');
    end
end

function exportSource = localRunPipelineExportSource(runObj, sourcePath)
    exportSource = [];
    try
        if isstruct(runObj.ctx) && isfield(runObj.ctx, 'pipelineSpec') && isstruct(runObj.ctx.pipelineSpec) && ...
                isfield(runObj.ctx.pipelineSpec, 'nodes') && ~isempty(runObj.ctx.pipelineSpec.nodes)
            exportSource = runObj.ctx.pipelineSpec;
            return;
        end
    catch
    end
    if nargin >= 2 && ~isempty(sourcePath)
        exportSource = sourcePath;
    end
end

function tf = localExistingHubBundleUsableForRun(bundlePath, pipelineJsonPath, runObj)
    tf = false;
    if exist(pipelineJsonPath, 'file') ~= 2
        return;
    end
    try
        spec = jsondecode(fileread(pipelineJsonPath));
    catch
        return;
    end
    if ~isstruct(spec) || ~isfield(spec, 'nodes') || isempty(spec.nodes)
        return;
    end

    selectedIds = localSelectedRunNodeIds(runObj);
    if ~isempty(selectedIds)
        bundleIds = cell(1, numel(spec.nodes));
        for i = 1:numel(spec.nodes)
            bundleIds{i} = localText(localGetField(spec.nodes(i), 'id', ''));
        end
        missing = setdiff(selectedIds, bundleIds, 'stable');
        if ~isempty(missing)
            return;
        end
        if ~localBundleManifestContainsSelectedNodes(bundlePath, selectedIds)
            return;
        end
    end

    for i = 1:numel(spec.nodes)
        node = spec.nodes(i);
        nodeType = lower(localText(localGetField(node, 'type', '')));
        if ~any(strcmp(nodeType, {'classifier','processor'}))
            continue;
        end
        modulePath = localText(localNested(node, {'params','modulePath'}, ''));
        if isempty(modulePath)
            continue;
        end
        if ~localModulePathInsideBundle(modulePath, bundlePath, pipelineJsonPath)
            continue;
        end
        absPath = localResolveBundleRelativePath(modulePath, fileparts(pipelineJsonPath));
        if exist(absPath, 'dir') ~= 7 && exist(absPath, 'file') ~= 2
            return;
        end
    end
    tf = true;
end

function tf = localBundleManifestContainsSelectedNodes(bundlePath, selectedIds)
    tf = false;
    manifestPath = fullfile(bundlePath, 'export_manifest.json');
    if exist(manifestPath, 'file') ~= 2
        return;
    end
    try
        manifest = jsondecode(fileread(manifestPath));
    catch
        return;
    end
    if ~isstruct(manifest) || ~isfield(manifest, 'nodes') || isempty(manifest.nodes)
        return;
    end
    manifestIds = cell(1, numel(manifest.nodes));
    for i = 1:numel(manifest.nodes)
        manifestIds{i} = localText(localGetField(manifest.nodes(i), 'id', ''));
    end
    tf = isempty(setdiff(selectedIds, manifestIds, 'stable'));
end

function localAssertHubBundleUsableForRun(bundlePath, pipelineJsonPath, runObj)
    if localExistingHubBundleUsableForRun(bundlePath, pipelineJsonPath, runObj)
        return;
    end
    error('detecdiv_hub_submit_pipeline_run:IncompleteHubPipelineBundle', ...
        ['Hub pipeline bundle is incomplete or stale for this run: %s\n' ...
         'Rebuild the bundle from the current pipeline run before submitting to the Hub.'], ...
        bundlePath);
end

function tf = localModulePathInsideBundle(modulePath, bundlePath, pipelineJsonPath)
    tf = false;
    absPath = localResolveBundleRelativePath(modulePath, fileparts(pipelineJsonPath));
    if isempty(absPath)
        return;
    end
    tf = localPathInside(absPath, bundlePath) || localSamePath(absPath, bundlePath);
end

function absPath = localResolveBundleRelativePath(pathText, baseDir)
    absPath = char(string(pathText));
    if isempty(absPath)
        return;
    end
    absPath = strrep(absPath, '/', filesep);
    if localLooksLikeLocalClientPath(absPath) || localLooksLikeServerPath(absPath)
        return;
    end
    if startsWith(absPath, './')
        absPath = extractAfter(absPath, 2);
        absPath = char(string(absPath));
    end
    absPath = fullfile(baseDir, absPath);
end

function tf = localLooksLikeLocalClientPath(pathValue)
    txt = char(string(pathValue));
    tf = ~isempty(regexp(txt, '^[A-Za-z]:[\\/]', 'once')) || startsWith(txt, '\\');
end

function tf = localLooksLikeServerPath(pathValue)
    txt = strrep(char(string(pathValue)), '\', '/');
    tf = startsWith(txt, '/');
end

function bundleRef = localExportRunPipelineBundle(runObj, ref, hub, shallowObj)
    bundleRef = struct('pipeline_bundle_uri', '', 'export_manifest_uri', '', 'pipeline_json_path', '');
    runPath = char(string(runObj.path));
    if isempty(runPath)
        return;
    end
    bundlePath = fullfile(runPath, 'hub_pipeline_bundle');
    manifestPath = fullfile(bundlePath, 'export_manifest.json');
    pipelineJsonPath = fullfile(bundlePath, 'pipeline', 'pipeline.json');
    sourcePath = localRunPipelineSourcePath(runObj, ref, hub);
    exportSource = localRunPipelineExportSource(runObj, sourcePath);
    if isempty(exportSource)
        return;
    end
    % Rebuild on every Hub submission. A previous bundle can have the same
    % node ids but stale classifier/processor module contents or paths.
    pipelineExport(exportSource, bundlePath, ...
        'projectObj', shallowObj, ...
        'overwrite', true);
    localPruneHubBundleForRun(bundlePath, runObj);
    localRepairHubPipelineBundlePaths(bundlePath, pipelineJsonPath, ref, hub);
    localAssertHubBundleUsableForRun(bundlePath, pipelineJsonPath, runObj);
    bundleRef.pipeline_bundle_uri = localTranslatePathForServer(bundlePath, ref, hub);
    bundleRef.export_manifest_uri = localTranslatePathForServer(manifestPath, ref, hub);
    bundleRef.pipeline_json_path = localTranslatePathForServer(pipelineJsonPath, ref, hub);
end

function report = localRepairHubPipelineBundlePaths(bundlePath, pipelineJsonPath, ref, hub)
    report = struct('changed', false, 'rewrites', {{}}, 'warnings', {{}});
    if exist(pipelineJsonPath, 'file') ~= 2
        return;
    end
    try
        spec = jsondecode(fileread(pipelineJsonPath));
    catch ME
        report.warnings{end+1} = ['Could not read bundle pipeline JSON: ' ME.message];
        warning('detecdiv_hub_submit_pipeline_run:BundlePathRepair', '%s', report.warnings{end});
        return;
    end
    if ~isstruct(spec) || ~isfield(spec, 'nodes') || isempty(spec.nodes)
        return;
    end

    pipelineDir = fileparts(pipelineJsonPath);
    for i = 1:numel(spec.nodes)
        [nodeOut, nodeReport] = localRepairHubBundleNodePaths(spec.nodes(i), bundlePath, pipelineDir, ref, hub);
        spec.nodes(i) = nodeOut;
        if nodeReport.changed
            report.changed = true;
            report.rewrites = [report.rewrites nodeReport.rewrites]; %#ok<AGROW>
        end
    end

    if report.changed
        localWriteJsonFile(pipelineJsonPath, spec);
        fprintf('[hub-submit] Rewrote %d bundle module path(s) relative to %s.\n', ...
            numel(report.rewrites), pipelineJsonPath);
    end
end

function [node, report] = localRepairHubBundleNodePaths(node, bundlePath, pipelineDir, ref, hub)
    report = struct('changed', false, 'rewrites', {{}});
    if ~isstruct(node)
        return;
    end
    nodeId = localText(localGetField(node, 'id', ''));
    moduleId = localText(localNested(node, {'params','moduleId'}, ''));
    moduleKind = localText(localNested(node, {'params','moduleKind'}, localGetField(node, 'type', '')));
    if isempty(moduleId)
        moduleId = localText(localNested(node, {'origin','id'}, ''));
    end
    if isempty(moduleKind)
        moduleKind = localText(localNested(node, {'origin','kind'}, ''));
    end

    if isfield(node, 'params') && isstruct(node.params) && isfield(node.params, 'modulePath')
        [node.params.modulePath, changed, rewrite] = localRepairBundlePathValue( ...
            node.params.modulePath, bundlePath, pipelineDir, moduleKind, moduleId, ref, hub, ...
            [nodeId '.params.modulePath']);
        if changed
            report.changed = true;
            report.rewrites{end+1} = rewrite; %#ok<AGROW>
        end
    end

    if isfield(node, 'origin') && isstruct(node.origin) && isfield(node.origin, 'path')
        [node.origin.path, changed, rewrite] = localRepairBundlePathValue( ...
            node.origin.path, bundlePath, pipelineDir, moduleKind, moduleId, ref, hub, ...
            [nodeId '.origin.path']);
        if changed
            report.changed = true;
            report.rewrites{end+1} = rewrite; %#ok<AGROW>
        end
    end
end

function [valueOut, changed, rewrite] = localRepairBundlePathValue(valueIn, bundlePath, pipelineDir, moduleKind, moduleId, ref, hub, label)
    valueOut = valueIn;
    changed = false;
    rewrite = struct('field', label, 'from', '', 'to', '');
    if isempty(valueIn) || ~(ischar(valueIn) || (isstring(valueIn) && isscalar(valueIn)))
        return;
    end

    pathText = char(string(valueIn));
    bundleAssetPath = localResolveBundleAssetPath(pathText, bundlePath, moduleKind, moduleId, ref, hub);
    if isempty(bundleAssetPath)
        return;
    end

    relPath = localRelativeJsonPath(pipelineDir, bundleAssetPath);
    if strcmp(char(string(valueIn)), relPath)
        return;
    end
    valueOut = relPath;
    changed = true;
    rewrite.from = pathText;
    rewrite.to = relPath;
end

function assetPath = localResolveBundleAssetPath(pathText, bundlePath, moduleKind, moduleId, ref, hub)
    assetPath = '';
    candidates = {};
    candidates{end+1} = char(string(pathText)); %#ok<AGROW>
    try
        [mappedPath, mapped] = detecdiv_paths_map_module_path(pathText, localPathMappingCtx(ref, hub), 'local');
        if mapped
            candidates{end+1} = mappedPath; %#ok<AGROW>
        end
    catch
    end
    try
        [mappedPath, mapped] = detecdiv_paths_map_module_path(pathText, localPathMappingCtx(ref, hub), 'server');
        if mapped
            [localPath, localMapped] = detecdiv_paths_map_module_path(mappedPath, localPathMappingCtx(ref, hub), 'local');
            if localMapped
                candidates{end+1} = localPath; %#ok<AGROW>
            end
        end
    catch
    end

    if ~isempty(moduleId)
        candidates{end+1} = fullfile(bundlePath, 'assets', localBundleAssetSubdir(moduleKind), moduleId); %#ok<AGROW>
    end

    for i = 1:numel(candidates)
        candidate = char(string(candidates{i}));
        if isempty(candidate)
            continue;
        end
        if localPathInside(candidate, bundlePath) && (exist(candidate, 'dir') == 7 || exist(candidate, 'file') == 2)
            assetPath = candidate;
            return;
        end
    end
end

function subdir = localBundleAssetSubdir(moduleKind)
    switch lower(char(string(moduleKind)))
        case 'classifier'
            subdir = 'classification';
        case 'processor'
            subdir = 'processing';
        otherwise
            subdir = 'modules';
    end
end

function rel = localRelativeJsonPath(fromPath, toPath)
    fromPath = localNormalizePathForRelative(fromPath);
    toPath = localNormalizePathForRelative(toPath);
    if exist(fromPath, 'file') == 2
        fromPath = fileparts(fromPath);
    end
    fromParts = localSplitPathParts(fromPath);
    toParts = localSplitPathParts(toPath);
    n = min(numel(fromParts), numel(toParts));
    common = 0;
    for i = 1:n
        if strcmpi(fromParts{i}, toParts{i})
            common = i;
        else
            break;
        end
    end
    parts = [repmat({'..'}, 1, numel(fromParts) - common), toParts(common+1:end)];
    if isempty(parts)
        rel = './';
    else
        rel = strrep(fullfile(parts{:}), '\', '/');
        if ~startsWith(rel, '../') && ~startsWith(rel, './')
            rel = ['./' rel];
        end
    end
end

function parts = localSplitPathParts(pathText)
    pathText = strrep(char(string(pathText)), '\', '/');
    parts = regexp(pathText, '/', 'split');
    parts = parts(~cellfun(@isempty, parts));
end

function pathOut = localNormalizePathForRelative(pathIn)
    pathOut = char(string(pathIn));
    pathOut = strrep(pathOut, '/', filesep);
    pathOut = strrep(pathOut, '\', filesep);
    pathOut = regexprep(pathOut, [regexptranslate('escape', filesep) '+$'], '');
end

function localWriteJsonFile(filename, value)
    try
        txt = jsonencode(value, 'PrettyPrint', true);
    catch
        txt = jsonencode(value);
    end
    fid = fopen(filename, 'w');
    if fid < 0
        error('detecdiv_hub_submit_pipeline_run:WriteBundleJson', ...
            'Unable to write repaired bundle pipeline JSON: %s', filename);
    end
    cleaner = onCleanup(@() fclose(fid));
    fwrite(fid, txt, 'char');
    clear cleaner;
end

function sourcePath = localRunPipelineSourcePath(runObj, ref, hub)
    sourcePath = '';
    candidates = {};
    try
        if isstruct(runObj.pipelineRef) && isfield(runObj.pipelineRef, 'path') && ~isempty(runObj.pipelineRef.path)
            candidates{end+1} = char(string(runObj.pipelineRef.path)); %#ok<AGROW>
        end
    catch
    end
    try
        if ~isempty(runObj.templatePath)
            candidates{end+1} = char(string(runObj.templatePath)); %#ok<AGROW>
        end
    catch
    end
    try
        if isstruct(runObj.ctx) && isfield(runObj.ctx, 'pipelineRef') && isstruct(runObj.ctx.pipelineRef) && ...
                isfield(runObj.ctx.pipelineRef, 'path') && ~isempty(runObj.ctx.pipelineRef.path)
            candidates{end+1} = char(string(runObj.ctx.pipelineRef.path)); %#ok<AGROW>
        end
    catch
    end
    for i = 1:numel(candidates)
        sourcePath = localReadablePipelinePath(candidates{i}, ref, hub);
        if ~isempty(sourcePath)
            return;
        end
    end
    sourcePath = '';
end

function bundlePath = localExistingHubBundleFromPipelineSource(sourcePath)
    bundlePath = '';
    sourcePath = char(string(sourcePath));
    if isempty(sourcePath)
        return;
    end
    candidates = {sourcePath};
    if isfolder(sourcePath)
        [parentDir, leafName] = fileparts(sourcePath);
        if strcmpi(leafName, 'pipeline')
            candidates{end+1} = parentDir; %#ok<AGROW>
        end
    else
        [parentDir, fileName, fileExt] = fileparts(sourcePath);
        if strcmpi([fileName fileExt], 'pipeline.json')
            candidates{end+1} = fileparts(parentDir); %#ok<AGROW>
        end
    end
    for i = 1:numel(candidates)
        root = candidates{i};
        if localLooksLikeHubBundle(root)
            bundlePath = root;
            return;
        end
    end
end

function tf = localLooksLikeHubBundle(bundlePath)
    tf = false;
    bundlePath = char(string(bundlePath));
    if isempty(bundlePath) || exist(bundlePath, 'dir') ~= 7
        return;
    end
    tf = exist(fullfile(bundlePath, 'export_manifest.json'), 'file') == 2 && ...
        exist(fullfile(bundlePath, 'pipeline', 'pipeline.json'), 'file') == 2;
end

function localPruneHubBundleForRun(bundlePath, runObj)
    selectedIds = localSelectedRunNodeIds(runObj);
    if isempty(selectedIds)
        return;
    end
    pipelineJsonPath = fullfile(bundlePath, 'pipeline', 'pipeline.json');
    if exist(pipelineJsonPath, 'file') ~= 2
        return;
    end
    try
        spec = jsondecode(fileread(pipelineJsonPath));
    catch
        return;
    end
    if ~isstruct(spec) || ~isfield(spec, 'nodes') || isempty(spec.nodes)
        return;
    end

    keepPaths = {};
    for i = 1:numel(spec.nodes)
        node = spec.nodes(i);
        nodeId = localText(localGetField(node, 'id', ''));
        if isempty(nodeId) || ~any(strcmp(selectedIds, nodeId))
            continue;
        end
        nodeType = localText(localGetField(node, 'type', ''));
        moduleKind = localText(localNested(node, {'params','moduleKind'}, localNested(node, {'origin','kind'}, nodeType)));
        moduleId = localText(localNested(node, {'params','moduleId'}, localNested(node, {'origin','id'}, '')));
        if isempty(moduleId)
            moduleId = nodeId;
        end
        assetSubdir = localRunBundleAssetSubdir(moduleKind, nodeType);
        if ~isempty(assetSubdir) && ~isempty(moduleId)
            keepPaths{end+1} = fullfile(bundlePath, 'assets', assetSubdir, moduleId); %#ok<AGROW>
        end
    end
    keepPaths = unique(keepPaths, 'stable');
    localPruneBundleAssets(bundlePath, keepPaths);
    localPruneBundleManifest(bundlePath, selectedIds);
end

function selectedIds = localSelectedRunNodeIds(runObj)
    selectedIds = {};
    candidates = {};
    try
        candidates{end+1} = runObj.ctx.run.selectedNodes; %#ok<AGROW>
    catch
    end
    try
        candidates{end+1} = runObj.run.selectedNodes; %#ok<AGROW>
    catch
    end
    for i = 1:numel(candidates)
        ids = localStringList(candidates{i});
        if ~isempty(ids)
            selectedIds = ids;
            return;
        end
    end
end

function values = localStringList(value)
    values = {};
    if isempty(value)
        return;
    end
    if ischar(value) || isstring(value)
        arr = cellstr(string(value(:)));
    elseif iscell(value)
        arr = cellfun(@(x) char(string(x)), value(:), 'UniformOutput', false);
    else
        return;
    end
    arr = arr(~cellfun(@isempty, arr));
    values = unique(arr(:)', 'stable');
end

function subdir = localRunBundleAssetSubdir(moduleKind, nodeType)
    key = lower(char(string(moduleKind)));
    if isempty(key)
        key = lower(char(string(nodeType)));
    end
    switch key
        case {'classifier','classification'}
            subdir = 'classification';
        case {'processor','processing'}
            subdir = 'processing';
        case {'roipattern','roi_pattern'}
            subdir = 'roipatterns';
        otherwise
            subdir = '';
    end
end

function localPruneBundleAssets(bundlePath, keepPaths)
    assetsDir = fullfile(bundlePath, 'assets');
    if exist(assetsDir, 'dir') ~= 7
        return;
    end
    listing = dir(assetsDir);
    listing = listing([listing.isdir]);
    listing = listing(~ismember({listing.name}, {'.','..'}));
    for i = 1:numel(listing)
        categoryDir = fullfile(assetsDir, listing(i).name);
        children = dir(categoryDir);
        children = children(~ismember({children.name}, {'.','..'}));
        for j = 1:numel(children)
            childPath = fullfile(categoryDir, children(j).name);
            if localShouldKeepBundleAsset(childPath, keepPaths)
                continue;
            end
            if ~localPathInside(childPath, assetsDir)
                continue;
            end
            if children(j).isdir
                [ok, msg, msgId] = rmdir(childPath, 's');
            else
                ok = true; msg = ''; msgId = '';
                try
                    delete(childPath);
                catch ME
                    ok = false; msg = ME.message; msgId = ME.identifier;
                end
            end
            if ~ok
                warning('detecdiv_hub_submit_pipeline_run:PruneBundleAssetFailed', ...
                    'Unable to remove unused Hub bundle asset %s (%s): %s', childPath, msgId, msg);
            end
        end
    end
end

function tf = localShouldKeepBundleAsset(assetPath, keepPaths)
    tf = false;
    for i = 1:numel(keepPaths)
        keepPath = keepPaths{i};
        if localSamePath(assetPath, keepPath) || localPathInside(assetPath, keepPath)
            tf = true;
            return;
        end
    end
end

function localPruneBundleManifest(bundlePath, selectedIds)
    manifestPath = fullfile(bundlePath, 'export_manifest.json');
    if exist(manifestPath, 'file') ~= 2
        return;
    end
    try
        manifest = jsondecode(fileread(manifestPath));
    catch
        return;
    end
    if ~isstruct(manifest) || ~isfield(manifest, 'nodes') || isempty(manifest.nodes)
        return;
    end
    keep = false(size(manifest.nodes));
    for i = 1:numel(manifest.nodes)
        nodeId = localText(localGetField(manifest.nodes(i), 'id', ''));
        keep(i) = any(strcmp(selectedIds, nodeId));
    end
    manifest.nodes = manifest.nodes(keep);
    localWriteJsonFile(manifestPath, manifest);
end

function localCopyExistingHubBundle(sourceBundlePath, bundlePath, runPath)
    sourceBundlePath = char(string(sourceBundlePath));
    bundlePath = char(string(bundlePath));
    runPath = char(string(runPath));
    if localSamePath(sourceBundlePath, bundlePath)
        return;
    end
    [~, leafName] = fileparts(bundlePath);
    if ~strcmpi(leafName, 'hub_pipeline_bundle') || ~localPathInside(bundlePath, runPath)
        error('detecdiv_hub_submit_pipeline_run:UnsafeBundleCopy', ...
            'Refusing to replace unexpected Hub bundle path: %s', bundlePath);
    end
    if ~localLooksLikeHubBundle(sourceBundlePath)
        error('detecdiv_hub_submit_pipeline_run:InvalidSourceBundle', ...
            'Source Hub bundle is incomplete: %s', sourceBundlePath);
    end
    if exist(bundlePath, 'dir') == 7
        [ok, msg, msgId] = rmdir(bundlePath, 's');
        if ~ok
            error('detecdiv_hub_submit_pipeline_run:RemoveBundleFailed', ...
                'Unable to remove incomplete Hub bundle %s (%s): %s', bundlePath, msgId, msg);
        end
    end
    parentDir = fileparts(bundlePath);
    if exist(parentDir, 'dir') ~= 7
        [ok, msg, msgId] = mkdir(parentDir);
        if ~ok
            error('detecdiv_hub_submit_pipeline_run:CreateBundleParentFailed', ...
                'Unable to create Hub bundle parent %s (%s): %s', parentDir, msgId, msg);
        end
    end
    [ok, msg, msgId] = copyfile(sourceBundlePath, bundlePath, 'f');
    if ~ok
        error('detecdiv_hub_submit_pipeline_run:CopyBundleFailed', ...
            'Unable to copy Hub bundle from %s to %s (%s): %s', ...
            sourceBundlePath, bundlePath, msgId, msg);
    end
    if ~localLooksLikeHubBundle(bundlePath)
        error('detecdiv_hub_submit_pipeline_run:CopiedBundleIncomplete', ...
            'Copied Hub bundle is incomplete: %s', bundlePath);
    end
end

function tf = localSamePath(pathA, pathB)
    tf = false;
    try
        a = char(java.io.File(char(string(pathA))).getCanonicalPath());
        b = char(java.io.File(char(string(pathB))).getCanonicalPath());
        tf = strcmpi(strrep(a, '/', filesep), strrep(b, '/', filesep));
    catch
        tf = strcmpi(char(string(pathA)), char(string(pathB)));
    end
end

function pathOut = localReadablePipelinePath(pathIn, ref, hub)
    pathOut = char(string(pathIn));
    if isempty(pathOut)
        return;
    end
    if exist(pathOut, 'dir') == 7 || exist(pathOut, 'file') == 2
        return;
    end
    try
        [mappedPath, mapped] = detecdiv_paths_map_module_path(pathOut, localPathMappingCtx(ref, hub), 'local');
        if mapped && (exist(mappedPath, 'dir') == 7 || exist(mappedPath, 'file') == 2)
            pathOut = mappedPath;
            return;
        end
    catch
    end
    pathOut = '';
end

function tf = localPathInside(pathValue, folderValue)
    tf = false;
    try
        pathValue = char(java.io.File(char(string(pathValue))).getCanonicalPath());
        folderValue = char(java.io.File(char(string(folderValue))).getCanonicalPath());
        pathValue = lower(strrep(pathValue, '/', filesep));
        folderValue = lower(strrep(folderValue, '/', filesep));
        if ~endsWith(folderValue, filesep)
            folderValue = [folderValue filesep];
        end
        tf = startsWith(pathValue, folderValue);
    catch
    end
end

function pathOut = localPipelineJsonPath(pathIn, ref, hub)
    pathOut = char(string(pathIn));
    if isfolder(pathOut)
        pathOut = fullfile(pathOut, 'pipeline.json');
    end
    pathOut = localTranslatePathForServer(pathOut, ref, hub);
end

function [out, translated] = localTranslatePathForServer(pathIn, ref, hub)
    out = char(string(pathIn));
    translated = false;
    if isempty(out)
        return;
    end
    [out, translated] = detecdiv_paths_map_module_path(out, localPathMappingCtx(ref, hub), 'server');
    % Ensure POSIX separators for server-side worker.
    out = strrep(out, '\', '/');
end

function runRequest = localBuildRunRequest(runObj, hub, ref)
    ctx = struct();
    try
        if isstruct(runObj.ctx)
            ctx = runObj.ctx;
        end
    catch
    end

    runRequest = struct();
    runRequest.run_id = char(string(runObj.runId));
    runRequest.description = char(string(runObj.description));
    runRequest.selected_nodes = localCellText(localNested(ctx, {'run','selectedNodes'}, {}));
    runRequest.node_params = localBuildNodeParamsList( ...
        localNested(ctx, {'run','nodeParams'}, struct()), runRequest.selected_nodes, ref, hub);
    runRequest.run_policy = localText(localNested(ctx, {'run','runPolicy'}, 'resume'));
    runRequest.input_source = localText(localNested(ctx, {'run','inputSource'}, ''));
    localValidateInputSourceForSelectedNodes(runRequest.input_source, runRequest.selected_nodes, ctx, runObj);
    runRequest.existing_data_policy = localText(localNested(ctx, {'io','existingPolicy'}, ''));
    runRequest.roi_cache_policy = localText(localNested(ctx, {'io','cachePolicy'}, 'auto'));
    runRequest.paths = localBuildRunPaths(ctx, ref, hub);
    runRequest.selection = struct( ...
        'fovs', localNested(ctx, {'sel','fovs'}, []), ...
        'frames', localNested(ctx, {'sel','frames'}, []), ...
        'rois', localNested(ctx, {'sel','rois'}, []), ...
        'channels', {localCellText(localNested(ctx, {'sel','channels'}, {}))});
    runRequest.available_channels = localCellText(localNested(ctx, {'run','availableChannels'}, localNested(ctx, {'channels'}, {})));
    runRequest.roi_channels = localCellText(localNested(ctx, {'roiChannels'}, localNested(ctx, {'run','availableChannels'}, {})));
    runRequest.masks = localCellText(localNested(ctx, {'masks'}, {}));
    runRequest.data_series = localCellText(localNested(ctx, {'dataSeriesNames'}, localNested(ctx, {'dataSeries'}, {})));
    runRequest.control = localBuildRunControl(ctx);
    runRequest.python = localNested(ctx, {'exec','python'}, struct());
    runRequest.gpu = struct('mode', localText(localNested(ctx, {'run','gpuPolicy'}, localNested(ctx, {'exec','gpuPolicy'}, 'module_default'))));
end

function localValidateInputSourceForSelectedNodes(inputSource, selectedNodes, ctx, runObj)
    if isempty(selectedNodes) || ~localIsRawInputSource(inputSource)
        return;
    end
    selectedTypes = localSelectedNodeTypesForSubmit(selectedNodes, ctx, runObj);
    if isempty(selectedTypes)
        return;
    end
    if ~any(strcmp(selectedTypes, 'dataloader'))
        error('detecdiv_hub_submit_pipeline_run:RawModeWithoutDataloader', ...
            ['Input mode is raw-data/dataloader, but the selected pipeline run does not include a dataloader node. ' ...
             'Switch Input mode to "Read from existing project", or include a dataloader in the selected run.']);
    end
end

function tf = localIsRawInputSource(inputSource)
    txt = lower(strtrim(char(string(inputSource))));
    tf = contains(txt, 'dataloader') || contains(txt, 'raw') || contains(txt, 'pipeline start');
end

function nodeTypes = localSelectedNodeTypesForSubmit(selectedNodes, ctx, runObj)
    nodeTypes = {};
    nodes = localPipelineSpecNodesForSubmit(ctx, runObj);
    if isempty(nodes)
        return;
    end
    for i = 1:numel(selectedNodes)
        nodeId = char(string(selectedNodes{i}));
        for j = 1:numel(nodes)
            if strcmp(char(string(localGetFieldForSubmit(nodes(j), 'id', ''))), nodeId)
                nodeTypes{end+1} = lower(char(string(localGetFieldForSubmit(nodes(j), 'type', '')))); %#ok<AGROW>
                break;
            end
        end
    end
    nodeTypes = unique(nodeTypes, 'stable');
end

function nodes = localPipelineSpecNodesForSubmit(ctx, runObj)
    nodes = [];
    try
        spec = localNested(ctx, {'pipelineSpec'}, struct());
        if isstruct(spec) && isfield(spec, 'nodes') && ~isempty(spec.nodes)
            nodes = spec.nodes;
            return;
        end
    catch
    end
    paths = {};
    try
        if isstruct(runObj.pipelineRef) && isfield(runObj.pipelineRef, 'path') && ~isempty(runObj.pipelineRef.path)
            paths{end+1} = char(string(runObj.pipelineRef.path)); %#ok<AGROW>
        end
    catch
    end
    try
        if ~isempty(runObj.templatePath)
            paths{end+1} = char(string(runObj.templatePath)); %#ok<AGROW>
        end
    catch
    end
    for i = 1:numel(paths)
        p = paths{i};
        if exist(p, 'dir') == 7
            p = fullfile(p, 'pipeline.json');
        end
        if exist(p, 'file') ~= 2
            continue;
        end
        try
            spec = jsondecode(fileread(p));
            if isstruct(spec) && isfield(spec, 'nodes') && ~isempty(spec.nodes)
                nodes = spec.nodes;
                return;
            end
        catch
        end
    end
end

function value = localGetFieldForSubmit(S, fieldName, defaultValue)
    value = defaultValue;
    try
        if isstruct(S) && isfield(S, fieldName) && ~isempty(S.(fieldName))
            value = S.(fieldName);
        end
    catch
    end
end

function value = localGetField(S, fieldName, defaultValue)
    value = defaultValue;
    try
        if isstruct(S) && isfield(S, fieldName) && ~isempty(S.(fieldName))
            value = S.(fieldName);
        end
    catch
        value = defaultValue;
    end
end

function items = localBuildNodeParamsList(nodeParams, selectedNodes, ref, hub)
    items = {};
    if isempty(nodeParams)
        return;
    end

    if iscell(nodeParams)
        for i = 1:numel(nodeParams)
            item = localNormalizeNodeParamEntry(nodeParams{i}, '', ref, hub);
            if ~isempty(item)
                items{end+1} = item; %#ok<AGROW>
            end
        end
        return;
    end

    if ~isstruct(nodeParams)
        return;
    end

    if isfield(nodeParams, 'id') && isfield(nodeParams, 'params')
        for i = 1:numel(nodeParams)
            item = localNormalizeNodeParamEntry(nodeParams(i), '', ref, hub);
            if ~isempty(item)
                items{end+1} = item; %#ok<AGROW>
            end
        end
        return;
    end

    keys = fieldnames(nodeParams);
    used = false(size(keys));
    selectedNodes = localCellText(selectedNodes);
    for i = 1:numel(selectedNodes)
        nodeId = char(string(selectedNodes{i}));
        key = localNodeParamsKey(nodeParams, nodeId);
        if isempty(key)
            continue;
        end
        item = localNormalizeNodeParamEntry(nodeParams.(key), nodeId, ref, hub);
        if ~isempty(item)
            items{end+1} = item; %#ok<AGROW>
        end
        used(strcmp(keys, key)) = true;
    end

    for i = 1:numel(keys)
        if used(i)
            continue;
        end
        key = keys{i};
        item = localNormalizeNodeParamEntry(nodeParams.(key), key, ref, hub);
        if ~isempty(item)
            items{end+1} = item; %#ok<AGROW>
        end
    end
end

function key = localNodeParamsKey(nodeParams, nodeId)
    key = '';
    if isfield(nodeParams, nodeId)
        key = nodeId;
        return;
    end
    validKey = matlab.lang.makeValidName(nodeId);
    if isfield(nodeParams, validKey)
        key = validKey;
    end
end

function item = localNormalizeNodeParamEntry(value, fallbackId, ref, hub)
    item = [];
    nodeId = fallbackId;
    params = value;
    if isstruct(value) && isfield(value, 'id') && isfield(value, 'params')
        nodeId = localText(value.id);
        params = value.params;
    end
    if isempty(nodeId)
        return;
    end
    if isempty(params)
        params = struct();
    end
    item = struct('id', char(string(nodeId)), ...
        'params', localTranslateValuePathsForServer(params, ref, hub));
end

function paths = localBuildRunPaths(ctx, ref, hub)
    rawDataPath = localText(localNested(ctx, {'run','rawDataPath'}, localNested(ctx, {'io','rawDataPath'}, localNested(ctx, {'rawDataPath'}, ''))));
    projectPath = localText(localNested(ctx, {'run','projectPath'}, localNested(ctx, {'io','projectPath'}, localNested(ctx, {'projectPath'}, ''))));
    paths = struct();
    paths.raw_data_path = rawDataPath;
    paths.project_path = projectPath;
    paths.server_raw_data_path = localText(localNested(ctx, {'run','serverRawDataPath'}, localNested(ctx, {'io','serverRawDataPath'}, '')));
    paths.server_project_path = localText(localNested(ctx, {'run','serverProjectPath'}, localNested(ctx, {'io','serverProjectPath'}, '')));
    if isempty(paths.server_raw_data_path) && ~isempty(rawDataPath)
        paths.server_raw_data_path = localTranslatePathForServer(rawDataPath, ref, hub);
    end
    if isempty(paths.server_project_path) && ~isempty(projectPath)
        paths.server_project_path = localTranslatePathForServer(projectPath, ref, hub);
    end
    paths.server_project_data_folder = localText(localNested(ctx, {'run','serverProjectDataFolder'}, localNested(ctx, {'io','serverProjectDataFolder'}, '')));
    paths.path_mappings = localHubPathMappings(hub);
end

function value = localTranslateValuePathsForServer(value, ref, hub)
    if isstruct(value)
        for i = 1:numel(value)
            names = fieldnames(value(i));
            for j = 1:numel(names)
                value(i).(names{j}) = localTranslateValuePathsForServer(value(i).(names{j}), ref, hub);
            end
        end
    elseif iscell(value)
        for i = 1:numel(value)
            value{i} = localTranslateValuePathsForServer(value{i}, ref, hub);
        end
    elseif isstring(value)
        for i = 1:numel(value)
            textValue = char(value(i));
            if localLooksLikePathText(textValue)
                value(i) = string(localTranslatePathForServer(textValue, ref, hub));
            end
        end
    elseif ischar(value)
        if localLooksLikePathText(value)
            value = localTranslatePathForServer(value, ref, hub);
        end
    end
end

function tf = localLooksLikePathText(value)
    value = char(string(value));
    tf = ~isempty(regexp(value, '^[A-Za-z]:[\\/]', 'once')) || ...
        startsWith(value, '\') || startsWith(value, '/') || ...
        contains(value, '\') || contains(value, '/');
end

function mappings = localHubPathMappings(hub)
    mappings = detecdiv_paths_module_mappings(localPathMappingCtx(struct(), hub));
end

function ctx = localPathMappingCtx(ref, hub)
    ctx = struct();
    if nargin >= 2 && isstruct(hub)
        ctx.hub = hub;
    else
        ctx.hub = struct();
    end
    extra = struct('localRoot', {}, 'remoteRoot', {});
    try
        if isstruct(ref) && isfield(ref, 'local_project_dir_path') && isfield(ref, 'project_dir_path') && ...
                ~isempty(ref.local_project_dir_path) && ~isempty(ref.project_dir_path)
            extra = localAppendServerPathMapping(extra, ref.local_project_dir_path, ref.project_dir_path);
        end
        if isstruct(ref) && isfield(ref, 'local_project_root_path') && isfield(ref, 'project_root_path') && ...
                ~isempty(ref.local_project_root_path) && ~isempty(ref.project_root_path)
            extra = localAppendServerPathMapping(extra, ref.local_project_root_path, ref.project_root_path);
        end
    catch
    end
    if ~isempty(extra)
        existing = struct('localRoot', {}, 'remoteRoot', {});
        try
            if isfield(ctx.hub, 'pathMappings') && isstruct(ctx.hub.pathMappings)
                existing = ctx.hub.pathMappings;
            end
        catch
        end
        ctx.hub.pathMappings = [extra existing];
    end
end

function mappings = localAppendServerPathMapping(mappings, localRoot, remoteRoot)
    localRoot = char(string(localRoot));
    remoteRoot = char(string(remoteRoot));
    if isempty(localRoot) || isempty(remoteRoot) || ~localLooksLikeServerPath(remoteRoot)
        return;
    end
    mappings(end+1).localRoot = localRoot; %#ok<AGROW>
    mappings(end).remoteRoot = remoteRoot;
end

function control = localBuildRunControl(ctx)
    control = struct();
    control.resume_policy = localText(localNested(ctx, {'run','runPolicy'}, 'resume'));
    control.cancel_policy = 'cooperative';
    control.progress_granularity = 'roi';
    control.local_cancel_mode = 'file_token';
    control.hub_cancel_mode = 'hub_job_cancel';
    control.hub_cancel_endpoint = '/pipeline-runs/{job_id}/cancel';
end

function execution = localBuildExecution(opts)
    execution = struct();
    execution.allow_gui = false;
    execution.interactive = false;
    execution.save_project = opts.saveProject;
    execution.write_scope = opts.writeScope;
    execution.requested_mode = opts.requestedMode;
    if ~isempty(opts.executionTargetId)
        execution.execution_target_id = opts.executionTargetId;
    end
end

function runObj = localAttachHubJob(runObj, job, ref)
    if ~isstruct(runObj.ctx)
        runObj.ctx = struct();
    end
    if ~isfield(runObj.ctx, 'hub') || ~isstruct(runObj.ctx.hub)
        runObj.ctx.hub = struct();
    end
    runObj.ctx.hub.project_id = ref.project_id;
    runObj.ctx.hub.project_key = ref.project_key;
    runObj.ctx.hub.job_id = char(string(job.id));
    runObj.ctx.hub.status = char(string(job.status));
    runObj.ctx.hub.submitted_at = char(datetime('now'));
    runObj.ctx.hub.project_stale_after_job = true;
    runObj.status = ['hub_' char(string(job.status))];
end

function value = localNested(S, pathParts, defaultValue)
    value = defaultValue;
    cur = S;
    for i = 1:numel(pathParts)
        if ~isstruct(cur) || ~isfield(cur, pathParts{i})
            return;
        end
        cur = cur.(pathParts{i});
    end
    if ~isempty(cur)
        value = cur;
    end
end

function out = localCellText(value)
    if isempty(value)
        out = {};
    elseif iscell(value)
        out = cellfun(@(x) char(string(x)), value(:)', 'UniformOutput', false);
    elseif isstring(value)
        out = cellstr(value(:)');
    else
        out = {char(string(value))};
    end
end

function txt = localText(value)
    txt = '';
    if ~isempty(value)
        txt = char(string(value));
    end
end

function host = localHostName()
    host = '';
    try
        host = char(string(java.net.InetAddress.getLocalHost.getHostName));
    catch
    end
end
