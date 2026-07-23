function state = detecdiv_hub_local_project_state(shallowObj)
% detecdiv_hub_local_project_state  Resolve cached Hub state without network I/O.
%
% Prefer runProfiles.hub, then supplement missing identity fields from Hub
% pipeline runs embedded in the project. This helper is safe for selection
% and paint callbacks because it never contacts the server.

    state = struct();
    if isempty(shallowObj) || ~isa(shallowObj, 'shallow')
        return;
    end

    try
        if isprop(shallowObj, 'runProfiles') && isstruct(shallowObj.runProfiles) && ...
                isfield(shallowObj.runProfiles, 'hub') && isstruct(shallowObj.runProfiles.hub)
            state = shallowObj.runProfiles.hub;
        end
    catch
    end

    if localHasIdentity(state)
        return;
    end

    try
        if ~isfield(shallowObj.processing, 'pipelineRun') || isempty(shallowObj.processing.pipelineRun)
            return;
        end
        runs = shallowObj.processing.pipelineRun;
        for i = numel(runs):-1:1
            if ~isstruct(runs(i).ctx) || ~isfield(runs(i).ctx, 'hub') || ...
                    ~isstruct(runs(i).ctx.hub)
                continue;
            end
            runHub = runs(i).ctx.hub;
            projectId = localText(runHub, {'project_id','hub_project_id'});
            projectKey = localText(runHub, {'project_key','hub_project_key'});
            jobId = localText(runHub, {'job_id','hub_job_id'});
            if isempty(projectId) && isempty(projectKey) && isempty(jobId)
                continue;
            end
            state.hubManaged = true;
            if ~isempty(projectId)
                state.hub_project_id = projectId;
                state.project_id = projectId;
            end
            if ~isempty(projectKey)
                state.project_key = projectKey;
            end
            if ~isfield(state, 'mode') || isempty(state.mode)
                state.mode = 'hub_run_known';
            end
            if ~isfield(state, 'reason') || isempty(state.reason)
                state.reason = 'Hub identity recovered from the latest pipeline run.';
            end
            return;
        end
    catch
    end
end

function tf = localHasIdentity(state)
    tf = false;
    try
        tf = isstruct(state) && ( ...
            (isfield(state, 'hubManaged') && logical(state.hubManaged)) || ...
            (isfield(state, 'hub_managed') && logical(state.hub_managed)) || ...
            (isfield(state, 'hub_project_id') && ~isempty(state.hub_project_id)) || ...
            (isfield(state, 'project_id') && ~isempty(state.project_id)));
    catch
    end
end

function txt = localText(S, names)
    txt = '';
    for i = 1:numel(names)
        try
            if isfield(S, names{i}) && ~isempty(S.(names{i}))
                txt = char(string(S.(names{i})));
                return;
            end
        catch
        end
    end
end
