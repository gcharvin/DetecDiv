function detecdiv_emit_workspace_changed(ctx, report, status, sourceName)
% detecdiv_emit_workspace_changed  Notify open DetecDiv apps after a run mutates workspace/project state.

if nargin < 1 || ~isstruct(ctx)
    ctx = struct();
end
if nargin < 2 || ~isstruct(report)
    report = struct();
end
if nargin < 3 || isempty(status)
    status = 'updated';
end
if nargin < 4 || isempty(sourceName)
    sourceName = 'detecdiv';
end

try
    payload = struct();
    payload.kind = 'pipelineRun';
    payload.action = 'completed';
    payload.source = char(string(sourceName));
    payload.status = char(string(status));
    payload.projectObj = [];
    payload.projectMatPath = '';
    payload.projectPath = '';
    payload.projectName = '';
    payload.projectVarName = '';
    payload.runId = '';
    payload.summary = struct();

    if isfield(ctx, 'runId') && ~isempty(ctx.runId)
        payload.runId = char(string(ctx.runId));
    end
    if isfield(report, 'summary')
        payload.summary = report.summary;
    end
    if isfield(ctx, 'run') && isstruct(ctx.run)
        if isfield(ctx.run, 'projectVarName') && ~isempty(ctx.run.projectVarName)
            payload.projectVarName = char(string(ctx.run.projectVarName));
        elseif isfield(ctx.run, 'workspaceVar') && ~isempty(ctx.run.workspaceVar)
            payload.projectVarName = char(string(ctx.run.workspaceVar));
        end
    end

    shallowObj = [];
    if isfield(ctx, 'shallow') && isa(ctx.shallow, 'shallow')
        shallowObj = ctx.shallow;
    elseif isfield(ctx, 'shallowObj') && isa(ctx.shallowObj, 'shallow')
        shallowObj = ctx.shallowObj;
    end

    if isa(shallowObj, 'shallow')
        payload.projectObj = shallowObj;
        try
            [projectRoot, projectName] = shallowObj.getPath;
            payload.projectMatPath = fullfile(projectRoot, [projectName '.mat']);
            payload.projectPath = fullfile(projectRoot, projectName);
            payload.projectName = char(string(projectName));
        catch
        end
        if isempty(payload.projectName)
            try
                payload.projectName = char(string(shallowObj.id));
            catch
            end
        end
    end

    detecdiv_event('emit', 'pipelineRunCompleted', payload);
    detecdiv_event('emit', 'workspaceChanged', payload);
catch ME
    warning('detecdiv:WorkspaceEventEmitFailed', ...
        'Unable to broadcast workspace update: %s', ME.message);
end
end
