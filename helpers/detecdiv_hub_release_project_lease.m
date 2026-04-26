function lease = detecdiv_hub_release_project_lease(project, lockId, hub)
% detecdiv_hub_release_project_lease  Release a client edit lease.

    if nargin < 3 || isempty(hub)
        hub = detecdiv_hub_settings_get();
    end
    ref = localProjectRef(project, hub);
    if isempty(ref.project_id) || isempty(lockId)
        error('detecdiv_hub_release_project_lease:MissingInput', 'project id and lockId are required.');
    end
    lease = detecdiv_hub_request('DELETE', ['/projects/' ref.project_id '/leases/' char(string(lockId))], [], hub);
end
