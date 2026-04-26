function status = detecdiv_hub_project_locks(project, hub)
% detecdiv_hub_project_locks  Read project write-lock status from the hub.

    if nargin < 2 || isempty(hub)
        hub = detecdiv_hub_settings_get();
    end
    ref = localProjectRef(project, hub);
    if isempty(ref.project_id)
        error('detecdiv_hub_project_locks:MissingProjectId', ...
            'Hub project id is required. Store it in shallowObj.runProfiles.hub.hub_project_id.');
    end

    status = detecdiv_hub_request('GET', ['/projects/' ref.project_id '/locks'], [], hub);
end
