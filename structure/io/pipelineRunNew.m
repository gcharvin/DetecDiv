function runObj = pipelineRunNew(shallowObj, templateId, templatePath, varargin)
% pipelineRunNew  Create and attach a new pipeline run to a project.

    if nargin < 1 || isempty(shallowObj) || ~isa(shallowObj,'shallow')
        error('pipelineRunNew:MissingProject','A shallow project is required.');
    end
    if nargin < 2 || isempty(templateId)
        templateId = 'pipeline';
    end
    if nargin < 3
        templatePath = '';
    end

    % optional args
    runId = '';
    description = '';
    ctx = struct();
    status = 'new';
    pipelineRef = struct();
    targetRef = struct();

    i = 1;
    while i <= numel(varargin)
        key = varargin{i};
        if ~ischar(key) && ~isstring(key)
            i = i + 1;
            continue;
        end

        switch lower(char(string(key)))
            case 'runid'
                runId = varargin{i+1};
            case 'description'
                description = varargin{i+1};
            case 'ctx'
                ctx = varargin{i+1};
            case 'status'
                status = varargin{i+1};
            case 'pipelineref'
                pipelineRef = varargin{i+1};
            case 'targetref'
                targetRef = varargin{i+1};
        end
        i = i + 2;
    end

    ensurePipelineRunField(shallowObj);

    % compute runId if missing
    if isempty(runId)
        runId = nextRunId(shallowObj, templateId);
    end

    projectPath = fullfile(shallowObj.io.path, shallowObj.io.file);
    runObj = pipelineRun(projectPath, runId, numel(shallowObj.processing.pipelineRun)+1);

    if isempty(pipelineRef) || ~isstruct(pipelineRef)
        pipelineRef = struct();
    end
    if isempty(targetRef) || ~isstruct(targetRef)
        targetRef = struct();
    end

    if isempty(fieldnames(pipelineRef)) && isfield(ctx,'pipelineRef') && isstruct(ctx.pipelineRef)
        pipelineRef = ctx.pipelineRef;
    end
    if isempty(fieldnames(targetRef)) && isfield(ctx,'targetRef') && isstruct(ctx.targetRef)
        targetRef = ctx.targetRef;
    end

    runObj.pipelineRef = normalizePipelineRef(pipelineRef, templateId, templatePath);
    runObj.targetRef = normalizeTargetRef(targetRef, shallowObj);

    % Compatibility fields
    runObj.templateId = runObj.pipelineRef.id;
    runObj.templatePath = runObj.pipelineRef.path;
    runObj.projectPath = runObj.targetRef.projectPath;
    runObj.projectName = runObj.targetRef.projectName;

    runObj.description = description;
    runObj.ctx = stripHeavyContextForRunStorage(ctx);
    runObj.status = status;
    runObj.ctx = attachRunPathsToContext(runObj.ctx, runObj);

    if ~isfield(runObj.ctx,'pipelineRef') || ~isstruct(runObj.ctx.pipelineRef)
        runObj.ctx.pipelineRef = runObj.pipelineRef;
    end
    if ~isfield(runObj.ctx,'targetRef') || ~isstruct(runObj.ctx.targetRef)
        runObj.ctx.targetRef = runObj.targetRef;
    end

    % attach to project
    shallowObj.processing.pipelineRun(end+1) = runObj;
    emitPipelineRunCreated(shallowObj, runObj);
end

function ctx = stripHeavyContextForRunStorage(ctx)
    if ~isstruct(ctx)
        ctx = struct();
        return;
    end
    heavyFields = {'shallow', 'shallowObj', 'project', 'projectObj', ...
        'fovList', 'roiList', 'rois', 'classifierObj', 'classiObj', ...
        'progressDlg', 'cancel'};
    for i = 1:numel(heavyFields)
        name = heavyFields{i};
        try
            if isfield(ctx, name)
                ctx = rmfield(ctx, name);
            end
        catch
        end
    end
    try
        if isfield(ctx, 'store') && isstruct(ctx.store) && isfield(ctx.store, 'classifierRuntime')
            ctx.store = rmfield(ctx.store, 'classifierRuntime');
        end
    catch
    end
end

function emitPipelineRunCreated(shallowObj, runObj)
    if exist('detecdiv_event', 'file') ~= 2
        return;
    end

    payload = struct();
    payload.kind = 'pipelineRun';
    payload.action = 'created';
    payload.source = 'pipelineRunNew';
    try
        payload.runId = char(string(runObj.runId));
    catch
        payload.runId = '';
    end
    try
        payload.runIndex = numel(shallowObj.processing.pipelineRun);
    catch
        payload.runIndex = [];
    end
    try
        payload.runPath = char(string(runObj.path));
    catch
        payload.runPath = '';
    end
    try
        payload.projectPath = fullfile(shallowObj.io.path, shallowObj.io.file);
    catch
        payload.projectPath = '';
    end
    try
        payload.projectName = char(string(shallowObj.id));
    catch
        payload.projectName = '';
    end

    try
        detecdiv_event('emit', 'pipelineRunCreated', payload);
        detecdiv_event('emit', 'workspaceChanged', payload);
    catch ME
        warning('pipelineRunNew:EventEmitFailed', ...
            'Unable to broadcast pipeline run creation: %s', ME.message);
    end
end

function ctx = attachRunPathsToContext(ctx, runObj)
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
    runPath = '';
    try
        [runPath, ~] = runObj.getPath;
    catch
        runPath = '';
    end
    if isempty(runPath)
        return;
    end
    eventLogPath = fullfile(runPath, 'run_events.jsonl');
    ctx.runId = char(string(runObj.runId));
    ctx.run.runId = char(string(runObj.runId));
    ctx.run.path = runPath;
    ctx.run.runPath = runPath;
    ctx.run.eventLogPath = eventLogPath;
    ctx.io.eventLogPath = eventLogPath;
    ctx.store.runPath = runPath;
    ctx.store.eventLogPath = eventLogPath;
end

function ensurePipelineRunField(shallowObj)
    if ~isfield(shallowObj.processing,'pipelineRun') || isempty(shallowObj.processing.pipelineRun)
        shallowObj.processing.pipelineRun = pipelineRun.empty;
    end
end

function out = normalizePipelineRef(ref, templateId, templatePath)
    out = struct('id', char(string(templateId)), 'path', char(string(templatePath)), 'version', '');
    if nargin < 1 || isempty(ref) || ~isstruct(ref)
        return;
    end

    if isfield(ref,'id') && ~isempty(ref.id)
        out.id = char(string(ref.id));
    end
    if isfield(ref,'path') && ~isempty(ref.path)
        out.path = char(string(ref.path));
    end
    if isfield(ref,'version') && ~isempty(ref.version)
        out.version = char(string(ref.version));
    end
end

function out = normalizeTargetRef(ref, shallowObj)
    projectPath = fullfile(shallowObj.io.path, shallowObj.io.file);
    out = struct('type','shallow', 'projectPath', projectPath, 'projectName', shallowObj.io.file, ...
        'fovIds', [], 'roiIds', {{}}, 'classiPath', '', 'notes', '');

    if nargin < 1 || isempty(ref) || ~isstruct(ref)
        return;
    end

    if isfield(ref,'type') && ~isempty(ref.type)
        out.type = char(string(ref.type));
    end
    if isfield(ref,'projectPath') && ~isempty(ref.projectPath)
        out.projectPath = char(string(ref.projectPath));
    end
    if isfield(ref,'projectName') && ~isempty(ref.projectName)
        out.projectName = char(string(ref.projectName));
    end
    if isfield(ref,'fovIds') && ~isempty(ref.fovIds)
        out.fovIds = ref.fovIds;
    end
    if isfield(ref,'roiIds') && ~isempty(ref.roiIds)
        out.roiIds = ref.roiIds;
    end
    if isfield(ref,'classiPath') && ~isempty(ref.classiPath)
        out.classiPath = char(string(ref.classiPath));
    end
    if isfield(ref,'notes') && ~isempty(ref.notes)
        out.notes = char(string(ref.notes));
    end
end

function runId = nextRunId(shallowObj, templateId)
    runId = [templateId '_1'];
    if ~isfield(shallowObj.processing,'pipelineRun') || isempty(shallowObj.processing.pipelineRun)
        return;
    end

    existing = shallowObj.processing.pipelineRun;
    names = arrayfun(@(p) p.runId, existing, 'UniformOutput', false);
    n = 1;
    while any(strcmp(names, [templateId '_' num2str(n)]))
        n = n + 1;
    end
    runId = [templateId '_' num2str(n)];
end
