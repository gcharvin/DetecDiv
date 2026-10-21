function job = detecdiv_hub_find_active_pipeline_run(runObj, project, hub)
% Find an already submitted execution of this run without writing or submitting.
job = [];
if isempty(runObj) || ~isa(runObj,'pipelineRun'), return; end
if nargin < 3 || isempty(hub), hub = detecdiv_hub_settings_get(); end
runId = char(string(runObj.runId));
if isempty(runId), return; end
savedHub = struct();
if isstruct(runObj.ctx) && isfield(runObj.ctx,'hub') && isstruct(runObj.ctx.hub)
    savedHub = runObj.ctx.hub;
end
projectId = textField(savedHub,'project_id');
if nargin >= 2 && ~isempty(project)
    ref = localProjectRef(project,hub);
    resolvedId = textField(ref,'project_id');
    if ~isempty(resolvedId), projectId = resolvedId; end
end
knownId = textField(savedHub,'job_id');
if isempty(knownId), knownId = textField(savedHub,'hub_job_id'); end
if ~isempty(knownId)
    try
        candidate = detecdiv_hub_get_pipeline_run(knownId,hub);
        if matches(candidate,runId,projectId), job = candidate; return; end
    catch ME
        if ~strcmp(ME.identifier,'detecdiv_hub_request:HTTP404'), rethrow(ME); end
    end
end
if isempty(projectId), return; end
summary = detecdiv_hub_project_lock_summary(struct('project_id',projectId),hub);
for i = 1:numel(summary.locks)
    lock = summary.locks(i);
    if ~strcmpi(lock.kind,'server_job') || isempty(lock.job_id) || strcmp(lock.job_id,knownId)
        continue;
    end
    candidate = detecdiv_hub_get_pipeline_run(lock.job_id,hub);
    if matches(candidate,runId,projectId), job = candidate; return; end
end
end

function tf = matches(job,runId,projectId)
tf = false;
if ~isstruct(job) || ~any(strcmpi(textField(job,'status'),{'queued','running','cancelling'}))
    return;
end
if ~isempty(projectId) && ~strcmp(textField(job,'project_id'),projectId), return; end
if ~isfield(job,'params_json') || ~isstruct(job.params_json) || ...
        ~isfield(job.params_json,'run_request') || ~isstruct(job.params_json.run_request)
    return;
end
tf = ~isempty(textField(job,'id')) && strcmp(textField(job.params_json.run_request,'run_id'),runId);
end

function value = textField(s,key)
value = '';
if isstruct(s) && isscalar(s) && isfield(s,key) && ~isempty(s.(key))
    value = char(string(s.(key)));
end
end
